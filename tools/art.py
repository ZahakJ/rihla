#!/usr/bin/env python3
"""Draw the GitHub social preview.

    python3 tools/art.py            # writes docs/media/social-preview.png
    python3 tools/art.py --svg DIR  # also keeps the SVG sources in DIR

It is built as SVG here, then rasterised with rsvg-convert, so the result
does not depend on the fonts of whoever views it. Needs rsvg-convert,
JetBrainsMono Nerd Font Mono and Noto Naskh Arabic (fc-match must find them).
Colours are rihla's palette (Catppuccin Mocha), read from tmux/palette.conf.
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "docs", "media")

def read_palette():
    """The colours from tmux/palette.conf, the one file tmux and Neovim read them from."""
    pal = {}
    with open(os.path.join(HERE, "..", "tmux", "palette.conf")) as f:
        for line in f:
            m = re.match(r'set -g @rihla_([a-z0-9]+) "(#[0-9a-fA-F]{6})"', line)
            if m:
                pal[m.group(1)] = m.group(2)
    return pal


C = read_palette()
MONO = "JetBrainsMono Nerd Font Mono"
ARABIC = "Noto Naskh Arabic"
CHAR = 0.6  # advance of one JetBrains Mono character, in em

# The journey: what a VS Code user presses, and what rihla teaches instead.
JOURNEY = [
    (["Ctrl", "P"], ["Space", "f", "f"], "find a file"),
    (["Ctrl", "Shift", "F"], ["Space", "f", "g"], "search the project"),
    (["F12"], ["g", "d"], "go to definition"),
    (["F2"], ["g", "r", "n"], "rename"),
]


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def text(x, y, s, size, fill, weight="normal", anchor="start", family=MONO, extra=""):
    return (
        f'<text x="{x:.1f}" y="{y:.1f}" font-family="{family}" font-size="{size}" '
        f'font-weight="{weight}" fill="{fill}" text-anchor="{anchor}" xml:space="preserve" {extra}>{esc(s)}</text>'
    )


def pill(x, y, h, label, bg, size):
    """A rounded label like the tmux and Neovim status bars draw. Returns (svg, width)."""
    w = len(label) * size * CHAR + h
    svg = (
        f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h}" rx="{h / 2}" fill="{bg}"/>'
        + text(x + w / 2, y + h / 2 + size * 0.36, label, size, C["crust"], "bold", "middle")
    )
    return svg, w


def keycap(x, y, label, size, h):
    w = max(h, len(label) * size * CHAR + size * 1.2)
    svg = (
        f'<rect x="{x:.1f}" y="{y + 3:.1f}" width="{w:.1f}" height="{h}" rx="7" fill="{C["crust"]}"/>'
        f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h}" rx="7" fill="{C["surface0"]}" '
        f'stroke="{C["surface1"]}" stroke-width="1.2"/>'
        + text(x + w / 2, y + h / 2 + size * 0.36, label, size, C["text"], "normal", "middle")
    )
    return svg, w


def keys(x, y, labels, size, h, gap):
    out = []
    for lab in labels:
        s, w = keycap(x, y, lab, size, h)
        out.append(s)
        x += w + gap
    return "".join(out), x - gap


def tile2(x, y, h, a, a_bg, b, size, a_fg=None, b_fg=None, mirror=False):
    """Two tiles joined by a rounded edge, as the tmux bar and Neovim's status line draw
    them: a mode tile (crust on a colour) and a raised tile (surface0). mirror puts the
    raised tile first, as on the right end of both bars. Returns (svg, width)."""
    adv = size * CHAR
    wa = len(a) * adv + h * 0.9
    wb = len(b) * adv + h * 0.9
    w = wa + wb
    cy = y + h / 2 + size * 0.36
    a_fg = a_fg or C["crust"]
    b_fg = b_fg or a_bg
    r = h / 2
    if not mirror:
        out = [
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h}" rx="{r}" fill="{C["surface0"]}"/>',
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{wa:.1f}" height="{h}" rx="{r}" fill="{a_bg}"/>',
            text(x + wa / 2, cy, a, size, a_fg, "bold", "middle"),
            text(x + wa + wb / 2, cy, b, size, b_fg, "normal", "middle"),
        ]
    else:
        out = [
            f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h}" rx="{r}" fill="{C["surface0"]}"/>',
            f'<rect x="{x + wb:.1f}" y="{y:.1f}" width="{wa:.1f}" height="{h}" rx="{r}" fill="{a_bg}"/>',
            text(x + wb / 2, cy, b, size, b_fg, "normal", "middle"),
            text(x + wb + wa / 2, cy, a, size, a_fg, "bold", "middle"),
        ]
    return "".join(out), w


def tmux_bar(x, y, w, h, size):
    """The tmux bar: no background of its own, tiles on the terminal's."""
    adv = size * CHAR
    cy = y + h / 2 + size * 0.36
    out = []
    s, pw = tile2(x, y, h, "\uf489", C["mauve"], "rihla", size)
    out.append(s)
    cx = x + pw + adv
    s, ww = tile2(cx, y, h, "1", C["blue"], "nvim", size, b_fg=C["text"])
    out.append(s)
    cx += ww + adv
    for label in ("2 shell", "3 notes"):
        out.append(text(cx, cy, label[0], size, C["overlay"]))
        out.append(text(cx + 2 * adv, cy, label[2:], size, C["subtext"]))
        cx += (len(label) + 2) * adv
    # right: the key hint, then the date | time tile
    s, rw = tile2(0, 0, h, "10:04", C["mauve"], "Tue 06 Oct", size, b_fg=C["mauve"], mirror=True)
    rx = x + w - rw
    s, _ = tile2(rx, y, h, "10:04", C["mauve"], "Tue 06 Oct", size, b_fg=C["mauve"], mirror=True)
    out.append(s)
    hint = [("Ctrl-Space", None), ("h", "key"), ("menu", None), ("d", "key"), ("detach", None)]
    hw = sum(len(t) * adv + (h * 0.9 if k else 0) + adv for t, k in hint)
    hx = rx - 3 * adv - hw
    for t, k in hint:
        if k:
            kw = len(t) * adv + h * 0.9
            out.append(f'<rect x="{hx:.1f}" y="{y:.1f}" width="{kw:.1f}" height="{h}" rx="{h / 2}" fill="{C["surface0"]}"/>')
            out.append(text(hx + kw / 2, cy, t, size, C["text"], "bold", "middle"))
            hx += kw + adv
        else:
            out.append(text(hx, cy, t, size, C["overlay"]))
            hx += (len(t) + 1) * adv
    return "".join(out)


