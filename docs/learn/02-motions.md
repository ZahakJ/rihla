# Lesson 2: Moving by words and lines

Week 1. 20 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** move to where you want in two or three keystrokes, not ten. hjkl is not the
point; words, line ends and counts are.

## Keys

| Key | Does |
|---|---|
| `w` / `b` | next word start / previous word start |
| `e` | end of the word |
| `W` `B` `E` | the same, but a WORD is anything between spaces (`foo.bar(x)` is one WORD) |
| `0` / `^` / `$` | line start / first non-blank character / line end |
| `gg` / `G` / `42G` | first line / last line / line 42 |
| `}` / `{` | next / previous blank line (paragraph) |
| `Ctrl-d` / `Ctrl-u` | half a page down / up |
| `7j` `12k` | a count: move 7 lines down, 12 up |

## Why

Holding `j` (or the down arrow) is the slowest way to get anywhere. The numbers in the
left gutter are **relative**: the line 7 below you shows `7`. So `7j` lands exactly
there, every time, with no overshoot. The line you are on shows its real number.

Words are the next unit up. `w` and `b` move a word at a time, and the capital versions
skip punctuation. `}` jumps paragraph by paragraph, which in code usually means block by
block.

Almost every key in this lesson takes a count: `3w`, `2}`, `5e`.

Once you mark this lesson done, the habit hints start: if you press `j` six times in a
row, a line at the bottom suggests the count. That is the habit this lesson builds.

## Practice

Count your keystrokes.

### Exercise 1: words

Put the cursor on the S of START. Reach the E of END using only `w` (count them),
then do it again using a count (e.g. `6w`). Then go back with `b`.

```text
START the quick brown fox jumps over the lazy END dog
```

### Exercise 2: WORDs

Here `w` stops at every dot and bracket. Use `W` instead: fewer presses.

```text
START config.window.size(width=80, height=24).apply() END
```

### Exercise 3: line ends

From anywhere on the line, go to the end (`$`), the first non-blank (`^`), and
column zero (`0`). Notice `^` and `0` differ here:

```text
        indented_line_with_leading_spaces = True
```

### Exercise 4: counts and the gutter

The target line below says TARGET. Put the cursor on this line, read TARGET's
number in the gutter on the left, and jump there with that number and `j`.

```text
.
.
.
.
.
.
.
.
.
TARGET: you got here with one count. Now go back with the right number and k.
```

### Exercise 5: paragraphs

Starting on "block one", visit each block with `}` and come back with `{`.

```text
block one
  some code
  more code

block two
  some code

block three
  some code
  more code
  even more code
```

### Exercise 6: the whole page

`gg` goes to the top of this page, `G` to the bottom, `3G` to line 3.
Try them, and come back here each time with `Ctrl-o`.

## Away from this page

1. Read the relative number of a line you want, type it, then `j` or `k`. Do this for
   ten different lines.
2. In a real file of yours, move through it with only `}`, `{`, `Ctrl-d`, `Ctrl-u` and
   counts for five minutes.
3. Turn on strict mode for a day: `:Rihla habits strict`. A fifth `j` in a row does
   nothing until you use a count. `:Rihla habits hint` turns it back.

## You are done when

- You read the gutter and type `8j` without thinking about it.
- You use `w` / `b` / `e` and `0` / `$` instead of `h` / `l` for anything more than two characters.
- Five-plus repeated `j` presses (the hint) are rare in a normal working day.

Then press `Space h n` for lesson 3.

> Tip: the gutter numbers are relative. The line marked 7 is 7j away. No counting needed.

> Tip: `}` and `{` jump between blank lines, which in code is roughly function to function.

> Tip: `^` goes to the first non-blank character of the line, which is usually what you want instead of `0`.

> Tip: `Ctrl-o` takes you back after a big jump like `G` or `gg`.
