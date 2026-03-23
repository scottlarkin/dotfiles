
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
# Optimize compinit - only check for updates once per day (faster startup)
autoload -U compinit
# Regenerate compdump if older than 24 hours, otherwise use cached version
if [[ -n ${HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

source $ZSH/oh-my-zsh.sh


export EDITOR='nvim'

# nvm alias default - only set once, not on every shell startup
# Run manually: nvm alias default 22

alias ll='ls -al'
alias lg='lazygit'
alias ls='ls --color'
# apply prettier to all changed files 
alias prf='prettier --write $(git diff --name-only)'
alias typos='cursor-agent "look at the diff between the current branch and the local dev branch and find any typos or silly mistakes. Look at file names too. Consider code conventions depending on the language used." -p'
alias typosfix='cursor-agent --force "look at the diff between the current branch and the local dev branch and find any typos or silly mistakes. Look at file names too. Consider code conventions depending on the language used. Fix any typos (ignore differences between US and british spelling)" -p'


alias commit='cursor-agent "look at my staged changes. come up with a clear and concise commit message and description output as json {commit:string; description:string;}. the commit message must be meaningful but no more than 6 words. the description must be less than 20 words" -p --model grok' 

. "$HOME/.local/bin/env"


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Initialize starship (only once - removed duplicate)
eval "$(starship init zsh)"

if [[ "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select" || \
      "${widgets[zle-keymap-select]#user:}" == "starship_zle-keymap-select-wrapped" ]]; then
    zle -N zle-keymap-select "";
fi
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

# pnpm - consolidated PATH addition
export PNPM_HOME="/Users/scottlarkin/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# Add homebrew pnpm if not already in PATH
[[ ":$PATH:" != *":/opt/homebrew/opt/pnpm@9/bin:"* ]] && export PATH="/opt/homebrew/opt/pnpm@9/bin:$PATH"

. "$HOME/.atuin/bin/env"

eval "$(atuin init zsh)"
export PATH="$HOME/.local/bin:$PATH"

# bun completions
[ -s "/Users/scottlarkin/.bun/_bun" ] && source "/Users/scottlarkin/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
