# Lesson 6: Search, replace, and Vim's multi-cursor

Week 2. 20 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** find anything in a file in one motion, replace with confidence, and make the
same change in many places without a multi-cursor.

## Keys

| Key | Does |
|---|---|
| `/text` `Enter` / `?text` | search forward / backward |
| `n` / `N` | next / previous match (rihla keeps it centred) |
| `*` / `#` | search for the word under the cursor, forward / backward |
| `:%s/old/new/g` | replace everywhere in the file (`c` at the end asks each time) |
| `:s/old/new/` | replace on this line only, or in a selection |
| `gn` | select the next match (a text object for "the search result") |
| `cgn` then `.` | change the next match; `.` changes the one after, `n` skips one |
| `&` | repeat the last `:s` on this line |

`Esc` clears the highlighted matches.

## Why

Search is a motion. `d/foo` deletes up to "foo"; `y?def` copies back to the last "def".
It is often the fastest way to anywhere on the screen: look, type three letters, Enter.

`:%s` previews live as you type: a small list of every affected line appears at the
bottom while you type, and goes away when you press `Enter` or `Esc`. Search is
case-insensitive unless you type a capital (`smartcase`).

VS Code's Ctrl+D (add next occurrence) becomes `*` (search this word), `cgn` (change the
match), type, `Esc`, then `.` for each next one. You see each change happen, `n` skips
one, and `.` keeps working after you scroll away.

`:%s//new/g` with an empty pattern reuses the last search, so `*` then `:%s//new/g` renames
every occurrence of the word under the cursor in the file. (For a real rename across
files, use the LSP rename in lesson 10.)

## Practice

`%` in `:%s` means "the whole file", and here the file is this whole page, words in
the explanations included. So the replacements below work on a selection instead.

### Exercise 1

From the top of the paragraph below, reach each word in CAPITALS with `/` and its first
three letters (e.g. `/ora` Enter). Use `n` if the first match is not the one you want.

```text
The river ran past the ORANGE grove and under the old stone BRIDGE, where children
fished for SILVER minnows every summer. Beyond the bridge the road climbed toward the
MONASTERY, its walls pale in the evening LIGHT.
```

### Exercise 2

Rename the variable tmp to buffer. Put the cursor on the first tmp, press `*` (it
searches the whole word), then `cgn`, type buffer, `Esc`. Now press `.` for each next
one. "tmpdir" is a different word, so `*` does not match it. But the tmp inside
"/var/tmp" IS a whole word and does match: when the cursor lands there, press `n` to
skip it instead of `.`

```text
tmp = read_input()
tmp = tmp.strip()
tmpdir = "/var/tmp"
if not tmp:
    tmp = default
write_output(tmp)
```

### Exercise 3

Undo exercise 2 (`u` until it is back), then do it with substitute instead. Put the
cursor on one of the code lines in exercise 2, select them with `vip` (lesson 4), then
type the line below and press `Enter`. The `'<,'>` in front ("the selected lines")
appears by itself when you press `:`. Answer `y` or `n` at each match.

```text
:s/\<tmp\>/buffer/gc
```

### Exercise 4

Delete from the start of the next line up to the word "keep" with `d/keep` Enter.

```text
delete all of these words and keep the rest of the line
```

### Exercise 5

Select the three cat lines below with `V` and `jj`, then replace only inside them with
`:s/cat/dog/g` (the `'<,'>` range appears by itself when you press `:`).

```text
cat cat cat
cat cat
cat
This cat line is outside the selection and must stay a cat.
```

## Away from this page

Today: every time you would scroll looking for something, `/` it instead.

## You are done when

- `/` is your default way to move to anything you can see more than a few lines away.
- `*` `cgn` `.` is your Ctrl+D.
- You write `:%s` with `g` and `c` flags without looking them up.

Then press `Space h n` for lesson 7.

> Tip: `*` then `cgn`, type the new word, `Esc`, then `.` `.` `.` is Vim's Ctrl+D. Press `n` to skip one.

> Tip: `:%s//new/g` with an empty pattern reuses your last search, so `*` then `:%s//new/g` replaces the word under the cursor everywhere.

> Tip: search is a motion: `d/foo` deletes everything up to "foo".

> Tip: `\<word\>` in a pattern matches whole words only, which is what `*` searches for.
