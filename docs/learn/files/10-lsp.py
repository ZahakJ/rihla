"""Lesson 10 practice: LSP. Your own copy: wreck it freely (Space h r resets it).

Space h h goes back to the lesson page (press Esc first if you are typing).
Wait for "basedpyright ready for python" at the bottom the first time (a few seconds).
If nothing happens, Space l L (:Rihla langs) shows what is missing.
"""

import math


def calc_area(radius: float) -> float:
    """Area of a circle with the given radius."""
    return math.pi * radius**2


def describe(radius: float) -> str:
    # Exercise 1: K on "sqrt" below shows its documentation.
    side = math.sqrt(calc_area(radius))
    return f"circle of radius {radius}, equal-area square side {side:.2f}"


def main() -> None:
    # Exercise 2: gd on describe (go to definition), then Ctrl-o to come back.
    print(describe(2.0))
    # Exercise 3: grn on calc_area anywhere, rename it to area. Both uses change.
    print(calc_area(3.0))
    # Exercise 4: the next line has a type error. ]d jumps to it, Ctrl-w d shows it.
    print(calc_area("three"))
    # Exercise 5: gra on the unknown name below offers fixes, if the server has one.
    print(sqrtt(4))
    # Exercise 6: on a new line below, type "math." and pick something from the menu.


if __name__ == "__main__":
    main()
