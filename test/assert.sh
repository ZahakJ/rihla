#!/bin/sh
# Headless end-to-end check, run as an ordinary user (no root, no sudo) on a machine or in a
# container. test/run.sh calls it inside docker; CI calls it directly on macOS.
#
#   sh test/assert.sh [--offline BUNDLE]
#
# Uses the current $HOME, which should be a throwaway one. Steps: plant a pre-existing
# config, snapshot $HOME, install from the checkout this file lives in, assert, re-run the
# installer (must be a no-op), uninstall, and compare $HOME with the snapshot.
# Prints "RESULT <check> PASS|FAIL [detail]" lines and exits non-zero on any FAIL.

set -u
SRC=$(cd "$(dirname "$0")/.." && pwd -P)
OFFLINE=
[ "${1:-}" = --offline ] && OFFLINE=$2
WORK=$(mktemp -d "${TMPDIR:-/tmp}/rihla-test.XXXXXX")
FAILS=0
SOCK=rihla-test-$$

result() { # result NAME PASS|FAIL [DETAIL]
	printf 'RESULT %s %s %s\n' "$1" "$2" "${3:-}"
	[ "$2" = PASS ] || FAILS=$((FAILS + 1))
}
check() { # check NAME DETAIL COMMAND...
	n=$1 d=$2
	shift 2
	if "$@"; then result "$n" PASS "$d"; else result "$n" FAIL "$d"; fi
}

