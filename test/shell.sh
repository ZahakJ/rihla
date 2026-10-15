#!/bin/sh
# The shell inside rihla's tmux must be the shell outside it, and `rihla shell` must give
# a bare machine the comforts of a set-up zsh or bash. Called by test/assert.sh after the
# install (rihla on PATH), with the same throwaway HOME.
#
#   sh test/shell.sh [--offline]
#
# Parity, for bash and (when installed) zsh: a shell started by tmux reads the same rc
# files as one in a terminal (bash: not a login shell), so it has the same expanded
# prompt bytes (digits masked), the user's settings, and no doubled PATH entries; TERM is
# tmux-256color with italics and 256 colours; COLORTERM says truecolor; 24-bit colour
# printed in a pane reaches the attached terminal as 24-bit colour; Home, End and
# Ctrl-Left typed into a real client arrive as the pane's terminfo says they will; a
# client with TERM=xterm-kitty (kitty over SSH) can attach.
# Shell layer: `rihla shell` for bash (ble.sh, starship, fzf, zoxide) and zsh
# (autosuggestions, syntax highlighting, starship, fzf, zoxide); typing in a tmux pane
# shows the grey suggestion within 500 ms, Right accepts it, an unknown command turns red,
# the shell starts with nothing but its prompt (rihla's starship prompt where the layer
# says so) in under 300 ms, Ctrl-R is fzf; Ctrl-T and Alt-C list with fd and the shared
# defaults (hidden files in, node_modules out), as do rg and fd themselves; rgi finds a
# line and Enter opens nvim there, Ctrl-Q puts every hit in nvim's quickfix list; with
# xz to unpack it, `rihla shell --fish` makes tmux open fish with suggestions, colours,
# fzf and rgi, and --no-fish gives the shell back; an existing oh-my-zsh / powerlevel10k /
# plugin setup (stub files) is detected and left alone; `rihla shell --off` removes it.
# Prints "RESULT ..." lines like test/assert.sh; exits non-zero on failure.

set -u
# Shells started here must use the throwaway HOME's files only, whatever the caller exported.
unset HISTFILE HISTSIZE HISTFILESIZE SAVEHIST HISTCONTROL ZDOTDIR STARSHIP_CONFIG STARSHIP_CACHE \
	STARSHIP_SHELL STARSHIP_SESSION_KEY _ZO_DATA_DIR FZF_DEFAULT_OPTS FZF_DEFAULT_OPTS_FILE \
	XDG_CONFIG_HOME XDG_DATA_HOME XDG_STATE_HOME XDG_CACHE_HOME TMUX TMUX_PANE BLE_VERSION
OFFLINE=
[ "${1:-}" = --offline ] && OFFLINE=1
TB=$(command -v tmux) || {
	echo "RESULT shell-tests FAIL no tmux"
	exit 1
}
SOCK=rihla-sh-$$-0
NSOCK=0
W=$(mktemp -d "${TMPDIR:-/tmp}/rihla-sh.XXXXXX")
FAILS=0
HOLD='' CLIENT=''
t() { "$TB" -L "$SOCK" "$@"; }
result() {
	printf 'RESULT %s %s %s\n' "$1" "$2" "${3:-}"
	[ "$2" = PASS ] || FAILS=$((FAILS + 1))
}
stop_client() {
	[ -n "$CLIENT" ] && kill "$CLIENT" 2>/dev/null
	[ -n "$HOLD" ] && kill "$HOLD" 2>/dev/null
	CLIENT='' HOLD=''
}
cleanup() {
	stop_client
	i=0
	while [ $i -le $NSOCK ]; do
		"$TB" -L "rihla-sh-$$-$i" kill-server >/dev/null 2>&1
		i=$((i + 1))
	done
	rm -rf "$W"
}
# A new tmux server on a socket of its own: starting one right after kill-server on the
# same socket can meet the old server on its way out ("server exited unexpectedly").
fresh_server() {
	t kill-server >/dev/null 2>&1
	NSOCK=$((NSOCK + 1))
	SOCK=rihla-sh-$$-$NSOCK
}
trap cleanup EXIT
wait_for() { # wait_for COMMAND...: poll up to 30 s
	n=0
	while [ $n -lt 300 ]; do
		"$@" && return 0
		n=$((n + 1))
		sleep 0.1
	done
	return 1
}
hex() { od -An -tx1 | tr -s ' \n' '  ' | sed 's/^ *//; s/ *$//'; }
now_ms() { # milliseconds (GNU date; perl or python3 where date has no %N, as on macOS)
	ns=$(date +%s%N 2>/dev/null)
	case $ns in
	'' | *N*) perl -MTime::HiRes=time -e 'printf "%d\n", time * 1000' 2>/dev/null ||
		python3 -c 'import time; print(int(time.time() * 1000))' ;;
	*) echo $((ns / 1000000)) ;;
	esac
}
# poll_ms LIMIT COMMAND...: milliseconds until COMMAND succeeds (polled every 20 ms), or
# nothing after LIMIT ms.
poll_ms() {
	lim=$1
	shift
	p0=$(now_ms)
	while :; do
		"$@" && echo $(($(now_ms) - p0)) && return 0
		[ $(($(now_ms) - p0)) -gt "$lim" ] && return 1
		sleep 0.02
	done
}
# speed_startup LABEL COMMAND...: median of 5 starts (after one to fill the caches) < 300 ms.
speed_startup() {
	sl=$1
	shift
	"$@" </dev/null >/dev/null 2>&1
	sleep 1
	ts=
	for _ in 1 2 3 4 5; do
		a=$(now_ms)
		"$@" </dev/null >/dev/null 2>&1
		ts="$ts $(($(now_ms) - a))"
	done
	med=$(printf '%s\n' $ts | sort -n | sed -n 3p)
	if [ -n "$med" ] && [ "$med" -lt 300 ]; then
		result "speed-startup-$sl" PASS "median $med ms of 5 starts (limit 300; runs:$ts)"
	else
		result "speed-startup-$sl" FAIL "median ${med:-?} ms of 5 starts (limit 300; runs:$ts)"
	fi
}

