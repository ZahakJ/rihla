# Lesson 18: Editing at scale: `:g` and `:normal`

Week 6. 20 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** apply an edit to every line that matches a pattern, in one command.

## Keys

| Command | Does |
|---|---|
| `:g/pat/d` | delete every line matching `pat` |
| `:v/pat/d` (or `:g!`) | delete every line **not** matching |
| `:g/pat/norm A;` | run normal-mode keys on every matching line |
| `:g/pat/m0` | move matching lines to the top (in reverse order) |
| `:g/pat/t$` | copy matching lines to the end of the file |
| `:'<,'>norm .` | repeat the last change on every selected line |
| `:%norm @a` | run macro `a` on every line |
| `:sort` / `:sort u` / `:sort n` | sort lines / remove duplicates / numeric |
| `:5,20d` `:.,+3y` `:.,$s/a/b/` | ranges: lines 5 to 20, this line and the next 3, here to the end |

## Why

`:g` (global) is "for every line matching this pattern, run this command". With `:norm`
the command can be any normal-mode keys, so anything you can do by hand on one line, you
can do on all matching lines at once: `:g/TODO/norm gcc` comments out every TODO line,
`:g/^$/d` removes blank lines, `:g/console.log/d` cleans debug output.

`:norm` on a range does the same without the pattern: select lines, `:norm A;` appends a
semicolon to each. Combined with `.` (`:'<,'>norm .`) it repeats your last change on every
line of the selection.

`:g` works in every vi since the 1970s.

## Practice

A plain `:g` works on the whole file, and the file here is this whole page, explanations
included. So each exercise first selects its own lines: put the cursor on one of them and
press `vip` (the lines between two blank lines are one paragraph), then type the command.
The `'<,'>` in front appears by itself when you press `:` with lines selected. `u` undoes
a whole `:g` at once.

### Exercise 1

Delete every line containing "debug": `vip`, then `:g/debug/d` and `Enter`.

```text

start()
debug("entering loop")
process()
debug("x is", x)
finish()
debug("done")

```

### Exercise 2

Append `;` to every line starting with let: `vip`, then `:g/^let/norm A;`

```text

let a = 1
let b = 2
print(a)
let c = a + b

```

### Exercise 3

Keep only the ERROR lines in this block: `vip`, then `:v/ERROR/d`

```text

INFO  starting
ERROR disk full
INFO  retrying
WARN  slow
ERROR timeout
INFO  done

```

### Exercise 4

Sort these and remove duplicates: `vip`, then `:sort u`

```text

pear
apple
fig
apple
banana
pear

```

### Exercise 5

On the first line below, change "old" to "new" with `ciw` (cursor on old), `Esc`.
Then select the other three lines (`j`, `V`, `jj`) and run `:'<,'>norm .`
(`:norm` starts with the cursor in column 1 of each line, which is on "old".)

```text

old one
old two
old three
old four

```

### Exercise 6

Comment out every TODO line. Plain text has no comment style, so first type
`:setlocal commentstring=#\ %s` and `Enter`; then `vip` and `:g/TODO/norm gcc`.
(In code files the right comment style is already set.)

```text

work()
# fine
TODO: remove this
more_work()
TODO: and this

```

## You are done when

- Cleaning a file of a certain kind of line is one `:g` command, not a search-and-delete loop.
- You use `:norm` on a selection instead of editing line by line.

Then press `Space h n` for lesson 19.

> Tip: `:g/pattern/d` deletes every matching line; `:v/pattern/d` keeps only the matching ones.

> Tip: `:g/pattern/norm <keys>` runs any normal-mode keys on each matching line, for example `:g/TODO/norm gcc`.

> Tip: select lines and `:norm .` repeats your last change on each of them.
