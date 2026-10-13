_test_runner_cannot_mask_failed_assertion() {
  test_make_temp_dir || return
  local suite="$TEST_TMP_DIR/meta-suite" output='' exit_status=0

  command mkdir -p -- "$suite/tests" || return
  command cp "$TEST_REPO_ROOT/tests/run.zsh" "$suite/tests/run.zsh" || return
  command cp "$TEST_REPO_ROOT/tests/support.zsh" "$suite/tests/support.zsh" || return
  test_write_file "$suite/tests/masked_test.zsh" $'
_test_deliberately_masked_failure() {
  test_assert_equal expected actual "deliberate harness probe"
  true
}
test_case "unhandled assertion failure" _test_deliberately_masked_failure
' || return

  output=$("$TEST_ZSH_BIN" "$suite/tests/run.zsh" 2>&1) || exit_status=$?
  (( exit_status != 0 )) || {
    test_fail 'runner allowed a later success to mask a failed assertion'
    return
  }
  test_assert_contains "$output" 'FAIL  unhandled assertion failure' \
    'nested runner did not report the failed assertion'
}
test_case 'test runner cannot mask an unhandled failed assertion' \
  _test_runner_cannot_mask_failed_assertion

# A signalled test must stop after its cleanup, even while it waits on a nested
# shell, and fail; it must not continue without its temporary directory.
_test_runner_ends_signalled_test() {
  test_make_temp_dir || return
  zmodload zsh/datetime || return
  local suite="$TEST_TMP_DIR/meta-suite" nested_tmp="$TEST_TMP_DIR/tmp"
  local output='' recorded=''
  local -i exit_status=0
  local -F started=0 elapsed=0
  local -a leftovers=()

  command mkdir -p -- "$suite/tests" "$nested_tmp" || return
  command cp "$TEST_REPO_ROOT/tests/run.zsh" "$suite/tests/run.zsh" || return
  command cp "$TEST_REPO_ROOT/tests/support.zsh" "$suite/tests/support.zsh" || return
  test_write_file "$suite/tests/signal_test.zsh" $'
_test_terminated_probe() {
  zmodload zsh/system || return
  test_make_temp_dir || return
  print -r -- "$TEST_TMP_DIR" >| "${TESTS_DIR:h}/recorded" || return
  kill -TERM $sysparams[pid]
  : >| "${TESTS_DIR:h}/continued"
}
test_case "terminated probe" _test_terminated_probe

_test_waiting_probe() {
  zmodload zsh/system || return
  test_make_temp_dir || return
  local -i self=$sysparams[pid]
  local output=
  ( sleep 0.3; kill -TERM $self ) &!
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" "sleep 4" 2> /dev/null)
}
test_case "waiting probe" _test_waiting_probe
' || return

  # A file, not a command substitution: the waiting probe's nested shell is
  # left running until its short sleep ends.
  started=$EPOCHREALTIME
  TMPDIR=$nested_tmp "$TEST_ZSH_BIN" "$suite/tests/run.zsh" \
    >| "$suite/output" 2>&1 || exit_status=$?
  elapsed=$(( EPOCHREALTIME - started ))
  output=$(<"$suite/output") || return

  test_assert_contains "$output" 'FAIL  terminated probe' \
    'nested runner did not report the terminated test' || return
  test_assert_contains "$output" 'FAIL  waiting probe' \
    'nested runner did not report the test terminated while waiting' || return
  test_assert_equal 1 "$exit_status" 'nested runner did not finish its run' || return
  [[ ! -e $suite/continued ]] || {
    test_fail 'a terminated test continued after its cleanup'
    return
  }
  recorded=$(<"$suite/recorded") || return
  [[ $recorded == "$nested_tmp"/my-zsh-tests.* && ! -e $recorded ]] || {
    test_fail "the terminated test left its temporary directory: ${(qqq)recorded}"
    return
  }
  leftovers=("$nested_tmp"/*(DN))
  (( ! ${#leftovers} )) || {
    test_fail "signalled tests left temporary state: ${(j:, :)${(qqq)leftovers}}"
    return
  }
  (( elapsed < 2.5 )) ||
    test_fail "TERM did not end a test waiting on a nested shell (${elapsed} s)"
}
test_case 'test runner ends a test that receives TERM and removes its temporary directory' \
  _test_runner_ends_signalled_test

_test_runner_isolates_fixture_git_environment() {
  test_make_temp_dir || return
  local suite="$TEST_TMP_DIR/meta-suite" operator_home="$TEST_TMP_DIR/operator-home"
  local sentinel="$TEST_TMP_DIR/sentinel" marker="$TEST_TMP_DIR/hook-marker"
  local output='' head_before='' head_after='' config_before='' exit_status=0
  local -a isolated=(env -i PATH="$PATH" HOME="$TEST_TMP_DIR"
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null)

  command mkdir -p -- "$suite/tests" "$operator_home/hooks" "$TEST_TMP_DIR/tmp" || return
  command cp "$TEST_REPO_ROOT/tests/run.zsh" "$suite/tests/run.zsh" || return
  command cp "$TEST_REPO_ROOT/tests/support.zsh" "$suite/tests/support.zsh" || return
  test_write_file "$suite/tests/probe_test.zsh" $'
_test_fixture_git_probe() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/r"
  command git init -q -- "$repo" || return
  command git -C "$repo" config user.name F || return
  command git -C "$repo" -c user.email=f@example.invalid -c commit.gpgsign=false \\
    commit -q --allow-empty -m probe
}
test_case "fixture git probe" _test_fixture_git_probe
' || return

  # The operator's global configuration runs a hook on every commit.
  test_write_file "$operator_home/hooks/post-commit" "#!/bin/sh
: > ${(qq)marker}" || return
  command chmod +x "$operator_home/hooks/post-commit" || return
  command "${isolated[@]}" git config --file "$operator_home/.gitconfig" \
    core.hooksPath "$operator_home/hooks" || return

  # An inherited GIT_DIR names this unrelated repository.
  command "${isolated[@]}" git init -q -- "$sentinel" || return
  command "${isolated[@]}" git -C "$sentinel" -c user.name=S \
    -c user.email=s@example.invalid -c commit.gpgsign=false \
    commit -q --allow-empty -m sentinel || return
  head_before=$(command "${isolated[@]}" git -C "$sentinel" rev-parse HEAD) || return
  config_before=$(<"$sentinel/.git/config") || return

  output=$(command env -i PATH="$PATH" HOME="$operator_home" \
    TMPDIR="$TEST_TMP_DIR/tmp" GIT_DIR="$sentinel/.git" \
    "$TEST_ZSH_BIN" "$suite/tests/run.zsh" 2>&1) || exit_status=$?

  head_after=$(command "${isolated[@]}" git -C "$sentinel" rev-parse HEAD) || return
  test_assert_equal "$head_before" "$head_after" \
    'inherited GIT_DIR redirected a fixture commit into another repository' || return
  test_assert_equal "$config_before" "$(<"$sentinel/.git/config")" \
    'inherited GIT_DIR redirected a fixture config write into another repository' || return
  [[ ! -e $marker ]] || {
    test_fail 'a runner-level Git fixture ran a hook from global Git configuration'
    return
  }
  test_assert_equal 0 "$exit_status" 'nested runner failed the Git fixture probe' || return
  test_assert_contains "$output" 'PASS  fixture git probe' \
    'nested runner did not report the Git fixture probe'
}
test_case 'test runner isolates fixture Git commands from inherited repository selectors and global configuration' \
  _test_runner_isolates_fixture_git_environment

# The bootstrap reports a peer's load diagnostic and keeps going, so the
# handoff re-source check must reject any output, not only a failing status.
_test_verify_rejects_reload_diagnostics() {
  test_make_temp_dir || return
  local suite="$TEST_TMP_DIR/meta-suite" output='' exit_status=0
  local -a isolated=(env -i PATH="$PATH" HOME="$TEST_TMP_DIR/home"
    TMPDIR="$TEST_TMP_DIR/tmp" GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null)

  command mkdir -p -- "$suite/tests" "$suite/.zsh.addons" \
    "$TEST_TMP_DIR/home" "$TEST_TMP_DIR/tmp" || return
  command cp "$TEST_REPO_ROOT/tests/verify.zsh" "$suite/tests/verify.zsh" || return
  command cp "$TEST_REPO_ROOT/.zshrc" "$suite/.zshrc" || return
  test_write_file "$suite/install.zsh" ':' || return
  test_write_file "$suite/templates/init.zsh" ':' || return
  command "${isolated[@]}" git init -q -- "$suite" || return
  command "${isolated[@]}" git -C "$suite" add -A || return

  output=$(command "${isolated[@]}" "$TEST_ZSH_BIN" "$suite/tests/verify.zsh" 2>&1) ||
    exit_status=$?
  test_assert_equal 0 "$exit_status" "verify failed its clean control run: $output" || return
  test_assert_contains "$output" 're-source: ok' \
    'verify did not report a clean double re-source' || return

  test_write_file "$suite/.zsh.addons/.zsh.broken" \
    $'print -u2 -r -- "fixture peer: simulated load error"\n:' || return
  exit_status=0
  output=$(command "${isolated[@]}" "$TEST_ZSH_BIN" "$suite/tests/verify.zsh" 2>&1) ||
    exit_status=$?
  (( exit_status != 0 )) || {
    test_fail "verify accepted a double re-source with load diagnostics: $output"
    return
  }
  test_assert_contains "$output" 're-source: failed' \
    'verify did not report the failed double re-source' || return
  test_assert_contains "$output" 'fixture peer: simulated load error' \
    'verify did not show the load diagnostics'
}
test_case 'verify fails the double re-source when a peer reports load diagnostics' \
  _test_verify_rejects_reload_diagnostics

# Shared PTY helpers must never hand the operator's GUI or clipboard programs
# to file actions; a test that wants those effects passes its own fakes.
_test_search_session_fails_closed_on_effects() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    _zle_picker_run() {
      print -r -- "open=$_directory_browser_open|clipboard=$_directory_browser_clipboard"
      return 1
    }
    test_search_session x
    test_search_session y /fake/copy /fake/open
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'open=|clipboard=\nopen=/fake/open|clipboard=/fake/copy' "$output" \
    'shared search session resolved a system open or clipboard executable'
}
test_case 'shared search session never resolves system open or clipboard executables' \
  _test_search_session_fails_closed_on_effects

# PTY expectations (tests/pty_support.zsh). Each probe runs in an isolated
# shell under a watchdog, so a wait that regresses into a hang fails its case
# instead of hanging the suite. Probes print status:, elapsed: and detail:
# lines; elapsed time is measured around one expectation.
_test_pty_probe() {
  test_make_temp_dir || return
  local -i probe_status=0
  REPLY=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/tests/pty_support.zsh" || exit 91
    command mkfifo "$HOME/events" || exit 92
    exec {event_fd}<> "$HOME/events"
    { zselect -t 1200; kill -KILL $$; } > /dev/null 2>&1 &
    local -i watchdog=$!
    trap '\''kill $watchdog 2> /dev/null'\'' EXIT
    local -F started=0
    '"$1"'
  ' "$TEST_REPO_ROOT" 2>&1) || probe_status=$?
  (( probe_status == 0 )) || test_fail "PTY probe exited $probe_status: $REPLY"
}

_test_pty_field() {
  REPLY=${${(M)${(f)1}:#$2:*}#$2:}
}

_test_pty_assert_elapsed() {
  local output=$1 minimum=$2 maximum=$3 label=$4
  _test_pty_field "$output" elapsed
  [[ $REPLY == <->(|.<->) ]] && (( REPLY >= minimum && REPLY < maximum )) && return 0
  test_fail "$label: waited ${REPLY:-?} s, expected at least $minimum and under $maximum; output: $output"
}

_test_pty_expect_fails_at_deadline_without_marker() {
  local output=''
  _test_pty_probe '
    _probe_child() { print -r -- OTHER-MARKER; read -k; }
    test_pty_start probe _probe_child || exit 93
    started=$EPOCHREALTIME
    test_pty_expect probe "" WANTED-MARKER 2 2> "$HOME/stderr"
    print -r -- "status:$?"
    print -r -- "elapsed:$(( EPOCHREALTIME - started ))"
    zpty -d probe
    print -r -- "detail:$(<"$HOME/stderr")"
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 1 "$REPLY" "a missing marker did not fail: $output" || return
  _test_pty_assert_elapsed "$output" 2 3 'a missing marker did not fail at its deadline' || return
  test_assert_contains "$output" WANTED-MARKER 'the failure did not name the missing marker'
}
test_case 'PTY expectation fails at its deadline when its marker never arrives' \
  _test_pty_expect_fails_at_deadline_without_marker

_test_pty_expect_fails_at_deadline_during_output() {
  local output=''
  _test_pty_probe '
    _probe_child() { while :; do print -r -- REPAINT; zselect -t 10; done; }
    test_pty_start probe _probe_child || exit 93
    started=$EPOCHREALTIME
    test_pty_expect probe $event_fd WANTED 2 2> /dev/null
    print -r -- "status:$?"
    print -r -- "elapsed:$(( EPOCHREALTIME - started ))"
    zpty -d probe
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 1 "$REPLY" "a missing event did not fail while output continued: $output" || return
  _test_pty_assert_elapsed "$output" 2 3 'continuous output postponed the deadline'
}
test_case 'PTY expectation fails at its deadline while output never stops' \
  _test_pty_expect_fails_at_deadline_during_output

_test_pty_expect_waits_through_silence() {
  local output=''
  _test_pty_probe '
    _probe_child() {
      print -r -u $event_fd "STATE|ready"
      print -r -- painted
      zselect -t 80
      print -r -u $event_fd WANTED
      read -k
    }
    test_pty_start probe _probe_child || exit 93
    started=$EPOCHREALTIME
    test_pty_expect -p probe $event_fd "STATE|" 3 || exit 94
    print -r -- "prefix:$REPLY"
    test_pty_expect probe $event_fd WANTED 3
    print -r -- "status:$?"
    print -r -- "elapsed:$(( EPOCHREALTIME - started ))"
    print -r -- "detail:$REPLY"
    zpty -d probe
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 0 "$REPLY" "an event after a silent pause was missed: $output" || return
  _test_pty_assert_elapsed "$output" 0 3 'the event did not end the wait' || return
  _test_pty_field "$output" detail
  test_assert_equal WANTED "$REPLY" 'the matching event was not returned' || return
  _test_pty_field "$output" prefix
  test_assert_equal 'STATE|ready' "$REPLY" 'a prefix expectation did not return its whole event'
}
test_case 'PTY expectation keeps waiting through silence until its deadline' \
  _test_pty_expect_waits_through_silence

_test_pty_expect_fails_promptly_after_exit() {
  local output=''
  _test_pty_probe '
    _probe_child() { print -r -- goodbye; print -r -u $event_fd OTHER; }
    test_pty_start probe _probe_child || exit 93
    started=$EPOCHREALTIME
    test_pty_expect probe $event_fd WANTED 3 2> "$HOME/stderr"
    print -r -- "status:$?"
    print -r -- "elapsed:$(( EPOCHREALTIME - started ))"
    zpty -d probe
    print -r -- "detail:$(<"$HOME/stderr")"
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 1 "$REPLY" "a finished command did not fail the wait: $output" || return
  _test_pty_assert_elapsed "$output" 0 1.5 'a finished command left the wait running' || return
  test_assert_contains "$output" WANTED 'the failure did not name the missing event' || return
  [[ $output != *"bad file descriptor"* ]] ||
    test_fail "the wait selected on a closed terminal: $output"
}
test_case 'PTY expectation fails promptly when its child exits without the marker' \
  _test_pty_expect_fails_promptly_after_exit

_test_pty_expect_matches_split_marker() {
  local output=''
  _test_pty_probe '
    _probe_child() {
      print -rn -- FRAME-1:EN
      zselect -t 30
      print -r -- "D-MARK tail"
      read -k
    }
    test_pty_start probe _probe_child || exit 93
    test_pty_expect probe "" END-MARK 3
    print -r -- "status:$?"
    print -r -- "detail:${(V)REPLY}"
    print -r -- "read:${(V)TEST_PTY_OUTPUT}"
    zpty -d probe
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 0 "$REPLY" "a marker split across reads was missed: $output" || return
  _test_pty_field "$output" detail
  test_assert_equal 'FRAME-1:END-MARK tail^M\n' "$REPLY" \
    'the expectation did not return the whole line holding its marker' || return
  _test_pty_field "$output" read
  test_assert_equal 'FRAME-1:END-MARK tail^M\n' "$REPLY" 'the call lost terminal output it read'
}
test_case 'PTY expectation matches a marker split across non-blocking reads' \
  _test_pty_expect_matches_split_marker

_test_pty_expect_waits_for_finish() {
  local output=''
  _test_pty_probe '
    _probe_child() { print -r -- FIRST; zselect -t 30; print -rn -- LAST; }
    test_pty_start probe _probe_child || exit 93
    test_pty_expect probe "" FIRST 3 || exit 94
    print -r -- "first:${(V)TEST_PTY_OUTPUT}"
    test_pty_expect probe "" "" 3
    print -r -- "status:$?"
    print -r -- "read:${(V)TEST_PTY_OUTPUT}"
    zpty -d probe
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 0 "$REPLY" "a finished command did not end an empty expectation: $output" || return
  _test_pty_field "$output" first
  test_assert_equal 'FIRST^M\n' "$REPLY" 'the first call did not report its own output' || return
  _test_pty_field "$output" read
  test_assert_equal 'LAST' "$REPLY" 'the final call did not report only the rest of the output'
}
test_case 'PTY expectation reports the output of each call and an empty marker waits for the command to finish' \
  _test_pty_expect_waits_for_finish

_test_pty_expect_refuses_blocking_sessions() {
  local output=''
  _test_pty_probe '
    _probe_child() { read -k; }
    zpty probe _probe_child || exit 93
    started=$EPOCHREALTIME
    test_pty_expect probe "" WANTED 2 2> "$HOME/stderr"
    print -r -- "status:$?"
    print -r -- "elapsed:$(( EPOCHREALTIME - started ))"
    zpty -d probe
    print -r -- "detail:$(<"$HOME/stderr")"
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 2 "$REPLY" "a blocking session was read: $output" || return
  _test_pty_assert_elapsed "$output" 0 1 'a blocking session was not refused at once' || return
  test_assert_contains "$output" 'usage: test_pty_expect' 'the refusal did not explain its usage'
}
test_case 'PTY expectation refuses a session not started nonblocking by its helper' \
  _test_pty_expect_refuses_blocking_sessions

_test_pty_expect_stops_at_caller_events() {
  local output=''
  _test_pty_probe '
    _probe_child() {
      print -r -u $event_fd FIRST
      print -r -u $event_fd "RESULT|1"
      zselect -t 30
      print -r -u $event_fd WANTED
      read -k
    }
    test_pty_start probe _probe_child || exit 93
    test_pty_expect -p probe $event_fd "" 3 || exit 94
    print -r -- "next:$REPLY"
    print -r -- "first-events:${(j:,:)TEST_PTY_EVENTS}"
    started=$EPOCHREALTIME
    test_pty_expect -s "(RESULT|DONE)*" probe $event_fd WANTED 3 2> "$HOME/stderr"
    print -r -- "status:$?"
    print -r -- "elapsed:$(( EPOCHREALTIME - started ))"
    print -r -- "events:${(j:,:)TEST_PTY_EVENTS}"
    test_pty_expect -g probe $event_fd "W?NT*" 3 || exit 95
    print -r -- "glob:$REPLY"
    zpty -d probe
    print -r -- "detail:$(<"$HOME/stderr")"
  ' || return
  output=$REPLY
  _test_pty_field "$output" glob
  test_assert_equal WANTED "$REPLY" 'a glob expectation did not return the matching event' || return
  _test_pty_field "$output" first-events
  test_assert_equal FIRST "$REPLY" 'the first call did not report the event it read' || return
  _test_pty_field "$output" events
  test_assert_equal 'RESULT|1' "$REPLY" 'the stopped call did not report only its own events' || return
  _test_pty_field "$output" next
  test_assert_equal FIRST "$REPLY" 'an empty prefix did not take the next event' || return
  _test_pty_field "$output" status
  test_assert_equal 1 "$REPLY" "a caller stop event did not fail the wait: $output" || return
  _test_pty_assert_elapsed "$output" 0 1 'a caller stop event did not end the wait at once' || return
  test_assert_contains "$output" 'RESULT|1' 'the failure did not name the stop event'
}
test_case 'PTY expectation reports the events of each call, takes the next one, matches globs and fails at once on a caller stop event' \
  _test_pty_expect_stops_at_caller_events

_test_pty_expect_continues_a_caller_line() {
  local output=''
  _test_pty_probe '
    _probe_child() { print -rn -- xA; zselect -t 30; print -r -- By; read -k; }
    test_pty_start probe _probe_child || exit 93
    test_pty_expect probe "" xA 3 || exit 94
    test_pty_expect -c "$REPLY" probe "" AB 3
    print -r -- "status:$?"
    print -r -- "detail:${(V)REPLY}"
    zpty -d probe
  ' || return
  output=$REPLY
  _test_pty_field "$output" status
  test_assert_equal 0 "$REPLY" "a marker continuing the caller line was missed: $output" || return
  _test_pty_field "$output" detail
  test_assert_equal 'xABy^M\n' "$REPLY" 'the continued line was not returned whole'
}
test_case 'PTY expectation continues a line the caller already read' \
  _test_pty_expect_continues_a_caller_line
