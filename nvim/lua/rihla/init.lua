-- rihla: load order. Each step is guarded, so one failure is reported in one
-- line (full trace in :Rihla log) and the rest of the editor still works.
local M = {}

function M.setup()
  local util = require("rihla.util")
  vim.g.rihla_root = util.root
  vim.g.rihla_start = vim.g.rihla_start or (vim.uv or vim.loop).hrtime()

  -- Defaults the user may override in ~/.config/rihla/local.lua.
  local defaults = {
    rihla_auto_install = true, -- install missing language tools via mason when a file type is first opened
    rihla_format_on_save = false, -- off: reformatting whole files in a shared work repo surprises people
    rihla_habits = "hint", -- off | hint | strict  (<leader>th cycles)
    rihla_dashboard = true,
  }
  for k, v in pairs(defaults) do
    if vim.g[k] == nil then
      vim.g[k] = v
    end
  end

  -- An early hook, for settings that must exist before plugins load
  -- (for example vim.g.rihla_auto_install = false).
  local early = util.user_dir .. "/init.lua"
  if vim.fn.filereadable(early) == 1 then
    util.safe("~/.config/rihla/init.lua", dofile, early)
  end

  util.safe("icons", require, "rihla.icons")
  util.safe("options", require, "rihla.options")
  util.safe("keymaps", require, "rihla.keymaps")
  util.safe("autocmds", require, "rihla.autocmds")
  util.safe("conflicts", function()
    require("rihla.conflict").setup()
  end)
  util.safe("commands", function()
    require("rihla.commands").setup()
  end)
  util.safe("plugins", function()
    require("rihla.lazy").setup()
  end)
  util.safe("languages", function()
    require("rihla.lang").setup()
  end)
  util.safe("learning", function()
    require("rihla.learn").setup()
  end)
  util.safe("habits", function()
    require("rihla.habits").setup()
  end)
  util.safe("dashboard", function()
    require("rihla.dashboard").setup()
  end)

  -- The user's own settings load last, so they win.
  local loc = util.user_dir .. "/local.lua"
  if vim.fn.filereadable(loc) == 1 then
    util.safe("~/.config/rihla/local.lua", dofile, loc)
  end
end

return M
