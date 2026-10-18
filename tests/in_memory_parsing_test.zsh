# Captured data is parsed in memory. Zsh 5.9 backs here-strings and
# here-documents with temporary files under ${TMPPREFIX:-/tmp/zsh}, so a parse
# through `<<<` writes the data to disk and fails when that directory is
# unwritable or full. Each probe runs twice in one isolated shell, with the
# default TMPPREFIX and with TMPPREFIX inside a missing directory; both runs
# must print the same exact result without diagnostics.

# Runs inside the shell under test.
_in_memory_twice() {
  local probe=$1 default='' missing=''
  default=$("$probe" 2>&1)
  missing=$(TMPPREFIX="$HOME/missing-tmpprefix/zsh"; "$probe" 2>&1)
  print -r -- "$default"
  [[ $missing == "$default" ]] ||
    print -r -- "--- with TMPPREFIX in a missing directory:"$'\n'"$missing"
}

_in_memory_git_repository() {
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  export GIT_AUTHOR_DATE='2026-01-02T03:04:05Z' GIT_COMMITTER_DATE='2026-01-02T03:04:05Z'
  command git init -q -b main "$1" || return
  builtin cd -- "$1" || return
  command git config user.name Fixture
  command git config user.email fixture@example.invalid
  command git config commit.gpgsign false
}

_in_memory_source_git() {
  local unit=''
  for unit in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) \
      "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"; do
    source "$unit" || return
  done
}

# When a here-string could not be created, the filter-override builder once
# succeeded with no overrides, so passive prompt and review status captures ran
# repository-configured filters.
_test_in_memory_repository_filters_stay_disabled() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/in_memory_parsing_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.prompt" && source "$1/.zsh.addons/.zsh.git-review" &&
      _in_memory_source_git "$1" || exit 2
    _in_memory_git_repository "$HOME/repository" || exit 3
    export FILTER_PROBE="$HOME/filter-ran"
    print -r -- "*.txt filter=fixture" > .gitattributes
    print -r -- baseline > tracked.txt
    git add . && git commit -qm base || exit 4
    print -r -- $'"'"'#!/bin/sh\n: > "$FILTER_PROBE"\n/bin/cat'"'"' > "$HOME/filter"
    chmod +x "$HOME/filter" || exit 5
    git config filter.fixture.clean "$HOME/filter" && git config filter.fixture.required true || exit 6
    # Same size, so status must compare content instead of trusting stat data.
    print -r -- "changed!" > tracked.txt
    TMPPREFIX="$HOME/missing-tmpprefix/zsh"
    _prompt_git 2>/dev/null
    print -r -- "prompt: $_PROMPT_GIT_TEXT"
    typeset -ga _GIT_REVIEW_CONFIG=()
    _git_review_prepare "$PWD" 2>/dev/null && _git_review_changes_capture "$PWD" 2>/dev/null
    print -r -- "review: ${(j:|:)_GIT_REVIEW_PATHS}"
    [[ ! -e $FILTER_PROBE ]] || print -r -- "a repository filter ran"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'prompt: main !1 no-upstream
review: tracked.txt' "$output" \
    'passive Git status ran a repository filter when a here-string temporary file was unavailable'
}
test_case 'in-memory parsing: prompt and review never run repository filters without here-string temporary files' \
  _test_in_memory_repository_filters_stay_disabled