# A terminal in a pty, reading what we type from a fifo: run_pty LOG COMMAND (TERM from env).
run_pty() {
	rm -f "$W/in"
	mkfifo "$W/in"
	sleep 300 >"$W/in" &
	HOLD=$!
	if [ "$(uname -s)" = Linux ]; then
		# script runs the command with $SHELL -c: sh, so no rc file of the caller's shell runs first.
		SHELL=/bin/sh script -qfc "stty rows 30 cols 120 2>/dev/null; exec $2" "$1" <"$W/in" >/dev/null 2>&1 &
	else
		python3 -c 'import pty, sys; pty.spawn(["sh", "-c", sys.argv[1]])' "stty rows 30 cols 120; exec $2" <"$W/in" >"$1" 2>&1 &
	fi
	CLIENT=$!
}
# A fifo write blocks while nobody reads it: only write while the terminal is alive.
type_in() {
	kill -0 "${CLIENT:-0}" 2>/dev/null || return 1
	# shellcheck disable=SC2059
	printf "$1" >"$W/in"
}

# What a shell knows about itself, written to a file (sourced by bash and zsh).
cat >"$W/probe.sh" <<'EOF'
_f=$1
{
	echo "TERM=$TERM"
	echo "COLORTERM=${COLORTERM:-}"
	echo "colors=$(tput colors 2>/dev/null)"
	echo "italics=$(tput sitm >/dev/null 2>&1 && echo yes || echo no)"
	if [ -n "${ZSH_VERSION:-}" ]; then
		echo "login=$([[ -o login ]] && echo yes || echo no)"
		echo "prompt=$(print -rnP -- "$PROMPT" | od -An -tx1 | tr -s ' \n' '  ' | tr '0-9a-f' 'x')"
		echo "promptlen=${#${(%%)PROMPT}}"
		echo "ctrlr=$(bindkey '^R' 2>/dev/null)"
		echo "layer=${rihla_shell_on[*]:-}"
		echo "skipped=${rihla_shell_skipped[*]:-}"
	else
		echo "login=$(shopt -q login_shell && echo yes || echo no)"
		echo "prompt=$(printf '%s' "$PS1" | od -An -tx1 | tr -s ' \n' '  ' | tr '0-9a-f' 'x')"
		echo "promptlen=${#PS1}"
		echo "ctrlr=$(declare -F __fzf_history__ >/dev/null 2>&1 && echo 1 || echo 0)"
		echo "layer=${rihla_shell_on:-}"
		echo "skipped=${rihla_shell_skipped:-}"
	fi
	echo "editor=${EDITOR:-}"
	echo "pathdups=$(echo "$PATH" | tr ':' '\n' | sort | uniq -d | tr '\n' ' ')"
} >"$_f.tmp" && mv "$_f.tmp" "$_f"
EOF

# probe_outside SHELL FILE: the shell in a plain terminal (a pty from script, no tmux).
# Terminals on macOS (Terminal.app, iTerm2) start login shells; elsewhere they do not.
probe_outside() {
	if [ "$(uname -s)" = Darwin ]; then
		run_pty "$W/outside.log" "env SHELL=$1 $1 -l -i"
	else
		run_pty "$W/outside.log" "env SHELL=$1 $1 -i"
	fi
	sleep 2
	type_in ". $W/probe.sh $2\r"
	wait_for test -s "$2"
	type_in 'exit\r'
	sleep 0.3
	stop_client
}

# probe_inside SHELL FILE: the shell tmux starts for a new session (default-command). The
# server is started from an interactive SHELL, as a user does: the pane inherits what that
# shell exported (PATH, STARSHIP_SHELL, ...) and must still set itself up the same way.
# On macOS that shell is a login shell, as a terminal there starts one.
probe_inside() {
	fresh_server
	lg=
	[ "$(uname -s)" = Darwin ] && lg=-l
	SHELL=$1 "$1" $lg -i -c "'$TB' -L '$SOCK' -f '$HOME/.tmux.conf' new-session -d -s p -x 120 -y 30; unset HISTFILE" \
		</dev/null >/dev/null 2>&1
	has_session || return 1
	sleep 2
	t send-keys -t p ". $W/probe.sh $2" Enter
	wait_for test -s "$2"
}

