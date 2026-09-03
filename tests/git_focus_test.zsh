# Focused/full presentation changes retain source positions, not screen rows.
_test_git_focus_default() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    _git_review_load() {
      _GIT_REVIEW_PATHS=(file) _GIT_REVIEW_LABELS=(file)
      _GIT_REVIEW_KINDS=(unstaged) _GIT_REVIEW_CONTEXTS=(M) _GIT_REVIEW_DETAILS=(ready)
    }
    local -i captures=0 loops=0
    _git_review_diff_capture() {
      [[ $6 == 3 ]] || { print -u2 "default review must request three context lines, got $6"; return 2; }
      (( ++captures ))
      _GIT_REVIEW_DATA=$'\''@@ -30 +30 @@\n-old\n+new\n'\''
    }
    _zle_picker_loop() {
      (( ++loops == 1 )) || return 1
      _ZLE_PICKER_SELECTED_VALUE=1 _ZLE_PICKER_ACTION=inspect
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
    }
    _git_review_view /fixture working
    (( captures == 1 )) || exit 1
    print focused
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal focused "$output"
}
test_case 'Git focused review requests compact context by default' _test_git_focus_default

_test_git_focus_coordinates() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    (( ${+functions[_git_review_document_anchor]} && ${+functions[_git_review_document_seek]} )) || {
      print -u2 "source-line anchoring is missing"; exit 1
    }
    _GIT_REVIEW_DATA=$'\''@@ -10,3 +10,3 @@\n before\n-old\n+new\n after\n@@ -30,3 +30,3 @@\n before\n-old\n+new\n after\n'\''
    _GIT_REVIEW_TRUNCATED=0
    _git_review_document_parse
    _git_review_document_anchor 1
    [[ $REPLY == new:10 ]] || exit 2
    _git_review_document_anchor 3
    [[ $REPLY == old:11 ]] || exit 3
    _git_review_document_seek old:31
    [[ $REPLY == 8 ]] || exit 4
    _git_review_document_seek new:31
    [[ $REPLY == 9 ]] || exit 5
    # Unchanged gaps choose nearest retained context; exact ties go earlier.
    _git_review_document_seek new:21
    [[ $REPLY == 5 ]] || exit 6
    _git_review_document_seek new:22
    [[ $REPLY == 7 ]] || exit 7
    _git_review_document_seek new:1
    [[ $REPLY == 2 ]] || exit 8
    _git_review_document_seek new:9000
    [[ $REPLY == 10 ]] || exit 9
    _GIT_REVIEW_DATA="Binary files differ"
    _git_review_document_parse
    _git_review_document_seek old:31
    [[ $REPLY == 0 ]] || exit 10
    # Pure deletions use old coordinates; insertions use new coordinates.
    _GIT_REVIEW_DATA=$'\''@@ -1,2 +0,0 @@\n-one\n-two\n'\''
    _git_review_document_parse
    _git_review_document_anchor 1
    [[ $REPLY == old:1 ]] || exit 11
    _git_review_document_seek old:2
    [[ $REPLY == 3 ]] || exit 12
    _GIT_REVIEW_DATA=$'\''@@ -0,0 +1,2 @@\n+one\n+two\n'\''
    _git_review_document_parse
    _git_review_document_anchor 1
    [[ $REPLY == new:1 ]] || exit 13
    print coordinates
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal coordinates "$output"
}
test_case 'Git focused review maps old and new source lines with deterministic nearest-context fallback' _test_git_focus_coordinates

_test_git_focus_wrap() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_DOCUMENT_LINES=("a long source line wrapping several times" "next source line")
    _ZLE_PICKER_DOCUMENT_ROLES=(text text)
    _ZLE_PICKER_INSPECT_TEXTS=(one ready two ready)
    _zle_picker_inspect_prepare one 10
    _ZLE_PICKER_INSPECT_OFFSET=2
    _zle_picker_inspect_prepare two 10
    [[ $_ZLE_PICKER_DOCUMENT_ROWS[one] == 1 ]] || {
      print -u2 "wrapped continuation must bookmark its logical source line"; exit 1
    }
    # A mode switch requests a logical row after new content is wrapped.
    _ZLE_PICKER_DOCUMENT_TARGET_ROW=2
    _zle_picker_inspect_prepare one 10
    (( _ZLE_PICKER_INSPECT_OFFSET > 0 && !_ZLE_PICKER_DOCUMENT_TARGET_ROW )) || exit 2
    [[ $_ZLE_PICKER_INSPECT_SOURCE_LINES[_ZLE_PICKER_INSPECT_OFFSET+1] == 2 ]] || exit 4
    [[ $_ZLE_PICKER_INSPECT_LINES[_ZLE_PICKER_INSPECT_OFFSET+1] == "next sour"* ]] || exit 3
    print wrapped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal wrapped "$output"
}
test_case 'Git focused review anchors wrapped lines and restores into the newly wrapped document' _test_git_focus_wrap

