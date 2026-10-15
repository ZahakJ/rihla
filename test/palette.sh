#!/bin/sh
# One palette for the tmux bar and the editor's status line: tmux/palette.conf.
#
#   sh test/palette.sh [TMUX_BINARY]
#
# Needs rihla installed for the current user (nvim and its plugins; test/assert.sh runs it
# after the install). Checks:
#   - tmux (3.0+) loads palette.conf and every @rihla_<name> resolves to the same #rrggbb
#     that Neovim's require("rihla.palette") holds, mode colours included;
#   - lualine's theme uses those mode colours for its mode tiles, exactly as the tmux bar
#     does (normal = the idle tmux tile, command = PREFIX, visual = COPY);
#   - the drawn tmux bar uses the normal-mode colour when idle;
#   - no colour is written anywhere else: no #rrggbb in tmux/*.conf besides palette.conf,
#     and every #rrggbb in nvim/lua, shell/ (prompt themes) and tools/art.py is one of
#     the palette's values.
# Prints "RESULT ..." lines like test/assert.sh; exits non-zero on failure.

set -u
SRC=$(cd "$(dirname "$0")/.." && pwd -P)
TB=${1:-tmux}
PAL=$SRC/tmux/palette.conf
W=$(mktemp -d "${TMPDIR:-/tmp}/rihla-pal.XXXXXX")
SOCK=rihla-pal-$$
FAILS=0
result() {
	printf 'RESULT %s %s %s\n' "$1" "$2" "${3:-}"
	[ "$2" = PASS ] || FAILS=$((FAILS + 1))
}
cleanup() {
	"$TB" -L "$SOCK" kill-server >/dev/null 2>&1
	rm -rf "$W"
}
trap cleanup EXIT

names=$(sed -n 's/^set -g @rihla_\([a-z0-9_]*\) ".*/\1/p' "$PAL")
values=$(sed -n 's/^set -g @rihla_[a-z0-9_]* "\(#[0-9a-fA-F]\{6\}\)".*/\1/p' "$PAL" | tr 'A-F' 'a-f' | sort -u)

# --- tmux: what the config resolves each name to.
major=$("$TB" -V 2>/dev/null | sed 's/^[^0-9]*\([0-9]*\).*/\1/')
if [ "${major:-0}" -ge 3 ]; then
	cat >"$W/tmux.conf" <<EOF
set-environment -g RIHLA_HOME '$SRC'
set-environment -g RIHLA_TMUX '$SRC/tmux'
source-file '$SRC/tmux/tmux.conf'
EOF
	env -i PATH="$PATH" HOME="$W" TERM=xterm-256color SHELL=/bin/sh "$TB" -L "$SOCK" -f "$W/tmux.conf" \
		new-session -d -s p -x 120 -y 20 >/dev/null 2>&1
	sleep 1
	: >"$W/tmux.txt"
	for n in $names; do
		printf '%s %s\n' "$n" "$("$TB" -L "$SOCK" display-message -p "#{E:@rihla_$n}" 2>/dev/null)" >>"$W/tmux.txt"
	done
	drawn=$("$TB" -L "$SOCK" display-message -p -t p '#{T:status-left}' 2>/dev/null)
	HAVE_TMUX=1
else
	echo "== palette: tmux older than 3.0 has no palette (its bar uses the 256-colour fallback)"
	HAVE_TMUX=
fi

# --- Neovim: the palette module and lualine's theme, as the running config has them.
cat >"$W/dump.lua" <<'EOF'
local out = {}
local p = require("rihla.palette")
for k, v in pairs(p) do
  out[#out + 1] = k .. " " .. v
end
local ok, sl = pcall(require, "rihla.statusline")
if ok then
  for _, m in ipairs({ "normal", "insert", "visual", "replace", "command", "terminal" }) do
    out[#out + 1] = "lualine_" .. m .. " " .. sl.theme[m].a.bg
  end
end
table.sort(out)
io.stdout:write(table.concat(out, "\n") .. "\n")
EOF
nvim --headless "+luafile $W/dump.lua" +qa >"$W/nvim.txt" 2>/dev/null
if ! grep -q '^mauve #' "$W/nvim.txt"; then
	result palette-nvim FAIL "Neovim did not report its palette: $(head -c 200 "$W/nvim.txt" | tr '\n' ' ')"
else
	bad=
	for n in $names; do
		nv=$(sed -n "s/^$n //p" "$W/nvim.txt")
		case $nv in '#'??????) ;; *) bad="$bad $n=nvim:'$nv'" ;; esac
		if [ -n "$HAVE_TMUX" ]; then
			tv=$(sed -n "s/^$n //p" "$W/tmux.txt")
			[ "$tv" = "$nv" ] || bad="$bad $n=tmux:$tv/nvim:$nv"
		fi
	done
	if [ -z "$bad" ]; then
		result palette-parity PASS "$(echo $names | wc -w | tr -d ' ') names, the same in $([ -n "$HAVE_TMUX" ] && echo "tmux and Neovim" || echo "Neovim (tmux before 3.0 has none)")"
	else
		result palette-parity FAIL "$bad"
	fi
	bad=
	for m in normal insert visual replace command terminal; do
		lv=$(sed -n "s/^lualine_$m //p" "$W/nvim.txt")
		pv=$(sed -n "s/^mode_$m //p" "$W/nvim.txt")
		[ -n "$lv" ] && [ "$lv" = "$pv" ] || bad="$bad $m=lualine:$lv/palette:$pv"
	done
	if [ -z "$bad" ]; then
		result palette-modes PASS "lualine's mode tiles use the palette's mode colours (normal $(sed -n 's/^mode_normal //p' "$W/nvim.txt"), command $(sed -n 's/^mode_command //p' "$W/nvim.txt"), visual $(sed -n 's/^mode_visual //p' "$W/nvim.txt"))"
	else
		result palette-modes FAIL "$bad"
	fi
	if [ -n "$HAVE_TMUX" ]; then
		mn=$(sed -n 's/^mode_normal //p' "$W/nvim.txt")
		case $drawn in *"bg=$mn"*) result palette-bar-idle PASS "idle tmux tile drawn in $mn, as NORMAL in Neovim" ;;
		*) result palette-bar-idle FAIL "idle status-left does not use $mn: $drawn" ;;
		esac
	fi
fi

# --- No colour written anywhere else.
stray=$(grep -lE '#[0-9a-fA-F]{6}\b' "$SRC"/tmux/*.conf | grep -v '/palette.conf$')
if [ -z "$stray" ]; then
	result palette-tmux-literals PASS "no #rrggbb in tmux/*.conf besides palette.conf"
else
	result palette-tmux-literals FAIL "colours written in: $stray"
fi
others=
for f in "$SRC"/nvim/lua/rihla/*.lua "$SRC"/nvim/lua/rihla/plugins/*.lua "$SRC"/shell/* "$SRC"/tools/art.py; do
	[ -f "$f" ] || continue
	for h in $(grep -oE '#[0-9a-fA-F]{6}\b' "$f" | tr 'A-F' 'a-f' | sort -u); do
		echo "$values" | grep -qx "$h" || others="$others ${f#"$SRC"/}:$h"
	done
done
if [ -z "$others" ]; then
	result palette-literals PASS "every colour in nvim/lua, shell/ and tools/art.py is a palette value"
else
	result palette-literals FAIL "not in tmux/palette.conf:$others"
fi

echo "== palette: $FAILS failed check(s)"
[ "$FAILS" -eq 0 ]
