-- Completion: blink.cmp.
--
-- Sources for LSP, buffer words, paths and snippets are built in; snippets use
-- vim.snippet. The pure-Lua matcher is used: no download, no compiler.
--
-- Keys: Ctrl-n / Ctrl-p (or Up/Down) move, Enter or Ctrl-y accepts, Ctrl-e
-- closes, Ctrl-Space opens, Tab / Shift-Tab jump between snippet fields.
local icons = require("rihla.icons")

return require("rihla.spec").wrap({
  {
    "saghen/blink.cmp",
    event = { "InsertEnter", "CmdlineEnter" },
    dependencies = { "rafamadriz/friendly-snippets" },
    main = "blink.cmp",
    opts = {
      -- Not in grug-far's Search / Replace / Files Filter lines: a snippet popup over
      -- the replace panel is noise. vim.b.completion = false turns it off in any buffer.
      enabled = function()
        return vim.bo.filetype ~= "grug-far" and vim.bo.buftype ~= "prompt" and vim.b.completion ~= false
      end,
      keymap = {
        preset = "enter",
        ["<C-y>"] = { "select_and_accept", "fallback" },
      },
      appearance = {
        nerd_font_variant = "mono",
        kind_icons = icons.kinds, -- nil in nerd mode = blink's own icons
      },
      completion = {
        list = { selection = { preselect = true, auto_insert = false } },
        menu = {
          border = "rounded",
          draw = {
            columns = icons.nerd and { { "kind_icon" }, { "label", "label_description", gap = 1 }, { "kind" } }
              or { { "label", "label_description", gap = 1 }, { "kind" } },
          },
        },
        documentation = { auto_show = true, auto_show_delay_ms = 300, window = { border = "rounded" } },
        ghost_text = { enabled = false },
      },
      signature = { enabled = true, window = { border = "rounded" } },
      sources = {
        default = { "lsp", "path", "snippets", "buffer" },
        per_filetype = { lua = { inherit_defaults = true, "lazydev" } },
        providers = {
          lazydev = { name = "LazyDev", module = "lazydev.integrations.blink", score_offset = 100 },
        },
      },
      cmdline = { enabled = true, completion = { menu = { auto_show = false } } },
      fuzzy = { implementation = "lua" },
    },
  },
})
