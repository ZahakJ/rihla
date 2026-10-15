-- Small UI helpers: a floating document viewer, window zoom and zen mode.
local M = {}

-- Every popup rihla opens says how to close it, and q or Esc really does.
M.close_hint = " q or Esc closes "

local function close_keys(buf, win)
  for _, k in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", k, function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end, { buffer = buf, nowait = true, desc = "Close this popup" })
  end
end

local function centred(buf, title, width, height)
  local cols, lines = vim.o.columns, vim.o.lines
  width = math.min(width, cols - 4)
  height = math.min(height, lines - 4)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((cols - width) / 2),
    row = math.floor((lines - height) / 2) - 1,
    style = "minimal",
    border = "rounded",
    title = " " .. title .. " ",
    title_pos = "center",
    footer = M.close_hint,
    footer_pos = "center",
  })
  vim.wo[win].winhighlight = "NormalFloat:Normal"
  vim.wo[win].cursorline = true
  close_keys(buf, win)
  return win
end

--- Open a file read-only in a centred float. / searches it, q or Esc closes.
function M.float_file(path, title)
  if vim.fn.filereadable(path) == 0 then
    vim.notify("rihla: cannot read " .. path, vim.log.levels.WARN)
    return
  end
  local buf = vim.fn.bufadd(path)
  vim.fn.bufload(buf)
  vim.bo[buf].buflisted = false
  vim.bo[buf].modifiable = false
  vim.bo[buf].readonly = true
  vim.bo[buf].swapfile = false
  local win = centred(
    buf,
    (title or vim.fn.fnamemodify(path, ":t")) .. "  (/ searches, q or Esc closes)",
    110,
    math.floor(vim.o.lines * 0.85)
  )
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = true
  vim.wo[win].conceallevel = 2
  return win, buf
end

--- Show some lines in a centred float (a scratch buffer). Returns win, buf, win.
function M.float_lines(lines, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  local width = #title + 6
  for _, l in ipairs(lines) do
    width = math.max(width, vim.fn.strdisplaywidth(l) + 4)
  end
  local win = centred(buf, title, width, #lines)
  return win, buf, win
end

--- Toggle "this window takes the whole tab" and back (Ctrl-w o, but undoable).
function M.zoom()
  if vim.t.rihla_zoomed then
    vim.cmd("tabclose")
    return
  end
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    return
  end
  local view = vim.fn.winsaveview()
  vim.cmd("tab split")
  vim.fn.winrestview(view)
  vim.t.rihla_zoomed = true
end

local zen_saved
--- Zen mode: one window, no numbers, no status line, no sign column.
--- Press the key again to leave. Built in, so no plugin is needed for it.
function M.zen()
  if zen_saved then
    for k, v in pairs(zen_saved.global) do
      vim.o[k] = v
    end
    if vim.t.rihla_zen then
      vim.cmd("tabclose")
    end
    zen_saved = nil
    return
  end
  zen_saved = { global = { laststatus = vim.o.laststatus, showtabline = vim.o.showtabline, cmdheight = vim.o.cmdheight } }
  vim.cmd("tab split")
  vim.t.rihla_zen = true
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.signcolumn = "no"
  vim.wo.cursorline = false
  vim.wo.foldcolumn = "0"
  vim.o.laststatus = 0
  vim.o.showtabline = 0
  -- Centre the text with an empty vertical split on each side.
  local width = math.max(0, math.floor((vim.o.columns - 100) / 2))
  if width > 4 then
    for _, side in ipairs({ "topleft", "botright" }) do
      vim.cmd(side .. " vnew")
      vim.bo.buftype = "nofile"
      vim.bo.bufhidden = "wipe"
      vim.wo.number = false
      vim.wo.relativenumber = false
      vim.wo.signcolumn = "no"
      vim.wo.cursorline = false
      vim.wo.statusline = " "
      vim.wo.winhighlight = "Normal:Normal,EndOfBuffer:Normal,WinSeparator:Normal"
      vim.cmd("vertical resize " .. width)
      vim.cmd("wincmd p")
    end
  end
end

--- A closed fold: its first line, then how many lines it hides.
function M.foldtext()
  local first = vim.fn.getline(vim.v.foldstart):gsub("\t", string.rep(" ", vim.bo.tabstop))
  local n = vim.v.foldend - vim.v.foldstart + 1
  return { { first, "Folded" }, { ("  ... %d lines (za opens)"):format(n), "Comment" } }
end

local terms = {}
--- Toggle a floating terminal running `cmd` (lazygit, a REPL...). Needs toggleterm.
function M.float_cmd(cmd)
  if not terms[cmd] then
    local Terminal = require("toggleterm.terminal").Terminal
    terms[cmd] = Terminal:new({
      cmd = cmd,
      direction = "float",
      hidden = true,
      display_name = " " .. cmd .. "  (q quits it) ",
      float_opts = { border = "rounded", title_pos = "center" },
    })
  end
  terms[cmd]:toggle()
end

return M
