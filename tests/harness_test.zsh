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
