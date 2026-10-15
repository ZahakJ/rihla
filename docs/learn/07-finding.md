# Lesson 7: Finding files and getting back

Week 3. 20 minutes. This lesson works on a whole project, not just this page;
`Space h h` always brings you back to this page.

**Goal:** open any file in a project in a second, switch between open files without the
mouse, and always be able to get back to where you were.

## Keys

| Key | Does |
|---|---|
| `Space f f` / `Ctrl-p` | find a file by fuzzy name |
| `Space f r` | recent files |
| `Space f g` | search text across the project (ripgrep) |
| `Space f b` | open buffers (files you have open) |
| `Ctrl-^` / `Space b a` | the alternate file: toggle between the last two |
| `[b` / `]b` | previous / next buffer (the tabs at the top) |
| `Ctrl-o` / `Ctrl-i` | back / forward through the jump list (works across files) |
| `Space f R` | reopen the last picker where you left it |

A **picker** is the search box these keys open. Inside one: type to filter,
`Ctrl-n` / `Ctrl-p` (or `Ctrl-j` / `Ctrl-k`) to move, `Enter` to open, `Esc` to close
it. `Ctrl-q` sends everything to the quickfix list (lesson 11), and `Ctrl-v` / `Ctrl-x`
open the file in a split (lesson 8).

## Why

The fuzzy finder is VS Code's Ctrl+P, and it matches the same way: `rlinit` finds
`rihla/lua/init.lua`. A buffer is an open file; the tabs along the top are buffers.
Unlike VS Code you do not need to close them: keep dozens open and jump with `Space f b`.

The real speed is in getting back. `Ctrl-^` flips between two files (a test and its
implementation, a header and its source). `Ctrl-o` walks back through every jump you
made, `gd` into a library included, so exploring code is never a one-way trip.

The project is the directory you started Neovim in. Start it at the root of the repo
(`cd project && nvim`), or change it with `:cd path`.

## Practice

You need a project. Use one of yours: type `:cd ~/path/to/project` and `Enter`. No
project handy? This makes the rihla repository the project (type it, then `Enter`):

```text
:exe 'cd' g:rihla_root
```

Every file opens in this same window, in place of this page. After each step, come
back here with `Space h h` (or `Ctrl-^`, which you are about to learn) and tick the box:
put the cursor on the space between the brackets and press `r` then `x`.

- [ ] `Space f f`, type 3 or 4 letters of a file name, `Enter`. Repeat for 5 files.
- [ ] Note how few letters it took. Try again with even fewer: the last letters of the name often work best.
- [ ] `Ctrl-^` ten times between the last two files.
- [ ] `[b` and `]b` to walk through all open buffers.
- [ ] `Space f b`, type part of a name, `Enter`.
- [ ] `Space f g`, search for a word you know is in the project (try `function`), open a match.
- [ ] `Ctrl-o` until you are back where you started; then `Ctrl-i` forward again.
- [ ] `Space f r` to see recent files across all projects.
- [ ] `Space b d` on three buffers you no longer need (it closes the file, not the window).
- [ ] Back here: `Space f r` and pick this page, or `Space h h`.

When all are ticked, `:cd -` and `Enter` returns to the previous directory.

## You are done when

- You never use the file tree to open a file whose name you know.
- `Ctrl-^` and `Ctrl-o` are reflexes.
- Having twenty buffers open does not bother you.

Then press `Space h n` for lesson 7b, the eight VS Code habits on one page.

> Tip: `Ctrl-^` toggles between the current and the previous file.

> Tip: in any picker, `Ctrl-q` sends the results to the quickfix list so you can work through them one by one.

> Tip: `Space f R` reopens the last picker with the same search, right where you left it.

> Tip: `Ctrl-o` walks back through your jumps, even across files; `Ctrl-i` walks forward again.
