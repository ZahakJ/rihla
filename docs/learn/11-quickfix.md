# Lesson 11: The quickfix list

Week 4. 20 minutes. This lesson makes a small throwaway project and works on it;
`Space h h` brings you back to this page, in one window, at any time.

**Goal:** turn any list of places (search results, errors, references) into a to-do
list you can step through, and change all of them at once. This is VS Code's search
panel and problems panel in one.

## Keys

| Key | Does |
|---|---|
| `Ctrl-q` (in a picker) | send all results to the quickfix list |
| `:copen` / `:cclose` / `Space x q` | open / close / toggle the list window |
| `]q` / `[q` | next / previous entry (`:cnext` / `:cprev`) |
| `Enter` (in the list) | jump to that entry |
| `:cdo {cmd}` | run a command on every entry, e.g. `:cdo s/old/new/ \| update` |
| `:cfdo {cmd}` | run it once per file in the list |
| `:vimgrep /pat/ **` / `:grep pat` | fill the list from a search (rihla's `:grep` uses ripgrep) |
| `Space x X` | all diagnostics into the list |
| `:colder` / `:cnewer` | go back to the previous list, and forward again |

The list opens as a window at the bottom of the screen (lesson 8): `Ctrl-j` / `Ctrl-k`
move between it and the code, `Space x q` or `:cclose` closes it.

## Why

The quickfix list is Vim's universal "list of locations". Anything can fill it: grep,
the compiler (`:make`), the language server (`grr` puts references there), diagnostics.
Once there, the same keys work through it.

Project-wide search and replace is three steps:

1. `Space f g` and search for the old text (or `:grep old`).
2. `Ctrl-q` to send the results to the list.
3. `:cdo s/old/new/g | update`: substitute on every line in the list and save each file.

Add `c` (`s/old/new/gc`) to confirm each one. Because you saw the list first, nothing is
replaced that you did not see. `u` in a file undoes it there.

For "fix every error": `Space x X`, then `]q`, fix, `]q`, fix. The list stays put while
you work.

## Practice

Doing a replace across a real project is the point, so make a throwaway one. Type each
line below, then `Enter`. (A shortcut: on a line, `yy` then `@"` runs it, as if typed.)

```text
:call mkdir(stdpath('state') . '/rihla/qf-practice', 'p')
:exe 'cd' stdpath('state') . '/rihla/qf-practice'
:call writefile(['color = "red"', 'print(color)', '# TODO: rename color'], 'a.py')
:call writefile(['let color = 1', 'echo color', '" TODO: rename color'], 'b.vim')
:call writefile(['color: red', 'size: big', '# TODO: rename color'], 'c.yaml')
```

Now tick each box (cursor on the space between the brackets, `r` `x`). Coming back to
this page between steps: `Space h h` (it also closes the list window; `:copen` brings
it back).

- [ ] `:grep TODO` then `:copen`. Three entries, one per file.
- [ ] `]q` and `[q` to walk them. `Ctrl-w p` jumps between the list and the code.
- [ ] `Space f g`, type `color`, then `Ctrl-q`. The list now has every "color".
- [ ] `:cdo s/color/colour/gc | update` and answer `y` for each. Every file is changed and saved.
- [ ] `:cfdo %s/colour/color/g | update` puts it back (once per file this time).
- [ ] `:colder` shows the TODO list again; `:cnewer` returns.
- [ ] `Space x q` to close the list.
- [ ] `grr` on a function in a code file of yours: the references open in the list.
- [ ] `:cd -` to go back where you were. The folder stays in `~/.local/state/nvim/rihla/qf-practice` until you delete it.

## You are done when

- You do project-wide replacements with `Ctrl-q` + `:cdo` and trust them.
- `]q` / `[q` is how you work through search results and errors.
- You know that `grr`, `:grep`, and `Space x X` all feed the same list.

Then press `Space h n` for lesson 12.

> Tip: project-wide replace is `Space f g`, `Ctrl-q`, then `:cdo s/old/new/g | update`. Add `c` to confirm each one.

> Tip: `]q` and `[q` step through the quickfix list from anywhere, without opening it.

> Tip: `:colder` brings back the previous quickfix list, so a new search never loses the old results.
