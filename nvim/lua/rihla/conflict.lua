-- Merge conflicts in the file itself, the way VS Code shows them.
--
-- A file with conflict markers (<<<<<<< / ||||||| / ======= / >>>>>>>) gets its
-- two sides coloured, a line above each conflict naming the keys, and, in that
-- buffer only:
--   co  keep ours (current, HEAD)     ct  take theirs (incoming)
--   cb  keep both                     c0  keep neither
--   ]x  next conflict                 [x  previous conflict
-- Each choice is one change, so u undoes it. Space g x lists every conflict in
-- the repository in the quickfix list (]q / [q walk it).
--
-- The in-file part needs no git; the list works with git 1.8.3.
-- ct (change till) and co / cb / c0 keep their Vim meaning in every other buffer.
local util = require("rihla.util")

local M = {}

M.ns = vim.api.nvim_create_namespace("rihla_conflict")

local MARK = { start = "^<<<<<<<", base = "^|||||||", mid = "^=======$", finish = "^>>>>>>>" }

--- All conflicts in a buffer: { start, base?, mid, finish } (1-based line numbers).
function M.parse(buf)
  local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
  local out, cur = {}, nil
  for i, l in ipairs(lines) do
    if l:find(MARK.start) then
      cur = { start = i }
    elseif cur and not cur.mid and l:find(MARK.base) then
      cur.base = i
    elseif cur and not cur.mid and l:find(MARK.mid) then
      cur.mid = i
    elseif cur and cur.mid and l:find(MARK.finish) then
      cur.finish = i
      out[#out + 1] = cur
      cur = nil
    end
  end
  return out
end

--- The conflict the cursor is in, or nil.
function M.at(buf, lnum)
  for _, c in ipairs(M.parse(buf)) do
    if lnum >= c.start and lnum <= c.finish then
      return c
    end
  end
end

local function set_hl()
  local p = require("rihla.palette")
  local function blend(fg, bg, a)
    local function ch(h, i)
      return tonumber(h:sub(i, i + 1), 16)
    end
    local out = "#"
    for _, i in ipairs({ 2, 4, 6 }) do
      out = out .. ("%02x"):format(math.floor(ch(fg, i) * a + ch(bg, i) * (1 - a) + 0.5))
    end
    return out
  end
  vim.api.nvim_set_hl(0, "RihlaConflictOurs", { bg = blend(p.green, p.base, 0.18), default = true })
  vim.api.nvim_set_hl(0, "RihlaConflictOursLabel", { bg = blend(p.green, p.base, 0.4), fg = p.text, bold = true, default = true })
  vim.api.nvim_set_hl(0, "RihlaConflictTheirs", { bg = blend(p.blue, p.base, 0.18), default = true })
  vim.api.nvim_set_hl(0, "RihlaConflictTheirsLabel", { bg = blend(p.blue, p.base, 0.4), fg = p.text, bold = true, default = true })
  vim.api.nvim_set_hl(0, "RihlaConflictBase", { bg = blend(p.overlay, p.base, 0.15), default = true })
  vim.api.nvim_set_hl(0, "RihlaConflictHint", { fg = p.overlay, italic = true, default = true })
end

local function line_hl(buf, from, to, group)
  for l = from, to do
    vim.api.nvim_buf_set_extmark(buf, M.ns, l - 1, 0, { line_hl_group = group, priority = 200 })
  end
end

local labels = {
  co = "Conflict: keep ours (current, HEAD)",
  ct = "Conflict: take theirs (incoming)",
  cb = "Conflict: keep both",
  c0 = "Conflict: keep neither",
  ["]x"] = "Next merge conflict",
  ["[x"] = "Previous merge conflict",
}

local function set_keys(buf, on)
  local have = vim.b[buf].rihla_conflict_keys
  if on == (have == true) then
    return
  end
  vim.b[buf].rihla_conflict_keys = on
  local fns = {
    co = function()
      M.choose("ours")
    end,
    ct = function()
      M.choose("theirs")
    end,
    cb = function()
      M.choose("both")
    end,
    c0 = function()
      M.choose("none")
    end,
    ["]x"] = function()
      M.jump(1)
    end,
    ["[x"] = function()
      M.jump(-1)
    end,
  }
  for lhs, fn in pairs(fns) do
    if on then
      vim.keymap.set("n", lhs, fn, { buffer = buf, desc = labels[lhs], nowait = true, silent = true })
    else
      pcall(vim.keymap.del, "n", lhs, { buffer = buf })
    end
  end
end

--- Draw the colours and the key hints; add or remove the keys.
function M.refresh(buf)
  buf = buf or vim.api.nvim_get_current_buf()
  if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
    return
  end
  vim.api.nvim_buf_clear_namespace(buf, M.ns, 0, -1)
  -- Quick test in C first: most files have no marker at all.
  local has = vim.api.nvim_buf_call(buf, function()
    return vim.fn.search([[^<<<<<<<\( \|$\)]], "nw") > 0
  end)
  local list = has and M.parse(buf) or {}
  for _, c in ipairs(list) do
    local ours_end = (c.base or c.mid) - 1
    vim.api.nvim_buf_set_extmark(buf, M.ns, c.start - 1, 0, {
      line_hl_group = "RihlaConflictOursLabel",
      virt_text = { { "  ours (current)", "RihlaConflictOursLabel" } },
      virt_lines = { { { "co keep ours  ct take theirs  cb both  c0 neither  ]x next  Space g m merge view", "RihlaConflictHint" } } },
      virt_lines_above = true,
      priority = 200,
    })
    line_hl(buf, c.start + 1, ours_end, "RihlaConflictOurs")
    if c.base then
      line_hl(buf, c.base, c.mid - 1, "RihlaConflictBase")
    end
    line_hl(buf, c.mid + 1, c.finish - 1, "RihlaConflictTheirs")
    vim.api.nvim_buf_set_extmark(buf, M.ns, c.finish - 1, 0, {
      line_hl_group = "RihlaConflictTheirsLabel",
      virt_text = { { "  theirs (incoming)", "RihlaConflictTheirsLabel" } },
      priority = 200,
    })
  end
  set_keys(buf, #list > 0)
  -- A half-merged file is full of syntax errors; they only hide the conflict.
  -- Diagnostics come back when the last conflict is resolved.
  if #list > 0 and not vim.b[buf].rihla_conflict_diag_off then
    vim.b[buf].rihla_conflict_diag_off = true
    vim.diagnostic.enable(false, { bufnr = buf })
  elseif #list == 0 and vim.b[buf].rihla_conflict_diag_off then
    vim.b[buf].rihla_conflict_diag_off = nil
    vim.diagnostic.enable(true, { bufnr = buf })
  end
  return list
end

--- Resolve the conflict under the cursor: "ours", "theirs", "both" or "none".
function M.choose(side)
  local buf = vim.api.nvim_get_current_buf()
  local lnum = vim.fn.line(".")
  local c = M.at(buf, lnum)
  if not c then
    util.say("The cursor is not in a conflict. ]x goes to the next one.")
    return
  end
  local lines = vim.api.nvim_buf_get_lines(buf, c.start - 1, c.finish, false)
  local function part(a, b) -- buffer lines a..b, inclusive
    local out = {}
    for l = a, b do
      out[#out + 1] = lines[l - c.start + 1]
    end
    return out
  end
  local ours = part(c.start + 1, (c.base or c.mid) - 1)
  local theirs = part(c.mid + 1, c.finish - 1)
  local new = ({
    ours = ours,
    theirs = theirs,
    both = vim.list_extend(vim.list_extend({}, ours), theirs),
    none = {},
  })[side]
  vim.api.nvim_buf_set_lines(buf, c.start - 1, c.finish, false, new)
  pcall(vim.api.nvim_win_set_cursor, 0, { math.max(1, math.min(c.start, vim.api.nvim_buf_line_count(buf))), 0 })
  local left = M.refresh(buf)
  if #left == 0 then
    util.say("No conflicts left in this file. Save it (:w), then git add it.")
  end
end

--- ]x / [x: the next / previous conflict start.
function M.jump(dir)
  local lnum = vim.fn.line(".")
  local list = M.parse(0)
  local target
  if dir > 0 then
    for _, c in ipairs(list) do
      if c.start > lnum then
        target = c.start
        break
      end
    end
  else
    for i = #list, 1, -1 do
      if list[i].start < lnum then
        target = list[i].start
        break
      end
    end
  end
  if not target then
    util.say(#list == 0 and "No conflicts in this file." or "No more conflicts this way.")
    return
  end
  vim.cmd("normal! m'")
  vim.api.nvim_win_set_cursor(0, { target, 0 })
end

--- Every conflict in the current file's repository -> the quickfix list: git's
--- list of unmerged files, else files with conflict markers under the repository
--- top. Outside a repository: the file's own folder (or the working directory
--- when it is not the home directory, which is never crawled).
function M.to_quickfix()
  local files = {}
  local name = vim.api.nvim_buf_get_name(0)
  local dir = (name ~= "" and vim.bo.buftype == "") and vim.fn.fnamemodify(name, ":p:h") or vim.fn.getcwd()
  if vim.fn.isdirectory(dir) == 0 then
    dir = vim.fn.getcwd()
  end
  local root
  local function run(cmd, cwd)
    -- no `git -C`: git 1.8.3 (CentOS 7) lacks it
    local ok, r = pcall(function()
      return vim.system(cmd, { cwd = cwd, text = true }):wait()
    end)
    if not ok or r.code ~= 0 then
      return nil
    end
    return vim.split(vim.trim(r.stdout or ""), "\n", { trimempty = true })
  end
  if util.has("git") then
    local top = run({ "git", "rev-parse", "--show-toplevel" }, dir)
    if top and top[1] then
      root = top[1]
      for _, f in ipairs(run({ "git", "diff", "--name-only", "--diff-filter=U" }, root) or {}) do
        files[#files + 1] = root .. "/" .. f
      end
    end
  end
  if not root then
    local home = vim.fn.fnamemodify(vim.env.HOME or "", ":p"):gsub("/$", "")
    if dir:gsub("/$", "") == home then
      util.say("Not in a git repository: open a file of the repository first (the home folder is not searched).")
      return
    end
    root = dir
  end
  if #files == 0 and util.has("rg") then
    for _, f in ipairs(run({ "rg", "-l", "--no-messages", "^<<<<<<< ", root }, root) or {}) do
      files[#files + 1] = f
    end
  end
  local items = {}
  for _, f in ipairs(files) do
    local buf = vim.fn.bufadd(f)
    vim.fn.bufload(buf)
    for _, c in ipairs(M.parse(buf)) do
      items[#items + 1] = {
        bufnr = buf,
        lnum = c.start,
        text = ("conflict (%d lines ours, %d theirs)"):format((c.base or c.mid) - c.start - 1, c.finish - c.mid - 1),
      }
    end
  end
  vim.fn.setqflist({}, " ", { title = "merge conflicts", items = items })
  if #items == 0 then
    util.say("No merge conflicts found.")
    return
  end
  vim.cmd("botright copen")
end

function M.setup()
  set_hl()
  local group = vim.api.nvim_create_augroup("rihla_conflict", { clear = true })
  vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = set_hl })
  vim.api.nvim_create_autocmd({ "BufReadPost", "BufWinEnter", "TextChanged", "InsertLeave", "FileChangedShellPost" }, {
    group = group,
    callback = function(ev)
      local buf = ev.buf
      vim.schedule(function()
        pcall(M.refresh, buf)
      end)
    end,
  })
end

return M
