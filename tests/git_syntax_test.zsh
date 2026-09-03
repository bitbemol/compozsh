# Syntax is optional metadata over an unchanged, read-only review snapshot.
_test_git_syntax_protocol() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-let old = 1\n+let new = 2\n'\''
    _git_review_document_parse
    local original=${(F)_ZLE_PICKER_DOCUMENT_LINES}
    _git_syntax_apply $'\''compozsh-syntax-1\n2 0 3 keyword\n3 10 11 number\ndone'\'' || exit 1
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[2] == "15:18:keyword " ]] || exit 2
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[3] == "25:26:number " ]] || exit 3
    local bad
    for bad in "2 -1 3 keyword" "2 0 99 string" "999 0 1 string" "2 0 3 exec" "1 0 1 keyword" "2 0 3 keyword;evil" "2 00 3 keyword"; do
      _git_syntax_apply $'\''compozsh-syntax-1\n'\''"$bad"$'\''\ndone'\'' && exit 4
      (( !${#_ZLE_PICKER_DOCUMENT_SYNTAX} )) || exit 5
    done
    _git_syntax_apply $'\''compozsh-syntax-1\n2 0 3 keyword'\'' && exit 6
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == "$original" ]] || exit 7
    print protocol
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal protocol "$output"
}
test_case 'Git syntax validates bounded token metadata without changing document text' _test_git_syntax_protocol

_test_git_syntax_native() {
  test_make_temp_dir || return
  local output
  test_write_file "$TEST_TMP_DIR/home/.vimrc" 'call writefile(["unsafe"], expand("~/vim-config-ran"))'
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    # Removed comments must not contaminate the new side. Gaps reset context.
    _GIT_REVIEW_DATA=$'\''@@ -1,3 +1,3 @@\n-/* comment\n-let old = 1\n-*/\n+let new = 42 // note\n+let text = "é界"\n+// vim: set exrc:\n@@ -90 +90 @@\n let last = 7\n'\''
    _git_review_document_parse
    # An unusable temporary prefix proves the provider does not spill source
    # through Zsh here-string temporary files, even if immediately unlinked.
    local TMPPREFIX="$HOME/no-such-directory/source"
    _git_syntax_capture sample.swift
    [[ $_GIT_SYNTAX_NOTE == "Swift syntax · viewport" ]] || { print -u2 -- "$_GIT_SYNTAX_NOTE"; exit 1; }
    _git_syntax_apply "$_GIT_SYNTAX_DATA" || exit 2
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[3] == *:comment* ]] || exit 3
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[5] == *:keyword* && $_ZLE_PICKER_DOCUMENT_SYNTAX[5] == *:number* ]] || exit 4
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[6] == *:string* && $_ZLE_PICKER_DOCUMENT_SYNTAX[9] == *:keyword* ]] || exit 5
    [[ ! -e $HOME/vim-config-ran ]] || exit 6
    _git_syntax_capture unknown.wonderlang
    [[ -z $_GIT_SYNTAX_DATA && $_GIT_SYNTAX_NOTE == "plain syntax · unsupported type" ]] || exit 7
    _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+'\''${(l:70000::x:)}
    _git_review_document_parse
    _git_syntax_capture large.swift
    [[ -z $_GIT_SYNTAX_DATA && $_GIT_SYNTAX_NOTE == "plain syntax · size limit" ]] || exit 8
    _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+let text = "é界"\n'\''
    _git_review_document_parse
    export LC_ALL=C
    _git_syntax_capture unicode.swift
    [[ -z $_GIT_SYNTAX_DATA && $_GIT_SYNTAX_NOTE == "plain syntax · UTF-8 locale required" ]] || exit 9
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'Git syntax uses system Vim on separate source fragments with safe fallbacks' _test_git_syntax_native

_test_git_syntax_render() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_DOCUMENT_LINES=($'\''               +\t"é界\e[2J"'\'')
    _ZLE_PICKER_DOCUMENT_ROLES=(success)
    _ZLE_PICKER_DOCUMENT_SYNTAX=(1 "17:25:string ")
    _ZLE_PICKER_INSPECT_TEXTS=(one ready)
    _ZLE_PICKER_RESULTS=(one) _ZLE_PICKER_LABELS=(sample.swift)
    _zle_picker_inspect_prepare one 22
    [[ $_ZLE_PICKER_INSPECT_SYNTAX[1] == "20:21:string " ]] || { print -u2 -- "${(F)_ZLE_PICKER_INSPECT_SYNTAX}"; exit 1; }
    [[ $_ZLE_PICKER_INSPECT_SYNTAX[2] == "0:8:string " ]] || exit 2
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} != *$'\''\e'\''* ]] || exit 3
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    local captured="" original=${(F)_ZLE_PICKER_DOCUMENT_LINES}
    region_highlight=("0 1 bold memo=fixture")
    zle() { captured=${(F)region_highlight}; }
    _zle_picker_render "" 1
    _zle_picker_show
    [[ $captured == *"fg=231,bg=22"* && $captured == *"bg=22,fg=151"* ]] || { print -u2 -- "$captured"; exit 4; }
    _ZLE_PICKER_DOCUMENT_ROLES=(error) _ZLE_PICKER_INSPECT_KEY=""
    _zle_picker_render "" 1
    _zle_picker_show
    [[ $captured == *"fg=231,bg=52"* && $captured == *"bg=52,fg=151"* ]] || { print -u2 -- "removed styles: $captured"; exit 5; }
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == "$original" && ${(F)region_highlight} == "0 1 bold memo=fixture" ]] || { print -u2 -- "document or highlight cleanup changed"; exit 6; }
    _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_INSPECT_KEY=""
    _zle_picker_render "" 1
    _zle_picker_show
    [[ $captured != *bg=52* && $captured != *bg=22* ]] || { print -u2 -- "stale syntax: $captured"; exit 7; }
    print rendered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal rendered "$output"
}
test_case 'Git syntax survives Unicode tabs control sanitization wrapping and diff backgrounds' _test_git_syntax_render

_test_git_syntax_visible_rows() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local -i index=0 _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_SCREEN_ACTIVE=1
    local _ZLE_PICKER_DOCUMENT_KEY=one
    local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    for (( index=1; index<=100; ++index )); do
      _ZLE_PICKER_DOCUMENT_LINES+=("               line $index")
      _ZLE_PICKER_DOCUMENT_ROLES+=(text)
    done
    local -A _ZLE_PICKER_INSPECT_TEXTS=(one ready)
    _ZLE_PICKER_RESULTS=(one) _ZLE_PICKER_LABELS=(sample.swift)
    COLUMNS=120 LINES=24
    _zle_picker_render "" 1
    local first=$_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST last=$_ZLE_PICKER_DOCUMENT_VISIBLE_LAST
    (( first == 1 && last > first && last < 100 )) || exit 1
    _ZLE_PICKER_INSPECT_OFFSET=10
    _zle_picker_render "" 1
    (( _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST > first &&
       _ZLE_PICKER_DOCUMENT_VISIBLE_LAST > last )) || exit 2
    print "$first:$last:${_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST}:${_ZLE_PICKER_DOCUMENT_VISIBLE_LAST}"
  ' "$TEST_REPO_ROOT") || return
  [[ $output == <->:<->:<->:<-> ]] || return 1
}
test_case 'Git syntax derives its source-row viewport from rendered wrapped rows' _test_git_syntax_visible_rows

