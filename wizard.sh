#!/usr/bin/bash

SCRIPT_PATH="$(dirname "$0")"
TMP="$SCRIPT_PATH/tmp"
NANORC="./hello.sh"
BASHRC="./bashrc_test.sh"

# include statements
source "$SCRIPT_PATH/nano/setup.sh"
source "$SCRIPT_PATH/bash/setup.sh"

main () {
    # Creates a tmp directory if it doesn't already exist
    if [ ! -d "./tmp" ]; then
        mkdir "./tmp"
    fi

    MENU="$(whiptail --title "Configure Application" --menu "Select application to configure" 10 70 3 \
    "Nano" "GNU Nano Text Editor" \
    "Bash" "Bourne-Again Shell" 3>&1 1>&2 2>&3 )"

    mapfile -t menu_options <<< "$MENU"

    for option in "${menu_options[@]}"; do
        case "$option" in
            "Nano")
                nano_setup
                ;;
            
            "Bash")
                bash_setup
                ;;
        esac
    done

    exitstatus="$?"
    if [ "$exitstatus" = 0 ]; then
        exit
    fi
}

cleanup () {
    if [ -d $TMP ]; then
        rm -r "$TMP"
    fi
}

main
#nano_setup
