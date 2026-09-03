_test_xcode_run_log_bounds() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    (( ${+functions[_xcode_run_log_append]} )) || { print -u2 "missing bounded run log"; exit 1; }
    local _xcode_run_log="" _xcode_run_trimmed=0
    _xcode_run_log_append "$(print -rl -- row-{001..300})"
    (( ${#${(f)_xcode_run_log}} <= 200 && _xcode_run_trimmed )) || exit 2
    [[ $_xcode_run_log == *row-300 && $_xcode_run_log != *row-001* ]] || exit 3
    _xcode_run_log_append "${(l:40000::x:)}"
    (( ${#_xcode_run_log} <= 32768 )) || exit 4
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'Xcode run logs retain only a bounded recent tail' _test_xcode_run_log_bounds

_test_xcode_run_log_resize_tail() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    local -i _ZLE_PICKER_INSPECT_CLIP_LINES=1
    local text="" width=0 index=0
    for (( index=1; index<=200; ++index )); do
      text+="row-$index ${(l:80::界:)}"$'\''\n'\''
    done
    _ZLE_PICKER_INSPECT_TEXTS=(run "${text%$'\''\n'\''}")
    for width in 80 12 40; do
      _zle_picker_inspect_prepare run $width
      (( ${#_ZLE_PICKER_INSPECT_LINES} == 200 )) || { print -u2 "resize lost log rows"; exit 1; }
      [[ ${_ZLE_PICKER_INSPECT_LINES[-1]} == row-200* ]] || exit 2
      for text in "${_ZLE_PICKER_INSPECT_LINES[@]}"; do
        (( ${(m)#text} <= width )) || exit 3
      done
      [[ ${(j: :)_ZLE_PICKER_INSPECT_ROLES} != *heading* ]] || exit 4
    done
    print tail
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal tail "$output"
}
test_case 'Xcode run clipped log snapshots preserve newest rows across resize' _test_xcode_run_log_resize_tail

_test_xcode_run_read_error() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_fd=-1 _xcode_run_eof=0 _xcode_run_publish=0
    local _xcode_run_log="" _xcode_run_trimmed=0 _xcode_run_context=fixture
    local _xcode_run_read_error=0 _ZLE_PICKER_SUBTITLE=""
    local _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_GUIDE_ACTIVE=0
    local -a _XCODE_PICKER_VALUES=(stop)
    local -A _ZLE_PICKER_INSPECT_TEXTS=()
    sysread() { return 2; }
    _xcode_run_idle
    [[ $_ZLE_PICKER_SUBTITLE == *"output unavailable"* &&
       $_ZLE_PICKER_INSPECT_TITLE == "App output · Unavailable" ]] || { print -u2 "read error hidden"; exit 1; }
    _xcode_run_idle
    [[ $? == 2 ]] || exit 2
    print stopped-polling
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal stopped-polling "$output"
}
test_case 'Xcode run stops polling a failed output pipe and discloses missing output' _test_xcode_run_read_error

_test_xcode_run_delayed_output() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    zmodload zsh/system
    command mkfifo "$HOME/output" || exit 1
    local _xcode_run_fd=-1 writer=-1 _xcode_run_eof=0 _xcode_run_publish=1
    local _xcode_run_log="" _xcode_run_trimmed=0 _xcode_run_context=fixture
    local _xcode_run_read_error=0 _ZLE_PICKER_SUBTITLE=""
    local _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_GUIDE_ACTIVE=0
    local -A _ZLE_PICKER_INSPECT_TEXTS=()
    sysopen -r -o nonblock -u _xcode_run_fd "$HOME/output" || exit 2
    sysopen -w -o nonblock -u writer "$HOME/output" || exit 2
    exec {writer}>&-
    _xcode_run_idle
    (( !_xcode_run_eof )) || { print -u2 "launch writer gap closed output prematurely"; exit 3; }
    sysopen -w -o nonblock -u writer "$HOME/output" || exit 4
    print -r -u $writer -- delayed-output
    _xcode_run_idle
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[run]} == *delayed-output* ]] || exit 5
    exec {writer}>&-
    _xcode_run_idle
    (( _xcode_run_eof )) || exit 6
    [[ $_ZLE_PICKER_INSPECT_TITLE == "App output · Closed" ]] || exit 7
    exec {_xcode_run_fd}<&-
    print delayed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal delayed "$output"
}
test_case 'Xcode run waits through the initial FIFO writer gap before receiving app output' _test_xcode_run_delayed_output

_test_xcode_run_pipe_mapping() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    export TMPDIR=$HOME
    local root="$HOME/simulator data" scenario="" launches=0 captures=0
    command mkdir -p "$root/tmp" "$HOME/other/tmp"
    command ln -s "$root" "$HOME/link"
    command mkdir "$HOME/linked-child"
    command ln -s "$root/tmp" "$HOME/linked-child/tmp"
    _xcode_run_logs_start() { return 1; }
    _xcode_capture_command() {
      if [[ $2 == simctl && $3 == getenv ]]; then
        [[ $4 == SIM-456 && $5 == SIMULATOR_SHARED_RESOURCES_DIRECTORY ]] || return 90
        (( ++captures ))
        _XCODE_CAPTURE=$scenario
        return 0
      fi
      (( ++launches ))
      [[ $3 == launch && $4 == --stdout=/tmp/compozsh-xcode-run.*/output &&
         $5 == --stderr=${4#--stdout=} ]] || { print -u2 "launch did not receive guest FIFO paths"; return 91; }
      local guest=${4#--stdout=}
      [[ -p $root$guest && -d ${root}${guest:h} ]] || return 92
      _XCODE_CAPTURE="com.example.app: 12345"
      return 0
    }
    _xcode_run_identity() { return 1; }
    _zle_picker_run() { _ZLE_PICKER_SELECTED_VALUE=stop; return 0; }
    for scenario in relative "$HOME/missing" "$HOME/link" "$HOME/link/" "$HOME/link/." "$HOME/linked-child" "$root"$'\''\nextra'\'' "$root"$'\''\t'\''; do
      _xcode_run_live SIM-456 com.example.app fixture
      [[ $? != 0 && $launches == 0 ]] || { print -u2 "invalid Simulator root reached launch"; exit 1; }
    done
    scenario=$root
    _xcode_run_live SIM-456 com.example.app fixture
    [[ $? == 1 && $launches == 1 && $captures == 9 ]] || exit 2
    local -a remnants=("$root/tmp"/compozsh-xcode-run.*(N))
    (( !${#remnants} )) || exit 3
    [[ -d $root/tmp && -d $HOME/other/tmp ]] || exit 4
    print mapped
  ' "$TEST_REPO_ROOT" 2>"$TEST_TMP_DIR/errors") || return
  test_assert_equal mapped "$output"
}
test_case 'Xcode run maps a validated exact Simulator root to private host and guest FIFO paths' _test_xcode_run_pipe_mapping

_test_xcode_run_idle_freezes_reading() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    zmodload zsh/system
    command mkfifo "$HOME/output" || exit 1
    exec {fd}<> "$HOME/output"
    local _xcode_run_fd=$fd _xcode_run_eof=0 _xcode_run_publish=1
    local _xcode_run_log="" _xcode_run_trimmed=0 _xcode_run_context=fixture
    local -a _XCODE_PICKER_VALUES=(stop read)
    local -A _ZLE_PICKER_INSPECT_TEXTS=()
    _ZLE_PICKER_INSPECT_WIDTH=50
    print -r -u $fd -- first
    _xcode_run_idle || exit 2
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[run]} == *first* ]] || exit 3
    _ZLE_PICKER_INSPECT_FOCUS=1
    local before=${_ZLE_PICKER_INSPECT_TEXTS[run]}
    print -r -u $fd -- latest
    _xcode_run_idle || exit 4
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[run]} == "$before" && $_xcode_run_log == *latest* ]] || exit 5
    print -r -u $fd -- newer
    _xcode_run_idle
    [[ $? == 1 && $_xcode_run_log == *newer* && ${_ZLE_PICKER_INSPECT_TEXTS[run]} == "$before" ]] || {
      print -u2 "paused output requested an unchanged repaint"; exit 7
    }
    _ZLE_PICKER_INSPECT_FOCUS=0
    _xcode_run_idle
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[run]} == *latest* ]] || { print -u2 "leaving reading kept stale logs"; exit 6; }
    exec {fd}>&-
    print frozen
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal frozen "$output"
}
test_case 'Xcode run pauses the displayed logs while reading and resumes the latest tail' _test_xcode_run_idle_freezes_reading

_test_xcode_run_action_continuity() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_lldb=/fixture/lldb _xcode_run_identity=fixture
    local _xcode_run_log=$(print -rl -- row-{001..100})
    local _xcode_run_eof=1 _xcode_run_trimmed=0 _xcode_run_context=fixture
    local _xcode_run_publish=1 _xcode_run_read_error=0 calls=0 reader_calls=0
    _zle_picker_loop() {
      (( ++calls ))
      (( _ZLE_PICKER_DIGIT_SELECT )) || { print -u2 "Read output disabled digits"; return 9; }
      [[ $_XCODE_PICKER_VALUES[2] == read && $_XCODE_PICKER_LABELS[2] == "Read output · Full view, filter and copy" ]] || {
        print -u2 "second action still offers redundant following"; return 8
      }
      if (( calls == 2 )); then
        (( _zle_picker_start_focus == 0 && $3 == 2 )) || { print -u2 "Read output did not return to actions"; return 8; }
      elif (( calls == 3 )); then
        [[ $1 == output && $3 == 1 ]] && (( _zle_picker_start_focus == 0 )) || {
          print -u2 "Read output lost filtered selection"; return 13
        }
      fi
      _xcode_picker_collect "$1" 10
      COLUMNS=120 LINES=30
      _ZLE_PICKER_INSPECT_FOCUS=${_zle_picker_start_focus:-0}
      _zle_picker_render "" ${3:-1}
      _xcode_run_idle
      _zle_picker_render "" ${3:-1}
      local offset=$_ZLE_PICKER_INSPECT_OFFSET
      (( offset > 0 )) || return 10
      _zle_picker_render "" 2
      [[ $_ZLE_PICKER_INSPECT_OFFSET == $offset ]] || { print -u2 "action change lost tail"; return 11; }
      if (( calls == 1 )); then
        _ZLE_PICKER_SELECTED_VALUE=read
        _ZLE_PICKER_BOOKMARK=("" 2 0)
        _ZLE_PICKER_DIGIT_SELECT=0
      elif (( calls == 2 )); then
        _ZLE_PICKER_SELECTED_VALUE=read
        _ZLE_PICKER_BOOKMARK=(output 1 0)
      else
        _ZLE_PICKER_SELECTED_VALUE=stop
      fi
      return 0
    }
    _xcode_logs_reader() { (( ++reader_calls )); return 1; }
    _xcode_run_controller || exit $?
    (( calls == 3 && reader_calls == 2 )) || exit 12
    print continuous
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal continuous "$output"
}
test_case 'Xcode run Read output opens the reader and preserves digits and log continuity' _test_xcode_run_action_continuity

_test_xcode_run_quiet_feedback() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_lldb=/fixture/lldb _xcode_run_identity=fixture
    local _xcode_run_log="" _xcode_run_eof=0 _xcode_run_trimmed=0 _xcode_run_context=fixture
    local _xcode_run_publish=1 _xcode_run_read_error=0 _xcode_run_fd=-1
    local _xcode_run_unified_status=following _xcode_run_unified_fd=-1
    sysread() { return 4; }
    _zle_picker_loop() {
      _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_GUIDE_ACTIVE=0
      _xcode_run_idle
      [[ $_ZLE_PICKER_INSPECT_TITLE == "App output · Following" &&
         ${_ZLE_PICKER_INSPECT_TEXTS[run]} == *"Waiting for app output."* &&
         ${_ZLE_PICKER_INSPECT_TEXTS[run]} == *"Logger/os_log"* ]] || { print -u2 "quiet output state is unexplained"; return 8; }
      _xcode_picker_collect "" 10
      COLUMNS=120 LINES=30
      _zle_picker_render "" 1
      [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"Waiting for app output."* &&
         ${(j: :)_ZLE_PICKER_DISPLAY} == *"stdout/stderr + Logger/os_log"* ]] || return 13
      _xcode_run_idle
      [[ $? == 1 ]] || return 9
      _ZLE_PICKER_INSPECT_FOCUS=1
      _xcode_run_idle
      [[ $_ZLE_PICKER_INSPECT_TITLE == "App output · Paused" ]] || return 10
      _xcode_run_log=received
      _xcode_run_idle
      [[ $? == 1 && ${_ZLE_PICKER_INSPECT_TEXTS[run]} != received ]] || return 11
      _ZLE_PICKER_INSPECT_FOCUS=0
      _xcode_run_idle
      [[ $_ZLE_PICKER_INSPECT_TITLE == "App output · Following" &&
         ${_ZLE_PICKER_INSPECT_TEXTS[run]} == received ]] || return 12
      _ZLE_PICKER_SELECTED_VALUE=stop
      return 0
    }
    _xcode_run_controller || exit $?
    print feedback
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal feedback "$output"
}
test_case 'Xcode run explains quiet output and shows following or paused without redundant repaint' \
  _test_xcode_run_quiet_feedback

