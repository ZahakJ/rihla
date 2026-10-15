-- Plugin manager bootstrap.
--
-- lazy.nvim itself is pinned to a commit here; every other plugin is pinned by
-- nvim/lazy-lock.json in the repository. Nothing updates on its own: the
-- update checker and change detection are off, and the only way plugins move
-- is `rihla update`, which pulls the repo, re-runs the installer (plugins go
-- to the lockfile commits) and, where git is usable, runs `:Rihla sync`.
--
-- The lockfile lazy writes to is a copy in stdpath("data")/rihla/, not the one
-- in the repo. That way plugins you add in ~/.config/rihla/plugins/ get
-- recorded without leaving the git checkout dirty (which would block updates).
local util = require("rihla.util")
local icons = require("rihla.icons")

local M = {}

M.LAZY_COMMIT = "85c7ff3711b730b4030d03144f6db6375044ae82" -- v11.17.5
M.LAZY_URL = "https://github.com/folke/lazy.nvim.git"
M.repo_lock = util.root .. "/nvim/lazy-lock.json"
M.lock = vim.fn.stdpath("data") .. "/rihla/lazy-lock.json"

local function decode(path)
  local s = util.read(path)
  if not s then
    return nil
  end
  local ok, t = pcall(vim.json.decode, s)
  return ok and type(t) == "table" and t or nil
end

--- Merge the repo's pins into the working lockfile. The repo wins for every
--- plugin it knows; plugins only you added keep their own pins.
function M.merge_lock()
  local repo = decode(M.repo_lock) or {}
  local mine = decode(M.lock) or {}
  for name, pin in pairs(repo) do
    mine[name] = pin
  end
  local names = vim.tbl_keys(mine)
  table.sort(names)
  local out = { "{" }
  for i, name in ipairs(names) do
    local p = mine[name]
    out[#out + 1] = ('  %s: { "branch": %s, "commit": %s }%s'):format(
      vim.json.encode(name),
      vim.json.encode(p.branch or ""),
      vim.json.encode(p.commit or ""),
      i < #names and "," or ""
    )
  end
  out[#out + 1] = "}\n"
  util.write(M.lock, table.concat(out, "\n"))
  util.write(M.lock .. ".repo-hash", vim.fn.sha256(util.read(M.repo_lock) or ""))
end

local function user_plugin_specs()
  local specs = {}
  local dir = util.user_dir .. "/plugins"
  for _, file in ipairs(vim.fn.globpath(dir, "*.lua", false, true)) do
    util.safe("user plugin spec " .. vim.fn.fnamemodify(file, ":t"), function()
      local spec = dofile(file)
      if type(spec) == "table" then
        table.insert(specs, spec)
      end
    end)
  end
  return specs
end

local ascii_lazy_icons = {
  cmd = "cmd ",
  config = "cfg ",
  debug = "dbg ",
  event = "ev ",
  favorite = "* ",
  ft = "ft ",
  init = "init ",
  import = "imp ",
  keys = "key ",
  lazy = "lazy ",
  loaded = "+",
  not_loaded = "-",
  plugin = "plug ",
  runtime = "rt ",
  require = "req ",
  source = "src ",
  start = "> ",
  task = "ok ",
  list = { "*", ">", "+", "-" },
}

function M.setup()
  local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
  local uv = vim.uv or vim.loop
  if not uv.fs_stat(lazypath .. "/lua/lazy/init.lua") then
    if not util.has("git") then
      util.hint("git", "git is not installed, so plugins cannot be fetched. Install git, then restart.", vim.log.levels.WARN)
      return false
    end
    vim.api.nvim_echo({ { "rihla: fetching the plugin manager (one time)...", "Comment" } }, false, {})
    local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--quiet", M.LAZY_URL, lazypath })
    if vim.v.shell_error == 0 then
      vim.fn.system({ "git", "-C", lazypath, "checkout", "--quiet", M.LAZY_COMMIT })
    end
    if vim.v.shell_error ~= 0 then
      vim.fn.delete(lazypath, "rf")
      util.hint(
        "lazy-clone",
        "could not fetch lazy.nvim (offline?). The editor works without plugins; run `rihla update` when online. "
          .. vim.trim(out or ""):gsub("\n", " "),
        vim.log.levels.WARN
      )
      return false
    end
  end
  vim.opt.rtp:prepend(lazypath)

  -- Seed or refresh the working lockfile from the repo.
  local repo_hash = vim.fn.sha256(util.read(M.repo_lock) or "")
  -- Merging only rewrites the pins; plugins move when `rihla update` (or
  -- :Rihla sync / :Lazy restore) runs, never at startup.
  if not uv.fs_stat(M.lock) or (util.read(M.lock .. ".repo-hash") or "") ~= repo_hash then
    M.merge_lock()
  end

  local spec = { { import = "rihla.plugins" } }
  vim.list_extend(spec, user_plugin_specs())

  local ok, lazy = pcall(require, "lazy")
  if not ok then
    util.hint("lazy-load", "lazy.nvim failed to load: " .. tostring(lazy):match("^[^\n]*"), vim.log.levels.WARN)
    return false
  end
  lazy.setup({
    spec = spec,
    lockfile = M.lock,
    defaults = { lazy = false, version = false }, -- versions come from the lockfile
    install = { missing = true, colorscheme = { "catppuccin-mocha", "habamax" } },
    checker = { enabled = false }, -- no background update checks, ever
    change_detection = { enabled = false, notify = false },
    rocks = { enabled = false }, -- no luarocks download; no plugin here needs it
    pkg = { enabled = false },
    ui = { border = "rounded", icons = icons.nerd and nil or ascii_lazy_icons, backdrop = 100 },
    performance = {
      rtp = {
        disabled_plugins = { "gzip", "tarPlugin", "tohtml", "zipPlugin", "rplugin" },
      },
    },
  })
  return true
end

--- Make installed plugins match the lockfile (used by `rihla update`).
--- Headless: nvim --headless "+Rihla sync" +qa
function M.sync()
  M.merge_lock()
  local lazy = require("lazy")
  lazy.restore({ wait = true, show = #vim.api.nvim_list_uis() > 0 })
  lazy.clean({ wait = true, show = false })
  -- Installed tree-sitter parsers must match the nvim-treesitter version.
  if util.has_cc() then
    pcall(function()
      local nts = require("nvim-treesitter")
      if #nts.get_installed() > 0 then
        nts.update():wait(300000)
      end
    end)
  end
end

return M
