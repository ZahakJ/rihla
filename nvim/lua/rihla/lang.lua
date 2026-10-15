-- The language engine: reads the langs table and, when a file type is first
-- opened, starts tree-sitter, enables the language server, and installs
-- whatever is missing in the background. Nothing here blocks startup.
local util = require("rihla.util")
local tools = require("rihla.tools")

local M = {}

M.langs = {} -- name -> entry
M.by_ft = {} -- filetype -> entry
local done = {} -- language name -> true once handled this session

local function list(x)
  if x == nil then
    return {}
  end
  return type(x) == "table" and x or { x }
end

function M.load()
  local base = vim.deepcopy(require("rihla.langs"))
  local user = util.user_dir .. "/langs.lua"
  if vim.fn.filereadable(user) == 1 then
    util.safe("~/.config/rihla/langs.lua", function()
      local extra = dofile(user)
      if type(extra) ~= "table" then
        error("langs.lua must return a table")
      end
      for name, entry in pairs(extra) do
        if entry == false then
          base[name] = nil
        elseif type(base[name]) == "table" and type(entry) == "table" then
          base[name] = vim.tbl_extend("force", base[name], entry)
        else
          base[name] = entry
        end
      end
    end)
  end
  M.langs, M.by_ft = {}, {}
  for name, entry in pairs(base) do
    entry.name = name
    M.langs[name] = entry
    for _, ft in ipairs(list(entry.ft)) do
      M.by_ft[ft] = entry
    end
  end
end

--- conform's formatters_by_ft, built from the table.
function M.formatters_by_ft()
  local out = {}
  for ft, e in pairs(M.by_ft) do
    if e.fmt and #e.fmt > 0 then
      out[ft] = vim.deepcopy(e.fmt)
    end
  end
  return out
end

--- nvim-lint's linters_by_ft, built from the table.
function M.linters_by_ft()
  local out = {}
  for ft, e in pairs(M.by_ft) do
    if e.lint and #e.lint > 0 then
      out[ft] = vim.deepcopy(e.lint)
    end
  end
  return out
end

-- Tree-sitter --------------------------------------------------------------

local function ts_lang(ft)
  return vim.treesitter.language.get_lang(ft) or ft
end

