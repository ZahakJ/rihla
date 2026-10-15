-- rihla: Neovim entry point.
--
-- Everything lives in lua/rihla/. This file only checks the version and hands
-- over, so a too-old Neovim says so in one line instead of failing halfway.
if vim.fn.has("nvim-0.11") == 0 then
  local v = vim.version()
  vim.api.nvim_echo({
    {
      ("rihla needs Neovim 0.11 or newer; this is %d.%d.%d. Run `rihla install` to get a pinned build in your home directory."):format(
        v.major,
        v.minor,
        v.patch
      ),
      "ErrorMsg",
    },
  }, true, {})
  return
end

-- Leader must be set before any mapping is defined, including plugin ones.
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

require("rihla").setup()
