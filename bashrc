##
# bashrc
##

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

## Styling
# Shell: Read more about colourizing the shell here: https://linoxide.com/change-linux-shell-prompt-with-different-colors/
export PS1='\[\e[32m\u\] \[\e[36m\w\] \[\e[34m\]\[\e[1m\]$ \[\e[0m\]'
# Colourful ls commands
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias ip='ip -color=auto'

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
