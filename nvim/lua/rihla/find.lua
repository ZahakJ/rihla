-- Helpers for finding things; the plugin spec (and why snacks.picker) is in
-- plugins/find.lua.
local util = require("rihla.util")
local icons = require("rihla.icons")

local function S()
  return require("snacks")
end

local M = {}

M.ripgreprc = util.root .. "/shell/ripgreprc"
M.fdignore = util.root .. "/shell/fdignore"

--- Extra fd arguments: the shared ignore file, when fd is what will run.
function M.fd_args()
  if (util.has("fd") or util.has("fdfind")) and vim.fn.filereadable(M.fdignore) == 1 then
    return { "--ignore-file", M.fdignore }
  end
  return {}
end

-- The help line under every picker: how to use it and how to close it.
M.footer = {
  files = " Enter opens  Esc closes  Ctrl-v split  Ctrl-q quickfix  ? keys ",
  grep = " Alt-r regex  Alt-c case  Alt-w word  Alt-s folder/glob  Ctrl-q quickfix ",
  plain = " Enter picks  Esc closes  ? keys ",
}

--- A picker layout with a help line along its bottom edge. Wide screens get
--- the list and a preview side by side, narrow ones (80 columns) stacked.
function M.layout(footer, opts)
  opts = opts or {}
  return function()
    local title = { title = "{title} {live} {flags}", title_pos = "center", footer = footer, footer_pos = "center" }
    if opts.preview == false then
      return {
        hidden = { "preview" },
        layout = vim.tbl_extend("force", {
          backdrop = false,
          width = 0.6,
          min_width = 70,
          max_width = 120,
          height = 0.6,
          min_height = 8,
          box = "vertical",
          border = true,
          { win = "input", height = 1, border = "bottom" },
          { win = "list", border = "none" },
          { win = "preview", title = "{preview}", height = 0.4, border = "top" },
        }, title),
      }
    end
    if vim.o.columns >= 120 then
      return {
        layout = {
          box = "horizontal",
          width = 0.9,
          min_width = 120,
          height = 0.8,
          vim.tbl_extend("force", {
            box = "vertical",
            border = true,
            { win = "input", height = 1, border = "bottom" },
            { win = "list", border = "none" },
          }, title),
          { win = "preview", title = "{preview}", border = true, width = 0.45 },
        },
      }
    end
    return {
      layout = vim.tbl_extend("force", {
        backdrop = false,
        width = 0.9,
        min_width = 60,
        height = 0.85,
        min_height = 20,
        box = "vertical",
        border = true,
        { win = "input", height = 1, border = "bottom" },
        { win = "list", border = "none" },
        { win = "preview", title = "{preview}", height = 0.45, border = "top" },
      }, title),
    }
  end
end

local function hint_finder()
  if not (util.has("fd") or util.has("fdfind") or util.has("rg")) then
    util.hint("finder", "fd and ripgrep (rg) not found: file search uses `find` and is slower. Install fd.")
  end
end

--- Find a file by name (VS Code Ctrl+P): open and recent files of this folder
--- first, then every file, ranked by how often and how recently you opened
--- them (frecency) and how well the name matches.
function M.files(opts)
  hint_finder()
  -- The file you are in is not offered (Enter would just stay there).
  local cur = vim.api.nvim_buf_get_name(0)
  cur = cur ~= "" and vim.fs.normalize(vim.fn.fnamemodify(cur, ":p")) or nil
  return S().picker.smart(vim.tbl_deep_extend("force", {
    title = "Find file",
    multi = { { source = "buffers", current = false }, "recent", "files" },
    transform = function(item, ctx)
      local path = Snacks.picker.util.path(item)
      if cur and path and vim.fs.normalize(path) == cur then
        return false
      end
      return require("snacks.picker.transform").unique_file(item, ctx)
    end,
    filter = { cwd = true },
    hidden = true,
    follow = true,
    args = M.fd_args(),
    layout = M.layout(M.footer.files),
  }, opts or {}))
end

