# Lesson 16: Marks and the jump list

Week 6. 15 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** bookmark places and get back to them instantly, inside a file and across files.

## Keys

| Key | Does |
|---|---|
| `ma` | set mark `a` here (lowercase: this file only) |
| `` `a `` / `'a` | jump to mark `a` exactly / to its line |
| `mA` | an uppercase mark works across files ("the config file", "the test") |
| `` `. `` / `g;` / `g,` | the last change / walk back / forward through changes |
| `gi` | go back to where you last typed and enter insert mode |
| `''` | back to the line before the last jump |
| `Ctrl-o` / `Ctrl-i` | back / forward in the jump list |
| `:marks` / `Space f m` | list marks |
| `d'a` `` y`a `` | marks are motions: delete to the line of mark `a`, yank to the mark |

## Why

Lowercase marks are for "I will be back here in a minute" inside a file: `ma`, go look
at something, `` `a ``. Uppercase marks are bookmarks that survive closing Neovim: put
`mC` in a config file you edit often and `` `C `` opens it from anywhere.

You often do not need to set marks at all: Vim keeps them for you. `` `. `` is where you
last changed something, `gi` resumes typing where you stopped, `Ctrl-o` walks back
through every jump (searches, `G`, `gd`, `%`...).

## Practice

### Exercise 1

Set a mark on each SPOT: `ma` on SPOT A, `mb` on SPOT B, `mc` on SPOT C.
Then jump between them in any order with `` `a `` `` `b `` `` `c `` (backtick) and
`'a` `'b` `'c` (quote). What is the difference? (backtick: exact column; quote: start
of the line)

```text
SPOT A is here, in the middle of the line.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
              SPOT B is indented.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
.
SPOT C is further down.
```

### Exercise 2

Change the word EDIT-ME below to anything. Then `gg` to the top.
Now `` `. `` jumps back to the change, and `gi` puts you back in insert mode right
there. `Esc`.

```text
EDIT-ME
```

### Exercise 3

Go to SPOT A with `` `a ``. Press `G` to go to the bottom. Press `''` (two single
quotes) to go back, and `''` again to bounce.

### Exercise 4

On SPOT B press `mb` again. Go to SPOT A. Now `d'b` deletes every line from SPOT A down
to SPOT B. Undo with `u`.

### Exercise 5

`mP` here, then open any other file (`Space f r`). `` `P `` brings you back.

## Away from this page

Set `mC` in a file you edit often, close it, and come back with `` `C `` from another file.

## You are done when

- You use `` `. `` and `gi` instead of scrolling back to your last edit.
- You keep one or two uppercase marks for files you visit all the time.
- `Ctrl-o` is how you get back after any jump.

Then press `Space h n` for lesson 17.

> Tip: `gi` takes you back to where you last typed and puts you in insert mode, ready to continue.

> Tip: uppercase marks (`mA`) jump across files and survive restarts. Good for files you visit daily.

> Tip: `` `. `` jumps to the last change; `g;` keeps walking back through earlier changes.
