_test_claude_syntax_hook_reports_zsh_errors_only() {
  test_make_temp_dir || return
  local hook="$TEST_REPO_ROOT/.claude/hooks/zsh-syntax.zsh"
  local good="$TEST_TMP_DIR/.zsh.good" bad="$TEST_TMP_DIR/broken.zsh"
  local other="$TEST_TMP_DIR/notes.md" cache_dir="$TEST_TMP_DIR/.zsh.addons/support/cache"
  local output='' result=0

  [[ -f $hook ]] || { test_fail 'syntax hook script is missing'; return 1; }
  test_write_file "$good" 'print -r -- ok' || return
  test_write_file "$bad" 'if true; then' || return
  test_write_file "$other" 'if true; then' || return
  command mkdir -p -- "$cache_dir" || return
  test_write_file "$cache_dir/.zsh.manual.cache" 'if true; then' || return

  output=$(print -r -- "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$good\"}}" |
    /bin/zsh -f "$hook" 2>&1) || result=$?
  test_assert_equal 0 "$result" 'hook rejected a valid Zsh peer' || return
  test_assert_equal '' "$output" 'hook printed output for a valid file' || return

  result=0
  output=$(print -r -- "{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"$bad\"}}" |
    /bin/zsh -f "$hook" 2>&1) || result=$?
  test_assert_equal 2 "$result" 'hook did not block on a Zsh syntax error' || return
  test_assert_contains "$output" 'broken.zsh' 'hook did not name the broken file' || return

  for output in "$other" "$cache_dir/.zsh.manual.cache" "$TEST_TMP_DIR/missing.zsh"; do
    result=0
    print -r -- "{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"$output\"}}" |
      /bin/zsh -f "$hook" >/dev/null 2>&1 || result=$?
    test_assert_equal 0 "$result" "hook checked a non-Zsh or cache file: ${output:t}" || return
  done

  result=0
  print -r -- '{"tool_name":"Edit"}' | /bin/zsh -f "$hook" >/dev/null 2>&1 || result=$?
  test_assert_equal 0 "$result" 'hook failed on input without a file path'
}
test_case 'tooling: Claude syntax hook blocks only on Zsh syntax errors' \
  _test_claude_syntax_hook_reports_zsh_errors_only

_test_claude_settings_are_valid_and_scoped() {
  local settings="$TEST_REPO_ROOT/.claude/settings.json"
  local text=''

  [[ -f $settings ]] || { test_fail 'project Claude settings are missing'; return 1; }
  text="$(<"$settings")"
  /usr/bin/plutil -convert json -o /dev/null -- "$settings" >/dev/null 2>&1 ||
    { test_fail 'project Claude settings are not valid JSON'; return 1; }
  local allow=''
  allow=$(/usr/bin/plutil -extract permissions.allow json -o - -- "$settings") || {
    test_fail 'settings have no permissions.allow list'
    return 1
  }
  allow=${allow//\\\//\/}
  test_assert_equal \
    '["Bash(zsh tests/run.zsh *)","Bash(zsh tests/verify.zsh)","Bash(zsh -fn -- *)"]' \
    "$allow" 'pre-approved commands changed; every zsh grant must end options with --' || return
  local denied=''
  for denied in '~/.zshrc' '~/.zshenv' '~/.zprofile' '~/.zlogin' '~/.zsh_history' \
                '~/.zsh_sessions/**' '~/.zsh.addons/**'; do
    test_assert_contains "$text" "\"Read($denied)\"" \
      "settings do not deny reading $denied" || return
    test_assert_contains "$text" "\"Edit($denied)\"" \
      "settings do not deny editing or redirecting into $denied" || return
  done
  test_assert_contains "$text" '.claude/hooks/zsh-syntax.zsh' \
    'settings do not register the syntax hook' || return
  [[ $text != *bypassPermissions* && $text != *'"Bash"'* && $text != *'"Bash(*)"'* ]] ||
    test_fail 'project settings grant unrestricted shell access'
}
test_case 'tooling: project Claude settings stay valid and narrowly scoped' \
  _test_claude_settings_are_valid_and_scoped
