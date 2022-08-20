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
    echo -n "Version $VERSION
Usage:  $SCRIPT_NAME
        $SCRIPT_NAME [OPTION]

Manage configuration files

Deploy or edit configuration files across the system. $SCRIPT_NAME manages them from a
single file, making them portable between different UNIX and UNIX-like systems.

Option:
        --edit-configs      add, remove, edit configurations and entries
        --help              this page
        --save [apps]       apply settings from master configuration file to named
                            applications
        --save-all          apply settings from master configuration file to all
                            applications

Master configuration file location in order of priority:

\$XDG_CONFIG_HOME/configspack/config.ini
\$HOME/.configspack/config.ini
/etc/configspack/config.ini
[path/to/script]/configs/config.ini

Exit codes:
0   if OK,
2   if --save was used with invalid arguments. Arguments must correspond to
    an applciation name, according to the master configuration file
8   if master configuration file has syntax errors
"
}


function main () {
    ### Main menu

    # Attempts to find config read config file. The following is the order that it will look for the file:
    # 1. $XDG_CONFIG_HOME/configspack/config.ini
    # 2. $HOME/.configspack.ini
    # 3. /path/to/configspack/configs/config.ini
    
    validate_config

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

    if [ "$?" = 1 ]; then save_changes; exit 0; fi
    
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

    if [ ! -z "$template_filepath" ]; then
        if [ ! -f "$template_filepath" ]; then
            echo "$SCRIPT_NAME: Could not find template file path $template_filepath."
            exit 1
        fi
        
        cat "$template_filepath" > "$filepath";
    fi

    local features="$($parser       --search-section \
                                    --file $CONFIG \
                                    --section $app_name/ \
                                    --new-line True)"

    features="$(echo "$features" | tr '\n' ' ' )"
    IFS=" " read -ra features_list <<< "$features"

    # Copy code snippets into the named dotfile only if enabled
    for feature in "${features_list[@]}"; do
        # Ensures that only the features are included, not categories
        IFS='/' read -ra feature_validate <<< "$feature"
        if [ "${feature_validate[2]}" == '' ]; then continue; fi

        is_checked="$($parser   --value \
                                --file $CONFIG \
                                --section $feature \
                                --key checked)"

        if [ "$is_checked" == 'ON' ]; then
            echo -e "$($parser     --value\
                        --file $CONFIG \
                        --section $feature \
                        --key snippet)" >> "$filepath"
            printf '\n' >> "$filepath"
        fi
    done
}

