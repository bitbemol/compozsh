_test_git_tree_divergent_depth() {
  test_make_temp_dir || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local deep="${(l:6000::a/:)}"
    local -a _GIT_REVIEW_PATHS=("root/${deep}one" "root/other/two" "root/notice/")
    local -a _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    local -A _ZLE_PICKER_DOCUMENT_BRANCHES=() _ZLE_PICKER_CONTEXTS=()
    local -A _ZLE_PICKER_INSPECT_TEXTS=() _ZLE_PICKER_ACCEPT_LABELS=()
    local -A _ZLE_PICKER_LABEL_PREFIXES=()
    local -A _git_tree_depths=() expanded=()
    local -i commands_seen=0
    TRAPDEBUG() { (( ++commands_seen )); return 0; }
    _git_review_tree_rows "" 0 1 2 3
    unfunction TRAPDEBUG
    [[ ${_ZLE_PICKER_RESULTS[(Ie)1]} != 0 && ${_ZLE_PICKER_RESULTS[(Ie)2]} != 0 &&
       ${_ZLE_PICKER_RESULTS[(Ie)3]} != 0 && ${_ZLE_PICKER_RESULTS[(Ie)d:root/]} != 0 &&
       ${_ZLE_PICKER_RESULTS[(Ie)d:root/notice/]} == 0 ]] || exit 1
    # A nonbranching stretch is one compressed choice. Repeatedly shortening
    # the entire path makes shell work grow with every omitted component.
    # Count work rather than enforcing a machine-dependent timing threshold.
    (( commands_seen < 1000 )) || {
      print -u2 -r -- "Deep divergent captured paths required $commands_seen shell steps"
      exit 2
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree compresses divergent deep prefixes without per-component shell rescans' _test_git_tree_divergent_depth

_test_git_tree_deep_scope_reconciliation() {
  test_make_temp_dir || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local deep="${(l:6000::a/:)}"
    local -a _GIT_REVIEW_PATHS=(other/file "odd[*/remaining" "odd[*/deep/remaining" root/notice/)
    local _git_tree_scope="odd[*/deep/$deep" _git_tree_filter_scope=root/notice/gone/ literal_prefix="odd[*/"
    local -A _git_tree_expanded=("odd[*/" 0 "odd[*/deep/" 1 "odd[*/gone/" 0)
    local -A _git_tree_filter_expanded=(root/notice/ 0 root/gone/ 0)
    local -a _git_tree_scopes=("" "odd[*/") _git_tree_returns=("d:odd[*/" 7)
    local -a bookmark=(query 3 2)
    local -i commands_seen=0
    TRAPDEBUG() { (( ++commands_seen )); return 0; }
    _git_review_tree_reconcile
    unfunction TRAPDEBUG
    [[ $_git_tree_scope == "odd[*/deep/" && $_git_tree_filter_scope == root/notice/ &&
       ${#_git_tree_expanded} == 2 && ${_git_tree_expanded[$literal_prefix]} == 0 &&
       ${#_git_tree_filter_expanded} == 1 && ${_git_tree_filter_expanded[root/notice/]} == 0 &&
       ${_git_tree_scopes[2]} == "odd[*/" && ${_git_tree_returns[2]} == 7 &&
       ${bookmark[2]} == 3 && ${bookmark[3]} == 2 ]] || exit 1
    (( commands_seen < 1000 )) || {
      print -u2 -r -- "Vanished deep scope required $commands_seen shell steps"
      exit 2
    }
    _git_review_tree_reconcile
    [[ $_git_tree_scope == "odd[*/deep/" && $_git_tree_filter_scope == root/notice/ ]] || exit 3
    _GIT_REVIEW_PATHS=()
    _git_review_tree_reconcile
    [[ -z $_git_tree_scope && -z $_git_tree_filter_scope &&
       ${#_git_tree_expanded} == 0 && ${#_git_tree_filter_expanded} == 0 ]] || exit 4
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree reconciles a vanished deep scope with bounded ancestor searches and literal bookmarks' _test_git_tree_deep_scope_reconciliation
