# Keep lifecycle events off the terminal: observing cleanup must not move its
# cursor or accidentally erase the frame being tested.
_test_picker_screen_lifecycle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/tests/pty_support.zsh" || exit 12
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
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
    local scenario="" trace="" event=""
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
        # Every scenario, Ctrl-C included, returns to its caller.
        _screen_event && [[ $event == DONE ]] || exit 6
        if [[ $scenario == no-screen || $scenario == redirected ]]; then
          test_pty_screen_sessions "$trace" 0 || exit 7
          if [[ $scenario == redirected ]]; then
            [[ $(<"$HOME/redirected") != *$'\''\e'\''* ]] || exit 8
          fi
        else
          test_pty_screen_sessions "$trace" 1 || exit 9
          [[ $reply[1] == *$'\''\e[2J'\''* ]] || exit 10
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

# Ctrl-L is Redraw. Only the owned alternate screen may be cleared, and only by
# the builtin widget: a user or plugin clear-screen widget never runs inside
# the modal session, and the inline fallback repaints in place instead of
# clearing the main screen.
_test_picker_screen_ctrl_l_redraws_in_place() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/tests/pty_support.zsh" || exit 12
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local terminal=""
    local -A enters=() leaves=() clears=()
    for terminal in xterm-256color vt100; do
      TERM=$terminal
      enters[$terminal]=$terminfo[smcup] leaves[$terminal]=$terminfo[rmcup]
      clears[$terminal]=${terminfo[clear]%%\$<*}
      [[ -n $clears[$terminal] ]] || exit 13
    done
    TERM=xterm-256color
    functions[_redraw_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _redraw_original_show
      print -r -u $event_fd -- FRAME
    }
    _redraw_collect() {
      _ZLE_PICKER_RESULTS=(first second)
      _ZLE_PICKER_LABELS=(first second)
    }
    # A dotfile or plugin may replace the clear-screen widget by name.
    _user_clear() {
      print -r -u $event_fd -- USER-CLEAR
      zle .clear-screen
    }
    zle -N clear-screen _user_clear
    _redraw_driver() {
      command stty rows 30 cols 120
      TERM=$terminal
      _ZLE_PICKER_COLLECTOR=_redraw_collect
      _zle_picker_run 10
      print -r -u $event_fd -- DONE
    }
    # Read events through <wanted>, counting user clear-screen widget runs.
    _redraw_until() {
      while test_pty_expect -p redraw $event_fd ""; do
        trace+=$TEST_PTY_OUTPUT post+=$TEST_PTY_OUTPUT
        [[ $REPLY == USER-CLEAR ]] && (( ++user_clears ))
        [[ $REPLY == "$1" ]] && return 0
      done
      trace+=$TEST_PTY_OUTPUT post+=$TEST_PTY_OUTPUT
      return 1
    }
    # A frame is written before its event, so this takes the rest of it.
    _redraw_drain() {
      local chunk=""
      while zpty -r redraw chunk; do
        trace+=$chunk post+=$chunk
      done
    }
    # Read terminal output until the second row has been painted again.
    _redraw_painted() {
      [[ $post == *second* ]] && return 0
      test_pty_expect redraw "" second 2
      local -i painted=$?
      trace+=$TEST_PTY_OUTPUT post+=$TEST_PTY_OUTPUT
      return $painted
    }
    local trace="" post="" redrawn="" enter="" leave="" clear="" placement=""
    local -i user_clears=0 repainted=0
    for terminal in xterm-256color vt100; do
      trace="" post="" redrawn="" user_clears=0 repainted=0
      enter=$enters[$terminal] leave=$leaves[$terminal] clear=$clears[$terminal]
      test_pty_start redraw _redraw_driver || exit 3
      {
        _redraw_until FRAME || exit 4
        _redraw_drain
        post=""
        zpty -w -n redraw $'\''\x0c'\''
        _redraw_until FRAME || exit 5
        _redraw_painted && repainted=1
        redrawn=$post
        zpty -w -n redraw $'\''\x07'\''
        _redraw_until DONE || exit 6
        test_pty_expect redraw "" "" || exit 7
        trace+=$TEST_PTY_OUTPUT
        # Redraw may clear only inside the owned alternate screen.
        placement=none
        if [[ $redrawn == *"$clear"* ]]; then
          placement=main
          # The helper reads this shell'\''s xterm-256color capabilities, and
          # only that terminal has a screen ($enter is empty for vt100).
          if [[ -n $enter && -n $leave ]] && test_pty_screen_sessions "$trace" 1 &&
             [[ $redrawn != *"$enter"* && $redrawn != *"$leave"* ]]; then
            placement=screen
          fi
        fi
        print -r -- "$terminal|user-clears=$user_clears|repainted=$repainted|clear=$placement"
      } always {
        zpty -d redraw
      }
    done
    exec {event_fd}>&-
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
xterm-256color|user-clears=0|repainted=1|clear=screen
vt100|user-clears=0|repainted=1|clear=none' "status:$exit_status"$'\n'"$output" \
    'Ctrl-L ran a user clear-screen widget, cleared the main screen or did not repaint'
}
test_case 'picker screen Ctrl-L redraws in place without user clear-screen widgets or main-screen clears' \
  _test_picker_screen_ctrl_l_redraws_in_place

