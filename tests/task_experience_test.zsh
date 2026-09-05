# Task-specific presentation composes captured facts without new effects.
_test_task_action_surface() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    COLUMNS=120 LINES=30 _ZLE_PICKER_SCREEN_ACTIVE=1
    _check() {
      (( _ZLE_PICKER_ACTION_VIEW == 1 )) || return 11
      _ZLE_PICKER_RESULTS=(open copy) _ZLE_PICKER_LABELS=(Open Copy)
      _ZLE_PICKER_VIEW_LIMIT=10
      _ZLE_PICKER_DESCRIPTIONS=(open "Launch the registered app" copy "Keep the exact path")
      _ZLE_PICKER_ACTION_CONTEXT=$'"'"'TARGET\n/example/literal % [a].txt'"'"'
      _ZLE_PICKER_INSPECT_TEXTS=(open "Explicit application launch" copy "Clipboard after cleanup")
      _zle_picker_render "" 1
      [[ ${(j:|:)_ZLE_PICKER_DISPLAY} == *"Launch the registered app"* &&
         ${(j:|:)_ZLE_PICKER_INSPECT_LINES} == *"/example/literal % [a].txt"* &&
         ${(j:|:)_ZLE_PICKER_INSPECT_LINES} == *"Explicit application launch"* ]] || return 12
      (( _ZLE_PICKER_VISIBLE_COUNT == 2 && _ZLE_PICKER_DISPLAY_INDEX_ENDS[3] == 0 )) || return 13
      [[ $_ZLE_PICKER_INSPECT_ROLES[1] == heading &&
         $_ZLE_PICKER_INSPECT_ROLES[2] == text &&
         $_ZLE_PICKER_INSPECT_ROLES[4] == text ]] || return 16
      # Choice capacity survives short windows; the focused plan remains readable.
      LINES=16 COLUMNS=70
      _ZLE_PICKER_RESULTS=(item-{01..20}) _ZLE_PICKER_LABELS=(item-{01..20})
      _zle_picker_render "" 1
      (( _ZLE_PICKER_VISIBLE_COUNT == 10 )) || return 14
      _ZLE_PICKER_DESCRIPTIONS[leak]=private
      return 0
    }
    _zle_ui_view action _check || exit $?
    [[ -z ${_ZLE_PICKER_DESCRIPTIONS[leak]-} && ${_ZLE_PICKER_ACTION_VIEW:-0} == 0 ]] || exit 15
    print surface
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal surface "$output"
}
test_case 'task experience action cards retain target plans capacity and scoped state' _test_task_action_surface

_test_task_history_inspection() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    COLUMNS=120 LINES=30 _ZLE_PICKER_SCREEN_ACTIVE=1
    _ZLE_PICKER_VALUE_INSPECT=1
    _ZLE_PICKER_RESULTS=($'"'"'printf "%s" "$(never-run)"\nsecond literal line'"'"')
    _ZLE_PICKER_LABELS=("${_ZLE_PICKER_RESULTS[@]}")
    _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_render "" 1
    [[ ${(j:|:)_ZLE_PICKER_INSPECT_LINES} == *'"'"'$(never-run)'"'"'* &&
       ${(j:|:)_ZLE_PICKER_INSPECT_LINES} == *"second literal line"* ]] || exit 1
    _zle_picker_footer 119 ""
    [[ $REPLY == *"Tab list"* ]] || exit 2
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_picker_render "" 0
    [[ ${(j:|:)_ZLE_PICKER_INSPECT_LINES} != *never-run* ]] || exit 3
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'task experience inspects exact captured commands without evaluation or stale selection' _test_task_history_inspection

_test_task_xcode_resume() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_PICKER_VALUES=(scheme destination build)
    _XCODE_PICKER_LABELS=("Scheme · Demo" "Destination · Simulator" "Build · Incremental build")
    _XCODE_PICKER_SEARCH=(scheme destination build)
    _XCODE_PICKER_DETAILS=(scheme destination build)
    _zle_picker_loop() {
      [[ $1 == i && $2 == 10 && $3 == 2 && $4 == 1 && $_zle_picker_start_focus == 1 ]] || return 10
      [[ $_ZLE_PICKER_ACCEPT_LABELS[build] == build ]] || return 11
      [[ $_ZLE_PICKER_DESCRIPTIONS[build] == "Incremental build" ]] || return 12
      print resumed
    }
    _xcode_choose "Xcode / Actions" "Demo · Debug · Simulator" "Filter actions" options i build 1 1
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal resumed "$output"
}
test_case 'task experience Xcode action returns restore filter exact choice viewport and focus' _test_task_xcode_resume

