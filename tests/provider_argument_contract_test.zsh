# Captured counts and explicit targets stay literal across reusable callers.
_test_provider_literal_xcode_children() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.pure.matching_decimal_limit"
    local fixture_count="" expected=0
    local -a cases=("1+1" 1 "0" 1 "0002" 3 "9999999999999999999999999999999999999999999999999999" 65)
    _compozsh_plutil_raw() { [[ $2 == root.children ]] || return 1; REPLY=$fixture_count; }
    while (( ${#cases} )); do
      fixture_count=$cases[1] expected=$cases[2]
      shift 2 cases
      _XCODE_TEST_DETAIL_NODE_COUNT=0
      _xcode_test_node_sources_capture "{}" root 2> "$HOME/error"
      [[ $_XCODE_TEST_DETAIL_NODE_COUNT == "$expected" && ! -s "$HOME/error" ]] || exit 1
    done
    unfunction _matching_decimal_limit
    fixture_count=2 _XCODE_TEST_DETAIL_NODE_COUNT=0
    _xcode_test_node_sources_capture "{}" root 2> "$HOME/error"
    [[ $_XCODE_TEST_DETAIL_NODE_COUNT == 1 && ! -s "$HOME/error" ]] || exit 2
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'provider arguments bound Xcode child counts before arithmetic and omit missing count support' _test_provider_literal_xcode_children

_test_provider_literal_xcode_failures() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.pure.matching_decimal_limit"
    commands[xcrun]=/usr/bin/true
    _xcode_capture_command() { _XCODE_CAPTURE="{}"; }
    _xcode_test_build_issues_capture() { return 0; }
    _xcode_test_failure_files_capture() { return 1; }
    local fixture_count="" expected=0
    local -a cases=("1+1" 0 "0" 0 "0002" 2 "9999999999999999999999999999999999999999999999999999" 20)
    _compozsh_plutil_raw() { [[ $2 == testFailures ]] || return 1; REPLY=$fixture_count; }
    while (( ${#cases} )); do
      fixture_count=$cases[1] expected=$cases[2]
      shift 2 cases
      _xcode_test_result_capture /fixture.xcresult 1 2> "$HOME/error"
      [[ ${#_XCODE_TEST_FAILURE_NAMES} == "$expected" && ! -s "$HOME/error" ]] || exit 1
    done
    unfunction _matching_decimal_limit
    fixture_count=2
    _xcode_test_result_capture /fixture.xcresult 1 2> "$HOME/error"
    [[ ${#_XCODE_TEST_FAILURE_NAMES} == 0 && ! -s "$HOME/error" ]] || exit 2
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'provider arguments bound Xcode failure counts before arithmetic and omit missing count support' _test_provider_literal_xcode_failures

_test_provider_explicit_macos_review_target() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    _USB_DISK_IDS=(disk7 disk8)
    _USB_DISK_LABELS=(DriveA DriveB)
    _USB_DISK_DETAILS=(DetailsA DetailsB)
    _USB_IMAGE_PATHS=(/fixture.app)
    _USB_IMAGE_DETAILS=(Installer)
    _usb_choose() { REPLY="$2|${_USB_PICKER_LABELS[4]}"; }
    local disk_index=1
    _usb_macos_review_choose /fixture.app 2
    [[ $REPLY == *"/dev/disk8|Change drive · DriveB" && $disk_index == 1 ]] || exit 1
    unset disk_index
    _usb_macos_review_choose /fixture.app 2
    [[ $REPLY == *"/dev/disk8|Change drive · DriveB" ]] || exit 2
    print exact
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal exact "$output"
}
test_case 'provider arguments keep macOS review target independent of absent or conflicting caller index' _test_provider_explicit_macos_review_target
