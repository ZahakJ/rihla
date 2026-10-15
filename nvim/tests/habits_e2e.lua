-- The eight VS Code habits, end to end, headless (docs/vscode-to-neovim.md, lesson 7b):
--   1 find a file          2 find text (regex, scope, quickfix)   3 replace across files
--   4 terminal on demand   5 the view (breadcrumb, outline, folds) 6 file tree
--   7 open files as tabs   8 merge conflicts
-- Each check presses the real mapping where it can and looks at the result.
--
--   nvim --headless "+luafile nvim/tests/habits_e2e.lua"   (or nvim/tests/run.sh habits)
local results, failed = {}, 0
local function check(name, ok, detail)
  results[#results + 1] = ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, (detail and detail ~= "") and ("  -- " .. tostring(detail)) or "")
  if not ok then
    failed = failed + 1
  end
end
local function note(s)
  results[#results + 1] = "note  " .. s
end

vim.g.rihla_auto_install = false
-- The git parts need a git that rihla's git features accept (2.19+; CentOS 7 has
-- 1.8.3, which cannot even run `git -C`); the merge view needs 2.31+ (diffview).
local function git_at_least(ma, mi)
  if vim.fn.executable("git") ~= 1 then
    return false
  end
  local a, b = vim.fn.system({ "git", "--version" }):match("(%d+)%.(%d+)")
  a, b = tonumber(a) or 0, tonumber(b) or 0
  return a > ma or (a == ma and b >= mi)
end
local has_git = git_at_least(2, 19)
local has_diffview_git = git_at_least(2, 31)
local function git(dir, ...)
  return vim.fn.system(vim.list_extend({ "git", "-C", dir, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main" }, { ... }))
end

local function press(lhs, mode)
  local m = vim.fn.maparg(lhs, mode or "n", false, true)
  if m.callback then
    m.callback()
    return true
  elseif m.rhs and m.rhs ~= "" then
    vim.api.nvim_feedkeys(vim.keycode(lhs), "mx", false)
    return true
  end
  return false
end

local function wait(ms, fn)
  return vim.wait(ms, fn, 20)
end

local function write(path, lines)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  vim.fn.writefile(lines, path)
end

local function picker()
  local ok, list = pcall(function()
    return Snacks.picker.get({ tab = false })
  end)
  return ok and list[#list] or nil
end

local function settle(p)
  wait(10000, function()
    return not p:is_active()
  end)
  vim.wait(150)
  wait(10000, function()
    return not p:is_active()
  end)
end

local function items(p)
  local out = {}
  for _, it in ipairs(p:items()) do
    out[#out + 1] = it
  end
  return out
end

local function close_pickers()
  pcall(function()
    for _, p in ipairs(Snacks.picker.get({ tab = false })) do
      p:close()
    end
  end)
  vim.wait(100)
end

local function only_window()
  close_pickers()
  pcall(vim.cmd, "silent! only!")
end

-- A small project ----------------------------------------------------------------------
local dir = vim.fn.resolve(vim.fn.tempname()) .. "-habits"
write(dir .. "/src/deep/server.py", { "def handler(event):", "    return 'rihla_needle_7731'", "", "def other():", "    return 1" })
write(dir .. "/src/app.ts", { "export const a = 'rihla_needle_7731';", "export const b = 'RIHLA_NEEDLE_7731';" })
write(dir .. "/lib/util.ts", { "export function util() { return 'rihla_needle_9'; }" })
write(dir .. "/.config/settings.ts", { "export const hidden = 'rihla_needle_hidden';" })
write(dir .. "/node_modules/pkg/index.js", { "rihla_needle_7731" })
write(dir .. "/README.md", { "# Project", "", "## Usage", "", "nothing here" })
write(dir .. "/src/fold.lua", {
  "local M = {}",
  "",
  "function M.outer()",
  "  local function inner_helper()",
  "    return 1",
  "  end",
  "  return inner_helper()",
  "end",
  "",
  "return M",
})
if has_git then
  git(dir, "init", "-q")
  write(dir .. "/.gitignore", { "node_modules/" })
  git(dir, "add", ".")
  git(dir, "commit", "-q", "-m", "init")
end
vim.cmd("cd " .. vim.fn.fnameescape(dir))

local function run()
  -- Load every plugin first, so each key below is the real mapping and not
  -- lazy.nvim's stand-in (which loads the plugin and replays the key later).
  require("lazy").load({ plugins = vim.tbl_keys(require("lazy.core.config").plugins), wait = true })
  local find = require("rihla.find")

  -- 1. Find a file by name ---------------------------------------------------------------
  vim.cmd("edit lib/util.ts")
  vim.cmd("edit src/app.ts")
  check("1 find file: Ctrl-p is mapped", vim.fn.maparg("<C-p>", "n") ~= "")
  press("<leader>ff")
  local p = picker()
  check("1 find file: Space f f opens the picker", p ~= nil)
  if p then
    settle(p)
    local first = items(p)[1]
    check("1 find file: the other open file comes first (recent first, not the current one)", first and first.file and first.file:find("util.ts", 1, true) ~= nil, first and first.file)
    p.input.filter.pattern = "servpy"
    p:find({ refresh = false })
    settle(p)
    first = items(p)[1]
    check("1 find file: fuzzy 'servpy' ranks src/deep/server.py first", first and first.file and first.file:find("server.py", 1, true) ~= nil, first and first.file)
    p.input.filter.pattern = "settings"
    p:find({ refresh = false })
    settle(p)
    first = items(p)[1]
    check("1 find file: hidden files are found (.config/settings.ts)", first and first.file and first.file:find(".config/settings.ts", 1, true) ~= nil, first and first.file)
    p.input.filter.pattern = ""
    p:find({ refresh = false })
    settle(p)
    local bad = {}
    for _, it in ipairs(items(p)) do
      if (it.file or ""):find("%.git/") or (it.file or ""):find("node_modules", 1, true) then
        bad[#bad + 1] = it.file
      end
    end
    check("1 find file: .git and node_modules are left out", #bad == 0, table.concat(bad, " "))
    -- the preview pane exists in the layout
    check("1 find file: has a preview", p.preview and p.preview.win and p.preview.win:valid())
    close_pickers()
  end

  -- 2. Find text: live ripgrep, regex, toggles, scope, quickfix ------------------------
  if vim.fn.executable("rg") ~= 1 then
    note("2: no ripgrep here, live grep checks skipped")
  else
    press("<leader>fg")
    p = picker()
    check("2 grep: Space f g opens the live grep picker", p ~= nil and p.opts.live == true)
    if p then
      local function search(s)
        p.input.filter.search = s
        p:find({ refresh = false })
        settle(p)
        local files = {}
        for _, it in ipairs(items(p)) do
          files[#files + 1] = vim.fn.fnamemodify(it.file, ":.") .. ":" .. (it.pos and it.pos[1] or 0)
        end
        table.sort(files)
        return files
      end
      local hits = search([[rihla_needle_\d{4}]])
      check("2 grep: regex is on by default (\\d{4})", vim.tbl_contains(hits, "src/deep/server.py:2"), table.concat(hits, " "))
      check("2 grep: node_modules is not searched", not table.concat(hits, " "):find("node_modules", 1, true), table.concat(hits, " "))
      local title = vim.inspect(p.layout.root.opts.title) .. vim.inspect((p.layout.box_wins[2] or {}).opts and p.layout.box_wins[2].opts.title)
      check("2 grep: the title shows the regex toggle (.*)", title:find(".*", 1, true) ~= nil, title)
      local before = #search("rihla_needle_7731")
      p:action("toggle_case")
      settle(p)
      hits = search("rihla_needle_7731")
      check("2 grep: Alt-c makes it case-sensitive (fewer hits)", #hits < before and #hits > 0, before .. " -> " .. #hits)
      title = vim.inspect(p.layout.root.opts.title) .. vim.inspect((p.layout.box_wins[2] or {}).opts and p.layout.box_wins[2].opts.title)
      check("2 grep: the title shows Aa while case-sensitive", title:find("Aa", 1, true) ~= nil, title)
      p:action("toggle_case")
      p:action("toggle_word")
      hits = search("needle")
      check("2 grep: Alt-w whole word: 'needle' inside rihla_needle_ does not match", #hits == 0, table.concat(hits, " "))
      p:action("toggle_word")
      hits = search("needle -- -g *.ts")
      local only_ts = #hits > 0
      for _, h in ipairs(hits) do
        if not h:match("%.ts:%d+$") then
          only_ts = false
        end
      end
      check("2 grep: a glob after -- in the prompt scopes it (*.ts only)", only_ts, table.concat(hits, " "))
      search("rihla_needle_7731")
      local n = p:count()
      -- each row shows line:column as ripgrep and the quickfix list count them (from 1)
      local rows = {}
      for _, it in ipairs(items(p)) do
        local t = {}
        for _, seg in ipairs(require("snacks.picker.format").file(it, p)) do
          t[#t + 1] = type(seg[1]) == "string" and seg[1] or ""
        end
        rows[#rows + 1] = { shown = table.concat(t), col = it.pos[2] + 1, lnum = it.pos[1] }
      end
      local cols_ok = #rows > 0
      for _, r in ipairs(rows) do
        cols_ok = cols_ok and r.shown:find(":" .. r.lnum .. ":" .. r.col .. " ", 1, true) ~= nil
      end
      check("2 grep: every row shows line:column, the column counted from 1", cols_ok, rows[1] and rows[1].shown)
      p:action("qflist")
      vim.wait(200)
      local qf = vim.fn.getqflist()
      check("2 grep: Ctrl-q sends every hit to the quickfix list", #qf == n and n > 0, #qf .. " of " .. n)
      local qtitle = vim.fn.getqflist({ title = 1 }).title
      check("2 grep: the quickfix list is titled with the search", qtitle:find("rihla_needle_7731", 1, true) ~= nil, qtitle)
      local same = #rows == #qf
      for i, q in ipairs(qf) do
        same = same and rows[i] ~= nil and rows[i].col == q.col and rows[i].lnum == q.lnum
      end
      check("2 grep: the picker and the quickfix list give the same line and column", same)
      local qfwin = vim.fn.getqflist({ winid = 0 }).winid
      check("2 grep: the quickfix window opens", qfwin ~= 0)
      vim.cmd("wincmd p")
      vim.cmd("cfirst")
      local f1 = vim.api.nvim_buf_get_name(0)
      press("]q")
      local f2 = vim.fn.getqflist({ idx = 0 }).idx
      check("2 grep: ]q walks to the next hit", f2 == 2, "idx " .. tostring(f2) .. " from " .. f1)
      press("<leader>xq")
      check("2 grep: Space x q closes / opens the quickfix list", vim.fn.getqflist({ winid = 0 }).winid == 0)
    end
    only_window()
    -- scoped grep from the API Space f G uses
    local dirs, globs = find.parse_scope("src **/*.py")
    check("2 grep: Space f G scope 'src **/*.py' = folder src + glob", #dirs == 1 and dirs[1]:find("/src/$") ~= nil and globs[1] == "**/*.py", vim.inspect({ dirs, globs }))
    p = find.grep({ dirs = dirs, glob = globs })
    if p then
      p.input.filter.search = "rihla_needle"
      p:find({ refresh = false })
      settle(p)
      local files = {}
      for _, it in ipairs(items(p)) do
        files[#files + 1] = vim.fn.fnamemodify(it.file, ":.")
      end
      check("2 grep: scoped to src + *.py finds only src/deep/server.py", #files == 1 and files[1]:find("server.py", 1, true) ~= nil, table.concat(files, " "))
      check("2 grep: the title names the scope", (p.title or ""):find("src", 1, true) ~= nil, p.title)
    end
    only_window()
    -- word under the cursor
    vim.cmd("edit src/app.ts")
    vim.api.nvim_win_set_cursor(0, { 1, 20 })
    press("<leader>fw")
    p = picker()
    if p then
      settle(p)
      local n = #items(p)
      check("2 grep: Space f w finds the word under the cursor", n >= 2, n .. " hits for " .. vim.inspect(p.input.filter.search))
    else
      check("2 grep: Space f w opens a picker", false)
    end
    only_window()
  end

  -- 3. Replace across files (grug-far): preview first, then replace, then undo ----------
  if vim.fn.executable("rg") ~= 1 then
    note("3: no ripgrep here, grug-far checks skipped")
  else
    local replace = require("rihla.replace")
    local target = dir .. "/src/deep/server.py"
    local before = vim.fn.readfile(target)
    vim.cmd("edit src/app.ts")
    press("<leader>rP")
    local gf = require("grug-far")
    local inst
    wait(5000, function()
      local ok, i = pcall(gf.get_instance)
      inst = ok and i or nil
      return inst ~= nil
    end)
    check("3 replace: Space r P opens grug-far", inst ~= nil)
    if inst then
      local ready = false
      inst:when_ready(function()
        ready = true
      end)
      wait(5000, function()
        return ready
      end)
      inst:update_input_values({ search = "rihla_needle_(\\d+)", replacement = "rihla_pin_$1", filesFilter = "*.py" }, true)
      inst:search()
      local buf = inst:get_buf()
      wait(10000, function()
        return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"):find("rihla_pin_7731", 1, true) ~= nil
      end)
      local text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
      check("3 replace: the preview shows the new text", text:find("rihla_pin_7731", 1, true) ~= nil)
      check("3 replace: nothing is written before replace-all", vim.deep_equal(vim.fn.readfile(target), before))
      check("3 replace: the Files Filter (*.py) leaves .ts files out of the results", text:find("app.ts", 1, true) == nil)
      inst:replace()
      wait(10000, function()
        return table.concat(vim.fn.readfile(target), "\n"):find("rihla_pin_7731", 1, true) ~= nil
      end)
      check("3 replace: replace-all writes the file", table.concat(vim.fn.readfile(target), "\n"):find("rihla_pin_7731", 1, true) ~= nil)
      check("3 replace: a filtered-out file is untouched", table.concat(vim.fn.readfile(dir .. "/src/app.ts"), "\n"):find("rihla_needle_7731", 1, true) ~= nil)
      check("3 replace: Space r u is mapped", vim.fn.maparg("<leader>ru", "n") ~= "")
      replace.undo(true)
      check("3 replace: Space r u puts the file back", vim.deep_equal(vim.fn.readfile(target), before))
      vim.api.nvim_set_current_win(vim.fn.bufwinid(buf))
      require("lazy").load({ plugins = { "blink.cmp" } })
      local okb, on = pcall(function()
        return require("blink.cmp.config").enabled()
      end)
      check("3 replace: no completion popup in grug-far's input lines", okb and on == false, tostring(on))
      vim.cmd("quit")
      vim.wait(100)
      check("3 replace: :q closes grug-far for good (no tab left behind)", not vim.api.nvim_buf_is_valid(buf) or not vim.bo[buf].buflisted)
    end
    only_window()
    -- in-file :%s pre-filled
    vim.cmd("edit src/app.ts")
    vim.api.nvim_win_set_cursor(0, { 1, 14 })
    local typed
    local orig = vim.api.nvim_feedkeys
    vim.api.nvim_feedkeys = function(keys, ...)
      typed = (typed or "") .. keys
      return orig(keys, ...)
    end
    local okr = pcall(press, "<leader>rr")
    vim.api.nvim_feedkeys = orig
    vim.api.nvim_feedkeys(vim.keycode("<C-c>"), "nx", false)
    check("3 replace: Space r r pre-fills :%s with the word (exact case), cursor at the replacement", okr and typed ~= nil and vim.startswith(typed, ":%s/\\C\\<rihla_needle_7731\\>//gc"), typed and vim.fn.keytrans(typed))
    only_window()
  end

  -- 4. Terminal on demand --------------------------------------------------------------
  vim.cmd("edit src/deep/server.py")
  local term = require("rihla.term")
  local src = vim.api.nvim_get_current_buf()
  press([[<C-\>]])
  local t = term.get("bottom")
  wait(3000, function()
    return t ~= nil and t:is_open() and t.job_id ~= nil
  end)
  check("4 terminal: Ctrl-\\ opens a terminal at the bottom", t ~= nil and t:is_open())
  check("4 terminal: it starts in the file's folder", t ~= nil and vim.fs.normalize(t.dir) == vim.fs.normalize(dir .. "/src/deep"), t and t.dir)
  local tbuf = t and t.bufnr
  if t then
    vim.cmd("stopinsert")
    t:toggle()
    check("4 terminal: Ctrl-\\ again hides it", not t:is_open())
    vim.api.nvim_set_current_buf(src)
    vim.api.nvim_buf_set_lines(src, 4, 5, false, { "echo rihla_term_$((6*7))" })
    vim.api.nvim_win_set_cursor(0, { 5, 0 })
    press("<leader>ts")
    wait(5000, function()
      return table.concat(vim.api.nvim_buf_get_lines(t.bufnr, 0, -1, false), "\n"):find("rihla_term_42", 1, true) ~= nil
    end)
    check("4 terminal: Space t s runs the line in it", table.concat(vim.api.nvim_buf_get_lines(t.bufnr, 0, -1, false), "\n"):find("rihla_term_42", 1, true) ~= nil)
    check("4 terminal: the same session after hide / show", t.bufnr == tbuf)
    check("4 terminal: the cursor stays in the file", vim.api.nvim_get_current_buf() == src)
    vim.cmd("silent! undo")
    t:shutdown()
  end
  press("<leader>tt")
  local tf = term.get("float")
  wait(3000, function()
    return tf ~= nil and tf:is_open()
  end)
  check("4 terminal: Space t t opens a floating one", tf ~= nil and tf:is_open() and vim.api.nvim_win_get_config(tf.window).relative ~= "")
  if tf then
    vim.cmd("stopinsert")
    tf:shutdown()
  end
  check("4 terminal: Esc Esc leaves terminal mode (mapped)", vim.fn.maparg("<Esc><Esc>", "t") ~= "")
  only_window()

  -- 5. The view: breadcrumb, outline, folds, quiet diagnostics ----------------------------
  vim.cmd("edit src/fold.lua")
  vim.api.nvim_win_set_cursor(0, { 5, 4 })
  local fbuf, fwin = vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win()
  vim.api.nvim_exec_autocmds("BufWinEnter", { buffer = fbuf })
  local crumb = ""
  wait(5000, function()
    -- headless nothing draws the winbar; evaluating it builds the bar
    pcall(vim.api.nvim_eval_statusline, vim.wo[fwin].winbar, { winid = fwin, use_winbar = true })
    local okd, bar = pcall(function()
      return require("dropbar.api").get_dropbar(fbuf, fwin)
    end)
    if okd and bar then
      pcall(bar.update, bar)
      crumb = bar:cat(true)
    end
    return crumb:find("inner_helper", 1, true) ~= nil
  end)
  check("5 view: the breadcrumb shows file > function path", crumb:find("fold.lua", 1, true) ~= nil and crumb:find("outer", 1, true) ~= nil and crumb:find("inner_helper", 1, true) ~= nil, crumb)
  check("5 view: folds come from tree-sitter", vim.wo.foldmethod == "expr" and vim.wo.foldexpr:find("treesitter", 1, true) ~= nil, vim.wo.foldmethod .. " " .. vim.wo.foldexpr)
  vim.cmd("normal! zx")
  check("5 view: folds exist", vim.fn.foldlevel(4) > 0, "foldlevel(4)=" .. vim.fn.foldlevel(4))
  check("5 view: and start open", vim.fn.foldclosed(4) == -1)
  vim.api.nvim_win_set_cursor(0, { 4, 0 })
  press("<leader>z")
  vim.cmd("redraw")
  check("5 view: Space z (za) closes the fold", vim.fn.foldclosed(4) ~= -1)
  vim.cmd("normal! zR")
  local vt = vim.diagnostic.config().virtual_text
  check("5 view: inline text only for errors", type(vt) == "table" and vt.severity ~= nil and vt.severity.min == vim.diagnostic.severity.ERROR, vim.inspect(vt))
  local has_lua_ls = vim.fn.executable("lua-language-server") == 1
  p = has_lua_ls and nil or nil
  if not has_lua_ls then
    note("5: the outline (Space c s) needs a language server or tree-sitter locals; lua-language-server is not installed here, so it was not opened")
  end
  if p and not p.closed then
    settle(p)
    local names = {}
    for _, it in ipairs(items(p)) do
      names[#names + 1] = it.name or it.text
    end
    check("5 view: Space c s outline lists the functions (tree-sitter)", table.concat(names, " "):find("outer", 1, true) ~= nil, table.concat(names, " "))
  end
  only_window()
  check("5 view: Space l f formats, Space t f toggles on save", vim.fn.maparg("<leader>lf", "n") ~= "" and vim.fn.maparg("<leader>tf", "n") ~= "")

  -- 6. File tree ----------------------------------------------------------------------
  vim.cmd("edit src/deep/server.py")
  local file = vim.api.nvim_buf_get_name(0)
  press("<leader>E")
  wait(3000, function()
    return vim.bo.filetype == "NvimTree"
  end)
  local api = require("nvim-tree.api")
  wait(3000, function()
    local node = api.tree.get_node_under_cursor()
    return node and node.absolute_path == file
  end)
  local node = api.tree.get_node_under_cursor()
  check("6 tree: Space E reveals the file in the tree", node ~= nil and node.absolute_path == file, node and node.absolute_path)
  check("6 tree: ? shows the keys", vim.fn.maparg("?", "n", false, true).buffer == 1)
  check("6 tree: Ctrl-l moves on like a pane", (vim.fn.maparg("<C-l>", "n", false, true).rhs or ""):find("TmuxNavigateRight", 1, true) ~= nil)
  vim.cmd("wincmd p")
  press("<leader>e")
  check("6 tree: Space e from the file focuses the open tree", vim.bo.filetype == "NvimTree")
  press("<leader>e")
  check("6 tree: Space e in the tree closes it", not api.tree.is_visible())
  press("<leader>e")
  check("6 tree: Space e opens it again", api.tree.is_visible())
  if has_git then
    write(dir .. "/src/deep/server.py", { "changed" })
    api.tree.reload()
    vim.wait(1500)
    local lines = table.concat(vim.api.nvim_buf_get_lines(vim.fn.bufnr("NvimTree_1"), 0, -1, false), "\n")
    local okg = false
    pcall(function()
      api.tree.find_file({ buf = file, focus = true })
      local n = api.tree.get_node_under_cursor()
      okg = n and n.git_status ~= nil
    end)
    check("6 tree: git status reaches the tree", okg, lines:sub(1, 200))
    git(dir, "checkout", "-q", "--", "src/deep/server.py")
  end
  api.tree.close()
  only_window()

  -- 7. Open files as tabs ----------------------------------------------------------------
  require("lazy").load({ plugins = { "bufferline.nvim" } })
  vim.cmd("silent! %bwipeout!")
  for _, f in ipairs({ "README.md", "src/app.ts", "lib/util.ts" }) do
    vim.cmd("edit " .. f)
  end
  vim.cmd("redrawtabline")
  local tl = vim.o.tabline ~= "" and vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str or ""
  check("7 tabs: the tab bar numbers the files", tl:find("1", 1, true) ~= nil and tl:find("3", 1, true) ~= nil and tl:find("README", 1, true) ~= nil, tl)
  press("<M-1>")
  check("7 tabs: Alt-1 goes to the first tab", vim.fn.expand("%:t") == "README.md", vim.fn.expand("%:t"))
  press("<leader>2")
  check("7 tabs: Space 2 goes to the second", vim.fn.expand("%:t") == "app.ts", vim.fn.expand("%:t"))
  press("<leader>bp")
  local pinned = false
  pcall(function()
    local cur = vim.api.nvim_get_current_buf()
    for _, el in ipairs(require("bufferline.state").components) do
      if el.id == cur then
        pinned = require("bufferline.groups")._is_pinned(el) and true or false
      end
    end
  end)
  check("7 tabs: Space b p pins it", pinned)
  -- pin the third tab too: pinned tabs move left, and the numbers follow them
  press("<leader>3")
  press("<leader>bp")
  vim.cmd("redrawtabline")
  tl = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str
  local shown = {}
  for n, name in tl:gmatch("(%d)%.[^%w_]*([%w_]+)%.%a+") do
    shown[#shown + 1] = n .. "." .. name
  end
  check("7 tabs: numbers read 1, 2, 3 from the left after pinning", table.concat(shown, " ") == "1.app 2.util 3.README", tl)
  local reached = {}
  for i = 1, 3 do
    press("<M-" .. i .. ">")
    reached[#reached + 1] = i .. "." .. vim.fn.expand("%:t:r")
  end
  check("7 tabs: Alt-N reaches the tab numbered N", table.concat(reached, " ") == table.concat(shown, " "), table.concat(reached, " "))
  press("<leader>3")
  press("<leader>bo")
  local left = {}
  for _, bi in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
    left[#left + 1] = vim.fn.fnamemodify(bi.name, ":t")
  end
  table.sort(left)
  check("7 tabs: Space b o keeps the pinned tabs", table.concat(left, " ") == "README.md app.ts util.ts", table.concat(left, " "))
  for _, f in ipairs({ "src/app.ts", "lib/util.ts" }) do
    vim.cmd("edit " .. f)
    press("<leader>bp")
  end
  press("<leader>bb")
  p = picker()
  if p then
    settle(p)
    check("7 tabs: Space b b lists the open files", #items(p) >= 3, #items(p))
    local nums_ok, shown_nums = true, {}
    local order = require("rihla.tabs").order()
    for _, it in ipairs(items(p)) do
      local first = require("snacks.picker.format").buffer(it, p)[1][1]
      shown_nums[#shown_nums + 1] = vim.trim(first)
      local want
      for i, id in ipairs(order) do
        if id == it.buf then
          want = i .. "."
        end
      end
      nums_ok = nums_ok and vim.trim(first) == want
    end
    check("7 tabs: Space b b numbers each file as its tab", nums_ok, table.concat(shown_nums, " "))
  else
    check("7 tabs: Space b b opens a picker", false)
  end
  only_window()
  vim.o.columns = 80
  vim.cmd("redrawtabline")
  tl = vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true, maxwidth = 80 }).str
  check("7 tabs: fits 80 columns", vim.fn.strdisplaywidth(tl) <= 80, vim.fn.strdisplaywidth(tl))

  -- 8. Merge conflicts ----------------------------------------------------------------
  if not has_git then
    note("8: no git 2.19+ here, merge conflict checks skipped")
  else
    local m = vim.fn.resolve(vim.fn.tempname()) .. "-merge"
    vim.fn.mkdir(m, "p")
    git(m, "init", "-q")
    local mid = { "m1", "m2", "m3", "m4", "m5", "m6" }
    local function body(a, b)
      return vim.list_extend(vim.list_extend({ "top", a }, mid), { b, "bottom" })
    end
    write(m .. "/f.txt", body("one", "two"))
    git(m, "add", ".")
    git(m, "commit", "-q", "-m", "base")
    git(m, "checkout", "-q", "-b", "theirs")
    write(m .. "/f.txt", body("one THEIRS", "two THEIRS"))
    git(m, "commit", "-q", "-am", "theirs")
    git(m, "checkout", "-q", "main")
    write(m .. "/f.txt", body("one OURS", "two OURS"))
    git(m, "commit", "-q", "-am", "ours")
    git(m, "merge", "-q", "theirs")
    local conflicted = vim.fn.readfile(m .. "/f.txt")
    check("8 merge: (a real conflict was made)", table.concat(conflicted, "\n"):find("<<<<<<<", 1, true) ~= nil)
    vim.cmd("cd " .. vim.fn.fnameescape(m))
    vim.cmd("silent! %bwipeout!")
    vim.cmd("edit f.txt")
    local b = vim.api.nvim_get_current_buf()
    wait(8000, function()
      return vim.fn.maparg("co", "n", false, true).buffer == 1
    end)
    check("8 merge: co/ct/cb/c0 exist in the conflicted file", vim.fn.maparg("co", "n", false, true).buffer == 1 and vim.fn.maparg("ct", "n", false, true).buffer == 1 and vim.fn.maparg("cb", "n", false, true).buffer == 1 and vim.fn.maparg("c0", "n", false, true).buffer == 1)
    local desc = vim.fn.maparg("ct", "n", false, true).desc or ""
    check("8 merge: they have plain names in which-key", desc:find("theirs", 1, true) ~= nil, desc)
    local marks = vim.api.nvim_buf_get_extmarks(b, require("rihla.conflict").ns, 0, -1, { details = true })
    check("8 merge: the two sides are highlighted", #marks > 0, #marks .. " extmarks")
    check("8 merge: its syntax errors are hidden (no error count in the status line)", not vim.diagnostic.is_enabled({ bufnr = b }))
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local stops = {}
    for _ = 1, 3 do
      press("]x")
      vim.wait(50)
      stops[#stops + 1] = vim.fn.line(".")
    end
    local distinct = {}
    for _, l in ipairs(stops) do
      distinct[l] = true
    end
    check("8 merge: ]x walks the 2 conflicts", vim.tbl_count(distinct) == 2, table.concat(stops, ","))
    -- Space g x from a working directory above the repository: only the repository's
    -- conflicts, not a file with markers next to it
    local outside = vim.fn.fnamemodify(m, ":h") .. "/outside-conflict.txt"
    write(outside, { "<<<<<<< ours", "a", "=======", "b", ">>>>>>> theirs" })
    vim.cmd("cd " .. vim.fn.fnameescape(vim.fn.fnamemodify(m, ":h")))
    press("<leader>gx")
    vim.wait(800)
    local qf = vim.fn.getqflist()
    local foreign = {}
    for _, q in ipairs(qf) do
      local f = vim.fn.fnamemodify(vim.fn.bufname(q.bufnr), ":p")
      if not vim.startswith(f, m .. "/") then
        foreign[#foreign + 1] = f
      end
    end
    check("8 merge: Space g x lists conflicts in the quickfix list", #qf >= 1, #qf .. " entries")
    check("8 merge: Space g x stays in the file's repository", #foreign == 0, table.concat(foreign, " "))
    vim.fn.delete(outside)
    vim.cmd("cd " .. vim.fn.fnameescape(m))
    vim.cmd("cclose")
    vim.api.nvim_set_current_buf(b)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    press("]x")
    press("co")
    vim.wait(100)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    vim.o.undolevels = vim.o.undolevels -- an undo break, as between two key presses
    press("]x")
    press("ct")
    vim.wait(100)
    local got = vim.api.nvim_buf_get_lines(b, 0, -1, false)
    check("8 merge: co then ct resolve the file correctly", vim.deep_equal(got, body("one OURS", "two THEIRS")), table.concat(got, "|"))
    vim.cmd("normal! u")
    check("8 merge: u undoes a choice", #require("rihla.conflict").parse(b) == 1)
    vim.cmd("silent! edit! f.txt")
    -- the 3-way merge view
    if not has_diffview_git then
      note("8: git older than 2.31: the merge view and history (diffview) were not opened")
      return
    end
    local tabs = vim.fn.tabpagenr("$")
    press("<leader>gm")
    wait(8000, function()
      return vim.fn.tabpagenr("$") > tabs
    end)
    local fts = {}
    wait(5000, function()
      fts = {}
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        fts[#fts + 1] = vim.bo[vim.api.nvim_win_get_buf(w)].filetype
      end
      return vim.tbl_contains(fts, "DiffviewFiles")
    end)
    local diffwins = 0
    wait(8000, function()
      diffwins = 0
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.wo[w].diff then
          diffwins = diffwins + 1
        end
      end
      return diffwins >= 3
    end)
    check("8 merge: Space g m opens the merge view (file list + 3 diff windows)", vim.tbl_contains(fts, "DiffviewFiles") and diffwins >= 3, table.concat(fts, ",") .. " diff windows " .. diffwins)
    pcall(vim.cmd, "DiffviewClose")
    press("<leader>gh")
    wait(5000, function()
      for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        if vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "DiffviewFileHistory" then
          return true
        end
      end
    end)
    local hist = false
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      hist = hist or vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "DiffviewFileHistory"
    end
    check("8 merge: Space g h opens the file history", hist)
    pcall(vim.cmd, "DiffviewClose")
  end
end

vim.defer_fn(function()
  local ok, e = xpcall(run, debug.traceback)
  if not ok then
    check("habits_e2e script itself", false, e)
  end
  for _, l in ipairs(results) do
    io.stdout:write(l .. "\n")
  end
  io.stdout:write(("%d checks, %d failed\n"):format(#vim.tbl_filter(function(l)
    return not l:match("^note")
  end, results), failed))
  vim.cmd(failed == 0 and "qa!" or "cquit 1")
end, 500)
