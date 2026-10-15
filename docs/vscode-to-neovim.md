# VS Code to Neovim

What you did in VS Code, and how to do it here. Inside Neovim, `Space h v` searches this
table (type "rename", "ctrl+shift+f", "multi cursor") and `Space h V` opens it to read.

Three columns matter:

- **rihla**: the key in this setup.
- **Plain Vim**: the way that works in any Vim or Neovim with no config, on any server.
  "none" means there is no
  sensible built-in way.
- **Notes**: what is different.

`Space` is the leader key. `Space f f` means: press Space, release, press f, press f.
`Ctrl-w v` means Ctrl and w together, release, then v.

## The eight habits

The things most of a VS Code day is made of, each on one key. Lesson 7b (`:Rihla learn 7b`,
or `Space h n` after lesson 7) walks through all eight on a practice project.

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| 1. Ctrl+P: open a file by name | `Ctrl-p` or `Space f f` | `:find name` with `:set path+=**` | fuzzy, with a preview; open and recently used files come first; hidden files are searched, `.git` and `node_modules` are not (fd, same defaults as the shell) |
| 2. Ctrl+Shift+F: search in files, regex | `Space f g` | `:vimgrep /re/ **` then `:copen` | live ripgrep, regex on. In the search: `Alt-r` regex, `Alt-c` match case, `Alt-w` whole word (the title shows `.*` `Aa` `ab\|`), `Alt-s` only in a folder or glob, `Ctrl-q` all hits to the quickfix list, then `]q` `[q`. `Space f G` asks for the folder or glob first; `text -- -g *.ts` in the prompt works too |
| 3. Ctrl+Shift+H: replace in files | `Space r p` | `:vimgrep`, then `:cdo s/old/new/g \| update` | grug-far: Search, Replace, Files Filter (`*.ts`), Paths (`src/`) at the top, every change shown before and after, nothing written until `\r` (replace all). `Space r u` puts the files back. In one file: `Space r r` |
| 4. Ctrl+`: terminal on demand | ``Ctrl-\`` (bottom), `Space t t` (floating) | `:terminal` | opens in the file's folder, keeps running when hidden; `Space t s` runs the line or selection in it; `Esc Esc` to scroll or copy |
| 5. A clear view of the file | the bar above the file, `Space c s`, `za` | `gO`, `za`, `zM` / `zR` | breadcrumb (folder > file > class > function), outline panel, folds (open at the start), errors as text at the line end and other problems as gutter signs (`Space x x` lists them, `K` explains), `Space l f` formats |
| 6. Explorer sidebar | `Space e` (open, focus, close), `Space E` (show this file) | `:Explore` | git status on each file, `a` new, `r` rename, `d` delete, `x` cut, `c` copy, `p` paste, `?` all keys; `Ctrl-h` / `Ctrl-l` move between it and the file |
| 7. Editor tabs | `Alt-1`..`Alt-9` or `Space 1`..`Space 9`, `Space b b` | `:ls`, `:b 3` | numbered tabs along the top; `Space b p` pin, `Space b o` close others, `Space b r` close to the right, `Space b d` close; `[b` `]b` previous / next |
| 8. Merge conflicts | `]x` `[x`, `co` `ct` `cb` `c0`, `Space g m` | `/^<<<<<<<` | in the file: ours / theirs coloured, `co` keep ours (current), `ct` take theirs (incoming), `cb` both, `c0` neither, `u` undoes; `Space g x` lists every conflict; `Space g m` is the 3-way merge view, `Space g h` the file's history |

