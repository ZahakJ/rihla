# Lesson 5: Jumping on a line

Week 2. 15 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** get to any character on the current line in two keys.

## Keys

| Key | Does |
|---|---|
| `f{c}` | jump forward **to** the next `c` on this line (`{c}`: any character you type) |
| `t{c}` | jump forward **till** just before the next `c` |
| `F{c}` / `T{c}` | the same, backwards |
| `;` / `,` | repeat the last f/t/F/T forward / backward |
| `%` | jump to the matching bracket: `(` `)`, `[` `]`, `{` `}` |
| `dt)` `ct,` `yf;` | with an operator: delete till `)`, change till `,`, copy through `;` |

## Why

Within a line, `w` and `b` are often still too many presses. Look at where you want to
go, pick the character there (or next to it), and `f` it. If there is an earlier copy of
that character, `;` hops to the next one.

`t` is the one you use with operators: `ct,` changes everything up to the comma and
leaves the comma alone. `dt)` empties the rest of an argument list. These are the edits
VS Code makes you do with shift-and-arrows.

`%` on a bracket jumps to its partner. `d%` deletes a whole bracketed expression;
`v%` selects it.

## Practice

Start each exercise at the start of the line (press `0`).

### Exercise 1

Reach the character above each `^` with `f` and that character, using `;` when there is
an earlier copy of the same character. Two or three keys each.

```text
result = transform(data, key="value", strict=True) + offset * 2
                   ^          ^                  ^         ^
```

### Exercise 2

Change only the second argument to 99 with: `f,` then `w`, then `ct,` 99 `Esc`.
Then delete the third argument with: `f,` `;` then `dt)` (and tidy the comma with `x`).

```text
configure(width, 42, height, depth)
```

### Exercise 3

Put the cursor on the first `(` and press `%` to jump to its partner. Press `%` again to
come back. Then on the `[` press `d%` to delete the whole list.

```text
compute(alpha(beta(1, 2)), [3, 4, 5], {"key": (6, 7)})
```

### Exercise 4

Backwards: press `$` to go to the end, then `F(` to the last opening bracket.
`;` repeats in the same direction (further back), `,` goes the other way (forwards again).

```text
outer(middle(inner(value)))
```

### Exercise 5

Delete from the start of the line up to (not including) END with `dtE`. It works because
the first capital E on the line is in END; `dte` (lowercase) would stop at the e in
"here". `f` and `t` are case-sensitive.

```text
start here, then remove all of this text up to END and keep END
```

## Away from this page

All day: when you are about to press `l` or `w` four times, use `f` instead.

## You are done when

- You use `f`/`t` without deciding to: the eyes land on a character and the fingers follow.
- `ct{c}` and `dt{c}` are your normal way to change part of a line.
- You use `;` instead of repeating `f{c}`.

Then press `Space h n` for lesson 6.

> Tip: `f(` then `;` hops from one opening bracket to the next on the line.

> Tip: `ct,` changes up to the next comma and keeps the comma. Perfect for function arguments.

> Tip: `%` jumps between matching brackets; `d%` deletes everything between them, brackets included.
