# rihla's shell layer for fish: what shell/zsh.rc gives zsh. fish brings autosuggestions,
# syntax highlighting and completions itself; this adds rihla's colours, prompt, the fzf
# keys, zoxide and the rg/fd defaults with rgi and ff.
#
# Used only inside rihla's tmux, after `rihla shell --fish`: tmux starts fish with
#   fish -C 'source <this file>'
# so it runs after your own config.fish and conf.d. Nothing is written to your fish
# config. Each piece is skipped when you already have one (a fish_prompt of your own, fzf
# key bindings, z). Turn pieces off with RIHLA_SHELL_NO="prompt zoxide" as for zsh.

status is-interactive; or return 0
set -q rihla_shell_loaded; and return 0
set -g rihla_shell_loaded 1
set -g rihla_shell_on
set -g rihla_shell_skipped

set -l here (path dirname (path resolve (status filename)))/..
set here (path normalize $here)
set -l tools $HOME/.local/share/rihla-tools/shell
set -q XDG_DATA_HOME; and set tools $XDG_DATA_HOME/rihla-tools/shell
set -q RIHLA_TOOLS; and set tools $RIHLA_TOOLS/shell
set -l state $HOME/.local/state/rihla/shell
set -q XDG_STATE_HOME; and set state $XDG_STATE_HOME/rihla/shell
set -l cfg $HOME/.config/rihla
set -q XDG_CONFIG_HOME; and set cfg $XDG_CONFIG_HOME/rihla
set -q RIHLA_CONFIG; and set cfg $RIHLA_CONFIG
set -l no (string split ' ' -- "$RIHLA_SHELL_NO")
set -l icons ascii
if set -q RIHLA_ICONS
    set icons $RIHLA_ICONS
else if test -r $cfg/icons
    read -l m <$cfg/icons
    set icons (string trim -- $m)
end
test "$icons" = nerd; or set icons ascii

# A program's setup text, kept in a file while it is newer than the program and this file
# (starting fzf, zoxide and starship in every new shell costs more than the rest).
set -g __rihla_self (status filename)
function __rihla_cached --argument-names file prog
    if test -s $file -a $file -nt $prog -a $file -nt $__rihla_self
        read -l line <$file
        test "$line" = "# rihla cache: $prog"; and return 0
    end
    set -l out ($argv[3..] 2>/dev/null | string collect)
    test -n "$out"; or return 1
    mkdir -p (path dirname $file) 2>/dev/null
    printf '# rihla cache: %s\n%s\n' $prog $out >$file.$fish_pid 2>/dev/null
    and command mv -f $file.$fish_pid $file 2>/dev/null
end

# ------------------------------------------------------------ colours and greeting
# Catppuccin Mocha, as in rihla's tmux bar, nvim and the zsh layer.
if not contains colours $no
    set -g fish_greeting
    set -g fish_color_command a6e3a1
    set -g fish_color_keyword cba6f7
    set -g fish_color_quote f9e2af
    set -g fish_color_redirection 94e2d5
    set -g fish_color_end 94e2d5
    set -g fish_color_error f38ba8
    set -g fish_color_param cdd6f4
    set -g fish_color_option 89b4fa
    set -g fish_color_comment 6c7086
    set -g fish_color_operator fab387
    set -g fish_color_escape fab387
    set -g fish_color_autosuggestion 6c7086
    set -g fish_color_valid_path --underline
    set -g fish_pager_color_prefix cba6f7
    set -g fish_pager_color_progress 6c7086
    set -g fish_pager_color_description 6c7086
    set -g fish_color_search_match --background=313244
    set -g fish_color_selection --background=313244
    set -a rihla_shell_on colours
end

# ------------------------------------------------------------ search: rg, fd, rgi, ff
set -l fd
command -q fd; and set fd fd
test -z "$fd"; and command -q fdfind; and set fd fdfind
set -l fdo
test -n "$fd"; and set fdo --hidden --follow --ignore-file $here/fdignore
if contains search $no
    set -a rihla_shell_skipped search:RIHLA_SHELL_NO
else
    if not set -q RIPGREP_CONFIG_PATH; and test -r $here/ripgreprc
        set -gx RIPGREP_CONFIG_PATH $here/ripgreprc
    end
    if test -n "$fd"; and not functions -q $fd
        function $fd --inherit-variable fd --inherit-variable fdo --wraps $fd
            command $fd $fdo $argv
        end
    end
    for n in rgi ff fdi
        functions -q $n; or command -q $n; and continue
        set -l script $here/bin/(string replace fdi ff -- $n)
        function $n --inherit-variable script
            sh $script $argv
        end
    end
    set -a rihla_shell_on search
end

# ------------------------------------------------------------ fzf
if contains fzf $no
    set -a rihla_shell_skipped fzf:RIHLA_SHELL_NO
else if bind \cr 2>/dev/null | string match -q '*fzf*'
    # Ctrl-R already runs fzf (fzf_key_bindings in your config). A packaged
    # fzf_key_bindings function that nothing calls does not count.
    set -a rihla_shell_skipped fzf:yours