pane_has() { t capture-pane -p -t "$1" 2>/dev/null | grep -q -- "$2"; }
field() { sed -n "s/^$1=//p" "$2"; }
has_session() { wait_for t has-session -t p 2>/dev/null; }
has_client() { [ -n "$(t list-clients 2>/dev/null)" ]; }

# ------------------------------------------------------------------ parity
parity() { # parity SHELL-PATH LABEL
	sh=$1 l=$2
	rm -f "$W/out-$l" "$W/in-$l"
	probe_outside "$sh" "$W/out-$l"
	probe_inside "$sh" "$W/in-$l"
	if [ ! -s "$W/out-$l" ] || [ ! -s "$W/in-$l" ]; then
		result "tmux-parity-$l" FAIL "no probe output (outside: $([ -s "$W/out-$l" ] && echo ok || echo none), inside: $([ -s "$W/in-$l" ] && echo ok || echo none))"
		return
	fi
	bad=
	keys="prompt promptlen editor pathdups layer skipped"
	case $l in bash*) keys="$keys login" ;; esac
	for k in $keys; do
		[ "$(field $k "$W/out-$l")" = "$(field $k "$W/in-$l")" ] || bad="$bad $k(outside '$(field $k "$W/out-$l" | cut -c1-60)' inside '$(field $k "$W/in-$l" | cut -c1-60)')"
	done
	# bash in tmux must not be a login shell on Linux (it would skip ~/.bashrc). On macOS
	# it is one, as in a terminal there (it reads ~/.bash_profile, where rihla's line goes);
	# the comparison above checks that. zsh is a login shell in tmux everywhere, as tmux
	# starts it by default (it reads .zshrc either way); compare everything else.
	case $l in
	bash*) [ "$(uname -s)" = Darwin ] || [ "$(field login "$W/in-$l")" = no ] || bad="$bad login-shell-in-tmux" ;;
	esac
	if [ -z "$bad" ]; then
		result "tmux-parity-$l" PASS "same prompt bytes ($(field promptlen "$W/in-$l") chars), login shell: $(field login "$W/in-$l"), rc read (EDITOR=$(field editor "$W/in-$l")), PATH without duplicates"
	else
		result "tmux-parity-$l" FAIL "differs:$bad"
	fi
	tt=$(field TERM "$W/in-$l") ct=$(field COLORTERM "$W/in-$l")
	if ! command -v tput >/dev/null 2>&1; then
		# Minimal images (Rocky 9) have the terminfo files but no tput to read them.
		if [ "$tt" = tmux-256color ] && [ "$ct" = truecolor ]; then
			result "tmux-term-$l" PASS "TERM=$tt, COLORTERM=$ct (no tput here to ask for colours and italics)"
		else
			result "tmux-term-$l" FAIL "TERM=$tt COLORTERM=$ct"
		fi
	elif [ "$tt" = tmux-256color ] && [ "$(field colors "$W/in-$l")" = 256 ] && [ "$(field italics "$W/in-$l")" = yes ] && [ "$ct" = truecolor ]; then
		result "tmux-term-$l" PASS "TERM=$tt, 256 colours, italics, COLORTERM=$ct"
	else
		result "tmux-term-$l" FAIL "TERM=$tt colors=$(field colors "$W/in-$l") italics=$(field italics "$W/in-$l") COLORTERM=$ct"
	fi
}

# ------------------------------------------------------------------ client: colour, keys
client_checks() {
	fresh_server
	SHELL=/bin/sh t -f "$HOME/.tmux.conf" new-session -d -s c -x 120 -y 30 || return 1
	TERM=xterm-256color run_pty "$W/client.log" "$TB -L $SOCK attach -t c"
	if ! wait_for has_client; then
		result tmux-truecolor FAIL "no client attached"
		stop_client
		return
	fi
	sleep 0.5
	t send-keys -t c "printf '\\033[48;2;1;2;3m rgb \\033[0m\\n'" Enter
	sleep 1
	if grep -aq '48;2;1;2;3m\|48:2::1:2:3m\|48:2:1:2:3m' "$W/client.log"; then
		result tmux-truecolor PASS "a 24-bit colour printed in a pane reaches the terminal as 24-bit"
	else
		result tmux-truecolor FAIL "the terminal got no 48;2;1;2;3 (downsampled or dropped)"
	fi
	# Keys as xterm sends them (normal cursor mode): Home, End, Ctrl-Left.
	t send-keys -t c "clear; stty raw -echo; dd bs=1 count=14 2>/dev/null | od -An -tx1 > $W/keys.txt; stty sane" Enter
	sleep 1
	type_in '\033[H'
	sleep 0.2
	type_in '\033[F'
	sleep 0.2
	type_in '\033[1;5D'
	wait_for test -s "$W/keys.txt"
	got=$(tr -s ' \n' '  ' <"$W/keys.txt" | sed 's/^ *//; s/ *$//')
	pt=$(t show -gv default-terminal 2>/dev/null)
	if command -v tput >/dev/null 2>&1; then
		want=$({ TERM=$pt tput khome; TERM=$pt tput kend; printf '\033[1;5D'; } | hex)
	else
		# No tput: tmux-256color's and screen-256color's khome and kend.
		want=$(printf '\033[1~\033[4~\033[1;5D' | hex)
	fi
	if [ -n "$got" ] && [ "$got" = "$want" ]; then
		result tmux-keys PASS "Home End Ctrl-Left arrive as the pane's terminfo says ($got)"
	else
		result tmux-keys FAIL "got '$got', terminfo says '$want'"
	fi
	stop_client
	# kitty over SSH: TERM=xterm-kitty must be usable (rihla brings the entry if missing).
	if [ "$(uname -s)" = Linux ]; then
		TERM=xterm-kitty run_pty "$W/kitty.log" "$TB -L $SOCK attach -t c"
		if wait_for has_client; then
			result tmux-kitty-term PASS "a client with TERM=xterm-kitty attaches"
		else
			result tmux-kitty-term FAIL "$(tr -d '\r' <"$W/kitty.log" | grep -a 'terminal' | head -n 1)"
		fi
		stop_client
	fi
	t kill-server >/dev/null 2>&1
}

