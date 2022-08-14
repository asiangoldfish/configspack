#!/usr/bin/bash

# Global variables
DEPS=( "jq" )                               # Dependencies

SCRIPT_NAME="$(basename $0)"
SCRIPT_PATH="$(cd $(dirname "${BASH_SOURCE[0]}") && pwd)"             # This script's root directory
TMP="$HOME/.cache/configspack"                          # Temporary directory path

NAME="configspack"                          # This application's name
VERSION="1.0.0"                             # Application version number

AFFECTED_DOTFILES=""                        # Dotfiles to apply changes to

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
        "$HOME/.configspack/config.ini"
        "/etc/configspack/config.ini"
        "$SCRIPT_PATH/configs/config.ini"
    )
    
    # Read config file based on the order
    # If a file has been found, then create a copy of it to be used throughout
    # the application runtime
    # If no files were found, then exit the application
    if [ -z "$ORIGINAL_CONFIG" ]; then
        for file in "${config_order[@]}"; do
            if [ -f "$file" ]; then
                ORIGINAL_CONFIG="$file"
                CONFIG="$TMP/config.ini"

                # Validate all application filepaths in the config file
                validate_filepaths
    
                if [ ! -d "$TMP" ]; then mkdir "$TMP"; fi
                    cp "$ORIGINAL_CONFIG" "$CONFIG"
                break
            fi
        done
    fi

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
        if [[ "$app" =~ [Dd]'efault' ]]; then continue; fi
        # Gets the dotfile description to display in the main menu
        local description="$($parser    --file $CONFIG\
                                        --value \
                                        --section $app \
                                        --key description)"

        # Assemble the main menu entries
        menu_entries+=( "$app" "$description" )
    done
    
    MENU="$(whiptail    --title "Configure Application" \
                        --menu "Select application to configure" \
                        --ok-button "Select" \
                        --cancel-button "Save Changes" \
                        10 70 3 \
                        "${menu_entries[@]}" \
                        3>&1 1>&2 2>&3 )"

    if [ "$?" = 1 ]; then save_changes; exit; fi
    
    # Go to edit dotfiles page if selected. Otherwise proceed with configuration
    [ "${MENU[0]}" = "${menu_entries[0]}" ] && edit_config || bash_setup "$MENU"
}

cleanup () {
    # Cleans up all temporary files that this program has created
    if [ -d "$TMP" ]; then
        rm -r "$TMP"
    fi
}

function update_dotfile() {
    # Applies changes to a named dotfile
    local app_name="$1"
    local backup_files="$2"
    local filepath="$($parser       --value \
                                    --file $CONFIG \
                                    --section $app_name \
                                    --key filepath)"

    # Backup dotfiles before creating new ones
    if [ "$backup_files" == "True" ] && [ -f "$filepath" ]; then
        cp "$filepath" "$TMP/$app_name".conf
    fi

    # TODO - Apply changes to dotfiles
    rm "$filepath" &> /dev/null
    touch "$filepath"

    # Add template if this applies
    template_filepath="$($parser    --value \
                                    --file $CONFIG \
                                    --section $app_name \
                                    --key template)"

    if [ ! -z "$template_filepath" ]; then cat "$template_filepath" > "$filepath"; fi

    local features="$($parser       --search-section \
                                    --file $CONFIG \
                                    --section $app_name/ \
                                    --new-line True | \
                                    awk -F/ '{ if ($3 != "") { print } }' | \
                                    awk NF)"                    # print only non-empty lines

    features="$(echo "$features" | tr '\n' ' ' )"
    IFS=" " read -ra features_list <<< "$features"

    # Copy code snippets into the named dotfile
    for feature in "${features_list[@]}"; do
        $parser     --value\
                    --file $CONFIG \
                    --section $feature \
                    --key snippet >> "$filepath"
        printf '\n' >> "$filepath"
    done
}

function validate_filepaths() {
    # Validates all file paths found in the config file
    
    local roots IFS invalid_filepaths root_sections root path
    
    roots="$($parser    --root-sections \
                        --file $ORIGINAL_CONFIG \
                        --new-line False)"

    IFS=' ' read -ra root_sections <<< "$roots"

    invalid_filepaths=()

    # Finds the filepath for each file
    for root in "${root_sections[@]}"; do
        # Ignore Default section
        if [[ "$root" =~ [Dd]'efault' ]]; then continue; fi
        filepath="$($parser --value \
                            --file $ORIGINAL_CONFIG \
                            --section $root \
                            --key filepath)"
            
    done

    if [[ "${#invalid_filepaths[@]}" -gt 0 ]]; then
        printf "$SCRIPT_NAME: The following applications' configuration file do not have a valid path:\n\n"
        
        for path in "${invalid_filepaths[@]}"; do printf "$path\n"; done
        exit
    fi
}

function save_changes() {
    # If the user has made any changes, then save and overwrite affected dot files
    
    local file_path

    # Checks if any changes actually were made
    diff $CONFIG $ORIGINAL_CONFIG > /dev/null; if [ "$(echo $?)" == 0 ]; then exit; fi

    # Finds files affected and applies changes to them
    roots="$($parser                    --root-sections \
                                        --file $CONFIG \
                                        --new-line False)"
    
    IFS=' ' read -ra root_sections <<< "$roots"
    
    invalid_filepaths=()

    # prepare for backing up files
    # create .cache if it does not exist
    backup_files="$($parser --value \
                            --file $CONFIG \
                            --section Default \
                            --key backup_files)"

    # checks for invalid filepaths
    for file in "${AFFECTED_DOTFILES[@]}"; do
        if [ -z "$file" ]; then continue; fi

        for root in "${root_sections[@]}"; do
            if [[ "$root" =~ [Dd]'efault' ]]; then continue; fi
            if [ "$file" == "$root" ]; then update_dotfile "$file" "$backup_files"; fi
        done
    done
    
    unset backup_files
    #cleanup
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
