# Navigator state lives only for this invocation; paths are never shell code.
_test_directory_navigator_bookmarks() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/alpha/child" \
    "$TEST_TMP_DIR/home/Projects/beta/child" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    setopt AUTO_CD
    _DIRECTORY_PICKER_INPUT="~/Projects/"
    _DIRECTORY_PICKER_STACK=()
    _DIRECTORY_PICKER_QUERIES=() _DIRECTORY_PICKER_SELECTIONS=() _DIRECTORY_PICKER_OFFSETS=()
    _DIRECTORY_PICKER_RESUME=("" 1 0)
    _directory_picker_prepare "$_DIRECTORY_PICKER_INPUT" ${#_DIRECTORY_PICKER_INPUT} || exit 1
    _ZLE_PICKER_BOOKMARK=(a 2 1)
    _directory_picker_transition parent "~/Projects/beta/"
    (( $? == 1 )) && [[ ${(j:,:)_DIRECTORY_PICKER_RESUME} == "a,2,1" ]] || exit 11
    _directory_picker_transition descend "~/Projects/beta/" || exit 2
    [[ ${(j:,:)_DIRECTORY_PICKER_RESUME} == ",1,0" ]] || exit 3
    # A newly created sibling changes the ordinal; Back must find beta by value.
    command mkdir "$HOME/Projects/aardvark" || exit 4
    _ZLE_PICKER_BOOKMARK=(child 1 0)
    _directory_picker_transition parent "" || exit 5
    [[ ${(j:,:)_DIRECTORY_PICKER_RESUME} == "a,3,1" &&
       $_DIRECTORY_PICKER_INPUT == "~/Projects/" &&
       !${#_DIRECTORY_PICKER_STACK} ]] || { print -u2 -- "lost bookmark: ${(j:,:)_DIRECTORY_PICKER_RESUME}"; exit 6; }
    _ZLE_PICKER_BOOKMARK=(b 1 0)
    _directory_picker_transition descend "~/Projects/beta/" || exit 7
    command mv "$HOME/Projects/beta" "$HOME/Projects/renamed" || exit 8
    _directory_picker_transition parent "" || exit 9
    [[ ${(j:,:)_DIRECTORY_PICKER_RESUME} == "b,1,0" ]] || exit 10
    print bookmarks
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bookmarks "$output"
}
test_case 'directory navigator restores query, selected path, and viewport when returning' _test_directory_navigator_bookmarks

_test_directory_navigator_hidden() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/visible" \
    "$TEST_TMP_DIR/home/Projects/.private/child" "$TEST_TMP_DIR/home/Only/.hidden" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    setopt AUTO_CD
    _DIRECTORY_PICKER_INPUT="~/Projects/"
    _DIRECTORY_PICKER_SHOW_HIDDEN=0
    _directory_picker_prepare "$_DIRECTORY_PICKER_INPUT" ${#_DIRECTORY_PICKER_INPUT} || exit 1
    [[ ${(j:,:)_DIRECTORY_PICKER_LABELS} == visible/ ]] || exit 2
    _ZLE_PICKER_BOOKMARK=("" 1 0)
    _directory_picker_transition toggle-hidden "~/Projects/visible/" || exit 3
    [[ $_DIRECTORY_PICKER_SHOW_HIDDEN == 1 &&
       ${(j:,:)_DIRECTORY_PICKER_LABELS} == .private/,visible/ &&
       ${(j:,:)_DIRECTORY_PICKER_RESUME} == ",2,0" ]] || exit 4
    _ZLE_PICKER_BOOKMARK=("" 2 0)
    _directory_picker_transition toggle-hidden "~/Projects/visible/" || exit 5
    [[ $_DIRECTORY_PICKER_SHOW_HIDDEN == 0 && ${(j:,:)_DIRECTORY_PICKER_LABELS} == visible/ ]] || exit 6
    # Hiding the only child keeps an empty, usable level; toggling can recover.
    _DIRECTORY_PICKER_INPUT="~/Only/" _DIRECTORY_PICKER_SHOW_HIDDEN=1
    _directory_picker_prepare "$_DIRECTORY_PICKER_INPUT" ${#_DIRECTORY_PICKER_INPUT} || exit 7
    _ZLE_PICKER_BOOKMARK=("" 1 0)
    _directory_picker_transition toggle-hidden "~/Only/.hidden/" || exit 8
    (( !${#_DIRECTORY_PICKER_VALUES} )) || exit 9
    _directory_picker_transition toggle-hidden "" || exit 10
    [[ ${(j:,:)_DIRECTORY_PICKER_LABELS} == .hidden/ ]] || exit 11
    print hidden
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal hidden "$output"
}
test_case 'directory navigator toggles hidden children and recovers from an empty view' _test_directory_navigator_hidden

_test_directory_navigator_header() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _directory_picker_breadcrumb "~/Projects/Example & Co/"
    [[ $REPLY == "~ › Projects › Example & Co" ]] || exit 1
    _ZLE_PICKER_SUBTITLE=$REPLY
    _ZLE_PICKER_TITLE=Directories
    _ZLE_PICKER_BROWSE_LABEL="Hidden: off"
    _ZLE_PICKER_INSPECT_ACTION=insert
    _ZLE_PICKER_RESULTS=(one two) _ZLE_PICKER_LABELS=(one two)
    _ZLE_PICKER_SCREEN_ACTIVE=1
    for COLUMNS in 40 120 180; do
      for LINES in 10 30 50; do
        _zle_picker_render two 2
        [[ $_ZLE_PICKER_HEADER == *"Hidden: off"* && -n $_ZLE_PICKER_SUBTITLE_ROW ]] || exit 2
        (( ${#_ZLE_PICKER_DISPLAY} == LINES - 5 &&
           ${(m)#_ZLE_PICKER_SUBTITLE_ROW} < COLUMNS )) || exit 3
        [[ ${_ZLE_PICKER_DISPLAY[-1]} == *"Esc cancel"* ]] || exit 4
      done
    done
    _directory_picker_breadcrumb /
    [[ $REPLY == / ]] || exit 5
    _ZLE_PICKER_SUBTITLE=$'\''literal %F{red}\e[2J\npath'\''
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_SUBTITLE_ROW != *$'\''\e'\''* && $_ZLE_PICKER_SUBTITLE_ROW != *$'\''\n'\''* ]] || exit 6
    LINES=8
    _zle_picker_render "" 1
    [[ -z $_ZLE_PICKER_SUBTITLE_ROW ]] || exit 7
    print header
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal header "$output"
}
test_case 'directory navigator separates a safe responsive breadcrumb from the title and filter' _test_directory_navigator_header

_test_directory_navigator_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/alpha/child/deep" \
    "$TEST_TMP_DIR/home/Projects/beta/child/deep" \
    "$TEST_TMP_DIR/home/Projects/.hidden/child" \
    "$TEST_TMP_DIR/home/Projects/space & Co/child" || return
  test_write_file "$TEST_TMP_DIR/home/bin/pbcopy" '#!/bin/zsh -df
    IFS= read -r content
    print -rn -- "$content" > "$HOME/copied"
  ' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/pbcopy" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    PATH="$HOME/bin:$PATH"
    rehash
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    setopt AUTO_CD
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    functions[_nav_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _nav_original_show
      (( BUFFERLINES == LINES - 1 )) || print -r -u $event_fd -- BAD-GEOMETRY
      print -r -u $event_fd -- "FRAME|$_DIRECTORY_PICKER_SHOW_HIDDEN|$_ZLE_PICKER_QUERY|${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]-}|${#_DIRECTORY_PICKER_STACK}|$COLUMNS|$LINES"
    }
    _nav_widget() {
      BUFFER="~/Projects/" CURSOR=11
      _directory_context_complete_widget
      [[ $BUFFER == "~/Projects/" && $CURSOR == 11 && -z $_ZLE_PICKER_SUBTITLE ]] || {
        print -r -u $event_fd -- BAD-RESTORE
        return 1
      }
      (( !${#_DIRECTORY_PICKER_VALUES} && !${#_DIRECTORY_PICKER_STACK} )) || {
        print -r -u $event_fd -- BAD-CLEANUP
        return 3
      }
      [[ $(<"$HOME/copied") == "$HOME/Projects/space & Co" ]] || {
        print -r -u $event_fd -- BAD-COPY
        return 2
      }
      print -r -u $event_fd -- DONE
      zle .accept-line
    }
    zle -N nav-test _nav_widget
    bindkey "^X^P" nav-test
    _nav_driver() {
      command stty rows 30 cols 120
      print -r -u $event_fd -- "READY:$(command tty)"
      local draft=""
      vared draft
    }
    _nav_expect() {
      local expected=$1 chunk=""
      while zselect -r $event_fd $pty_fd -t 500; do
        while zpty -r nav chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* ]] && break
          # Multi-character typing emits one frame per inserted character.
          [[ $event == FRAME* || $event == READY:* ]] || break
        fi
      done
      print -u2 -r -- "expected $expected; last event: $event"
      return 1
    }
    local event="" trace="" pty_fd=0 device=""
    zpty -b nav _nav_driver || exit 3
    pty_fd=$REPLY
    {
      # The readiness event contains the real PTY device used for resize.
      zselect -r $event_fd -t 500 && IFS= read -r -u $event_fd event || exit 4
      device=${event#READY:}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 5
      zpty -w -n nav $'\''\x18\x10'\''
      _nav_expect "FRAME|0||~/Projects/alpha/|0|120|30" || exit 6
      zpty -w -n nav a
      _nav_expect "FRAME|0|a|~/Projects/alpha/|0|120|30" || exit 7
      zpty -w -n nav $'\''\e[B'\''
      _nav_expect "FRAME|0|a|~/Projects/beta/|0|120|30" || exit 8
      zpty -w -n nav $'\''\e[C'\''
      _nav_expect "FRAME|0||~/Projects/beta/child/|1|120|30" || exit 9
      zpty -w -n nav c
      _nav_expect "FRAME|0|c|~/Projects/beta/child/|1|120|30" || exit 10
      zpty -w -n nav $'\''\t'\''
      _nav_expect "FRAME|0||~/Projects/beta/child/deep/|2|120|30" || exit 11
      zpty -w -n nav $'\''\e[D'\''
      _nav_expect "FRAME|0|c|~/Projects/beta/child/|1|120|30" || exit 12
      zpty -w -n nav $'\''\e[Z'\''
      _nav_expect "FRAME|0|a|~/Projects/beta/|0|120|30" || exit 13
      zpty -w -n nav $'\''\e[D'\''
      _nav_expect "FRAME|0|a|~/Projects/beta/|0|120|30" || exit 14
      zpty -w -n nav $'\''\x14'\''
      _nav_expect "FRAME|1|a|~/Projects/beta/|0|120|30" || exit 15
      zpty -w -n nav $'\''\x15.'\''
      _nav_expect "FRAME|1|.|~/Projects/.hidden/|0|120|30" || exit 16
      zpty -w -n nav $'\''\x14'\''
      _nav_expect "FRAME|0|.||0|120|30" || exit 17
      zpty -w -n nav $'\''\x14'\''
      _nav_expect "FRAME|1|.|~/Projects/.hidden/|0|120|30" || exit 18
      zpty -w -n nav $'\''\x15space'\''
      _nav_expect "FRAME|1|space|~/Projects/space & Co/|0|120|30" || exit 19
      zpty -w -n nav $'\''\e[C'\''
      _nav_expect "FRAME|1||~/Projects/space & Co/child/|1|120|30" || exit 24
      zpty -w -n nav $'\''\e[D'\''
      _nav_expect "FRAME|1|space|~/Projects/space & Co/|0|120|30" || exit 25
      command stty rows 18 cols 70 < "$device" || exit 20
      _nav_expect "FRAME|1|space|~/Projects/space & Co/|0|70|18" || exit 21
      zpty -w -n nav $'\''\x19'\''
      _nav_expect DONE || exit 22
      [[ $trace != *"read-only variable"* && $trace != *"bad math expression"* &&
         $trace != *$'\''\e[3J'\''* ]] || exit 23
    } always {
      zpty -d nav
      exec {event_fd}>&-
    }
    print native-navigator
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native-navigator "$output"
}
test_case 'directory navigator preserves native keys, nested bookmarks, clipboard data, and resized editing state' _test_directory_navigator_native
