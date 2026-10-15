# Lesson 9: Registers and the clipboard

Week 3. 15 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** never lose something you yanked, keep several things on the clipboard at once,
and paste without clobbering.

## Keys

| Key | Does |
|---|---|
| `"ay` / `"ap` | yank into / paste from register `a` (any letter a to z) |
| `"Ay` | append to register `a` |
| `"0p` | paste the last **yank** (deletes do not overwrite it) |
| `"+y` / `"+p` | the system clipboard explicitly |
| `"_d` | delete into the black hole: nothing is overwritten |
| `Space p` (visual) | paste over a selection and keep what you had yanked |
| `Ctrl-r a` (insert mode) | insert register `a` while typing; `Ctrl-r +` the clipboard |
| `:reg` or `Space f "` | see what every register holds |

`"a` is two keys: the double quote, then the letter.

## Why

Every `d`, `c` and `y` puts text in the unnamed register, which `p` pastes. That is why
`dd` then `p` moves a line. It is also why yanking a word, deleting another one, then
pasting gives you the deleted one: the delete replaced it. The fix is `"0p`: register `0`
always has the last yank.

In rihla, `y` and `p` also use the system clipboard (`clipboard=unnamedplus`), so a yank in
Neovim pastes in your browser. Over SSH, with no clipboard tool on the server, the yank
travels back through the terminal (OSC 52), also through tmux. Your terminal has to allow
it; most modern ones do.

Named registers (`"a` to `"z`) are for when you need several things at once: gather
three snippets into `a`, `b`, `c`, then paste each where it goes. Macros (lesson 17) are
stored in the same registers.

## Practice

`:reg` and `Enter` shows what each register holds; `Enter` again (or `q`) closes the list.

### Exercise 1: the yank register

Yank the word KEEP with `yiw`. Then delete the word JUNK with `diw`. Now `p` pastes JUNK
(the delete replaced it). Undo, then paste with `"0p` instead.

```text
KEEP          JUNK          paste here ->
```

### Exercise 2: named registers

Yank each line into a register: `"ayy` on the first, `"byy` on the second, `"cyy` on
the third. Then on the ASSEMBLE line paste them in the order c, a, b with `"cp` `"ap` `"bp`.

```text
first line: apples
second line: bread
third line: cheese
ASSEMBLE:
```

### Exercise 3: paste over, keep the register

Yank the word "blue" with `yiw`. Then for each "red" below: `viw` then `Space p`
(rihla). The register still has "blue", so you can repeat. Try once with plain `p`
instead of `Space p` to see the difference.

```text
blue
red red red
```

### Exercise 4: insert-mode paste

Yank "rihla" with `yiw`. Go to the end of the next line with `A`, type a space, then
press `Ctrl-r` `0` to insert the yank without leaving insert mode. `Esc`.

```text
rihla
this setup is called
```

### Exercise 5: black hole

Yank "important" with `yiw`. Delete the next line with `"_dd`. Now `p` still pastes
"important".

```text
important
delete this line without losing the yank
```

## Away from this page

Yank something in Neovim, paste it in another application.

## You are done when

- You reach for `"0p` when `p` pastes the wrong thing.
- You use `Ctrl-r "` and `Ctrl-r 0` in insert mode and on the `:` command line.
- You have checked that yank goes to your system clipboard on each machine you use.

Then press `Space h n` for lesson 10.

> Tip: `"0p` pastes your last yank even after you have deleted other text since.

> Tip: `Ctrl-r` followed by a register name pastes it in insert mode and on the command line; `Ctrl-r Ctrl-w` on the command line inserts the word under the cursor.

> Tip: in visual mode, `Space p` pastes over the selection without losing what you yanked, so you can paste the same thing again.
