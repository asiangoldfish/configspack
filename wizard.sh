#!/usr/bin/bash

# Check for dependencies
DEPS=( "jq" )

SCRIPT_PATH="$(dirname "$0")"
TMP="$SCRIPT_PATH/tmp"

CONFIGS_DIR="$SCRIPT_PATH/configs"
CONFIG_FILES=()  # List of all available config files

# include statements
source "$SCRIPT_PATH/nano/setup.sh"
source "$SCRIPT_PATH/bash/setup.sh"

function get_configs () {
    ### Gets all supported dotfiles based on the configuration files available
    ### The format should be as follows: dotfile.configs.json

    # List all elements in the configs directory
    for entry in "./configs"/*; do
        # Only consider the dotfile if it is a file
        if [ ! -f "$entry" ]; then continue; fi

        CONFIG_FILES+=( "$entry" )
    done
}

function dependency_check () {
    missing_dependencies=()

    for dep in "${DEPS[@]}"; do
        command -v "$dep" &> /dev/null || missing_dependencies+=( "$dep" )
    done

    printf "%s" "${missing_dependencies[@]}"

    # Quit if missing dependencies were found
    if (( ${#missing_dependencies[@]} > 0 )); then echo "Missing dependencies were found:"; echo "${missing_dependencies[@]}"; exit 1; fi
}

    # TODO - Find a more elegant solution to append all config files to the CONFIG_FILES array
    get_configs

function get_all_labels () {
    ### Gets all application name and description from each JSON config file and return them
    ### as a string that is recognized by whiptail as menu entries
    local combined=()

    # Iterate all config files
    for config in "${CONFIG_FILES[@]}"; do
        local app
        app="$(cat $config | jq -r '.app')"
        local description
        description="$(cat $config | jq -r '.description')"
        combined+=( "$app" )
        combined+=( "$description" )
    done

    # Return
    echo "${combined[@]}"
}

function main () {
    # Creates a tmp directory if it doesn't already exist
    # if [ ! -d "./tmp" ]; then mkdir "./tmp"; fi

    # TODO - Write a better error message. Maybe create a manpage or help page to direct the user to?
    # Return an error message if no JSON config files were found
    if (( ${#CONFIG_FILES[@]} == 0 )); then echo "Could not find any configuration files"; exit 1; fi

    # Get all labels from config files to display them in the main menu screen
    local menu_entries

    # Iterate all config files
    for config in "${CONFIG_FILES[@]}"; do
        local dotfile
        dotfile="$(cat $config | jq -r '.dotfile')"
        local description
        description="$(cat $config | jq -r '.description')"
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
    bash_setup "dotfile=$MENU"
}

cleanup () {
    if [ -d "$TMP" ]; then
        rm -r "$TMP"
    fi
}

function foobar () {
    MENU="$(whiptail    --title "Configure Application" \
                        --menu "Select application to configure" \
                        10 70 3 \
                        "Hello" "world" \
                        3>&1 1>&2 2>&3 )"

    exitstatus="$?"

    if [ "$exitstatus" = 1 ]; then exit; fi
} 

main
#dependency_check
