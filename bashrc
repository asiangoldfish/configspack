##
# bashrc
##

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

## Styling
# Shell: Read more about colourizing the shell here:
# https://www.luossfi.org/blog/2021/02/linux-colorful-bash-prompt/
GREEN='\[\e[92m\]' 
RED='\[\e[91m\]' 
CYAN='\[\e[96m\]' 
YELLOW='\[\e[93m\]' 
RESET='\[\e[0m\]' 
if [ "$(whoami)" = 'root' ] 
then
  PS1="${RESET}[${RED}\u${RESET}@${CYAN}\h ${YELLOW}\w${RESET}]\$ " 
else
  PS1="${RESET}[${GREEN}\u${RESET}@${CYAN}\h ${YELLOW}\w${RESET}]\$ " 
fi

# Colourful ls commands
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

## Autocompletion for sudo commands
# Code taken from https://stackoverflow.com/questions/45532320/human-friendly-bash-auto-completion-with-sudo
# Make sure that the file "/usr/share/bash-completion/bash_completion" exists.
if command -v sudo &> /dev/null; then complete -cf sudo; fi

## Git autocompletion
# Code taken from https://wiki.archlinux.org/title/Git#Bash_completion
if command -v git &>/dev/null; then
    if [ -f "/usr/share/git/completion/git-completion.bash" ]; then
        source "/usr/share/git/completion/git-completion.bash"
    elif [ -f "/usr/share/bash-completion/completions/git" ]; then
        source "/usr/share/bash-completion/completions/git"
    fi
fi

## Custom scripts or commands
# Create your custom commands here to change, improve or add new functionalities to your shell
if [ -d "$HOME/Scripts" ]; then
    PATH="$PATH:$HOME/Scripts"
fi

## Dotnet CLI autocomplete
if command -v dotnet &>/dev/null; then
    _dotnet_bash_complete() {
        local word=${COMP_WORDS[COMP_CWORD]}

        local completions
        completions="$(dotnet complete --position "${COMP_POINT}" "${COMP_LINE}" 2>/dev/null)"
        if [ $? -ne 0 ]; then
            completions=""
        fi

        COMPREPLY=("$(compgen -W "$completions" -- "$word")")
    }

    complete -f -F _dotnet_bash_complete dotnet
fi
