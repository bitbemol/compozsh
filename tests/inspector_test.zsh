# Regression tests for the optional tool inspector.
_test_inspector_snapshot() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.tools"
    _compozsh_tool_capture
    _compozsh_tool_inspector_capture || exit 1
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[cpdir]} == *"usage: cpdir"* ]] || exit 2
    print snapshot
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal snapshot "$output"
}
test_case "inspector captures canonical help" _test_inspector_snapshot

_test_inspector_layout() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_TITLE="Tools"
    _ZLE_PICKER_RESULTS=(sample other)
    _ZLE_PICKER_LABELS=(sample other)
    _ZLE_PICKER_RESULT_INDEXES=(1 2)
    typeset -gA _ZLE_PICKER_INSPECT_TEXTS=(
      sample "$(print -rl -- "usage: sample" "Sample guide." {1..80})"
      other "usage: other")
    COLUMNS=120 LINES=30
    _zle_picker_render sample 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"Sample guide."* ]] || exit 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"│"* ]] || exit 2
    _ZLE_PICKER_INSPECT_FOCUS=1
    _ZLE_PICKER_INSPECT_OFFSET=20
    _zle_picker_render sample 1
    (( _ZLE_PICKER_INSPECT_OFFSET == 20 )) || exit 3
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"Sample guide."* ]] || exit 4
    COLUMNS=45
    _zle_picker_render sample 1
    (( !_ZLE_PICKER_INDEXES_VISIBLE )) || exit 5
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"│"* ]] || exit 6
    _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render sample 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *sample* ]] || exit 7
    _zle_picker_render sample 2
    (( _ZLE_PICKER_INSPECT_OFFSET == 0 )) || exit 8
    _ZLE_PICKER_INSPECT_TEXTS=()
    _zle_picker_render sample 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"Help"* ]] || exit 9
    print responsive
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal responsive "$output"
}
test_case 'inspector adapts panes and scrolls captured help' _test_inspector_layout

_test_inspector_bounds_and_literals() {
  test_make_temp_dir || return
  local output addon="$TEST_TMP_DIR/home/.zsh.addons/.zsh.fixture"
  test_write_file "$addon" '
    safe-tool() { print bad > "$HOME/ran"; }
    no-help() { print bad > "$HOME/ran"; }
    _compozsh_help_safe-tool() {
      print -rl -- "usage: safe-tool" "Literal %F{red} text"
      print -r -- ${(l:40000::x:)}
    }
  ' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.editor"
    source "$2"
    _compozsh_tool_capture
    _compozsh_tool_inspector_capture
    [[ ! -e "$HOME/ran" ]] || exit 1
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[no-help]} == *"No Compozsh help"* ]] || exit 2
    (( ${#_ZLE_PICKER_INSPECT_TEXTS[safe-tool]} < 33000 )) || exit 3
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[safe-tool]} == *truncated* ]] || exit 4
    _zle_picker_inspect_prepare safe-tool 40
    (( ${#_ZLE_PICKER_INSPECT_LINES} == 256 )) || exit 11
    [[ ${_ZLE_PICKER_INSPECT_LINES[-1]} == *truncated* ]] || exit 12
    _ZLE_PICKER_RESULTS=(safe-tool)
    _ZLE_PICKER_RESULT_INDEXES=(1)
    _ZLE_PICKER_LABELS=("界界界界界界界界界界界界界界界界界界界界")
    _ZLE_PICKER_INSPECT_TEXTS[safe-tool]=$'\''usage: safe-tool\nLiteral %F{red} $(never-run)\n\e]52;c;invalid\a\n界界界界界界界界界界界界界界界界界界界界界界界界界界界界'\''
    setopt PROMPT_SUBST
    _zle_picker_inspect_prepare safe-tool 70
    [[ ${_ZLE_PICKER_INSPECT_LINES[2]} == '"'"'Literal %F{red} $(never-run)'"'"' ]] || exit 13
    for columns in 120 100 99 45 20; do
      COLUMNS=$columns LINES=16
      for _ZLE_PICKER_INSPECT_FOCUS in 0 1; do
        _zle_picker_render "${(l:200::界:)}" 1
        (( ${(m)#_ZLE_PICKER_QUERY_ROW} < COLUMNS )) || exit 9
        for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
          (( ${(m)#row} < COLUMNS )) || { print -u2 -- "row overflow at $columns: ${(m)#row}"; exit 5; }
          [[ $row != *$'\''\e'\''* && $row != *$'\''\a'\''* ]] || exit 6
        done
        (( ${#_ZLE_PICKER_INSPECT_LINES} <= 256 )) || exit 7
      done
    done
    COLUMNS=120 LINES=10
    _ZLE_PICKER_RESULTS=({1..20})
    _ZLE_PICKER_LABELS=({1..20})
    _ZLE_PICKER_RESULT_INDEXES=({1..20})
    _zle_picker_render "" 20
    (( ${#_ZLE_PICKER_DISPLAY} <= LINES - 5 )) || exit 8
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_picker_render missing 0
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"No matching selection."* ]] || exit 10
    print bounded-literal
  ' "$TEST_REPO_ROOT" "$addon") || return
  test_assert_equal bounded-literal "$output"
}
test_case 'inspector bounds captures and fits literal Unicode text after resize' \
  _test_inspector_bounds_and_literals

_test_inspector_native_controls() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.tools"
    zmodload zsh/zpty
    functions[_inspector_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _inspector_original_show
      print -r -- "FRAME:$_ZLE_PICKER_INSPECT_FOCUS:$_ZLE_PICKER_INSPECT_OFFSET:$_ZLE_PICKER_QUERY:END-FRAME"
    }
    _inspector_driver() {
      COLUMNS=120 LINES=30
      compozsh
      print -r -- "DONE:${#_ZLE_PICKER_INSPECT_TEXTS}:$_ZLE_PICKER_INSPECT_FOCUS:END-DONE"
    }
    zpty inspector _inspector_driver || exit 1
    {
      zpty -r inspector frame "*END-FRAME*" || exit 2
      [[ $frame == *"Help"* ]] || exit 3
      zpty -w -n inspector $'\''\e[C'\''
      zpty -r inspector frame "*END-FRAME*" || exit 4
      [[ $frame == *"FRAME:1:0:"* ]] || exit 5
      zpty -w -n inspector $'\''\e[B'\''
      zpty -r inspector frame "*END-FRAME*" || exit 6
      [[ $frame == *"FRAME:1:1:"* ]] || exit 7
      zpty -w -n inspector $'\''\e[D'\''
      zpty -r inspector frame "*END-FRAME*" || exit 8
      [[ $frame == *"FRAME:0:1:"* ]] || exit 9
      zpty -w -n inspector $'\''\t'\''
      zpty -r inspector frame "*END-FRAME*" || exit 12
      [[ $frame == *"FRAME:1:1:"* ]] || exit 13
      zpty -w -n inspector $'\''\e[200~cpdir\e[201~'\''
      zpty -r inspector frame "*END-FRAME*" || exit 14
      [[ $frame == *"FRAME:0:0:cpdir:"* ]] || exit 15
      zpty -w -n inspector $'\''\x07'\''
      zpty -r inspector frame "*END-DONE*" || exit 10
      [[ $frame == *"DONE:0:0:"* ]] || exit 11
    } always {
      zpty -d inspector
    }
    print native-controls
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native-controls "$output"
}
test_case 'inspector native ZLE supports focus, scrolling, and cancellation cleanup' \
  _test_inspector_native_controls
