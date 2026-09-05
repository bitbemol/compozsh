# Feature adapters preserve task data while shared components scope view state.

_test_ui_feature_choice_scopes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.git-worktree"
    source "$1/.zsh.addons/.zsh.git-review"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT_FOLLOW=1
    _ZLE_PICKER_INSPECT_FIXED_KEY=outer _ZLE_PICKER_IDLE_CALLBACK=outer-callback
    _ZLE_PICKER_INSPECT_STACKED=1 _ZLE_PICKER_INSPECT_CLIP_LINES=1
    _ZLE_PICKER_PASSIVE_LINES=(outer) _ZLE_PICKER_GUIDE_CONTEXT=(outer)
    _ZLE_PICKER_INSPECT_TEXTS=(outer "outer details")
    local fixture="" result=0
    local -A _git_compare_details=() _git_compare_actions=()
    _zle_picker_loop() {
      (( !_ZLE_PICKER_DOCUMENT && !_ZLE_PICKER_READER_ONLY &&
          _ZLE_PICKER_DOCUMENT_FOLLOW == -1 && !_ZLE_PICKER_INSPECT_STACKED &&
          !_ZLE_PICKER_INSPECT_CLIP_LINES && !_ZLE_PICKER_COPY_ENABLED )) || {
        print -u2 -- "$fixture inherited reader capabilities"; return 30
      }
      [[ -z $_ZLE_PICKER_INSPECT_FIXED_KEY && -z $_ZLE_PICKER_IDLE_CALLBACK &&
         ${#_ZLE_PICKER_GUIDE_CONTEXT} == 0 ]] || return 31
      case $fixture in
        xcode)
          [[ ${_ZLE_PICKER_INSPECT_TEXTS[key]} == detail &&
             ${_ZLE_PICKER_LABEL_HIGHLIGHTS[key]} == "0:6:picker-header" &&
             ${_ZLE_PICKER_ACCEPT_LABELS[key]} == option &&
             ${_ZLE_PICKER_DESCRIPTIONS[key]} == setting && $_ZLE_PICKER_ACTION_VIEW == 1 ]] || return 32 ;;
        usb)
          [[ ${_ZLE_PICKER_INSPECT_TEXTS[key]} == detail &&
             ${_ZLE_PICKER_LABEL_HIGHLIGHTS[key]} == "0:6:picker-success" &&
             ${_ZLE_PICKER_ACCEPT_LABELS[key]:-$_ZLE_PICKER_INSPECT_ACTION} == choose ]] || return 33 ;;
        worktree)
          [[ ${_ZLE_PICKER_INSPECT_TEXTS[key]} == detail &&
             ${_ZLE_PICKER_ACCEPT_LABELS[key]} == inspect &&
             $_ZLE_PICKER_OPTIONS_KIND == worktree ]] || return 34 ;;
        review)
          [[ ${_ZLE_PICKER_INSPECT_TEXTS[key]} == detail &&
             ${_ZLE_PICKER_ACCEPT_LABELS[key]} == use ]] || return 35 ;;
      esac
      (( ${#_ZLE_PICKER_INSPECT_TEXTS} == 1 && ${#_ZLE_PICKER_PASSIVE_LINES} == 0 )) || return 36
      _ZLE_PICKER_SELECTED_VALUE=key _ZLE_PICKER_ACTION=select
      _ZLE_PICKER_BOOKMARK=(query 2 1)
      return 17
    }
    for fixture in xcode usb worktree review; do
      case $fixture in
        xcode)
          _XCODE_PICKER_VALUES=(key) _XCODE_PICKER_LABELS=("Option · setting")
          _XCODE_PICKER_DETAILS=(detail)
          _xcode_choose Title Scope Filter options ;;
        usb)
          _USB_PICKER_VALUES=(key) _USB_PICKER_LABELS=("Option · setting")
          _USB_PICKER_DETAILS=(detail) _USB_PICKER_HIGHLIGHTS=("0:6:picker-success")
          _usb_choose Title Scope Filter 1 0 1 ;;
        worktree)
          _GWT_DETAILS=(key detail) _GWT_LABELS=(key inspect)
          _git_worktree_pick Title Scope Filter ;;
        review)
          _git_compare_details=(key detail) _git_compare_actions=(key use)
          _git_review_pick Title Scope Filter ;;
      esac
      result=$?
      (( result == 17 )) || { print -u2 -- "$fixture returned $result"; exit 1; }
      (( _ZLE_PICKER_DOCUMENT && _ZLE_PICKER_READER_ONLY && _ZLE_PICKER_DOCUMENT_FOLLOW == 1 )) || exit 2
      [[ $_ZLE_PICKER_INSPECT_FIXED_KEY == outer && $_ZLE_PICKER_IDLE_CALLBACK == outer-callback &&
         $_ZLE_PICKER_SELECTED_VALUE == key && ${(j:|:)_ZLE_PICKER_BOOKMARK} == query\|2\|1 ]] || exit 3
    done
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'UI feature choice adapters isolate prior readers and preserve captured details and outputs' \
  _test_ui_feature_choice_scopes

