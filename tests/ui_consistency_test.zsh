_test_ui_consistency_authored_actions() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    _usb_choose() {
      [[ $_USB_PICKER_LABELS[1] == Done && $_USB_PICKER_VALUES[1] == done ]] || return 41
    }
    _usb_windows_unsupported_choose /fixture/example.iso || exit 1
    _xcode_test_result_choose() {
      [[ $_XCODE_PICKER_LABELS[1] == Done && $_XCODE_PICKER_VALUES[1] == done ]] || return 42
      [[ ${_XCODE_PICKER_LABELS[(r)*Copy*]} == "Copy report and done" ]] || return 43
      _ZLE_PICKER_SELECTED_VALUE=done
    }
    _XCODE_TEST_RESULT=Passed _XCODE_TEST_REPORT=report _XCODE_TEST_CLIPBOARD_BINARY=$2
    _xcode_test_result_screen 0 || exit 2
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    _ZLE_PICKER_RESULTS=(literal) _ZLE_PICKER_LABELS=("[ literal filename ]")
    _zle_picker_render "" 1
    [[ ${(j:|:)_ZLE_PICKER_DISPLAY} == *"[ literal filename ]"* ]] || exit 3
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN"
}
test_case 'UI consistency removes authored button brackets without stripping literal labels' _test_ui_consistency_authored_actions

_test_ui_consistency_empty_palette() {
  test_make_temp_dir || return
  local scheme=''
  for scheme in dark light; do
    test_run_interactive "$TEST_TMP_DIR/home" '
      ZSH_COLOR_SCHEME=$2
      source "$1/.zsh.addons/support/.zsh.appearance"
      [[ $ZSH_HIGHLIGHT_STYLES[picker-empty] == "$ZSH_HIGHLIGHT_STYLES[picker-muted]" ]] || exit 1
      [[ $ZSH_HIGHLIGHT_STYLES[picker-error] != "$ZSH_HIGHLIGHT_STYLES[picker-empty]" ]] || exit 2
      source "$1/.zsh.addons/support/.zsh.ui"
      _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
      _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
      _zle_picker_render "unmatched" 0
      [[ $_ZLE_PICKER_DISPLAY_STYLES[2] == picker-empty && $_ZLE_PICKER_DISPLAY[2] == *"no matches"* ]] || exit 3
      (( ! _ZLE_PICKER_INDEXES_VISIBLE )) || exit 4
      ZSH_HIGHLIGHT_STYLES[picker-empty]="fg=123"
      source "$1/.zsh.addons/support/.zsh.appearance"
      _zle_picker_style picker-empty
      [[ $REPLY == "fg=123" ]] || exit 5
    ' "$TEST_REPO_ROOT" "$scheme" || return
  done
}
test_case 'UI consistency treats empty matches as neutral while retaining errors and overrides' _test_ui_consistency_empty_palette

_test_ui_consistency_tool_actions() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.help"
    _COMPOZSH_TOOL_NAMES=(documented unknown limited)
    _COMPOZSH_TOOL_HELPERS=(documented trusted-fixture limited limited-fixture)
    _compozsh_tool_inspector_capture() {
      _ZLE_PICKER_INSPECT_TEXTS=(documented $'"'"'usage: documented\nExplain a documented tool.'"'"' unknown "No help available" limited "Preview limit reached")
    }
    _zle_picker_run() {
      [[ $_ZLE_PICKER_ACCEPT_LABELS[documented] == "read help" && $_ZLE_PICKER_ACCEPT_LABELS[unknown] == inspect ]] || return 41
      [[ $_ZLE_PICKER_DESCRIPTIONS[documented] == "Explain a documented tool." ]] || return 42
      [[ $_ZLE_PICKER_ACCEPT_LABELS[limited] == inspect ]] || return 43
    }
    _compozsh_choose || exit 1
    (( ! ${#_ZLE_PICKER_ACCEPT_LABELS} )) || exit 2
  ' "$TEST_REPO_ROOT"
}
test_case 'UI consistency makes tool acceptance reflect captured help capability' _test_ui_consistency_tool_actions
