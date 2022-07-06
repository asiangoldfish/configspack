function edit_config () {
    # Create and add entries to the menu
    local config_names
    for config in "${CONFIG_FILES[@]}"; do
        # Formats the config file path and fetch the file name from it
        IFS="/" read -ra arr <<< "$config"
        config_names=( "${arr[${#arr[@]} - 1]}" )
    done
    unset arr

    echo "${config_names[@]}"
    exit

    local menu
    menu="$(whiptail    --title "Edit Configuration" \
                        --menu "Edit dotfile configuration" \
                        10 70 3 \
                        "Hello" "" \
                        3>&1 1>&2 2>&3 )"

    exitstatus="$?"
    if [ "$exitstatus" = 1 ]; then exit; fi

    local menu_options
    mapfile -t menu_options <<< "${menu[@]}"
    
    unset menu

    for option in "${menu_options[@]}"; do
        case "$option" in 
            "Edit") edit_config;;
            "Add") add_config;;
            "Remove") remove_config;;
        esac
    done

    unset menu_options
    
    # Open editor
    # ${VISUAL:-${EDITOR:-vi}} "${filename}"
}

add_config () {
    :
}

remove_config () {
    :
}
