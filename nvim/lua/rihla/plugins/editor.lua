-- Editing aids, the file tree, the terminal, sessions and tmux navigation.
local icons = require("rihla.icons")
local util = require("rihla.util")

local ascii_tree_glyphs = {
  default = "",
  symlink = "",
  bookmark = "*",
  modified = "+",
  hidden = "h",
  folder = {
    arrow_closed = ">",
    arrow_open = "v",
    default = "",
    open = "",
    empty = "",
    empty_open = "",
    symlink = "",
    symlink_open = "",
  },
  git = { unstaged = "M", staged = "S", unmerged = "U", renamed = "R", untracked = "?", deleted = "D", ignored = "!" },
}

local M = {}

--- Space e: open the tree; when it is open but you are in a file, go to it;
--- when you are in it, close it. (VS Code's Ctrl+Shift+E, then Ctrl+B.)
function M.tree_key()
  local api = require("nvim-tree.api")
  if not api.tree.is_visible() then
    api.tree.open({ find_file = false })
  elseif vim.bo.filetype ~= "NvimTree" then
    api.tree.focus()
  else
    api.tree.close()
  end
end

--- Keys in the tree: nvim-tree's own (a add, r rename, d delete, x cut,
--- c copy, p paste, R refresh, H hidden files, g? help), plus ? for help, and
--- Ctrl-h/j/k/l moving to the next window or tmux pane like everywhere else.
function M.tree_attach(buf)
  local api = require("nvim-tree.api")
  api.config.mappings.default_on_attach(buf)
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, desc = "tree: " .. desc, nowait = true, silent = true })
  end
  map("?", api.tree.toggle_help, "help (all keys)")
  map("<C-k>", "<cmd>TmuxNavigateUp<CR>", "window/pane above")
  map("<C-j>", "<cmd>TmuxNavigateDown<CR>", "window/pane below")
  map("<C-h>", "<cmd>TmuxNavigateLeft<CR>", "window/pane left")
  map("<C-l>", "<cmd>TmuxNavigateRight<CR>", "window/pane right")
  map("i", api.node.show_info_popup, "file info (size, dates)")
  map("l", api.node.open.edit, "open")
  map("h", api.node.navigate.parent_close, "close folder")
end

