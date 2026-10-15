# The shell

What `rihla shell` gives your shell, the defaults the shell and the editor share, and fish.
Installing the layer and switching it off: [install.md](install.md#the-shell-layer).

## Keys and commands

The same in zsh, bash and fish (rihla's fish runs in rihla's tmux, see below), in any
terminal down to 80x24. Lists open in fzf: type to narrow, arrows or Ctrl-J/K to move,
Enter to pick, Esc to leave.

| Key or command | What it does |
| --- | --- |
| type, then Right or End | take the grey suggestion (your earlier command that starts the same way) |
| Up / Down | earlier / later commands that start with what you typed |
| Ctrl-R | search all earlier commands (fzf) |
| Ctrl-T | pick files and folders below here (fd: hidden files in, `.git` and `node_modules` out), with a preview; pasted where the cursor is |
| Alt-C | pick a folder below here and `cd` into it, with a preview |
| `**` then Tab | the same list for any command's argument: `nvim src/**<Tab>`, `cd **<Tab>` (zsh and bash) |
| `rgi [PATTERN] [rg options, paths]` | search inside files as you type, a regular expression; the file around each hit beside the list. Enter opens nvim at that line; Ctrl-Q opens nvim with every hit in the quickfix list (`]q` / `[q` step through them) |
| `ff [PATTERN] [PATH]`, `fdi` | find a file by name (regular expression), narrow by typing, Enter opens it in nvim (Tab marks several) |
| `z part-of-a-dir` | jump to a folder you have been in before (zoxide) |
| `rg`, `fd` | ripgrep and fd with the shared defaults below |

Examples: `rgi 'def \w+_test' tests/`, `rgi TODO -g '*.py'`, `rgi -t c 'malloc\('`,
`ff '\.ya?ml$'`, `ff config src`.

## Defaults

The shell and the editor search the same way. Two files in rihla's checkout hold the
defaults; both sides read them from there, so a change to one list changes both.

| File | Read by | What it says |
| --- | --- | --- |
| `shell/ripgreprc` | `rg` everywhere once `RIPGREP_CONFIG_PATH` points at it (the shell layer exports it when you have not set your own; `rgi` sets it for itself); the editor's grep and live grep | `--smart-case --hidden --follow --max-columns=300 --max-columns-preview`, and a `--glob=!NAME` for each name in the ignore list |
| `shell/fdignore` | `fd --hidden --follow --ignore-file <rihla>/shell/fdignore` (fd has no config file: the shell layer's `fd` alias, Ctrl-T, Alt-C, `**<Tab>`, `ff`; the editor's file finder) | the ignore list, in gitignore syntax |

The ignore list: `.git/ .hg/ .svn/ node_modules/ .venv/ __pycache__/ .mypy_cache/
.pytest_cache/ .ruff_cache/ .tox/ .direnv/ .DS_Store`. Both tools also honour
`.gitignore`. Hidden files (dotfiles such as `.github/` or `.env`) are searched.

For the editor: `<rihla>` is `$RIHLA_HOME` when set (tmux sets it), otherwise the parent of
the resolved Neovim config directory (`~/.config/nvim` links to `<rihla>/nvim`). A
`RIPGREP_CONFIG_PATH` you set wins. `rg --no-config` and `fd -u` search without the
defaults.

## fish

`rihla shell --fish` installs fish 4.9.3 (pinned in `lib/manifest`, included in the
offline bundle) and makes **rihla's tmux only** open fish in new windows and panes, with
rihla's colours, prompt, keys, `rgi` and `ff` (`shell/fish/rihla.fish`, read with
`fish -C`; nothing is written to your fish config). Your login shell is not changed (no
`chsh`); outside tmux you keep zsh or bash. `rihla shell --no-fish` gives tmux your shell
back; `rihla shell --off` removes everything.

- The official Linux build is a single static binary, so it runs on CentOS 7. Unpacking it
  needs `xz`; where `xz` is missing, `rihla shell --fish` says so and tmux keeps your
  shell. On macOS, bring a fish 3.6+ of your own.
- Suggestions, highlighting and completions are fish's own; fzf, zoxide and starship
  work.
- PATH is fine: fish inherits it from tmux.

What does not work in fish (it is not a POSIX shell):

- `source ~/.bashrc`, a vendor's `env.sh`, conda's bash `activate`, a team's setup
  script: they need their fish version, or `bash -c '...'`.
- bash/zsh aliases and `export -f` functions.
- `[[ ]]`, here-docs, `for ...; do ... done`, `${var:-default}`. (`$(...)`, `&&` and
  `VAR=value command` work in fish 3.4+.)

## Your own setup

The layer skips each piece you already have (see [install.md](install.md#the-shell-layer)),
so on a set-up machine it may add almost nothing. `rihla check` measures how long your zsh takes to start and names what it finds slow, one
line each with what to change. For example:

```
[info] zsh starts in 45 ms with your config
[info] oh-my-zsh loads its library and 3 plugin(s) at every start
       fix: keep only the plugins you use in plugins=(...)
[warn] zsh-autosuggestions asks zsh's completion when history has no match (...)
       fix: ZSH_AUTOSUGGEST_STRATEGY=(history) before the plugin loads
[info] .zshrc runs fastfetch at every zsh start, also in each tmux pane
       fix: run it only in a login shell ([[ -o login ]]), or not at all
```

It also says when powerlevel10k runs without its instant prompt, and when the history
file has more than 100,000 lines. rihla never edits your config.
