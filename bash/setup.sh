# shellcheck shell=bash

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
    if [ "$raw" = False ]; then
        mapfile -t subcategories <<< "$(cat "$CONFIGS" | jq ".categories.$category.subCategory | keys[]")"
    else
        mapfile -t subcategories <<< "$(cat "$CONFIGS" | jq -r ".categories.$category.subCategory | keys[]")"
    fi

    # Return statement
    echo "${subcategories[@]}"
}

function bash_setup () {
    ### Main entry to the dotfile's configuration menu
    ###
    ### Arguments:
    ###     - dotfile [string]: Name of dotfile
    
    # Maps arguments to variables
    local argv
    for arg in "$@"; do
        IFS="=" read -ra argv <<< "$arg"
        case "${argv[0]}" in
            "dotfile") local dotfile="${argv[1]}";;
        esac
        shift
    done
    
    # Fetches the config file for this dotfile
    local dotfile_no_dot
    IFS="." read -ra dotfile_no_dot <<< "$dotfile"
    local CONFIGS="$CONFIGS_DIR/${dotfile_no_dot[1]}.configs.json"

    # Create a new dotfile if it doesn't already exists
    if [ ! -f "$dotfile" ]; then touch "$dotfile"; fi

    # Maps all categories
    local CATEGORIES
    mapfile -t CATEGORIES <<< "$(cat "$CONFIGS" | jq -r '.categories | keys[]')"

    # Creates a new menu based on the categories array and JSON config
    local new_menu=()
    for category in "${CATEGORIES[@]}"; do
        # Sub menu description
        description="$(cat $CONFIGS | jq -r ".categories.$category.menuDescription")"
        new_menu+=( "${category^}" )
        new_menu+=( "$description" )
    done

    # Bashrc Main Menu
    local menu
    menu="$(whiptail   --title "Configure Application" \
                            --menu "Select application to configure" \
                            --ok-button "Select" \
                            --cancel-button "Back" 10 78 3 \
                            "${new_menu[@]}" \
                            3>&1 1>&2 2>&3 )"
    # Prompt the user to override bashrc with the new changes
    exitstatus=$?
    if [[ $exitstatus = 1 ]]; then override_bashrc; fi

    # Direct user to the selected menu
    completions "category=${menu,}" "config=$CONFIGS" "config_no_path=${dotfile_no_dot[1]}.configs.json"
}

# TODO - Remove this function?
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

mkdir_tmp() {
    if [ ! -d "$TMP" ]; then mkdir "$TMP"; fi

    return 0
}

function completions () {
    ### Handles autocompletion related settings
    ###
    ### - Creates a checkbox menu to enable users picking their features of choice.
    ### - Fetches existing settings and updates the checkboxes accordingly
    ### - Updates the checkbox field in the JSON config
    ###
    ### Arguments:
    ###     - category [string]: Show the menu of this category
    ###     - config [string]: Configuration file path
    ###     - config_no_path [string]: Configuration file name
    ###

    
    local argv
    for arg in "$@"; do
        IFS="=" read -ra argv <<< "$arg"
        case "${argv[0]}" in
            "category") local category="${argv[1]}";;
            "config") local config="${argv[1]}";;
            "config_no_path") local config_no_path="${argv[1]}";;
        esac
        shift
    done

    # Gets all subcategories in the menu
    local subcategories
    IFS=" " read -ra subcategories <<< "$(get_subcategories category="$category" raw=True)"

    # Generate menu entries
    # TODO - Fix the ON/OFF switch to dynamically match what's in the dotfile and keep the change until the user goes back to main menu
    local menu_entry
    local i=0
    for subcat in "${subcategories[@]}"; do
        # Description of this entry
        local description
        description="$(cat "$config" | jq -r ".categories.$category.subCategory.$subcat.description")"

        # Whether the checkbox should be ON or OFF
        local checkbox
        checkbox="$(cat "$config" | jq -r ".categories.$category.subCategory.$subcat.checkbox")"

        menu_entry+=( "$subcat" "$description" "$checkbox" )
        i+=1
    done
    
    unset i

    # Build the checklist menu
    local menu
    menu="$(whiptail  --title "${category^}" \
                                    --checklist \
                                    --separate-output "Select applications" \
                                    --ok-button "Select" \
                                    --cancel-button "Back" \
                                    10 78 5 \
                                    "${menu_entry[@]}" \
                                    3>&1 1>&2 2>&3)"

    # Returns to bash menu if cancelled
    # TODO - Change this back to returning bash_setup when finished
    exitstatus=$?
    if [ $exitstatus = 1 ]; then  exit; fi #bash_setup; fi

    local menu_options
    mapfile -t menu_options <<< "$menu"

    # Updates new checkboxes and overwrites them in JSON config
    mkdir_tmp

    # Sort ON entries
    local ons
    local offs

    for subcat in "${subcategories[@]}"; do
        for option in "${menu_options[@]}"; do
            # If subcat matches option, then consider subcat as ON, otherwise OFF
            if [[ "$subcat" = "$option" ]]; then ons+=("$option"); fi
        done
    done

    # Sort OFF entries
    for i in "${subcategories[@]}"; do
        skip=
        for j in "${menu_options[@]}"; do
            [[ $i == "$j" ]] && { skip=1; break; }
        done
        [[ -n $skip ]] || offs+=( "$i" )
    done

    echo "ONs: " "${ons[@]}"
    echo "OFFs: " "${offs[@]}"

    local tmp_file="$TMP/$config_no_path"

    # Overwrite entries for ONs
    for on in "${ons[@]}"; do
        cat "$config" | jq -r '.categories.'"$category"'.subCategory.'"$on"'.checkbox = "ON"' > "$tmp_file" && mv "$tmp_file" "$config"
    done

    # Overwrite entries for OFFs
    for off in "${offs[@]}"; do
        cat "$config" | jq -r '.categories.'"$category"'.subCategory.'"$off"'.checkbox = "OFF"' > "$tmp_file" && mv "$tmp_file" "$config"
    done

    unset ons offs tmp_file

    # TODO - Go back to previous page with all the correct arguments
    #bash_setup
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