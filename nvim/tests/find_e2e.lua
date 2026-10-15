-- Fuzzy finding end to end: in a small project, press the real <leader>ff and
-- <leader>fg mappings, type into the picker (snacks.picker), and require that
-- the expected file and line come back. Uses whatever backend this machine has
-- (fd / ripgrep, or the find / grep -r fallbacks).
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
  if p.opts.live then
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
