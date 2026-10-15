-- The learning mode's promises to a beginner, checked headless:
--
--   nvim --headless "+luafile nvim/tests/learn.lua"   (or nvim/tests/run.sh learn)
--
--   * a lesson opens in ONE window, with no floating window, by every entry point:
--     the shell (`rihla learn` runs nvim "+Rihla learn"), :Rihla learn, the keys,
--     the dashboard, next / previous / list, and from a screen that already had splits
--   * Space h h (:Rihla home) gets back to the lesson, one window, normal mode, from a
--     mess of splits, tabs, popups, a picker or a macro recording
--   * lessons are copies under stdpath("state"); the repository files never change
--   * quitting from a changed lesson needs no "!" and keeps the change
--   * every popup rihla opens says how to close it, and q (Esc for pickers) closes it
--   * the first screen of lesson 0 says how to quit, come back, move and go on
--   * the lesson header names the lesson, the next key, quit, and the way back
--   * habit hints only name keys from lessons marked done
--   * the old name of the check command appears nowhere in the tree
--
-- Uses its own state directory, so your progress is untouched.
local results, failed, notes = {}, 0, {}
local function check(name, ok, detail)
  detail = detail and tostring(detail):gsub("%s*\n%s*", " ") or nil
  results[#results + 1] = ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, (detail and detail ~= "") and ("  -- " .. detail) or "")
  if not ok then
    failed = failed + 1
  end
end

local util = require("rihla.util")
local learn = require("rihla.learn")
vim.g.rihla_auto_install = false

-- A private state directory for this process and the child processes below.
local state = vim.fn.tempname() .. "-state"
vim.fn.mkdir(state .. "/nvim/rihla", "p")
learn.state_file = state .. "/nvim/rihla/learn.json"
learn.copy_dir = state .. "/nvim/rihla/lessons"

local function wins()
  local normal, floats = 0, 0
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.api.nvim_win_get_config(w).relative ~= "" then
      floats = floats + 1
    else
      normal = normal + 1
    end
  end
  return normal, floats
end

local function one_window(label)
  local n, f = wins()
  local ln = learn.lesson_of(vim.api.nvim_get_current_buf())
  check(
    ("one window: %s"):format(label),
    n == 1 and f == 0 and ln ~= nil,
    ("windows=%d floats=%d lesson=%s buf=%s"):format(n, f, tostring(ln), vim.api.nvim_buf_get_name(0))
  )
end

-- Start every case from one plain window in one tab.
local function fresh()
  pcall(vim.cmd, "silent! only!")
  pcall(vim.cmd, "silent! tabonly!")
  vim.cmd("enew!")
end

local function keymap(lhs)
  return vim.fn.maparg(lhs, "n", false, true)
end

local function press(lhs)
  local m = keymap(lhs)
  if m.callback then
    m.callback()
  else
    vim.api.nvim_feedkeys(vim.keycode(lhs), "mx", false)
  end
end

local function feed(keys)
  vim.api.nvim_feedkeys(vim.keycode(keys), "mtx", false)
end

local function digest(dir)
  local out = {}
  for name, kind in vim.fs.dir(dir, { depth = 5 }) do
    if kind == "file" then
      out[#out + 1] = name .. "=" .. vim.fn.sha256(util.read(dir .. "/" .. name) or "")
    end
  end
  table.sort(out)
  return table.concat(out, "\n")
end

local function child(cmds)
  local args = { vim.v.progpath, "--headless" }
  for _, c in ipairs(cmds) do
    args[#args + 1] = "+" .. c
  end
  local env = { XDG_STATE_HOME = state }
  local r = vim.system(args, { env = env, text = true, timeout = 60000 }):wait()
  return r
end

local function run()
  local repo_before = digest(learn.dir)
  local lessons = learn.lessons()
  check(("lessons: %d found, numbered from 0"):format(#lessons), #lessons >= 20 and lessons[1].n == 0)

  -- Lesson 7b sits between 7 and 8 without renumbering anything -----------------
  local order = {}
  for _, l in ipairs(lessons) do
    order[#order + 1] = l.label or learn.label(l.n)
  end
  local joined = " " .. table.concat(order, " ") .. " "
  check("7b: listed between 7 and 8", joined:find(" 7 7b 8 ", 1, true) ~= nil, joined)
  check("7b: ids read both ways", learn.parse_id("07b") == learn.parse_id("7b") and learn.label(learn.parse_id("7b")) == "7b" and learn.parse_id("12") == 12)
  local saved = vim.deepcopy(learn.state())
  learn.save({ current = 7, done = { ["6"] = "x" }, copies = {} })
  vim.cmd("Rihla learn next")
  check("7b: next from 7 opens 7b", learn.state().current == learn.parse_id("7b") and learn.lesson_of(0) == learn.parse_id("7b"), learn.state().current)
  check("7b: progress keeps 7 as done", learn.state().done["7"] ~= nil)
  local comp = learn.companions(learn.parse_id("7b"))
  local copied = #comp > 0
  for _, f in ipairs(comp) do
    copied = copied and vim.fn.filereadable(learn.copy_dir .. "/" .. vim.fn.fnamemodify(f, ":t")) == 1
  end
  check("7b: its practice files are copied next to the page", copied, #comp .. " file(s)")
  vim.cmd("Rihla learn next")
  check("7b: next from 7b opens 8", learn.state().current == 8 and learn.lesson_of(0) == 8, learn.state().current)
  vim.cmd("Rihla learn 7b")
  check("7b: :Rihla learn 7b opens it", learn.lesson_of(0) == learn.parse_id("7b"))
  local bar = vim.api.nvim_eval_statusline(learn.winbar(), { use_winbar = true }).str
  check("7b: the header says Lesson 7b", bar:find("Lesson 7b (", 1, true) ~= nil, bar)
  check("7b: the header counts every lesson", bar:find(("(%d of %d)"):format(learn.position(learn.parse_id("7b")), #lessons), 1, true) ~= nil and learn.position(learn.parse_id("7b")) == 9, bar)
  -- Someone who had finished lesson 7 before 7b existed: `rihla learn` shows 7b once,
  -- then Space h n carries on at 8, and the next `rihla learn` opens 8.
  local done_to_7 = {}
  for i = 0, 7 do
    done_to_7[tostring(i)] = "x"
  end
  learn.save({ current = 8, done = done_to_7, copies = {} })
  vim.cmd("Rihla learn")
  check("7b: an old progress past 7 is shown the new lesson 7b once", learn.lesson_of(0) == learn.parse_id("7b"), learn.lesson_of(0))
  vim.cmd("Rihla learn next")
  check("7b: Space h n from it goes on to 8", learn.lesson_of(0) == 8, learn.lesson_of(0))
  vim.cmd("Rihla learn")
  check("7b: the next `rihla learn` opens 8", learn.lesson_of(0) == 8, learn.lesson_of(0))
  learn.save({ current = 8, done = done_to_7, copies = {}, shown = { ["7b"] = "x" } })
  vim.cmd("Rihla learn")
  check("7b: once shown, it does not come back", learn.lesson_of(0) == 8, learn.lesson_of(0))
  learn.save({ current = 12, done = { ["0"] = "x" }, copies = {} })
  vim.cmd("Rihla learn")
  check("7b: lessons skipped on purpose are not brought back", learn.lesson_of(0) == 12, learn.lesson_of(0))
  learn.save(saved)

  -- Lesson 0, first screen -------------------------------------------------------
  local first = {}
  for line in io.lines(learn.get(0).file) do
    first[#first + 1] = line
    if #first == 20 then
      break
    end
  end
  local screen = table.concat(first, "\n")
  local need = {
    { "quit", "To quit" },
    { "press Esc first", "`Esc`, then type `:q`" },
    { "unsaved changes", "Save changes?" },
    { "E37 and :q!", "`:q!`" },
    { "come back with rihla learn", "`rihla learn`" },
    { "command not found: open a new terminal", "open a\n  new one" },
    { "move with j / k", "`j` moves down" },
    { "arrow keys and mouse wheel", "mouse wheel" },
    { "next lesson key", "To go to the next lesson:** press `Space`, then `h`, then `n`" },
    { "the panic key", "`Space` `h` `h`" },
  }
  for _, n in ipairs(need) do
    check("lesson 0 first screen (20 lines): " .. n[1], screen:find(n[2], 1, true) ~= nil)
  end
  check("lesson 0: the quit instructions come first", (screen:find("To quit", 1, true) or 99) < 40)

  -- Nothing in the lessons assumes two windows ----------------------------------------
  local leaks = {}
  for _, l in ipairs(lessons) do
    local text = (util.read(l.file) or ""):lower()
    for _, pat in ipairs({ "left window", "right window", "lesson right", "practice left", "on the left (", "lesson on the right", "opens with it", "the practice file on the" }) do
      if text:find(pat, 1, true) then
        leaks[#leaks + 1] = l.name .. ": " .. pat
      end
    end
  end
  check("lessons: no two-window wording", #leaks == 0, table.concat(leaks, "; "))

  -- Entry points ---------------------------------------------------------------------
  fresh()
  vim.cmd("Rihla learn")
  one_window(":Rihla learn")
  local copy = vim.api.nvim_buf_get_name(0)
  check(
    "copy: lives under the state dir, not the checkout",
    learn.lesson_of(vim.fn.bufnr(copy)) ~= nil and not vim.startswith(copy, util.root)
  )
  check("copy: no swap file", vim.bo.swapfile == false)
  local bar = vim.api.nvim_eval_statusline(vim.wo.winbar, { winid = 0, use_winbar = true }).str
  for _, part in ipairs({ "Lesson 0 (1 of", "Space h n", ":q", "Space h h" }) do
    check(("header at %d columns shows %q"):format(vim.o.columns, part), bar:find(part, 1, true) ~= nil, bar)
  end

  fresh()
  press("<leader>hl")
  one_window("Space h l")

  fresh()
  press("<leader>hn")
  one_window("Space h n (next)")
  check("next: moved to lesson 1 and marked 0 done", learn.state().current == 1 and learn.is_done(0))
  press("<leader>hp")
  one_window("Space h p (previous)")
  check("previous: back at lesson 0", learn.state().current == 0)
  vim.cmd("Rihla learn next")
  one_window(":Rihla learn next")
  vim.cmd("Rihla learn prev")
  one_window(":Rihla learn prev")
  vim.cmd("Rihla learn 3")
  one_window(":Rihla learn 3")

  -- The list: a popup that says how to close it; Enter opens the lesson in one window.
  fresh()
  press("<leader>hL")
  local _, f = wins()
  local cfg = vim.api.nvim_win_get_config(0)
  check("list: opens as a popup", f == 1 and cfg.relative ~= "")
  vim.api.nvim_win_set_cursor(0, { 3, 0 }) -- lesson 2
  feed("<CR>")
  one_window("lesson list, Enter")
  check("list: Enter opened lesson 2", learn.state().current == 2)

  -- From a screen that already has splits and a popup: one window in one tab, so
  -- that :q quits (a new tab would look the same, but :q would bring the splits back).
  fresh()
  vim.cmd("vsplit | split")
  require("rihla.ui").float_file(util.docs .. "/cheatsheet-nvim.md", "cheat")
  press("<leader>hl")
  one_window("Space h l from three splits and a popup")
  check("Space h l from splits: one tab", vim.fn.tabpagenr("$") == 1, vim.fn.tabpagenr("$"))
  fresh()
  vim.cmd("vsplit")
  press("<leader>hn")
  one_window("Space h n from two splits (lesson 8)")
  check("Space h n from splits: one tab", vim.fn.tabpagenr("$") == 1, vim.fn.tabpagenr("$"))
  fresh()
  vim.cmd("vsplit")
  require("rihla.ui").zoom()
  press("<leader>hp")
  one_window("Space h p from a zoomed split (Space w m)")
  check("Space h p from a zoom: one tab, zoom forgotten", vim.fn.tabpagenr("$") == 1 and vim.t.rihla_zoomed == nil)
  for _, entry in ipairs({ "Rihla learn", "Rihla learn next", "Rihla learn prev" }) do
    local rq = child({ "Rihla learn 8", "vsplit", entry, "q" })
    check(("quit: :q right after :%s from a split exits"):format(entry), rq.code == 0, ("code=%s signal=%s"):format(rq.code, rq.signal))
  end

  -- The dashboard: lessons and quit first; a wrong key explains instead of failing.
  fresh()
  vim.cmd("tabnew")
  require("rihla.dashboard").open()
  local dash = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  local pos = {}
  for i, l in ipairs(dash) do
    for _, k in ipairs({ "lesson", "Quit", "Find file" }) do
      if not pos[k] and l:find(k, 1, true) and l:match("^%s+%a   ") then
        pos[k] = i
      end
    end
  end
  check(
    "dashboard: the lessons and Quit are the first two entries",
    pos.lesson and pos.Quit and pos["Find file"] and pos.lesson < pos.Quit and pos.Quit < pos["Find file"],
    vim.inspect(pos)
  )
  vim.v.errmsg = ""
  feed("i")
  check("dashboard: a wrong key (i) gives no error and stays in normal mode", vim.v.errmsg == "" and vim.api.nvim_get_mode().mode == "n", vim.v.errmsg)
  feed("l")
  feed("") -- run what the dashboard key queued
  one_window("dashboard l")
  pcall(vim.cmd, "silent! tabonly!")

  -- The shell: `rihla learn` runs nvim "+Rihla learn".
  local r = child({
    "Rihla learn",
    [[lua local n,f=0,0 for _,w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do if vim.api.nvim_win_get_config(w).relative~='' then f=f+1 else n=n+1 end end io.stdout:write(('%d %d %s'):format(n,f,vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0),':t')))]],
    "qa!",
  })
  check("one window: the shell (nvim +'Rihla learn')", r.code == 0 and (r.stdout or ""):match("^1 0 %d%d%a?%-.*%.md$") ~= nil, (r.stdout or "") .. (r.stderr or ""))
  r = child({ "Rihla learn print", "qa" })
  check("shell: rihla learn list prints the lessons", r.code == 0 and (r.stdout or ""):find("00  Start here", 1, true) ~= nil, r.stdout)

  -- Quitting a changed lesson: no "!", nothing lost --------------------------------------
  local l1 = learn.get(1)
  local orig = vim.split(util.read(l1.file), "\n")
  r = child({ "Rihla learn 1", "normal! ggdd", "q" })
  local after = vim.split(util.read(learn.copy_dir .. "/" .. l1.name) or "", "\n")
  check("quit: :q after an edit exits without '!'", r.code == 0, ("code=%s signal=%s %s"):format(r.code, r.signal, r.stderr or ""))
  check("quit: the edit was kept", #after == #orig - 1 and after[1] ~= orig[1])
  r = child({ "Rihla learn 1", "normal! ggiKEPT ", "qa" })
  after = vim.split(util.read(learn.copy_dir .. "/" .. l1.name) or "", "\n")
  check("quit: :qa after typing exits and keeps it", r.code == 0 and vim.startswith(after[1] or "", "KEPT "), after[1])
  r = child({ "Rihla learn 1", "normal! ggdd", "confirm qa" })
  check("quit: Space q q (:confirm qa) asks nothing", r.code == 0, r.stderr)

  -- Reset gives the original back.
  vim.cmd("Rihla learn 1")
  vim.cmd("Rihla learn reset")
  local reset = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  check("reset: the page is the original again", reset[1] == orig[1] and #reset == #orig - (orig[#orig] == "" and 1 or 0))
  one_window(":Rihla learn reset")

  -- Space h h, the panic key ------------------------------------------------------------
  fresh()
  vim.cmd("Rihla learn 2")
  vim.cmd("tabnew | vsplit | split")
  feed("qq") -- start recording a macro by accident
  check("home: (a recording is running)", vim.fn.reg_recording() == "q")
  require("rihla.ui").float_file(util.docs .. "/cheatsheet-nvim.md", "cheat")
  press("<leader>hh")
  feed("")
  one_window("Space h h from tabs, splits, a popup and a recording")
  check("home: one tab", vim.fn.tabpagenr("$") == 1)
  check("home: back on the current lesson", learn.lesson_of(0) == 2)
  check("home: recording stopped", vim.fn.reg_recording() == "")
  check("home: normal mode", vim.api.nvim_get_mode().mode == "n")
  local okp = pcall(function()
    require("rihla.cheat").vscode_picker()
  end)
  vim.wait(300)
  local in_prompt = vim.bo.filetype == "snacks_picker_input"
  vim.cmd("Rihla home")
  vim.wait(100)
  one_window(":Rihla home from inside a picker")
  check("home: (the picker was open)", okp and in_prompt)

  -- Every popup says how to close it, and closes ------------------------------------------
  local function closes(label, open, key)
    fresh()
    local before = #vim.api.nvim_list_wins()
    local ok, err = pcall(open)
    vim.wait(400)
    local win = vim.api.nvim_get_current_win()
    local c = vim.api.nvim_win_get_config(win)
    local text = vim.inspect({ c.title, c.footer }) .. (vim.wo[win].winbar or "")
    local says = text:find("closes", 1, true) ~= nil or text:find("close", 1, true) ~= nil
    check(("popup %s: opened, says how to close"):format(label), ok and c.relative ~= "" and says, ok and text or tostring(err))
    feed(key or "q")
    vim.wait(200)
    check(("popup %s: %s closes it"):format(label, key or "q"), #vim.api.nvim_list_wins() <= before and vim.api.nvim_win_get_config(0).relative == "")
  end
  closes("cheat sheet (Space h c)", function()
    press("<leader>hc")
  end)
  closes("cheat sheet, Esc", function()
    press("<leader>hc")
  end, "<Esc>")
  closes("tmux cheat sheet (Space h T)", function()
    press("<leader>hT")
  end)
  closes("VS Code table (Space h V)", function()
    press("<leader>hV")
  end)
  closes("lesson list (Space h L)", function()
    press("<leader>hL")
  end)
  closes(":Rihla (the command list)", function()
    vim.cmd("Rihla")
  end)
  closes("languages (Space l L)", function()
    press("<leader>lL")
  end)
  closes(":Rihla log", function()
    util.log("test line")
    vim.cmd("Rihla log")
  end)
  if #vim.api.nvim_list_uis() > 0 then
    closes(":Lazy", function()
      vim.cmd("Lazy")
    end)
  else
    notes[#notes + 1] = "note  :Lazy opens no window without a UI (headless); it gets the same footer as :Mason"
  end
  closes(":Mason", function()
    vim.cmd("Mason")
  end)
  closes("check (Space h C)", function()
    press("<leader>hC")
    vim.wait(3000, function()
      return vim.bo.filetype == "checkhealth"
    end)
  end)
  -- Pickers: Esc closes (typing q filters), and the results box says so.
  for _, p in ipairs({ { "VS Code search (Space h v)", "<leader>hv" }, { "find file (Space f f)", "<leader>ff" }, { "command palette (Space Space)", "<leader><leader>" } }) do
    fresh()
    press(p[2])
    vim.wait(2000, function()
      return vim.bo.filetype == "snacks_picker_input"
    end)
    -- The picker's help line is the footer of its border.
    local titles = {}
    for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
      local c = vim.api.nvim_win_get_config(w)
      titles[#titles + 1] = vim.inspect(c.title)
      titles[#titles + 1] = vim.inspect(c.footer)
    end
    local all = table.concat(titles, " ")
    check(("picker %s: says Esc closes"):format(p[1]), all:find("Esc closes", 1, true) ~= nil, all)
    feed("<Esc>")
    vim.wait(200)
    local _, fl = wins()
    check(("picker %s: Esc closes it"):format(p[1]), fl == 0)
  end
  -- The terminal says how to leave it.
  fresh()
  local okt = pcall(vim.cmd, "ToggleTerm direction=horizontal")
  vim.wait(300)
  check("terminal: says how to stop typing in it and hide it", okt and vim.bo.buftype == "terminal" and vim.wo.winbar:find("Esc Esc", 1, true) ~= nil, vim.wo.winbar)
  pcall(vim.cmd, "ToggleTerm")
  -- A macro recording says how to stop it.
  pcall(function()
    require("lazy").load({ plugins = { "lualine.nvim" } })
  end)
  fresh()
  feed("qz")
  vim.wait(50)
  local sl = vim.api.nvim_eval_statusline(vim.o.statusline, {}).str
  feed("q")
  check("recording: the status line says press q to stop", sl:find("press q to stop", 1, true) ~= nil, sl)

  -- Habit hints only name what has been taught ---------------------------------------------
  local habits = require("rihla.habits")
  local s = learn.state()
  s.done = {}
  learn.save(s)
  local rule = { tips = { { 2, "a count" }, { 5, "f<char>" } } }
  check("habits: silent before the lesson that teaches the fix", habits.message(rule, 6, "'j'") == nil)
  s.done = { ["0"] = "x", ["1"] = "x", ["2"] = "x" }
  learn.save(s)
  local msg = habits.message(rule, 6, "'j'") or ""
  check("habits: after lesson 2, names only lesson 2's keys", msg:find("a count", 1, true) ~= nil and not msg:find("f<char>", 1, true), msg)

  -- One line, or Neovim stops at "Press ENTER": the whole echo, "habit: " included,
  -- leaves 12 columns for the ruler and showcmd. Whole, not cut, at 80 columns.
  s.done = {}
  for _, l in ipairs(lessons) do
    s.done[tostring(l.n)] = "x"
  end
  learn.save(s)
  for _, cols in ipairs({ 80, 120 }) do
    local long = {}
    for name, rl in pairs(habits.rules) do
      local label = rl.label or "'" .. rl.keys[1] .. "'"
      local m = habits.message(rl, 12, label) or ""
      local fitted = habits.fit(m, cols)
      if #habits.prefix + vim.fn.strdisplaywidth(fitted) > cols - 12 or fitted ~= m then
        long[#long + 1] = ("%s (%d): %s"):format(name, #habits.prefix + #m, m)
      end
    end
    check(("habits: every hint fits one line at %d columns, whole"):format(cols), #long == 0, table.concat(long, "; "))
    local cut = habits.fit(string.rep("x", 200), cols)
    check(("habits: a long hint is cut to one line at %d columns"):format(cols), #habits.prefix + #cut <= cols - 12, #cut)
  end
  s.done = {}
  learn.save(s)

  -- The line shown when a lesson opens keeps its keys and fits, at 80 and 120 columns.
  local bad = {}
  for _, cols in ipairs({ 80, 120 }) do
    for _, l in ipairs(lessons) do
      local b = learn.banner(l.n, l.title, cols)
      if vim.fn.strdisplaywidth(b) > cols - 12 or not b:find("Space h n", 1, true) or not b:find(":q Enter", 1, true) then
        bad[#bad + 1] = cols .. ": " .. b
      end
      local f = util.fit(b, nil, cols)
      if f ~= b then
        bad[#bad + 1] = cols .. " cut: " .. f
      end
    end
  end
  check("lesson message: keys kept, one line, at 80 and 120 columns", #bad == 0, table.concat(bad, "; "))
  local cut = util.fit(string.rep("x", 200), nil, 80)
  check("say: a cut message without a 'where' just ends in ...", #cut <= 68 and vim.endswith(cut, "...") and not cut:find("Rihla", 1, true), cut)

  -- The repository is untouched; the old name of the check command is gone --------------
  check("checkout: docs/learn unchanged by all of the above", digest(learn.dir) == repo_before)
  local old = "doc" .. "tor"
  local hits = {}
  for name, kind in vim.fs.dir(util.root, {
    depth = 8,
    skip = function(d)
      return not d:match("%.git$")
    end,
  }) do
    if kind == "file" and not name:match("%.png$") then
      local text = (util.read(util.root .. "/" .. name) or ""):lower()
      if text:find(old, 1, true) or name:lower():find(old, 1, true) then
        hits[#hits + 1] = name
      end
    end
  end
  check("the old name of the check command appears nowhere", #hits == 0, table.concat(hits, ", "))

  local errs = {}
  for _, e in ipairs(util.errors) do
    errs[#errs + 1] = e.name .. ": " .. tostring(e.err):match("^[^\n]*")
  end
  check("no rihla errors", #errs == 0, table.concat(errs, " | "))
end

vim.defer_fn(function()
  local ok, err = xpcall(run, debug.traceback)
  if not ok then
    check("learn script itself", false, err)
  end
  for _, l in ipairs(results) do
    io.stdout:write(l .. "\n")
  end
  for _, l in ipairs(notes) do
    io.stdout:write(l .. "\n")
  end
  io.stdout:write(("%d checks, %d failed\n"):format(#results, failed))
  vim.fn.delete(state, "rf")
  vim.cmd(failed == 0 and "qa!" or "cquit 1")
end, 800)