## Files and navigation

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Ctrl+P (quick open file) | `Space f f` or `Ctrl-p` | `:e **/name<Tab>` or `:find name` | `:set path+=**` makes `:find` search subfolders |
| Ctrl+P, recent files | `Space f r` | `:browse oldfiles` | |
| Ctrl+Tab (switch open editor) | `Space b b`, `[b` `]b` | `:ls` then `:b 3`, `:bnext`, `:bprev` | Neovim 0.11 maps `[b` `]b` by default |
| Ctrl+Tab twice quickly (last two files) | `Ctrl-^` or `Space b a` | `Ctrl-^` | the alternate file; the single most useful buffer key |
| Alt+1..9 (go to editor 1..9) | `Alt-1`..`Alt-9` or `Space 1`..`Space 9` | `:b` + number from `:ls` | the tabs along the top are numbered |
| Pin editor | `Space b p` | none | pinned tabs stay on the left; `Space b P` closes the rest |
| Close editors to the right | `Space b r` | none | |
| Ctrl+W (close editor) | `Space b d` | `:bd` | `:bd` also closes the window; rihla's keeps the layout |
| Ctrl+K W (close all editors) | `Space b o` (close others) | `:%bd` then `:e#` | |
| Ctrl+Shift+T (reopen closed) | `Space f r` then Enter | `:e#` | |
| Ctrl+Shift+E (Explorer sidebar) | `Space e` | `:Explore` or `:e .` | in the tree: `a` new, `d` delete, `r` rename, `x` cut, `c` copy, `p` paste, `?` help; `Space e` again focuses it, a third time closes it |
| Reveal active file in Explorer | `Space E` | `:Explore` opens at the file's folder | |
| New file | `:e path/new.txt` | `:e path/new.txt` | rihla creates missing folders on save |
| Ctrl+S (save) | `Ctrl-s` | `:w` | |
| Save all | `:wa` | `:wa` | |
| Ctrl+G (go to line) | `42G` or `:42` | `42G` or `:42` | |
| Go to start / end of file | `gg` / `G` | `gg` / `G` | |
| Ctrl+Shift+O (go to symbol in file) | `Space f s` | `gO` (with LSP) | |
| Ctrl+T (go to symbol in workspace) | `Space f S` | none | |
| Alt+Left / Alt+Right (back / forward) | `Ctrl-o` / `Ctrl-i` | `Ctrl-o` / `Ctrl-i` | the jump list: lesson 16 |
| Go to last edit location | `` `. `` or `g;` | `` `. `` or `g;` | `g;` and `g,` walk the change list |
| Breadcrumbs | the bar above each file; `Space c p` picks a part | `gO` | from the language server, else tree-sitter |
| Outline view | `Space c s` | `gO` (with LSP) | a panel on the right; `Enter` jumps, `Esc` closes |
| Fold / unfold (Ctrl+Shift+[ / ]) | `za` or `Space z`; `zM` / `zR` all | `za`, `zc`, `zo`, `zM`, `zR` | folds come from tree-sitter or the language server, else indentation; files open unfolded |
| Open folder | `cd` in the shell, then `nvim` | `:cd path` | Neovim's project is its working directory |
| Recent folders / workspaces | `Space q S` (sessions) | `:mksession` / `nvim -S` | sessions save open files and splits per folder |
| Reopen last workspace | `Space q s` | `nvim -S Session.vim` | |

## Search and replace

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Ctrl+F (find in file) | `/text` then `n` `N` | `/text`, `n`, `N` | `?text` searches backwards |
| Find the word under the cursor | `*` / `#` | `*` / `#` | |
| Ctrl+H (replace in file) | `Space r r` (word under the cursor filled in, exact case) | `:%s/old/new/gc` | asks at each match: `y` yes, `n` no, `a` all, `q` stop; live preview as you type |
| Replace in selection | select, then `:s/old/new/g` | same | `:` on a selection fills in `'<,'>` |
| Ctrl+Shift+F (find in files) | `Space f g` (or `Ctrl-Shift-f` where the terminal passes it) | `:vimgrep /text/ **` then `:copen` | live ripgrep, regex on; `Ctrl-q` sends every hit to the quickfix list |
| Files to include / exclude | `Space f G`, or `Alt-s` in the search, or `text -- -g *.ts` | `:vimgrep /text/ src/**/*.ts` | a folder, a glob, or both |
| Find in files for the word under the cursor | `Space f w` | `:vimgrep /<C-r><C-w>/ **` | |
| Ctrl+Shift+H (replace in files) | `Space r p` (or `Space f g`, `Ctrl-q`, then `:cdo s/old/new/g \| update`) | `:vimgrep`, then `:cdo s/old/new/g \| update` | grug-far previews every change; `\r` replaces all; `Space r u` undoes; lesson 11 for `:cdo` |
| Match case / whole word toggles | `Alt-c` / `Alt-w` in `Space f g`; in `/`: `\C`, `\<word\>` | `\C` in the pattern, `\<word\>` | rihla: case-insensitive unless you type a capital |
| Regex search | always on | always on | Vim regex: `\v` at the start makes it like normal regex |

