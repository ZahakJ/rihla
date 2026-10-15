-- Headless smoke test for the rihla Neovim config.
--
--   nvim --headless "+luafile nvim/tests/smoke.lua"
--   (or nvim/tests/run.sh smoke)
--
-- Exits 0 when everything passes, 1 otherwise, printing one line per check.
-- Checks:
--   1. startup produced no errors or warnings (rihla's own error list,
--      v:errmsg and :messages)
--   2. every plugin in nvim/lazy-lock.json is installed and loads cleanly
--   3. every <leader> mapping (and every rihla mapping) has a description
--   4. in ascii icon mode, no UI string rihla controls contains a Nerd Font
--      (private-use-area) glyph: icons table, status line, buffer line,
--      which-key, file tree, completion kinds, diagnostic/dap signs,
--      lazy/mason UI icons, dashboard, the picker (snacks) and the breadcrumb
--   5. the dashboard, cheat sheet, VS Code picker data, lesson list and the
--      command palette build without errors (lessons: nvim/tests/learn.lua)
local results, failed = {}, 0
local function check(name, ok, detail)
  if vim.env.RIHLA_TEST_VERBOSE then io.stderr:write(name .. "\n") end
  results[#results + 1] = ("%s  %s%s"):format(ok and "PASS" or "FAIL", name, (detail and detail ~= "") and ("  -- " .. detail) or "")
  if not ok then
    failed = failed + 1
  end
end

local function finish()
  for _, l in ipairs(results) do
    io.stdout:write(l .. "\n")
  end
  io.stdout:write(("%d checks, %d failed\n"):format(#results, failed))
  vim.cmd(failed == 0 and "qa!" or "cquit 1")
end

local util = require("rihla.util")
-- Tests must not download tools; the LSP test (lsp_e2e.lua) does that on purpose.
vim.g.rihla_auto_install = false

-- Anything that looks like trouble in :messages.
local function bad_messages()
  local msgs = vim.split(vim.fn.execute("messages"), "\n", { trimempty = true })
  local bad = {}
  for _, m in ipairs(msgs) do
    local lm = m:lower()
    if
      m:match("E%d+:")
      or lm:match("error")
      or lm:match("warn")
      or lm:match("traceback")
      or lm:match("deprecat")
      or lm:match("failed")
    then
      bad[#bad + 1] = m
    end
  end
  return bad
end

-- Private use areas: BMP U+E000-F8FF, planes 15 and 16. Nerd Font glyphs live there.
local function pua(s)
  if type(s) ~= "string" then
    return nil
  end
  local ok, codes = pcall(vim.str_utf_pos, s)
  if not ok then
    return nil
  end
  for _, start in ipairs(codes) do
    local ch = s:sub(start, start + 3)
    local okc, cp = pcall(vim.fn.char2nr, ch, true)
    if okc and ((cp >= 0xE000 and cp <= 0xF8FF) or cp >= 0xF0000) then
      return ("U+%X"):format(cp)
    end
  end
  return nil
end

local function scan(value, path, found, seen)
  seen = seen or {}
  local t = type(value)
  if t == "string" then
    local hit = pua(value)
    if hit then
      found[#found + 1] = path .. "=" .. hit
    end
  elseif t == "table" and not seen[value] then
    seen[value] = true
    for k, v in pairs(value) do
      scan(v, path .. "." .. tostring(k), found, seen)
    end
  end
  return found
end

local function buf_text(buf)
  return table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end

local function run()
  -- 1. startup ---------------------------------------------------------------
  local errs = {}
  for _, e in ipairs(util.errors) do
    errs[#errs + 1] = e.name .. ": " .. tostring(e.err):match("^[^\n]*")
  end
  check("startup: no rihla errors", #errs == 0, table.concat(errs, " | "))
  check("startup: v:errmsg empty", vim.v.errmsg == "", vim.v.errmsg)
  local bad = bad_messages()
  check("startup: no errors/warnings in :messages", #bad == 0, table.concat(bad, " | "))
  check("startup: icons mode is " .. tostring(vim.g.rihla_icons), vim.g.rihla_icons == "ascii" or vim.g.rihla_icons == "nerd")

  -- 2. plugins from the lockfile ---------------------------------------------
  local lock = vim.json.decode(util.read(util.root .. "/nvim/lazy-lock.json") or "{}")
  local lazy = require("lazy")
  local by_name = {}
  for _, p in ipairs(lazy.plugins()) do
    by_name[p.name] = p
  end
  local not_installed, load_fail, skipped, wrong_commit = {}, {}, {}, {}
  local names = vim.tbl_keys(lock)
  table.sort(names)
  for _, name in ipairs(names) do
    local p = by_name[name]
    local disabled = (require("lazy.core.config").spec.disabled or {})[name]
    if not p and disabled then
      skipped[#skipped + 1] = name -- cond = false on this Neovim (e.g. tree-sitter on 0.11)
    elseif not p then
      not_installed[#not_installed + 1] = name .. "(not in spec)"
    elseif p.cond == false or (type(p.cond) == "function" and not p.cond()) then
      skipped[#skipped + 1] = name
    elseif not p._.installed then
      not_installed[#not_installed + 1] = name
    else
      local head = vim.fn.executable("git") == 1 and vim.trim(vim.fn.system({ "git", "-C", p.dir, "rev-parse", "HEAD" }))
        or vim.trim(util.read(p.dir .. "/.git/HEAD") or "")
      if head:match("^%x+$") and head ~= lock[name].commit then
        wrong_commit[#wrong_commit + 1] = name
      end
      local before = #util.errors
      local ok, err = pcall(lazy.load, { plugins = { name } })
      if not ok or not p._.loaded or #util.errors > before then
        load_fail[#load_fail + 1] = name .. ": " .. tostring(err or (util.errors[#util.errors] or {}).err):match("^[^\n]*")
      end
    end
  end
  check(("plugins: all %d in lockfile installed"):format(#names - #skipped), #not_installed == 0, table.concat(not_installed, ", "))
  check("plugins: checked out at the locked commit", #wrong_commit == 0, table.concat(wrong_commit, ", "))
  check("plugins: all load without error", #load_fail == 0, table.concat(load_fail, " | "))
  if #skipped > 0 then
    check("plugins: skipped on this Neovim (cond): " .. table.concat(skipped, ", "), true)
  end
  vim.wait(200)
  bad = bad_messages()
  check("plugins: no errors/warnings in :messages after loading all", #bad == 0, table.concat(bad, " | "))

  -- 3. descriptions on mappings ----------------------------------------------
  -- Open a real file in a git repo so buffer-local maps (gitsigns) exist too.
  local tmp = vim.fn.tempname()
  vim.fn.mkdir(tmp, "p")
  local has_git = vim.fn.executable("git") == 1
  if has_git then
    vim.fn.system({ "git", "-C", tmp, "init", "-q" })
  end
  vim.fn.writefile({ "local a = 1", "return a" }, tmp .. "/x.lua")
  if has_git then
    vim.fn.system({ "git", "-C", tmp, "add", "." })
  end
  vim.cmd("edit " .. tmp .. "/x.lua")
  vim.fn.writefile({ "local a = 2", "return a" }, tmp .. "/x.lua")
  if has_git then
    vim.wait(1500, function()
      return vim.b.gitsigns_status_dict ~= nil
    end)
  end
  local leader = vim.g.mapleader
  local missing = {}
  for _, mode in ipairs({ "n", "x", "o", "i", "t", "v" }) do
    local maps = vim.api.nvim_get_keymap(mode)
    vim.list_extend(maps, vim.api.nvim_buf_get_keymap(0, mode))
    for _, m in ipairs(maps) do
      local is_leader = m.lhs:sub(1, #leader) == leader and #m.lhs > #leader
      if is_leader and (m.desc == nil or m.desc == "") and not m.lhs:match("<Plug>") then
        missing[#missing + 1] = mode .. ":" .. m.lhs:gsub(" ", "<leader>", 1)
      end
    end
  end
  check("keymaps: every <leader> mapping has a description", #missing == 0, table.concat(missing, ", "))
  local count = 0
  for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
    if m.lhs:sub(1, #leader) == leader then
      count = count + 1
    end
  end
  check(("keymaps: %d normal-mode <leader> mappings"):format(count), count > 60)

  -- 4. icons -----------------------------------------------------------------
  if vim.g.rihla_icons == "ascii" then
    local icons = require("rihla.icons")
    local found = {}
    scan({ diag = icons.diag, git = icons.git, sep = icons.sep, ui = icons.ui, dap = icons.dap, kinds = icons.kinds }, "icons", found)
    -- status line and buffer line, evaluated
    vim.cmd("vsplit | edit " .. tmp .. "/y.lua")
    vim.diagnostic.set(vim.api.nvim_create_namespace("smoke"), 0, {
      { lnum = 0, col = 0, message = "e", severity = 1 },
      { lnum = 0, col = 0, message = "w", severity = 2 },
    })
    local okl = pcall(function()
      require("lualine").refresh({ force = true })
    end)
    local sl = vim.o.statusline ~= "" and vim.api.nvim_eval_statusline(vim.o.statusline, { use_tabline = false }).str or ""
    scan(sl, "statusline", found)
    if vim.o.tabline ~= "" then
      scan(vim.api.nvim_eval_statusline(vim.o.tabline, { use_tabline = true }).str, "tabline", found)
    end
    check("ascii: status line rendered", okl and sl ~= "", sl)
    -- signs
    scan(vim.diagnostic.config(), "diagnostic.config", found)
    for _, s in ipairs(vim.fn.sign_getdefined()) do
      scan(s.text, "sign." .. s.name, found)
    end
    -- plugin configs that carry glyphs
    scan(require("lazy.core.config").options.ui.icons, "lazy.ui.icons", found)
    local okm, mset = pcall(require, "mason.settings")
    if okm then
      scan(mset.current.ui.icons, "mason.ui.icons", found)
    end
    scan(require("which-key.config").options.icons, "which-key.icons", found)
    local okb, bcfg = pcall(require, "blink.cmp.config")
    if okb then
      scan(bcfg.appearance.kind_icons, "blink.kind_icons", found)
    end
    local oks = pcall(function()
      local cfg = Snacks.picker.config.get()
      scan({ cfg.prompt, cfg.icons }, "snacks.picker", found)
    end)
    check("ascii: snacks.picker config read", oks)
    local okdb, dbcfg = pcall(require, "dropbar.configs")
    if okdb then
      scan({ dbcfg.opts.icons.ui, dbcfg.opts.icons.enable and dbcfg.opts.icons.kinds.symbols or {} }, "dropbar", found)
    end
    local okgf, gfo = pcall(function()
      local o = require("grug-far.opts")
      return o.getGlobalOptions()
    end)
    check("ascii: grug-far options read", okgf and type(gfo) == "table", not okgf and tostring(gfo) or nil)
    if okgf and type(gfo) == "table" then
      scan({ gfo.icons and gfo.icons.enabled ~= false and gfo.icons or {}, gfo.spinnerStates, gfo.resultsSeparatorLineChar }, "grug-far", found)
    end
    -- a picker, rendered: the file picker on this folder
    local okpk = pcall(function()
      local p = require("rihla.find").files()
      vim.wait(3000, function()
        return p and not p:is_active()
      end)
      vim.wait(200)
      for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
        local c = vim.api.nvim_win_get_config(win)
        if c.relative ~= "" then
          scan(buf_text(vim.api.nvim_win_get_buf(win)), "picker window", found)
          scan({ c.title, c.footer }, "picker title", found)
          local wo = vim.wo[win].statuscolumn
          if wo ~= "" then
            scan(vim.api.nvim_eval_statusline(wo, { winid = win, use_statuscol_lnum = 1 }).str, "picker prompt", found)
          end
        end
      end
      p:close()
      vim.wait(100)
    end)
    check("ascii: file picker rendered", okpk)
    -- the breadcrumb, rendered
    local okbar = pcall(function()
      vim.api.nvim_eval_statusline(vim.wo.winbar, { winid = 0, use_winbar = true })
      local bar = require("dropbar.api").get_dropbar(vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win())
      if bar then
        scan(bar:cat(true), "breadcrumb", found)
      end
    end)
    check("ascii: breadcrumb rendered", okbar)
    local okd, dcfg = pcall(require, "dapui.config")
    if okd then
      scan(dcfg.icons, "dapui.icons", found)
    end
    -- which-key popup, rendered
    -- show() waits for a key, so a timer reads the popup and then presses Esc.
    local wk_seen = false
    vim.defer_fn(function()
      for _, win in ipairs(vim.api.nvim_list_wins()) do
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == "wk" then
          wk_seen = true
          scan(buf_text(buf), "which-key popup", found)
        end
      end
      vim.api.nvim_input("<Esc>")
    end, 400)
    local okw = pcall(function()
      require("which-key").show({ keys = "<leader>", loop = false })
    end)
    vim.wait(800, function()
      return wk_seen
    end)
    check("ascii: which-key popup opened", okw and wk_seen)
    -- file tree, rendered
    local okn, errn = pcall(vim.cmd, "NvimTreeOpen " .. tmp)
    vim.wait(300)
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      local buf = vim.api.nvim_win_get_buf(win)
      if vim.bo[buf].filetype == "NvimTree" then
        scan(buf_text(buf), "nvim-tree", found)
      end
    end
    pcall(vim.cmd, "NvimTreeClose")
    check("ascii: file tree opened", okn, okn and "" or tostring(errn))
    -- dashboard, rendered
    vim.cmd("tabnew")
    local okdash = pcall(require("rihla.dashboard").open)
    scan(buf_text(0), "dashboard", found)
    check("ascii: dashboard rendered", okdash and #buf_text(0) > 100)
    vim.cmd("tabclose!")
    check("ascii: no Nerd Font glyphs in UI strings", #found == 0, table.concat(found, ", "))
  else
    check("icons: nerd mode (ascii scan skipped; run with RIHLA_ICONS=ascii)", true)
  end

  -- 5. teaching layer -----------------------------------------------------------
  local learn = require("rihla.learn")
  local lessons = learn.lessons()
  check(("learn: %d lessons found"):format(#lessons), #lessons >= 15)
  check("learn: tips found", #learn.tips() >= 15, tostring(#learn.tips()))
  -- (nvim/tests/learn.lua checks the lessons themselves, with its own state dir.)
  local rows = require("rihla.cheat").rows()
  check(("vscode table: %d rows"):format(#rows), #rows >= 50)
  local okf, win = pcall(require("rihla.ui").float_file, util.docs .. "/cheatsheet-nvim.md", "cheat")
  check("cheat sheet: float opens", okf and win ~= nil)
  if okf and win then
    pcall(vim.api.nvim_win_close, win, true)
  end
  local okp, items = pcall(require("rihla.cmdpalette").items)
  check("palette: builds", okp and #items > 60, okp and tostring(#items) or tostring(items))
  local okh = pcall(vim.cmd, "checkhealth rihla")
  check("checkhealth rihla runs", okh)
  -- Diagnostics are underlined with a curl in their own colour.
  local curl = {}
  for _, n in ipairs({ "Error", "Warn", "Info", "Hint" }) do
    local hl = vim.api.nvim_get_hl(0, { name = "DiagnosticUnderline" .. n, link = false })
    if not (hl.undercurl and hl.sp) then
      curl[#curl + 1] = n
    end
  end
  check("diagnostics: undercurl with a colour", #curl == 0, table.concat(curl, ", "))

  -- final sweep
  errs = {}
  for _, e in ipairs(util.errors) do
    errs[#errs + 1] = e.name .. ": " .. tostring(e.err):match("^[^\n]*")
  end
  check("end: no rihla errors after all checks", #errs == 0, table.concat(errs, " | "))
  bad = bad_messages()
  check("end: no errors/warnings in :messages", #bad == 0, table.concat(bad, " | "))
end

-- Run after startup has fully settled (VeryLazy plugins, deferred hints).
vim.defer_fn(function()
  local ok, err = xpcall(run, debug.traceback)
  if not ok then
    check("smoke script itself", false, err)
  end
  finish()
end, 800)
