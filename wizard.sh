#!/usr/bin/bash

# Global variables
DEPS=( "jq" )                               # Dependencies

SCRIPT_PATH="$(dirname "$0")"               # This script's root directory
TMP="/tmp"                                  # Temporary directory path

CONFIGS_DIR="$SCRIPT_PATH/configs"          # Where all configs are stored at
CONFIG_FILES=()                             # List of all available config files

NAME="configspack"                          # This application's name
VERSION="1.0.0"                             # Application version number

# include statements
source "$SCRIPT_PATH/scripts/setup.sh"
source "$SCRIPT_PATH/scripts/manage_configs.sh"

function get_configs () {
    ### Description:    Gets all supported dotfiles based on the configuration files available
    ###                 The format should be as follows: dotfile.configs.json

    for entry in "./configs"/*; do
        [ ! -f "$entry" ] && continue || CONFIG_FILES+=( "$entry" )
    done
}

function dependency_check () {
    ### Description:    Ensures that all dependencies are present

    local missing_dependencies
    for dep in "${DEPS[@]}"; do command -v "$dep" &> /dev/null || missing_dependencies+=( "$dep" ); done

    # Quit if missing dependencies were found
    (( ${#missing_dependencies[@]} > 0 )) && printf "Missing dependencies were found:\n%s\n" "${missing_dependencies[@]}" && return 1 ||  return 0
}

function usage () {
    cat << EOF
$NAME, version $VERSION
Usage:  wizard.sh
        wizard.sh [Option]
Options:
        --edit-configs      add, remove, edit configurations and entries
        --help              this page
EOF
}

# Fetches all config files
get_configs

function main () {
    ### Main menu

    # Creates a tmp directory if it doesn't already exist
    # if [ ! -d "./tmp" ]; then mkdir "./tmp"; fi

    # TODO - Write a better error message. Maybe create a manpage or help page to direct the user to?
    # Return an error message if no JSON config files were found
    if (( ${#CONFIG_FILES[@]} == 0 )); then echo "Could not find any configuration files"; exit 1; fi

    # Get all labels from config files to display them in the main menu screen
    local menu_entries=( "Edit dotfiles" "" )

    # Iterate all config files
    for config in "${CONFIG_FILES[@]}"; do
        # Gets the filepath from JSON config
        local dotfile="$(cat $config | jq -r '.dotfile')"

        # Gets the dotfile description to display in the main menu
        local description="$(cat "$config" | jq -r '.description')"

        # Assemble the main menu entries
        menu_entries+=( "$dotfile" "         $description" )
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
    [ "${MENU[0]}" = "${menu_entries[0]}" ] && edit_config || bash_setup "$HOME/$MENU"
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
