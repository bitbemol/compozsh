_test_mkcd_contract() {
  test_make_temp_dir || return
  local target="$TEST_TMP_DIR/new/nested" output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" \
    'source "$1/.zsh.addons/.zsh.tools"; mkcd "$2"; print -r -- "$PWD|${PWD:P}"' \
    "$TEST_REPO_ROOT" "$target") || return
  test_assert_equal "$target|${target:P}" "$output" \
    'mkcd did not create and enter the requested directory'
}
test_case 'mkcd creates and enters exactly one requested directory' \
  _test_mkcd_contract

_test_cpdir_contract() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" target="$TEST_TMP_DIR/path with spaces"
  local output='' copied='' copied_size=''
  command mkdir -p "$fake_bin" "$target" || return
  test_write_file "$fake_bin/pbcopy" $'#!/bin/zsh\nIFS= read -r -d \'\' value\nprint -rn -- "$value" >| "$HOME/clipboard"\n' || return
  command chmod +x "$fake_bin/pbcopy" || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    PATH="$2"
    rehash
    source "$1/.zsh.addons/.zsh.tools"
    builtin cd "$3" || exit
    cpdir
  ' "$TEST_REPO_ROOT" "$fake_bin" "$target") || return
  copied=$(<"$TEST_TMP_DIR/home/clipboard") || return
  copied_size=$(command wc -c < "$TEST_TMP_DIR/home/clipboard") || return
  copied_size=${copied_size//[[:space:]]/}

  test_assert_equal "$target" "$copied" \
    'cpdir did not copy the exact logical working directory' || return
  test_assert_equal "${#target}" "$copied_size" \
    'cpdir appended bytes such as a trailing newline' || return
  test_assert_equal "Copied ${target} to the clipboard." "$output" \
    'cpdir did not confirm the copied directory'
}
test_case 'cpdir copies the current directory without a trailing newline' \
  _test_cpdir_contract

_test_cpdir_missing_clipboard() {
  test_make_temp_dir || return
  local empty_bin="$TEST_TMP_DIR/empty-bin" output='' exit_status=0
  command mkdir -p "$empty_bin" || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    PATH="$2"
    rehash
    source "$1/.zsh.addons/.zsh.tools"
    cpdir
  ' "$TEST_REPO_ROOT" "$empty_bin" 2>&1) || exit_status=$?

  (( exit_status != 0 )) || {
    test_fail 'cpdir succeeded without a clipboard command'
    return
  }
  test_assert_contains "$output" 'pbcopy is unavailable' \
    'cpdir omitted its missing-clipboard diagnostic'
}
test_case 'cpdir fails clearly when the macOS clipboard is unavailable' \
  _test_cpdir_missing_clipboard

_test_git_discard_all_scope() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repository" output=''
  command mkdir -p "$repo" || return
  command git -C "$repo" init -q || return
  command git -C "$repo" config user.name 'Zsh Tests' || return
  command git -C "$repo" config user.email 'zsh-tests.invalid@example.invalid' || return
  test_write_file "$repo/.gitignore" $'ignored/\n' || return
  test_write_file "$repo/tracked.txt" 'baseline' || return
  command git -C "$repo" add .gitignore tracked.txt || return
  command git -C "$repo" commit -qm baseline || return
  test_write_file "$repo/tracked.txt" 'changed' || return
  test_write_file "$repo/untracked.txt" 'temporary' || return
  test_write_file "$repo/ignored/keep.txt" 'preserve' || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.tools"
    builtin cd "$2" || exit
    git-discard-all <<< y >/dev/null 2>&1 || exit
    [[ -e untracked.txt ]]; untracked_exists=$(( !$? ))
    [[ -e ignored/keep.txt ]]; ignored_exists=$(( !$? ))
    print -r -- "$(<tracked.txt)|$untracked_exists|$ignored_exists"
  ' "$TEST_REPO_ROOT" "$repo") || return
  test_assert_equal 'baseline|0|1' "$output" \
    'git-discard-all changed data outside its documented scope'
}
test_case 'git-discard-all restores tracked data and preserves ignored files' \
  _test_git_discard_all_scope

_test_git_discard_all_refuses_without_commit() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repository" output='' exit_status=0
  command mkdir -p "$repo" || return
  command git -C "$repo" init -q || return
  test_write_file "$repo/untracked.txt" 'keep me' || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.tools"
    builtin cd "$2" || exit
    git-discard-all
  ' "$TEST_REPO_ROOT" "$repo" 2>&1) || exit_status=$?
  (( exit_status != 0 )) || {
    test_fail 'git-discard-all succeeded in a repository without a commit'
    return
  }
  test_assert_contains "$output" 'no commit to restore' \
    'missing no-commit refusal diagnostic' || return
  [[ -f "$repo/untracked.txt" ]] ||
    test_fail 'refused discard removed an untracked file'
}
test_case 'git-discard-all refuses repositories without a restorable commit' \
  _test_git_discard_all_refuses_without_commit

_test_prompt_refresh_invalidates_memory_only() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    typeset -gA _PROMPT_RUNTIME_VERSION_CACHE=(one value)
    typeset -gA _PROMPT_GIT_DIR_CACHE=(two value)
    typeset -gi _GREP_SUPPORTS_COLOR=1
    typeset -g _GREP_COLOR_BINARY=/usr/bin/grep
    source "$1/.zsh.addons/.zsh.tools"
    prompt-refresh
    print -r -- "${#_PROMPT_RUNTIME_VERSION_CACHE}|${#_PROMPT_GIT_DIR_CACHE}|$_GREP_SUPPORTS_COLOR|${#_GREP_COLOR_BINARY}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '0|0|-1|0' "$output" \
    'prompt-refresh did not invalidate all documented in-memory caches'
}
test_case 'prompt-refresh clears runtime, Git, and output capability caches' \
  _test_prompt_refresh_invalidates_memory_only
