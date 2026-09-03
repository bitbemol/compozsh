# A missing promisor object must remain unavailable: inspection cannot fetch it.
# The synthetic remote helper only records invocation and fails; no transport runs.
_test_git_missing_object_reads() {
  test_make_temp_dir || return
  local mode=$1 output=''
  test_write_file "$TEST_TMP_DIR/bin/git-remote-fixture" $'#!/bin/sh\n: > "$GIT_PROBE"\nexit 1' || return
  command chmod +x "$TEST_TMP_DIR/bin/git-remote-fixture" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    export PATH="$2:$PATH" GIT_PROBE="$HOME/transport-invoked"
    local repo="$HOME/repository" oid="" result=0
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" config user.name Fixture
    command git -C "$repo" config user.email fixture@example.invalid
    command git -C "$repo" -c commit.gpgsign=false commit --allow-empty -qm fixture || exit 2
    oid=$(command git -C "$repo" rev-parse HEAD)
    command git -C "$repo" config remote.origin.url fixture::unavailable
    command git -C "$repo" config remote.origin.promisor true
    command git -C "$repo" config remote.origin.partialclonefilter blob:none
    command git -C "$repo" config protocol.fixture.allow always
    command rm -- "$repo/.git/objects/${oid[1,2]}/${oid[3,-1]}" || exit 3
    export GIT_NO_LAZY_FETCH=0 GIT_ALLOW_PROTOCOL=fixture GIT_TERMINAL_PROMPT=1
    export GIT_TRACE="$HOME/git-trace"
    if [[ $3 == navigation ]]; then
      source "$1/.zsh.addons/.zsh.navigation"
      source "$1/.zsh.addons/support/.zsh.matching"
      builtin cd "$repo" || exit 4
      _git_branch_stack_load || exit 5
      _git_branch_inspector_capture "$repo" || exit 6
      [[ ${_ZLE_PICKER_INSPECT_TEXTS[main]} == *"Commit details unavailable"* ]] || exit 7
    else
      source "$1/.zsh.addons/.zsh.tools"
      builtin cd "$repo" || exit 8
      git-discard-all <<< y > "$HOME/output" 2> "$HOME/error"
      result=$?
      (( result != 0 )) && [[ $(<"$HOME/error") == *"no commit to restore"* ]] || exit 9
    fi
    [[ ! -e "$GIT_PROBE" && $(<"$HOME/git-trace") != *"fetch origin"* ]] || {
      print -u2 -- "local Git inspection attempted a promisor fetch"
      exit 10
    }
    [[ $GIT_NO_LAZY_FETCH == 0 && $GIT_ALLOW_PROTOCOL == fixture &&
       $GIT_TERMINAL_PROMPT == 1 ]] || exit 11
    print local
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" "$mode") || return
  test_assert_equal local "$output"
}

_test_navigation_missing_commit_local_only() { _test_git_missing_object_reads navigation; }
test_case 'branch navigation captures missing-commit metadata without promisor fetch or transport' \
  _test_navigation_missing_commit_local_only

_test_discard_missing_commit_local_only() { _test_git_missing_object_reads discard; }
test_case 'git-discard-all validates missing HEAD locally without promisor fetch or transport' \
  _test_discard_missing_commit_local_only
