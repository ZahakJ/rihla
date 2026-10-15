-- The terminal on demand (VS Code's Ctrl+`), on top of toggleterm.nvim.
--
-- Three terminals, each its own shell session that survives being hidden:
--   bottom (Ctrl-\ or Space t b), floating (Space t t), right (Space t r).
-- Each starts in the directory of the file you are editing when you first open
-- it (the folder Neovim started in when the buffer has no file), and then stays
-- where you cd'd it. Space t s sends the current line, or the selection, to the
-- terminal you used last and runs it. The shell is your login shell ($SHELL),
-- with your own rc files, so rihla's shell layer is there when you turned it on.
local util = require("rihla.util")

local M = {}

M.terms = {} -- name -> toggleterm Terminal
M.last = "bottom"

local kinds = {
  bottom = { id = 1, direction = "horizontal" },
  float = { id = 2, direction = "float" },
  right = { id = 3, direction = "vertical" },
}

--- The folder a new terminal starts in: the current file's, else the working directory.
function M.start_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name ~= "" and vim.bo.buftype == "" then
    local dir = vim.fn.fnamemodify(name, ":p:h")
    if vim.fn.isdirectory(dir) == 1 then
      return dir
    end
  end
  return vim.fn.getcwd()
end

function M.get(name, create)
  local t = M.terms[name]
  if t and t.bufnr and vim.api.nvim_buf_is_valid(t.bufnr) then
    return t
  end
  if not create then
    return nil
  end
  local Terminal = require("toggleterm.terminal").Terminal
  local k = kinds[name]
  t = Terminal:new({
    count = k.id,
    direction = k.direction,
    dir = M.start_dir(),
    hidden = true, -- not part of :ToggleTerm's numbering
    display_name = name,
    close_on_exit = true,
  })
  M.terms[name] = t
  return t
end

--- Show or hide one of the terminals.
function M.toggle(name)
  local t = M.get(name, true)
  M.last = name
  t:toggle()
end

--- Send the current line (normal mode) or the selected lines (visual mode)
--- to the terminal used last, opening it if needed, and run them.
function M.send(visual)
  local lines
  if visual then
    lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  else
    lines = { vim.api.nvim_get_current_line() }
  end
  lines = vim.tbl_filter(function(l)
    return vim.trim(l) ~= ""
  end, lines)
  if #lines == 0 then
    util.say("Nothing to send: the line is empty.")
    return
  end
  -- Drop the indentation the lines share (an indented shell command in a
  -- README, a block from inside a function): what you see is what runs.
  local indent
  for _, l in ipairs(lines) do
    local n = #l:match("^%s*")
    indent = math.min(indent or n, n)
  end
  for i, l in ipairs(lines) do
    lines[i] = l:sub((indent or 0) + 1)
  end
  local win = vim.api.nvim_get_current_win()
  local t = M.get(M.last, true)
  if not t:is_open() then
    t:open()
  end
  if vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  end
  -- Straight to the shell: toggleterm's own send enters the terminal buffer,
  -- which leaves you typing in the file you came from.
  vim.fn.chansend(t.job_id, table.concat(lines, "\n") .. "\n")
  vim.defer_fn(function()
    if t.window and vim.api.nvim_win_is_valid(t.window) then
      pcall(vim.api.nvim_win_set_cursor, t.window, { vim.api.nvim_buf_line_count(t.bufnr), 0 })
    end
  end, 50)
  vim.cmd("stopinsert")
  -- Opening the terminal queues an "insert mode" for it (toggleterm's
  -- start_in_insert), which can arrive after we are back in the file. Undo it
  -- there, as long as nothing has been typed since.
  local buf = vim.api.nvim_get_current_buf()
  local tick = vim.b[buf].changedtick
  local function guard()
    if vim.api.nvim_get_current_win() == win and vim.fn.mode() == "i" and vim.b[buf].changedtick == tick then
      vim.cmd("stopinsert")
    end
  end
  vim.schedule(guard)
  vim.defer_fn(guard, 100)
  vim.defer_fn(guard, 300)
end

return M
