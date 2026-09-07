# Shared Git mechanics retain caller policies and reject unsafe override argv.
_test_shared_git_filter_overrides() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_git_filter_overrides" || exit 1
    local names=$'"'"'filter.alpha.clean\0filter.alpha.process\0filter.beta.required\0'"'"'
    local -a reply=()
    _compozsh_git_filter_overrides "$names" clean || exit 2
    (( ${#reply} == 12 )) && [[ $reply[2] == filter.alpha.clean= &&
      $reply[12] == filter.beta.required=false ]] || exit 3
    _compozsh_git_filter_overrides "$names" restore || exit 4
    (( ${#reply} == 16 )) && [[ $reply[4] == filter.alpha.smudge= ]] || exit 5
    _compozsh_git_filter_overrides $'"'"'filter.foo=bar.clean\0'"'"' clean && exit 6
    names=""
    for index in {1..682}; do names+="filter.driver${index}.clean"$'"'"'\0'"'"'; done
    _compozsh_git_filter_overrides "$names" clean || exit 7
    (( ${#reply} == 4092 )) || exit 8
    names+=$'"'"'filter.overflow.clean\0'"'"'
    _compozsh_git_filter_overrides "$names" clean && exit 9
    (( ${#reply} <= 4096 )) || exit 10
    names=""
    for index in {1..512}; do names+="filter.driver${index}.smudge"$'"'"'\0'"'"'; done
    _compozsh_git_filter_overrides "$names" restore || exit 11
    (( ${#reply} == 4096 )) || exit 12
    names+=$'"'"'filter.overflow.smudge\0'"'"'
    _compozsh_git_filter_overrides "$names" restore && exit 13
    (( ${#reply} == 4096 )) || exit 14
    print safe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal safe "$output"
}
test_case 'shared Git filter override builder deduplicates preserves smudge policy and bounds safe argv' _test_shared_git_filter_overrides

_test_shared_git_bounded_capture() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded" || exit 1
    fixture() { print -rn -- "$1"; return "$2"; }
    local -a reply=()
    local literal=$'"'"'a\0b\n\n'"'"'
    _compozsh_capture_bounded 32 fixture "$literal" 1 || exit 2
    [[ $reply[1] == "$literal" && $reply[2] == complete && $reply[3] == 1 ]] || exit 3
    _compozsh_capture_bounded 8 fixture 123456 0 || exit 4
    [[ $reply[1] == 123456 && $reply[2] == complete && $reply[3] == 0 ]] || exit 5
    _compozsh_capture_bounded 8 fixture 12345678901234567890 0 || exit 6
    [[ $reply[1] == 12345678 && $reply[2] == truncated ]] || exit 7
    _compozsh_capture_bounded 32 fixture "" 2 || exit 8
    [[ -z $reply[1] && $reply[2] == complete && $reply[3] == 2 ]] || exit 9
    _compozsh_capture_bounded 999999999999999999999 fixture "" 0 && exit 10
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'shared Git bounded capture preserves NUL newlines exit status and caller-visible truncation' _test_shared_git_bounded_capture

_test_shared_git_operation_state() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_git_operation" || exit 1
    local root="$HOME/metadata" REPLY=""
    command mkdir -p "$root/sequencer" "$root/rebase-merge"
    _compozsh_git_operation "$root" 1
    [[ $REPLY == rebase ]] || exit 2
    : > "$root/MERGE_HEAD"
    _compozsh_git_operation "$root" 1
    [[ $REPLY == merge ]] || exit 3
    command rm "$root/MERGE_HEAD"
    command rmdir "$root/rebase-merge"
    _compozsh_git_operation "$root" 0
    [[ -z $REPLY ]] || exit 4
    _compozsh_git_operation "$root" 1
    [[ $REPLY == cherry-pick/revert ]] || exit 5
    print state
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal state "$output"
}
test_case 'shared Git operation observation preserves marker precedence and sequencer policy' _test_shared_git_operation_state

_test_shared_git_ambiguous_filter_consumers() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    export FILTER_PROBE="$HOME/filter-ran"
    local repo="$HOME/repository" result=0
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" config user.name Fixture
    command git -C "$repo" config user.email fixture@example.invalid
    print -r -- "file filter=foo=bar" > "$repo/.gitattributes"
    print -r -- base > "$repo/file"
    command git -C "$repo" add . || exit 2
    command git -C "$repo" -c commit.gpgsign=false commit -qm fixture || exit 3
    command git -C "$repo" config "filter.foo=bar.clean" '"'"': > "$FILTER_PROBE"; /bin/cat'"'"'
    command git -C "$repo" config "filter.foo=bar.required" true
    print -r -- changed >> "$repo/file"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.tools"
    for component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) \
      "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$component"; done
    builtin cd "$repo" || exit 4
    _prompt_git || :
    [[ ! -e $FILTER_PROBE ]] || exit 5
    _tools_git_discard_all <<< n > "$HOME/output" 2> "$HOME/error"
    result=$?
    (( result != 0 )) && [[ ! -e $FILTER_PROBE &&
      $(<"$HOME/error") == *"could not validate repository content filters"* &&
      $(<"$repo/file") == $'"'"'base\nchanged'"'"' ]] || exit 6
    print refused
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refused "$output"
}
test_case 'shared Git safety refuses ambiguous filter drivers in prompt and discard before configured execution' _test_shared_git_ambiguous_filter_consumers

_test_shared_git_support_fallback() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-worktree"
    local provider_called=0
    _git_review_git() { provider_called=1; }
    _git_worktree_git() { provider_called=1; }
    _GIT_REVIEW_DATA=stale _GWT_DATA=stale
    _git_review_capture /fixture && exit 1
    _git_worktree_capture /fixture && exit 2
    (( ! provider_called )) && [[ -z $_GIT_REVIEW_DATA && -z $_GWT_DATA &&
      $_GWT_ERROR == *"support is unavailable"* ]] || exit 3
    # Loading dependencies later makes the same already-loaded callers usable.
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded" || exit 4
    _git_review_git() { print -rn -- captured; }
    _git_worktree_git() { print -rn -- captured; }
    _git_review_capture /fixture && [[ $_GIT_REVIEW_DATA == captured ]] || exit 5
    _git_worktree_capture /fixture && [[ $_GWT_DATA == captured ]] || exit 6
    print deferred
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal deferred "$output"
}
test_case 'shared Git capture refuses missing support and resumes after deferred peer loading' _test_shared_git_support_fallback
