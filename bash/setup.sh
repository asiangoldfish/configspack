AUTOCOMPLETIONS="$TMP/bash_autocompletions.txt"
COLOURIZE="$TMP/bash_colourize.txt"
PATHS="$TMP/bash_paths.txt"
CONFIGS="$SCRIPT_PATH/bash/bash_configs.json"

# Notes
# cat "autocompletion_test.json" | jq -r '.autocompletion.sudo.snippet' > bashtest.sh

bash_setup () {
    # Create a new bashrc if it doesn't already exists
    if [ ! -f "$BASHRC" ]; then touch "$BASHRC"; fi

    # Copy existing settings in bashrc to tmp file
    if [ ! -f "$AUTOCOMPLETIONS" ]; then bashrc_to_tmp; fi

    # Bashrc Main Menu
    BASH_MENU="$(whiptail --title "Configure Application" --menu "Select application to configure" --ok-button "Select" --cancel-button "Back" 10 78 3 \
    "Autocompletions" "Tab complete commands" \
    "Colourizations" "Colourize commands" \
    "PATH" "Execute commands from anywhere" \
    "History" "Customize the Bash history command" \
    "Misc" "Other options" \
    3>&1 1>&2 2>&3 )"

    # Prompt the user to override bashrc with the new changes
    exitstatus=$?
    if [[ $exitstatus = 1 ]]; then override_bashrc; fi

    # Direct user to the selected menu
    mapfile -t bash_options <<< "$BASH_MENU"

    for option in "${bash_options[@]}"; do
        case "$option" in
            "Autocompletions") completions;;
            "Colourizations") colourizations;;
            "PATH") path;;
            "History") hist;;
            "Misc") misc;;
        esac
    done
}

json_value () {
    ### Finds the value of a given key in a JSON file.
    ### Arguments:
    ###     - json [string]: JSON file to search for keys
    ###     - key [string]:  The key whose value belongs to. Nest keys wih the
    ###                      delimiter '.'
    ### Example:
    ###     - Given the following JSON:
    ###       "{
    ###           "foo": {
    ###               "bar": "hello"
    ###           }
    ###       }",
    ###       the key to find "hello" is: ".foo.bar"

    # Maps arguments to variables
    for arg in "$@"; do
        IFS="=" read -ra argv <<< "$arg"
        case "${argv[0]}" in
            "json") local json="${argv[1]}";;
            "key") local key="${argv[1]}";;
        esac
    done
    
    local result="$(cat "$json" | jq -r "$key")"
    echo "$result"
}

bashrc_to_tmp () {
    ### Copy current settings from bashrc into tmp file
    ### Arguments:
    ###     None
    ### Results:
    ###     None

    # Map all features of autocompletion in an array
    mapfile -t features <<< "$(json_value json="$CONFIGS" key='.autocompletion | keys[]')"

    # Find search strings for each feature based on json config file
    for feature in "${features[@]}"; do
        local search_phrase="$(json_value json="$CONFIGS" key=".autocompletion.$feature.search")"

        # Copy settings from bashrc to tmp file
        if [ ! -z "$(grep "$search_phrase" "$BASHRC")" ]; then
            # If search phrase was found in bashrc, copy the given setting to tmp file
            cat "$CONFIGS" | jq -r ".autocompletion.$feature.snippet" >> "$AUTOCOMPLETIONS"
        fi
    done
}

apply_checks () {
    ### Validates whether a file contains a given string
    ### Arguments:
    ###     - search [string]: Search by this string
    ###     - target [string]: File to search in
    ### Returns:
    ###     - string: "ON" or "OFF" depending on if the string was found
    ### Notes:
    ###     - This function uses grep for validation. Anything returned by grep
    ###       is considered as "valid".

    # Maps arguments to variables
    for arg in "$@"; do
        IFS="=" read -ra argv <<< "$arg"
        case "${argv[0]}" in
            "search") search="${argv[1]}";;
            "target") target="${argv[1]}";;
        esac
    done

    if [ ! -z "$(grep "$search" "$target")" ]; then return "ON"; else return "OFF"; fi
}

