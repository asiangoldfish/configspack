nano_setup () {
    ## File path variables
    NANORC="./hello.sh"
    #NANORC="$HOME/.NANORC"
    SYNTAX_HIGHLIGHTING="$SCRIPT_PATH/nano/syntax_highlighting.txt"

    ## Preset checks
    # Line numbers
    if [ ! -z "$(grep "set linenumbers" "$NANORC")" ]; then linenum_check="ON"; else linenum_check="OFF"; fi
    # Soft wrap
    if [ ! -z "$(grep "set softwrap" "$NANORC")" ]; then softwrap_check="ON"; else softwrap_check="OFF"; fi
    # Soft wrap
    if [ ! -z "$(grep "set nonewlines" "$NANORC")" ]; then nonewlines_check="ON"; else nonewlines_check="OFF"; fi
    # Soft wrap
    if [ ! -z "$(grep "syntax definitions" "$NANORC")" ]; then syntax_check="ON"; else syntax_check="OFF"; fi

    # Prompt user to select nano features to include
    OPTIONS=$(whiptail --title "Nano Configuration" --checklist --separate-output "Select features" 10 78 4 \
    "Line Numbers" "Displays line numbers to the left" $linenum_check \
    "Soft Wrap" "Soft wrap overflowing text" $softwrap_check \
    "No New Lines" "Prevents automatic new line at EOF" $nonewlines_check \
    "Add Syntax Highlighting" "Include syntax definitions" $syntax_check 3>&1 1>&2 2>&3)

    # Returns to main menu if cancelled
    exitstatus=$?
    if [ $exitstatus = 1 ]; then
        main
    fi

    # Map $OPTIONS results as array
    mapfile -t nano_options <<< "$OPTIONS"

    # Adds auto-generated notification at the beginning of the file
    printf "# This file is generated with "$0"\n\n" > "$NANORC"


    for option in "${nano_options[@]}"; do
        case "$option" in
            "Line Numbers")
                echo """# Displays line numbers to the left
    set linenumbers
    """ >> "$NANORC"
                ;;

            "Soft Wrap")
                echo """# Move overflowing text to the next line. Does not alter the file.
    set softwrap
    """ >> "$NANORC"
                ;;

            "No New Lines")
                echo """# Prevents automatic new line at end of file
    set nonewlines
    """ >> "$NANORC"
                ;;

            "Add Syntax Highlighting")
                if [ -f "$SYNTAX_HIGHLIGHTING" ]; then
                    cat "$SYNTAX_HIGHLIGHTING" >> "$NANORC"
                else
                    echo "Could not add syntax highlighting to nanorc"
                fi
            ;;
        esac
    done

    # Return to main menu
    main
}