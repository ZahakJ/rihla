# Lesson 13: Debugging

Week 4. 20 minutes. This lesson needs a real Python file; the steps below open it in
this same window, and `Space h h` brings you back to this page.

**Goal:** set breakpoints, step, and inspect variables in Neovim with the same function
keys as VS Code.

## Keys

| Key | Does |
|---|---|
| `F9` / `Space d b` | toggle a breakpoint on this line |
| `F5` / `Space d c` | start debugging (pick a configuration), or continue |
| `F10` / `F11` / `Shift-F11` | step over / into / out |
| `Shift-F5` / `Space d t` | stop |
| `Space d C` | run to the cursor |
| `Space d B` | conditional breakpoint (`x > 10`) |
| `Space d L` | log point: prints a message, does not stop |
| `Space d e` | evaluate the expression under the cursor (or the selection) |
| `Space d r` | the debug REPL: type expressions while stopped |
| `Space d u` | show / hide the panels |

## Why

Debuggers talk the Debug Adapter Protocol, the same as in VS Code; nvim-dap is the client
and the panels (variables, watches, call stack, breakpoints, console) open by themselves
around the code when a session starts. `Space d u` hides them; `Space h h` closes them
and brings you back to this page.

The first `F5` in a language installs its debugger if needed: debugpy for Python,
codelldb for C, C++ and Rust (or the system's gdb 14+), delve for Go. That can take a
minute once. If a language has no debugger set up, `F5` says so and how to add one.

A configuration is what VS Code keeps in `launch.json`. rihla ships "run this file" style
defaults; nvim-dap also reads a project's `.vscode/launch.json`, and you can add your own
in `~/.config/rihla/local.lua` (see `lua/rihla/dap.lua` for the shape).

Some terminals send odd codes for Shift + function keys; the `Space d` keys always work.

## Practice

1. Open the practice file: type `:Rihla learn file` and press `Enter` (or `Space h f`).
   It opens `13-debugging.py` in place of this page.
2. `F9` on the line marked BREAK HERE, `F5`, pick "Run this file". debugpy needs
   Python's `venv` module (on Debian/Ubuntu the `python3-venv` package); `rihla check`
   in the terminal (or `Space h C`) says whether you have it.
3. When it stops: look at the variables panel, `F10` a few times, `F11` into `step()`.
   `Ctrl-h/j/k/l` move between the panels and the code (lesson 8).
4. `Space d e` on an expression, `Space d r` and type `total * 2` in the REPL.
5. Add a conditional breakpoint `i == 3`, restart with `Space d l` (run last).
6. `Shift-F5` (or `Space d t`) to stop. `Space h h` to come back to this page.

## You are done when

- You debug with breakpoints instead of print statements when the bug is not obvious.
- You can start, step, inspect and stop without looking at this page.

Then press `Space h n` for lesson 14.

> Tip: `F5`, `F9`, `F10`, `F11` work as in VS Code. If a Shift + F-key does nothing in your terminal, use `Space d` and the letter.

> Tip: `Space d L` adds a log point: it prints a message with `{expressions}` in braces, without stopping the program.
