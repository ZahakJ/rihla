-- Icon sets. One switch decides whether the UI may use Nerd Font glyphs.
--
-- Order: $RIHLA_ICONS, then the one-word file ~/.config/rihla/icons, then
-- "ascii". ascii is the default because a Nerd Font glyph in a font that does
-- not have it is a tofu box, and over SSH you rarely know the font. ascii mode
-- uses only ASCII plus box-drawing characters that every terminal font has.
--
-- Nerd glyphs are written as \u{...} escapes so the source stays readable in
-- any font and the tests can find them.
local util = require("rihla.util")

local M = {}

local function detect()
  local env = vim.env.RIHLA_ICONS
  if env == "nerd" or env == "ascii" then
    return env
  end
  local s = util.read(util.user_dir .. "/icons")
  s = s and vim.trim(s) or ""
  if s == "nerd" or s == "ascii" then
    return s
  end
  return "ascii"
end

M.mode = detect()
M.nerd = M.mode == "nerd"
vim.g.rihla_icons = M.mode

local nerd = {
  diag = { ERROR = "\u{f0159} ", WARN = "\u{f0026} ", INFO = "\u{f02fd} ", HINT = "\u{f0336} " },
  git = { branch = "\u{e725} ", added = "+", modified = "~", removed = "-" },
  sep = { left = "\u{e0b6}", right = "\u{e0b4}", sub = "" },
  ui = {
    modified = "\u{f03eb}",
    readonly = "\u{f033e}",
    lock = "\u{f033e}",
    close = "\u{f0156}",
    folder_closed = "\u{e5ff}",
    folder_open = "\u{e5fe}",
    folder_empty = "\u{f0256}",
    file = "\u{f0214}",
    arrow_closed = "\u{f0142}",
    arrow_open = "\u{f0140}",
    prompt = "\u{f0349} ",
    caret = "\u{f0142} ",
    lsp = "\u{f0168} ",
    fmt = "\u{f0247} ",
    lesson = "\u{f00ba} ",
  },
  dap = {
    breakpoint = "\u{f0765}",
    condition = "\u{f0766}",
    rejected = "\u{f05e7}",
    log = "\u{f0336}",
    stopped = "\u{f0142}",
  },
  -- nil means "use the plugin's own Nerd Font defaults"
  kinds = nil,
}

local ascii = {
  diag = { ERROR = "E ", WARN = "W ", INFO = "I ", HINT = "H " },
  git = { branch = "", added = "+", modified = "~", removed = "-" },
  sep = { left = "", right = "", sub = "│" },
  ui = {
    modified = "+",
    readonly = "[RO]",
    lock = "[RO]",
    close = "x",
    folder_closed = "",
    folder_open = "",
    folder_empty = "",
    file = "",
    arrow_closed = ">",
    arrow_open = "v",
    prompt = "> ",
    caret = "> ",
    lsp = "lsp:",
    fmt = "fmt ",
    lesson = "",
  },
  dap = { breakpoint = "B", condition = "C", rejected = "R", log = "L", stopped = ">" },
  -- Completion item kinds as short words: readable in any font.
  kinds = {
    Text = "txt",
    Method = "meth",
    Function = "fn",
    Constructor = "new",
    Field = "fld",
    Variable = "var",
    Class = "cls",
    Interface = "intf",
    Module = "mod",
    Property = "prop",
    Unit = "unit",
    Value = "val",
    Enum = "enum",
    Keyword = "kw",
    Snippet = "snip",
    Color = "col",
    File = "file",
    Reference = "ref",
    Folder = "dir",
    EnumMember = "enum",
    Constant = "const",
    Struct = "struct",
    Event = "evt",
    Operator = "op",
    TypeParameter = "type",
  },
}

local set = M.nerd and nerd or ascii
for k, v in pairs(set) do
  M[k] = v
end

return M
