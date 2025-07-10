
# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

export ZSH="$HOME/.oh-my-zsh"

ZSH_THEME="robbyrussell"


# CASE_SENSITIVE="true"

HYPHEN_INSENSITIVE="true"

ENABLE_CORRECTION="true"

COMPLETION_WAITING_DOTS="true"



zstyle ':omz:plugins:nvm' lazy yes
  
plugins=(git nvm pnpm starship zsh-syntax-highlighting zsh-autosuggestions)

fpath+=${ZSH_CUSTOM:-${ZSH:-~/.oh-my-zsh}/custom}/plugins/zsh-completions/src
autoload -U compinit && compinit

source $ZSH/oh-my-zsh.sh


export EDITOR='nvim'



nvm alias default 22

alias ll='ls -al'
alias lg='lazygit'
alias ls='ls --color'
# apply prettier to all changed files 
alias prf='prettier --write $(git diff --name-only)'

. "$HOME/.local/bin/env"


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh


eval "$(starship init zsh)"

if [[ "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select" || \
      "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select-wrapped" ]]; then
    zle -N zle-keymap-select "";
fi

eval "$(starship init zsh)"
HISTSIZE=5000
HISTFILE=~/.zsh_history
SAVEHIST=$HISTSIZE
HISTDUP=erase
setopt appendhistory
setopt sharehistory
setopt hist_ignore_space
setopt hist_ignore_all_dups
setopt hist_save_no_dups
setopt hist_find_no_dups

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-Z}'

bindkey -v