def nvim_bar(x, y, w, h, size, right):
    adv = size * CHAR
    cy = y + h / 2 + size * 0.36
    s, pw = tile2(x, y, h, "NORMAL", C["mauve"], "Lesson 3/19", size)
    out = [s, text(x + pw + 2 * adv, cy, "the grammar", size, C["subtext"])]
    s, rw = tile2(0, 0, h, "1:1", C["mauve"], "Top", size, b_fg=C["mauve"], mirror=True)
    s, _ = tile2(x + w - rw, y, h, "1:1", C["mauve"], "Top", size, b_fg=C["mauve"], mirror=True)
    out.append(s)
    out.append(text(x + w - rw - 3 * adv, cy, right, size, C["overlay"], anchor="end"))
    return "".join(out)


def journey(x, y, size, h, row_gap, arrow_w, items=JOURNEY):
    """Rows of keycaps: VS Code keys on the left, rihla's on the right."""
    gap = 6
    left_w = 0
    for left, _, _ in JOURNEY:  # same column width for every group
        _, end = keys(0, 0, left, size, h, gap)
        left_w = max(left_w, end)
    out = [
        text(x, y - 14, "VS Code", size * 0.85, C["overlay"]),
        text(x + left_w + arrow_w, y - 14, "rihla (Vim keys)", size * 0.85, C["overlay"]),
    ]
    for i, (left, right, _) in enumerate(items):
        ry = y + i * (h + row_gap)
        s, _ = keys(x, ry, left, size, h, gap)
        out.append(s)
        ax = x + left_w + 12
        mid = ry + h / 2
        out.append(
            f'<path d="M{ax:.1f} {mid:.1f} H{ax + arrow_w - 30:.1f} m-7 -6 l7 6 l-7 6" fill="none" '
            f'stroke="{C["mauve"]}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>'
        )
        s, _ = keys(x + left_w + arrow_w, ry, right, size, h, gap)
        out.append(s)
    return "".join(out)


