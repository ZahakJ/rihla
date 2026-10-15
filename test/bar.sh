#!/bin/sh
# The tmux bar as a user sees it, on any tmux from 1.8 up: the config is loaded from this
# checkout (like the ~/.tmux.conf the installer writes) into a throwaway HOME, a real
# client is attached inside a second tmux of 80x24 columns, and that outer pane is read
# back with capture-pane, so what is checked is what the terminal would draw.
#
#   sh test/bar.sh [TMUX_BINARY]
#
# Every version: the config loads without an error, the bar fits 80 columns with the
# session, all three window names and the time still on it, and ascii mode draws no
# Nerd Font or powerline glyph (private-use code points) anywhere in the bar, the window
# formats or the pane titles.
# tmux 2.6+: a window with two panes gets a title line over each pane; one pane, none.
# tmux 3.0+: the mode tile says PREFIX, COPY, ZOOM (and SEARCH on 3.2+); nerd mode draws
# the rounded tile ends; at 160 columns the date, directory and git segment are there.
# tmux 3.2+: at 80 columns the date steps aside and git takes the place of the key hint.
# The cheat sheet text is wrapped to the popup's width.
# The git segment (tmux/bin/git-status): nothing outside a repository, branch and counts
# inside one, and how long it takes (it must stay under 50 ms).
# Prints "RESULT ..." lines like test/assert.sh; exits non-zero on failure.

set -u
SRC=$(cd "$(dirname "$0")/.." && pwd -P)
TB=${1:-tmux}
TB=$(command -v "$TB" 2>/dev/null) || {
	echo "RESULT bar-tests FAIL no tmux binary '${1:-tmux}'"
	exit 1
}
W=$(mktemp -d "${TMPDIR:-/tmp}/rihla-bar.XXXXXX")
# Each start() uses fresh sockets: reusing one while the old server is still shutting
# down makes the new session flaky.
N=0
IN=rihla-bar-in-$$-0
OUT=rihla-bar-out-$$-0
FAILS=0
result() {
	printf 'RESULT %s %s %s\n' "$1" "$2" "${3:-}"
	[ "$2" = PASS ] || FAILS=$((FAILS + 1))
}
# Every tmux started here gets a throwaway HOME and nothing else from the caller.
tx() {
	env -i PATH="$PATH" HOME="$W/home" TERM=xterm-256color LANG="${LANG:-C}" SHELL=/bin/sh \
		RIHLA_ICONS="$ICONS" "$TB" "$@"
}
ti() { tx -L "$IN" "$@"; }
to() { tx -L "$OUT" "$@"; }
cleanup() {
	ti kill-server >/dev/null 2>&1
	to kill-server >/dev/null 2>&1
	rm -rf "$W"
}
next_sockets() {
	ti kill-server >/dev/null 2>&1
	to kill-server >/dev/null 2>&1
	N=$((N + 1))
	IN=rihla-bar-in-$$-$N
	OUT=rihla-bar-out-$$-$N
}
trap cleanup EXIT

TV=$("$TB" -V 2>/dev/null)
# tmux-ver asks the server named by $TMUX; here there is none, so it runs "tmux -V" from
# PATH. Put the tested binary first.
mkdir -p "$W/bin" "$W/home/.config/rihla"
ln -s "$TB" "$W/bin/tmux"
PATH=$W/bin:$PATH
export PATH
at_least() { TMUX='' sh "$SRC/tmux/bin/tmux-ver" "$1"; }

cat >"$W/home/.tmux.conf" <<EOF
set-environment -g RIHLA_HOME '$SRC'
set-environment -g RIHLA_TMUX '$SRC/tmux'
set-environment -g RIHLA_CONFIG '$W/home/.config/rihla'
source-file '$SRC/tmux/tmux.conf'
EOF

# The private-use areas: U+E000-U+F8FF (UTF-8 EE xx xx, EF 80-A3 xx) and planes 15-16
# (F3 B0-BF.., F4 80-8F..). Nerd Font icons and powerline separators all live there.
PUA=$(printf '\356\\|\357[\200-\243]\\|\363[\260-\277]\\|\364[\200-\217]')
has_pua() { LC_ALL=C grep -q "$PUA"; }

# A git repository with one staged, one changed and one untracked file.
REPO=$W/home/repo
GIT=
if command -v git >/dev/null 2>&1; then
	mkdir -p "$REPO"
	(
		cd "$REPO" && git init -q . && git symbolic-ref HEAD refs/heads/main
		printf 'a\n' >a && printf 'b\n' >b &&
			git add a b && git -c user.name=t -c user.email=t@t.invalid commit -q -m one &&
			printf 'a2\n' >a && git add a && printf 'b2\n' >b && printf 'c\n' >c
	) >/dev/null 2>&1 && GIT=1
