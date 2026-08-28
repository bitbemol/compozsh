# Public file selection must distinguish navigation from explicit file actions.
_test_file_actions_native() {
  test_make_temp_dir || return
  local output i
  test_write_file "$TEST_TMP_DIR/files/folder/child" fixture || return
  for i in {01..25}; do
    test_write_file "$TEST_TMP_DIR/files/row-$i" fixture || return
  done
  test_write_file "$TEST_TMP_DIR/files/note & final.txt" fixture || return
  command ln -s 'note & final.txt' "$TEST_TMP_DIR/files/link-note" || return
  command ln -s folder "$TEST_TMP_DIR/files/link-dir" || return
  test_write_file "$TEST_TMP_DIR/bin/open" $'#!/bin/zsh\nprint -rl -- "$@" > "$HOME/opened"' || return
  test_write_file "$TEST_TMP_DIR/bin/pbcopy" $'#!/bin/zsh\n/bin/cat > "$HOME/copied"' || return
  command chmod +x "$TEST_TMP_DIR/bin/open" "$TEST_TMP_DIR/bin/pbcopy" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$3" "${path[@]}")
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.find"
    source "$1/tests/support.zsh"
    builtin cd "${2:A}"
    zmodload zsh/zpty
    functions[_actions_capture_original]=$functions[_file_search_capture_local]
    _file_search_capture_local() { (( ++captures )); _actions_capture_original "$@"; }
    functions[_actions_show_original]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _actions_show_original
      # The waiting frame is not an actionable result. Its lifecycle is
      # covered separately by search_capture_test; synchronize on ready views.
      (( ${_ZLE_PICKER_BUSY:-0} )) && return 0
      print -r -- "FRAME:$_ZLE_PICKER_TITLE:$_ZLE_PICKER_QUERY:$_ZLE_PICKER_SELECTED:$_ZLE_PICKER_VIEW_OFFSET:$captures:END-ACTION-FRAME"
    }
    _actions_driver() {
      COLUMNS=120 LINES=30
      setopt AUTO_PUSHD PUSHD_SILENT
      local -i captures=0
      local original=$PWD actual="" expected="$PWD/note & final.txt"
      case $scenario in
        (directory|directory-digit) test_search_session folder ;;
        (linked-directory) test_search_session link-dir ;;
        (resume) test_search_session row ;;
        (link) test_search_session link-note ;;
        (*) test_search_session "note & final" ;;
      esac
      case $scenario in
        (linked-directory)
          [[ $PWD -ef "$original/folder" && ${dirstack[1]} -ef "$original" ]] || {
            print -u2 -r -- "expected directory navigation with the previous location in the stack"
            return 1
          } ;;
        (directory|directory-digit)
          IFS= read -r -z actual || return 1
          _file_search_quote "$original/folder"
          [[ $PWD == "$original" && $actual == "$REPLY" ]] || return 1 ;;
        (copy) [[ $(<"$HOME/copied") == "$expected" ]] || return 2 ;;
        (open) [[ $(<"$HOME/opened") == "--"$'\''\n'\''"$expected" ]] || return 3 ;;
        (reveal) [[ $(<"$HOME/opened") == "-R"$'\''\n'\''"--"$'\''\n'\''"$expected" ]] || return 4 ;;
        (insert)
          IFS= read -r -z actual || return 5
          _file_search_quote "$expected"
          [[ $actual == "$REPLY" ]] || return 6 ;;
        (link|resume)
          [[ ! -e "$HOME/opened" && ! -e "$HOME/copied" ]] || return 7 ;;
      esac
      [[ $scenario == directory* || $scenario == linked-directory || $PWD == "$original" ]] || return 8
      (( captures == 1 && !_ZLE_PICKER_ACTIVE && !${#_ZLE_PICKER_INSPECT_TEXTS} )) || return 9
      print -r -- END-ACTION-DONE
    }
    _actions_read() {
      local recent=''
      while zpty -r actions frame; do
        recent+=$frame
        recent=${recent[-4000,-1]}
        [[ $frame == *"$1"* ]] && return 0
      done
      print -u2 -r -- "file actions ($scenario): missing $1; recent output: ${(V)recent}"
      return 1
    }
    for scenario in directory directory-digit linked-directory resume link insert copy open reveal; do
      zpty actions _actions_driver || exit 1
      {
        _actions_read END-ACTION-FRAME || exit 2
        if [[ $scenario == resume ]]; then
          zpty -w -n actions $'\''\e[200~row\e[201~'\''
          _actions_read END-ACTION-FRAME || exit 3
          for i in 1 2; do
            zpty -w -n actions $'\''\x16'\''
            _actions_read END-ACTION-FRAME || exit 4
          done
          [[ $frame == *":row:21:11:1:"* ]] || exit 5
        fi
        if [[ $scenario == directory-digit ]]; then
          zpty -w -n actions 1
        else
          zpty -w -n actions $'\''\r'\''
        fi
        if [[ $scenario != directory* ]]; then
          _actions_read END-ACTION-FRAME || exit 6
          [[ $frame == *"FRAME:File actions"* ]] || exit 7
          if [[ $scenario == resume || $scenario == link ]]; then
            zpty -w -n actions $'\''\e'\''
            _actions_read END-ACTION-FRAME || exit 8
            [[ $frame == *"FRAME:Files"* ]] || exit 9
            if [[ $scenario == resume ]]; then
              [[ $frame == *":row:21:11:1:"* ]] || exit 10
            fi
            zpty -w -n actions $'\''\x07'\''
          else
            action_query=$scenario
            [[ $scenario == linked-directory ]] && action_query=enter
            zpty -w -n actions $'\''\e[200~'\''"$action_query"$'\''\e[201~'\''
            _actions_read END-ACTION-FRAME || exit 11
            zpty -w -n actions $'\''\r'\''
          fi
        fi
        _actions_read END-ACTION-DONE || exit 12
      } always {
        zpty -d actions
      }
    done
    print type-aware-actions
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/files" "$TEST_TMP_DIR/bin") || return
  test_assert_equal type-aware-actions "$output"
}
test_case 'file actions navigate directories, require explicit file actions, and restore a paged search' _test_file_actions_native

_test_file_actions_boundaries() {
  test_make_temp_dir || return
  local output
  test_write_file "$TEST_TMP_DIR/files/-note \$(never-run); [x].txt" fixture || return
  test_write_file "$TEST_TMP_DIR/files/directory/child" fixture || return
  command ln -s directory "$TEST_TMP_DIR/files/linked-directory" || return
  command ln -s missing "$TEST_TMP_DIR/files/broken" || return
  command mkfifo "$TEST_TMP_DIR/files/pipe" || return
  test_write_file "$TEST_TMP_DIR/bin/open" $'#!/bin/zsh\nprint -rl -- "$@" > "$HOME/opened"\nexit "${OPEN_STATUS:-0}"' || return
  command chmod +x "$TEST_TMP_DIR/bin/open" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    source "$1/tests/support.zsh"
    root=${2:A}
    selected="$root/"'"'"'-note $(never-run); [x].txt'"'"'
    initial=$PWD
    # Rendering uses only captured data, including the selected action label.
    typeset -A _ZLE_PICKER_ACCEPT_LABELS=()
    _FILE_SEARCH_VALUES=("$selected" "$root/directory" "$root/broken")
    _FILE_SEARCH_LABELS=("· note" "▸ directory/" "↗ broken")
    _file_search_inspector_capture
    [[ ${_ZLE_PICKER_ACCEPT_LABELS[$selected]} == "file actions" &&
       ${_ZLE_PICKER_ACCEPT_LABELS[$root/directory]} == "enter directory" &&
       ${_ZLE_PICKER_ACCEPT_LABELS[$root/broken]} == "file actions" ]] || exit 1
    # Inspect capability-driven menus without starting an editor or an app.
    _zle_picker_run() {
      [[ ${_file_action_values[(Ie)insert]} -gt 0 ]] || return 40
      if [[ $mode == unavailable ]]; then
        [[ ${(j:|:)_file_action_values} == insert ]] || return 41
      else
        (( ! ${_file_action_values[(Ie)open]} && ! ${_file_action_values[(Ie)enter-link]} &&
           ${_file_action_values[(Ie)reveal]} )) || return 42
      fi
      return 0
    }
    mode=unavailable
    _file_search_actions "$selected" "" "" || exit 2
    mode=broken
    _file_search_actions "$root/broken" "" "$3/open" || exit 3
    [[ ! -e "$HOME/opened" ]] || exit 4
    for invalid in missing pipe broken; do
      _file_search_apply open "$root/$invalid" "" "$3/open" 2>/dev/null
      (( $? == 1 )) || exit 5
    done
    _file_search_apply directory "$root/linked-directory" "" "" 2>/dev/null
    (( $? == 1 )) && [[ $PWD == "$initial" ]] || exit 6
    _file_search_apply enter-link "$root/directory" "" "" 2>/dev/null
    (( $? == 1 )) || exit 7
    _file_search_apply open "$selected" "" "" 2>/dev/null
    (( $? == 1 )) || exit 8
    _file_search_apply unexpected "$selected" "" "$3/open"
    (( $? == 2 )) && [[ ! -e "$HOME/opened" ]] || exit 9
    _file_search_apply open "$selected" "" "$3/open" || exit 10
    [[ $(<"$HOME/opened") == "--"$'\''\n'\''"$selected" ]] || exit 11
    _file_search_apply reveal "$root/broken" "" "$3/open" || exit 12
    [[ $(<"$HOME/opened") == "-R"$'\''\n'\''"--"$'\''\n'\''"$root/broken" ]] || exit 13
    export OPEN_STATUS=19
    _file_search_apply open "$selected" "" "$3/open"
    (( $? == 19 )) || exit 14
    _file_search_apply insert "$selected" "" "" || exit 15
    IFS= read -r -z inserted || exit 16
    _file_search_quote "$selected"
    [[ $inserted == "$REPLY" && $PWD == "$initial" ]] || exit 17
    print safe-actions
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/files" "$TEST_TMP_DIR/bin") || return
  test_assert_equal safe-actions "$output"
}
test_case 'file actions preserve literal paths, capability fallbacks, stale-item guards, and app exit status' _test_file_actions_boundaries
