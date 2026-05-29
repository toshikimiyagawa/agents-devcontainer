# ==============================================================================
# History
# ==============================================================================
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt HIST_IGNORE_DUPS       # skip consecutive duplicates
setopt HIST_IGNORE_ALL_DUPS   # remove older duplicate entries
setopt HIST_IGNORE_SPACE      # skip commands starting with space
setopt HIST_REDUCE_BLANKS     # trim extra blanks
setopt SHARE_HISTORY          # share history across sessions
setopt INC_APPEND_HISTORY     # write immediately, not on exit

# ==============================================================================
# Directory navigation
# ==============================================================================
setopt AUTO_CD                # type directory name to cd
setopt AUTO_PUSHD             # push directories onto stack
setopt PUSHD_IGNORE_DUPS      # no duplicate dirs in stack
setopt PUSHD_SILENT           # suppress pushd output

# ==============================================================================
# Completion
# ==============================================================================
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'   # case-insensitive
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# ==============================================================================
# Key bindings
# ==============================================================================
bindkey -e                             # emacs keybindings
bindkey '^[[A' history-search-backward # up arrow: history search
bindkey '^[[B' history-search-forward  # down arrow: history search
bindkey '^[[1;5C' forward-word         # ctrl+right: word forward
bindkey '^[[1;5D' backward-word        # ctrl+left: word backward

# ==============================================================================
# Prompt — starship (Gruvbox Rainbow preset, see ~/.config/starship.toml)
# ==============================================================================
eval "$(starship init zsh)"

# ==============================================================================
# Aliases — general
# ==============================================================================
alias ls='ls --color=auto'
alias ll='ls -lhF --color=auto'
alias la='ls -lahF --color=auto'
alias grep='grep --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'
alias diff='diff --color=auto'
alias tree='tree -C'

# ==============================================================================
# Aliases — git
# ==============================================================================
alias g='git'
alias gs='git status -sb'
alias gl='git log --oneline --graph --decorate -20'
alias gla='git log --oneline --graph --decorate --all -20'
alias gd='git diff'
alias gds='git diff --staged'
alias ga='git add'
alias gc='git commit'
alias gco='git checkout'
alias gb='git branch -vv'
alias gp='git push'
alias gpl='git pull --rebase'
alias gst='git stash'
alias gstp='git stash pop'

# ==============================================================================
# Aliases — Python / project
# ==============================================================================
alias py='python3'
alias pip='pip3'
alias mkenv='python3 -m venv .venv && source .venv/bin/activate'
alias activate='source .venv/bin/activate'

# ==============================================================================
# Useful functions
# ==============================================================================

# cd then ls
cdl() { cd "$@" && ll; }

# mkdir then cd
mkcd() { mkdir -p "$1" && cd "$1"; }

# Quick grep through source files
src() { grep -rn "$1" --include="*.py" --include="*.ts" --include="*.js" .; }

# Show top 10 largest files/dirs
biggest() { du -ah "${1:-.}" | sort -rh | head -20; }

# ==============================================================================
# Editor
# ==============================================================================
export EDITOR=vim
export VISUAL=vim

# ==============================================================================
# PATH
# ==============================================================================
export PATH="$HOME/.local/bin:$PATH"

# ==============================================================================
# Miscellaneous
# ==============================================================================
setopt NO_BEEP                # silence all bells
setopt CORRECT                # suggest corrections for mistyped commands
export LESS='-R --quit-if-one-screen --no-init'
export LESSHISTFILE=/dev/null # don't save less history

# ==============================================================================
# gh auth — first-run hint
# ==============================================================================
if ! gh auth status >/dev/null 2>&1; then
  echo ""
  echo "  gh is not authenticated. Run the following to log in:"
  echo "  gh auth login -p https -h github.com -s repo,read:org -w"
  echo "  Your token will persist across rebuilds via the devcontainer-gh-* volume."
  echo ""
fi

# ==============================================================================
# tmux auto-start
# ==============================================================================
if [[ -z "$TMUX" ]]; then
  tmux new-session -A -s main -D
fi
