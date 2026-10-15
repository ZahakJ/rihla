-- Helpers for find and replace; the plugin spec is plugins/replace.lua.
local util = require("rihla.util")
local icons = require("rihla.icons")

local M = {}

M.undo_stack = {} -- { { time = os.time(), files = { [path] = content } }, ... }
local last_edit = 0

--- Keep the content of `path` before grug-far changes it. Edits less than two
--- seconds apart belong to the same replace.
function M.remember(path)
  local abs = vim.fn.fnamemodify(path, ":p")
  local now = (vim.uv or vim.loop).now()
  if #M.undo_stack == 0 or now - last_edit > 2000 then
    M.undo_stack[#M.undo_stack + 1] = { time = os.time(), files = {} }
  end
  last_edit = now
  local batch = M.undo_stack[#M.undo_stack]
  if batch.files[abs] == nil then
    batch.files[abs] = util.read(abs) or false
  end
end

--- Put back the files of the last project-wide replace.
function M.undo(force)
  local batch = M.undo_stack[#M.undo_stack]
  if not batch then
    util.say("Nothing to undo: no project-wide replace in this session.")
    return
  end
  local n = vim.tbl_count(batch.files)
  local go = force
    or vim.fn.confirm(
        ("Put back %d file(s) as they were before the replace at %s? Edits made since then are lost."):format(
          n,
          os.date("%H:%M:%S", batch.time)
        ),
        "&Yes\n&No",
        2
      )
      == 1
  if not go then
    return
  end
  for path, content in pairs(batch.files) do
    if content then
      util.write(path, content)
    end
  end
  table.remove(M.undo_stack)
  vim.cmd("silent! checktime")
  util.say(("Put back %d file(s)."):format(n))
end

--- Open grug-far. opts.word: pre-fill the word under the cursor; opts.file:
--- only this file; opts.visual: pre-fill the selection.
function M.project(opts)
  opts = opts or {}
  if not util.has("rg") then
    util.hint("rg-replace", "ripgrep (rg) not found: replace across files needs it. `rihla install` adds rg.", vim.log.levels.WARN)
    return
  end
  local gf = require("grug-far")
  local prefills = {}
  if opts.file then
    local f = vim.fn.expand("%")
    if f == "" then
      util.say("This buffer has no file; Space r p searches the whole project.")
      return
    end
    prefills.paths = vim.fn.fnameescape(f)
  end
  if opts.visual then
    return gf.with_visual_selection({ prefills = prefills })
  end
  if opts.word then
    prefills.search = vim.fn.expand("<cword>")
  end
  return gf.open({ prefills = prefills })
end

--- In this file: :%s with the word under the cursor (whole word) or the
--- selected text (literal), the cursor left where the replacement goes. \C:
--- exact case, so renaming `item` leaves the class `Item` alone (delete the \C
--- to match any case).
function M.in_file(visual)
  local pat
  if visual then
    local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
    vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
    local text = table.concat(lines, "\n")
    pat = "\\V\\C" .. vim.fn.escape(text, "/\\"):gsub("\n", "\\n")
  else
    local w = vim.fn.expand("<cword>")
    if w == "" then
      pat = ""
    else
      pat = "\\C\\<" .. vim.fn.escape(w, "/\\") .. "\\>"
    end
  end
  local cmd = ":%s/" .. pat .. "//gc"
  vim.api.nvim_feedkeys(vim.keycode(cmd .. "<Left><Left><Left>"), "n", false)
end

--- Replace inside the selection only: :'<,'>s/\%V//gc with the cursor in the pattern.
function M.in_selection()
  vim.api.nvim_feedkeys(vim.keycode([[:s/\%V//gc<Left><Left><Left><Left>]]), "n", false)
end

return M
