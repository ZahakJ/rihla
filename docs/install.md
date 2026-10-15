# Installing rihla

```sh
curl -fsSL https://raw.githubusercontent.com/ZahakJ/rihla/main/install.sh | sh
```

No curl? `wget -qO- https://raw.githubusercontent.com/ZahakJ/rihla/main/install.sh | sh`.
With options: `curl -fsSL .../install.sh | sh -s -- --icons nerd --no-shell`.
From a checkout: `sh install.sh`. No network: see [Offline](#offline-machines).

Everything goes into your home directory. rihla never asks for or runs sudo. Running the
installer again is safe: a second run changes nothing and says so.

## What goes where

| What | Where | Notes |
| --- | --- | --- |
| rihla itself (this repo) | `~/.local/share/rihla` | `RIHLA_HOME` to change |
| Neovim, ripgrep, fd, fzf, lazygit, tmux | `~/.local/share/rihla-tools/<tool>-<version>/` | pinned in `lib/manifest`, sha256-checked |
| Commands | `~/.local/bin/{nvim,rg,fd,fzf,lazygit,tmux,rihla}` | `nvim` is a small script that runs the pinned build; the rest are symlinks |
| Neovim config | `~/.config/nvim` -> `~/.local/share/rihla/nvim` | symlink |
| Neovim plugins | `~/.local/share/nvim/lazy/` | at the commits in `nvim/lazy-lock.json` |
| tmux config | `~/.tmux.conf` | four lines that source `~/.local/share/rihla/tmux/tmux.conf` |
| PATH | one marked block in `~/.bashrc` (`~/.bash_profile` on macOS), `.zshrc` (in `$ZDOTDIR` when your `~/.zshenv` sets one), `~/.config/fish/conf.d/rihla.fish` or `~/.profile` | puts `~/.local/bin` first on PATH; in bash, zsh and sh it also runs `stty -ixon` in interactive shells, so Ctrl-s (save) does not freeze the terminal. Skip with `--no-shell`. A block from an older rihla is updated in place |
| Terminal descriptions | `~/.terminfo/t/tmux-256color`, `~/.terminfo/x/xterm-kitty` | only when the system has none (CentOS/RHEL 7 lacks both, macOS lacks `tmux-256color`). Gives italics and the right keys inside tmux, and makes kitty work over SSH. From ncurses' own database, see `tmux/terminfo/rihla.src` |
| Shell layer (only after `rihla shell`) | `~/.local/share/rihla-tools/shell/`, one more line in the block above | see [The shell layer](#the-shell-layer) |
| Lesson pages and progress | `~/.local/state/nvim/rihla/lessons/`, `~/.local/state/nvim/rihla/learn.json` | your copies of the lessons; made when you open one |
| Your overrides | `~/.config/rihla/` | never written by install/update, except the `icons` file when it does not exist |
| Backups, journal, logs | `~/.local/state/rihla/` | removed by uninstall |
| Download cache | `~/.cache/rihla/` | `RIHLA_CACHE` to share one |

`XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME` and `XDG_CONFIG_HOME` are respected
where they are set.

Tools other than Neovim are installed only when the system copy is missing or older than
the floor in `lib/manifest` (rg 13, fd 8, fzf 0.48, lazygit 0.40, tmux 3.2). Neovim is
always the pinned one (0.12.5).

## What the machine needs

| Needed | Why |
| --- | --- |
| `sh`, coreutils, `sed`, `awk`, `grep`, `tar`, `gzip` | every Unix has them |
| `curl` or `wget`, with CA certificates | downloads (not needed for an offline bundle) |
| `sha256sum`, `shasum` or `openssl` | checksums |
| glibc 2.17 or newer (Linux), or macOS | the Neovim builds |

If something is missing, the installer names it and stops before changing anything.

Optional, and checked by `rihla check`: git (2.19+ for `:Lazy` and the git gutter), `ps`
(tmux uses it to tell nvim panes apart for Ctrl-h/j/k/l; without it a simpler check is
used), a C compiler (tree-sitter parsers), Node.js (a few language servers).

## How it decides

- **Neovim build**: the official Linux build needs glibc 2.34. Below that (CentOS 7,
  RHEL 8, Ubuntu 20.04) rihla uses the same release from neovim/neovim-releases, built
  against glibc 2.17. If a build does not start, the next compatible one is tried.
- **tmux**: system tmux 3.2 or newer is used as it is. Otherwise, on Linux, a fully static
  tmux 3.6b (musl, from mjakob-gh/build-static-tmux, sha256-pinned) goes into
  `~/.local/share/rihla-tools`. The config also loads on older tmux down to 1.8, with
  fewer features and no errors. macOS has no prebuilt tmux: `brew install tmux`.
- **Plugins**: with git 2.19 or newer, lazy.nvim clones each plugin and checks out the
  lockfile commit. With no git or an older one (CentOS 7 has 1.8.3), each plugin is
  downloaded as a GitHub tarball at its lockfile commit, so the first start needs no
  git at all. `RIHLA_PLUGIN_FETCH=git|tarball` forces one. In tarball mode `:Lazy update`
  does not work; `rihla update` does.
- **Icons**: `nerd` when `fc-list` shows a Nerd Font, or when the terminal reports (by its
  version, which also crosses SSH) that it draws Nerd Font symbols with any font: kitty
  0.33+, WezTerm, Ghostty. Otherwise `ascii` (plain text that every font has).
  `rihla icons auto` asks the terminal again and, if it cannot tell, shows four symbols
  and asks you whether they look like pictures or boxes. `rihla icons nerd|ascii` sets it.
- **Shells in tmux**: on Linux a pane runs bash as an interactive shell that reads
  `~/.bashrc`, the way a terminal window does, not as a login shell (tmux's default, which
  skips `~/.bashrc` when no `~/.bash_profile` sources it). zsh keeps tmux's default login
  shell; it reads `.zshrc` either way. On macOS, where terminals open login shells, a pane
  is a login shell too: bash runs `/etc/profile` and then `~/.bash_profile`, which is where
  `rihla shell` puts its line on macOS.
  Inside tmux `COLORTERM=truecolor` is set (tmux turns 24-bit colour into 256 colours when
  the terminal outside cannot show it), and the terminal's title follows the title your
  shell sets.

## Options

| `install.sh` / `rihla install` | |
| --- | --- |
| `--icons nerd\|ascii` | set the icon mode |
| `--no-shell` | do not touch shell rc files; add `~/.local/bin` to PATH yourself |
| `--shell` | also turn on the [shell layer](#the-shell-layer) (the same as running `rihla shell` afterwards) |
| `--minimal` | skip lazygit |
| `--no-plugins` | skip plugin provisioning (debugging) |
| `--offline FILE` (install.sh) | install from a bundle, no network |
| `--home DIR` (install.sh) | install rihla somewhere other than `~/.local/share/rihla` |

| Environment | |
| --- | --- |
| `RIHLA_HOME` | where rihla lives |
| `RIHLA_REF`, `RIHLA_REPO` | branch/tag and repository to install from |
| `RIHLA_CACHE` | download cache directory (left alone by uninstall) |
| `RIHLA_PLUGIN_FETCH` | `git` or `tarball` |
| `RIHLA_ICONS` | `nerd` or `ascii`, overrides `~/.config/rihla/icons` (nvim, tmux and the shell layer's prompt) |
| `RIHLA_SHELL_NO` | pieces of the shell layer to leave off, e.g. `"prompt zoxide"` (set it before rihla's line in your rc file) |
| `https_proxy`, `http_proxy`, `no_proxy` (or uppercase) | used for every download |

## Commands

| Command | |
| --- | --- |
| `rihla check` | versions and a checklist with a fix for each problem; fine in a dumb terminal |
| `rihla update` | newest rihla, then tools and plugins move to its pins |
| `rihla update --offline FILE` | the same from a bundle |
| `rihla uninstall` | remove everything rihla installed and put the old config back |
| `rihla bundle` | build an offline bundle (below) |
| `rihla icons nerd\|ascii\|auto` | switch icon mode; `auto` asks the terminal, or you |
| `rihla shell` | turn on the [shell layer](#the-shell-layer) for your shell (`--for zsh\|bash` to choose) |
| `rihla shell status` | what the layer switched on, and what it left to your own setup |
| `rihla shell --fish` | also make rihla's tmux open fish (pinned; your login shell stays) |
| `rihla shell --no-fish` | tmux opens your own shell again |
| `rihla shell --off` | remove the layer's line and files (and fish in tmux) |
| `rihla cheat [nvim\|tmux]` | cheat sheets |
| `rihla learn` | open the current lesson in nvim |
| `rihla version` | rihla and pinned tool versions |

## The shell layer

`rihla shell` adds prompt, suggestions, highlighting, completion and fzf keys to a bare
shell. Every piece is pinned and sha256-checked in `lib/manifest` and installed into your
home. A default install does not turn it on. It adds one line to rihla's block in your
`.zshrc` or `~/.bashrc`:

```sh
[ -f "$HOME/.local/share/rihla/shell/zsh.rc" ] && . "$HOME/.local/share/rihla/shell/zsh.rc"
```

| Piece | zsh | bash |
| --- | --- | --- |
| Prompt | starship 1.26.0 with rihla's Catppuccin config (`shell/starship-nerd.toml` or `-ascii.toml` by icon mode): the directory in a blue pill like the current tmux window, the git branch in mauve, a green or red arrow. On zsh 5.0.8+ the git status is filled in after the prompt is drawn. A plain zsh prompt in the same colours if starship cannot run | the same (git status drawn with the prompt); a plain bash prompt as fallback |
| Autosuggestions | zsh-autosuggestions 0.7.1 (grey text from history; Right arrow or End accepts); from history only, looked up in the background on zsh 5.0.8+ | ble.sh 0.4.0-devel3 (bash 4.0+; unpacking needs `xz`), 20 ms after the last key |
| Syntax highlighting | zsh-syntax-highlighting 0.8.0 (lines over 300 characters, mostly pastes, are left plain) | ble.sh |
| Completion | menu completion, case-insensitive, zsh-completions 0.36.0 | lists on the first Tab, ignores case (only without your own `~/.inputrc`) |
| fzf keys | Ctrl-R history, Ctrl-T files, Alt-C directories, `**<Tab>`, listing with fd and the shared defaults, with a preview (the fzf rihla installs) | the same (with ble.sh, bound in its keymaps too) |
| Search | `rgi` (search file contents as you type, Enter opens nvim at the hit, Ctrl-Q fills the quickfix list), `ff`/`fdi` (find a file, open it), `rg` and `fd` with the defaults the editor uses ([shell.md](shell.md#defaults)) | the same |
| zoxide 0.10.0 | `z part-of-a-dir` | the same |
| History | shared between terminals, 50000 lines, no duplicates | appended from every terminal, 50000 lines, no duplicates |
| Keys | Home, End, Delete, Ctrl-Left/Right; Up/Down find earlier commands starting with what you typed | the same |

Keys and commands in detail: [shell.md](shell.md).

**fish in tmux.** `rihla shell --fish` also installs fish 4.9.3 (the official static
build, so it runs on CentOS 7; unpacking needs `xz`; on macOS a fish 3.6+ of your own) and
makes rihla's tmux open fish in new windows and panes, with rihla's colours, prompt, fzf
keys, zoxide, `rgi` and `ff` from `shell/fish/rihla.fish` (started with `fish -C`, so
nothing is written to your fish config). Your login shell, and every terminal outside tmux,
stay as they are. `rihla shell --no-fish` gives tmux your shell back. What does not work in
fish: [shell.md](shell.md#fish).

**Your own setup wins, piece by piece.** The line runs after the rest of your rc file and
skips anything you already have: powerlevel10k, starship, an oh-my-zsh or promptinit
theme, or any prompt that is not your distribution's default; your own
zsh-autosuggestions, syntax highlighting (zsh-syntax-highlighting or
fast-syntax-highlighting), compinit (oh-my-zsh runs one), fzf key bindings, zoxide, or
history settings. `rihla shell` and `rihla shell status` say what was skipped and why
("you already have powerlevel10k; rihla's prompt is not enabled"). It prints nothing while
the shell starts, so powerlevel10k's instant prompt stays quiet. `rihla check` measures how
long your own zsh takes to start and names what slows it, one line each with what to
change; it changes nothing itself.

**Old systems.** zsh 5.0.2 (CentOS 7) is the floor; both zsh plugins support it. Before
zsh 5.0.8 suggestions are looked up while you wait; before 5.3 starship's setup is
adjusted; before 5.7 highlighting uses 256-colour approximations of the palette.
starship and zoxide are static musl builds, so glibc does not matter; if starship cannot
run, the plain prompt is used. bash: ble.sh needs bash 4.0+ (CentOS 7 has 4.2; macOS's
`/bin/bash` is 3.2), `xz` to unpack, and the usual POSIX commands, `ps` among them
(minimal container images often lack it: install `procps` or `procps-ng`). Without them
bash gets the prompt, fzf keys, zoxide, history and keys only, and `rihla shell` says
which one was missing.

**Inside tmux and nested shells.** A pane, or a zsh or bash started from your shell,
inherits its environment and sets itself up the same way. rihla's starship and zoxide
are never put on PATH; a starship or zoxide of your own on PATH is used instead. In zsh
the layer keeps each PATH entry once (`typeset -U path`).

Files: the scripts in `~/.local/share/rihla/shell/`, the tools in
`~/.local/share/rihla-tools/shell/`, the layer's runtime data (completion cache, the saved
setup of fzf, zoxide and starship, zoxide's database, starship's log) in
`~/.local/state/rihla/shell/`. ble.sh keeps `~/.cache/blesh` and `~/.local/state/blesh`;
rihla's fish makes `~/.config/fish` and `~/.cache/fish` when they were not there, and
`~/.local/state/rihla/tmux-shell.conf` tells tmux to open it. `rihla shell --off` and
`rihla uninstall` remove all of these and the line. Your history files stay (fish's is
`~/.local/share/fish/fish_history`).

Offline: `rihla bundle` includes the layer's files; `install.sh --offline BUNDLE --shell`
turns it on there. An offline install also leaves them in the download cache, so a later
`rihla shell` works without the network.

## No root, no sudo

Nothing is written outside your home directory (and `$TMPDIR` while running). Binaries are
static where upstream offers it (ripgrep, fd, fzf, lazygit, tmux) and the Neovim builds
carry their own libraries. The installer does not
talk to a running tmux server; reload with `prefix r` or `tmux source-file ~/.tmux.conf`.

## Your existing config

On the first install, anything rihla would replace is moved, not deleted, into
`~/.local/state/rihla/backup-<date>/` with a `MANIFEST`: `~/.config/nvim`, `~/.tmux.conf`,
`~/.config/tmux` (when it holds a `tmux.conf`, since tmux 3.1+ would load it too),
`~/.local/share/nvim`, `~/.local/state/nvim`, `~/.cache/nvim`, and any command in
`~/.local/bin` with the same name as one rihla installs.

`rihla uninstall` undoes every step from a journal: removes what rihla created, removes
the PATH block from your rc file (byte for byte as before), moves the backups back, and
removes the directories it created when they are empty. `~/.config/rihla` (your
overrides) stays. The Neovim data rihla's nvim created (plugins, undo history, shada) is
removed with it.

## Customising without forking

| File | Effect |
| --- | --- |
| `~/.config/rihla/local.lua` | Lua run last in nvim |
| `~/.config/rihla/plugins/*.lua` | extra lazy.nvim specs |
| `~/.config/rihla/langs.lua` | more languages |
| `~/.config/rihla/tmux/local.conf` | tmux settings, loaded last |
| `~/.config/rihla/icons` | `nerd` or `ascii` |

More in [nvim.md](nvim.md#customising-without-forking).

## Offline machines

On any machine with network (it does not need rihla installed):

```sh
sh bin/rihla bundle                      # linux x86_64, glibc 2.17+ (runs everywhere)
sh bin/rihla bundle --arch arm64 -o rihla-arm64.tar.gz
sh bin/rihla bundle --os darwin --arch arm64
```

The bundle (about 36 MB) holds the repo, the pinned tools for that target, the shell
layer's files and every plugin at its lockfile commit. Copy it over, then:

```sh
tar -xzf rihla-bundle-linux-x86_64.tar.gz rihla-bundle/rihla/install.sh
sh rihla-bundle/rihla/install.sh --offline rihla-bundle-linux-x86_64.tar.gz
```

Nothing is downloaded. A newer bundle later: `rihla update --offline FILE`. Language
servers and tree-sitter parsers that the editor installs on demand still need the network;
without it the editor says so once and carries on.

## Proxies

`https_proxy`/`http_proxy`/`no_proxy` (either case) are passed to curl, wget, git and the
plugin downloads. GNU wget reads only the lowercase names, so the installer and Neovim
(for mason's downloads) copy an uppercase-only setting to lowercase. Credentials in the
URL work (`http://user:pass@proxy:3128`); `rihla check` shows the proxy with the
credentials masked. A proxy that intercepts TLS needs its CA in the system store (or
`CURL_CA_BUNDLE` / `SSL_CERT_FILE`).

## Troubleshooting

| Symptom | Cause and fix |
| --- | --- |
| `nvim: ... GLIBC_2.34 not found` | an old machine picked the wrong build. Run `rihla install` again; it tests the build and falls back to the glibc 2.17 one. glibc older than 2.17 (CentOS 6) is not supported |
| `open terminal failed: missing or unsuitable terminal: xterm-kitty` (kitty, over SSH) | the remote machine has no description of kitty. `rihla install` (or update) puts one in `~/.terminfo` when the system lacks it; `kitten ssh` does the same per host |
| bash prompt or aliases missing inside tmux | tmux started a login shell, which skips `~/.bashrc`. rihla's config starts bash as a normal interactive shell on Linux; on macOS a pane is a login shell, so have `~/.bash_profile` source `~/.bashrc`. Reload: `prefix r`, then open a new pane. A `default-command` of your own in `~/.config/rihla/tmux/local.conf` wins |
| `ble/term.sh: updating tput cache for TERM=...` | ble.sh (the bash layer) says this once per terminal type, the first time |
| `rihla: command not found` after install | the PATH block applies to new shells: open one, or `export PATH="$HOME/.local/bin:$PATH"` |
| yank does not reach the clipboard | over SSH this needs OSC 52 support in your terminal (kitty, WezTerm, iTerm2, Windows Terminal, foot, recent Alacritty); in tmux it is on. Locally, install `wl-clipboard` (Wayland) or `xclip` (X11). `rihla check` shows which path is in use |
| boxes or question marks in the status line | the icon mode is `nerd` but the terminal font is not a Nerd Font: `rihla icons ascii`, or install JetBrainsMono Nerd Font in the terminal you type in |
| colours look washed out or wrong | the terminal is not passing true colour. Outside tmux check `echo $COLORTERM` (want `truecolor`) and `echo $TERM` (want `xterm-256color` or the terminal's own). Over SSH add `SendEnv COLORTERM` (client) and `AcceptEnv COLORTERM` (server), or `export COLORTERM=truecolor` |
| tmux: no popup / menu, `prefix h` opens a window | tmux older than 3.2. `rihla check` says which tmux runs; on Linux `rihla install` brings 3.6b, make sure `~/.local/bin` comes first in PATH |
| Ctrl-h/j/k/l do not move out of nvim in tmux | check that nvim was started inside tmux (`echo $TMUX` in its shell). Without `ps` (minimal containers) tmux falls back to the pane's foreground command, which misses an nvim started by another program such as `git commit`; install procps |
| `:Lazy update` fails with git errors | git is missing or older than 2.19 (tarball mode); use `rihla update` |
| downloads fail behind a proxy | set `https_proxy` before running the installer; check with `rihla check` |
| `another rihla run (PID n) is in progress` | wait for it. A lock left by a run that was killed is noticed (its PID is gone) and removed by the next run |
| `no python language server (needs python3-venv ...)`, debugpy not installed | Debian/Ubuntu ship python3 without `venv`; install `python3-venv`. `rihla check` checks it |
| `installing stylua failed (needs unzip ...)` | install `unzip`; the editor retries on its next start |
| musl (Alpine) | Neovim publishes no musl build; the installer warns. Use the distro's Neovim 0.11+ |

## Tests

`test/run.sh <distro>` installs into a fresh container and checks the result;
`test/run.sh --offline BUNDLE <distro>` does the same from a bundle, and `test/run.sh local`
runs the checks here with a throwaway HOME (no docker). Details:
[ARCHITECTURE.md](ARCHITECTURE.md#tests).
