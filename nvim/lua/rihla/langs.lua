-- Languages. One entry per language; adding a language is one entry here or
-- in ~/.config/rihla/langs.lua (which is merged over this table; set an
-- entry to `false` there to switch a language off).
--
-- Fields (all optional except ft):
--   ft    file types this entry covers (:set ft? in a buffer shows it)
--   ts    tree-sitter parsers for syntax highlighting and text objects
--   lsp   language servers, by their nvim-lspconfig name. Each item is a
--         server, or a list of alternatives in order of preference: the first
--         one already on PATH is used, otherwise the first one that can be
--         installed on this machine (e.g. no Node.js -> skip npm servers).
--   fmt   formatters, by their conform.nvim name, run in order
--   lint  linters, by their nvim-lint name
--   dap   debug adapters (see lua/rihla/dap.lua), alternatives in order
--   tools extra mason packages to install alongside
--
-- Tools missing from PATH are installed by mason the first time a file of
-- that type is opened (vim.g.rihla_auto_install = false to stop that), or on
-- demand with :Rihla install <language>. :Rihla langs shows the status.
return {
  lua = {
    ft = { "lua" },
    ts = { "lua", "luadoc" },
    lsp = { "lua_ls" },
    fmt = { "stylua" },
  },
  python = {
    ft = { "python" },
    ts = { "python" },
    -- basedpyright installs from PyPI with its own Node runtime, so it works
    -- on machines without Node.js; pylsp is pure Python, the last resort.
    lsp = { { "basedpyright", "pyright", "pylsp" }, "ruff" },
    fmt = { "ruff_organize_imports", "ruff_format" },
    dap = { "debugpy" },
  },
  c = {
    ft = { "c", "cpp", "objc", "objcpp", "cuda" },
    ts = { "c", "cpp" },
    lsp = { "clangd" },
    fmt = { "clang-format" },
    dap = { "codelldb", "gdb" },
  },
  rust = {
    ft = { "rust" },
    ts = { "rust" },
    lsp = { "rust_analyzer" },
    fmt = { "rustfmt" }, -- comes with rustup, not mason
    dap = { "codelldb", "gdb" },
  },
  go = {
    ft = { "go", "gomod", "gowork", "gotmpl" },
    ts = { "go", "gomod", "gosum", "gowork" },
    lsp = { "gopls" },
    fmt = { "goimports", "gofmt" },
    dap = { "delve" },
  },
  javascript = {
    ft = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
    ts = { "javascript", "typescript", "tsx", "jsdoc" },
    lsp = { "ts_ls" },
    fmt = { "prettier" },
  },
  html = { ft = { "html" }, ts = { "html" }, lsp = { "html" }, fmt = { "prettier" } },
  css = { ft = { "css", "scss", "less" }, ts = { "css", "scss" }, lsp = { "cssls" }, fmt = { "prettier" } },
  bash = {
    ft = { "sh", "bash" },
    ts = { "bash" },
    lsp = { "bashls" }, -- runs shellcheck itself when it is installed
    fmt = { "shfmt" },
    tools = { "shellcheck" },
  },
  json = { ft = { "json", "jsonc" }, ts = { "json" }, lsp = { "jsonls" }, fmt = { "prettier" } },
  yaml = { ft = { "yaml" }, ts = { "yaml" }, lsp = { "yamlls" }, fmt = { "prettier" } },
  toml = { ft = { "toml" }, ts = { "toml" }, lsp = { "taplo" }, fmt = { "taplo" } },
  markdown = {
    ft = { "markdown" },
    ts = { "markdown", "markdown_inline" },
    lsp = { "marksman" },
    fmt = { "prettier" },
  },
  docker = { ft = { "dockerfile" }, ts = { "dockerfile" }, lsp = { "dockerls" }, lint = { "hadolint" } },
  sql = { ft = { "sql" }, ts = { "sql" }, fmt = { "sql_formatter" } },
  java = { ft = { "java" }, ts = { "java" }, lsp = { "jdtls" } }, -- jdtls needs Java 21+ on PATH
  vim = { ft = { "vim" }, ts = { "vim", "vimdoc" } },
  make = { ft = { "make" }, ts = { "make" } },
  gitcommit = { ft = { "gitcommit", "diff", "git_rebase" }, ts = { "gitcommit", "diff", "git_rebase" } },
}
