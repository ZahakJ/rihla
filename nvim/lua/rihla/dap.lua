-- Debug adapters. Each adapter is set up only when a debug session starts;
-- if its tool is missing, mason installs it first (debuggers are large, so
-- they are never installed just because a file was opened).
--
--   debugpy   Python              (mason: debugpy, needs python3)
--   codelldb  C, C++, Rust        (mason: codelldb, prebuilt binary)
--   gdb       C, C++, Rust        (system gdb 14+, which speaks DAP natively)
--   delve     Go                  (mason: delve, needs go)
local util = require("rihla.util")
local tools = require("rihla.tools")

local M = {}

local function mason_path(...)
  return table.concat({ tools.mason_root, ... }, "/")
end

local function ask_program()
  return vim.fn.input("Program to debug: ", vim.fn.getcwd() .. "/", "file")
end

local function python_for_project()
  local venv = vim.env.VIRTUAL_ENV or vim.env.CONDA_PREFIX
  if venv and vim.fn.executable(venv .. "/bin/python") == 1 then
    return venv .. "/bin/python"
  end
  for _, d in ipairs({ ".venv", "venv" }) do
    local p = vim.fn.getcwd() .. "/" .. d .. "/bin/python"
    if vim.fn.executable(p) == 1 then
      return p
    end
  end
  return vim.fn.exepath("python3") ~= "" and vim.fn.exepath("python3") or "python"
end

local function gdb_ok()
  if not util.has("gdb") then
    return false
  end
  local v = vim.fn.system({ "gdb", "--version" }):match("(%d+)%.%d+")
  return v and tonumber(v) >= 14
end

-- name -> { ready = fn() -> bool, setup = fn(dap) }
M.adapters = {
  debugpy = {
    ready = function()
      return tools.available("debugpy")
    end,
    setup = function(dap)
      dap.adapters.python = function(cb, config)
        if config.request == "attach" then
          local c = config.connect or {}
          cb({ type = "server", host = c.host or "127.0.0.1", port = c.port or 5678 })
        else
          cb({
            type = "executable",
            command = mason_path("packages", "debugpy", "venv", "bin", "python"),
            args = { "-m", "debugpy.adapter" },
            options = { source_filetype = "python" },
          })
        end
      end
      dap.configurations.python = dap.configurations.python
        or {
          {
            type = "python",
            request = "launch",
            name = "Run this file",
            program = "${file}",
            console = "integratedTerminal",
            pythonPath = python_for_project,
          },
          {
            type = "python",
            request = "launch",
            name = "Run this file with arguments",
            program = "${file}",
            args = function()
              return vim.split(vim.fn.input("Arguments: "), " ", { trimempty = true })
            end,
            console = "integratedTerminal",
            pythonPath = python_for_project,
          },
          {
            type = "python",
            request = "attach",
            name = "Attach to debugpy on localhost:5678",
            connect = { host = "127.0.0.1", port = 5678 },
          },
        }
    end,
    fts = { "python" },
  },
  codelldb = {
    ready = function()
      return tools.available("codelldb")
    end,
    setup = function(dap)
      dap.adapters.codelldb = {
        type = "server",
        port = "${port}",
        executable = { command = vim.fn.exepath("codelldb") ~= "" and vim.fn.exepath("codelldb") or mason_path("bin", "codelldb"), args = { "--port", "${port}" } },
      }
      local cfg = {
        { type = "codelldb", request = "launch", name = "Launch a program", program = ask_program, cwd = "${workspaceFolder}", stopOnEntry = false },
      }
      for _, ft in ipairs({ "c", "cpp", "rust" }) do
        dap.configurations[ft] = dap.configurations[ft] or cfg
      end
    end,
    fts = { "c", "cpp", "rust" },
  },
  gdb = {
    ready = gdb_ok,
    setup = function(dap)
      dap.adapters.gdb = { type = "executable", command = "gdb", args = { "--interpreter=dap", "--eval-command", "set print pretty on" } }
      local cfg = {
        { type = "gdb", request = "launch", name = "Launch a program (gdb)", program = ask_program, cwd = "${workspaceFolder}", stopAtBeginningOfMainSubprogram = false },
      }
      for _, ft in ipairs({ "c", "cpp", "rust" }) do
        dap.configurations[ft] = dap.configurations[ft] or cfg
      end
    end,
    fts = { "c", "cpp", "rust" },
  },
  delve = {
    ready = function()
      return tools.available("delve")
    end,
    setup = function(dap)
      dap.adapters.go = {
        type = "server",
        port = "${port}",
        executable = { command = vim.fn.exepath("dlv") ~= "" and vim.fn.exepath("dlv") or mason_path("bin", "dlv"), args = { "dap", "-l", "127.0.0.1:${port}" } },
      }
      dap.configurations.go = dap.configurations.go
        or {
          { type = "go", name = "Debug this file", request = "launch", program = "${file}" },
          { type = "go", name = "Debug this package", request = "launch", program = "${fileDirname}" },
          { type = "go", name = "Debug tests in this package", request = "launch", mode = "test", program = "${fileDirname}" },
        }
    end,
    fts = { "go" },
  },
}

local configured = {}
--- Make sure an adapter for this file type is set up; cb(ok) when it is.
function M.ensure(ft, cb)
  local dap = require("dap")
  if dap.configurations[ft] and #dap.configurations[ft] > 0 and configured[ft] then
    return cb(true)
  end
  local entry = require("rihla.lang").by_ft[ft]
  local names = entry and entry.dap or {}
  if type(names) == "string" then
    names = { names }
  end
  if #names == 0 then
    if dap.configurations[ft] then
      return cb(true)
    end
    vim.notify(("rihla: no debugger set up for '%s'. Add a dap entry in ~/.config/rihla/langs.lua"):format(ft), vim.log.levels.WARN)
    return cb(false)
  end
  for _, name in ipairs(names) do
    local a = M.adapters[name]
    if a and a.ready() then
      a.setup(dap)
      configured[ft] = true
      return cb(true)
    end
  end
  -- Nothing ready: install the first installable one.
  local reasons = {}
  for _, name in ipairs(names) do
    local a = M.adapters[name]
    local why = tools.blocker(name)
    if a and not why then
      tools.install(name, function(ok, msg)
        if ok then
          a.setup(dap)
          configured[ft] = true
          cb(true)
        else
          vim.notify("rihla: " .. tostring(msg), vim.log.levels.WARN)
          cb(false)
        end
      end)
      return
    end
    reasons[#reasons + 1] = why
  end
  vim.notify(("rihla: no debugger for %s: %s"):format(ft, table.concat(reasons, "; ")), vim.log.levels.WARN)
  cb(false)
end

--- F5: continue a running session, or start one for this file type.
function M.continue()
  local dap = require("dap")
  if dap.session() then
    return dap.continue()
  end
  M.ensure(vim.bo.filetype, function(ok)
    if ok then
      dap.continue()
    end
  end)
end

return M
