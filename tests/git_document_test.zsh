# A review document is one continuous selected-file reader, not hunk pickers.
_test_git_document_layout() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_DOCUMENT=1
    _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_DOCUMENT_LINES=("  1   1  unchanged" "      2 +added")
    _ZLE_PICKER_DOCUMENT_ROLES=(text success)
    _ZLE_PICKER_INSPECT_TEXTS=(one ready two ready)
    _ZLE_PICKER_RESULTS=(one two) _ZLE_PICKER_LABELS=(first.swift second.swift)
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render "" 1
    (( _ZLE_PICKER_INSPECT_WIDTH >= 75 )) || { print -u2 "document must be the primary pane"; exit 1; }
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *first.swift* && ${(F)_ZLE_PICKER_DISPLAY} == *unchanged* ]] || exit 2
    _ZLE_PICKER_INSPECT_FOCUS=1
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *second.swift* ]] || exit 3
    COLUMNS=70
    _zle_picker_render "" 1
    (( _ZLE_PICKER_INSPECT_WIDTH == 69 && !_ZLE_PICKER_INDEXES_VISIBLE )) || exit 4
    _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render "" 1
    (( _ZLE_PICKER_INDEXES_VISIBLE )) || exit 5
    _ZLE_PICKER_DOCUMENT=0 COLUMNS=120
    _zle_picker_render "" 1
    (( _ZLE_PICKER_INSPECT_WIDTH <= 48 )) || exit 6
    print layout
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal layout "$output"
}
test_case 'Git document gives the reader primary width while preserving other inspectors and narrow focus' _test_git_document_layout

_test_git_document_continuity() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.git-review"
    (( ${+functions[_git_review_document_parse]} )) || { print -u2 "continuous numbered document missing"; exit 1; }
    _GIT_REVIEW_DATA=$'\''diff --git a/file b/file\n--- a/file\n+++ b/file\n@@ -1,2 +1,400 @@\n keep\n-old\n'\''
    repeat 399; do _GIT_REVIEW_DATA+=$'\''+new line\n'\''; done
    _GIT_REVIEW_TRUNCATED=0
    _git_review_document_parse
    (( ${#_ZLE_PICKER_DOCUMENT_LINES} > 400 )) || exit 2
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *400* && ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *keep* ]] || exit 3
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY == *+399* && $_GIT_REVIEW_DOCUMENT_SUMMARY == *-1* ]] || exit 4
    (( ${_ZLE_PICKER_DOCUMENT_ROLES[(Ie)success]} && ${_ZLE_PICKER_DOCUMENT_ROLES[(Ie)error]} )) || exit 5
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_INSPECT_TEXTS=(one ready)
    _zle_picker_inspect_prepare one 70
    (( ${#_ZLE_PICKER_INSPECT_LINES} > 400 )) || exit 6
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} != *"Preview truncated"* ]] || exit 7
    _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-old\n+new\e[2J\n'\''
    _GIT_REVIEW_TRUNCATED=1
    _git_review_document_parse
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY == *partial* && ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *Limits:* ]] || exit 8
    _ZLE_PICKER_DOCUMENT_KEY=two
    _zle_picker_inspect_prepare two 70
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} != *$'\''\e'\''* ]] || exit 9
    print continuous
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal continuous "$output"
}
test_case 'Git document retains continuous numbered code beyond preview limits and sanitizes terminal data' _test_git_document_continuity