completions () {
    ### Handles autocompletion related settings
    ###
    ### - Creates a checkbox menu to enable users picking their features of choice.
    ### - Fetches existing settings and updates the checkboxes accordingly
    ### - Generates a temporary file storing selected features

    # This variable stores ON's and OFF's for each setting. Makes the selecion more dynamic.
    local completion_check=()

    # Dynamically fetches all features to add from JSON config
    mapfile -t features <<< "$(json_value json="$CONFIGS" key='.autocompletion | keys[]')"

    # Iterate over each feature
    for feature in "${features[@]}"; do
        # Fetches the search keyword from the JSON config
        search_phrase="$(json_value json="$CONFIGS" key=".autocompletion.$feature.search")"
        
        # If there already is a tmp file, then use settings from it instead of bashrc
        if [ ! -z "$(grep "$search_phrase" "$AUTOCOMPLETIONS")" ]; then completion_check+=( "ON" ); else completion_check+=( "OFF" ); fi
    done

    COMPLETION_OPTIONS="$(whiptail --title "Autocompletions" --checklist --separate-output "Select applications" --ok-button "Select" --cancel-button "Back" 10 78 5 \
    "Sudo" "Execute super user commands" "${completion_check[0]}" \
    "Git" "Version control system" "${completion_check[1]}" \
    ".NET" "Microsoft .NET CLI" "${completion_check[2]}" \
    3>&1 1>&2 2>&3)"

    # Returns to bash menu if cancelled
    exitstatus=$?
    if [ $exitstatus = 1 ]; then bash_setup; fi

    # Wipe the old tmp file
    if [ -f "$AUTOCOMPLETIONS" ]; then rm "$AUTOCOMPLETIONS"; fi

    mapfile -t completion_options <<< "$COMPLETION_OPTIONS"

    for option in "${completion_options[@]}"; do
        case "$option" in
            "Sudo")
                eval "json_value json=$CONFIGS key=.autocompletion.sudo.snippet" >> "$AUTOCOMPLETIONS"
                printf "\n\n" >> "$AUTOCOMPLETIONS"
                ;;
            "Git")
                eval "json_value json=$CONFIGS key=.autocompletion.git.snippet" >> "$AUTOCOMPLETIONS"
                printf "\n\n" >> "$AUTOCOMPLETIONS"
                ;;
            ".NET")
                eval "json_value json=$CONFIGS key=.autocompletion.dotnet.snippet" >> "$AUTOCOMPLETIONS"
                printf "\n\n" >> "$AUTOCOMPLETIONS"
        esac
    done

    bash_setup
}

colourizations () {
    path="$SCRIPT_PATH/bash/colourizations"    # Path to autocompletions
    prompt="$(cat "$path/prompt_colourize.txt")"
    ls="$(cat "$path/ls_colourize.txt")"
    dir="$(cat "$path/dir_colourize.txt")"
    vdir="$(cat "$path/vdir_colourize.txt")"
    grep="$(cat "$path/grep_colourize.txt")"
    egrep="$(cat "$path/egrep_colourize.txt")"
    fgrep="$(cat "$path/fgrep_colourize.txt")"

    # Transfer existing settings to temporary file
    

    # Use preset checks from temporary files if they exist
    if [ -f "$COLOURIZE" ]; then
        # Prompt
        if [ ! -z "$(grep 'Shell Prompt' "$COLOURIZE")" ]; then prompt_check="ON"; else prompt_check="OFF"; fi
        # ls
        if [ ! -z "$(grep 'alias ls' "$COLOURIZE")" ]; then ls_check="ON"; else ls_check="OFF"; fi
        # dir
        if [ ! -z "$(grep 'alias dir' "$COLOURIZE")" ]; then dir_check="ON"; else dir_check="OFF"; fi
        # vdir
        if [ ! -z "$(grep 'alias vdir' "$COLOURIZE")" ]; then vdir_check="ON"; else vdir_check="OFF"; fi
        # grep
        if [ ! -z "$(grep 'alias grep' "$COLOURIZE")" ]; then grep_check="ON"; else grep_check="OFF"; fi
        # egrep
        if [ ! -z "$(grep 'alias egrep' "$COLOURIZE")" ]; then egrep_check="ON"; else egrep_check="OFF"; fi
        # fgrep
        if [ ! -z "$(grep 'alias fgrep' "$COLOURIZE")" ]; then fgrep_check="ON"; else fgrep_check="OFF"; fi
    else
        # Prompt
        if [ ! -z "$(grep 'Shell Prompt' "$BASHRC")" ]; then prompt_check="ON"; else prompt_check="OFF"; fi
        # ls
        if [ ! -z "$(grep 'alias ls' "$BASHRC")" ]; then ls_check="ON"; else ls_check="OFF"; fi
        # dir
        if [ ! -z "$(grep 'alias dir' "$BASHRC")" ]; then dir_check="ON"; else dir_check="OFF"; fi
        # vdir
        if [ ! -z "$(grep 'alias vdir' "$BASHRC")" ]; then vdir_check="ON"; else vdir_check="OFF"; fi
        # grep
        if [ ! -z "$(grep 'alias grep' "$BASHRC")" ]; then grep_check="ON"; else grep_check="OFF"; fi
        # egrep
        if [ ! -z "$(grep 'alias egrep' "$BASHRC")" ]; then egrep_check="ON"; else egrep_check="OFF"; fi
        # fgrep
        if [ ! -z "$(grep 'alias fgrep' "$BASHRC")" ]; then fgrep_check="ON"; else fgrep_check="OFF"; fi
    fi

    COLOURIZE_OPTIONS="$(whiptail --title "PATH" --checklist --separate-output "Select commands to colourize" 10 78 5 \
    "Colourize Prompt" "Colourful shell prompt" $prompt_check \
    "ls" "List directory contents" $ls_check \
    "dir" "List directory contents" $dir_check \
    "vdir" "List directory contents" $vdir_check \
    "grep" "Print lines that match patterns" $grep_check \
    "egrep" "Print lines that match patterns" $egrep_check \
    "fgrep" "Print lines that match patterns" $fgrep_check \
    3>&1 1>&2 2>&3)"

    # Returns to bash menu if cancelled
    exitstatus=$?
    if [ $exitstatus = 1 ]; then bash_setup; fi
    
    # Wipe the old tmp file
    if [ -f "$COLOURIZE" ]; then rm "$COLOURIZE"; fi


    mapfile -t colourize_options <<< "$COLOURIZE_OPTIONS"

    for option in "${colourize_options[@]}"; do
        case "$option" in
            "Colourize Prompt")
                printf "$prompt\n\n" >> "$COLOURIZE"
                ;;
            "ls")
                printf "$ls\n" >> "$COLOURIZE"
                ;;
            "dir")
                printf "$dir\n" >> "$COLOURIZE"
                ;;
            "vdir")
                printf "$vdir\n" >> "$COLOURIZE"
                ;;
            "grep")
                printf "$grep\n" >> "$COLOURIZE"
                ;;
            "egrep")
                printf "$egrep\n" >> "$COLOURIZE"
                ;;
            "fgrep")
                printf "$fgrep\n" >> "$COLOURIZE"
                ;;
        esac
    done

    bash_setup
}

