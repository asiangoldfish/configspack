function get_subcategories() {
    ### Returns the subcategories in a menu
    ### Arguments:
    ###     - category [string]: The category that this subcategories belong to
    ### Returns:
    ###     - string(): A string array with subcategories
    ### Example:
    ###     - get_subcategories "foo"

    local category="$1"
    
    local subcategories
    mapfile -t subcategories <<< "$(cat "$CONFIGS" | jq -r ".categories.$category.subCategory | keys[]")"

    # Return statement
    echo "${subcategories[@]}"
}

function bash_setup () {
    ### Main entry to the dotfile's configuration menu
    ###
    ### Arguments:
    ###     - dotfile [string]: Name of dotfile
    
    local dotfile="$1"
    
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
    [[ "$?" = 1 ]] && override_bashrc "$CONFIGS" "$dotfile" "${dotfile_no_dot[1]}"

    # Direct user to the selected menu
    completions "${menu,}" "$CONFIGS" "${dotfile_no_dot[1]}.configs.json" "$dotfile"
    
    unset dotfile_no_dot
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
    ###     - dotfile [string]: dotfile path

    
    local category="$1"
    local config="$2"
    local config_no_path="$3"
    local dotfile="$4"

    # Gets all subcategories in the menu
    local subcategories
    IFS=" " read -ra subcategories <<< "$(get_subcategories "$category")"

    # Generate menu entries
    local menu_entry
    for subcat in "${subcategories[@]}"; do
        local description="$(jq -r ".categories.$category.subCategory.$subcat.description" "$config")"
        local checkbox="$(jq -r ".categories.$category.subCategory.$subcat.checkbox" "$config")"
        menu_entry+=( "$subcat" "$description" "$checkbox" )
    done
    
    # Build the checklist menu
    local menu="$(whiptail  --title "${category^}" \
                                    --checklist \
                                    --separate-output "Select applications" \
                                    --ok-button "Select" \
                                    --cancel-button "Back" \
                                    10 78 5 \
                                    "${menu_entry[@]}" \
                                    3>&1 1>&2 2>&3)"

    # Returns to bash menu if cancelled
    [ $? = 1 ] && bash_setup "$dotfile"

    local menu_options; mapfile -t menu_options <<< "$menu"

    # Updates new checkboxes and overwrites them in JSON config
    if [ ! -d "$TMP" ]; then mkdir "$TMP"; fi

    # TODO - Bug: ONs and OFFs are persisted even after going back to main menu
    # Sort ON entries
    local ons
    local offs

    for subcat in "${subcategories[@]}"; do
        for option in "${menu_options[@]}"; do
            [[ "$subcat" = "$option" ]] && ons+=("$option")
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

    local tmp_file="$TMP/$config_no_path"

    # Overwrite entries for ONs
    for on in "${ons[@]}"; do
        jq -r '.categories.'"$category"'.subCategory.'"$on"'.checkbox = "ON"' "$config" > "$tmp_file" && mv "$tmp_file" "$config"
    done

    # Overwrite entries for OFFs
    for off in "${offs[@]}"; do
        jq -r '.categories.'"$category"'.subCategory.'"$off"'.checkbox = "OFF"' "$config" > "$tmp_file" && mv "$tmp_file" "$config"
    done

    # Go back to submenu
    bash_setup "$dotfile"
}

function override_bashrc() {
    ### Based on the checkboxes in JSON config, generate a new dotfile
    ###
    ### Arguments:
    ###     - config [string]: JSON config file to pull from
    ###     - dotfile_path [string]: Path to dotfile to apply changes to
    ###     - dotfile_no_dot [string]: Dotfile name without the dot

    # Map args to variables
    local argv
    for arg in "$@"; do
        IFS="=" read -ra argv <<< "$arg"
        case "${argv[0]}" in
            "config") local config="${argv[1]}";;
            "dotfile_path") local dotfile_path="${argv[1]}";;
            "dotfile_no_dot") local dotfile_no_dot="${argv[1]}";;
        esac
        shift
    done

    # Confirm changes
    whiptail --yesno 'Save changes to dotfile?' 10 78 3
    [ "$?" -eq 1 ] && main

    # Generate new dotfile with boilerplate code if available
    [ -f "$dotfile_path" ] && rm "$dotfile_path" && touch "$dotfile_path"

    local templates="$SCRIPT_PATH/templates/$dotfile_no_dot.templates.txt"
    [ -f "$templates" ] && cat "$templates" > "$dotfile_path" && echo "" >> "$dotfile_path"

    # Iterate over all categories, then for each of the subcategories
    # copy the snippets to the dotfile if its checkbox is ON
    local categories; mapfile -t categories <<< "$(cat "$config" | jq -r ".categories | keys[]")"
    
    for cat in "${categories[@]}"; do
        local subcategories; mapfile -t subcategories <<< "$(cat "$config" | jq -r ".categories.$cat.subCategory | keys[]")"

        for subcat in "${subcategories[@]}"; do
            # Finally, copy snippets to dotfile if checkbox is ON
            checkbox="$(jq -r ".categories.$cat.subCategory.$subcat.checkbox" "$config")"
            [[ "$checkbox" = "ON" ]] && jq -r ".categories.$cat.subCategory.$subcat.snippet" "$config" >> "$dotfile" && echo "" >> "$dotfile"
        done
    done

    # Back to main menu
    main
}