# File listing of $HOME with types, link targets, modes and checksums.
snapshot() { # snapshot [all]
	all=${1:-}
	(cd "$HOME" && find . -print 2>/dev/null) | LC_ALL=C sort | while IFS= read -r f; do
		[ "$f" = . ] && continue
		case $f in ./.cache/rihla-test* | ./.local/state/nvim | ./.local/state/nvim/* | ./.cache/nvim | ./.cache/nvim/*)
			[ -n "$all" ] || continue ;;
		# Shell history the test's own shells wrote: the user's data, kept by uninstall.
		./.bash_history | ./.zsh_history) continue ;;
		esac
		p=$HOME/${f#./}
		m=$(ls -ld "$p" | cut -c1-10)
		if [ -h "$p" ]; then
			echo "L $m $f -> $(readlink "$p")"
		elif [ -d "$p" ]; then
			echo "D $m $f"
		else
			echo "F $m $f $(cksum <"$p")"
		fi
	done
}

echo "== system: $(uname -sm), user $(id -un 2>/dev/null || id -u), HOME=$HOME"
for t in git tmux curl wget ps python3 cc; do
	if command -v "$t" >/dev/null 2>&1; then
		echo "== system $t: $("$t" --version 2>/dev/null | head -n 1)$([ "$t" = tmux ] && tmux -V)"
	else
		echo "== system $t: none"
	fi
done
SYS_TMUX=$(command -v tmux 2>/dev/null)

# ------------------------------------------------------------------ pre-existing config
mkdir -p "$HOME/.config/nvim" "$HOME/.local/share/nvim/site" "$HOME/.config/tmux"
printf -- '-- my old init.lua\nvim.o.number = true\n' >"$HOME/.config/nvim/init.lua"
printf 'old plugin data\n' >"$HOME/.local/share/nvim/site/marker"
printf 'set -g prefix C-a\n' >"$HOME/.tmux.conf"
printf 'set -g mouse off\n' >"$HOME/.config/tmux/tmux.conf"
# An rc file without a final newline: uninstall must restore it byte for byte.
printf 'export EDITOR=vi' >"$HOME/.bashrc"
# On macOS terminals start login shells, so a bash user's settings are in .bash_profile
# (where `rihla shell` puts its line there).
[ "$(uname -s)" = Darwin ] && printf '# my bash_profile\nexport EDITOR=vi' >"$HOME/.bash_profile"
# The same for zsh, when there is one (the shell layer writes its line there).
command -v zsh >/dev/null 2>&1 && printf '# my zshrc\nexport EDITOR=vi' >"$HOME/.zshrc"
printf '# user override\n' >"$HOME/.rihla-keep" # unrelated file that must survive
snapshot all >"$WORK/before"

# ------------------------------------------------------------------ install
export SHELL=/bin/bash
if [ -n "$OFFLINE" ]; then
	(cd "$WORK" && gzip -dc "$OFFLINE" | tar -xf - rihla-bundle/rihla/install.sh)
	sh "$WORK/rihla-bundle/rihla/install.sh" --offline "$OFFLINE" >"$WORK/install1.log" 2>&1
else
	sh "$SRC/install.sh" >"$WORK/install1.log" 2>&1
fi
rc=$?
cat "$WORK/install1.log"
check install "exit $rc" [ "$rc" -eq 0 ]
# The bundle carries the shell layer whole: its scripts, the fish layer, every pinned tool.
if [ -n "$OFFLINE" ]; then
	gzip -dc "$OFFLINE" | tar -tf - >"$WORK/bundle.list" 2>/dev/null
	miss=
	for f in rihla/shell/zsh.rc rihla/shell/bash.rc rihla/shell/fish/rihla.fish rihla/shell/bin/rgi \
		rihla/shell/bin/ff rihla/shell/bin/preview rihla/shell/ripgreprc rihla/shell/fdignore; do
		grep -q "^rihla-bundle/$f\$" "$WORK/bundle.list" || miss="$miss $f"
	done
	for t in starship zoxide ble- fish-; do
		grep -q "^rihla-bundle/downloads/.*$t" "$WORK/bundle.list" || miss="$miss downloads/*$t*"
	done
	check bundle-shell-files "shell scripts, fish layer and shell tools in the bundle${miss:+; missing:$miss}" [ -z "$miss" ]
fi

PATH=$HOME/.local/bin:$PATH
export PATH
RH=$HOME/.local/share/rihla

# ------------------------------------------------------------------ nvim
NV=$(nvim --version 2>/dev/null | head -n 1)
PIN=$(awk '$1 == "asset" && $2 == "nvim" { print $3; exit }' "$SRC/lib/manifest")
NVBUILD=$(sed -n 's/^exec "\(.*\)" "\$@"$/\1/p' "$HOME/.local/bin/nvim" 2>/dev/null)
NVBUILD=$(readlink "$NVBUILD" 2>/dev/null || echo "$NVBUILD")
NVSHA=$(cat "${NVBUILD%/bin/nvim}/../.rihla-sha256" 2>/dev/null | cut -c1-12)
NVURL=$(awk -v s="$NVSHA" '$1 == "asset" && $2 == "nvim" && index($8, s) == 1 { print $9 }' "$SRC/lib/manifest")
check nvim-pinned "$NV from ${NVURL:-?} (sha ${NVSHA:-?})" [ "$NV" = "NVIM v$PIN" ]
for t in rg fd fzf lazygit tmux git; do
	p=$(command -v "$t" 2>/dev/null) || { echo "== tool $t: none"; continue; }
	case $(readlink "$p" 2>/dev/null) in *rihla-tools*) w=rihla ;; *) w=system ;; esac
	echo "== tool $t: $w $p"
done
grep -h 'mode)' "$WORK/install1.log" | tail -n 1 | sed 's/^ */== plugins: /'

nvim --headless "+qa" >"$WORK/start.out" 2>&1
rc=$?
if grep -Eiq 'E[0-9]+:|error|stack traceback' "$WORK/start.out" || [ $rc -ne 0 ]; then
	result nvim-starts-clean FAIL "exit $rc: $(head -c 400 "$WORK/start.out" | tr '\n' ' ')"
else
	result nvim-starts-clean PASS "$(wc -c <"$WORK/start.out" | tr -d ' ') bytes of output"
fi

out=$(RIHLA_PROVISION=check RIHLA_PROVISION_OUT="$WORK/check.tsv" RIHLA_PROVISION_LUA="$RH/lib/provision.lua" \
	nvim --headless -i NONE --cmd 'lua dofile(vim.env.RIHLA_PROVISION_LUA)' 2>&1)
rc=$?
check plugins-at-lock "$(grep -c '^ok' "$WORK/check.tsv" 2>/dev/null) ok, $(grep -c '^FAIL' "$WORK/check.tsv" 2>/dev/null) failed" [ $rc -eq 0 ]
[ $rc -eq 0 ] || { grep '^FAIL' "$WORK/check.tsv"; echo "$out" | tail -n 20; }

# Every lockfile entry is installed, or switched off here by its `cond` (reported as skip).
missing=
skipped=
total=0
for name in $(sed -n 's/^[[:space:]]*"\([^"]*\)": *{.*/\1/p' "$RH/nvim/lazy-lock.json"); do
	total=$((total + 1))
	[ -d "$HOME/.local/share/nvim/lazy/$name" ] && continue
	if grep -q "^skip$(printf '\t')$name$(printf '\t')" "$WORK/check.tsv" 2>/dev/null; then
		skipped="$skipped $name"
	else
		missing="$missing $name"
	fi
done
check plugins-present "$total in lockfile${skipped:+, off by cond here:$skipped}${missing:+, missing:$missing}" [ -z "$missing" ] && [ "$total" -gt 0 ]

cs=$(nvim --headless "+lua io.stdout:write(vim.g.colors_name or 'none')" +qa 2>/dev/null)
case $cs in catppuccin*) result colorscheme PASS "$cs" ;; *) result colorscheme FAIL "got '$cs'" ;; esac

