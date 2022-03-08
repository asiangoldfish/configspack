#!/usr/bin/bash

if ! command -v curl &> /dev/null; then
    printf "Curl was not found. Install curl before proceeding\n"
fi

if [ -f ~/.bashrc ]; then
    read -p "File .bashrc already exists. Overwrite? [y/n]" yn

    case $yn in
        y )
            curl -o https://raw.githubusercontent.com/asiangoldfish/configspack/main/bashrc ~/.bashrc
            ;;
        * )
            printf "Skipping .bashrc\n"
            ;;
    esac
else
    curl -o https://raw.githubusercontent.com/asiangoldfish/configspack/main/bashrc ~/.bashrc

fi

if [ -f ~/.nanorc ]; then
    read -p "File .nanorc already exists. Overwrite? [y/n]" yn

    case $yn in
        y )
            curl -o https://raw.githubusercontent.com/asiangoldfish/configspack/main/nanorc ~/.nanorc
            ;;
        * )
            printf "Skipping .nanorc\n"
            ;;
    esac
else
    curl -o https://raw.githubusercontent.com/asiangoldfish/configspack/main/nanorc ~/.nanorc

fi

printf "Installation complete!\n"