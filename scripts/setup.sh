function get_subcategories() {
    ### Returns the subcategories in a menu
    ### Arguments:
    ###     - category [str]: The category that this subcategories belong to
    ###     - search_depth [int]: Nested sections depth
    ### Returns:
    ###     - string(): A string array with subcategories
    ### Example:
    ###     - get_subcategories "foo"

    local subcategories
    local depth
    depth="$2"

    subcat="$($parser --file $CONFIG \
            --search-section \
            --pattern "$1" | \
            awk 'BEGIN{FS="/"};{print $'"$depth"'}' | \
            sed '$!N; /^\(.*\)\n\1$/!P; D' | sed '/^$/d')"
 
    subcat_str="${subcat//[$'\t\r\n']/ }"

    # Return statement
    echo "${subcat_str[@]}"
}

function bash_setup () {
    ### Main entry to the dotfile's configuration menu
    subcat="$(get_subcategories $1 2)"
    IFS=' ' read -ra categories <<< "$subcat"
    
    # Creates a new menu based on the categories array and JSON config
    local new_menu=()
    for category in "${categories[@]}"; do

        # Sub menu description
        description="$($parser  --value \
                                --file $CONFIG \
                                --section "$1/$category" \
                                --key description)"

        new_menu+=( "$category" "$description" )
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
    completions "${menu}" "$1"
    
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
    local app_name="$2"
    local subcategories
    local menu_entry
    local subcat
    local description
    local menu

    # Gets all subcategories in the menu
    IFS=" " read -ra subcategories <<< "$(get_subcategories "$category" 3)"
    

    # Generate menu entries
    for subcat in "${subcategories[@]}"; do
        description="$($parser --value \
                                    --file $CONFIG \
                                    --section $app_name/$category/$subcat \
                                    --key description)"
        menu_entry+=( "$subcat" "$description" 'ON' )
    done

    # Build the checklist menu
    menu="$(whiptail                --title "${category}" \
                                    --checklist \
                                    --separate-output "Select applications" \
                                    --ok-button "Select" \
                                    --cancel-button "Back" \
                                    10 78 5 \
                                    "${menu_entry[@]}" \
                                    3>&1 1>&2 2>&3)"


    # Returns to bash menu if cancelled
    [ $? = 1 ] && bash_setup "Bash"


    local menu_options; mapfile -t menu_options <<< "$menu"
    
    echo "${menu_options[@]}"
    exit

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
    local config="$1"
    local dotfile_path="$2"
    local dotfile_no_dot="$3"

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