## Editing

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Ctrl+D (add next occurrence) | `*` then `cgn`, type, `Esc`, then `.` `.` `.` | same | `n` skips one; this is Vim's multi-cursor. Lesson 6 |
| Ctrl+Shift+L (select all occurrences) | `:%s/word/new/g` | same | or `*` then `:%s//new/g` (empty pattern = last search) |
| Alt+Click (multi-cursor) | `Ctrl-v` block select, `I` or `A` to type on every line | same | for columns; for scattered places use `cgn` + `.` or a macro |
| Ctrl+Alt+Down (cursor below) | `Ctrl-v` `j` `j` then `I` | same | |
| Alt+Up / Alt+Down (move line) | `Alt-k` / `Alt-j` | `ddkP` / `ddp` or `:m -2` / `:m +1` | works on a selection too |
| Shift+Alt+Down (copy line down) | `yyp` | `yyp` | `yyP` copies it up |
| Ctrl+Shift+K (delete line) | `dd` | `dd` | `5dd` deletes five |
| Ctrl+X on an empty selection (cut line) | `dd` | `dd` | deleted text goes to the register, so `p` pastes it |
| Ctrl+C / Ctrl+V | `y` / `p` | `"+y` / `"+p` | rihla puts yanks on the system clipboard; over SSH via OSC 52 |
| Paste without losing the clipboard | `Space p` in visual mode | `"_dP` | |
| Ctrl+Z / Ctrl+Shift+Z | `u` / `Ctrl-r` | `u` / `Ctrl-r` | `:earlier 10m` goes back in time |
| Ctrl+/ (toggle comment) | `gcc`, `gc` on a selection, `Ctrl-/` | `gcc`, `gc{motion}` (Neovim 0.10+) | `gcip` comments a paragraph |
| Shift+Alt+A (block comment) | `gc` on a selection | same | |
| Tab / Shift+Tab on a selection (indent) | `>` / `<` (selection stays) | `>` / `<`, `>>` / `<<` | `.` repeats |
| Ctrl+] / Ctrl+[ (indent line) | `>>` / `<<` | same | |
| Format document (Shift+Alt+F) | `Space l f` | `gg=G` (indent only) | uses the formatter from the langs table |
| Format selection | select, `Space l f` or `gq` | `=` | |
| Format on save | `Space t f` toggles | none | off by default, so you do not reformat a whole shared file by accident |
| Expand selection (Shift+Alt+Right) | `vaf` `vac` `vi(` `va{` | `vi(` `va{` `vip` | text objects: lesson 4 |
| Select word | `viw` | `viw` | |
| Select line (Ctrl+L) | `V` | `V` | |
| Select all (Ctrl+A) | `ggVG` | `ggVG` | |
| Surround with quotes / brackets | `ysiw"`, `cs"'`, `ds(` | none | vim-surround keys |
| Auto-close brackets | on | none | |
| Join lines (Ctrl+J in some keymaps) | `J` | `J` | `gJ` joins without a space |
| Change case | `~`, `gUiw`, `guiw` | same | |
| Increment number | `Ctrl-a` / `Ctrl-x` | same | `g Ctrl-a` on a block makes a sequence |
| Rename file | `Space e`, then `r` on the file | `:saveas new` then delete the old | |
| Snippets | type the prefix, accept from the menu, `Tab` to the next field | none | friendly-snippets: the VS Code snippet collection |
| Emmet | not included | none | add it in `~/.config/rihla/plugins/` if you write HTML |

## Code intelligence

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| IntelliSense (Ctrl+Space) | `Ctrl-Space` in insert mode; appears as you type | `Ctrl-x Ctrl-o` (omni), `Ctrl-n` (words) | `Enter` / `Ctrl-y` accept, `Ctrl-e` closes |
| Parameter hints (Ctrl+Shift+Space) | shown while you type; `Space l k` on demand | `Ctrl-s` in insert mode (Neovim 0.11, with LSP) | rihla keeps `Ctrl-s` for saving |
| Hover (mouse over) | `K` | `K` (Neovim 0.10+, with LSP) | `K` twice jumps into the hover window |
| F12 (go to definition) | `gd` or `F12` | `gd` jumps to the local declaration without LSP | |
| Ctrl+F12 (go to implementation) | `gri` | `gri` (Neovim 0.11) | |
| Go to type definition | `grt` | `grt` (Neovim 0.12) | |
| Shift+F12 (find all references) | `grr` or `Shift-F12` | `grr` (Neovim 0.11) | results land in the quickfix list |
| Alt+F12 (peek definition) | `Space l d` (picker with preview) | none | |
| F2 (rename symbol) | `grn` or `F2` | `grn` (Neovim 0.11) | |
| Ctrl+. (quick fix / code action) | `gra` or `Space l a` | `gra` (Neovim 0.11) | |
| Call hierarchy | `Space l c` | none | incoming calls |
| Organise imports | `Space l a` and pick it, or format (Python: ruff does it) | none | |
| Inlay hints | `Space t i` | none | |
| Restart language server | `Space l l` | `:lsp restart` (0.12) | |
| Output / language server status | `Space l I` | `:checkhealth vim.lsp` | |
| Extensions: install a language | `:Rihla install go` or just open a .go file | none | see "Settings and extensions" below |

## Problems and diagnostics

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Ctrl+Shift+M (Problems panel) | `Space f d` (picker), `Space x X` (quickfix) | `:lua vim.diagnostic.setqflist()` | |
| Problems in this file | `Space x x` | `:lua vim.diagnostic.setloclist()` | |
| F8 / Shift+F8 (next / previous problem) | `]d` / `[d` or `F8` / `Shift-F8` | `]d` / `[d` (Neovim 0.10+) | `]D` jumps to the last |
| Show the error under the cursor | `Space x d` or `Ctrl-w d` | `Ctrl-w d` (Neovim 0.10+) | |
| Toggle inline error text | `Space t v` | none | |

## Layout: splits, panels, terminal

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Ctrl+\\ (split editor right) | `Space \|` | `Ctrl-w v` or `:vsplit` | same key as the tmux split |
| Split editor down | `Space -` | `Ctrl-w s` or `:split` | |
| Ctrl+1 / Ctrl+2 (focus editor group) | `Ctrl-h/j/k/l` | `Ctrl-w h/j/k/l` | rihla's keys also cross into tmux panes |
| Close editor group | `Space w c` | `Ctrl-w c` | |
| Close other groups | `Space w o` | `Ctrl-w o` | |
| Maximise editor group | `Space w m` (toggle) | `Ctrl-w _` and `Ctrl-w \|`, `Ctrl-w =` to even out | |
| Resize | `Ctrl-arrow keys` | `Ctrl-w +` `-` `<` `>` | |
| Ctrl+` (toggle terminal) | ``Ctrl-\`` | `:terminal` | `Esc Esc` leaves terminal mode; starts in the file's folder |
| Terminal in the middle of the screen | `Space t t` | none | its own session, separate from the bottom one |
| Run selected text in terminal | `Space t s` | none | the line, or the selected lines |
| New terminal in a split | `Space t b` / `Space t r` | `:split \| terminal` | in tmux, a pane (`prefix -`) is often better |
| Ctrl+B (toggle sidebar) | `Space e` | `:Lexplore` | |
| Zen mode (Ctrl+K Z) | `Space t z` | none | |
| Toggle word wrap (Alt+Z) | `Space t w` | `:set wrap!` | |
| Minimap | not included | none | `Space c s` (outline) shows the file's structure instead |
| Tabs as editor windows | buffers along the top; `:tabnew` for real tabs | `:tabnew`, `gt`, `gT` | Vim tabs are layouts, not files |

## Command palette and help

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Ctrl+Shift+P (command palette) | `Space Space` | `:` then `Tab` to complete | shows the key for each action, so you learn it |
| Keyboard shortcuts list | `Space h k` or just `Space` and wait | `:map` | |
| Keybinding cheat sheet | `Space h c` | none | |
| Help | `Space f h` | `:help topic` | `:help` is excellent; `Ctrl-]` follows links |
| Welcome page | the start screen (`nvim` with no file) | `:intro` | |
| Interactive tutorial | `Space h t` | `:Tutor` | lesson 0 |

## Source control

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Ctrl+Shift+G (Source Control panel) | `Space g g` (lazygit) or `Space g s` | `:!git status` | without lazygit, `Space g g` opens fugitive's `:Git` |
| Stage a change | `Space g a` on the hunk | none | in `:Git`: `s` stage, `u` unstage, `=` diff, `cc` commit |
| Discard a change | `Space g r` | `:!git checkout -- %` | |
| Commit | `Space g c` | `:!git commit` | |
| Push / Pull | `Space g P` / `Space g f` | `:!git push` | |
| Gutter change markers | on | none | |
| Next / previous change | `]h` / `[h` | `]c` / `[c` in diff mode | |
| Open changes (diff) | `Space g d` | `:diffsplit` | |
| Timeline / file history | `Space g h` | `:!git log -p %` | diffview: every commit that touched the file, with its diff |
| Git blame (GitLens) | `Space g b` (line), `Space g B` (file), `Space g t` (inline) | `:!git blame %` | |
| File history (into the quickfix list) | `Space g L` | `:!git log -p %` | |
| Merge conflicts: Accept Current / Incoming / Both | `co` / `ct` / `cb` (`c0`: neither), `]x` `[x` to move | `/^<<<<<<<` to find markers | only in a file with conflict markers; `u` undoes |
| Merge editor (3-way) | `Space g m` | `:Gvdiffsplit!` (fugitive), then `d2o` / `d3o` | ours and theirs on top, the result below; `q` closes |
| All conflicts | `Space g x` | `:vimgrep /^<<<<<<</ **` | into the quickfix list |

## Debugging

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| F5 (start / continue) | `F5` or `Space d c` | `:Termdebug` (C, gdb only) | the debugger installs the first time you press it |
| Shift+F5 (stop) | `Shift-F5` or `Space d t` | none | |
| F9 (toggle breakpoint) | `F9` or `Space d b` | none | |
| Conditional breakpoint | `Space d B` | none | |
| Logpoint | `Space d L` | none | |
| F10 / F11 / Shift+F11 | the same keys, or `Space d o` / `d i` / `d O` | none | |
| Run to cursor | `Space d C` | none | |
| Debug console | `Space d r` (REPL) | none | |
| Variables / watch / call stack panels | open automatically; `Space d u` toggles | none | |
| Hover a variable while debugging | `Space d e` | none | |
| launch.json | `dap.configurations` in `~/.config/rihla/local.lua` | none | nvim-dap also reads `.vscode/launch.json` |

## Settings and extensions

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Settings (Ctrl+,) | `~/.config/rihla/local.lua` (`Space f u` to open) | `~/.config/nvim/init.lua` | never edit the repo; local.lua loads last |
| Install an extension | a file in `~/.config/rihla/plugins/` returning a lazy.nvim spec | `:packadd` | |
| Add a language | an entry in `~/.config/rihla/langs.lua` | none | see `lua/rihla/langs.lua` for the fields |
| Keyboard shortcuts.json | `vim.keymap.set(...)` in local.lua | `:nnoremap` | |
| Change colour theme | `Space f C` to try; set in local.lua | `:colorscheme habamax` | the shared rihla theme is Catppuccin Mocha |
| Icons (file icon theme) | `:Rihla icons nerd` (needs a Nerd Font) | none | ascii by default, safe on any terminal |
| Update extensions | `rihla update` (moves every pin together) | none | nothing updates on its own |
| Developer: Reload Window | quit and reopen, or `:restart` (0.12) | `:source $MYVIMRC` | |
| Check what is wrong | `Space h C` (`:Rihla check`) | `:checkhealth` | |
| Settings Sync | the rihla repo is your settings sync | none | `~/.config/rihla` is yours to keep in your own dotfiles |

## Habits that do not translate

| VS Code | rihla | Plain Vim | Notes |
|---|---|---|---|
| Hold an arrow key to travel | counts: `12j`, `}`, `Ctrl-d`, `/text` | same | the gutter shows relative line numbers so the count is right there |
| Click to place the cursor | still works; try `f`, `t`, `/` | same | the mouse is on in rihla |
| Select with the mouse, then type | `ciw`, `ci"`, `cit` | same | change a text object in one go |
| Stay in insert mode | `Esc` after every change | same | short changes make `u` and `.` precise |
| Search the Marketplace for a feature | `:help` it first | same | Vim usually already has it |
