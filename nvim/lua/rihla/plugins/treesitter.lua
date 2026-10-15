-- Tree-sitter.
--
-- Neovim ships parsers for C, Lua, Markdown, Vimscript, Vim help and queries,
-- and highlights with them out of the box. For other languages a parser has
-- to be compiled, which needs a C compiler and the tree-sitter CLI. The
-- current nvim-treesitter (branch "main") does that and needs Neovim 0.12+.
--
-- What happens on each kind of machine:
--   Neovim 0.12+, C compiler: parsers are built in the background the first
--     time a file type is opened (the CLI comes from mason if missing).
--   no C compiler: one hint, then Vim's regex highlighting; still coloured,
--     just less precise. Parsers copied into ~/.local/share/nvim/site/parser
--     from another machine with the same OS/arch are used as-is.
--   Neovim 0.11: nvim-treesitter is not loaded; bundled parsers only.
-- Starting tree-sitter per buffer is done by lua/rihla/lang.lua.
local util = require("rihla.util")

return require("rihla.spec").wrap({
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false, -- does not support lazy loading; it only adds queries and commands
    cond = util.nvim_at_least(12),
    config = function()
      require("nvim-treesitter").setup({ install_dir = vim.fn.stdpath("data") .. "/site" })
      -- Background parser installs would otherwise print four progress lines
      -- per language ("Downloading... Compiling... Installing..."), which can
      -- stack into a hit-Enter prompt. Keep progress quiet and turn errors into
      -- one rihla hint per language; the full text goes to :Rihla log.
      pcall(function()
        local log = require("nvim-treesitter.log")
        local Logger = log.Logger
        Logger.info = function(self, m, ...)
          util.log(("[treesitter %s] %s"):format(self.ctx or "", m:format(...)))
        end
        local orig_error = Logger.error
        Logger.error = function(self, m, ...)
          local text = m:format(...)
          util.log(("[treesitter %s] error: %s"):format(self.ctx or "", text))
          local lang = (self.ctx or ""):match("install/(.+)")
          if lang then
            util.hint(
              "ts-fail-" .. lang,
              ("tree-sitter parser for %s could not be installed (offline?); using regex highlighting. :Rihla log has details."):format(lang)
            )
            return text
          end
          return orig_error(self, m, ...)
        end
      end)
    end,
  },
})
