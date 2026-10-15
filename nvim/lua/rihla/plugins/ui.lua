-- Look: theme, status line, buffer tabs, indent guides, icons.
local icons = require("rihla.icons")

-- Alt-1..9 and Space 1..9 jump to the tab with that number (VS Code: Ctrl+1..9
-- picks an editor group, Alt+1..9 a tab on Linux). Alt-N needs a terminal that
-- sends Alt as Esc+N (all common ones do); inside tmux it works unless your own
-- tmux config binds M-1..9. The number on a tab is its place from the left,
-- pinned tabs included (lua/rihla/tabs.lua), so it is always the key that reaches it.
local goto_keys = {}
for i = 1, 9 do
  local go = function()
    require("rihla.tabs").go(i)
  end
  goto_keys[#goto_keys + 1] = { "<M-" .. i .. ">", go, desc = "Go to tab " .. i }
  goto_keys[#goto_keys + 1] = { "<leader>" .. i, go, desc = i == 1 and "Go to tab 1 (Space 1..9, Alt-1..9)" or ("Go to tab " .. i) }
end

return require("rihla.spec").wrap({
  -- Catppuccin Mocha, the shared rihla palette. Loaded first so nothing flashes.
  {
    "catppuccin/nvim",
    name = "catppuccin",
    lazy = false,
    priority = 1000,
    config = function()
      local p = require("rihla.palette")
      require("catppuccin").setup({
        flavour = "mocha",
        term_colors = true,
        no_italic = false,
        -- Diagnostics get a curly underline in their colour, as in VS Code (the terminal
        -- draws a straight one where it cannot curl; tmux passes it on, see modern.conf).
        lsp_styles = {
          underlines = {
            errors = { "undercurl" },
            warnings = { "undercurl" },
            information = { "undercurl" },
            hints = { "undercurl" },
            ok = { "undercurl" },
          },
        },
        integrations = {
          blink_cmp = true,
          gitsigns = true,
          indent_blankline = { enabled = true, scope_color = "mauve" },
          mason = true,
          native_lsp = { enabled = true },
          nvimtree = true,
          snacks = { enabled = true },
          grug_far = true,
          diffview = true,
          dropbar = { enabled = true, color_mode = true },
          treesitter = true,
          which_key = true,
          dap = true,
          dap_ui = true,
          mini = { enabled = true },
        },
        custom_highlights = function()
          return {
            CursorLineNr = { fg = p.mauve, style = { "bold" } },
            FloatBorder = { fg = p.mauve },
            FloatTitle = { fg = p.base, bg = p.mauve, style = { "bold" } },
            WinSeparator = { fg = p.surface1 },
            SnacksPickerBorder = { fg = p.mauve },
            SnacksPickerTitle = { fg = p.base, bg = p.mauve, style = { "bold" } },
            FloatFooter = { fg = p.subtext },
            WhichKeyBorder = { fg = p.mauve },
            WhichKey = { fg = p.mauve },
            WhichKeyGroup = { fg = p.blue },
            Search = { fg = p.base, bg = p.blue },
            IncSearch = { fg = p.base, bg = p.mauve },
            CurSearch = { fg = p.base, bg = p.mauve },
            RihlaHint = { fg = p.overlay, style = { "italic" } },
          }
        end,
      })
      vim.cmd.colorscheme("catppuccin-mocha")
    end,
  },

  -- Status line, hand-rolled from the palette (see lua/rihla/statusline.lua).
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    init = function()
      -- Until lualine loads, show an empty bar instead of the default one.
      vim.o.statusline = " "
    end,
    config = function()
      require("lualine").setup(require("rihla.statusline").config())
    end,
  },

  -- Open buffers as tabs along the top, like editor tabs in VS Code.
  -- The Vim-native way to switch is [b / ]b, Ctrl-^, or <leader>fb.
  {
    "akinsho/bufferline.nvim",
    event = "VeryLazy",
    keys = {
      { "<leader>bp", "<cmd>BufferLineTogglePin<CR>", desc = "Pin / unpin this tab (stays left, kept by close others)" },
      { "<leader>bP", "<cmd>BufferLineGroupClose ungrouped<CR>", desc = "Close every tab that is not pinned" },
      {
        "<leader>bo",
        function()
          require("rihla.tabs").close_others()
        end,
        desc = "Close other tabs (keeps pinned and unsaved ones)",
      },
      { "<leader>bl", "<cmd>BufferLineCloseLeft<CR>", desc = "Close buffers to the left" },
      { "<leader>br", "<cmd>BufferLineCloseRight<CR>", desc = "Close buffers to the right" },
      { "<leader>bj", "<cmd>BufferLinePick<CR>", desc = "Jump to buffer by letter" },
      { "<leader>b<", "<cmd>BufferLineMovePrev<CR>", desc = "Move buffer left" },
      { "<leader>b>", "<cmd>BufferLineMoveNext<CR>", desc = "Move buffer right" },
      unpack(goto_keys),
    },
    config = function()
      do
        local p = require("rihla.palette")
        local opts = {
          options = {
            mode = "buffers",
            -- the tab's place from the left, pinned tabs first: the number Alt-N / Space N jumps to
            numbers = function(o)
              return require("rihla.tabs").number(o)
            end,
            diagnostics = "nvim_lsp",
            always_show_bufferline = false, -- hidden while only one file is open
            show_buffer_icons = icons.nerd,
            show_buffer_close_icons = false,
            show_close_icon = false,
            separator_style = "thin",
            indicator = { style = "underline" },
            modified_icon = icons.ui.modified,
            left_trunc_marker = "<",
            right_trunc_marker = ">",
            offsets = { { filetype = "NvimTree", text = "Files", highlight = "Directory", text_align = "left" } },
            max_name_length = 18,
            tab_size = 8, -- tabs as wide as their names: more of them fit at 80 columns
            truncate_names = true,
            diagnostics_indicator = function(count, level)
              local k = level:match("error") and "ERROR" or "WARN"
              return vim.trim(icons.diag[k]) .. count
            end,
          },
          highlights = {
            fill = { bg = p.crust },
            background = { fg = p.overlay, bg = p.crust },
            buffer_visible = { fg = p.subtext, bg = p.crust },
            buffer_selected = { fg = p.text, bg = p.base, bold = true, italic = false, sp = p.mauve },
            indicator_selected = { fg = p.mauve, bg = p.base, sp = p.mauve },
            separator = { fg = p.crust, bg = p.crust },
            separator_selected = { fg = p.crust, bg = p.base },
            separator_visible = { fg = p.crust, bg = p.crust },
            modified = { fg = p.peach, bg = p.crust },
            modified_selected = { fg = p.peach, bg = p.base },
            modified_visible = { fg = p.peach, bg = p.crust },
          },
        }
        if not icons.nerd then
          opts.options.buffer_close_icon = "x"
          opts.options.close_icon = "x"
          opts.options.get_element_icon = function()
            return "", nil
          end
        end
        require("bufferline").setup(opts)
      end
    end,
  },

  -- Thin indent guides; box-drawing characters exist in every terminal font.
  {
    "lukas-reineke/indent-blankline.nvim",
    main = "ibl",
    event = { "BufReadPost", "BufNewFile" },
    opts = {
      indent = { char = "│", tab_char = "│" },
      scope = { enabled = true, show_start = false, show_end = false },
      exclude = { filetypes = { "help", "rihla-dashboard", "lazy", "mason", "NvimTree", "toggleterm", "markdown" } },
    },
  },

  -- Breadcrumb along the top of each file window (VS Code's breadcrumbs):
  -- folder > file > class > function, from the language server when one is
  -- attached, else tree-sitter, and Markdown headings. Nothing to compile.
  -- Space c p picks a part and opens a menu of its siblings; clicking works too.
  {
    "Bekaboo/dropbar.nvim",
    event = { "BufReadPost", "BufNewFile" },
    keys = {
      {
        "<leader>cp",
        function()
          require("dropbar.api").pick()
        end,
        desc = "Breadcrumb: pick a part, browse its siblings",
      },
    },
    config = function()
      local function enable(buf, win)
        if not (vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_win_is_valid(win)) then
          return false
        end
        if vim.fn.win_gettype(win) ~= "" or vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) == "" then
          return false
        end
        if vim.wo[win].winbar ~= "" or vim.bo[buf].filetype == "help" then
          return false -- a lesson page or another header owns this line
        end
        if require("rihla.learn").lesson_of(buf) then
          return false
        end
        local stat = (vim.uv or vim.loop).fs_stat(vim.api.nvim_buf_get_name(buf))
        return not (stat and stat.size > 1024 * 1024)
      end
      local opts = {
        bar = {
          enable = enable,
          attach_events = { "BufWinEnter", "BufWritePost", "BufEnter", "FileType", "LspAttach" },
        },
      }
      if not icons.nerd then
        opts.icons = {
          enable = false,
          ui = { bar = { separator = " > ", extends = "..." }, menu = { separator = " ", indicator = "> " } },
        }
      end
      require("dropbar").setup(opts)
    end,
  },
})
