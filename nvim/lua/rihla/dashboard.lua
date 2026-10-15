-- The start screen: shown when Neovim starts with no file. Single keys act
-- on it (f, r, g, ...); each line also shows the key that works everywhere
-- else. Drawn from the shared palette.
local p = require("rihla.palette")
local util = require("rihla.util")

local M = {}

local logo = {
  [[██████╗ ██╗██╗  ██╗██╗      █████╗ ]],
  [[██╔══██╗██║██║  ██║██║     ██╔══██╗]],
  [[██████╔╝██║███████║██║     ███████║]],
  [[██╔══██╗██║██╔══██║██║     ██╔══██║]],
  [[██║  ██║██║██║  ██║███████╗██║  ██║]],
  [[╚═╝  ╚═╝╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝]],
}

-- For short screens (an 80x24 terminal, a tmux pane): the name in three lines of
-- box-drawing characters, which every terminal font has.
local logo_small = {
  [[┏━┓╻╻ ╻╻  ┏━┓]],
  [[┣┳┛┃┣━┫┃  ┣━┫]],
  [[╹┗╸╹╹ ╹┗━╸╹ ╹]],
}

local function blend(a, b, t)
  local function ch(hex, i)
    return tonumber(hex:sub(i, i + 1), 16)
  end
  local out = "#"
  for _, i in ipairs({ 2, 4, 6 }) do
    out = out .. string.format("%02x", math.floor(ch(a, i) + (ch(b, i) - ch(a, i)) * t + 0.5))
  end
  return out
end

