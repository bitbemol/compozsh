# One interaction vocabulary for every full-screen tool.
_test_fullscreen_footer_contract() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_INSPECT_ACTION=switch
    _ZLE_PICKER_COPY_ENABLED=1 _ZLE_PICKER_DIGIT_SELECT=1
    _ZLE_PICKER_INDEXES_VISIBLE=1
    _ZLE_PICKER_INSPECT_TEXTS=(main details)
    _ZLE_PICKER_RESULTS=(main) _ZLE_PICKER_SELECTED=1
    for width in 39 69 119 179; do
      _zle_picker_footer $width "" || exit 1
      [[ $REPLY == *"⏎ switch"* && $REPLY == *"Esc cancel"* &&
         $REPLY == *"^K keys"* && $REPLY != *…* ]] || exit 2
      (( ${(m)#REPLY} <= width )) || exit 3
    done
    _zle_picker_footer 179 ""
    [[ $REPLY == *"^Y copy"* && $REPLY == *"Tab details"* && $REPLY == *"0–9 switch"* ]] || exit 4
    _zle_picker_footer 179 query
    [[ $REPLY != *"0–9"* ]] || exit 5
    _ZLE_PICKER_COPY_ENABLED=0 _ZLE_PICKER_CANCEL_LABEL=back
    _zle_picker_footer 179 ""
    [[ $REPLY != *"^Y copy"* && $REPLY == *"Esc back"* ]] || exit 6
    _ZLE_PICKER_REFRESH_ENABLED=1
    _zle_picker_footer 179 ""
    [[ $REPLY == *"^R refresh"* ]] || exit 8
    LINES=50 _zle_picker_guide_render 179
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Ctrl-R"*"Refresh the current captured choices"* ]] || exit 9
    _ZLE_PICKER_REFRESH_ENABLED=0
    _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_footer 179 ""
    [[ $REPLY == *"↑/↓ scroll"* && $REPLY == *"Tab list"* && $REPLY != *"0–9"* ]] || exit 7
    print consistent
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal consistent "$output"
}
test_case 'fullscreen contract keeps essential shortcuts visible and capability hints consistent' _test_fullscreen_footer_contract

_test_fullscreen_status_view_omits_input_and_bottom_footer() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.output"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    COLUMNS=140 LINES=32
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_STATUS_VIEW=1 _ZLE_PICKER_BUSY=1
    _ZLE_PICKER_TITLE="External device / Flash · Step 3 of 3"
    _ZLE_PICKER_SUBTITLE="Image  ›  Drive  ›  FLASH"
    _ZLE_PICKER_BROWSE_LABEL="● WRITING IMAGE"
    _ZLE_PICKER_QUERY_LABEL=Query _ZLE_PICKER_QUERY=""
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _ZLE_PICKER_RESULT_INDEXES=()
    _ZLE_PICKER_EMPTY_LINES=("" IMAGE "  linux.iso" "" "[========········] 50%" "KEEP THE EXTERNAL DRIVE CONNECTED")
    _ZLE_PICKER_BUSY_STYLES=(picker-text picker-status-heading picker-status-info picker-text picker-status-progress picker-status-warning)
    _zle_picker_render "" 0 || exit 1
    [[ -z $_ZLE_PICKER_QUERY_ROW ]] || exit 2
    [[ $_ZLE_PICKER_DISPLAY[-1] == "KEEP THE EXTERNAL DRIVE CONNECTED"* ]] || exit 3
    [[ ${(F)_ZLE_PICKER_DISPLAY} != *Query* && ${(F)_ZLE_PICKER_DISPLAY} != *"● WRITING IMAGE"* ]] || exit 4
    [[ ${(j:,:)_ZLE_PICKER_DISPLAY_STYLES} == *picker-status-progress* &&
       ${(j:,:)_ZLE_PICKER_DISPLAY_STYLES} == *picker-status-warning* ]] || exit 5
    [[ $_ZLE_PICKER_TITLEBAR == *"In progress" && $_ZLE_PICKER_HEADER == "● WRITING IMAGE" ]] || exit 6
    print status-layout
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal status-layout "$output"
}
test_case 'fullscreen status view keeps progress prominent and removes input chrome' \
  _test_fullscreen_status_view_omits_input_and_bottom_footer

_test_fullscreen_passive_rows_are_not_picker_actions() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    COLUMNS=140 LINES=24
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_DIGIT_SELECT=1
    _ZLE_PICKER_TITLE="External device / Flash · Windows unsupported"
    _ZLE_PICKER_BROWSE_LABEL="captured choices · no action yet"
    _ZLE_PICKER_QUERY_LABEL=Done
    _ZLE_PICKER_RESULTS=(done) _ZLE_PICKER_LABELS=(Done)
    _ZLE_PICKER_RESULT_INDEXES=(1)
    _ZLE_PICKER_PASSIVE_LINES=(
      "Windows USB creation is unavailable on stock macOS"
      "Boot requirement · Windows Setup requires FAT32")
    _ZLE_PICKER_PASSIVE_STYLES=(picker-error picker-text)
    _zle_picker_render "" 1 || exit 1
    [[ $_ZLE_PICKER_DISPLAY[2] == "[ 1] ▸ Done"* ]] || exit 2
    [[ $_ZLE_PICKER_DISPLAY[3] == "Windows USB creation is unavailable"* &&
       $_ZLE_PICKER_DISPLAY[4] == "Boot requirement"* ]] || exit 3
    [[ $_ZLE_PICKER_DISPLAY[3] != \[* && $_ZLE_PICKER_DISPLAY[4] != \[* ]] || exit 4
    [[ ${(j:,:)_ZLE_PICKER_VISIBLE_KEYS} == 1 ]] || exit 5
    [[ $_ZLE_PICKER_DISPLAY_STYLES[3] == picker-error &&
       $_ZLE_PICKER_DISPLAY_STYLES[4] == picker-text ]] || exit 6
    print passive-layout
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal passive-layout "$output"
}
test_case 'fullscreen passive context never receives picker numbers or actions' \
  _test_fullscreen_passive_rows_are_not_picker_actions

_test_files_primary_action_hints() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_RESULTS=(/example/notes.txt) _ZLE_PICKER_SELECTED=1
    _ZLE_PICKER_ACCEPT_LABELS=(/example/notes.txt "file actions")
    _ZLE_PICKER_INSPECT_ACTION=insert _ZLE_PICKER_CANCEL_LABEL=back
    _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_SEARCH_ACTION=search-local
    for width in 59 79 119; do
      _zle_picker_footer $width notes
      [[ $REPLY == "⏎ file actions"* && $REPLY == *"Esc back"* &&
         $REPLY == *"^K keys"* && $REPLY == *"^X options"* ]] || {
        print -u2 -- "File action/options hints missing at $width columns: $REPLY"
        exit 1
      }
      (( ${(m)#REPLY} <= width )) || exit 2
    done
    for width in 12 24 39; do
      _zle_picker_footer $width notes
      [[ $REPLY == *Esc* && $REPLY != *"^X"* ]] || exit 3
      (( ${(m)#REPLY} <= width )) || exit 4
    done
    _ZLE_PICKER_WORKSPACE_ACTIONS=0 _ZLE_PICKER_SEARCH_ACTION=""
    _ZLE_PICKER_ACCEPT_LABELS=() _ZLE_PICKER_INSPECT_ACTION=apply
    _zle_picker_footer 119 ""
    [[ $REPLY == "⏎ apply"* && $REPLY != *"^X"* ]] || exit 5
    print primary-actions
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal primary-actions "$output"
}
test_case 'file results prioritize Enter and expose optional workspace controls at compact widths' _test_files_primary_action_hints

_test_git_review_shortcut_label() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_RESULTS=(main) _ZLE_PICKER_SELECTED=1
    _ZLE_PICKER_INSPECT_ACTION=switch _ZLE_PICKER_WORKSPACE_ACTIONS=1
    _ZLE_PICKER_OPTIONS_KIND=git
    for width in 49 69 119 179; do
      _zle_picker_footer $width ""
      [[ $REPLY == *"^X review"* && $REPLY != *"^X options"* &&
         $REPLY == *"Esc cancel"* && $REPLY == *"^K keys"* ]] || {
        print -u2 -- "Branch hint must name review: $REPLY"; exit 1
      }
      (( ${(m)#REPLY} <= width )) || exit 2
    done
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_SELECTED=0
    _zle_picker_footer 119 ""
    [[ $REPLY == *"^X review"* ]] || exit 3
    # Review stays reachable in an unborn repo, but not without its peer.
    _ZLE_PICKER_WORKSPACE_ACTIONS=0
    _zle_picker_footer 119 ""
    [[ $REPLY != *"^X"* ]] || exit 4
    # Reader disclosure is direct; filesystem menus retain their own labels.
    _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_DOCUMENT=1
    _ZLE_PICKER_DOCUMENT_REFRESH=1 _ZLE_PICKER_DOCUMENT_MODE=focused
    _ZLE_PICKER_OPTIONS_KIND=git-document
    _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_INSPECT_ACTION=read
    _zle_picker_footer 119 ""
    [[ $REPLY == *"→ read"* && $REPLY == *"^R refresh"* && $REPLY != *"^X"* ]] || exit 5
    _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_OPTIONS_KIND=""
    _zle_picker_footer 119 ""
    [[ $REPLY == *"^X options"* && $REPLY != *"^X review"* ]] || exit 6
    _ZLE_PICKER_WORKSPACE_ACTIONS=0
    _zle_picker_footer 119 ""
    [[ $REPLY != *"^X"* ]] || exit 7
    print contextual
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal contextual "$output"
}
test_case 'Git branch shortcut names review while reader disclosure and filesystem options remain contextual' _test_git_review_shortcut_label

_test_fullscreen_guide_contract() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_GUIDE_ACTIVE=1
    _ZLE_PICKER_TITLE=Branches _ZLE_PICKER_SUBTITLE="Example repository"
    _ZLE_PICKER_INSPECT_ACTION=switch _ZLE_PICKER_COPY_ENABLED=1
    _ZLE_PICKER_RESULTS=(main topic) _ZLE_PICKER_LABELS=(main topic)
    _ZLE_PICKER_INSPECT_TEXTS=(main details topic details)
    for COLUMNS in 40 120; do
      for LINES in 10 30; do
        _zle_picker_render topic 2
        [[ ${(j:,:)_ZLE_PICKER_DISPLAY} == *"Keyboard guide"* ]] || exit 1
        (( !_ZLE_PICKER_INDEXES_VISIBLE && ${#_ZLE_PICKER_DISPLAY} == LINES - 5 )) || exit 2
        [[ $_ZLE_PICKER_SELECTED == 2 && $_ZLE_PICKER_QUERY == topic ]] || exit 3
        for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
          (( ${(m)#row} < COLUMNS )) || exit 4
        done
      done
    done
    _zle_picker_step 1 2 2
    (( REPLY == 2 && _ZLE_PICKER_GUIDE_OFFSET == 1 )) || exit 5
    _ZLE_PICKER_GUIDE_ACTIVE=0
    _zle_picker_render topic 2
    [[ ${(j:,:)_ZLE_PICKER_DISPLAY} != *"Keyboard guide"* && $_ZLE_PICKER_SELECTED == 2 ]] || exit 6
    print guide
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal guide "$output"
}
test_case 'fullscreen contract keyboard guide preserves selection and responsive geometry' _test_fullscreen_guide_contract

_test_directory_workspace_snapshot() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/work/api" "$TEST_TMP_DIR/home/personal/api" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd "$HOME/work/api"
    dirstack=("$HOME/personal/api" "$HOME/missing")
    _directory_stack_capture
    _directory_stack_describe
    [[ ${_NAVIGATION_PICKER_LABELS[1]} == api/ && ${_NAVIGATION_PICKER_LABELS[2]} == api/ ]] || exit 1
    [[ ${_ZLE_PICKER_CONTEXTS[$HOME/work/api]} == *"current"* &&
       ${_ZLE_PICKER_CONTEXTS[$HOME/personal/api]} == *"~/personal"* ]] || exit 2
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[$HOME/missing]} == *"Unavailable"* ]] || exit 3
    _zle_picker_inspect_prepare "$HOME/missing" 48
    [[ ${(j:,:)_ZLE_PICKER_INSPECT_ROLES} == *warning* ]] || exit 7
    _navigation_picker_collect personal 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == "$HOME/personal/api" ]] || exit 4
    _navigation_picker_collect api 10
    (( ${#_ZLE_PICKER_RESULTS} == 2 )) || exit 5
    # The captured view is stable even if a directory disappears while open.
    command rmdir "$HOME/personal/api"
    _navigation_picker_collect personal 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == "$HOME/personal/api" ]] || exit 6
    _NAVIGATION_PICKER_VALUES=() _NAVIGATION_PICKER_LABELS=() _NAVIGATION_PICKER_INDEXES=()
    for i in {1..201}; do
      _NAVIGATION_PICKER_VALUES+=("$HOME/entry-$i")
      _NAVIGATION_PICKER_LABELS+=("~/entry-$i")
      _NAVIGATION_PICKER_INDEXES+=($i)
    done
    _directory_stack_describe
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[$HOME/entry-201]} == *"Not checked"* ]] || exit 8
    print snapshot
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal snapshot "$output"
}
test_case 'directory workspace distinguishes duplicate names and searches complete captured paths' _test_directory_workspace_snapshot

_test_directory_workspace_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/work/api" "$TEST_TMP_DIR/home/personal/api" || return
  test_write_file "$TEST_TMP_DIR/home/bin/pbcopy" $'#!/bin/zsh -df\n/bin/cat > "$HOME/copied"' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/pbcopy" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$HOME/bin" "${path[@]}")
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd "$HOME/work/api"
    dirstack=("$HOME/personal/api")
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    functions[_contract_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _contract_show
      (( BUFFERLINES == LINES - 1 )) || print -r -u $efd BAD-GEOMETRY
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_GUIDE_ACTIVE|$_ZLE_PICKER_QUERY|${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]-}|$COLUMNS|$LINES"
    }
    _contract_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "READY:$(command tty)"
      _directory_browser_session ./ cd command recents
      local result=$?
      (( result == 0 && !${#_ZLE_PICKER_INSPECT_TEXTS} && !${#_NAVIGATION_PICKER_SEARCH_LABELS} )) || {
        print -r -u $efd BAD-CLEANUP; return 1
      }
      if [[ $scenario == copy ]]; then
        [[ $(<"$HOME/copied") == "$HOME/personal/api" && $PWD == "$HOME/work/api" ]] || {
          print -r -u $efd BAD-COPY; return 2
        }
      else
        [[ $PWD == "$HOME/personal/api" ]] || { print -r -u $efd BAD-CD; return 3; }
      fi
      print -r -u $efd DONE
    }
    _contract_expect() {
      local expected=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r contract chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $expected; last event $event"
      return 1
    }
    local scenario="" event="" trace="" device="" pfd=0
    for scenario in copy cd; do
      zpty -b contract _contract_driver || exit 2
      pfd=$REPLY
      {
        zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 3
        device=${event#READY:}
        [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
        _contract_expect "FRAME|0||$HOME/work/api|120|30" || exit 5
        if [[ $scenario == copy ]]; then
          zpty -w -n contract personal
          _contract_expect "FRAME|0|personal|$HOME/personal/api|120|30" || exit 6
          zpty -w -n contract $'\''\x0b'\''
          _contract_expect "FRAME|1|personal|$HOME/personal/api|120|30" || exit 7
          # Pasted newlines/digits must be consumed as paste data, never keys
          # that dismiss the guide or activate a result after dismissal.
          zpty -w -n contract $'\''\e[200~\r1\e[201~\r'\''
          _contract_expect "FRAME|0|personal|$HOME/personal/api|120|30" || exit 14
          zpty -w -n contract $'\''\x0b'\''
          _contract_expect "FRAME|1|personal|$HOME/personal/api|120|30" || exit 15
          # A digit, clipboard key and text cannot apply or alter the guide.
          zpty -w -n contract $'\''1\x19\x0f\x18\x14z'\''
          command stty rows 12 cols 70 < "$device" || exit 8
          _contract_expect "FRAME|1|personal|$HOME/personal/api|70|12" || exit 9
          zpty -w -n contract $'\''\x16'\''
          _contract_expect "FRAME|1|personal|$HOME/personal/api|70|12" || exit 10
          zpty -w -n contract $'\''\x04'\''
          _contract_expect "FRAME|1|personal|$HOME/personal/api|70|12" || exit 16
          zpty -w -n contract $'\''\x0b'\''
          _contract_expect "FRAME|0|personal|$HOME/personal/api|70|12" || exit 17
          zpty -w -n contract $'\''\x0b'\''
          _contract_expect "FRAME|1|personal|$HOME/personal/api|70|12" || exit 18
          zpty -w -n contract $'\''\e'\''
          _contract_expect "FRAME|0|personal|$HOME/personal/api|70|12" || exit 11
          zpty -w -n contract $'\''\x19'\''
        else
          zpty -w -n contract 1
        fi
        _contract_expect DONE || exit 12
        [[ $trace != *"read-only variable"* && $trace != *"bad math"* && $trace != *$'\''\e[3J'\''* ]] || exit 13
      } always {
        zpty -d contract
      }
    done
    exec {efd}>&-
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'directory workspace native guide survives resize and preserves copy and digit navigation' _test_directory_workspace_native
