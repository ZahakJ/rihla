-- End-to-end debugger check: for each adapter, start a session on a small
-- program with a breakpoint, and require that it stops on that line, that a
-- variable can be evaluated, and that the session ends cleanly.
--
--   nvim --headless "+luafile nvim/tests/dap_e2e.lua"
--   RIHLA_DAP_ADAPTERS=debugpy,codelldb,gdb (default debugpy,codelldb)
--
-- debugpy and codelldb are installed through mason if missing (network needed
-- once); gdb must be 14+ on PATH; the C cases need a C compiler.
local results, failed = {}, 0
local function check(name, ok, detail)
  local line = ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, (detail and detail ~= "") and ("  -- " .. detail) or "")
  results[#results + 1] = line
  io.stderr:write(line .. "\n")
  if not ok then
    failed = failed + 1
  end
end

local function session_case(name, ft, file, lines, bp_line, config, expr, expect)
  local dap = require("dap")
  local rdap = require("rihla.dap")
  local ready = nil
  -- Install this adapter's tool if needed (ensure() alone would stop at the
  -- first adapter that is ready, e.g. a system gdb for C).
  local tools = require("rihla.tools")
  if not rdap.adapters[name].ready() and tools.known[name] and tools.known[name].pkg then
    tools.install(name, function(ok)
      ready = ok
    end)
  else
    ready = rdap.adapters[name].ready()
  end
  vim.wait(600000, function()
    return ready ~= nil
  end, 200)
  if not ready then
    check(name .. ": adapter ready", false)
    return
  end
  -- ensure() may have set up a different adapter for this file type first;
  -- set up the one under test explicitly.
  rdap.adapters[name].setup(dap)
  check(name .. ": adapter ready", true)

  vim.cmd("edit " .. vim.fn.fnameescape(file))
  dap.clear_breakpoints()
  vim.api.nvim_win_set_cursor(0, { bp_line, 0 })
  dap.toggle_breakpoint()
  local stopped_line
  dap.listeners.after.event_stopped["rihla_test"] = function(session, body)
    vim.defer_fn(function()
      local f = session.current_frame
      stopped_line = f and f.line or -1
    end, 300)
  end
  if vim.env.RIHLA_TEST_VERBOSE then
    dap.listeners.after.event_output["rihla_test"] = function(_, body)
      io.stderr:write("output: " .. tostring(body.output))
    end
    dap.listeners.after.event_terminated["rihla_test"] = function()
      io.stderr:write("terminated\n")
    end
  end
  dap.run(config)
  local ok = vim.wait(60000, function()
    return stopped_line ~= nil
  end, 100)
  check(("%s: stopped at breakpoint line %d"):format(name, bp_line), ok and stopped_line == bp_line, tostring(stopped_line))
  if ok then
    local value
    local session = dap.session()
    session:evaluate({ expression = expr, context = "watch" }, function(err, resp)
      if vim.env.RIHLA_TEST_VERBOSE then
        io.stderr:write(vim.inspect({ err = err, resp = resp }) .. "\n")
      end
      value = err and ("error: " .. tostring(err.message or err)) or (resp and resp.result)
    end)
    vim.wait(10000, function()
      return value ~= nil
    end, 100)
    check(("%s: evaluate %s = %s"):format(name, expr, tostring(value)), value ~= nil and tostring(value):find(expect, 1, true) ~= nil)
  end
  dap.terminate()
  local ended = vim.wait(15000, function()
    return dap.session() == nil
  end, 100)
  check(name .. ": session ended", ended)
  dap.listeners.after.event_stopped["rihla_test"] = nil
end

local function run()
  local adapters = vim.split(vim.env.RIHLA_DAP_ADAPTERS or "debugpy,codelldb", ",", { trimempty = true })
  local dir = vim.fn.tempname() .. "-dap"
  vim.fn.mkdir(dir, "p")
  vim.cmd("cd " .. dir)
  pcall(require, "dap") -- load nvim-dap (and dap-ui) through lazy
  for _, name in ipairs(adapters) do
    if name == "debugpy" then
      local file = dir .. "/prog.py"
      vim.fn.writefile({ "def run(n):", "    total = 0", "    for i in range(n):", "        total += i", "    return total", "", "print(run(5))" }, file)
      session_case(name, "python", file, nil, 4, {
        type = "python",
        request = "launch",
        name = "test",
        program = file,
        console = "internalConsole",
      }, "n", "5")
    elseif name == "codelldb" or name == "gdb" then
      local src = dir .. "/prog.c"
      vim.fn.writefile({ "#include <stdio.h>", "int main(void) {", "  int n = 5;", "  int total = 0;", "  for (int i = 0; i < n; i++) total += i;", '  printf("%d\\n", total);', "  return 0;", "}" }, src)
      local cc = vim.fn.exepath("cc") ~= "" and "cc" or "gcc"
      vim.fn.system({ cc, "-g", "-O0", "-o", dir .. "/prog", src })
      if vim.v.shell_error ~= 0 then
        check(name .. ": compile test program", false, "no C compiler?")
      else
        session_case(name, "c", src, nil, 5, {
          type = name,
          request = "launch",
          name = "test",
          program = dir .. "/prog",
          cwd = dir,
        }, "n", "5")
      end
    else
      check(name .. ": known adapter", false)
    end
  end
end

vim.defer_fn(function()
  local ok, err = xpcall(run, debug.traceback)
  if not ok then
    check("dap_e2e script itself", false, err)
  end
  for _, l in ipairs(results) do
    io.stdout:write(l .. "\n")
  end
  io.stdout:write(("%d checks, %d failed\n"):format(#results, failed))
  vim.cmd(failed == 0 and "qa!" or "cquit 1")
end, 500)
