#!/usr/bin/bash

file_exists() (
    printf "File %s already exists\n" "#1"
    return 0
)

if ! command -v curl &> /dev/null; then
    printf "Curl was not found. Install curl before proceeding\n"
fi

if [ -f ~/.bashrc ]; then
    file_exists() ".bashrc"
else
    curl -o ~/.bashrc https://raw.githubusercontent.com/asiangoldfish/configspack/main/bashrc
fi

if [ -f ~/.nanorc ]; then
    file_exists() ".nanorc"
else
    curl -o ~/.nanorc https://raw.githubusercontent.com/asiangoldfish/configspack/main/nanorc
fi

if [ -f ~/.xinitrc ]; then
    file_exists() ".xinitrc"
else
    curl -o ~/.xinitrc https://raw.githubusercontent.com/asiangoldfish/configspack/main/xinitrc
fi

printf "Installation complete!\n"
