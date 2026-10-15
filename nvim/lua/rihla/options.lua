-- Editor behaviour. Nothing here loads a plugin.
local o = vim.opt
local util = require("rihla.util")
local icons = require("rihla.icons")

-- Remote-plugin providers: no plugin here uses them, and probing for a Python
-- host costs ~80 ms the first time a .py file opens.
for _, p in ipairs({ "python3", "ruby", "perl", "node" }) do
  vim.g["loaded_" .. p .. "_provider"] = 0
end

-- Proxy: GNU wget reads only the lowercase variables, curl both. mason, lazy and the
-- tree-sitter CLI run whichever of the two is installed, so mirror what the user set
-- (either case) into the other, the same as bin/rihla does for the installer.
for _, n in ipairs({ "https_proxy", "http_proxy", "no_proxy" }) do
  local lo, up = vim.env[n], vim.env[n:upper()]
  if (lo == nil or lo == "") and up and up ~= "" then
    vim.env[n] = up
  elseif (up == nil or up == "") and lo and lo ~= "" then
    vim.env[n:upper()] = lo
  end
end

-- :checkhealth (and :Rihla check) in a float that q closes, not in a new tab.
vim.g.health = { style = "float" }

o.number = true
o.relativenumber = true -- 5j / 12k become readable at a glance; lesson 2 leans on this
o.signcolumn = "yes" -- stop the text jumping sideways when a sign appears
o.cursorline = true
o.scrolloff = 8
o.sidescrolloff = 8
o.wrap = false
o.showmode = false -- the status line already shows the mode
o.laststatus = 3 -- one status line for the whole screen, like VS Code
o.pumheight = 12
o.winminwidth = 5
o.fillchars = { eob = " ", fold = " ", foldopen = "v", foldclose = ">", foldsep = " " }
o.list = true
o.listchars = { tab = "> ", trail = "·", nbsp = "+" }

o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.smartindent = true
o.shiftround = true

o.ignorecase = true
o.smartcase = true -- a capital letter in the search makes it case-sensitive
o.inccommand = "split" -- live preview of :%s/// in a split; lesson 6

o.splitright = true
o.splitbelow = true

o.undofile = true -- undo survives closing the file
o.swapfile = false
o.updatetime = 250
o.timeoutlen = 400 -- which-key appears after this many ms
o.mouse = "a" -- the mouse works; nobody is punished on day one
o.confirm = true -- ask rather than refuse to quit with unsaved changes
o.virtualedit = "block"
o.completeopt = { "menu", "menuone", "noselect" }
o.shortmess:append({ I = true, c = true, W = true })
o.jumpoptions = "view"
-- Folds: from tree-sitter when the file type has a parser (lang.lua), from the
-- language server when it offers them (plugins/lsp.lua), else by indent. They
-- exist from the start (za / Space z toggles one, zM / zR all) but start open.
o.foldlevel = 99
o.foldlevelstart = 99
o.foldmethod = "indent"
o.foldtext = "v:lua.require'rihla.ui'.foldtext()"
o.sessionoptions = { "buffers", "curdir", "tabpages", "winsize", "help", "globals", "skiprtp", "folds" }
o.wildmode = "longest:full,full"
o.grepprg = util.has("rg") and "rg --vimgrep --smart-case" or o.grepprg:get()
o.grepformat = "%f:%l:%c:%m,%f:%l:%m"

if not icons.nerd then
  -- Folding markers and the like already use ASCII above; nothing else to do.
  o.fillchars:append({ diff = "-" })
end

-- Prose is wrapped; code is not.
vim.api.nvim_create_autocmd("FileType", {
  group = vim.api.nvim_create_augroup("rihla_prose", { clear = true }),
  pattern = { "markdown", "text", "gitcommit" },
  callback = function()
    vim.opt_local.wrap = true
    vim.opt_local.linebreak = true
  end,
})

-- Clipboard. Yank goes to the system clipboard, like VS Code. Deciding which
-- provider exists runs external checks, so it is deferred past startup.
-- Over SSH with no clipboard tool, OSC 52 sends the yank through the terminal
-- (and through tmux with set-clipboard on) to your local clipboard.
vim.schedule(function()
  local function ssh()
    return vim.env.SSH_TTY ~= nil or vim.env.SSH_CONNECTION ~= nil
  end
  -- has('clipboard') asks the provider, which looks for wl-copy, xclip, pbcopy...
  local has_provider = vim.fn.has("clipboard") == 1
  if not has_provider and (ssh() or vim.env.TMUX) and vim.g.clipboard == nil then
    local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
    if ok then
      -- Many terminals refuse OSC 52 *reads* or ask for permission each time,
      -- so paste comes from the unnamed register instead of blocking.
      local function paste()
        return { vim.fn.split(vim.fn.getreg(""), "\n"), vim.fn.getregtype("") }
      end
      vim.g.clipboard = {
        name = "OSC 52 (rihla)",
        copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
        paste = { ["+"] = paste, ["*"] = paste },
      }
      has_provider = true
    end
  end
  if has_provider and not vim.g.rihla_no_system_clipboard then
    vim.opt.clipboard = "unnamedplus"
  elseif not has_provider then
    util.hint(
      "clipboard",
      "no clipboard tool found: yank stays inside Neovim. Install wl-clipboard or xclip (or use SSH/tmux for OSC 52).",
      vim.log.levels.DEBUG
    )
  end
end)
