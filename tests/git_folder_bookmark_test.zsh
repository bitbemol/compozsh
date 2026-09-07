_test_git_folder_bookmark_refresh() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local context=3
    local literal_folder="d:odd[*/"
    local -a _GIT_REVIEW_PATHS=(src/a other/b "odd[*/c") _GIT_REVIEW_KINDS=(unstaged unstaged unstaged)
    local -A _git_document_cache=() _git_document_partial=() _git_document_syntax_cache=()
    local -A _git_document_syntax_notes=() _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_failures=() _git_document_contexts=() _git_document_anchors=()
    local -a _git_document_order=()
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_SELECTED=1
    _ZLE_PICKER_RESULTS=(d:src/)
    _ZLE_PICKER_DOCUMENT_BRANCHES=(d:src/ 1 d:other/ 1 "d:odd[*/" 1)
    _ZLE_PICKER_DOCUMENT_OFFSETS=(1 8 2 6 d:src/ 2 d:other/ 3 "d:odd[*/" 5)
    _ZLE_PICKER_DOCUMENT_ROWS=(1 77 2 42 d:src/ 3 d:other/ 4 "d:odd[*/" 6)
    _ZLE_PICKER_INSPECT_KEY=d:src/ _ZLE_PICKER_INSPECT_OFFSET=7
    _ZLE_PICKER_INSPECT_SOURCE_LINES=({1..30})
    _git_review_auto_forget_other_documents
    [[ $_ZLE_PICKER_DOCUMENT_OFFSETS[d:src/] == 7 &&
       $_ZLE_PICKER_DOCUMENT_ROWS[d:src/] == 8 &&
       $_ZLE_PICKER_DOCUMENT_OFFSETS[d:other/] == 3 &&
       ${_ZLE_PICKER_DOCUMENT_OFFSETS[$literal_folder]} == 5 &&
       $_ZLE_PICKER_DOCUMENT_OFFSETS[1] == 8 &&
       ${+_ZLE_PICKER_DOCUMENT_OFFSETS[2]} == 0 ]] || {
      print -u2 "unchanged automatic observation discarded a folder bookmark or retained an obsolete file"; exit 1
    }
    # A replacement capture can change numeric IDs and remove literal scopes.
    # Keep only surviving folder prefixes, with glob characters treated literally.
    _GIT_REVIEW_PATHS=("odd[*/new" src/new root)
    _ZLE_PICKER_DOCUMENT_OFFSETS[d:srcx/]=9
    _ZLE_PICKER_DOCUMENT_ROWS[d:srcx/]=10
    _git_review_syntax_cleanup() { :; }
    _git_review_document_reset
    [[ ${#_ZLE_PICKER_DOCUMENT_OFFSETS} == 2 &&
       $_ZLE_PICKER_DOCUMENT_OFFSETS[d:src/] == 7 &&
       $_ZLE_PICKER_DOCUMENT_ROWS[d:src/] == 8 &&
       ${_ZLE_PICKER_DOCUMENT_OFFSETS[$literal_folder]} == 5 &&
       ${+_ZLE_PICKER_DOCUMENT_OFFSETS[1]} == 0 &&
       ${+_ZLE_PICKER_DOCUMENT_OFFSETS[d:other/]} == 0 &&
       ${+_ZLE_PICKER_DOCUMENT_OFFSETS[d:srcx/]} == 0 ]] || {
      print -u2 "replacement capture lost surviving folders or retained obsolete identities"; exit 2
    }
    _GIT_REVIEW_PATHS=()
    _git_review_document_reset
    [[ ${#_ZLE_PICKER_DOCUMENT_OFFSETS} == 0 && ${#_ZLE_PICKER_DOCUMENT_ROWS} == 0 ]] || exit 3
  ' "$TEST_REPO_ROOT"
}
test_case 'Git folder bookmarks survive unchanged observations and replacement captures without stale file identities' _test_git_folder_bookmark_refresh

_test_git_folder_bookmark_hidden_filter() {
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
    _ZLE_PICKER_EXCLUDE=src
    _git_review_file_collect "" 100
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_DOCUMENT_OFFSETS[d:src/] == 3 ]] || {
      print -u2 "filter hid a folder before retaining its reading position"; exit 1
    }
    _ZLE_PICKER_EXCLUDE=""
    _git_review_file_collect "" 100
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_INSPECT_KEY == d:src/ && $_ZLE_PICKER_INSPECT_OFFSET == 3 &&
       $_ZLE_PICKER_DOCUMENT_OFFSETS[1] == 8 ]] || {
      print -u2 "clearing a filter lost the folder position or independent file bookmark"; exit 2
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'Git folder bookmarks survive filters that hide the currently prepared summary' _test_git_folder_bookmark_hidden_filter
