-- Small helpers shared by every rihla module.
local M = {}

-- Where the repository lives. This file is <root>/nvim/lua/rihla/util.lua and
-- ~/.config/nvim is usually a symlink into the checkout, so resolve it first.
local src = debug.getinfo(1, "S").source:sub(2)
src = (vim.uv or vim.loop).fs_realpath(src) or src
M.root = vim.fn.fnamemodify(src, ":h:h:h:h")
M.docs = M.root .. "/docs"

-- The user's own overrides; install and update never write here.
M.user_dir = (vim.env.XDG_CONFIG_HOME or (vim.env.HOME .. "/.config")) .. "/rihla"

M.errors = {} -- every failure reported through M.safe, for :Rihla check and tests
M.hints = {} -- every one-line hint shown this session

local exe_cache = {}
--- Is `bin` on PATH? Cached, because executable() stats every PATH entry.
function M.has(bin)
  if exe_cache[bin] == nil then
    exe_cache[bin] = vim.fn.executable(bin) == 1
  end
  return exe_cache[bin]
end

--- Forget cached lookups (after mason installs something).
function M.reset_has()
  exe_cache = {}
end

--- Is there a C compiler that tree-sitter can use?
function M.has_cc()
  local cc = vim.env.CC
  if cc and cc ~= "" and M.has(cc) then
    return true
  end
  return M.has("cc") or M.has("gcc") or M.has("clang")
end

local log_path
local function log(msg)
  log_path = log_path or (vim.fn.stdpath("log") .. "/rihla.log")
  local f = io.open(log_path, "a")
  if f then
    f:write(os.date("%Y-%m-%d %H:%M:%S "), msg, "\n")
    f:close()
  end
end
M.log = log

local function first_line(s)
  s = tostring(s or "")
  return (s:match("^[^\n]*") or s)
end

--- Run fn; on failure report ONE line and keep going.
--- The full traceback goes to stdpath("log")/rihla.log.
function M.safe(name, fn, ...)
  local ok, err = xpcall(fn, debug.traceback, ...)
  if not ok then
    table.insert(M.errors, { name = name, err = err })
    log(("[%s] %s"):format(name, err))
    local line = ("rihla: %s failed: %s (details: :Rihla log)"):format(name, first_line(err))
    M.say(line, vim.log.levels.WARN, ":Rihla log")
  end
  return ok, err
end

-- Hints already shown in an earlier session: "needs unzip" is said once, not
-- at every start. They stay listed in :Rihla check (and :checkhealth rihla).
local seen_file = vim.fn.stdpath("state") .. "/rihla/hints-seen.json"
local seen
local function seen_before(key, msg)
  if not seen then
    local ok, t = pcall(vim.json.decode, M.read(seen_file) or "")
    seen = ok and type(t) == "table" and t or {}
  end
  if seen[key] == msg then
    return true
  end
  seen[key] = msg
  if #vim.api.nvim_list_uis() > 0 then
    M.write(seen_file, vim.json.encode(seen))
  end
  return false
end

--- Show a one-line hint the first time it comes up. Hints are advice, not
--- errors: a missing optional tool, a feature that degraded, and the fix.
--- Each one is shown once (across sessions); :Rihla check lists them all.
function M.hint(key, msg, level)
  if M.hints[key] then
    return
  end
  M.hints[key] = msg
  log("[hint] " .. msg)
  if vim.g.rihla_quiet_hints or level == vim.log.levels.DEBUG then
    return -- DEBUG hints are only logged and listed by :Rihla check
  end
  if seen_before(key, msg) then
    return
  end
  M.say("rihla: " .. msg, level, ":Rihla check")
end

--- Cut text to one line of the screen (12 columns stay free for the ruler and
--- the keys being typed), ending in "... (where)" or "...".
function M.fit(text, where, columns)
  local room = (columns or vim.o.columns) - 12
  if vim.fn.strdisplaywidth(text) <= room or room < 20 then
    return text
  end
  local tail = where and ("... (" .. where .. ")") or "..."
  if #tail > room / 2 then
    tail = "..."
  end
  return vim.fn.strcharpart(text, 0, room - #tail) .. tail
end

local queue, draining = {}, false
--- Show a one-line message. Messages are shown one at a time, a moment
--- apart, and cut to the screen width: two messages in the same redraw, or
--- one that wraps, would stack into a hit-Enter prompt. `where` names the
--- command that shows the full text when it had to be cut (hints are in
--- :Rihla check, errors in :Rihla log); without it a cut line just ends in "...".
function M.say(text, level, where)
  table.insert(queue, { text = text, level = level, where = where })
  if draining then
    return
  end
  draining = true
  local function drain()
    local item = table.remove(queue, 1)
    if not item then
      draining = false
      return
    end
    local t = item.text
    if #vim.api.nvim_list_uis() > 0 then
      t = M.fit(t, item.where)
    end
    vim.notify(t, item.level or vim.log.levels.INFO)
    vim.defer_fn(drain, #queue > 0 and 1200 or 0)
  end
  vim.schedule(drain)
end

--- Read a whole file, or nil.
function M.read(path)
  local f = io.open(path, "r")
  if not f then
    return nil
  end
  local s = f:read("*a")
  f:close()
  return s
end

function M.write(path, s)
  vim.fn.mkdir(vim.fn.fnamemodify(path, ":h"), "p")
  local f = io.open(path, "w")
  if not f then
    return false
  end
  f:write(s)
  f:close()
  return true
end

--- Set a keymap. Every rihla mapping goes through here so that it always has
--- a description (which-key, the palette and the tests rely on that).
function M.map(mode, lhs, rhs, desc, opts)
  opts = vim.tbl_extend("force", { silent = true }, opts or {})
  opts.desc = desc
  vim.keymap.set(mode, lhs, rhs, opts)
end

function M.nvim_at_least(minor)
  return vim.fn.has("nvim-0." .. minor) == 1
end

return M
