# Lesson 15: tmux: copy mode, and working with Neovim

Week 5. 20 minutes. Do this one with this page open inside tmux (lesson 14 shows how:
`tmux new -s practice`, then `rihla learn`).

**Goal:** scroll back and copy terminal output with the keyboard, keep one session per
project, and split work between Neovim and the shell in the way that fits each task.

## Keys

| Key | Does |
|---|---|
| `prefix [` | copy mode: scroll and search the pane's history (`q` leaves) |
| `v` / `y` (in copy mode) | start a selection / copy it (to the system clipboard; over SSH too) |
| `Ctrl-v` (in copy mode) | rectangle selection |
| `/` `?` `n` `N` (in copy mode) | search the history, as in Vim |
| mouse wheel / drag | scrolls / selects and copies (mouse is on) |
| `prefix ]` | paste the last tmux copy |
| `prefix (` / `prefix )` | previous / next session |
| `prefix $` | rename the session |
| `prefix Ctrl-l` | clear the screen (`Ctrl-l` alone moves to the right pane) |
| `prefix r` | reload the tmux config |

## Why

Copy mode is Vim inside the terminal's scrollback: the same `hjkl`, `w`, `/`, `v`, `y`.
Copying a stack trace from a test run is `prefix [`, `?Error`, `v`, a few `j`, `y`. The copy
lands on your system clipboard, via OSC 52 when you are on a server, so you can paste it in
your browser or back into Neovim. The bar shows COPY while you are in copy mode, and `q`
leaves it.

When to use which:

- **Neovim's terminal** (``Ctrl-\``): quick one-off commands while editing, output you will
  copy into a buffer. ``Ctrl-\`` again hides it.
- **A tmux pane**: anything long-running or that you want to keep (servers, test
  watchers, logs, a REPL), and anything you want to survive closing Neovim.
- **A tmux window**: a separate task in the same project (a second repo, a database shell).
- **A tmux session**: a separate project. `prefix s` switches between them.

A good daily shape: `tmux new -s project` in the repo, `nvim` in window 1 with a shell
pane below it, a server or test watcher in window 2.

## Practice

With this page in a tmux pane, open a shell next to it: `prefix -` (below). `Ctrl-k`
comes back to this page, `Ctrl-j` goes to the shell. Tick each box as you go.

- [ ] In the shell: `seq 1 500` to fill the scrollback.
- [ ] `prefix [`, then `?` and `250` `Enter`: you are on line 250 of the output.
- [ ] `v`, then `10j`, then `y`. The selection is copied and copy mode ends.
- [ ] `Ctrl-k` to this page, then `p` on the empty line below: the numbers 250 to 260 appear.
- [ ] Back in the shell, `prefix [`, then `Ctrl-v` and select a rectangle (a column of digits), `y`, paste it below too.
- [ ] Scroll with the mouse wheel; drag to select (it copies on release).
- [ ] `tmux new -s other -d` in the shell, then `prefix )` and `prefix (` to switch sessions.
- [ ] `prefix $` to rename the current session.
- [ ] `prefix Ctrl-l` to clear the shell pane.
- [ ] Clean up: `tmux kill-session -t other`, and `exit` in the shell pane.

```text
paste here:

```

## Away from this page

1. Run a test or server in a pane, edit in another, and switch with `Ctrl-j` / `Ctrl-k`
   for half an hour of real work.
2. Over SSH (if you have a server): yank in Neovim or tmux on the server, paste locally.

## You are done when

- You copy from terminal output with copy mode instead of the mouse.
- Each project you are working on is its own session.
- You know when to use a Neovim terminal and when a tmux pane.

Then press `Space h n` for lesson 16.

> Tip: in tmux copy mode, `?` searches backwards through the scrollback, which is where the error you want usually is.

> Tip: one tmux session per project; `prefix s` shows them all as a tree.

> Tip: `prefix Ctrl-l` clears the screen, since `Ctrl-l` on its own moves to the pane on the right.
