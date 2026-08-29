# Whole-workspace refresh preserves literal path + kind, not reassigned IDs.
_test_git_refresh_workspace() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    _zle_picker_capture() { shift 3; "$@"; }
    local -i generation=0 lists=0 captures=0 prepares=0 loops=0
    _git_review_prepare() { (( ++prepares )); return 0; }
    _git_review_changes_capture() {
      (( ++lists ))
      _git_review_reset
      _GIT_REVIEW_PATHS=("same[1] file" "same[1] file" z)
      _GIT_REVIEW_KINDS=(staged unstaged untracked)
      (( generation )) && {
        _GIT_REVIEW_PATHS=(a "${_GIT_REVIEW_PATHS[@]}")
        _GIT_REVIEW_KINDS=(untracked "${_GIT_REVIEW_KINDS[@]}")
      }
      _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}")
      _GIT_REVIEW_CONTEXTS=("${_GIT_REVIEW_KINDS[@]}")
      _GIT_REVIEW_DETAILS=("${_GIT_REVIEW_PATHS[@]}")
      _GIT_REVIEW_SUMMARY="generation $generation"
    }
    _git_review_diff_capture() {
      (( ++captures ))
      _GIT_REVIEW_DATA=$'\''@@ -30,2 +30,2 @@\n before\n-old\n+'\''"$2 generation $generation"$'\''\n'\''
      _GIT_REVIEW_TRUNCATED=0
    }
    _zle_picker_loop() {
      (( ++loops ))
      _ZLE_PICKER_BOOKMARK=(same 2 0) _ZLE_PICKER_BOOKMARK_FOCUS=1
      _ZLE_PICKER_SELECTED_VALUE=2
      case $loops in
        (1) _ZLE_PICKER_ACTION=inspect ;;
        (2) _ZLE_PICKER_ACTION=document-full ;;
        (3)
          (( captures == 2 )) || return 71
          _ZLE_PICKER_DOCUMENT_ROWS[2]=4
          generation=1 _ZLE_PICKER_ACTION=document-refresh ;;
        (4)
          (( lists == 2 && prepares == 1 )) || { print -u2 "refresh did not recapture the file list safely"; return 72; }
          [[ $_ZLE_PICKER_DOCUMENT_KEY == 3 && $1 == same && $3 == 2 && $_zle_picker_start_focus == 1 ]] || return 73
          [[ $_ZLE_PICKER_DOCUMENT_MODE == full && $_ZLE_PICKER_DOCUMENT_TARGET_ROW == 4 ]] || return 74
          [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"unstaged generation 1"* ]] || return 75
          (( ${#_git_document_cache} == 1 && captures == 3 )) || return 76
          _ZLE_PICKER_SELECTED_VALUE=3 _ZLE_PICKER_ACTION=document-focused ;;
        (5)
          [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"unstaged generation 1"* && $captures == 4 ]] || return 77
          _ZLE_PICKER_SELECTED_VALUE=2 _ZLE_PICKER_ACTION=inspect ;;
        (6)
          [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"staged generation 1"* && $captures == 5 ]] || return 78
          return 1 ;;
        (*) return 79 ;;
      esac
    }
    _git_review_view /fixture working
    [[ $? == 1 && $loops == 6 ]] || exit 1
    print refreshed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refreshed "$output"
}
test_case 'Git workspace refresh recaptures files and preserves literal selection kind filter focus and source area' _test_git_refresh_workspace