# The idioms in engineering/zsh.md#idioms must keep matching the read loops
# they describe, including NUL, Meta (0x83) and invalid bytes in both locales.
_test_in_memory_split_idioms() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    TMPPREFIX="$HOME/zsh"
    compare() {
      local text="" old="" new="" a="" b="" c=""
      local -a fields=()
      for text in "" a $'"'"'a\n'"'"' $'"'"'a\n\nb\n\n'"'"' $'"'"'\0'"'"' $'"'"'a\0'"'"' $'"'"'a\0b'"'"' \
          $'"'"'a\0\0b\0c\0'"'"' $'"'"'\n\0\n\0'"'"' $'"'"'r\x83\xff\\t \0x\ty\0z'"'"' \
          $'"'"'k\0v\0\0k2\0v2\0k3'"'"' $'"'"'1\x002\x003\x004\x005\x006\x007'"'"'; do
        old="" new=""
        while IFS= read -r a; do old+="<$a>"; done <<< "$text"
        for a in "${(@f)text}"; do new+="<$a>"; done
        old+="|" new+="|"
        while IFS= read -r -d "" a; do old+="<$a>"; done <<< "$text"
        fields=("${(@0)text}")
        for a in "${(@)fields[1,-2]}"; do new+="<$a>"; done
        old+="|" new+="|"
        while IFS= read -r -d "" a && IFS= read -r -d "" b && IFS= read -r -d "" c; do old+="<$a,$b,$c>"; done <<< "$text"
        for a b c in "${(@)fields[1,(${#fields}-1)/3*3]}"; do new+="<$a,$b,$c>"; done
        [[ $old == "$new" ]] || print -r -- "$LC_ALL ${(qqqq)text}: ${(qqqq)old} != ${(qqqq)new}"
      done
    }
    compare
    LC_ALL=en_US.UTF-8 compare
    print -r -- compared
  ' 2>&1) || return
  test_assert_equal compared "$output" 'a documented in-memory split no longer matches its here-string read loop'
}
test_case 'in-memory parsing: documented split idioms match here-string read loops record for record' \
  _test_in_memory_split_idioms

_in_memory_prompt_probe() {
  _prompt_git
  print -r -- "${_PROMPT_GIT_TEXT/$(command git rev-parse --short=7 HEAD)/OID}|$_PROMPT_GIT_UPSTREAM_TEXT"
}

_test_in_memory_prompt_git_status() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/in_memory_parsing_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.prompt" && _in_memory_source_git "$1" || exit 2
    _in_memory_git_repository "$HOME/repository" || exit 3
    print -r -- base > tracked
    git add tracked && git commit -qm base && git branch base || exit 4
    print -r -- ahead >> tracked
    git commit -qam ahead && git branch -q -u base || exit 5
    print -r -- stashed >> tracked
    git stash -q || exit 6
    print -r -- staged > staged
    git add staged || exit 7
    print -r -- modified >> tracked
    print -r -- untracked > $'"'"'line\nbreak'"'"'
    _in_memory_twice _in_memory_prompt_probe
    git checkout -q --detach || exit 8
    _in_memory_twice _in_memory_prompt_probe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'main +1 !1 ?1 ≡1 ⇡1|base
@OID +1 !1 ?1 ≡1|' "$output" \
    'prompt Git status depended on a here-string temporary file'
}
test_case 'in-memory parsing: prompt Git status needs no here-string temporary file' \
  _test_in_memory_prompt_git_status

