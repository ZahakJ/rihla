-- Find and replace (VS Code Ctrl+H and Ctrl+Shift+H).
--
-- In one file: Vim's own :%s, pre-filled by Space r r with the word under the
-- cursor (or the selection), so only the replacement is left to type. 'c' asks
-- at every match (y / n / a all / q quit) and 'inccommand' previews it live.
--
-- Across files: grug-far.nvim. A buffer with Search, Replace, Files Filter (a
-- glob such as *.ts) and Paths (folders) at the top; every match below shows
-- the line before and after the change as you type, nothing is written until
-- you press \r (replace all) or sync single lines. It uses ripgrep with the
-- shared defaults (shell/ripgreprc), and regex is on, as in VS Code.
--
-- Undo: a replace writes files on disk, which `u` cannot reach for files that
-- are not open. rihla keeps a copy of every file grug-far is about to change
-- (its on_before_edit_file hook), and Space r u puts them back.
local icons = require("rihla.icons")
local M = require("rihla.replace")

local ascii_icons = { enabled = false }

local specs = require("rihla.spec").wrap({
  {
    "MagicDuck/grug-far.nvim",
    cmd = { "GrugFar", "GrugFarWithin" },
    keys = {
      { "<leader>rr", function() M.in_file(false) end, desc = "Replace word in this file (:%s, asks each)" },
      { "<leader>rr", function() M.in_file(true) end, mode = "x", desc = "Replace selected text in this file" },
      { "<leader>rs", function() M.in_selection() end, mode = "x", desc = "Replace inside the selection only" },
      { "<leader>rp", function() M.project({ word = true }) end, desc = "Replace in project (VS Code Ctrl+Shift+H)" },
      { "<leader>rp", function() M.project({ visual = true }) end, mode = "x", desc = "Replace selection in project" },
      { "<leader>rP", function() M.project() end, desc = "Replace in project (empty search)" },
      { "<leader>rf", function() M.project({ file = true, word = true }) end, desc = "Replace in this file, with preview" },
      { "<leader>ru", function() M.undo() end, desc = "Undo the last project replace" },
    },
    config = function()
      require("grug-far").setup({
        -- \r replace all, \s sync edited lines, \q quickfix, g? help (shown on top)
        windowCreationCommand = "botright vsplit",
        startInInsertMode = true,
        -- Like VS Code's Search panel, not an editor tab: unlisted (no tab number) and
        -- gone after :q. Space r p opens a fresh one.
        transient = true,
        icons = not icons.nerd and ascii_icons or nil,
        spinnerStates = not icons.nerd and { "- ", "\\ ", "| ", "/ " } or nil,
        resultsSeparatorLineChar = "─",
        filePathConcealChar = icons.nerd and nil or "...",
        hooks = {
          on_before_edit_file = function(on_finish, file)
            -- called from a libuv callback, where vim.fn is not allowed
            vim.schedule(function()
              pcall(M.remember, file.path)
              on_finish()
            end)
          end,
        },
      })
    end,
  },
})

return specs
