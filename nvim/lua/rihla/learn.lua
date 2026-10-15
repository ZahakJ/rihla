-- The curriculum: docs/learn/NN-*.md. Each lesson is ONE page, read and done in
-- one window, the way Vim's own tutor works: a short instruction, then the text
-- to practise on right under it, then the next instruction. Nothing opens a
-- second window by itself.
--
-- The page you see is your own copy, in stdpath("state")/rihla/lessons/
-- (~/.local/state/nvim/rihla/lessons/), so you can wreck it; the files in the
-- repository never change. Copies save themselves (no "unsaved changes" when you
-- quit), and :Rihla learn reset (Space h r) gives you a fresh one.
--
-- A few lessons need a real code file (LSP, debugging): docs/learn/files/NN-*
-- is copied next to the lesson and opened in the same window with
-- :Rihla learn file (Space h f). Space h h (:Rihla home) always comes back.
--
-- Progress lives in stdpath("state")/rihla/learn.json and survives updates.
local util = require("rihla.util")

local M = {}

M.dir = util.docs .. "/learn"
M.files_dir = M.dir .. "/files"
M.state_file = vim.fn.stdpath("state") .. "/rihla/learn.json"
M.copy_dir = vim.fn.stdpath("state") .. "/rihla/lessons"

--- Lesson ids: "07" is lesson 7; "07b" is a lesson inserted after 7 (lesson
--- 7b), so the numbers of the lessons after it, and everyone's progress, stay
--- the same. Inside, 7b is the number 7.2 (a = .1, b = .2 ...).
function M.parse_id(id)
  local d, letter = tostring(id or ""):match("^0*(%d+)(%a?)$")
  if not d then
    return nil
  end
  local n = tonumber(d)
  if letter ~= "" then
    n = n + (letter:lower():byte() - 96) / 10
  end
  return n
end

--- 7 -> "7", 7.2 -> "7b": how a lesson number is written.
function M.label(n)
  n = tonumber(n) or 0
  local whole = math.floor(n)
  local frac = math.floor((n - whole) * 10 + 0.5)
  return frac > 0 and (whole .. string.char(96 + frac)) or tostring(whole)
end

--- 7 -> "07", 7.2 -> "07b": the prefix of the lesson's file names.
function M.prefix(n)
  local label = M.label(n)
  local d, letter = label:match("^(%d+)(%a?)$")
  return ("%02d%s"):format(tonumber(d), letter)
end

