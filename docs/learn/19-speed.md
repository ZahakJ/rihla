# Lesson 19: Deliberate speed

Week 6, and after. Ongoing. The timed course at the end of this page is your own copy:
`Space h r` gives you a fresh one each time you run it.

**Goal:** keep getting faster after the lessons end, by noticing slow spots and fixing
them one at a time.

## The habits that make the difference

| Instead of | Do |
|---|---|
| `jjjjjj` | `6j` (read the gutter), `}`, `Ctrl-d`, or `/text` |
| `llllll` / `wwww` | `f{char}`, `t{char}`, `;` |
| selecting with `v` and many moves | a text object: `ci"`, `dap`, `yif` |
| retyping the same edit | `.` (and `cgn` + `.` for scattered matches) |
| the same edit on many lines | a macro, `:g/pat/norm ...`, or `:'<,'>norm .` |
| scrolling to find your last edit | `` `. ``, `gi`, `g;` |
| the file tree to open a known file | `Space f f`, `Ctrl-^`, `Space f b` |
| search, then open, then search again | `Space f g` then `Ctrl-q` and `]q` |
| staying in insert mode and arrowing around | `Esc`, move, re-enter with `i a I A o O` |
| reaching for the mouse | it works, but each time ask which key would have done it |

## How to keep improving

1. **Turn strict mode on** for a week: `:Rihla habits strict` (or `Space t h` twice).
   Repeated `hjkl` stop working after four presses and the arrow keys only show a hint.
   It is annoying for two days and then the counts and jumps are habits. To keep it,
   put `vim.g.rihla_habits = "strict"` in `~/.config/rihla/local.lua`.
2. **One key a week.** Pick one thing from the table above or from `:help` (`:help
   text-objects`, `:help motion.txt` are worth reading once) and use it on purpose for a week.
   Help opens in a window above this one; `:q` closes it.
3. **Notice repetition.** When you do the same thing three times, stop and ask whether
   `.`, a macro, `:g`, or a text object would do it. Usually one does.
4. **Read the hints.** Each habit hint names the lesson that covers the faster key, and
   only keys from lessons you have marked done. `:Rihla habits` shows which hints you got
   most this session.
5. **Keep a scratch file** for practising a new trick before using it on real work.
6. **Re-do a lesson** whose "done when" you are no longer sure of. Lessons 2 to 6 are
   worth a second pass after a month. `Space h L` lists them; `Space h r` on a lesson
   gives you a fresh page.

## Practice: a timed course

Each task names a target number of keystrokes in brackets; a key with a count counts as
one. Note your time for the whole course, and the keys you used. Do it once now and
again at the end of each week; the times should drop.

```text
1. [4] Go to the last colour in task 8 (hint: / and its first two letters).

2. [4] Change the text inside the quotes to "done":
       status = "pending review by the team"

3. [3] Delete this whole paragraph, wherever the cursor is in it:
       the paragraph to delete starts here
       and it continues on this line
       and ends here

4. [6] Rename every "val" to "value" below, skipping the one in "interval":
       val = 1
       interval = val * 2
       print(val)

5. [5] Swap the two lines below:
       second
       first

6. [7] Wrap the word WRAP in parentheses using the surround keys (ysiw then a bracket):
       please WRAP this word

7. [8] Delete every line that contains "noise":
       keep 1
       noise
       keep 2
       more noise here
       keep 3

8. [12] Turn these into a quoted list with a macro (one record, then a count):
       red
       green
       blue
       cyan

9. [4] Jump back to the place of your last edit, and continue typing there.

10. [2] Toggle between this page and the previously open file, twice.
```

End of the course. Note your time.

## You are done when

There is no end. A good sign: you watch someone use VS Code and keep wanting to say
"you could have just pressed...".

`Space h L` shows all lessons, done or not.

> Tip: strict mode (`:Rihla habits strict`) stops repeated hjkl after four presses until you use a count. One week of it builds the habit.

> Tip: when you do the same thing three times, stop and ask whether `.`, a macro, `:g` or a text object would do it.

> Tip: `:help text-objects` and `:help motion.txt` are worth reading once, slowly, with a practice file open.
