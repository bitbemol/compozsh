# All task surfaces derive navigation from existing captured capabilities.
_test_workspace_focus_navigation() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    _ZLE_PICKER_RESULTS=(one two) _ZLE_PICKER_LABELS=(one two)
    _ZLE_PICKER_INSPECT_TEXTS=(one "Captured details")
    for _ZLE_PICKER_INSPECT_TITLE in Help Branch Location Preview Action "App output"; do
      _ZLE_PICKER_INSPECT_FOCUS=0
      _zle_picker_render "" 1
      [[ $_ZLE_PICKER_DISPLAY[1] == *"▸ Results  ›  $_ZLE_PICKER_INSPECT_TITLE"* &&
         $_ZLE_PICKER_DISPLAY[1] == *"^E inspect"* ]] || exit 1
      _ZLE_PICKER_INSPECT_FOCUS=1
      _zle_picker_render "" 1
      [[ $_ZLE_PICKER_DISPLAY[1] == *"Results  ›  ▸ $_ZLE_PICKER_INSPECT_TITLE"* &&
         $_ZLE_PICKER_DISPLAY[1] == *"^B results"* ]] || exit 2
      (( _ZLE_PICKER_DISPLAY_INDEX_ENDS[1] == 0 &&
         _ZLE_PICKER_DISPLAY_MATCH_STARTS[1] == -1 &&
         ${#_ZLE_PICKER_DISPLAY} == LINES-4 )) || exit 3
      [[ $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[1] == *picker-focus* ]] || exit 4
    done
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_DOCUMENT_LINES=(line) _ZLE_PICKER_DOCUMENT_MODE=focused
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_DISPLAY[1] == *"Files  ›  ▸ Focused diff  ›  Full file"* ]] || exit 5
    _ZLE_PICKER_DOCUMENT_MODE=full
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_DISPLAY[1] == *"Files  ›  Focused diff  ›  ▸ Full file"* ]] || exit 6
    _zle_picker_render "" 2
    [[ $_ZLE_PICKER_DISPLAY[1] != *"Full file"* ]] || exit 11
    _ZLE_PICKER_DOCUMENT_MODE=""
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_DISPLAY[1] != *"Full file"* ]] || exit 12
    _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_INSPECT_TITLE="App logs"
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_DISPLAY[1] == *"▸ App logs"* && $_ZLE_PICKER_DISPLAY[1] != *Files* ]] || exit 7
    _ZLE_PICKER_READER_ONLY=0 _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_INSPECT_FOCUS=0
    _ZLE_PICKER_INSPECT_TEXTS=() _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_DISPLAY[1] == *"▸ Results"* && $_ZLE_PICKER_DISPLAY[1] != *inspect* ]] || exit 8
    _ZLE_PICKER_QUERY_SUBMIT=1
    _zle_picker_render "literal text" 0
    [[ $_ZLE_PICKER_DISPLAY[1] == *"▸ Query"* ]] || exit 9
    _ZLE_PICKER_GUIDE_ACTIVE=1
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_DISPLAY[1] == *"▸ Keyboard guide"* && $_ZLE_PICKER_DISPLAY[1] != *inspect* ]] || exit 10
    _ZLE_PICKER_GUIDE_ACTIVE=0 _ZLE_PICKER_BUSY=1
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_DISPLAY[1] == *"▸ In progress"* && $_ZLE_PICKER_DISPLAY[1] != *inspect* ]] || exit 13
    print navigation
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal navigation "$output"
}
test_case 'workspace focus navigation follows tool capabilities without fake actions or lost rows' _test_workspace_focus_navigation

_test_workspace_focus_geometry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_SCREEN_ACTIVE=1 LINES=30
    _ZLE_PICKER_RESULTS=(one two) _ZLE_PICKER_LABELS=(one two)
    _ZLE_PICKER_INSPECT_TEXTS=(one "$(print -rl -- detail-{01..80})")
    for COLUMNS in 100 120 160 240; do
      _ZLE_PICKER_INSPECT_FOCUS=0
      _zle_picker_render "" 1
      wide=$_ZLE_PICKER_DISPLAY_LEFT_ENDS[2]
      _ZLE_PICKER_INSPECT_FOCUS=1
      _zle_picker_render "" 1
      narrow=$_ZLE_PICKER_DISPLAY_LEFT_ENDS[2]
      (( narrow < wide && narrow >= 28 && narrow <= 42 &&
         _ZLE_PICKER_SELECTED == 1 && _ZLE_PICKER_VISIBLE_COUNT == 2 )) || exit 1
      _ZLE_PICKER_INSPECT_FOCUS=0
      _zle_picker_render "" 1
      (( _ZLE_PICKER_DISPLAY_LEFT_ENDS[2] == wide )) || exit 2
    done
    _ZLE_PICKER_INSPECT_TITLE=$'\''界 café\e[2J\n%F{red}'\''
    for COLUMNS in 4 8 20 40 70 100; do
      for _ZLE_PICKER_INSPECT_FOCUS in 0 1; do
        _zle_picker_render "" 1
        (( ${(m)#_ZLE_PICKER_DISPLAY[1]} <= COLUMNS-1 )) || exit 3
        [[ $_ZLE_PICKER_DISPLAY[1] != *$'\''\e'\''* && $_ZLE_PICKER_DISPLAY[1] != *$'\''\n'\''* ]] || exit 4
        if [[ $_ZLE_PICKER_DISPLAY[1] == *"^E"* ]]; then
          [[ $_ZLE_PICKER_DISPLAY[1] == *"^E inspect"* ]] || exit 5
        fi
        if [[ $_ZLE_PICKER_DISPLAY[1] == *"^B"* ]]; then
          [[ $_ZLE_PICKER_DISPLAY[1] == *"^B results"* ]] || exit 6
        fi
      done
    done
    print geometry
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal geometry "$output"
}
test_case 'workspace focus expands reading width and reverses without losing selection' _test_workspace_focus_geometry

_test_workspace_focus_reading_anchor() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_INSPECT_TEXTS=(one "$(print -rl -- "A long first paragraph with many words that wrap onto multiple lines in the narrow preview." "Anchor paragraph" tail-{01..30})")
    _zle_picker_inspect_prepare one 28
    anchor="Anchor paragraph"
    _ZLE_PICKER_INSPECT_OFFSET=$(( ${_ZLE_PICKER_INSPECT_LINES[(i)$anchor]}-1 ))
    _zle_picker_inspect_prepare one 90
    [[ $_ZLE_PICKER_INSPECT_LINES[_ZLE_PICKER_INSPECT_OFFSET+1] == "Anchor paragraph" ]] || exit 1
    _zle_picker_inspect_prepare one 28
    [[ $_ZLE_PICKER_INSPECT_LINES[_ZLE_PICKER_INSPECT_OFFSET+1] == "Anchor paragraph" ]] || exit 2
    print anchor
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal anchor "$output"
}
test_case 'workspace focus rewrapping preserves the source paragraph being read' _test_workspace_focus_reading_anchor
