"""Lesson 13 practice: debugging. Your own copy: wreck it freely (Space h r resets it).

Space h h goes back to the lesson page, in one window (it also closes the debug panels).

1. Put the cursor on the line marked BREAK HERE and press F9 (or Space d b).
2. Press F5 (or Space d c) and choose "Run this file". The first time, debugpy is
   installed in the background; press F5 again once it says it is ready.
3. When it stops: F10 steps over, F11 steps into step(), Shift-F11 (or Space d O) steps out.
4. Space d e on "total" shows its value. Space d r opens a REPL: type total * 2, Enter.
5. Shift-F5 (or Space d t) stops.
"""


def step(i: int, total: int) -> int:
    doubled = i * 2
    return total + doubled


def run(n: int) -> int:
    total = 0
    for i in range(n):
        total = step(i, total)  # BREAK HERE
    return total


if __name__ == "__main__":
    print("result:", run(5))