_test_git_syntax_cache() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(one.swift two.swift three.swift four.swift five.swift)
    local -a _GIT_REVIEW_KINDS=(unstaged unstaged unstaged staged untracked)
    local -i calls=0
    _git_review_diff_capture() { _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-let old = 1\n+let new = 2\n'\''; _GIT_REVIEW_TRUNCATED=0; }
    _git_syntax_capture() { (( ++calls )); return 99; }
    local protocol=$'\''compozsh-syntax-1\n2 0 3 keyword\n3 0 3 keyword\ndone'\''
    _git_review_document_load /fixture 1 "" "" 3
    (( calls == 0 && ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 0 )) || exit 1
    [[ $_ZLE_PICKER_SUBTITLE == *"syntax loads in viewport"* ]] || exit 2
    _git_document_syntax_cache[1:3]=$protocol
    _git_document_syntax_notes[1:3]="Swift syntax · viewport"
    _git_document_syntax_first[1:3]=1 _git_document_syntax_last[1:3]=3
    _git_review_document_load /fixture 1 "" "" 3
    (( calls == 0 && ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 2 )) || exit 3
    _git_review_document_load /fixture 2 "" "" 3
    (( calls == 0 && ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 0 )) || exit 4
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_RESULTS=(1 2) _ZLE_PICKER_LABELS=(one.swift two.swift)
    _ZLE_PICKER_INSPECT_TEXTS=(1 ready 2 ready) COLUMNS=120 LINES=30
    _zle_picker_render "" 1
    _ZLE_PICKER_INSPECT_OFFSET=1 COLUMNS=100
    _zle_picker_render "" 1
    (( calls == 0 )) || exit 5
    local key
    for index in 2 3 4 5; do
      _git_review_document_load /fixture $index "" "" 3
      key="$index:3"
      [[ $index == 5 ]] && key="$index:new"
      _git_document_syntax_cache[$key]=$protocol
      _git_document_syntax_notes[$key]="Swift syntax · viewport"
      _git_document_syntax_first[$key]=1 _git_document_syntax_last[$key]=3
      _git_review_document_load /fixture $index "" "" 3
    done
    (( ${#_git_document_syntax_cache} == 4 && ${#_git_document_syntax_notes} == 4 )) || {
      print -u2 -- "cache counts: ${#_git_document_syntax_cache}/${#_git_document_syntax_notes}"
      exit 6
    }
    (( ${#_git_document_syntax_first} == 4 && ${#_git_document_syntax_last} == 4 )) || {
      print -u2 -- "range counts: ${#_git_document_syntax_first}/${#_git_document_syntax_last}"
      exit 7
    }
    [[ $_ZLE_PICKER_SUBTITLE == *"Swift syntax"* ]] || exit 8
    print cached
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal cached "$output"
}
test_case 'Git syntax shares snapshot eviction refresh and provider-free rendering' _test_git_syntax_cache

_test_git_syntax_viewport_schedule() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=101 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=110
    local -i _ZLE_PICKER_SELECTED=1
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=sample.swift
    local -a _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_DOCUMENT_LINES=() _GIT_REVIEW_KINDS=(unstaged)
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _git_document_syntax_failures=() _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local captured=""
    local -i row=0
    for (( row=1; row<=300; ++row )); do _ZLE_PICKER_DOCUMENT_LINES+=("line $row"); done
    local -i request_id=0 _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=1
    local _ZLE_PICKER_SUBTITLE="fixture"
    _git_syntax_prepare_input() {
      captured="$2:$3"
      _GIT_SYNTAX_INPUT=payload
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_apply() { return 0; }
    _git_syntax_session_poll() { return 2; }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }
    # A missing viewport is queued immediately at the pre-paint boundary,
    # without waiting for the resident worker.
    _git_review_syntax_idle
    [[ $captured == 71:140 ]] && (( _ZLE_PICKER_DOCUMENT_PENDING == 1 )) || {
      print -u2 -- "initial: $captured pending=$_ZLE_PICKER_DOCUMENT_PENDING"; exit 1
    }

    # Once the first atomic window is installed, ordinary line navigation is
    # served directly from it and never enters the loading presentation.
    captured=""
    _git_syntax_session_active_id=0 _ZLE_PICKER_DOCUMENT_PENDING=0
    _git_document_syntax_first[1:3]=71 _git_document_syntax_last[1:3]=140
    _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=101 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=110
    _git_review_syntax_idle
    [[ -z $captured ]] && (( !_ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "covered line navigation reloaded: $captured pending=$_ZLE_PICKER_DOCUMENT_PENDING"; exit 2
    }

    # Two pages before the lower edge, begin a multi-page replacement without
    # hiding the currently highlighted source.
    captured=""
    _git_syntax_session_active_id=0 _ZLE_PICKER_DOCUMENT_PENDING=0
    _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=111 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=120
    _git_review_syntax_idle
    [[ $captured == "81:150" ]] && (( _git_syntax_session_active_id == 2 && !_ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "read-ahead: $captured active=$_git_syntax_session_active_id pending=$_ZLE_PICKER_DOCUMENT_PENDING"; exit 3
    }

    # While that speculative request is active, the old colored window stays
    # visible; idle polling must not substitute the loading surface.
    _git_review_syntax_idle
    (( _git_syntax_session_active_id == 2 && !_ZLE_PICKER_DOCUMENT_PENDING )) || exit 4

    # A full Option/Fn page jump remains inside the read-ahead runway. Once its
    # replacement is installed, the same rule recenters again before the edge.
    captured=""
    _git_syntax_session_active_id=0
    _git_document_syntax_first[1:3]=81 _git_document_syntax_last[1:3]=150
    _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=141 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=150
    _git_review_syntax_idle
    [[ $captured == "111:180" ]] && (( !_ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "page read-ahead: $captured pending=$_ZLE_PICKER_DOCUMENT_PENDING"; exit 5
    }
    print scheduled
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scheduled "$output"
}
test_case 'Git syntax keeps a multi-page highlighted runway ahead of reader navigation' _test_git_syntax_viewport_schedule

_test_git_syntax_read_ahead_failure_keeps_frame() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=31 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=38
    local -i _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_DOCUMENT_PENDING=0
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=sample.swift
    local -a _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_DOCUMENT_LINES=({1..100})
    local -a _GIT_REVIEW_KINDS=(unstaged)
    local -A _git_document_syntax_first=([1:3]=1) _git_document_syntax_last=([1:3]=40)
    local -A _git_document_syntax_cache=([1:3]=old) _git_document_syntax_notes=([1:3]="Swift syntax · viewport")
    local -A _git_document_syntax_failures=() _ZLE_PICKER_DOCUMENT_SYNTAX=([31]="0:4:keyword")
    local -i request_id=0 poll_mode=0 _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local -i _git_review_snapshot_epoch=1 _git_syntax_active_epoch=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local _ZLE_PICKER_SUBTITLE=fixture
    _git_syntax_prepare_input() {
      _GIT_SYNTAX_INPUT=payload
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_apply() { print -u2 -- unexpected-apply; return 1; }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }
    _git_syntax_session_poll() {
      (( _git_syntax_session_active_id )) || return 2
      (( poll_mode )) || return 1
      REPLY=$_git_syntax_session_active_id
      _git_syntax_session_active_id=0
      _GIT_SYNTAX_DATA=""
      return 3
    }

    _git_review_syntax_idle
    (( request_id == 1 && !_ZLE_PICKER_DOCUMENT_PENDING )) || exit 1
    poll_mode=1
    _git_review_syntax_idle
    [[ ${_git_document_syntax_cache[1:3]} == old &&
       ${_git_document_syntax_first[1:3]} == 1 &&
       ${_git_document_syntax_last[1:3]} == 40 &&
       ${_ZLE_PICKER_DOCUMENT_SYNTAX[31]} == "0:4:keyword" ]] || exit 2
    (( !_ZLE_PICKER_DOCUMENT_PENDING )) || exit 3

    # The same speculative window does not spin after failure. Navigation that
    # actually leaves coverage will derive a new required request instead.
    _git_review_syntax_idle
    (( request_id == 1 && !_ZLE_PICKER_DOCUMENT_PENDING )) || exit 4
    print retained
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal retained "$output"
}
test_case 'Git syntax read-ahead failure preserves the installed highlighted frame' \
  _test_git_syntax_read_ahead_failure_keeps_frame

_test_git_syntax_short_document_viewport_schedule() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_SCREEN_ACTIVE=1
    local -i _GIT_REVIEW_DOCUMENT_HAS_CODE=1 _ZLE_PICKER_SELECTED=1
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=short.swift
    local -a _ZLE_PICKER_DOCUMENT_LINES=(
      "               struct Short {"
      "                 let value = 1"
      "               }"
    )
    local -a _ZLE_PICKER_DOCUMENT_ROLES=(text text text)
    local -a _ZLE_PICKER_RESULTS=({1..15}) _ZLE_PICKER_LABELS=()
    local -a _GIT_REVIEW_KINDS=(unstaged) _GIT_REVIEW_DOCUMENT_OLD=(1 2 3)
    local -a _GIT_REVIEW_DOCUMENT_NEW=(1 2 3)
    local -A _ZLE_PICKER_INSPECT_TEXTS=([1]=ready)
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _git_document_syntax_failures=() _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -i request_id=0 _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local -i _git_review_snapshot_epoch=1 _git_syntax_active_epoch=0
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=0
    local _git_syntax_active_key="" _git_syntax_active_note="" _git_syntax_status_note=""
    local _ZLE_PICKER_SUBTITLE=fixture captured=""
    local -i index=0
    for (( index=1; index<=15; ++index )); do _ZLE_PICKER_LABELS+=("file-$index.swift"); done
    _git_syntax_prepare_input() {
      captured="$2:$3"
      _GIT_SYNTAX_INPUT=payload
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_apply() { return 0; }
    _git_syntax_session_poll() { return 2; }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }

    # Fifteen list rows make the shared pane taller than this three-row source.
    # Geometry must clamp to the final prepared source row instead of indexing
    # unused pane space and publishing a zero last row.
    COLUMNS=120 LINES=30
    _zle_picker_render "" 1
    (( _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST == 1 &&
       _ZLE_PICKER_DOCUMENT_VISIBLE_LAST == 3 )) || {
      print -u2 -- "short document geometry: $_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST:$_ZLE_PICKER_DOCUMENT_VISIBLE_LAST"
      exit 1
    }
    _git_review_syntax_idle
    [[ $captured == 1:3 ]] && (( request_id == 1 && _ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "short document was not scheduled: range=$captured request=$request_id pending=$_ZLE_PICKER_DOCUMENT_PENDING"
      exit 2
    }
    print short-scheduled
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal short-scheduled "$output"
}
test_case 'Git syntax schedules a short document when the file list makes its pane taller' \
  _test_git_syntax_short_document_viewport_schedule

_test_git_syntax_latest_viewport_wins() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=8
    local -i _ZLE_PICKER_SELECTED=1
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=one.swift
    local -a _ZLE_PICKER_RESULTS=(1 2) _ZLE_PICKER_DOCUMENT_LINES=() _GIT_REVIEW_KINDS=(unstaged unstaged)
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -i row=0 request_id=0 poll_mode=0 applied=0
    for (( row=1; row<=20; ++row )); do _ZLE_PICKER_DOCUMENT_LINES+=("line $row"); done
    local -i _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_session_pid=99
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=1
    local _ZLE_PICKER_SUBTITLE="fixture"
    _git_syntax_prepare_input() {
      _GIT_SYNTAX_INPUT="payload:$1:$2:$3"
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }
    _git_syntax_session_poll() {
      if (( !_git_syntax_session_active_id )); then return 2; fi
      (( poll_mode )) || return 1
      REPLY=$_git_syntax_session_active_id
      _git_syntax_session_active_id=0
      _git_syntax_session_ready=1
      _GIT_SYNTAX_DATA=$'"'"'compozsh-syntax-1\n1 0 4 keyword\ndone\n'"'"'
      poll_mode=0
      return 0
    }
    _git_syntax_apply() {
      (( ++applied ))
      _ZLE_PICKER_DOCUMENT_SYNTAX[1]="0:4:keyword"
      return 0
    }

    _git_review_syntax_idle
    (( _git_syntax_session_active_id == 1 && _ZLE_PICKER_DOCUMENT_PENDING )) || exit 1

    # Selection two supersedes the in-flight request for selection one. The
    # old response must never enter either the cache or the visible reader.
    _ZLE_PICKER_SELECTED=2 _ZLE_PICKER_DOCUMENT_KEY=2 _ZLE_PICKER_DOCUMENT_TITLE=two.swift
    _ZLE_PICKER_SUBTITLE="fixture" _ZLE_PICKER_DOCUMENT_PENDING=0
    _git_review_syntax_idle
    (( _git_syntax_session_active_id == 1 && applied == 0 && _ZLE_PICKER_DOCUMENT_PENDING )) || exit 2
    poll_mode=1
    _git_review_syntax_idle
    (( _git_syntax_session_active_id == 2 && request_id == 2 && applied == 0 )) || exit 3
    [[ -z ${_git_document_syntax_cache[1:3]+present} &&
       -z ${_git_document_syntax_cache[2:3]+present} ]] || exit 4

    poll_mode=1
    _git_review_syntax_idle
    (( applied == 1 && !_ZLE_PICKER_DOCUMENT_PENDING )) || exit 5
    [[ -n ${_git_document_syntax_cache[2:3]} &&
       -z ${_git_document_syntax_cache[1:3]+present} ]] || exit 6
    [[ $_ZLE_PICKER_SUBTITLE == *"Swift syntax · viewport"* ]] || exit 7
    print latest
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal latest "$output"
}
test_case 'Git syntax discards stale generations and publishes only the latest viewport' _test_git_syntax_latest_viewport_wins

_test_git_syntax_transient_failure_retries() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=8
    local -i _ZLE_PICKER_SELECTED=1
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=one.swift
    local -a _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_DOCUMENT_LINES=({1..12}) _GIT_REVIEW_KINDS=(unstaged)
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _git_document_syntax_failures=()
    local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -i request_id=0 poll_mode=0 applied=0
    local -i _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_session_pid=99
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local -i _git_review_snapshot_epoch=1 _git_syntax_active_epoch=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=1
    local _ZLE_PICKER_SUBTITLE="fixture"
    _git_syntax_prepare_input() {
      _GIT_SYNTAX_INPUT=payload
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }
    _git_syntax_session_poll() {
      (( _git_syntax_session_active_id )) || return 2
      case $poll_mode in
        (0) return 1 ;;
        (1)
          REPLY=$_git_syntax_session_active_id
          _git_syntax_session_active_id=0
          _git_syntax_session_ready=1
          poll_mode=0
          _GIT_SYNTAX_DATA=""
          return 3 ;;
        (2)
          REPLY=$_git_syntax_session_active_id
          _git_syntax_session_active_id=0
          _git_syntax_session_ready=1
          poll_mode=0
          _GIT_SYNTAX_DATA=$'"'"'compozsh-syntax-1\n1 0 4 keyword\ndone\n'"'"'
          return 0 ;;
      esac
    }
    _git_syntax_apply() {
      (( ++applied ))
      _ZLE_PICKER_DOCUMENT_SYNTAX[1]="0:4:keyword"
      return 0
    }

    _git_review_syntax_idle
    (( request_id == 1 && _git_syntax_session_active_id == 1 )) || {
      print -u2 -- "initial transient request: requests=$request_id active=$_git_syntax_session_active_id"
      exit 1
    }
    poll_mode=1
    _git_review_syntax_idle
    [[ -z ${_git_document_syntax_cache[1:3]+present} &&
       -z ${_git_document_syntax_first[1:3]+present} &&
       -z ${_git_document_syntax_last[1:3]+present} ]] || {
      print -u2 -- "transient syntax failure was cached as covered"
      exit 2
    }
    (( !${+_git_syntax_session_disabled} )) || {
      print -u2 -- "transient failure introduced a global provider-disable state"
      exit 3
    }
    (( _ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "retryable syntax failure exposed the plain document before retry"
      exit 7
    }

    # A later quiet idle boundary may retry the same current viewport. The
    # first request failure must not make the plain fallback permanent.
    (( request_id >= 2 )) || _git_review_syntax_idle
    (( request_id == 2 && _git_syntax_session_active_id == 2 )) || {
      print -u2 -- "retry was not scheduled: requests=$request_id active=$_git_syntax_session_active_id"
      exit 4
    }
    poll_mode=2
    _git_review_syntax_idle
    (( applied == 1 && !_ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "retry did not publish: applied=$applied pending=$_ZLE_PICKER_DOCUMENT_PENDING"
      exit 5
    }
    [[ -n ${_git_document_syntax_cache[1:3]} &&
       $_ZLE_PICKER_SUBTITLE == *"Swift syntax · viewport"* ]] || exit 6
    print recovered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal recovered "$output"
}
test_case 'Git syntax retries a transient request failure without caching or global disable' _test_git_syntax_transient_failure_retries

_test_git_syntax_transient_failure_is_viewport_scoped() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=8
    local -i _ZLE_PICKER_SELECTED=1
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=one.swift
    local -a _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_DOCUMENT_LINES=({1..100}) _GIT_REVIEW_KINDS=(unstaged)
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _git_document_syntax_failures=()
    local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -i request_id=0 poll_mode=0 applied=0
    local -i _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_session_pid=99
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local -i _git_review_snapshot_epoch=1 _git_syntax_active_epoch=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=1
    local _ZLE_PICKER_SUBTITLE="fixture"
    _git_syntax_prepare_input() {
      _GIT_SYNTAX_INPUT=payload
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }
    _git_syntax_session_poll() {
      (( _git_syntax_session_active_id )) || return 2
      (( poll_mode )) || return 1
      REPLY=$_git_syntax_session_active_id
      _git_syntax_session_active_id=0
      _git_syntax_session_ready=1
      if (( poll_mode == 1 )); then
        poll_mode=0 _GIT_SYNTAX_DATA=""
        return 3
      fi
      poll_mode=0
      _GIT_SYNTAX_DATA=$'"'"'compozsh-syntax-1\n1 0 4 keyword\ndone\n'"'"'
      return 0
    }
    _git_syntax_apply() {
      (( ++applied ))
      _ZLE_PICKER_DOCUMENT_SYNTAX[1]="0:4:keyword"
      return 0
    }

    # Viewport A fails once and remains retryable behind the pending surface.
    _git_review_syntax_idle
    (( request_id == 1 && _git_syntax_active_first == 1 && _git_syntax_active_last == 32 )) || exit 1
    poll_mode=1
    _git_review_syntax_idle
    (( _ZLE_PICKER_DOCUMENT_PENDING )) || exit 2

    # Moving before A retries gives viewport B its own first attempt. Its first
    # failure must not consume the retry budget for A or become covered plain.
    _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=43
    _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=50
    _git_review_syntax_idle
    (( request_id == 2 && _git_syntax_active_first == 19 && _git_syntax_active_last == 74 )) || exit 3
    poll_mode=1
    _git_review_syntax_idle
    [[ -z ${_git_document_syntax_cache[1:3]+present} &&
       -z ${_git_document_syntax_first[1:3]+present} &&
       -z ${_git_document_syntax_last[1:3]+present} ]] || {
      print -u2 -- "first failure in a new viewport was cached as terminal coverage"
      exit 4
    }
    (( _ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "new viewport exposed plain source instead of retaining pending geometry"
      exit 5
    }

    _git_review_syntax_idle
    (( request_id == 3 && _git_syntax_session_active_id == 3 )) || exit 6
    poll_mode=2
    _git_review_syntax_idle
    (( applied == 1 && !_ZLE_PICKER_DOCUMENT_PENDING )) || exit 7
    [[ -n ${_git_document_syntax_cache[1:3]} ]] || exit 8
    print viewport-recovered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal viewport-recovered "$output"
}
test_case 'Git syntax scopes transient retry budgets to one captured viewport' \
  _test_git_syntax_transient_failure_is_viewport_scoped

_test_git_syntax_success_replaces_plain_status() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=8
    local -i _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_DOCUMENT_PENDING=1
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=one.swift
    local -a _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_DOCUMENT_LINES=({1..12}) _GIT_REVIEW_KINDS=(unstaged)
    local -A _git_document_syntax_first=([1:3]=1) _git_document_syntax_last=([1:3]=10)
    local -A _git_document_syntax_cache=([1:3]="")
    local -A _git_document_syntax_notes=([1:3]="plain syntax · unavailable after retry")
    local -A _git_document_syntax_failures=() _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -i _git_syntax_session_active_id=1 _git_syntax_active_first=1 _git_syntax_active_last=10
    local -i _git_review_snapshot_epoch=1 _git_syntax_active_epoch=1
    local _git_syntax_active_key=1:3 _git_syntax_active_note="Swift syntax · viewport"
    local _git_syntax_status_note="plain syntax · unavailable after retry"
    local _ZLE_PICKER_SUBTITLE="fixture · plain syntax · unavailable after retry"
    local -i _ZLE_PICKER_INSPECT_WIDTH=1 applied=0
    _git_syntax_prepare_input() { _GIT_SYNTAX_INPUT=payload; }
    _git_syntax_session_request() { return 2; }
    _git_syntax_session_poll() {
      REPLY=1
      _git_syntax_session_active_id=0
      _GIT_SYNTAX_DATA=$'"'"'compozsh-syntax-1\n1 0 4 keyword\ndone\n'"'"'
      return 0
    }
    _git_syntax_apply() {
      (( ++applied ))
      _ZLE_PICKER_DOCUMENT_SYNTAX[1]="0:4:keyword"
      return 0
    }

    _git_review_syntax_idle
    (( applied == 1 && !_ZLE_PICKER_DOCUMENT_PENDING )) || exit 1
    [[ $_ZLE_PICKER_SUBTITLE == *"Swift syntax · viewport"* &&
       $_ZLE_PICKER_SUBTITLE != *"plain syntax"* &&
       $_git_syntax_status_note == "Swift syntax · viewport" ]] || {
      print -u2 -- "successful syntax left a stale fallback status: $_ZLE_PICKER_SUBTITLE"
      exit 2
    }
    print status-replaced
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal status-replaced "$output"
}
test_case 'Git syntax success replaces a stale plain-fallback status note' \
  _test_git_syntax_success_replaces_plain_status

_test_git_syntax_snapshot_epoch() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=8
    local -i _ZLE_PICKER_SELECTED=1
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=one.swift
    local -a _ZLE_PICKER_RESULTS=(1) _ZLE_PICKER_DOCUMENT_LINES=({1..12}) _GIT_REVIEW_KINDS=(unstaged)
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -i request_id=0 poll_mode=0 applied=0
    local -i _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_session_pid=99
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local -i _git_review_snapshot_epoch=1 _git_syntax_active_epoch=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=1
    local _ZLE_PICKER_SUBTITLE="fixture"
    _git_syntax_prepare_input() {
      _GIT_SYNTAX_INPUT="payload:epoch=$_git_review_snapshot_epoch"
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }
    _git_syntax_session_poll() {
      (( _git_syntax_session_active_id )) || return 2
      (( poll_mode )) || return 1
      REPLY=$_git_syntax_session_active_id
      _git_syntax_session_active_id=0
      _git_syntax_session_ready=1
      poll_mode=0
      _GIT_SYNTAX_DATA=$'"'"'compozsh-syntax-1\n1 0 4 keyword\ndone\n'"'"'
      return 0
    }
    _git_syntax_apply() {
      (( ++applied ))
      _ZLE_PICKER_DOCUMENT_SYNTAX[1]="0:4:keyword"
      return 0
    }

    _git_review_syntax_idle
    (( request_id == 1 && _git_syntax_active_epoch == 1 )) || {
      print -u2 -- "initial epoch request: requests=$request_id active-epoch=$_git_syntax_active_epoch"
      exit 1
    }

    # A refresh may reuse numeric file index and focused/full context. Epoch is
    # therefore part of syntax identity even when the visible cache key text is
    # otherwise unchanged.
    _git_review_snapshot_epoch=2
    _ZLE_PICKER_DOCUMENT_LINES=({101..112})
    _ZLE_PICKER_SUBTITLE="fixture" _ZLE_PICKER_DOCUMENT_PENDING=0
    poll_mode=1
    _git_review_syntax_idle
    (( applied == 0 )) || {
      print -u2 -- "pre-refresh syntax was published into the new snapshot"
      exit 2
    }
    (( request_id == 2 && _git_syntax_session_active_id == 2 && _git_syntax_active_epoch == 2 )) || {
      print -u2 -- "new snapshot was not scheduled: requests=$request_id active=$_git_syntax_session_active_id epoch=$_git_syntax_active_epoch"
      exit 3
    }
    (( ${#_git_document_syntax_cache} == 0 )) || exit 4

    poll_mode=1
    _git_review_syntax_idle
    (( applied == 1 && !_ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "current epoch did not publish: applied=$applied pending=$_ZLE_PICKER_DOCUMENT_PENDING"
      exit 5
    }
    (( ${#_git_document_syntax_cache} == 1 )) || exit 6
    print epoch
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal epoch "$output"
}
test_case 'Git syntax rejects a pre-refresh completion when numeric document identity is reused' _test_git_syntax_snapshot_epoch

_test_git_syntax_selected_document_alignment() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=8
    local -i _ZLE_PICKER_SELECTED=2
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=one.swift
    local -a _ZLE_PICKER_RESULTS=(1 2) _ZLE_PICKER_DOCUMENT_LINES=("line 1")
    local -a _GIT_REVIEW_KINDS=(unstaged unstaged)
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -i request_id=0 poll_mode=0 applied=0
    local -i _git_syntax_session_active_id=0 _git_syntax_session_ready=1
    local -i _git_syntax_session_pid=99
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local -i _git_review_snapshot_epoch=1 _git_syntax_active_epoch=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=1
    local _ZLE_PICKER_SUBTITLE="fixture"
    _git_syntax_prepare_input() {
      _GIT_SYNTAX_INPUT=payload
      _GIT_SYNTAX_SUCCESS_NOTE="Swift syntax · viewport"
    }
    _git_syntax_session_request() {
      REPLY=$(( ++request_id ))
      _git_syntax_session_active_id=$REPLY
      return 0
    }
    _git_syntax_session_poll() {
      (( _git_syntax_session_active_id )) || return 2
      (( poll_mode )) || return 1
      REPLY=$_git_syntax_session_active_id
      _git_syntax_session_active_id=0
      _git_syntax_session_ready=1
      poll_mode=0
      _GIT_SYNTAX_DATA=$'"'"'compozsh-syntax-1\n1 0 4 keyword\ndone\n'"'"'
      return 0
    }
    _git_syntax_apply() { (( ++applied )); return 0; }

    # The list has advanced to result two while document one remains installed.
    # Idle provider work must follow the selected target, not the stale reader.
    _git_review_syntax_idle
    (( request_id == 0 && applied == 0 && !_ZLE_PICKER_DOCUMENT_PENDING )) || {
      print -u2 -- "syntax was scheduled for a document that no longer matches selection"
      exit 1
    }

    # Also reject a completion if selection changes after a valid request was
    # submitted but before its response arrives.
    _ZLE_PICKER_SELECTED=1
    _git_review_syntax_idle
    (( request_id == 1 && _git_syntax_session_active_id == 1 )) || exit 2
    _ZLE_PICKER_SELECTED=2
    poll_mode=1
    _git_review_syntax_idle
    (( applied == 0 && ${#_git_document_syntax_cache} == 0 )) || {
      print -u2 -- "syntax was published after selection left its document"
      exit 3
    }
    print aligned
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal aligned "$output"
}
test_case 'Git syntax neither schedules nor publishes for a reader behind the selected result' _test_git_syntax_selected_document_alignment

_test_git_syntax_pending_geometry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local -i row=0 _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_PENDING=1
    local _ZLE_PICKER_DOCUMENT_KEY=one
    local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    for (( row=1; row<=80; ++row )); do
      _ZLE_PICKER_DOCUMENT_LINES+=("               SECRET_SOURCE_$row")
      _ZLE_PICKER_DOCUMENT_ROLES+=(text)
    done
    local -A _ZLE_PICKER_INSPECT_TEXTS=(one ready)
    _ZLE_PICKER_RESULTS=(one) _ZLE_PICKER_LABELS=(sample.swift)
    COLUMNS=120 LINES=24
    _zle_picker_render "" 1
    local pending=${(F)_ZLE_PICKER_INSPECT_LINES}
    [[ $pending != *SECRET_SOURCE* && $pending == *"Preparing highlighted preview…"* ]] || {
      print -u2 -- "pending paint exposed source or omitted notice"
      exit 1
    }
    (( _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST == 1 &&
       _ZLE_PICKER_DOCUMENT_VISIBLE_LAST > _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST )) || {
      print -u2 -- "initial geometry: $_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST:$_ZLE_PICKER_DOCUMENT_VISIBLE_LAST"
      exit 2
    }

    # Polling/repainting while pending must retain a real multi-row source
    # viewport; otherwise the asynchronous request can never complete.
    _ZLE_PICKER_INSPECT_OFFSET=12 _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_render "" 1
    (( _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST > 1 &&
       _ZLE_PICKER_DOCUMENT_VISIBLE_LAST > _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST )) || {
      print -u2 -- "scrolled geometry: $_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST:$_ZLE_PICKER_DOCUMENT_VISIBLE_LAST"
      exit 3
    }
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} != *SECRET_SOURCE* ]] || {
      print -u2 -- "scrolled pending paint exposed source"
      exit 4
    }

    _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} == *SECRET_SOURCE* ]] || {
      print -u2 -- "completed paint omitted source"
      exit 5
    }
    print geometry
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal geometry "$output"
}
test_case 'Git syntax pending paint hides plain source without losing viewport geometry' _test_git_syntax_pending_geometry

_test_git_syntax_resident_session() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 TMPDIR="$HOME/tmp"
    command mkdir -p "$TMPDIR"
    source "$1/.zsh.addons/.zsh.git-syntax"
    local _git_syntax_session_dir="" _git_syntax_session_request_fifo=""
    local _git_syntax_session_response_fifo="" _git_syntax_session_buffer=""
    local -i _git_syntax_session_fd=-1 _git_syntax_session_pid=0
    local -i _git_syntax_session_ready=0 _git_syntax_session_generation=0
    local -i _git_syntax_session_active_id=0 attempts=0 idle_status=0
    local -F _git_syntax_session_deadline=0
    _git_syntax_session_start || exit 1
    local pid=$_git_syntax_session_pid directory=$_git_syntax_session_dir
    _git_syntax_session_capture $'\''swift\n1\t1\t1\tstruct Thing {\n'\'' || exit 2
    [[ $_GIT_SYNTAX_DATA == *keyword* ]] || exit 3
    (( _git_syntax_session_pid == pid )) || exit 4

    # The response and following ready marker may arrive in separate FIFO
    # reads. Once ready is observed, quiescent UI polls must describe an idle
    # resident, not interpret its cleared deadline as expiry and kill it.
    while (( !_git_syntax_session_ready && ++attempts < 100 )); do
      zselect -r $_git_syntax_session_fd -t 1 2>/dev/null
      _git_syntax_session_poll >/dev/null 2>&1
    done
    (( _git_syntax_session_ready && _git_syntax_session_pid == pid )) || exit 10
    repeat 3; do
      _git_syntax_session_poll >/dev/null 2>&1
      idle_status=$?
      (( idle_status == 2 && _git_syntax_session_ready &&
         _git_syntax_session_pid == pid )) || exit 11
    done
    _git_syntax_session_capture $'\''python\n1\t1\t1\tvalue = "hello"\n'\'' || exit 5
    [[ $_GIT_SYNTAX_DATA == *string* ]] || exit 6
    (( _git_syntax_session_pid == pid && _git_syntax_session_generation == 2 )) || exit 7
    _git_syntax_session_stop
    kill -0 $pid 2>/dev/null && exit 8
    [[ ! -e $directory ]] || exit 9
    print resident
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal resident "$output"
}
test_case 'Git syntax reuses one framed Vim process and removes every session resource' _test_git_syntax_resident_session

_test_git_syntax_dead_reader_request_is_nonblocking() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 TMPDIR="$HOME/tmp"
    command mkdir -p "$TMPDIR"
    source "$1/.zsh.addons/.zsh.git-syntax"
    zmodload zsh/zpty
    zmodload zsh/zselect

    _dead_reader_driver() {
      emulate -L zsh
      unsetopt MONITOR NOTIFY
      local _git_syntax_session_dir="" _git_syntax_session_request_fifo=""
      local _git_syntax_session_response_fifo="" _git_syntax_session_buffer=""
      local -i _git_syntax_session_fd=-1 _git_syntax_session_pid=0
      local -i _git_syntax_session_ready=0 _git_syntax_session_generation=0
      local -i _git_syntax_session_active_id=0 attempts=0 result=0
      local -F _git_syntax_session_deadline=0
      _git_syntax_session_start || { print START-FAILED; return 1; }
      while (( !_git_syntax_session_ready && ++attempts < 100 )); do
        _git_syntax_session_poll >/dev/null 2>&1
        (( _git_syntax_session_ready )) || zselect -r $_git_syntax_session_fd -t 1 2>/dev/null
      done
      (( _git_syntax_session_ready )) || { print READY-FAILED; return 2; }

      # Reproduce the exact transport race: readiness was observed, but the
      # worker disappears before request opens its FIFO writer. Prevent the
      # request helper from transparently starting a replacement child so this
      # call exercises the dead-reader open itself.
      kill -KILL $_git_syntax_session_pid 2>/dev/null
      wait $_git_syntax_session_pid 2>/dev/null
      _git_syntax_session_start() { return 0; }
      _git_syntax_session_request $'"'"'swift\n1\t1\t1\tlet value = 1\n'"'"'
      result=$?
      print -r -- "RESULT:$result"
      _git_syntax_session_stop
      (( result != 0 ))
    }

    local trace="" chunk="" pfd=0
    zpty -b dead-reader _dead_reader_driver || exit 1
    pfd=$REPLY
    {
      # A blocking FIFO open never produces RESULT. Bound the probe externally
      # so a regression fails instead of hanging the entire native suite.
      while zselect -r $pfd -t 100; do
        while zpty -r dead-reader chunk; do trace+=$chunk; done
        [[ $trace == *RESULT:* ]] && break
      done
      while zpty -r dead-reader chunk; do trace+=$chunk; done
      [[ $trace == *RESULT:<1-9>* ]] || {
        print -u2 -- "dead-reader request blocked or succeeded unexpectedly: ${(qqq)trace}"
        exit 2
      }
    } always {
      zpty -d dead-reader 2>/dev/null
    }
    print dead-reader-safe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal dead-reader-safe "$output"
}
test_case 'Git syntax request returns promptly when a ready worker dies before FIFO open' \
  _test_git_syntax_dead_reader_request_is_nonblocking

_test_git_syntax_atomic_window() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 TMPDIR="$HOME/tmp"
    command mkdir -p "$TMPDIR"
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-let old = 1\n+let new = 2\n'\''
    _git_review_document_parse
    local -i context=3 _ZLE_PICKER_DOCUMENT=1 _GIT_REVIEW_DOCUMENT_HAS_CODE=1
    local -i _ZLE_PICKER_SELECTED=1
    local _git_syntax_session_dir="" _git_syntax_session_request_fifo=""
    local _git_syntax_session_response_fifo="" _git_syntax_session_buffer=""
    local -i _git_syntax_session_fd=-1 _git_syntax_session_pid=0
    local -i _git_syntax_session_ready=0 _git_syntax_session_generation=0
    local -i _git_syntax_session_active_id=0
    local -i _git_syntax_active_first=0 _git_syntax_active_last=0
    local -F _git_syntax_session_deadline=0
    local _git_syntax_active_key="" _git_syntax_active_note=""
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_TITLE=sample.swift
    local _ZLE_PICKER_SUBTITLE="fixture · syntax loads in viewport"
    local -i _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST=1 _ZLE_PICKER_DOCUMENT_VISIBLE_LAST=3
    local -i _ZLE_PICKER_DOCUMENT_PENDING=0 _ZLE_PICKER_INSPECT_WIDTH=1
    local -a _ZLE_PICKER_RESULTS=(1) _GIT_REVIEW_KINDS=(unstaged)
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -A _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
    _git_syntax_session_start || exit 1
    local pid=$_git_syntax_session_pid directory=$_git_syntax_session_dir
    _git_review_syntax_idle
    (( $? == 0 && _git_syntax_session_pid == pid && _ZLE_PICKER_DOCUMENT_PENDING == 1 )) || exit 2
    (( ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 0 )) || exit 3
    local -i attempts=0
    while (( _ZLE_PICKER_DOCUMENT_PENDING && ++attempts < 100 )); do
      zselect -r $_git_syntax_session_fd -t 1 2>/dev/null
      _git_review_syntax_idle >/dev/null
    done
    [[ -n ${_git_document_syntax_cache[1:3]} && ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 2 ]] || {
      print -u2 -- "publish: cache=${#_git_document_syntax_cache[1:3]} spans=${#_ZLE_PICKER_DOCUMENT_SYNTAX} note=${_git_document_syntax_notes[1:3]-}"
      exit 4
    }
    [[ $_ZLE_PICKER_SUBTITLE == *"Swift syntax · viewport"* && $_ZLE_PICKER_SUBTITLE != *"loads in viewport"* ]] || {
      print -u2 -- "subtitle: $_ZLE_PICKER_SUBTITLE"
      exit 5
    }
    _git_review_syntax_cleanup
    kill -0 $pid 2>/dev/null && exit 6
    [[ ! -e $directory ]] || exit 7
    print atomic
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal atomic "$output"
}
test_case 'Git syntax publishes a resident viewport asynchronously and cleans it' _test_git_syntax_atomic_window

_test_git_syntax_job_scope() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    _git_review_load() {
      _GIT_REVIEW_SUMMARY=ready _GIT_REVIEW_NOTICE=""
      _GIT_REVIEW_LABELS=()
      return 0
    }
    _git_review_rows() { return 0; }
    _git_review_syntax_cleanup() { return 0; }
    _zle_picker_loop() {
      [[ $options[monitor] == off && $options[notify] == off ]] ||
        print -r -u $efd BAD-OPTIONS
      (sleep 0.02) &
      local child=$!
      sleep 0.05
      wait $child || print -r -u $efd BAD-WAIT
      return 1
    }
    _job_scope_driver() {
      setopt MONITOR NOTIFY
      _git_review_view /fixture working
      [[ $options[monitor] == on && $options[notify] == on ]] ||
        print -r -u $efd BAD-RESTORE
      print -r -u $efd DONE
    }
    local trace="" chunk="" event="" pfd=0
    zpty -b job-scope _job_scope_driver
    pfd=$REPLY
    {
      while zselect -r $efd $pfd -t 300; do
        while zpty -r job-scope chunk; do trace+=$chunk; done
        if IFS= read -r -u $efd event; then
          [[ $event == DONE ]] && break
          [[ $event == BAD-* ]] && { print -u2 -- "$event"; exit 1; }
        fi
      done
      while zpty -r job-scope chunk; do trace+=$chunk; done
      [[ $event == DONE ]] || { print -u2 -- "missing completion: $event"; exit 2; }
      [[ $trace != *" + done"* && $trace != *"] "<->* ]] || {
        print -u2 -- "job control leaked into screen output: ${(qqq)trace}"
        exit 3
      }
      print job-scope
    } always {
      zpty -d job-scope 2>/dev/null
      exec {efd}<&-
    }
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal job-scope "$output"
}
test_case 'Git syntax workers cannot write shell job records into the screen session' _test_git_syntax_job_scope