_test_task_consumers() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/target.txt" literal || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.git-review"
    local expected="files" target=$2
    _ZLE_PICKER_SESSION=1
    _zle_picker_loop() {
      (( _ZLE_PICKER_ACTION_VIEW )) || return 10
      case $expected in
        files) [[ $_ZLE_PICKER_ACTION_CONTEXT == *"$target"* &&
          $_ZLE_PICKER_ACCEPT_LABELS[insert] == insert &&
          $_ZLE_PICKER_DESCRIPTIONS[insert] == *"quoted"* ]] || return 11 ;;
        git) [[ $_ZLE_PICKER_ACTION_CONTEXT == *"/example/repo"* &&
          $_ZLE_PICKER_DESCRIPTIONS[working] == *"Staged"* &&
          $_ZLE_PICKER_ACCEPT_LABELS[compare] == configure ]] || return 12 ;;
      esac
      print "$expected"
    }
    _file_search_actions "$target" "" "" || exit $?
    expected=git
    _git_review_options /example/repo "feature/literal %" || exit $?
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/target.txt") || return
  test_assert_equal $'files\ngit' "$output"
}
test_case 'task experience file and Git actions expose exact target consequence and next step' _test_task_consumers

_test_task_draft_inspect() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.editor"
    BUFFER=$'"'"'git status; $(never-run)\nsecond line'"'"' CURSOR=4
    local original=$BUFFER
    _ZLE_PICKER_BOOKMARK=(outer 1 0) _ZLE_PICKER_SELECTED_VALUE=outer
    [[ $(bindkey $'"'"'\e\r'"'"') == *compozsh-inspect* ]] || exit 1
    _zle_picker_screen_session() { "$1"; }
    _zle_picker_loop() {
      (( _ZLE_PICKER_ACTION_VIEW )) || return 11
      [[ $_ZLE_PICKER_ACTION_CONTEXT == *"Cursor 4"* ]] || return 12
      [[ ${_DRAFT_INSPECT_VALUES[(Ie)read]} != 0 ]] || return 13
      [[ ${_DRAFT_INSPECT_VALUES[(Ie)files]} != 0 ]] || return 14
      _ZLE_PICKER_SELECTED_VALUE=back
      _ZLE_PICKER_BOOKMARK=(private-filter 1 0)
      _ZLE_PICKER_DISPLAY=(private-draft-frame)
      return 0
    }
    zle() { :; }
    _draft_inspect_widget || exit $?
    [[ $BUFFER == "$original" && $CURSOR == 4 && -z ${_DRAFT_INSPECT_BUFFER-} ]] || exit 2
    [[ $_ZLE_PICKER_BOOKMARK[1] == outer && $_ZLE_PICKER_SELECTED_VALUE == outer &&
       ${_ZLE_PICKER_DISPLAY[1]-} != private-draft-frame ]] || exit 3
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'task experience draft inspection is explicit literal scoped and preserves editing' _test_task_draft_inspect

_test_task_captured_reader() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    _zle_picker_loop() {
      (( _ZLE_PICKER_READER_ONLY && !_ZLE_PICKER_DIGIT_SELECT )) || return 10
      "$_ZLE_PICKER_COLLECTOR" "[literal]" 10
      [[ ${(j:|:)_ZLE_PICKER_DOCUMENT_LINES} == "one [literal] line" &&
         ${#_ZLE_PICKER_RESULTS} == 0 ]] || return 11
      print reader
    }
    _zle_ui_read_text Help "Captured text" $'"'"'one [literal] line\nother text'"'"'
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal reader "$output"
}
test_case 'task experience shared captured reader filters literal lines without selectable content' _test_task_captured_reader

_test_task_tools_read_return() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.help"
    _ZLE_PICKER_SESSION=1
    _COMPOZSH_TOOL_NAMES=(example)
    local -i visits=0 reads=0 captures=0
    _compozsh_tool_inspector_capture() {
      (( ++captures ))
      _ZLE_PICKER_INSPECT_TEXTS=(example $'"'"'usage: example\nA literal guide.'"'"')
    }
    _zle_picker_loop() {
      (( ++visits ))
      if (( visits == 1 )); then
        _ZLE_PICKER_SELECTED_VALUE=example
        _ZLE_PICKER_BOOKMARK=(exam 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=1
        _ZLE_PICKER_DIGIT_SELECT=0
        return 0
      fi
      [[ $1 == exam && $_zle_picker_start_focus == 1 ]] || return 12
      (( _ZLE_PICKER_DIGIT_SELECT )) || return 14
      return 1
    }
    _compozsh_help_workspace() {
      [[ $1 == *"usage: example"* && $1 == *"A literal guide."* ]] || return 13
      (( ++reads )); return 1
    }
    _zle_picker_run() { return 20; }
    _compozsh_choose
    [[ $? == 1 && $visits == 2 && $reads == 1 && $captures == 1 ]] || exit 1
    [[ -z ${_ZLE_PICKER_INSPECT_TEXTS[example]-} ]] || exit 2
    print journey
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal journey "$output"
}
test_case 'task experience tool help opens captured topics and restores its bookmark' _test_task_tools_read_return

_test_task_remaining_action_adapters() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.git-worktree"
    source "$1/.zsh.addons/.zsh.git-review"
    local expected=usb
    _zle_picker_loop() {
      (( _ZLE_PICKER_ACTION_VIEW )) || return 10
      case $expected in
        usb) [[ $_ZLE_PICKER_ACCEPT_LABELS[flash-verify] == "review confirmation" &&
          $_ZLE_PICKER_INSPECT_TEXTS[flash-verify] == *"exact drive"* &&
          $_ZLE_PICKER_ACTION_CONTEXT == *"/dev/disk9"* ]] || return 11 ;;
        worktree) [[ $_ZLE_PICKER_ACTION_CONTEXT == *"/example/repo"* &&
          $_ZLE_PICKER_DESCRIPTIONS[apply] == *"after cleanup"* ]] || return 12 ;;
        compare) [[ $_ZLE_PICKER_ACTION_CONTEXT == *"feature against main"* &&
          $_ZLE_PICKER_ACCEPT_LABELS[open] == review ]] || return 13 ;;
      esac
      print "$expected"
    }
    _USB_PICKER_VALUES=(flash-verify) _USB_PICKER_DETAILS=("Revalidate the exact drive")
    _usb_choose Review /dev/disk9 Filter 0 0 0 "" "" "" action || exit $?
    expected=worktree
    local -A _GWT_DETAILS=(apply "Create after cleanup") _GWT_LABELS=(apply create)
    _git_worktree_pick Create /example/repo Filter || exit $?
    expected=compare
    local -A _git_compare_details=(open "Captured endpoints") _git_compare_actions=(open review)
    _git_review_pick Compare "feature against main" Filter "" 1 0 0 action || exit $?
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'usb\nworktree\ncompare' "$output"
}
test_case 'task experience USB worktree and comparison setup share explicit action plans' _test_task_remaining_action_adapters

