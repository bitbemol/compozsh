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
      source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect_choices"
      source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_git_local"
      source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
      builtin cd "$repo" || exit 4
      _git_branch_stack_load || exit 5
      _git_branch_inspector_capture "$repo" || exit 6
      _git_branch_inspect_text main
      [[ $REPLY == *"Commit details unavailable"* ]] || exit 7
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
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect_choices"
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

# Every explicit-root Git wrapper reaches Git through the shared local-only
# entry: a PATH-shadowed logging git records argv and the GIT_* environment.
# Each record carries the shared set plus the caller's own controls; review,
# worktree and Search reset inherited selectors to the root, the branch read
# keeps them (bare g shadows them first), and the caller's environment survives.
_test_shared_git_entry_wrappers() {
  test_make_temp_dir || return
  local output='' exit_status=0
  test_write_file "$TEST_TMP_DIR/bin/git" '#!/bin/sh
for argument do printf "arg %s\n" "$argument"; done > "$COMPOZSH_TEST_GIT_LOG"
env | LC_ALL=C sort | grep "^GIT_" >> "$COMPOZSH_TEST_GIT_LOG"
exit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH="$2:$PATH"
    local root="$HOME/root" worker="" name=""
    local -a report=() ambient=(GIT_ALTERNATE_OBJECT_DIRECTORIES=/ambient/alternates
      GIT_COMMON_DIR=/ambient/common GIT_DIR=/ambient/git-dir GIT_INDEX_FILE=/ambient/index
      GIT_NAMESPACE=ambient GIT_OBJECT_DIRECTORY=/ambient/objects GIT_WORK_TREE=/ambient/work-tree)
    for name in navigation find git-review git-worktree; do source "$1/.zsh.addons/.zsh.$name" || exit 1; done
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    export "${ambient[@]}" GIT_OPTIONAL_LOCKS=1 GIT_NO_LAZY_FETCH=0 GIT_TERMINAL_PROMPT=1 GIT_ALLOW_PROTOCOL=file
    _GIT_REVIEW_CONFIG=(-c filter.fixture.clean=)
    _shared_git_check() {
      local label=$1 policy=$2 tail=$3 line="" joined="" setting=""
      local -a arguments=() environment=() missing=()
      shift 3
      [[ -f $HOME/log.$label ]] || { report+=("$label: no Git call"); return; }
      for line in "${(@f)$(<$HOME/log.$label)}"; do
        if [[ $line == "arg "* ]]; then arguments+=("${line#arg }"); else environment+=("$line"); fi
      done
      joined="|${(j:|:)arguments}|"
      for setting in --no-pager --no-replace-objects "-C|$root" "-c|core.fsmonitor=false" \
          "-c|core.untrackedCache=false" "-c|core.hooksPath=/dev/null" "-c|log.showSignature=false" \
          GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL= "$@"; do
        if [[ $setting == GIT_* ]]; then
          (( ${environment[(Ie)$setting]} )) || missing+=("$setting")
        else
          [[ $joined == *"|$setting|"* ]] || missing+=("${setting//|/ }")
        fi
      done
      [[ $joined == *"|$tail|" ]] || missing+=("trailing ${tail//|/ }")
      for setting in "${ambient[@]}"; do
        if [[ $policy == root ]]; then
          (( ${#${(M)environment:#${setting%%=*}=*}} == 0 )) || missing+=("reset ${setting%%=*}")
        else
          (( ${environment[(Ie)$setting]} )) || missing+=("inherited ${setting%%=*}")
        fi
      done
      (( ${#missing} )) && report+=("$label: missing ${(j:, :)missing}") || report+=("$label: ok")
    }
    export COMPOZSH_TEST_GIT_LOG=$HOME/log.review
    _git_review_git "$root" status --porcelain
    _shared_git_check review root "status|--porcelain" "-c|filter.fixture.clean=" \
      GIT_LITERAL_PATHSPECS=1 GIT_GLOB_PATHSPECS=0 GIT_NOGLOB_PATHSPECS=0 GIT_ICASE_PATHSPECS=0
    export COMPOZSH_TEST_GIT_LOG=$HOME/log.review-worker
    worker=$(_GIT_REVIEW_WORKER_EXEC=1 _git_review_git "$root" log -1; print -rn -- returned)
    [[ -z $worker ]] && report+=("review worker replaced its process") || report+=("review worker $worker")
    _shared_git_check review-worker root "log|-1" "-c|filter.fixture.clean=" \
      GIT_LITERAL_PATHSPECS=1 GIT_GLOB_PATHSPECS=0 GIT_NOGLOB_PATHSPECS=0 GIT_ICASE_PATHSPECS=0
    export COMPOZSH_TEST_GIT_LOG=$HOME/log.worktree
    _git_worktree_git "$root" worktree list --porcelain
    _shared_git_check worktree root "worktree|list|--porcelain" GIT_LITERAL_PATHSPECS=1 \
      "-c|maintenance.auto=false" "-c|gc.auto=0" "-c|submodule.recurse=false" \
      "-c|fetch.recurseSubmodules=false" "-c|checkout.guess=false" "-c|branch.autoSetupMerge=false"
    export COMPOZSH_TEST_GIT_LOG=$HOME/log.branch
    _git_branch_read "$root" for-each-ref refs/heads/
    _shared_git_check branch inherit "for-each-ref|refs/heads/" "-c|maintenance.auto=false" "-c|gc.auto=0"
    export COMPOZSH_TEST_GIT_LOG=$HOME/log.find
    _file_search_git "$root" ls-files -z
    _shared_git_check find root "ls-files|-z"
    [[ $GIT_DIR == /ambient/git-dir && $GIT_NAMESPACE == ambient && $GIT_OPTIONAL_LOCKS == 1 &&
       $GIT_NO_LAZY_FETCH == 0 && $GIT_ALLOW_PROTOCOL == file && ${+GIT_LITERAL_PATHSPECS} == 0 ]] &&
      report+=("caller environment kept") || report+=("caller environment changed")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
review: ok
review worker replaced its process
review-worker: ok
worktree: ok
branch: ok
find: ok
caller environment kept' "status:$exit_status"$'\n'"$output" \
    'an explicit-root Git wrapper lost the shared local-only environment or flags'
}
test_case 'shared Git entry gives every wrapper the same local-only environment and read flags' \
  _test_shared_git_entry_wrappers

# The prompt, filter discovery and guarded discard reach Git through the same
# entry with the inherit policy: every call, from the prompt's status and
# metadata reads to discard's validation, cleanup, restore and verification,
# carries the shared set and keeps the caller's chosen repository selectors.
# The logging git answers just enough for each flow to run to completion.
_test_shared_git_entry_inherit_callers() {
  test_make_temp_dir || return
  local output='' exit_status=0
  test_write_file "$TEST_TMP_DIR/bin/git" '#!/bin/sh
count=0
[ -f "$COMPOZSH_TEST_GIT_LOGS/count" ] && read -r count < "$COMPOZSH_TEST_GIT_LOGS/count"
count=$((count + 1))
printf "%s\n" "$count" > "$COMPOZSH_TEST_GIT_LOGS/count"
{ for argument do printf "arg %s\n" "$argument"; done; env | LC_ALL=C sort | grep "^GIT_"; } > "$COMPOZSH_TEST_GIT_LOGS/call.$count"
case " $* " in
  *" config "*) exit 1 ;;
  *" --show-toplevel "*) printf "%s\n" "$COMPOZSH_TEST_GIT_ROOT" ;;
  *" --absolute-git-dir "*) printf "%s\n" "$COMPOZSH_TEST_GIT_ROOT/.git" ;;
  *" --verify "*) printf "%s\n" 0123456789abcdef0123456789abcdef01234567 ;;
  *" --porcelain=v2 "*) printf "# branch.oid 0123456789abcdef0123456789abcdef01234567\n# branch.head main\n" ;;
  *" --porcelain=v1 "*) [ -e "$COMPOZSH_TEST_GIT_LOGS/cleaned" ] || printf " M file\n" ;;
  *" clean "*) : > "$COMPOZSH_TEST_GIT_LOGS/cleaned" ;;
