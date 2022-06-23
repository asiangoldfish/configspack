# shellcheck shell=bash

CONFIGS="$SCRIPT_PATH/configs/bashrc_configs.json"

# Maps each categories' settings to their designated tmp file
mapfile -t CATEGORIES <<< "$(cat "$CONFIGS" | jq -r '.categories | keys[]')"

TMP_FILES=()

function throw_error
{
    ### Throws an error for debugging purposes
    ### Arguments:
    ###     - $1: Error message

    # TODO - At the moment the below lines only returns the line number of caller
    #        and not where the actual error is. Fix this so the error message
    #        displays where the error actually is in line numbers.

    printf '%s' "$(caller): "
    printf '%s\n' "${1:-"Unknown error"}" 1>&2
    exit 111
}

function get_subcategories() {
    ### Returns the subcategories in a menu
    ### Arguments:
    ###     - category [string]: The category that this subcategories belong to
    ###     - raw [bool]: Whether jq should return a string in raw format
    ### Returns:
    ###     - string(): A string array with subcategories
    ### Example:
    ###     - get_subcategory category="foo" raw=True

    # Maps arguments to variables
    for arg in "$@"; do
        IFS="=" read -ra argv <<< "$arg"
        case "${argv[0]}" in
            "category") category="${argv[1]}";;
            "raw") raw="${argv[1]}";;
        esac
        shift
    done
    
    if [ "$category" = "" ]; then throw_error "${FUNCNAME} is missing named argument 'category'"; fi
    if [ "$raw" = "" ]; then throw_error "${FUNCNAME} is missing named argument 'raw'"; fi

    local subcategories
    mapfile -t subcategories <<< "$(cat "$CONFIGS" | jq -r ".categories.$category.subCategory | keys[]")"

    # Return statement
    echo "${subcategories[@]}"
}

function bash_setup () {
    # Create a new bashrc if it doesn't already exists
    if [ ! -f "$BASHRC" ]; then touch "$BASHRC"; fi

    # Creates a new menu based on the categories array and JSON config
    new_menu=()

    for category in "${CATEGORIES[@]}"; do
        # Sub menu description
        description="$(cat $CONFIGS | jq -r ".categories.$category.menuDescription")"

        new_menu+=( "${category^}" )
        new_menu+=( "$description" )
    done

    # Bashrc Main Menu
    BASH_MENU="$(whiptail   --title "Configure Application" \
                            --menu "Select application to configure" \
                            --ok-button "Select" \
                            --cancel-button "Back" 10 78 3 \
                            "${new_menu[@]}" \
                            3>&1 1>&2 2>&3 )"
    # Prompt the user to override bashrc with the new changes
    exitstatus=$?
    if [[ $exitstatus = 1 ]]; then override_bashrc; fi

    # Direct user to the selected menu
    mapfile -t bash_options <<< "$BASH_MENU"

    # Iterator for getting iterated element in aray
    i=0
    for option in "${bash_options[@]}"; do
        for category in "${CATEGORIES[@]}"; do
            if [ "${option,}" == "$category" ]; then
            completions "${category,}" "${TMP_FILES[$i]}"
            break
            fi
        done
        i+=1
    done
}

function generate_tmp() {
    ### Generates a new temporary file
    ### The file name has the format xxx.yyy.tmp where x is the dotfile
    ### name and y is the subcategory name.
    ###
    ### Arguments:
    ###     - $1 [string]: Target directory to store the file
    ###     - $2 [string]: Dotfile name
    ###     - $3 [string]: Subcategory name
    ###     - $4 [bool]: Replace old file?

    # Throw an error if there are missing arguments
    if [ "$1" = "" ]; then throw_error "Missing positional argument target directory"; fi
    if [ "$2" = "" ]; then throw_error "Missing positional argument dotfile name"; fi
    if [ "$3" = "" ]; then throw_error "Missing positional argument subcategory directory"; fi
    
    # Map args to variables
    target="$1"; dotfile="$2"; subcategory="$3"; replace="$4"

    # The tmp file name
    local tmp_file="$dotfile.$subcategory.tmp"

    # Remove the old tmp file
    if [ "$replace" = True ] && [ -f "$target/$tmp_file" ]; then rm "$target/$tmp_file"; fi

    # Create new tmp file if one doesn't already exist
    if [ ! -f "$target/$tmp_file" ]; then touch "$target/$tmp_file"; fi

    return 0
}

