# Lesson 0: Start here

**To quit:** press `Esc`, then type `:q` and press `Enter`.
  If it asks "Save changes?", press `y` to keep them or `n` to throw them away.
  If it says `E37` ("No write since last change"), type `:q!` and `Enter`.

**To come back later:** in the terminal, type `rihla learn` and press `Enter`.
  If it says "rihla: command not found", close the terminal window, open a
  new one, and type it again.

**To move on this page:** `j` moves down a line, `k` moves up.
  The arrow keys and the mouse wheel work too.

**To go to the next lesson:** press `Space`, then `h`, then `n`,
  one key after the other (not all together).

**Lost?** Press `Esc` twice, then `Space` `h` `h`: you are back here, in one window.

The bar at the top always shows the next-lesson and quit keys. Read on: `j`.

## How keys are written

| Written | Means |
|---|---|
| `Space h n` | press Space, let go, press h, let go, press n |
| `Ctrl-d` | hold Ctrl and press d, like Ctrl+C for copy. Vim's help writes it `<C-d>` |
| `G` | a capital letter: hold Shift and press g |
| `:q Enter` | type a colon, then q, then press Enter. What you type after `:` shows at the very bottom |
| `Esc` | the Escape key, top left. It gets you out of almost anything. Pressing it too often never hurts |
| leader | Vim's word for the key that starts rihla's own shortcuts. Here it is `Space` |

The cheat sheet (`Space h c`, close it with `q`) starts with this table too.

## Two modes

Neovim has **modes**. Most of the time you are in **normal mode**: keys are
commands, so `j` moves down instead of typing a j. To type text you go into
**insert mode** (press `i`), and `Esc` brings you back. The bar at the bottom of
the screen says which mode you are in: NORMAL or INSERT.

That is the one big difference from VS Code. It feels odd for a day.

Two more words you will meet: a **buffer** is a file you have open, and a
**window** is a view of one on the screen. This lesson is one buffer in one window.

## Try it, right here

This page is your own copy. Nothing you do to it can break anything, and
`Space h r` gives you a fresh one.

1. Move down to the line with the stars below, using `j` (or the arrow key).
2. Press `x` a few times: each press deletes the character under the cursor.
3. Press `i`, type `hello`, press `Esc`. The bottom bar said INSERT while you typed.
4. Press `u` to undo, as many times as you like.

```text
***** delete some of these stars, then type something here:
```

## What is on the screen

- **The bar at the top**: which lesson this is, and its keys.
- **The numbers on the left**: how far each line is from the cursor (lesson 2 uses them).
- **The bar at the bottom**: the mode, the file, where the cursor is.
- **The last line**: messages, and what you type after `:`.

If the last line says "Press ENTER or type command to continue", press `Enter`.

## The lesson keys

| Key | Typed command | Does |
|---|---|---|
| `Space h n` | `:Rihla learn next` | mark this lesson done, open the next |
| `Space h p` | `:Rihla learn prev` | the previous lesson |
| `Space h L` | `:Rihla learn list` | all lessons, and which you have done (`q` closes the list) |
| `Space h r` | `:Rihla learn reset` | a fresh copy of this lesson |
| `Space h d` | `:Rihla learn done` | mark it done, stay here |
| `Space h h` | `:Rihla home` | lost? back to the lesson, one window |

In the terminal, `rihla learn next`, `rihla learn list` and `rihla learn reset`
do the same. Your progress is kept when you quit.

## Next: Neovim's own tutor

Neovim comes with an interactive tutorial, about 30 minutes. Everything in
rihla builds on it.

Type `:Tutor` and press `Enter`. It opens in this same window. It is a page you
edit, like this one: read a step, do what it says right there, move on.
`Space h h` brings you back to this page at any time.

The tutor uses these keys:

| Key | Does |
|---|---|
| `h j k l` | left, down, up, right (lesson 2 explains why you will soon use them less) |
| `i` | insert text before the cursor |
| `Esc` | back to normal mode |
| `x` | delete the character under the cursor |
| `:q!` then Enter | quit without saving (if you get lost: Esc, then this) |
| `u` | undo |

1. Do all of chapter 1 of the tutor in one sitting.
2. Do chapter 2 the next day: `:Tutor vim-02-beginner` and `Enter`.
3. When the tutor says "type :q! to quit", it means it: Neovim closes and you are
   in the terminal. Type `rihla learn` there to come back to this page.

## You are done when

- You have finished both chapters of `:Tutor`.
- You can open a file, change a word, save, and quit without looking anything up.

Then press `Space h n` for lesson 1.

> Tip: lost or stuck? Press Esc twice. You are back in normal mode and nothing you type will be inserted.

> Tip: `:Tutor` can be reopened any time. Doing chapter 1 once a week for the first month is a good warm-up.

> Tip: `Space h h` (or `:Rihla home`) closes extra windows and popups and puts you back on your lesson.
