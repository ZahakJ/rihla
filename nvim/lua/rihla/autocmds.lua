-- Autocommands that need no plugin.
local util = require("rihla.util")
local group = vim.api.nvim_create_augroup("rihla", { clear = true })
local au = function(ev, opts)
  opts.group = group
  vim.api.nvim_create_autocmd(ev, opts)
end

-- Flash what was yanked, so you can see what y + motion actually covered.
au("TextYankPost", {
  callback = function()
    (vim.hl or vim.highlight).on_yank({ timeout = 150 })
  end,
})

-- Reopen a file where you left it ('" is Vim's mark for that).
au("BufReadPost", {
  callback = function(ev)
    local ft = vim.bo[ev.buf].filetype
    if ft == "gitcommit" or vim.b[ev.buf].rihla_last_loc then
      return
    end
    vim.b[ev.buf].rihla_last_loc = true
    local mark = vim.api.nvim_buf_get_mark(ev.buf, '"')
    if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(ev.buf) then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- Files changed on disk (git checkout, a formatter in a tmux pane) reload.
au({ "FocusGained", "TermClose", "TermLeave" }, {
  callback = function()
    if vim.o.buftype ~= "nofile" then
      vim.cmd("checktime")
    end
  end,
})

-- Keep splits even when the terminal (or tmux pane) is resized.
au("VimResized", {
  callback = function()
    local tab = vim.fn.tabpagenr()
    vim.cmd("tabdo wincmd =")
    vim.cmd("tabnext " .. tab)
  end,
})

-- q closes helper windows (help, quickfix, man pages, check health).
au("FileType", {
  pattern = { "help", "qf", "man", "checkhealth", "lspinfo", "notify", "dap-float", "fugitiveblame", "git" },
  callback = function(ev)
    vim.bo[ev.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = ev.buf, silent = true, desc = "Close this window" })
  end,
})

-- Create missing parent directories on save (:w new/dir/file.txt just works).
au("BufWritePre", {
  callback = function(ev)
    if ev.match:match("^%w%w+:[\\/][\\/]") then
      return
    end
    local file = (vim.uv or vim.loop).fs_realpath(ev.match) or ev.match
    vim.fn.mkdir(vim.fn.fnamemodify(file, ":p:h"), "p")
  end,
})

-- Without true colour the Catppuccin hex colours cannot be shown. Fall back to
-- habamax, which ships with Neovim and is designed for 256 colours, and say
-- how to get the real theme.
au("UIEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      if not vim.o.termguicolors then
        pcall(vim.cmd.colorscheme, "habamax")
        util.hint(
          "truecolor",
          "no true colour reported, using a 256-colour theme. Has it? export COLORTERM=truecolor"
        )
      end
    end, 300)
  end,
})
-- The terminal may answer the true-colour query late (slow SSH); switch back.
au("OptionSet", {
  pattern = "termguicolors",
  callback = function()
    if vim.o.termguicolors and vim.g.colors_name == "habamax" then
      pcall(vim.cmd.colorscheme, "catppuccin-mocha")
    end
  end,
})

-- Beginner safety nets -------------------------------------------------------------
-- Every popup says how to close it. Plugins' own windows (lazy, mason, check
-- health) get a footer; their q already closes them.
local function footer_for(buf, text)
  vim.schedule(function()
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
      if ok and cfg.relative ~= "" then
        local border = cfg.border
        if border == nil or border == "none" or border == "" or (type(border) == "table" and #border == 0) then
          border = "rounded" -- a footer needs a border to sit on
        end
        pcall(vim.api.nvim_win_set_config, win, { border = border, footer = text, footer_pos = "center" })
      end
    end
  end)
end
au("FileType", {
  pattern = { "lazy", "mason", "checkhealth" },
  callback = function(ev)
    footer_for(ev.buf, " q or Esc closes ")
    if ev.match == "checkhealth" then
      vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = ev.buf, silent = true, desc = "Close this window" })
    end
  end,
})

-- The terminal says how to get out of it: a terminal window keeps every key
-- for the program running in it, which is confusing the first time.
local term_bar = "%#WinBar# Ctrl-\\: hide this terminal   Esc Esc: stop typing in it   Space h h: lesson "
au({ "TermOpen", "BufWinEnter", "WinEnter" }, {
  callback = function()
    local win = vim.api.nvim_get_current_win()
    if vim.bo.buftype ~= "terminal" then
      return
    end
    local cfg = vim.api.nvim_win_get_config(win)
    if cfg.relative ~= "" and cfg.title then
      return -- a titled float (lazygit) says it in its title
    end
    vim.wo[win][0].winbar = term_bar
  end,
})

-- q: (instead of :q) opens the command-line window, a list of old commands.
-- Say what it is and how to leave; :q works there too.
au("CmdwinEnter", {
  callback = function()
    vim.wo.winbar = "%#WinBar# Command history (you typed q: instead of :q).  Close it: :q Enter, or Ctrl-c "
  end,
})

-- Ctrl-z puts Neovim in the background and drops you in the shell, which looks
-- like it closed. Say so in the shell, and how to get back.
au("VimSuspend", {
  callback = function()
    vim.defer_fn(function()
      pcall(vim.api.nvim_chan_send, vim.v.stderr, "\r\nrihla: Neovim is paused in the background (Ctrl-z). Type  fg  and press Enter to go back to it.\r\n")
    end, 200)
  end,
})
