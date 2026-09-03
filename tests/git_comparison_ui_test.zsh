# Compare captured choices without losing direction or displaying stale facts.
_test_git_comparison_ui_subtitle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    local root=/repository/project-name _git_compare_method=exact
    local _git_compare_from=${(l:40::a:)} _git_compare_to=${(l:40::b:)} _git_compare_before=${(l:40::c:)}
    local _git_compare_from_label=release/next _git_compare_to_label=feature/allow-revision-review
    local _git_compare_context="" _git_compare_method_label=""
    _ZLE_PICKER_TITLE="Git comparison" _ZLE_PICKER_SUBTITLE_RENDERER=_git_review_comparison_subtitle
    _git_review_capture() { print -u2 unexpected-provider; exit 90; }
    LINES=24
    for _git_compare_to_label in feature/allow-revision-review "功能/审查很长的分支名称" $'\''feature/\e[31m%-review'\''; do
      for _git_compare_method in exact ancestor; do
        _git_review_comparison_context
        _ZLE_PICKER_SUBTITLE="$_git_compare_context · ${root:t}"
        for COLUMNS in 60 80 90 120; do
          _zle_picker_render "" 0
          [[ $_ZLE_PICKER_SUBTITLE_ROW == *" → To "* && $_ZLE_PICKER_SUBTITLE_ROW == *bbbbbbbbbbbb* ]] || exit 1
          [[ $_ZLE_PICKER_SUBTITLE_ROW != *$'\''\e'\''* ]] || exit 2
          (( ${(m)#_ZLE_PICKER_SUBTITLE_ROW} <= COLUMNS - 1 )) || exit 3
          if [[ $_git_compare_method == ancestor ]]; then
            [[ $_ZLE_PICKER_SUBTITLE_ROW == "Ancestor cccccccccccc"* ]] || exit 4
          else
            [[ $_ZLE_PICKER_SUBTITLE_ROW == From* && $_ZLE_PICKER_SUBTITLE_ROW == *aaaaaaaaaaaa* ]] || exit 5
          fi
        done
      done
    done
    COLUMNS=80
    _ZLE_PICKER_SUBTITLE="Plain caller context"
    _ZLE_PICKER_SUBTITLE_RENDERER=missing_formatter
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_SUBTITLE_ROW == "Plain caller context" ]] || exit 6
    _test_failed_formatter() { REPLY=unusable; return 1; }
    _ZLE_PICKER_SUBTITLE_RENDERER=_test_failed_formatter
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_SUBTITLE_ROW == "Plain caller context" ]] || exit 7
    _test_busy_formatter() { print -u2 unexpected-busy-formatter; exit 91; }
    _ZLE_PICKER_SUBTITLE_RENDERER=_test_busy_formatter _ZLE_PICKER_BUSY=1
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_SUBTITLE_ROW == "Plain caller context" ]] || exit 8
    print oriented
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal oriented "$output"
}
test_case 'Git comparison UI retains direction IDs and safe Unicode labels across narrow layouts' _test_git_comparison_ui_subtitle

_test_git_comparison_ui_missing_endpoint() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    _git_review_load() { "$@"; }
    _git_review_resolve() { return 1; }
    _git_review_endpoint_choose() { REPLY=${(l:40::a:)}; _git_compare_label=main; }
    local -i step=0
    _zle_picker_loop() {
      (( ++step ))
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      if (( step == 1 )); then _ZLE_PICKER_SELECTED_VALUE=from; return 0; fi
      [[ $3 == 1 && $_ZLE_PICKER_BROWSE_LABEL == *"Choose Compare"* && ${_NAVIGATION_PICKER_VALUES[(Ie)open]} == 0 ]] || exit 1
      return 1
    }
    _git_review_compare_choose /repository ""
    [[ $? == 1 && $step == 2 ]] || exit 2
    print missing
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal missing "$output"
}
test_case 'Git comparison UI focuses and names the remaining missing endpoint' _test_git_comparison_ui_missing_endpoint

