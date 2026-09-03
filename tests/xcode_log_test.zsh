_test_xcode_log_sources_keep_fragments_separate() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_log="" _xcode_run_trimmed=0
    local -a _xcode_run_pending=("" "")
    (( ${+functions[_xcode_run_output_append]} )) || { print -u2 "missing independent log sources"; exit 1; }
    _xcode_run_output_append 1 "partial "
    _xcode_run_output_append 2 $'\''Logger record\n'\''
    _xcode_run_output_append 1 $'\''stdout\n'\''
    [[ $_xcode_run_log == $'\''Logger record\npartial stdout\n'\'' ]] || { print -u2 "mixed source fragments"; exit 2; }
    [[ -z ${_xcode_run_pending[1]} && -z ${_xcode_run_pending[2]} ]] || exit 3
    _xcode_run_output_append 2 "${(l:16000::x:)}"
    (( ${#_xcode_run_pending[2]} <= 8192 && _xcode_run_trimmed )) || exit 4
    print separate
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal separate "$output"
}
test_case 'Xcode logs keep partial stdout and Logger records separate and bounded' _test_xcode_log_sources_keep_fragments_separate

_test_xcode_log_native_scope() {
  test_make_temp_dir || return
  local output
  command mkdir -p "$TEST_TMP_DIR/home/app with spaces.app" "$TEST_TMP_DIR/home/run" || return
  test_write_file "$TEST_TMP_DIR/home/app with spaces.app/Info.plist" '<?xml version="1.0"?><plist version="1.0"><dict><key>CFBundleExecutable</key><string>Example</string></dict></plist>' || return
  test_write_file "$TEST_TMP_DIR/home/app with spaces.app/Example" fixture || return
  test_write_file "$TEST_TMP_DIR/home/bin/xcrun" '#!/bin/zsh -df
if [[ $2 == get_app_container ]]; then
  [[ $3 == SIM-456 && $4 == com.example.app && $5 == app ]] || exit 91
  print -r -- "$HOME/app with spaces.app"
elif [[ $2 == spawn ]]; then
  print -r -- "${(j:|:)@}" > "$HOME/log-call"
  print -r -- "$SIMCTL_CHILD_LOGRC|$SIMCTL_CHILD_NSUnbufferedIO" > "$HOME/log-env"
  print -r -- "$$" > "$HOME/log-pid"
  [[ $SCENARIO != failed ]] || exit 7
  print -r -- "Filtering the log data using fixture"
  print -r -- "Timestamp               Ty Process[PID:TID]"
  read -r -t 20 < "$HOME/control"
else
  exit 92
fi' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/xcrun" "$TEST_TMP_DIR/home/app with spaces.app/Example" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$HOME/bin" $path); rehash
    export TMPDIR=$HOME SCENARIO=ready
    source "$1/.zsh.addons/.zsh.xcode"
    zmodload zsh/system
    command mkfifo "$HOME/control"
    exec {control}<> "$HOME/control"
    local _xcode_run_dir="$HOME/run" _xcode_run_unified_fifo="" _xcode_run_unified_status=""
    local -i _xcode_run_unified_fd=-1 _xcode_run_logger=0
    local _XCODE_CAPTURE="" _XCODE_CAPTURE_ERROR=""
    (( ${+functions[_xcode_run_logs_start]} )) || { print -u2 "missing native Logger capture"; exit 1; }
    _xcode_run_logs_start SIM-456 com.example.app || { print -u2 "logger failed to start"; exit 2; }
    [[ $_xcode_run_unified_status == following && $_xcode_run_logger -gt 1 && $_xcode_run_unified_fd -ge 0 ]] || exit 3
    [[ $(<"$HOME/log-env") == /dev/null\|YES ]] || exit 4
    local calls=$(<"$HOME/log-call")
    [[ $calls == "simctl|spawn|SIM-456|log|stream|--predicate|processImagePath == \"${HOME:A}/app with spaces.app/Example\"|--level|debug|--style|compact|--color|none" ]] || { print -u2 -- "$calls"; exit 5; }
    local logger=$_xcode_run_logger
    _xcode_run_logs_stop
    kill -0 "$logger" 2>/dev/null && { print -u2 "logging child survived stop"; exit 6; }
    (( _xcode_run_logger == 0 )) || exit 7
    exec {_xcode_run_unified_fd}<&-
    command rm -- "$_xcode_run_unified_fifo"
    SCENARIO=failed
    _xcode_run_logs_start SIM-456 com.example.app
    [[ $? != 0 && $_xcode_run_unified_status == unavailable ]] || exit 8
    _xcode_run_logs_stop
    (( _xcode_run_unified_fd >= 0 )) && exec {_xcode_run_unified_fd}<&-
    exec {control}>&-
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'Xcode Logger capture prefilters the exact executable disables logrc and reaps its child' _test_xcode_log_native_scope

_test_xcode_log_fairness_and_independent_closure() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_log="" _xcode_run_trimmed=0 _xcode_run_context=fixture
    local -a _xcode_run_pending=("" "") reads=()
    local _xcode_run_fd=11 _xcode_run_unified_fd=12 _xcode_run_unified_status=following
    local _xcode_run_eof=0 _xcode_run_stdout_seen=0 _xcode_run_read_error=0 _xcode_run_publish=1
    local _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_GUIDE_ACTIVE=0 _ZLE_PICKER_INSPECT_WIDTH=0
    local _ZLE_PICKER_SUBTITLE="" _ZLE_PICKER_INSPECT_TITLE=""
    local -A _ZLE_PICKER_INSPECT_TEXTS=()
    local -a _ZLE_PICKER_PASSIVE_LINES=("" "")
    local scenario=gap
    sysread() {
      reads+=($2)
      if [[ $2 == 11 ]]; then
        [[ $scenario == gap || $scenario == closed ]] && return 5
        chunk="${(l:8000::x:)}"$'\''\n'\''
      else
        chunk=$'\''Logger marker\n'\''
      fi
      return 0
    }
    _xcode_run_idle
    (( !_xcode_run_eof )) || { print -u2 "Logger closed unopened stdout"; exit 1; }
    [[ ${(j: :)reads} == "11 12 11 12" ]] || exit 2
    scenario=flood reads=()
    _xcode_run_idle
    [[ ${(j: :)reads} == "11 12 11 12" && $_xcode_run_log == *"Logger marker"* ]] || exit 3
    (( ${#_xcode_run_log} <= 32768 )) || exit 4
    scenario=closed
    _xcode_run_idle
    [[ $_xcode_run_eof == 1 && $_xcode_run_unified_status == following &&
       $_ZLE_PICKER_INSPECT_TITLE == "stdout closed · Following" ]] || { print -u2 "live Logger incorrectly labelled closed"; exit 5; }
    _xcode_run_idle
    [[ $? != 2 && $_xcode_run_log == *"Logger marker"* ]] || exit 6
    print fair
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal fair "$output"
}
test_case 'Xcode logs drain both sources fairly and keep Logger live after stdout closes' _test_xcode_log_fairness_and_independent_closure

_test_xcode_log_paused_source_failure_visibility() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_log="" _xcode_run_trimmed=0
    local _xcode_run_context="Fixture app and exact selected Simulator"
    local -a _xcode_run_pending=("" "")
    local _xcode_run_fd=11 _xcode_run_unified_fd=12 _xcode_run_unified_status=following
    local _xcode_run_eof=0 _xcode_run_stdout_seen=0 _xcode_run_read_error=0 _xcode_run_publish=1
    local _xcode_run_lldb="" _xcode_run_identity=fixture scenario=ready failure=2 source_fd=12
    sysread() {
      [[ $scenario == failed && $2 == $source_fd ]] && return $failure
      return 4
    }
    _zle_picker_loop() {
      local seed="" expected="" before="" visible="" prepared="" source_name=""
      COLUMNS=70 LINES=18 _ZLE_PICKER_SCREEN_ACTIVE=1
      _xcode_picker_collect "" 10
      for source_fd in 12 11; do
        [[ $source_fd == 12 ]] && source_name=Logger || source_name=stdout
        for seed in "" $'\''frozen app line one\nfrozen app line two\n'\''; do
          for failure in 2 5; do
            # EOF before stdout has ever opened remains a provisional writer gap.
            [[ $source_fd == 11 && -z $seed && $failure == 5 ]] && continue
            [[ $failure == 2 ]] && expected=unavailable || expected=closed
            scenario=ready
            _xcode_run_log=$seed _xcode_run_unified_status=following
            _xcode_run_eof=0 _xcode_run_read_error=0 _xcode_run_publish=1
            _xcode_run_stdout_seen=$(( ${#seed} > 0 ))
            _xcode_run_pending=("" "")
            _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_GUIDE_ACTIVE=0
            _zle_picker_render "" 1
            _xcode_run_idle
            _zle_picker_render "" 1
            _ZLE_PICKER_INSPECT_FOCUS=1
            _xcode_run_idle
            _zle_picker_render "" 1
            before=${_ZLE_PICKER_INSPECT_TEXTS[run]}
            scenario=failed
            _xcode_run_idle
            _zle_picker_render "" 1
            visible=${(j: :)_ZLE_PICKER_DISPLAY}
            [[ ${visible:l} == *${source_name:l}* && ${visible:l} == *$expected* &&
               $_ZLE_PICKER_INSPECT_TITLE == *Paused* ]] || {
              print -u2 -- "paused reader hid $source_name $expected (retained bytes: ${#seed})"
              return 8
            }
            if [[ -n $seed ]]; then
              [[ ${_ZLE_PICKER_INSPECT_TEXTS[run]} == "$before" &&
                 $visible == *"frozen app line one"*"frozen app line two"* ]] || {
                print -u2 "source status changed the frozen app log snapshot"
                return 9
              }
            else
              prepared=${(j: :)_ZLE_PICKER_INSPECT_LINES}
              [[ ${_ZLE_PICKER_INSPECT_TEXTS[run]} != "$before" &&
                 ${prepared:l} == *logger* &&
                 ( $source_fd == 11 || ${prepared:l} == *$expected* ) &&
                 $prepared != *"stdout/stderr + Logger/os_log"* ]] || {
                print -u2 "paused empty reader reused stale text after $source_name $expected"
                return 10
              }
            fi
          done
        done
      done
      _ZLE_PICKER_SELECTED_VALUE=stop
      return 0
    }
    _xcode_run_controller || exit $?
    print visible-source-state
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal visible-source-state "$output"
}
test_case 'Xcode paused reader exposes source failures without replacing frozen app logs' \
  _test_xcode_log_paused_source_failure_visibility

_test_xcode_log_expired_child_cleanup() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    zmodload zsh/parameter
    local _xcode_run_logger=$$ signalled=0
    kill() { signalled=1; return 0; }
    _xcode_run_logs_stop
    (( !signalled && !_xcode_run_logger )) || { print -u2 "signalled a PID absent from owned jobs"; exit 1; }
    print owned
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal owned "$output"
}
test_case 'Xcode Logger cleanup never signals an expired or reused child PID' _test_xcode_log_expired_child_cleanup
