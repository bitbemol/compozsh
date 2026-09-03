# Terminal-aware native output and palette contracts.

_test_output_palette_drives_native_git_colors() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    typeset -gA ZSH_OUTPUT_COLORS=(success 123)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    _output_git_color_arguments
    print -r -- "palette:${ZSH_OUTPUT_COLORS[success]}|${ZSH_OUTPUT_COLORS[error]}|${ZSH_OUTPUT_COLORS[match]}"
    print -r -- "wrapper:${+functions[git]}"
    print -r -- "added:${_OUTPUT_GIT_COLOR_CONFIG[(r)color.status.added=*]}"
    print -r -- "removed:${_OUTPUT_GIT_COLOR_CONFIG[(r)color.diff.old=*]}"
    print -r -- "branch:${_OUTPUT_GIT_COLOR_CONFIG[(r)color.branch.current=*]}"
    _output_git_subcommand_uses_color commit
    print -r -- "commit:$?"
    _output_git_subcommand_uses_color clone
    print -r -- "clone:$?"
    _output_git_subcommand_uses_color config || print -r -- "config:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'palette:123|203|199' \
    'output palette replaced a local role or omitted defaults' || return
  test_assert_contains "$output" 'wrapper:1' \
    'Git output wrapper is unavailable' || return
  test_assert_contains "$output" 'added:color.status.added=bold 123' \
    'Git added status does not use the shared success role' || return
  test_assert_contains "$output" 'removed:color.diff.old=203' \
    'Git removed lines do not use the shared error role' || return
  test_assert_contains "$output" 'branch:color.branch.current=bold 123' \
    'Git current branch does not use the shared success role' || return
  test_assert_contains "$output" 'commit:0' \
    'Git commit is missing native color configuration' || return
  test_assert_contains "$output" 'clone:0' \
    'Git clone is missing native color configuration' || return
  test_assert_contains "$output" 'config:1' \
    'Git configuration inspection was incorrectly decorated'
}
test_case 'native Git colors use the customizable semantic output palette' \
  _test_output_palette_drives_native_git_colors

_test_git_wrapper_preserves_plain_delegation_and_status() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/git" $'#!/bin/zsh\nprint -r -- "${(j:|:)@}"\n[[ ${@: -1} == fail ]] && exit 23\nexit 0' || return
  command chmod +x "$fake_bin/git" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    path=("$2" $path)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    git -C /tmp/example status --short
    git status fail
    print -r -- "status:$?"
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_contains "$output" '-C|/tmp/example|status|--short' \
    'non-terminal Git output did not preserve the original argv' || return
  test_assert_contains "$output" 'status|fail' \
    'Git wrapper did not delegate the failing invocation' || return
  test_assert_contains "$output" 'status:23' \
    'Git wrapper did not preserve the underlying exit status'
}
test_case 'Git wrapper leaves non-terminal output byte-compatible' \
  _test_git_wrapper_preserves_plain_delegation_and_status

_test_man_uses_semantic_output_palette() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/man" $'#!/bin/zsh
typeset -i heading=0 warning=0 match=0 selected=0
[[ $LESS_TERMCAP_md == $'"'"'\e[1;38;5;123m'"'"' ]] && heading=1
[[ $LESS_TERMCAP_us == $'"'"'\e[4;38;5;124m'"'"' ]] && warning=1
[[ $LESS_TERMCAP_mb == $'"'"'\e[1;38;5;125m'"'"' ]] && match=1
[[ $LESS_TERMCAP_so == $'"'"'\e[1;38;5;16;48;5;123m'"'"' ]] && selected=1
print -r -- "$heading|$warning|$match|$selected|${(j:|:)@}"' || return
  command chmod +x "$fake_bin/man" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    path=("$2" $path)
    typeset -gA ZSH_OUTPUT_COLORS=(heading 123 warning 124 match 125)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    man git-status
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_equal '1|1|1|1|git-status' "$output" \
    'manual-page styles did not use the semantic output palette'
}
test_case 'manual-page styling shares the semantic output palette' \
  _test_man_uses_semantic_output_palette

_test_output_palette_matches_prompt_semantics() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"; print -r -- "${ZSH_OUTPUT_COLORS[success]}|${ZSH_OUTPUT_COLORS[warning]}|${ZSH_OUTPUT_COLORS[error]}|${ZSH_OUTPUT_COLORS[match]}"' "$TEST_REPO_ROOT") || return
  test_assert_equal '71|221|203|199' "$output" \
    'output palette diverged from the established semantic colors'
}
test_case 'output palette follows established prompt semantics' \
  _test_output_palette_matches_prompt_semantics

_test_output_palette_rejects_malformed_indexes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"; ZSH_OUTPUT_COLORS[success]=999999999999999999999999999999999999; _output_color success 71; print -r -- "fallback:$REPLY"' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal 'fallback:71' "$output" \
    'malformed output color escaped validation or emitted a diagnostic'
}
test_case 'output palette rejects malformed color indexes safely' \
  _test_output_palette_rejects_malformed_indexes