_test_git_comparison_ui_draft_ancestor() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    _git_review_load() { "$@"; }
    _git_review_resolve() { REPLY=${(l:40::b:)}; }
    _git_review_endpoint_choose() {
      if [[ $2 == From ]]; then REPLY=${(l:40::a:)}; _git_compare_label=main
      else REPLY=${(l:40::d:)}; _git_compare_label=other-topic; fi
    }
    _git_review_prepare() { return 0; }
    local -i step=0 captures=0
    _git_review_compare_base() { (( ++captures )); REPLY=${(l:40::c:)}; }
    _git_review_view() { return 1; }
    _zle_picker_loop() {
      (( ++step ))
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      case $step in
        (1) _ZLE_PICKER_SELECTED_VALUE=from;;
        (2) _ZLE_PICKER_SELECTED_VALUE=method;;
        (3) _ZLE_PICKER_SELECTED_VALUE=ancestor;;
        (4) [[ $_ZLE_PICKER_INSPECT_TEXTS[open] == *"Common ancestor of main and topic"* && $captures == 0 ]] || exit 1
            _ZLE_PICKER_SELECTED_VALUE=open;;
        (5) [[ $_git_compare_before == ${(l:40::c:)} && $captures == 1 ]] || exit 2
            _ZLE_PICKER_SELECTED_VALUE=to;;
        (6) [[ -z $_git_compare_before && $_ZLE_PICKER_INSPECT_TEXTS[open] == *"Common ancestor of main and other-topic"* && $_ZLE_PICKER_INSPECT_TEXTS[open] != *cccccccccccc* ]] || exit 3
            _ZLE_PICKER_SELECTED_VALUE=open;;
        (7) _ZLE_PICKER_SELECTED_VALUE=method;;
        (8) _ZLE_PICKER_SELECTED_VALUE=exact;;
        (9) [[ -z $_git_compare_before && $captures == 2 && $_ZLE_PICKER_INSPECT_TEXTS[open] != *Ancestor* ]] || exit 4
            return 1;;
        (*) exit 5;;
      esac
      return 0
    }
    _git_review_compare_choose /repository topic
    [[ $? == 1 && $step == 9 ]] || exit 6
    print draft
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal draft "$output"
}
test_case 'Git comparison UI separates unresolved choices from captured ancestor facts' _test_git_comparison_ui_draft_ancestor

_test_git_comparison_ui_guide() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    local _git_compare_method=ancestor _git_compare_method_label="Since common ancestor"
    local _git_compare_from=${(l:64::a:)} _git_compare_to=${(l:64::b:)} _git_compare_before=${(l:64::c:)}
    local _git_compare_from_label=main _git_compare_to_label=topic _git_compare_context="Captured comparison"
    _git_review_load() { "$@"; }
    _git_review_comparison_files_capture() { return 0; }
    _git_review_rows() { return 0; }
    _git_review_syntax_cleanup() { return 0; }
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_SUBTITLE_RENDERER == _git_review_comparison_subtitle ]] || exit 1
      LINES=80
      _zle_picker_guide_render 79
      local guide=${(F)_ZLE_PICKER_DISPLAY}
      [[ $guide == *"$_git_compare_before"* && $guide == *"$_git_compare_to"* && $guide == *"$_git_compare_from"* ]] || exit 2
      [[ $guide != *"staged and unstaged"* && $guide != *"another tool edits files"* ]] || exit 3
      [[ $guide == *"same IDs"* ]] || exit 4
      return 1
    }
    _git_review_view /repository comparison "" "$_git_compare_to" "$_git_compare_before"
    [[ $? == 1 && -z $_ZLE_PICKER_SUBTITLE_RENDERER ]] || exit 5
    print guide
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal guide "$output"
}
test_case 'Git comparison UI exposes complete SHA256 endpoints and accurate snapshot guidance' _test_git_comparison_ui_guide

