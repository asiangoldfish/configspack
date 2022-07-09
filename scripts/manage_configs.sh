function edit_config () {
    # Create and add entries to the menu
    local config_names
    local arr
    for config in "${CONFIG_FILES[@]}"; do
        # Formats the config file path and fetch the file name from it
        IFS="/" read -ra arr <<< "$config"
        config_names+=( "${arr[${#arr[@]} - 1]}" "" )
    done

    local menu="$(whiptail      --title "Edit Configuration" \
                                --menu "Edit dotfile configuration" \
                                10 70 3 \
                                "${config_names[@]}" \
                                3>&1 1>&2 2>&3 )"

    [ "$exitstatus" = 1 ] && exit

    mapfile -t menu_options <<< "${menu[@]}"
    
    #local new_snippet="$TMP/configspack.new_snippet.tmp"
    # Open editor
    #${VISUAL:-${EDITOR:-vi}} "$new_snippet"
}

add_config () {
    :
}

remove_config () {
    :
}
