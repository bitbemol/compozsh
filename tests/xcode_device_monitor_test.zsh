_test_xcode_device_monitor_lifecycle() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" '#!/bin/zsh -df
print -r -- "${(j:|:)@}" > "$HOME/launch"
print -r -- "device request failed"
print -u2 -r -- "literal %F{red} [*]"
exit 7' || return
  command chmod +x "$TEST_TMP_DIR/bin/xcrun" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    path=("$2/bin" $path)
    export TMPDIR=$HOME
    (( ${+functions[_xcode_run_device_live]} )) || { print -u2 "missing device monitor"; exit 1; }
    _zle_picker_run() {
      local -i attempts=0
      while (( attempts++ < 100 )); do
        _xcode_run_read_sources
        (( _xcode_device_done && _xcode_run_eof )) && break
        zselect -t 1
      done
      [[ $_xcode_run_log == *"device request failed"* && $_xcode_run_log == *"literal %F{red} [*]"* && $_xcode_device_done == 1 ]] || return 91
      [[ $_xcode_run_initial_logs == 1 && -z $_xcode_run_lldb ]] || return 92
      print restored > "$HOME/restored"
      _ZLE_PICKER_SELECTED_VALUE=stop
    }
    _xcode_run_device_live DEVICE-123 com.example.app "App · Apple TV" arm64
    local result=$?
    [[ $result == 7 && -f $HOME/restored ]] || exit 2
    [[ $(<"$HOME/launch") == "devicectl|device|process|launch|--device|DEVICE-123|--terminate-existing|--console|--arch|arm64|com.example.app" ]] || exit 3
    local -a leftovers=("$HOME"/compozsh-xcode-device.*(N))
    (( !${#leftovers} )) || exit 4
    print device-monitor
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal device-monitor "$output" 'device monitor lost native output/status or cleanup'
}
test_case 'Xcode device monitor captures native console output and preserves exit status and cleanup' _test_xcode_device_monitor_lifecycle

_test_xcode_device_monitor_stop() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" '#!/bin/zsh -df
trap '\''[[ -f $HOME/restored ]] || exit 91; print stopped > "$HOME/stopped"; exit ${STOP_STATUS:-0}'\'' TERM
[[ $STOP_MODE == ignore ]] && trap "" TERM
exec {gate}<> "$HOME/gate"
print ready
while read -r -u $gate line; do :; done' || return
  command chmod +x "$TEST_TMP_DIR/bin/xcrun" || return
  command mkdir -p "$TEST_TMP_DIR/home" || return
  command mkfifo "$TEST_TMP_DIR/home/gate" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    path=("$2/bin" $path)
    export TMPDIR=$HOME
    _zle_picker_run() {
      local -i attempts=0
      while (( attempts++ < 100 )); do
        _xcode_run_read_sources
        [[ $_xcode_run_log == *ready* ]] && break
        zselect -t 1
      done
      [[ $_xcode_run_log == *ready* && ! -f $HOME/stopped ]] || return 91
      print restored > "$HOME/restored"
      _ZLE_PICKER_SELECTED_VALUE=stop
    }
    _xcode_run_device_live DEVICE-123 com.example.app "App · Apple TV" || exit 1
    [[ $(<"$HOME/stopped") == stopped ]] || exit 2
    command rm "$HOME/restored" "$HOME/stopped"
    export STOP_STATUS=7
    _xcode_run_device_live DEVICE-123 com.example.app "App · Apple TV"
    [[ $? == 7 ]] || { print -u2 "native termination failure was hidden"; exit 4; }
    command rm "$HOME/restored" "$HOME/stopped"
    export STOP_MODE=ignore
    _xcode_run_device_live DEVICE-123 com.example.app "App · Apple TV" 2> "$HOME/stop-error"
    [[ $? == 1 && $(<"$HOME/stop-error") == *"check or stop the app on the device"* && ! -f $HOME/stopped ]] || exit 5
    local -a leftovers=("$HOME"/compozsh-xcode-device.*(N))
    (( !${#leftovers} )) || exit 3
    print stopped
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal stopped "$output" 'device Stop did not restore the screen before native console termination'
}
test_case 'Xcode device monitor stops only its console after screen restoration and removes its pipe' _test_xcode_device_monitor_stop

_test_xcode_device_monitor_suspended_stop() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" '#!/bin/zsh -df
trap '\''print stopped > "$HOME/stopped"; exit ${STOP_STATUS:-0}'\'' TERM
exec {gate}<> "$HOME/gate"
print ready
while read -r -u $gate line; do :; done' || return
  command chmod +x "$TEST_TMP_DIR/bin/xcrun" || return
  command mkdir -p "$TEST_TMP_DIR/home" || return
  command mkfifo "$TEST_TMP_DIR/home/gate" "$TEST_TMP_DIR/home/watchdog" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    path=("$2/bin" $path)
    export TMPDIR=$HOME
    zmodload zsh/zselect zsh/parameter
    unsetopt MONITOR NOTIFY BG_NICE
    exec {watchdog_gate}<> "$HOME/watchdog"
    local -i watchdog=0 logger=0 result=0
    _zle_picker_run() {
      local -i attempt=0
      for (( attempt=0; attempt<100; ++attempt )); do
        _xcode_run_read_sources
        [[ $_xcode_run_log == *ready* ]] && break
        zselect -t 1
      done
      [[ $_xcode_run_log == *ready* ]] || return 91
      logger=$_xcode_device_pid
      kill -STOP $logger
      for (( attempt=0; attempt<100; ++attempt )); do
        [[ ${(j: :)jobstates} == *"$logger=suspended"* ]] && break
        zselect -t 1
      done
      {
        if ! IFS= read -r -t 3 -u $watchdog_gate line; then
          print expired > "$HOME/expired"
          kill -KILL $logger 2>/dev/null
        fi
      } &
      watchdog=$!
      _ZLE_PICKER_SELECTED_VALUE=stop
    }
    local expected=''
    for expected in 0 7 127 145; do
    export STOP_STATUS=$expected
    {
      _xcode_run_device_live DEVICE-123 com.example.app "App · Apple TV"
      result=$?
      print -r -u $watchdog_gate -- complete
      wait $watchdog 2>/dev/null
      watchdog=0
      [[ ! -f $HOME/expired ]] || { print -u2 "suspended device cleanup waited for watchdog"; exit 1; }
      [[ -f $HOME/stopped ]] || { print -u2 "suspended device did not terminate gracefully"; exit 2; }
      if [[ $expected == 127 ]]; then
        (( result != 0 )) || { print -u2 "ambiguous stopped status became success"; exit 4; }
      else
        [[ $result == $expected ]] || { print -u2 "suspended device did not preserve status $expected (actual $result)"; exit 2; }
      fi
      command rm "$HOME/stopped"
      local -a leftovers=("$HOME"/compozsh-xcode-device.*(N))
      (( !${#leftovers} )) || exit 3
    } always {
      (( watchdog > 1 )) && { kill -KILL $watchdog 2>/dev/null; wait $watchdog 2>/dev/null; }
    }
    done
    exec {watchdog_gate}>&-
    print resumed-and-stopped
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal resumed-and-stopped "$output"
}
test_case 'Xcode device monitor resumes and gracefully stops a suspended owned console' \
  _test_xcode_device_monitor_suspended_stop

_test_xcode_device_monitor_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home" || return
  command mkfifo "$TEST_TMP_DIR/home/gate" "$TEST_TMP_DIR/home/events" || return
  test_write_file "$TEST_TMP_DIR/home/bin/xcrun" '#!/bin/zsh -df
trap '\''[[ -f $HOME/restored ]] || exit 91; print stopped > "$HOME/stopped"; exit 0'\'' TERM
exec {gate}<> "$HOME/gate"
print "network request failed"
print "network retry finished"
while read -r -u $gate line; do :; done' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/xcrun" || return
  test_write_file "$TEST_TMP_DIR/home/session.zsh" '
    path=("$HOME/bin" $path)
    export TMPDIR=$HOME
    source "$1/.zsh.addons/.zsh.editor"
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.xcode"
    exec {events}<> "$HOME/events"
    functions[_device_show]=$functions[_zle_picker_show]
    functions[_device_screen]=$functions[_zle_picker_run]
    _zle_picker_show() {
      _device_show
      local state="VIEW:$_ZLE_PICKER_TITLE:$COLUMNS:${_xcode_logs_query-}:${_ZLE_PICKER_EXCLUDE-}:${_xcode_logs_matches-}"
      if [[ $state != "$previous" ]]; then
        print -r -u $events -- "$state"
        previous=$state
      fi
    }
    zle() {
      if [[ $1 == -R && -n ${POSTDISPLAY:-} && $_ZLE_PICKER_TITLE == "Xcode / Logs" ]]; then
        local row=""
        for row in ${(f)POSTDISPLAY}; do
          (( ${(m)#row} < COLUMNS )) || print -r -u $events BAD-WIDTH
        done
      fi
      builtin zle "$@"
    }
    _zle_picker_run() {
      local result=0
      _device_screen "$@"
      result=$?
      print restored > "$HOME/restored"
      return $result
    }
    _driver() {
      local before=$(command stty -g) previous="" result=0
      _xcode_run_device_live DEVICE-123 com.example.app "Example · Apple TV" arm64
      result=$?
      [[ $(command stty -g) == "$before" ]] || { print -r -u $events "BAD-STTY:$before:$(command stty -g)"; result=99; }
      (( _ZLE_PICKER_ACTIVE == 0 && _ZLE_PICKER_SCREEN_ACTIVE == 0 )) || result=97
      [[ $(<"$HOME/stopped") == stopped ]] || result=98
      print -r -u $events -- "DONE:$result"
    }
    command stty rows 24 cols 100
    print -r -u $events -- "READY:$(command tty)"
  ' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    zmodload zsh/zpty zsh/zselect
    exec {events}<> "$HOME/events"
    local event="" trace="" chunk="" device="" pfd=0
    _until() {
      while zselect -r $events $pfd -t 300; do
        while zpty -r device chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $events event; then
          [[ $event == ${~1} ]] && return 0
          [[ $event == (BAD-*|DONE:*) ]] && break
        fi
      done
      print -u2 -r -- "expected $1 got $event; ${(V)trace[-1200,-1]}"
      return 1
    }
    zpty -b device "$2" -dfi
    pfd=$REPLY
    {
      zpty -w device "source ${(q)HOME}/session.zsh ${(q)1}"
      _until "READY:*" || exit 1
      device=${event#READY:}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 2
      zpty -w device _driver
      _until "VIEW:Xcode / Logs:100:::2" || exit 3
      zpty -w -n device nrfd
      _until "VIEW:Xcode / Logs:100:nrfd::2" || exit 4
      zpty -w -n device $'\''\x1d'\''retry
      _until "VIEW:Xcode / Logs:100:nrfd:retry:1" || exit 5
      command stty rows 12 cols 40 < "$device"
      _until "VIEW:Xcode / Logs:40:nrfd:retry:1" || exit 6
      zpty -w -n device $'\''\e'\''
      _until "VIEW:Xcode / Run:40:*" || exit 7
      zpty -w -n device $'\''\e'\''
      _until "DONE:0" || exit 8
      [[ $trace == *"network request failed"* && $trace == *"Find in logs"* && $trace == *"Exclude contains"* &&
         $trace != *"command not found"* && $trace != *"bad math"* && $trace != *"terminated"* ]] || exit 9
    } always {
      zpty -d device
      exec {events}>&-
    }
    print native-device
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN") || return
  test_assert_equal native-device "$output" 'native device monitor did not preserve search resize and terminal cleanup'
}
test_case 'Xcode device monitor native terminal supports fuzzy exclusion resize and Stop cleanup' _test_xcode_device_monitor_native
