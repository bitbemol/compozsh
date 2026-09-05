_test_compose_native() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/fixtures/compose-native.zsh"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'command composer native help fields live preview resize insertion and cancel restore ZLE' _test_compose_native
