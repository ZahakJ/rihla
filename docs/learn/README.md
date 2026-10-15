# Learning path

Six weeks, from "how do I quit" to macros and `:g`. Each lesson is short: a goal, the 5 to 10 keys that reach it, and practice right under each
explanation, on the same page. Fifteen to twenty minutes for the lesson, then a few
minutes a day of using the keys on real work.

## Start

In the terminal, type `rihla learn` and press Enter. (If it says "command not found",
open a new terminal window first.) Lesson 0 opens. Its first screen says how to quit,
how to come back, how to move and how to go to the next lesson; nothing else is needed
to begin.

## How a lesson looks

One page, in one window, like Vim's own tutor: you read a short part, then do it on the
text right under it, then scroll on (`j`, the arrow keys or the mouse wheel). Nothing
opens a second window unless a lesson asks you to, and the lessons that do (7b, 8)
say first how to get back to one window.

The bar at the top of the page shows the lesson, the key for the next one
(`Space h n`), how to quit (`Esc`, then `:q` and Enter) and the way back if you get lost
(`Esc` twice, then `Space h h`).

The page is your own copy, in `~/.local/state/nvim/rihla/lessons/`; the files in this
folder never change. It saves itself, so quitting never asks about it. Wreck it freely:
`Space h r` gives you a fresh one.

A few lessons need more than one page: a real code file (10 and 13: `Space h f` opens it
in the same window), a small project (7, 7b, 11, 12), or tmux (14 and 15). Each says exactly
what to type to get there, and `Space h h` always comes back to the lesson.

## The keys

| Key | Typed command | In the terminal | Does |
|---|---|---|---|
| `Space h l` | `:Rihla learn` | `rihla learn` | open your current lesson |
| `Space h n` | `:Rihla learn next` | `rihla learn next` | mark it done and open the next one |
| `Space h p` | `:Rihla learn prev` | `rihla learn prev` | the previous lesson |
| `Space h d` | `:Rihla learn done` | `rihla learn done` | mark it done, stay |
| `Space h L` | `:Rihla learn list` | `rihla learn list` | all lessons, with what you have done |
| `Space h r` | `:Rihla learn reset` | `rihla learn reset` | a fresh copy of the lesson |
| `Space h f` | `:Rihla learn file` | | the lesson's practice code file (7b, 10, 13) |
| `Space h h` | `:Rihla home` | | lost? back to the lesson, one window, normal mode |
| | `:Rihla learn 7` | `rihla learn 7` | jump to lesson 7 (`:Rihla learn 7b` for 7b) |
| `Space h i` | `:Rihla tip` | | a tip from the lessons you have reached |

`Space h n` means: press Space, let go, press h, let go, press n. Progress is kept in
`~/.local/state/nvim/rihla/learn.json`, so it survives quitting and updates.

If you prefer reading the lesson beside your own file, `:Rihla learn split` opens it on
the right of whatever you are editing. Nothing opens that way by itself.

While you learn, rihla's habit hints (`Space t h` to change) watch for slow patterns
such as pressing `j` ten times, and suggest the faster key in one line at the bottom.
They only ever name keys from lessons you have marked done, so they stay quiet in the
first lessons. Arrows and the mouse keep working. When a lesson says "turn on strict",
it means `:Rihla habits strict`, which stops a fifth `j` in a row from doing anything
until you use a count.

## The plan

| Week | Lesson | You learn |
|---|---|---|
| 1 | [00 Start here](00-start-here.md) | quit, come back, move, next lesson; then `:Tutor`, Neovim's own 30-minute interactive tutorial |
| 1 | [01 Modes, and staying alive](01-modes.md) | insert, normal, visual, command line; save, quit, undo |
| 1 | [02 Moving by words and lines](02-motions.md) | `w b e`, `0 ^ $`, `gg G`, counts and relative numbers |
| 1 | [03 The grammar: operator + motion](03-grammar.md) | `d c y` with any motion, `dd cc yy`, `p`, and `.` |
| 2 | [04 Text objects](04-textobjects.md) | `iw aw i" a( it ip`, and `if ac` from tree-sitter |
| 2 | [05 Jumping on a line](05-line-jumps.md) | `f t F T ; ,` and `%` |
| 2 | [06 Search, replace, and Vim's multi-cursor](06-search.md) | `/ ? n N * #`, `:s`, `cgn` + `.` |
| 3 | [07 Finding files and getting back](07-finding.md) | pickers, buffers, `Ctrl-^`, `Ctrl-o` |
| 3 | [07b Your VS Code day, in rihla](07b-vscode-habits.md) | the eight habits: `Ctrl-p`, `Space f g`, `Space r p`, ``Ctrl-\``, the breadcrumb and folds, `Space e`, numbered tabs, `co` / `ct` on merge conflicts |
| 3 | [08 Windows, splits and the file tree](08-windows.md) | `Ctrl-w`, `Ctrl-h/j/k/l`, `Space e` |
| 3 | [09 Registers and the clipboard](09-registers.md) | `"a`, `"0`, `"+`, `"_`, `Ctrl-r` in insert mode |
| 4 | [10 Code with LSP](10-lsp.md) | `K gd grr grn gra ]d`, completion, formatting |
| 4 | [11 The quickfix list](11-quickfix.md) | project-wide search and replace, `:cdo` |
| 4 | [12 Git in the editor](12-git.md) | hunks, staging, blame, lazygit / fugitive |
| 4 | [13 Debugging](13-debugging.md) | breakpoints, stepping, the REPL |
| 5 | [14 tmux: sessions, windows, panes](14-tmux-basics.md) | the prefix, splitting, moving, detaching |
| 5 | [15 tmux: copy mode and working with Neovim](15-tmux-workflow.md) | copy mode, a session per project, the editor and the shell side by side |
| 6 | [16 Marks and the jump list](16-marks.md) | `m`, `'`, `` ` ``, `g;`, `gi` |
| 6 | [17 Macros](17-macros.md) | `q`, `@`, `@@`, counts, fixing a macro |
| 6 | [18 Editing at scale: `:g` and `:normal`](18-global.md) | `:g/pat/cmd`, `:norm`, ranges |
| 6 | [19 Deliberate speed](19-speed.md) | the habits that make the difference, and how to keep improving |

If you are short on time: lessons 1 to 6, then 10 and 14. Come back for the rest.