fi

# Start the session to look at: three windows, the first in the repository.
start() { # start WIDTH
	next_sockets
	dir=$W/home
	[ -n "$GIT" ] && dir=$REPO
	(cd "$dir" && ti -f "$W/home/.tmux.conf" new-session -d -s demo -n code -x "$1" -y 24) >"$W/err" 2>&1
	ti new-window -d -n server >>"$W/err" 2>&1
	ti new-window -d -n notes >>"$W/err" 2>&1
	# source-file from a client reports parse and command errors on stderr.
	ti source-file "$W/home/.tmux.conf" >>"$W/err" 2>&1
	# The client: inside an outer tmux of the given width, its status line off.
	# screen-256color: a terminal description every system has (tmux 3.6 would default to
	# tmux-256color, which CentOS 7 lacks, and the inner client would refuse to start).
	printf 'set -g default-terminal screen-256color\n' >"$W/outer.conf"
	to -f "$W/outer.conf" new-session -d -s o -x "$1" -y 24 \
		"unset TMUX; exec '$TB' -u -L $IN attach -t demo" >>"$W/err" 2>&1
	to set -g status off >/dev/null 2>&1
	to set -gw utf8 on >/dev/null 2>&1 # tmux 1.x only
	# Wait for the client to draw (a slow container can take seconds).
	n=0
	while [ $n -lt 30 ] && [ -z "$(bar | tr -d ' ')" ]; do
		sleep 0.5
		n=$((n + 1))
	done
	settle
}
# Old tmux runs if-shell in the background and #() jobs always are: give them a moment.
settle() {
	sleep 1
	ti refresh-client -S >/dev/null 2>&1
	sleep "${1:-1}"
}
bar() { to capture-pane -p -t o | sed -n '1p'; }
row2() { to capture-pane -p -t o | sed -n '2p'; }
width() { printf '%s\n' "$1" | LC_ALL=C awk '{ t = $0; n = length(t); n -= gsub(/[\200-\277]/, "", t); print n }'; }
# For messages: the line without its icons, runs of spaces squeezed.
show() { printf '%s' "$1" | LC_ALL=C tr -d '\200-\377' | sed 's/  */ /g'; }

for ICONS in ascii nerd; do
	start 80
	b=$(bar)
	if [ -s "$W/err" ]; then
		result "bar-loads-$ICONS" FAIL "$TV: $(head -c 300 "$W/err" | tr '\n' ' ')"
	else
		result "bar-loads-$ICONS" PASS "$TV, no errors"
	fi
	miss=
	for want in demo code server notes; do
		case $b in *"$want"*) ;; *) miss="$miss $want" ;; esac
	done
	printf '%s' "$b" | grep -q '[0-9][0-9]:[0-9][0-9]' || miss="$miss time"
	if [ -z "$miss" ] && [ "$(width "$b")" -le 80 ]; then
		result "bar-80-columns-$ICONS" PASS "$(width "$b") columns:$(show "$b")"
	else
		result "bar-80-columns-$ICONS" FAIL "missing:$miss in '$b'"
	fi
	if [ "$ICONS" = ascii ]; then
		drawn=$b
		if at_least 2.9; then
			drawn="$drawn$(ti display-message -p '#{T:status-left}#{T:status-right}#{T:window-status-format}#{T:window-status-current-format}#{T:pane-border-format}' 2>/dev/null)"
		fi
		if [ -z "$b" ]; then
			result bar-ascii-plain FAIL "nothing drawn"
		elif printf '%s' "$drawn" | has_pua; then
			result bar-ascii-plain FAIL "private-use glyphs in ascii mode: $b"
		else
			result bar-ascii-plain PASS "no private-use code point in the bar or its formats"
		fi
	elif at_least 3.0; then
		if printf '%s' "$b" | LC_ALL=C grep -q "$(printf '\356\202\266')"; then
			result bar-nerd-tiles PASS "rounded tile ends drawn"
		else
			result bar-nerd-tiles FAIL "no rounded tile ends: $b"
		fi
	fi
done

# Pane titles: over each pane when a window has two, none with one (tmux 2.6+).
if at_least 2.6; then
	ICONS=ascii
	start 80
	one=$(row2)
	ti split-window -h -t demo:1 >/dev/null 2>&1
	settle 0
	two=$(row2)
	ti resize-pane -Z -t demo:1 >/dev/null 2>&1
	settle 0
	zoomed=$(row2)
	case $one in *─*) r1=line ;; *) r1=none ;; esac
	case $two in *" 1 "*" 2 "*) r2=titles ;; *) r2=none ;; esac
	case $zoomed in *─*) rz=line ;; *) rz=none ;; esac
	if [ "$r1" = none ] && [ "$r2" = titles ] && [ "$rz" = none ]; then
		result bar-pane-titles PASS "one pane: none; two: '$(printf '%s' "$two" | sed 's/[─ ]\{2,\}/ /g')'; zoomed: none"
	else
		result bar-pane-titles FAIL "one pane: '$one'; two panes: '$two'; zoomed: '$zoomed'"
	fi
