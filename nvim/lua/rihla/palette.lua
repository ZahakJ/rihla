-- The shared rihla palette: Catppuccin Mocha with mauve as the accent.
--
-- The values live in one file, <rihla>/tmux/palette.conf, which tmux sources and this
-- module parses, so the tmux bar and the editor's status line cannot drift apart
-- (test/palette.sh compares what each of them ends up drawing with). Lines look like
--   set -g @rihla_mauve "#cba6f7"
--   set -g @rihla_mode_normal "#{@rihla_mauve}"
-- The status line and dashboard are drawn from these directly rather than through a
-- theme plugin, because theme plugins rename options between versions.
local root = require("rihla.util").root

local M = {}

local raw = {}
local f = io.open(root .. "/tmux/palette.conf", "r")
if f then
  for line in f:lines() do
    local name, value = line:match('^set %-g @rihla_([%w_]+) "([^"]+)"')
    if name then
      raw[name] = value
    end
  end
  f:close()
end

local function resolve(v, depth)
  local ref = v:match("^#{@rihla_([%w_]+)}$")
  if ref and depth < 5 then
    return raw[ref] and resolve(raw[ref], depth + 1) or nil
  end
  return v:match("^#%x%x%x%x%x%x$") and v or nil
end

for name, v in pairs(raw) do
  local hex = resolve(v, 0)
  if hex then
    M[name] = hex
  end
end

-- Without the file (a copied nvim/ directory on its own) fall back to the colour
-- scheme's own Mocha palette, so the editor still draws in the same colours.
if not M.mauve then
  local ok, cp = pcall(function()
    return require("catppuccin.palettes").get_palette("mocha")
  end)
  cp = ok and cp or {}
  local map = {
    base = "base", mantle = "mantle", crust = "crust", surface0 = "surface0", surface1 = "surface1",
    surface2 = "surface2", overlay = "overlay0", subtext = "subtext0", text = "text", mauve = "mauve",
    blue = "blue", red = "red", green = "green", yellow = "yellow", peach = "peach", teal = "teal", pink = "pink",
    rosewater = "rosewater",
  }
  for k, v in pairs(map) do
    M[k] = cp[v]
  end
  M.mode_normal, M.mode_insert, M.mode_visual = M.mauve, M.green, M.blue
  M.mode_replace, M.mode_command, M.mode_terminal = M.red, M.peach, M.teal
  M.mode_search, M.mode_zoom = M.yellow, M.teal
end

return M
