# A full-screen picker has stable chrome; filtering only changes its content.
_test_picker_workspace_layout() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    typeset -i _ZLE_PICKER_SCREEN_ACTIVE=1
    _ZLE_PICKER_TITLE=Branches
    _ZLE_PICKER_INSPECT_ACTION=select
    _ZLE_PICKER_VIEW_LIMIT=10
    _ZLE_PICKER_DIGIT_SELECT=1
    for COLUMNS in 40 120 180; do
      for LINES in 10 30 50; do
        for count in 0 1 10 20; do
          _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _ZLE_PICKER_RESULT_INDEXES=()
          for (( i=1; i<=count; ++i )); do
            _ZLE_PICKER_RESULTS+=("branch-$i")
            _ZLE_PICKER_LABELS+=("branch-$i")
            _ZLE_PICKER_RESULT_INDEXES+=($i)
          done
          _zle_picker_render branch 1
          (( ${#_ZLE_PICKER_DISPLAY} == LINES - 4 )) || {
            print -u2 -- "footer moved at $COLUMNS x $LINES with $count results"
            exit 1
          }
          [[ ${_ZLE_PICKER_DISPLAY[1]} == ─* &&
             ${_ZLE_PICKER_DISPLAY[-1]} == *"Esc cancel"* ]] || exit 2
          (( _ZLE_PICKER_VISIBLE_COUNT <= 10 &&
             _ZLE_PICKER_VISIBLE_COUNT <= LINES - 6 )) || exit 3
          for metadata in _ZLE_PICKER_DISPLAY_STYLES _ZLE_PICKER_DISPLAY_INDEX_ENDS \
            _ZLE_PICKER_DISPLAY_HIGHLIGHTS \
            _ZLE_PICKER_DISPLAY_LEFT_ENDS _ZLE_PICKER_DISPLAY_RIGHT_ROLES _ZLE_PICKER_DISPLAY_RIGHT_SYNTAX \
            _ZLE_PICKER_DISPLAY_CONTEXT_STARTS _ZLE_PICKER_DISPLAY_MATCH_STARTS; do
            (( ${#${(@P)metadata}} == ${#_ZLE_PICKER_DISPLAY} )) || {
              print -u2 -- "misaligned row metadata: $metadata"
              exit 10
            }
          done
          for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
            (( ${(m)#row} < COLUMNS )) || exit 4
            [[ $row != *$'\''\e'\''* ]] || exit 5
          done
        done
      done
    done
    COLUMNS=120 LINES=50
    _ZLE_PICKER_INSPECT_TEXTS=(branch-1 "$(print -rl -- detail-{01..80})")
    _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render "" 1
    (( ${#_ZLE_PICKER_DISPLAY} == 46 && _ZLE_PICKER_INSPECT_PAGE < 15 )) || exit 6
    _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_render "" 1
    (( ${#_ZLE_PICKER_DISPLAY} == 46 && _ZLE_PICKER_INSPECT_PAGE > 30 )) || exit 7
    [[ ${(j:,:)_ZLE_PICKER_VISIBLE_KEYS} == 1,2,3,4,5,6,7,8,9,0 ]] || exit 8
    _ZLE_PICKER_SCREEN_ACTIVE=0
    _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render "" 1
    (( ${#_ZLE_PICKER_DISPLAY} < 20 )) || exit 9
    print anchored
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal anchored "$output"
}
test_case 'picker workspace anchors search and footer across filtering, focus, and terminal sizes' _test_picker_workspace_layout

_test_picker_workspace_matches() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _zle_picker_match_spans "swift build -c release" "-c SWIFT"
    [[ ${(j:,:)reply} == "12 14,0 5" ]] || exit 1
    _zle_picker_match_spans "git switch" gsw
    [[ ${(j:,:)reply} == "0 1,4 6" ]] || exit 2
    _zle_picker_match_spans "literal [x]* filename" "[x]*"
    [[ ${(j:,:)reply} == "8 12" ]] || exit 3
    _zle_picker_match_spans "界 café" CAFÉ
    [[ ${(j:,:)reply} == "2 6" ]] || exit 4
    _zle_picker_match_spans "partial" parz
    (( !${#reply} )) || exit 5
    _zle_picker_match_spans "anything" ""
    (( !${#reply} )) || exit 6
    print matched
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal matched "$output"
}
test_case 'picker workspace highlights literal and fuzzy fragments without interpreting patterns' _test_picker_workspace_matches

_test_picker_workspace_semantic_label_highlights() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    COLUMNS=80 LINES=30
    _ZLE_PICKER_DIGIT_SELECT=1
    _ZLE_PICKER_RESULTS=(image)
    _ZLE_PICKER_LABELS=("disk.iso · ARM64 · 2.0 GiB")
    _ZLE_PICKER_RESULT_INDEXES=(1)
    _ZLE_PICKER_LABEL_HIGHLIGHTS=(image "11:16:picker-architecture 19:26:picker-size 0:4:not-a-role")
    _zle_picker_render "" 1
    print -r -- "spans:${_ZLE_PICKER_DISPLAY_HIGHLIGHTS[1]}"
    _zle_picker_label_highlight_style picker-architecture 1 "fg=16,bg=75,bold"
    print -r -- "selected-architecture:$REPLY"
    _zle_picker_label_highlight_style picker-size 1 "fg=16,bg=75,bold"
    print -r -- "selected-size:$REPLY"
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'spans:18:23:picker-architecture 26:33:picker-size' \
    'semantic label spans did not follow the visible result-row prefix' || return
  test_assert_contains "$output" 'selected-architecture:bg=75,bold,fg=231,bold' \
    'architecture styling replaced the selected-row background' || return
  test_assert_contains "$output" 'selected-size:bg=75,bold,fg=229,bold' \
    'size styling did not remain visually distinct on the selected row'
}
test_case 'picker workspace colors semantic label spans without embedding terminal escapes' \
  _test_picker_workspace_semantic_label_highlights

# A real shell prompt (rather than vared) proves that a multiline draft and
# prompt cannot push the fixed workspace footer below the terminal boundary.
_test_picker_workspace_native_editor() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/session.zsh" '
    source "$1/.zsh.addons/.zsh.editor"
    PROMPT=$'\''fixture line one\nfixture line two\n> '\''
    RPROMPT=fixture-clock
    exec {event_fd}<> "$HOME/events"
    functions[_workspace_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _workspace_original_show
      [[ $_ZLE_PICKER_POSTDISPLAY == "Compozsh / History"* &&
         $_ZLE_PICKER_POSTDISPLAY == "$_ZLE_PICKER_TITLEBAR"$'\''\n'\''"$_ZLE_PICKER_HEADER"* ]] || {
        print -r -u $event_fd -- BAD-TITLE
        return 1
      }
      (( BUFFERLINES == LINES - 1 )) &&
        [[ -z $BUFFER && -z $PREDISPLAY && -z $POSTDISPLAY && -z $PROMPT && -z $RPROMPT ]] || {
          print -r -u $event_fd -- BAD-FRAME
          return 1
        }
      print -r -u $event_fd -- "FRAME:$COLUMNS:$LINES:$_ZLE_PICKER_SELECTED"
    }
    zle() {
      if [[ $1 == -R && -n $POSTDISPLAY && $POSTDISPLAY == "$_ZLE_PICKER_POSTDISPLAY" ]]; then
        [[ -n ${region_highlight[(r)P0 *memo=my-zsh-picker]} ]] ||
          print -r -u $event_fd -- NO-TITLE-STYLE
        [[ -n ${region_highlight[(r)*underline*memo=my-zsh-picker]} ]] ||
          print -r -u $event_fd -- NO-MATCH-STYLE
      fi
      builtin zle "$@"
    }
    _workspace_collect() {
      _ZLE_PICKER_RESULTS=("swift build -c release" "swift test -c debug")
      _ZLE_PICKER_LABELS=("${_ZLE_PICKER_RESULTS[@]}")
    }
    _workspace_launch() {
      local expected=$'\''unfinished\nmultiline draft\nwith more lines'\''
      local original_prompt=$PROMPT original_rprompt=$RPROMPT
      BUFFER=$expected CURSOR=8 MARK=3 PREDISPLAY=prefix POSTDISPLAY=suffix
      region_highlight=("0 2 bold memo=fixture")
      _ZLE_PICKER_COLLECTOR=_workspace_collect
      _ZLE_PICKER_TITLE=History
      _ZLE_PICKER_INSPECT_ACTION=insert
      _zle_picker_loop "SWIFT -c" 10
      (( $? == 1 )) && [[ $BUFFER == "$expected" && $CURSOR == 8 && $MARK == 3 &&
        $PREDISPLAY == prefix && $POSTDISPLAY == suffix &&
        $PROMPT == "$original_prompt" && $RPROMPT == "$original_rprompt" &&
        ${(j: :)region_highlight} == "0 2 bold memo=fixture" ]] || {
          print -r -u $event_fd -- BAD-RESTORE
          return 1
      }
      print -r -u $event_fd -- RESTORED
    }
    zle -N workspace-launch _workspace_launch
    bindkey "^X^P" workspace-launch
    command stty rows 30 cols 120
    print -r -u $event_fd -- "READY:$(command tty)"
  ' || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    _workspace_event() {
      local chunk=""
      while zselect -r $event_fd $pty_fd -t 500; do
        while zpty -r workspace chunk; do trace+=$chunk; done
        IFS= read -r -t 0 -u $event_fd event && return 0
      done
      print -u2 -- "workspace event timed out after $event"
      return 1
    }
    local event="" trace="" device="" pty_fd=0
    zpty -b workspace "$2" -dfi || exit 3
    pty_fd=$REPLY
    {
      zpty -w workspace "source ${(q)HOME}/session.zsh ${(q)1}"
      _workspace_event && [[ $event == READY:* ]] || exit 4
      device=${event#READY:}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 5
      zpty -w -n workspace $'\''\x18\x10'\''
      _workspace_event && [[ $event == FRAME:120:30:1 ]] || {
        print -u2 -- "unexpected first workspace: $event"
        exit 6
      }
      command stty rows 18 cols 70 < "$device" || exit 7
      _workspace_event && [[ $event == FRAME:70:18:1 ]] || exit 8
      zpty -w -n workspace $'\''\e[B'\''
      _workspace_event && [[ $event == FRAME:70:18:2 ]] || exit 9
      zpty -w -n workspace $'\''\x07'\''
      _workspace_event && [[ $event == RESTORED ]] || { print -u2 -- "$event"; exit 10; }
      [[ $trace != *"read-only variable"* && $trace != *"bad math expression"* ]] || exit 11
    } always {
      zpty -d workspace
      exec {event_fd}>&-
    }
    print native-workspace
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN") || return
  test_assert_equal native-workspace "$output"
}
test_case 'picker workspace hides and restores multiline shell editing state through a real resize' _test_picker_workspace_native_editor
