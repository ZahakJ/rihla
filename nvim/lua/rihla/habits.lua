-- Habit hints: notice slow movement patterns and suggest the faster Vim way.
--
-- Levels (<leader>th cycles, :Rihla habits <level> sets, vim.g.rihla_habits
-- in ~/.config/rihla/local.lua makes it stick):
--   off     nothing.
--   hint    (default) arrows, mouse and repeated keys all still work; after a
--           run of slow presses a one-line hint suggests the better motion.
--           It only watches, it never changes what a key does.
--   strict  as hint, and after 4 repeats of h/j/k/l the next ones do nothing
--           until you pause or use a count (5j); arrows in normal mode show
--           the hint instead of moving.
-- Each hint names the lesson that teaches the fix.
local util = require("rihla.util")

local M = {}

local ns = vim.api.nvim_create_namespace("rihla_habits")
local levels = { "off", "hint", "strict" }
local t = function(k)
  return vim.api.nvim_replace_termcodes(k, true, true, true)
end

-- Each hint names only keys from lessons you have marked done (Space h n or
-- Space h d), so nothing is suggested before it has been taught. Until then a
-- rule stays silent. { lesson, text } pieces are joined in order.
local rules = {
  vertical = {
    keys = { "j", "k" },
    after = 6,
    tips = {
      { 2, "a count (7j)" },
      { 2, "} { Ctrl-d/u" },
      { 6, "/text" },
    },
  },
  horizontal = {
    keys = { "h", "l" },
    after = 6,
    tips = { { 2, "w b e by word" }, { 5, "f<char> t<char>" } },
  },
  word = {
    keys = { "w", "b", "e", "W", "B" },
    after = 6,
    tips = { { 2, "a count (4w)" }, { 5, "f<char>" }, { 6, "/text" } },
  },
  delete = {
    keys = { "x", "X" },
    after = 5,
    tips = { { 3, "dw a word, D to line end" }, { 5, "dt<char>" } },
  },
  arrow_n = {
    keys = { t("<Up>"), t("<Down>"), t("<Left>"), t("<Right>") },
    after = 1,
    label = "arrow keys",
    tips = { { 2, "j k h l; w b } { go further" } },
    throttle = 120,
  },
  arrow_i = {
    keys = { t("<Up>"), t("<Down>"), t("<Left>"), t("<Right>") },
    mode = "i",
    after = 4,
    label = "arrows in insert",
    tips = { { 1, "Esc, move, then i a A o" } },
    throttle = 120,
  },
}

