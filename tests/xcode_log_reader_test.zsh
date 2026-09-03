_test_xcode_log_reader_literal_filter() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_logs_snapshot=$'\''Info: first\nERROR: [a]* literal\nerror: second\nlast without newline'\''
    local _xcode_logs_text="" _xcode_logs_query="" _xcode_logs_notice=""
    local _xcode_logs_total=0 _xcode_logs_matches=0 _xcode_logs_trimmed=0
    local _xcode_run_clipboard=/fixture/pbcopy
    local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
    (( ${+functions[_xcode_logs_collect]} )) || { print -u2 "missing captured-log filter"; exit 1; }
    _xcode_logs_collect ERROR 10
    [[ $_xcode_logs_text == $'\''ERROR: [a]* literal\nerror: second\n'\'' &&
       $_xcode_logs_matches == 2 && $_xcode_logs_total == 4 &&
       ${#_ZLE_PICKER_RESULTS} == 0 && ${#_ZLE_PICKER_DOCUMENT_LINES} == 2 ]] || exit 2
    _xcode_logs_collect "[a]*" 10
    [[ $_xcode_logs_matches == 1 && $_xcode_logs_text == $'\''ERROR: [a]* literal\n'\'' ]] || { print -u2 "filter interpreted pattern syntax"; exit 3; }
    _xcode_logs_collect missing 10
    [[ $_xcode_logs_matches == 0 && -z $_xcode_logs_text && $_ZLE_PICKER_COPY_ENABLED == 0 ]] || exit 4
    _xcode_logs_collect "" 10
    [[ $_xcode_logs_text == "$_xcode_logs_snapshot" && $_ZLE_PICKER_COPY_ENABLED == 1 ]] || exit 5
    print filtered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal filtered "$output"
}
test_case 'Xcode full log reader filters literal lines and copies exact retained matching text' _test_xcode_log_reader_literal_filter

_test_xcode_log_reader_navigation() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_logs_snapshot=$'\''first\nERROR here\nlast\n'\'' _xcode_logs_query=ERROR
    local _xcode_logs_offset=4 _xcode_logs_row=2 _xcode_logs_trimmed=0 _xcode_logs_notice=""
    local _xcode_logs_follow=0
    local _xcode_run_context=fixture _xcode_run_clipboard=/fixture/pbcopy
    local _xcode_run_unified_status=following _xcode_run_eof=0 _xcode_run_read_error=0
    local _xcode_logs_copy_payload="" _xcode_logs_copy_count=0 calls=0
    (( ${+functions[_xcode_logs_reader]} )) || { print -u2 "missing full log reader"; exit 1; }
    _zle_picker_loop() {
      (( ++calls ))
      [[ $_ZLE_PICKER_READER_ONLY == 1 && $_ZLE_PICKER_CANCEL_LABEL == back &&
         $_ZLE_PICKER_INSPECT_ACTION == options && $1 == ERROR ]] || return 93
      "$_ZLE_PICKER_COLLECTOR" "$1" 10
      _ZLE_PICKER_BOOKMARK=("$1" 0 0)
      _ZLE_PICKER_DOCUMENT_OFFSETS[logs]=7
      _ZLE_PICKER_DOCUMENT_ROWS[logs]=2
      case $calls in
        1) _ZLE_PICKER_ACTION=select; return 0 ;;
        2) return 1 ;;
        3) _ZLE_PICKER_ACTION=copy; return 0 ;;
      esac
      return 99
    }
    _xcode_logs_options() { return 1; }
    _xcode_logs_reader
    [[ $? == 1 && $calls == 2 && $_xcode_logs_query == ERROR && $_xcode_logs_offset == 7 ]] || exit 2
    _xcode_logs_reader
    [[ $? == 0 && $_ZLE_PICKER_SELECTED_VALUE == copy-logs &&
       $_xcode_logs_copy_payload == $'\''ERROR here\n'\'' && $_xcode_logs_copy_count == 1 ]] || exit 3
    print returned
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal returned "$output"
}
test_case 'Xcode log reader returns through options and Escape while preserving its own bookmark' _test_xcode_log_reader_navigation

_test_xcode_log_reader_clipboard() {
  test_make_temp_dir || return
  local output
  test_write_file "$TEST_TMP_DIR/home/pbcopy spy" '#!/bin/zsh -df
[[ -f $HOME/restored ]] || exit 91
[[ $SCENARIO != failed ]] || exit 7
command cat > "$HOME/clipboard"' || return
  command chmod +x "$TEST_TMP_DIR/home/pbcopy spy" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_run_clipboard="$HOME/pbcopy spy" _xcode_logs_copy_payload=$'\''error: %(literal) [*]\n'\''
    local _xcode_logs_copy_count=1 _xcode_logs_notice=""
    (( ${+functions[_xcode_logs_copy]} )) || { print -u2 "missing captured-log copy"; exit 1; }
    print ready > "$HOME/restored"
    _xcode_logs_copy || exit 2
    [[ $(<"$HOME/clipboard") == "error: %(literal) [*]" && $_xcode_logs_notice == *Copied* ]] || exit 3
    export SCENARIO=failed
    _xcode_logs_copy
    [[ $? != 0 && $_xcode_logs_notice == *failed* ]] || exit 4
    _xcode_run_clipboard="$HOME/missing"
    _xcode_logs_copy
    [[ $? != 0 ]] || exit 5
    print copied
  ' "$TEST_REPO_ROOT" 2>"$TEST_TMP_DIR/errors") || return
  test_assert_equal copied "$output"
}
test_case 'Xcode log copy writes only requested retained text and reports clipboard failures' _test_xcode_log_reader_clipboard

