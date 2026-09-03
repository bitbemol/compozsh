_test_action_matching_keeps_feature_order_and_literal_targets() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/.zsh.usb"
    local -a _XCODE_PICKER_VALUES=("fuzzy [exact]" duplicate prefix duplicate metadata)
    local -a _XCODE_PICKER_LABELS=(a---b "in ab" AB "another ab" none)
    local -a _XCODE_PICKER_SEARCH=("" "" "" "" "a b")
    local -a _USB_PICKER_VALUES=("${_XCODE_PICKER_VALUES[@]}")
    local -a _USB_PICKER_LABELS=("${_XCODE_PICKER_LABELS[@]}")
    local -a _USB_PICKER_SEARCH=("${_XCODE_PICKER_SEARCH[@]}")
    _xcode_picker_collect ab 10
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == "fuzzy [exact]|duplicate|prefix|duplicate|metadata" ]] || exit 1
    _usb_picker_collect ab 10
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == "prefix|duplicate|fuzzy [exact]|metadata" ]] || exit 2
    local query="" collector=""
    for query in "[" "(" "*" "?" "\\" "a b"; do
      _XCODE_PICKER_VALUES=("exact [value]" other)
      _XCODE_PICKER_LABELS=("$query" unrelated) _XCODE_PICKER_SEARCH=("" "")
      _USB_PICKER_VALUES=("${_XCODE_PICKER_VALUES[@]}")
      _USB_PICKER_LABELS=("${_XCODE_PICKER_LABELS[@]}") _USB_PICKER_SEARCH=("" "")
      for collector in _xcode_picker_collect _usb_picker_collect; do
        "$collector" "$query" 10
        [[ ${#_ZLE_PICKER_RESULTS} == 1 && $_ZLE_PICKER_RESULTS[1] == "exact [value]" ]] || exit 3
        "$collector" "" 1
        [[ ${#_ZLE_PICKER_RESULTS} == 1 && $_ZLE_PICKER_RESULTS[1] == "exact [value]" ]] || exit 4
      done
    done
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'Action matching preserves feature ordering, deduplication and literal targets' \
  _test_action_matching_keeps_feature_order_and_literal_targets

_test_action_matching_missing_capability_fallbacks() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh\nprint -r -- "native-xcode:$*"' || return
  command chmod +x "$fake_bin/xcodebuild" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/.zsh.usb"
    unfunction _matching_compile
    _xcode_container_discover() {
      _XCODE_CONTAINERS=(/synthetic/App.xcodeproj)
      _XCODE_CONTAINER_KINDS=(project)
    }
    _zle_picker_run() { print forbidden-ui; return 1; }
    _usb_images_capture() { print forbidden-provider; return 1; }
    _action_fallback_fixture() {
      xcode
      print -r -- "xcode-status:$?"
      flash-usb
      print -r -- "flash-status:$?"
      format-external-device
      print -r -- "format-status:$?"
      print END-FALLBACK
    }
    zmodload zsh/zpty || exit 1
    local chunk="" captured=""
    zpty action-fallback _action_fallback_fixture || exit 2
    {
      while zpty -r action-fallback chunk; do
        captured+=$chunk
        [[ $chunk == *END-FALLBACK* ]] && break
      done
      [[ $captured == *END-FALLBACK* && $captured != *forbidden-* ]] || {
        print -u2 -r -- "$captured"; exit 3
      }
      [[ $captured == *"native-xcode:-project /synthetic/App.xcodeproj"* &&
         $captured == *"-list"* && $captured == *"xcode-status:0"* &&
         $captured == *"flash-status:1"* && $captured == *"format-status:1"* ]] || {
        print -u2 -r -- "$captured"; exit 4
      }
    } always {
      zpty -d action-fallback
    }
    print guarded
  ' "$TEST_REPO_ROOT" "$fake_bin") || return
  test_assert_equal guarded "$output"
}
test_case 'Action matching missing capability uses public native and refusal fallbacks' \
  _test_action_matching_missing_capability_fallbacks
