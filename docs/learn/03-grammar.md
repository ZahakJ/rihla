# Lesson 3: The grammar: operator + motion

Week 1. 20 minutes. The most important lesson.
Your own copy: `Space h r` gives you a fresh one.

**Goal:** see editing as sentences: an operator (a verb) followed by a motion (where it
applies). Once this clicks, every motion you learn is also a delete, a change and a copy.

## Keys

| Key | Does |
|---|---|
| `d{motion}` | delete over the motion: `dw` a word, `d$` to line end, `d}` to the paragraph end |
| `c{motion}` | change: delete, then insert mode. `cw`, `c$`, `cb` |
| `y{motion}` | yank (copy): `yw`, `y$`, `y}` |
| `dd` `cc` `yy` | doubling the operator means the whole line |
| `D` `C` | shorthand for `d$` and `c$` |
| `p` / `P` | paste after / before the cursor (a yanked line goes below / above) |
| `.` | repeat the last change |
| `>` `<` `=` `gU` `gu` `gc` | more operators: indent, outdent, re-indent, upper, lower, comment |

`{motion}` stands for any motion from lesson 2: `w`, `$`, `}`, `3j`...

## Why

`d3w` reads "delete three words". `c$` reads "change to end of line". `y}` reads "copy to
end of paragraph". There is no special key for each combination: the operator and the
motion compose, so learning one new motion gives you three new edits.

`.` repeats the last change, operator and motion together. Change a word with `cw`, type
the new one, `Esc`; now `w.` changes the next one. Most of "Vim is fast" is `.`.

Deleted text is not lost: it is in a register (lesson 9), so `dd` then `p` moves a line,
and `xp` swaps two characters.

## Practice

### Exercise 1

Each line says what to do. Do it with one operator + motion; the keys are in brackets.

```text
delete the next two words: one two three four             (cursor on "one", d2w)
change to the end of line: this part should become NEW   (cursor on "this", C or c$)
yank this line and paste it twice below it               (yy p p)
delete everything from here to the end of the line      (D)
uppercase this word: shout                               (cursor on "shout", gUw)
indent this line and the next one                        (>j)
  this one too
```

### Exercise 2

Change every "foo" to "bar". Do the first with `cw` bar `Esc`, then for each next one
move to it (`w` or `j`) and press `.` to repeat. (Lesson 6 adds a faster way: `/foo`
Enter.)

```text
foo = foo + 1
print(foo)
return foo
```

### Exercise 3

Put these lines in order 1 to 5 using `dd` and `p` (or `P`).

```text
3. third
1. first
5. fifth
2. second
4. fourth
```

### Exercise 4

Sentences. Without trying first, say what each does. Then try them on the paragraph
below (`u` undoes each one).

```text
d}     y$     c0     >}     gUw     dG     yG
```

```text
The paragraph to try them on starts here,
continues on this line,
and ends on this one.
```

`dG` deletes to the end of this page; `u` brings it all back.

### Exercise 5

Remove every "very ". Do the first with `dw` on it, then move to the next one with `w`
(or a count) and press `.` each time:

```text
this is very very simple and very very fast and very clear
```

## Away from this page

Turn three of your daily edits into sentences out loud: "change inside...", "delete
to...". It feels silly for a day and then it is automatic.

## You are done when

- You use `cw` / `c$` / `dd` / `yy` instead of selecting and typing over.
- You reach for `.` whenever you are about to repeat an edit.
- You can say what `d}`, `y$`, `>j` and `gUw` do without trying them.

Then press `Space h n` for lesson 4.

> Tip: operators compose with every motion. Learn a motion, and you have also learned a delete, a change and a copy.

> Tip: `.` repeats the last change. Make the change once with `cw`, then `n.` or `j.` to repeat it elsewhere.

> Tip: `ddp` swaps a line with the one below it; `xp` swaps two characters.

> Tip: `C` changes to the end of the line, `D` deletes to it. They are `c$` and `d$` with fewer keys.
