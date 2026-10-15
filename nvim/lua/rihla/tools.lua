-- External tools (language servers, formatters, linters, debug adapters):
-- where they come from and how to install them with mason without blocking.
--
-- Each known tool: mason package, the executable it provides, and what the
-- installer needs on this machine ("npm" = Node.js, "python3" = Python with
-- venv, "go", "java"). Prebuilt binaries ("github") need nothing but may need
-- a newer glibc than an old distribution has; that is checked after install.
local util = require("rihla.util")

local M = {}

-- kind: lsp | fmt | lint | dap
M.known = {
  -- language servers (nvim-lspconfig names)
  lua_ls = { pkg = "lua-language-server", bin = "lua-language-server", src = "github" },
  basedpyright = { pkg = "basedpyright", bin = "basedpyright-langserver", src = "python3" },
  pyright = { pkg = "pyright", bin = "pyright-langserver", src = "npm" },
  pylsp = { pkg = "python-lsp-server", bin = "pylsp", src = "python3" },
  ruff = { pkg = "ruff", bin = "ruff", src = "python3" },
  clangd = { pkg = "clangd", bin = "clangd", src = "github" },
  rust_analyzer = { pkg = "rust-analyzer", bin = "rust-analyzer", src = "github" },
  gopls = { pkg = "gopls", bin = "gopls", src = "go" },
  ts_ls = { pkg = "typescript-language-server", bin = "typescript-language-server", src = "npm" },
  html = { pkg = "html-lsp", bin = "vscode-html-language-server", src = "npm" },
  cssls = { pkg = "css-lsp", bin = "vscode-css-language-server", src = "npm" },
  bashls = { pkg = "bash-language-server", bin = "bash-language-server", src = "npm" },
  jsonls = { pkg = "json-lsp", bin = "vscode-json-language-server", src = "npm" },
  yamlls = { pkg = "yaml-language-server", bin = "yaml-language-server", src = "npm" },
  taplo = { pkg = "taplo", bin = "taplo", src = "github" },
  marksman = { pkg = "marksman", bin = "marksman", src = "github" },
  dockerls = { pkg = "dockerfile-language-server", bin = "docker-langserver", src = "npm" },
  jdtls = { pkg = "jdtls", bin = "jdtls", src = "java" },
  -- formatters (conform.nvim names)
  stylua = { pkg = "stylua", bin = "stylua", src = "github" },
  ruff_format = { pkg = "ruff", bin = "ruff", src = "python3" },
  ruff_organize_imports = { pkg = "ruff", bin = "ruff", src = "python3" },
  ["clang-format"] = { pkg = "clang-format", bin = "clang-format", src = "python3" },
  rustfmt = { bin = "rustfmt", hint = "install Rust with rustup; rustfmt comes with it" },
  goimports = { pkg = "goimports", bin = "goimports", src = "go" },
  gofmt = { bin = "gofmt", hint = "comes with Go" },
  prettier = { pkg = "prettier", bin = "prettier", src = "npm" },
  shfmt = { pkg = "shfmt", bin = "shfmt", src = "github" },
  sql_formatter = { pkg = "sql-formatter", bin = "sql-formatter", src = "npm" },
  -- linters (nvim-lint names) and extras
  hadolint = { pkg = "hadolint", bin = "hadolint", src = "github" },
  shellcheck = { pkg = "shellcheck", bin = "shellcheck", src = "github" },
  -- debug adapters (lua/rihla/dap.lua names)
  debugpy = { pkg = "debugpy", src = "python3" },
  codelldb = { pkg = "codelldb", bin = "codelldb", src = "github" },
  delve = { pkg = "delve", bin = "dlv", src = "go" },
  gdb = { bin = "gdb", hint = "install gdb 14 or newer from your package manager" },
  -- tree-sitter's CLI, used to build parsers (with a C compiler)
  ["tree-sitter-cli"] = { pkg = "tree-sitter-cli", bin = "tree-sitter", src = "github" },
}

