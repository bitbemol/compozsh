_test_git_folder_summary() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -a _GIT_REVIEW_PATHS=("src/a" "src/a" "src/sub/b" "src2/c" "src/notice/")
    local -a _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}")
    local -a _GIT_REVIEW_KINDS=(staged unstaged untracked conflict untracked)
    local -a _GIT_REVIEW_CONTEXTS=("Staged M" "Unstaged M" Untracked "Conflict UU" Untracked)
    local _GIT_REVIEW_SUMMARY="5 captured changes · partial snapshot"
    local _git_file_view=tree _git_tree_scope="" _git_tree_filter="" _git_tree_exclude="" _git_tree_filter_scope=""
    local -A _git_tree_expanded=() _git_tree_filter_expanded=() _git_tree_depths=()
    _git_review_rows
    _git_review_file_collect "" 1000
    local summary=${_ZLE_PICKER_INSPECT_TEXTS[d:src/]}
    [[ $summary == *"4 change entries · 3 distinct paths"* &&
       $summary == *"Direct paths: 2"* && $summary == *"Child folders: 1"* &&
       $summary == *"Staged: 1"* && $summary == *"Unstaged: 1"* &&
       $summary == *"New: 2"* && $summary != *"Conflicts:"* &&
       $summary == *"Partial snapshot"* && $summary == *"Where changes are"* &&
       $summary == *"Direct entries"* && $summary == *"sub/"* &&
       $summary == *"Bars count change entries"* ]] || { print -u2 "folder summary missing or counts incorrect"; exit 1; }
    _git_tree_scope=src/
    _git_review_file_collect "" 1000
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[d:src/]} == "$summary" ]] || exit 2
    _ZLE_PICKER_EXCLUDE=sub
    _git_review_file_collect "" 1000
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[d:src/]} == *"3 change entries · 2 distinct paths"* &&
       ${_ZLE_PICKER_INSPECT_TEXTS[d:src/]} == *"Filtered captured changes"* ]] || exit 3
    _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_RESULTS=(d:src/)
    _ZLE_PICKER_BROWSE_LABEL="snapshot · stale file syntax" _git_review_refresh_status="auto on"
    (( ${+functions[_git_review_file_browse]} )) || exit 4
    _git_review_file_browse 120
    [[ $REPLY == *"auto on"* && $REPLY == *"Folder summary"* && $REPLY != *stale* ]] || exit 5
    local kind=working root=repo
    _ZLE_PICKER_SUBTITLE="stale focused diff · file syntax"
    _git_review_file_subtitle 120
    [[ $REPLY == *"captured folder"* && $REPLY != *stale* && $REPLY != *syntax* ]] || exit 13
    _ZLE_PICKER_RESULTS=(1)
    _git_review_file_browse 120
    [[ $REPLY == "$_ZLE_PICKER_BROWSE_LABEL" ]] || exit 6
    _GIT_REVIEW_KINDS=(commit commit commit comparison commit)
    _GIT_REVIEW_CONTEXTS=("+10 -2" Binary "+5 -3" "+20 -4" "+0 -1")
    _git_review_folder_summary src/ 1 2 3 4 5
    [[ $REPLY == *"Committed: 4"* && $REPLY != *"Compared:"* &&
       $REPLY == *"Lines: +15 -6 · Binary entries: 1"* ]] || { print -u2 "committed summary lacks captured line totals"; exit 7; }
    _GIT_REVIEW_CONTEXTS[1]="+999999999999 -2"
    _git_review_folder_summary src/ 1 2 3 4 5
    [[ $REPLY == *"Incomplete line totals · Entries without totals: 1"* ]] || exit 12
    _GIT_REVIEW_KINDS=()
    _git_review_folder_summary src/ 1 2 3 4 5
    [[ $REPLY == *"Other: 4"* ]] || exit 8
    local -i summary_calls=0
    local -a bookmark=("" 1 0)
    functions -c _git_review_folder_summary _test_folder_summary_original
    _git_review_folder_summary() { (( ++summary_calls )); _test_folder_summary_original "$@"; }
    _git_tree_scope="" _ZLE_PICKER_EXCLUDE=""
    _git_review_file_collect "" 2
    (( summary_calls == 1 )) || { print -u2 "offscreen summaries were eagerly built"; exit 9; }
    summary_calls=0
    _git_review_file_reselect 1
    (( summary_calls == 0 )) || exit 10
    _ZLE_PICKER_DOCUMENT_KEY=1
    _zle_ui_view() { [[ $3 == src/ ]] || { print -u2 "folder options described a previous file"; return 2; }; return 1; }
    _git_review_file_options d:src/ || exit 11
  ' "$TEST_REPO_ROOT"
}
test_case 'Git folder summary counts captured exact paths states filters and partial coverage' _test_git_folder_summary