_test_ui_feature_query_scopes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.git-worktree"
    source "$1/.zsh.addons/.zsh.git-review"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT_FOLLOW=1
    _ZLE_PICKER_INSPECT_FIXED_KEY=outer _ZLE_PICKER_IDLE_CALLBACK=outer-callback
    _ZLE_PICKER_PASSIVE_LINES=(outer) _ZLE_PICKER_INSPECT_TEXTS=(outer detail)
    _GWT_ROOT=/example
    local fixture="" result=0
    _zle_picker_loop() {
      (( _ZLE_PICKER_QUERY_SUBMIT && !_ZLE_PICKER_DIGIT_SELECT &&
          !_ZLE_PICKER_DOCUMENT && !_ZLE_PICKER_READER_ONLY && !_ZLE_PICKER_COPY_ENABLED &&
          _ZLE_PICKER_DOCUMENT_FOLLOW == -1 )) || return 30
      [[ $_ZLE_PICKER_COLLECTOR == _zle_picker_query_collect &&
         -z $_ZLE_PICKER_INSPECT_FIXED_KEY && -z $_ZLE_PICKER_IDLE_CALLBACK &&
         ${#_ZLE_PICKER_PASSIVE_LINES} == 0 && ${#_ZLE_PICKER_INSPECT_TEXTS} == 0 &&
         ${#_ZLE_PICKER_EMPTY_LINES} -gt 0 ]] || return 31
      _ZLE_PICKER_RESULTS=(stale) _ZLE_PICKER_LABELS=(stale)
      "$_ZLE_PICKER_COLLECTOR" query 10
      (( !${#_ZLE_PICKER_RESULTS} && !${#_ZLE_PICKER_LABELS} )) || return 32
      return 1
    }
    for fixture in image checksum volume worktree revision; do
      case $fixture in
        image) _usb_read_image_path Scope ;;
        checksum) _usb_read_checksum Scope draft ;;
        volume) _usb_read_volume_name Scope draft ;;
        worktree) _git_worktree_text Title Query draft Guidance ;;
        revision) _git_review_revision_text /example From draft ;;
      esac
      result=$?
      (( result == 1 )) || { print -u2 -- "$fixture returned $result"; exit 1; }
      (( _ZLE_PICKER_DOCUMENT && _ZLE_PICKER_READER_ONLY && _ZLE_PICKER_DOCUMENT_FOLLOW == 1 )) || exit 2
    done
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'UI feature literal query views share empty collection and suppress prior reader capabilities' \
  _test_ui_feature_query_scopes

_test_ui_feature_passive_results() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    local fixture="" result=0
    _zle_picker_loop() {
      if [[ $fixture == usb ]]; then
        [[ ${(j:|:)_ZLE_PICKER_PASSIVE_LINES} == "Verified|Issue" &&
           ${(j:|:)_ZLE_PICKER_PASSIVE_STYLES} == "picker-success|picker-error" &&
           ${(j:|:)_USB_PICKER_VALUES} == done ]] || return 30
      elif [[ $fixture == windows ]]; then
        (( ${#_ZLE_PICKER_PASSIVE_LINES} == 5 )) || return 31
        [[ $_ZLE_PICKER_PASSIVE_STYLES[1] == picker-error &&
           $_ZLE_PICKER_PASSIVE_STYLES[5] == picker-success ]] || return 32
      else
        [[ ${(j:|:)_ZLE_PICKER_PASSIVE_LINES} == "Passed" &&
           ${_ZLE_PICKER_ACCEPT_LABELS[copy-report]} == "copy report and done" ]] || return 33
      fi
      return 1
    }
    for fixture in usb windows xcode; do
      case $fixture in
        usb)
          _USB_PICKER_VALUES=(done verified issue) _USB_PICKER_LABELS=(Done Verified Issue)
          _USB_PICKER_HIGHLIGHTS=("" "0:8:picker-success" "0:5:picker-error")
          _USB_PICKER_SEARCH=(done verified issue) _USB_PICKER_DETAILS=("" "" "")
          _usb_result_choose Result Scope ;;
        windows) _usb_windows_unsupported_choose /example.iso ;;
        xcode)
          _XCODE_PICKER_VALUES=(copy-report) _XCODE_PICKER_LABELS=(Copy)
          _XCODE_PICKER_DETAILS=(detail) _XCODE_PICKER_HIGHLIGHTS=("")
          _XCODE_TEST_PASSIVE_LINES=(Passed) _XCODE_TEST_PASSIVE_STYLES=(picker-success)
          _xcode_test_result_choose Result Scope ;;
      esac
      result=$?
      (( result == 1 )) || { print -u2 -- "$fixture lost passive result rows: $result"; exit 1; }
    done
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'UI feature result views preserve passive rows and explicit completion actions' \
  _test_ui_feature_passive_results

_test_ui_feature_xcode_reader_bookmark_scope() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.xcode"
    _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_DIRECTORY_ACTIONS=1
    _ZLE_PICKER_HIERARCHY_ENABLED=1 _ZLE_PICKER_QUERY_SUBMIT=1
    _ZLE_PICKER_DOCUMENT_FOLLOW=1 _ZLE_PICKER_INSPECT_FIXED_KEY=outer
    local fixture=reader result=0
    local _xcode_logs_follow=0 _xcode_logs_query=draft _xcode_logs_offset=7
    local _xcode_logs_row=12 _xcode_logs_width=60 _xcode_logs_matches=3 _xcode_logs_total=4
    local _xcode_logs_text=example _xcode_run_clipboard=/fixture/clipboard
    _xcode_logs_capture() { print -u2 unexpected-capture; return 99; }
    _zle_picker_loop() {
      (( !_ZLE_PICKER_WORKSPACE_ACTIONS && !_ZLE_PICKER_DIRECTORY_ACTIONS &&
          !_ZLE_PICKER_HIERARCHY_ENABLED && !_ZLE_PICKER_QUERY_SUBMIT )) || return 30
      if [[ $fixture == reader ]]; then
        (( _ZLE_PICKER_DOCUMENT && _ZLE_PICKER_READER_ONLY &&
            !_ZLE_PICKER_DIGIT_SELECT && !_ZLE_PICKER_IDLE_PREPAINT )) || return 31
        [[ $_ZLE_PICKER_IDLE_CALLBACK == _xcode_logs_idle &&
           $_ZLE_PICKER_INSPECT_FIXED_KEY == logs && $1 == draft ]] || return 32
        _ZLE_PICKER_DOCUMENT_FOLLOW=1
        _ZLE_PICKER_BOOKMARK=(filtered 0 0)
        _ZLE_PICKER_DOCUMENT_OFFSETS[logs]=17
        _ZLE_PICKER_DOCUMENT_ROWS[logs]=24
        _ZLE_PICKER_DOCUMENT_WIDTHS[logs]=80
      else
        (( !_ZLE_PICKER_DOCUMENT && !_ZLE_PICKER_READER_ONLY &&
            _ZLE_PICKER_DOCUMENT_FOLLOW == -1 && _ZLE_PICKER_DIGIT_SELECT )) || return 33
        [[ $_ZLE_PICKER_IDLE_CALLBACK == _xcode_run_capture_idle &&
           -z $_ZLE_PICKER_INSPECT_FIXED_KEY ]] || return 34
        (( ${_XCODE_PICKER_VALUES[(Ie)copy]} )) || return 35
      fi
      return 1
    }
    _xcode_logs_reader; result=$?
    (( result == 1 )) || { print -u2 -- "reader returned $result"; exit 1; }
    [[ $_xcode_logs_query == filtered && $_xcode_logs_follow == 1 &&
       $_xcode_logs_offset == 17 && $_xcode_logs_row == 24 && $_xcode_logs_width == 80 ]] || exit 2
    fixture=options
    _xcode_logs_options; result=$?
    (( result == 1 )) || { print -u2 -- "options returned $result"; exit 3; }
    [[ $_ZLE_PICKER_INSPECT_FIXED_KEY == outer && $_ZLE_PICKER_QUERY_SUBMIT == 1 ]] || exit 4
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'UI feature Xcode reader saves source bookmarks before leaving its scope' \
  _test_ui_feature_xcode_reader_bookmark_scope

_test_ui_feature_usb_status_scope() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.usb"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_IDLE_CALLBACK=outer
    _ZLE_PICKER_PASSIVE_LINES=(outer)
    _zle_picker_capture() {
      (( _ZLE_PICKER_STATUS_VIEW && !_ZLE_PICKER_DOCUMENT && !_ZLE_PICKER_READER_ONLY &&
          !_ZLE_PICKER_DIGIT_SELECT )) || return 30
      [[ -z $_ZLE_PICKER_IDLE_CALLBACK && ${#_ZLE_PICKER_PASSIVE_LINES} == 0 &&
         ${(j:|:)_ZLE_PICKER_BUSY_LINES} == "Stage|Waiting" &&
         ${(j:|:)_ZLE_PICKER_BUSY_STYLES} == "picker-status-heading|picker-status-info" &&
         $4 == _usb_noop ]] || return 31
    }
    _usb_progress_stage preparing heading Stage info Waiting || exit 1
    [[ $_ZLE_PICKER_DOCUMENT == 1 && $_ZLE_PICKER_IDLE_CALLBACK == outer ]] || exit 2
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'UI feature USB progress scopes status without inheriting reader effects' \
  _test_ui_feature_usb_status_scope

_test_ui_feature_collectors_keep_matching_and_visible_digits() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/.zsh.usb"
    _XCODE_PICKER_VALUES=(fuzzy prefix substring)
    _XCODE_PICKER_LABELS=(l-a-t-e "late item" "unrelated late") _XCODE_PICKER_SEARCH=()
    _USB_PICKER_VALUES=("${_XCODE_PICKER_VALUES[@]}")
    _USB_PICKER_LABELS=("${_XCODE_PICKER_LABELS[@]}") _USB_PICKER_SEARCH=()
    _xcode_picker_collect late 10
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == "fuzzy|prefix|substring" ]] || exit 1
    _usb_picker_collect late 10
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == "prefix|substring|fuzzy" ]] || exit 2
    _XCODE_PICKER_VALUES=({1..12}) _XCODE_PICKER_LABELS=(row{1..12})
    _USB_PICKER_VALUES=("${_XCODE_PICKER_VALUES[@]}")
    _USB_PICKER_LABELS=("${_XCODE_PICKER_LABELS[@]}")
    local collector=""
    COLUMNS=80 LINES=24
    _ZLE_PICKER_VIEW_LIMIT=10 _ZLE_PICKER_DIGIT_SELECT=1
    for collector in _xcode_picker_collect _usb_picker_collect; do
      "$collector" "" 12
      _ZLE_PICKER_VIEW_OFFSET=0
      _zle_picker_render "" 1
      [[ ${(j:|:)_ZLE_PICKER_VISIBLE_KEYS} == "1|2|3|4|5|6|7|8|9|0" ]] || exit 3
      _ZLE_PICKER_VIEW_OFFSET=2
      _zle_picker_render "" 12
      [[ ${(j:|:)_ZLE_PICKER_VISIBLE_KEYS} == "1|2|3|4|5|6|7|8|9|0" &&
         $_ZLE_PICKER_VIEW_OFFSET == 2 && $_ZLE_PICKER_SELECTED == 12 ]] || exit 4
    done
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'UI feature collectors retain distinct ranking and shared visible digit slots' \
  _test_ui_feature_collectors_keep_matching_and_visible_digits

