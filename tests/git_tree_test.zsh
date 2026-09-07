_test_git_tree_capture() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    (( ${+functions[_git_review_file_collect]} )) || { print -u2 "tree file view missing"; exit 1; }
    local -a _GIT_REVIEW_PATHS=(README src/a src/a src/deep/b src/deep/more/c src/deep/more/next/d)
    local -a _GIT_REVIEW_LABELS=(README src/a src/a src/deep/b src/deep/more/c src/deep/more/next/d)
    local -a _GIT_REVIEW_KINDS=(unstaged staged unstaged untracked unstaged unstaged)
    local -a _GIT_REVIEW_CONTEXTS=(Uncommitted Staged Uncommitted Untracked Uncommitted Uncommitted)
    local _git_file_view=tree _git_tree_scope="" _git_tree_filter="" _git_tree_exclude=""
    local -A _git_tree_expanded=() _git_tree_depths=()
    local -a _git_tree_scopes=() _git_tree_returns=()
    _ZLE_PICKER_DOCUMENT=1
    _git_review_rows
    _git_review_file_collect "" 1000
    [[ ${_ZLE_PICKER_RESULTS[(Ie)1]} != 0 && ${_ZLE_PICKER_RESULTS[(Ie)d:src/]} != 0 &&
       ${_ZLE_PICKER_RESULTS[(Ie)2]} != 0 && ${_ZLE_PICKER_RESULTS[(Ie)3]} != 0 &&
       ${_ZLE_PICKER_RESULTS[(Ie)5]} != 0 && ${_ZLE_PICKER_RESULTS[(Ie)6]} == 0 &&
       $_ZLE_PICKER_ACCEPT_LABELS[d:src/deep/more/] == collapse &&
       $_ZLE_PICKER_ACCEPT_LABELS[d:src/deep/more/next/] == "open folder" ]] || exit 2
    [[ ${_ZLE_PICKER_LABEL_PREFIXES[d:src/deep/more/]} == "  ▾ " &&
       ${_ZLE_PICKER_LABEL_PREFIXES[5]} == "    " ]] || exit 8
    _git_tree_expanded[src/]=0
    _git_review_file_collect "" 1000
    [[ ${_ZLE_PICKER_RESULTS[(Ie)2]} == 0 && $_ZLE_PICKER_ACCEPT_LABELS[d:src/] == expand ]] || exit 3
    _git_review_file_collect next/d 1000
    [[ ${_ZLE_PICKER_RESULTS[(Ie)6]} != 0 ]] || exit 4
    _git_review_file_collect "" 1000
    [[ ${_ZLE_PICKER_RESULTS[(Ie)2]} == 0 ]] || exit 5
    _git_file_view=flat
    _git_review_file_collect "" 1000
    [[ ${#_ZLE_PICKER_RESULTS} == 6 && ${#_ZLE_PICKER_DOCUMENT_BRANCHES} == 0 &&
       $_ZLE_PICKER_LABELS[4] == b && $_ZLE_PICKER_CONTEXTS[4] == New ]] || exit 6
    _git_file_view=tree _git_tree_scope=src/deep/more/
    _git_review_file_collect "" 1000
    [[ ${_ZLE_PICKER_RESULTS[(Ie)5]} != 0 && ${_ZLE_PICKER_RESULTS[(Ie)6]} != 0 ]] || exit 7
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree derives bounded expandable rows and flat files from one captured list' _test_git_tree_capture

_test_git_tree_literal() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    (( ${+functions[_git_review_file_collect]} )) || { print -u2 "tree file view missing"; exit 1; }
    local deep="" n
    for n in {1..100}; do deep+="level$n/"; done
    local -a _GIT_REVIEW_PATHS=("${deep}a.swift" "${deep}b.swift" "odd[*/a.swift" "nested/" )
    local -a _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}")
    local -a _GIT_REVIEW_KINDS=(staged unstaged untracked untracked)
    local -a _GIT_REVIEW_CONTEXTS=(Staged Uncommitted Untracked Untracked)
    local _git_file_view=tree _git_tree_scope="" _git_tree_filter="" _git_tree_exclude=""
    local -A _git_tree_expanded=() _git_tree_depths=()
    local -a _git_tree_scopes=() _git_tree_returns=()
    _ZLE_PICKER_DOCUMENT=1
    _git_review_rows
    _git_review_file_collect "" 1000
    [[ ${#_ZLE_PICKER_RESULTS} == 6 && ${_ZLE_PICKER_RESULTS[(Ie)1]} != 0 &&
       ${_ZLE_PICKER_RESULTS[(Ie)4]} != 0 && ${_ZLE_PICKER_RESULTS[(Ie)d:nested/]} == 0 ]] || exit 2
    local _ZLE_PICKER_EXCLUDE="odd[*"
    _git_review_file_collect "" 1000
    [[ ${_ZLE_PICKER_RESULTS[(Ie)3]} == 0 && ${_ZLE_PICKER_RESULTS[(Ie)1]} != 0 ]] || exit 3
    _git_file_view=flat _ZLE_PICKER_EXCLUDE=""
    _git_review_file_collect "" 1000
    [[ $_ZLE_PICKER_LABELS[1] == "a.swift · "* && $_ZLE_PICKER_LABELS[3] == "a.swift · odd[*/" ]] || exit 4
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree compresses extreme depth and preserves literal paths exclusion and separate repository notices' _test_git_tree_literal

_test_git_tree_reader() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=1
    _ZLE_PICKER_DOCUMENT_TITLE=src/file.swift
    _ZLE_PICKER_DOCUMENT_LINES=("captured document") _ZLE_PICKER_DOCUMENT_ROLES=(text)
    _ZLE_PICKER_RESULTS=(d:src/ 1) _ZLE_PICKER_LABELS=("▾ src/" file.swift)
    _ZLE_PICKER_DOCUMENT_BRANCHES=(d:src/ 1)
    _ZLE_PICKER_INSPECT_TEXTS=(d:src/ folder 1 ready)
    _ZLE_PICKER_ACCEPT_LABELS=(d:src/ collapse)
    _ZLE_PICKER_OPTIONS_KIND=file-views _ZLE_PICKER_WORKSPACE_ACTIONS=1
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Folder summary"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *"captured document"* &&
       ${_ZLE_PICKER_DISPLAY[-1]} == *"collapse"* &&
       ${_ZLE_PICKER_DISPLAY[-1]} == *"^X views"* ]] || exit 1
    _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Folder summary"* && ${_ZLE_PICKER_DISPLAY[-1]} != *collapse* ]] || exit 2
    COLUMNS=40
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Folder summary"* ]] || exit 3
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree folder selection shows a separate summary with capability derived actions' _test_git_tree_reader