# The painted frame copies labels, inspector, query and location text. The
# screen owner must release it on every exit path, including a capture status
# that ends the session, or the last view would outlive its lifetime in shell
# parameters (and in set/typeset output) after the screen closes.
_test_picker_screen_releases_frame() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/tests/pty_support.zsh" || exit 12
    zmodload zsh/parameter
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local marker=frame-marker
    functions[_frame_original_show]=$functions[_zle_picker_show]
    # Report marker rows and whether the composed frame showed the marker.
    _zle_picker_show() {
      _frame_original_show
      print -r -u $event_fd -- "FRAME|${#${(@M)_ZLE_PICKER_DISPLAY:#*$marker*}}|${${(M)_ZLE_PICKER_POSTDISPLAY:#*$marker*}:+1}"
    }
    _frame_collect() {
      _ZLE_PICKER_RESULTS=(first second)
      _ZLE_PICKER_LABELS=("export API_TOKEN=$marker" second)
    }
    _frame_capture() {
      _zle_picker_capture Search "$HOME/$marker" "$marker" false
    }
    # Like a real view, the snapshot is scoped to the view, which has ended
    # by the time the driver inspects what the shell still holds.
    _frame_view() {
      local -A _ZLE_PICKER_INSPECT_TEXTS=(first "export API_TOKEN=$marker" second plain)
      _ZLE_PICKER_COLLECTOR=_frame_collect
      if [[ $scenario == capture-failure ]]; then
        _zle_picker_run 10 "" 1 0 _frame_capture
      else
        _zle_picker_run 10
      fi
    }
    _frame_driver() {
      command stty rows 30 cols 120
      local -i result=-1
      local name="" holders=""
      {
        _frame_view
        result=$?
      } always {
        for name in ${(ok)parameters[(I)_ZLE_PICKER_*]}; do
          [[ ${(Pkvj: :)name} == *"$marker"* ]] && holders+=" $name"
        done
        print -r -u $event_fd -- "AFTER|$scenario|$result|$_ZLE_PICKER_SELECTED_VALUE|rows=${#_ZLE_PICKER_DISPLAY}|holders=${holders# }"
      }
    }
    local scenario=""
    for scenario in accept cancel abort capture-failure; do
      test_pty_start frame _frame_driver || exit 3
      {
        test_pty_expect -p frame $event_fd FRAME || exit 4
        print -r -- "$scenario painted:${REPLY#FRAME|}"
        case $scenario in
          (accept) zpty -w -n frame $'\''\r'\'' ;;
          (cancel) zpty -w -n frame $'\''\x07'\'' ;;
          (abort) zpty -w -n frame $'\''\x03'\'' ;;
        esac
        test_pty_expect -p frame $event_fd AFTER || exit 5
        print -r -- "${REPLY#AFTER|}"
      } always {
        zpty -d frame
      }
    done
    exec {event_fd}>&-
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
accept painted:2|1
accept|0|first|rows=0|holders=
cancel painted:2|1
cancel|1||rows=0|holders=
abort painted:2|1
abort|130||rows=0|holders=
capture-failure painted:0|1
capture-failure|1||rows=0|holders=' "status:$exit_status"$'\n'"$output" \
    'the painted picker frame outlived its screen session'
}
test_case 'picker screen releases its painted frame on accept, cancel, abort and capture failure' \
  _test_picker_screen_releases_frame