_test_ui_usb_output_without_optional_palette() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    zmodload zsh/zpty || exit 1
    _usb_style_fixture() {
      _usb_format_color_style heading 1
      print -rn -- "$REPLY"
      _usb_confirmation_prompt "ERASE disk9"
      print -r -- "$REPLY"
      print END-STYLE
    }
    _usb_style_capture() {
      local chunk="" captured=""
      zpty usb-style _usb_style_fixture || return 1
      {
        while zpty -r usb-style chunk; do
          captured+=$chunk
          [[ $chunk == *END-STYLE* ]] && break
        done
        [[ $captured == *END-STYLE* ]] || return 1
        REPLY=$captured
      } always {
        zpty -d usb-style
      }
    }
    _usb_style_capture || exit 2
    [[ $REPLY != *$'\''\e'\''* ]] || exit 3
    typeset -gA _COMPOZSH_COLOR_FALLBACKS=(output:heading 123 output:warning 124)
    _usb_style_capture || exit 4
    [[ $REPLY == *$'\''\e[1;38;5;123m'\''* &&
       $REPLY == *$'\''\e[1;38;5;124m'\''* ]] || {
      print -u2 -- "USB did not use centralized defaults without output peer"; exit 5
    }
    typeset -gA ZSH_OUTPUT_COLORS=(heading 125 warning 126)
    _usb_style_capture || exit 6
    [[ $REPLY == *$'\''\e[1;38;5;125m'\''* &&
       $REPLY == *$'\''\e[1;38;5;126m'\''* ]] || exit 7
    _output_color() { REPLY=""; return 1; }
    _usb_style_capture || exit 8
    [[ $REPLY != *$'\''\e'\''* ]] || { print -u2 -- "USB emitted an empty color escape"; exit 9; }
    print guarded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal guarded "$output"
}
test_case 'UI USB output consumes centralized defaults and guards unavailable color roles' \
  _test_ui_usb_output_without_optional_palette
