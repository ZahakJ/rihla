# Lesson 4: Text objects

Week 2. 20 minutes. Your own copy: `Space h r` gives you a fresh one.

**Goal:** stop selecting text by hand. Name the thing you want (a word, the inside of
quotes, a function) and act on all of it at once, from anywhere inside it.

## Keys

After an operator (`d`, `c`, `y`, `v`...), `i` means *inner* and `a` means *around*:

| Key | Object |
|---|---|
| `iw` / `aw` | word / word plus the space after it |
| `i"` `a"` `i'` `` i` `` | inside / around quotes |
| `i(` `i[` `i{` `i<` | inside brackets (`ib` = `i(`, `iB` = `i{`) |
| `it` / `at` | inside / around an HTML or XML tag |
| `ip` / `ap` | paragraph |
| `if` / `af` | function body / whole function (tree-sitter) |
| `ic` / `ac` | class (tree-sitter) |
| `io` / `ao` | if-statement or loop (tree-sitter) |
| `ih` | the git change (hunk) under the cursor |

Examples: `ciw` change this word, `di(` empty the parentheses, `ya"` copy the quoted string
with its quotes, `vaf` select the whole function, `dap` delete the paragraph.

## Why

Motions say "from here to there", so the cursor position matters. Text objects say
"this thing", so it does not: `ci"` works anywhere inside the string, and rihla's text
objects even look ahead, so `ci"` on a line before the string jumps to it.

This replaces most mouse selection. Combined with `.`, `ci"` + new text + `Esc`
then `.` on the next string is a two-key edit.

`if` / `ac` / `io` need a tree-sitter parser for the language. `:Rihla langs` shows which
languages have one ("syntax:tree-sitter"); on a machine with no C compiler they may not,
and exercises 3 and 5 then say so in one line at the bottom. The rest works everywhere.

## Practice

The code below is Python, so the tree-sitter objects (`if`/`af`, `ic`/`ac`, `io`/`ao`)
have something to work on.

### Exercise 1

Change the text inside each string with `ci"` (cursor anywhere on the line), type
something new, `Esc`.

```python
greeting = "hello world"
farewell = "goodbye for now"
path = "/usr/local/share"
```

### Exercise 2

Empty each argument list with `di(` (from anywhere on the line), then put back
something new with `ci(` instead.

```python
print("one", "two", "three")
total = add(1, 2, 3, 4)
result = compute(alpha, beta, gamma=None)
```

### Exercise 3

Put the cursor inside a function body: `daf` deletes the function, `u` brings it back.
`vif` selects only the body (`Esc` drops the selection). `vac` on a method selects the
whole class.

```python
def area(width, height):
    if width < 0 or height < 0:
        raise ValueError("negative size")
    return width * height


class Shape:
    def __init__(self, name):
        self.name = name

    def describe(self):
        for part in self.name.split():
            print(part)
        return self.name
```

### Exercise 4

Swap the two arguments: `yiw` on "left", then `viwp` on "right" (which replaces it and
puts "right" in the register), then go back and `viwp` on "left". Lesson 9 shows a
cleaner way.

```python
swap(left, right)
```

### Exercise 5

`dio` inside the loop body below deletes the body of the for-loop; `cio` changes it.

```python
for item in [1, 2, 3]:
    print(item)
    print(item * 2)
```

### Exercise 6

Paragraphs: put the cursor on one of the three lines, `vip` selects all three, then
press `>` to indent them.

```python

first = 1
second = 2
third = 3

```

## Away from this page

In real code today, use `ci(`, `ci"` and `ciw` at least ten times each.

## You are done when

- Changing a string, a word or an argument list is one `ci` + character, from anywhere in it.
- You use `vip` / `vaf` instead of `V` and many `j`s.
- `dap`, `yi{`, `cit` read like words.

Then press `Space h n` for lesson 5.

> Tip: `ci"` works from anywhere inside the quotes, and on the line before them it jumps forward to the next pair.

> Tip: `daf` deletes a whole function, `vac` selects a class. Tree-sitter knows where they end.

> Tip: `ciw` changes the word under the cursor without first moving to its start.

> Tip: `vip` selects the paragraph. Then `>` indents it, `gc` comments it, `:sort` sorts it.