_test_xcode_log_reader_feedback() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_logs_notice="Copy failed: clipboard write failed"
    local _xcode_run_lldb=/fixture/lldb _xcode_run_identity=fixture
    local _xcode_run_log=message _xcode_run_eof=0 _xcode_run_trimmed=0 _xcode_run_context=fixture
    local _xcode_run_unified_status=following _xcode_run_read_error=0
    _zle_picker_loop() {
      COLUMNS=70 LINES=11 _ZLE_PICKER_SCREEN_ACTIVE=1
      _xcode_picker_collect "" 10
      _zle_picker_render "" 1
      [[ $_ZLE_PICKER_HEADER == *"Copy failed: clipboard write failed"* ]] || {
        print -u2 "copy failure hidden in short Run screen"; return 9;
      }
      _ZLE_PICKER_SELECTED_VALUE=stop
    }
    _xcode_run_controller || exit $?
    local _xcode_logs_snapshot=message _xcode_logs_query="" _xcode_run_clipboard=""
    local _xcode_logs_trimmed=1 _xcode_logs_notice="" _xcode_logs_text=""
    local -i _xcode_logs_matches=0 _xcode_logs_total=0
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
    _xcode_run_unified_status=unavailable
    _xcode_logs_collect "" 10
    COLUMNS=40 LINES=18 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT=1
    _ZLE_PICKER_DOCUMENT_KEY=logs _ZLE_PICKER_INSPECT_FIXED_KEY=logs
    _ZLE_PICKER_INSPECT_TEXTS=(logs "")
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_HEADER == *"Logger unavailable"* ]] || {
      print -u2 "source failure hidden in narrow reader"; exit 10;
    }
    print feedback
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal feedback "$output"
}
test_case 'Xcode log feedback keeps copy and source failures visible in small windows' _test_xcode_log_reader_feedback

_test_xcode_log_copy_failure_status() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output
  command mkdir -p "$home/simulator data/tmp" || return
  test_write_file "$home/bin/xcrun" '#!/bin/zsh -df
if [[ $2 == getenv ]]; then print -r -- "$HOME/simulator data"; exit; fi
if [[ $1 == --find ]]; then print -r -- "$HOME/bin/lldb"; exit; fi
if [[ $2 == launch ]]; then print -r -- "com.example.app: 12345"; fi' || return
  test_write_file "$home/bin/ps" '#!/bin/zsh -df
print -r -- "501 Wed Sep 2 12:00:00 2026 /sim/Example.app/Example"' || return
  test_write_file "$home/bin/pbcopy" '#!/bin/zsh -df
[[ -f $HOME/restored ]] || exit 91
exit 7' || return
  test_write_file "$home/bin/lldb" '#!/bin/zsh -df
