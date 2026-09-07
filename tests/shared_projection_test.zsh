_test_shared_decimal_limit() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1"/.zsh.addons/support/functions/.zsh.pure.matching_*(N.); do source "$unit"; done
    local REPLY=sentinel
    _matching_decimal_limit 0008 10 || exit 1
    [[ $REPLY == 8 ]] || exit 2
    _matching_decimal_limit 999999999999999999999999999999 7 || exit 3
    [[ $REPLY == 7 ]] || exit 4
    _matching_decimal_limit 000 0 || exit 5
    [[ $REPLY == 0 ]] || exit 6
    _matching_decimal_limit "1+2" 10 && exit 7
    _matching_decimal_limit 2 -1 && exit 8
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'shared decimal limit preserves literal zero large and invalid bounds' _test_shared_decimal_limit

_test_shared_projection() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1"/.zsh.addons/support/functions/.zsh.*(N.); do source "$unit"; done
    local -a values=("literal [one]" two two) labels=(First Second Third)
    local -a search=(ab "a---b" AB) indexes=(9 4 7)
    _zle_ui_collect ranked ab 10 values labels search "" text indexes || exit 1
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == "literal [one]|two" &&
       ${(j:|:)_ZLE_PICKER_LABELS} == "First|Third" &&
       ${(j:,:)_ZLE_PICKER_RESULT_INDEXES} == 9,7 ]] || exit 2
    _zle_ui_collect source Second 10 values labels labels "" text source || exit 3
    [[ $_ZLE_PICKER_RESULTS == two && $_ZLE_PICKER_RESULT_INDEXES == 2 ]] || exit 4
    _zle_ui_collect source Second 10 values labels labels "" text visible || exit 5
    [[ $_ZLE_PICKER_RESULT_INDEXES == 1 ]] || exit 6
    _zle_ui_collect source "" 10 values labels labels "" text none || exit 7
    [[ ${#_ZLE_PICKER_RESULTS} == 3 && ${#_ZLE_PICKER_RESULT_INDEXES} == 0 ]] || exit 8
    _zle_ui_collect source "" 10 values "labels[1]" labels "" text none && exit 9
    [[ ${(j:|:)labels} == "First|Second|Third" ]] || exit 10
    local -a REPLY=(ab beta)
    _matching_select source beta 10 values REPLY
    [[ $? == 2 ]] || exit 11
    _zle_ui_collect source beta 10 values labels REPLY "" text source
    [[ $? == 2 ]] || exit 12
    [[ ${(j:|:)REPLY} == "ab|beta" ]] || exit 13
    _ZLE_PICKER_RESULTS=(sentinel)
    _zle_ui_collect source "" 10 _ZLE_PICKER_RESULTS labels labels "" text source
    [[ $? == 2 && $_ZLE_PICKER_RESULTS == sentinel ]] || exit 14
    print projected
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal projected "$output"
}
test_case 'shared projection retains literal targets ordering labels and caller numbering' _test_shared_projection

_test_shared_usb_progress() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1"/.zsh.addons/support/functions/.zsh.pure.usb_*(N.); do source "$unit"; done
    local -a reply=()
    _USB_PROGRESS_BAR=sentinel
    _usb_progress_model 512 1024 65 10 || exit 1
    [[ $reply[1] == "[=====·····] 50%" &&
       $reply[2] == "512 bytes of 1.0 KiB · 1m 5s elapsed" ]] || exit 2
    _usb_progress_model 999 10 0 10 "literal [phase]" || exit 3
    [[ $reply[1] == "[==========] 100%" &&
       $reply[2] == "literal [phase] · 10 bytes of 10 bytes · 0s elapsed" ]] || exit 4
    [[ $_USB_PROGRESS_BAR == sentinel ]] || exit 5
    _usb_progress_model 0 0 -1 10 || exit 6
    [[ $reply[1] == "[··········] 0%" &&
       $reply[2] == "0 bytes of 0 bytes · 0s elapsed" ]] || exit 7
    _usb_progress_model "1+2" 10 0 10 && exit 8
    (( !${#reply} )) || exit 9
    print modeled
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal modeled "$output"
}
test_case 'shared USB progress models captured facts without changing effect state' _test_shared_usb_progress