local function set_hl()
  for i = 1, #logo do
    vim.api.nvim_set_hl(0, "RihlaLogo" .. i, { fg = blend(p.mauve, p.blue, (i - 1) / (#logo - 1)), bold = true })
  end
  vim.api.nvim_set_hl(0, "RihlaDashKey", { fg = p.mauve, bold = true })
  vim.api.nvim_set_hl(0, "RihlaDashText", { fg = p.text })
  vim.api.nvim_set_hl(0, "RihlaDashShortcut", { fg = p.overlay })
  vim.api.nvim_set_hl(0, "RihlaDashLesson", { fg = p.green, bold = true })
  vim.api.nvim_set_hl(0, "RihlaDashQuit", { fg = p.peach, bold = true })
  vim.api.nvim_set_hl(0, "RihlaDashHelp", { fg = p.subtext })
  vim.api.nvim_set_hl(0, "RihlaDashTip", { fg = p.subtext, italic = true })
  vim.api.nvim_set_hl(0, "RihlaDashTipLabel", { fg = p.peach, bold = true })
  vim.api.nvim_set_hl(0, "RihlaDashFooter", { fg = p.surface2 })
end

local function items()
  local learn = require("rihla.learn")
  local lesson, st = learn.current()
  local started = st and (st.current > 0 or next(st.done) ~= nil)
  local lesson_label = lesson
      and ((started and "Continue: lesson %s, %s" or "Start the lessons: %s, %s"):format(lesson.label, lesson.title))
    or "Lessons"
  local function keys(k)
    return function()
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), "m", false)
    end
  end
  -- The first two are what someone new needs: how to start learning, how to leave.
  return {
    { "l", lesson_label, "Space h l", keys("<leader>hl"), "RihlaDashLesson" },
    {
      "q",
      "Quit (anywhere else: Esc, then :q Enter)",
      ":q",
      function()
        vim.cmd("confirm qa")
      end,
      "RihlaDashQuit",
    },
    { gap = true },
    { "f", "Find file", "Space f f", keys("<leader>ff") },
    { "r", "Recent files", "Space f r", keys("<leader>fr") },
    { "g", "Grep in project", "Space f g", keys("<leader>fg") },
    { "e", "File tree", "Space e", keys("<leader>e") },
    { "s", "Restore session", "Space q s", keys("<leader>qs") },
    { "p", "Command palette", "Space Space", keys("<leader><leader>") },
    { "c", "Cheat sheet", "Space h c", keys("<leader>hc") },
    { "v", "VS Code -> Neovim", "Space h v", keys("<leader>hv") },
    {
      "n",
      "New file",
      ":enew",
      function()
        vim.cmd("enew")
      end,
    },
  }
end

local function wrap(text, width)
  local lines, line = {}, ""
  for word in text:gmatch("%S+") do
    if #line + #word + 1 > width and line ~= "" then
      lines[#lines + 1] = line
      line = word
    else
      line = line == "" and word or (line .. " " .. word)
    end
  end
  if line ~= "" then
    lines[#lines + 1] = line
  end
  return lines
end

M.buf = nil

local function render()
  local buf = M.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    return
  end
  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    return
  end
  local width = vim.api.nvim_win_get_width(win)
  local height = vim.api.nvim_win_get_height(win)
  local logo_w = vim.fn.strdisplaywidth(logo[1])
  local block_w = math.max(60, logo_w)
  local function pad(n)
    return string.rep(" ", math.max(0, math.floor((width - n) / 2)))
  end
  local lines, hls = {}, {}
  local function add(text, groups)
    lines[#lines + 1] = text
    if groups then
      for _, g in ipairs(groups) do
        hls[#hls + 1] = { #lines - 1, g[1], g[2], g[3] }
      end
    end
  end

  local show_logo = height >= 30 and width >= logo_w + 2
  if show_logo then
    for i, l in ipairs(logo) do
      local s = pad(logo_w) .. l
      add(s, { { "RihlaLogo" .. i, 0, #s } })
    end
  else
    local w = vim.fn.strdisplaywidth(logo_small[1])
    for i, l in ipairs(logo_small) do
      local s = pad(w) .. l
      add(s, { { "RihlaLogo" .. (i == 1 and 1 or i == 2 and 3 or #logo), 0, #s } })
    end
  end
  local v = vim.version()
  local sub = ("the journey  -  Neovim %d.%d.%d"):format(v.major, v.minor, v.patch)
  -- An 80x24 terminal leaves about 21 rows: fewer blank lines there.
  local roomy = height >= 26
  add("")
  add(pad(#sub) .. sub, { { "RihlaDashShortcut", 0, -1 } })
  add("")

  M.item_lines = {}
  local left = pad(block_w)
  local help = "Press one of the letters below."
  add(left .. "  " .. help, { { "RihlaDashHelp", #left, -1 } })
  if roomy then
    add("")
  end
  for _, it in ipairs(items()) do
    if it.gap then
      add("")
      goto continue
    end
    local label = it[2]
    if #label > block_w - 18 then
      label = label:sub(1, block_w - 21) .. "..."
    end
    local gap = block_w - 6 - #label - #it[3]
    local s = left .. "  " .. it[1] .. "   " .. label .. string.rep(" ", math.max(1, gap)) .. it[3]
    local k0 = #left + 2
    add(s, {
      { "RihlaDashKey", k0, k0 + 1 },
      { it[5] or "RihlaDashText", k0 + 4, k0 + 4 + #label },
      { "RihlaDashShortcut", #s - #it[3], #s },
    })
    M.item_lines[#lines] = it
    ::continue::
  end

  add("")
  local tip = require("rihla.learn").tip(false)
  local tw = tip and wrap(tip, block_w - 6) or {}
  -- On a short screen the tip gives way, so the footer still fits.
  if tip and #lines + #tw + 2 <= height then
    for i, l in ipairs(tw) do
      local prefix = i == 1 and "Tip  " or "     "
      local s = left .. prefix .. l
      add(s, { { i == 1 and "RihlaDashTipLabel" or "RihlaDashTip", #left, #left + 5 }, { "RihlaDashTip", #left + 5, #s } })
    end
    add("")
  end
  local ok, lazy = pcall(require, "lazy")
  if ok then
    local st = lazy.stats()
    local ms = st.startuptime and st.startuptime > 0 and (" in %.0f ms"):format(st.startuptime) or ""
    local s = ("%d of %d plugins loaded%s  -  icons: %s"):format(st.loaded, st.count, ms, vim.g.rihla_icons)
    add(pad(#s) .. s, { { "RihlaDashFooter", 0, -1 } })
  end

  -- Vertical centring.
  local top = math.max(0, math.floor((height - #lines) / 2) - 1)
  local final = {}
  for _ = 1, top do
    final[#final + 1] = ""
  end
  vim.list_extend(final, lines)
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, final)
  vim.bo[buf].modifiable = false
  local ns = vim.api.nvim_create_namespace("rihla_dashboard")
  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  for _, h in ipairs(hls) do
    local row = h[1] + top
    local line = final[row + 1] or ""
    local e = h[4] == -1 and #line or math.min(h[4], #line)
    pcall(vim.api.nvim_buf_set_extmark, buf, ns, row, h[3], { end_col = e, hl_group = h[2] })
  end
  local shifted = {}
  for l, it in pairs(M.item_lines) do
    shifted[l + top] = it
  end
  M.item_lines = shifted
  -- Cursor on the first item.
  local first = math.huge
  for l in pairs(shifted) do
    first = math.min(first, l)
  end
  if first < math.huge then
    pcall(vim.api.nvim_win_set_cursor, win, { first, #left + 2 })
  end
end

function M.open()
  set_hl()
  local orig = vim.api.nvim_get_current_buf()
  local buf = vim.api.nvim_create_buf(false, true)
  M.buf = buf
  vim.api.nvim_win_set_buf(0, buf)
  -- Drop the empty startup buffer so it does not linger as "[No Name]".
  if orig ~= buf and vim.api.nvim_buf_get_name(orig) == "" and not vim.bo[orig].modified then
    pcall(vim.api.nvim_buf_delete, orig, {})
  end
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "rihla-dashboard"
  local wo = vim.wo[0][0]
  wo.number = false
  wo.relativenumber = false
  wo.cursorline = false
  wo.signcolumn = "no"
  wo.list = false
  wo.foldcolumn = "0"
  wo.statuscolumn = ""
  render()
  local used = {}
  for _, it in ipairs(items()) do
    if not it.gap then
      used[it[1]] = true
      vim.keymap.set("n", it[1], function()
        it[4]()
      end, { buffer = buf, nowait = true, silent = true, desc = "Dashboard: " .. it[2] })
    end
  end
  -- Keys that would edit text only give "E21: Cannot make changes" here. Say
  -- what this screen is instead, so nobody is left wondering.
  for _, k in ipairs({ "i", "a", "o", "I", "A", "O", "x", "X", "d", "D", "c", "C", "s", "S", "R", "u", "U", "P", "J", "Q", "y", "<C-r>", "<BS>", "<Del>" }) do
    if not used[k] then
      vim.keymap.set("n", k, function()
        util.say("Start screen: l lessons, q quit, or a letter from the list.")
      end, { buffer = buf, nowait = true, silent = true, desc = "Dashboard: explain this screen" })
    end
  end
  vim.keymap.set("n", "<CR>", function()
    local it = M.item_lines and M.item_lines[vim.fn.line(".")]
    if it then
      it[4]()
    end
  end, { buffer = buf, silent = true, desc = "Dashboard: run item under cursor" })
  local g = vim.api.nvim_create_augroup("rihla_dashboard", { clear = true })
  vim.api.nvim_create_autocmd({ "VimResized", "WinResized" }, { group = g, buffer = buf, callback = render })
  vim.api.nvim_create_autocmd("User", { group = g, pattern = "LazyVimStarted", once = true, callback = render })
  vim.api.nvim_create_autocmd("ColorScheme", { group = g, callback = set_hl })
end

function M.setup()
  if not vim.g.rihla_dashboard then
    return
  end
  local stdin = false
  vim.api.nvim_create_autocmd("StdinReadPre", {
    once = true,
    callback = function()
      stdin = true
    end,
  })
  vim.api.nvim_create_autocmd("VimEnter", {
    once = true,
    callback = function()
      if stdin or vim.fn.argc() > 0 or #vim.api.nvim_list_uis() == 0 then
        return
      end
      local b = vim.api.nvim_get_current_buf()
      if vim.api.nvim_buf_get_name(b) ~= "" or vim.api.nvim_buf_line_count(b) > 1 or vim.bo[b].modified then
        return
      end
      util.safe("dashboard", M.open)
    end,
  })
end

return M