_test_git_syntax_failure() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/slow.vim" '
    call writefile([string(getpid())], expand("<sfile>:p:h") . "/child-pid")
    while 1
    endwhile
  '
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+let value = 1\n'\''
    _git_review_document_parse
    local _GIT_SYNTAX_SCRIPT="$HOME/slow.vim"
    _git_syntax_capture sample.swift
    [[ $_GIT_SYNTAX_NOTE == "plain syntax · unavailable or time limit" && -z $_GIT_SYNTAX_DATA ]] || exit 1
    [[ -s $HOME/child-pid ]] || exit 2
    local child=$(<"$HOME/child-pid")
    kill -0 $child 2>/dev/null && { print -u2 "syntax process survived timeout"; exit 3; }
    print failure
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal failure "$output"
}
test_case 'Git syntax kills and reaps a timed-out resident provider' _test_git_syntax_failure

_test_git_syntax_languages() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    local name
    for name in sample.zsh sample.sh sample.json sample.py; do
      case $name in
        (*.zsh|*.sh) _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+echo "hello" # comment\n'\'' ;;
        (*.json) _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+{"name": "hello", "value": 42}\n'\'' ;;
        (*.py) _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+value = "hello" # comment\n'\'' ;;
      esac
      _git_review_document_parse
      _git_syntax_capture "$name"
      _git_syntax_apply "$_GIT_SYNTAX_DATA" || { print -u2 -- "$name: $_GIT_SYNTAX_NOTE"; exit 1; }
      [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[2] == *:string* ]] || { print -u2 -- "$name: $_ZLE_PICKER_DOCUMENT_SYNTAX[2]"; exit 2; }
    done
    # An absent provider leaves the review usable in any peer load order.
    unfunction _git_syntax_capture _git_syntax_apply
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(file.swift) _GIT_REVIEW_KINDS=(unstaged)
    _git_review_diff_capture() { _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-old\n+new\n'\''; _GIT_REVIEW_TRUNCATED=0; }
    _git_review_document_load /fixture 1 "" "" 3 || exit 3
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *+new* && ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 0 ]] || exit 4
    print languages
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal languages "$output"
}
test_case 'Git syntax covers the initial language allowlist and remains optional' _test_git_syntax_languages

