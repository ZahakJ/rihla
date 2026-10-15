-- Finding things: snacks.picker (folke/snacks.nvim), driving fd and ripgrep.
--
-- The search defaults are the shell's (docs/shell.md, "Defaults"): ripgrep reads
-- <rihla>/shell/ripgreprc and fd gets <rihla>/shell/fdignore, so hidden files are
-- searched, symlinks followed, .git and node_modules left out, in both places.
-- Without fd the file list comes from `rg --files`, without both from `find`.
-- Each fallback says so once.
local util = require("rihla.util")
local icons = require("rihla.icons")
local M = require("rihla.find")
local pick = M.pick

local function S()
  return require("snacks")
end

local spec = {
  "folke/snacks.nvim",
  -- Loads after the screen is drawn (startup time does not change); a key
  -- below loads it earlier when pressed first.
  event = "VeryLazy",
  init = function()
    -- The shell's ripgrep defaults, unless you set your own.
    if (vim.env.RIPGREP_CONFIG_PATH or "") == "" and vim.fn.filereadable(M.ripgreprc) == 1 then
      vim.env.RIPGREP_CONFIG_PATH = M.ripgreprc
    end
    -- vim.ui.select (code actions, prompts) uses the picker once it is loaded.
    local orig = vim.ui.select
    vim.ui.select = function(...)
      local ok = pcall(require("lazy").load, { plugins = { "snacks.nvim" } })
      if not ok or vim.ui.select == nil or vim.ui.select == M._select_stub then
        vim.ui.select = orig
      end
      return vim.ui.select(...)
    end
    M._select_stub = vim.ui.select
  end,
  keys = {
    { "<leader><leader>", function() require("rihla.cmdpalette").open() end, desc = "Command palette (actions + keys)" },
    { "<C-p>", function() M.files() end, desc = "Find file (VS Code Ctrl+P)" },
    { "<leader>ff", function() M.files() end, desc = "Find file by name (recent first)" },
    { "<leader>fg", function() M.grep() end, desc = "Grep text in project (regex, live)" },
    { "<C-S-f>", function() M.grep() end, desc = "Grep text in project (VS Code Ctrl+Shift+F)" },
    { "<leader>fG", function() M.grep_scoped() end, desc = "Grep in a folder / glob (asks where)" },
    { "<leader>fw", function() M.grep_word() end, mode = { "n", "x" }, desc = "Grep word under cursor / selection" },
    { "<leader>fb", pick("buffers", { title = "Open files" }), desc = "Open buffers (files)" },
    { "<leader>bb", pick("buffers", { title = "Open files" }), desc = "Pick an open buffer (VS Code Ctrl+Tab)" },
    { "<leader>fr", pick("recent", { title = "Recent files" }), desc = "Recent files" },
    { "<leader>fh", pick("help"), desc = "Help pages" },
    { "<leader>fk", pick("keymaps"), desc = "Keymaps (search by key or description)" },
    { "<leader>fc", pick("commands"), desc = "Commands (:...)" },
    { "<leader>f:", pick("command_history"), desc = "Command history" },
    { "<leader>f/", pick("lines", { title = "Lines in this file" }), desc = "Fuzzy search in this file" },
    { "<leader>fs", function() M.symbols() end, desc = "Symbols in this file (VS Code Ctrl+Shift+O)" },
    { "<leader>fS", pick("lsp_workspace_symbols"), desc = "Symbols in workspace (VS Code Ctrl+T)" },
    { "<leader>cs", function() M.symbols() end, desc = "Outline: symbols of this file, side panel" },
    { "<leader>fd", pick("diagnostics"), desc = "Diagnostics (problems panel)" },
    { "<leader>fR", pick("resume"), desc = "Resume last search" },
    { "<leader>fq", pick("qflist"), desc = "Quickfix list (picker)" },
    { "<leader>fm", pick("marks"), desc = "Marks" },
    { '<leader>f"', pick("registers"), desc = "Registers" },
    { "<leader>fj", pick("jumps"), desc = "Jump list" },
    { "<leader>ft", M.filetypes, desc = "Set file type" },
    { "<leader>fC", pick("colorschemes"), desc = "Colour schemes" },
    {
      "<leader>fu",
      function()
        S().picker.files({ cwd = util.user_dir, hidden = true, title = "Your rihla overrides", layout = M.layout(M.footer.files) })
      end,
      desc = "Your rihla overrides (~/.config/rihla)",
    },
    { "<leader>hk", pick("keymaps"), desc = "Search all keymaps" },
  },
  config = function()
    local cfg = {
      prompt = icons.ui.prompt,
      ui_select = true,
      layout = M.layout(M.footer.plain),
      matcher = { frecency = true, cwd_bonus = true },
      -- The title shows a flag only for what you switched away from the default
      -- (hidden files and symlinks are always on, as in the shell).
      toggles = { follow = false, hidden = false, ignored = "ignored", modified = false },
      formatters = { file = { filename_first = true, truncate = 80 } },
      win = {
        -- A preview inherits the editor window's options; the breadcrumb is not wanted there.
        preview = { wo = { winbar = "" } },
        input = {
          keys = {
            -- One Esc closes, as in VS Code (the default: first Esc to normal mode).
            ["<Esc>"] = { "close", mode = { "n", "i" } },
          },
        },
      },
      sources = {
        files = { args = M.fd_args(), hidden = true, follow = true },
        select = { layout = M.layout(M.footer.plain, { preview = false }) },
      },
    }
    if not icons.nerd then
      cfg.icons = M.ascii_icons()
    end
    require("snacks").setup({ picker = cfg })
    M.patch_snacks()
    if not icons.nerd then
      -- The busy spinner is Braille dots; ascii mode promises plain characters.
      local frames = { "-", "\\", "|", "/" }
      Snacks.util.spinner = function()
        return frames[math.floor((vim.uv or vim.loop).hrtime() / (1e6 * 120)) % #frames + 1]
      end
    end
    -- Count visits from now on, so "recent first" knows what you opened
    -- before the first search.
    vim.schedule(function()
      pcall(function()
        require("snacks.picker.core.frecency").setup()
      end)
    end)
  end,
}

return require("rihla.spec").wrap({ spec })
