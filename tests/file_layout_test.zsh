# Filename-first presentation keeps exact values separate from display labels.
_test_file_layout_snapshot() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.editor"
    _FILE_SEARCH_ROOT=/snapshot
    _FILE_SEARCH_SOURCE=local
    _FILE_SEARCH_VALUES=(/snapshot/docs/readme.md /snapshot/tests/readme.md /snapshot/docs)
    _FILE_SEARCH_LABELS=("· docs/readme.md" "· tests/readme.md" "▸ docs/")
    _FILE_SEARCH_MATCH_TEXTS=(docs/readme.md tests/readme.md docs)
    # No filesystem access is needed for presentation.
    path=()
    _file_search_inspector_capture
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[/snapshot/docs/readme.md]} == $'\''File\n\n  /snapshot/docs/readme.md'\'' ]] || exit 1
    _file_search_picker_collect "" 10
    [[ ${_ZLE_PICKER_LABELS[1]} == "· readme.md" &&
       ${_ZLE_PICKER_LABELS[2]} == "· readme.md" &&
       ${_ZLE_PICKER_LABELS[3]} == "▸ docs/" ]] || exit 2
    [[ ${_ZLE_PICKER_CONTEXTS[/snapshot/docs/readme.md]} == docs/ &&
       ${_ZLE_PICKER_CONTEXTS[/snapshot/tests/readme.md]} == tests/ ]] || exit 3
    [[ ${_ZLE_PICKER_RESULTS[1]} == /snapshot/docs/readme.md ]] || exit 4
    _file_search_picker_collect tests 10
    [[ ${_ZLE_PICKER_RESULTS[1]} == /snapshot/tests/readme.md &&
       ${_ZLE_PICKER_LABELS[1]} == "· readme.md" ]] || exit 5
    _FILE_SEARCH_VALUES=(/)
    _FILE_SEARCH_LABELS=("▸ /")
    _file_search_inspector_capture
    _file_search_picker_collect "" 10
    [[ ${_ZLE_PICKER_LABELS[1]} == "▸ /" && ${_ZLE_PICKER_CONTEXTS[/]} == / ]] || exit 6
    print filename-first
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal filename-first "$output"
}
test_case 'file layout shows filenames with distinct folder context and one full path' _test_file_layout_snapshot

_test_file_layout_widths() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_RESULTS=(/snapshot/docs/report.md /snapshot/tests/report.md)
    _ZLE_PICKER_LABELS=("· report.md" "· report.md")
    _ZLE_PICKER_CONTEXTS=(/snapshot/docs/report.md docs/ /snapshot/tests/report.md tests/)
    _ZLE_PICKER_INSPECT_TEXTS=(/snapshot/docs/report.md $'\''File\n\n  /snapshot/docs/report.md'\'')
    _ZLE_PICKER_INSPECT_TITLE=Path
    COLUMNS=102 LINES=30
    _zle_picker_render "" 1
    (( _ZLE_PICKER_DISPLAY_LEFT_ENDS[1] >= 55 )) || exit 1
    [[ ${_ZLE_PICKER_DISPLAY[1]} == *"report.md"*"docs/"* &&
       ${_ZLE_PICKER_DISPLAY[2]} == *"report.md"*"tests/"* ]] || exit 2
    [[ ${_ZLE_PICKER_DISPLAY[1]#*│} != *"report.md"* &&
       ${_ZLE_PICKER_DISPLAY[1]#*│} != *"1/"* ]] || exit 3
    (( _ZLE_PICKER_DISPLAY_CONTEXT_STARTS[2] > 0 )) || exit 4
    # Small result sets and short details should not reserve a tall empty box.
    (( ${#_ZLE_PICKER_DISPLAY} <= 7 )) || exit 9
    _ZLE_PICKER_LABELS[1]="· release-notes-${(l:80::界:)}-final.md"
    _ZLE_PICKER_CONTEXTS[/snapshot/docs/report.md]=$'\''deep/\e]52;c;invalid\a/parent/'\''
    for COLUMNS in 140 102 100 99 60 30 20 8; do
      for _ZLE_PICKER_INSPECT_FOCUS in 0 1; do
        _zle_picker_render "" 1
        for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
          (( ${(m)#row} < COLUMNS )) || exit 5
          [[ $row != *$'\''\e'\''* && $row != *$'\''\a'\''* ]] || exit 6
        done
        (( COLUMNS < 60 || _ZLE_PICKER_INSPECT_FOCUS )) ||
          [[ ${_ZLE_PICKER_DISPLAY[1]} == *"final.md"* ]] || exit 7
      done
    done
    [[ ${_ZLE_PICKER_RESULTS[1]} == /snapshot/docs/report.md ]] || exit 8
    # Long unbroken Unicode paths wrap without losing characters between rows.
    value="/snapshot/${(l:100::界:)}-report.md"
    _ZLE_PICKER_INSPECT_TEXTS=("$value" "File"$'\''\n\n  '\''"$value")
    for width in 13 20 37 48 73; do
      _zle_picker_inspect_prepare "$value" $width
      joined="${(j::)_ZLE_PICKER_INSPECT_LINES[3,-1]}"
      [[ ${joined#  } == "$value" ]] || exit 10
      for row in "${_ZLE_PICKER_INSPECT_LINES[@]}"; do
        (( ${(m)#row} <= width )) || exit 11
      done
    done
    print width-safe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal width-safe "$output"
}
test_case 'file layout balances panes and preserves long filename suffixes at narrow widths' _test_file_layout_widths
