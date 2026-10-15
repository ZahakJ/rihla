# Lesson 17: Macros

Week 6. 20 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** record an edit once and replay it on as many places as needed. This replaces
most of what you would write a script or use multi-cursor for.

## Keys

| Key | Does |
|---|---|
| `qa` | start recording into register `a` (the status line says "recording a macro in @a") |
| `q` | stop recording |
| `@a` | play macro `a` |
| `@@` | play the last played macro again |
| `5@a` | play it 5 times |
| `:'<,'>norm @a` | play it once on every line of the selection |
| `qA` | append more keys to macro `a` |
| `"ap` then edit then `"ayy` | fix a macro by editing its text |

If you ever see "recording" at the bottom without meaning to: you pressed `q` and a
letter. Press `q` once to stop. Nothing else happened.

## Why

`.` repeats one change; a macro repeats a whole sequence: move, change, move, change.
The trick is to record a macro that works from a predictable start and ends where the
next run should start. That usually means:

1. Start at the beginning of the line (`0` or `^`).
2. Move with searches and text objects, not counts of `l` (`f,` not `lllll`), so the
   macro works on lines of different lengths.
3. Finish by moving to the next line (`j`), so `@@` or a count continues.

If a step fails (a search finds nothing), the macro stops, so `100@a` is safe on 40 lines:
it stops when it runs out. On this page, use counts that fit (`4@a`), since the lines
after an exercise belong to the next one.

A macro is just text in a register. `"ap` pastes it, you can edit it like any text,
and `"ayy` (or `"ay$`) puts it back.

## Practice

### Exercise 1

Turn each name into `"name",` (quoted, with a comma). On "alpha" type:
`qa` `0` `i"` `Esc` `A",` `Esc` `j` `q`. Then `4@a` for the rest (or `@a` then `@@ @@ @@`).

```text
alpha
beta
gamma
delta
epsilon
```

### Exercise 2

Turn each CSV line into a call: `user("ana", 34, "lisbon")`. Record into `b` on the
first line, starting with `0` and ending with `j`. Hints: `0` `i` `user("` `Esc`, then
`f,` `i"` `Esc`, and so on (`f,` `;` `t,` `a` are your friends). Then select the
remaining lines with `V` and `jjj`, and run `:'<,'>norm @b`.

```text
ana,34,lisbon
bilal,29,cairo
chen,41,taipei
dara,25,dublin
eitan,38,haifa
```

### Exercise 3

A macro that breaks. On the first line below record `qc` `0` `f:` `r=` `j` `q`.
Run `3@c`. It stops on the line with no colon: a failed `f` stops the macro.
Now fix the data or the macro: `"cp` pastes the macro as text, edit it, then `0"cy$`
stores it back.

```text
key: value
size: 10
broken line without a colon
mode: fast
```

### Exercise 4

Not everything needs a macro. Number the lines below 1. 2. 3. 4.: select them with
`V3j`, then `:'<,'>norm I0. ` (a space after the dot). Then `gv` to reselect, and
`g Ctrl-a`: the zeros become 1, 2, 3, 4.

```text
first item
second item
third item
fourth item
```

## Away from this page

Next time you catch yourself repeating the same edit on many lines, record it.

## You are done when

- You record macros that start with `0` and end with `j`, and play them with counts.
- You use `:'<,'>norm @a` to run a macro over a selection.
- You have fixed a macro by pasting, editing and yanking it back.

Then press `Space h n` for lesson 18.

> Tip: start a macro with `0` and end it with `j`, then `100@a` runs it on every line until one fails.

> Tip: inside a macro, move with `f`, `t`, `/` and text objects instead of `l`, so it works on lines of different lengths.

> Tip: `:'<,'>norm @a` runs a macro once on every selected line.
