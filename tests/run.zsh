#!/usr/bin/env zsh

emulate -LR zsh
setopt PIPE_FAIL

# Git fixtures also run in this process. An inherited selector such as GIT_DIR
# could redirect them into a real repository, and global or system
# configuration could run the operator's hooks or signing programs.
unset -m 'GIT_*'
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

typeset -gr TESTS_DIR=${0:A:h}
typeset -gr TEST_REPO_ROOT=${TESTS_DIR:h}

source "$TESTS_DIR/support.zsh" || exit 1

(( $# <= 1 )) || {
  print -u2 -r -- 'usage: zsh tests/run.zsh [description-filter]'
  exit 2
}
typeset -gr TEST_FILTER=${1:-}

typeset test_file=''
for test_file in "$TESTS_DIR"/*_test.zsh(N.); do
  source "$test_file" || exit 1
done
unset test_file

(( ${#TEST_CASE_FUNCTIONS} )) || {
  print -u2 -r -- 'No tests registered.'
  exit 1
}

zmodload zsh/datetime zsh/system
typeset -F suite_started=$EPOCHREALTIME
typeset -i passed=0 failed=0 selected=0 index=0
typeset -i test_status=0
typeset name='' function_name=''

for (( index = 1; index <= ${#TEST_CASE_FUNCTIONS}; ++index )); do
  name=${TEST_CASE_NAMES[index]}
  function_name=${TEST_CASE_FUNCTIONS[index]}
  [[ -z $TEST_FILTER || ${name:l} == *"${TEST_FILTER:l}"* ]] || continue
  (( ++selected ))

  # A signalled test cleans up, then dies of the same signal: a trap-level exit
  # would wait for a blocking read or nested shell, and returning would continue
  # the test without its directory. The runner reports it as failed.
  (
    setopt ERR_RETURN
    TEST_TMP_DIR=''
    trap 'test_cleanup_temp' EXIT
    trap 'test_cleanup_temp; builtin trap - INT; builtin kill -INT ${sysparams[pid]}' INT
    trap 'test_cleanup_temp; builtin trap - TERM; builtin kill -TERM ${sysparams[pid]}' TERM
    "$function_name"
  )
  test_status=$?
  if (( test_status == 0 )); then
    print -r -- "PASS  $name"
    (( ++passed ))
  else
    print -r -- "FAIL  $name"
    (( ++failed ))
  fi
done

(( selected )) || {
  print -u2 -r -- "No tests match: ${(qqq)TEST_FILTER}"
  exit 2
}

typeset -F elapsed_ms=$(( (EPOCHREALTIME - suite_started) * 1000.0 ))
print
printf '%d passed, %d failed · %.1f ms\n' $passed $failed $elapsed_ms
(( failed == 0 ))