_test_xcode_run_narrow_layout() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_lldb=/fixture/lldb _xcode_run_identity=fixture
    local _xcode_run_log=$(print -rl -- row-{001..100})
    local _xcode_run_eof=1 _xcode_run_trimmed=0 _xcode_run_context=fixture
    local _xcode_run_publish=1 _xcode_run_read_error=0
    _zle_picker_loop() {
      local columns=0 lines=0 query="" index=0
      _ZLE_PICKER_SCREEN_ACTIVE=1
      for columns in 80 70 40; do
        for lines in 24 18 12 11 10 9; do
          for query in "" no-match; do
            COLUMNS=$columns LINES=$lines
            _xcode_picker_collect "$query" 10
            _zle_picker_render "$query" 1
            _xcode_run_idle
            _zle_picker_render "$query" 1
            [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *row-100* ]] || {
              print -u2 "latest output hidden at $columns x $lines ($query)"; return 9
            }
            _zle_picker_body_height
            (( ${#_ZLE_PICKER_DISPLAY} <= REPLY + 2 )) || { print -u2 "stacked body overflow"; return 10; }
            for (( index=1; index<=${#_ZLE_PICKER_DISPLAY}; ++index )); do
              if [[ ${_ZLE_PICKER_DISPLAY[index]} == *row-100* ]]; then
                (( !_ZLE_PICKER_DISPLAY_INDEX_ENDS[index] )) || return 11
                [[ ${_ZLE_PICKER_DISPLAY_STYLES[index]} == picker-text ]] || return 12
              fi
            done
          done
        done
      done
      _ZLE_PICKER_SELECTED_VALUE=stop
      return 0
    }
    _xcode_run_controller || exit $?
    print visible
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal visible "$output"
}
test_case 'Xcode run follows visible logs in narrow windows even with no matching actions' _test_xcode_run_narrow_layout

_test_xcode_run_identity_failure() {
  test_make_temp_dir || return
  local output
  command mkdir -p "$TEST_TMP_DIR/home/simulator data/tmp" || return
  test_write_file "$TEST_TMP_DIR/home/bin/xcrun" '#!/bin/zsh -df
if [[ $2 == getenv ]]; then print -r -- "$HOME/simulator data"; exit; fi
if [[ $2 == launch ]]; then
  print -r -- "com.example.app: 12345"
elif [[ $2 == terminate ]]; then
  print terminated >> "$HOME/effects"
else
  exit 1
fi' || return
  test_write_file "$TEST_TMP_DIR/home/bin/ps" '#!/bin/zsh -df
[[ -f $HOME/identity ]] || exit 1
print -r -- "501 Wed Sep 2 12:00:00 2026 /sim/Example.app/Example"' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/"* || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$HOME/bin" $path); rehash
    export TMPDIR=$HOME
    source "$1/.zsh.addons/.zsh.xcode"
    _zle_picker_run() {
      _ZLE_PICKER_SELECTED_VALUE=stop
      command rm -f -- "$HOME/identity"
      return 0
    }
    _xcode_run_live SIM-456 com.example.app fixture
    [[ $? == 1 && ! -e $HOME/effects ]] || { print -u2 "initial identity failure silently succeeded"; exit 2; }
    print identity > "$HOME/identity"
    _xcode_run_live SIM-456 com.example.app fixture
    [[ $? == 1 && ! -e $HOME/effects ]] || { print -u2 "cleanup identity failure silently succeeded"; exit 3; }
    local -a remnants=("$HOME/simulator data/tmp"/compozsh-xcode-run.*(N))
    (( !${#remnants} )) || exit 4
    print uncertain
  ' "$TEST_REPO_ROOT" 2>"$TEST_TMP_DIR/errors") || return
  test_assert_equal uncertain "$output" || return
  test_assert_contains "$(<"$TEST_TMP_DIR/errors")" 'could not verify the launched process; check or stop the app in Simulator'
}
test_case 'Xcode run discloses unavailable identity without terminating an unverified process' _test_xcode_run_identity_failure

_test_xcode_run_failure_cleanup() {
  test_make_temp_dir || return
  local output
  command mkdir -p "$TEST_TMP_DIR/home/simulator data/tmp" || return
  test_write_file "$TEST_TMP_DIR/home/bin/xcrun" '#!/bin/zsh -df
if [[ $2 == getenv ]]; then print -r -- "$HOME/simulator data"; exit; fi
if [[ $2 == launch ]]; then
  case $SCENARIO in
    failed) print -u2 launch-failed; exit 65 ;;
    malformed) print -r -- "com.example.app: 1; unwanted" ;;
    stop-failed) print -r -- "com.example.app: 12345" ;;
  esac
elif [[ $2 == terminate ]]; then
  print -r -- stop-attempt >> "$HOME/effects"
  exit 7
else
  exit 1
fi' || return
  test_write_file "$TEST_TMP_DIR/home/bin/ps" '#!/bin/zsh -df
print -r -- "501 Wed Sep 2 12:00:00 2026 /sim/Example.app/Example"' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/"* || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$HOME/bin" $path); rehash
    export TMPDIR=$HOME SCENARIO=failed
    source "$1/.zsh.addons/.zsh.xcode"
    _zle_picker_run() { print screen >> "$HOME/effects"; _ZLE_PICKER_SELECTED_VALUE=stop; }
    _xcode_run_live SIM-456 com.example.app fixture
    [[ $? == 65 && ! -f $HOME/effects ]] || exit 1
    SCENARIO=malformed
    _xcode_run_live SIM-456 com.example.app fixture
    [[ $? == 1 && ! -f $HOME/effects ]] || exit 2
    SCENARIO=stop-failed
    _xcode_run_live SIM-456 com.example.app fixture
    [[ $? == 1 && $(<"$HOME/effects") == $'\''screen\nstop-attempt'\'' ]] || exit 3
    local -a remnants=("$HOME/simulator data/tmp"/compozsh-xcode-run.*(N))
    (( !${#remnants} )) || exit 4
    print failures
  ' "$TEST_REPO_ROOT" 2>"$TEST_TMP_DIR/errors") || return
  test_assert_equal failures "$output" || return
  local errors=$(<"$TEST_TMP_DIR/errors")
  test_assert_contains "$errors" launch-failed || return
  test_assert_contains "$errors" 'no exact PID' || return
  test_assert_contains "$errors" 'could not stop the app'
}
test_case 'Xcode run refuses malformed PIDs preserves failures and removes temporary pipes' _test_xcode_run_failure_cleanup

_test_xcode_run_lifecycle() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output
  command mkdir -p "$TEST_TMP_DIR/home/simulator data/tmp" || return
  test_write_file "$fake_bin/xcrun" '#!/bin/zsh -df
print -r -- "${(j:|:)@}" >> "$HOME/calls"
if [[ $2 == getenv ]]; then print -r -- "$HOME/simulator data"; exit; fi
if [[ $1 == --find ]]; then print -r -- "$HOME/bin/lldb"; exit; fi
if [[ $2 == launch ]]; then
  [[ $SIMCTL_CHILD_NSUnbufferedIO == YES && ${(j:|:)@} == *"|--terminate-running-process|"* ]] || exit 95
  for argument in "$@"; do
    [[ $argument == --stdout=* ]] && pipe=${argument#--stdout=}
  done
  pipe="$HOME/simulator data$pipe"
  [[ -p $pipe ]] || exit 9
  print -r -- "hello from app" > "$pipe"
  print -r -- "com.example.app: 12345"
fi' || return
  test_write_file "$fake_bin/ps" '#!/bin/zsh -df
[[ ! -e $HOME/replaced ]] && print -r -- "501 Wed Sep 2 12:00:00 2026 /sim/Example.app/Example"' || return
  test_write_file "$TEST_TMP_DIR/home/bin/lldb" '#!/bin/zsh -df
print -r -- "lldb|${(j:|:)@}" >> "$HOME/calls"
exit 23' || return
  command chmod +x "$fake_bin/"* "$TEST_TMP_DIR/home/bin/lldb" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2" $path); rehash
    export TMPDIR=$HOME
    source "$1/.zsh.addons/.zsh.xcode"
    (( ${+functions[_xcode_run_live]} )) || { print -u2 "missing run view"; exit 1; }
    _zle_picker_run() {
      [[ -p $_xcode_run_fifo && $_xcode_run_pid == 12345 ]] || return 8
      _ZLE_PICKER_SELECTED_VALUE=$choice
      [[ $choice == replaced ]] && { print replaced > "$HOME/replaced"; _ZLE_PICKER_SELECTED_VALUE=lldb; }
      return 0
    }
    choice=stop
    _xcode_run_live SIM-456 com.example.app "App · Simulator" || exit 2
    choice=lldb
    _xcode_run_live SIM-456 com.example.app "App · Simulator"
    [[ $? == 23 ]] || exit 3
    choice=replaced
    _xcode_run_live SIM-456 com.example.app "App · Simulator"
    [[ $? != 0 ]] || exit 4
    [[ -z $(print -rl -- "$HOME/simulator data/tmp"/compozsh-xcode-run.*(N)) ]] || exit 5
    print lifecycle
  ' "$TEST_REPO_ROOT" "$fake_bin" 2>"$TEST_TMP_DIR/errors") || return
  test_assert_contains "$output" lifecycle || return
  local calls=$(<"$TEST_TMP_DIR/home/calls")
  test_assert_contains "$calls" 'simctl|terminate|SIM-456|com.example.app' || return
  test_assert_contains "$calls" 'lldb|--no-lldbinit|--source-quietly|--one-line-before-file|settings set target.load-script-from-symbol-file false|--no-use-colors|--attach-pid|12345' || return
  local -a lldb_calls=("${(@M)${(f)calls}:#lldb|*}")
  (( ${#lldb_calls} == 1 )) || test_fail 'LLDB attached after process identity changed'
}
test_case 'Xcode run stops exact target and hands off LLDB after screen cleanup' _test_xcode_run_lifecycle

_test_xcode_lldb_terminal_presentation() {
  test_make_temp_dir || return
  local output=''
  test_write_file "$TEST_TMP_DIR/home/lldb spy" '#!/bin/zsh -df
for argument in "$@"; do print -r -- "${(V)argument}"; done
exit 23' || return
  command chmod +x "$TEST_TMP_DIR/home/lldb spy" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    typeset -gA ZSH_OUTPUT_COLORS=(heading 123 warning 124 muted 125)
    source "$1/.zsh.addons/.zsh.output"
    source "$1/.zsh.addons/.zsh.output"
    (( ${+functions[_xcode_run_debugger]} )) || { print -u2 missing-debugger-presentation; exit 1; }
    zmodload zsh/zpty || exit 2
    _debugger_test_driver() {
      _xcode_run_debugger "$HOME/lldb spy" 12345
      print -r -- "status:$?"
      print -r -- END-DEBUGGER-COLOR
    }
    _debugger_test_capture() {
      local line="" capture=""
      zpty debugger-color _debugger_test_driver || return
      {
        while zpty -r debugger-color line; do
          capture+=$line
          [[ $line == *END-DEBUGGER-COLOR* ]] && break
        done
        [[ $capture == *END-DEBUGGER-COLOR* ]] || return 1
        REPLY=$capture
      } always {
        zpty -d debugger-color
      }
    }
    plain=$(_debugger_test_driver)
    [[ $plain == *--no-use-colors* && $plain != *prompt-ansi* ]] || exit 3
    for terminal in xterm-256color screen-256color; do
      TERM=$terminal
      _debugger_test_capture || exit 4
      [[ $REPLY == *--no-lldbinit* && $REPLY == *--source-quietly* &&
         $REPLY == *"settings set target.load-script-from-symbol-file false"* &&
         $REPLY == *--attach-pid*12345*status:23* ]] || exit 5
      [[ $REPLY == *"settings set --exists use-color true"* &&
         $REPLY == *"settings set --exists highlight-source true"* &&
         $REPLY == *"prompt-ansi-prefix"*"^[[1;38;5;123m"* &&
         $REPLY == *"stop-show-line-ansi-prefix"*"^[[1;38;5;124m"* &&
         $REPLY == *"show-autosuggestion-ansi-prefix"*"^[[38;5;125m"* &&
         $REPLY != *--no-use-colors* ]] || { print -u2 -- "$REPLY"; exit 6; }
      [[ $REPLY == *"prompt-ansi-suffix"*"^[[0m"* &&
         $REPLY == *"stop-show-line-ansi-suffix"*"^[[0m"* ]] || exit 7
    done
    TERM=ansi
    _debugger_test_capture || exit 8
    [[ $REPLY == *"use-color true"* && $REPLY != *prompt-ansi* ]] || exit 9
    for terminal in dumb "" compozsh-unknown-terminal; do
      TERM=$terminal
      _debugger_test_capture || exit 10
      [[ $REPLY == *--no-use-colors* && $REPLY != *prompt-ansi* ]] || exit 11
    done
    TERM=xterm-256color NO_COLOR=1
    _debugger_test_capture || exit 12
    [[ $REPLY == *--no-use-colors* && $REPLY != *prompt-ansi* ]] || exit 13
    unset NO_COLOR
    ZSH_OUTPUT_COLORS[heading]="123; script invalid-command"
    _debugger_test_capture || exit 14
    [[ $REPLY == *"^[[1;38;5;75m"* && $REPLY != *invalid-command* ]] || exit 15
    unfunction _output_lldb_color_arguments
    _debugger_test_capture || exit 16
    [[ $REPLY == *"use-color true"* && $REPLY != *prompt-ansi* &&
       $REPLY == *status:23* ]] || exit 17
    print presentation
  ' "$TEST_REPO_ROOT" 2>"$TEST_TMP_DIR/errors") || {
    print -u2 -r -- "$(<"$TEST_TMP_DIR/errors")"
    return 1
  }
  test_assert_equal presentation "$output"
}
test_case 'Xcode LLDB presentation honors terminal palette plain fallbacks and debugger status' \
  _test_xcode_lldb_terminal_presentation

# Real nested ZLE, with output injected independently of terminal input. Frame
# observations travel through a separate pipe and cannot mask screen damage.
_test_xcode_run_native_screen() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output
  command mkdir -p "$home/simulator data/tmp" || return
  test_write_file "$home/bin/xcrun" '#!/bin/zsh -df
if [[ $2 == getenv ]]; then print -r -- "$HOME/simulator data"; exit; fi
if [[ $1 == --find ]]; then
  [[ -f $HOME/enable-lldb ]] || exit 1
  print -r -- "$HOME/bin/lldb"
  exit
fi
if [[ $2 == launch ]]; then
  for argument in "$@"; do
    [[ $argument == --stdout=* ]] && pipe=${argument#--stdout=}
  done
  print -r -- "first app line" > "$HOME/simulator data$pipe"
  print -r -- "com.example.app: 12345"
elif [[ $2 == terminate ]]; then
  [[ -f $HOME/screen-closed ]] || exit 91
  print -r -- "${(j:|:)@}" > "$HOME/stopped"
fi' || return
  test_write_file "$home/bin/lldb" '#!/bin/zsh -df
[[ -f $HOME/screen-closed ]] || exit 92
print -r -- "${(j:|:)@}" > "$HOME/debugged"
exit 23' || return
  test_write_file "$home/bin/ps" '#!/bin/zsh -df
print -r -- "501 Wed Sep 2 12:00:00 2026 /sim/Example.app/Example"' || return
  test_write_file "$home/bin/pbcopy" '#!/bin/zsh -df
[[ -f $HOME/screen-closed && ! -f $HOME/stopped ]] || exit 93
command cat > "$HOME/copied"' || return
  command chmod +x "$home/bin/"* || return
  test_write_file "$home/session.zsh" '
    path=("$HOME/bin" $path); rehash
    export TMPDIR=$HOME
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    PROMPT="fixture> " RPROMPT="clock"
    exec {events}<> "$HOME/events"
    functions[_run_original]=$functions[_zle_picker_run]
    functions[_run_show]=$functions[_zle_picker_show]
    functions[_run_read_sources]=$functions[_xcode_run_read_sources]
    _xcode_run_read_sources() {
      _run_read_sources
      local changed=$REPLY marker=""
      for marker in "during guide line" "while paused line" "missing now matches"; do
        if [[ $_xcode_run_log == *"$marker"* && $reported != *"$marker"* ]]; then
          print -r -u $events -- "CAPTURED:$marker:${_xcode_logs_matches-}:${_ZLE_PICKER_DOCUMENT_FOLLOW:--1}"
          reported+=$marker
        fi
      done
      REPLY=$changed
    }
    _zle_picker_run() {
      local writer=-1 result=0
      command rm -f -- "$HOME/screen-closed"
      exec {writer}> "$_xcode_run_fifo"
      print -r -u $events -- "PIPE:$_xcode_run_fifo"
      {
        _run_original "$@"
        result=$?
      } always {
        print closed >| "$HOME/screen-closed"
        exec {writer}>&-
      }
      return $result
    }
    _zle_picker_show() {
      _run_show
      local latest=0 shown=0
      [[ ${_ZLE_PICKER_INSPECT_TEXTS[run]} == *latest* ]] && latest=1
      [[ $_ZLE_PICKER_POSTDISPLAY == *"latest app line"* ]] && shown=1
      local event="FRAME:$COLUMNS:$LINES:$_ZLE_PICKER_INSPECT_FOCUS:$_ZLE_PICKER_GUIDE_ACTIVE:$latest:$shown"
      if [[ $event != "$previous" ]]; then
        print -r -u $events -- "$event"
        previous=$event
      fi
      local view="VIEW:$_ZLE_PICKER_TITLE:${_xcode_logs_query-}:${_xcode_logs_matches-}:$_ZLE_PICKER_INSPECT_WIDTH:${_ZLE_PICKER_DOCUMENT_FOLLOW:--1}"
      if [[ $view != "$previous_view" ]]; then
        print -r -u $events -- "$view"
        previous_view=$view
      fi
    }
    _run_entry() {
      local before=$(command stty -g) previous="" previous_view="" reported="" result=0
      local REPLY=caller-scratch
      command rm -f -- "$HOME/screen-closed"
      {
        _xcode_run_live SIM-456 com.example.app "App · Simulator"
        result=$?
      } always {
        [[ $REPLY == caller-scratch ]] || result=96
        [[ ${_ZLE_PICKER_BOOKMARK[1]-} != private-log-filter ]] || result=95
        [[ $PROMPT == "fixture> " && $RPROMPT == clock &&
           $(command stty -g) == "$before" && $_ZLE_PICKER_ACTIVE == 0 ]] || result=99
        local -a remnants=("$HOME/simulator data/tmp"/compozsh-xcode-run.*(N))
        (( !${#remnants} )) || result=98
        [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"app line"* ]] || result=97
        if [[ ${1:-} == abort ]]; then
          print -r -u $events -- "ABORT:$result"
        else
          print -r -u $events -- "DONE:$result"
        fi
      }
    }
    command stty rows 30 cols 120
    print -r -u $events -- "READY:$(command tty)"
  ' || return
  output=$(test_run_interactive "$home" '
    export LC_ALL=en_US.UTF-8
    zmodload zsh/zpty zsh/zselect
    command mkfifo "$HOME/events"
    exec {events}<> "$HOME/events"
    local trace="" event="" device="" pipe="" chunk="" pfd=0
    _event() {
      while zselect -r $events $pfd -t 300; do
        while zpty -r run chunk; do trace+=$chunk; done
        IFS= read -r -t 0 -u $events event && return 0
      done
      print -u2 -- "run event timed out: $event"
      return 1
    }
    _frame() {
      while _event; do
        [[ $event == ${~1} ]] && return 0
        [[ $event == DONE:* ]] && break
      done
      print -u2 -- "expected $1, got $event"
      return 1
    }
    zpty -b run "$2" -dfi
    pfd=$REPLY
    {
      zpty -w run "source ${(q)HOME}/session.zsh ${(q)1}"
      _event && [[ $event == READY:* ]] || exit 1
      device=${event#READY:}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 2
      zpty -w run _run_entry
      _event && [[ $event == PIPE:* ]] || exit 3
      pipe=${event#PIPE:}
      [[ -p $pipe && $pipe == "${HOME:A}/simulator data/tmp"/compozsh-xcode-run.*/output ]] || exit 4
      _frame FRAME:120:30:0:0:0:0 || exit 5
      zpty -w -n run 2
      _frame "VIEW:Xcode / Logs::1:119:1" || exit 6
      print -r -- "latest app line" > "$pipe"
      _frame "VIEW:Xcode / Logs::2:119:1" || exit 24
      command stty rows 18 cols 70 < "$device"
      _frame FRAME:70:18:1:0:0:1 || exit 7
      zpty -w -n run $'\''\x0b'\''
      _frame FRAME:70:18:1:1:0:0 || exit 8
      print -r -- "during guide line" > "$pipe"
      _frame "CAPTURED:during guide line:2:1" || exit 38
      zpty -w -n run $'\''\e'\''
      _frame "VIEW:Xcode / Logs::3:69:1" || exit 9
      zpty -w -n run $'\''\e[A'\''
      _frame "VIEW:Xcode / Logs::3:69:0" || exit 39
      print -r -- "while paused line" > "$pipe"
      _frame "CAPTURED:while paused line:3:0" || exit 40
      zpty -w -n run $'\''\e[F'\''
      _frame "VIEW:Xcode / Logs::4:69:1" || exit 41
      zpty -w -n run $'\''\e'\''
      _frame FRAME:70:18:0:0:1:1 || exit 10
      # Filtering stays live after zero matches. Options freeze only displayed
      # copy scope while the same owner keeps draining the app pipe.
      zpty -w -n run 2
      _frame "VIEW:Xcode / Logs::4:69:1" || exit 42
      zpty -w -n run missing
      _frame "VIEW:Xcode / Logs:missing:0:69:1" || exit 25
      zpty -w -n run $'\''\r'\''
      _frame "VIEW:Xcode / Logs / Options:missing:0:*:-1" || exit 26
      print -r -- "missing now matches" > "$pipe"
      _frame "CAPTURED:missing now matches:0:-1" || exit 43
      zpty -w -n run $'\''\e'\''
      _frame "VIEW:Xcode / Logs:missing:1:69:1" || exit 27
      zpty -w -n run $'\''\r'\''
      _frame "VIEW:Xcode / Logs / Options:missing:1:*:-1" || exit 29
      zpty -w -n run 1
      _frame "VIEW:Xcode / Run:missing::*" || exit 30
      [[ $(<"$HOME/copied") == "missing now matches" && ! -e $HOME/stopped ]] || exit 31
      # Copy closes only the screen, then Run reopens with the same app owner.
      # Reader reentry retains the filter; clearing it copies all captured lines.
      zpty -w -n run 2
      _frame "VIEW:Xcode / Logs:missing:1:69:1" || exit 32
      zpty -w -n run $'\''\x15'\''
      _frame "VIEW:Xcode / Logs::5:69:1" || exit 33
      zpty -w -n run $'\''\x19'\''
      _frame "VIEW:Xcode / Run:::*" || exit 34
      [[ $(<"$HOME/copied") == $'\''first app line\nlatest app line\nduring guide line\nwhile paused line\nmissing now matches'\'' && ! -e $HOME/stopped ]] || exit 35
      zpty -w -n run $'\''\t'\''
      _frame FRAME:70:18:1:0:1:1 || exit 11
      zpty -w -n run $'\''\e'\''
      _frame DONE:0 || exit 12
      [[ $(<"$HOME/stopped") == "simctl|terminate|SIM-456|com.example.app" ]] || exit 13
      [[ ! -e $pipe && ! -d ${pipe:h} ]] || exit 14
      print enabled > "$HOME/enable-lldb"
      zpty -w run _run_entry
      _frame FRAME:70:18:0:0:0:0 || exit 16
      zpty -w -n run 2
      _frame FRAME:70:18:1:0:0:0 || exit 21
      zpty -w -n run $'\''\e'\''
      _frame FRAME:70:18:0:0:0:0 || exit 22
      zpty -w -n run 3
      _frame DONE:23 || exit 17
      [[ $(<"$HOME/debugged") == *"--attach-pid|12345" ]] || exit 18
      zpty -w run "_run_entry abort"
      _frame FRAME:70:18:0:0:0:0 || exit 19
      zpty -w -n run 2
      _frame "VIEW:Xcode / Logs::1:69:1" || exit 36
      zpty -w -n run private-log-filter
      _frame "VIEW:Xcode / Logs:private-log-filter:0:69:1" || exit 37
      zpty -w -n run $'\''\x03'\''
      _frame ABORT:0 || exit 20
      [[ $trace != *"bad math"* && $trace != *"read-only variable"* &&
         $trace != *"command not found"* && $trace != *"_xcode_run_drain"* ]] || {
        print -u2 -r -- "unexpected runtime diagnostic or helper job notice"
        exit 15
      }
    } always {
      zpty -d run
      exec {events}>&-
    }
    print native-run
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN") || {
    test_fail "native run fixture exited with status $?"
    return 1
  }
  test_assert_equal native-run "$output"
}
test_case 'Xcode run native screen supports live filtered logs pause copy return resize Stop LLDB and abort cleanup' _test_xcode_run_native_screen
