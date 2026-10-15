# Architecture

rihla is three things in one repository: a POSIX `sh` installer that puts pinned tools in
the user's home, a Neovim config under `nvim/`, and a tmux config under `tmux/`, with an
opt-in shell layer under `shell/`. The installed copy of the repository is the config:
`~/.config/nvim` is a symlink into it and `~/.tmux.conf` sources it.

```
install.sh ──> $RIHLA_HOME (repo copy) ──> bin/rihla install
                                             ├─ tools_step    lib/manifest → ~/.local/share/rihla-tools
                                             ├─ config_step   ~/.config/nvim, ~/.tmux.conf, terminfo, icons
                                             ├─ shell_step    PATH block in the shell rc file
                                             └─ plugins_step  lib/provision.lua → ~/.local/share/nvim/lazy
```

## Bootstrap: `install.sh`

The whole script is a `main()` called on the last line, so a truncated `curl | sh` runs
nothing. It checks for `tar gzip sed awk grep cksum`, a downloader and a sha256 tool,
then obtains the source in one of three ways:

| Source | How |
| --- | --- |
| a checkout next to `install.sh` | copied with `tree_tar`: `git ls-files -co --exclude-standard`, so ignored and `.git/info/exclude`d files never reach the install |
| the network | `git clone --depth 1 -b $RIHLA_REF`, falling back to `$RIHLA_REPO/archive/$REF.tar.gz` |
| `--offline BUNDLE` | the bundle's `rihla/` tree, and `--offline-dir` passed on to `bin/rihla` |

Copies are staged in `$DEST.new-$$` and swapped in with two `mv`s. A fingerprint of the
source tar stream (`cksum`) is stored in `$DEST/.rihla-source`; an unchanged source is not
copied again, which keeps a second run a no-op. Directories `install.sh` had to create are
passed to `bin/rihla` in `RIHLA_CREATED_DIRS` so uninstall can remove them.

## Installer: `bin/rihla`

One POSIX `sh` file.
`rihla install` runs, in order: platform detection (`uname`, glibc version from `getconf` or
`ldd`), `preflight` (required commands), `journal_init`, a lock, then the four steps
above. Every step is idempotent; output distinguishes `ok` from `changed`, and the summary
counts changes.

### Pins: `lib/manifest`

```
asset <tool> <version> <os> <arch> <min-glibc> <format> <sha256> <url> <binary-path>
floor <tool> <version>
```

`asset_rows` (awk) selects the rows usable on the target, in file order. For one tool the
preferred build comes first and the most compatible last: Neovim's official Linux build
needs glibc 2.34, so a second row points at `neovim/neovim-releases`, built against 2.17.
`install_tool` walks the rows, unpacks each into `rihla-tools/<tool>-<version>/`, runs
`<bin> --version`, and keeps the first that runs. `floor` rows are the minimum system
version used as is (rg 13, fd 8, fzf 0.48, lazygit 0.40, tmux 3.2, git 2.19); Neovim is
always the pinned build.

Downloads go through `fetch_asset URL SHA256`: the offline bundle and the cache
(`~/.cache/rihla/<sha12>-<file>`) are checked first, and every file is verified against the
manifest digest before use.

`~/.local/bin/nvim` is a four-line script that prepends `rihla-tools/bin` to `PATH` and
execs the pinned binary, so the editor finds rihla's rg, fd, fzf and lazygit even before
the shell's `PATH` is updated. The other tools are symlinks.

### Journal and uninstall

Every change is appended to `~/.local/state/rihla/journal`, one tab-separated line:

| Kind | Meaning | Undone by |
| --- | --- | --- |
| `mkdir <dir>` | directory rihla created | `rmdir`, deepest first, only when empty |
| `link <path>` / `file <path>` | symlink or file rihla wrote | `rm` |
| `tree <dir>` | directory rihla owns entirely | `rm -rf` |
| `moved <path> <backup>` | a pre-existing path moved into `backup-<date>/` | moved back |
| `rc <file> <how>` | the marked block in a shell rc file | removed byte for byte |

`claim` moves anything rihla is about to replace and does not own into the backup
directory, with a `MANIFEST`. `rihla uninstall` replays the journal in reverse: removals
first, then restores (a path recreated since install is moved aside as
`<path>.rihla-conflict-<date>`), then empty directories. Side effects of the download
tools themselves (`~/.pki/nssdb` from NSS curl, `~/.wget-hsts`, tree-sitter's lock
directory) are journalled when absent before install, so a full cycle leaves `$HOME` as
it was; `test/assert.sh` compares a snapshot to prove it.

