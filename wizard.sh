#!/usr/bin/bash

# Global variables
DEPS=( "jq" )                               # Dependencies

SCRIPT_NAME="$(basename $0)"
SCRIPT_PATH="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"             # This script's root directory
TMP="/tmp"                                  # Temporary directory path

NAME="configspack"                          # This application's name
VERSION="1.0.0"                             # Application version number

parser="$SCRIPT_PATH/scripts/parser.py"     # parse ini file

# include statements
source "$SCRIPT_PATH/scripts/setup.sh"
source "$SCRIPT_PATH/scripts/manage_configs.sh"


function dependency_check () {
    ### Description:    Ensures that all dependencies are present

    local missing_dependencies
    for dep in "${DEPS[@]}"; do command -v "$dep" &> /dev/null || missing_dependencies+=( "$dep" ); done

    # Quit if missing dependencies were found
    (( ${#missing_dependencies[@]} > 0 )) && printf "Missing dependencies were found:\n%s\n" "${missing_dependencies[@]}" && return 1 ||  return 0
}


function usage () {
    printf 'Version %s
Usage:  %s
        %s [OPTION]

Manage configuration files

Deploy or edit configuration files across the system. %s manages them from a single file,
making them portable between different UNIX and UNIX-like systems. The master configuration file is
read from the following locations:

- $XDG_CONFIG_HOME/configspack/config.ini
- $HOME/.configspack.ini
- /etc/configspack/config.ini
- $HOME/$SCRIPT_PATH/configs/config.ini

Option:
        --edit-configs      add, remove, edit configurations and entries
        --help              this page
' "$VERSION" "$SCRIPT_NAME" "$SCRIPT_NAME" "$SCRIPT_NAME"
}


function main () {
    ### Main menu

    # Attempts to find config read config file. The following is the order that it will look for the file:
    # 1. $XDG_CONFIG_HOME/configspack/config.ini
    # 2. $HOME/.configspack.ini
    # 3. /path/to/configspack/configs/config.ini
    
    config_order=(
        "$XDG_CONFIG_HOME/configspack/config.ini"
        "$HOME/.configspack.ini"
        "/etc/configspack/config.ini"
        "$SCRIPT_PATH/configs/config.ini"
    )
    
    # Read config file based on the order
    for file in "${config_order[@]}"; do
        if [ -f "$file" ]; then
            CONFIG="$file"
            break
        fi
    done
    
    # Raise error if no config file was found
    if [ -z "$CONFIG" ]; then
        printf "%s: Could not detect configuration file. For details about the file location, use \'%s --help\'\n" "$SCRIPT_NAME" "$SCRIPT_NAME"
        return 1
    fi
    
    # Gets a list of app names and assigns them to an array
    apps_list="$($parser --root-sections --file $CONFIG)"
    sorted_apps_str="${apps_list//[$'\t\r\n']/ }"
    
    IFS=' ' read -ra apps <<< "$sorted_apps_str"
    
    # Get all labels from config files to display them in the main menu screen
    local menu_entries=( "Edit dotfiles" "" )

    # Iterate all config files
    for app in "${apps[@]}"; do
        # Gets the dotfile description to display in the main menu
        local description="$($parser    --file $CONFIG\
                                        --value \
                                        --section $app \
                                        --key 'description')"

        # Assemble the main menu entries
        menu_entries+=( "$app" "$description" )
    done
    
    MENU="$(whiptail    --title "Configure Application" \
                        --menu "Select application to configure" \
                        --ok-button "Select" \
                        --cancel-button "Exit" \
                        10 70 3 \
                        "${menu_entries[@]}" \
                        3>&1 1>&2 2>&3 )"

    if [ "$?" = 1 ]; then cleanup; exit; fi
    
    # Go to edit dotfiles page if selected. Otherwise proceed with configuration
    [ "${MENU[0]}" = "${menu_entries[0]}" ] && edit_config || bash_setup "$MENU"
}

cleanup () {
    #if [ -d "$TMP" ]; then
    #    rm -r "$TMP"
    #fi
    :
}

for arg in "$@"; do
    case "$arg" in
        "--edit-configs") edit_configs; exit;;
        "--help") usage; exit;;
        *) printf "Invalid option: '%s'\nMore info with 'wizard.sh --help'\n" "$arg"; exit;;
    esac
    shift
done

# Checks for dependencies
dependency_check || exit

# Main loop
main
