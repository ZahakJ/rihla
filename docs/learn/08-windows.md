# Lesson 8: Windows, splits and the file tree

Week 3. 15 minutes.

**Goal:** lay out the screen the way the task needs (code and test side by side, a
reference file below) and move around it without the mouse.

## First: how to get back to one window

This lesson splits the screen on purpose. Three ways back, all safe (no file is closed,
nothing is lost):

| Key | Does |
|---|---|
| `Ctrl-w o` | keep only the window the cursor is in; close the others (`:only` Enter) |
| `Ctrl-w c` | close the window the cursor is in (`:close` Enter) |
| `Space h h` | back to this lesson, in one window, whatever happened |

`Ctrl-w o` means: hold Ctrl and press w, let go, then press o. Try `Ctrl-w o` now:
nothing happens, because there is only one window. That is the point.

Opening a lesson (`Space h n` at the end of this one, or `Space h l`) also goes back to
one window. Your files stay open: `Space f b` lists them.

## Keys

| Key | Does |
|---|---|
| `Space \|` / `Space -` | split right / below (the same keys split panes in tmux) |
| `Ctrl-w v` / `Ctrl-w s` | the plain-Vim way to do the same |
| `Ctrl-h` `Ctrl-j` `Ctrl-k` `Ctrl-l` | move to the window on the left / below / above / right, and into tmux panes |
| `Ctrl-w c` / `Ctrl-w o` | close this window / close all the others |
| `Space w m` | maximise this window; again to restore |
| `Ctrl-w =` | make all windows the same size |
| `Ctrl-arrow keys` | resize |
| `Space e` / `Space E` | file tree / reveal the current file in it |

In the file tree: `Enter` opens, `a` creates (end the name with `/` for a folder), `d`
deletes, `r` renames, `c` / `x` / `p` copy, cut, paste, `H` shows hidden files, `?`
lists all keys, `q` closes.

## Why

A window is a view onto a buffer; several windows can show the same file at different
places (handy for long files: `Ctrl-w v`, then scroll one of them). Closing a window does
not close the file.

The `Ctrl-h/j/k/l` keys are shared with tmux (lesson 14): when the next window over is a
tmux pane instead of a Neovim split, the same key goes there. One set of keys for
everything on the screen.

The file tree is there for when you do not know the name of what you want, and for
creating, moving and renaming files. When you know the name, `Space f f` is faster.

## Practice

Tick each box as you go: cursor on the space between the brackets, then `r` `x`.
If the screen gets confusing at any point, `Ctrl-w o` or `Space h h`.

- [ ] `Space |` to split right. Both windows show this page. `Ctrl-l` and `Ctrl-h` to move between the two.
- [ ] `Space -` to split the right one down. Visit all three with `Ctrl-h/j/k/l`.
- [ ] `Ctrl-w =` to even them out. `Ctrl-Right` a few times to widen one.
- [ ] `Space w m` to maximise the current one, `Space w m` again to restore.
- [ ] `Ctrl-w o` to close all but this one.
- [ ] `Ctrl-w v` and `Ctrl-w s`: the same splits, plain-Vim keys. `Ctrl-w c` to close each.
- [ ] Two views of this page: `Ctrl-w v`, then `G` in one of them. Both show the same buffer; type in one and watch the other. `Ctrl-w o`.
- [ ] Open a file in a split from a picker: `Space f f`, pick a file, `Ctrl-v` instead of `Enter`. `Ctrl-w c` closes that split again.
- [ ] `Space e` to open the tree on the left. Move with `j` / `k`, open a folder with `Enter`. `Ctrl-l` goes back to this page.
- [ ] In the tree: `a`, type `rihla-practice/`, `Enter` (a folder). On it, `a`, `notes.txt`, `Enter` (a file).
- [ ] `r` on notes.txt to rename it to `todo.txt`.
- [ ] `d` on the folder to delete it (answer y).
- [ ] `q` to close the tree. `Space E` to open it at this page; `q` again.

Where was the tree pointing? At the current directory (`:pwd` and `Enter` shows it).
This page itself lives in `~/.local/state/nvim/rihla/lessons/`.

## Away from this page

1. Open a file and its test side by side (`Space |`, then `Space f f` in the new window).
2. Spend a day keeping one split open beside your main window and moving with `Ctrl-h` / `Ctrl-l`.

## You are done when

- You split, move and close windows without thinking about which keys.
- You use `Space w m` to focus on one window and come back.
- You use the tree for file operations, not for opening files you can name.

Then press `Space h n` for lesson 9.

> Tip: `Space |` and `Space -` split windows in Neovim; prefix then `|` and `-` split panes in tmux. Same shapes, same keys.

> Tip: `Ctrl-w o` closes every other window. `Space w m` does the same but can be undone.

> Tip: in the file tree, `a` creates a file; a name ending in `/` creates a folder.