The lock is a directory (`mkdir` is atomic) holding the owner's PID; a lock whose PID is
gone or a zombie is removed by the next run.

### Shell rc block

`rc_block` writes one block between `# >>> rihla >>>` and `# <<< rihla <<<` into the rc
file of `$SHELL`: `~/.bashrc` (`~/.bash_profile` on macOS), `$ZDOTDIR/.zshrc` (zsh is asked
for `ZDOTDIR`, since `~/.zshenv` often sets it without exporting),
`~/.config/fish/conf.d/rihla.fish`, or `~/.profile`. The block adds `~/.local/bin` to
`PATH` once, runs `stty -ixon` in interactive shells so Ctrl-s reaches the editor, and,
after `rihla shell`, sources `shell/<shell>.rc`. A block from an older version is
rewritten in place.

### Plugins

`plugins_step` picks a fetch mode with `plugin_mode`: `git` when git ≥ 2.19 is on `PATH`,
otherwise (and always offline) `tarball`.

- **git**: lazy.nvim is cloned with `--filter=blob:none` and checked out at its lockfile
  commit; lazy then installs and restores every plugin at the commits in
  `nvim/lazy-lock.json`.
- **tarball**: each plugin is downloaded from
  `codeload.github.com/<owner>/<repo>/tar.gz/<commit>` and given a minimal `.git` (`HEAD`,
  branch refs, `config`, no objects) plus `.git/rihla-tarball` holding the commit. lazy
  reads the commit from the refs, so lockfile logic works without git. Only GitHub-hosted
  plugins can be fetched this way. When git later becomes usable, the next install
  replaces these directories with clones.

Provisioning runs Neovim headless with the real config:

```
nvim --headless -i NONE --cmd "luafile <rihla>/lib/provision.lua"
```

`provision.lua` wraps `require("lazy").setup` to force `install.missing = false`,
`checker.enabled = false` and `change_detection.enabled = false`, then acts on `VimEnter`
by `RIHLA_PROVISION`:

| Mode | Does |
| --- | --- |
| `list` | prints `name url dir commit branch` for every plugin (the installer fetches tarballs from this) |
| `restore` | git mode: install missing, check out lockfile commits, clean removed plugins |
| `build` | tarball mode: run lazy's build steps, clean removed plugins |
| `check` | every plugin present at its lockfile commit; used first so a provisioned home is left untouched |

Plugins disabled on a machine by their `cond` (gitsigns without git) are reported as
`skip`. Build steps must not need a compiler: a failed build fails the install.

lazy writes its lockfile to a working copy in `~/.local/share/nvim/rihla/lazy-lock.json`,
not into the repository. `require("rihla.lazy").merge_lock()` copies the repository's pins
over it on every provisioning run, so the repository wins for the plugins it ships and
plugins the user added keep their own pins. The checkout stays clean, so `git reset` in
`rihla update` never conflicts.

### Update, bundle, check

`rihla update` resets the checkout to `origin/$REF` (or replaces a non-git copy from the
archive), re-runs `rihla install` from the new tree so tools and plugins move to the new
pins, and in git mode runs `:Rihla sync` headless (removes unlisted plugins, rebuilds
tree-sitter parsers).

`rihla bundle [--os --arch --glibc]` stages the repository, every manifest row usable on
the target (all Neovim fallbacks included), and every plugin tarball at its lockfile
commit into one `tar.gz` (about 36 MB). Built on a machine without rihla installed, it
leaves nothing behind outside the stage directory.

`rihla check` is read-only: versions, `PATH` order, clipboard path, colour support, icon
mode, plugins at their commits, proxy settings (credentials masked), and a timed start of
the user's own zsh with a line per slow component it recognises.

## Neovim: `nvim/`

`nvim/init.lua` refuses Neovim older than 0.11 with one message, sets the leader to
Space, and calls `require("rihla").setup()`. `rihla/init.lua` loads every module through
`util.safe`, which turns an error into one line (full trace in `:Rihla log`) and keeps
loading the rest:

```
~/.config/rihla/init.lua → icons → options → keymaps → autocmds → conflict → commands
  → lazy (plugins) → lang → learn → habits → dashboard → ~/.config/rihla/local.lua
```

`util.root` is the repository root, found from the resolved path of `util.lua` itself, so
the config needs no environment variable to locate `docs/`, `shell/` or `tmux/`.

