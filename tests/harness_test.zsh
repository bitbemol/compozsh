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