function validate_config() {
    # Validates the master configuration file
    #
    # Returns:
    #   0: success
    #   8: validation failed with syntax errors

    # Read config file based on the order
    # If a file has been found, then create a copy of it to be used throughout
    # the application runtime
    # If no files were found, then exit the application

    config_order=(
        "$XDG_CONFIG_HOME/configspack/config.ini"
        "$HOME/.configspack/config.ini"
        "/etc/configspack/config.ini"
        "$SCRIPT_PATH/configs/config.ini"
    )
    
    if [ -z "$ORIGINAL_CONFIG" ]; then
        for file in "${config_order[@]}"; do
            if [ -f "$file" ]; then
                ORIGINAL_CONFIG="$file"
                CONFIG="$TMP/config.ini"
                
                # Validates the configuration file and outputs the error message
                # if debug mode is activated
                $parser --validate-config --file "$ORIGINAL_CONFIG"
                local parser_exitcode="$?"

                if [ "$parser_exitcode" != 0 ]; then exit "$parser_exitcode"; fi
                
                # Validate all application filepaths in the config file
                validate_filepaths
                
                # creates a copy of the master config that the user will edit
                if [ ! -d "$TMP" ]; then mkdir "$TMP"; fi
                    cp "$ORIGINAL_CONFIG" "$CONFIG"
                break
            fi
        done
    fi

    # Raise error if no config file was found
    if [ -z "$CONFIG" ]; then
        echo -n "$SCRIPT_NAME: Could not detect master configuration file.
        For details about file location, use '$SCRIPT_NAME --help'"
        return 1
    fi
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

function direct_save() {
    # Configure all or named application based on the master configuration file

    validate_config

    # Validate app
    local root_sections="$($parser  --root-sections \
                                    --file $ORIGINAL_CONFIG \
                                    --new-line False)"
    local roots
    IFS=' ' read -ra roots <<< "$root_sections"

    local section
    for section in "${roots[@]}"; do
        if [[ "$section" =~ [Dd]'efault' ]]; then continue; fi
        app_names+=( "$($parser --value \
                                --file $ORIGINAL_CONFIG \
                                --section $section \
                                --key app)" )
    done

    local apps
    # Checks if SAVE_ALL or SAVE_APP is enabled
    if [ ! -z "$SAVE_APPS" ]; then
        IFS=' ' read -ra save_apps <<< "$SAVE_APPS"
    elif [ ! -z "$SAVE_ALL" ]; then
        local app
        for app in "${app_names[@]}"; do save_apps+=( "$app" ); done
    fi

    # Matches app name and sections in master config. If they don't match,
    # then throw an error back to the user
    unset app; local app
    for arg in "${save_apps[@]}"; do
        if [[ "$arg" =~ [Dd]'efault' ]] || [ "$arg" == "--save" ]; then continue; fi
        for app in "${app_names[@]}"; do
            if [ "$arg" == "$app" ]; then
                continue 2
            fi
        done

        invalid_apps+=( "$arg" )                # App was not found
    done
    unset app

    # Report back to user if invalid apps were found
    if [ ! -z "$invalid_apps" ]; then
        echo -e "The following apps could not be recognized:\n"
        for app in "${invalid_apps[@]}"; do
            echo "$app"
        done
        echo -e "\nPlease make sure to match the section names of the master configuration file.
Look for exit code 2 after using \'$SCRIPT_PATH --help\' for more
info."
        exit 1
    fi

    echo "Setting up configurations..."

    local get_options options option
    # Save to files
    for app in "${save_apps[@]}"; do
        if [[ "$app" =~ [Dd]'efault' ]] || [ "$app" == "--save" ]; then continue; fi

        printf "Saving $app\'s configuration\n"

        get_options="$($parser  --search-section \
                                --file "$ORIGINAL_CONFIG" \
                                --section "$app/")"

        IFS=' ' read -ra options <<< "$(echo $get_options | \
                                        sed '$!N; /^\(.*\)\n\1$/!P; D' | \
                                        sed '/^$/d')"
        
        # Create new file and apply templates to the file
        local file="$($parser   --value \
                                --file "$ORIGINAL_CONFIG" \
                                --section "$app" \
                                --key filepath)"

        local template_path="$($parser      --value \
                                            --file "$ORIGINAL_CONFIG" \
                                            --section "$app" \
                                            --key 'template')"

        if [ ! -f "$template_path" ]; then
            echo "$SCRIPT_NAME: Could not find template path: $template_path"
            echo "Please change the template path for application $app"
            exit 1
        fi

        cat "$template_path" > "$file"

        for option in "${options[@]}"; do
            # Filters the option to remove application and categories name
            IFS='/' read -ra checked_verify <<< "$option"
            filtered_option="$( echo "${checked_verify[@]}" | \
                                awk '{print $3}')"
            
            # Skip empty lines
            if [ -z "$filtered_option" ]; then continue; fi

            # If this option is checked, then include this feature
            local checked="$($parser    --value \
                                        --file $ORIGINAL_CONFIG \
                                        --section $option \
                                        --key checked)"
            
            if [ "$checked" == 'ON' ]; then
                snippet="$($parser  --value \
                                    --file "$ORIGINAL_CONFIG" \
                                    --section "$option" \
                                    --key 'snippet')"
                echo -e "$snippet\n" >> "$file"
            fi
        done

    done
    unset get_options options option

    echo "Configuration setups complete!"
    
    # Assume that the saving was complete
    exit 0
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
            if [ "$file" == "$root" ]; then echo "$file"; update_dotfile "$file" "$backup_files"; fi
        done
    done
    
    unset backup_files

    # update the original config file with the new one
    cp "$CONFIG" "$ORIGINAL_CONFIG" || { printf echo "$SCRIPT_NAME: Could not update the configuration file with new settings"; exit; }
    #cleanup
}

i=0
for arg in "$@"; do
    case "$arg" in
        '--edit-configs') edit_configs; exit;;
        '--save') SAVE_APPS="$@"; direct_save; exit;;
        '--save-all') SAVE_ALL=True; direct_save; exit;;
        '--help') usage; exit;;

        *)
            echo "$SCRIPT_NAME: option '$arg' is not recognized"
            echo "Try '$SCRIPT_NAME --help' for more information"
            exit
            ;;
    esac
    shift

    ((i+=1))
done

# Checks for dependencies
dependency_check || exit

# Main loop
main
