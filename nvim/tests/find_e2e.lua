-- Fuzzy finding end to end: in a small project, press the real <leader>ff and
-- <leader>fg mappings, type into the picker (snacks.picker), and require that
-- the expected file and line come back. Uses whatever backend this machine has
-- (fd / ripgrep, or the find / grep -r fallbacks). Then search as an IDE user does:
-- another folder, your home and the whole disk, extension / glob / exclude filters
-- changed while the query stays, hidden / ignored / symlink toggles, refining the
-- hits, the selection to the quickfix list, :Grep and :Find, and closing a search
-- of the whole disk leaves no ripgrep running.
--
--   nvim --headless "+luafile nvim/tests/find_e2e.lua"
local results, failed = {}, 0
local function check(name, ok, detail)
  results[#results + 1] = ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, (detail and detail ~= "") and ("  -- " .. detail) or "")
  if not ok then
    failed = failed + 1
  end
end

local function picker()
  local ok, list = pcall(function()
    return Snacks.picker.get({ tab = false })
  end)
  return ok and list[#list] or nil
end

local function settle(p)
  vim.wait(15000, function()
    return not p:is_active()
  end, 50)
  vim.wait(200)
  vim.wait(15000, function()
    return not p:is_active()
  end, 50)
end

--- Type `text` into the open picker (the pattern for files, the live search for
--- grep), wait for it to finish, return the items and close it.
local function picker_results(text)
  local p = picker()
  if not p then
    return nil, "no picker opened"
  end
  if text == nil then
    -- keep what is typed
  elseif p.opts.live then
    p.input.filter.search = text
  else
    p.input.filter.pattern = text
  end
  p:find({ refresh = false })
  settle(p)
  local items = p:items()
  p:close()
  vim.wait(100)
  return items
end

local function press(lhs)
  local m = vim.fn.maparg(lhs, "n", false, true)
  if not m.callback then
    return false
  end
  m.callback()
  return vim.wait(5000, function()
    return picker() ~= nil
  end, 50)
end

local function names(list, base)
  local out = {}
  for _, e in ipairs(list or {}) do
    local f = e.file or ""
    if base and f:sub(1, #base) == base then
      f = f:sub(#base + 1)
    end
    out[#out + 1] = f:gsub("^%./", "") .. (e.pos and (":" .. e.pos[1]) or "")
  end
  table.sort(out)
  return out
end

local function has(list, pat)
  for _, s in ipairs(list) do
    if s:find(pat, 1, true) then
      return true
    end
  end
  return false
end

local function title_of(p)
  local t = {}
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    local c = vim.api.nvim_win_get_config(w)
    if c.relative ~= "" and c.title then
      t[#t + 1] = vim.inspect(c.title)
    end
  end
  return (p.title or "") .. " " .. table.concat(t, " ")
end

--- Answer the next vim.ui.input (the Alt-s prompt) with `text`; returns what it was asked.
local function answer(text)
  local asked = {}
  local orig = vim.ui.input
  vim.ui.input = function(opts, cb)
    vim.ui.input = orig
    asked.default = opts.default
    asked.completion = opts.completion
    cb(text)
  end
  return asked
end

--- Live grep: set the query, wait, return the hits as "path:line" below `base`.
local function hits(p, query, base)
  if query then
    p.input.filter.search = query
  end
  p:find({ refresh = false })
  settle(p)
  return names(p:items(), base)
end

-- Neovim lists child processes with ps; minimal images have none (then the check is skipped).
local function rg_children()
  local n = 0
  local ok, kids = pcall(vim.api.nvim_get_proc_children, vim.fn.getpid())
  for _, pid in ipairs(ok and kids or {}) do
    local okp, info = pcall(vim.api.nvim_get_proc, pid)
    if okp and info and (info.name or ""):match("^rg") then
      n = n + 1
    end
  end
  return n
end

local function power(dir, has_rg)
  local find = require("rihla.find")
  local sep = "/"
  -- A second tree outside the project, as "another repo" or your home would be.
  local other = vim.fn.tempname() .. "-other"
  for _, d in ipairs({ "lib", "tests", "vendor", ".cache", "real" }) do
    vim.fn.mkdir(other .. sep .. d, "p")
  end
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/lib/core.py")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/lib/core.lua")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/lib/core.test.ts")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/lib/core.ts")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/tests/test_core.py")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/vendor/dep.py")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/.cache/cached.py")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/real/linked.py")
  vim.fn.writefile({ "x = 'zq_power_1'" }, other .. "/built.log")
  vim.fn.writefile({ "*.log" }, other .. "/.ignore") -- rg and fd honour .ignore outside git too
  local linked = vim.fn.tempname() .. "-linked"
  vim.fn.mkdir(linked, "p")
  vim.fn.writefile({ "x = 'zq_power_1'" }, linked .. "/far.py")
  pcall(vim.uv.fs_symlink, linked, other .. "/link")
  local base = vim.fn.fnamemodify(other, ":p")

  -- The scope line
  local f = find.parse_filters("src ~ .py *.test.ts !tests/ -t lua -tpy -U --max-depth=3")
  check(
    "scope line: folders, .ext, globs, !excludes, -t types and flags",
    #f.dirs == 2
      and f.dirs[1]:find("/src/$") ~= nil
      and vim.deep_equal(f.exts, { "py" })
      and vim.deep_equal(f.globs, { "*.test.ts" })
      and vim.deep_equal(f.excludes, { "tests/" })
      and vim.deep_equal(f.types, { "lua", "py" })
      and vim.deep_equal(f.args, { "-U", "--max-depth=3" }),
    vim.inspect(f)
  )
  check("scope line: ripgrep globs", vim.deep_equal(find.rg_globs(f), { "*.test.ts", "*.py", "!tests/" }), vim.inspect(find.rg_globs(f)))
  local roots = find.disk_roots()
  local bad = {}
  for _, r in ipairs(roots) do
    if r:match("^/proc") or r:match("^/sys") or r:match("^/dev") or r:match("^/run") then
      bad[#bad + 1] = r
    end
  end
  check("whole disk: searched as its folders and local disks, no /proc /sys /dev /run", #roots > 0 and #bad == 0, table.concat(roots, " "))
  local done = {}
  for _, c in ipairs(_G.rihla_scope_complete("", "src .py " .. other .. "/li")) do
    done[#done + 1] = c
  end
  check("scope prompt: Tab completes the last word as a folder", done[1] == "src .py " .. other .. "/lib/", vim.inspect(done))

  if has_rg then
    -- Another folder, with filters typed in one line, changed while the query stays.
    local p = find.grep({ filters = other .. " .py !tests/ !vendor/" })
    local h = hits(p, "zq_power_\\d", base)
    check("grep in another folder with .py !tests/ !vendor/", vim.deep_equal(h, { ".cache/cached.py:1", "lib/core.py:1", "link/far.py:1", "real/linked.py:1" }), table.concat(h, " "))
    check("grep: the title names the folder and filters", title_of(p):find(".py !tests/ !vendor/", 1, true) ~= nil, title_of(p))
    local asked = answer(other .. " .ts !*.test.ts")
    p:action("set_scope")
    h = hits(p, nil, base)
    check("Alt-s: the prompt starts from the current filters", asked.default == other .. " .py !tests/ !vendor/", vim.inspect(asked.default))
    check("Alt-s: new filters, same query (.ts without *.test.ts)", vim.deep_equal(h, { "lib/core.ts:1" }) and p.input.filter.search == "zq_power_\\d", table.concat(h, " ") .. " / " .. p.input.filter.search)
    answer(other .. " -t lua")
    p:action("set_scope")
    h = hits(p, nil, base)
    check("Alt-s: a ripgrep type (-t lua)", vim.deep_equal(h, { "lib/core.lua:1" }), table.concat(h, " "))
    answer(other .. " .py")
    p:action("set_scope")
    h = hits(p, nil, base)
    check("hidden files and symlinked folders are searched by default", has(h, ".cache/cached.py") and has(h, "link/far.py"), table.concat(h, " "))
    p:action("toggle_hidden")
    h = hits(p, nil, base)
    check("Alt-h leaves hidden files out (and the title says -hidden)", not has(h, ".cache/") and has(h, "lib/core.py") and title_of(p):find("-hidden", 1, true) ~= nil, table.concat(h, " ") .. " | " .. title_of(p))
    p:action("toggle_hidden")
    p:action("toggle_follow")
    h = hits(p, nil, base)
    check("Alt-f stops following symlinks (-links)", not has(h, "link/far.py") and has(h, "lib/core.py") and title_of(p):find("-links", 1, true) ~= nil, table.concat(h, " "))
    p:action("toggle_follow")
    answer(other)
    p:action("set_scope")
    h = hits(p, nil, base)
    local before_ignored = has(h, "built.log")
    p:action("toggle_ignored")
    h = hits(p, nil, base)
    check("ignored files are left out; Alt-i searches them (+ignored)", not before_ignored and has(h, "built.log") and title_of(p):find("+ignored", 1, true) ~= nil, table.concat(h, " "))
    p:action("toggle_ignored")
    -- Fixed string: a regex character taken literally.
    vim.fn.writefile({ "a.b(c" }, other .. "/lib/lit.txt")
    p:action("toggle_regex")
    h = hits(p, "a.b(c", base)
    check("Alt-r: fixed string ('a.b(c' found literally)", vim.deep_equal(h, { "lib/lit.txt:1" }), table.concat(h, " "))
    p:action("toggle_regex")
    -- Refine: Ctrl-g stops the live search and filters the hits fuzzily.
    h = hits(p, "zq_power_1", base)
    local n_all = #h
    p:action("toggle_live")
    p.input.filter.pattern = "file:'core."
    p:find({ refresh = false })
    settle(p)
    h = names(p:items(), base)
    local all_core = #h > 0 and #h < n_all
    for _, x in ipairs(h) do
      all_core = all_core and x:find("core.", 1, true) ~= nil
    end
    check("Ctrl-g refines the hits by file name (file:'core.)", all_core and p.input.filter.search == "zq_power_1", n_all .. " -> " .. table.concat(h, " "))
    -- The selection, not every hit, to the quickfix list.
    p:action("select_and_next")
    p:action("qflist")
    vim.wait(200)
    check("Tab then Ctrl-q: only the selected hit goes to the quickfix list", #vim.fn.getqflist() == 1, #vim.fn.getqflist() .. " entries")
    vim.cmd("cclose")
    for _, q in ipairs(Snacks.picker.get({ tab = false })) do
      q:close()
    end
    vim.wait(100)

    -- Your home: hidden files and symlinks start off; the whole disk searches no pseudo files.
    local real_home = vim.env.HOME
    vim.env.HOME = other
    p = find.grep({ filters = "~ .py" })
    h = hits(p, "zq_power_1", base)
    check("grep in ~: starts without hidden files and symlinks", has(h, "lib/core.py") and not has(h, ".cache/") and not has(h, "link/"), table.concat(h, " "))
    check("grep in ~: the title says ~ and -hidden", title_of(p):find("Grep in ~", 1, true) ~= nil and title_of(p):find("-hidden", 1, true) ~= nil, title_of(p))
    p:close()
    vim.env.HOME = real_home
    vim.wait(100)

    local can_list = vim.fn.has("win32") == 1 or vim.fn.executable("ps") == 1
    local before = can_list and rg_children() or 0
    p = find.grep({ filters = "/", search = "zq_power_never_[0-9]{9}" })
    check("grep in /: the title says /", title_of(p):find("Grep in /", 1, true) ~= nil, title_of(p))
    if can_list then
      local started = vim.wait(5000, function()
        return rg_children() > before
      end, 20)
      p:close()
      local stopped = vim.wait(5000, function()
        return rg_children() <= before
      end, 50)
      check("grep in /: Esc while it runs stops ripgrep", started and stopped, ("started %s, rg left: %d"):format(tostring(started), rg_children()))
    else
      p:close()
      results[#results + 1] = "note  no ps here, so Neovim cannot list child processes; the stop-on-Esc check is skipped"
    end

    -- :Grep with a scope and a query, from the command line (nvim +'Grep ... -- ...').
    vim.cmd("Grep " .. vim.fn.fnameescape(other) .. " .lua -- zq_power")
    p = picker()
    h = p and hits(p, nil, base) or {}
    check(":Grep FOLDER .lua -- QUERY opens the search there", vim.deep_equal(h, { "lib/core.lua:1" }), table.concat(h, " "))
    if p then
      p:close()
    end
  else
    -- No ripgrep: the scope still applies to grep -r.
    find.grep_fallback("zq_power_1", find.parse_filters(other .. " .py !tests/"))
    local qf = {}
    for _, e in ipairs(vim.fn.getqflist()) do
      qf[#qf + 1] = vim.api.nvim_buf_get_name(e.bufnr)
    end
    check("grep -r (no ripgrep): .py and !tests/ apply", #qf > 0 and not has(qf, "tests/") and not has(qf, ".lua"), table.concat(qf, " "))
    vim.cmd("cclose")
  end

  -- Files in another folder, by extension and glob, changed while the name stays.
  local p = find.files({ filters = other .. " .py !tests/" })
  local got = picker_results("core")
  local fl = names(got, base)
  check("find file in another folder: .py, !tests/", has(fl, "lib/core.py") and not has(fl, "core.lua") and not has(fl, "tests/"), table.concat(fl, " "))
  p = find.files({ filters = other .. " *.test.ts" })
  fl = names(picker_results(""), base)
  check("find file: a glob (*.test.ts)", vim.deep_equal(fl, { "lib/core.test.ts" }), table.concat(fl, " "))
  p = find.files({ filters = other .. " .lua" })
  p.input.filter.pattern = "core"
  p:find({ refresh = false })
  settle(p)
  local asked = answer(other .. " .ts")
  p:action("set_scope")
  vim.wait(3000, function()
    local q = picker()
    return q ~= nil and q ~= p
  end)
  local q = picker()
  local kept = q and q.input.filter.pattern or ""
  fl = names(q and picker_results(nil) or {}, base)
  check("Alt-s in find file: new filters, the name typed stays", asked.default == other .. " .lua" and kept == "core" and has(fl, "lib/core.ts") and not has(fl, ".lua"), vim.inspect(asked.default) .. " " .. kept .. " " .. table.concat(fl, " "))
  vim.cmd("Find " .. vim.fn.fnameescape(other) .. " .lua")
  fl = names(picker_results(""), base)
  check(":Find FOLDER .lua lists only Lua files there", vim.deep_equal(fl, { "lib/core.lua" }), table.concat(fl, " "))
end

local function run()
  local dir = vim.fn.tempname() .. "-find"
  vim.fn.mkdir(dir .. "/src/deep", "p")
  vim.fn.writefile({ "def handler(event):", "    return 'rihla_needle_7731'" }, dir .. "/src/deep/server.py")
  vim.fn.writefile({ "nothing here" }, dir .. "/README.md")
  vim.cmd("cd " .. vim.fn.fnameescape(dir))
  require("lazy").load({ plugins = { "snacks.nvim" } })

  local has_rg = vim.fn.executable("rg") == 1
  if has_rg then
    check("grep picker opens (Space f g)", press("<leader>fg"))
    local entries, err = picker_results("rihla_needle_7731")
    local hit = false
    for _, e in ipairs(entries or {}) do
      if (e.file or ""):find("server.py", 1, true) and e.pos and e.pos[1] == 2 then
        hit = true
      end
    end
    check("grep finds the line (ripgrep)", hit, err or (#(entries or {}) .. " result(s)"))
  else
    -- Without ripgrep Space f g asks for a pattern and fills the quickfix list.
    require("rihla.find").grep_fallback("rihla_needle_7731")
    local qf = vim.fn.getqflist()
    local hit = false
    for _, e in ipairs(qf) do
      if vim.api.nvim_buf_get_name(e.bufnr):find("server.py", 1, true) and e.lnum == 2 then
        hit = true
      end
    end
    check("grep finds the line (grep -r into the quickfix list, no ripgrep here)", hit, #qf .. " result(s)")
    vim.cmd("cclose")
  end

  local finder = (vim.fn.executable("fd") == 1 or vim.fn.executable("fdfind") == 1) and "fd"
    or vim.fn.executable("rg") == 1 and "rg --files"
    or "find"
  check("file picker opens (Space f f)", press("<leader>ff"))
  local entries, err = picker_results("servpy")
  local first = entries and entries[1]
  local name = first and first.file or ""
  check(("fuzzy file search ranks src/deep/server.py first (%s)"):format(finder), tostring(name):find("server.py", 1, true) ~= nil, err or tostring(name))
  power(dir, has_rg)
end

vim.defer_fn(function()
  local ok, e = xpcall(run, debug.traceback)
  if not ok then
    check("find_e2e script itself", false, e)
  end
  for _, l in ipairs(results) do
    io.stdout:write(l .. "\n")
  end
  io.stdout:write(("%d checks, %d failed\n"):format(#results, failed))
  vim.cmd(failed == 0 and "qa!" or "cquit 1")
end, 300)
