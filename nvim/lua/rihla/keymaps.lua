-- Core keymaps that need no plugin. Plugin keys live with their plugin in
-- lua/rihla/plugins/*.lua; which-key shows all of them: press Space and wait.
--
-- Rule of thumb: ADD keys, do not change what Vim keys already do, so what you
-- learn here still works on a bare server. The few VS Code keys added below
-- (Ctrl-s, Ctrl-p, F2, F12, Alt-arrows, Ctrl-/) sit on keys Vim leaves idle or
-- that duplicate something trivial, and each has a Vim-native twin that the
-- lessons teach.
local util = require("rihla.util")
local map = util.map

-- Search highlight: Esc clears it (Vim's own way is :noh or Ctrl-l).
map("n", "<Esc>", "<cmd>nohlsearch<CR><Esc>", "Clear search highlight")

-- Keep the cursor centred while paging and stepping through matches.
map("n", "<C-d>", "<C-d>zz", "Half page down (centred)")
map("n", "<C-u>", "<C-u>zz", "Half page up (centred)")
map("n", "n", "'Nn'[v:searchforward].'zv'", "Next match", { expr = true })
map("n", "N", "'nN'[v:searchforward].'zv'", "Previous match", { expr = true })

-- j/k on a wrapped line move by screen line, unless a count is given, so 7j
-- still means "seven real lines down" (relative numbers stay truthful).
map({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", "Down", { expr = true })
map({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", "Up", { expr = true })

-- Stay in visual mode after indenting, so >>> can be repeated.
map("x", "<", "<gv", "Indent left (keep selection)")
map("x", ">", ">gv", "Indent right (keep selection)")

-- VS Code habits on keys Vim leaves free -----------------------------------
map({ "n", "x" }, "<C-s>", "<cmd>write<CR>", "Save file (Vim: :w)")
map("i", "<C-s>", "<Esc><cmd>write<CR>", "Save file and leave insert (Vim: Esc :w)")

-- Alt-j/k (and Alt-Up/Down) move lines, like Alt+Up/Down in VS Code.
-- The Vim way is ddp / ddkP, or :m+1 / :m-2.
for _, k in ipairs({
  { "<A-j>", "<A-Down>", ".+1", "'>+1", "down" },
  { "<A-k>", "<A-Up>", ".-2", "'<-2", "up" },
}) do
  for _, lhs in ipairs({ k[1], k[2] }) do
    map("n", lhs, "<cmd>m " .. k[3] .. "<CR>==", "Move line " .. k[5] .. " (Vim: ddp)")
    map("i", lhs, "<Esc><cmd>m " .. k[3] .. "<CR>==gi", "Move line " .. k[5])
    map("x", lhs, ":<C-u>'<,'>m " .. k[4] .. "<CR>gv=gv", "Move selection " .. k[5])
  end
end

-- Ctrl-/ comments, like VS Code. Terminals send Ctrl-/ as Ctrl-_.
-- The Vim (0.10+) way: gcc for a line, gc + motion, gc in visual mode.
for _, lhs in ipairs({ "<C-/>", "<C-_>" }) do
  map("n", lhs, "gcc", "Toggle comment (Vim: gcc)", { remap = true })
  map("x", lhs, "gc", "Toggle comment (Vim: gc)", { remap = true })
end

-- Paste over a selection without losing what you yanked.
map("x", "<leader>p", [["_dP]], "Paste over selection, keep register")

-- Windows ---------------------------------------------------------------
-- Ctrl-h/j/k/l is owned by vim-tmux-navigator (moves across tmux panes too).
-- Splits use the same keys as the rihla tmux splits: | and -.
map("n", "<leader>|", "<C-w>v", "Split right (Vim: Ctrl-w v)")
map("n", "<leader>-", "<C-w>s", "Split below (Vim: Ctrl-w s)")
map("n", "<leader>wv", "<C-w>v", "Split right (Ctrl-w v)")
map("n", "<leader>ws", "<C-w>s", "Split below (Ctrl-w s)")
map("n", "<leader>wc", "<C-w>c", "Close window (Ctrl-w c)")
map("n", "<leader>wo", "<C-w>o", "Close other windows (Ctrl-w o)")
map("n", "<leader>w=", "<C-w>=", "Equal sizes (Ctrl-w =)")
map("n", "<leader>ww", "<C-w>p", "Previous window (Ctrl-w p)")
map("n", "<leader>wx", "<C-w>x", "Swap with next (Ctrl-w x)")
map("n", "<leader>wm", function()
  require("rihla.ui").zoom()
end, "Maximise / restore window")
map("n", "<C-Up>", "<cmd>resize +2<CR>", "Taller window")
map("n", "<C-Down>", "<cmd>resize -2<CR>", "Shorter window")
map("n", "<C-Left>", "<cmd>vertical resize -2<CR>", "Narrower window")
map("n", "<C-Right>", "<cmd>vertical resize +2<CR>", "Wider window")

-- Buffers -----------------------------------------------------------------
-- Vim 0.11 already has [b and ]b for previous/next buffer; these add names.
-- Space b b (pick an open buffer) and the numbered tabs (Alt-1..9, Space 1..9)
-- are in plugins/find.lua and plugins/ui.lua. The alternate file is Ctrl-^.
map("n", "<leader>ba", "<C-^>", "Alternate buffer: the previous file (Ctrl-^)")
map("n", "<leader>bn", "<cmd>bnext<CR>", "Next buffer (]b)")
if not util.nvim_at_least(11) or vim.fn.maparg("]b", "n") == "" then
  map("n", "]b", "<cmd>bnext<CR>", "Next buffer")
  map("n", "[b", "<cmd>bprevious<CR>", "Previous buffer")
end

-- Folds -------------------------------------------------------------------
-- za toggles the fold under the cursor, zR opens all, zM closes all (Vim's own).
map("n", "<leader>z", "za", "Fold / unfold here (za)")
map("n", "<leader>Z", function()
  vim.wo.foldlevel = vim.wo.foldlevel >= 99 and 0 or 99
end, "Fold / unfold everything (zM / zR)")

-- Quit and sessions ------------------------------------------------------
map("n", "<leader>qq", "<cmd>confirm qall<CR>", "Quit all (asks to save)")

-- Diagnostics (no plugin needed) ------------------------------------------
map("n", "<leader>xd", function()
  vim.diagnostic.open_float({ border = "rounded" })
end, "Line diagnostics (Ctrl-w d)")
map("n", "<leader>xx", function()
  vim.diagnostic.setloclist({ open = true })
end, "Buffer diagnostics -> location list")
map("n", "<leader>xX", function()
  vim.diagnostic.setqflist({ open = true })
end, "All diagnostics -> quickfix")
map("n", "<leader>xq", function()
  local open = false
  for _, w in ipairs(vim.fn.getwininfo()) do
    if w.quickfix == 1 and w.loclist == 0 then
      open = true
    end
  end
  vim.cmd(open and "cclose" or "copen")
end, "Toggle quickfix list")
map("n", "<leader>xl", function()
  local ok = pcall(vim.cmd, vim.fn.getloclist(0, { winid = 0 }).winid ~= 0 and "lclose" or "lopen")
  if not ok then
    vim.notify("Location list is empty", vim.log.levels.INFO)
  end
end, "Toggle location list")
map("n", "]q", "<cmd>cnext<CR>", "Next quickfix item")
map("n", "[q", "<cmd>cprevious<CR>", "Previous quickfix item")

-- Toggles --------------------------------------------------------------------
local function toggle(opt, name)
  return function()
    vim.opt_local[opt] = not vim.opt_local[opt]:get()
    vim.notify(("%s %s"):format(name, vim.opt_local[opt]:get() and "on" or "off"))
  end
end
map("n", "<leader>tw", toggle("wrap", "Wrap"), "Toggle line wrap")
map("n", "<leader>tS", toggle("spell", "Spell check"), "Toggle spell check")
map("n", "<leader>tn", toggle("relativenumber", "Relative numbers"), "Toggle relative numbers")
map("n", "<leader>td", function()
  local on = not vim.diagnostic.is_enabled()
  vim.diagnostic.enable(on)
  vim.notify("Diagnostics " .. (on and "on" or "off"))
end, "Toggle diagnostics")
map("n", "<leader>tv", function()
  local cfg = vim.diagnostic.config() or {}
  local all = type(cfg.virtual_text) == "table" and cfg.virtual_text.severity == nil
  -- errors only (the default) -> every problem -> errors only
  local vt = { spacing = 2, prefix = "", source = "if_many" }
  if not all then
    vim.diagnostic.config({ virtual_text = vt })
    vim.notify("Inline text: every problem")
  else
    vt.severity = { min = vim.diagnostic.severity.ERROR }
    vim.diagnostic.config({ virtual_text = vt })
    vim.notify("Inline text: errors only (warnings and hints: signs in the gutter, Space x x)")
  end
end, "Inline diagnostic text: errors only / all")
map("n", "<leader>ti", function()
  local on = not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
  vim.lsp.inlay_hint.enable(on, { bufnr = 0 })
  vim.notify("Inlay hints " .. (on and "on" or "off"))
end, "Toggle inlay hints")
map("n", "<leader>tf", function()
  vim.g.rihla_format_on_save = not vim.g.rihla_format_on_save
  vim.notify("Format on save " .. (vim.g.rihla_format_on_save and "on (all files)" or "off (all files)"))
end, "Toggle format on save (global)")
map("n", "<leader>tF", function()
  local cur = vim.b.rihla_format_on_save
  if cur == nil then
    cur = vim.g.rihla_format_on_save
  end
  vim.b.rihla_format_on_save = not cur
  vim.notify("Format on save " .. (vim.b.rihla_format_on_save and "on" or "off") .. " (this buffer)")
end, "Toggle format on save (this buffer)")
map("n", "<leader>tz", function()
  require("rihla.ui").zen()
end, "Zen mode (distraction free)")

-- Terminal mode: Esc Esc leaves it (a single Esc goes to the program, which
-- shells and fzf need).
map("t", "<Esc><Esc>", [[<C-\><C-n>]], "Leave terminal mode")

-- Diagnostics in VS Code style F8 / Shift-F8
map("n", "<F8>", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, "Next problem (]d)")
map("n", "<S-F8>", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, "Previous problem ([d)")
