_test_xcode_refresh_replaces_managed_skill() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"

  test_write_file "$source_dir/swift/SKILL.md" 'new instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'old instructions' || return
  test_write_file "$target_dir/swift/stale.txt" 'remove me' || return
  test_write_file "$target_dir/swift/.xcode-skill-export" 'old-build' || return

  test_run_noninteractive "$home" \
    'source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" >/dev/null || return

  test_assert_equal 'new instructions' "$(<"$target_dir/swift/SKILL.md")" \
    'managed Xcode skill did not receive the new export' || return
  [[ ! -e "$target_dir/swift/stale.txt" ]] ||
    test_fail 'managed Xcode refresh retained a stale file' || return
  test_assert_equal 'new-build' "$(<"$target_dir/swift/.xcode-skill-export")" \
    'managed Xcode skill marker was not refreshed'
}
test_case 'Xcode skill refresh atomically replaces stale managed content' \
  _test_xcode_refresh_replaces_managed_skill

_test_xcode_refresh_rolls_back_partial_copy() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"
  local fake_bin="$TEST_TMP_DIR/bin"

  test_write_file "$source_dir/swift/SKILL.md" 'new instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'old instructions' || return
  test_write_file "$target_dir/swift/.xcode-skill-export" 'old-build' || return
  test_write_file "$fake_bin/cp" \
    $'#!/usr/bin/env zsh\nprint -r -- partial >| "${@[-1]}/partial.txt"\nexit 1' || return
  command chmod +x "$fake_bin/cp" || return

  local output=''
  local -i command_status=0
  output=$(test_run_noninteractive "$home" \
    'path=("$4" $path)
     rehash
     source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" "$fake_bin" 2>&1) ||
    command_status=$?

  (( command_status != 0 )) || test_fail 'partial Xcode skill copy reported success' || return
  test_assert_equal 'old instructions' "$(<"$target_dir/swift/SKILL.md")" \
    'failed Xcode refresh replaced the previous skill' || return
  test_assert_equal 'old-build' "$(<"$target_dir/swift/.xcode-skill-export")" \
    'failed Xcode refresh replaced the previous marker' || return
  [[ ! -e "$target_dir/swift/partial.txt" ]] ||
    test_fail 'failed Xcode refresh polluted the active skill' || return
  test_assert_contains "$output" 'failed to copy swift' \
    'failed Xcode refresh did not report its error'
}
test_case 'failed Xcode skill refresh preserves the previous complete skill' \
  _test_xcode_refresh_rolls_back_partial_copy

_test_xcode_failed_restore_keeps_recovery_backup() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"
  local fake_bin="$TEST_TMP_DIR/bin" count_file="$TEST_TMP_DIR/mv-count"
  local output='' recovery=''
  local -a recoveries=()

  test_write_file "$source_dir/swift/SKILL.md" 'new instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'old instructions' || return
  test_write_file "$target_dir/swift/.xcode-skill-export" 'old-build' || return
  test_write_file "$fake_bin/mv" $'#!/usr/bin/env zsh
integer count=0
[[ -f $FAKE_MV_COUNT ]] && count=$(<$FAKE_MV_COUNT)
(( ++count ))
print -r -- $count >| $FAKE_MV_COUNT
(( count == 1 )) && exec /bin/mv "$@"
exit 1' || return
  command chmod +x "$fake_bin/mv" || return

  output=$(test_run_noninteractive "$home" \
    'path=("$4" $path)
     export FAKE_MV_COUNT=$5
     rehash
     source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" "$fake_bin" \
    "$count_file" 2>&1) || true

  recoveries=("$target_dir"/.xcode-skill-backup.*/previous(N/))
  (( ${#recoveries} == 1 )) ||
    test_fail 'failed Xcode restore deleted its only recovery backup' || return
  recovery=${recoveries[1]}
  test_assert_equal 'old instructions' "$(<"$recovery/SKILL.md")" \
    'Xcode recovery backup does not contain the previous skill' || return
  test_assert_contains "$output" "$recovery" \
    'failed Xcode restore did not print its recovery path'
}
test_case 'failed Xcode rollback retains and reports the previous skill' \
  _test_xcode_failed_restore_keeps_recovery_backup

_test_xcode_install_preserves_unmarked_conflict() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"

  test_write_file "$source_dir/swift/SKILL.md" 'Apple instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'personal instructions' || return

  local output=''
  output=$(test_run_noninteractive "$home" \
    'source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" 2>&1) || true

  test_assert_equal 'personal instructions' "$(<"$target_dir/swift/SKILL.md")" \
    'Xcode installer replaced an unmarked personal skill' || return
  test_assert_contains "$output" 'kept existing personal skill swift' \
    'Xcode installer did not report the preserved conflict'
}
test_case 'Xcode skill installation preserves unmarked personal conflicts' \
  _test_xcode_install_preserves_unmarked_conflict
