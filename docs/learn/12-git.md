# Lesson 12: Git in the editor

Week 4. 20 minutes. This lesson makes a throwaway git repository and works in it;
`Space h h` brings you back to this page, in one window, at any time.

**Goal:** see what changed while you edit, stage exactly the hunks you mean to, read
blame and history, and commit, without switching to another window.

## Keys

| Key | Does |
|---|---|
| (the gutter) | `│` added or changed lines, `_` deleted lines |
| `]h` / `[h` | next / previous changed hunk |
| `Space g p` | preview the hunk (what it was before) |
| `Space g a` / `Space g r` | stage / reset (discard) this hunk; in visual mode, only the selected lines |
| `Space g b` / `Space g B` | blame this line / the whole file |
| `Space g d` | diff this file against the index |
| `Space g g` | lazygit, full screen (or fugitive's `:Git` if lazygit is not installed) |
| `Space g s` / `Space g c` | `:Git` status / commit (fugitive) |
| `Space g L` | history of this file in the quickfix list |
| `ih` | text object: the hunk under the cursor (`vih`, `dih`) |

In `:Git` (fugitive's status window): `s` stage, `u` unstage, `=` show the diff inline,
`cc` commit, `dd` diff split, `g?` all keys, `q` closes it. In lazygit: `?` shows its
keys, `space` stages, `c` commits, `P` pushes, `q` quits.

## Why

VS Code's Source Control panel is two things: per-line markers while you edit, and a
staging UI. Here the markers come from gitsigns (gutter, `]h`, hunk actions), and the
staging UI is lazygit when it is installed (rihla's installer brings it) or fugitive,
which needs nothing but git.

Staging hunk by hunk from the buffer (`Space g a`) is the habit worth building: commits
come out small and on topic, because you choose each change as you read it.

## Practice

Make a throwaway repository: type each line, then `Enter`. The last one opens
`list.txt` in place of this page; `Space h h` comes back here.

```text
:call mkdir(stdpath('state') . '/rihla/git-practice', 'p')
:exe 'cd' stdpath('state') . '/rihla/git-practice'
:!git init -q && printf 'one\ntwo\nthree\nfour\nfive\nsix\nseven\neight\n' > list.txt && git add . && git -c user.name=practice -c user.email= commit -qm start
:e list.txt
```

Tick each box as you go (cursor between the brackets, `r` `x`; this page is not in
that repository).

- [ ] In list.txt, change "two" to "TWO" and delete "six". Signs appear in the gutter.
- [ ] `]h` and `[h` to jump between the two hunks.
- [ ] `Space g p` on each to preview the change.
- [ ] `Space g a` on the first hunk to stage it. Its sign changes.
- [ ] `Space g r` on the second to discard it ("six" comes back).
- [ ] `Space g s` for fugitive's status, in a window at the top: the staged change is listed. `=` shows it inline.
- [ ] In the status window, `cc` to commit, write a message, `:wq`. `q` closes the status window.
- [ ] Change three lines, then select just one of them with `V` and stage it with `Space g a`.
- [ ] `Space g g`: lazygit if installed (`q` to quit it), otherwise `:Git` again.
- [ ] `Space g b` on a line to see its blame.
- [ ] `:cd -` to go back, and `Space h h` to come back to this page.

## Away from this page

1. Blame a line in a real repo, then `Space g L` to see the file's history.
2. Commit something with `Space g c` (fugitive) and something with lazygit.

## You are done when

- You review your own changes with `]h` and `Space g p` before committing.
- You stage partial changes with `Space g a` on a hunk or a selection.
- You know where to look when lazygit is not installed on a machine (`:Git`).

Then press `Space h n` for lesson 13.

> Tip: `]h` and `[h` jump between changed hunks; `Space g p` shows what each one replaced.

> Tip: stage only part of a hunk by selecting the lines first, then `Space g a`.

> Tip: `Space g b` shows who changed the line under the cursor, when, and in which commit.
