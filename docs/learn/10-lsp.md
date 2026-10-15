# Lesson 10: Code with LSP

Week 4. 20 minutes. This lesson needs a real Python file; the steps below open it in
this same window, and `Space h h` brings you back to this page.

**Goal:** read and change code the way you did in VS Code (go to definition, references,
rename, quick fix, completion) with keys that work in any Neovim 0.11+.

## Keys

Neovim maps most of these itself, in every buffer with a language server. They work on
a bare Neovim with LSP set up, so they are the ones to learn.

| Key | Does |
|---|---|
| `K` | documentation for the thing under the cursor (`K` again to enter the window, `q` to close it) |
| `gd` / `F12` | go to definition (`Ctrl-o` comes back) |
| `grr` | references (into the quickfix list) |
| `grn` / `F2` | rename everywhere |
| `gra` / `Space l a` | code action: quick fixes, imports, refactors |
| `gri` / `grt` | implementation / type definition |
| `gO` / `Space f s` | symbols in this file |
| `]d` / `[d` | next / previous diagnostic; `Ctrl-w d` shows the full message |
| `Space l f` | format the file (or the selection) |
| `Ctrl-Space` (insert) | completion menu; `Enter` accepts, `Ctrl-n` / `Ctrl-p` move, `Ctrl-e` closes |

## Why

A language server is the same engine VS Code uses (Pylance's core is pyright; rust-analyzer,
gopls, clangd are the same programs). rihla installs it the first time you open a file
of that language: a line at the bottom says "installing ... in the background", and a
few seconds later "ready". `Space l L` shows what each language has.

`gd` and `Ctrl-o` together let you dive into code and come back up, the same way as
lesson 7. References and diagnostics go into the quickfix list, which lesson 11 turns
into a tool for working through many places in a row.

Completion appears as you type. Snippets (`for`, `def`, `fn`...) come from the same
collection VS Code uses; after accepting one, `Tab` jumps to the next field.

Format on save is **off** (so you do not reformat a whole shared file by accident). Turn it
on with `Space t f`, or for one file with `Space t F`.

## Practice

1. Open the practice file: type `:Rihla learn file` and press `Enter` (or `Space h f`).
   It opens `10-lsp.py` in place of this page. The exercises are written in it as
   comments. To come back here at any time: `Space h h`.
2. Wait for "basedpyright ready" (or "pyright", "pylsp") at the bottom, a few seconds
   the first time. If nothing comes, `Space l L` says what is missing. Python's language
   servers need Python 3 with its `venv` module (on Debian/Ubuntu the `python3-venv`
   package); without it, do the drills in a Lua file instead: `lua_ls` needs nothing extra.
3. `K` on `math.sqrt` to read its documentation. `q` closes it.
4. `gd` on a function call, `Ctrl-o` back. Three times.
5. `grn` on `calc_area` to rename it to `area`; check every call changed.
6. `]d` to the first diagnostic, `Ctrl-w d` to read it, `gra` to see the fixes.
7. Type `import ` on a new line and pick from the completion menu.
8. `Space h h` to come back to this page.

## Away from this page

In your own code: use `gd`, `grr` and `grn` instead of searching, for a day.

## You are done when

- `K`, `gd`, `grr`, `grn`, `gra`, `]d` are in your fingers.
- You check `Space l L` (or `:checkhealth rihla`) first when a language "does nothing".
- You know format on save is off and how to run the formatter yourself.

Then press `Space h n` for lesson 11.

> Tip: `K` on anything shows its documentation. Press `K` again to move into the window and scroll it.

> Tip: `gd` then `Ctrl-o` is a round trip: dive into a definition, come back to exactly where you were.

> Tip: `grn` renames a symbol across the whole project, through the language server. It is safer than search and replace.

> Tip: `Space l L` shows which languages have a server, a formatter and a debugger installed, and what is missing.
