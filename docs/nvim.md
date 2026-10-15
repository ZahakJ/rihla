# The Neovim side

What is in `nvim/`, how to change it without forking, and what happens on machines that
lack something.

## Layout

| Path | What |
|---|---|
| `nvim/init.lua` | checks the Neovim version (0.11+), sets Space as leader, hands over |
| `nvim/lua/rihla/init.lua` | load order; every step is guarded, so one failure is one line and the rest still works |
| `options.lua` `keymaps.lua` `autocmds.lua` | editor behaviour that needs no plugin |
| `icons.lua` | the ascii / nerd switch (see Icons) |
| `palette.lua` `statusline.lua` `dashboard.lua` | the shared Catppuccin Mocha palette and what is drawn from it |
| `lazy.lua` | plugin manager bootstrap, lockfile handling |
| `langs.lua` `lang.lua` `tools.lua` `dap.lua` | the language table and the engine that acts on it |
| `learn.lua` `habits.lua` `cheat.lua` `cmdpalette.lua` `commands.lua` `health.lua` | the teaching layer, `:Rihla`, `:checkhealth rihla` |
| `find.lua` `replace.lua` `term.lua` `conflict.lua` | the VS Code habits: pickers and grep scope, replace with undo, the terminals, merge conflicts in the file |
| `plugins/*.lua` | one file per area, each plugin with its keys |
| `nvim/lazy-lock.json` | the exact commit of every plugin |
| `nvim/tests/` | headless tests (see Tests) |

## Plugins

30 plugins. Each is pinned; nothing updates unless you run `rihla update`.