# ------------------------------------------------------------------ shell layer in a pane
# layer_typing SHELL LABEL [COMMAND]: a quiet start, the suggestion (and how fast it shows),
# accept, highlighting in a real tmux pane. COMMAND: what tmux starts (default: SHELL).
layer_typing() {
	sh=$1 l=$2
	fresh_server
	SHELL=$sh t -f "$HOME/.tmux.conf" new-session -d -s l -x 120 -y 30 ${3:+"$3"} || return 1
	# A prompt first (ble.sh's first start in a new HOME builds its caches), then type.
	wait_for pane_has l '[^[:space:]]'
	sleep 2
	# Nothing but the prompt: no error from a setup that does not work here. (ble.sh says
	# once per terminal type that it made its cache: its own message, not an error.)
	scr=$(t capture-pane -p -t l | grep -v '^[[:space:]]*$' | grep -v '^ble/term.sh: updating tput cache')
	n=$(printf '%s\n' "$scr" | grep -c .)
	case $LAYER_ON in *prompt:starship*) star=1 ;; *) star= ;; esac
	if [ "$n" -eq 1 ] && ! printf '%s' "$scr" | grep -qi 'error\|unknown\|not found\|(eval)'; then
		if [ -z "$star" ] || t capture-pane -e -p -t l | grep -q '48;2;137;180;250m\|48;5;111m'; then
			[ -n "$star" ] && star=", rihla's starship prompt"
			result "layer-quiet-start-$l" PASS "only the prompt on screen$star"
		else
			result "layer-quiet-start-$l" FAIL "the layer says starship, the prompt is not rihla's: '$scr'"
		fi
	else
		result "layer-quiet-start-$l" FAIL "$(printf '%s' "$scr" | head -n 3 | tr '\n' '|')"
		# The pane with its escape sequences, to tell a stray terminal reply from a message.
		t capture-pane -e -p -t l | grep -v '^[[:space:]]*$' | head -n 5 | cat -v | sed 's/^/   pane: /'
	fi
	t send-keys -t l -l 'echo rihla-p'
	if ms=$(poll_ms 5000 pane_has l 'echo rihla-probe'); then sug=1; else sug=; fi
	cap=$(t capture-pane -p -t l | grep 'echo rihla-p' | tail -n 1)
	t send-keys -t l Right
	sleep 0.5
	t send-keys -t l Enter
	sleep 1
	acc=$(t capture-pane -p -t l | grep -c '^rihla-probe')
	if [ -n "$sug" ] && [ "$acc" -ge 1 ]; then
		result "layer-autosuggest-$l" PASS "typing 'echo rihla-p' shows 'echo rihla-probe'; Right accepts it"
	else
		result "layer-autosuggest-$l" FAIL "line: '$cap'; accepted lines: $acc"
	fi
	# From sending the keys to the suggestion on screen, through tmux.
	if [ -n "$sug" ] && [ "$ms" -le 500 ]; then
		result "speed-suggest-$l" PASS "suggestion on screen $ms ms after the keys were sent (limit 500)"
	else
		result "speed-suggest-$l" FAIL "${ms:-no suggestion} ms (limit 500)"
	fi
	t send-keys -t l -l 'nonexistentcmd'
	sleep 1.5
	cap=$(t capture-pane -e -p -t l | grep 'nonexistentcmd' | tail -n 1)
	case $cap in
	*'243;139;168m'*nonexistentcmd* | *'38;5;211m'*nonexistentcmd*) result "layer-highlight-$l" PASS "an unknown command is drawn in red" ;;
	*) result "layer-highlight-$l" FAIL "$(printf '%s' "$cap" | od -c | head -n 4 | tr -s ' \n' ' ')" ;;
	esac
	t send-keys -t l C-u
	t kill-server >/dev/null 2>&1
}

# A small project: a hit in a text file, one in a hidden file, one in node_modules.
mkdir -p "$W/proj/src" "$W/proj/.hidden" "$W/proj/node_modules/x"
printf 'first line\nsecond\nthe needle = 1\nreturn needle\n' >"$W/proj/src/notes.txt"
echo needle >"$W/proj/.hidden/h.txt"
echo needle >"$W/proj/node_modules/x/n.js"

