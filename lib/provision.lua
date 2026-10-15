-- Headless plugin provisioning, driven by bin/rihla. Not part of the editor config.
--
-- Run as:  nvim --headless -i NONE --cmd "luafile <rihla>/lib/provision.lua"
-- The user's real init.lua then loads as usual; this file only wraps lazy.setup so the
-- run never clones on its own, then acts on VimEnter according to RIHLA_PROVISION:
--   list     print "name<TAB>url<TAB>dir<TAB>commit<TAB>branch" for every plugin
--   restore  (git mode) install missing plugins, check out the lockfile commits, remove
--            plugins that left the config
--   build    (tarball mode) run lazy's build steps, remove plugins that left the config
--   check    verify every plugin is present at its lockfile commit
-- Output goes to RIHLA_PROVISION_OUT (or stdout). Exit status is non-zero when any
-- plugin failed, so the installer can stop with a clear message.

local mode = vim.env.RIHLA_PROVISION or "check"
local out = vim.env.RIHLA_PROVISION_OUT
local lazydir = vim.env.RIHLA_LAZY_DIR or (vim.fn.stdpath("data") .. "/lazy/lazy.nvim")

local lines, failed = {}, 0
local function emit(s)
  lines[#lines + 1] = s
end
local function fail(s)
  failed = failed + 1
  emit("FAIL\t" .. s)
end

local function finish()
  local text = table.concat(lines, "\n") .. "\n"
  if out and out ~= "" then
    local f = assert(io.open(out, "w"))
    f:write(text)
    f:close()
  else
    io.stdout:write(text)
  end
  vim.cmd(failed > 0 and "cquit 1" or "qall!")
end

vim.opt.rtp:prepend(lazydir)
local ok, lazy = pcall(require, "lazy")
local setup_called = false

if ok then
  local orig = lazy.setup
  lazy.setup = function(spec, opts)
    if type(spec) == "table" and spec.spec then
      opts, spec = spec, nil
    end
    opts = opts or {}
    if spec ~= nil then
      opts.spec = spec
    end
    -- Never clone or check for updates behind the installer's back.
    opts.install = vim.tbl_extend("force", opts.install or {}, { missing = false })
    opts.checker = vim.tbl_extend("force", opts.checker or {}, { enabled = false })
    opts.change_detection = vim.tbl_extend("force", opts.change_detection or {}, { enabled = false })
    setup_called = true
    return orig(opts.spec, opts)
  end
end

local function read_lock(path)
  local f = io.open(path, "r")
  if not f then
    return {}
  end
  local data = f:read("*a")
  f:close()
  local okj, lock = pcall(vim.json.decode, data)
  return okj and type(lock) == "table" and lock or {}
end

local function managed_plugins()
  local Config = require("lazy.core.config")
  local list = {}
  for _, p in pairs(Config.plugins) do
    if not p._.is_local and not p.virtual then
      list[#list + 1] = p
    end
  end
  table.sort(list, function(a, b)
    return a.name < b.name
  end)
  return list, Config
end

local function task_errors(p)
  local msgs = {}
  for _, t in ipairs(p._.tasks or {}) do
    if t:has_errors() then
      local o = t:output(vim.log.levels.ERROR) or ""
      msgs[#msgs + 1] = (t.name or "task") .. ": " .. o:gsub("%s+", " "):sub(1, 300)
    end
  end
  return msgs
end

local function check(plugins, Config)
  local Git = require("lazy.manage.git")
  local lock = read_lock(Config.options.lockfile)
  -- Directories of plugins no longer in the spec (removed upstream): clean them.
  for _, p in ipairs(Config.to_clean or {}) do
    fail(p.name .. "\tno longer in the config (stale directory " .. p.dir .. ")")
  end
  -- Plugins whose `cond` is false here (e.g. gitsigns without git) are not needed now;
  -- lazy installs them if the condition changes.
  local skipped = vim.tbl_keys(Config.spec.ignore_installed or {})
  table.sort(skipped)
  for _, name in ipairs(skipped) do
    emit("skip\t" .. name .. "\tcond is false on this machine")
  end
  for _, p in ipairs(plugins) do
    local errs = task_errors(p)
    if not vim.uv.fs_stat(p.dir) then
      fail(p.name .. "\tnot installed")
    elseif #errs > 0 then
      fail(p.name .. "\t" .. table.concat(errs, " | "))
    else
      local want = lock[p.name] and lock[p.name].commit
      local info = Git.info(p.dir)
      local have = info and info.commit
      if want and have ~= want then
        fail(p.name .. "\tat " .. tostring(have) .. ", lockfile wants " .. want)
      elseif not want then
        emit("WARN\t" .. p.name .. "\tnot in lazy-lock.json")
      else
        emit("ok\t" .. p.name .. "\t" .. have)
      end
    end
  end
end

-- The rihla config keeps lazy's working lockfile outside the repo and merges the repo's
-- pins into it; make sure that merge has happened so we act on the repo's pins.
local function sync_lock()
  local okr, rl = pcall(require, "rihla.lazy")
  if okr and type(rl) == "table" and type(rl.merge_lock) == "function" then
    pcall(rl.merge_lock)
  end
  pcall(function()
    local Lock = require("lazy.manage.lock")
    Lock._loaded = false
    Lock.load()
  end)
end

local function main()
  if not ok then
    fail("lazy.nvim\tnot found at " .. lazydir)
    return
  end
  if not setup_called then
    fail("config\tinit.lua never called require('lazy').setup()")
    return
  end
  sync_lock()
  local plugins, Config = managed_plugins()
  if mode == "list" then
    local lock = read_lock(Config.options.lockfile)
    for _, p in ipairs(plugins) do
      local l = lock[p.name] or {}
      emit(table.concat({ p.name, p.url or "", p.dir, l.commit or p.commit or "", l.branch or p.branch or "" }, "\t"))
    end
    return
  end
  local Manage = require("lazy.manage")
  if mode == "restore" then
    -- install clones what is missing (checked out at the lockfile commit); restore moves
    -- plugins that are present but at another commit.
    Manage.install({ wait = true, show = false, lockfile = true })
    Manage.restore({ wait = true, show = false })
    Manage.clean({ wait = true, show = false })
  elseif mode == "build" then
    local todo = {}
    for _, p in ipairs(plugins) do
      if p.build and p._.installed then
        todo[#todo + 1] = p
      end
    end
    if #todo > 0 then
      Manage.build({ plugins = todo, wait = true, show = false })
    end
    Manage.clean({ wait = true, show = false })
  end
  check(plugins, Config)
end

vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = function()
    vim.schedule(function()
      local okm, err = xpcall(main, debug.traceback)
      if not okm then
        fail("provision\t" .. tostring(err):gsub("\n", " "))
      end
      finish()
    end)
  end,
})