# Both branch choices remain visible and independently editable in the setup.
_test_git_comparison_ui_pair_choices() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    _git_review_load() { "$@"; }
    _git_review_resolve() { REPLY=${(l:40::a:)}; }
    _git_review_prepare() { return 0; }
    _git_review_compare_base() { REPLY=$3; }
    _git_review_endpoint_choose() {
      if [[ $2 == From ]]; then REPLY=${(l:40::b:)}; _git_compare_label=release/next
      else REPLY=${(l:40::c:)}; _git_compare_label=feature/search; fi
    }
    local -i step=0 views=0
    _git_review_view() {
      [[ $4 == ${(l:40::c:)} && $5 == ${(l:40::b:)} ]] || exit 9
      (( ++views ))
      return 1
    }
    _zle_picker_loop() {
      (( ++step ))
      _ZLE_PICKER_BOOKMARK=("" 2 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      case $step in
        (1) [[ $_NAVIGATION_PICKER_VALUES[1] == to && $_NAVIGATION_PICKER_VALUES[2] == from && $3 == 2 ]] || exit 1
            [[ $_NAVIGATION_PICKER_LABELS[1] == "Compare · topic" && $_NAVIGATION_PICKER_LABELS[2] == "Against · Choose branch or commit…" ]] || exit 2
            [[ $_ZLE_PICKER_INSPECT_TEXTS[to] == *"Enter changes"* && $_ZLE_PICKER_INSPECT_TEXTS[from] == *topic* ]] || exit 3
            _ZLE_PICKER_SELECTED_VALUE=from ;;
        (2) [[ $3 == 4 && $_NAVIGATION_PICKER_LABELS[2] == "Against · release/next" && $_ZLE_PICKER_INSPECT_TEXTS[open] == *"Compare topic against release/next"* ]] || exit 4
            _ZLE_PICKER_SELECTED_VALUE=to ;;
        (3) [[ $_NAVIGATION_PICKER_LABELS[1] == "Compare · feature/search" && $_NAVIGATION_PICKER_LABELS[2] == "Against · release/next" ]] || exit 5
            _ZLE_PICKER_SELECTED_VALUE=method ;;
        (4) [[ $_NAVIGATION_PICKER_LABELS[1] == "All differences" && $_ZLE_PICKER_INSPECT_TEXTS[ancestor] == *feature/search* && $_ZLE_PICKER_INSPECT_TEXTS[ancestor] == *release/next* ]] || exit 6
            _ZLE_PICKER_SELECTED_VALUE=ancestor ;;
        (5) _ZLE_PICKER_SELECTED_VALUE=method ;;
        (6) [[ $3 == 2 ]] || exit 11
            _ZLE_PICKER_SELECTED_VALUE=ancestor ;;
        (7) _ZLE_PICKER_SELECTED_VALUE=open ;;
        (8) [[ $_NAVIGATION_PICKER_LABELS[1] == *feature/search* && $_NAVIGATION_PICKER_LABELS[2] == *release/next* ]] || exit 7
            return 1 ;;
        (*) exit 8 ;;
      esac
      return 0
    }
    _git_review_compare_choose /repository topic
    [[ $? == 1 && $step == 8 && $views == 1 ]] || exit 10
    print pair
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal pair "$output"
}
test_case 'Git comparison UI makes both branch choices explicit and preserves independent edits' _test_git_comparison_ui_pair_choices

_test_git_comparison_ui_ref_acceptance() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.git-review"
    _NAVIGATION_PICKER_VALUES=(1 2 3)
    _NAVIGATION_PICKER_LABELS=("main · branch" "release/next · branch" "release/old · branch")
    _NAVIGATION_PICKER_INDEXES=(1 2 3)
    _git_review_ref_collect release/next 3
    [[ $_ZLE_PICKER_RESULTS[1] == 2 && $_ZLE_PICKER_RESULTS[2] == enter ]] || exit 1
    _git_review_ref_collect release 2
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == 2,enter ]] || exit 2
    _git_review_ref_collect "" 1
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == enter ]] || exit 3
    _git_review_ref_collect missing 3
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == enter ]] || exit 4
    _git_review_ref_collect "" 2
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == 1,enter ]] || exit 5
    _git_review_ref_collect "" 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == 1,enter,2,3 ]] || exit 6
    print refs
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refs "$output"
}
test_case 'Git comparison UI accepts matching refs before offering literal entry' _test_git_comparison_ui_ref_acceptance

_test_git_comparison_ui_ref_identity() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    _git_review_load() { "$@"; }
    _git_review_refs_capture() {
      _GIT_REVIEW_REFS=(refs/heads/release refs/tags/release refs/remotes/origin/release)
      _GIT_REVIEW_REF_OIDS=(${(l:40::a:)} ${(l:40::b:)} ${(l:40::c:)})
      _GIT_REVIEW_REF_LABELS=("release · branch" "release · tag" "origin/release · remote-tracking")
    }
    _git_review_capture() { _GIT_REVIEW_DATA=${(l:40::a:)}; }
    local _git_compare_to_label=topic _git_compare_label=""
    local -i selection=1
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_SUBTITLE == *"Compare: topic"* ]] || exit 1
      _ZLE_PICKER_SELECTED_VALUE=$selection
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      return 0
    }
    _git_review_endpoint_choose /repository From || exit 2
    [[ $_git_compare_label == release ]] || exit 3
    selection=2
    _git_review_endpoint_choose /repository From || exit 4
    [[ $_git_compare_label == "release · tag" ]] || exit 5
    selection=3
    _git_review_endpoint_choose /repository From || exit 6
    [[ $_git_compare_label == "origin/release · remote-tracking" ]] || exit 7
    print identity
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal identity "$output"
}
test_case 'Git comparison UI preserves ref kind and the opposite branch while choosing' _test_git_comparison_ui_ref_identity
