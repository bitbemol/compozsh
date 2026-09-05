_test_git_atlas_groups() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    (( ${+functions[_git_review_atlas_rows]} )) || { print -u2 missing-atlas; exit 1; }
    local -a _GIT_REVIEW_PATHS=(src/a src/a src/deep/b README $'"'"'odd\n%/file'"'"')
    local -a _GIT_REVIEW_KINDS=(staged unstaged untracked staged conflict)
    local -a _GIT_REVIEW_LABELS=(a a b README odd)
    local -a _atlas_values=() _atlas_labels=()
    local -A _atlas_details=() _atlas_groups=()
    _git_review_atlas_rows "" || exit 2
    local key=src/
    [[ ${#_atlas_values} == 3 && $_atlas_groups[$key] == "1 2 3" ]] || exit 3
    [[ ${(j:|:)_atlas_labels} == *"3 entries"* && ${(j:|:)_atlas_labels} == *"README"* ]] || exit 4
    _git_review_atlas_rows src/ || exit 5
    [[ ${#_atlas_values} == 3 && $_atlas_values[1] == f:1 && $_atlas_values[2] == f:2 &&
       $_atlas_values[3] == d:src/deep/ ]] || exit 6
    _git_review_atlas_rows src/deep/
    [[ $_atlas_values[1] == f:3 ]] || exit 7
    print atlas
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal atlas "$output"
}
test_case 'Git atlas groups captured exact paths and preserves staged unstaged identities' _test_git_atlas_groups

_test_git_atlas_blocked_reads() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/support/.zsh.ui"
    local -a _GIT_REVIEW_PATHS=(file) _GIT_REVIEW_KINDS=(unstaged)
    local -a _GIT_REVIEW_LABELS=(file) _GIT_REVIEW_CONTEXTS=(Modified)
    local -i _git_review_reads_blocked=1 visits=0 notices=0
    _git_review_view() { print -u2 unsafe-atlas-read; return 81; }
    _zle_ui_read_text() { (( ++notices )); return 1; }
    _zle_picker_loop() {
      (( ++visits ))
      (( visits == 1 )) || return 1
      _ZLE_PICKER_SELECTED_VALUE=f:1 _ZLE_PICKER_BOOKMARK=("" 1 0)
      return 0
    }
    _git_review_atlas /example/repo
    [[ $? == 1 && $notices == 1 ]] || exit 1
  ' "$TEST_REPO_ROOT"
}
test_case 'Git atlas preserves a failed safety preparation block on uncached file reads' _test_git_atlas_blocked_reads

_test_git_atlas_comparison_scope() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/support/.zsh.ui"
    local -a _GIT_REVIEW_PATHS=(src/file) _GIT_REVIEW_KINDS=(comparison)
    local -a _GIT_REVIEW_LABELS=(file) _GIT_REVIEW_CONTEXTS=(Modified) _GIT_REVIEW_DETAILS=()
    local _ZLE_PICKER_SUBTITLE="Against main @ aaaa → Compare topic @ bbbb"
    local -a _ZLE_PICKER_GUIDE_CONTEXT=("Full endpoint aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_SUBTITLE == *"Against main @ aaaa"* && $_ZLE_PICKER_SUBTITLE == *"Compare topic @ bbbb"* &&
         ${(j:|:)_ZLE_PICKER_GUIDE_CONTEXT} == *aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa* &&
         ${(j:|:)_ZLE_PICKER_INSPECT_TEXTS} == *"1 committed"* ]] || return 12
      return 1
    }
    _git_review_atlas /repo bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
    [[ $? == 1 ]] || exit 1
  ' "$TEST_REPO_ROOT"
}
test_case 'Git atlas retains comparison endpoint scope and distinguishes committed entry counts' _test_git_atlas_comparison_scope