function bashrc_to_tmp () {
    ### Copies all settings from bashrc into temporary files.
    ### Each JSON config first depth key is considered a category.
    ### Each category receives its own temporary file. Ex: bash_category.tmp
    ### Settings from bashrc is copied to the appropriate temporary file.
    for category in "${CATEGORIES[@]}"; do

        # Temporary file to store settings in
        tmp_file="$TMP/bashrc_$category.tmp"
        if [ ! -d "$TMP" ]; then mkdir "$TMP"; fi

        # Append the file to the global array variable of temporary files
        TMP_FILES+=( "$tmp_file" )

        local subs
        mapfile -t subs <<< "$(get_subcategories category="$category" raw=True )"

        echo "${subs[@]}"
        exit

        # Map all setting of a given category in an array
        mapfile -t apps <<< "$(cat "$CONFIGS" | jq ".categories.$category.subCategory | keys[]")"

        # Find "search" strings for each setting based on json config file
        for app in "${apps[@]}"; do
            local search_phrase
            search_phrase="$(cat "$CONFIGS" | jq -r ".categories.$category.subCategory.$app.search")"

            # Copy settings from bashrc to tmp file
            if [ ! -z "$(grep "$search_phrase" "$BASHRC")" ]; then
                # If search phrase was found in bashrc, copy the given setting to tmp file
                cat "$CONFIGS" | jq -r ".categories.$category.subCategory.$app.snippet" >> "$tmp_file"
            fi
        done
    done
}

function apply_checks () {
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

function completions () {
    ### Handles autocompletion related settings
    ###
    ### - Creates a checkbox menu to enable users picking their features of choice.
    ### - Fetches existing settings and updates the checkboxes accordingly
    ### - Generates a temporary file storing selected features

    # This variable stores ON's and OFF's for each setting. Makes the selecion more dynamic.
    local completion_options_array=()
    local category="$1"
    local tmp_file="$2"

    # Dynamically fetches all features to add from JSON config
    mapfile -t features <<< "$(cat "$CONFIGS" | jq -r ".categories.autocompletion.subCategory | keys[]")"

    # Get all names, search strings and ON/OFF statements and add them all to an array. Then, use the array in the whiptail checklist.
    for feature in "${features[@]}"; do
        # Fetches the search keyword from the JSON config
        #search_phrase="$(cat "$CONFIGS" | jq ".categories.$category.subCategory.$feature.search")"

	    search_phrase="$(cat "$CONFIGS"  | jq ".categories.$category.subCategory.$feature.search")"

        # Add the variables to the dynamic array
        completion_options_array+=( "$feature" "$search_phrase" )

        # If there already is a tmp file, then use settings from it instead of bashrc
        if grep -q "$search_phrase" "$tmp_file"; then completion_options_array+=( "OFF" ); echo "OFF"; else completion_options_array+=( "ON" ); echo "ON"; fi
    done

    exit

    # Build the checklist menu
    COMPLETION_OPTIONS="$(whiptail  --title "${category^}" \
                                    --checklist \
                                    --separate-output "Select applications" \
                                    --ok-button "Select" \
                                    --cancel-button "Back" \
                                    10 78 5 \
                                    "${completion_options_array[@]}" \
                                    3>&1 1>&2 2>&3)"

    # Returns to bash menu if cancelled
    exitstatus=$?
    if [ $exitstatus = 1 ]; then bash_setup; fi

    # Wipe the old tmp file
    if [ -f "$tmp_file" ]; then rm "$tmp_file"; fi

    mapfile -t completion_options <<< "$COMPLETION_OPTIONS"

    # Iterator for getting iterated element in aray
    for option in "${completion_options[@]}"; do
        for feature in "${features[@]}"; do
            if [ "$option" == "$feature" ]; then
                cat "$CONFIGS" | jq .categories."$0".subCategory."$feature".snippet >> "$tmp_file"
                printf "\n\n" >> "$tmp_file"
            fi
        done
    done

    bash_setup
}

function append_boilerplate() {
    ### Prints boilerplate code that always is included in bashrc
    cat "./templates/bashrc_templates.txt" >> "$BASHRC"
}

function override_bashrc() {
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

    # rm "$BASHRC"
# 
    #append_boilerplate

    #if [ -f "$AUTOCOMPLETIONS" ]; then
    #    cat "$AUTOCOMPLETIONS" >> "$BASHRC"
    #fi

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