# Result limits arrive as settings text. Nineteen or more digits would print a
# truncation warning inside the editor and wrap before clamping.
_test_picker_limits_reject_overflowing_settings() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    # The nested editor reads the run limit; it ends with the run.
    local limit="" seen=""
    vared() { seen=$_ZLE_PICKER_RUN_LIMIT; return 1; }
    for limit in 99999999999999999999 15 99; do
      _zle_picker_run "$limit"
      print -r -- "run:$?|$seen"
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
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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
    # Like compozsh, declare the invocation-scoped (here empty) tool catalog.
    local -a _COMPOZSH_TOOL_NAMES=()
    local -A _COMPOZSH_TOOL_HELPERS=() _COMPOZSH_TOOL_SOURCES=()
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

# Ctrl-C aborts a workspace with the conventional interrupted status, the same
# from every entry; Escape and Ctrl-G keep their cancel statuses. A real
# interactive shell runs each public command, and precmd reports its status.
_test_picker_screen_status_matrix() {
  test_make_temp_dir || return
  local shell_home=$TEST_TMP_DIR/home/shell
  command mkdir -p "$shell_home/repo" || return
  command ln -s "$TEST_REPO_ROOT/.zshrc" "$shell_home/.zshrc" || return
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 command git -C "$shell_home/repo" init -q || return
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 command git -C "$shell_home/repo" \
    -c user.name=Test -c user.email=test@example.invalid commit -q --allow-empty -m init || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/pty_support.zsh" || exit 18
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events" || exit 2
    local zsh_bin=$2 shell_home=$HOME/shell
    _status_shell() {
      command env -i PATH="$PATH" HOME="$shell_home" ZDOTDIR="$shell_home" \
        TERM=xterm-256color LC_ALL=en_US.UTF-8 TMPDIR="$TMPDIR" \
        ZSH_LOCAL_INIT=/dev/null GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 \
        STATUS_EVENTS="$HOME/events" "$zsh_bin" -di
    }
    local cmd="" key="" name="" trace="" result=""
    local -A keys=(escape $'\''\e'\'' ctrl-g $'\''\x07'\'' ctrl-c $'\''\x03'\'')
    local -A expected=(escape 0 ctrl-g 0 ctrl-c 130)
    test_pty_start status _status_shell || exit 3
    {
      zpty -w status '\'' _status_event() { print -r -- "PROMPT:$?" >> $STATUS_EVENTS; }; precmd_functions=(_status_event $precmd_functions); stty rows 30 cols 120; cd -q ~/repo'\''
      test_pty_expect -p status $efd PROMPT: 20 || exit 4
      for cmd in g compozsh "g --review" "g --worktree" external-device "g --help"; do
        for name in escape ctrl-g ctrl-c; do
          zpty -w status "$cmd"
          { test_pty_expect status "" "all keys" 20 } always { trace=$TEST_PTY_OUTPUT }
          (( $? == 0 )) || { print -r -- "$cmd $name: no workspace frame"; continue; }
          zpty -w -n status $keys[$name]
          test_pty_expect -p status $efd PROMPT: 20 || { print -r -- "$cmd $name: no prompt"; exit 5; }
          result=${REPLY#PROMPT:}
          [[ $result == $expected[$name] ]] || print -r -- "$cmd $name: status $result"
        done
      done
    } always {
      zpty -d status
    }
    exec {efd}>&-
    print matrix
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN") || return
  test_assert_equal matrix "$output"
}
test_case 'picker screen Ctrl-C returns 130 from every workspace entry' \
  _test_picker_screen_status_matrix