# search_checks SHELL LABEL: rg and fd defaults, Ctrl-T, Alt-C and rgi in a tmux pane.
search_checks() {
	sh=$1 l=$2
	fresh_server
	SHELL=$sh t -f "$HOME/.tmux.conf" new-session -d -s s -x 100 -y 30 -c "$W/proj" ${3:+"$3"} || return 1
	wait_for pane_has s '[^[:space:]]'
	sleep 2
	rm -f "$W/rg-$l.out" "$W/fd-$l.out"
	t send-keys -t s "rg -l needle > $W/rg-$l.out; fd > $W/fd-$l.out" Enter
	wait_for test -s "$W/fd-$l.out"
	sleep 0.3
	if grep -q '^\.hidden/h.txt$' "$W/rg-$l.out" && grep -q '^\.hidden/h.txt$' "$W/fd-$l.out" &&
		! grep -q node_modules "$W/rg-$l.out" "$W/fd-$l.out"; then
		result "search-defaults-$l" PASS "rg and fd list the hidden file and leave node_modules out"
	else
		result "search-defaults-$l" FAIL "rg: $(tr '\n' ' ' <"$W/rg-$l.out"); fd: $(tr '\n' ' ' <"$W/fd-$l.out")"
	fi
	t send-keys -t s 'clear' Enter
	sleep 0.5
	t send-keys -t s C-t
	if wait_for pane_has s 'hidden/h.txt'; then
		sleep 0.5
		if pane_has s node_modules; then
			result "fzf-ctrl-t-$l" FAIL "node_modules is listed"
		else
			result "fzf-ctrl-t-$l" PASS "Ctrl-T lists with fd: hidden files in, node_modules out"
		fi
	else
		result "fzf-ctrl-t-$l" FAIL "$(t capture-pane -p -t s | grep -v '^$' | head -n 5 | tr '\n' '|')"
	fi
	t send-keys -t s Escape
	sleep 0.5
	t send-keys -t s C-u 'clear' Enter
	sleep 0.5
	# Ctrl-R: fzf's list of earlier commands (its counter, "2/2"), not the shell's own search.
	t send-keys -t s C-r
	# Wait for the history entry itself: fzf draws "0/0" before its input has arrived.
	if wait_for pane_has s 'rihla-probe' && pane_has s '[1-9][0-9]*/[1-9]'; then
		result "fzf-ctrl-r-$l" PASS "Ctrl-R opens fzf on the history"
	else
		result "fzf-ctrl-r-$l" FAIL "$(t capture-pane -p -t s | grep -v '^$' | head -n 4 | tr '\n' '|')"
	fi
	t send-keys -t s Escape
	sleep 0.5
	t send-keys -t s C-u 'clear' Enter
	sleep 0.5
	t send-keys -t s M-c
	if wait_for pane_has s '\.hidden'; then
		sleep 0.5
		if pane_has s node_modules || pane_has s 'notes.txt'; then
			result "fzf-alt-c-$l" FAIL "lists files or node_modules: $(t capture-pane -p -t s | grep -v '^$' | head -n 6 | tr '\n' '|')"
		else
			result "fzf-alt-c-$l" PASS "Alt-C lists directories with fd, node_modules left out"
		fi
	else
		result "fzf-alt-c-$l" FAIL "$(t capture-pane -p -t s | grep -v '^$' | head -n 5 | tr '\n' '|')"
	fi
	t send-keys -t s Escape
	sleep 0.5
	# rgi: one hit, Enter, nvim at that line and column ("the needle": column 5).
	rm -f "$W/rgi-$l.out" "$W/qf-$l.out"
	t send-keys -t s C-u "rgi 'needle = 1'" Enter
	if wait_for pane_has s 'src/notes.txt:3'; then
		t send-keys -t s Enter
		if wait_for nvim_running s; then
			sleep 1
			t send-keys -t s Escape ":call writefile([expand('%') . ':' . line('.') . ':' . col('.')], '$W/rgi-$l.out')" Enter
			wait_for test -s "$W/rgi-$l.out"
			t send-keys -t s Escape ':qa!' Enter
		fi
	fi
	got=$(cat "$W/rgi-$l.out" 2>/dev/null)
	if [ "$got" = src/notes.txt:3:5 ]; then
		result "rgi-open-$l" PASS "rgi finds the line; Enter opens nvim at src/notes.txt:3:5"
	else
		result "rgi-open-$l" FAIL "nvim at '${got:-nothing}': $(t capture-pane -p -t s | grep -v '^$' | tail -n 4 | tr '\n' '|')"
	fi
	wait_for nvim_gone s
	t send-keys -t s C-u "rgi needle" Enter
	if wait_for pane_has s 'hidden/h.txt'; then
		sleep 0.5
		t send-keys -t s C-q
		if wait_for nvim_running s; then
			sleep 1
			t send-keys -t s Escape ":call writefile([len(getqflist())], '$W/qf-$l.out')" Enter
			wait_for test -s "$W/qf-$l.out"
			t send-keys -t s Escape ':qa!' Enter
		fi
	fi
	got=$(cat "$W/qf-$l.out" 2>/dev/null)
	if [ "$got" = 3 ]; then
		result "rgi-quickfix-$l" PASS "Ctrl-Q opens nvim with the 3 hits in the quickfix list"
	else
		result "rgi-quickfix-$l" FAIL "quickfix entries: '${got:-none}'"
	fi
	t kill-server >/dev/null 2>&1
}
nvim_running() { [ "$(t display -p -t "$1" '#{pane_current_command}' 2>/dev/null)" = nvim ]; }
nvim_gone() { ! nvim_running "$1"; }

