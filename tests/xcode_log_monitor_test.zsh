_test_xcode_monitor_fuzzy_exclusion() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    local _xcode_logs_snapshot=$'\''network request failed\nnetwork retry finished\nnetwork request failed\nnoise [*] literal\n'\''
    local _xcode_logs_text="" _xcode_logs_query="" _xcode_logs_exclude="" _ZLE_PICKER_EXCLUDE="retry"
    local _xcode_logs_notice="" _xcode_run_clipboard=/fixture/pbcopy _xcode_logs_severity=all
    local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
    _xcode_logs_collect "nrfd" 0
    [[ $_xcode_logs_matches == 2 && $_xcode_logs_text == $'\''network request failed\nnetwork request failed\n'\'' ]] || { print -u2 "fuzzy matching lost chronology or duplicates"; exit 1; }
    _ZLE_PICKER_EXCLUDE="request"
    _xcode_logs_collect "nrfd" 0
    [[ $_xcode_logs_matches == 1 && $_xcode_logs_text == $'\''network retry finished\n'\'' ]] || exit 2
    _ZLE_PICKER_EXCLUDE="[*]"
    _xcode_logs_collect "" 0
    [[ $_xcode_logs_matches == 3 && $_xcode_logs_text != *noise* ]] || exit 3
    _ZLE_PICKER_EXCLUDE="request failed"
    _xcode_logs_collect "" 0
    [[ $_xcode_logs_matches == 2 && $_xcode_logs_text == *"noise [*] literal"* ]] || exit 4
    print filters
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal filters "$output" 'log search did not share fuzzy and literal exclusion semantics'
}
test_case 'Xcode monitor fuzzy search and exclusion preserve exact raw source order and duplicates' _test_xcode_monitor_fuzzy_exclusion

_test_xcode_monitor_severity() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local first="2026-09-07 12:00:00.000 Er App[12:ab] [com.example:network] Request failed"
    local second="2026-09-07 12:00:01.000 Ft App[12:ab] [com.example:storage] Could not save"
    local _xcode_logs_snapshot="$first"$'\''\n'\''"$second"$'\''\nError is only a word in stdout\n'\''
    local _xcode_logs_text="" _xcode_logs_query="" _xcode_logs_exclude="" _ZLE_PICKER_EXCLUDE=""
    local _xcode_logs_notice="" _xcode_run_clipboard="" _xcode_logs_severity=issues
    local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
    _xcode_logs_collect "" 0
    [[ $_xcode_logs_matches == 2 && $_xcode_logs_errors == 1 && $_xcode_logs_faults == 1 && $_xcode_logs_total == 3 ]] || exit 1
    [[ $_xcode_logs_text == "$first"$'\''\n'\''"$second"$'\''\n'\'' ]] || exit 2
    [[ $_ZLE_PICKER_BROWSE_LABEL == *"1 Error"* && $_ZLE_PICKER_BROWSE_LABEL == *"1 Fault"* ]] || exit 3
    _xcode_logs_severity=all
    _xcode_logs_collect "" 0
    [[ $_xcode_logs_matches == 3 ]] || exit 4
    print severity
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal severity "$output" 'monitor inferred health from plain words or lost native severity'
}
test_case 'Xcode monitor summarizes native severity and can isolate errors and faults' _test_xcode_monitor_severity

_test_xcode_monitor_starts_with_logs() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_initial_logs=1 events=""
    _xcode_logs_capture() { events+=capture, }
    _xcode_logs_reader() { events+=logs,; return 1 }
    _zle_ui_view() { events+=controls }
    _xcode_run_controller || exit
    [[ $events == capture,logs,controls && $_xcode_run_initial_logs == 0 ]] || exit 1
    print monitor
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal monitor "$output" 'Run did not open its primary log reader before controls'
}
test_case 'Xcode monitor opens logs first and Escape returns to run controls' _test_xcode_monitor_starts_with_logs

_test_xcode_monitor_filter_bookmark() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/ui/.zsh.ui.zle_ui_view"
    local _xcode_logs_query=nrfd _xcode_logs_exclude=retry _xcode_logs_exclude_focus=1 _xcode_logs_exclude_shown=1
    local _xcode_logs_follow=0 _xcode_logs_snapshot="network request failed" _xcode_run_context=fixture
    local _xcode_logs_severity=all calls=0
    _zle_picker_loop() {
      (( ++calls ))
      [[ $_ZLE_PICKER_READER_ONLY == 1 && $_ZLE_PICKER_EXCLUSION_ENABLED == 1 && $1 == nrfd && $5 == retry && $6 == 1 && $7 == 1 ]] || return 91
      _ZLE_PICKER_BOOKMARK=(nrfd 0 0 retry 1 1)
      return 1
    }
    _xcode_logs_reader
    [[ $? == 1 && $_xcode_logs_exclude == retry && $_xcode_logs_query == nrfd && $_xcode_logs_exclude_focus == 1 ]] || exit 1
    _xcode_logs_reader
    [[ $? == 1 && $calls == 2 ]] || exit 2
    print bookmark
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bookmark "$output" 'reader lost filter/exclusion field state across reopen'
}
test_case 'Xcode monitor preserves both search fields and their editing focus across reopen' _test_xcode_monitor_filter_bookmark