--- grep with two toggles the stock finder does not have: case-sensitive
--- (Alt-c) and whole word (Alt-w). Both become ripgrep flags.
function M.grep_finder(opts, ctx)
  local args = vim.deepcopy(opts.args or {})
  if opts.case then
    args[#args + 1] = "--case-sensitive"
  end
  if opts.word then
    args[#args + 1] = "--word-regexp"
  end
  local o = setmetatable({ args = args }, { __index = opts })
  return require("snacks.picker.source.grep").grep(o, ctx)
end

--- Folder and glob scope from one line: "src" (a folder) and/or "**/*.ts" (a glob).
function M.parse_scope(text)
  local dirs, globs = {}, {}
  for _, part in ipairs(vim.split(vim.trim(text or ""), "%s+", { trimempty = true })) do
    local p = vim.fn.expand(part)
    if vim.fn.isdirectory(p) == 1 then
      dirs[#dirs + 1] = vim.fn.fnamemodify(p, ":p")
    else
      globs[#globs + 1] = part
    end
  end
  return dirs, globs
end

function M.scope_title(dirs, globs)
  local parts = {}
  for _, d in ipairs(dirs or {}) do
    parts[#parts + 1] = vim.fn.fnamemodify(d, ":~:.")
  end
  vim.list_extend(parts, globs or {})
  return #parts > 0 and ("Grep in " .. table.concat(parts, " ")) or "Grep (regex)"
end

local scope_prompt = "Search only in (folder and/or glob, e.g. src **/*.ts): "

function M.set_scope(picker)
  vim.ui.input({ prompt = scope_prompt }, function(text)
    if text == nil then
      return
    end
    local dirs, globs = M.parse_scope(text)
    picker.opts.dirs = dirs
    picker.opts.glob = globs
    picker.title = M.scope_title(dirs, globs)
    picker:find()
    picker:update_titles()
  end)
end

M.grep_toggles = {
  regex = { icon = ".*", value = true }, -- shown while regex is on (VS Code's .* button)
  case = { icon = "Aa" }, -- shown while case-sensitive is on
  word = { icon = "ab|" }, -- shown while whole word is on
  hidden = false,
  follow = false,
  ignored = "ignored",
  modified = false,
}

local grep_keys = {
  ["<a-c>"] = { "toggle_case", mode = { "i", "n" }, desc = "Toggle case-sensitive" },
  ["<a-w>"] = { "toggle_word", mode = { "i", "n" }, desc = "Toggle whole word" },
  ["<a-r>"] = { "toggle_regex", mode = { "i", "n" }, desc = "Toggle regex" },
  ["<a-s>"] = { "set_scope", mode = { "i", "n" }, desc = "Search only in a folder / glob" },
}

function M.grep_opts(extra)
  return vim.tbl_deep_extend("force", {
    title = "Grep (regex)",
    finder = M.grep_finder,
    regex = true,
    hidden = true,
    follow = true,
    toggles = M.grep_toggles,
    actions = { set_scope = M.set_scope },
    win = { input = { keys = grep_keys }, list = { keys = grep_keys } },
    layout = M.layout(M.footer.grep),
  }, extra or {})
end

--- Without ripgrep: ask for the pattern, run `grep -rnIE`, results in the quickfix list.
function M.grep_fallback(pattern)
  local function run(pat)
    if not pat or pat == "" then
      return
    end
    local out = vim.fn.systemlist({ "grep", "-rnIHE", "--exclude-dir=.git", "--exclude-dir=node_modules", "-e", pat, "." })
    vim.fn.setqflist({}, " ", { title = "grep " .. pat, lines = out, efm = "%f:%l:%m" })
    vim.cmd("botright copen")
  end
  if pattern then
    return run(pattern)
  end
  vim.ui.input({ prompt = "grep (no ripgrep here; results go to the quickfix list): " }, run)
end

--- Live grep across the project, regex on (VS Code Ctrl+Shift+F).
function M.grep(opts)
  opts = opts or {}
  if (opts.dirs and #opts.dirs > 0) or (opts.glob and #opts.glob > 0) then
    opts.title = opts.title or M.scope_title(opts.dirs, opts.glob)
  end
  if not util.has("rg") then
    util.hint("rg", "ripgrep (rg) not found: search uses grep -r into the quickfix list. `rihla install` adds rg.")
    return M.grep_fallback()
  end
  return S().picker.grep(M.grep_opts(opts))
end

--- The same, first asking where: a folder, a glob, or both.
function M.grep_scoped()
  vim.ui.input({ prompt = scope_prompt }, function(text)
    if text == nil then
      return
    end
    local dirs, globs = M.parse_scope(text)
    M.grep({ dirs = dirs, glob = globs })
  end)
end

--- The word under the cursor (or the selection): literal, whole word.
function M.grep_word()
  if not util.has("rg") then
    return M.grep_fallback(vim.fn.expand("<cword>"))
  end
  return S().picker.grep_word(M.grep_opts({ title = "Grep word", regex = false, word = true, args = {}, live = false }))
end

--- Two small changes to snacks.picker, so a hit reads the same everywhere
--- (picker, quickfix list, ripgrep, rgi): the column is shown 1-based on every row
--- (snacks shows it 0-based and leaves it out at column 1), and the quickfix list
--- that Ctrl-q fills is titled with the search instead of ":setqflist()".
function M.patch_snacks()
  local fmt = require("snacks.picker.format")
  if not fmt._rihla then
    fmt._rihla = true
    local filename = fmt.filename
    fmt.filename = function(item, picker)
      if item.pos and item.pos[1] > 0 and item.pos[2] and item.line ~= nil then
        local shown = setmetatable({ pos = { item.pos[1], item.pos[2] + 1 } }, { __index = item })
        return filename(shown, picker)
      end
      return filename(item, picker)
    end
  end
  if not fmt._rihla_buffer then
    -- The open-files picker (Space b b) numbers each file as its tab is numbered
    -- (Alt-N reaches it), not by Neovim's internal buffer number.
    fmt._rihla_buffer = true
    local buffer = fmt.buffer
    fmt.buffer = function(item, picker)
      local ret = buffer(item, picker)
      local n = ""
      local ok, order = pcall(function()
        return require("rihla.tabs").order()
      end)
      for i, id in ipairs(ok and order or {}) do
        if id == item.buf then
          n = i .. "."
        end
      end
      if ret[1] and ret[1][2] == "SnacksPickerBufNr" then
        ret[1] = { Snacks.picker.util.align(n, 3), "SnacksPickerBufNr" }
      end
      return ret
    end
  end
  local actions = require("snacks.picker.actions")
  if not actions._rihla then
    actions._rihla = true
    for _, name in ipairs({ "qflist", "qflist_all", "loclist" }) do
      local orig = actions[name]
      actions[name] = function(picker, ...)
        local title = picker.title or "picker"
        local f = picker.input and picker.input.filter or {}
        local what = (f.search ~= nil and f.search ~= "") and f.search or f.pattern
        if what and what ~= "" then
          title = title .. ": " .. what
        end
        local win = picker.main
        local r = orig(picker, ...)
        if name == "loclist" then
          pcall(vim.fn.setloclist, win, {}, "a", { title = title })
        else
          vim.fn.setqflist({}, "a", { title = title })
        end
        return r
      end
    end
  end
end

function M.pick(name, opts)
  return function()
    return S().picker[name](vim.tbl_deep_extend("force", { layout = M.layout(M.footer.plain) }, opts or {}))
  end
end

--- Symbols of this file: from the language server when one is attached,
--- else from tree-sitter. In a panel on the right that stays open (VS Code's
--- Outline): Enter jumps, Esc closes.
function M.symbols()
  local source = "lsp_symbols"
  if #vim.lsp.get_clients({ bufnr = 0, method = "textDocument/documentSymbol" }) == 0 then
    local ok, parser = pcall(vim.treesitter.get_parser, 0, nil, { error = false })
    if not ok or not parser then
      util.say("Outline: no language server and no tree-sitter parser for this file (:Rihla langs says why).", vim.log.levels.WARN)
      return
    end
    source = "treesitter"
  end
  return S().picker[source]({
    title = "Outline",
    focus = "list",
    jump = { close = false },
    auto_close = false, -- stays open while you work in the file (Ctrl-w p / Ctrl-h back)
    layout = {
      preset = "right",
      preview = "main",
      layout = { width = 38, min_width = 30, footer = " Enter jumps  Esc closes ", footer_pos = "center" },
    },
  })
end

function M.filetypes()
  vim.ui.select(vim.fn.getcompletion("", "filetype"), { prompt = "Set file type" }, function(ft)
    if ft then
      vim.bo.filetype = ft
    end
  end)
end

-- Plain-text glyphs for ascii mode (the defaults are Nerd Font symbols).
function M.ascii_icons()
  local kinds = {}
  for k, v in pairs(icons.kinds or {}) do
    kinds[k] = v .. " "
  end
  for _, k in ipairs({ "Array", "Boolean", "Collapsed", "Control", "Copilot", "Key", "Namespace", "Null", "Number", "Object", "Package", "String", "Unknown" }) do
    kinds[k] = kinds[k] or (k:lower():sub(1, 4) .. " ")
  end
  return {
    files = { enabled = false, dir = "", dir_open = "", file = "" },
    keymaps = { nowait = "nowait " },
    tree = { vertical = "│ ", middle = "├╴", last = "└╴" },
    undo = { saved = "saved " },
    ui = { live = "live ", hidden = "h", ignored = "i", follow = "f", selected = "* ", unselected = "  " },
    git = {
      enabled = true,
      commit = "",
      staged = "S",
      added = "A",
      deleted = "D",
      ignored = "!",
      modified = "M",
      renamed = "R",
      unmerged = "U",
      untracked = "?",
    },
    diagnostics = { Error = "E ", Warn = "W ", Hint = "H ", Info = "I " },
    lsp = { unavailable = "-", enabled = "+", disabled = "x", attached = "lsp " },
    kinds = kinds,
  }
end

return M