esac
exit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH="$2:$PATH" COMPOZSH_TEST_GIT_LOGS="$HOME/logs" COMPOZSH_TEST_GIT_ROOT="$HOME/root"
    local root="$HOME/root" name="" line="" label="" setting="" joined="" count=""
    local -i index=0 found=0
    local -a report=() arguments=() environment=() missing=() ambient=(
      GIT_ALTERNATE_OBJECT_DIRECTORIES=/ambient/alternates GIT_COMMON_DIR=/ambient/common
      GIT_DIR=/ambient/git-dir GIT_INDEX_FILE=/ambient/index GIT_NAMESPACE=ambient
      GIT_OBJECT_DIRECTORY=/ambient/objects GIT_WORK_TREE=/ambient/work-tree)
    command mkdir -p -- "$COMPOZSH_TEST_GIT_LOGS" "$root/.git" || exit 1
    for name in prompt navigation tools; do source "$1/.zsh.addons/.zsh.$name" || exit 1; done
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    builtin cd "$root" || exit 1
    export "${ambient[@]}" GIT_OPTIONAL_LOCKS=1 GIT_NO_LAZY_FETCH=0 GIT_TERMINAL_PROMPT=1 GIT_ALLOW_PROTOCOL=file
    _prompt_git
    report+=("prompt $_PROMPT_GIT_TEXT")
    _tools_git_discard_all <<< y > /dev/null 2>&1
    report+=("discard status=$?")
    count=$(<$COMPOZSH_TEST_GIT_LOGS/count)
    [[ $count == <1-99> ]] || exit 2
    for (( index = 1; index <= count; ++index )); do
      arguments=() environment=() missing=()
      for line in "${(@f)$(<$COMPOZSH_TEST_GIT_LOGS/call.$index)}"; do
        if [[ $line == "arg "* ]]; then arguments+=("${line#arg }"); else environment+=("$line"); fi
      done
      found=${arguments[(i)(config|status|rev-parse|clean|restore)]}
      label="${arguments[found]-} ${arguments[found+1]-}"
      joined="|${(j:|:)arguments}|"
      for setting in --no-pager --no-replace-objects "-C|$root" "-c|core.fsmonitor=false" \
          "-c|core.untrackedCache=false" "-c|core.hooksPath=/dev/null" "-c|log.showSignature=false" \
          GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL= "${ambient[@]}"; do
        if [[ $setting == GIT_* ]]; then
          (( ${environment[(Ie)$setting]} )) || missing+=("${setting%%=*}")
        else
          [[ $joined == *"|$setting|"* ]] || missing+=("${setting//|/ }")
        fi
      done
      (( ${#missing} )) && report+=("${label%%=0*}: missing ${(j:, :)missing}") ||
        report+=("${label%%=0*}: ok")
    done
    [[ $GIT_DIR == /ambient/git-dir && $GIT_WORK_TREE == /ambient/work-tree &&
       $GIT_OPTIONAL_LOCKS == 1 && $GIT_NO_LAZY_FETCH == 0 && $GIT_TERMINAL_PROMPT == 1 &&
       $GIT_ALLOW_PROTOCOL == file ]] &&
      report+=("caller environment kept") || report+=("caller environment changed")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
prompt main no-upstream
discard status=0
config --null: ok
status --porcelain=v2: ok
rev-parse --absolute-git-dir: ok
rev-parse --show-toplevel: ok
rev-parse --verify: ok
rev-parse --absolute-git-dir: ok
config --null: ok
status --porcelain=v1: ok
rev-parse --show-toplevel: ok
rev-parse --verify: ok
rev-parse --absolute-git-dir: ok
config --null: ok
status --porcelain=v1: ok
clean -fdq: ok
restore --source: ok
status --porcelain=v1: ok
caller environment kept' "status:$exit_status"$'\n'"$output" \
    'a prompt, filter-discovery or discard Git call lost the shared local-only set or inherited selectors'
}
test_case 'shared Git entry gives prompt, filter discovery and discard the same local-only set with inherited selectors' \
  _test_shared_git_entry_inherit_callers

# Support installs as a unit, but a peer loaded without the shared entry fails
# closed: no wrapper, prompt read, filter discovery or discard runs Git, and
# none carries an inline copy of the controls.
_test_shared_git_entry_missing_fails_closed() {
  test_make_temp_dir || return
  local output='' exit_status=0
  test_write_file "$TEST_TMP_DIR/bin/git" '#!/bin/sh
printf "%s\n" "$*" >> "$HOME/git-calls"
exit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH="$2:$PATH"
    local name="" worker=""
    local -a report=()
    # Support subset: everything except the shared local-only Git entry.
    for name in navigation find git-review git-worktree prompt tools; do source "$1/.zsh.addons/.zsh.$name" || exit 1; done
    for name in impure.compozsh_capture_bounded impure.compozsh_git_filter_config \
        pure.compozsh_git_filter_overrides impure.compozsh_git_operation; do
      source "$1/.zsh.addons/support/functions/.zsh.$name" || exit 1
    done
    (( ! ${+functions[_compozsh_git_local]} )) || exit 2
    _git_review_git "$HOME" status; report+=("review $?")
    worker=$(_GIT_REVIEW_WORKER_EXEC=1 _git_review_git "$HOME" status; print -rn -- "returned $?")
    report+=("review worker $worker")
    _git_worktree_git "$HOME" worktree list; report+=("worktree $?")
    _git_branch_read "$HOME" for-each-ref; report+=("branch $?")
    _file_search_git "$HOME" ls-files -z; report+=("find $?")
    builtin cd "$HOME" || exit 3
    _compozsh_git_filter_config "$HOME" clean; report+=("filter $?")
    GIT_DIR=$HOME _prompt_git; report+=("prompt $? ${_PROMPT_GIT_TEXT:-none}")
    _tools_git_discard_all < /dev/null > "$HOME/discard-output" 2>&1
    report+=("discard $?: $(<$HOME/discard-output)")
    [[ -e $HOME/git-calls ]] && report+=("Git ran: $(<$HOME/git-calls)") || report+=("Git never ran")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
review 2
review worker returned 2
worktree 2
branch 2
find 2
filter 2
prompt 1 none
discard 1: g --discard-all: shared Git safety support is unavailable; nothing was discarded
Git never ran' "status:$exit_status"$'\n'"$output" \
    'a wrapper or caller ran Git without the shared local-only entry'
}
test_case 'shared Git entry missing leaves every wrapper, the prompt and discard failing closed' \
  _test_shared_git_entry_missing_fails_closed

# The system git shim. When PATH selects /usr/bin/git, the shared entry may run
# the Git that shim would launch directly, but only after the real
# /usr/bin/codesign proves Apple signed that exact file as com.apple.git, and
# only while the file's identity is unchanged. The resolver seam
# (_compozsh_git_local_find) supplies each candidate path here; the signature
# check is never stubbed. A refused candidate must never run: the script writes
# a marker, and an echo copy would print its arguments instead of the exec path
# that /usr/bin/git reports.
_test_git_shim_apple_git() {
  REPLY=$(command env -i PATH=/usr/bin:/bin HOME="$TEST_TMP_DIR/home" \
    /usr/bin/xcrun --find git 2>/dev/null) && [[ $REPLY == /* ]] &&
    command /usr/bin/codesign --verify --strict \
      -R '=anchor apple and identifier "com.apple.git"' -- "$REPLY" >/dev/null 2>&1
}

_test_git_shim_refuses_untrusted() {
  test_make_temp_dir || return
  local output='' exit_status=0
  test_write_file "$TEST_TMP_DIR/script/git" $'#!/bin/sh\n: > "$HOME/script-ran"\necho fake' || return
  command chmod +x "$TEST_TMP_DIR/script/git" || return
  command mkdir -p -- "$TEST_TMP_DIR/adhoc" "$TEST_TMP_DIR/apple" || return
  command cp -- /bin/echo "$TEST_TMP_DIR/adhoc/git" || return
  command cp -- /bin/echo "$TEST_TMP_DIR/apple/git" || return
  command /usr/bin/codesign -s - -f -- "$TEST_TMP_DIR/adhoc/git" >/dev/null 2>&1 || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH=/usr/bin:/bin
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    source "$1/.zsh.addons/.zsh.tools" || exit 1
    local shim="" ran="" candidate=""
    local -a report=()
    shim=$(command /usr/bin/git -C "$HOME" --exec-path) || exit 2
    _compozsh_git_local_find() { REPLY=$GIT_SHIM_CANDIDATE; }
    for candidate in script adhoc apple; do
      _tools_refresh
      GIT_SHIM_CANDIDATE=$2/$candidate/git
      _compozsh_git_local resolve
      report+=("$candidate: resolve $? direct ${_COMPOZSH_GIT_LOCAL_BINARY[2]:-none}")
      ran=$(_compozsh_git_local inherit "$HOME" -- --exec-path 2>&1)
      [[ $ran == "$shim" ]] && report+=("$candidate: /usr/bin/git ran") ||
        report+=("$candidate: ran ${(q+)ran}")
    done
    [[ -e $HOME/script-ran ]] && report+=("unsigned script ran") || report+=("unsigned script never ran")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
script: resolve 1 direct none
script: /usr/bin/git ran
adhoc: resolve 1 direct none
adhoc: /usr/bin/git ran
apple: resolve 1 direct none
apple: /usr/bin/git ran
unsigned script never ran' "status:$exit_status"$'\n'"$output" \
    'the git shim resolver accepted or ran an unsigned, ad-hoc signed or non-Git binary'
}
test_case 'git shim refuses unsigned, ad-hoc signed and Apple non-Git binaries without running them' \
  _test_git_shim_refuses_untrusted

# A verified copy of Apple's Git runs directly (its exec path follows its own
# location). Appending a byte or swapping a script into its place changes the
# recorded identity, so the very next call runs /usr/bin/git, and the next
# resolve point re-verifies and refuses it. Needs an Apple-signed Git.
_test_git_shim_identity_recheck() {
  test_make_temp_dir || return
  local output='' exit_status=0 apple_git=''
  _test_git_shim_apple_git || {
    print -u2 -r -- '      not applicable here: no Apple-signed Git behind /usr/bin/git'
    return 0
  }
  apple_git=$REPLY
  command mkdir -p -- "$TEST_TMP_DIR/tampered/bin" "$TEST_TMP_DIR/swapped/bin" || return
  command cp -- "$apple_git" "$TEST_TMP_DIR/tampered/bin/git" || return
  command cp -- "$apple_git" "$TEST_TMP_DIR/swapped/bin/git" || return
  test_write_file "$TEST_TMP_DIR/fake-git" $'#!/bin/sh\n: > "$HOME/fake-ran"\necho fake' || return
  command chmod +x "$TEST_TMP_DIR/fake-git" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH=/usr/bin:/bin
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    source "$1/.zsh.addons/.zsh.tools" || exit 1
    local shim="" ran="" name=""
    local -a report=()
    shim=$(command /usr/bin/git -C "$HOME" --exec-path) || exit 2
    _compozsh_git_local_find() { REPLY=$GIT_SHIM_CANDIDATE; }
    for name in tampered swapped; do
      _tools_refresh
      GIT_SHIM_CANDIDATE=$2/$name/bin/git
      _compozsh_git_local resolve; report+=("$name: verified $?")
      ran=$(_compozsh_git_local inherit "$HOME" -- --exec-path 2>&1)
      [[ $ran == "$2/$name/libexec/git-core" ]] && report+=("$name: ran directly") ||
        report+=("$name: ran ${(q+)ran}")
      if [[ $name == tampered ]]; then
        print -rn -- x >> "$GIT_SHIM_CANDIDATE" || exit 3
      else
        command mv -f -- "$2/fake-git" "$GIT_SHIM_CANDIDATE" || exit 3
      fi
      ran=$(_compozsh_git_local inherit "$HOME" -- --exec-path 2>&1)
      [[ $ran == "$shim" ]] && report+=("$name: /usr/bin/git ran") || report+=("$name: ran ${(q+)ran}")
      _compozsh_git_local resolve
      report+=("$name: reverified $? direct ${_COMPOZSH_GIT_LOCAL_BINARY[2]:-none}")
      ran=$(_compozsh_git_local inherit "$HOME" -- --exec-path 2>&1)
      [[ $ran == "$shim" ]] && report+=("$name: /usr/bin/git ran") || report+=("$name: ran ${(q+)ran}")
    done
    [[ -e $HOME/fake-ran ]] && report+=("swapped script ran") || report+=("swapped script never ran")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
tampered: verified 0
tampered: ran directly
tampered: /usr/bin/git ran
tampered: reverified 1 direct none
tampered: /usr/bin/git ran
swapped: verified 0
swapped: ran directly
swapped: /usr/bin/git ran
swapped: reverified 1 direct none
swapped: /usr/bin/git ran
swapped script never ran' "status:$exit_status"$'\n'"$output" \
    'the git shim memo outlived a tampered or swapped binary'
}
test_case 'git shim runs a verified Apple Git directly and falls back once it is tampered with or swapped' \
  _test_git_shim_identity_recheck

# Resolution is per shell and keyed by every selector the shim honors: the same
# selectors reuse the answer (a refusal included), a changed exported
# DEVELOPER_DIR, TOOLCHAINS or SDKROOT resolves again, a subshell never
# resolves (its memo would die with it), compozsh --refresh forgets the answer,
# and a Git chosen elsewhere on PATH is never resolved or replaced. The probe
# seam reports a developer directory throughout, so only selectors vary.
_test_git_shim_resolution_keys() {
  test_make_temp_dir || return
  local output='' exit_status=0
  test_write_file "$TEST_TMP_DIR/script/git" $'#!/bin/sh\n: > "$HOME/path-git-ran"\necho fake' || return
  command chmod +x "$TEST_TMP_DIR/script/git" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH=/usr/bin:/bin
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    source "$1/.zsh.addons/.zsh.tools" || exit 1
    local -a report=()
    : > "$HOME/finds"
    GIT_SHIM_CANDIDATE=$2/script/git
    _compozsh_developer_dir() { REPLY=/fixture/Developer; }
    _compozsh_git_local_find() { print -r -- find >> "$HOME/finds"; REPLY=$GIT_SHIM_CANDIDATE; }
    _shim_step() {
      local -a finds=("${(@f)$(<$HOME/finds)}")
      report+=("$1 $2 finds ${#${(@)finds:#}}")
    }
    _compozsh_git_local resolve; _shim_step first $?
    _compozsh_git_local resolve; _shim_step "same selectors" $?
    export DEVELOPER_DIR=$HOME/developer
    _compozsh_git_local resolve; _shim_step DEVELOPER_DIR $?
    _compozsh_git_local resolve; _shim_step "DEVELOPER_DIR again" $?
    export TOOLCHAINS=fixture
    _compozsh_git_local resolve; _shim_step TOOLCHAINS $?
    export SDKROOT=$HOME/sdk
    _compozsh_git_local resolve; _shim_step SDKROOT $?
    _tools_refresh
    ( _compozsh_git_local resolve ); _shim_step "subshell after refresh" $?
    _compozsh_git_local resolve; _shim_step "parent after refresh" $?
    export PATH=$2/script:/usr/bin:/bin
    _compozsh_git_local resolve; _shim_step "PATH git" $?
    _compozsh_git_local inherit "$HOME" -- --version > /dev/null 2>&1
    [[ -e $HOME/path-git-ran ]] && report+=("PATH git ran") || report+=("PATH git did not run")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
first 1 finds 1
same selectors 1 finds 1
DEVELOPER_DIR 1 finds 2
DEVELOPER_DIR again 1 finds 2
TOOLCHAINS 1 finds 3
SDKROOT 1 finds 4
subshell after refresh 1 finds 4
parent after refresh 1 finds 5
PATH git 1 finds 5
PATH git ran' "status:$exit_status"$'\n'"$output" \
    'the git shim resolver ignored a selector, PATH, a subshell or refresh'
}
test_case 'shared Git entry resolves the system git shim once per shell and honors its selectors, PATH and refresh' \
  _test_git_shim_resolution_keys

# End to end with the real resolver: the prompt resolves once in its own shell,
# and every prompt Git read, all inside command substitutions, runs Apple's Git
# directly. Trace2 records SDKROOT only for runs launched through the shim,
# which adds it. Needs an Apple-signed Git.
_test_git_shim_prompt_direct() {
  test_make_temp_dir || return
  local output='' exit_status=0
  _test_git_shim_apple_git || {
    print -u2 -r -- '      not applicable here: no Apple-signed Git behind /usr/bin/git'
    return 0
  }
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH=/usr/bin:/bin GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    local repo="$HOME/repository" direct="" shimmed=""
    local -a report=() lines=()
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid \
      -c commit.gpgsign=false commit --allow-empty -qm fixture || exit 1
    source "$1/.zsh.addons/.zsh.prompt" || exit 1
    source "$1/.zsh.addons/.zsh.tools" || exit 1
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    : > "$HOME/finds"
    functions[_test_real_find]=$functions[_compozsh_git_local_find]
    _compozsh_git_local_find() { print -r -- find >> "$HOME/finds"; _test_real_find "$@"; }
    builtin cd "$repo" || exit 2
    export GIT_TRACE2_ENV_VARS=SDKROOT GIT_TRACE2_EVENT=$HOME/trace
    _prompt_git; report+=("prompt $_PROMPT_GIT_TEXT")
    _prompt_git; report+=("prompt $_PROMPT_GIT_TEXT")
    unset GIT_TRACE2_ENV_VARS GIT_TRACE2_EVENT
    lines=("${(@f)$(<$HOME/finds)}"); report+=("resolved ${#${(@)lines:#}} time")
    [[ ${_COMPOZSH_GIT_LOCAL_BINARY[2]-} == "$2" ]] && report+=("direct binary is xcrun answer") ||
      report+=("direct binary ${(q+)_COMPOZSH_GIT_LOCAL_BINARY[2]-}")
    lines=("${(@f)$(<$HOME/trace)}")
    report+=("Git runs ${#${(@M)lines:#*\"event\":\"start\"*}}, through the shim ${#${(@M)lines:#*\"param\":\"SDKROOT\"*}}")
    direct=$(_compozsh_git_local inherit "$repo" -- --version; _compozsh_git_local inherit "$repo" -- config --get core.bare)
    shimmed=$(command /usr/bin/git -C "$repo" --version; command /usr/bin/git -C "$repo" config --get core.bare)
    [[ -n $direct && $direct == "$shimmed" ]] && report+=("output matches /usr/bin/git") ||
      report+=("output differs: ${(q+)direct} vs ${(q+)shimmed}")
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$REPLY" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
prompt main no-upstream
prompt main no-upstream
resolved 1 time
direct binary is xcrun answer
Git runs 5, through the shim 0
output matches /usr/bin/git' "status:$exit_status"$'\n'"$output" \
    'the prompt did not run the verified Apple Git directly'
}
test_case 'git shim lets the prompt run the Apple Git behind /usr/bin/git directly with identical output' \
  _test_git_shim_prompt_direct

# Without Apple's developer tools, /usr/bin/git and /usr/bin/xcrun make macOS
# offer to install them. Passive reads (the prompt's status, its filter
# discovery and the shim resolve, and Search's default provider) ask the
# developer-directory probe first and start neither when it finds none; a Git
# elsewhere on PATH still runs, and with a developer directory the launcher
# runs as before. The probe seam (_compozsh_developer_dir) stands in
# for the machine's state, the xcrun seam records each find, Git's trace
# records every launcher-started Git and a PATH Git records its own calls.
# A PATH link to /usr/bin/git is the launcher too. A recording stand-in can't
# play one (a link that resolves to /usr/bin/git runs it), so the linked rows
# ask only the entry's decisions, which run nothing even where the gate misses
# the link: `available` (which the prompt and Search obey, as the first row
# shows) and `resolve`, which leaves a link to the launcher (no xcrun find)
# with or without tools. The real probe follows an exported DEVELOPER_DIR, an
# Xcode bundle's Contents/Developer included, to the launcher's
# libxcrun.dylib.
_test_git_launcher_without_developer_tools() {
  test_make_temp_dir || return
  local output='' exit_status=0
  command mkdir -p -- "$TEST_TMP_DIR/link" || return
  command ln -s /usr/bin/git "$TEST_TMP_DIR/link/git" || return
  test_write_file "$TEST_TMP_DIR/bin/git" '#!/bin/sh
printf "%s\n" "$*" >> "$HOME/path-git"
case " $* " in
  *" config "*) exit 1 ;;
  *" --porcelain=v2 "*) printf "# branch.oid 0123456789abcdef0123456789abcdef01234567\n# branch.head path-git\n" ;;
  *" --is-inside-work-tree "*) printf "true\n" ;;
  *" --absolute-git-dir "*) printf "%s/.git\n" "$PWD" ;;
esac
exit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH=/usr/bin:/bin GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    local repo="$HOME/repository" developer=none name=""
    local -a report=()
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid \
      -c commit.gpgsign=false commit --allow-empty -qm fixture || exit 1
    for name in prompt find tools; do source "$1/.zsh.addons/.zsh.$name" || exit 1; done
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    functions[_test_real_probe]=$functions[_compozsh_developer_dir]
    _compozsh_developer_dir() { [[ $developer != none ]] || return 1; REPLY=$developer; }
    _compozsh_git_local_find() { print -r -- find >> "$HOME/finds"; return 1; }
    _passive_row() {
      local -x GIT_TRACE2_EVENT=$HOME/trace
      local -a lines=()
      local resolved=0 provider="" started=0
      : > "$HOME/finds"; : > "$HOME/path-git"; : > "$HOME/trace"
      _tools_refresh
      builtin cd "$repo" || exit 2
      _prompt_git
      _compozsh_git_local resolve; resolved=$?
      _file_search_default_provider "$repo"; provider=$REPLY
      lines=("${(@f)$(<$HOME/finds)}")
      report+=("$1: prompt ${_PROMPT_GIT_TEXT:-none}, Search $provider, resolve $resolved, xcrun finds ${#${(@)lines:#}}")
      lines=("${(@f)$(<$HOME/trace)}")
      started="${#${(@M)lines:#*\"event\":\"start\"*}}"
      (( started )) && report+=("$1: launcher Git ran") || report+=("$1: launcher Git never ran")
      [[ -s $HOME/path-git ]] && report+=("$1: PATH Git ran") || report+=("$1: PATH Git never ran")
    }
    _linked_row() {
      local available=0 resolved=0
      local -a lines=()
      : > "$HOME/finds"
      [[ ${commands[git]-} == "$2/git" && ${commands[git]:A} == /usr/bin/git ]] || exit 4
      _compozsh_git_local available; available=$?
      _compozsh_git_local resolve; resolved=$?
      lines=("${(@f)$(<$HOME/finds)}")
      report+=("$1: available $available, resolve $resolved, xcrun finds ${#${(@)lines:#}}")
    }
    _passive_row "no tools"
    PATH=$2:/usr/bin:/bin _passive_row "no tools, PATH Git"
    PATH=$3:/usr/bin:/bin _linked_row "no tools, linked launcher" "$3"
    developer=/fixture/Developer _passive_row "tools"
    developer=/fixture/Developer PATH=$3:/usr/bin:/bin _linked_row "tools, linked launcher" "$3"
    command mkdir -p -- "$HOME/developer/usr/lib" "$HOME/Fixture.app/Contents/Developer/usr/lib" \
      "$HOME/empty" || exit 3
    : > "$HOME/developer/usr/lib/libxcrun.dylib"
    : > "$HOME/Fixture.app/Contents/Developer/usr/lib/libxcrun.dylib"
    for name in developer Fixture.app empty missing; do
      report+=("$(export DEVELOPER_DIR=$HOME/$name; REPLY=""
        _test_real_probe; print -rn -- "probe $name: status $? ${${REPLY#$HOME/}:-none}")")
    done
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" "$TEST_TMP_DIR/link" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
no tools: prompt none, Search local, resolve 1, xcrun finds 0
no tools: launcher Git never ran
no tools: PATH Git never ran
no tools, PATH Git: prompt path-git no-upstream, Search git, resolve 1, xcrun finds 0
no tools, PATH Git: launcher Git never ran
no tools, PATH Git: PATH Git ran
no tools, linked launcher: available 1, resolve 1, xcrun finds 0
tools: prompt main no-upstream, Search git, resolve 1, xcrun finds 1
tools: launcher Git ran
tools: PATH Git never ran
tools, linked launcher: available 0, resolve 1, xcrun finds 0
probe developer: status 0 developer
probe Fixture.app: status 0 Fixture.app/Contents/Developer
probe empty: status 1 none
probe missing: status 1 none' "status:$exit_status"$'\n'"$output" \
    'a passive Git read started Apple'\''s launcher or xcrun without developer tools'
}
test_case 'passive Git reads never start the launcher or xcrun without developer tools' \
  _test_git_launcher_without_developer_tools

# Only on macOS is /usr/bin/git Apple's launcher; elsewhere it is an ordinary
# Git. With the platform seam (OSTYPE, as the runtime gate reads it) set to
# Linux and no developer directory, the prompt's Git summary and Search's
# default provider still run /usr/bin/git; the Darwin row is the control that
# keeps the gate. The direct-run seam (_compozsh_git_local_direct) hands the
# entry a recording stand-in in place of /usr/bin/git and the xcrun seam fails,
# so neither a real Git nor xcrun runs, and the fixture repository is files.
_test_git_launcher_gate_is_darwin_only() {
  test_make_temp_dir || return
  local output='' exit_status=0
  test_write_file "$TEST_TMP_DIR/bin/git" '#!/bin/sh
printf "%s\n" "$*" >> "$HOME/stand-in"
case " $* " in
  *" config "*) exit 1 ;;
  *" --porcelain=v2 "*) printf "# branch.oid 0123456789abcdef0123456789abcdef01234567\n# branch.head stand-in\n" ;;
  *" --is-inside-work-tree "*) printf "true\n" ;;
  *" --absolute-git-dir "*) printf "%s/.git\n" "$PWD" ;;
esac
exit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  test_write_file "$TEST_TMP_DIR/home/repository/.git/HEAD" 'ref: refs/heads/main' || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export PATH=/usr/bin:/bin
    local repo="$HOME/repository" stand_in="$2/git" name=""
    local -a report=()
    for name in prompt find tools; do source "$1/.zsh.addons/.zsh.$name" || exit 1; done
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    [[ ${commands[git]-} == /usr/bin/git ]] || exit 2
    _compozsh_developer_dir() { return 1; }
    _compozsh_git_local_find() { return 1; }
    _compozsh_git_local_direct() { REPLY=$stand_in; }
    _platform_row() {
      local OSTYPE=$1 provider="" ran=""
      : > "$HOME/stand-in"
      _tools_refresh
      builtin cd "$repo" || exit 3
      _prompt_git
      _file_search_default_provider "$repo"; provider=$REPLY
      [[ -s $HOME/stand-in ]] && ran=ran || ran="never ran"
      report+=("$1: prompt ${_PROMPT_GIT_TEXT:-none}, Search $provider, /usr/bin/git $ran")
    }
    _platform_row darwin25.0
    _platform_row linux-gnu
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
darwin25.0: prompt none, Search local, /usr/bin/git never ran
linux-gnu: prompt stand-in no-upstream, Search git, /usr/bin/git ran' \
    "status:$exit_status"$'\n'"$output" \
    'outside macOS a passive Git read skipped /usr/bin/git without developer tools'
}
test_case 'passive Git reads still run /usr/bin/git outside macOS without developer tools' \
  _test_git_launcher_gate_is_darwin_only