layer_on() { # layer_on bash|zsh
	k=$1 sh=$(command -v "$1")
	SHELL=$sh rihla shell >"$W/layer-$k.out" 2>&1
	rc=$?
	sed "s/^/   [shell $k] /" "$W/layer-$k.out"
	f=$(SHELL=$sh rihla shell status 2>/dev/null | sed -n 's/^shell layer: on for [a-z]* (line in \(.*\))$/\1/p')
	on=$(SHELL=$sh rihla shell status 2>/dev/null | sed -n 's/^  on: //p')
	want="prompt fzf zoxide search" miss=
	[ "$k" = zsh ] && want="$want autosuggestions highlighting completion"
	# ble.sh comes as .tar.xz; without xz it is skipped (and the installer says so). It
	# needs bash 4+ (macOS's /bin/bash is 3.2) and ps (not in minimal images); without
	# either the layer skips it and `rihla shell` says why.
	if [ "$k" = bash ]; then
		bv=$("$sh" -c 'echo "${BASH_VERSINFO[0]}"' 2>/dev/null)
		if command -v xz >/dev/null 2>&1 && command -v ps >/dev/null 2>&1 && [ "${bv:-0}" -ge 4 ]; then
			want="$want blesh"
		elif ! grep -q 'ble\.sh' "$W/layer-$k.out"; then
			miss="$miss blesh-reason"
		fi
	fi
	for p in $want; do
		case " $on " in *" $p "* | *" $p:"*) ;; *) miss="$miss $p" ;; esac
	done
	LAYER_ON=$on
	if [ $rc -eq 0 ] && [ -n "$f" ] && [ -z "$miss" ]; then
		result "layer-on-$k" PASS "line in $f; on: $on"
	else
		result "layer-on-$k" FAIL "exit $rc, file '$f', on: '$on', missing:$miss"
		# Diagnostics for a failure on a system we cannot run locally (macOS in CI).
		echo "   [diag] full status:"
		SHELL=$sh rihla shell status 2>&1 | sed 's/^/   [diag]   /'
		echo "   [diag] rc file $f:"
		sed 's/^/   [diag]   /' "$f" 2>/dev/null
		echo "   [diag] trace of an interactive login $k reading its rc (rihla lines only):"
		"$sh" -l -i -x -c 'echo "@@on=${rihla_shell_on:-} loaded=${rihla_shell_loaded:-} dash=$-"' </dev/null 2>&1 |
			grep -nE 'rihla|@@on|bash_profile|bashrc|zshrc|return' | head -n 40 | sed 's/^/   [diag]   /'
	fi
}

# ------------------------------------------------------------------ run
zsh_bin=$(command -v zsh 2>/dev/null)
echo "== shell: bash $(bash --version | sed -n '1s/.*version \([^ ]*\).*/\1/p')${zsh_bin:+, zsh $(zsh --version | cut -d' ' -f2)}"

parity "$(command -v bash)" bash
[ -n "$zsh_bin" ] && parity "$zsh_bin" zsh
client_checks

# History to suggest from (the user's own history files; not removed by uninstall).
echo 'echo rihla-probe' >>"$HOME/.bash_history"

layer_on bash
# Suggestions and highlighting in bash come from ble.sh, which needs xz to unpack.
case " $LAYER_ON " in
*" blesh "*) layer_typing "$(command -v bash)" bash ;;
*) echo "== bash: no ble.sh here (bash 3, or no xz to unpack it, or no ps), so no suggestions or highlighting to test" ;;
esac
search_checks "$(command -v bash)" bash
# With the layer on, the shell in tmux is still the shell outside it.
parity "$(command -v bash)" bash-layer
if [ -n "$zsh_bin" ]; then
	printf 'echo rihla-probe\n' >>"$HOME/.zsh_history"
	layer_on zsh
	speed_startup zsh "$zsh_bin" -i -c 'unset HISTFILE; exit'
	# zsh -i -c with no terminal (a script, an IDE, ssh host 'zsh -i -c ...'): nothing on stderr.
	err=$("$zsh_bin" -i -c 'unset HISTFILE; true' </dev/null 2>&1 >/dev/null)
	if [ -z "$err" ]; then
		result layer-no-tty-zsh PASS "zsh -i -c without a terminal prints nothing"
	else
		result layer-no-tty-zsh FAIL "$(printf '%s' "$err" | head -n 3 | tr '\n' '|')"
	fi
	layer_typing "$zsh_bin" zsh
	search_checks "$zsh_bin" zsh
	parity "$zsh_bin" zsh-layer