_test_git_tree_refresh_scope() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -a _GIT_REVIEW_PATHS=(src/remaining)
    local _git_tree_scope=src/gone/deep/ _git_tree_filter_scope=missing/
    local -A _git_tree_expanded=(src/ 0 src/gone/ 0) _git_tree_filter_expanded=(missing/ 0)
    local -a _git_tree_scopes=() _git_tree_returns=() _git_tree_filter_scopes=() _git_tree_filter_returns=()
    (( ${+functions[_git_review_tree_reconcile]} )) || { print -u2 "tree refresh reconciliation missing"; exit 1; }
    _git_review_tree_reconcile
    [[ $_git_tree_scope == src/ && -z $_git_tree_filter_scope &&
       $_git_tree_expanded[src/] == 0 && ${#_git_tree_expanded} == 1 &&
       ${#_git_tree_filter_expanded} == 0 ]] || exit 2
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree refresh removes obsolete folds and returns a vanished scope to its nearest captured ancestor' _test_git_tree_refresh_scope

_test_git_tree_cells() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_CONTEXT_MIN_WIDTH=11
    _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_LINES=(code)
    _ZLE_PICKER_DOCUMENT_ROLES=(text)
    _ZLE_PICKER_RESULTS=(1 d:folder/) _ZLE_PICKER_LABELS=("      非常に長いファイル名.swift" "    ▸ very-long-directory-name/")
    _ZLE_PICKER_LABEL_PREFIXES=(1 "      " d:folder/ "    ▸ ")
    _ZLE_PICKER_DOCUMENT_BRANCHES=(d:folder/ 1)
    _ZLE_PICKER_INSPECT_TEXTS=(1 ready d:folder/ directory)
    _ZLE_PICKER_CONTEXTS=(1 "Unstaged M" d:folder/ "12 changes")
    _ZLE_PICKER_SCREEN_ACTIVE=1 LINES=30 COLUMNS=120
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_DISPLAY[2] == *"      "*"Unstaged M"* &&
       $_ZLE_PICKER_DISPLAY[3] == *"    ▸ "* ]] || { print -u2 -r -- "${(F)_ZLE_PICKER_DISPLAY}"; exit 1; }
    local row width
    for width in 90 100 120 40; do
      COLUMNS=$width
      _zle_picker_render "" 1
      for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
        (( ${(m)#row} < width )) || { print -u2 -r -- "overflow $width: $row"; exit 2; }
      done
      [[ $_ZLE_PICKER_DISPLAY[2] == *"Unstaged M"* ]] || { print -u2 -r -- "state lost $width: $_ZLE_PICKER_DISPLAY[2]"; exit 3; }
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree keeps indentation folder markers and complete change states within narrow cell budgets' _test_git_tree_cells

_test_git_tree_roundtrip() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -a _GIT_REVIEW_PATHS=(other/file src/a src/deep/b src/deep/more/c)
    local -a _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}") _GIT_REVIEW_KINDS=(unstaged unstaged unstaged unstaged)
    local -a _GIT_REVIEW_CONTEXTS=(M M M M) bookmark=("" 1 0)
    local _git_file_view=tree _git_tree_scope=src/ _git_tree_filter="" _git_tree_exclude="" _git_tree_filter_scope=""
    local -A _git_tree_expanded=() _git_tree_filter_expanded=() _git_tree_depths=()
    local -a _git_tree_bookmark=() _git_flat_bookmark=()
    local _git_tree_selected="" _git_flat_selected="" _git_tree_document="" _git_flat_document=""
    local -i focus=0
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=1
    _git_review_rows
    _git_review_file_collect "" 1000
    local menu_choice=flat
    _zle_ui_view() { _ZLE_PICKER_SELECTED_VALUE=$menu_choice; return 0; }
    _git_review_file_options d:src/
    [[ $_git_file_view == flat ]] || exit 1
    menu_choice=tree
    _git_review_file_options 1
    [[ $_git_tree_scope == src/ && ${_ZLE_PICKER_RESULTS[bookmark[2]]} == d:src/ ]] || {
      print -u2 "Tree → All files → Tree lost the selected folder or scope"; exit 2
    }
    _git_tree_expanded[src/]=0
    _git_review_file_collect "" 1000
    _git_review_file_options d:src/
    [[ $_git_tree_expanded[src/] == 0 && $_git_tree_scope == src/ &&
       ${_ZLE_PICKER_RESULTS[bookmark[2]]} == d:src/ ]] || { print -u2 "choosing the current view changed navigation"; exit 3; }
    menu_choice=flat
    _git_review_file_options d:src/
    _ZLE_PICKER_DOCUMENT_KEY=2
    menu_choice=tree
    _git_review_file_options 2
    [[ ${_ZLE_PICKER_RESULTS[bookmark[2]]} == 2 ]] || { print -u2 "returning from a different flat file failed to reveal it"; exit 4; }
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree and flat round trips retain folder scope bookmarks and reveal a newly selected file' _test_git_tree_roundtrip

_test_git_tree_flat_ancestor() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -a _GIT_REVIEW_PATHS=(lib/deep/file) bookmark=("" 1 0)
    local _git_file_view=flat _git_tree_scope=src/ _git_tree_filter_scope=""
    local -i calls=0
    _zle_ui_view() {
      (( ++calls ))
      if (( calls == 1 )); then _ZLE_PICKER_SELECTED_VALUE=ancestor; return 0; fi
      [[ $3 == lib/deep/ ]] || { print -u2 "flat ancestor chooser used $3 instead of the selected file parent"; return 2; }
      return 1
    }
    _git_review_file_options 1 || exit 1
    (( calls == 2 )) || exit 2
  ' "$TEST_REPO_ROOT"
}
test_case 'Git flat ancestor navigation uses the selected file instead of a saved tree scope' _test_git_tree_flat_ancestor

_test_git_tree_reachable() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -a _GIT_REVIEW_PATHS=() _GIT_REVIEW_LABELS=() _GIT_REVIEW_KINDS=() _GIT_REVIEW_CONTEXTS=()
    local -i n=0 visits=0
    local component="" literal=$'\''odd\n%[*]/'\''
    for n in {1..96}; do
      case $(( n % 4 )) in
        0) component="src/deep/group$((n%7))/more/" ;;
        1) component="src2/" ;;
        2) component="$literal" ;;
        3) component="" ;;
      esac
      _GIT_REVIEW_PATHS+=("${component}file$n")
      _GIT_REVIEW_KINDS+=(unstaged) _GIT_REVIEW_CONTEXTS+=("Unstaged M")
    done
    _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}")
    local _git_file_view=tree _git_tree_scope="" _git_tree_filter="" _git_tree_exclude="" _git_tree_filter_scope=""
    local -A _git_tree_expanded=() _git_tree_filter_expanded=() _git_tree_depths=() seen=() opened=()
    local -a pending=("") values=()
    local value="" scope=""
    _ZLE_PICKER_DOCUMENT=1
    _git_review_rows
    while (( ${#pending} )); do
      (( ++visits < 100 )) || { print -u2 "tree scopes did not converge"; exit 1; }
      scope=$pending[1] pending[1]=()
      _git_tree_scope=$scope
      _git_review_file_collect "" 10000
      values=("${_ZLE_PICKER_RESULTS[@]}")
      for value in "${values[@]}"; do
        if [[ $value == d:* ]]; then
          (( ${_git_tree_depths[$value]} <= 3 )) || exit 2
          if [[ $_ZLE_PICKER_ACCEPT_LABELS[$value] == "open folder" && -z ${opened[$value]-} ]]; then
            opened[$value]=1
            pending+=("${value#d:}")
          fi
        else
          [[ ${_GIT_REVIEW_PATHS[value]} == "$scope"* ]] || { print -u2 "file escaped visible scope"; exit 3; }
          seen[$value]=1
        fi
      done
    done
    (( ${#seen} == ${#_GIT_REVIEW_PATHS} )) || { print -u2 "unreachable captured files"; exit 4; }
    _git_file_view=flat
    _git_review_file_collect "" 10000
    (( ${#_ZLE_PICKER_RESULTS} == ${#seen} )) || exit 5
    _GIT_REVIEW_PATHS=() _GIT_REVIEW_LABELS=() _GIT_REVIEW_KINDS=() _GIT_REVIEW_CONTEXTS=()
    _git_review_rows
    _git_review_tree_reconcile
    _git_file_view=tree
    _git_review_file_collect "" 10000
    [[ -z $_git_tree_scope && ${#_ZLE_PICKER_RESULTS} == 0 && ${#_ZLE_PICKER_DOCUMENT_BRANCHES} == 0 ]] || exit 6
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree keeps every captured file reachable across literal overlapping scopes and empty refresh' _test_git_tree_reachable
