# Keep lifecycle events off the terminal: observing cleanup must not move its
# cursor or accidentally erase the frame being tested.
_test_picker_screen_lifecycle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    zmodload zsh/zpty
    zmodload zsh/zselect
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
      local chunk=""
      while zselect -r $event_fd $pty_fd -t 500; do
        while zpty -r screen chunk; do trace+=$chunk; done
        IFS= read -r -t 0 -u $event_fd event && return 0
      done
      print -u2 -r -- "$scenario: missing event after $event"
      return 1
    }
    local scenario="" trace="" event="" pty_fd=0 before="" after="" screen=""
    for scenario in accept cancel abort read-fail no-screen redirected; do
      trace="" event=""
      zpty -b screen _screen_driver || exit 3
      pty_fd=$REPLY
      {
        _screen_event && [[ $event == FRAME ]] || exit 4
        case $scenario in
          (accept) zpty -w -n screen 2 ;;
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
          after=${trace#*"$leave"}
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
