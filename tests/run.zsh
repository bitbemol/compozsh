#!/usr/bin/env zsh

emulate -LR zsh
setopt PIPE_FAIL

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

zmodload zsh/datetime
typeset -F suite_started=$EPOCHREALTIME
typeset -i passed=0 failed=0 selected=0 index=0
typeset -i test_status=0
typeset name='' function_name=''

for (( index = 1; index <= ${#TEST_CASE_FUNCTIONS}; ++index )); do
  name=${TEST_CASE_NAMES[index]}
  function_name=${TEST_CASE_FUNCTIONS[index]}
  [[ -z $TEST_FILTER || ${name:l} == *"${TEST_FILTER:l}"* ]] || continue
  (( ++selected ))

  (
    setopt ERR_RETURN
    TEST_TMP_DIR=''
    trap 'test_cleanup_temp' EXIT INT TERM
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