_in_memory_review_changes_probe() {
  local -i index=0
  typeset -ga _GIT_REVIEW_CONFIG=()
  _git_review_prepare "$PWD" || print -r -- 'prepare failed'
  _git_review_changes_capture "$PWD" || print -r -- 'capture failed'
  print -r -- "$_GIT_REVIEW_SUMMARY ${#_GIT_REVIEW_CONFIG}"
  for (( index = 1; index <= ${#_GIT_REVIEW_PATHS}; index++ )); do
    print -r -- "${(qqqq)_GIT_REVIEW_PATHS[index]} $_GIT_REVIEW_KINDS[index] $_GIT_REVIEW_CONTEXTS[index]"
  done
  # A byte-truncated capture can end inside a record: only NUL-terminated
  # records are published, and empty records are skipped.
  _GIT_REVIEW_DATA=$'M  kept\0\0?? also kept\0 M cut-off'
  _git_review_changes_parse
  print -r -- "${(j:|:)_GIT_REVIEW_PATHS}"
}

_test_in_memory_review_changes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/in_memory_parsing_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.git-review" && _in_memory_source_git "$1" || exit 2
    _in_memory_git_repository "$HOME/repository" || exit 3
    git config filter.fixture.clean false
    print -r -- original > tracked
    print -r -- original > $'"'"'tab\tname'"'"'
    git add . && git commit -qm initial || exit 4
    print -r -- staged >> tracked
    git add tracked || exit 5
    print -r -- unstaged >> $'"'"'tab\tname'"'"'
    print -r -- new > $'"'"'new\nline'"'"'
    _in_memory_twice _in_memory_review_changes_probe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal "1 staged · 1 unstaged · 1 untracked · 0 conflicts 6
\$'tab\\tname' unstaged Unstaged M
\$'tracked' staged Staged M
\$'new\\nline' untracked Untracked
kept|also kept" "$output" \
    'Git review working changes depended on a here-string temporary file'
}
test_case 'in-memory parsing: Git review working changes need no here-string temporary file' \
  _test_in_memory_review_changes

_in_memory_review_history_probe() {
  local head='' first='' commit='' index=0
  head=$(command git rev-parse HEAD) first=$(command git rev-parse HEAD~1)
  _git_review_refs_capture "$PWD" || print -r -- 'refs failed'
  for (( index = 1; index <= ${#_GIT_REVIEW_REFS}; index++ )); do
    [[ $_GIT_REVIEW_REF_OIDS[index] == $(command git rev-parse "$_GIT_REVIEW_REFS[index]") ]] ||
      print -r -- "wrong object for $_GIT_REVIEW_REFS[index]"
  done
  print -r -- "${(j:|:)_GIT_REVIEW_REF_LABELS}"
  _git_review_commits_capture "$PWD" "$head" || print -r -- 'commits failed'
  [[ "${(j: :)_GIT_REVIEW_PATHS}" == "$head $first" && $_GIT_REVIEW_PARENTS[1] == "$first" &&
    -z $_GIT_REVIEW_PARENTS[2] ]] || print -r -- 'wrong commit identities'
  for commit in "${_GIT_REVIEW_LABELS[@]}"; do print -r -- "${(qqqq)commit#* · }"; done
  print -r -- "${(j:|:)_GIT_REVIEW_CONTEXTS}|$_GIT_REVIEW_SUMMARY"
  _git_review_commit_files_capture "$PWD" "$head" "$first" || print -r -- 'files failed'
  for (( index = 1; index <= ${#_GIT_REVIEW_PATHS}; index++ )); do
    print -r -- "${(qqqq)_GIT_REVIEW_PATHS[index]} $_GIT_REVIEW_CONTEXTS[index]"
  done
  print -r -- "${_GIT_REVIEW_SUMMARY#* · }"
  # A truncated ref triple is never published.
  _git_review_capture() {
    _GIT_REVIEW_DATA="refs/heads/main"$'\0'commit$'\0'"$head"$'\0\n'
    _GIT_REVIEW_DATA+="refs/heads/cut"$'\0'commit$'\0'"${head[1,20]}"
  }
  _git_review_refs_capture "$PWD" || print -r -- 'stub failed'
  print -r -- "${(j:|:)_GIT_REVIEW_REFS}"
}

_test_in_memory_review_history() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/in_memory_parsing_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.git-review" && _in_memory_source_git "$1" || exit 2
    _in_memory_git_repository "$HOME/repository" || exit 3
    print -r -- original > $'"'"'tab\tname'"'"'
    git add . && git commit -qm $'"'"'first\tsubject'"'"' || exit 4
    print -r -- changed >> $'"'"'tab\tname'"'"'
    print -r -- new > $'"'"'new\nline'"'"'
    print -rn -- $'"'"'\0binary'"'"' > blob
    git add . && git commit -qm "second \\ subject" || exit 5
    git branch feature && git tag light && git tag -a annotated -m note || exit 6
    git update-ref refs/remotes/origin/main HEAD || exit 7
    _in_memory_twice _in_memory_review_history_probe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal "feature · branch|main · branch|origin/main · remote-tracking|annotated · tag|light · tag
\$'second \\\\ subject'
\$'first\\tsubject'
2026-01-02|2026-01-02|local history · read-only
\$'blob' Binary
\$'new\\nline' +1 -0
\$'tab\\tname' +1 -0
first-parent changes · 3 captured files · read-only
refs/heads/main" "$output" \
    'Git review refs, history or committed files depended on a here-string temporary file'
}
test_case 'in-memory parsing: Git review refs history and committed files need no here-string temporary file' \
  _test_in_memory_review_history

_in_memory_branch_probe() {
  local short='' REPLY=''
  _git_recent_branches "$PWD" || print -r -- 'catalog failed'
  print -r -- "$_GIT_RECENT_CURRENT|${(j:|:)_GIT_RECENT_BRANCHES}"
  _git_branch_remote_capture "$PWD" || print -r -- 'remote capture failed'
  print -r -- "${(j:|:)_GIT_BRANCH_REMOTE_VALUES}|${_GIT_BRANCH_REMOTE_NAMES[remote:refs/remotes/origin/fix/remote-only]}"
  _git_branch_inspector_capture "$PWD"
  short=$(command git rev-parse --short main)
  _git_branch_inspect_text main
  print -r -- "${REPLY/$short/OID}"
}

_test_in_memory_branch_catalog() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/in_memory_parsing_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.navigation" && _in_memory_source_git "$1" || exit 2
    _in_memory_git_repository "$HOME/repository" || exit 3
    git commit -q --allow-empty -m $'"'"'tab\tsubject'"'"' || exit 4
    git branch zeta && git branch feature/older && git branch "topic/ünïcode" || exit 5
    git switch -q feature/older && git switch -q main && git switch -q "topic/ünïcode" || exit 6
    git config branch.main.remote origin
    git config branch.main.merge refs/heads/main
    git remote add origin https://example.invalid/origin.git || exit 7
    git update-ref refs/remotes/origin/main HEAD && git update-ref refs/remotes/origin/fix/remote-only HEAD || exit 8
    git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/main || exit 9
    _in_memory_twice _in_memory_branch_probe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'topic/ünïcode|topic/ünïcode|main|feature/older|zeta
remote:refs/remotes/origin/fix/remote-only|fix/remote-only
main
Local branch

Latest commit:
  OID
  tab\tsubject

Upstream:
  origin/main

  Enter switches to this branch.
  Snapshot captured when g opened; no fetch.' "$output" \
    'Git branch catalog, remote fallback or details depended on a here-string temporary file'
}
test_case 'in-memory parsing: Git branch catalog remote fallback and details need no here-string temporary file' \
  _test_in_memory_branch_catalog

_in_memory_worktree_probe() {
  local -i index=0
  _git_worktree_snapshot && _git_worktree_branches || print -r -- "catalog failed: $_GWT_ERROR"
  for (( index = 1; index <= ${#_GWT_PATHS}; index++ )); do
    print -r -- "${_GWT_PATHS[index]/#$HOME/~}|$_GWT_BRANCHES[index]|$_GWT_STATES[index]"
  done
  print -r -- "${(j:|:)_GWT_REFS}"
  _git_worktree_remove_check "$HOME/occupied" && print -r -- removable
  command git -C "$HOME/occupied" update-index --assume-unchanged file
  _git_worktree_remove_check "$HOME/occupied" || print -r -- "$_GWT_ERROR"
  command git -C "$HOME/occupied" update-index --no-assume-unchanged file
}

_test_in_memory_worktree_catalog() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh" && source "$1/tests/git_worktree_test.zsh" || exit 1
    source "$1/tests/in_memory_parsing_test.zsh" || exit 1
    _test_worktree_fixture "$1" || exit 2
    _in_memory_twice _in_memory_worktree_probe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '~/repo|main|
~/occupied|feature/occupied|
feature/available|feature/occupied|main
removable
Sparse, unmerged or assume-unchanged index entries prevent a complete removal check.' "$output" \
    'Git worktree catalogs or removal checks depended on a here-string temporary file'
}
test_case 'in-memory parsing: Git worktree catalogs and removal checks need no here-string temporary file' \
  _test_in_memory_worktree_catalog