def name_block(x, y, size, tag_size, tag_gap):
    adv = size * CHAR
    cur_x = x + 5 * adv + size * 0.08
    return "".join([
        text(x, y, "rihla", size, "url(#name)", "bold", extra='letter-spacing="0"'),
        # a block cursor, as in normal mode
        f'<rect x="{cur_x:.1f}" y="{y - size * 0.7:.1f}" width="{adv * 0.8:.1f}" '
        f'height="{size * 0.84:.1f}" rx="3" fill="{C["text"]}" opacity="0.7"/>',
        text(cur_x + adv + size * 0.25, y - size * 0.06, "رحلة", size * 0.42, C["overlay"], family=ARABIC),
        text(x + 4, y + tag_gap, "Neovim + tmux that installs anywhere", tag_size, C["text"]),
        text(x + 4, y + tag_gap + tag_size * 1.32, "and teaches you as you go.", tag_size, C["text"]),
    ])


def defs():
    return (
        "<defs>"
        f'<linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">'
        f'<stop offset="0" stop-color="{C["base"]}"/><stop offset="1" stop-color="{C["crust"]}"/></linearGradient>'
        f'<linearGradient id="name" x1="0" y1="0" x2="0" y2="1">'
        f'<stop offset="0.15" stop-color="{C["mauve"]}"/><stop offset="1" stop-color="{C["blue"]}"/></linearGradient>'
        "</defs>"
    )


def social():
    W, H = 1280, 640
    body = [
        defs(),
        f'<rect width="{W}" height="{H}" fill="url(#bg)"/>',
        tmux_bar(40, 36, W - 80, 36, 17),
        name_block(80, 236, 140, 36, 70),
        journey(84, 440, 17, 38, 14, 80, JOURNEY[:2]),
        journey(700, 440, 17, 38, 14, 80, JOURNEY[2:]),
        nvim_bar(40, H - 72, W - 80, 36, 17, "github.com/ZahakJ/rihla"),
    ]
    return W, H, body


def render(name, W, H, body, out, svg_dir, zoom):
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
        + "".join(body) + "</svg>\n"
    )
    with tempfile.TemporaryDirectory() as tmp:
        src = os.path.join(svg_dir or tmp, name + ".svg")
        with open(src, "w", encoding="utf-8") as f:
            f.write(svg)
        subprocess.run(["rsvg-convert", "-z", str(zoom), "-o", out, src], check=True)


def check_tools():
    if not shutil.which("rsvg-convert"):
        sys.exit("art.py: needs rsvg-convert (librsvg)")
    for fam in (MONO, ARABIC):
        got = subprocess.run(["fc-match", "-f", "%{family}", fam], capture_output=True, text=True).stdout
        if fam not in got:
            sys.exit(f"art.py: font '{fam}' not installed (fc-match gave '{got}')")


def main():
    svg_dir = None
    if len(sys.argv) == 3 and sys.argv[1] == "--svg":
        svg_dir = sys.argv[2]
        os.makedirs(svg_dir, exist_ok=True)
    check_tools()
    for name, fn, out, zoom in (("social-preview", social, "social-preview.png", 1),):
        W, H, body = fn()
        dest = os.path.normpath(os.path.join(ASSETS, out))
        render(name, W, H, body, dest, svg_dir, zoom)
        print(dest)


if __name__ == "__main__":
    main()
