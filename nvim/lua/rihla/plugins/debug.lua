-- Debugger: nvim-dap (the protocol client) and nvim-dap-ui (panels for
-- variables, stack, breakpoints and a console). Adapters: lua/rihla/dap.lua.
-- The function keys match VS Code: F5 continue, F9 breakpoint, F10 step
-- over, F11 step into, Shift-F11 step out, Shift-F5 stop.
local icons = require("rihla.icons")

local function dap(fn, ...)
  local args = { ... }
  return function()
    require("dap")[fn](unpack(args))
  end
end
local function cont()
  require("rihla.dap").continue()
end

return require("rihla.spec").wrap({
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      {
        "rcarriga/nvim-dap-ui",
        dependencies = { "nvim-neotest/nvim-nio" },
        config = function()
          local dapui = require("dapui")
          dapui.setup({
            icons = icons.nerd and nil or { expanded = "v", collapsed = ">", current_frame = ">" },
            controls = { enabled = icons.nerd },
            floating = { border = "rounded" },
          })
          local dapm = require("dap")
          dapm.listeners.after.event_initialized["rihla_dapui"] = function()
            dapui.open()
          end
          dapm.listeners.before.event_terminated["rihla_dapui"] = function()
            dapui.close()
          end
          dapm.listeners.before.event_exited["rihla_dapui"] = function()
            dapui.close()
          end
        end,
      },
    },
    keys = {
      { "<F5>", cont, desc = "Debug: start / continue" },
      { "<S-F5>", dap("terminate"), desc = "Debug: stop" },
      { "<F17>", dap("terminate"), desc = "Debug: stop (Shift-F5)" },
      { "<F9>", dap("toggle_breakpoint"), desc = "Debug: toggle breakpoint" },
      { "<F10>", dap("step_over"), desc = "Debug: step over" },
      { "<F11>", dap("step_into"), desc = "Debug: step into" },
      { "<S-F11>", dap("step_out"), desc = "Debug: step out" },
      { "<F23>", dap("step_out"), desc = "Debug: step out (Shift-F11)" },
      { "<leader>dc", cont, desc = "Start / continue (F5)" },
      { "<leader>db", dap("toggle_breakpoint"), desc = "Toggle breakpoint (F9)" },
      {
        "<leader>dB",
        function()
          require("dap").set_breakpoint(vim.fn.input("Break when: "))
        end,
        desc = "Conditional breakpoint",
      },
      {
        "<leader>dL",
        function()
          require("dap").set_breakpoint(nil, nil, vim.fn.input("Log message ({expr} works): "))
        end,
        desc = "Log point (print, don't stop)",
      },
      { "<leader>do", dap("step_over"), desc = "Step over (F10)" },
      { "<leader>di", dap("step_into"), desc = "Step into (F11)" },
      { "<leader>dO", dap("step_out"), desc = "Step out (Shift-F11)" },
      { "<leader>dC", dap("run_to_cursor"), desc = "Run to cursor" },
      { "<leader>dl", dap("run_last"), desc = "Run last configuration again" },
      { "<leader>dt", dap("terminate"), desc = "Terminate (Shift-F5)" },
      {
        "<leader>dr",
        function()
          require("dap").repl.toggle()
        end,
        desc = "Toggle REPL",
      },
      { "<leader>dX", dap("clear_breakpoints"), desc = "Clear all breakpoints" },
      {
        "<leader>du",
        function()
          require("dapui").toggle()
        end,
        desc = "Toggle debugger panels",
      },
      {
        "<leader>de",
        function()
          require("dapui").eval()
        end,
        mode = { "n", "x" },
        desc = "Evaluate expression under cursor",
      },
    },
    config = function()
      local sign = vim.fn.sign_define
      sign("DapBreakpoint", { text = icons.dap.breakpoint, texthl = "DiagnosticError" })
      sign("DapBreakpointCondition", { text = icons.dap.condition, texthl = "DiagnosticWarn" })
      sign("DapBreakpointRejected", { text = icons.dap.rejected, texthl = "DiagnosticHint" })
      sign("DapLogPoint", { text = icons.dap.log, texthl = "DiagnosticInfo" })
      sign("DapStopped", { text = icons.dap.stopped, texthl = "DiagnosticOk", linehl = "Visual" })
      -- Load dap-ui with dap so the panels open on the first session.
      pcall(require, "dapui")
    end,
  },
})
