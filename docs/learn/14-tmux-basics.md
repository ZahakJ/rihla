# Lesson 14: tmux: sessions, windows, panes

Week 5. 20 minutes. This one happens in tmux, around Neovim: the steps below take you
there and bring this page with you.

**Goal:** run everything for a project in one tmux session (editor, shell, server, logs),
switch between them with the keyboard, and leave it running when you disconnect.

## Keys

Every tmux key starts with the **prefix**: `Ctrl-Space` in rihla (the default `Ctrl-b`
also works). Press it, let go, then press the key. `prefix d` means: `Ctrl-Space`,
let go, `d`. The bar at the top shows PREFIX while tmux waits for that key.

| Key | Does |
|---|---|
| `tmux new -s work` | (shell) start a session called "work" |
| `prefix d` | detach: the session keeps running, you are back in the plain terminal |
| `tmux a -t work` / `tmux ls` | (shell) attach to it again / list sessions |
| `prefix \|` / `prefix -` | split the pane right / below (keeps the current directory) |
| `Ctrl-h/j/k/l` | move between panes, and between Neovim splits inside them |
| `prefix z` | zoom this pane to full size; again to restore |
| `prefix x` | close this pane (asks first) |
| `prefix c` / `prefix 1..9` | new window / go to window 1..9 |
| `prefix ,` | rename the window |
| `prefix s` | pick a session (and its windows) from a tree |
| `prefix h` | a menu of the common actions (`q` or `Esc` closes it) |
| `prefix H` | the rihla tmux cheat sheet (`q` closes it); `prefix ?` lists every key |
| `exit` | (shell) closes this pane; the last one closes the session |

## Why

A **session** is a workspace that survives closing the terminal or losing the SSH
connection: detach at the end of the day, `tmux a` the next morning, everything is where
you left it. A **window** is a full-screen tab (shown in the bar at the top). A **pane**
is a split inside a window.

The common shape: one window per task, Neovim in the main pane, a shell in a small pane
below (`prefix -`), `Ctrl-j` / `Ctrl-k` between them. The `Ctrl-h/j/k/l` keys do not care
whether the neighbour is a tmux pane or a Neovim split. That is VS Code's integrated
terminal, except it is a real terminal that keeps running when the editor closes.

Windows are numbered from 1 so `prefix 1` is the leftmost. The default tmux keys still
work (`prefix "` and `prefix %` split too), so any tmux tutorial applies.

## Practice

First, take this page into tmux:

1. Quit Neovim: `Esc`, then `:q` and `Enter`.
2. In the terminal: `tmux new -s practice` and `Enter`. A bar appears at the top: you
   are in tmux. Its right end reminds you of the menu key and how to leave (in a narrow
   terminal, inside a git repository, the branch takes that place).
3. Type `rihla learn` and `Enter`: this page again, now inside tmux.

Then tick each box as you go (cursor between the brackets, `r` `x`):

- [ ] `prefix |` (split right). A shell opens on the right; this page stays on the left.
- [ ] `Ctrl-h` back to this page, `Ctrl-l` to the shell.
- [ ] In the shell pane, `prefix -` (split below). `Ctrl-h`, `Ctrl-l`, `Ctrl-j`, `Ctrl-k` visit each pane.
- [ ] Here in Neovim, `Space |`. Now `Ctrl-h/l` crosses both Neovim splits and tmux panes. `Ctrl-w o` closes the extra Neovim split.
- [ ] `prefix z` on this pane (zoom), `prefix z` again.
- [ ] `prefix c` for a new window; `prefix ,` and name it `server`.
- [ ] `prefix 1` and `prefix 2` to switch windows. End on window 1, with this page.
- [ ] `prefix s`: the session tree. `Enter` to pick, `q` to leave it.
- [ ] `prefix h`: the menu. `Esc` closes it.
- [ ] `prefix H`: the cheat sheet. `q` to close it.
- [ ] `prefix d` to detach: you are in the plain terminal, and tmux keeps running. Then `tmux ls`, then `tmux a -t practice`: everything is still there.
- [ ] In the extra shell panes, `exit` closes each one.

When you are finished: `prefix d`, then `tmux kill-session -t practice` closes the whole
session (this page is saved). `rihla learn` opens it again.

## You are done when

- Your work lives in named sessions, one per project, and you detach instead of closing.
- Moving between editor and shell is `Ctrl-j` / `Ctrl-k`, never the mouse.
- You can find any tmux key with `prefix H` or `prefix ?`.

Then press `Space h n` for lesson 15.

> Tip: detach with `prefix d` instead of closing the terminal. `tmux a` brings everything back, even after an SSH disconnect.

> Tip: `prefix z` zooms a pane to full screen and back; the bar shows ZOOM while zoomed.

> Tip: `Ctrl-h/j/k/l` move between tmux panes and Neovim splits with the same keys.