--- Start tree-sitter highlighting if a parser exists; return true on success.
--- Otherwise the buffer keeps Vim's regex syntax highlighting.
function M.ts_start(buf)
  local ft = vim.bo[buf].filetype
  if ft == "" then
    return false
  end
  local lang = ts_lang(ft)
  if not pcall(vim.treesitter.language.add, lang) then
    return false
  end
  local ok = pcall(vim.treesitter.start, buf, lang)
  if ok then
    -- Folding and (with nvim-treesitter) indentation from the syntax tree.
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      vim.wo[win][0].foldmethod = "expr"
      vim.wo[win][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
    end
    if package.loaded["nvim-treesitter"] and ft ~= "python" and ft ~= "yaml" then
      vim.bo[buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
    end
  end
  return ok
end

local ts_installing = {}
local function restart_ts(parsers)
  for _, b in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_loaded(b) and vim.tbl_contains(parsers, ts_lang(vim.bo[b].filetype)) then
      M.ts_start(b)
    end
  end
end

local function has_parser(lang)
  return #vim.api.nvim_get_runtime_file("parser/" .. lang .. ".*", false) > 0
end

--- Install missing parsers for a language (needs nvim-treesitter, a C
--- compiler and the tree-sitter CLI; mason fetches the CLI if missing).
function M.ts_install(entry, cb)
  cb = cb or function() end
  local missing = {}
  for _, p in ipairs(list(entry.ts)) do
    if not has_parser(p) and not ts_installing[p] then
      missing[#missing + 1] = p
    end
  end
  if #missing == 0 then
    return cb(true)
  end
  local ok_ts, nts = pcall(require, "nvim-treesitter")
  if not ok_ts then
    util.hint(
      "ts-nvim",
      "tree-sitter parsers can only be installed on Neovim 0.12+ (nvim-treesitter); using regex highlighting."
    )
    return cb(false)
  end
  if not util.has_cc() then
    util.hint(
      "ts-cc",
      "no C compiler, so tree-sitter parsers cannot be built; using Vim's regex highlighting. Install gcc or clang to upgrade."
    )
    return cb(false)
  end
  if not (util.has("curl") and util.has("tar")) then
    util.hint("ts-curl", "tree-sitter parser install needs curl and tar; using regex highlighting.")
    return cb(false)
  end
  local function go()
    for _, p in ipairs(missing) do
      ts_installing[p] = true
    end
    tools.pending = tools.pending + 1
    local ok, task = pcall(nts.install, missing)
    local function finish()
      tools.pending = tools.pending - 1
      for _, p in ipairs(missing) do
        ts_installing[p] = nil
      end
      restart_ts(missing)
      cb(true)
    end
    if not ok or type(task) ~= "table" then
      tools.pending = tools.pending - 1
      util.hint("ts-install-" .. entry.name, "tree-sitter install failed for " .. entry.name .. ": " .. tostring(task))
      return cb(false)
    end
    -- task:await(cb) runs cb when the async install finishes.
    if task.await then
      task:await(vim.schedule_wrap(finish))
    else
      vim.defer_fn(finish, 30000)
    end
  end
  if util.has("tree-sitter") or tools.available("tree-sitter-cli") then
    go()
  else
    tools.install("tree-sitter-cli", function(ok, msg)
      if ok then
        go()
      else
        util.hint("ts-cli", "tree-sitter CLI unavailable (" .. tostring(msg) .. "); using regex highlighting.")
        cb(false)
      end
    end)
  end
end

-- Language servers --------------------------------------------------------

local function server_bin(name)
  local ok, cfg = pcall(function()
    return vim.lsp.config[name]
  end)
  if ok and cfg and type(cfg.cmd) == "table" and cfg.cmd[1] then
    return cfg.cmd[1]
  end
  local t = tools.known[name]
  return t and t.bin
end

--- Is this server runnable right now (on PATH or in mason's bin)?
function M.server_ready(name)
  local bin = server_bin(name)
  return bin ~= nil and tools.available(name, bin)
end

local enabled = {}
local function enable(name)
  if enabled[name] then
    return
  end
  enabled[name] = true
  if not M._caps then
    -- Tell servers what the completion engine supports (snippets etc.)
    -- before the first one starts; blink is otherwise loaded on InsertEnter.
    M._caps = true
    pcall(function()
      vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })
    end)
  end
  util.safe("lsp " .. name, vim.lsp.enable, name)
end
M.enabled = enabled

--- For each server slot, enable the first available alternative; otherwise
--- install the first one this machine can install.
function M.ensure_lsp(entry, opts)
  opts = opts or {}
  for _, slot in ipairs(list(entry.lsp)) do
    local alts = list(slot)
    local picked
    for _, name in ipairs(alts) do
      if M.server_ready(name) then
        picked = name
        break
      end
    end
    if picked then
      enable(picked)
    elseif vim.g.rihla_auto_install or opts.force then
      local reasons = {}
      local candidates = {}
      for _, name in ipairs(alts) do
        local why = tools.blocker(name)
        if why then
          reasons[#reasons + 1] = why
        else
          candidates[#candidates + 1] = name
        end
      end
      if #candidates > 0 then
        -- Try each installable alternative in turn: basedpyright needs
        -- Python 3.10+, so on RHEL 9's Python 3.9 the next one is used.
        local failures = {}
        local function try(i)
          local target = candidates[i]
          if not target then
            util.hint(
              "lsp-" .. entry.name,
              ("no %s language server: %s"):format(entry.name, table.concat(failures, "; ")),
              vim.log.levels.WARN
            )
            return
          end
          tools.install(target, function(ok, msg)
            if ok then
              enable(target)
              util.say(("rihla: %s ready for %s"):format(target, entry.name))
            else
              util.log(("[lsp] %s: %s"):format(target, tostring(msg)))
              failures[#failures + 1] = tostring(msg)
              try(i + 1)
            end
          end)
        end
        try(1)
      else
        -- One short line: "needs python3 or Node.js". :Rihla langs has the detail.
        local needs, seen = {}, {}
        for _, name in ipairs(alts) do
          local r = tools.missing_runtime(name)
          if r and not seen[r] then
            seen[r] = true
            needs[#needs + 1] = r
          end
        end
        local why = #needs > 0 and ("needs " .. table.concat(needs, " or ")) or table.concat(reasons, "; ")
        util.hint(
          "lsp-" .. entry.name,
          ("no %s language server (%s); editing works without one. :Rihla langs"):format(entry.name, why)
        )
      end
    else
      util.hint(
        "lsp-" .. entry.name,
        ("no language server for %s on PATH; run :Rihla install %s"):format(entry.name, entry.name)
      )
    end
  end
end

--- Formatters, linters and extra tools: install quietly what is missing.
function M.ensure_tools(entry, opts)
  opts = opts or {}
  if not (vim.g.rihla_auto_install or opts.force) then
    return
  end
  local seen = {}
  local names = {}
  vim.list_extend(names, list(entry.fmt))
  vim.list_extend(names, list(entry.lint))
  vim.list_extend(names, list(entry.tools))
  if opts.with_dap then
    vim.list_extend(names, { list(entry.dap)[1] })
  end
  for _, name in ipairs(names) do
    local t = tools.known[name]
    local key = t and (t.pkg or t.bin) or name
    if not seen[key] and not tools.available(name) then
      seen[key] = true
      if not tools.blocker(name) then
        tools.install(name, function(ok, msg)
          if not ok then
            util.hint("tool-" .. name, msg)
          end
        end)
      elseif opts.force then
        util.hint("tool-" .. name, tools.blocker(name))
      end
    end
  end
end

--- Everything for one language. force = install even if auto-install is off.
function M.ensure(entry, opts)
  opts = opts or {}
  if vim.g.rihla_auto_install or opts.force then
    util.safe("treesitter " .. entry.name, M.ts_install, entry)
  end
  util.safe("lsp " .. entry.name, M.ensure_lsp, entry, opts)
  util.safe("tools " .. entry.name, M.ensure_tools, entry, opts)
end

function M.on_filetype(buf)
  local ft = vim.bo[buf].filetype
  if ft == "" or vim.bo[buf].buftype ~= "" then
    return
  end
  local entry = M.by_ft[ft]
  M.ts_start(buf)
  -- Lesson pages and rihla's own docs (the cheat sheets) are markdown, but nothing
  -- should be installed for them: the first minutes stay free of "installing ...".
  local name = vim.api.nvim_buf_get_name(buf)
  if require("rihla.learn").lesson_of(buf) or vim.startswith(name, util.docs .. "/") then
    return
  end
  if not entry or done[entry.name] then
    return
  end
  done[entry.name] = true
  -- Give the UI a moment first: opening a file must feel instant.
  vim.defer_fn(function()
    M.ensure(entry)
  end, 50)
end

function M.setup()
  M.load()
  local group = vim.api.nvim_create_augroup("rihla_lang", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    callback = function(ev)
      util.safe("filetype " .. ev.match, M.on_filetype, ev.buf)
    end,
  })
  -- Buffers opened before this ran (nvim file.py) get the same treatment.
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.bo[b].filetype ~= "" then
          util.safe("filetype", M.on_filetype, b)
        end
      end
    end,
  })
end

return M
