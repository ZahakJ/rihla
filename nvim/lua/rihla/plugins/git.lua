-- Git: gitsigns for changes in the gutter and per-hunk actions; lazygit in a
-- float when it is installed, vim-fugitive (:Git) always. Fugitive needs only
-- git itself, so <leader>gg still does something useful on a bare server.
local util = require("rihla.util")

local function lazygit_or_fugitive()
  if not util.has("git") then
    util.hint("nogit", "git is not installed on this machine.", vim.log.levels.WARN)
    return
  end
  if util.has("lazygit") then
    require("rihla.ui").float_cmd("lazygit")
  else
    util.hint("lazygit", "lazygit not found, opening :Git (fugitive) instead. Install lazygit for the full-screen UI.")
    vim.cmd("Git")
  end
end

--- Is the system git at least major.minor? (CentOS 7 ships 1.8.3.)
local git_version
local function git_at_least(major, minor)
  if not util.has("git") then
    return false
  end
  if not git_version then
    local v = vim.fn.system({ "git", "--version" }):match("(%d+%.%d+)") or "0.0"
    local ma, mi = v:match("(%d+)%.(%d+)")
    git_version = { tonumber(ma), tonumber(mi) }
  end
  return git_version[1] > major or (git_version[1] == major and git_version[2] >= minor)
end

--- Run a diffview command, or say in one line why it cannot run here.
local function diffview(cmd)
  return function()
    if not git_at_least(2, 31) then
      util.hint(
        "diffview-git",
        "the merge and history views need git 2.31 or newer. In a conflicted file: co ct cb c0 and ]x [x still work (git 2.19+), or :Gvdiffsplit!.",
        vim.log.levels.WARN
      )
      return
    end
    vim.cmd(cmd)
  end
end

local function gs(fn, ...)
  local args = { ... }
  return function()
    require("gitsigns")[fn](unpack(args))
  end
end

return require("rihla.spec").wrap({
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    -- Without git it would print an error on every file; there is nothing to show anyway.
    -- Old git (CentOS 7 ships 1.8.3) cannot answer what gitsigns asks, so it never
    -- attaches; 2.19 is the same "usable git" floor the installer uses.
    cond = function()
      return git_at_least(2, 19)
    end,
    config = function()
      require("gitsigns").setup({
        -- Box-drawing signs: visible in every font.
        signs = {
          add = { text = "│" },
          change = { text = "│" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
          untracked = { text = "┆" },
        },
        current_line_blame = false,
        current_line_blame_opts = { delay = 400 },
        on_attach = function(buf)
          local function map(mode, l, r, desc)
            vim.keymap.set(mode, l, r, { buffer = buf, desc = desc, silent = true })
          end
          map("n", "]h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "]c", bang = true })
            else
              require("gitsigns").nav_hunk("next")
            end
          end, "Next git change (hunk)")
          map("n", "[h", function()
            if vim.wo.diff then
              vim.cmd.normal({ "[c", bang = true })
            else
              require("gitsigns").nav_hunk("prev")
            end
          end, "Previous git change (hunk)")
          map("n", "<leader>ga", gs("stage_hunk"), "Stage hunk (or unstage)")
          map("x", "<leader>ga", function()
            require("gitsigns").stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Stage selected lines")
          map("n", "<leader>gr", gs("reset_hunk"), "Reset hunk (discard change)")
          map("x", "<leader>gr", function()
            require("gitsigns").reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
          end, "Reset selected lines")
          map("n", "<leader>gA", gs("stage_buffer"), "Stage whole file")
          map("n", "<leader>gR", gs("reset_buffer"), "Reset whole file")
          map("n", "<leader>gp", gs("preview_hunk_inline"), "Preview hunk")
          map("n", "<leader>gb", gs("blame_line", { full = true }), "Blame this line")
          map("n", "<leader>gB", gs("blame"), "Blame whole file")
          map("n", "<leader>gt", gs("toggle_current_line_blame"), "Toggle inline blame")
          map("n", "<leader>gd", gs("diffthis"), "Diff against index")
          map("n", "<leader>gD", gs("diffthis", "~"), "Diff against last commit")
          map({ "o", "x" }, "ih", ":<C-u>Gitsigns select_hunk<CR>", "inner git hunk (text object)")
        end,
      })
    end,
  },

  {
    "tpope/vim-fugitive",
    cmd = { "Git", "G", "Gdiffsplit", "Gvdiffsplit", "Gread", "Gwrite", "Gedit", "GBrowse", "Gclog" },
    keys = {
      { "<leader>gg", lazygit_or_fugitive, desc = "Git UI (lazygit, or :Git)" },
      { "<leader>gs", "<cmd>Git<CR>", desc = "Git status (fugitive)" },
      { "<leader>gc", "<cmd>Git commit<CR>", desc = "Commit" },
      { "<leader>gl", "<cmd>Git log --oneline --graph -n 200<CR>", desc = "Log (graph)" },
      { "<leader>gL", "<cmd>Gclog %<CR>", desc = "History of this file -> quickfix" },
      { "<leader>gP", "<cmd>Git push<CR>", desc = "Push" },
      { "<leader>gf", "<cmd>Git pull --rebase<CR>", desc = "Pull (rebase)" },
      { "<leader>gm", diffview("DiffviewOpen"), desc = "Merge conflicts: 3-way merge view (or changes vs HEAD)" },
      { "<leader>gh", diffview("DiffviewFileHistory %"), desc = "History of this file (diffs per commit)" },
      { "<leader>gH", diffview("DiffviewFileHistory"), desc = "History of the repository" },
      {
        "<leader>gx",
        function()
          require("rihla.conflict").to_quickfix()
        end,
        desc = "All merge conflicts -> quickfix list",
      },
      {
        "<leader>gF",
        function()
          require("rihla.find").pick("git_status", { title = "Changed files" })()
        end,
        desc = "Changed files (picker)",
      },
    },
  },

  -- diffview: the 3-way merge view (Space g m) and file history (Space g h).
  -- In the merge view the result is the window at the bottom; co ct cb c0 and
  -- ]x [x (lua/rihla/conflict.lua) work there as in any conflicted file.
  -- q closes it.
  {
    "sindrets/diffview.nvim",
    cmd = { "DiffviewOpen", "DiffviewFileHistory", "DiffviewClose" },
    cond = function()
      return git_at_least(2, 31)
    end,
    config = function()
      local close = { "n", "q", "<cmd>DiffviewClose<CR>", { desc = "Close the diff view" } }
      require("diffview").setup({
        use_icons = require("rihla.icons").nerd,
        enhanced_diff_hl = true,
        signs = require("rihla.icons").nerd and nil or { fold_closed = ">", fold_open = "v", done = "ok" },
        view = {
          merge_tool = { layout = "diff3_mixed", disable_diagnostics = true, winbar_info = true },
        },
        keymaps = {
          view = { close },
          file_panel = { close },
          file_history_panel = { close },
        },
      })
    end,
  },
})