path () {
    path="$SCRIPT_PATH/bash/paths"    # Path to autocompletions
    scripts="$(cat "$path/scripts_path.txt")"

    # Use preset checks from temporary files if they exist
    if [ -f "$PATHS" ]; then
        # Scripts
        if [ ! -z "$(grep 'Custom scripts or commands' "$PATHS")" ]; then scripts_check="ON"; else scripts_check="OFF"; fi
    fi

    PATHS_OPTIONS="$(whiptail --title "PATH" --checklist --separate-output "Select PATHs to include" 10 78 5 \
    "Scripts" "Include ~/Scripts to add custom scripts" "$scripts_check" \
    3>&1 1>&2 2>&3)"

    # Returns to bash menu if cancelled
    exitstatus=$?
    if [ $exitstatus = 1 ]; then bash_setup; fi
    
    # Wipe the old tmp file
    if [ -f "$PATHS" ]; then rm "$PATHS"; fi

    mapfile -t paths_options <<< "$PATHS_OPTIONS"

    for option in "${paths_options[@]}"; do
        case "$option" in
            "Scripts")
                printf "$scripts\n\n" >> "$PATHS"
        esac
    done

    bash_setup
}

hist () {
    OPTIONS="$(whiptail --title "PATH" --checklist --separate-output "Select PATHs to include" 10 78 5 \
    "History- Ignore" "Ignores duplicate lines and lines starting with space" OFF \
    "History- Append" "Append to the history file, don't overwrite it" OFF \
    3>&1 1>&2 2>&3)"

    bash_setup
}

misc () {
    OPTIONS="$(whiptail --title "Autocompletions" --checklist --separate-output "Enable Miscellaneous Options" 10 78 5 \
    "Bash Aliases" "Source .bash_aliases for custom aliases" OFF \
    3>&1 1>&2 2>&3)"

    bash_setup
}

print_boilerplate() {
    ### Prints boilerplate code that always is included in bashrc

    # Autogenerated notification
    printf '# This file is generated with %s\n\n' "$0" >> "$BASHRC"

    # Do nothing if the shell or subshell is not run interactively, like activated through a script.
    printf '# If not running interactively, don'\''t do anything\n [[ $- != *i* ]] && return\n\n' >> "$BASHRC"
}

override_bashrc() {
    # TODO - Add confirmation on changes
    
    # Do nothing if no changes were made
    #if [ -f "$AUTOCOMPLETE" || -f "$COLOURIZE" || -f "$PATHS" ]; then
    #    # Confirm changes
    #    if (whiptail --title "Confirm Changes" --yesno "Override and save new changes to bashrc?" 10 78); then
    #            :
    #        else
    #            cleanup
    #            main
    #    fi
    #fi

    rm "$BASHRC"

    print_boilerplate

    if [ -f "$AUTOCOMPLETIONS" ]; then
        cat "$AUTOCOMPLETIONS" >> "$BASHRC"
    fi

    #if [ -f "$COLOURIZE" ]; then
    #    echo "# Colourize commands" >> "$BASHRC"
    #    cat "$COLOURIZE" >> "$BASHRC"
    #fi

    #if [ -f "$PATHS" ]; then
    #    echo "" >> "$BASHRC"
    #    echo "# PATHs" >> "$BASHRC"
    #    cat "$PATHS" >> "$BASHRC"
    #fi

    # Cleanup
    cleanup

    # Back to main menu
    main
}