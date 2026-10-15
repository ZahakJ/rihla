# tmux cheat sheet

Close this sheet with `q`. Move with `j` / `k`, the arrow keys or the mouse wheel.

**prefix** means: press **Ctrl-Space** (hold Ctrl, press Space), let go, then press the
key that follows. So `prefix d` is Ctrl-Space, then d. **Ctrl-b** (the tmux default)
works as the prefix too. The tile at the left of the bar says what tmux is doing:
`PREFIX` (peach) while it waits for that key, `COPY` (blue) in copy mode (`q` leaves it),
`SEARCH` (yellow) once a search is on screen, `ZOOM` (teal) while a pane is zoomed.

**Getting out of tmux:** `prefix d` (detach) takes you back to the plain terminal and
leaves everything running; `tmux attach` brings it back. `exit` in a shell closes that
pane; closing the last one ends the session.

Open this sheet inside tmux with `prefix H`. `prefix h` opens a menu of the common
actions (each entry shows its key, and the same key picks it). `prefix ?` lists every key.

## Sessions

A session is a set of windows that keeps running when you close the terminal or lose SSH.

| Keys / command | Action |
| --- | --- |
| `tmux` | start a new session |
| `tmux new -s work` | start a session named `work` |
| `tmux ls` | list sessions |
| `tmux attach` / `tmux a -t work` | reattach (to the last one / to `work`) |
| `prefix d` | detach: leave everything running and return to the shell |
| `prefix s` | pick a session from a list |
| `prefix $` | rename the session |
| `prefix ( )` | previous / next session |

## Windows (tabs)

| Keys | Action |
| --- | --- |
| `prefix c` | new window |
| `prefix n` / `prefix p` | next / previous window |
| `prefix 1` .. `prefix 9` | go to window 1..9 (numbering starts at 1) |
| `prefix ,` | rename the window |
| `prefix w` | pick a window from a tree of all sessions |
| `prefix &` | close the window (asks first) |

## Panes (splits)

| Keys | Action |
| --- | --- |
| `prefix \|` | split left / right, same directory |
| `prefix -` | split top / bottom, same directory |
| `prefix %` / `prefix "` | the default split keys, still there |
| `Ctrl-h` `Ctrl-j` `Ctrl-k` `Ctrl-l` | move left / down / up / right, across tmux panes and nvim splits alike |
| `prefix Ctrl-l` | clear the screen (plain `Ctrl-l` moves right) |
| `prefix z` | zoom the pane to full window and back |
| `prefix x` | close the pane (asks first) |
| `prefix q` | show pane numbers; press one to jump there |
| `prefix Space` | cycle through layouts |
| `prefix {` / `prefix }` | swap the pane with the previous / next one |
| `prefix Ctrl-arrow` | resize the pane |
| `prefix !` | turn the pane into its own window |
| mouse | click a pane to focus it, drag a border to resize, scroll to enter copy mode |

## Copy mode (scrolling, selecting, copying)

`prefix [` enters copy mode (so does scrolling up with the mouse). Keys are vi-like.

| Keys | Action |
| --- | --- |
| `h j k l`, `w b`, `Ctrl-u` / `Ctrl-d` | move, by word, half page up / down |
| `g` / `G` | top / bottom of the history |
| `/` / `?`, then `n` / `N` | search down / up, next / previous match |
| `v` | start a selection |
| `Ctrl-v` | switch between line and block selection |
| `y` | copy the selection and leave copy mode |
| `q` | leave copy mode (`Esc` only clears the selection) |
| `prefix ]` | paste what you copied |

Copying puts the text in the system clipboard of the terminal you are typing in, over
SSH too (OSC 52; most current terminals allow it). When a clipboard tool is present
(`wl-copy`, `xclip`, `xsel`, `pbcopy`) it gets the text as well.

## Help and config

| Keys | Action |
| --- | --- |
| `prefix h` | menu of common actions (tmux 3.2+) |
| `prefix H` | this cheat sheet |
| `prefix ?` | every key binding (`q` to close) |
| `prefix :` | type a tmux command, e.g. `:kill-session` |
| `prefix r` | reload the config |
| `prefix t` | big clock |

Your own settings go in `~/.config/rihla/tmux/local.conf`; it is loaded last, so it can
override anything here. `rihla install` and `rihla update` never touch it.

## From the shell

| Command | Action |
| --- | --- |
| `rihla cheat tmux` | print this sheet |
| `rihla check` | check tmux version, clipboard, colours |
| `rihla icons nerd` / `ascii` | status bar with Nerd Font glyphs, or plain |

Older tmux: rihla installs tmux 3.6b on Linux when the system one is older than 3.2. With
an older tmux the config still loads; the menu and popups are missing and `prefix h` /
`prefix H` open the cheat sheet in a new window instead.