else if command -q fzf; and __rihla_cached $state/init/fzf.fish (command -s fzf) fzf --fish
    if not set -q FZF_DEFAULT_OPTS; and not set -q FZF_DEFAULT_OPTS_FILE
        set -gx FZF_DEFAULT_OPTS "--height=50% --min-height=12 --layout=reverse --border=rounded --info=inline --color=bg+:#313244,spinner:#f5e0dc,hl:#f38ba8,fg:#cdd6f4,header:#f38ba8,info:#cba6f7,pointer:#cba6f7,marker:#a6e3a1,fg+:#cdd6f4,prompt:#cba6f7,hl+:#f38ba8,border:#6c7086"
    end
    if test -n "$fd"
        set -q FZF_DEFAULT_COMMAND; or set -gx FZF_DEFAULT_COMMAND "$fd --type f $fdo"
        set -q FZF_CTRL_T_COMMAND; or set -gx FZF_CTRL_T_COMMAND "$fd $fdo"
        set -q FZF_ALT_C_COMMAND; or set -gx FZF_ALT_C_COMMAND "$fd --type d $fdo"
    end
    set -l p "--height=80% --preview 'sh $here/bin/preview {}' --preview-window 'right,55%,border-left,<100(down,50%,border-top)'"
    set -q FZF_CTRL_T_OPTS; or set -gx FZF_CTRL_T_OPTS $p
    set -q FZF_ALT_C_OPTS; or set -gx FZF_ALT_C_OPTS $p
    source $state/init/fzf.fish
    set -a rihla_shell_on fzf
else
    set -a rihla_shell_skipped "fzf:no fzf 0.48+ on PATH"
end

# ------------------------------------------------------------ zoxide
set -l zo (command -s zoxide)
test -z "$zo"; and test -x $tools/bin/zoxide; and set zo $tools/bin/zoxide
if contains zoxide $no
    set -a rihla_shell_skipped zoxide:RIHLA_SHELL_NO
else if functions -q __zoxide_z; or functions -q z
    set -a rihla_shell_skipped "zoxide:yours (z is already defined)"
else if test -n "$zo"; and __rihla_cached $state/init/zoxide.fish $zo $zo init fish
    set -q _ZO_DATA_DIR; or set -gx _ZO_DATA_DIR $state/zoxide
    test -d $_ZO_DATA_DIR; or mkdir -p $_ZO_DATA_DIR 2>/dev/null
    # zoxide's functions call `command zoxide`; rihla's copy is not on PATH.
    string replace -a 'command zoxide' (string escape -- $zo) <$state/init/zoxide.fish | source
    set -a rihla_shell_on zoxide
else
    set -a rihla_shell_skipped "zoxide:not installed"
end

# ------------------------------------------------------------ prompt
# A fish_prompt of your own (a function file in your fish config) wins.
set -l ss (command -s starship)
test -z "$ss"; and test -x $tools/bin/starship; and set ss $tools/bin/starship
if contains prompt $no
    set -a rihla_shell_skipped prompt:RIHLA_SHELL_NO
else if functions -q fish_prompt; and not string match -q '*/share/fish/functions/fish_prompt.fish' -- (functions --details fish_prompt); and not string match -q 'embedded:*' -- (functions --details fish_prompt)
    set -a rihla_shell_skipped "prompt:your own fish_prompt"
else if test -n "$ss"; and begin
        # Before starship first runs: it writes a log directory there (else ~/.cache).
        set -q STARSHIP_CACHE; or set -gx STARSHIP_CACHE $state/starship
        __rihla_cached $state/init/starship.fish $ss $ss init fish --print-full-init
    end
    # rihla's own config, also when inherited from the shell that started tmux.
    if not set -q STARSHIP_CONFIG; or string match -q -- "$here/starship-*.toml" $STARSHIP_CONFIG; or string match -q -- "$state/init/starship-*-async.toml" $STARSHIP_CONFIG
        set -l mine $HOME/.config/starship.toml
        set -q XDG_CONFIG_HOME; and set mine $XDG_CONFIG_HOME/starship.toml
        if test -f $mine
            set -gx STARSHIP_CONFIG $mine
        else
            set -gx STARSHIP_CONFIG $here/starship-$icons.toml
        end
    end
    set -e RIHLA_GIT_STATUS
    source $state/init/starship.fish
    set -a rihla_shell_on prompt:starship
else
    # The directory in a blue block, the branch in mauve, a green or red arrow.
    function fish_prompt
        set -l s $status
        set -l b (command git symbolic-ref --short HEAD 2>/dev/null)
        set_color 11111b -b 89b4fa; printf ' %s ' (prompt_pwd); set_color normal
        test -n "$b"; and set_color cba6f7; and printf ' on %s' $b
        if test $s -eq 0; set_color a6e3a1; else; set_color f38ba8; end
        printf ' > '; set_color normal
    end
    set -a rihla_shell_on prompt:fish
end

functions --erase __rihla_cached
set --erase __rihla_self
