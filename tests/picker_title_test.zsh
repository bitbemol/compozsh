# Tool identity is separate from mutable result status in every full-screen view.
_test_picker_titles() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    _ZLE_PICKER_SUBTITLE="~ › Projects"
    _ZLE_PICKER_BROWSE_LABEL="captured items"
    _ZLE_PICKER_RESULTS=(one two) _ZLE_PICKER_LABELS=(one two)
    _ZLE_PICKER_INSPECT_ACTION=insert
    for title in History "Recent directories" Branches Files "Tool explorer" "Directory browser" "File actions" "Folder actions"; do
      _ZLE_PICKER_TITLE=$title
      _zle_picker_render "" 1
      [[ $_ZLE_PICKER_TITLEBAR == "Compozsh / $title"* && $_ZLE_PICKER_TITLEBAR == *"Enter: insert · Results" ]] || {
        print -u2 -- "missing dedicated title bar for $title"; exit 1;
      }
      [[ $_ZLE_PICKER_HEADER == "captured items · 2 shown" && $_ZLE_PICKER_SUBTITLE_ROW == "~ › Projects" ]] || exit 2
      (( ${#_ZLE_PICKER_DISPLAY} == LINES - 5 && _ZLE_PICKER_VISIBLE_COUNT == 2 )) || exit 3
      (( _ZLE_PICKER_TITLEBAR_META_START > ${#title} )) || exit 4
      [[ ${_ZLE_PICKER_TITLEBAR[$(( _ZLE_PICKER_TITLEBAR_META_START + 1 )),-1]} == "Enter: insert · Results" ]] || exit 5
      saved_title=$_ZLE_PICKER_TITLEBAR
      _zle_picker_render "typed query" 2
      [[ $_ZLE_PICKER_TITLEBAR == "$saved_title" ]] || exit 6
    done
    _ZLE_PICKER_ACCEPT_LABELS=(two "file actions")
    _zle_picker_render "" 2
    [[ $_ZLE_PICKER_TITLEBAR == *"Enter: file actions · Results" ]] || exit 7
    _ZLE_PICKER_INSPECT_TITLE=Preview _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_render "" 2
    [[ $_ZLE_PICKER_TITLEBAR == *"Enter: file actions · Preview" ]] || exit 8
    _ZLE_PICKER_GUIDE_ACTIVE=1
    _zle_picker_render "" 2
    [[ $_ZLE_PICKER_TITLEBAR == *"Keyboard guide" && $_ZLE_PICKER_TITLEBAR != *"Enter:"* ]] || exit 9
    _ZLE_PICKER_GUIDE_ACTIVE=0 _ZLE_PICKER_INSPECT_FOCUS=0
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_TITLEBAR == *"No selection" && $_ZLE_PICKER_TITLEBAR != *"Enter:"* ]] || exit 10
    _ZLE_PICKER_SCREEN_ACTIVE=0
    _zle_picker_render "" 0
    [[ -z $_ZLE_PICKER_TITLEBAR && $_ZLE_PICKER_HEADER == "Folder actions · captured items · 0 shown" ]] || exit 11
    print titles
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal titles "$output"
}
test_case 'fullscreen title bars separate identity, result status, action and focus across tools' _test_picker_titles

_test_picker_title_sizing() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_SCREEN_ACTIVE=1 LINES=30
    _ZLE_PICKER_RESULTS=(one) _ZLE_PICKER_LABELS=(one)
    _ZLE_PICKER_TITLE="Directory browser" _ZLE_PICKER_INSPECT_ACTION=insert
    for COLUMNS in 8 20 40 80 120; do
      _zle_picker_render "" 1
      (( ${(m)#_ZLE_PICKER_TITLEBAR} == COLUMNS - 1 )) || { print -u2 "title width mismatch: $COLUMNS"; exit 1; }
      if (( COLUMNS == 20 )); then
        [[ $_ZLE_PICKER_TITLEBAR == "Directory browser"* && $_ZLE_PICKER_TITLEBAR != *Compozsh* ]] || exit 2
      fi
      if (( COLUMNS <= 40 )); then
        (( _ZLE_PICKER_TITLEBAR_META_START == -1 )) || exit 3
      fi
    done
    _ZLE_PICKER_TITLE=$'\''Literal\e[31m\n%F{red}界 café'\''
    _ZLE_PICKER_ACCEPT_LABELS=(one $'\''apply\n\e[2J'\'')
    for COLUMNS in 20 40 120; do
      _zle_picker_render "" 1
      (( ${(m)#_ZLE_PICKER_TITLEBAR} == COLUMNS - 1 )) || exit 4
      [[ $_ZLE_PICKER_TITLEBAR != *$'\''\e'\''* && $_ZLE_PICKER_TITLEBAR != *$'\''\n'\''* ]] || exit 5
    done
    print responsive
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal responsive "$output"
}
test_case 'fullscreen titles prioritize tool identity and safely fit narrow Unicode windows' _test_picker_title_sizing
