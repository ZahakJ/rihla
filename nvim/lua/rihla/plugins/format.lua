-- Formatting (conform.nvim) and linting (nvim-lint). Which tool runs for
-- which language comes from lua/rihla/langs.lua. A formatter that is not
-- installed is skipped; the language server's formatter is the fallback.
local util = require("rihla.util")

local function fmt_enabled(buf)
  local b = vim.b[buf].rihla_format_on_save
  if b ~= nil then
    return b
  end
  return vim.g.rihla_format_on_save
end

return require("rihla.spec").wrap({
  {
    "stevearc/conform.nvim",
    event = "BufWritePre",
    cmd = { "ConformInfo" },
    keys = {
      {
        "<leader>lf",
        function()
          require("conform").format({ async = true }, function(err)
            if err then
              vim.notify("rihla: " .. tostring(err):match("^[^\n]*"), vim.log.levels.WARN)
            end
          end)
        end,
        mode = { "n", "x" },
        desc = "Format file / selection",
      },
      { "<leader>lF", "<cmd>ConformInfo<CR>", desc = "Formatter info" },
    },
    init = function()
      -- gq + motion formats with the same formatter (Vim's own operator).
      vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
    end,
    config = function()
      require("conform").setup({
        formatters_by_ft = require("rihla.lang").formatters_by_ft(),
        default_format_opts = { lsp_format = "fallback", timeout_ms = 3000 },
        notify_no_formatters = true,
        format_on_save = function(buf)
          if fmt_enabled(buf) then
            return { timeout_ms = 1500, lsp_format = "fallback" }
          end
        end,
      })
    end,
  },

  {
    "mfussenegger/nvim-lint",
    event = { "BufReadPost", "BufWritePost", "BufNewFile" },
    config = function()
      local lint = require("lint")
      lint.linters_by_ft = require("rihla.lang").linters_by_ft()
      local function run()
        local names = lint.linters_by_ft[vim.bo.filetype]
        if not names or vim.bo.buftype ~= "" then
          return
        end
        local ready = {}
        for _, name in ipairs(names) do
          local l = lint.linters[name]
          local cmd = l and (type(l) == "function" and l().cmd or l.cmd)
          if type(cmd) == "function" then
            cmd = cmd()
          end
          if cmd and util.has(cmd) or require("rihla.tools").available(name) then
            ready[#ready + 1] = name
          end
        end
        if #ready > 0 then
          lint.try_lint(ready)
        end
      end
      vim.api.nvim_create_autocmd({ "BufReadPost", "BufWritePost", "InsertLeave" }, {
        group = vim.api.nvim_create_augroup("rihla_lint", { clear = true }),
        callback = function()
          util.safe("lint", run)
        end,
      })
      run()
    end,
  },
})
