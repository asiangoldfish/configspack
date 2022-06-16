AUTOCOMPLETIONS="$TMP/bash_autocompletions.txt"
COLOURIZE="$TMP/bash_colourize.txt"

bash_setup () {
    BASHRC="./bashrc_test.txt"
    
    # Create a new bashrc if it doesn't already exists
    if [ ! -f "$BASHRC" ]; then
        touch "$BASHRC"
    fi

    # Bashrc menu
    BASH_MENU="$(whiptail --title "Configure Application" --menu "Select application to configure" --ok-button "Select" --cancel-button "Back" 10 78 3 \
    "Autocompletions" "Tab complete commands" \
    "Colourizations" "Colourize commands" \
    "PATH" "Execute commands from anywhere" \
    "History" "Customize the Bash history command" \
    "Misc" "Other options" \
    3>&1 1>&2 2>&3 )"

    # Prompt the user to override bashrc with the new changes
    exitstatus=$?
    if [[ $exitstatus = 1 ]]; then
        if (whiptail --title "Confirm Changes" --yesno "Override and save new changes to bashrc?" 10 78); then
            override_bashrc
        else
            rm -r "$TMP"
        fi
    fi

    mapfile -t bash_options <<< "$BASH_MENU"

    for option in "${bash_options[@]}"; do
        case "$option" in
            "Autocompletions")
                completions
                ;;

            "Colourizations")
                colourizations
                ;;
            
            "PATH")
                path
                ;;

            "History")
                hist
                ;;

            "Misc")
                misc
                ;;
        esac
    done
}

completions () {
    path="$SCRIPT_PATH/bash/autocompletions"    # Path to autocompletions
    dotnet="$(cat "$path/dotnet_autocompletion.txt")"
    sudo="$(cat $path/sudo_autocompletion.txt)"
    git="$(cat $path/git_autocompletion.txt)"

    # Use preset checks from temporary files if they exist
    if [ -f "$AUTOCOMPLETIONS" ]; then
        # Sudo
        if [ ! -z "$(grep "Sudo autocompletion" "$AUTOCOMPLETIONS")" ]; then sudo_check="ON"; else sudo_check="OFF"; fi
        # Git
        if [ ! -z "$(grep "Git autocompletion" "$AUTOCOMPLETIONS")" ]; then git_check="ON"; else git_check="OFF"; fi
        # Dotnet
        if [ ! -z "$(grep "Dotnet autocompletion" "$AUTOCOMPLETIONS")" ]; then dotnet_check="ON"; else dotnet_check="OFF"; fi
    else
        # Sudo
        if [ ! -z "$(grep "Sudo autocompletion" "$BASHRC")" ]; then sudo_check="ON"; else sudo_check="OFF"; fi
        # Git
        if [ ! -z "$(grep "Git autocompletion" "$BASHRC")" ]; then git_check="ON"; else git_check="OFF"; fi
        # Dotnet
        if [ ! -z "$(grep "Dotnet autocompletion" "$BASHRC")" ]; then dotnet_check="ON"; else dotnet_check="OFF"; fi
    fi
    
    COMPLETION_OPTIONS="$(whiptail --title "Autocompletions" --checklist --separate-output "Select applications" --ok-button "Select" --cancel-button "Back" 10 78 5 \
    "Sudo" "Execute super user commands" $sudo_check \
    "Git" "Version Control System" $git_check \
    ".NET" "Microsoft .NET CLI" $dotnet_check \
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
                printf "$sudo\n\n" >> "$AUTOCOMPLETIONS"
                ;;
            "Git")
                printf "$git\n\n" >> "$AUTOCOMPLETIONS"
                ;;
            ".NET")
                printf "$dotnet\n\n" >> "$AUTOCOMPLETIONS"
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

    mapfile -t colourize_options <<< "$COLOURIZE_OPTIONS"

    echo "$colourize_options"

    for option in "${colourize_options[@]}"; do
        case "$option" in
            "Colourize Prompt")
                printf "$prompt\n\n" >> "$COLOURIZE"
                ;;
            "ls")
                printf "$ls\n\n" >> "$COLOURIZE"
                ;;
            "dir")
                printf "$dir\n\n" >> "$COLOURIZE"
                ;;
            "vdir")
                printf "$vdir\n\n" >> "$COLOURIZE"
                ;;
            "grep")
                printf "$grep\n\n" >> "$COLOURIZE"
                ;;
            "egrep")
                printf "$egrep\n\n" >> "$COLOURIZE"
                ;;
            "fgrep")
                printf "$fgrep\n\n" >> "$COLOURIZE"
                ;;
        esac
    done

    bash_setup
}

path () {
    OPTIONS="$(whiptail --title "PATH" --checklist --separate-output "Select PATHs to include" 10 78 5 \
    "Scripts" "Include ~/Scripts to add custom scripts" OFF \
    3>&1 1>&2 2>&3)"

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

override_bashrc() {
    # Adds auto-generated notification at the beginning of the file
    printf "# This file is generated with "$0"\n\n" > "$BASHRC"

    cat "$AUTOCOMPLETIONS" >> "$BASHRC"

    # Cleanup
    cleanup

    # Back to main menu
    main
}