-- Language servers: nvim-lspconfig supplies the server definitions, Neovim's
-- own vim.lsp.enable runs them, mason installs them (see lua/rihla/lang.lua
-- for when). Keys are set only in buffers where a server is attached.
local icons = require("rihla.icons")
local tools = require("rihla.tools")
local util = require("rihla.util")

local function on_attach(ev)
  local buf = ev.buf
  local client = vim.lsp.get_client_by_id(ev.data.client_id)
  local function map(mode, lhs, rhs, desc)
    vim.keymap.set(mode, lhs, rhs, { buffer = buf, desc = desc, silent = true })
  end
  local tb = function(name)
    return require("rihla.find").pick(name)
  end
  -- Neovim 0.11 already maps these in every LSP buffer, and they work on any
  -- machine with no config at all, so rihla teaches them first:
  --   K hover   grn rename   gra code action   grr references
  --   gri implementation   gO symbols   (Ctrl-s in insert is signature help on plain 0.11; rihla saves with it)
  --   [d ]d previous/next diagnostic   Ctrl-w d diagnostic float
  -- What follows adds the rest, plus VS Code's function keys.
  map("n", "gd", vim.lsp.buf.definition, "Go to definition")
  map("n", "gD", vim.lsp.buf.declaration, "Go to declaration")
  if vim.fn.maparg("grt", "n") == "" then
    map("n", "grt", vim.lsp.buf.type_definition, "Go to type definition")
  end
  map("n", "<F12>", vim.lsp.buf.definition, "Go to definition (gd)")
  map("n", "<S-F12>", vim.lsp.buf.references, "References (grr)")
  map("n", "<F24>", vim.lsp.buf.references, "References (grr)") -- Shift-F12 in some terminals
  map("n", "<F2>", vim.lsp.buf.rename, "Rename symbol (grn)")
  map({ "n", "x" }, "<leader>la", vim.lsp.buf.code_action, "Code action (gra)")
  map("n", "<leader>lr", vim.lsp.buf.rename, "Rename symbol (grn)")
  map("n", "<leader>ld", tb("lsp_definitions"), "Definitions (picker)")
  map("n", "<leader>lR", tb("lsp_references"), "References (picker)")
  map("n", "<leader>li", tb("lsp_implementations"), "Implementations (picker)")
  map("n", "<leader>lt", tb("lsp_type_definitions"), "Type definitions (picker)")
  map("n", "<leader>ls", function() require("rihla.find").symbols() end, "Symbols in file (gO)")
  map("n", "<leader>lS", tb("lsp_workspace_symbols"), "Symbols in workspace")
  map("n", "<leader>lc", tb("lsp_incoming_calls"), "Who calls this (incoming calls)")
  map("n", "<leader>lk", vim.lsp.buf.signature_help, "Signature help")
  map("n", "<leader>lI", "<cmd>checkhealth vim.lsp<CR>", "LSP status (attached servers)")
  map("n", "<leader>ll", function()
    if vim.fn.exists(":LspRestart") == 2 then
      vim.cmd("LspRestart")
    else
      vim.cmd("lsp restart")
    end
  end, "Restart language server")
  -- Folds from the language server when tree-sitter has none for this file
  -- (no parser: CentOS 7 has no compiler to build one).
  if client and client:supports_method("textDocument/foldingRange") then
    for _, win in ipairs(vim.fn.win_findbuf(buf)) do
      if vim.wo[win].foldmethod ~= "expr" then
        vim.wo[win][0].foldmethod = "expr"
        vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
      end
    end
  end
  if client and client:supports_method("textDocument/codeLens") then
    map("n", "<leader>lx", vim.lsp.codelens.run, "Run code lens")
  end
  if client and client:supports_method("textDocument/documentHighlight") then
    -- Highlight other uses of the symbol under the cursor after a pause.
    local g = vim.api.nvim_create_augroup("rihla_lsp_hl_" .. buf, { clear = true })
    vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
      group = g,
      buffer = buf,
      callback = vim.lsp.buf.document_highlight,
    })
    vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "BufLeave" }, {
      group = g,
      buffer = buf,
      callback = vim.lsp.buf.clear_references,
    })
  end
