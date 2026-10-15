-- :checkhealth rihla (also :Rihla check, Space h C). Says what works on this machine,
-- what degraded, and the one thing to install to fix each.
local util = require("rihla.util")
local tools = require("rihla.tools")

local M = {}

local h = vim.health

local function bin_version(bin, args)
  local ok, res = pcall(function()
    return vim.system({ bin, unpack(args or { "--version" }) }, { text = true }):wait(3000)
  end)
  if not ok or not res or res.code ~= 0 then
    return nil
  end
  return vim.trim((res.stdout ~= "" and res.stdout or res.stderr or ""):match("[^\n]*"))
end

function M.check()
  h.start("rihla: core")
  local v = vim.version()
  local vs = ("%d.%d.%d"):format(v.major, v.minor, v.patch)
  if vim.fn.has("nvim-0.12") == 1 then
    h.ok("Neovim " .. vs)
  elseif vim.fn.has("nvim-0.11") == 1 then
    h.warn("Neovim " .. vs .. ": works, but tree-sitter parsers cannot be installed (needs 0.12)", { "Run `rihla install` to get the pinned Neovim." })
  end
  h.info("rihla root: " .. util.root:gsub("^" .. vim.pesc(vim.env.HOME or "~"), "~"))
  h.info("icons: " .. vim.g.rihla_icons .. "  (:Rihla icons nerd|ascii)")
  h.info("habit hints: " .. tostring(vim.g.rihla_habits) .. "  (<leader>th)")
  h.info("format on save: " .. tostring(vim.g.rihla_format_on_save) .. "  (<leader>tf)")
  h.info("auto-install language tools: " .. tostring(vim.g.rihla_auto_install))
  if #util.errors == 0 then
    h.ok("no configuration errors this session")
  else
    for _, e in ipairs(util.errors) do
      h.error(e.name .. ": " .. tostring(e.err):match("^[^\n]*"), { ":Rihla log for the full trace" })
    end
  end
  for k, msg in pairs(util.hints) do
    h.warn(msg, { "hint id: " .. k })
  end

  h.start("rihla: plugins")
  local ok, lazy = pcall(require, "lazy")
  if not ok then
    h.error("lazy.nvim is not installed", { "Run `rihla update` (needs git and network once)" })
  else
    local st = lazy.stats()
    h.ok(("%d plugins, %d loaded so far, startup %.1f ms"):format(st.count, st.loaded, st.startuptime or 0))
    local missing = {}
    for _, p in ipairs(lazy.plugins()) do
      if not p._.installed and p.cond ~= false then
        missing[#missing + 1] = p.name
      end
    end
    if #missing > 0 then
      h.warn("not installed: " .. table.concat(missing, ", "), { "Run `rihla update` or :Lazy install" })
    end
  end
  h.info("lockfile: " .. require("rihla.lazy").lock:gsub("^" .. vim.pesc(vim.env.HOME or "~"), "~"))

  h.start("rihla: external tools (all optional)")
  local list = {
    { "git", "plugins, git integration", true },
    { "rg", "project search (<leader>fg) and find-and-replace (<leader>rp)" },
    { "fd", "file search (<leader>ff); falls back to rg --files or find" },
    { "lazygit", "<leader>gg full-screen git UI; falls back to :Git" },
    { "node", "npm-based language servers (TS, JSON, YAML, Bash, HTML, CSS)" },
    { "python3", "Python language servers, formatters, debugpy" },
    { "curl", "mason and tree-sitter downloads", true },
    { "unzip", "mason (unpacks most tools)", true },
    { "tar", "mason and tree-sitter downloads", true },
    { "tree-sitter", "building parsers (mason installs it if missing)" },
  }
  for _, t in ipairs(list) do
    if util.has(t[1]) then
      h.ok(("%s: %s"):format(t[1], t[2]))
    elseif t[3] then
      h.warn(("%s missing: %s"):format(t[1], t[2]))
    else
      h.info(("%s missing: %s"):format(t[1], t[2]))
    end
  end
  if util.has("python3") and not require("rihla.tools").python3_venv() then
    h.warn("python3 has no venv/ensurepip: Python language servers, ruff and debugpy cannot be installed", {
      "Debian/Ubuntu: sudo apt install python3-venv (ask your administrator if you have no sudo)",
    })
  end
  if util.has_cc() then
    h.ok("C compiler: tree-sitter parsers can be built")
  else
    h.warn("no C compiler: syntax uses Vim's regex highlighting except for bundled parsers (C, Lua, Markdown, Vim, help)", {
      "Install gcc or clang, or copy parsers into ~/.local/share/nvim/site/parser/",
    })
  end
  if util.has("node") then
    local nv = bin_version("node")
    local major = nv and tonumber(nv:match("v(%d+)"))
    if major and major < 18 then
      h.warn("node " .. nv .. " is old; most npm language servers need 18+")
    else
      h.ok("node " .. (nv or "?"))
    end
  end
  local glibc = bin_version("ldd")
  if glibc then
    h.info("libc: " .. glibc)
  end

  h.start("rihla: clipboard")
  if vim.g.clipboard and type(vim.g.clipboard) == "table" and vim.g.clipboard.name == "OSC 52 (rihla)" then
    h.ok("OSC 52: yanks travel through the terminal (and tmux) to your local clipboard")
  elseif vim.fn.has("clipboard") == 1 then
    h.ok("system clipboard provider found; y and p use it")
  else
    h.warn("no clipboard provider: yank stays inside Neovim", { "Install wl-clipboard (Wayland) or xclip (X11)" })
  end
  if vim.o.termguicolors then
    h.ok("true colour")
  else
    h.warn("no true colour: using a 256-colour fallback theme", { "export COLORTERM=truecolor if the terminal supports it" })
  end

  h.start("rihla: languages (:Rihla langs for the table)")
  local lang = require("rihla.lang")
  for _, row in ipairs(M.lang_rows()) do
    local e = lang.langs[row.name]
    local line = ("%-10s %s"):format(row.name, row.summary)
    if row.lsp_ok or not e.lsp or #e.lsp == 0 then
      h.ok(line)
    else
      h.info(line)
    end
  end
end

--- One row per language for the status table.
function M.lang_rows()
  local lang = require("rihla.lang")
  local names = vim.tbl_keys(lang.langs)
  table.sort(names)
  local rows = {}
  local function has_parser(p)
    return #vim.api.nvim_get_runtime_file("parser/" .. p .. ".*", false) > 0
  end
  for _, name in ipairs(names) do
    local e = lang.langs[name]
    local parts = {}
    -- parsers
    local ts = e.ts or {}
    local have = 0
    for _, p in ipairs(ts) do
      if has_parser(p) then
        have = have + 1
      end
    end
    if #ts > 0 then
      parts[#parts + 1] = ("syntax:%s"):format(have == #ts and "tree-sitter" or (have > 0 and "partial" or "regex"))
    end
    -- servers
    local lsp_ok = false
    local servers = {}
    for _, slot in ipairs(e.lsp or {}) do
      local alts = type(slot) == "table" and slot or { slot }
      local got
      for _, s in ipairs(alts) do
        if lang.server_ready(s) then
          got = s
          break
        end
      end
      if got then
        lsp_ok = true
        servers[#servers + 1] = got .. "(ok)"
      else
        local why = tools.blocker(alts[1])
        servers[#servers + 1] = alts[1] .. (why and "(cannot install: " .. why .. ")" or "(not installed)")
      end
    end
    if #servers > 0 then
      parts[#parts + 1] = "lsp:" .. table.concat(servers, ",")
    end
    local function tool_list(label, names_)
      if not names_ or #names_ == 0 then
        return
      end
      local s = {}
      for _, n in ipairs(names_) do
        s[#s + 1] = n .. (tools.available(n) and "(ok)" or "(-)")
      end
      parts[#parts + 1] = label .. ":" .. table.concat(s, ",")
    end
    tool_list("fmt", e.fmt)
    tool_list("lint", e.lint)
    tool_list("dap", e.dap)
    rows[#rows + 1] = { name = name, summary = table.concat(parts, "  "), lsp_ok = lsp_ok }
  end
  return rows
end

function M.langs_float()
  local lines = {
    "Languages  (ok = ready, (-) = not installed; :Rihla install <lang> installs now)",
    "Add or change languages in ~/.config/rihla/langs.lua (see lua/rihla/langs.lua)",
    "",
  }
  for _, r in ipairs(M.lang_rows()) do
    lines[#lines + 1] = ("%-11s %s"):format(r.name, r.summary)
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  local width = math.min(vim.o.columns - 4, 140)
  local height = math.min(#lines, vim.o.lines - 6)
  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    col = math.floor((vim.o.columns - width) / 2),
    row = math.floor((vim.o.lines - height) / 2) - 1,
    border = "rounded",
    style = "minimal",
    title = " rihla languages ",
    title_pos = "center",
    footer = " q or Esc closes ",
    footer_pos = "center",
  })
  vim.wo[win].wrap = false
  vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, desc = "Close" })
  vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, desc = "Close" })
end

return M