| Module | Role |
| --- | --- |
| `lazy.lua` | lazy.nvim bootstrap at a pinned commit (v11.17.5), working lockfile, user specs from `~/.config/rihla/plugins/*.lua`; update checker and change detection off |
| `plugins/*.lua` | one spec file per area: completion, debug, editor, find, format, git, lsp, replace, treesitter, ui, whichkey |
| `langs.lua` / `lang.lua` | a table per language (`ft ts lsp fmt lint dap tools`) and the engine that acts on it on the first `FileType` of each kind, after the buffer is drawn |
| `tools.lua` / `dap.lua` | mason installs and their preconditions (Node.js, `python3 -m venv`, unzip, a runnable binary on this glibc); debug adapters installed on the first `F5` |
| `palette.lua` / `statusline.lua` / `dashboard.lua` | colours parsed from `tmux/palette.conf`; the status line and start screen drawn from them |
| `learn.lua` | the lessons (below) |
| `habits.lua` | counts slow key runs and shows a one-line hint naming the lesson that teaches the faster key; only keys from lessons marked done are named |
| `find.lua` / `replace.lua` / `term.lua` / `tabs.lua` | picker scope and toggles, replace with undo, bottom and floating terminals, numbered and pinned tabs |
| `conflict.lua` | merge conflicts in the buffer: highlights, `co` `ct` `cb` `c0`, `]x` `[x`, the quickfix list; needs no git |
| `commands.lua` / `cmdpalette.lua` / `cheat.lua` / `health.lua` | `:Rihla <sub>`, the command palette, cheat sheets, `:checkhealth rihla` |

### Language engine

On the first buffer of a file type, `lang.on_filetype` looks up its entry and, in the
background:

1. starts tree-sitter if a parser is installed, otherwise keeps regex syntax and builds the
   parser when a C compiler and the tree-sitter CLI exist;
2. for each `lsp` item (a server, or a list of alternatives) enables the first server on
   `PATH`, else installs the first one mason can install here, runs it once to prove it
   starts on this glibc, then enables it with `vim.lsp.enable`;
3. installs missing formatters (conform.nvim) and linters (nvim-lint) the same way.

`vim.g.rihla_auto_install = false` turns installs off; `:Rihla install <lang>|all` runs
them on demand and, headless, waits for them.

### Lessons

The curriculum is `docs/learn/NN-*.md`. Opening a lesson copies it to
`~/.local/state/nvim/rihla/lessons/`, so practice edits never touch the repository; copies
save themselves and `:Rihla learn reset` restores one. Each lesson is a single page in one
window, with a header bar naming the keys for next, quit and back. Lessons that need real
code copy `docs/learn/files/NN-*` beside the page. Progress is
`~/.local/state/nvim/rihla/learn.json`. An inserted lesson such as `07b` is stored as 7.2,
so the numbers of the lessons after it, and existing progress, do not change.

## tmux: `tmux/`

The installer writes `~/.tmux.conf` as a stub that sets `RIHLA_HOME`, `RIHLA_TMUX` and
`RIHLA_CONFIG` in the global environment and sources, in order:

```
tmux/tmux.conf            settings valid on tmux 1.8+
  tmux/modern.conf        tmux 3.0+: the bar, palette, OSC 52, undercurl, shell choice
  tmux/tmux-3.2.conf      tmux 3.2+: popups and the prefix-h menu
~/.local/state/rihla/tmux-shell.conf   written by `rihla shell --fish`
~/.config/rihla/tmux/local.conf        the user's own, last
```

Version gates are `if-shell '"$RIHLA_TMUX/bin/tmux-ver" X.Y [Z.W]'`, so one config loads
without errors from tmux 1.8 to 3.6; older servers get fewer features.

Prefix is Ctrl-Space with Ctrl-b as `prefix2`. Ctrl-h/j/k/l are bound at the root table:
when the pane's TTY runs nvim or fzf (`ps -o state= -o comm= -t <tty>`, or
`pane_current_command` without `ps`) the key is passed through, otherwise tmux selects the
neighbouring pane; vim-tmux-navigator does the reverse at nvim's edge.

The status bar is hand-built in `modern.conf` from `#{@rihla_*}` options. Its end tiles take
the colour of the mode (mauve normal, peach PREFIX, blue COPY, yellow SEARCH, teal ZOOM),
the same mapping the editor's status line uses for its modes. Segments drop out by
terminal width (date, directory, battery, git). `bin/git-status` is a `#()` job that walks
up the directory tree in `sh` before starting git, so panes outside a repository never
fork git. Copy mode sends the selection to the outer terminal with OSC 52 (`set-clipboard on`),
which works over SSH; `bin/copy` also hands it to `wl-copy`, `xclip`, `xsel`, `pbcopy` or
`clip.exe` when one is reachable.

### The shared palette

`tmux/palette.conf` is the only file that spells out colours:

