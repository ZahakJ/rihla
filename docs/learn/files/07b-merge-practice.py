"""Practice file for lesson 7b: two merge conflicts, as git leaves them.

The first: keep ours (co). The second: take theirs (ct).
"""


def greeting(name: str) -> str:
<<<<<<< HEAD
    return f"Hello, {name}!"
=======
    return f"Hi {name}"
>>>>>>> feature/short-greeting


def farewell(name: str) -> str:
    # say goodbye
<<<<<<< HEAD
    return "Bye."
=======
    return f"Goodbye, {name}. See you soon."
>>>>>>> feature/short-greeting