# ------------------------------------------------------------------ editor end to end
# The config's own headless tests (nvim/tests), run against the installed copy.
#   smoke: no startup errors, all plugins load, no Nerd Font glyph anywhere in ascii mode
#   keys:  every key the docs name exists;  find: the picker returns the right file / line
#   habits: the eight VS Code habits (find, grep, replace, terminal, view, tree, tabs, conflicts)
#   learn: a lesson is one window from every entry point, Space h h, copies, quitting, popups
#   lsp:   a server attaches to a real file and answers (languages: RIHLA_TEST_LSP)
ICONS=$(rihla icons 2>/dev/null)
NVT=$RH/nvim/tests/run.sh
for what in smoke keys find habits learn; do
	sh "$NVT" "$what" >"$WORK/nvt-$what.out" 2>&1
	rc=$?
	sed "s/^/   [$what] /" "$WORK/nvt-$what.out"
	n=$(grep -c '^PASS' "$WORK/nvt-$what.out")
	f=$(grep '^FAIL' "$WORK/nvt-$what.out" | head -n 3 | cut -c1-200 | tr '\n' ' ')
	check "nvim-$what" "$n checks passed${f:+; $f}" [ $rc -eq 0 ]
done
LSP_LANGS=${RIHLA_TEST_LSP-lua}
if [ -n "$OFFLINE" ] || [ -n "${RIHLA_TEST_OFFLINE:-}" ]; then
	echo "== lsp: skipped offline (servers are installed on first use, which needs the network)"
elif [ -n "$LSP_LANGS" ]; then
	RIHLA_LSP_LANGS=$LSP_LANGS RIHLA_LSP_TIMEOUT=${RIHLA_LSP_TIMEOUT:-600} sh "$NVT" lsp >"$WORK/nvt-lsp.out" 2>&1
	rc=$?
	sed 's/^/   [lsp] /' "$WORK/nvt-lsp.out"
	servers=$(sed -n 's/^PASS  \([a-z]*\): server attached  -- \(.*\)/\1=\2/p' "$WORK/nvt-lsp.out" | tr '\n' ' ')
	f=$(grep '^FAIL' "$WORK/nvt-lsp.out" | head -n 3 | cut -c1-200 | tr '\n' ' ')
	check nvim-lsp "attached: ${servers:-none}; diagnostics, completion, hover${f:+; $f}" [ $rc -eq 0 ]
fi

