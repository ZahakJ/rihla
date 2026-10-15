-- End-to-end LSP check: for each language, open a file in a fresh project,
-- let rihla install the server through mason (network needed the first
-- time), then require that the server attaches, diagnostics arrive, and a
-- completion request returns items.
--
--   nvim --headless "+luafile nvim/tests/lsp_e2e.lua"
--   RIHLA_LSP_LANGS=lua,python (default) chooses the languages.
--   RIHLA_LSP_TIMEOUT=600 seconds allowed for installs (default 600).
--
-- Exits 0 if every language passes, 1 otherwise. One line per check.
local results, failed = {}, 0
local function check(name, ok, detail)
  local line = ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, (detail and detail ~= "") and ("  -- " .. detail) or "")
  results[#results + 1] = line
  io.stderr:write(line .. "\n")
  if not ok then
    failed = failed + 1
  end
end

local cases = {
  lua = {
    file = "main.lua",
    text = {
      "local M = {}",
      "function M.greet(name)",
      '  return "hello " .. name',
      "end",
      "print(undefined_global_xyz)",
      "local s = string.",
      "return M",
    },
    -- completion right after "string."
    complete_at = { 5, 17 },
    expect_item = "format",
    expect_diag = "undefined",
  },
  python = {
    file = "main.py",
    text = {
      "import os",
      "",
      "",
      "def add(a: int, b: int) -> int:",
      "    return a + b",
      "",
      "",
      'add("x", 2)',
      "os.path.",
    },
    complete_at = { 8, 8 },
    expect_item = "join",
    -- the type checker (basedpyright/pyright) reports add("x", 2); pylsp, the
    -- no-Node fallback, does not type-check, so any diagnostic counts there
    expect_diag = "literal",
  },
}

local function run()
  local tools = require("rihla.tools")
  local timeout = (tonumber(vim.env.RIHLA_LSP_TIMEOUT) or 600) * 1000
  local langs = vim.split(vim.env.RIHLA_LSP_LANGS or "lua,python", ",", { trimempty = true })
  vim.g.rihla_auto_install = true

  for _, lang in ipairs(langs) do
    local c = cases[lang]
    if not c then
      check(lang .. ": test case exists", false, "no case for " .. lang)
      goto continue
    end
    local dir = vim.fn.tempname() .. "-" .. lang
    vim.fn.mkdir(dir .. "/.git", "p") -- a root marker, so servers see a project
    vim.fn.writefile(c.text, dir .. "/" .. c.file)
    vim.cmd("cd " .. vim.fn.fnameescape(dir))
    vim.cmd("edit " .. c.file)
    local buf = vim.api.nvim_get_current_buf()
    local t0 = vim.uv.hrtime()

    -- installs started by the FileType handler (deferred 50 ms)
    vim.wait(300)
    tools.wait(timeout)
    -- Wait for a server that can complete (for Python, ruff alone is not enough).
    local attached = vim.wait(60000, function()
      for _, cl in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
        if cl:supports_method("textDocument/completion") then
          return true
        end
      end
      return false
    end, 100)
    local names = vim.tbl_map(function(cl)
      return cl.name
    end, vim.lsp.get_clients({ bufnr = buf }))
    check(lang .. ": server attached", attached, table.concat(names, ","))
    if not attached then
      local hints = {}
      for _, h in pairs(require("rihla.util").hints) do
        hints[#hints + 1] = h
      end
      check(lang .. ": (hints)", false, table.concat(hints, " | "))
      goto continue
    end

    local got_diag = vim.wait(120000, function()
      for _, d in ipairs(vim.diagnostic.get(buf)) do
        local pylsp = #vim.lsp.get_clients({ bufnr = buf, name = "pylsp" }) > 0
        if not c.expect_diag or pylsp or d.message:lower():find(c.expect_diag, 1, true) then
          return true
        end
      end
      return false
    end, 200)
    local msgs = vim.tbl_map(function(d)
      return (d.source or "?") .. ": " .. d.message:gsub("\n.*", "")
    end, vim.diagnostic.get(buf))
    check(lang .. ": diagnostics arrived", got_diag, table.concat(msgs, " | "))

    -- completion, retried while the server indexes
    local items, found = 0, false
    local deadline = vim.uv.now() + 60000
    while vim.uv.now() < deadline and not found do
      local client = vim.lsp.get_clients({ bufnr = buf })[1]
      for _, cl in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
        if cl:supports_method("textDocument/completion") then
          client = cl
          break
        end
      end
      local params = {
        textDocument = { uri = vim.uri_from_bufnr(buf) },
        position = { line = c.complete_at[1], character = c.complete_at[2] },
      }
      local res = client:request_sync("textDocument/completion", params, 20000, buf)
      local list = res and res.result
      local arr = list and (list.items or list) or {}
      items = #arr
      for _, it in ipairs(arr) do
        if it.label and it.label:find(c.expect_item, 1, true) then
          found = true
        end
      end
      if not found then
        vim.wait(2000)
      end
    end
    check(("%s: completion returned items (%d, includes %q)"):format(lang, items, c.expect_item), found)

    local hover = vim.lsp.buf_request_sync(buf, "textDocument/hover", {
      textDocument = { uri = vim.uri_from_bufnr(buf) },
      position = { line = 0, character = 7 },
    }, 15000)
    local hov = false
    for _, r in pairs(hover or {}) do
      if r.result and r.result.contents then
        hov = true
      end
    end
    check(lang .. ": hover answered", hov)
    check(("%s: total %.1f s"):format(lang, (vim.uv.hrtime() - t0) / 1e9), true)
    vim.cmd("cd -")
    ::continue::
  end
end

vim.defer_fn(function()
  local ok, err = xpcall(run, debug.traceback)
  if not ok then
    check("lsp_e2e script itself", false, err)
  end
  for _, l in ipairs(results) do
    io.stdout:write(l .. "\n")
  end
  io.stdout:write(("%d checks, %d failed\n"):format(#results, failed))
  vim.cmd(failed == 0 and "qa!" or "cquit 1")
end, 500)
