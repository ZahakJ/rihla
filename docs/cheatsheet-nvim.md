# rihla: Neovim cheat sheet

Close this sheet with `q` or `Esc`. Search it with `/`, a word, `Enter`.

## How keys are written

| Written | Means |
|---|---|
| `Space h n` | press Space, let go, press h, let go, press n: one key after another |
| `Ctrl-d` | hold Ctrl and press d (Vim's help writes it `<C-d>`) |
| `G` | a capital letter: Shift and g |
| `:q Enter` | type a colon, then q, then press Enter (the `:` line appears at the bottom) |
| `Esc` | the Escape key. It gets you out of almost anything; press it twice when unsure |
| leader | in rihla, the `Space` key (`<leader>` in Vim's help) |
| prefix | tmux only: `Ctrl-Space`, pressed before a tmux key |
| normal mode | where keys are commands (`j` moves down). You start here; `Esc` comes back here |
| insert mode | keys type text. The bottom bar says INSERT |
| buffer / window | an open file / a view of one on the screen |

Lost? `Esc` twice, then `Space h h`: back to your lesson in one window.

Leader is `Space`. Press `Space` and wait: a popup lists what can follow.
`Space Space` is the command palette (search by what you want to do; the key is shown next to it).
`Space h c` opens this sheet, `Space h v` searches the VS Code table, `Space h l` opens your current lesson.

Keys in **plain Vim** (no plugin, work on any server) are marked with a dot: ·

## The eight VS Code habits

| VS Code | rihla |
|---|---|
| Ctrl+P: open a file by name | `Ctrl-p` or `Space f f` (open and recent files first) |
| Ctrl+Shift+F: search in files (regex) | `Space f g`; in it `Alt-r` regex, `Alt-c` case, `Alt-w` word, `Alt-s` folder/glob, `Ctrl-q` quickfix |
| Ctrl+Shift+H: replace in files | `Space r p` (preview first, `\r` replaces all, `Space r u` undoes); `Space r r` in this file |
| Ctrl+`: terminal | ``Ctrl-\`` bottom, `Space t t` floating; `Space t s` runs the line or selection there |
| Breadcrumbs, outline, folding | the bar above the file; `Space c s` outline; `za` or `Space z` fold |
| Explorer | `Space e` open / focus / close, `Space E` show this file; `?` in the tree |
| Editor tabs | `Alt-1`..`Alt-9` or `Space 1`..`Space 9`, `Space b b` pick, `Space b p` pin, `Space b d` close |
| Merge conflicts | `]x` `[x`, then `co` ours, `ct` theirs, `cb` both, `c0` none; `Space g m` 3-way view |

## Survival

| Key | Does |
|---|---|
| `i` `a` `o` `O` · | insert before cursor / after / new line below / above |
| `Esc` · | back to normal mode (also clears search highlight) |
| `:w` `:q` `:wq` `:q!` · | save, quit, both, quit without saving |
| `Ctrl-s` | save (VS Code habit) |
| `u` `Ctrl-r` · | undo, redo |
| `.` · | repeat the last change |
| `:Tutor` · | the built-in interactive tutorial (lesson 0) |

## Moving

| Key | Does |
|---|---|
| `w` `b` `e` · | next word start / previous word start / word end (`W B E`: WORDs, by spaces) |
| `0` `^` `$` · | line start / first non-blank / line end |
| `f<c>` `t<c>` `;` `,` · | jump to / before character `c` on the line; repeat forward / back |
| `gg` `G` `42G` · | first line, last line, line 42 |
| `}` `{` · | next / previous paragraph (blank line) |
| `%` · | matching bracket |
| `Ctrl-d` `Ctrl-u` · | half page down / up (rihla keeps the cursor centred) |
| `7j` `3k` · | counts: the relative numbers in the gutter tell you the count |
| `Ctrl-o` `Ctrl-i` · | jump back / forward (the jump list) |
| `''` `` `. `` `gi` · | back to last jump / last change / insert where you last inserted |
| `Ctrl-h/j/k/l` | move to the split or tmux pane on that side |

## Editing: operator + motion

| Key | Does |
|---|---|
| `d` `c` `y` · | delete, change (delete + insert), yank (copy) ... followed by a motion |
| `dw` `cw` `y$` `d}` · | delete word, change word, copy to line end, delete paragraph |
| `dd` `cc` `yy` · | the whole line |
| `diw` `ci"` `da(` `yit` · | text objects: inner word, inside quotes, around parens, inside tag |
| `dif` `vac` `cio` | function / class / conditional-or-loop (tree-sitter text objects; need the language's parser, else one line says so) |
| `p` `P` · | paste after / before |
| `>>` `<<` `=` · | indent, outdent, re-indent |
| `gcc` `gc{motion}` · | comment a line / a motion (`Ctrl-/` also works) |
| `ys{motion}{char}` `ds{char}` `cs{old}{new}` | add / delete / change surrounding quotes or brackets |
| `Alt-j` `Alt-k` | move line or selection down / up (Vim: `:m +1`, `ddp`) |
| `v` `V` `Ctrl-v` · | visual: characters, lines, block |

## Search and replace

| Key | Does |
|---|---|
| `/text` `?text` `n` `N` · | search forward / back, next / previous |
| `*` `#` · | search the word under the cursor |
| `:%s/old/new/gc` · | replace in file, confirm each (live preview while typing) |
| `cgn` then `.` · | change the next match, `.` repeats on the next one (multi-cursor, Vim style) |
| `Space r r` | `:%s` with the word under the cursor filled in (exact case, `\C`): type the new text, `Enter`, then `y`/`n` at each match (on a selection: the selected text) |
| `Space f g` | grep the project (live, regex); `text -- -g *.ts` searches only `.ts` files |
| `Space f G` | grep, asking first where: a folder, a glob or both (`src **/*.ts`) |
| `Space f w` | grep the word under the cursor or the selection |
| `Alt-r` `Alt-c` `Alt-w` `Alt-s` in grep | regex / case-sensitive / whole word / folder or glob; the title shows `.*` `Aa` `ab\|` |
| `Ctrl-q` in a picker | send results to the quickfix list (`]q` `[q` walk it), then `:cdo s/a/b/` |
| `Space r p` | replace across files (grug-far): every change previewed, `\r` replaces all, `Space r u` puts the files back |
| `Space r f` | the same, in this file only |

## Find (Space f)

| Key | Does |
|---|---|
| `Space f f` or `Ctrl-p` | find file (open and recent files first, hidden files too) |
| `Space f r` | recent files |
| `Space f b` | open buffers |
| `Space f g` / `Space f G` | grep text / grep in a folder or glob |
| `Space f s` / `Space f S` | symbols in file / in workspace |
| `Space c s` | outline: this file's symbols in a panel on the right |
| `Space f d` | diagnostics |
| `Space f h` `Space f k` `Space f c` | help, keymaps, commands |
| `Space f R` | resume the last picker |
| `Space f u` | your own overrides in `~/.config/rihla` |

## Files, buffers, windows

| Key | Does |
|---|---|
| `Space e` / `Space E` | file tree: open, focus, close / show this file in it (`?` in the tree for its keys: `a` new, `r` rename, `d` delete, `x` cut, `c` copy, `p` paste) |
| `[b` `]b` · | previous / next buffer (the tabs along the top) |
| `Alt-1`..`Alt-9` / `Space 1`..`Space 9` | go to tab 1..9 (the numbers on the tabs) |
| `Space b b` | pick an open buffer (type part of its name) |
| `Ctrl-^` · / `Space b a` | alternate buffer (toggle between the last two) |
| `Space b p` / `Space b P` | pin the tab / close every tab that is not pinned |
| `Space b o` / `Space b r` | close other tabs (pinned and unsaved ones stay) / the ones to the right |
| `Space b d` | close buffer, keep the window |
| `Space \|` `Space -` | split right / below (same keys as the tmux splits) |
| `Ctrl-w s` `Ctrl-w v` `Ctrl-w c` `Ctrl-w o` · | split, vsplit, close, only this one |
| `Space w m` | maximise / restore the window |
| `Ctrl-arrows` | resize the window |
| `Space q s` | restore the session for this folder |

## Code (LSP)

| Key | Does |
|---|---|
| `K` · | hover documentation |
| `gd` / `F12` | go to definition |
| `grr` · / `Shift-F12` | references |
| `grn` · / `F2` | rename |
| `gra` · / `Space l a` | code action (quick fix) |
| `gri` · `grt` · `gO` · | implementation, type definition, symbols in file |
| `]d` `[d` · / `F8` | next / previous diagnostic |
| `Ctrl-w d` · / `Space x d` | diagnostic under the cursor in a float |
| `Space l f` / `gq{motion}` | format file or selection |
| `za` · / `Space z` | fold or unfold here (`zM` / `zR` · all; `Space Z` toggles all) |
| `Space c p` | breadcrumb (the bar above the file): pick a part, browse its siblings |
| `Space t f` | format on save on/off (off by default) |
| `Ctrl-Space` (insert) | open completion; `Enter` or `Ctrl-y` accept, `Ctrl-n/p` move, `Ctrl-e` close |
| `Space l k` | signature help (it also pops up by itself while you type arguments). Plain Neovim 0.11 has it on `Ctrl-s` in insert mode; rihla uses that key to save |
| `Space l L` | which languages have what installed |
| `Space l m` | `:Mason`, the tool installer |

## Diagnostics and quickfix (Space x)

| Key | Does |
|---|---|
| `Space x x` | this buffer's problems in the location list |
| `Space x X` | all problems in the quickfix list |
| `Space x q` / `Space x l` | toggle quickfix / location list |
| `]q` `[q` · | next / previous quickfix item |
| `:cdo {cmd}` · | run a command on every quickfix entry |

## Git (Space g)

| Key | Does |
|---|---|
| `Space g g` | lazygit (or `:Git` when lazygit is missing) |
| `]h` `[h` | next / previous changed hunk |
| `Space g p` | preview the hunk |
| `Space g a` / `Space g r` | stage / reset the hunk (works on a selection too) |
| `Space g b` / `Space g B` | blame line / whole file |
| `Space g d` | diff against the index |
| `Space g s` `Space g c` `Space g l` | status, commit, log (fugitive) |
| `ih` | text object: the hunk (`vih`, `dih`) |
| `]x` `[x` | next / previous merge conflict (in a file with conflict markers) |
| `co` `ct` `cb` `c0` | conflict: keep ours / take theirs / both / neither (only in a conflicted file; `u` undoes) |
| `Space g x` | every conflict in the repository in the quickfix list |
| `Space g m` | 3-way merge view (diffview), `q` closes |
| `Space g h` / `Space g H` | history of this file / of the repository |

## Debug (Space d, or VS Code function keys)

| Key | Does |
|---|---|
| `F5` / `Space d c` | start or continue |
| `F9` / `Space d b` | toggle breakpoint (`Space d B` conditional, `Space d L` log point) |
| `F10` `F11` `Shift-F11` | step over, into, out |
| `Shift-F5` / `Space d t` | stop |
| `Space d u` | panels on/off |
| `Space d e` | evaluate the expression under the cursor |

## Terminal and toggles (Space t)

| Key | Does |
|---|---|
| ``Ctrl-\`` | terminal at the bottom on/off (starts in the file's folder, keeps running when hidden) |
| `Space t t` / `Space t b` / `Space t r` | floating / bottom / right terminal |
| `Space t s` | run this line (or the selection) in the terminal |
| `Esc Esc` | leave terminal mode (then move like any buffer) |
| `Space t h` | habit hints: off, hint, strict |
| `Space t w` `Space t S` `Space t n` | wrap, spell, relative numbers |
| `Space t d` `Space t v` `Space t i` | diagnostics, inline text (errors only / all), inlay hints |
| `Space t z` | zen mode |

## Help and learning (Space h)

| Key | Does |
|---|---|
| `Space h c` | this cheat sheet (`Space h T` for tmux) |
| `Space h v` / `Space h V` | VS Code to Neovim: search / read |
| `Space h l` / `Space h L` | current lesson / all lessons and your progress |
| `Space h n` / `Space h p` | lesson done, open the next / previous lesson |
| `Space h d` / `Space h r` | mark the lesson done / reset it (a fresh copy) |
| `Space h f` | the lesson's practice file (lessons 7b, 10 and 13) |
| `Space h h` | lost? back to the lesson, in one window |
| `Space h t` | `:Tutor` |
| `Space h i` | a tip |
| `Space h k` | search every keymap |
| `Space h C` | check: what works on this machine |
| `:help {topic}` · | Neovim's manual, e.g. `:help text-objects` |

## Commands

| Command | Does |
|---|---|
| `:Rihla` | list subcommands: learn, home, cheat, vscode, check, langs, install, habits, icons, sync |
| `:Rihla install python` | install the language server, formatter and debugger for a language now |
| `:Rihla icons nerd` | use Nerd Font icons (restart) |
| `:Lazy` / `:Mason` | plugins / tools (both read-only by habit: updates come from `rihla update`) |
| `:checkhealth rihla` | the same report as `Space h C` (`:Rihla check`) |