fi

# The mode tile (tmux 3.0+): typed prefix, copy mode, a zoomed pane, a search.
if at_least 3.0; then
	ICONS=nerd
	start 100
	modes=
	ti switch-client -T prefix >/dev/null 2>&1
	settle 0
	case $(bar) in *PREFIX*) modes="$modes PREFIX" ;; esac
	ti switch-client -T root >/dev/null 2>&1
	ti send-keys -t demo:1 'echo rihla-marker' Enter >/dev/null 2>&1
	sleep 0.5
	ti copy-mode -t demo:1 >/dev/null 2>&1
	settle 0
	case $(bar) in *COPY*) modes="$modes COPY" ;; esac
	want=" PREFIX COPY"
	if at_least 3.2; then
		ti send-keys -t demo:1 -X search-backward 'marker' >/dev/null 2>&1
		settle 0
		case $(bar) in *SEARCH*) modes="$modes SEARCH" ;; esac
		want="$want SEARCH"
	fi
	ti send-keys -t demo:1 -X cancel >/dev/null 2>&1
	ti split-window -t demo:1 >/dev/null 2>&1
	ti resize-pane -Z -t demo:1 >/dev/null 2>&1
	settle 0
	case $(bar) in *ZOOM*) modes="$modes ZOOM" ;; esac
	want="$want ZOOM"
	if [ "$modes" = "$want" ]; then
		result bar-modes PASS "mode tile showed$modes"
	else
		result bar-modes FAIL "wanted$want, saw$modes; last bar: $(show "$(bar)")"
	fi
	# A window named after its program keeps that name in copy mode (not "[tmux]").
	ti new-window -d -t demo:9 >/dev/null 2>&1
	sleep 0.5
	ti copy-mode -t demo:9 >/dev/null 2>&1
	settle 0
	wn=$(ti display-message -p -t demo:9 '#W' 2>/dev/null)
	case $wn in '' | *'[tmux]'*) result bar-copy-name FAIL "window name in copy mode: '$wn'" ;;
	*) result bar-copy-name PASS "window name in copy mode: '$wn'" ;;
	esac
	# tmux 3.7 draws a prompt only as wide as its text: rihla's message-format clears the
	# rest of the line and puts the mode tile in front (typed through the client, as a user).
	if at_least 3.7; then
		ti kill-window -t demo:9 >/dev/null 2>&1
		ti select-window -t demo:1 >/dev/null 2>&1
		to send-keys -t o C-Space '[' >/dev/null 2>&1
		sleep 0.3
		to send-keys -t o '?' >/dev/null 2>&1
		sleep 0.3
		to send-keys -t o r i >/dev/null 2>&1
		sleep 0.5
		p=$(bar)
		to send-keys -t o C-c q >/dev/null 2>&1
		case $p in *SEARCH*"(search up) ri"*)
			if printf '%s' "$p" | grep -q '[0-9][0-9]:[0-9][0-9]\|demo'; then
				result bar-prompt FAIL "the bar shows through the prompt: $(show "$p")"
			else
				result bar-prompt PASS "$(show "$p")"
			fi ;;
		*) result bar-prompt FAIL "no SEARCH tile and prompt: $(show "$p")" ;;
		esac
	fi

	# Wide: every segment. Narrow (3.2+): the date and git step aside, the time stays.
	start 170
	settle 2
	wide=$(bar)
	day=$(LC_ALL=C date +%a)
	miss=
	case $wide in *"$day "*) ;; *) miss="$miss date" ;; esac
	case $wide in *"~/repo"* | *"/repo"*) ;; *) [ -n "$GIT" ] && miss="$miss directory" ;; esac
	if [ -n "$GIT" ]; then
		case $wide in *"main +1 !1 ?1"*) ;; *) miss="$miss git" ;; esac
	fi
	if [ -z "$miss" ]; then
		result bar-wide PASS "$(show "$wide")"
	else
		result bar-wide FAIL "missing:$miss in '$wide'"
	fi
	if at_least 3.2; then
		start 80
		narrow=$(bar)
		if ! printf '%s' "$narrow" | grep -q '[0-9][0-9]:[0-9][0-9]'; then
			result bar-narrow FAIL "no time at 80 columns: '$narrow'"
		else
			# In a repository git takes the place of the key hint; the date stays out.
			bad=
			case $narrow in *"$day "*) bad="$bad date" ;; esac
			if [ -n "$GIT" ]; then
				case $narrow in *"main +1"*) ;; *) bad="$bad no-git" ;; esac
				case $narrow in *"Ctrl-Space"*) bad="$bad key-hint" ;; esac
			fi
			if [ -z "$bad" ]; then
				result bar-narrow PASS "80 columns: time${GIT:+, git (in place of the key hint)}, no date:$(show "$narrow")"
			else
				result bar-narrow FAIL "at 80 columns:$bad in '$narrow'"
			fi
		fi
	fi