fi
grep -q '^ctrlr=.*fzf-history-widget' "$W/in-zsh-layer" 2>/dev/null && zr=1 || zr=
br=$(field ctrlr "$W/in-bash-layer" 2>/dev/null)
if [ "${br:-0}" -ge 1 ] && { [ -z "$zsh_bin" ] || [ -n "$zr" ]; }; then
	result layer-ctrl-r PASS "Ctrl-R runs fzf's history search"
else
	result layer-ctrl-r FAIL "bash fzf bindings: ${br:-?}; zsh ^R: $(field ctrlr "$W/in-zsh-layer" 2>/dev/null)"
fi

# ------------------------------------------------------------------ fish in rihla's tmux
fish_checks() {
	SHELL=$(command -v bash) rihla shell --fish >"$W/fish.out" 2>&1
	sed 's/^/   [fish] /' "$W/fish.out"
	conf=${XDG_STATE_HOME:-$HOME/.local/state}/rihla/tmux-shell.conf
	if [ ! -f "$conf" ]; then
		# No xz (Rocky 9, Ubuntu 24.04 images) or no build for this system: one line says so.
		why=$(grep 'warn.*fish' "$W/fish.out" | head -n 1)
		case $why in
		*'needs xz'* | *'no pinned build'*) result fish-on PASS "not here, and rihla shell --fish says why:${why#*warn}" ;;
		*) result fish-on FAIL "no tmux-shell.conf and no reason given" ;;
		esac
		return
	fi
	fb=$(sed -n "s/^set -g default-command \"exec '\([^']*\)'.*/\1/p" "$conf")
	frc=$(sed -n "s/.*-C 'source \(.*\)'\"$/\1/p" "$conf")
	on=$(sed -n 's/.*in tmux: //p' "$W/fish.out")
	miss=
	for p in colours search fzf zoxide prompt; do
		case " $on " in *" $p "* | *" $p:"*) ;; *) miss="$miss $p" ;; esac
	done
	if [ -x "$fb" ] && [ -f "$frc" ] && [ -z "$miss" ]; then
		result fish-on PASS "$("$fb" --version) in tmux; on: $on"
	else
		result fish-on FAIL "fish '$fb', layer '$frc', on: '$on', missing:$miss"
	fi
	mkdir -p "$HOME/.local/share/fish"
	printf -- '- cmd: echo rihla-probe\n  when: 1700000000\n' >>"$HOME/.local/share/fish/fish_history"
	speed_startup fish "$fb" -i -C "source $frc" -c exit
	fresh_server
	SHELL=$(command -v bash) t -f "$HOME/.tmux.conf" new-session -d -s f -x 100 -y 30 || return 1
	wait_for pane_has f '[^[:space:]]'
	sleep 1
	pane_runs_shell() { case $(t display -p -t f '#{pane_current_command}') in bash | sh | zsh | fish) return 0 ;; esac; return 1; }
	wait_for pane_runs_shell
	cmd=$(t display -p -t f '#{pane_current_command}')
	rm -f "$W/fish-r.out"
	t send-keys -t f "bind ctrl-r > $W/fish-r.out" Enter
	wait_for test -s "$W/fish-r.out"
	if [ "$cmd" = fish ] && grep -q fzf "$W/fish-r.out"; then
		result fish-in-tmux PASS "a new tmux pane runs fish; Ctrl-R is fzf's history search"
	else
		result fish-in-tmux FAIL "pane runs '$cmd'; ctrl-r: $(cat "$W/fish-r.out" 2>/dev/null)"
	fi
	t kill-server >/dev/null 2>&1
	LAYER_ON=$on
	layer_typing "$(command -v bash)" fish
	search_checks "$(command -v bash)" fish
	SHELL=$(command -v bash) rihla shell --no-fish >"$W/nofish.out" 2>&1
	fresh_server
	SHELL=$(command -v bash) t -f "$HOME/.tmux.conf" new-session -d -s f -x 100 -y 30 || return 1
	wait_for pane_has f '[^[:space:]]'
	# The prompt's helpers (awk, git) run briefly in the pane: wait for the shell itself.
	pane_runs_shell() { case $(t display -p -t f '#{pane_current_command}') in bash | sh | zsh | fish) return 0 ;; esac; return 1; }
	wait_for pane_runs_shell
	cmd=$(t display -p -t f '#{pane_current_command}')
	if [ ! -f "$conf" ] && [ "$cmd" = bash ] && [ ! -e "$fb" ]; then
		result fish-off PASS "rihla shell --no-fish: tmux opens bash again, rihla's fish removed"
	else
		result fish-off FAIL "pane runs '$cmd'; conf left: $([ -f "$conf" ] && echo yes || echo no); $(tr '\n' ' ' <"$W/nofish.out")"
	fi
	t kill-server >/dev/null 2>&1
	# The test's fish history (yours would stay: rihla does not remove it).
	rm -rf "$HOME/.local/share/fish"
}
[ "$(uname -s)" = Linux ] && fish_checks

