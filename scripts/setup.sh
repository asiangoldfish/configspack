function get_subcategories() {
    ### Returns the subcategories in a menu
    ### Arguments:
    ###     - category [str]: The category that this subcategories belong to
    ###     - search_depth [int]: Nested sections depth
    ### Example:
    ###     - get_subcategories "foo"

    local subcat_str
    local subcat
    local depth
    depth="$2"
    
    subcat="$($parser --file $CONFIG \
            --search-section \
            --section "$1" | \
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

    # Returns to bash menu if cancelled
    [ "$?" = 1 ] && main


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
    
    local entry
    # config settings for already activated options
    for subcat in "${subcategories[@]}"; do
        entry="$($parser            --value \
                                    --file $CONFIG \
                                    --section $app_name/$category/$subcat \
                                    --key checked)"
        original_entry+=( "$entry" )
    done
    unset entry
    
    # Generate menu entries
    local categories="$()"
    local index=0
    for ((i = 0; i < ${#subcategories[@]}; ++i)); do
        description="$($parser --value \
                                    --file $CONFIG \
                                    --section $app_name/$category/${subcategories[i]} \
                                    --key description)"
        menu_entry+=(   "${subcategories[i]}"
                        "$description"
                        "${original_entry[i]}" )
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

    unset menu_entry

    # Returns to bash menu if cancelled
    [ $? = 1 ] && bash_setup "Bash"


    local menu_options; mapfile -t menu_options <<< "$menu"
    
    # manipulates the config to mirror the activated menu entries above
    for subcat in "${subcategories[@]}"; do
        section="$app_name/$category/$subcat"
        
        # if the menu entry was selected, then 'checked' in config is ON
        for item in "${menu_options[@]}"; do
            if [ "$subcat" == "$item" ]; then
                "$parser"           --create-field \
                                    --file $CONFIG \
                                    --section $section \
                                    --key checked \
                                    --new-value ON
                continue 2
            fi
        done
        "$parser"               --create-field \
                                --file $CONFIG \
                                --section $section \
                                --key checked \
                                --new-value OFF
    done

    # if any changes were made, then register this application to the array of affected dotfiles
    local available_sections
    IFS=' ' read -ra available_sections <<< "$($parser  --search-section \
                                                        --file $CONFIG \
                                                        --section $app_name/$category/ \
                                                        --new-line False)"

    local original_check
    local new_check
    for section in "${available_sections[@]}"; do
        original_check=( "$($parser --value \
                                      --file $ORIGINAL_CONFIG \
                                      --section $section \
                                      --key checked)"
                                  )
        new_check=( "$($parser      --value \
                                      --file $CONFIG \
                                      --section $section \
                                      --key checked)"
                                  )
        
        # compare the original and the new value. If they are not the same, then
        # we know that a change was made
        if [ "$original_checks" != "$new_check" ]; then
            # avoid writing duplicate entries to AFFECTED_DOTFILES
            for name in "${AFFECTED_DOTFILES[@]}"; do
                if [ "$app_name" == "$name" ]; then
                    does_name_exist=True
                    break 2
                fi
            done
        fi
    done

    if [ -z "$does_name_exist" ]; then AFFECTED_DOTFILES+=( "$app_name" ); fi

    unset category subcategories menu_entry subcat description menu categories index menu_options has_changes_been_made get_checked section original_entry

    # Go back to submenu
    bash_setup "$app_name"
}