_test_git_focus_transition() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(one two) _GIT_REVIEW_KINDS=(unstaged staged)
    local focused=$'\''@@ -10,3 +10,3 @@\n before\n-old\n+new\n after\n@@ -30,3 +30,3 @@\n before\n-old\n+new\n after\n'\''
    local full=$'\''@@ -1,50 +1,50 @@\n'\'' i=0 captures=0
    for ((i=1; i<=50; ++i)); do
      if (( i == 11 || i == 31 )); then full+=$'\''-old\n+new\n'\''
      else full+=" line $i"$'\''\n'\''; fi
    done
    _git_review_diff_capture() {
      (( ++captures ))
      _GIT_REVIEW_DATA=$focused
      [[ $6 == 3 ]] || _GIT_REVIEW_DATA=$full
      _GIT_REVIEW_TRUNCATED=0
    }
    _ZLE_PICKER_DOCUMENT=1
    _git_review_document_load /fixture 1 "" "" 3
    _ZLE_PICKER_DOCUMENT_ROWS[1]=9  # +new at source line 31
    _git_review_document_load /fixture 1 "" "" 1000000000
    (( _ZLE_PICKER_DOCUMENT_TARGET_ROW > 30 )) || {
      print -u2 "expansion lost the selected source area"; exit 1
    }
    [[ $_GIT_REVIEW_DOCUMENT_NEW[_ZLE_PICKER_DOCUMENT_TARGET_ROW] == 31 ]] || exit 2
    _ZLE_PICKER_DOCUMENT_ROWS[1]=$_ZLE_PICKER_DOCUMENT_TARGET_ROW
    _ZLE_PICKER_DOCUMENT_OFFSETS[1]=17
    _git_review_document_load /fixture 1 "" "" 1000000000
    [[ $_ZLE_PICKER_DOCUMENT_TARGET_ROW == 0 && $_ZLE_PICKER_DOCUMENT_OFFSETS[1] == 17 && $captures == 2 ]] || exit 7
    _git_review_document_load /fixture 1 "" "" 3
    [[ $_ZLE_PICKER_DOCUMENT_TARGET_ROW == 9 && $captures == 2 ]] || exit 3
    # A different file must keep its own source area when the global mode changed.
    _ZLE_PICKER_DOCUMENT_ROWS[1]=3  # old line 11
    _git_review_document_load /fixture 2 "" "" 3
    _ZLE_PICKER_DOCUMENT_ROWS[2]=9
    _git_review_document_load /fixture 2 "" "" 1000000000
    _ZLE_PICKER_DOCUMENT_ROWS[2]=$_ZLE_PICKER_DOCUMENT_TARGET_ROW
    _git_review_document_load /fixture 1 "" "" 1000000000
    [[ $_GIT_REVIEW_DOCUMENT_OLD[_ZLE_PICKER_DOCUMENT_TARGET_ROW] == 11 ]] || exit 4
    # Collapse from an unchanged area halfway between hunks.
    _ZLE_PICKER_DOCUMENT_ROWS[1]=23  # unchanged source line 21 (one deletion before it)
    _git_review_document_load /fixture 1 "" "" 3
    [[ $_ZLE_PICKER_DOCUMENT_TARGET_ROW == 5 && $_ZLE_PICKER_BROWSE_LABEL == *nearest* ]] || exit 5
    # A shortened / failed recapture cannot leave an out-of-range anchor.
    _ZLE_PICKER_DOCUMENT_ROWS[1]=9
    _git_document_cache[1:1000000000]="Unavailable: fixture read failed"
    _git_review_document_load /fixture 1 "" "" 1000000000
    [[ $_ZLE_PICKER_DOCUMENT_TARGET_ROW == 0 && $_ZLE_PICKER_DOCUMENT_OFFSETS[1] == 0 ]] || exit 6
    # A full capture capped before the requested area lands on retained code
    # and explicitly reports both the partial data and nearest-context move.
    _git_review_document_load /fixture 1 "" "" 3
    _ZLE_PICKER_DOCUMENT_ROWS[1]=9
    _git_document_cache[1:1000000000]=$'\''@@ -1,50 +1,50 @@\n first line\n'\''
    _git_document_partial[1:1000000000]=1
    _git_review_document_load /fixture 1 "" "" 1000000000
    [[ $_ZLE_PICKER_DOCUMENT_TARGET_ROW == 2 && $_ZLE_PICKER_BROWSE_LABEL == *partial*nearest* ]] || exit 8
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *Limits:* ]] || exit 9
    print transitions
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal transitions "$output"
}
test_case 'Git focused review preserves source areas across modes cache visits and unavailable snapshots' _test_git_focus_transition