local lessons_cache
--- All lessons: { n = number, label = "7b", file = path, title = string, name = "NN-x.md" }
function M.lessons()
  if lessons_cache then
    return lessons_cache
  end
  local out = {}
  local files = vim.fn.globpath(M.dir, "[0-9][0-9]-*.md", false, true)
  vim.list_extend(files, vim.fn.globpath(M.dir, "[0-9][0-9][a-z]-*.md", false, true))
  for _, f in ipairs(files) do
    local n = M.parse_id(vim.fn.fnamemodify(f, ":t"):match("^(%d+%a?)%-"))
    local title
    for line in io.lines(f) do
      title = line:match("^#%s+(.+)")
      if title then
        break
      end
    end
    title = title and title:gsub("^Lesson%s+%d+%a?:%s*", "") or vim.fn.fnamemodify(f, ":t:r")
    out[#out + 1] = { n = n, label = M.label(n), file = f, title = title, name = vim.fn.fnamemodify(f, ":t") }
  end
  table.sort(out, function(a, b)
    return a.n < b.n
  end)
  lessons_cache = out
  return out
end

function M.get(n)
  for _, l in ipairs(M.lessons()) do
    if l.n == n then
      return l
    end
  end
end

function M.last()
  local all = M.lessons()
  return all[#all] and all[#all].n or 0
end

--- Where lesson n is in the list, counting from 1 (lesson 0 is 1 of 21, 7b is 9).
function M.position(n)
  for i, l in ipairs(M.lessons()) do
    if l.n == n then
      return i
    end
  end
  return 0
end

--- A lesson inserted behind where you are (7b, when you had already finished 7)
--- that you have not done and have not been shown: the first one, or nil.
--- Lessons you skipped on purpose are not inserted ones and never come back.
function M.new_before(s)
  for _, l in ipairs(M.lessons()) do
    local whole = math.floor(l.n)
    if
      l.n ~= whole
      and l.n < s.current
      and s.done[tostring(whole)]
      and not s.done[tostring(l.n)]
      and not s.shown[l.label]
    then
      return l
    end
  end
end

function M.state()
  local s = util.read(M.state_file)
  local ok, t = pcall(vim.json.decode, s or "")
  if not ok or type(t) ~= "table" then
    t = {}
  end
  t.current = tonumber(t.current) or 0
  t.done = type(t.done) == "table" and t.done or {}
  t.copies = type(t.copies) == "table" and t.copies or {}
  t.shown = type(t.shown) == "table" and t.shown or {}
  return t
end

function M.save(t)
  util.write(M.state_file, vim.json.encode(t))
end

function M.current()
  local s = M.state()
  return M.get(s.current) or M.lessons()[1], s
end

--- Has lesson n been marked done? Habit hints only name keys from those lessons.
function M.is_done(n)
  return M.state().done[tostring(n)] ~= nil
end

-- Copies ---------------------------------------------------------------------

local function sha(s)
  return vim.fn.sha256(s or "")
end

function M.copy_path(l)
  return M.copy_dir .. "/" .. l.name
end

--- Is buf one of the lesson copies? Returns the lesson number.
function M.lesson_of(buf)
  local name = vim.api.nvim_buf_get_name(buf or 0)
  if name == "" then
    return nil
  end
  -- Compare resolved paths too: Neovim names the buffer by its real path, so a home
  -- directory reached through a symlink (macOS /var, automounted homes) would not match.
  local uv = vim.uv or vim.loop
  local dirs = { M.copy_dir, uv.fs_realpath(M.copy_dir) }
  local names = { name, uv.fs_realpath(name) }
  for _, d in pairs(dirs) do
    local dir = vim.fs.normalize(d) .. "/"
    for _, f in pairs(names) do
      f = vim.fs.normalize(f)
      if f:sub(1, #dir) == dir then
        return M.parse_id(f:sub(#dir + 1):match("^(%d%d%a?)%-.*%.md$"))
      end
    end
  end
  return nil
end

--- The code files a lesson needs besides its page (docs/learn/files/NN-*).
function M.companions(n)
  return vim.fn.globpath(M.files_dir, M.prefix(n) .. "-*", false, true)
end

--- Make sure the copy of lesson l exists; reset = true replaces it with a fresh one.
--- When the lesson in the repository changed (after `rihla update`) and you never
--- edited your copy, the copy follows it; when you did, you are told once.
function M.ensure_copy(l, reset)
  local src = util.read(l.file) or ""
  local dst = M.copy_path(l)
  local s = M.state()
  local key = tostring(l.n)
  local rec = s.copies[key]
  local exists = vim.fn.filereadable(dst) == 1
  local write = reset or not exists
  if exists and not reset and rec and rec.src ~= sha(src) then
    if sha(util.read(dst)) == rec.copy then
      write = true
    elseif not rec.told then
      rec.told = true
      M.save(s)
      util.say(("Lesson %s has a newer version: Space h r gets it (your notes go)."):format(l.label))
    end
  end
  if write then
    util.write(dst, src)
    s.copies[key] = { src = sha(src), copy = sha(src) }
    M.save(s)
  elseif not rec then
    s.copies[key] = { src = sha(src), copy = sha(util.read(dst)) }
    M.save(s)
  end
  for _, f in ipairs(M.companions(l.n)) do
    local c = M.copy_dir .. "/" .. vim.fn.fnamemodify(f, ":t")
    if reset or vim.fn.filereadable(c) == 0 then
      util.write(c, util.read(f) or "")
    end
  end
  return dst
end

-- The header (winbar) -----------------------------------------------------------

local function set_hl()
  local p = require("rihla.palette")
  vim.api.nvim_set_hl(0, "RihlaLessonBar", { fg = p.text, bg = p.surface0 })
  vim.api.nvim_set_hl(0, "RihlaLessonTitle", { fg = p.crust, bg = p.green, bold = true })
  vim.api.nvim_set_hl(0, "RihlaLessonKey", { fg = p.mauve, bg = p.surface0, bold = true })
end

--- The one-line header of a lesson window: where you are, the next key, how to
--- quit, the way back. Parts drop off from the right on a narrow screen.
function M.winbar()
  local win = vim.g.statusline_winid or vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(win)
  local n = M.lesson_of(buf)
  local l = n and M.get(n)
  if not l then
    return ""
  end
  local width = vim.api.nvim_win_get_width(win)
  -- The first three always fit on an 80-column screen; the rest when there is room.
  local parts = {
    { "next ", "Space h n" },
    { "quit ", "Esc :q" },
    { "lost? ", "Space h h" },
    { "all lessons ", "Space h L" },
    { "keys ", "Space h c" },
  }
  if n == M.last() then
    parts[1] = { "list ", "Space h L" }
    table.remove(parts, 4)
  end
  local essential = 0
  for i = 1, 3 do
    essential = essential + 3 + #parts[i][1] + #parts[i][2]
  end
  local title = (" Lesson %s (%d of %d): %s "):format(l.label, M.position(n), #M.lessons(), l.title)
  local room = math.max(14, width - essential)
  if vim.fn.strdisplaywidth(title) > room then
    title = vim.fn.strcharpart(title, 0, room - 4) .. "... "
  end
  local out = "%#RihlaLessonTitle#" .. title:gsub("%%", "%%%%") .. "%#RihlaLessonBar#"
  local used = vim.fn.strdisplaywidth(title)
  for _, part in ipairs(parts) do
    local w = 3 + #part[1] + #part[2]
    if used + w > width then
      break
    end
    out = out .. "   " .. part[1] .. "%#RihlaLessonKey#" .. part[2] .. "%#RihlaLessonBar#"
    used = used + w
  end
  return out
end

local WINBAR = "%{%v:lua.require'rihla.learn'.winbar()%}"

--- Show or clear the header of win depending on what it shows now.
function M.decorate(win)
  if not vim.api.nvim_win_is_valid(win) then
    return
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local wo = vim.wo[win][0]
  if M.lesson_of(buf) then
    wo.winbar = WINBAR
    wo.wrap = true
    wo.linebreak = true
    wo.conceallevel = 2
    wo.concealcursor = ""
    wo.signcolumn = "no"
    wo.foldenable = false
    vim.w[win].rihla_lesson_bar = true
  elseif vim.w[win].rihla_lesson_bar then
    vim.w[win].rihla_lesson_bar = nil
    wo.winbar = ""
    wo.conceallevel = 0
    wo.foldenable = true
    wo.signcolumn = vim.o.signcolumn
    wo.wrap = vim.go.wrap
    wo.linebreak = vim.go.linebreak
  end
end

-- Saving ---------------------------------------------------------------------

--- Write a lesson copy if it changed. Copies never ask "save changes?".
function M.save_buf(buf)
  if not (vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].modified and M.lesson_of(buf)) then
    return
  end
  vim.api.nvim_buf_call(buf, function()
    pcall(vim.cmd, "silent! lockmarks noautocmd write")
  end)
end

function M.save_all()
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and M.lesson_of(b) then
      M.save_buf(b)
    end
  end
end

local group = vim.api.nvim_create_augroup("rihla_learn", { clear = true })

local function setup_buffer(buf)
  vim.bo[buf].swapfile = false
  vim.bo[buf].buflisted = true
  vim.b[buf].rihla_format_on_save = false
  vim.api.nvim_clear_autocmds({ group = group, buffer = buf })
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertLeave", "BufLeave", "FocusLost" }, {
    group = group,
    buffer = buf,
    callback = function(ev)
      M.save_buf(ev.buf)
    end,
  })
end

-- Windows ----------------------------------------------------------------------

local function is_float(win)
  local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
  return ok and cfg.relative ~= nil and cfg.relative ~= ""
end

--- Close every floating window in this tab (popups, pickers, the terminal float).
function M.close_floats()
  -- An open picker is closed properly, so it does not come back half-drawn.
  if package.loaded["snacks.picker"] then
    pcall(function()
      for _, p in ipairs(Snacks.picker.get({ tab = false })) do
        p:close()
      end
    end)
  end
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if is_float(win) then
      pcall(vim.api.nvim_win_close, win, true)
    end
  end
end

local function normal_windows()
  local n = 0
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if not is_float(win) then
      n = n + 1
    end
  end
  return n
end

--- The line shown when a lesson opens. The keys always fit: on a narrow
--- screen the title goes first (the header at the top has it too).
function M.banner(n, title, columns)
  local keys = "Space h n: next lesson.  :q Enter: quit."
  local room = (columns or vim.o.columns) - 12
  local full = ("Lesson %s: %s.  %s"):format(M.label(n), title, keys)
  if vim.fn.strdisplaywidth(full) <= room then
    return full
  end
  local short = ("Lesson %s.  %s"):format(M.label(n), keys)
  if #short <= room then
    return short
  end
  return "Space h n: next.  :q Enter: quit."
end

--- Close every other window and tab page. Buffers stay loaded ('hidden').
function M.one_window()
  M.save_all()
  pcall(vim.cmd, "silent! tabonly!")
  pcall(vim.cmd, "silent! only!")
  vim.t.rihla_zoomed = nil -- a zoom (Space w m) has nothing left to go back to
  if is_float(0) then
    -- Still in a float nothing could close: start from a plain window.
    pcall(vim.cmd, "noautocmd wincmd p")
  end
end

--- Show lesson n in ONE window. opts.here: always use the current window
--- (used by Space h h, which has just closed the others).
function M.open(n, opts)
  opts = opts or {}
  local l = M.get(n)
  if not l then
    util.say(("rihla: there is no lesson %s. Space h L lists them."):format(M.label(n)), vim.log.levels.WARN)
    return
  end
  local s = M.state()
  s.current = n
  M.save(s)
  local path = M.ensure_copy(l)
  if vim.fn.getcmdwintype() ~= "" then
    -- The command-line window (q:) cannot open files; leave it first.
    pcall(vim.cmd, "quit")
  end
  M.close_floats()
  if not opts.here and (normal_windows() > 1 or vim.fn.tabpagenr("$") > 1) then
    -- One window in one tab, so that :q quits. A new tab would look the same
    -- but :q would only bring the old splits back. Closing windows closes no
    -- file: every buffer stays open (Space f b lists them) and lessons are saved.
    M.one_window()
  end
  local cur = vim.api.nvim_buf_get_name(0)
  if vim.fs.normalize(cur) ~= vim.fs.normalize(path) then
    vim.cmd("noswapfile edit " .. vim.fn.fnameescape(path))
  end
  local buf = vim.api.nvim_get_current_buf()
  setup_buffer(buf)
  M.decorate(vim.api.nvim_get_current_win())
  -- The previous lesson page goes away (saved), so the tab bar along the top
  -- does not fill up with lessons.
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if b ~= buf and vim.api.nvim_buf_is_loaded(b) and M.lesson_of(b) and #vim.fn.win_findbuf(b) == 0 then
      M.save_buf(b)
      pcall(vim.api.nvim_buf_delete, b, {})
    end
  end
  if opts.top then
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
  end
  if #vim.api.nvim_list_uis() > 0 then
    local note = opts.note
    if note and vim.fn.strdisplaywidth(note) > vim.o.columns - 12 then
      note = note:gsub(": [^.]*%.", ".", 1)
    end
    util.say(note or M.banner(n, l.title))
  end
end

--- The panic key (Space h h, :Rihla home): whatever happened, back to the
--- current lesson in one window, in normal mode.
function M.home()
  if vim.fn.getcmdwintype() ~= "" then
    pcall(vim.cmd, "quit")
    return vim.schedule(M.home)
  end
  pcall(vim.cmd, "stopinsert")
  M.close_floats()
  M.one_window()
  local l = M.current()
  M.open(l.n, { here = true })
  pcall(vim.cmd, "nohlsearch")
  if vim.fn.reg_recording() ~= "" then
    -- Stop a macro recording ("recording @q") that started by accident.
    vim.api.nvim_feedkeys("q", "n", false)
  end
end

--- Opt-in: the lesson on the right of what you are editing. Never automatic.
function M.split()
  local l = M.current()
  local path = M.ensure_copy(l)
  vim.cmd("botright vsplit " .. vim.fn.fnameescape(path))
  setup_buffer(vim.api.nvim_get_current_buf())
  M.decorate(vim.api.nvim_get_current_win())
  vim.cmd("vertical resize " .. math.max(50, math.floor(vim.o.columns * 0.45)))
  util.say("Lesson on the right. Ctrl-h / Ctrl-l: move. Space h h: one window.")
end

--- Open the code file a lesson needs, in this same window.
function M.file()
  local l = M.current()
  M.ensure_copy(l)
  local files = M.companions(l.n)
  if #files == 0 then
    util.say(("Lesson %s is all on its page. Space h h shows it."):format(l.label))
    return
  end
  local c = M.copy_dir .. "/" .. vim.fn.fnamemodify(files[1], ":t")
  M.close_floats()
  vim.cmd("noswapfile edit " .. vim.fn.fnameescape(c))
  util.say("Practice file, lesson " .. l.label .. ". Space h h: back to the lesson.")
end

-- The lesson list ------------------------------------------------------------------

local function list_lines()
  local s = M.state()
  local lines = {}
  for _, l in ipairs(M.lessons()) do
    local mark = s.done[tostring(l.n)] and "[x]" or (l.n == s.current and "[>]" or "[ ]")
    lines[#lines + 1] = ("%s %-3s %s"):format(mark, M.prefix(l.n), l.title)
  end
  return lines, s
end

--- `rihla learn list` in the shell: the same list, printed.
function M.print_list()
  local lines = list_lines()
  io.stdout:write(table.concat(lines, "\n") .. "\n")
  io.stdout:write("[x] done  [>] current.  Open one: rihla learn <number>\n")
end

function M.list()
  local lines, s = list_lines()
  local _, buf, win = require("rihla.ui").float_lines(lines, "Lessons: Enter opens, q or Esc closes")
  if not win then
    return
  end
  local cur = 1
  for i, l in ipairs(M.lessons()) do
    if l.n == s.current then
      cur = i
    end
  end
  pcall(vim.api.nvim_win_set_cursor, win, { cur, 0 })
  vim.keymap.set("n", "<CR>", function()
    local n = M.parse_id(vim.api.nvim_get_current_line():match("^%[.%]%s+(%d+%a?)"))
    pcall(vim.api.nvim_win_close, win, true)
    if n then
      M.open(n)
    end
  end, { buffer = buf, nowait = true, desc = "Open this lesson" })
end

-- Commands -----------------------------------------------------------------

--- A message in the editor, or on stdout for `rihla learn done` in the shell.
local function tell(msg)
  if #vim.api.nvim_list_uis() == 0 then
    io.stdout:write(msg .. "\n")
  else
    util.say(msg)
  end
end

local function next_of(n)
  for _, l in ipairs(M.lessons()) do
    if l.n > n then
      return l.n
    end
  end
end

function M.reset()
  local l = M.current()
  local path = M.ensure_copy(l, true)
  local b = vim.fn.bufnr(path)
  if b > 0 and vim.api.nvim_buf_is_loaded(b) then
    vim.api.nvim_buf_call(b, function()
      pcall(vim.cmd, "silent! edit!")
    end)
  end
  if #vim.api.nvim_list_uis() > 0 then
    M.open(l.n, { top = true })
    util.say(("Lesson %s is fresh again: a new copy, your changes are gone."):format(l.label))
  end
end

M.usage = "Usage: :Rihla learn [next|prev|done|list|reset|file|split|<number>]"

function M.command(args)
  local a = args[1]
  local s = M.state()
  if not a then
    -- Progress is kept when a lesson is added (7b came after 7); the first time you
    -- come back past it, it opens once, and Space h n carries on where you were.
    local new = M.new_before(s)
    if new and s.current > 0 then
      s.shown[new.label] = os.date("%Y-%m-%d")
      M.save(s)
      local nxt = next_of(new.n)
      return M.open(new.n, {
        top = true,
        note = ("New lesson %s, added after %s: %s. Space h n: on to lesson %s."):format(
          new.label,
          M.label(math.floor(new.n)),
          new.title,
          M.label(nxt or s.current)
        ),
      })
    end
    return M.open(s.current)
  elseif a == "list" then
    return M.list()
  elseif a == "print" then
    return M.print_list()
  elseif a == "next" or a == "done" then
    s.done[tostring(s.current)] = os.date("%Y-%m-%d")
    local nxt = next_of(s.current)
    if a == "done" or not nxt then
      M.save(s)
      tell(
        nxt and ("Lesson %s marked done. Space h n (or rihla learn next) opens lesson %s."):format(M.label(s.current), M.label(nxt))
          or "That was the last lesson. Well done."
      )
      return
    end
    s.current = nxt
    M.save(s)
    return M.open(nxt, { top = true })
  elseif a == "prev" then
    local prev
    for _, l in ipairs(M.lessons()) do
      if l.n < s.current then
        prev = l.n
      end
    end
    return M.open(prev or s.current)
  elseif a == "reset" then
    return M.reset()
  elseif a == "file" then
    return M.file()
  elseif a == "split" then
    return M.split()
  elseif a == "home" then
    return M.home()
  elseif M.parse_id(a) then
    return M.open(M.parse_id(a))
  else
    tell(M.usage)
  end
end

--- Tips are the "> Tip:" lines in the lessons. The tip of the day comes from
--- lessons up to one past the current one, so it is never far ahead of you.
function M.tips(upto)
  local out = {}
  for _, l in ipairs(M.lessons()) do
    if not upto or l.n <= upto then
      for line in io.lines(l.file) do
        local t = line:match("^>%s*Tip:%s*(.+)")
        if t then
          -- Markdown code spans read fine without their backticks on screen.
          out[#out + 1] = (t:gsub("``%s*(.-)%s*``", "%1"):gsub("`", ""))
        end
      end
    end
  end
  return out
end

function M.tip(random)
  local s = M.state()
  local tips = M.tips(s.current + 1)
  if #tips == 0 then
    tips = M.tips()
  end
  if #tips == 0 then
    return nil
  end
  local i
  if random then
    math.randomseed(os.time())
    i = math.random(#tips)
  else
    i = (tonumber(os.date("%j")) % #tips) + 1
  end
  return tips[i]
end

function M.setup()
  set_hl()
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
  -- The header follows the buffer: it shows on a lesson, and goes when the same
  -- window moves on to another file.
  vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
    group = group,
    callback = function()
      M.decorate(vim.api.nvim_get_current_win())
    end,
  })
  -- A lesson page opened any other way (:e, recent files) is still a lesson page.
  -- (No autocommand pattern: a HOME with spaces would need escaping there.)
  vim.api.nvim_create_autocmd("BufReadPre", {
    group = group,
    callback = function(ev)
      if M.lesson_of(ev.buf) then
        vim.bo[ev.buf].swapfile = false
      end
    end,
  })
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = group,
    callback = function(ev)
      if M.lesson_of(ev.buf) then
        setup_buffer(ev.buf)
      end
    end,
  })
  -- Quitting never asks about a lesson page: it is saved first.
  vim.api.nvim_create_autocmd({ "QuitPre", "ExitPre", "VimLeavePre" }, {
    group = group,
    callback = M.save_all,
  })
end

return M