_test_task_prompt_entry_and_logs() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.xcode"
    COLUMNS=100 LINES=30 _PROMPT_INTERACTION_KIND=ready
    _PROMPT_INTERACTION_LABELS=(PROJECT) _PROMPT_INTERACTION_VALUES=(Demo)
    _PROMPT_INTERACTION_ROLES=(project)
    _prompt_interaction_layout
    [[ $_PROMPT_INTERACTION_SEGMENT != *"inspect draft"* ]] || exit 1
    source "$1/.zsh.addons/.zsh.editor"
    _prompt_interaction_layout
    [[ $_PROMPT_INTERACTION_SEGMENT == *"Option-Return inspect draft"* ]] || exit 2
    COLUMNS=20
    _prompt_interaction_layout
    [[ $_PROMPT_INTERACTION_SEGMENT != *"inspect draft"* ]] || exit 3
    _xcode_logs_matches=5 _xcode_logs_total=8 _xcode_logs_follow=1
    _zle_picker_loop() {
      (( _ZLE_PICKER_ACTION_VIEW )) || return 10
      [[ $_ZLE_PICKER_INSPECT_TEXTS[last] == *"new output"* &&
         $_ZLE_PICKER_ACCEPT_LABELS[last] == "follow latest" ]] || return 11
      print connected
    }
    _xcode_logs_options
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal connected "$output"
}
test_case 'task experience prompt advertises available inspection and logs explain transitions' _test_task_prompt_entry_and_logs

_test_task_discard_confirmation() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.tools"
    _zle_picker_run() {
      [[ $_ZLE_PICKER_TITLE == "Git / Discard confirmation" &&
         $_ZLE_PICKER_QUERY_LABEL == *"[y/N]"* &&
         $_ZLE_PICKER_SUBTITLE == "/example/literal %" && $2 == "" ]] || return 10
      [[ ${(j:|:)_ZLE_PICKER_EMPTY_LINES} == *"Ignored files, stashes, commits"* &&
         $_ZLE_PICKER_INSPECT_TEXTS[changes] == *'"'"'$(never-run)'"'"'* ]] || return 11
      (( _ZLE_PICKER_QUERY_SUBMIT && !_ZLE_PICKER_DIGIT_SELECT )) || return 12
      _ZLE_PICKER_SELECTED_VALUE=$answer
      return 0
    }
    local answer=""
    _tools_discard_confirm "/example/literal %" '"'"' M $(never-run)'"'"'
    [[ $? == 1 ]] || exit 1
    answer=yes
    _tools_discard_confirm "/example/literal %" '"'"' M $(never-run)'"'"'
    [[ $? == 1 ]] || exit 2
    answer=y
    _tools_discard_confirm "/example/literal %" '"'"' M $(never-run)'"'"' || exit 3
    [[ -z ${_ZLE_PICKER_INSPECT_TEXTS[changes]-} ]] || exit 4
    print confirmed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal confirmed "$output"
}
test_case 'task experience destructive Git confirmation stays literal explicit and default no' _test_task_discard_confirmation
