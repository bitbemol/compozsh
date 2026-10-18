# Whole-workspace refresh preserves literal path + kind, not reassigned IDs.
_test_git_refresh_workspace() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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
      local -a fields=("$1")
      [[ $1 == --bookmark ]] && fields=("${(@P)2}")
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
          [[ $_ZLE_PICKER_DOCUMENT_KEY == 3 && $fields[1] == same && $fields[2] == 2 && $fields[7] == 1 ]] || return 73
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
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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
      local -a fields=("$1")
      [[ $1 == --bookmark ]] && fields=("${(@P)2}")
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
             ${#_ZLE_PICKER_DOCUMENT_LINES} == 0 && ${fields[7]-0} == 0 &&
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
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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
      local -a fields=("$1")
      [[ $1 == --bookmark ]] && fields=("${(@P)2}")
      _ZLE_PICKER_SELECTED_VALUE=2 _ZLE_PICKER_ACTION=document-refresh
      _ZLE_PICKER_BOOKMARK=(beta 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=1
      case $loops in
        (1) _ZLE_PICKER_ACTION=inspect ;;
        (2) generation=1 ;;
        (3)
          [[ $fields[1] == beta && ${fields[7]-0} == 0 && -z $_ZLE_PICKER_DOCUMENT_KEY &&
             ${#_ZLE_PICKER_DOCUMENT_LINES} == 0 && ${#_ZLE_PICKER_EMPTY_LINES} == 0 &&
             $_ZLE_PICKER_BROWSE_LABEL == *"previous selection no longer in results"* ]] || return 71
          _ZLE_PICKER_SELECTED_VALUE="" _ZLE_PICKER_BOOKMARK=(alpha 1 0) ;;
        (4)
          [[ $fields[1] == alpha && $_ZLE_PICKER_DOCUMENT_KEY == 1 && $list_reads == 3 ]] || return 72
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

# List-mode selection rebind after a successful recapture, for both refresh
# paths side by side. Both bind the selection by literal path and change kind
# and keep a surviving item's visible slot. When the selection vanished, Ctrl-R
# reads the first match and automatic publication reads nothing.
_test_git_refresh_list_rebind() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local mode="" scenario="" loaded="" loaded_data="" context=3 _ZLE_PICKER_OPTIONS_KIND=""
    local -i focus=1 _ZLE_PICKER_DOCUMENT=1
    local _ZLE_PICKER_DOCUMENT_KEY=5 _git_review_event_status=""
    local -A _ZLE_PICKER_DOCUMENT_ROWS=(5 77)
    local -A _git_document_contexts=() _git_document_anchors=() _git_document_cache=() _git_document_partial=()
    local -a _GIT_REVIEW_PATHS=() _GIT_REVIEW_LABELS=() _GIT_REVIEW_KINDS=() _GIT_REVIEW_CONTEXTS=()
    local -a _GIT_REVIEW_DETAILS=() _GIT_REVIEW_PARENTS=() _GIT_REVIEW_CONFIG=()
    local -a _git_auto_candidate_paths=() _git_auto_candidate_labels=() _git_auto_candidate_kinds=()
    local -a _git_auto_candidate_contexts=() _git_auto_candidate_details=() _git_auto_candidate_parents=()
    local -a _git_auto_candidate_config=() bookmark=() expected=()
    local _git_auto_candidate_request_name=e _git_auto_candidate_request_kind=unstaged
    local _git_auto_candidate_request_context=3 _git_auto_candidate_diff_data=CAPTURED
    local -i _git_auto_candidate_diff_truncated=0 _git_auto_candidate_list_truncated=0
    _git_review_document_load() {
      _ZLE_PICKER_DOCUMENT_KEY=$2 loaded=${_GIT_REVIEW_PATHS[$2]}/${_GIT_REVIEW_KINDS[$2]}
      _git_review_document_cache_key "$2" "$5"
      loaded_data=${_git_document_cache[$REPLY]-}
    }
    _git_review_document_anchor() { REPLY="new:$1"; }
    _git_review_auto_candidate_clear() { :; }
    _git_review_status_apply() { :; }
    _git_review_load() {
      _GIT_REVIEW_PATHS=("${_git_auto_candidate_paths[@]}")
      _GIT_REVIEW_LABELS=("${_git_auto_candidate_labels[@]}")
      _GIT_REVIEW_KINDS=("${_git_auto_candidate_kinds[@]}")
      _GIT_REVIEW_CONTEXTS=("${_git_auto_candidate_contexts[@]}")
      _GIT_REVIEW_DETAILS=("${_git_auto_candidate_details[@]}")
      _GIT_REVIEW_PARENTS=("${_git_auto_candidate_parents[@]}")
    }
    for scenario in inserted vanished; do
      for mode in auto manual; do
        _GIT_REVIEW_PATHS=(a b c d e f) _GIT_REVIEW_LABELS=(a b c d e f)
        _GIT_REVIEW_KINDS=(unstaged unstaged unstaged unstaged unstaged unstaged)
        _GIT_REVIEW_CONTEXTS=(M M M M M M) _GIT_REVIEW_DETAILS=(a b c d e f)
        _GIT_REVIEW_PARENTS=("" "" "" "" "" "")
        if [[ $scenario == inserted ]]; then
          # The same path with another kind lands above the selection too.
          _git_auto_candidate_paths=(n e a b c d e f)
          _git_auto_candidate_kinds=(untracked staged unstaged unstaged unstaged unstaged unstaged unstaged)
        else
          _git_auto_candidate_paths=(n a b c d f)
          _git_auto_candidate_kinds=(untracked unstaged unstaged unstaged unstaged unstaged)
        fi
        _git_auto_candidate_labels=("${_git_auto_candidate_paths[@]}")
        _git_auto_candidate_details=("${_git_auto_candidate_paths[@]}")
        _git_auto_candidate_contexts=("${_git_auto_candidate_kinds[@]}")
        _git_auto_candidate_parents=("${_git_auto_candidate_paths[@]/*/}")
        _ZLE_PICKER_DOCUMENT_KEY=5 focus=1 context=3 loaded="" loaded_data="" _git_review_event_status=""
        _git_document_anchors=() _ZLE_PICKER_DOCUMENT_ROWS=(5 77)
        bookmark=("" 5 2)
        _git_review_rows
        if [[ $mode == auto ]]; then
          _git_review_auto_publish root 5 || exit 10
        else
          _git_review_refresh root working "" "" 5 5 || exit 11
        fi
        case $scenario/$mode in
          (inserted/auto) expected=("" 7 4 1 3 e/unstaged CAPTURED "updated automatically") ;;
          (inserted/manual) expected=("" 7 4 1 3 e/unstaged "" refreshed) ;;
          (vanished/auto) expected=("" 1 0 0 3 "" "" "updated automatically · previous selection no longer in results") ;;
          (vanished/manual) expected=("" 1 0 0 3 n/untracked "" "refreshed · previous selection no longer in results") ;;
        esac
        [[ "${(j:|:)bookmark[1,3]}|$focus|$context|$loaded|$loaded_data|$_git_review_event_status" == "${(j:|:)expected}" ]] || {
          print -u2 -r -- "$scenario $mode: ${(j:|:)bookmark[1,3]}|$focus|$context|$loaded|$loaded_data|$_git_review_event_status"
          exit 2
        }
        if [[ $scenario == inserted ]]; then
          [[ $_ZLE_PICKER_DOCUMENT_KEY == 7 && ${_git_document_anchors[7]-} == new:77 &&
             ${_git_document_contexts[7]-} == refresh ]] || {
            print -u2 -r -- "$scenario $mode lost reader identity or anchor: $_ZLE_PICKER_DOCUMENT_KEY ${(kv)_git_document_anchors} ${(kv)_git_document_contexts}"; exit 3
          }
        fi
      done
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'Git manual and automatic refresh keep their selection row and visible slot after inserts above the selection' _test_git_refresh_list_rebind
