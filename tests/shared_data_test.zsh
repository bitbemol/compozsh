# Shared transformations consume literal captured data; effects stay in callers.
_test_shared_data_matching_contract() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    local -a reply=() values=("literal [target]" duplicate prefix duplicate metadata)
    local -a texts=(a---b "in ab" AB "another ab" "a b")
    _matching_select ranked ab 10 values texts || exit 1
    [[ ${(j:,:)reply} == 3,2,1,5 ]] || exit 2
    _matching_select source ab 10 values texts || exit 3
    [[ ${(j:,:)reply} == 1,2,3,4,5 ]] || exit 4
    _matching_select ranked "" 10 values texts || exit 5
    [[ ${(j:,:)reply} == 1,2,3,4,5 ]] || exit 6
    _matching_select ranked ab 2 values texts || exit 7
    [[ ${(j:,:)reply} == 3,2 ]] || exit 8
    local -a literal_values=(one two) literal_texts=("a[---?" plain)
    _matching_select ranked "[?" 9999999999999999999999999999 literal_values literal_texts || exit 9
    [[ $reply == 1 ]] || exit 10
    _matching_select ranked ab 0 values texts || exit 11
    (( !${#reply} )) || exit 12
    [[ ${(j:|:)values} == "literal [target]|duplicate|prefix|duplicate|metadata" ]] || exit 13
    (( ! ${+_ZLE_PICKER_RESULTS} )) || exit 14
    _matching_select ranked ab 10 "values[1]" texts && exit 15
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared data selection preserves ranking duplicates literals bounds and input ownership' \
  _test_shared_data_matching_contract

_test_shared_data_action_contract() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    local -a reply=()
    local -a values=(one "exact [target]" three) labels=(Plain "[literal]" Other)
    _zle_ui_collect source "[" 10 values labels labels "" text source || exit 1
    [[ $_ZLE_PICKER_RESULTS == "exact [target]" && $_ZLE_PICKER_RESULT_INDEXES == 2 ]] || exit 2
    _zle_ui_collect source "[" 10 values labels labels "" text visible || exit 3
    [[ $_ZLE_PICKER_RESULT_INDEXES == 1 && $_ZLE_PICKER_LABELS == "[literal]" ]] || exit 4
    _zle_ui_descriptions one "first
second" "literal [key]" "" || exit 5
    [[ ${#reply} == 4 && $reply[2] == first && $reply[3] == "literal [key]" && -z $reply[4] ]] || exit 6
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared data action rows preserve source and visible indexes and literal descriptions' \
  _test_shared_data_action_contract

_test_shared_data_result_contract() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    local -a reply=()
    _USB_RESULT_OUTCOME=sentinel
    _usb_result_model windows-installer 0 outcome complete verified 0 verify_scope windows-file-tree started 1 ejected 0 || exit 1
    [[ $reply[1] == *"Couldn’t complete"* && ${reply[-4]} == "Check the drive before removing it" ]] || exit 2
    _usb_result_model macos-installer 0 outcome complete verified 1 source_validated 1 started 1 ejected 1 || exit 3
    [[ $reply[1] == *Complete && ${(j:|:)reply} == *"Apple-signed full installer"* && ${(j:|:)reply} != *"byte-for-byte"* ]] || exit 4
    _usb_result_model raw 1 outcome failed started 0 ejected 0 error "literal [error] %F{red}" || exit 5
    [[ ${(j:|:)reply} == *"literal [error] %F{red}"* && ${reply[-4]} == "Nothing was written · drive remains mounted" ]] || exit 6
    [[ $_USB_RESULT_OUTCOME == sentinel ]] || exit 7
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared data result model keeps verification claims literal errors and effect state separate' \
  _test_shared_data_result_contract

_test_shared_data_path_actions() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    local -a reply=()
    _zle_ui_path_actions 0 0 0 0 "Copy path" enter-link open reveal copy insert || exit 1
    [[ ${#reply} == 4 && $reply[1] == insert ]] || exit 2
    _zle_ui_path_actions 1 1 1 1 "Copy absolute path" copy open reveal enter-link || exit 3
    [[ ${#reply} == 16 && $reply[1] == copy && $reply[2] == "Copy absolute path" &&
       $reply[5] == open && $reply[9] == reveal && $reply[16] == "follow link" ]] || exit 4
    [[ $reply[7] == *"only open files you trust"* ]] || exit 5
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared data path action catalog preserves capabilities ordering and explicit effects' \
  _test_shared_data_path_actions
