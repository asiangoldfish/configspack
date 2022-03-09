## Customize your Bash shell here!

## Styling
# Shell: Read more about colourizing the shell here: https://linoxide.com/change-linux-shell-prompt-with-different-colors/
export PS1='\[\e[32m\u\] \[\e[36m\w\] \[\e[34m\]\[\e[1m\]$ \[\e[0m\]'
# Colourful ls commands
alias ls="ls --color=auto"
alias grep = "grep --color=auto"
alias ip="ip -color=auto"
export LESS="-R --use-color -Db+r$Du+b"
export MANPAGER="less -R --use-color -Dd+r -Du+b"


## Autocompletion for sudo commands
# Code taken from https://stackoverflow.com/questions/45532320/human-friendly-bash-auto-completion-with-sudo
# Make sure that the file "/usr/share/bash-completion/bash_completion" exists.
complete -cf sudo || printf "Sudo commands are not available. To disable this, comment this line out in "$HOME/.bashrc"\n"

## Git autocompletion
# Code taken from https://wiki.archlinux.org/title/Git#Bash_completion
if command -v git &> /dev/null; then
    if [ -f "/usr/share/git/completion/git-completion.bash" ]; then
        source "/usr/share/git/completion/git-completion.bash"
    elif [ -f "/usr/share/bash-completion/completions/git" ]; then
        source "/usr/share/bash-completion/completions/git"
    fi
fi

## Custom scripts or commands
# Create your custom commands here to change, improve or add new functionalities to your shell
if [ -d $HOME/Scripts ]; then
    PATH=$PATH:$HOME/Scripts
fi