```
set -g @rihla_mauve "#cba6f7"
set -g @rihla_mode_normal "#{@rihla_mauve}"
```

tmux sources it; `nvim/lua/rihla/palette.lua` parses the same lines (resolving
`#{@rihla_x}` references). `test/palette.sh` checks that every hex colour in `nvim/lua`,
`shell/` and `tools/art.py` is a palette value, and that tmux and Neovim resolve each mode
colour to the same value.

## Shell layer: `shell/`

`rihla shell` installs pinned starship, zoxide and, per shell, zsh-autosuggestions,
zsh-syntax-highlighting and zsh-completions, or ble.sh for bash, into
`rihla-tools/shell/`, then adds one `source` line to the rc block. `shell/zsh.rc` and
`shell/bash.rc` run after the user's own rc file and enable each piece only when the shell
has no equivalent already (a prompt theme, autosuggestions, highlighting, `compinit`, fzf
bindings, zoxide, history options). They record the result in `rihla_shell_on` and
`rihla_shell_skipped`, which `rihla shell status` reads from a probe shell
(`zsh -i -c`, with `HISTFILE` unset before exit).

Start-up cost is kept low by caching the generated init code of starship, zoxide and fzf in
`~/.local/state/rihla/shell/`, running `compinit` with a daily dump check, and on zsh 5.0.8+
computing autosuggestions and git status asynchronously. `test/pty-latency.py` measures
per-keystroke latency in a pseudo-terminal.

`rihla shell --fish` installs a static fish and writes `tmux-shell.conf`, making tmux's
`default-command` `exec <fish> -C 'source <rihla>/shell/fish/rihla.fish'`; the login shell and the
user's fish config are not changed.

`shell/ripgreprc` and `shell/fdignore` are the search defaults for both the shell
(`RIPGREP_CONFIG_PATH`, `fd --ignore-file`) and the editor's pickers. `shell/bin/rgi` and
`ff` are fzf front ends over rg and fd that open hits in nvim.

## Tests

| Command | Checks |
| --- | --- |
| `test/run.sh <distro>…` / `all` | installs as a non-root user in a fresh container (repository mounted read-only, home on tmpfs) and runs `test/assert.sh` |
| `test/run.sh --offline BUNDLE <distro>` | the same from a bundle with `--network none` |
| `test/run.sh local` | `test/assert.sh` on this machine with a throwaway `HOME`, no docker |
| `test/run.sh tmux-versions` | `test/bar.sh` against each distro's own tmux, 1.8 to 3.4 |
| `test/assert.sh` | plant a config, snapshot `$HOME`, install, assert, re-install (must change nothing), uninstall, compare with the snapshot |
| `test/bar.sh` | loads the tmux config in a throwaway server, attaches a real 80×24 client inside a second tmux, and checks the captured bar |
| `test/nav.sh` | Ctrl-h/j/k/l typed into a real tmux client move between nvim splits and shell panes |
| `test/shell.sh` | the shell layer on and off, skipped pieces, fzf keys, `rgi`, fish |
| `test/palette.sh` | the shared palette, as above |
| `nvim/tests/run.sh smoke\|keys\|learn\|find\|habits\|lsp\|dap` | headless editor tests, listed in [nvim.md](nvim.md#tests) |

`assert.sh` additionally requires a clean `nvim --headless +qa`, the Catppuccin colour
scheme, every lockfile plugin present (or skipped by its `cond`) at its commit, and the
LSP check for the languages in `RIHLA_TEST_LSP`.

The distros are CentOS 7, Rocky 8 and 9, Ubuntu 22.04 and 24.04, Debian 12, Fedora and
Arch; some rows add the distribution's own git, tmux or zsh (CentOS 7's git 1.8.3 and zsh
5.0.2) to exercise the old-system-tool paths. CI (`.github/workflows/ci.yml`) runs shellcheck, the container matrix, the
tmux-version matrix, an offline install on CentOS 7 and Ubuntu 24.04, and `test/run.sh
local` on macOS.

| Variable | |
| --- | --- |
| `RIHLA_TEST_CACHE` | download cache reused between runs |
| `RIHLA_TEST_LOGS` | log directory |
| `RIHLA_TEST_LSP` | languages for the LSP check, e.g. `lua,python`; empty skips it |
| `RIHLA_TEST_PROXY` | download through a proxy |
| `RIHLA_TEST_TMPFS` | size of the test home (default `3g`) |
| `RIHLA_TEST_PREFIX` | container name prefix |

Containers are removed after each run. The tree under test is exported with
`git ls-files -co --exclude-standard`, so uncommitted files are tested and ignored files
are not.
