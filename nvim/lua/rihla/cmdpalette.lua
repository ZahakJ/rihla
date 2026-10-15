-- Command palette (VS Code's Ctrl+Shift+P), on <leader><leader>.
-- Lists every action that has a key, with the key next to it, so searching
-- the palette also teaches the shortcut. Plus the :Rihla subcommands.
local M = {}

--- "<Space>lf" -> "Space l f", "<C-p>" -> "Ctrl-p": how the docs write keys.
local function pretty(lhs)
  local k = vim.fn.keytrans(vim.api.nvim_replace_termcodes(lhs, true, true, true))
  local out = {}
  local i = 1
  while i <= #k do
    local tok = k:match("^<[^>]+>", i)
    if tok then
      i = i + #tok
      tok = tok:sub(2, -2):gsub("^C%-", "Ctrl-"):gsub("^M%-", "Alt-"):gsub("^A%-", "Alt-"):gsub("^S%-", "Shift-")
      tok = ({ lt = "<", NL = "Ctrl-j", CR = "Enter", BS = "Backspace" })[tok] or tok
      tok = tok:gsub("^(Ctrl%-)(%u)$", function(c, l)
        return c .. l:lower()
      end)
    else
      tok = k:sub(i, i)
      i = i + 1
    end
    out[#out + 1] = tok
  end
  return table.concat(out, " ")
end

function M.items()
  local items, seen = {}, {}
  local function add(maps, scope)
    for _, m in ipairs(maps) do
      local desc = m.desc
      if desc and desc ~= "" and not m.lhs:match("^<Plug>") and not m.lhs:match("^<SNR>") then
        local key = pretty(m.lhs)
        local id = key .. desc
        if not seen[id] then
          seen[id] = true
          items[#items + 1] = { desc = desc, key = key, lhs = m.lhs, map = m, scope = scope }
        end
      end
    end
  end
  add(vim.api.nvim_buf_get_keymap(0, "n"), "buffer")
  add(vim.api.nvim_get_keymap("n"), "global")
  -- lazy.nvim's not-yet-loaded plugin keys are real mappings too, so they
  -- appear above. :Rihla subcommands:
  for name, sub in pairs(require("rihla.commands").sub) do
    items[#items + 1] = { desc = "Rihla: " .. sub.desc, key = ":Rihla " .. name, cmd = "Rihla " .. name }
  end
  table.sort(items, function(a, b)
    return a.desc:lower() < b.desc:lower()
  end)
  return items
end

local function run(item)
  if item.cmd then
    vim.cmd(item.cmd)
    return
  end
  local keys = vim.api.nvim_replace_termcodes(item.lhs, true, false, true)
  vim.api.nvim_feedkeys(keys, "m", false)
end

--- A plain list in the picker: rows of { text = what is matched, cols = { {text, hl}, ... } }.
--- on_pick(row) runs after the picker closes. Without snacks (it failed to
--- load), vim.ui.select's built-in list does the same job.
function M.list(rows, title, on_pick, opts)
  opts = opts or {}
  local ok, snacks = pcall(require, "snacks")
  if not ok or not snacks.picker then
    vim.ui.select(rows, {
      prompt = title,
      format_item = function(r)
        return r.text
      end,
    }, function(r)
      if r then
        on_pick(r)
      end
    end)
    return
  end
  local find = require("rihla.find")
  return snacks.picker.pick({
    title = title,
    items = rows,
    format = function(item)
      return item.cols
    end,
    preview = opts.preview or "none",
    layout = find.layout(opts.footer or find.footer.plain, { preview = opts.preview ~= nil }),
    confirm = function(picker, item)
      picker:close()
      if item then
        vim.schedule(function()
          on_pick(item)
        end)
      end
    end,
  })
end

function M.open()
  local rows = {}
  for _, i in ipairs(M.items()) do
    rows[#rows + 1] = {
      text = i.desc .. " " .. i.key,
      item = i,
      cols = { { ("%-52s"):format(vim.fn.strcharpart(i.desc, 0, 52)) }, { " " }, { i.key, "Comment" } },
    }
  end
  return M.list(rows, "Command palette (the key on the right does the same)", function(r)
    run(r.item)
  end)
end

return M