end

return require("rihla.spec").wrap({
  {
    "neovim/nvim-lspconfig",
    -- Only provides lsp/<server>.lua definitions on the runtimepath; costs
    -- nothing at startup and must be present before any server is enabled.
    lazy = false,
    init = function()
      -- mason's bin/ goes on PATH now, without loading mason, so servers it
      -- installed earlier are found by vim.lsp.enable and executable().
      local bin = tools.mason_root .. "/bin"
      if not (vim.env.PATH or ""):find(bin, 1, true) then
        vim.env.PATH = bin .. ":" .. (vim.env.PATH or "")
      end
    end,
    config = function()
      local sev = vim.diagnostic.severity
      vim.diagnostic.config({
        severity_sort = true,
        underline = true,
        update_in_insert = false,
        -- Quiet, as in VS Code: only errors get text at the end of the line;
        -- warnings and hints are a sign in the gutter and an underline
        -- (Space x x lists them, K or Space x d shows one). Space t v: all inline.
        virtual_text = { spacing = 2, prefix = "", source = "if_many", severity = { min = sev.ERROR } },
        float = { border = "rounded", source = "if_many" },
        signs = {
          text = {
            [sev.ERROR] = icons.diag.ERROR,
            [sev.WARN] = icons.diag.WARN,
            [sev.INFO] = icons.diag.INFO,
            [sev.HINT] = icons.diag.HINT,
          },
        },
      })

      -- Settings for servers that need them; everything else uses
      -- nvim-lspconfig's defaults.
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            workspace = { checkThirdParty = false },
            completion = { callSnippet = "Replace" },
            hint = { enable = true },
            telemetry = { enable = false },
          },
        },
      })
      vim.lsp.config("basedpyright", {
        settings = { basedpyright = { analysis = { typeCheckingMode = "standard" } } },
      })
      -- pylsp's jedi, parso and yapf keep caches in $XDG_CACHE_HOME; give them a
      -- folder inside nvim's own cache so they go away with it (rihla uninstall).
      vim.lsp.config("pylsp", { cmd_env = { XDG_CACHE_HOME = vim.fn.stdpath("cache") .. "/pylsp" } })
      -- marksman is a .NET program; without libicu (minimal Ubuntu/Debian images) it
      -- aborts on start, and every Markdown file (cheat sheet, lessons) would say so.
      -- Invariant globalization drops nothing a Markdown server needs.
      vim.lsp.config("marksman", { cmd_env = { DOTNET_SYSTEM_GLOBALIZATION_INVARIANT = "1" } })
      vim.lsp.config("clangd", { cmd = { "clangd", "--background-index", "--clang-tidy", "--header-insertion=never" } })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("rihla_lsp_attach", { clear = true }),
        callback = function(ev)
          util.safe("lsp keymaps", on_attach, ev)
        end,
      })
    end,
  },

  -- Installs servers, formatters, linters and debuggers into
  -- ~/.local/share/nvim/mason. :Mason opens its UI.
  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonUninstall", "MasonLog", "MasonUpdate" },
    keys = { { "<leader>lm", "<cmd>Mason<CR>", desc = "Mason: installed tools" } },
    config = function()
      require("mason").setup({
        PATH = "skip", -- already added in nvim-lspconfig's init above
        registries = { tools.registry },
        max_concurrent_installers = 2,
        ui = {
          border = "rounded",
          icons = icons.nerd and nil or { package_installed = "+", package_pending = "~", package_uninstalled = "-" },
        },
      })
    end,
  },

  -- Completion and docs for the Neovim Lua API while editing your own
  -- ~/.config/rihla/local.lua (or this config).
  {
    "folke/lazydev.nvim",
    ft = "lua",
    main = "lazydev",
    opts = { library = { { path = "${3rd}/luv/library", words = { "vim%.uv" } } } },
  },
})
