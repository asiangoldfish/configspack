#!/usr/bin/bash

# Check for dependencies
DEPS=( "jq" )

SCRIPT_PATH="$(dirname "$0")"
TMP="/tmp"

CONFIGS_DIR="$SCRIPT_PATH/configs"
CONFIG_FILES=()  # List of all available config files

NAME="configspack"
VERSION="1.0.0"

# include statements
source "$SCRIPT_PATH/scripts/setup.sh"
source "$SCRIPT_PATH/scripts/manage_configs.sh"

function get_configs () {
    ### Description:    Gets all supported dotfiles based on the configuration files available
    ###                 The format should be as follows: dotfile.configs.json

    # List all elements in the configs directory
    for entry in "./configs"/*; do
        # Only consider the dotfile if it is a file
        if [ ! -f "$entry" ]; then continue; fi

        CONFIG_FILES+=( "$entry" )
    done
}

function dependency_check () {
    ### Description:    Ensures that all dependencies are present

    local missing_dependencies

    for dep in "${DEPS[@]}"; do
        command -v "$dep" &> /dev/null || missing_dependencies+=( "$dep" )
    done

    # Quit if missing dependencies were found
    if (( ${#missing_dependencies[@]} > 0 )); then echo "Missing dependencies were found:"; echo "${missing_dependencies[@]}"; exit 1; fi
}

function usage () {
    cat << EOF
$NAME, version $VERSION
Usage:  wizard.sh
        wizard.sh [option]
options:
        --edit-configs      add, remove, edit configurations and entries
        --help              this page
EOF
}

function edit_configs () {
    local menu
    menu="$(whiptail    --title "Configuration Menu" \
                        --menu "Select application to configure" \
                        10 70 3 \
                        "Edit" "" \
                        "Add" "" \
                        "Remove" "" \
                        3>&1 1>&2 2>&3 )"

    exitstatus="$?"
    if [ "$exitstatus" = 1 ]; then exit; fi

    local menu_options
    mapfile -t menu_options <<< "${menu[@]}"
    
    unset menu

    for option in "${menu_options[@]}"; do
        case "$option" in 
            "Edit") edit_config;;
            "Add") add_config;;
            "Remove") remove_config;;
        esac
    done

    unset menu_options option exitstatus menu

    exit
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
    local menu_entries

    # Iterate all config files
    for config in "${CONFIG_FILES[@]}"; do
        # Gets the filepath from JSON config
        local dotfile
        dotfile="$(cat $config | jq -r '.dotfile')"

        # Gets the dotfile description to display in the main menu
        local description
        description="$(cat "$config" | jq -r '.description')"

        # Assemble the main menu entries
        menu_entries+=( "$dotfile" )
        menu_entries+=( "         $description" )
    done

    MENU="$(whiptail    --title "Configure Application" \
                        --menu "Select application to configure" \
                        10 70 3 \
                        "${menu_entries[@]}" \
                        3>&1 1>&2 2>&3 )"

    exitstatus="$?"
    if [ "$exitstatus" = 1 ]; then cleanup; exit; fi

    # Open the selected menu
    bash_setup "$HOME/$MENU"
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

dependency_check
main