_test_git_refresh_empty_failure() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    _zle_picker_capture() { shift 3; "$@"; }
    local -i generation=0 loops=0 captures=0 abort_status=0
    _git_review_prepare() { return $abort_status; }
    _git_review_changes_capture() {
      _git_review_reset
      (( generation == 2 )) && return 2
      if (( generation == 1 || generation == 3 )); then
        _GIT_REVIEW_PATHS=(new) _GIT_REVIEW_LABELS=(new)
        _GIT_REVIEW_KINDS=(untracked) _GIT_REVIEW_CONTEXTS=(Untracked) _GIT_REVIEW_DETAILS=(new)
      fi
      _GIT_REVIEW_SUMMARY="generation $generation"
      return 0
    }
    _git_review_diff_capture() {
      (( ++captures ))
      _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+new content\n'\''
      _GIT_REVIEW_TRUNCATED=0
    }
    _zle_picker_loop() {
      (( ++loops ))
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      _ZLE_PICKER_ACTION=document-refresh _ZLE_PICKER_SELECTED_VALUE=""
      case $loops in
        (1) generation=1 ;;
        (2)
          [[ ${(j:|:)_GIT_REVIEW_PATHS} == new && ${#_ZLE_PICKER_EMPTY_LINES} == 0 &&
             $_ZLE_PICKER_BROWSE_LABEL != *"previous selection"* ]] || {
            print -u2 "empty review did not discover a newly changed file"; return 71
          }
          _ZLE_PICKER_ACTION=inspect _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (3) generation=2 _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (4)
          [[ $_GIT_REVIEW_PATHS[1] == new && $_ZLE_PICKER_DOCUMENT_KEY == 1 &&
             ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"+new content"* &&
             $_ZLE_PICKER_BROWSE_LABEL == *"refresh failed"* && $captures == 1 ]] || return 72
          generation=3 _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (5)
          [[ $_ZLE_PICKER_BROWSE_LABEL != *"failed"* && $captures == 2 ]] || return 73
          generation=4 _ZLE_PICKER_SELECTED_VALUE=1 _ZLE_PICKER_BOOKMARK_FOCUS=1 ;;
        (6)
          [[ ${#_GIT_REVIEW_PATHS} == 0 && -z $_ZLE_PICKER_DOCUMENT_KEY &&
             ${#_ZLE_PICKER_DOCUMENT_LINES} == 0 && $_zle_picker_start_focus == 0 &&
             ${(F)_ZLE_PICKER_EMPTY_LINES} == *"No changes"* ]] || return 74
          abort_status=130 ;;
        (*) return 75 ;;
      esac
    }
    _git_review_view /fixture working
    [[ $? == 130 && $loops == 6 ]] || exit 1
    print recovered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal recovered "$output"
}
test_case 'Git workspace refresh handles empty new removed failed retry and aborted observations' _test_git_refresh_empty_failure

_test_git_refresh_filter_commit() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    _zle_picker_capture() { shift 3; "$@"; }
    local -i loops=0 generation=0 list_reads=0 preparation=0 captures=0
    local oid_fixture=${(l:40::a:)} parent_fixture=${(l:40::b:)}
    _git_review_prepare() { _GIT_REVIEW_CONFIG=(changed); return $preparation; }
    _git_review_commit_files_capture() {
      [[ $2 == "$oid_fixture" && $3 == "$parent_fixture" ]] || return 91
      (( ++list_reads ))
      _git_review_reset
      _GIT_REVIEW_PATHS=(alpha beta) _GIT_REVIEW_KINDS=(commit commit)
      (( generation )) && { _GIT_REVIEW_PATHS=(alpha); _GIT_REVIEW_KINDS=(commit); }
      _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}")
      _GIT_REVIEW_CONTEXTS=("${_GIT_REVIEW_KINDS[@]}")
      _GIT_REVIEW_DETAILS=("${_GIT_REVIEW_PATHS[@]}")
      _GIT_REVIEW_SUMMARY=commit
    }
    _git_review_diff_capture() {
      [[ $4 == "$oid_fixture" && $5 == "$parent_fixture" ]] || return 92
      (( ++captures ))
      _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-old\n+new\n'\''
      _GIT_REVIEW_TRUNCATED=0
    }
    _zle_picker_loop() {
      (( ++loops ))
      _ZLE_PICKER_SELECTED_VALUE=2 _ZLE_PICKER_ACTION=document-refresh
      _ZLE_PICKER_BOOKMARK=(beta 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=1
      case $loops in
        (1) _ZLE_PICKER_ACTION=inspect ;;
        (2) generation=1 ;;
        (3)
          [[ $1 == beta && $_zle_picker_start_focus == 0 && -z $_ZLE_PICKER_DOCUMENT_KEY &&
             ${#_ZLE_PICKER_DOCUMENT_LINES} == 0 && ${#_ZLE_PICKER_EMPTY_LINES} == 0 &&
             $_ZLE_PICKER_BROWSE_LABEL == *"previous selection no longer in results"* ]] || return 71
          _ZLE_PICKER_SELECTED_VALUE="" _ZLE_PICKER_BOOKMARK=(alpha 1 0) ;;
        (4)
          [[ $1 == alpha && $_ZLE_PICKER_DOCUMENT_KEY == 1 && $list_reads == 3 ]] || return 72
          _GIT_REVIEW_CONFIG=(previous) preparation=2
          _ZLE_PICKER_SELECTED_VALUE=1 _ZLE_PICKER_BOOKMARK=(alpha 1 0) ;;
        (5)
          [[ $_GIT_REVIEW_CONFIG[1] == previous && $list_reads == 3 &&
             $_ZLE_PICKER_DOCUMENT_KEY == 1 && $_ZLE_PICKER_BROWSE_LABEL == *"refresh failed"* ]] || return 73
          _ZLE_PICKER_SELECTED_VALUE=1 _ZLE_PICKER_ACTION=document-full
          _ZLE_PICKER_BOOKMARK=(alpha 1 0) ;;
        (6)
          [[ $captures == 2 && ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"safety configuration"* ]] || {
            print -u2 "failed safety refresh must block uncached diff reads"; return 75
          }
          preparation=0 _ZLE_PICKER_SELECTED_VALUE=1 _ZLE_PICKER_BOOKMARK=(alpha 1 0) ;;
        (7)
          [[ $captures == 3 && ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"+new"* ]] || return 76
          return 1 ;;
        (*) return 74 ;;
      esac
    }
    _git_review_view /fixture files "" "$oid_fixture" "$parent_fixture"
    [[ $? == 1 && $loops == 7 ]] || exit 1
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'Git workspace refresh preserves filtered-empty context immutable commit IDs and failed configuration safety' _test_git_refresh_filter_commit
