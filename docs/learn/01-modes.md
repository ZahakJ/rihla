# Lesson 1: Modes, and staying alive

Week 1. 15 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** always know which mode you are in, get into insert mode the right way for the
job, and get out again without thinking.

## Keys

| Key | Does |
|---|---|
| `i` / `a` | insert before / after the cursor |
| `I` / `A` | insert at the start / end of the line |
| `o` / `O` | open a new line below / above and insert |
| `Esc` | back to normal mode |
| `v` / `V` | visual mode: select characters / whole lines |
| `:w` `:q` `:wq` `:q!` | save, quit, save and quit, quit and throw changes away |
| `u` / `Ctrl-r` | undo / redo |

## Why

In VS Code you are always typing. In Vim you spend most of your time in **normal mode**,
where keys are commands, and drop into **insert mode** only to type new text. The status
line at the bottom shows the mode on the left, coloured: mauve NORMAL, green INSERT,
blue VISUAL.

The six ways into insert mode exist so you never have to move first: `A` adds a
semicolon at the end of a line from anywhere in it; `O` opens a line above without
reaching for the arrow keys. Short visits to insert mode also make undo precise: each
visit is one undo step.

## Practice

### Exercise 1

Put the cursor anywhere on each line below and press `A`, type `;`, press `Esc`.
Then move down with `j` and repeat. (Try `.` instead of `A ; Esc` on the second line:
it repeats your last change.)

```text
let total = 0
let count = 10
let name = "rihla"
total = total + count
```

### Exercise 2

On each line press `I`, type `//` and a space, press `Esc`.

```text
this line should be a comment
so should this one
and this one
```

### Exercise 3

The list below skips numbers. On "one" press `o` and type "two", then `Esc`.
On "five" press `O` and type "four". Fill in the rest the same way.

```text
one
three
five
seven
```

### Exercise 4

Delete this whole paragraph however you like. `dd` (press `d` twice) deletes the whole
line the cursor is on; lesson 3 explains why it is `dd`.
Then press `u` until it is back. Then `Ctrl-r` once. Then `u` once more.

```text
The quick brown fox jumps over the lazy dog.
Pack my box with five dozen liquor jugs.
```

### Exercise 5

Save, quit and come back:

1. Type `:w` and `Enter`. This saves. (Lesson pages also save themselves, so
   quitting never loses what you did here.)
2. Type `:q` and `Enter`. Neovim closes; you are in the terminal.
3. Type `rihla learn` and `Enter`. You are back on this page, where you were.

## Away from this page

Make a mess on purpose in a scratch file, then `u` until it is gone, then
`Ctrl-r` to bring it back. Open one with `nvim scratch.txt` in the terminal.

## You are done when

- You reach for `A`, `I`, `o`, `O` instead of moving then pressing `i`.
- You press `Esc` as soon as you finish typing, every time.
- You can tell the mode from the status line without thinking about it.

Then press `Space h n` for lesson 2.

> Tip: `A` appends at the end of the line from anywhere in it. No need to press End first.

> Tip: leave insert mode as soon as you stop typing. Small insert visits make `u` undo exactly what you expect.

> Tip: `Ctrl-s` saves too, but `:w` works on every machine you will ever SSH into.