fi

# The git segment script itself.
GS=$SRC/tmux/bin/git-status
out=$(sh "$GS" "$W/home" ascii)
if [ -z "$out" ]; then
	result git-segment-outside PASS "prints nothing outside a repository"
else
	result git-segment-outside FAIL "printed '$out' outside a repository"
fi
# Milliseconds for N runs, with python when there is one, else whole seconds.
ms() { # ms N COMMAND...
	n=$1
	shift
	if command -v python3 >/dev/null 2>&1; then
		python3 -c 'import subprocess, sys, time
n = int(sys.argv[1]); t = time.time()
for _ in range(n): subprocess.run(sys.argv[2:], stdout=subprocess.DEVNULL)
print(int((time.time() - t) * 1000 / n))' "$n" "$@"
	else
		s=$(date +%s)
		i=0
		while [ $i -lt "$n" ]; do "$@" >/dev/null; i=$((i + 1)); done
		# Whole seconds only: report the ceiling, so a pass is never flattering.
		echo $((($(date +%s) - s + 1) * 1000 / n))
	fi
}
if command -v python3 >/dev/null 2>&1; then UNIT=ms; else UNIT="ms or less (no python3: timed in whole seconds)"; fi
t_out=$(ms 100 sh "$GS" "$W/home" ascii)
if [ -n "$GIT" ]; then
	out=$(sh "$GS" "$REPO" ascii x x x x x)
	t_in=$(ms 100 sh "$GS" "$REPO" ascii)
	case $out in *main*"+1"*"!1"*"?1"*) ok=1 ;; *) ok= ;; esac
	if [ -n "$ok" ] && [ "$t_in" -lt 50 ] && [ "$t_out" -lt 50 ]; then
		result git-segment PASS "in a repo: '$(printf '%s' "$out" | sed 's/#\[[^]]*\]//g')' in $t_in $UNIT; outside: $t_out $UNIT"
	else
		result git-segment FAIL "output '$out', $t_in ms in a repo, $t_out ms outside (limit 50)"
	fi
else
	if [ "$t_out" -lt 50 ]; then
		result git-segment PASS "no git here; outside a repository $t_out $UNIT"
	else
		result git-segment FAIL "$t_out ms outside a repository (limit 50)"
	fi
fi

# The cheat sheet (prefix + H) is wrapped to the popup at word boundaries: no line wider
# than the popup, no word cut in two (every word drawn is a word of the Markdown).
for c in 76 60; do
	RIHLA_CHEAT_COLS=$c RIHLA_HOME=$SRC sh "$SRC/tmux/bin/cheat" </dev/null 2>/dev/null |
		sed "s/$(printf '\033')\[[0-9;]*m//g" >"$W/cheat.$c"
done
sed 's/`//g; s/\*\*//g; s/\\|/|/g' "$SRC/docs/cheatsheet-tmux.md" | tr -s ' |\t' '\n\n\n' | { cat; echo '|'; } | LC_ALL=C sort -u >"$W/cheat.words"
bad=
for c in 76 60; do
	long=$(LC_ALL=C awk -v c="$c" '{ t = $0; n = length(t) - gsub(/[\200-\277]/, "", t); if (n > c - 1) k++ } END { print k + 0 }' "$W/cheat.$c")
	[ "$long" = 0 ] || bad="$bad $long line(s) wider than $c columns;"
	cut=$(sed 1d "$W/cheat.$c" | tr -s ' ' '\n' | grep -v '^$' | grep -v "$(printf '\342\224\200')" | LC_ALL=C sort -u | LC_ALL=C comm -23 - "$W/cheat.words" | head -n 3 | tr '\n' ' ')
	[ -z "$cut" ] || bad="$bad at $c columns words not in the sheet: $cut;"
	[ -s "$W/cheat.$c" ] || bad="$bad nothing drawn at $c;"
done
if [ -z "$bad" ]; then
	result cheat-wrap PASS "drawn for 76 and 60 columns: $(wc -l <"$W/cheat.60" | tr -d ' ') lines at 60, no word cut"
else
	result cheat-wrap FAIL "$bad"
fi

echo "== bar: $FAILS failed check(s) ($TV)"
[ "$FAILS" -eq 0 ]
