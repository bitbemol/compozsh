# Read-only review uses disposable repositories and real Git, never user data.
_test_git_review_capture() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    [[ -f "$1/.zsh.addons/.zsh.git-review" ]] || { print -u2 "missing Git review capability"; exit 1; }
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -q
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print -r -- original > tracked
    print -r -- literal > "odd*[x]"
    git add .
    git commit -qm initial
    print -r -- staged >> tracked
    git add tracked
    print -r -- unstaged >> tracked
    print -r -- changed >> "odd*[x]"
    print -r -- private > untracked
    before=$(git hash-object .git/index)
    typeset -a _GIT_REVIEW_CONFIG=()
    _git_review_prepare "$PWD" || exit 2
    _git_review_changes_capture "$PWD" || exit 3
    [[ ${_GIT_REVIEW_KINDS[(Ie)staged]} -gt 0 && ${_GIT_REVIEW_KINDS[(Ie)unstaged]} -gt 0 && ${_GIT_REVIEW_KINDS[(Ie)untracked]} -gt 0 ]] || exit 4
    (( ${#_GIT_REVIEW_PATHS} == 4 )) || exit 5
    [[ ${_GIT_REVIEW_LABELS[(Ie)tracked]} -gt 0 && ${_GIT_REVIEW_CONTEXTS[(Ie)Staged M]} -gt 0 ]] || exit 13
    typeset -a _NAVIGATION_PICKER_VALUES=() _NAVIGATION_PICKER_LABELS=() _NAVIGATION_PICKER_INDEXES=() _NAVIGATION_PICKER_SEARCH_LABELS=()
    typeset -A _ZLE_PICKER_CONTEXTS=() _ZLE_PICKER_INSPECT_TEXTS=()
    _git_review_rows
    _navigation_picker_collect unstaged 10
    (( ${#_ZLE_PICKER_RESULTS} == 2 )) || exit 14
    _git_review_diff_capture "$PWD" staged tracked || exit 6
    [[ $_GIT_REVIEW_DATA == *+staged* && $_GIT_REVIEW_DATA != *+unstaged* ]] || exit 7
    _git_review_diff_capture "$PWD" unstaged "odd*[x]" || exit 8
    [[ $_GIT_REVIEW_DATA == *+changed* && $_GIT_REVIEW_DATA != *unstaged* ]] || exit 9
    _git_review_diff_capture "$PWD" untracked untracked || exit 10
    [[ $_GIT_REVIEW_DATA == *+private* ]] || exit 11
    [[ $(git hash-object .git/index) == "$before" && $(<untracked) == private ]] || exit 12
    print captured
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal captured "$output"
}
test_case 'Git review separates staged and unstaged snapshots and preserves literal targets without writes' _test_git_review_capture

_test_git_review_history() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    [[ -f "$1/.zsh.addons/.zsh.git-review" ]] || { print -u2 "missing commit review capability"; exit 1; }
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -q
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    name=$'\''notes\nwith tab\tcafé 東京.swift'\''
    print -r -- initial > "$name"
    git add .
    git commit -qm "literal %F{red} subject"
    oid=$(git rev-parse HEAD)
    typeset -a _GIT_REVIEW_CONFIG=()
    _git_review_prepare "$PWD" || exit 2
    _git_review_commits_capture "$PWD" "$oid" || exit 3
    [[ ${_GIT_REVIEW_PATHS[1]} == "$oid" && ${_GIT_REVIEW_LABELS[1]} == *"literal %F{red}"* ]] || exit 4
    _git_review_commit_files_capture "$PWD" "$oid" "" || exit 5
    [[ ${_GIT_REVIEW_PATHS[1]} == "$name" && ${_GIT_REVIEW_CONTEXTS[1]} == *+1* ]] || exit 6
    _git_review_diff_capture "$PWD" commit "$name" "$oid" "" || exit 7
    [[ $_GIT_REVIEW_DATA == *+initial* ]] || exit 8
    print history
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal history "$output"
}
test_case 'Git review reads root commits and newline-bearing paths from immutable commit IDs' _test_git_review_history

_test_git_review_render() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    [[ -f "$1/.zsh.addons/.zsh.git-review" ]] || { print -u2 "missing diff review capability"; exit 1; }
    source "$1/.zsh.addons/.zsh.git-review"
    _GIT_REVIEW_DATA=$'\''diff --git a/file b/file\n--- a/file\n+++ b/file\n@@ -1 +1 @@ title\n-old\n+new\e[2J\n@@ -20 +20 @@ other\n-before\n+after\n'\''
    _GIT_REVIEW_TRUNCATED=0
    _git_review_document_parse
    (( ${#_ZLE_PICKER_DOCUMENT_LINES} == 6 )) || exit 2
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY == *+2* && $_GIT_REVIEW_DOCUMENT_SUMMARY == *-2* ]] || exit 3
    _ZLE_PICKER_INSPECT_TEXTS=(one ready)
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_INSPECT_KEY=""
    _zle_picker_inspect_prepare one 60
    [[ ${_ZLE_PICKER_INSPECT_ROLES[(Ie)success]} -gt 0 && ${_ZLE_PICKER_INSPECT_ROLES[(Ie)error]} -gt 0 ]] || exit 4
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} != *$'\''\e'\''* ]] || exit 5
    _ZLE_PICKER_RESULTS=(one) _ZLE_PICKER_LABELS=(file)
    _ZLE_PICKER_INSPECT_FOCUS=1
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=70 LINES=30
    _zle_picker_render "" 1
    (( _ZLE_PICKER_INSPECT_WIDTH == 69 && !_ZLE_PICKER_INDEXES_VISIBLE )) || exit 6
    # The branch chooser has review options; the document workspace does not.
    _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=git
    _zle_picker_guide_render 119
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Ctrl-X"* && ${(F)_ZLE_PICKER_DISPLAY} != *"Spotlight"* ]] || exit 7
    print rendered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal rendered "$output"
}
test_case 'Git review renders safe semantic diff colors and a narrow full-width document' _test_git_review_render

_test_git_review_safety() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo/parent"
    cd "$HOME/repo"
    git init -q
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print -r -- before > parent/file
    print -r -- before > fifo
    print -r -- before > ":(glob)literal"
    git add . && git commit -qm initial || exit 1
    print -r -- after >> parent/file
    print -r -- after >> ":(glob)literal"
    print -r -- "* filter=fixture diff=fixture" > .gitattributes
    for key in filter.fixture.clean filter.fixture.process diff.fixture.command diff.fixture.textconv core.fsmonitor; do
      git config "$key" "touch $HOME/ran-helper"
    done
    git config filter.fixture.required true
    before=$(git hash-object --no-filters .git/index)
    config_before=$(git hash-object --no-filters .git/config)
    _git_review_prepare "$PWD" || exit 2
    _git_review_changes_capture "$PWD" || exit 3
    _git_review_diff_capture "$PWD" unstaged ":(glob)literal" || exit 4
    [[ $_GIT_REVIEW_DATA == *+after* && ! -e "$HOME/ran-helper" ]] || exit 5
    [[ $(git hash-object --no-filters .git/index) == "$before" && $(git hash-object --no-filters .git/config) == "$config_before" ]] || exit 6
    mv parent "$HOME/outside"
    ln -s "$HOME/outside" parent
    _git_review_diff_capture "$PWD" unstaged parent/file && exit 7
    mv fifo "$HOME/saved"
    mkfifo fifo
    _git_review_diff_capture "$PWD" unstaged fifo && exit 8
    _git_review_diff_capture "$PWD" staged ../outside/file && exit 9
    _git_review_commit_files_capture "$PWD" --output=unwanted "" && exit 10
    _git_review_diff_capture "$PWD" commit fifo --output=unwanted "" && exit 11
    [[ ! -e unwanted && ! -e "$HOME/ran-helper" ]] || exit 12
    print safe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal safe "$output"
}
test_case 'Git review suppresses configured executables and rejects escaping paths special files and option-like revisions' _test_git_review_safety

_test_git_review_limits() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    _git_review_git() { print -rn -- "${(pl:270000::x:)}"; }
    _git_review_capture fixture || exit 1
    (( _GIT_REVIEW_TRUNCATED && ${#_GIT_REVIEW_DATA} == 262144 )) || exit 2
    _git_review_prepare fixture && exit 3
    _git_review_git() { return 7; }
    _git_review_capture fixture && exit 4
    [[ -z $_GIT_REVIEW_DATA ]] || exit 5
    _git_review_git() { return 0; }
    _git_review_capture fixture || exit 6
    [[ -z $_GIT_REVIEW_DATA ]] || exit 7
    _git_review_git() {
      local -i i=0
      for (( i=1; i<=999; ++i )); do print -rn -- " M file-$i"$'\''\0'\''; done
      print -rn -- "MM last"$'\''\0'\''
    }
    _git_review_changes_capture fixture || exit 8
    (( ${#_GIT_REVIEW_PATHS} == 1000 && _GIT_REVIEW_TRUNCATED )) || exit 9
    [[ $_GIT_REVIEW_SUMMARY == *partial* ]] || exit 10
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'Git review bounds retained bytes and rows and distinguishes failed captures from empty success' _test_git_review_limits

_test_git_review_snapshot() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -q
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    _git_review_prepare "$PWD" || exit 1
    _git_review_changes_capture "$PWD" || exit 2
    (( ${#_GIT_REVIEW_PATHS} == 0 )) || exit 3
    print -r -- one > file
    print -rn -- $'\''binary\0data'\'' > binary
    git add . && git commit -qm initial || exit 4
    first=$(git rev-parse HEAD)
    print -r -- two >> file
    git add file && git commit -qm second || exit 5
    second=$(git rev-parse HEAD)
    _git_review_commits_capture "$PWD" "$second" || exit 6
    [[ ${_GIT_REVIEW_PARENTS[1]} == "$first" ]] || exit 7
    print -r -- three >> file
    git add file && git commit -qm third || exit 8
    _git_review_commit_files_capture "$PWD" "$second" "$first" || exit 9
    [[ ${_GIT_REVIEW_PATHS[1]} == file && ${_GIT_REVIEW_CONTEXTS[1]} == "+1 -0" ]] || exit 10
    _git_review_diff_capture "$PWD" commit file "$second" "$first" || exit 11
    [[ $_GIT_REVIEW_DATA == *+two* && $_GIT_REVIEW_DATA != *three* ]] || exit 12
    _git_review_commit_files_capture "$PWD" "$first" "" || exit 13
    [[ ${_GIT_REVIEW_CONTEXTS[(Ie)Binary]} -gt 0 ]] || exit 14
    _git_review_diff_capture "$PWD" commit binary "$first" "" || exit 15
    [[ $_GIT_REVIEW_DATA == *"Binary files"* && $_GIT_REVIEW_DATA != *"binary"$'\''\0'\''* ]] || exit 16
    _git_review_changes_capture "$HOME/missing" && exit 17
    (( ${#_GIT_REVIEW_PATHS} == 0 )) || exit 18
    git replace "$first" "$second" || exit 19
    _git_review_diff_capture "$PWD" commit file "$first" "" || exit 20
    [[ $_GIT_REVIEW_DATA == *+one* && $_GIT_REVIEW_DATA != *+two* ]] || exit 21
    print snapshot
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal snapshot "$output"
}
test_case 'Git review handles unborn and binary repositories and keeps commit snapshots stable when HEAD moves' _test_git_review_snapshot

_test_git_review_code_fidelity() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.git-review"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n--- removed text\n+++ added text\n'\''
    _git_review_document_parse
    _ZLE_PICKER_INSPECT_TEXTS=(one ready)
    _zle_picker_inspect_prepare one 60
    [[ $_ZLE_PICKER_INSPECT_ROLES[2] == error && $_ZLE_PICKER_INSPECT_ROLES[3] == success ]] || exit 1
    local original="+value =          another value;"
    _ZLE_PICKER_DOCUMENT_KEY=two
    _ZLE_PICKER_DOCUMENT_LINES=("$original") _ZLE_PICKER_DOCUMENT_ROLES=(success)
    _zle_picker_inspect_prepare two 12
    [[ ${(j::)_ZLE_PICKER_INSPECT_LINES} == "$original" ]] || exit 2
    _GIT_REVIEW_DATA=$'\''@@ -1 +1,180 @@\n'\''
    repeat 180; do _GIT_REVIEW_DATA+=$'\''+new line\n'\''; done
    _git_review_document_parse
    (( ${#_ZLE_PICKER_DOCUMENT_LINES} == 181 )) || exit 3
    [[ $_ZLE_PICKER_DOCUMENT_LINES[-1] == *180* && $_GIT_REVIEW_DOCUMENT_SUMMARY == *+180* ]] || exit 4
    print faithful
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal faithful "$output"
}
test_case 'Git review preserves code whitespace and hunk semantics for header-like changed lines and continuous hunks' _test_git_review_code_fidelity

_test_git_review_failures() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    local root=/fixture clipboard_binary="" _ZLE_PICKER_TITLE=Branches step=0 scenario=""
    _zle_picker_loop() {
      (( ++step ))
      _ZLE_PICKER_BOOKMARK=("filter" 2 0) _ZLE_PICKER_BOOKMARK_FOCUS=1
      case $step in
        (1) _ZLE_PICKER_ACTION=actions _ZLE_PICKER_SELECTED_VALUE=feature ;;
        (2) _ZLE_PICKER_SELECTED_VALUE=commits ;;
        (3) [[ $_ZLE_PICKER_TITLE == "Git review" && $_ZLE_PICKER_BROWSE_LABEL == unavailable ]] || return 77; return 130 ;;
        (*) return 88 ;;
      esac
      return 0
    }
    for scenario in config revision; do
      step=0
      _git_review_prepare() { [[ $scenario == revision ]]; }
      _git_review_capture() { return 2; }
      _git_review_branch_choose
      [[ $? == 130 && $step == 3 && $_ZLE_PICKER_TITLE == Branches ]] || exit 1
    done
    print failures
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal failures "$output"
}
test_case 'Git review propagates abort from failed config or ref capture and restores the parent title' _test_git_review_failures

_test_git_review_merges() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -qb main
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print -r -- base > common
    git add . && git commit -qm base
    git switch -qc side
    print -r -- side > side
    git add . && git commit -qm side
    git switch -q main
    print -r -- main > main
    git add . && git commit -qm main
    parent=$(git rev-parse HEAD)
    git merge --no-ff --no-edit -m merge side >/dev/null || exit 1
    merge=$(git rev-parse HEAD)
    _git_review_prepare "$PWD" || exit 2
    _git_review_commits_capture "$PWD" "$merge" || exit 3
    [[ $_GIT_REVIEW_PARENTS[1] == "$parent" ]] || exit 4
    _git_review_commit_files_capture "$PWD" "$merge" "$parent" || exit 5
    [[ ${(j:|:)_GIT_REVIEW_PATHS} == side ]] || exit 6
    _git_review_diff_capture "$PWD" commit side "$merge" "$parent" || exit 7
    [[ $_GIT_REVIEW_DATA == *+side* ]] || exit 8
    git switch -q side
    print -r -- left >| common
    git add common && git commit -qm left
    git switch -q main
    print -r -- right >| common
    git add common && git commit -qm right
    git merge --no-edit side >/dev/null 2>&1 && exit 9
    _git_review_changes_capture "$PWD" || exit 10
    [[ ${_GIT_REVIEW_KINDS[(Ie)conflict]} -gt 0 ]] || exit 11
    _git_review_diff_capture "$PWD" conflict common || exit 12
    [[ $_GIT_REVIEW_DATA == Conflict* && $_GIT_REVIEW_DATA != *left* && $_GIT_REVIEW_DATA != *right* ]] || exit 13
    print merged
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal merged "$output"
}
test_case 'Git review compares merge commits to the first parent and leaves conflict contents unread' _test_git_review_merges

_test_git_review_empty_states() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    _zle_picker_capture() { shift 3; "$@"; }
    _git_review_changes_capture() {
      _GIT_REVIEW_PATHS=(file) _GIT_REVIEW_LABELS=(file) _GIT_REVIEW_KINDS=(unstaged)
      _GIT_REVIEW_CONTEXTS=("Unstaged M") _GIT_REVIEW_DETAILS=(file)
    }
    _zle_picker_loop() {
      # A nonempty snapshot can have zero filter matches. Its empty-state
      # caption must come from the filter, not claim the worktree is clean.
      (( ${#_ZLE_PICKER_EMPTY_LINES} == 0 )) || return 78
      [[ $_ZLE_PICKER_EMPTY_LABEL == "no matching entries" ]] || return 79
      return 1
    }
    _git_review_view /fixture working
    [[ $? == 1 ]] || exit 1
    print accurate
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal accurate "$output"
}
test_case 'Git review distinguishes a filtered-out working snapshot from an actually empty worktree' _test_git_review_empty_states
