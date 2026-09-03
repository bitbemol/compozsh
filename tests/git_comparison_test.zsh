# Committed comparisons keep exact endpoints, independent of the checkout.
_test_git_comparison_providers() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    (( ${+functions[_git_review_resolve]} )) || { print -u2 "missing revision comparison"; exit 1; }
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -qb main
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print -r -- original > baseline
    print -r -- original > "feature*[x]"
    git add . && git commit -qm base || exit 2
    base=$(git rev-parse HEAD)
    git branch topic
    print -r -- upstream > baseline
    git commit -qam upstream || exit 3
    left=$(git rev-parse HEAD)
    git switch -q topic
    print -r -- topic > "feature*[x]"
    git commit -qam topic || exit 4
    right=$(git rev-parse HEAD)
    git tag -am annotated release "$left"
    git branch collision "$left"
    git branch refs/topic "$left"
    git tag collision "$right"
    git tag topic "$left"
    git update-ref refs/remotes/origin/main "$left"
    print -r -- dirty >> "feature*[x]"
    before=$(git hash-object .git/index)
    _git_recent_branches "$PWD" || exit 33
    [[ $_GIT_RECENT_CURRENT == topic && $_GIT_RECENT_BRANCHES[1] == topic ]] || exit 34
    typeset -a _GIT_REVIEW_CONFIG=()
    _git_review_prepare "$PWD" || exit 5
    for revision in main refs/heads/main refs/topic refs/heads/refs/topic release refs/tags/release origin/main refs/remotes/origin/main "$left" "${left[1,10]}"; do
      _git_review_resolve "$PWD" "$revision" && [[ $REPLY == "$left" ]] || exit 6
    done
    _git_review_resolve "$PWD" HEAD && [[ $REPLY == "$right" ]] || exit 7
    if _git_review_resolve "$PWD" collision; then exit 8; fi
    [[ $_GIT_REVIEW_ERROR == *ambiguous* ]] || exit 9
    for revision in missing --help "HEAD~1" "HEAD:baseline" "main...topic"; do
      if _git_review_resolve "$PWD" "$revision"; then exit 10; fi
      [[ -z $REPLY && -n $_GIT_REVIEW_ERROR ]] || exit 11
    done
    blob=$(git rev-parse HEAD:baseline)
    git tag blob "$blob"
    if _git_review_resolve "$PWD" blob; then exit 12; fi
    _git_review_compare_base "$PWD" exact "$left" "$right" && [[ $REPLY == "$left" ]] || exit 13
    _git_review_compare_base "$PWD" ancestor "$left" "$right" && [[ $REPLY == "$base" ]] || exit 14
    _git_review_comparison_files_capture "$PWD" "$right" "$left" || exit 15
    (( ${#_GIT_REVIEW_PATHS} == 2 )) && [[ $_GIT_REVIEW_KINDS[1] == comparison ]] || exit 16
    _git_review_diff_capture "$PWD" comparison "feature*[x]" "$right" "$left" || exit 17
    [[ $_GIT_REVIEW_DATA == *+topic* && $_GIT_REVIEW_DATA != *dirty* ]] || exit 18
    _git_review_comparison_files_capture "$PWD" "$right" "$base" || exit 19
    [[ ${#_GIT_REVIEW_PATHS} == 1 && $_GIT_REVIEW_PATHS[1] == "feature*[x]" ]] || exit 20
    git branch -f main "$right"
    _git_review_comparison_files_capture "$PWD" "$right" "$left" || exit 21
    (( ${#_GIT_REVIEW_PATHS} == 2 )) || exit 22
    _git_review_comparison_files_capture "$PWD" "$right" "$right" || exit 23
    (( !${#_GIT_REVIEW_PATHS} )) || exit 24
    tree=$(git rev-parse HEAD^{tree})
    unrelated=$(print -r -- unrelated | git commit-tree "$tree")
    if _git_review_compare_base "$PWD" ancestor "$left" "$unrelated"; then exit 25; fi
    [[ $_GIT_REVIEW_ERROR == *ancestor* ]] || exit 26
    a=$(print -r -- a | git commit-tree "$tree" -p "$left" -p "$right")
    b=$(print -r -- b | git commit-tree "$tree" -p "$right" -p "$left")
    if _git_review_compare_base "$PWD" ancestor "$a" "$b"; then exit 27; fi
    [[ $_GIT_REVIEW_ERROR == *multiple* ]] || exit 28
    _git_review_refs_capture "$PWD" || exit 29
    [[ ${_GIT_REVIEW_REFS[(Ie)refs/tags/release]} -gt 0 && ${_GIT_REVIEW_REFS[(Ie)refs/remotes/origin/main]} -gt 0 ]] || exit 30
    [[ ${_GIT_REVIEW_REFS[(Ie)refs/tags/blob]} == 0 ]] || exit 31
    [[ $(git hash-object .git/index) == "$before" && $(git symbolic-ref HEAD) == refs/heads/topic ]] || exit 32
    print compared
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal compared "$output"
}
test_case 'Git comparison resolves local revisions and separates exact from ancestor snapshots' _test_git_comparison_providers

_test_git_comparison_entry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    # Operational helper fails if help probes it; the existing g provider owns help.
    _git_review_session() { print -u2 unexpected-session; return 71; }
    g --review --help > "$HOME/help" 2> "$HOME/error"
    [[ $? == 0 && ! -s "$HOME/error" && $(<"$HOME/help") == *"g --review"* ]] || exit 1
    [[ $(<"$HOME/help") == "$(_compozsh_help_g)" ]] || exit 2
    for args in "--review one" "--review --merge-base" "--review --bad a b" "--review a b c"; do
      g ${(z)args} > "$HOME/out" 2> "$HOME/error"
      [[ $? == 2 && ! -s "$HOME/out" && $(<"$HOME/error") == "usage: g [git-arguments ...]" ]] || exit 3
    done
    _git_review_session() { print -r -- "session:$*"; return 37; }
    g --review a b > "$HOME/out"
    [[ $? == 37 && $(<"$HOME/out") == "session:exact a b" ]] || exit 4
    [[ $(g --review --merge-base a b) == "session:ancestor a b" ]] || exit 5
    [[ $(g --review) == "session:" ]] || exit 6
    mkdir -p "$HOME/repo"
    command git init -qb main "$HOME/repo"
    cd "$HOME/repo"
    command git config alias.review "status --short"
    [[ $(g review) == $(command git review) ]] || exit 9
    g diff --exit-code > "$HOME/wrapped" 2> "$HOME/wrapped-error"
    wrapped_status=$?
    command git diff --exit-code > "$HOME/native" 2> "$HOME/native-error"
    [[ $? == $wrapped_status && $(<"$HOME/wrapped") == $(<"$HOME/native") &&
       $(<"$HOME/wrapped-error") == $(<"$HOME/native-error") ]] || exit 10
    unfunction _git_review_session
    g --review a b > "$HOME/out" 2> "$HOME/error"
    [[ $? == 1 && ! -s "$HOME/out" && $(<"$HOME/error") == *unavailable* ]] || exit 7
    source "$1/.zsh.addons/.zsh.git-review"
    g --review a b > "$HOME/out" 2> "$HOME/error"
    [[ $? == 1 && ! -s "$HOME/out" && $(<"$HOME/error") == *terminal* ]] || exit 8
    print entry
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal entry "$output"
}
test_case 'Git comparison wrapper owns explicit review syntax help and unavailable fallback' _test_git_comparison_entry

_test_git_comparison_navigation() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    (( ${+functions[_git_review_compare_choose]} )) || exit 1
    typeset -i step=0 views=0
    typeset -a _GIT_REVIEW_CONFIG=()
    _git_review_load() { shift 0; "$@"; }
    _git_review_resolve() { REPLY=${(l:40::a:)}; }
    _git_review_compare_base() { REPLY=$3; }
    _git_review_prepare() { return 0; }
    _git_review_endpoint_choose() { REPLY=${(l:40::b:)}; _git_compare_label="other"; }
    _git_review_view() {
      [[ $2 == comparison && $4 == ${(l:40::a:)} && $5 == ${(l:40::b:)} ]] || exit 9
      [[ $_git_compare_context == *other* && $_git_compare_context == *selected* ]] || exit 10
      (( ++views ))
      return 1
    }
    _zle_picker_loop() {
      (( ++step ))
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      case $step in
        (1) [[ ${_NAVIGATION_PICKER_VALUES[(Ie)open]} == 0 ]] || exit 2
            _ZLE_PICKER_SELECTED_VALUE=from ;;
        (2) [[ $3 == 4 && ${_NAVIGATION_PICKER_VALUES[(Ie)open]} == 4 ]] || exit 3
            _ZLE_PICKER_SELECTED_VALUE=open ;;
        (3) [[ $_NAVIGATION_PICKER_LABELS[2] == *other* ]] || exit 4
            return 1 ;;
        (*) exit 5 ;;
      esac
    }
    _git_review_compare_choose /repository selected
    [[ $? == 1 && $views == 1 && $step == 3 ]] || exit 6
    _NAVIGATION_PICKER_VALUES=(ref) _NAVIGATION_PICKER_LABELS=(main) _NAVIGATION_PICKER_INDEXES=(1)
    _git_review_ref_collect nonexistent 5
    [[ $_ZLE_PICKER_RESULTS[1] == enter && $_ZLE_PICKER_LABELS[1] == *commit* ]] || exit 7
    print navigation
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal navigation "$output"
}
test_case 'Git comparison setup preserves its pair on Back and offers literal input with no ref matches' _test_git_comparison_navigation

_test_git_comparison_guide() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_GUIDE_CONTEXT=("Captured comparison: exact versions" "From: aaaa" "To: bbbb")
    LINES=100
    _zle_picker_guide_render 100
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"From: aaaa"* && ${(F)_ZLE_PICKER_DISPLAY} == *"To: bbbb"* ]] || exit 1
    print context
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal context "$output"
}
test_case 'Git comparison guide exposes captured endpoint context through shared rendering' _test_git_comparison_guide

_test_git_comparison_bounds() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    oid=${(l:40::a:)}
    _git_review_capture() { return 0; }
    if _git_review_diff_capture "$HOME" comparison file "$oid" ""; then exit 1; fi
    _git_review_capture() {
      _GIT_REVIEW_DATA="" _GIT_REVIEW_TRUNCATED=0
      local -i i
      for (( i=1; i<=1001; ++i )); do
        _GIT_REVIEW_DATA+="refs/tags/blob$i"$'\''\0'\''"blob"$'\''\0'\''"$oid"$'\''\0\n'\''
      done
    }
    _git_review_refs_capture "$HOME" || exit 2
    [[ $_GIT_REVIEW_TRUNCATED == 1 && ${#_GIT_REVIEW_REFS} == 0 ]] || exit 3
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'Git comparison refuses missing endpoints and marks ref discovery bounds before filtering' _test_git_comparison_bounds

_test_git_comparison_safety() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/helper" '#!/bin/sh
touch "$HOME/unexpected-helper"
exit 1' || return
  command chmod +x "$TEST_TMP_DIR/home/helper" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir "$HOME/repo"
    cd "$HOME/repo"
    git init -qb main
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print -r -- "tracked filter=hostile diff=hostile" > .gitattributes
    print base > tracked
    git add . && git commit -qm base || exit 1
    before=$(git rev-parse HEAD)
    print committed >> tracked
    git commit -qam update || exit 2
    after=$(git rev-parse HEAD)
    git tag -am tagged snapshot "$before"
    print private-working-content >> tracked
    index_before=$(git hash-object --no-filters .git/index)
    for key in core.pager core.fsmonitor diff.external diff.hostile.textconv filter.hostile.clean filter.hostile.smudge filter.hostile.process; do
      git config "$key" "$HOME/helper"
    done
    git config filter.hostile.required true
    mkdir "$HOME/hooks"
    cp "$HOME/helper" "$HOME/hooks/post-checkout"
    git config core.hooksPath "$HOME/hooks"
    export GIT_OPTIONAL_LOCKS=1 GIT_NO_LAZY_FETCH=0 GIT_ALLOW_PROTOCOL=ext
    _git_review_prepare "$PWD" || exit 3
    _git_review_refs_capture "$PWD" || exit 4
    _git_review_resolve "$PWD" snapshot && [[ $REPLY == "$before" ]] || exit 5
    _git_review_compare_base "$PWD" ancestor "$before" "$after" && [[ $REPLY == "$before" ]] || exit 6
    _git_review_comparison_files_capture "$PWD" "$after" "$before" || exit 7
    [[ ${#_GIT_REVIEW_PATHS} == 1 && $_GIT_REVIEW_PATHS[1] == tracked ]] || exit 8
    _git_review_diff_capture "$PWD" comparison tracked "$after" "$before" || exit 9
    [[ $_GIT_REVIEW_DATA == *+committed* && $_GIT_REVIEW_DATA != *private-working-content* ]] || exit 10
    [[ ! -e "$HOME/unexpected-helper" && $(git hash-object --no-filters .git/index) == "$index_before" ]] || exit 11
    [[ $GIT_OPTIONAL_LOCKS == 1 && $GIT_NO_LAZY_FETCH == 0 && $GIT_ALLOW_PROTOCOL == ext ]] || exit 12
    print hardened
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal hardened "$output"
}
test_case 'Git comparison suppresses configured executables and preserves index working files and caller environment' _test_git_comparison_safety
