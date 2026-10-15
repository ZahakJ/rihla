-- which-key: press Space (or g, z, ], [, ", ', Ctrl-w...) and wait; a popup
-- lists what can follow. This is the main way to discover keys, so every group
-- is labelled and every mapping in rihla carries a description.
local icons = require("rihla.icons")

local ascii_keys = {
  Up = "Up ",
  Down = "Down ",
  Left = "Left ",
  Right = "Right ",
  C = "C-",
  M = "M-",
  D = "D-",
  S = "S-",
  CR = "Enter ",
  Esc = "Esc ",
  ScrollWheelDown = "WheelDown ",
  ScrollWheelUp = "WheelUp ",
  NL = "Enter ",
  BS = "Backspace ",
  Space = "Space ",
  Tab = "Tab ",
  F1 = "F1",
  F2 = "F2",
  F3 = "F3",
  F4 = "F4",
  F5 = "F5",
  F6 = "F6",
  F7 = "F7",
  F8 = "F8",
  F9 = "F9",
  F10 = "F10",
  F11 = "F11",
  F12 = "F12",
}

return require("rihla.spec").wrap({
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    main = "which-key",
    opts = {
      preset = "helix", -- a tall column at the bottom right; does not hide the code
      delay = function(ctx)
        return ctx.plugin and 0 or 300
      end,
      win = { border = "rounded", title = true, title_pos = "center" },
      -- The help line at the bottom of the popup says "Esc close  Backspace back" in
      -- words: a newcomer does not know the Nerd Font glyphs for those keys.
      icons = icons.nerd and { mappings = true, keys = { Esc = "Esc ", BS = "Backspace " } } or {
        breadcrumb = ">",
        separator = "->",
        group = "+",
        ellipsis = "...",
        mappings = false,
        rules = false,
        colors = false,
        keys = ascii_keys,
      },
      spec = {
        { "<leader>f", group = "find (files, text, symbols)" },
        { "<leader>g", group = "git" },
        { "<leader>l", group = "lsp / language" },
        { "<leader>b", group = "buffer" },
        { "<leader>w", group = "window" },
        { "<leader>d", group = "debug" },
        { "<leader>t", group = "terminal / toggle" },
        { "<leader>x", group = "diagnostics / quickfix" },
        { "<leader>h", group = "help / learn" },
        { "<leader>q", group = "quit / session" },
        { "<leader>c", group = "code: outline, breadcrumb" },
        { "<leader>r", group = "replace (file, project)" },
        -- Space 1..9 jump to tabs; one line in the popup is enough for all nine.
        { "<leader>2", hidden = true },
        { "<leader>3", hidden = true },
        { "<leader>4", hidden = true },
        { "<leader>5", hidden = true },
        { "<leader>6", hidden = true },
        { "<leader>7", hidden = true },
        { "<leader>8", hidden = true },
        { "<leader>9", hidden = true },
        { "g", group = "goto / lsp (gr...)" },
        { "gr", group = "lsp: rename, refs, actions" },
        { "z", group = "fold / scroll" },
        { "]", group = "next" },
        { "[", group = "previous" },
        { "<C-w>", group = "windows" },
      },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Keys for this buffer",
      },
    },
  },
})