# Someone else's setup (stubs standing in for oh-my-zsh, powerlevel10k and the plugins):
# rihla must leave each piece alone and say so.
if [ -n "$zsh_bin" ]; then
	SHELL=$zsh_bin rihla shell --off >/dev/null 2>&1
	cp "$HOME/.zshrc" "$W/zshrc.mine"
	mkdir -p "$HOME/.oh-my-zsh-stub"
	cat >"$HOME/.oh-my-zsh-stub/oh-my-zsh.sh" <<'EOF'
# stand-in for oh-my-zsh with powerlevel10k and the two zsh-users plugins; like HyDE,
# the prompt is starship when `command -v starship` finds one, powerlevel10k otherwise
if command -v starship >/dev/null 2>&1; then
	prompt_starship_precmd() { :; }
else
	ZSH_THEME=powerlevel10k/powerlevel10k
	p10k() { :; }
fi
_zsh_autosuggest_start() { :; }
_zsh_highlight() { :; }
autoload -Uz compinit && compinit -i -d "$HOME/.oh-my-zsh-stub/zcompdump"
EOF
	printf '\nsource "$HOME/.oh-my-zsh-stub/oh-my-zsh.sh"\n' >>"$HOME/.zshrc"
	# Like some frameworks' .zshenv: a PATH entry put in front again by every zsh.
	[ -e "$HOME/.zshenv" ] && cp "$HOME/.zshenv" "$W/zshenv.mine"
	printf 'PATH="$HOME/.oh-my-zsh-stub/bin:$PATH"\n' >>"$HOME/.zshenv"
	SHELL=$zsh_bin rihla shell >"$W/stub.out" 2>&1
	sed 's/^/   [stub] /' "$W/stub.out"
	miss=
	# A starship of the system's own (a desktop running `test/run.sh local`) makes the stub
	# pick starship, as HyDE would.
	if command -v starship >/dev/null 2>&1; then mine=starship want_nest="outer 0 1 inner 0 1 dups: "; else mine=powerlevel10k want_nest="outer 1 0 inner 1 0 dups: "; fi
	grep -q "you already have $mine; rihla's prompt is not enabled" "$W/stub.out" || miss="$miss prompt"
	grep -q "you already have your own autosuggestions" "$W/stub.out" || miss="$miss autosuggestions"
	grep -q "you already have your own syntax highlighting" "$W/stub.out" || miss="$miss highlighting"
	grep -q "you already have your own completion" "$W/stub.out" || miss="$miss completion"
	if [ -z "$miss" ]; then
		result layer-detects-existing PASS "$mine, autosuggestions, highlighting, compinit of your own are left alone and named"
	else
		result layer-detects-existing FAIL "not detected:$miss"
	fi
	# A zsh started from that shell (a tmux pane, a nested zsh) inherits its PATH and
	# environment and must come out the same: the same prompt (rihla's starship is not on
	# PATH for the stub to find) and no PATH entry twice.
	# shellcheck disable=SC2016
	nest=$(SHELL=$zsh_bin "$zsh_bin" -i -c 'print -r -- "@@outer ${+functions[p10k]} ${+functions[prompt_starship_precmd]}"; '"$zsh_bin"' -i -c '"'"'print -r -- "@@inner ${+functions[p10k]} ${+functions[prompt_starship_precmd]} dups:$(print -rl -- $path | sort | uniq -d | tr "\n" ,)"; unset HISTFILE'"'"'; unset HISTFILE' </dev/null 2>/dev/null | sed -n 's/^@@//p' | tr '\n' ' ')
	if [ "$nest" = "$want_nest" ]; then
		result layer-nested-keeps-yours PASS "a nested zsh keeps $mine, PATH has no entry twice"
	else
		result layer-nested-keeps-yours FAIL "p10k / starship outside and inside: '$nest'"
	fi
	SHELL=$zsh_bin rihla shell --off >/dev/null 2>&1
	cp "$W/zshrc.mine" "$HOME/.zshrc"
	if [ -e "$W/zshenv.mine" ]; then cp "$W/zshenv.mine" "$HOME/.zshenv"; else rm -f "$HOME/.zshenv"; fi
	rm -rf "$HOME/.oh-my-zsh-stub"
fi

# Off again: the line goes, the files go, the rc file is as before.
cp "$HOME/.bashrc" "$W/bashrc.on"
SHELL=$(command -v bash) rihla shell --off >"$W/off.out" 2>&1
rc=$?
if [ $rc -eq 0 ] && ! grep -q 'shell/bash.rc' "$HOME/.bashrc" && [ ! -e "${XDG_DATA_HOME:-$HOME/.local/share}/rihla-tools/shell" ]; then
	result layer-off PASS "line and files removed"
else
	result layer-off FAIL "exit $rc: $(tr '\n' ' ' <"$W/off.out")"
fi
# Leave it on for the rest of assert.sh (re-install keeps it, uninstall removes it).
SHELL=$(command -v bash) rihla shell >/dev/null 2>&1
[ -n "$zsh_bin" ] && SHELL=$zsh_bin rihla shell >/dev/null 2>&1
[ -n "$OFFLINE" ] && echo "== shell layer installed with no network (from the bundle's copy in the download cache)"

[ "$FAILS" -eq 0 ]
