-- The status line, built from the shared palette (no theme plugin involved).
--
-- It is drawn with the same tiles as the tmux bar above it (tmux/modern.conf), so the
-- two read as one design: on the left a mode tile joined to a raised tile (here the git
-- branch, in tmux the session), on the right a raised tile joined to a mode tile (here
-- the cursor position, in tmux the clock). Mode colours come from tmux/palette.conf:
-- normal mauve, insert green, visual blue (tmux copy mode), replace red, command peach
-- (tmux: after the prefix key), terminal teal. Between the tiles there is no background
-- of its own, as in tmux: the terminal's shows through.
local p = require("rihla.palette")
local icons = require("rihla.icons")

local M = {}

local function mode_theme(accent)
  return {
    a = { fg = p.crust, bg = accent, gui = "bold" },
    b = { fg = accent, bg = p.surface0 },
    c = { fg = p.subtext, bg = "NONE" },
  }
end

M.theme = {
  normal = mode_theme(p.mode_normal),
  insert = mode_theme(p.mode_insert),
  visual = mode_theme(p.mode_visual),
  replace = mode_theme(p.mode_replace),
  command = mode_theme(p.mode_command),
  terminal = mode_theme(p.mode_terminal),
  inactive = {
    a = { fg = p.overlay, bg = "NONE" },
    b = { fg = p.overlay, bg = "NONE" },
    c = { fg = p.overlay, bg = "NONE" },
  },
}

local function lsp_clients()
  local names = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
    names[#names + 1] = c.name
  end
  if #names == 0 then
    return ""
  end
  return icons.ui.lsp .. table.concat(names, ",")
end

local function fmt_on_save()
  local on = vim.b.rihla_format_on_save
  if on == nil then
    on = vim.g.rihla_format_on_save
  end
  return on and vim.trim(icons.ui.fmt) or ""
end

-- "recording @q" after an accidental q: say what it is and how to stop it.
local recording = ""
vim.api.nvim_create_autocmd({ "RecordingEnter", "RecordingLeave" }, {
  group = vim.api.nvim_create_augroup("rihla_recording", { clear = true }),
  callback = function(ev)
    recording = ev.event == "RecordingEnter" and vim.fn.reg_recording() or ""
    pcall(function()
      require("lualine").refresh({ place = { "statusline" } })
    end)
  end,
})
local function macro()
  if recording == "" then
    return ""
  end
  return ("recording a macro in @%s: press q to stop"):format(recording)
end

local function habits()
  local lvl = vim.g.rihla_habits
  return lvl == "strict" and "habits:strict" or ""
end

function M.config()
  local sep = icons.sep
  return {
    options = {
      theme = M.theme,
      globalstatus = true,
      icons_enabled = icons.nerd,
      -- No lines between items, as in the tmux bar: spacing and colour group them.
      component_separators = { left = "", right = "" },
      section_separators = { left = sep.right, right = sep.left },
      disabled_filetypes = { statusline = { "rihla-dashboard" } },
      -- In a popup (a picker, a menu) the line keeps describing the file under it,
      -- not "[No Name]" and the popup's internal file type.
      ignore_focus = function(win)
        return vim.api.nvim_win_get_config(win).relative ~= ""
      end,
    },
    sections = {
      lualine_a = {
        {
          "mode",
          separator = { left = sep.left, right = sep.right },
          fmt = function(s)
            return s:sub(1, 3) == "V-L" and "V-LINE" or s
          end,
        },
      },
      lualine_b = {
        -- Branch and change counts in the same colours as the tmux git segment.
        { "branch", icon = { vim.trim(icons.git.branch), color = { fg = p.peach } } },
        {
          "diff",
          symbols = { added = icons.git.added, modified = icons.git.modified, removed = icons.git.removed },
          diff_color = { added = { fg = p.green }, modified = { fg = p.yellow }, removed = { fg = p.red } },
          source = function()
            local g = vim.b.gitsigns_status_dict
            if g then
              return { added = g.added, modified = g.changed, removed = g.removed }
            end
          end,
        },
      },
      lualine_c = {
        { "filename", path = 1, symbols = { modified = icons.ui.modified, readonly = icons.ui.readonly, unnamed = "[No Name]" } },
        {
          "diagnostics",
          symbols = { error = icons.diag.ERROR, warn = icons.diag.WARN, info = icons.diag.INFO, hint = icons.diag.HINT },
          -- Not where they are switched off (a file with merge conflicts: its syntax
          -- errors are hidden until the last conflict is resolved).
          cond = function()
            return vim.diagnostic.is_enabled({ bufnr = 0 })
          end,
        },
      },
      lualine_x = {
        { macro, color = { fg = p.crust, bg = p.red, gui = "bold" } },
        { habits, color = { fg = p.peach } },
        { fmt_on_save, color = { fg = p.green } },
        -- Narrow windows (a tmux split) keep the file name whole: the server names and
        -- the file type go first.
        { lsp_clients, color = { fg = p.blue }, cond = function() return vim.o.columns >= 110 end },
        { "filetype", colored = icons.nerd, icon_only = false, cond = function() return vim.o.columns >= 70 end },
      },
      lualine_y = { { "progress" } },
      lualine_z = { { "location", separator = { left = sep.left, right = sep.right } } },
    },
    extensions = { "nvim-tree", "lazy", "quickfix", "toggleterm", "fugitive", "man", "mason", "nvim-dap-ui" },
  }
end

return M
