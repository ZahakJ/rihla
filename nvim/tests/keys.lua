-- Docs vs real mappings: every `Space ...` key written in docs/ (and in the
-- dashboard / palette strings) must exist as a mapping, and so must the
-- non-leader keys rihla adds. Run from nvim/tests/run.sh keys.
--
-- LSP and gitsigns keys are buffer-local, so the test fires LspAttach on a
-- scratch buffer and opens a file inside a git repository first.
local root = vim.fn.fnamemodify(vim.fn.resolve(vim.fn.stdpath("config")), ":h")
-- gitsigns is switched off by its cond where git is missing or too old; its keys too.
local function gitsigns_on()
  local ok, cfg = pcall(require, "lazy.core.config")
  local p = ok and cfg.plugins["gitsigns.nvim"]
  return p ~= nil and p ~= false and not (p._ and p._.cond == false)
end
local fails, checks = 0, 0
local function report(ok, name, detail)
  checks = checks + 1
  if not ok then
    fails = fails + 1
  end
  io.stdout:write(("%s  %s%s\n"):format(ok and "PASS" or "FAIL", name, detail and ("  -- " .. detail) or ""))
end

pcall(function()
  require("lazy").load({ plugins = vim.tbl_keys(require("lazy.core.config").plugins), wait = true })
end)

-- A file in a git repository, so gitsigns attaches (when git exists).
local tmp = vim.fn.tempname()
vim.fn.mkdir(tmp, "p")
local f = tmp .. "/a.py"
vim.fn.writefile({ "x = 1" }, f)
if vim.fn.executable("git") == 1 then
  vim.fn.system({ "git", "-C", tmp, "init", "-q" })
  vim.fn.system({ "git", "-C", tmp, "add", "a.py" })
  vim.fn.writefile({ "x = 2" }, f)
end
vim.cmd.edit(f)
local buf = vim.api.nvim_get_current_buf()
vim.api.nvim_exec_autocmds("LspAttach", { buffer = buf, data = { client_id = 0 }, modeline = false })
vim.wait(5000, function()
  return not gitsigns_on() or vim.fn.maparg("]h", "n") ~= ""
end)

local lhs = {}
local function collect(maps)
  for _, m in ipairs(maps) do
    local k = vim.fn.keytrans(vim.keycode(m.lhs)):lower()
    lhs[k] = true
    lhs[(k:gsub("<nl>", "<c-j>"))] = true
  end
end
for _, mode in ipairs({ "n", "x", "o", "i", "t" }) do
  collect(vim.api.nvim_get_keymap(mode))
  collect(vim.api.nvim_buf_get_keymap(buf, mode))
end

-- "Space f g" -> "<space>fg" (keytrans spells the leader as <Space>).
local function norm(s)
  s = s:gsub("\\|", "|")
  local parts = vim.split(s, " ", { trimempty = true })
  local out = {}
  for i, p in ipairs(parts) do
    if i == 1 and p == "Space" then
      out[#out + 1] = "<space>"
    elseif p == "Space" then
      out[#out + 1] = "<space>"
    else
      out[#out + 1] = p
    end
  end
  return table.concat(out):lower()
end

local function exists(k)
  if lhs[k] then
    return true
  end
  -- A group prefix ("Space d") counts when some mapping starts with it.
  for m in pairs(lhs) do
    if m:sub(1, #k) == k and #m > #k then
      return true, "group"
    end
  end
  return false
end

local files = vim.fn.globpath(root .. "/docs", "**/*.md", false, true)
vim.list_extend(files, vim.fn.globpath(root .. "/nvim/lua", "**/*.lua", false, true))
if vim.fn.filereadable(root .. "/README.md") == 1 then
  table.insert(files, root .. "/README.md")
end
local seen, missing = {}, {}
for _, file in ipairs(files) do
  for _, line in ipairs(vim.fn.readfile(file)) do
    for key in line:gmatch("`(Space[^`]*)`") do
      -- "Space h l / Space h L" style cells are split on " / " by the docs already.
      local k = norm(key)
      if not seen[k] then
        seen[k] = true
        -- Without git, gitsigns is off (by its cond) and so are its Space g keys.
        local gitsigns_off = not gitsigns_on() and k:sub(1, 8) == "<space>g"
        if not exists(k) and not gitsigns_off then
          missing[#missing + 1] = ("%s (%s)"):format(key, vim.fn.fnamemodify(file, ":." ))
        end
      end
    end
  end
end
report(#missing == 0, ("docs: %d distinct Space keys exist as mappings"):format(vim.tbl_count(seen)), #missing > 0 and table.concat(missing, "; ") or nil)

-- Non-leader keys rihla adds and the docs promise.
local extra = {
  "<c-p>", "<c-s>", "<c-h>", "<c-j>", "<c-k>", "<c-l>", "<f5>", "<s-f5>", "<f9>", "<f10>", "<f11>",
  "<s-f11>", "<f8>", "<s-f8>", "<f2>", "<f12>", "<s-f12>", "gd", "<m-j>", "<m-k>", "<c-/>",
  "<c-\\>", "ys", "ds", "cs", "]h", "[h", "ih", "<esc><esc>",
}
if not gitsigns_on() then
  extra = vim.tbl_filter(function(k)
    return k ~= "]h" and k ~= "[h" and k ~= "ih"
  end, extra)
end
local nope = {}
for _, k in ipairs(extra) do
  if not lhs[k] then
    nope[#nope + 1] = k
  end
end
if vim.fn.has("nvim-0.12") == 1 then
  -- mini.ai owns a/i in operator-pending mode; af/if/ac/ic/ao/io are its tree-sitter objects.
  for _, k in ipairs({ "a", "i" }) do
    if not lhs[k] then
      nope[#nope + 1] = k
    end
  end
end
report(#nope == 0, ("keys: %d non-leader rihla keys exist"):format(#extra), #nope > 0 and table.concat(nope, " ") or nil)
if not gitsigns_on() then
  io.stdout:write("note  gitsigns is off here (no usable git): its keys were not required\n")
end

io.stdout:write(("%d checks, %d failed\n"):format(checks, fails))
vim.cmd(fails == 0 and "qa!" or "cq!")
