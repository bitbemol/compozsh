# Viewport positions are separate from exact result values and visible keys.
_test_picker_scroll_viewport() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_RESULTS=(item-{01..25})
    _ZLE_PICKER_LABELS=("${_ZLE_PICKER_RESULTS[@]}")
    _ZLE_PICKER_RESULT_INDEXES=({1..25})
    _ZLE_PICKER_DIGIT_SELECT=1
    _ZLE_PICKER_VIEW_LIMIT=10
    COLUMNS=80 LINES=30
    _zle_picker_render "" 11
    (( _ZLE_PICKER_VIEW_OFFSET == 1 && _ZLE_PICKER_SELECTED == 11 )) || exit 1
    [[ ${_ZLE_PICKER_DISPLAY[1]} == *item-02* &&
       ${_ZLE_PICKER_DISPLAY[10]} == *item-11* ]] || exit 2
    [[ $_ZLE_PICKER_HEADER == *"2–11 of 25"* ]] || exit 3
    [[ ${(j:,:)_ZLE_PICKER_VISIBLE_KEYS} == 1,2,3,4,5,6,7,8,9,0 ]] || exit 4
    _zle_picker_render "" 25
    _zle_picker_step 1 25 25
    (( REPLY == 25 )) || exit 5
    [[ $_ZLE_PICKER_HEADER == *"16–25 of 25"* ]] || exit 6
    LINES=10
    _zle_picker_render "" 25
    (( _ZLE_PICKER_SELECTED == 25 && _ZLE_PICKER_VISIBLE_COUNT == 4 )) || exit 7
    [[ ${_ZLE_PICKER_DISPLAY[4]} == *item-25* &&
       ${(j:,:)_ZLE_PICKER_VISIBLE_KEYS} == 1,2,3,4 ]] || exit 8
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_picker_render missing 0
    (( !_ZLE_PICKER_SELECTED && !_ZLE_PICKER_VIEW_OFFSET && !${#_ZLE_PICKER_VISIBLE_KEYS} )) || exit 9
    print viewport
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal viewport "$output"
}
test_case 'picker scrolling retains selection across pages and resize with visible-slot keys' _test_picker_scroll_viewport

_test_picker_scroll_collectors() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    fc -p /dev/null 50000
    for i in {1..35}; do print -s -- "fixture command-$i"; done
    # Commit the final queued event; the unrelated sentinel is not a match.
    print -s -- history-fixture-sentinel
    _history_search_collect fixture 31
    (( ${#_HISTORY_SEARCH_RESULTS} == 31 )) || exit 1
    [[ ${_HISTORY_SEARCH_RESULTS[31]} == "fixture command-5" ]] || exit 2
    _DIRECTORY_PICKER_VALUES=(dir-{01..35})
    _DIRECTORY_PICKER_LABELS=("${_DIRECTORY_PICKER_VALUES[@]}")
    _directory_picker_collect "" 31
    (( ${#_ZLE_PICKER_RESULTS} == 31 )) || exit 3
    # A picker-owned snapshot remains stable while later history arrives.
    typeset -A _history_search_source=(
      1 "snapshot older" 2 "snapshot duplicate" 3 "snapshot newer"
      4 "snapshot duplicate")
    _history_search_collect snapshot 10
    [[ ${(j:|:)_HISTORY_SEARCH_RESULTS} == "snapshot duplicate|snapshot newer|snapshot older" ]] || exit 4
    _history_search_source=(1 "a spaced b" 2 "before ab" 3 "ab start" 4 "ab start")
    _history_search_collect ab 10
    [[ ${(j:|:)_HISTORY_SEARCH_RESULTS} == "ab start|before ab|a spaced b" ]] || exit 5
    _history_search_source=(1 "--release git" 2 "before git --release" 3 "git --release")
    _history_search_collect "git --release" 10
    [[ ${(j:|:)_HISTORY_SEARCH_RESULTS} == "git --release|before git --release|--release git" ]] || exit 6
    print collectors
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal collectors "$output"
}
test_case 'picker scrolling can request history and directory matches beyond one screen' _test_picker_scroll_collectors

_test_picker_scroll_navigation_and_tools() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.help"
    # d and g share navigation capture; compozsh owns the tool catalog.
    _NAVIGATION_PICKER_VALUES=(fixture-{01..35})
    _NAVIGATION_PICKER_LABELS=("${_NAVIGATION_PICKER_VALUES[@]}")
    _NAVIGATION_PICKER_INDEXES=({0..34})
    _COMPOZSH_TOOL_NAMES=("${_NAVIGATION_PICKER_VALUES[@]}")
    _COMPOZSH_TOOL_LABELS=("${_COMPOZSH_TOOL_NAMES[@]}")
    _COMPOZSH_TOOL_SEARCH_TEXTS=("${_COMPOZSH_TOOL_NAMES[@]}")
    _COMPOZSH_TOOL_INDEXES=({1..35})
    for collector in _navigation_picker_collect _compozsh_tool_picker_collect; do
      for query in "" fixture fxtr; do
        "$collector" "$query" 10
        first_page=("${_ZLE_PICKER_RESULTS[@]}")
        "$collector" "$query" 31
        (( ${#_ZLE_PICKER_RESULTS} == 31 )) || exit 1
        [[ ${_ZLE_PICKER_RESULTS[31]} == fixture-31 &&
           ${(j:|:)_ZLE_PICKER_RESULTS[1,10]} == ${(j:|:)first_page} ]] || exit 2
        "$collector" "$query" 70
        (( ${#_ZLE_PICKER_RESULTS} == 35 )) || exit 3
        [[ ${_ZLE_PICKER_RESULTS[-1]} == fixture-35 ]] || exit 4
      done
      "$collector" missing 70
      (( !${#_ZLE_PICKER_RESULTS} )) || exit 5
    done
    print navigation-and-tools
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal navigation-and-tools "$output"
}
test_case 'directory, branch, and tool collectors preserve ranking across every scroll batch' _test_picker_scroll_navigation_and_tools

_test_picker_scroll_focused_panels() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_RESULTS=(item-{01..25})
    _ZLE_PICKER_LABELS=("${_ZLE_PICKER_RESULTS[@]}")
    _ZLE_PICKER_VIEW_LIMIT=10
    _ZLE_PICKER_INSPECT_TEXTS[item-11]="$(print -rl -- detail-{01..60})"
    LINES=30
    for _ZLE_PICKER_INSPECT_TITLE in Help Branch Path; do
      for COLUMNS in 120 70; do
        _ZLE_PICKER_INSPECT_FOCUS=0
        _ZLE_PICKER_INSPECT_OFFSET=0
        _zle_picker_render "" 11
        viewport=$_ZLE_PICKER_VIEW_OFFSET
        _ZLE_PICKER_INSPECT_FOCUS=1
        _zle_picker_page 1 11 25
        (( REPLY == 11 && _ZLE_PICKER_INSPECT_OFFSET == _ZLE_PICKER_INSPECT_PAGE )) || exit 1
        _zle_picker_render "" 11
        (( _ZLE_PICKER_VIEW_OFFSET == viewport && _ZLE_PICKER_SELECTED == 11 )) || exit 2
        _zle_picker_page 100 11 25
        _zle_picker_render "" 11
        (( _ZLE_PICKER_INSPECT_OFFSET == ${#_ZLE_PICKER_INSPECT_LINES} - _ZLE_PICKER_INSPECT_PAGE )) || exit 3
        _zle_picker_page -100 11 25
        _zle_picker_render "" 11
        (( !_ZLE_PICKER_INSPECT_OFFSET && _ZLE_PICKER_SELECTED == 11 )) || exit 4
        _ZLE_PICKER_INSPECT_FOCUS=0
        _zle_picker_page 1 11 25
        (( REPLY == 21 && !_ZLE_PICKER_INSPECT_OFFSET )) || exit 5
      done
    done
    print focused-panels
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal focused-panels "$output"
}
test_case 'help, branch, and path panels page only the focused pane in wide and narrow layouts' _test_picker_scroll_focused_panels

_test_picker_scroll_native() {
  test_make_temp_dir || return
  local output i
  for i in {01..25}; do
    test_write_file "$TEST_TMP_DIR/files/row-$i" fixture || return
  done
  test_write_file "$TEST_TMP_DIR/bin/pbcopy" $'#!/bin/zsh\n/bin/cat > "$HOME/copied"' || return
  command chmod +x "$TEST_TMP_DIR/bin/pbcopy" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$3" "${path[@]}")
    source "$1/.zsh.addons/.zsh.find"
    source "$1/tests/support.zsh"
    source "$1/.zsh.addons/.zsh.editor"
    builtin cd "$2"
    source "$1/.zsh.addons/.zsh.prompt"
    zmodload zsh/zpty
    functions[_scroll_capture_original]=$functions[_file_search_capture_local]
    _file_search_capture_local() { (( ++captures )); _scroll_capture_original "$@"; }
    functions[_scroll_collect_original]=$functions[_file_search_picker_collect]
    _file_search_picker_collect() { (( ++collections )); _scroll_collect_original "$@"; }
    functions[_scroll_show_original]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _scroll_show_original
      # Synchronize paging only after capture; waiting-state coverage is separate.
      (( ${_ZLE_PICKER_BUSY:-0} )) && return 0
      print -r -- "FRAME:$_ZLE_PICKER_SELECTED:$_ZLE_PICKER_VIEW_OFFSET:$captures:$collections:TTY=$tty_device:END-SCROLL-FRAME"
    }
    _scroll_driver() {
      COLUMNS=102 LINES=30
      local -i captures=0 collections=0
      local actual="" expected=""
      local tty_device=$(command tty)
      test_search_session row
      case $scenario in
        (end) expected="${PWD:A}/row-25" ;;
        (digit) expected="${PWD:A}/row-02" ;;
        (filter) expected="${PWD:A}/row-25" ;;
        (copy|arrows|zero|pane) expected="${PWD:A}/row-11" ;;
        (resize) expected="${PWD:A}/row-07" ;;
        (pageup) expected="${PWD:A}/row-01" ;;
      esac
      if [[ $scenario == copy ]]; then
        actual=$(<"$HOME/copied")
      else
        _file_search_quote "$expected"
        expected=$REPLY
        IFS= read -r -z actual || return 1
      fi
      [[ $actual == "$expected" ]] || { print -r -- BAD-VALUE; return 2; }
      (( captures == 1 && collections <= 5 && !_ZLE_PICKER_VIEW_OFFSET &&
         !${#_ZLE_PICKER_VISIBLE_KEYS} && !${#_ZLE_PICKER_RESULTS} )) || return 3
      print -r -- END-SCROLL-DONE
    }
    _scroll_read() {
      local last_frame=""
      while zpty -r scrolling frame; do
        last_frame=$frame
        if [[ $frame == *"read-only variable"* ]]; then
          print -u2 -r -- "unexpected picker diagnostics: ${(V)frame}"
          return 1
        fi
        [[ $frame == *"$1"* ]] && return 0
      done
      zpty -t scrolling
      print -u2 -r -- "scroll test ($scenario): child status $?; missing $1; last frame: ${(V)last_frame}"
      return 1
    }
    for scenario in end digit zero filter copy arrows pageup pane resize; do
      zpty scrolling _scroll_driver || exit 1
      {
        _scroll_read END-SCROLL-FRAME || exit 2
        if [[ $scenario == arrows ]]; then
          for key in {1..10}; do
            zpty -w -n scrolling $'\''\e[B'\''
            _scroll_read END-SCROLL-FRAME || exit 3
          done
        else
          zpty -w -n scrolling $'\''\x16'\''
          _scroll_read END-SCROLL-FRAME || exit 3
        fi
        [[ $frame == *"FRAME:11:1:1:"* ]] || exit 4
        case $scenario in
          (end)
            for key in $'\''\e[6~'\'' $'\''\x16'\'' $'\''\e[B'\''; do
              zpty -w -n scrolling "$key"
              _scroll_read END-SCROLL-FRAME || exit 5
            done
            [[ $frame == *"FRAME:25:15:1:"* ]] || exit 6
            zpty -w -n scrolling $'\''\r'\'' ;;
          (digit) zpty -w -n scrolling 1 ;;
          (zero) zpty -w -n scrolling 0 ;;
          (arrows) zpty -w -n scrolling $'\''\r'\'' ;;
          (pane)
            zpty -w -n scrolling $'\''\e[C'\''
            _scroll_read END-SCROLL-FRAME || exit 12
            [[ $frame == *"FRAME:11:1:1:"* ]] || exit 13
            zpty -w -n scrolling $'\''\r'\'' ;;
          (resize)
            device=${frame##*:TTY=}
            device=${device%%:END-SCROLL-FRAME*}
            [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 14
            command stty rows 12 cols 70 < "$device" || exit 15
            _scroll_read END-SCROLL-FRAME || exit 16
            # The persistent scope row reserves one body row: at 12 lines,
            # five results remain visible and the first slot becomes row 7.
            [[ $frame == *"FRAME:11:6:1:2:"* ]] || exit 17
            zpty -w -n scrolling 1 ;;
          (pageup)
            zpty -w -n scrolling $'\''\x04'\''
            _scroll_read END-SCROLL-FRAME || exit 10
            [[ $frame == *"FRAME:1:0:1:"* ]] || exit 11
            zpty -w -n scrolling $'\''\r'\'' ;;
          (filter)
            zpty -w -n scrolling $'\''\e[200~row-25\e[201~'\''
            _scroll_read END-SCROLL-FRAME || exit 7
            [[ $frame == *"FRAME:1:0:1:"* ]] || exit 8
            zpty -w -n scrolling $'\''\r'\'' ;;
          (copy) zpty -w -n scrolling $'\''\x19'\'' ;;
        esac
        if [[ $scenario != copy ]]; then
          # File selection now opens actions; insertion remains explicit.
          _scroll_read END-SCROLL-FRAME || exit 18
          zpty -w -n scrolling $'\''\e[200~insert\e[201~'\''
          _scroll_read END-SCROLL-FRAME || exit 19
          zpty -w -n scrolling $'\''\r'\''
        fi
        _scroll_read END-SCROLL-DONE || exit 9
      } always {
        zpty -d scrolling
      }
    done
    print scrolling-actions
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/files" "$TEST_TMP_DIR/bin") || return
  test_assert_equal scrolling-actions "$output"
}
test_case 'picker scrolling reaches later files, selects visible digits, refines, and copies without rescanning' _test_picker_scroll_native