_test_git_syntax_zle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _GIT_REVIEW_DATA=$'\''@@ -1 +1,32 @@\n-let value = 1 // old\n'\''
    repeat 32; do _GIT_REVIEW_DATA+=$'\''+let value = 42 // new\n'\''; done
    _git_review_document_parse
    _git_syntax_capture example.swift
    _git_syntax_apply "$_GIT_SYNTAX_DATA" || exit 1
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=1
    _ZLE_PICKER_TITLE="Working changes" _ZLE_PICKER_SUBTITLE="Synthetic syntax fixture"
    _ZLE_PICKER_DOCUMENT_TITLE=example.swift _ZLE_PICKER_INSPECT_TEXTS=(1 ready)
    _ZLE_PICKER_INSPECT_ACTION=read _ZLE_PICKER_COLLECTOR=_syntax_collect
    _ZLE_PICKER_IDLE_CALLBACK=_syntax_idle
    _syntax_collect() { _ZLE_PICKER_RESULTS=(1); _ZLE_PICKER_LABELS=(example.swift); }
    _syntax_idle() {
      if [[ ! -e $HOME/syntax-primed ]]; then
        print -r -- primed >| $HOME/syntax-primed
      fi
      return 2
    }
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions -c _zle_picker_show _syntax_original_show
    _zle_picker_show() {
      [[ -e $HOME/syntax-primed ]] || print -r -u $efd BAD-PREPAINT
      _syntax_original_show
      if (( _ZLE_PICKER_INSPECT_FOCUS )); then
        [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected-inactive]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} &&
           ${(F)_ZLE_PICKER_DISPLAY} == *" ┃ "* ]] || print -r -u $efd BAD-READER-FOCUS
      else
        [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} &&
           ${(F)_ZLE_PICKER_DISPLAY} == *" │ "* ]] || print -r -u $efd BAD-LIST-FOCUS
      fi
      print -r -u $efd -- "FRAME:$_ZLE_PICKER_INSPECT_FOCUS"
    }
    _syntax_driver() {
      command stty rows 30 cols 120
      _zle_picker_run 10
      [[ $? == 1 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 ]] || print -u $efd BAD-CLEANUP
      print -u $efd DONE
    }
    local trace="" chunk="" event="" pfd=0
    _syntax_expect() {
      local wanted=$1
      while zselect -r $efd $pfd -t 300; do
        while zpty -r syntax chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -- "expected $wanted, got $event"
      return 1
    }
    zpty -b syntax _syntax_driver
    pfd=$REPLY
    {
      _syntax_expect FRAME:0 || exit 2
      zpty -w -n syntax $'\''\t'\''
      _syntax_expect FRAME:1 || exit 3
      zpty -w -n syntax $'\''\e[B'\''
      _syntax_expect FRAME:1 || exit 4
      [[ $trace == *"48;5;22"* && $trace == *"48;5;52"* && $trace == *"38;5;189"* ]] || { print -u2 "native terminal colors missing"; exit 5; }
      [[ $trace == *"$enter"* && ${trace#*"$enter"} != *"$enter"* && $trace != *"$leave"* ]] || exit 6
      zpty -w -n syntax $'\''\e'\''
      _syntax_expect DONE || exit 7
      while zpty -r syntax chunk; do trace+=$chunk; done
      [[ $trace == *"$leave"* ]] || exit 8
      print native-zle
    } always {
      zpty -d syntax 2>/dev/null
      exec {efd}<&-
    }
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native-zle "$output"
}
test_case 'Git syntax renders native ZLE foregrounds and diff backgrounds with pane navigation and cleanup' _test_git_syntax_zle
