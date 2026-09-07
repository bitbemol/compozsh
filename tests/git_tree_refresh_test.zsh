_test_git_tree_refresh_projection() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local mode="" view="" selection="" selected_row="" expected_row=""
    local context=3 focus=1 _git_file_view=tree _git_tree_scope="" _git_tree_filter="" _git_tree_exclude="" _git_tree_filter_scope=""
    local _ZLE_PICKER_OPTIONS_KIND=file-views _ZLE_PICKER_DOCUMENT_KEY=3
    local -A _git_tree_expanded=() _git_tree_filter_expanded=() _git_tree_depths=()
    local -A _git_document_contexts=() _git_document_anchors=() _git_document_cache=() _git_document_partial=()
    local -A _ZLE_PICKER_DOCUMENT_ROWS=(3 77)
    local -a _GIT_REVIEW_PATHS=() _GIT_REVIEW_LABELS=() _GIT_REVIEW_KINDS=() _GIT_REVIEW_CONTEXTS=()
    local -a _git_auto_candidate_paths=(aa/new a/x b/y c/z)
    local -a _git_auto_candidate_labels=(aa/new a/x b/y c/z)
    local -a _git_auto_candidate_kinds=(unstaged unstaged unstaged unstaged)
    local -a _git_auto_candidate_contexts=(M M M M)
    local -a bookmark=()
    local _git_auto_candidate_request_name=c/z _git_auto_candidate_request_kind=unstaged _git_auto_candidate_request_context=3
    local -i original_rank=0 wanted_slot=2 load_failure=0
    _git_review_document_reset() { _ZLE_PICKER_DOCUMENT_KEY=""; }
    _git_review_document_load() { _ZLE_PICKER_DOCUMENT_KEY=$2; }
    _git_review_document_anchor() { REPLY="new:$1"; }
    _git_review_auto_candidate_clear() { :; }
    _git_review_status_apply() { :; }
    _git_review_load() {
      (( load_failure )) && return 1
      _GIT_REVIEW_PATHS=("${_git_auto_candidate_paths[@]}")
      _GIT_REVIEW_LABELS=("${_git_auto_candidate_labels[@]}")
      _GIT_REVIEW_KINDS=("${_git_auto_candidate_kinds[@]}")
      _GIT_REVIEW_CONTEXTS=("${_git_auto_candidate_contexts[@]}")
    }
    for mode in auto manual failed; do
      for view in tree flat; do
        for selection in file folder; do
          [[ $view == flat && $selection == folder ]] && continue
          _git_file_view=$view _ZLE_PICKER_DOCUMENT_KEY=3 focus=1 context=3
          _GIT_REVIEW_PATHS=(a/x b/y c/z)
          _GIT_REVIEW_LABELS=("${_GIT_REVIEW_PATHS[@]}")
          _GIT_REVIEW_KINDS=(unstaged unstaged unstaged) _GIT_REVIEW_CONTEXTS=(M M M)
          bookmark=("" 1 0 excluded 0 1)
          _git_review_rows
          _git_review_file_reselect 3
          selected_row=3 expected_row=4
          [[ $selection == folder ]] && selected_row=d:b/ expected_row=d:b/
          original_rank=${_ZLE_PICKER_RESULTS[(Ie)$selected_row]}
          bookmark[2]=$original_rank bookmark[3]=$(( original_rank - wanted_slot ))
          if [[ $mode == auto ]]; then
            _git_review_auto_publish root "$selected_row"
          else
            [[ $mode == failed ]] && load_failure=1 || load_failure=0
            _git_review_refresh root working "" "" 3 "$selected_row"
          fi
          if [[ $mode == failed ]]; then
            [[ $bookmark[2] == $original_rank && $bookmark[3] == $((original_rank-wanted_slot)) &&
               $_ZLE_PICKER_DOCUMENT_KEY == 3 ]] || { print -u2 "failed refresh changed $view $selection bookmark"; exit 1; }
            continue
          fi
          [[ ${_ZLE_PICKER_RESULTS[bookmark[2]]} == "$expected_row" &&
             $(( bookmark[2] - bookmark[3] )) == $wanted_slot ]] || {
            print -u2 -r -- "$mode $view $selection lost projected row or slot: $bookmark; $_ZLE_PICKER_RESULTS"; exit 2
          }
          [[ $_ZLE_PICKER_DOCUMENT_KEY == 4 && $_GIT_REVIEW_PATHS[4] == c/z &&
             ${_git_document_anchors[4]} == new:77 && $focus == 1 && $context == 3 &&
             $bookmark[4] == excluded && $bookmark[6] == 1 ]] || {
            print -u2 "$mode $view $selection lost reader identity anchor focus or filter"; exit 3
          }
        done
      done
    done
    _git_auto_candidate_paths=() _git_auto_candidate_labels=()
    _git_auto_candidate_kinds=() _git_auto_candidate_contexts=()
    for mode in auto manual; do
      _git_file_view=tree _ZLE_PICKER_DOCUMENT_KEY=3 focus=1 context=3 load_failure=0
      _GIT_REVIEW_PATHS=(a/x b/y c/z) _GIT_REVIEW_LABELS=(a/x b/y c/z)
      _GIT_REVIEW_KINDS=(unstaged unstaged unstaged) _GIT_REVIEW_CONTEXTS=(M M M)
      bookmark=("" 6 4)
      if [[ $mode == auto ]]; then
        _git_review_auto_publish root 3
      else
        _git_review_refresh root working "" "" 3 3
      fi
      [[ ${#_ZLE_PICKER_RESULTS} == 0 && $bookmark[3] == 0 &&
         -z $_ZLE_PICKER_DOCUMENT_KEY && $focus == 0 ]] || {
        print -u2 "$mode empty refresh retained an obsolete slot or document"; exit 4
      }
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'Git refresh preserves projected file and folder slots across snapshot insertion and failed captures' _test_git_tree_refresh_projection