_test_git_folder_summary_syntax() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_SELECTED=1
    _ZLE_PICKER_RESULTS=(d:src/) _ZLE_PICKER_DOCUMENT_BRANCHES=(d:src/ 1)
    _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=10
    _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    _git_review_document_cache_key() { print -u2 "folder requested retained-file syntax"; exit 9; }
    _git_review_syntax_idle
    (( $? == 2 )) || exit 1
  ' "$TEST_REPO_ROOT"
}
test_case 'Git folder summary rejects file syntax work before its next paint' _test_git_folder_summary_syntax

_test_git_folder_summary_literal_labels() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local directory=$'\''odd\nFolder /'\''
    local -a _GIT_REVIEW_PATHS=("${directory}child"$'\''\nHeader/file'\'') _GIT_REVIEW_KINDS=(unstaged)
    _git_review_folder_summary "$directory" 1
    [[ $REPLY == *"odd\\nFolder /"* && $REPLY == *"child\\nHeader/"* &&
       $REPLY != *$'\''\nFolder /'\''* && $REPLY != *$'\''\nHeader/'\''* ]] || {
      print -u2 "literal path controls became summary structure"; exit 1
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'Git folder summary keeps literal path controls separate from summary structure' _test_git_folder_summary_literal_labels

_test_git_folder_summary_filter_repaint() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    local -a _GIT_REVIEW_PATHS=(src/a src/sub/b)
    local -a _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}") _GIT_REVIEW_KINDS=(staged unstaged)
    local -a _GIT_REVIEW_CONTEXTS=("Staged M" "Unstaged M")
    local _git_file_view=tree _git_tree_scope="" _git_tree_filter="" _git_tree_exclude="" _git_tree_filter_scope=""
    local -A _git_tree_expanded=() _git_tree_filter_expanded=() _git_tree_depths=()
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=12
    _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_OFFSETS[1]=8
    _git_review_rows
    _git_review_file_collect "" 100
    _zle_picker_render "" 1
    _ZLE_PICKER_INSPECT_OFFSET=3
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} == *"2 change entries · 2 distinct paths"* ]] || exit 1
    _ZLE_PICKER_EXCLUDE=sub
    _git_review_file_collect "" 100
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_INSPECT_KEY == d:src/ &&
       ${(F)_ZLE_PICKER_INSPECT_LINES} == *"1 change entries · 1 distinct paths"* &&
       ${(F)_ZLE_PICKER_INSPECT_LINES} != *"2 change entries"* &&
       ${(F)_ZLE_PICKER_INSPECT_LINES} == *"Filtered captured changes"* ]] || {
      print -u2 "same-folder filter repaint retained the previous summary"; exit 2
    }
    [[ $_ZLE_PICKER_INSPECT_OFFSET == 3 && $_ZLE_PICKER_DOCUMENT_OFFSETS[1] == 8 ]] || {
      print -u2 "summary invalidation lost its position or the independent file bookmark"; exit 3
    }
    _ZLE_PICKER_EXCLUDE=""
    _git_review_file_collect "" 100
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} == *"2 change entries · 2 distinct paths"* &&
       ${(F)_ZLE_PICKER_INSPECT_LINES} != *"Filtered captured changes"* ]] || exit 4
  ' "$TEST_REPO_ROOT"
}
test_case 'Git folder summary updates the same prepared folder after filtering while preserving offsets' _test_git_folder_summary_filter_repaint
