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
  files = " Enter opens  Esc closes  Alt-s where  Ctrl-q quickfix  ? keys ",
  grep = " Alt-s where  Alt-r/c/w regex/case/word  Ctrl-g refine  Ctrl-q quickfix ",
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

-- ---------------------------------------------------------------- where and which files
-- One line says where to search and in which files. The Alt-s prompt in both pickers,
-- Space f G, Space f F, :Grep and :Find all read it:
--   src ~/work /    folders, one or more (~ is your home, / the whole disk)
--   .py .ts         extensions (any of them)
--   *.test.ts       a glob;  !tests/  !*.min.js  leave out
--   -t py  -T js    ripgrep file types (rg --type-list); any other -flag (-u, -U, -F,
--                   --max-depth=2) goes to ripgrep as it is
M.scope_prompt = "Where (folders ~ / src, .py *.ts, !tests/, -t py): "

local function is_glob(s)
  return s:find("[*?%[{]") ~= nil
end

--- The scope line, parsed. Folders are absolute, ending in "/".
function M.parse_filters(text)
  local f = { text = vim.trim(text or ""), dirs = {}, exts = {}, globs = {}, excludes = {}, types = {}, args = {} }
  local parts = vim.split(f.text, "%s+", { trimempty = true })
  local i = 1
  while i <= #parts do
    local part = parts[i]
    local t, rest = part:match("^%-([tT])(.*)$")
    if t then
      local v = rest
      if v == "" then
        i = i + 1
        v = parts[i]
      end
      if v and v ~= "" then
        if t == "t" then
          f.types[#f.types + 1] = v
        else
          vim.list_extend(f.args, { "-T", v })
        end
      end
    elseif part:sub(1, 1) == "-" then
      f.args[#f.args + 1] = part
    elseif part:sub(1, 1) == "!" and #part > 1 then
      f.excludes[#f.excludes + 1] = part:sub(2)
    else
      -- Only ~ and $VARS are expanded: expand() on a glob would walk the tree.
      local p = not is_glob(part) and vim.fs.normalize(part) or nil
      if p and vim.fn.isdirectory(p) == 1 then
        p = vim.fn.fnamemodify(p, ":p")
        f.dirs[#f.dirs + 1] = p:sub(-1) == "/" and p or (p .. "/")
      elseif part:match("^%.[%w_+-]+$") then
        f.exts[#f.exts + 1] = part:sub(2)
      else
        f.globs[#f.globs + 1] = part
      end
    end
    i = i + 1
  end
  return f
end

--- ripgrep's -g list for a parsed scope: globs, extensions as *.ext, excludes as !glob.
function M.rg_globs(f)
  local g = vim.list_extend({}, f.globs or {})
  for _, e in ipairs(f.exts or {}) do
    g[#g + 1] = "*." .. e
  end
  for _, e in ipairs(f.excludes or {}) do
    g[#g + 1] = "!" .. e
  end
  return g
end

--- Folder and glob scope from one line (the older two-value form of parse_filters).
function M.parse_scope(text)
  local f = M.parse_filters(text)
  return f.dirs, M.rg_globs(f), f
end

local function home()
  return vim.fs.normalize(vim.env.HOME or "~")
end

local function short_dir(d)
  local n = vim.fs.normalize(d)
  if n == "/" then
    return "/"
  end
  if n == home() then
    return "~"
  end
  return vim.fn.fnamemodify(n, ":~:.")
end

--- The picker title for a scope: "Grep in ~ .py !tests/".
function M.filter_title(f, what)
  local parts = {}
  for _, d in ipairs(f.dirs or {}) do
    parts[#parts + 1] = short_dir(d)
  end
  for _, e in ipairs(f.exts or {}) do
    parts[#parts + 1] = "." .. e
  end
  vim.list_extend(parts, f.globs or {})
  for _, e in ipairs(f.excludes or {}) do
    parts[#parts + 1] = "!" .. e
  end
  for _, t in ipairs(f.types or {}) do
    parts[#parts + 1] = "-t " .. t
  end
  vim.list_extend(parts, f.args or {})
  if what == "files" then
    return #parts > 0 and ("Files in " .. table.concat(parts, " ")) or "Find file"
  end
  return #parts > 0 and ("Grep in " .. table.concat(parts, " ")) or "Grep (regex)"
end

function M.scope_title(dirs, globs)
  return M.filter_title({ dirs = dirs, globs = globs })
end

--- A folder so large that hidden files and symlinks start off: your home or the disk.
function M.is_wide(dirs)
  for _, d in ipairs(dirs or {}) do
    local n = vim.fs.normalize(d)
    if n == "/" or n == home() then
      return true
    end
  end
  return false
end

-- The whole disk ("/") is searched as its top folders and the local disks mounted below
-- them, each without crossing into other mounts: no /proc, /sys, /dev or /run, no network
-- shares, nothing twice.
local skip_top = { proc = true, sys = true, dev = true, run = true, ["lost+found"] = true }
local local_fs = {}
for _, t in ipairs({ "ext2", "ext3", "ext4", "xfs", "btrfs", "zfs", "f2fs", "jfs", "reiserfs", "bcachefs", "vfat", "exfat", "ntfs", "ntfs3", "fuseblk", "apfs", "hfs" }) do
  local_fs[t] = true
end

function M.disk_roots()
  local roots, seen = {}, {}
  for name, kind in vim.fs.dir("/") do
    if kind == "directory" and not skip_top[name] then
      roots[#roots + 1] = "/" .. name
      seen["/" .. name] = true
    end
  end
  local fh = io.open("/proc/self/mounts", "r")
  if fh then
    for line in fh:lines() do
      local mnt, fstype = line:match("^%S+%s+(%S+)%s+(%S+)")
      if mnt then
        mnt = mnt:gsub("\\040", " ")
        local top = mnt:match("^/([^/]+)")
        if local_fs[fstype] and top and not skip_top[top] and not seen[mnt] then
          roots[#roots + 1] = mnt
          seen[mnt] = true
        end
      end
    end
    fh:close()
  end
  table.sort(roots)
  return roots
end

--- dirs with "/" replaced by the disk's roots; the second value says it was there.
function M.expand_dirs(dirs)
  local out, disk = {}, false
  for _, d in ipairs(dirs or {}) do
    if vim.fs.normalize(d) == "/" then
      disk = true
      vim.list_extend(out, M.disk_roots())
    else
      out[#out + 1] = d
    end
  end
  return out, disk
end

-- ---------------------------------------------------------------- find a file
local function hint_finder()
  if not (util.has("fd") or util.has("fdfind") or util.has("rg")) then
    util.hint("finder", "fd and ripgrep (rg) not found: file search uses `find` and is slower. Install fd.")
  end
end

local fd_one_fs
local function fd_has_one_fs()
  if fd_one_fs == nil then
    local fd = util.has("fd") and "fd" or util.has("fdfind") and "fdfind" or nil
    fd_one_fs = fd ~= nil and (vim.fn.system({ fd, "--help" }) or ""):find("one%-file%-system") ~= nil
  end
  return fd_one_fs
end

local scope_keys = {
  ["<a-s>"] = { "set_scope", mode = { "i", "n" }, desc = "Where and which files (folders, .ext, globs, !excludes)" },
}

--- Does a file path pass the include globs? A glob without "/" is matched against the
--- name, one with "/" against the path below the folder searched.
local function glob_matcher(globs)
  if #globs == 0 or not (vim.glob and vim.glob.to_lpeg) then
    return nil
  end
  local pats = {}
  for _, g in ipairs(globs) do
    local ok, lp = pcall(vim.glob.to_lpeg, g)
    if ok then
      pats[#pats + 1] = { lp = lp, path = g:find("/", 1, true) ~= nil }
    end
  end
  return function(file)
    local name = file:match("[^/]*$")
    for _, p in ipairs(pats) do
      if not p.path then
        if p.lp:match(name) then
          return true
        end
      else
        -- the path below any folder: "a/src/x.ts" is tried as itself, "src/x.ts", "x.ts"
        local s = file:gsub("^%./", "")
        while s do
          if p.lp:match(s) then
            return true
          end
          s = s:match("^[^/]*/(.+)$")
        end
      end
    end
    return false
  end
end

--- Files in a scope: folders, extensions, globs and excludes (rg types and flags are
--- grep-only). Your home and the whole disk start without hidden files and symlinks.
function M.files_in(f, extra)
  hint_finder()
  local dirs, disk = M.expand_dirs(f.dirs)
  local wide = M.is_wide(f.dirs)
  local args = M.fd_args()
  if disk and fd_has_one_fs() then
    args = vim.list_extend(vim.deepcopy(args), { "--one-file-system" })
  end
  local keep = glob_matcher(f.globs or {})
  return S().picker.files(vim.tbl_deep_extend("force", {
    title = M.filter_title(f, "files"),
    filters_text = f.text,
    dirs = #dirs > 0 and dirs or nil,
    ft = #f.exts > 0 and f.exts or nil,
    exclude = #f.excludes > 0 and f.excludes or nil,
    transform = keep and function(item)
      return keep(item.file or "") or false
    end or nil,
    hidden = not wide,
    follow = not wide,
    args = args,
    toggles = M.grep_toggles,
    actions = { set_scope = M.set_files_scope },
    win = { input = { keys = scope_keys }, list = { keys = scope_keys } },
    layout = M.layout(M.footer.files),
  }, extra or {}))
end

--- Alt-s in a file picker: change where, keep what you typed.
function M.set_files_scope(picker)
  local pattern = picker.input and picker.input.filter.pattern or ""
  vim.ui.input({ prompt = M.scope_prompt, default = picker.opts.filters_text or "", completion = "customlist,v:lua.rihla_scope_complete" }, function(text)
    if text == nil then
      return
    end
    picker:close()
    M.files_in(M.parse_filters(text), { pattern = pattern })
  end)
end

--- Find a file by name (VS Code Ctrl+P): open and recent files of this folder
--- first, then every file, ranked by how often and how recently you opened
--- them (frecency) and how well the name matches. opts.filters (a scope line)
--- searches there instead.
function M.files(opts)
  opts = opts or {}
  local filters = opts.filters
  opts.filters = nil
  if filters and vim.trim(filters) ~= "" then
    return M.files_in(M.parse_filters(filters), opts)
  end
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
    actions = { set_scope = M.set_files_scope },
    win = { input = { keys = scope_keys }, list = { keys = scope_keys } },
    layout = M.layout(M.footer.files),
  }, opts))
end

--- Find a file, first asking where (Space f F).
function M.files_scoped()
  vim.ui.input({ prompt = M.scope_prompt, completion = "customlist,v:lua.rihla_scope_complete" }, function(text)
    if text ~= nil then
      M.files({ filters = text })
    end
  end)
end

-- ---------------------------------------------------------------- find text
--- grep with the toggles the stock finder does not have: case-sensitive (Alt-c), whole
--- word (Alt-w), symlinks off for real (ripgreprc turns them on), the scope's flags, and
--- the whole disk searched as its local disks.
function M.grep_finder(opts, ctx)
  local args = vim.deepcopy(opts.args or {})
  if opts.case then
    args[#args + 1] = "--case-sensitive"
  end
  if opts.word then
    args[#args + 1] = "--word-regexp"
  end
  if not opts.follow then
    args[#args + 1] = "--no-follow"
  end
  vim.list_extend(args, opts.filter_args or {})
  local dirs, disk = M.expand_dirs(opts.dirs)
  if disk then
    vim.list_extend(args, { "--one-file-system", "--no-follow", "--no-messages" })
  end
  local o = setmetatable({ args = args, dirs = dirs }, { __index = opts })
  return require("snacks.picker.source.grep").grep(o, ctx)
end

--- Put a parsed scope into grep options.
function M.apply_filters(o, f)
  o.filters_text = f.text
  o.dirs = f.dirs
  o.glob = M.rg_globs(f)
  o.ft = f.types
  o.filter_args = f.args
  if M.is_wide(f.dirs) then
    o.hidden, o.follow = false, false
  end
  return o
end

function M.set_scope(picker)
  vim.ui.input({ prompt = M.scope_prompt, default = picker.opts.filters_text or "", completion = "customlist,v:lua.rihla_scope_complete" }, function(text)
    if text == nil then
      return
    end
    local f = M.parse_filters(text)
    M.apply_filters(picker.opts, f)
    picker.title = M.filter_title(f)
    picker:find()
    picker:update_titles()
  end)
end

--- Tab in the scope prompt completes the last word as a folder.
function _G.rihla_scope_complete(lead, line)
  line = line or lead or ""
  local before, last = line:match("^(.-)(%S*)$")
  if last:match("^[!%-]") or last:match("^%.[%w_+-]+$") and vim.fn.isdirectory(last) == 0 then
    return {}
  end
  local out = {}
  for _, d in ipairs(vim.fn.getcompletion(last, "dir")) do
    out[#out + 1] = before .. d
  end
  return out
end

-- The badges in a picker's title: on for regex (VS Code's .*), case and whole word; for
-- hidden files and symlinks (on by default) only when you switch them off.
M.grep_toggles = {
  regex = { icon = ".*", value = true }, -- shown while regex is on (VS Code's .* button)
  case = { icon = "Aa" }, -- shown while case-sensitive is on
  word = { icon = "ab|" }, -- shown while whole word is on
  hidden = { icon = "-hidden", value = false },
  follow = { icon = "-links", value = false },
  ignored = "+ignored",
  modified = false,
}

local grep_keys = {
  ["<a-c>"] = { "toggle_case", mode = { "i", "n" }, desc = "Toggle case-sensitive" },
  ["<a-w>"] = { "toggle_word", mode = { "i", "n" }, desc = "Toggle whole word" },
  ["<a-r>"] = { "toggle_regex", mode = { "i", "n" }, desc = "Toggle regex" },
  ["<a-s>"] = scope_keys["<a-s>"],
}

function M.grep_opts(extra)
  extra = extra or {}
  local o = vim.tbl_deep_extend("force", {
    title = "Grep (regex)",
    finder = M.grep_finder,
    regex = true,
    hidden = true,
    follow = true,
    toggles = M.grep_toggles,
    actions = { set_scope = M.set_scope },
    win = { input = { keys = grep_keys }, list = { keys = grep_keys } },
    layout = M.layout(M.footer.grep),
  }, extra)
  if extra.filters then
    local f = M.parse_filters(extra.filters)
    o.filters = nil
    M.apply_filters(o, f)
    o.title = extra.title or M.filter_title(f)
  end
  return o
end

--- Without ripgrep: ask for the pattern, run `grep -rnIE` in the scope (folders, .ext,
--- simple globs and excludes), results in the quickfix list.
function M.grep_fallback(pattern, f)
  f = f or M.parse_filters("")
  local function run(pat)
    if not pat or pat == "" then
      return
    end
    local cmd = { "grep", "-rnIHE", "--exclude-dir=.git", "--exclude-dir=node_modules" }
    for _, e in ipairs(f.exts) do
      cmd[#cmd + 1] = "--include=*." .. e
    end
    for _, g in ipairs(f.globs) do
      cmd[#cmd + 1] = "--include=" .. g:gsub("^%*%*/", "")
    end
    for _, e in ipairs(f.excludes) do
      cmd[#cmd + 1] = e:sub(-1) == "/" and ("--exclude-dir=" .. e:sub(1, -2)) or ("--exclude=" .. e)
    end
    vim.list_extend(cmd, { "-e", pat })
    local dirs = M.expand_dirs(f.dirs)
    vim.list_extend(cmd, #dirs > 0 and dirs or { "." })
    local out = vim.fn.systemlist(cmd)
    vim.fn.setqflist({}, " ", { title = "grep " .. pat, lines = out, efm = "%f:%l:%m" })
    vim.cmd("botright copen")
  end
  if pattern then
    return run(pattern)
  end
  vim.ui.input({ prompt = "grep (no ripgrep here; results go to the quickfix list): " }, run)
end

--- Live grep across the project, regex on (VS Code Ctrl+Shift+F). opts.filters (a scope
--- line) or opts.dirs / opts.glob say where; opts.search starts with a query.
function M.grep(opts)
  opts = opts or {}
  if (opts.dirs and #opts.dirs > 0) or (opts.glob and #opts.glob > 0) then
    opts.title = opts.title or M.scope_title(opts.dirs, opts.glob)
  end
  if not util.has("rg") then
    util.hint("rg", "ripgrep (rg) not found: search uses grep -r into the quickfix list. `rihla install` adds rg.")
    local f = opts.filters and M.parse_filters(opts.filters) or { dirs = opts.dirs or {}, exts = {}, globs = opts.glob or {}, excludes = {}, types = {}, args = {} }
    return M.grep_fallback(opts.search ~= "" and opts.search or nil, f)
  end
  return S().picker.grep(M.grep_opts(opts))
end

--- The same, first asking where: folders, extensions, globs, excludes (Space f G).
function M.grep_scoped()
  vim.ui.input({ prompt = M.scope_prompt, completion = "customlist,v:lua.rihla_scope_complete" }, function(text)
    if text ~= nil then
      M.grep({ filters = text })
    end
  end)
end

--- :Grep and :Find: "[scope] [-- query]", e.g. :Grep ~/src .py !tests/ -- TODO
function M.command(kind, args)
  local scope, query = (args or ""):match("^(.-)%s*%-%-%s+(.*)$")
  if not scope then
    scope, query = args or "", nil
  end
  if kind == "files" then
    return M.files({ filters = scope, pattern = query })
  end
  return M.grep({ filters = scope, search = query })
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
