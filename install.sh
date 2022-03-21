#!/usr/bin/bash

if ! command -v curl &> /dev/null; then
    printf "Curl was not found. Install curl before proceeding\n"
fi

if [ -f ~/.bashrc ]; then
    printf "Skipping .bashrc\n"
else
    curl -o ~/.bashrc https://raw.githubusercontent.com/asiangoldfish/configspack/main/bashrc
fi

if [ -f ~/.nanorc ]; then
    printf "Skipping .nanorc\n"
else
    curl -o ~/.nanorc https://raw.githubusercontent.com/asiangoldfish/configspack/main/nanorc
fi

if [ -f ~/.xinitrc ]; then
    printf "Skipping .xinitrc\n"
else
    curl -o ~/.xinitrc https://raw.githubusercontent.com/asiangoldfish/configspack/main/xinitrc
fi

printf "Installation complete!\n"