local NEEDS = {
  npm = { bins = { "node", "npm" }, why = "Node.js (node and npm)", short = "Node.js" },
  python3 = {
    bins = { "python3" },
    why = "python3 with the venv module (Debian/Ubuntu: python3-venv)",
    short = "python3",
    -- mason makes a venv per Python tool. Debian and Ubuntu ship python3 without
    -- ensurepip, so `python3 -m venv` fails and mason only reports "spawn: python3
    -- failed". Check up front so the message names the package to install.
    check = "python3_venv",
    missing = "python3-venv",
  },
  go = { bins = { "go" }, why = "the Go toolchain", short = "Go" },
  java = { bins = { "java" }, why = "Java 21 or newer", short = "Java 21+" },
}

local venv_ok -- nil = not checked yet
--- Can python3 make a virtual environment with pip in it (what mason does)?
function M.python3_venv()
  if venv_ok == nil then
    local ok, res = pcall(function()
      return vim.system({ "python3", "-c", "import venv, ensurepip" }, { stdin = false }):wait(5000)
    end)
    venv_ok = ok and res ~= nil and res.code == 0
  end
  return venv_ok
end

-- Which part of a runtime is missing: (short, long) or nil.
local function runtime_gap(need)
  for _, b in ipairs(need.bins) do
    if not util.has(b) then
      return need.short, need.why
    end
  end
  if need.check and not M[need.check]() then
    return need.missing,
      "python3's venv module (Debian/Ubuntu: sudo apt install python3-venv; ask your administrator if you have no sudo)"
  end
  return nil
end

--- What this tool needs that is missing, in one or two words ("Node.js"), or nil.
function M.missing_runtime(name)
  local t = M.known[name]
  local need = t and NEEDS[t.src]
  if not need then
    return nil
  end
  return (runtime_gap(need))
end

--- Mason's install root; its bin/ is prepended to PATH by mason.setup().
M.mason_root = vim.fn.stdpath("data") .. "/mason"

-- pip and npm, run by mason, would otherwise leave download caches in ~/.cache/pip and
-- ~/.npm that outlive `rihla uninstall`. Keep them under nvim's own cache directory
-- unless you chose a location yourself.
if not vim.env.PIP_CACHE_DIR then
  vim.env.PIP_CACHE_DIR = vim.fn.stdpath("cache") .. "/pip"
end
if not vim.env.npm_config_cache and not vim.env.NPM_CONFIG_CACHE then
  vim.env.npm_config_cache = vim.fn.stdpath("cache") .. "/npm"
end

--- Pinned registry: mason resolves package versions from this exact
--- snapshot, so a tool installed today and one installed next month match.
M.registry = "github:mason-org/mason-registry@2026-10-04-lucky-jar"

local mason_ready = false
function M.mason_setup()
  if mason_ready then
    return true
  end
  local ok = pcall(require, "mason")
  if not ok then
    return false
  end
  mason_ready = true
  return true
end

--- Is the tool's executable already available (system PATH or mason bin)?
function M.available(name, bin)
  local t = M.known[name]
  bin = bin or (t and t.bin)
  if not bin then
    -- debugpy: a Python module, not an executable
    if name == "debugpy" then
      return vim.fn.filereadable(M.mason_root .. "/packages/debugpy/venv/bin/python") == 1
    end
    return false
  end
  if util.has(bin) then
    return true
  end
  return vim.fn.executable(M.mason_root .. "/bin/" .. bin) == 1
end

--- Why can this tool not be installed here? nil if it can.
function M.blocker(name)
  local t = M.known[name]
  if not t then
    return ("rihla does not know how to install %s; put it on PATH"):format(name)
  end
  if not t.pkg then
    return t.hint or ("install %s yourself and put it on PATH"):format(t.bin)
  end
  local need = NEEDS[t.src]
  if need then
    local _, long = runtime_gap(need)
    if long then
      return ("%s needs %s, which is not installed"):format(t.pkg, long)
    end
  end
  if not (util.has("curl") or util.has("wget")) then
    return "mason needs curl or wget to download " .. t.pkg
  end
  if t.src == "github" and not util.has("unzip") and not util.has("tar") then
    return "mason needs unzip and tar to unpack " .. t.pkg
  end
  return nil
