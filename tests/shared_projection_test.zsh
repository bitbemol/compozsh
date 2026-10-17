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
    local -a search=(ab "a---b" AB)
    _zle_ui_collect ranked ab 10 values labels search "" text || exit 1
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == "literal [one]|two" &&
       ${(j:|:)_ZLE_PICKER_LABELS} == "First|Third" ]] || exit 2
    _zle_ui_collect source Second 10 values labels labels "" text || exit 3
    [[ $_ZLE_PICKER_RESULTS == two && $_ZLE_PICKER_LABELS == Second ]] || exit 4
    # Numbering belongs to the view: a ninth argument is refused, and the
    # collector neither publishes indexes nor chooses zero-based slots.
    _zle_ui_collect source Second 10 values labels labels "" text visible && exit 5
    (( !${#_ZLE_PICKER_RESULTS} && !${+_ZLE_PICKER_ZERO_BASED} &&
       !${+_ZLE_PICKER_RESULT_INDEXES} )) || exit 6
    _zle_ui_collect source "" 10 values labels labels "" text || exit 7
    [[ ${#_ZLE_PICKER_RESULTS} == 3 ]] || exit 8
    _zle_ui_collect source "" 10 values "labels[1]" labels "" text && exit 9
    [[ ${(j:|:)labels} == "First|Second|Third" ]] || exit 10
    local -a REPLY=(ab beta)
    _matching_select source beta 10 values REPLY
    [[ $? == 2 ]] || exit 11
    _zle_ui_collect source beta 10 values labels REPLY "" text
    [[ $? == 2 ]] || exit 12
    [[ ${(j:|:)REPLY} == "ab|beta" ]] || exit 13
    _ZLE_PICKER_RESULTS=(sentinel)
    _zle_ui_collect source "" 10 _ZLE_PICKER_RESULTS labels labels "" text
    [[ $? == 2 && $_ZLE_PICKER_RESULTS == sentinel ]] || exit 14
    print projected
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal projected "$output"
}
test_case 'shared projection retains literal targets ordering and labels and leaves numbering to the view' _test_shared_projection

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

_test_support_pure_usb_numeric_text() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    exec 2>&1
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/functions/.zsh.pure.usb_progress_bar"
    source "$1/.zsh.addons/support/functions/.zsh.pure.usb_human_duration"
    local REPLY="" value="" sentinel=7
    local -a a=(1)
    _usb_progress_bar 50 10 || exit 1
    [[ $REPLY == "[=====·····] 50%" ]] || exit 2
    _usb_progress_bar 010 010 || exit 3
    [[ $REPLY == "[=·········] 10%" ]] || exit 4
    _usb_progress_bar -5 -3 || exit 5
    [[ $REPLY == "[··········] 0%" ]] || exit 6
    _usb_progress_bar "" "" || exit 7
    [[ $REPLY == "[${(l:32::·:)}] 0%" ]] || exit 8
    _usb_human_duration 0100 || exit 9
    [[ $REPLY == "1m 40s" ]] || exit 10
    _usb_human_duration -4 || exit 11
    [[ $REPLY == 0s ]] || exit 12
    _usb_human_duration "" || exit 13
    [[ $REPLY == 0s ]] || exit 14
    _usb_human_duration 999999999999999999 || exit 15
    [[ $REPLY == "277777777777777h 46m 39s" ]] || exit 16
    COLUMNS=12
    for value in COLUMNS "sentinel=99" "1+1" "a[\$(print -u2 substituted)1]" - \
        9999999999999999999 -9999999999999999999; do
      REPLY=stale
      _usb_progress_bar "$value" 10
      [[ $? == 2 && -z $REPLY ]] || { print -r -- "bar accepted percent ${(qqq)value}: ${(qqq)REPLY}"; exit 17; }
      REPLY=stale
      _usb_progress_bar 50 "$value"
      [[ $? == 2 && -z $REPLY ]] || { print -r -- "bar accepted width ${(qqq)value}: ${(qqq)REPLY}"; exit 18; }
      REPLY=stale
      _usb_human_duration "$value"
      [[ $? == 2 && -z $REPLY ]] || { print -r -- "duration accepted ${(qqq)value}: ${(qqq)REPLY}"; exit 19; }
    done
    (( sentinel == 7 )) || exit 20
    source "$1/.zsh.addons/support/functions/.zsh.pure.usb_human_size"
    source "$1/.zsh.addons/support/functions/.zsh.pure.usb_progress_model"
    local -a reply=() arguments=()
    _usb_progress_model 999999999999999999 999999999999999999 -999999999999999999 999 || exit 21
    for value in "9999999999999999999 1 0 10" "1 9999999999999999999 0 10" \
        "1 2 1234567890123456789 32" "1 2 +1234567890123456789 32" "1 2 0 9999999999999999999"; do
      arguments=(${=value}) reply=(stale)
      _usb_progress_model "${arguments[@]}"
      [[ $? == 2 && ${#reply} == 0 ]] || { print -r -- "model accepted ${(qqq)value}: ${(qqq)reply}"; exit 22; }
    done
    print validated
  ' "$TEST_REPO_ROOT") || { print -r -- "$output"; return 1; }
  test_assert_equal validated "$output"
}
test_case 'support pure USB progress bar and duration validate numeric text before integer assignment' \
  _test_support_pure_usb_numeric_text
