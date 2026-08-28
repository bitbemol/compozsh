# Shallow snapshots, shared column geometry, and explicit browser actions.
_test_browser_preview() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/alpha/deep" || return
  test_write_file "$TEST_TMP_DIR/home/Projects/alpha/notes.txt" 'private content must never be read' || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    (( ${+functions[_directory_browser_preview]} )) || { print -u2 "missing shallow preview"; exit 1; }
    _DIRECTORY_PICKER_SHOW_HIDDEN=0
    _directory_browser_preview "~/Projects/alpha/" || exit 2
    [[ $REPLY == *notes.txt* && $REPLY == *deep/* && $REPLY != *"private content"* ]] || exit 3
    command mkdir "$HOME/Projects/alpha/.hidden"
    _directory_browser_preview "~/Projects/alpha/" || exit 4
    [[ $REPLY != *.hidden* ]] || exit 5
    _DIRECTORY_PICKER_SHOW_HIDDEN=1
    _directory_browser_preview "~/Projects/alpha/" || exit 6
    [[ $REPLY == *.hidden/* ]] || exit 7
    _directory_browser_preview "$HOME/missing"
    [[ $REPLY == *Unavailable:* ]] || exit 8
    for i in {1..50}; do command mkdir "$HOME/Projects/alpha/folder-$i"; done
    _directory_browser_preview "~/Projects/alpha/" || exit 9
    [[ $REPLY == *Limits:* ]] || exit 10
    (( ${#${(@f)REPLY}} <= 47 )) || exit 11
    print preview
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preview "$output"
}
test_case 'directory browser previews only one requested level with a visible bound' _test_browser_preview

_test_browser_contents_context() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/files" "$TEST_TMP_DIR/home/empty" \
    "$TEST_TMP_DIR/home/mixed/child" || return
  test_write_file "$TEST_TMP_DIR/home/files/notes.txt" 'never display this content' || return
  test_write_file "$TEST_TMP_DIR/home/files/.private" 'hidden content' || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    local scenario=files query="" row="" text=""
    # Pure content checks bypass only the terminal session, not the controller.
    _zle_picker_run() { "$5"; }
    local -i _ZLE_PICKER_SCREEN_ACTIVE=1
    _directory_browser_pick() {
      "$_ZLE_PICKER_COLLECTOR" "$query" 11
      for COLUMNS in 40 99 120 180; do
        for LINES in 10 30; do
          _zle_picker_render "$query" 1
          for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
            (( ${(m)#row} < COLUMNS )) || { print -u2 overflow; exit 1; }
          done
          (( ${#_ZLE_PICKER_DISPLAY} == LINES - 5 )) || exit 2
          (( !_ZLE_PICKER_INDEXES_VISIBLE && !_ZLE_PICKER_SELECTED )) || exit 3
        done
      done
      text="${(j:,:)_ZLE_PICKER_DISPLAY}"
      case $scenario in
        (files)
          [[ $text == *"No child directories"* && $text == *"1 file"* && $text == *notes.txt* ]] || {
            print -u2 -- "file-only folder lost its contents: $text"; exit 4;
          }
          [[ $text != *.private* && $text != *"never display"* && $text != *"hidden content"* ]] || exit 5
          [[ ${(j:,:)_ZLE_PICKER_DISPLAY_STYLES} != *picker-empty* ]] || exit 6 ;;
        (empty)
          [[ $text == *"No visible entries"* && $text != *notes.txt* ]] || exit 7 ;;
        (mixed)
          [[ $text == *"No directories match"* && $text == *"1 directory"* && $text == *"Clear"* ]] || exit 8
          : > "$HOME/mixed/created-after-capture.txt"
          "$_ZLE_PICKER_COLLECTOR" "$query" 11
          [[ ${(j:,:)_ZLE_PICKER_EMPTY_LINES} == *"0 files"* && ${(j:,:)_ZLE_PICKER_EMPTY_LINES} != *created-after-capture* ]] || exit 17 ;;
        (many)
          [[ $text == *"13 files"* && $text == *"5 more"* ]] || exit 9
          [[ ${#_ZLE_PICKER_EMPTY_LINES} -le 16 ]] || exit 10
          [[ $text != *$'\''\e'\''* && $text != *"never display"* ]] || exit 11 ;;
      esac
      # Rendering is a snapshot: later disk changes are not picked up by a filter.
      return 1
    }
    _directory_browser_session "~/files/" insert command
    (( $? == 1 )) || exit 12
    scenario=empty
    _directory_browser_session "~/empty/" insert command
    (( $? == 1 )) || exit 13
    scenario=mixed query=missing
    _directory_browser_session "~/mixed/" insert command
    (( $? == 1 )) || exit 14
    for i in {1..11}; do : > "$HOME/files/file-$i"; done
    : > "$HOME/files/"$'\''bad\ename\nfile'\''
    scenario=many query=""
    _directory_browser_session "~/files/" insert command
    (( $? == 1 )) || exit 15
    [[ -z $_ZLE_PICKER_INSPECT_FALLBACK && ${#_ZLE_PICKER_EMPTY_LINES} == 0 ]] || exit 16
    print context
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal context "$output"
}
test_case 'directory browser explains file-only, empty and filtered folders without selectable files' _test_browser_contents_context

_test_browser_columns() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_TRAIL=(Location "~" "  Projects" "    example")
    _ZLE_PICKER_RESULTS=(alpha beta) _ZLE_PICKER_LABELS=(alpha/ beta/)
    _ZLE_PICKER_SUBTITLE="~ › Projects › example" _ZLE_PICKER_TITLE="Directory browser"
    _ZLE_PICKER_INSPECT_TEXTS=(alpha "Inside alpha" beta "Inside beta")
    _ZLE_PICKER_SCREEN_ACTIVE=1
    for COLUMNS in 40 99 100 120 180; do
      for LINES in 10 30; do
        _zle_picker_render "" 2
        [[ $_ZLE_PICKER_SELECTED == 2 ]] || exit 1
        for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
          (( ${(m)#row} < COLUMNS )) || exit 2
        done
        (( ${#_ZLE_PICKER_DISPLAY} == LINES - 5 )) || exit 3
        if (( COLUMNS >= 120 )); then
          [[ ${(j:,:)_ZLE_PICKER_DISPLAY} == *Location* ]] || { print -u2 "missing location column"; exit 4; }
          (( ${#_ZLE_PICKER_DISPLAY_PREFIX_ENDS} == ${#_ZLE_PICKER_DISPLAY} )) || exit 5
        else
          [[ ${(j:,:)_ZLE_PICKER_DISPLAY} != *Location* ]] || exit 6
        fi
      done
    done
    COLUMNS=120 LINES=30
    _ZLE_PICKER_DIRECTORY_ACTIONS=1 _ZLE_PICKER_HIERARCHY_ENABLED=1
    _zle_picker_render "" 2
    _zle_picker_footer 119 ""
    [[ ${_ZLE_PICKER_DISPLAY[-1]} == "${(mr:119:: :)REPLY}" ]] || { print -u2 "column layout cut the footer"; exit 7; }
    _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_footer 179 ""
    [[ $REPLY == *"^B list"* && $REPLY != *"Tab list"* ]] || { print -u2 "wrong hierarchy focus key"; exit 8; }
    _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_INSPECT_EXPAND_KEY=beta
    _ZLE_PICKER_INSPECT_KEY=''
    _ZLE_PICKER_INSPECT_TEXTS[beta]=$'\''Snapshot\nOne level\n\n  one\n  two\n  three\n  final-visible-entry'\''
    _zle_picker_render "" 2
    [[ ${(j:,:)_ZLE_PICKER_DISPLAY} == *final-visible-entry* ]] || { print -u2 "explicit preview clipped early"; exit 9; }
    [[ -z ${_ZLE_PICKER_DISPLAY[-2]} ]] || { print -u2 "blank workspace rows should remain cheap blank rows"; exit 10; }
    print columns
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal columns "$output"
}
test_case 'directory browser columns collapse responsively while keeping results primary' _test_browser_columns

_test_browser_current_preview_layout() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _ZLE_PICKER_EMPTY_LINES=("No child directories" "1 file" "notes.txt")
    _ZLE_PICKER_INSPECT_FALLBACK=current
    _ZLE_PICKER_INSPECT_TEXTS=(current $'\''Contents snapshot\nOne level\n\n  · notes.txt'\'')
    for COLUMNS in 40 100 120 180; do
      LINES=30 _ZLE_PICKER_INSPECT_FOCUS=1
      _zle_picker_render "" 0
      [[ ${(j:,:)_ZLE_PICKER_DISPLAY} == *"Contents snapshot"* ]] || exit 1
      [[ ${_ZLE_PICKER_DISPLAY_LEFT_ENDS[2]} == 0 ]] || {
        print -u2 "an empty result list still reserves a main pane"; exit 2;
      }
      _ZLE_PICKER_INSPECT_FOCUS=0
      _zle_picker_render "" 0
      [[ ${(j:,:)_ZLE_PICKER_DISPLAY} == *notes.txt* && ${(j:,:)_ZLE_PICKER_DISPLAY} != *"Contents snapshot"* ]] || exit 3
    done
    print fullwidth
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal fullwidth "$output"
}
test_case 'directory browser gives an explicit current-folder preview the empty main workspace' _test_browser_current_preview_layout

_test_browser_empty_and_actions() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/empty" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    setopt AUTO_CD
    _DIRECTORY_PICKER_INPUT="~/Projects/"
    _directory_picker_prepare "$_DIRECTORY_PICKER_INPUT" ${#_DIRECTORY_PICKER_INPUT} || exit 1
    _ZLE_PICKER_BOOKMARK=("" 1 0)
    _directory_picker_transition descend "~/Projects/empty/" || { print -u2 "cannot enter empty folder"; exit 2; }
    (( !${#_DIRECTORY_PICKER_VALUES} )) || exit 3
    _ZLE_PICKER_BOOKMARK=("" 0 0)
    _directory_picker_transition parent "" || exit 4
    [[ $_DIRECTORY_PICKER_INPUT == "~/Projects/" ]] || exit 5
    _ZLE_PICKER_DIRECTORY_ACTIONS=1
    _ZLE_PICKER_HIERARCHY_ENABLED=1
    _zle_picker_footer 179 ""
    [[ $REPLY == *"^O preview"* && $REPLY == *"^X options"* && $REPLY == *"^T hidden"* ]] || exit 6
    _ZLE_PICKER_DIRECTORY_ACTIONS=2
    _ZLE_PICKER_HIERARCHY_ENABLED=0
    _zle_picker_footer 179 ""
    [[ $REPLY == *"^O browse"* ]] || exit 7
    print actions
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal actions "$output"
}
test_case 'directory browser enters empty folders and advertises explicit actions' _test_browser_empty_and_actions

_test_browser_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/alpha/empty" || return
  command mkdir -p "$TEST_TMP_DIR/home/files" || return
  test_write_file "$TEST_TMP_DIR/home/files/notes.txt" 'never read the file' || return
  test_write_file "$TEST_TMP_DIR/home/Projects/alpha/notes.txt" 'do not read' || return
  test_write_file "$TEST_TMP_DIR/home/bin/pbcopy" $'#!/bin/zsh -df\n/bin/cat > "$HOME/copied"' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/pbcopy" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$HOME/bin" "${path[@]}")
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd "$HOME/Projects"
    setopt AUTO_CD AUTO_PUSHD
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    functions[_browser_test_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _browser_test_show
      (( BUFFERLINES == LINES - 1 )) || print -r -u $efd BAD-GEOMETRY
      if [[ $scenario == fileonly ]] && (( preview_calls && _ZLE_PICKER_INSPECT_FOCUS )); then
        [[ $_ZLE_PICKER_POSTDISPLAY == *"Contents snapshot"* && $_ZLE_PICKER_POSTDISPLAY == *notes.txt* ]] || print -r -u $efd BAD-EMPTY-PREVIEW
      fi
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_INSPECT_FOCUS|$COLUMNS|$LINES"
    }
    functions[_browser_test_preview]=$functions[_directory_browser_preview]
    _directory_browser_preview() {
      (( !_ZLE_PICKER_ACTIVE )) || { print -r -u $efd BAD-PROVIDER; return 1; }
      (( ++preview_calls ))
      _browser_test_preview "$@"
      [[ $REPLY == *notes.txt* ]] || print -r -u $efd BAD-PREVIEW
      [[ $scenario == fileonly ]] && print -r -u $efd -- PREVIEW
    }
    _browser_widget() {
      BUFFER="~/Projects/" CURSOR=11
      _directory_context_complete_widget
      [[ $BUFFER == "~/Projects/" && $CURSOR == 11 && $PWD == "$HOME/Projects" &&
         $(<"$HOME/copied") == "$HOME/Projects/alpha" ]] || print -r -u $efd BAD-COPY
      (( preview_calls == 2 )) || print -r -u $efd BAD-SCANS
      print -r -u $efd DONE
      zle .accept-line
    }
    zle -N browser-test _browser_widget
    bindkey "^X^P" browser-test
    _browser_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "READY:$(command tty)"
      local -i preview_calls=0
      if [[ $scenario == widget ]]; then
        local draft=""
        vared draft
      elif [[ $scenario == fileonly ]]; then
        # Observe the real terminal-sequence reader budget without timing-dependent sleeps.
        read() {
          if [[ $# == 6 && $1 == -r && $2 == -t && $6 == sequence ]]; then
            (( $3 > 0 && $3 <= 0.03 )) || print -r -u $efd BAD-ESC-BUDGET
          fi
          builtin read "$@"
        }
        _directory_browser_session "~/files/" insert command
        [[ $? == 1 && $PWD == "$HOME/Projects" && $preview_calls == 3 ]] || print -r -u $efd BAD-EMPTY-STATE
        print -r -u $efd DONE
      else
        _directory_browser_session ./ cd command recents
        [[ $PWD == "$HOME/Projects/alpha/empty" ]] || print -r -u $efd BAD-CD
        print -r -u $efd DONE
      fi
    }
    _browser_expect() {
      local expected=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r browser chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $expected; last event $event"
      return 1
    }
    local scenario="" event="" device="" trace="" pfd=0
    for scenario in command widget fileonly; do
      zpty -b browser _browser_driver || exit 2
      pfd=$REPLY
      {
        zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 3
        device=${event#READY:}
        [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
        if [[ $scenario == command ]]; then
          _browser_expect "FRAME|Recent directories||0|120|30" || exit 5
          zpty -w -n browser $'\''\x0f'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 6
          zpty -w -n browser $'\''\e'\''
          _browser_expect "FRAME|Recent directories||0|120|30" || exit 7
          zpty -w -n browser $'\''\x0f'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 8
          zpty -w -n browser $'\''\e[C'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 9
          zpty -w -n browser $'\''\t'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 10
          zpty -w -n browser $'\''\x18'\''
          _browser_expect "FRAME|Folder actions||0|120|30" || exit 11
          zpty -w -n browser $'\''\r'\''
        elif [[ $scenario == widget ]]; then
          zpty -w -n browser $'\''\x18\x10'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 12
          zpty -w -n browser $'\''\x0f'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 13
          zpty -w -n browser $'\''\x18'\''
          _browser_expect "FRAME|Folder actions||0|120|30" || exit 14
          zpty -w -n browser $'\''\e'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 15
          command stty rows 12 cols 70 < "$device"
          _browser_expect "FRAME|Directory browser||0|70|12" || exit 16
          zpty -w -n browser $'\''\x0f'\''
          _browser_expect "FRAME|Directory browser||1|70|12" || exit 17
          zpty -w -n browser $'\''\x02\x18'\''
          _browser_expect "FRAME|Folder actions||0|70|12" || exit 18
          zpty -w -n browser Copy
          _browser_expect "FRAME|Folder actions|Copy|0|70|12" || exit 19
          zpty -w -n browser $'\''\r'\''
        else
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 22
          zpty -w -n browser $'\''\r'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 31
          zpty -w -n browser 4
          _browser_expect "FRAME|Directory browser|4|0|120|30" || exit 32
          zpty -w -n browser $'\''\x15'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 33
          zpty -w -n browser $'\''\x0f'\''
          _browser_expect PREVIEW || exit 23
          _browser_expect "FRAME|Directory browser||1|120|30" || exit 24
          zpty -w -n browser $'\''\x02'\''
          _browser_expect "FRAME|Directory browser||0|120|30" || exit 34
          zpty -w -n browser $'\''\x05'\''
          _browser_expect "FRAME|Directory browser||1|120|30" || exit 35
          zpty -w -n browser $'\''\x0f'\''
          _browser_expect PREVIEW || exit 25
          _browser_expect "FRAME|Directory browser||1|120|30" || exit 26
          zpty -w -n browser xyz
          _browser_expect "FRAME|Directory browser|xyz|0|120|30" || exit 27
          command stty rows 12 cols 70 < "$device"
          _browser_expect "FRAME|Directory browser|xyz|0|70|12" || exit 28
          zpty -w -n browser $'\''\x0f'\''
          _browser_expect PREVIEW || exit 29
          _browser_expect "FRAME|Directory browser|xyz|1|70|12" || exit 30
          zpty -w -n browser $'\''\x07'\''
        fi
        _browser_expect DONE || exit 20
        [[ $trace != *"read-only variable"* && $trace != *"bad math"* && $trace != *$'\''\e[3J'\''* ]] || exit 21
      } always {
        zpty -d browser
      }
    done
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'directory browser native actions preview resize and recent-location return preserve shell state' _test_browser_native

_test_browser_action_boundaries() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/literal ; echo nope" || return
  test_write_file "$TEST_TMP_DIR/home/bin/open" $'#!/bin/zsh -df\nprint -rl -- "$@" > "$HOME/open-args"\nexit 7' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/open" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$HOME/bin" "${path[@]}")
    source "$1/.zsh.addons/.zsh.editor"
    builtin cd "$HOME/Projects"
    local fixture_target="$HOME/Projects/literal ; echo nope" scenario=reveal
    _zle_picker_run() { "$5"; }
    # Replace only user selection; run the real browser/action boundary.
    _directory_browser_pick() {
      (( !_ZLE_PICKER_ACTIVE )) || exit 1
      _ZLE_PICKER_ACTION=$scenario
      _ZLE_PICKER_SELECTED_VALUE="$fixture_target/"
      _ZLE_PICKER_ACCEPTED=1
      return 0
    }
    _directory_browser_session ./ cd command
    local result=$?
    [[ $result == 7 && $(<"$HOME/open-args") == $'\''-R\n--\n'\''"$fixture_target" ]] || { print -u2 -- "reveal status=$result"; exit 2; }
    [[ $PWD == "$HOME/Projects" && ! -e nope ]] || { print -u2 after-reveal; exit 3; }
    scenario=select
    _directory_browser_session ./ cd command || { print -u2 cd-failed; exit 4; }
    [[ $PWD == "$fixture_target" ]] || { print -u2 cd-fixture_target; exit 5; }
    builtin cd "$HOME/Projects"
    scenario=select fixture_target="$HOME/missing"
    _directory_browser_session ./ cd command 2>/dev/null
    [[ $? != 0 && $PWD == "$HOME/Projects" ]] || { print -u2 stale-fixture_target; exit 6; }
    _directory_browser_absolute ./
    [[ $REPLY == "$HOME/Projects" ]] || { print -u2 -- "relative=$REPLY"; exit 7; }
    # Every fixture uses the literal path; no generated shell command is run.
    print boundaries
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal boundaries "$output"
}
test_case 'directory browser actions keep literal paths, failures, and directory changes explicit' _test_browser_action_boundaries