[[ -f $HOME/restored ]] || exit 92
exit 0' || return
  command chmod +x "$home/bin/"* || return
  output=$(test_run_interactive "$home" '
    path=("$HOME/bin" $path); rehash
    export TMPDIR=$HOME
    source "$1/.zsh.addons/.zsh.xcode"
    local calls=0
    _zle_picker_run() {
      (( ++calls ))
      if (( calls == 1 )); then
        _xcode_logs_copy_payload="retained message" _xcode_logs_copy_count=1
        _ZLE_PICKER_SELECTED_VALUE=copy-logs
      else
        [[ $_xcode_logs_notice == "Copy failed: clipboard write failed" ]] || return 93
        _ZLE_PICKER_SELECTED_VALUE=lldb
      fi
      print restored > "$HOME/restored"
    }
    _xcode_run_live SIM-456 com.example.app fixture > "$HOME/output"
    [[ $? == 1 && $calls == 2 ]] || { print -u2 "successful debugger cleared copy failure"; exit 1; }
    local -a remnants=("$HOME/simulator data/tmp"/compozsh-xcode-run.*(N))
    (( !${#remnants} )) || exit 2
    print sticky
  ' "$TEST_REPO_ROOT" 2>"$TEST_TMP_DIR/errors") || {
    print -u2 -r -- "$(<"$TEST_TMP_DIR/errors")"
    return 1
  }
  test_assert_equal sticky "$output"
}
test_case 'Xcode log copy failure remains nonzero after successful LLDB and cleanup' _test_xcode_log_copy_failure_status

_test_xcode_logs_live_publication() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.xcode"
    local _xcode_logs_snapshot="" _xcode_logs_query=ERROR _xcode_logs_notice=""
    local _xcode_logs_text="" _xcode_run_log="" _xcode_run_context=fixture _xcode_run_clipboard=/fixture/pbcopy
    local -a _xcode_run_pending=("" "")
    local -i _xcode_logs_total=0 _xcode_logs_matches=0 _xcode_logs_trimmed=0 _xcode_run_trimmed=0
    local -i _ZLE_PICKER_DOCUMENT_FOLLOW=1 _ZLE_PICKER_GUIDE_ACTIVE=0 _xcode_run_eof=0
    local _xcode_run_unified_status=following
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
    local reads=0
    _xcode_run_read_sources() { (( ++reads )); REPLY=0; }
    _xcode_logs_collect ERROR 10
    _xcode_run_log=$'\''debug ignored\nERROR first\n'\''
    _xcode_logs_idle
    [[ $? == 0 && $_xcode_logs_text == $'\''ERROR first\n'\'' && $_xcode_logs_matches == 1 ]] || {
      print -u2 "live zero-match filter did not publish new output automatically"; exit 1;
    }
    _xcode_logs_idle
    [[ $? == 1 ]] || { print -u2 "unchanged live output repainted"; exit 2; }
    _ZLE_PICKER_DOCUMENT_FOLLOW=0
    _xcode_run_log+=$'\''ERROR second\n'\''
    _xcode_logs_idle
    [[ $_xcode_logs_text == $'\''ERROR first\n'\'' ]] || { print -u2 "paused text moved"; exit 3; }
    _ZLE_PICKER_DOCUMENT_FOLLOW=1 _ZLE_PICKER_GUIDE_ACTIVE=1
    _xcode_logs_idle
    [[ $_xcode_logs_text == $'\''ERROR first\n'\'' ]] || { print -u2 "guide changed copy scope"; exit 4; }
    _ZLE_PICKER_GUIDE_ACTIVE=0
    _xcode_logs_idle
    [[ $_xcode_logs_text == $'\''ERROR first\nERROR second\n'\'' && $reads == 5 ]] || exit 5
    _xcode_run_trimmed=1
    _xcode_logs_idle
    [[ $? == 0 && $_ZLE_PICKER_BROWSE_LABEL == *"older logs dropped"* ]] || {
      print -u2 "unchanged repeated tail concealed dropped logs"; exit 6;
    }
    _xcode_logs_idle
    [[ $? == 1 ]] || exit 7
    _xcode_run_log=${_xcode_run_log/debug ignored/replacement noise}
    _ZLE_PICKER_INSPECT_WIDTH=79
    _xcode_logs_idle
    [[ $? == 1 && $_ZLE_PICKER_INSPECT_WIDTH == 79 ]] || {
      print -u2 "nonmatching noise repainted and discarded prepared wrapping"; exit 8;
    }
    print live
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal live "$output"
}
test_case 'Xcode logs follow new filtered output automatically while pause and guide keep stable text' _test_xcode_logs_live_publication

_test_xcode_logs_formatted_copy() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local first="2026-09-02 22:44:52.390 Er Example[123:456] [com.example:network] Request failed"
    local second="2026-09-02 22:44:53.390 In Example[123:456] [com.example:network] Retry started"
    local _xcode_logs_snapshot="$first"$'\''\n'\''"$second"$'\''\n'\''
    local _xcode_logs_text="" _xcode_logs_query="" _xcode_logs_notice=""
    local _xcode_logs_total=0 _xcode_logs_matches=0 _xcode_logs_trimmed=0
    local _xcode_run_clipboard=/fixture/pbcopy _xcode_run_context=fixture
    local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
    _xcode_logs_collect "" 10
    [[ $_xcode_logs_text == "$_xcode_logs_snapshot" && $_xcode_logs_matches == 2 ]] || exit 1
    [[ $_ZLE_PICKER_DOCUMENT_LINES[1] == "22:44:52.390 · Error · com.example:network" &&
       $_ZLE_PICKER_DOCUMENT_LINES[2] == "Request failed" &&
       -z $_ZLE_PICKER_DOCUMENT_LINES[3] &&
       $_ZLE_PICKER_DOCUMENT_LINES[-1] == "Retry started" &&
       $_ZLE_PICKER_DOCUMENT_ROLES[1] == error ]] || { print -u2 "records have no readable header/body separation"; exit 2; }
    _xcode_logs_collect "123:456" 10
    [[ $_xcode_logs_matches == 2 && $_xcode_logs_text == "$_xcode_logs_snapshot" ]] || exit 3
    _xcode_logs_collect failed 10
    [[ $_xcode_logs_matches == 1 && $_xcode_logs_text == "$first"$'\''\n'\'' &&
       $_ZLE_PICKER_DOCUMENT_LINES[-1] == "Request failed" ]] || exit 4
    print formatted
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal formatted "$output"
}
test_case 'Xcode formatted logs separate entries while filtering and copying original metadata' _test_xcode_logs_formatted_copy
