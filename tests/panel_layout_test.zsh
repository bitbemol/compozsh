# Shared information panels stay secondary until the user focuses them.
_test_panel_layout_hierarchy() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_RESULTS=(first second third)
    _ZLE_PICKER_LABELS=(feature/first feature/second feature/third)
    _ZLE_PICKER_RESULT_INDEXES=(0 1 2)
    _ZLE_PICKER_INSPECT_TEXTS[first]="$(print -rl -- "Fixture title" "Description" "" "Safety:" "  Be careful." detail-{01..60})"
    _ZLE_PICKER_VIEW_LIMIT=10
    for _ZLE_PICKER_INSPECT_TITLE in Help Branch Path Action; do
      for COLUMNS in 100 120 160 240; do
        LINES=30
        _ZLE_PICKER_INSPECT_FOCUS=0
        _zle_picker_render "" 1
        left_width=${_ZLE_PICKER_DISPLAY_LEFT_ENDS[1]}
        right_width=$(( COLUMNS - 1 - left_width - 3 ))
        (( left_width * 100 >= (COLUMNS - 1) * 60 &&
           right_width >= 28 && right_width <= 48 )) || {
          print -u2 -r -- "$_ZLE_PICKER_INSPECT_TITLE: secondary pane dominates at $COLUMNS columns ($left_width/$right_width)"
          exit 1
        }
        (( ${#_ZLE_PICKER_DISPLAY} <= 7 )) || {
          print -u2 -r -- "$_ZLE_PICKER_INSPECT_TITLE: passive details inflate a three-result list"
          exit 2
        }
        [[ ${_ZLE_PICKER_DISPLAY_RIGHT_ROLES[1]} == muted &&
           ${_ZLE_PICKER_DISPLAY_RIGHT_ROLES[2]} == info &&
           ${_ZLE_PICKER_DISPLAY_RIGHT_ROLES[5]} == warning ]] || exit 3
        [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} &&
           ${(F)_ZLE_PICKER_DISPLAY} == *" │ "* &&
           ${(F)_ZLE_PICKER_DISPLAY} != *" ┃ "* ]] || exit 7
        compact_page=$_ZLE_PICKER_INSPECT_PAGE
        _ZLE_PICKER_INSPECT_FOCUS=1
        _zle_picker_render "" 1
        (( ${_ZLE_PICKER_DISPLAY_LEFT_ENDS[1]} == left_width &&
           _ZLE_PICKER_INSPECT_PAGE > compact_page &&
           ${#_ZLE_PICKER_DISPLAY} <= 13 )) || exit 4
        [[ ${_ZLE_PICKER_DISPLAY_RIGHT_ROLES[1]} == heading ]] || exit 5
        [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected-inactive]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} &&
           ${(F)_ZLE_PICKER_DISPLAY} == *" ┃ "* ]] || exit 8
        for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
          (( ${(m)#row} < COLUMNS )) || exit 6
        done
      done
    done
    print list-first
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal list-first "$output"
}
test_case 'panel layout keeps every inspector secondary with bounded width and compact passive height' _test_panel_layout_hierarchy

_test_panel_layout_small_windows() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_RESULTS=(first second third)
    _ZLE_PICKER_LABELS=(first second third)
    _ZLE_PICKER_RESULT_INDEXES=(0 1 2)
    _ZLE_PICKER_INSPECT_TEXTS[second]="$(print -rl -- detail-{01..80})"
    for COLUMNS in 120 99 60 30; do
      for LINES in 30 18 10 8; do
        for _ZLE_PICKER_INSPECT_FOCUS in 0 1; do
          _ZLE_PICKER_INSPECT_OFFSET=0
          _zle_picker_render "" 2
          (( _ZLE_PICKER_SELECTED == 2 &&
             ${#_ZLE_PICKER_DISPLAY} <= LINES - 5 )) || exit 1
          if (( COLUMNS < 100 )); then
            [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"│"* &&
               ${(j: :)_ZLE_PICKER_DISPLAY} != *"┃"* ]] || exit 2
            if (( _ZLE_PICKER_INSPECT_FOCUS )); then
              (( !_ZLE_PICKER_INDEXES_VISIBLE )) || exit 3
            else
              (( ${#_ZLE_PICKER_DISPLAY} <= 4 )) || exit 4
            fi
          fi
          expected_page_stride=$_ZLE_PICKER_INSPECT_PAGE
          (( expected_page_stride > 1 )) && (( --expected_page_stride ))
          _zle_picker_page 1 2 3
          if (( _ZLE_PICKER_INSPECT_FOCUS )); then
            (( REPLY == 2 && _ZLE_PICKER_INSPECT_OFFSET == expected_page_stride )) || exit 5
          fi
        done
      done
    done
    _ZLE_PICKER_INSPECT_FOCUS=0
    COLUMNS=160 LINES=30
    _ZLE_PICKER_RESULTS=(item-{01..20})
    _ZLE_PICKER_LABELS=("${_ZLE_PICKER_RESULTS[@]}")
    _ZLE_PICKER_VIEW_LIMIT=20
    _ZLE_PICKER_INSPECT_TEXTS[item-11]="$(print -rl -- detail-{01..80})"
    _zle_picker_render "" 11
    (( _ZLE_PICKER_VISIBLE_COUNT == 20 &&
       ${#_ZLE_PICKER_DISPLAY} == 21 )) || exit 6
    print adaptive
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal adaptive "$output"
}
test_case 'panel layout preserves list capacity and focused paging across narrow and short windows' _test_panel_layout_small_windows

# Real resize signals must preserve focus, selection, and the captured results.
_test_panel_layout_native_resize() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.prompt"
    zmodload zsh/zpty
    functions[_panel_original_show]=$functions[_zle_picker_show]
    # Inspect the payload when ZLE is asked to paint it, rather than requiring
    # the width-dependent frame to remain installed while read waits.
    zle() {
      if [[ $1 == -R && -n ${POSTDISPLAY:-} && $POSTDISPLAY == "$_ZLE_PICKER_POSTDISPLAY" ]]; then
        local expected="$_ZLE_PICKER_TITLEBAR"$'\''\n'\''"$_ZLE_PICKER_HEADER"$'\''\n'\''"$_ZLE_PICKER_QUERY_ROW"$'\''\n'\''"${(F)_ZLE_PICKER_DISPLAY}"
        [[ $POSTDISPLAY == "$expected" && -z $BUFFER && $CURSOR == 0 &&
           -z $PREDISPLAY && $_ZLE_PICKER_QUERY == "feature query" &&
           -z ${region_highlight[(r)*memo=fixture]} &&
           -n ${region_highlight[(r)*memo=my-zsh-picker]} ]] ||
          print -u2 -r -- "PANEL-ERROR: resize lost editor state or failed to paint the calculated layout"
      fi
      builtin zle "$@"
    }
    _zle_picker_show() {
      _panel_original_show
      [[ -z $POSTDISPLAY ]] && (( !${#region_highlight} )) ||
        print -u2 -r -- "PANEL-ERROR: stale frame remains installed between paints"
      print -r -- "FRAME:$COLUMNS:$LINES:$_ZLE_PICKER_INSPECT_FOCUS:$_ZLE_PICKER_SELECTED:${_ZLE_PICKER_DISPLAY_LEFT_ENDS[2]:-0}:${#_ZLE_PICKER_DISPLAY}:$collections:TTY=$tty_device:END-PANEL-FRAME"
    }
    functions[_panel_original_widget]=$functions[_zle_picker_widget]
    _zle_picker_widget() {
      BUFFER=draft CURSOR=2 PREDISPLAY=prefix POSTDISPLAY=suffix
      region_highlight=("0 1 bold memo=fixture")
      _panel_original_widget
      [[ $BUFFER == draft && $CURSOR == 2 && $PREDISPLAY == prefix &&
         $POSTDISPLAY == suffix && ${(j: :)region_highlight} == "0 1 bold memo=fixture" ]] ||
        print -u2 -r -- "PANEL-ERROR: picker cleanup lost the existing editor display"
    }
    _panel_collect() {
      (( ++collections ))
      _ZLE_PICKER_RESULTS=(first second third)
      _ZLE_PICKER_LABELS=(feature/first feature/second feature/third)
      _ZLE_PICKER_RESULT_INDEXES=(0 1 2)
    }
    _panel_driver() {
      COLUMNS=120 LINES=30
      local -i collections=0
      local tty_device=$(command tty)
      _ZLE_PICKER_COLLECTOR=_panel_collect
      _ZLE_PICKER_INSPECT_TITLE=Branch
      _ZLE_PICKER_INSPECT_TEXTS=(first "$(print -rl -- detail-{01..60})" second "$(print -rl -- detail-{01..60})")
      _zle_picker_run 10 "feature query"
      (( $? == 1 && !_ZLE_PICKER_ACTIVE && !${#_ZLE_PICKER_RESULTS} )) || return 1
      print -r -- END-PANEL-DONE
    }
    _panel_read() {
      while zpty -r panel frame; do
        if [[ $frame == *"read-only variable"* || $frame == *PANEL-ERROR:* ]]; then
          print -u2 -r -- "unexpected picker diagnostics: ${(V)frame}"
          return 1
        fi
        [[ $frame == *"$1"* ]] && return 0
      done
      return 1
    }
    zpty panel _panel_driver || exit 1
    {
      _panel_read END-PANEL-FRAME || exit 2
      [[ $frame == *"FRAME:120:30:0:1:78:26:1:"* ]] || exit 3
      device=${frame##*:TTY=}
      device=${device%%:END-PANEL-FRAME*}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
      zpty -w -n panel $'\''\e[B'\''
      _panel_read END-PANEL-FRAME || exit 5
      [[ $frame == *"FRAME:120:30:0:2:"* ]] || exit 6
      command stty rows 18 cols 160 < "$device" || exit 7
      _panel_read END-PANEL-FRAME || exit 8
      [[ $frame == *"FRAME:160:18:0:2:108:14:1:"* ]] || exit 9
      zpty -w -n panel $'\''\x05'\''
      _panel_read END-PANEL-FRAME || exit 10
      [[ $frame == *"FRAME:160:18:1:2:108:14:1:"* ]] || exit 11
      command stty rows 18 cols 70 < "$device" || exit 12
      _panel_read END-PANEL-FRAME || exit 13
      [[ $frame == *"FRAME:70:18:1:2:0:14:1:"* ]] || exit 14
      zpty -w -n panel $'\''\x02'\''
      _panel_read END-PANEL-FRAME || exit 15
      [[ $frame == *"FRAME:70:18:0:2:-1:14:1:"* ]] || { print -u2 -r -- "unexpected list-only frame: ${(V)frame}"; exit 16; }
      command stty rows 30 cols 240 < "$device" || exit 17
      _panel_read END-PANEL-FRAME || exit 18
      [[ $frame == *"FRAME:240:30:0:2:188:26:1:"* ]] || exit 19
      zpty -w -n panel $'\''\x07'\''
      _panel_read END-PANEL-DONE || exit 20
    } always {
      zpty -d panel
    }
    print live-resize
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal live-resize "$output"
}
test_case 'panel layout handles live resize and focus without recapturing or losing selection' _test_panel_layout_native_resize
