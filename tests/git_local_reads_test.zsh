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
      for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
      source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
      builtin cd "$repo" || exit 4
      _git_branch_stack_load || exit 5
      _git_branch_inspector_capture "$repo" || exit 6
      [[ ${_ZLE_PICKER_INSPECT_TEXTS[main]} == *"Commit details unavailable"* ]] || exit 7
    else
      source "$1/.zsh.addons/.zsh.tools"
      for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$git_support_component"; done
    source "$1/.zsh.addons/.zsh.navigation"
      builtin cd "$repo" || exit 8
      g --discard-all <<< y > "$HOME/output" 2> "$HOME/error"
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
test_case 'g --discard-all validates missing HEAD locally without promisor fetch or transport' \
  _test_discard_missing_commit_local_only

# A repository-local log.showSignature plus gpg.program is project content: the
# review history, root-commit document, worker exec path and bare g's reflog
# must never run that program or let its output corrupt captured commit IDs.
_test_git_signature_verifier_never_runs() {
  test_make_temp_dir || return
  local output='' exit_status=0
  test_write_file "$TEST_TMP_DIR/bin/verifier" $'#!/bin/sh\nprintf x >> "$HOME/verifier-runs"\necho "gpg: Good signature from Fixture" >&2\nexit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/verifier" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    local repo="$HOME/repository" oid="" body="" runs="" worker=""
    local -a report=()
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" config user.name Fixture
    command git -C "$repo" config user.email fixture@example.invalid
    print -r -- content > "$repo/file"
    command git -C "$repo" add file || exit 2
    command git -C "$repo" -c commit.gpgsign=false commit -qm root || exit 2
    # Rewrite the root commit with a signature header Git will try to verify.
    body=$(command git -C "$repo" cat-file commit HEAD) || exit 3
    body="${body%%$'"'"'\n\n'"'"'*}"$'"'"'\ngpgsig -----BEGIN PGP SIGNATURE-----\n \n fixture\n -----END PGP SIGNATURE-----\n\n'"'"'"${body#*$'"'"'\n\n'"'"'}"$'"'"'\n'"'"'
    oid=$(print -rn -- "$body" | command git -C "$repo" hash-object -t commit -w --stdin) || exit 3
    command git -C "$repo" update-ref refs/heads/main "$oid" || exit 3
    command git -C "$repo" checkout -q -b other && command git -C "$repo" checkout -q main || exit 4
    command git -C "$repo" config gpg.program "$2/verifier"
    command git -C "$repo" config log.showSignature true
    : >| "$HOME/verifier-runs"
    source "$1/.zsh.addons/.zsh.navigation"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/.zsh.git-review"
    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$git_support_component"; done
    typeset -a _GIT_REVIEW_CONFIG=()
    _git_review_commits_capture "$repo" "$oid"
    report+=("commits status=$? rows=${#_GIT_REVIEW_PATHS}")
    _compozsh_git_valid_oid "$_GIT_REVIEW_PATHS[1]" && report+=("valid commit id") || report+=("invalid commit id ${(q+)_GIT_REVIEW_PATHS[1]}")
    runs=$(<"$HOME/verifier-runs"); report+=("verifier runs ${#runs}")
    _git_review_diff_capture "$repo" commit file "$oid" ""
    report+=("document status=$?")
    [[ $_GIT_REVIEW_DATA == "diff --git "* ]] && report+=("document starts with the diff") || report+=("document starts ${(q+)_GIT_REVIEW_DATA%%$'"'"'\n'"'"'*}")
    runs=$(<"$HOME/verifier-runs"); report+=("verifier runs ${#runs}")
    worker=$(_GIT_REVIEW_WORKER_EXEC=1 _git_review_git "$repo" log -1 --format=%H "$oid")
    [[ $worker == "$oid" ]] && report+=("worker exec commit id") || report+=("worker exec ${(q+)worker}")
    runs=$(<"$HOME/verifier-runs"); report+=("verifier runs ${#runs}")
    _git_recent_branches "$repo"
    report+=("branches status=$? ${(j:,:)_GIT_RECENT_BRANCHES}")
    runs=$(<"$HOME/verifier-runs"); report+=("verifier runs ${#runs}")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
commits status=0 rows=1
valid commit id
verifier runs 0
document status=0
document starts with the diff
verifier runs 0
worker exec commit id
verifier runs 0
branches status=0 main,other
verifier runs 0' "status:$exit_status"$'\n'"$output" \
    'a repository-configured signature verifier ran or corrupted a capture'
}
test_case 'Git review and branch navigation never run a repository-configured signature verifier' \
  _test_git_signature_verifier_never_runs