# ------------------------------------------------------------------ tmux
tmux_check() { # tmux_check LABEL BINARY
	label=$1 tb=$2
	tv=$("$tb" -V 2>/dev/null)
	"$tb" -L "$SOCK" kill-server >/dev/null 2>&1
	"$tb" -L "$SOCK" -f "$HOME/.tmux.conf" new-session -d -s t -x 120 -y 30 >"$WORK/tmux.out" 2>&1
	rc=$?
	# source-file from a client reports every parse or command error on stderr.
	"$tb" -L "$SOCK" source-file "$HOME/.tmux.conf" >>"$WORK/tmux.out" 2>&1 || rc=1
	prefix=$("$tb" -L "$SOCK" show-options -g prefix 2>/dev/null)
	# Old tmux runs if-shell asynchronously; give the version-gated parts a moment.
	sleep 1
	sl=$("$tb" -L "$SOCK" show-options -g status-left 2>/dev/null)
	# Themed: rihla's mode tile (3.0+), the PREFIX indicator (2.0+), or the legacy colours on 1.x.
	case $sl in
	*PREFIX* | *@rihla_mode_w*) ;;
	*) "$tb" -L "$SOCK" show-options -g status-bg 2>/dev/null | grep -q colour235 || rc=1 ;;
	esac
	if [ $rc -eq 0 ] && [ ! -s "$WORK/tmux.out" ] && [ "$prefix" = "prefix C-Space" ]; then
		result "tmux-config-$label" PASS "$tv, no errors, prefix C-Space, themed status-left"
	else
		result "tmux-config-$label" FAIL "$tv rc=$rc prefix='$prefix' status-left='$sl' $(head -c 300 "$WORK/tmux.out" | tr '\n' ' ')"
	fi
	# ascii icons: the drawn status bar has no Nerd Font / powerline glyphs (private-use
	# code points: U+E000-U+F8FF and planes 15-16).
	drawn=$("$tb" -L "$SOCK" display-message -p -t t '#{T:status-left}#{T:status-right}#{T:window-status-format}#{T:window-status-current-format}#{T:pane-border-format}' 2>/dev/null)
	if [ -n "$drawn" ] && [ "$ICONS" = ascii ]; then
		if printf '%s' "$drawn" | LC_ALL=C grep -q "$(printf '\356\\|\357[\200-\243]\\|\363[\260-\277]\\|\364[\200-\217]')"; then
			result "tmux-ascii-$label" FAIL "Nerd Font glyphs in the status bar in ascii mode"
		else
			result "tmux-ascii-$label" PASS "status bar drawn with plain characters only"
		fi
	fi
	if "$tb" -L "$SOCK" list-keys 2>/dev/null | grep -Eq '(-T root|-n) +C-h +if-shell'; then
		result "tmux-nav-keys-$label" PASS "C-h bound in root table"
	else
		result "tmux-nav-keys-$label" FAIL "no C-h binding"
	fi
	"$tb" -L "$SOCK" kill-server >/dev/null 2>&1
}
TMUX_BIN=$(command -v tmux 2>/dev/null)
if [ -n "$TMUX_BIN" ]; then
	src=system
	case $(readlink "$TMUX_BIN" 2>/dev/null) in *rihla-tools*) src=rihla ;; esac
	tmux_check "$src" "$TMUX_BIN"
else
	result tmux-config FAIL "no tmux on PATH"
fi
# Ctrl-h/j/k/l between tmux panes and nvim splits, typed into a real tmux client.
if [ -n "$TMUX_BIN" ]; then
	sh "$SRC/test/nav.sh" "$TMUX_BIN" >"$WORK/nav.out" 2>&1
	rc=$?
	cat "$WORK/nav.out"
	grep -q '^RESULT' "$WORK/nav.out" || result tmux-nvim-nav FAIL "nav.sh printed nothing (exit $rc)"
	FAILS=$((FAILS + $(grep -c '^RESULT [^ ]* FAIL' "$WORK/nav.out")))
fi
# The shell in tmux is the shell outside it; the shell layer (rihla shell) works.
if [ -n "$TMUX_BIN" ]; then
	# A watchdog: a terminal that never comes up must fail the run, not hang it.
	sh "$SRC/test/shell.sh" ${OFFLINE:+--offline} >"$WORK/shell.out" 2>&1 &
	spid=$!
	(
		n=0
		while kill -0 "$spid" 2>/dev/null; do
			n=$((n + 1))
			[ $n -gt 900 ] && kill "$spid" && echo "RESULT shell-tests FAIL killed after 900 s" >>"$WORK/shell.out" && break
			sleep 1
		done
	) &
	wait "$spid"
	rc=$?
	wait $! 2>/dev/null
	cat "$WORK/shell.out"
	grep -q '^RESULT' "$WORK/shell.out" || result shell-tests FAIL "shell.sh printed nothing (exit $rc)"
	FAILS=$((FAILS + $(grep -c '^RESULT [^ ]* FAIL' "$WORK/shell.out")))