return require("rihla.spec").wrap({
  -- mini.nvim: one mature, dependency-free plugin for several small jobs:
  --   mini.ai        better text objects (a/i + q quotes, b brackets, f function, c class)
  --   mini.surround  ys / ds / cs, the same keys as tpope's vim-surround
  --   mini.pairs     auto-close brackets and quotes
  --   mini.bufremove close a buffer without closing its window
  --   mini.icons     file icons, only in nerd mode
  {
    "nvim-mini/mini.nvim",
    event = "VeryLazy",
    dependencies = {
      { "nvim-treesitter/nvim-treesitter-textobjects", branch = "main", cond = util.nvim_at_least(12) },
    },
    init = function()
      if icons.nerd then
        -- Anything that asks for nvim-web-devicons gets mini.icons instead.
        package.preload["nvim-web-devicons"] = function()
          require("mini.icons").setup()
          require("mini.icons").mock_nvim_web_devicons()
          return package.loaded["nvim-web-devicons"]
        end
      end
    end,
    keys = {
      {
        "<leader>bd",
        function()
          require("mini.bufremove").delete(0, false)
        end,
        desc = "Close buffer (keep window)",
      },
      {
        "<leader>bD",
        function()
          require("mini.bufremove").delete(0, true)
        end,
        desc = "Close buffer, discard changes",
      },
    },
    config = function()
      local ai = require("mini.ai")
      -- Without a parser for the buffer mini.ai raises a Lua error (a stack trace and
      -- "Press ENTER"). Catch it and say in one line what is missing instead.
      local ts = function(a, i)
        local spec = ai.gen_spec.treesitter({ a = a, i = i })
        return function(...)
          local ok, res = pcall(spec, ...)
          if ok then
            return res
          end
          vim.notify(
            ("No tree-sitter parser for %s: f, c and o text objects need one (:checkhealth rihla says why)."):format(
              vim.bo.filetype ~= "" and vim.bo.filetype or "this buffer"
            ),
            vim.log.levels.WARN
          )
          return {}
        end
      end
      ai.setup({
        n_lines = 500,
        custom_textobjects = {
          f = ts("@function.outer", "@function.inner"), -- vaf, dif, cif: needs a tree-sitter parser
          c = ts("@class.outer", "@class.inner"),
          o = ts({ "@conditional.outer", "@loop.outer" }, { "@conditional.inner", "@loop.inner" }),
        },
      })

      require("mini.surround").setup({
        -- tpope/vim-surround keys, so the habit transfers.
        mappings = {
          add = "ys",
          delete = "ds",
          replace = "cs",
          find = "",
          find_left = "",
          highlight = "",
          update_n_lines = "",
          suffix_last = "",
          suffix_next = "",
        },
        search_method = "cover_or_next",
      })
      pcall(vim.keymap.del, "x", "ys")
      util.map("x", "S", [[:<C-u>lua MiniSurround.add('visual')<CR>]], "Surround selection")
      util.map("n", "yss", "ys_", "Surround line", { remap = true })

      -- ]f / [f: jump to the next / previous function (tree-sitter).
      local okm, move = pcall(require, "nvim-treesitter-textobjects.move")
      if okm then
        util.map({ "n", "x", "o" }, "]f", function()
          move.goto_next_start("@function.outer", "textobjects")
        end, "Next function start")
        util.map({ "n", "x", "o" }, "[f", function()
          move.goto_previous_start("@function.outer", "textobjects")
        end, "Previous function start")
      end

      -- Pair brackets and quotes only before whitespace, a line end or a closing
      -- bracket. Typing " in front of a word inserts one ", so recorded macros,
      -- . repeats and the lessons behave the same as in plain Vim.
      local nxt = "[%s\n%)%]%},;]"
      local quote = function(q)
        return { action = "closeopen", pair = q .. q, neigh_pattern = "[^%w\\]" .. nxt, register = { cr = false } }
      end
      require("mini.pairs").setup({
        modes = { insert = true, command = false, terminal = false },
        mappings = {
          ["("] = { action = "open", pair = "()", neigh_pattern = "[^\\]" .. nxt },
          ["["] = { action = "open", pair = "[]", neigh_pattern = "[^\\]" .. nxt },
          ["{"] = { action = "open", pair = "{}", neigh_pattern = "[^\\]" .. nxt },
          ['"'] = quote('"'),
          ["'"] = quote("'"),
          ["`"] = quote("`"),
        },
      })
      require("mini.bufremove").setup()
    end,
  },

  -- Detect indent style (tabs/spaces, width) from the file itself.
  { "tpope/vim-sleuth", event = { "BufReadPre", "BufNewFile" } },

  -- Ctrl-h/j/k/l move between Neovim splits and tmux panes with the same keys.
  {
    "christoomey/vim-tmux-navigator",
    init = function()
      vim.g.tmux_navigator_no_mappings = 1 -- we only want the four, not Ctrl-\
      vim.g.tmux_navigator_disable_when_zoomed = 1
    end,
    cmd = { "TmuxNavigateLeft", "TmuxNavigateDown", "TmuxNavigateUp", "TmuxNavigateRight" },
    keys = {
      { "<C-h>", "<cmd>TmuxNavigateLeft<CR>", desc = "Window/pane left" },
      { "<C-j>", "<cmd>TmuxNavigateDown<CR>", desc = "Window/pane below" },
      { "<C-k>", "<cmd>TmuxNavigateUp<CR>", desc = "Window/pane above" },
      { "<C-l>", "<cmd>TmuxNavigateRight<CR>", desc = "Window/pane right" },
    },
  },

  -- File tree (VS Code's Explorer). The Vim way: :e . or :Explore.
  {
    "nvim-tree/nvim-tree.lua",
    cmd = { "NvimTreeToggle", "NvimTreeFindFile", "NvimTreeOpen", "NvimTreeFocus" },
    keys = {
      { "<leader>e", function() M.tree_key() end, desc = "File tree: open / focus / close (VS Code Ctrl+Shift+E)" },
      { "<leader>E", "<cmd>NvimTreeFindFile!<CR>", desc = "Show this file in the tree" },
    },
    config = function()
      require("nvim-tree").setup({
        hijack_netrw = true,
        disable_netrw = false, -- keep :Explore working if this plugin ever fails
        sync_root_with_cwd = true,
        -- nvim-tree errors when git is enabled but not installed (bare CentOS 7)
        git = { enable = util.has("git") },
        view = { width = 32 },
        update_focused_file = { enable = true },
        filters = { custom = { "^.git$" } },
        on_attach = M.tree_attach,
        diagnostics = {
          enable = true,
          icons = {
            hint = vim.trim(icons.diag.HINT),
            info = vim.trim(icons.diag.INFO),
            warning = vim.trim(icons.diag.WARN),
            error = vim.trim(icons.diag.ERROR),
          },
        },
        renderer = {
          group_empty = true,
          root_folder_label = ":~:s?$?/?",
          highlight_git = "name",
          indent_markers = { enable = true },
          icons = {
            symlink_arrow = " -> ",
            git_placement = "after",
            show = {
              file = icons.nerd,
              folder = icons.nerd,
              folder_arrow = true,
              git = true,
              modified = true,
              diagnostics = true,
              bookmarks = true,
            },
            web_devicons = { file = { enable = icons.nerd }, folder = { enable = false } },
            glyphs = icons.nerd and nil or ascii_tree_glyphs,
          },
        },
        help = { sort_by = "desc" },
      })
    end,
  },

  -- Terminal on demand (VS Code's Ctrl+`): lua/rihla/term.lua.
  {
    "akinsho/toggleterm.nvim",
    cmd = { "ToggleTerm", "TermExec" },
    keys = {
      { [[<C-\>]], function() require("rihla.term").toggle("bottom") end, mode = { "n", "t" }, desc = "Terminal at the bottom: show / hide" },
      { "<leader>tt", function() require("rihla.term").toggle("float") end, desc = "Terminal, floating: show / hide" },
      { "<leader>tb", function() require("rihla.term").toggle("bottom") end, desc = "Terminal at the bottom: show / hide" },
      { "<leader>tr", function() require("rihla.term").toggle("right") end, desc = "Terminal on the right: show / hide" },
      { "<leader>ts", function() require("rihla.term").send(false) end, desc = "Send this line to the terminal (runs it)" },
      { "<leader>ts", function() require("rihla.term").send(true) end, mode = "x", desc = "Send selection to the terminal (runs it)" },
    },
    config = function()
      require("toggleterm").setup({
        size = function(term)
          return term.direction == "horizontal" and 14 or math.floor(vim.o.columns * 0.4)
        end,
        open_mapping = nil, -- set with the keys above
        shade_terminals = false,
        direction = "horizontal",
        persist_size = true,
        float_opts = { border = "rounded", title_pos = "center" },
        highlights = { FloatBorder = { link = "FloatBorder" } },
      })
    end,
  },

  -- Sessions: reopen a project with the same files and splits.
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    keys = {
      {
        "<leader>qs",
        function()
          require("persistence").load()
        end,
        desc = "Restore session for this folder",
      },
      {
        "<leader>ql",
        function()
          require("persistence").load({ last = true })
        end,
        desc = "Restore last session",
      },
      {
        "<leader>qS",
        function()
          require("persistence").select()
        end,
        desc = "Pick a session",
      },
      {
        "<leader>qd",
        function()
          require("persistence").stop()
        end,
        desc = "Do not save this session",
      },
    },
    main = "persistence",
    opts = {},
  },
})
