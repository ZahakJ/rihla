#!/bin/sh
# Run the Neovim config's headless tests against the config installed for the
# current user (~/.config/nvim -> rihla/nvim).
#
#   nvim/tests/run.sh            smoke test in ascii and nerd icon modes
#   nvim/tests/run.sh smoke      the same
#   nvim/tests/run.sh keys       every key the docs name exists as a mapping
#   nvim/tests/run.sh find       fuzzy file and text search return the right results
#   nvim/tests/run.sh habits     the eight VS Code habits end to end (find, grep, replace,
#                                terminal, view, tree, tabs, merge conflicts)
#   nvim/tests/run.sh learn      lessons: one window from every entry point, Space h h,
#                                copies, quitting, popups that say how to close
#   nvim/tests/run.sh lsp        LSP end to end (installs servers; needs network once)
#   nvim/tests/run.sh dap        debugger end to end (debugpy, codelldb; needs a C compiler)
#   nvim/tests/run.sh all        all of them
#
# Environment: NVIM_BIN (binary, default nvim), RIHLA_LSP_LANGS (default lua,python),
# RIHLA_DAP_ADAPTERS (default debugpy,codelldb; gdb needs gdb 14+),
# RIHLA_LSP_TIMEOUT (seconds for installs, default 600). Exit status is non-zero if
# any check fails.
set -u
here=$(cd "$(dirname "$0")" && pwd)
nvim=${NVIM_BIN:-nvim}
what=${1:-smoke}
status=0

# coreutils timeout is missing on macOS; run without a limit there.
to() {
  if command -v timeout >/dev/null 2>&1; then timeout "$@"; else shift; "$@"; fi
}

smoke() {
  for icons in ascii nerd; do
    echo "== smoke ($icons icons)"
    RIHLA_ICONS=$icons
    export RIHLA_ICONS
    to 300 "$nvim" --headless "+luafile $here/smoke.lua" 2>/dev/null || status=1
  done
  unset RIHLA_ICONS
}

keys() {
  echo "== keys named in the docs"
  to 300 "$nvim" --headless "+luafile $here/keys.lua" 2>/dev/null || status=1
}

learn() {
  echo "== learning mode"
  to 300 "$nvim" --headless "+luafile $here/learn.lua" 2>/dev/null || status=1
}

find_() {
  echo "== fuzzy finding end to end"
  to 300 "$nvim" --headless "+luafile $here/find_e2e.lua" 2>/dev/null || status=1
}

habits() {
  echo "== the eight VS Code habits end to end"
  to 300 "$nvim" --headless "+luafile $here/habits_e2e.lua" 2>/dev/null || status=1
}

lsp() {
  echo "== lsp end to end (${RIHLA_LSP_LANGS:-lua,python})"
  to 1200 "$nvim" --headless "+luafile $here/lsp_e2e.lua" 2>/dev/null || status=1
}

dap() {
  echo "== debugger end to end (${RIHLA_DAP_ADAPTERS:-debugpy,codelldb})"
  to 1200 "$nvim" --headless "+luafile $here/dap_e2e.lua" 2>/dev/null || status=1
}

case $what in
  smoke) smoke ;;
  keys) keys ;;
  find) find_ ;;
  habits) habits ;;
  learn) learn ;;
  lsp) lsp ;;
  dap) dap ;;
  all) smoke; keys; find_; habits; learn; lsp; dap ;;
  *) echo "usage: $0 [smoke|keys|find|habits|learn|lsp|dap|all]" >&2; exit 2 ;;
esac
exit $status
