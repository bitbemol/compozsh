_test_git_disclosure_transitions() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    local mode="" direction="" expected="" focus=0
    for mode in focused full ""; do
      for focus in 0 1; do
        for direction in right left; do
          expected=""
          case "$direction:$focus:$mode" in
            (right:0:full|left:1:full) expected=focused ;;
            (right:0:*) expected=read ;;
            (right:1:focused) expected=full ;;
            (left:1:*) expected=files ;;
          esac
          _zle_picker_document_direction "$direction" "$focus" "$mode" || exit 1
          [[ $REPLY == "$expected" ]] || { print -u2 "$direction:$focus:$mode -> $REPLY, expected $expected"; exit 2; }
        done
      done
    done
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_REFRESH=1
    _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_SELECTED=1
    _ZLE_PICKER_INSPECT_ACTION=read _ZLE_PICKER_CANCEL_LABEL=back
    _ZLE_PICKER_INSPECT_TEXTS=(1 ready)
    for mode in focused full ""; do
      _ZLE_PICKER_DOCUMENT_MODE=$mode
      for focus in 0 1; do
        _ZLE_PICKER_INSPECT_FOCUS=$focus
        _zle_picker_footer 179 ""
        [[ $REPLY == *"^R refresh"* && $REPLY != *"^X"* ]] || exit 3
        if (( !focus )); then
          [[ $mode == full ]] && expected="→ focused diff" || expected="→ read"
          [[ $REPLY == *"$expected"* && $REPLY != *"←"* ]] || exit 4
        else
          [[ $mode == full ]] && expected="← focused diff" || expected="← files"
          [[ $REPLY == *"$expected"* ]] || exit 5
          if [[ $mode == focused ]]; then [[ $REPLY == *"→ full file"* ]] || exit 6
          else [[ $REPLY != *"→"* ]] || exit 7; fi
        fi
      done
    done
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_SELECTED=0
    _zle_picker_footer 179 ""
    [[ $REPLY == *"^R refresh"* && $REPLY != *"→"* && $REPLY != *"←"* ]] || exit 8
    _ZLE_PICKER_SCREEN_ACTIVE=1 LINES=60
    _zle_picker_guide_render 119
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Files → focused diff → full-file context"* &&
       ${(F)_ZLE_PICKER_DISPLAY} == *"Ctrl-R"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *"Ctrl-X"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *"Right / Ctrl-E"* ]] || exit 9
    print disclosure
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal disclosure "$output"
}
test_case 'Git disclosure arrows and hints agree at every reading boundary' _test_git_disclosure_transitions

_test_git_document_focus_visibility() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_SCREEN_ACTIVE=1
    _ZLE_PICKER_RESULTS=(README.md AGENTS.md)
    _ZLE_PICKER_LABELS=(README.md AGENTS.md)
    _ZLE_PICKER_RESULT_INDEXES=(1 2)
    _ZLE_PICKER_CONTEXTS=("Unstaged M" "Unstaged M")
    _ZLE_PICKER_INSPECT_TEXTS=(README.md snapshot)
    _ZLE_PICKER_DOCUMENT_KEY=README.md
    _ZLE_PICKER_DOCUMENT_TITLE=README.md
    _ZLE_PICKER_DOCUMENT_LINES=("@@ -1 +1 @@" "-old" "+new")
    _ZLE_PICKER_DOCUMENT_ROLES=(info error success)
    _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_VIEW_START=1
    _ZLE_PICKER_VIEW_LIMIT=12 COLUMNS=120 LINES=30

    _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render "" 1
    [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} ]] || exit 1
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *" │ "* && ${(F)_ZLE_PICKER_DISPLAY} != *" ┃ "* ]] || exit 2

    _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_render "" 1
    [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected-inactive]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} ]] || exit 3
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *" ┃ "* && ${(F)_ZLE_PICKER_DISPLAY} == *"▸ README.md"* ]] || exit 4

    COLUMNS=70
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"▸ README.md"* ]] || exit 5
    [[ ${(F)_ZLE_PICKER_DISPLAY} != *" │ "* && ${(F)_ZLE_PICKER_DISPLAY} != *" ┃ "* ]] || exit 6
    print focus-visible
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal focus-visible "$output"
}
test_case 'Git document panes distinguish selected content from keyboard focus' _test_git_document_focus_visibility

_test_git_disclosure_capabilities() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.git-review"
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(tracked new binary failed) _GIT_REVIEW_KINDS=(unstaged untracked unstaged unstaged)
    _git_review_diff_capture() {
      _GIT_REVIEW_TRUNCATED=0
      _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-old\n+new'\''
      [[ $3 == binary ]] && _GIT_REVIEW_DATA="Binary files differ"
      [[ $3 == failed ]] && return 1
      return 0
    }
    _git_review_document_load /fixture 1 "" "" 3
    [[ $_ZLE_PICKER_DOCUMENT_MODE == focused ]] || exit 1
    _git_review_document_load /fixture 1 "" "" 1000000000
    [[ $_ZLE_PICKER_DOCUMENT_MODE == full ]] || exit 2
    local index=0
    for index in 2 3 4; do
      _git_review_document_load /fixture $index "" "" 3
      [[ -z $_ZLE_PICKER_DOCUMENT_MODE ]] || exit 3
    done
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"Ctrl-R"* ]] || exit 4
    print capabilities
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal capabilities "$output"
}
test_case 'Git disclosure skips redundant expansion for untracked files binary metadata and failures' _test_git_disclosure_capabilities