--- The hint text for a rule, from the lessons done so far; nil when none is.
function M.message(r, count, label)
  local learn = require("rihla.learn")
  local done = learn.state().done
  local parts, lessons, seen = {}, {}, {}
  for _, tip in ipairs(r.tips) do
    if done[tostring(tip[1])] then
      parts[#parts + 1] = tip[2]
      if not seen[tip[1]] then
        seen[tip[1]] = true
        lessons[#lessons + 1] = tostring(tip[1])
      end
    end
  end
  if #parts == 0 then
    return nil
  end
  local from = #lessons == 1 and ("lesson " .. lessons[1]) or ("lessons " .. table.concat(lessons, ", "))
  return ("%d x %s: %s (%s)."):format(count, label, table.concat(parts, "; "), from)
end

M.rules = rules

local by_key = { n = {}, i = {} }
for name, r in pairs(rules) do
  r.name = name
  for _, k in ipairs(r.keys) do
    by_key[r.mode or "n"][k] = r
  end
end

M.stats = {}
local last_key, run, last_time = nil, 0, 0
local last_shown = {}

local function now()
  return (vim.uv or vim.loop).now()
end

local function eligible()
  if vim.bo.buftype ~= "" or vim.fn.reg_executing() ~= "" or vim.fn.reg_recording() ~= "" then
    return false
  end
  return true
end

M.prefix = "habit: "

--- Cut msg so that "habit: " .. msg stays on one line: a message that wraps
--- stops Neovim at a "Press ENTER" prompt. 12 columns stay free for the
--- ruler and the keys being typed (showcmd) on the same line.
function M.fit(msg, columns)
  local room = (columns or vim.o.columns) - 12 - #M.prefix
  if vim.fn.strdisplaywidth(msg) > room then
    msg = vim.fn.strcharpart(msg, 0, math.max(room - 3, 0)) .. "..."
  end
  return msg
end

local function show(r, count, key)
  local label = r.label or ("'" .. vim.fn.keytrans(key) .. "'")
  local ok, msg = pcall(M.message, r, count, label)
  if not ok or not msg then
    return
  end
  local ts = now()
  if last_shown[r.name] and ts - last_shown[r.name] < (r.throttle or 20) * 1000 then
    return
  end
  last_shown[r.name] = ts
  M.stats[r.name] = (M.stats[r.name] or 0) + 1
  msg = M.fit(msg)
  vim.schedule(function()
    vim.api.nvim_echo({ { M.prefix, "DiagnosticWarn" }, { msg, "RihlaHint" } }, false, {})
  end)
end

local function on_key(_, typed)
  if vim.g.rihla_habits == "off" or not typed or typed == "" then
    return
  end
  local mode = vim.api.nvim_get_mode().mode
  local m = mode == "n" and "n" or (mode == "i" and "i" or nil)
  if not m then
    last_key, run = nil, 0
    return
  end
  local r = by_key[m][typed]
  local ts = now()
  if r and typed == last_key and ts - last_time < 1500 then
    run = run + 1
  elseif r then
    run = 1
  else
    -- Digits start a count, which is exactly the habit we want; reset.
    last_key, run = nil, 0
    return
  end
  last_key, last_time = typed, ts
  if run >= r.after and eligible() then
    show(r, run, typed)
  end
end

-- Strict mode: expr mappings that swallow a 5th quick repeat of h/j/k/l.
local strict_count, strict_key, strict_time = 0, nil, 0
local function strict_expr(key, plain)
  return function()
    if vim.v.count > 0 or vim.bo.buftype ~= "" then
      strict_count = 0
      return plain()
    end
    local ts = now()
    if key == strict_key and ts - strict_time < 1500 then
      strict_count = strict_count + 1
    else
      strict_count = 1
    end
    strict_key, strict_time = key, ts
    if strict_count > 4 then
      local r = by_key.n[key]
      show(r, strict_count, key)
      return ""
    end
    return plain()
  end
end

local strict_maps = {}
local function strict_on()
  local function wrapped(k)
    return function()
      return vim.v.count == 0 and ("g" .. k) or k
    end
  end
  local defs = {
    { "j", wrapped("j") },
    { "k", wrapped("k") },
    {
      "h",
      function()
        return "h"
      end,
    },
    {
      "l",
      function()
        return "l"
      end,
    },
  }
  for _, d in ipairs(defs) do
    vim.keymap.set("n", d[1], strict_expr(d[1], d[2]), { expr = true, desc = "Move (habits: strict)" })
    strict_maps[#strict_maps + 1] = d[1]
  end
  for _, k in ipairs({ "<Up>", "<Down>", "<Left>", "<Right>" }) do
    vim.keymap.set("n", k, function()
      show(rules.arrow_n, 1, t(k))
    end, { desc = "Arrow (habits: strict shows a hint)" })
    strict_maps[#strict_maps + 1] = k
  end
end

local function strict_off()
  for _, k in ipairs(strict_maps) do
    pcall(vim.keymap.del, "n", k)
  end
  strict_maps = {}
  -- Put back the core j/k (screen lines unless a count is given).
  vim.keymap.set({ "n", "x" }, "j", "v:count == 0 ? 'gj' : 'j'", { expr = true, silent = true, desc = "Down" })
  vim.keymap.set({ "n", "x" }, "k", "v:count == 0 ? 'gk' : 'k'", { expr = true, silent = true, desc = "Up" })
end

function M.set(level, quiet)
  if not vim.tbl_contains(levels, level or "") then
    local parts = {}
    for k, v in pairs(M.stats) do
      parts[#parts + 1] = k .. "=" .. v
    end
    vim.notify(
      ("habits: %s (off | hint | strict). Hints shown this session: %s"):format(
        vim.g.rihla_habits,
        #parts > 0 and table.concat(parts, ", ") or "none"
      )
    )
    return
  end
  local was = vim.g.rihla_habits
  vim.g.rihla_habits = level
  if was == "strict" and level ~= "strict" then
    strict_off()
  elseif level == "strict" and was ~= "strict" then
    strict_on()
  end
  if not quiet then
    vim.notify("habit hints: " .. level)
  end
end

function M.cycle()
  local i = 1
  for idx, l in ipairs(levels) do
    if l == vim.g.rihla_habits then
      i = idx
    end
  end
  M.set(levels[i % #levels + 1])
end

function M.setup()
  vim.on_key(function(key, typed)
    pcall(on_key, key, typed)
  end, ns)
  if vim.g.rihla_habits == "strict" then
    vim.g.rihla_habits = "hint"
    M.set("strict", true)
  end
  -- local.lua runs after this; honour a level set there.
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if vim.g.rihla_habits == "strict" and #strict_maps == 0 then
        vim.g.rihla_habits = "hint"
        M.set("strict", true)
      end
    end,
  })
  util.log("habits: " .. tostring(vim.g.rihla_habits))
end

return M