| Plugin | What |
|---|---|
| lazy.nvim | plugin manager, pinned to v11.17.5 in the bootstrap |
| catppuccin | the shared theme (Mocha, mauve accent) |
| lualine.nvim | status line in rihla's palette |
| bufferline.nvim | open files as tabs, like VS Code; hidden while only one file is open |
| which-key.nvim | press Space and wait: every group and key is listed with a description |
| indent-blankline.nvim | indent guides (box-drawing characters, safe in any font) |
| snacks.nvim (only its picker) | fuzzy finding: files (fd), live grep (ripgrep) with regex / case / whole-word toggles and a folder or glob scope, recent files first, buffers, symbols, the command palette and `vim.ui.select`. Pure Lua, no compiler |
| grug-far.nvim | replace across files with a preview of every change (`Space r p`); needs ripgrep |
| diffview.nvim | the 3-way merge view (`Space g m`) and file history (`Space g h`); needs git 2.31+, says so otherwise |
| dropbar.nvim | the breadcrumb above each file (folder > file > class > function), from LSP or tree-sitter |
| nvim-tree.lua | the file tree (VS Code's Explorer) |
| mini.nvim | one dependency-free plugin for text objects (mini.ai), surround (vim-surround keys), auto-pairs, closing buffers without closing windows, and icons in nerd mode |
| vim-sleuth | detects tabs vs spaces and indent width per file |
| vim-tmux-navigator | Ctrl-h/j/k/l across Neovim splits and tmux panes |
| toggleterm.nvim | the terminals (`Ctrl-\` bottom, `Space t t` floating, `Space t s` sends a line; `lua/rihla/term.lua`) and lazygit in a float |
| persistence.nvim | sessions per folder (`Space q s`) |
| nvim-lspconfig | server definitions for Neovim's built-in LSP client (`vim.lsp.enable`) |
| mason.nvim | installs servers, formatters, linters and debuggers into your home, no root; registry pinned |
| lazydev.nvim | completion for the Neovim API while editing your own `local.lua` |
| blink.cmp + friendly-snippets | completion, with the pure-Lua matcher (nothing downloaded or compiled) |
| conform.nvim | formatting, with the language server as fallback |
| nvim-lint | linters that are not language servers (hadolint) |
| gitsigns.nvim | changes in the gutter, hunk staging, blame |
| vim-fugitive | `:Git` |
| nvim-dap + nvim-dap-ui + nvim-nio | debugger and its panels |
| nvim-treesitter (main) + nvim-treesitter-textobjects | parser installs and function/class text objects; Neovim 0.12+ only (see Tree-sitter) |

Merge conflicts in the file are built in (`lua/rihla/conflict.lua`: colours,
`co` `ct` `cb` `c0`, `]x` `[x`, the quickfix list), as are the start screen and the habit
hints.

Search defaults are the shell's: ripgrep reads `shell/ripgreprc` (unless you set
`RIPGREP_CONFIG_PATH` yourself) and fd gets `--ignore-file shell/fdignore`
([shell.md](shell.md#defaults)).

## Customising without forking

Everything you change lives in `~/.config/rihla/`. `rihla install` and `rihla update`
never write there, so `git pull` of this repo never conflicts with your changes.

| File | Loaded | Use it for |
|---|---|---|
| `~/.config/rihla/init.lua` | first, before plugins | settings that must exist early: `vim.g.rihla_auto_install = false` |
| `~/.config/rihla/local.lua` | last | anything: options, keymaps, autocommands, `dap.configurations` |
| `~/.config/rihla/plugins/*.lua` | merged into the plugin spec | each file returns a lazy.nvim spec (or a list of them) |
| `~/.config/rihla/langs.lua` | merged over `lua/rihla/langs.lua` | add or change a language; `name = false` removes one |
| `~/.config/rihla/icons` | at startup | the word `nerd` or `ascii` (`:Rihla icons` writes it) |

Examples:

```lua
-- ~/.config/rihla/local.lua
vim.g.rihla_format_on_save = true      -- format every file on save
vim.g.rihla_habits = "strict"          -- or "off"
vim.opt.relativenumber = false
vim.keymap.set("n", "<leader>j", "<cmd>noh<CR>", { desc = "My own key" })
```

```lua
-- ~/.config/rihla/plugins/flash.lua
return {
  "folke/flash.nvim",
  keys = { { "s", function() require("flash").jump() end, desc = "Flash jump" } },
}
```

```lua
-- ~/.config/rihla/langs.lua
return {
  zig = { ft = { "zig" }, ts = { "zig" }, lsp = { "zls" } },        -- needs zls on PATH, or a tools.lua entry
  python = { fmt = { "black" } },                                     -- change one field
  java = false,                                                       -- never touch Java files
}
```

Plugins you add are pinned too: lazy writes them into the working lockfile at
`~/.local/share/nvim/rihla/lazy-lock.json`, which is seeded from the repo's
`nvim/lazy-lock.json`. The repo's pins always win for the plugins it ships.

## Languages

`lua/rihla/langs.lua` is one table: per language, the file types, tree-sitter parsers,
language servers, formatters, linters and debugger. `:Rihla langs` (`Space l L`) shows
what each has on this machine.

The first time a file type opens, rihla (in the background, after the file is on screen):

1. starts tree-sitter highlighting if a parser exists, otherwise keeps Vim's regex syntax
   and builds the parser if it can;
2. enables the first language server it finds on `PATH` (system installs win, so a
   company-provided `clangd` is used as is); if there is none, installs the first one this
   machine can run, with mason, and enables it when ready;
3. installs missing formatters and linters the same way.

Debuggers are installed on the first `F5` in that language, not on file open.

`vim.g.rihla_auto_install = false` stops all automatic installs; `:Rihla install python`
(or `all`) installs on demand. Headless, it waits until done, which is how to pre-seed a
machine: `nvim --headless "+Rihla install lua python" +qa`.

When the machine lacks something:

| Missing | Result |
|---|---|
| network | startup is unaffected once plugins are present; installs fail with one line each ("installing gopls failed (no network?)") |
| git, or git older than 2.19 | plugins must be pre-seeded (the installer does that); the gutter signs and hunk keys are off, `:Git` needs git itself, the file tree works |
| unzip | mason cannot unpack zip releases (stylua and others); the message says to install unzip |
| python3's `venv` module (Debian/Ubuntu: package `python3-venv`) | basedpyright, pylsp, ruff and debugpy are not attempted; one line names the package. `:checkhealth rihla` and `rihla check` warn about it |
| libicu | nothing visible: marksman (Markdown) is started with .NET's invariant globalization, so it runs without it |
| Node.js | npm-based servers (TS, JSON, YAML, Bash, HTML, CSS, Docker) are skipped with one line saying so. Python still gets basedpyright (from PyPI, it carries its own Node; needs Python 3.10+), or else pylsp |
| C compiler | one line, then regex highlighting for everything except the parsers Neovim ships (C, Lua, Markdown, Vim, help). The picker, breadcrumb (from the language server) and folds need none |
| old glibc | after installing a prebuilt binary, rihla runs it once (`--version`); if it fails with a `GLIBC_x.y` error the server is not enabled and the message says to install it another way. A system binary on `PATH` is always preferred |
| ripgrep / fd | file search uses `rg --files` or `find`; without ripgrep, `Space f g` asks for a pattern and runs `grep -r` into the quickfix list, and `Space r p` says it needs ripgrep (rihla installs both) |
| git 2.31 | `Space g m` / `Space g h` (diffview) say they need it; conflicts in the file (`co` `ct` ...) need no git at all, `Space g x` works with any git |
| lazygit | `Space g g` opens fugitive's `:Git` |
| clipboard tool, over SSH or in tmux | yank goes through OSC 52 to your local clipboard; paste comes from Neovim's own register |
| true colour | a 256-colour fallback theme (habamax) and a hint; Catppuccin returns if the terminal reports true colour later |
| Neovim 0.11 | works; nvim-treesitter is not loaded (it needs 0.12), so only bundled parsers highlight |

## Tree-sitter

Neovim ships parsers for C, Lua, Markdown, Vimscript, Vim help and tree-sitter queries.
Other languages need a parser compiled for this machine. nvim-treesitter (the `main`
branch) builds them with the tree-sitter CLI and a C compiler, and needs Neovim 0.12.
rihla fetches the CLI through mason when it is missing. Without a compiler rihla says so
once and keeps Vim's regex syntax highlighting, which colours everything, just less
precisely. Parsers built on another machine with the same OS, architecture and a
compatible glibc can be copied into `~/.local/share/nvim/site/parser/` (plus
`parser-info/`, and `queries/` linked to nvim-treesitter's `runtime/queries/<lang>`) and
are used as they are.

## Icons

`ascii` (the default) uses only ASCII and box-drawing characters: safe in any font, over
any SSH connection. `nerd` uses Nerd Font glyphs; choose it when your terminal uses a Nerd
Font. Order of precedence:
`$RIHLA_ICONS`, then `~/.config/rihla/icons`, then ascii. `:Rihla icons nerd` or
`rihla icons nerd` switches; restart Neovim afterwards.

## Habit hints

`vim.g.rihla_habits` is `hint` by default: the editor never blocks anything, and after a
run of slow presses (six `j` in a row, arrow keys in normal mode, five `x`) one line at the
bottom names the faster key and the lesson that teaches it. A hint only names keys from
lessons you have marked done (`Space h n` or `Space h d`). `strict` also stops a fifth
quick `h`/`j`/`k`/`l` in a row until you pause or use a count, and makes the arrow keys in
normal mode show the hint instead of moving. `Space t h` cycles off / hint / strict;
`:Rihla habits` shows the counts for this session.

## Troubleshooting

| Symptom | Look at |
|---|---|
| anything | `Space h C` / `:checkhealth rihla`: versions, tools, clipboard, colour, each language |
| a "rihla: X failed" line | `:Rihla log` has the full error |
| a language does nothing | `Space l L` / `:Rihla langs`, then `:Mason` and `:MasonLog` |
| no completion | `Space l I` (`:checkhealth vim.lsp`) to see whether a server is attached |
| boxes instead of icons | `:Rihla icons ascii`, restart |
| plugins at the wrong commit after a manual `git pull` | `rihla install` (or `:Rihla sync` when git is installed; `rihla update` runs both) |
| yank does not reach the system clipboard over SSH | the terminal must allow OSC 52 (kitty, WezTerm, iTerm2, Alacritty, Windows Terminal, foot do); in tmux, `set-clipboard on` (rihla's tmux config sets it) |

## Tests

| Command | What it checks |
|---|---|
| `nvim/tests/run.sh smoke` | startup is clean; every locked plugin is installed at its commit and loads; every `<leader>` key has a description; no Nerd Font glyph in ascii mode; the teaching UIs open. Runs in ascii and nerd mode |
| `nvim/tests/run.sh keys` | every Space key named in `docs/`, `README.md` and the dashboard exists as a mapping |
| `nvim/tests/run.sh learn` | lessons open in one window from every entry point, `Space h h` recovers from any layout, lesson copies never touch the repository, every popup closes with `q`, hints fit on one line |
| `nvim/tests/run.sh find` | `Space f g` and `Space f f` find the expected line and file, with or without ripgrep and fd |
| `nvim/tests/run.sh habits` | the eight VS Code habits with their real keys: picker, live grep and its toggles, grug-far replace and undo, terminals, breadcrumb and folds, file tree, numbered and pinned tabs, a real git merge conflict |
| `nvim/tests/run.sh lsp` | for Lua and Python: rihla installs the server, then it attaches, reports diagnostics, completes and answers hover |
| `nvim/tests/run.sh dap` | for debugpy (Python) and codelldb (C; `RIHLA_DAP_ADAPTERS=debugpy,codelldb,gdb` adds gdb 14+): stops on a breakpoint, evaluates a variable, ends |

They use whatever config `~/.config/nvim` points at, so they run as-is after
`rihla install`. `NVIM_BIN` picks the binary; `RIHLA_LSP_LANGS` the languages.
