# Keep lifecycle events off the terminal: observing cleanup must not move its
# cursor or accidentally erase the frame being tested.
_test_picker_screen_lifecycle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/tests/pty_support.zsh" || exit 12
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions[_screen_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _screen_original_show
      print -r -u $event_fd -- FRAME
    }
    read() {
      [[ $scenario == read-fail && $1 == -r && $2 == -k && $3 == 1 && $4 == key ]] && return 1
      builtin read "$@"
    }
    _screen_collect() {
      _ZLE_PICKER_RESULTS=(first second)
      _ZLE_PICKER_LABELS=(first second)
      _ZLE_PICKER_RESULT_INDEXES=(1 2)
    }
    _screen_assert_state() {
      [[ $BUFFER == draft && $CURSOR == 2 && $PREDISPLAY == prefix &&
         $POSTDISPLAY == suffix && ${(j: :)region_highlight} == "0 1 bold memo=fixture" &&
         $_ZLE_AUTOSUGGEST_SUSPENDED == 7 && $_ZLE_PICKER_ACTIVE == 0 &&
         ${#_ZLE_PICKER_RESULTS} == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]] || {
        print -r -u $event_fd -- BAD-STATE
        return 2
      }
    }
    zle() {
      builtin zle "$@"
      local -i result=$?
      # A real Ctrl-C interrupts the outer widget as well as vared. Observe
      # its always-cleanup at screen restoration, before the interrupt unwinds.
      if [[ $scenario == abort && $1 == .redisplay && $_ZLE_PICKER_ACTIVE == 0 ]]; then
        _screen_assert_state && print -r -u $event_fd -- RESTORED
      fi
      return $result
    }
    _zle_picker_widget() {
      BUFFER=draft CURSOR=2 PREDISPLAY=prefix POSTDISPLAY=suffix
      region_highlight=("0 1 bold memo=fixture")
      _ZLE_PICKER_DIGIT_SELECT=1
      _ZLE_AUTOSUGGEST_SUSPENDED=7
      _zle_picker_loop "" 10
      local -i result=$?
      _screen_assert_state || return
      if [[ $scenario == accept ]]; then
        (( result == 0 && _ZLE_PICKER_ACCEPTED )) &&
          [[ $_ZLE_PICKER_SELECTED_VALUE == second ]] || return 3
      else
        (( result == 1 && !_ZLE_PICKER_ACCEPTED )) || return 5
      fi
      print -r -u $event_fd -- RESTORED
    }
    _screen_driver() {
      command stty rows 30 cols 120
      [[ $scenario == no-screen ]] && TERM=vt100
      _ZLE_PICKER_COLLECTOR=_screen_collect
      if [[ $scenario == redirected ]]; then
        _zle_picker_run 10 > "$HOME/redirected"
      else
        _zle_picker_run 10
      fi
      print -r -u $event_fd -- DONE
    }
    _screen_event() {
      {
        test_pty_expect -p screen $event_fd "" || {
          print -u2 -r -- "$scenario: missing event after $event"
          return 1
        }
        event=$REPLY
      } always { trace+=$TEST_PTY_OUTPUT }
    }
    local scenario="" trace="" event="" before="" after="" screen=""
    for scenario in accept cancel abort read-fail no-screen redirected; do
      trace="" event=""
      test_pty_start screen _screen_driver || exit 3
      {
        _screen_event && [[ $event == FRAME ]] || exit 4
        case $scenario in
          (accept) zpty -w -n screen $'\''\e2'\'' ;;
          (abort) zpty -w -n screen $'\''\x03'\'' ;;
          (read-fail) ;;
          (*) zpty -w -n screen $'\''\x07'\'' ;;
        esac
        _screen_event && [[ $event == RESTORED ]] || {
          print -u2 -r -- "$scenario: failed to restore editor state ($event)"
          exit 5
        }
        if [[ $scenario != abort ]]; then
          _screen_event && [[ $event == DONE ]] || exit 6
        fi
        if [[ $scenario == no-screen || $scenario == redirected ]]; then
          [[ $trace != *"$enter"* && $trace != *"$leave"* &&
             $trace != *$'\''\e[2J'\''* ]] || exit 7
          if [[ $scenario == redirected ]]; then
            [[ $(<"$HOME/redirected") != *$'\''\e'\''* ]] || exit 8
          fi
        else
          [[ $trace == *"$enter"*"$leave"* ]] || exit 9
          before=${trace%%"$enter"*}
          screen=${${trace#*"$enter"}%%"$leave"*}
          (( ${#trace} - ${#${trace//"$leave"/}} == ${#leave} )) || exit 10
          after=${trace##*"$leave"}
          [[ $before != *$'\''\e[2J'\''* && $after != *$'\''\e[2J'\''* &&
             $screen == *$'\''\e[2J'\''* && $screen != *"$enter"* &&
             $after != *"$leave"* ]] || exit 10
        fi
        [[ $trace != *$'\''\e[3J'\''* && $trace != *"read-only variable"* ]] || exit 11
      } always {
        zpty -d screen
      }
    done
    exec {event_fd}>&-
    print restored
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal restored "$output"
}
test_case 'picker screen restores editor state on accept, cancel, abort, read failure, and plain fallbacks' _test_picker_screen_lifecycle

# Result limits arrive as settings text. Nineteen or more digits would print a
# truncation warning inside the editor and wrap before clamping.
_test_picker_limits_reject_overflowing_settings() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    vared() { return 1; }
    local limit=""
    for limit in 99999999999999999999 15 99; do
      _zle_picker_run "$limit"
      print -r -- "run:$?|$_ZLE_PICKER_RUN_LIMIT"
    done
    _limit_collect() { :; }
    _ZLE_PICKER_COLLECTOR=_limit_collect
    _zle_picker_screen_session() { return 1; }
    _zle_picker_loop "" 99999999999999999999
    print -r -- "loop:$?"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
run:2|10
run:2|15
run:2|20
loop:1' "status:$exit_status"$'\n'"$output" \
    'an overflowing picker limit was evaluated before validation'
}
test_case 'picker limits treat overflowing settings as their defaults' \
  _test_picker_limits_reject_overflowing_settings

# View-scoped flags and callbacks have no global value. A same-named variable
# inherited from the environment must never be evaluated as arithmetic or
# chosen as a callback; the editor's autosuggestion flag is read as text.
_test_picker_engine_drops_inherited_view_state() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    local name="" substitution='"'"'path[$(: >| $HOME/flag-marker)1]'"'"'
    local -a names=(_ZLE_PICKER_SESSION _ZLE_PICKER_SCREEN_ACTIVE _ZLE_PICKER_BUSY
      _ZLE_PICKER_EXCLUSION_ENABLED _ZLE_PICKER_QUERY_SUBMIT
      _ZLE_PICKER_QUERY_EMPTY_CANCEL _ZLE_PICKER_INSPECT_STACKED
      _ZLE_PICKER_INSPECT_CLIP_LINES _ZLE_PICKER_IDLE_PREPAINT
      _ZLE_PICKER_WORKSPACE_ACTIONS _zle_picker_start_focus
      _ZLE_PICKER_EXCLUDE_SHOWN _ZLE_PICKER_EXCLUDE_FOCUS)
    for name in "${names[@]}"; do export "$name=$substitution"; done
    export _ZLE_PICKER_IDLE_CALLBACK=_inherited_idle _ZLE_AUTOSUGGEST_SUSPENDED=$substitution
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    zmodload zsh/parameter
    local -a inherited=()
    for name in "${names[@]}" _ZLE_PICKER_IDLE_CALLBACK; do
      (( ${+parameters[$name]} )) && inherited+=("$name")
    done
    print -r -- "inherited:${(j:,:)inherited}"
    zle() { return 0; }
    _zle_picker_screen_session true
    print -r -- "session:$?|$_ZLE_AUTOSUGGEST_SUSPENDED"
    LINES=30 COLUMNS=100
    _zle_picker_body_height
    print -r -- "body:$REPLY"
    _zle_picker_can_select_digit ""; print -r -- "digit:$?"
    _zle_picker_redraw; print -r -- "redraw:$?"
    _flag_collect() { :; }
    _ZLE_PICKER_COLLECTOR=_flag_collect
    _zle_picker_screen_session() { print -r -- "screen:$1"; return 1; }
    _zle_picker_run() { print -r -- "run:$*"; return 1; }
    _zle_picker_loop "" 10; print -r -- "loop:$?"
    _file_search_actions_view "$HOME"; print -r -- "file actions:$?"
    _compozsh_view; print -r -- "tools:$?"
    local -a markers=($HOME/*-marker(N)); print -r -- "markers:${#markers}"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
inherited:
session:0|0
body:24
digit:1
redraw:0
screen:_zle_picker_loop
loop:1
run:10
file actions:1
run:10  1 0 _compozsh_browse_loop
tools:1
markers:0' "status:$exit_status"$'\n'"$output" \
    'the picker engine evaluated or kept inherited view-scoped state'
}
test_case 'picker engine drops inherited view state without evaluating it' \
  _test_picker_engine_drops_inherited_view_state
