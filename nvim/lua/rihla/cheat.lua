-- Searchable VS Code -> Neovim table: every row of docs/vscode-to-neovim.md
-- becomes a picker entry. Type what you would have done in VS Code ("rename",
-- "ctrl+shift+f", "multi cursor") and the row shows the rihla key and the
-- plain-Vim way. Enter jumps to that row in the full document.
local util = require("rihla.util")

local M = {}

M.file = util.docs .. "/vscode-to-neovim.md"

local function cells(line)
  local out = {}
  line = line:gsub("\\|", "\1") -- an escaped pipe inside a cell
  for c in (line:gsub("^%s*|", ""):gsub("|%s*$", "") .. "|"):gmatch("(.-)|") do
    c = c:gsub("`", ""):gsub("\1", "|")
    out[#out + 1] = vim.trim(c)
  end
  return out
end

--- Rows: { vscode, rihla, vim, section, lnum }
function M.rows()
  local rows, section, lnum = {}, "", 0
  if vim.fn.filereadable(M.file) == 0 then
    return rows
  end
  for line in io.lines(M.file) do
    lnum = lnum + 1
    local h = line:match("^##+%s+(.+)")
    if h then
      section = h
    elseif line:match("^%s*|") and not line:match("^%s*|%s*%-%-") then
      local c = cells(line)
      if #c >= 3 and c[1] ~= "VS Code" and c[1] ~= "" then
        rows[#rows + 1] = { vscode = c[1], rihla = c[2], vim = c[3], notes = c[4], section = section, lnum = lnum }
      end
    end
  end
  return rows
end

local function open_at(lnum)
  local win = require("rihla.ui").float_file(M.file, "VS Code -> Neovim")
  if win then
    pcall(vim.api.nvim_win_set_cursor, win, { lnum, 0 })
    vim.cmd("normal! zz")
  end
end

function M.vscode_picker()
  local rows = {}
  for _, r in ipairs(M.rows()) do
    rows[#rows + 1] = {
      text = table.concat({ r.vscode, r.rihla, r.vim, r.section, r.notes or "" }, " "),
      row = r,
      cols = {
        { ("%-36s"):format(vim.fn.strcharpart(r.vscode, 0, 36)) },
        { " " },
        { ("%-28s"):format(vim.fn.strcharpart(r.rihla, 0, 28)), "Function" },
        { " " },
        { r.vim, "Comment" },
      },
      -- what the preview pane shows
      preview = {
        text = table.concat({
          "Section:   " .. r.section,
          "",
          "VS Code:   " .. r.vscode,
          "rihla:     " .. r.rihla,
          "Plain Vim: " .. r.vim,
          (r.notes and r.notes ~= "") and ("\nNotes:\n" .. r.notes) or "",
        }, "\n"),
        ft = "text",
      },
    }
  end
  return require("rihla.cmdpalette").list(rows, "VS Code -> Neovim (VS Code | rihla | plain Vim)", function(r)
    open_at(r.row.lnum)
  end, { preview = "preview" })
end

return M