end

-- A prebuilt binary built against a newer glibc fails before main(); detect
-- that so the editor can say so instead of failing every time a file opens.
local function glibc_problem(bin)
  local path = vim.fn.exepath(bin)
  if path == "" then
    path = M.mason_root .. "/bin/" .. bin
  end
  local ok, res = pcall(function()
    return vim.system({ path, "--version" }, { text = true, stdin = false }):wait(5000)
  end)
  if not ok or not res then
    return nil
  end
  local out = (res.stderr or "") .. (res.stdout or "")
  return out:match("(GLIBC_[%d%.]+)") or out:match("(GLIBCXX_[%d%.]+)")
end

M.pending = 0
local waiting = {} -- pkg -> list of callbacks
local registry_refreshed = false

local function with_registry(cb)
  local registry = require("mason-registry")
  if registry_refreshed then
    return cb(registry)
  end
  registry.refresh(function(success)
    registry_refreshed = success ~= false
    cb(registry)
  end)
end

--- Install a tool by its rihla name; cb(ok, message) runs on the main loop.
--- Never blocks. Several requests for the same package share one install.
function M.install(name, cb)
  cb = cb or function() end
  local t = M.known[name]
  local why = M.blocker(name)
  if why then
    return cb(false, why)
  end
  if not M.mason_setup() then
    return cb(false, "mason.nvim is not available")
  end
  local pkgname = t.pkg
  if waiting[pkgname] then
    table.insert(waiting[pkgname], cb)
    return
  end
  waiting[pkgname] = { cb }
  M.pending = M.pending + 1
  local function finish(ok, msg)
    vim.schedule(function()
      M.pending = M.pending - 1
      util.reset_has()
      if ok and t.bin then
        local bad = glibc_problem(t.bin)
        if bad then
          ok = false
          msg = ("%s installed but needs %s, newer than this system's glibc. Install it from your package manager and put it on PATH"):format(
            pkgname,
            bad
          )
        end
      end
      local cbs = waiting[pkgname] or {}
      waiting[pkgname] = nil
      for _, f in ipairs(cbs) do
        pcall(f, ok, msg)
      end
    end)
  end
  local ok, err = pcall(with_registry, function(registry)
    local found, pkg = pcall(registry.get_package, pkgname)
    if not found then
      return finish(false, ("mason registry has no package %s (offline, or a proxy is needed? set https_proxy)"):format(pkgname))
    end
    if pkg:is_installed() then
      return finish(true)
    end
    util.log("[mason] installing " .. pkgname)
    util.say(("rihla: installing %s in the background (one time)..."):format(pkgname))
    if pkg:is_installing() then
      return finish(false, pkgname .. " is already being installed (see :Mason)")
    end
    pkg:install({}, function(success, e)
      if success then
        util.log("[mason] installed " .. pkgname)
        return finish(true)
      end
      util.log(("[mason] %s failed: %s"):format(pkgname, vim.inspect(e)))
      local why = tostring(e):match("^[^\n]*")
      if why:find("dial tcp") or why:find("Could not resolve") or why:find("resolve host") or why:find("network") then
        why = "no network?"
      elseif why:find('"unzip"') or why:find("unzip failed") then
        why = "needs unzip: install the unzip package"
      elseif why:find("python3 installation") then
        why = why:match("%(([^)]+)%)") and ("needs Python " .. why:match("%(([^)]+)%)")) or "needs a newer python3"
      elseif #why > 90 then
        why = why:sub(1, 87) .. "..."
      end
      finish(false, ("installing %s failed (%s); details in :MasonLog"):format(pkgname, why))
    end)
  end)
  if not ok then
    finish(false, "mason failed: " .. tostring(err):match("^[^\n]*"))
  end
end

--- Block until background installs finish (headless use: `rihla` pre-seeding).
function M.wait(timeout_ms)
  return vim.wait(timeout_ms or 600000, function()
    return M.pending == 0
  end, 200)
end

return M
