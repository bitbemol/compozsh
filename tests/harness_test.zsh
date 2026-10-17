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

# Product code stages temporary files below TMPDIR. A test child must use a
# TMPDIR inside its test's temporary directory, so a staged leftover goes with
# the test instead of accumulating in the runner's TMPDIR.
_test_runner_keeps_child_temporary_files_out_of_runner_tmpdir() {
  test_make_temp_dir || return
  local suite="$TEST_TMP_DIR/meta-suite" runner_tmp="$TEST_TMP_DIR/runner-tmp"
  local output='' recorded_test='' recorded_probe=''
  local -i exit_status=0
  local -a leftovers=()

  command mkdir -p -- "$suite/tests" || return
  command mkdir -m 0700 -- "$runner_tmp" || return
  command cp "$TEST_REPO_ROOT/tests/run.zsh" "$suite/tests/run.zsh" || return
  command cp "$TEST_REPO_ROOT/tests/support.zsh" "$suite/tests/support.zsh" || return
  test_write_file "$suite/tests/probe_test.zsh" $'
_test_child_tmpdir_probe() {
  test_make_temp_dir || return
  local probe=\'\'
  probe=$(test_run_interactive "$TEST_TMP_DIR/home" \'
    command mktemp -d "${TMPDIR:-/tmp}/compozsh-probe.XXXXXX"
  \') || return
  print -r -- "$TEST_TMP_DIR" >| "${TESTS_DIR:h}/recorded-test" || return
  print -r -- "$probe" >| "${TESTS_DIR:h}/recorded-probe"
}
test_case "child tmpdir probe" _test_child_tmpdir_probe
' || return

  output=$(TMPDIR=$runner_tmp "$TEST_ZSH_BIN" "$suite/tests/run.zsh" 2>&1) ||
    exit_status=$?
  test_assert_equal 0 "$exit_status" "nested runner failed the TMPDIR probe: $output" || return
  test_assert_contains "$output" 'PASS  child tmpdir probe' \
    'nested runner did not report the TMPDIR probe' || return
  leftovers=("$runner_tmp"/*(DN))
  (( ! ${#leftovers} )) || {
    test_fail "a test child left temporary state in the runner TMPDIR: ${(j:, :)${(qqq)leftovers}}"
    return
  }
  recorded_test=$(<"$suite/recorded-test") || return
  recorded_probe=$(<"$suite/recorded-probe") || return
  [[ $recorded_probe == "$recorded_test"/tmp/compozsh-probe.* &&
     ! -e $recorded_probe ]] ||
    test_fail "a test child did not stage below its test's TMPDIR: ${(qqq)recorded_probe}"
}
test_case 'test runner keeps product temporary files out of the runner TMPDIR' \
  _test_runner_keeps_child_temporary_files_out_of_runner_tmpdir

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

# The seam must run the production post-cleanup dispatcher, not a test-only
# one: a result under HOME inserts the same quoted absolute path as Tab does.
_test_search_session_uses_production_dispatch() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    target="$HOME/a b.txt"
    _zle_picker_run() {
      _ZLE_PICKER_ACTION=insert _ZLE_PICKER_SELECTED_VALUE=$target
      return 0
    }
    test_search_session x
    print -r -- "seam-status=$?"
    IFS= read -r -z inserted
    [[ $inserted == "${(q)target}" ]] && print -r -- seam=absolute || print -r -- "seam=$inserted"
    BUFFER="" CURSOR=0
    _directory_browser_dispatch widget insert insert "$target" 2>/dev/null
    print -r -- "widget-status=$?"
    [[ $BUFFER == "$inserted" && $CURSOR == ${#inserted} ]] && print -r -- widget=same || print -r -- "widget=$BUFFER"
  ' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal $'seam-status=0\nseam=absolute\nwidget-status=0\nwidget=same' "$output" \
    'shared search session did not insert through the production dispatcher'
}
test_case 'shared search session inserts through the production file-action dispatcher' \
  _test_search_session_uses_production_dispatch

# Child scripts load shared support as the installed unit, like .zshrc: every
# regular support/**/.zsh.?* file in lexical order, never support/cache, and
# the first failed source stops the load with its status.
_test_source_support_mirrors_the_bootstrap() {
  test_make_temp_dir || return
  local support="$TEST_TMP_DIR/root/.zsh.addons/support" output=''
  test_write_file "$support/.zsh.appearance" 'loaded+=(appearance)' || return
  test_write_file "$support/functions/.zsh.pure.entry" 'loaded+=(pure.entry)' || return
  test_write_file "$support/functions/notes.txt" 'loaded+=(notes)' || return
  test_write_file "$support/cache/.zsh.owner.cache" 'loaded+=(cache)' || return
  test_write_file "$support/ui/.zsh.ui.a" 'loaded+=(ui.a); typeset -g ui_global=kept' || return
  test_write_file "$support/ui/.zsh.ui.b" 'loaded+=(ui.b); return 7' || return
  test_write_file "$support/ui/.zsh.ui.c" 'loaded+=(ui.c)' || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    typeset -a loaded=()
    test_source_support "$2"
    print -r -- "status=$? ${(j:|:)loaded} ${ui_global:-lost}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/root") || return
  test_assert_equal 'status=7 appearance|pure.entry|ui.a|ui.b kept' "$output" \
    'test support loader diverged from the bootstrap support set, order or failure status'
}
test_case 'test support loader sources the shipped support set in bootstrap order and stops on failure' \
  _test_source_support_mirrors_the_bootstrap

# A hand-picked UI preamble tests a configuration that never ships. Keep one
# only where a test needs a support unit absent or loaded at a chosen point, or
# unit-tests a few UI entries with their collaborators stubbed, and name that
# subset in a "# Support subset:" comment in the same test function.
# A line is a preamble when it sources a UI unit by path, or loops over UI units
# and sources them, in either the quoted or the plain path spelling.
_test_is_ui_support_preamble() {
  emulate -L zsh -o extended_glob
  [[ $1 == (|*[[:space:]\;])source[[:space:]]*support/ui(/|\"/).zsh.ui.* ||
     $1 == (|*[[:space:]\;])for[[:space:]]*support/ui(/|\"/).zsh.ui.*source* ]]
}

_test_ui_support_preambles_use_the_shared_loader() {
  local file='' line='' trimmed='' offenders=''
  local -i number=0 marked=0
  # Pin both spellings, and the inventory and assertion forms that are not
  # preambles, so the scan cannot quietly narrow.
  for line in \
    'source "$1/.zsh.addons/support/ui/.zsh.ui.zle_picker_loop"' \
    'for c in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.); do source "$c"; done' \
    'for c in "$1"/.zsh.addons/support/ui/.zsh.ui.*; do source "$c"; done'; do
    _test_is_ui_support_preamble "$line" || test_fail "scan missed a UI preamble: $line" || return
  done
  for line in \
    'units+=("$TEST_REPO_ROOT"/.zsh.addons/support/ui/.zsh.ui.*(N.))' \
    '[[ ${functions_source[$f]} == "$1/.zsh.addons/support/ui/.zsh.ui.$owner" ]]'; do
    ! _test_is_ui_support_preamble "$line" || test_fail "scan flagged a non-preamble: $line" || return
  done
  for file in "$TEST_REPO_ROOT"/tests/*_test.zsh(N.); do
    [[ ${file:t} == harness_test.zsh ]] && continue
    number=0 marked=0
    while IFS= read -r line || [[ -n $line ]]; do
      (( ++number ))
      [[ $line == _*'() {' ]] && marked=0
      trimmed=${line#"${line%%[![:space:]]*}"}
      [[ $trimmed == '# Support subset: '?* ]] && marked=1
      (( !marked )) && _test_is_ui_support_preamble "$line" &&
        offenders+=" ${file:t}:$number"
    done < "$file"
  done
  [[ -z $offenders ]] ||
    test_fail "hand-picked UI support without a Support subset comment:$offenders"
}
test_case 'tests load shared UI support through test_source_support unless they name a support subset' \
  _test_ui_support_preambles_use_the_shared_loader

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

# Screen sessions (tests/pty_support.zsh). The helper reads only the trace it
# is given, so these probes need no terminal.
_test_pty_screen_sessions_counts_linearly() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/tests/pty_support.zsh" || exit 91
    local enter=$terminfo[smcup] leave=$terminfo[rmcup] clear=$'\''\e[2J'\'' big=""
    [[ -n $enter && -n $leave ]] || exit 92
    _probe() {
      test_pty_screen_sessions "$2" "$3" 2>> "$HOME/stderr"
      print -r -- "$1:$?:${#reply}:${(Vj:|:)reply}"
    }
    _probe one "a${enter}x${clear}y${leave}b" 1
    _probe two "${enter}x${leave}${enter}y${leave}" 2
    _probe none plain 0
    _probe count "a${enter}x${leave}b" 2
    _probe before "${clear}${enter}x${leave}" 1
    _probe after "${enter}x${leave}${clear}" 1
    _probe nested "${enter}a${enter}b${leave}c${leave}" 1
    _probe unclosed "${enter}a" 1
    _probe stray "${leave}${enter}a${leave}" 1
    _probe extra "${enter}a${leave}b${leave}" 1
    _probe misuse plain x
    # A 37-KB trace, where stripping one marker at a time took seconds.
    big=${(l:12500::x:)}
    local -F started=$EPOCHREALTIME
    test_pty_screen_sessions "${enter}${big}${leave}${big}${enter}${big}${leave}" 2
    print -r -- "big:$?:${#reply}:${#reply[1]}:${#reply[2]}"
    print -r -- "elapsed:$(( EPOCHREALTIME - started ))"
    print -r -- "detail:$(<"$HOME/stderr")"
  ' "$TEST_REPO_ROOT" 2>&1) || { test_fail "screen-session probe failed: $output"; return; }
  local expected='one:0:1:x^[[2Jy
two:0:2:x|y
none:0:0:
count:1:0:
before:1:0:
after:1:0:
nested:1:0:
unclosed:1:0:
stray:1:0:
extra:1:0:
misuse:2:0:
big:0:2:12500:12500'
  test_assert_equal "$expected" "${(F)${(f)output}[1,12]}" 'screen sessions were miscounted' || return
  _test_pty_assert_elapsed "$output" 0 1 'a large trace was not checked in linear time' || return
  test_assert_contains "$output" 'found 1 screen session' 'a wrong count was not reported'
}
test_case 'PTY expectation counts screen sessions in a trace linearly' \
  _test_pty_screen_sessions_counts_linearly

# Picker scripts (tests/picker_support.zsh) stand in for the engine's entry
# points, so these probes drive real views without a terminal.
_test_picker_script_helper() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" || exit 91
    test_source_support "$1" || exit 92
    source "$1/tests/picker_support.zsh" || exit 93
    _probe_collect() {
      _ZLE_PICKER_RESULTS=(a b "c d") _ZLE_PICKER_LABELS=(Alpha Beta "Gamma delta")
      _ZLE_PICKER_RESULT_INDEXES=(1 2 3)
    }
    _probe_view() {
      _ZLE_PICKER_TITLE=$1 _ZLE_PICKER_SUBTITLE="$1 subtitle" _ZLE_PICKER_COLLECTOR=_probe_collect
      _zle_picker_start_focus=${2:-0}
      _zle_picker_loop "" 10 "${5:-1}" 0 "${3:-}" 0 "${4:-0}"
    }
    # An observe function keeps its own names, such as a step counter.
    local -i step=0
    _probe_seen() {
      (( ++step ))
      print -r -- "seen:${#_ZLE_PICKER_RESULTS}:$_ZLE_PICKER_TITLE:$_ZLE_PICKER_EXCLUDE"
    }
    _probe_fail() { return 7; }
    _probe_session() { _zle_ui_view choice _probe_view five; }
    _probe_run() {
      local _ZLE_PICKER_TITLE=six _ZLE_PICKER_SUBTITLE="six subtitle" _ZLE_PICKER_COLLECTOR=_probe_collect
      _zle_picker_run 5
    }
    _probe() {
      local -i result=0
      _zle_ui_view "$2" _probe_view "$1" "${@[3,-1]}" 2>> "$HOME/stderr" || result=$?
      print -r -- "$1:$result:$_ZLE_PICKER_ACCEPTED:$_ZLE_PICKER_SELECTED_VALUE:$_ZLE_PICKER_ACTION:${(j:|:)_ZLE_PICKER_BOOKMARK}:$_ZLE_PICKER_BOOKMARK_FOCUS:${#_ZLE_PICKER_RESULTS}"
    }
    test_picker_script select b -- observe _probe_seen -- select "c d" inspect -- cancel -- \
      observe _probe_fail -- abort -- select a -- cancel -- select zzz
    _probe one choice
    _probe two choice 1 x 1 2
    _probe three reader
    _probe four choice
    _zle_picker_run 10 "" 1 0 _probe_session
    print -r -- "run-abort:$?"
    _probe_run
    print -r -- "run-select:$?:$_ZLE_PICKER_SELECTED_VALUE"
    _probe_run
    print -r -- "run-cancel:$?"
    _probe eight choice
    _probe nine choice
    print -r -- "titles:${(j:|:)TEST_PICKER_TITLES}"
    print -r -- "limits:${(j:|:)TEST_PICKER_LIMITS}"
    print -r -- "starts:${(j:|:)TEST_PICKER_STARTS}"
    print -r -- "steps:$step"
    print -r -- "subtitle:$TEST_PICKER_SUBTITLES[2]"
    print -r -- "labels:${(V)TEST_PICKER_LABELS[1]}"
    print -r -- "detail:$(<"$HOME/stderr")"
  ' "$TEST_REPO_ROOT" 2>&1) || { test_fail "picker script probe failed: $output"; return; }
  local expected='one:0:1:b:select:|2|0:0:0
seen:3:two:x
two:0:1:c d:inspect:|3|0|x|0|1:1:0
three:1:0::select:|1|0:1:0
four:7:0::select::0:0
run-abort:130
run-select:0:a
run-cancel:1
eight:2:0::select::0:0
nine:2:0::select::0:0
titles:one|two|three|four|five|six|six|eight|nine
limits:10|10|10|10|10|5|5|10|10
starts:1|2|1|1|1|1|1|1|1
steps:1
subtitle:two subtitle
labels:Alpha\nBeta\nGamma delta'
  test_assert_equal "$expected" "${(F)${(f)output}[1,16]}" 'scripted views received the wrong outcomes' || return
  test_assert_contains "$output" "not among the view's results" 'an uncollected selection was not reported' || return
  test_assert_contains "$output" 'no step left' 'an exhausted script was not reported'
}
test_case 'picker script helper selects, cancels, aborts and observes views' \
  _test_picker_script_helper
