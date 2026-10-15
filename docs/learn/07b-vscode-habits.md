# Lesson 7b: Your VS Code day, in rihla

Week 3. 25 minutes. This lesson uses two practice files and a terminal;
`Space h h` always brings you back to this page, in one window.

**Goal:** the eight things most of a VS Code day is made of, each on one key: open a
file by name, search the project, replace across files, a terminal, a clear view of the
file, the file tree, tabs, and merge conflicts.

## Keys

| VS Code | rihla | Does |
|---|---|---|
| Ctrl+P | `Ctrl-p` or `Space f f` | open a file by name; open and recent files first |
| Ctrl+Shift+F | `Space f g` | search every file, regex on, as you type |
| Ctrl+Shift+H | `Space r p` | replace across files, every change shown first |
| Ctrl+` | ``Ctrl-\`` / `Space t t` | terminal at the bottom / floating; `Space t s` runs a line in it |
| breadcrumbs, outline, folding | the bar on top, `Space c s`, `za` | where you are, the file's structure, fold a block |
| Explorer | `Space e` / `Space E` | the file tree / show this file in it |
| tabs | `Alt-1..9`, `Space b b` | go to tab N / pick an open file |
| merge conflicts | `]x`, `co` `ct` `cb` `c0` | next conflict; keep ours / theirs / both / neither |

Lost at any point (a split, a popup, a terminal that takes every key)? `Esc` twice, then
`Space h h`: this page, one window. `Ctrl-w o` keeps only the window you are in.

## Why

The pickers (the search boxes `Ctrl-p` and `Space f g` open) all work the same way: type
to filter, `Ctrl-n` / `Ctrl-p` or the arrows to move, `Enter` to open, `Esc` to close,
and the line along their bottom edge names their other keys.

## Practice

First make this lesson's folder the project. Type this, then `Enter`:

```text
:exe 'cd' expand('%:p:h')
```

It holds your lesson pages and the two practice files, `07b-inventory.py` and
`07b-merge-practice.py`. After each step, come back with `Space h h` and tick the box:
cursor between the brackets, `r` then `x`.

### 1. Open a file by name

- [ ] `Ctrl-p`, type `inv`, `Enter`. You are in 07b-inventory.py. `Space h h` back.
- [ ] `Ctrl-p` again: the file you just opened is at the top. Recent files come first.

### 2. Search the project

- [ ] `Space f g`, type `def \w+` (a regex: every function). The preview shows each hit.
- [ ] Press `Alt-w` (whole word) and `Alt-c` (match case): the title shows `ab|` and `Aa`.
      Press them again to turn them off.
- [ ] Type ` -- -g *.py` after the search: only Python files. `Alt-s` asks for a
      folder or glob instead.
- [ ] `Ctrl-q`: every hit goes to the quickfix list. `]q` and `[q` walk it,
      `Space x q` closes it. (Lesson 11 does more with this list.)

### 3. Replace across files

- [ ] Open 07b-inventory.py, put the cursor on a `quantity` and press `Space r p`: the
      Search line is filled in. `Esc`, `j`, `A`, type `qty`: the Replace line. Then `j`,
      `A`, type `*.py`: the Files Filter, so only Python files. Each change shows before
      and after; nothing is written yet.
- [ ] `Esc`, then `\r` (backslash, then r) writes them all. `Space r u` puts every file
      back. `:q` closes the replace window.
- [ ] In one file only: put the cursor on `item` in 07b-inventory.py, `Space r r`, type
      `entry`, `Enter`, then `y` or `n` at each match (`q` stops). `u` undoes. It
      matches the exact case (`\C` in the command), so the class `Item` stays; delete
      the `\C` to match any case, as VS Code does by default.

### 4. A terminal

- [ ] ``Ctrl-\``: a terminal at the bottom, in this folder. Type `ls` and `Enter`.
- [ ] ``Ctrl-\`` hides it and comes back to the file; ``Ctrl-\`` again shows it, with
      `ls` still there: it keeps running while hidden. `Space t t` is a floating one.
- [ ] Put the cursor on the line below and press `Space t s`: it runs in the terminal.

```text
echo "sent from the lesson page"
```

- [ ] In the terminal, `Esc Esc` stops typing into it so you can scroll and copy;
      `i` types into it again.

### 5. A clear view of the file

Open 07b-inventory.py (`Ctrl-p`, `inv`, `Enter`).

- [ ] Move into `low_stock`. The bar above the file reads folder > file > Store >
      low_stock: where you are.
- [ ] `Space c s`: the outline on the right (it needs the Python language server, which
      rihla installs the first time a Python file opens; otherwise it says so). `Enter`
      jumps, `Esc` closes.
- [ ] On `def add`, `za` folds it to one line; `za` opens it. `zM` folds all, `zR` opens all.
- [ ] Errors show as red text at the end of their line; warnings only as a sign in the
      gutter. `Space x x` lists them, `K` explains the one under the cursor.

### 6. The file tree

- [ ] `Space e` opens it, `Space e` from the file goes into it, `Space e` in the tree
      closes it. `Space E` shows the current file in it.
- [ ] In the tree: `a`, type `scratch.txt`, `Enter` makes a file. On it, `r` renames,
      `d` deletes (it asks). `?` lists every key.
- [ ] `Ctrl-l` and `Ctrl-h` move between the tree and the file, like tmux panes.

### 7. Tabs

The open files are tabs along the top, numbered.

- [ ] Open both practice files (`Ctrl-p` twice), then `Alt-1`, `Alt-2`, `Alt-3`.
      (`Space 1`, `Space 2` do the same where Alt is taken.)
- [ ] `Space b b`: pick an open file by name. `Space b p` pins a tab to the left,
      `Space b d` closes one, `Space b o` all the others except pinned ones. The
      numbers always count from the left, so pinned tabs become 1, 2, ...

### 8. Merge conflicts

- [ ] Open 07b-merge-practice.py. Each conflict is coloured: ours (current) green,
      theirs (incoming) blue, with the keys on the line above it.
- [ ] `]x` jumps to the first conflict. `co` keeps ours. `]x`, then `ct` takes theirs.
      `u` undoes a choice; `cb` keeps both, `c0` neither.
- [ ] In a real repository: `Space g x` lists every conflict in the quickfix list, and
      `Space g m` opens the 3-way merge view (ours and theirs on top, the result below,
      `q` closes it). `Space g h` shows the history of the file.
- [ ] Back here: `Space h h`. Then `Space h r` later gives you fresh practice files.

When you are done, `:cd -` and `Enter` returns to the previous folder.

## You are done when

- `Ctrl-p` and `Space f g` are how you get anywhere in a project.
- You reach for ``Ctrl-\`` instead of another terminal window.
- A merge conflict is `]x` and two letters, not a hunt for `<<<<<<<`.

Then press `Space h n` for lesson 8.

> Tip: in `Space f g`, `text -- -g *.ts` searches only TypeScript files; `Alt-s` asks for a folder or a glob.

> Tip: `Space t s` sends the current line, or the selected lines, to the terminal and runs them.

> Tip: in a file with merge conflicts, `]x` then `co` keeps ours and `ct` takes theirs; `u` undoes.

> Tip: `Space r u` puts back every file the last project-wide replace (`Space r p`) changed.
