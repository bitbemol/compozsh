# Action workspaces consume shared acceptance defaults while retaining exact
# targets, feature-owned details, and exceptional post-cleanup operations.
_test_action_ui_acceptance_defaults() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/.zsh.usb"
    local fixture="" expected_action=choose expected_value="" result=0
    _ZLE_PICKER_ACCEPT_LABELS=(outer execute)
    _ZLE_PICKER_INSPECT_ACTION=execute
    _zle_picker_loop() {
      "$_ZLE_PICKER_COLLECTOR" "" 20
      _ZLE_PICKER_SELECTED=${#_ZLE_PICKER_RESULTS}
      [[ ${_ZLE_PICKER_RESULTS[-1]} == "$expected_value" ]] || return 20
      _ZLE_PICKER_QUERY=""
      _zle_picker_titlebar 160
      [[ $_ZLE_PICKER_TITLEBAR == *"Enter: $expected_action · Results"* ]] || return 21
      _zle_picker_footer 160 ""
      [[ $REPLY == "⏎ $expected_action · Esc "* ]] || return 22
      case $fixture in
        usb-plain)
          (( !${#_ZLE_PICKER_INSPECT_TEXTS} && !${#_ZLE_PICKER_LABEL_HIGHLIGHTS} )) || return 23 ;;
        usb-details|xcode)
          [[ ${_ZLE_PICKER_INSPECT_TEXTS[$expected_value]} == "Captured detail" ]] || return 24 ;;
        usb-highlight)
          [[ ${_ZLE_PICKER_LABEL_HIGHLIGHTS[$expected_value]} == "0:4:picker-success" ]] || return 25 ;;
        result*)
          [[ ${_ZLE_PICKER_INSPECT_TEXTS[$expected_value]} == "Captured detail" ]] || return 26 ;;
      esac
      _ZLE_PICKER_SELECTED_VALUE=$expected_value _ZLE_PICKER_ACTION=select
      return 17
    }
    for fixture in usb-plain usb-details usb-highlight xcode result-done result-copy; do
      expected_action=choose expected_value="literal [target] % value"
      _XCODE_PICKER_VALUES=(first "$expected_value")
      _XCODE_PICKER_LABELS=(First Last) _XCODE_PICKER_DETAILS=("" "Captured detail")
      _XCODE_PICKER_HIGHLIGHTS=("" "0:4:picker-success") _XCODE_PICKER_SEARCH=()
      _USB_PICKER_VALUES=("${_XCODE_PICKER_VALUES[@]}")
      _USB_PICKER_LABELS=("${_XCODE_PICKER_LABELS[@]}")
      _USB_PICKER_DETAILS=("${_XCODE_PICKER_DETAILS[@]}")
      _USB_PICKER_HIGHLIGHTS=("${_XCODE_PICKER_HIGHLIGHTS[@]}") _USB_PICKER_SEARCH=()
      case $fixture in
        usb-plain) _usb_choose Title Scope Filter ;;
        usb-details) _usb_choose Title Scope Filter 1 ;;
        usb-highlight) _usb_choose Title Scope Filter 0 0 1 ;;
        xcode) _xcode_choose Title Scope Filter ;;
        result-done)
          expected_action=done
          _xcode_test_result_choose Title Scope ;;
        result-copy)
          expected_action="copy report and done" expected_value=copy-report
          _XCODE_PICKER_VALUES[-1]=$expected_value
          _xcode_test_result_choose Title Scope ;;
      esac
      result=$?
      (( result == 17 )) || { print -u2 -- "$fixture failed: $result"; exit 1; }
      [[ $_ZLE_PICKER_SELECTED_VALUE == "$expected_value" &&
         $_ZLE_PICKER_ACTION == select && $_ZLE_PICKER_INSPECT_ACTION == execute &&
         ${_ZLE_PICKER_ACCEPT_LABELS[outer]} == execute ]] || exit 2
    done
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'Action UI adapters preserve visible acceptance, exact targets and scoped metadata' \
  _test_action_ui_acceptance_defaults

_test_action_ui_format_name_contract() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    local -a trace=() erased=()
    local name="" personality="" result=0
    _usb_target_revalidate() { trace+=("check:$1:$2:$3"); }
    _usb_authorize() { trace+=(authorize); }
    _usb_diskutil_erase_run() { trace+=(erase); erased=("$@"); }
    for personality in APFS JHFS+; do
      for name in ${(l:129::x:)} ${(l:255::x:)}; do
        _usb_volume_name_validate "$name" "$personality" || exit 1
        trace=() erased=()
        _usb_format_execute disk9 captured-fingerprint "$personality" "$name" 90000
        result=$?
        (( result == 0 )) || { print -u2 -- "$personality rejected ${#name} validated characters: $result"; exit 2; }
        [[ ${(j:|:)trace} == "check:disk9:captured-fingerprint:1|authorize|check:disk9:captured-fingerprint:1|erase" &&
           ${#erased} == 4 && $erased[1] == eraseDisk && $erased[2] == "$personality" &&
           $erased[3] == "$name" && $erased[4] == /dev/disk9 ]] || exit 3
      done
    done
    for name in ${(l:256::x:)} "bad/name" " leading" "bad:name"; do
      trace=() erased=()
      _usb_format_execute disk9 captured-fingerprint APFS "$name" 90000
      result=$?
      (( result == 2 && !${#trace} && !${#erased} )) || {
        print -u2 -- "invalid APFS name reached execution: $result ${#trace}"; exit 4
      }
    done
    trace=() erased=()
    _usb_format_execute disk9 captured-fingerprint ExFAT "Too long portable name" 90000
    result=$?
    (( result == 2 && !${#trace} && !${#erased} )) || exit 5
    print validated
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal validated "$output"
}
test_case 'Action UI format dispatch shares the validated volume-name contract' \
  _test_action_ui_format_name_contract

_test_action_ui_format_failure_status() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    _usb_target_revalidate() { return 0; }
    _usb_authorize() { return 0; }
    _usb_diskutil_erase_run() { print -u2 -- native-format-error; return 7; }
    _usb_format_execute disk9 captured-fingerprint APFS External 90000 2> "$HOME/error"
    local result=$?
    (( result == 7 )) || { print -u2 -- "native diskutil status changed to $result"; exit 1; }
    [[ $(<"$HOME/error") == native-format-error &&
       $_USB_FORMAT_ERROR == *"prior layout may already be changed"* ]] || exit 2
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'Action UI format dispatch preserves native failure status and diagnostics' \
  _test_action_ui_format_failure_status
