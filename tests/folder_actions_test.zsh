# One flat, searchable menu separates exact-target actions from navigation.
_test_folder_actions_groups() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    local _DIRECTORY_PICKER_LOCATION="$HOME/current/"
    local selected="$HOME/selected %F{red}; literal/" choice=""
    local _directory_browser_clipboard=available _directory_browser_open=available
    local -i _FILES_WORKSPACE=1
    _directory_recents_choose() { return 99; }
    _file_search_choose() { return 99; }
    _directory_browser_pick() {
      local value="" label="" group="" previous="" expected="" last_target=""
      local -a seen=()
      local -i index=0
      for value in "${_directory_action_values[@]}"; do
        (( ++index ))
        label=${_directory_action_labels[index]}
        case $value in
          (view-recents) expected="Go to" ;;
          (current|current-cd|view-browse|search-*) expected="Current folder" ;;
          (*) expected="Current folder"
              [[ -n $selected ]] && expected="Selected folder" ;;
        esac
        [[ $label == "$expected · "* ]] || {
          print -u2 -r -- "Action $value must identify its group: $expected"
          return 31
        }
        group=${label%% · *}
        if [[ $group != $previous ]]; then
          (( ! ${seen[(Ie)$group]} )) || return 32
          seen+=("$group") previous=$group
        fi
        if [[ $group == "Go to" ]]; then
          [[ $_ZLE_PICKER_INSPECT_TEXTS[$value] == *"shell"* &&
             $_ZLE_PICKER_INSPECT_TEXTS[$value] != *"$HOME/current/"* ]] || return 33
        else
          last_target=$_DIRECTORY_PICKER_LOCATION
          [[ $group == "Selected folder" ]] && last_target=$selected
          [[ $_ZLE_PICKER_INSPECT_TEXTS[$value] == *"$last_target"* ]] || return 34
        fi
      done
      [[ ${seen[-1]} == "Go to" ]] || return 35
      _directory_browser_actions_collect "Go to · Recent directories (this shell)" 10
      [[ ${#_ZLE_PICKER_RESULTS} == 1 && $_ZLE_PICKER_RESULTS[1] == view-recents ]] || return 36
      # Labels and details remain captured data during filtering/rendering.
      for COLUMNS in 120 70 30; do
        LINES=20
        _zle_picker_render "Recent directories" 1
        for label in "${_ZLE_PICKER_DISPLAY[@]}"; do
          (( ${(m)#label} < COLUMNS )) || return 37
        done
      done
      _ZLE_PICKER_SELECTED_VALUE=$choice
    }
    for choice in select cd copy reveal current current-cd view-browse search-local view-recents; do
      _directory_browser_actions "$selected" insert || exit 1
      case $choice in
        (current) [[ $_ZLE_PICKER_ACTION == select && $_ZLE_PICKER_SELECTED_VALUE == "$_DIRECTORY_PICKER_LOCATION" ]] || exit 2 ;;
        (current-cd) [[ $_ZLE_PICKER_ACTION == cd && $_ZLE_PICKER_SELECTED_VALUE == "$_DIRECTORY_PICKER_LOCATION" ]] || exit 3 ;;
        (select|cd|copy|reveal) [[ $_ZLE_PICKER_ACTION == "$choice" && $_ZLE_PICKER_SELECTED_VALUE == "$selected" ]] || exit 4 ;;
        (*) [[ $_ZLE_PICKER_ACTION == "$choice" ]] || exit 5 ;;
      esac
    done
    selected="" choice=copy
    _directory_browser_actions "" insert || exit 6
    [[ $_ZLE_PICKER_SELECTED_VALUE == "$_DIRECTORY_PICKER_LOCATION" ]] || exit 7
    choice=insert
    _directory_browser_actions "" cd || exit 8
    [[ $_ZLE_PICKER_ACTION == insert && $_ZLE_PICKER_SELECTED_VALUE == "$_DIRECTORY_PICKER_LOCATION" ]] || exit 9
    # The runtime peer supplies app dispatch, including for an empty folder.
    source "$1/.zsh.addons/.zsh.find"
    choice=open
    _directory_browser_actions "" insert || exit 10
    [[ $_ZLE_PICKER_ACTION == open && $_ZLE_PICKER_SELECTED_VALUE == "$_DIRECTORY_PICKER_LOCATION" ]] || exit 11
    print grouped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal grouped "$output"
}
test_case 'folder actions group contextual targets separately from Go to navigation' _test_folder_actions_groups

_test_folder_actions_optional_groups() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    local _DIRECTORY_PICKER_LOCATION="$HOME/"
    local _directory_browser_clipboard="" _directory_browser_open=""
    local -i _FILES_WORKSPACE=1
    _directory_browser_pick() {
      [[ ${(j:|:)_directory_action_values} != *copy* &&
         ${(j:|:)_directory_action_values} != *open* &&
         ${(j:|:)_directory_action_values} != *reveal* &&
         ${(j:|:)_directory_action_values} != *view-recents* &&
         ${(j:|:)_directory_action_values} != *search-* ]] || return 21
      [[ ${(j:|:)_directory_action_labels} != *"Selected folder"* &&
         ${(j:|:)_directory_action_labels} != *"Go to"* &&
         ${_directory_action_labels[1]} == "Current folder · "* ]] || return 22
      return 1
    }
    _directory_browser_actions "" insert
    (( $? == 1 )) || exit 1
    _directory_browser_open=available
    _directory_browser_pick() {
      (( ! ${_directory_action_values[(Ie)open]} && ${_directory_action_values[(Ie)reveal]} )) || return 23
      return 1
    }
    _directory_browser_actions "" insert
    (( $? == 1 )) || exit 2
    print optional
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal optional "$output"
}
test_case 'folder actions omit empty groups and unavailable capabilities and preserve cancellation' _test_folder_actions_optional_groups