_test_git_document_cache() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(one two three four five)
    local -a _GIT_REVIEW_KINDS=(unstaged unstaged unstaged staged commit)
    local -i captures=0
    _git_review_diff_capture() {
      (( ++captures ))
      _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-old\n+new\n'\''
      _GIT_REVIEW_TRUNCATED=0
    }
    _git_review_document_load /fixture 1 "" "" 3
    _git_review_document_load /fixture 2 "" "" 3
    _git_review_document_load /fixture 1 "" "" 3
    (( captures == 2 )) || exit 1
    _git_review_document_load /fixture 1 "" "" 1000000000 || { print -u2 "successful full-context load must return success"; exit 5; }
    (( captures == 3 )) || exit 2
    for index in 3 4 5; do _git_review_document_load /fixture $index "" "" 3; done
    (( ${#_git_document_cache} == 4 && ${#_git_document_order} == 4 )) || exit 3
    _git_review_document_load /fixture 2 "" "" 3
    (( captures == 7 )) || exit 4
    print cached
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal cached "$output"
}
test_case 'Git document caches only four snapshots and keys them by file and context' _test_git_document_cache

_test_git_document_context() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -q
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print -r -- first-context > file
    repeat 400; do print -r -- unchanged >> file; done
    print -r -- last-context >> file
    git add . && git commit -qm initial || exit 1
    print -r -- new-line >> file
    _git_review_prepare "$PWD" || exit 2
    _git_review_diff_capture "$PWD" unstaged file "" "" 3 || exit 3
    [[ $_GIT_REVIEW_DATA != *first-context* && $_GIT_REVIEW_DATA == *+new-line* ]] || exit 4
    _git_review_diff_capture "$PWD" unstaged file "" "" 1000000000 || exit 5
    [[ $_GIT_REVIEW_DATA == *first-context* && $_GIT_REVIEW_DATA == *last-context* ]] || exit 6
    print context
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal context "$output"
}
test_case 'Git document supports full-file context and compact changes using the same read-only provider' _test_git_document_context

_test_git_document_labels() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    _ZLE_PICKER_DOCUMENT=1
    _GIT_REVIEW_PATHS=(Sources/Model.swift Tests/Model.swift)
    _GIT_REVIEW_LABELS=(Sources/Model.swift Tests/Model.swift)
    _GIT_REVIEW_CONTEXTS=("Staged M" "Unstaged M")
    _GIT_REVIEW_DETAILS=(ready ready)
    _git_review_rows
    [[ $_NAVIGATION_PICKER_LABELS[1] == Model.swift ]] || { print -u2 "navigator should show recognizable filenames"; exit 1; }
    _navigation_picker_collect Tests 20
    [[ $_ZLE_PICKER_RESULTS[1] == 2 && ${#_ZLE_PICKER_RESULTS} == 1 ]] || exit 2
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_SELECTED=0 _ZLE_PICKER_WORKSPACE_ACTIONS=1
    _zle_picker_footer 160 ""
    [[ $REPLY != *"^X options"* ]] || exit 3
    print labels
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal labels "$output"
}
test_case 'Git document shows filenames while filtering exact paths and omits unavailable selected-file options' _test_git_document_labels

_test_git_document_selection_settle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    local -i shows=0 keys_read=0 _ZLE_PICKER_SESSION=1 _ZLE_PICKER_DOCUMENT=1
    local -i _ZLE_PICKER_DOCUMENT_SETTLE_TICKS=4
    local _ZLE_PICKER_DOCUMENT_KEY=one _ZLE_PICKER_COLLECTOR=_frame_collect
    local -A _ZLE_PICKER_INSPECT_TEXTS=(one ready two ready three ready four ready)
    local -a read_events=(timeout timeout down timeout timeout timeout down timeout timeout timeout timeout)
    _frame_collect() {
      _ZLE_PICKER_RESULTS=(one two three four)
      _ZLE_PICKER_LABELS=(one.swift two.swift three.swift four.swift)
    }
    _zle_picker_show() { (( ++shows )); }
    # Script quiet ticks and navigation bytes without a wall clock. Ctrl-N uses
    # the same selection step as Down after cursor-sequence decoding. Each key
    # must restart the complete four-tick quiet interval.
    read() {
      local event=${read_events[1]-timeout}
      read_events[1]=()
      if [[ $event == down ]]; then
        (( ++keys_read ))
        key=$'"'"'\x0e'"'"'
        return 0
      fi
      return 1
    }
    _zle_picker_loop "" 10 2 0
    [[ $? == 0 && $_ZLE_PICKER_ACTION == inspect && $_ZLE_PICKER_SELECTED_VALUE == four &&
       $keys_read == 2 && ${#read_events} == 0 && $shows == 3 ]] || {
      print -u2 -- "document selection settled before repeated input: selected=$_ZLE_PICKER_SELECTED_VALUE keys=$keys_read events=${#read_events} shows=$shows"
      exit 1
    }

    # Repeats at the bottom still represent active input although selection no
    # longer changes. They must also restart settlement; otherwise preview work
    # can begin while the user continues holding Down.
    shows=0 keys_read=0
    read_events=(timeout timeout down timeout timeout timeout down timeout timeout timeout timeout)
    _zle_picker_loop "" 10 4 0
    [[ $? == 0 && $_ZLE_PICKER_ACTION == inspect && $_ZLE_PICKER_SELECTED_VALUE == four &&
       $keys_read == 2 && ${#read_events} == 0 && $shows == 3 ]] || {
      print -u2 -- "boundary repeats did not restart settlement: selected=$_ZLE_PICKER_SELECTED_VALUE keys=$keys_read events=${#read_events} shows=$shows"
      exit 2
    }
    print settled
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal settled "$output"
}
test_case 'Git document selection paints lightly and resolves only after input settles' \
  _test_git_document_selection_settle
