#!/bin/sh
# Ctrl-h/j/k/l across tmux panes and nvim splits, driven like a user would.
#
#   sh test/nav.sh [TMUX_BINARY]
#
# Starts tmux with the installed ~/.tmux.conf on a private socket: a shell pane on the
# left, nvim on the right with three splits (top-left, bottom-left, right). A real tmux
# client is attached through `script` (a pty), and the keys are typed into that client,
# so they go through tmux's key tables exactly as from a keyboard. After each key the
# active tmux pane and nvim's current window are compared with what should happen.
# Prints "RESULT ..." lines like test/assert.sh; exits non-zero on failure.

set -u
TB=${1:-tmux}
SOCK=rihla-nav-$$
W=$(mktemp -d "${TMPDIR:-/tmp}/rihla-nav.XXXXXX")
FAILS=0
t() { "$TB" -L "$SOCK" "$@"; }
result() {
	printf 'RESULT %s %s %s\n' "$1" "$2" "${3:-}"
	[ "$2" = PASS ] || FAILS=$((FAILS + 1))
}
cleanup() {
	t kill-server >/dev/null 2>&1
	[ -n "${HOLD:-}" ] && kill "$HOLD" 2>/dev/null
	[ -n "${CLIENT:-}" ] && kill "$CLIENT" 2>/dev/null
	rm -rf "$W"
}
trap cleanup EXIT

if ! command -v script >/dev/null 2>&1; then
	result tmux-nvim-nav FAIL "no 'script' command to attach a tmux client in a pty"
	exit 1
fi

# wait_for DESCRIPTION COMMAND...: poll up to 10 s.
wait_for() {
	n=0
	while [ $n -lt 100 ]; do
		"$@" && return 0
		n=$((n + 1))
		sleep 0.1
	done
	return 1
}
nv() { nvim --server "$W/nvim.sock" --remote-expr "$1" 2>/dev/null; }
pane() { t display-message -p -t nav '#{pane_index}' 2>/dev/null; }
state() { echo "pane $(pane) win $(nv 'winnr()')"; }
# is_state PATTERN: shell pattern, e.g. "pane 2 win [12]".
is_state() {
	# shellcheck disable=SC2254
	case $(state) in $1) return 0 ;; esac
	return 1
}

printf 'left\n' >"$W/a.txt"
printf 'right\n' >"$W/b.txt"
t -f "$HOME/.tmux.conf" new-session -d -s nav -x 160 -y 40 || {
	result tmux-nvim-nav FAIL "tmux did not start"
	exit 1
}
t split-window -h -t nav "exec nvim --listen '$W/nvim.sock' -O '$W/a.txt' '$W/b.txt' -c split"
wait_for test -S "$W/nvim.sock"
# -O a b -c split: top-left (1), bottom-left (2, current: rihla sets splitbelow), right (3).
wait_for is_state "pane 2 win 2" || {
	result tmux-nvim-nav FAIL "nvim did not come up: $(state)"
	exit 1
}

# A client in a pty, reading what we type from a fifo.
mkfifo "$W/in"
sleep 600 >"$W/in" &
HOLD=$!
attach="stty rows 40 cols 160 2>/dev/null; exec '$TB' -L '$SOCK' attach -t nav"
if [ "$(uname -s)" = Linux ]; then
	TERM=xterm-256color script -qfc "$attach" /dev/null <"$W/in" >/dev/null 2>&1 &
elif command -v python3 >/dev/null 2>&1; then
	# macOS: BSD script refuses a stdin that is not a terminal (tcgetattr fails on the
	# fifo), so python's pty module makes the pty instead.
	TERM=xterm-256color python3 -c 'import pty, sys; pty.spawn(["sh", "-c", sys.argv[1]])' \
		"$attach" <"$W/in" >/dev/null 2>&1 &
else # BSD script
	TERM=xterm-256color script -q /dev/null sh -c "$attach" <"$W/in" >/dev/null 2>&1 &
fi
CLIENT=$!
has_client() { [ -n "$(t list-clients 2>/dev/null)" ]; }
wait_for has_client || {
	result tmux-nvim-nav FAIL "no tmux client attached"
	exit 1
}
sleep 0.5

# step KEY-BYTE NAME EXPECTED-STATE
steps=0
step() {
	printf "$1" >"$W/in"
	if wait_for is_state "$3"; then
		steps=$((steps + 1))
	else
		result "nav-$2" FAIL "expected '$3', got '$(state)'"
	fi
}
# C-j=\012 C-k=\013 C-l=\014 C-h=\010
step '\013' "C-k inside nvim (bottom -> top split)" "pane 2 win 1"
step '\012' "C-j inside nvim (top -> bottom split)" "pane 2 win 2"
step '\014' "C-l inside nvim (left -> right split)" "pane 2 win 3"
step '\010' "C-h inside nvim (right -> left split)" "pane 2 win [12]"
step '\010' "C-h at nvim's left edge (-> tmux shell pane)" "pane 1 win [12]"
step '\014' "C-l from the shell pane (-> nvim pane)" "pane 2 win [12]"
if [ $steps -eq 6 ]; then
	result tmux-nvim-nav PASS "$("$TB" -V): C-j C-k C-l C-h inside nvim, C-h nvim->tmux pane, C-l tmux pane->nvim"
else
	result tmux-nvim-nav FAIL "$steps of 6 moves right"
fi
[ "$FAILS" -eq 0 ]