fi
# The config must also load cleanly on an old system tmux that rihla replaced.
if [ -n "$SYS_TMUX" ] && [ "$SYS_TMUX" != "$TMUX_BIN" ]; then
	tmux_check system-old "$SYS_TMUX"
fi
# The bar as drawn: fits 80 columns, plain in ascii mode, mode tile, pane titles, git
# segment (test/bar.sh); one palette for tmux and Neovim (test/palette.sh).
run_sub() { # run_sub NAME COMMAND...
	n=$1
	shift
	"$@" >"$WORK/$n.out" 2>&1
	rc=$?
	cat "$WORK/$n.out"
	grep -q '^RESULT' "$WORK/$n.out" || result "$n" FAIL "printed nothing (exit $rc)"
	FAILS=$((FAILS + $(grep -c '^RESULT [^ ]* FAIL' "$WORK/$n.out")))
}
if [ -n "$TMUX_BIN" ]; then
	run_sub bar sh "$SRC/test/bar.sh" "$TMUX_BIN"
	run_sub palette sh "$SRC/test/palette.sh" "$TMUX_BIN"
fi
if [ -n "$SYS_TMUX" ] && [ "$SYS_TMUX" != "$TMUX_BIN" ]; then
	run_sub bar-old sh "$SRC/test/bar.sh" "$SYS_TMUX"
fi

# ------------------------------------------------------------------ check (dumb terminal)
TERM=dumb rihla check >"$WORK/check.out" 2>&1
cat "$WORK/check.out"
if grep -q "$(printf '\033')" "$WORK/check.out"; then
	result check-dumb-term FAIL "escape codes in output"
else
	result check-dumb-term PASS "$(grep -c '^\[FAIL\]' "$WORK/check.out") FAIL lines (informational)"
fi

# ------------------------------------------------------------------ re-run is a no-op
snapshot >"$WORK/after1"
if [ -n "$OFFLINE" ]; then
	sh "$WORK/rihla-bundle/rihla/install.sh" --offline "$OFFLINE" >"$WORK/install2.log" 2>&1
else
	sh "$SRC/install.sh" >"$WORK/install2.log" 2>&1
fi
rc=$?
snapshot >"$WORK/after2"
if [ $rc -eq 0 ] && grep -q 'Nothing to do' "$WORK/install2.log" && [ "$(cat "$WORK/after1")" = "$(cat "$WORK/after2")" ]; then
	result reinstall-noop PASS "says 'Nothing to do', home unchanged"
else
	result reinstall-noop FAIL "exit $rc"
	cat "$WORK/install2.log"
	grep -vxFf "$WORK/after2" "$WORK/after1" | head -n 20
	grep -vxFf "$WORK/after1" "$WORK/after2" | head -n 20
fi

# ------------------------------------------------------------------ uninstall restores
rihla uninstall >"$WORK/uninstall.log" 2>&1
rc=$?
cat "$WORK/uninstall.log"
snapshot all >"$WORK/after-uninstall"
if [ $rc -eq 0 ] && [ "$(cat "$WORK/before")" = "$(cat "$WORK/after-uninstall")" ]; then
	result uninstall-restores PASS "home identical to the pre-install snapshot ($(wc -l <"$WORK/before" | tr -d ' ') entries)"
else
	result uninstall-restores FAIL "exit $rc"
	# diff is missing from some minimal images; grep shows the same.
	echo "--- only before uninstall snapshot:"
	grep -vxFf "$WORK/after-uninstall" "$WORK/before" | head -n 30
	echo "--- only after:"
	grep -vxFf "$WORK/before" "$WORK/after-uninstall" | head -n 30
fi

rm -rf "$WORK"
echo "== $FAILS failed check(s)"
[ "$FAILS" -eq 0 ]
