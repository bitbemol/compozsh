# Automatic Working changes refresh is a live terminal behavior: exercise the
# deadline wakeup, asynchronous Git worker, atomic repaint and pending-removal
# handoff through a real PTY rather than calling controller helpers in isolation.
_test_git_auto_refresh_native() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    ZSH_GIT_REVIEW_AUTO_REFRESH=1
    _GIT_REVIEW_AUTO_REFRESH_INTERVAL=0.12
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -qb main
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print -r -- base > file
    print -r -- base > other
    git add file other && git commit -qm initial || exit 1
    print -r -- one >> file
    local line=0
    for line in {1..30}; do print -r -- "context $line" >> file; done
    print -r -- other-change >> other

    zmodload zsh/zpty
    zmodload zsh/zselect
    zmodload zsh/datetime
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions -c _zle_picker_show _auto_test_show
    _zle_picker_show() {
      _auto_test_show
      (( ${_ZLE_PICKER_BUSY:-0} )) && {
        print -r -u $efd BUSY
        return 0
      }
      [[ $_ZLE_PICKER_TITLE == "Working changes" ]] || return 0
      local document=${(F)_ZLE_PICKER_DOCUMENT_LINES} state=none
      [[ $document == *"+one"* ]] && state=one
      [[ $document == *"+two"* ]] && state=two
      [[ $document == *"+three"* ]] && state=three
      local -i on=0 off=0 updated=0 pending=0 pause=0 resume=0
      [[ $_ZLE_PICKER_HEADER == *"auto on"* ]] && on=1
      [[ $_ZLE_PICKER_HEADER == *"auto off"* ]] && off=1
      [[ $_ZLE_PICKER_HEADER == *"updated automatically"* ]] && updated=1
      [[ $_ZLE_PICKER_HEADER == *"update ready"* ]] && pending=1
      [[ $_ZLE_PICKER_DISPLAY[-1] == *"^A pause auto"* ]] && pause=1
      [[ $_ZLE_PICKER_DISPLAY[-1] == *"^A resume auto"* ]] && resume=1
      local visible_query=${_ZLE_PICKER_QUERY:-_}
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_INSPECT_FOCUS|$state|$on|$off|$updated|$pending|$pause|$resume|${#_GIT_REVIEW_PATHS}|$visible_query|$_ZLE_PICKER_INSPECT_OFFSET"
    }
    zle() {
      [[ $1 == (clear-screen|.clear-screen) ]] && print -r -u $efd CLEAR
      builtin zle "$@"
    }
    _auto_test_driver() {
      command stty rows 26 cols 120
      print -r -u $efd READY
      _zle_picker_run 10 "" 1 0 _auto_test_session
      local outcome=$?
      print -r -u $efd -- "DONE:$outcome"
    }
    _auto_test_session() { _git_review_view "$HOME/repo" working; }
    _auto_test_expect() {
      local wanted=$1 forbidden=${2:-} event="" chunk=""
      local -i select_result=0
      local -F deadline=$(( EPOCHREALTIME + 6.0 ))
      while (( EPOCHREALTIME < deadline )); do
        zselect -r $efd $pfd -t 30 2>/dev/null
        select_result=$?
        if (( select_result == 0 )); then
          while zpty -r auto-review chunk; do trace+=$chunk; done
          if IFS= read -r -t 0 -u $efd event; then
            events+=("$event")
            if [[ -n $forbidden && $event == "$forbidden"* ]]; then
              print -u2 -r -- "forbidden intermediate frame $event while waiting for $wanted"
              return 1
            fi
            [[ $event == "$wanted" ]] && return 0
          fi
        else
          while zpty -r auto-review chunk; do trace+=$chunk; done
          zpty -t auto-review 2>/dev/null || break
        fi
      done
      while zpty -r auto-review chunk; do trace+=$chunk; done
      print -u2 -r -- "expected $wanted; got ${(j:,:)events}; trace=${(V)trace}"
      return 1
    }
    _auto_test_key() {
      zpty -w -n auto-review "$1"
      _auto_test_expect "$2"
    }

    local trace="" chunk="" event="" pfd=0
    local -a events=()
    zpty -b auto-review _auto_test_driver || exit 2
    pfd=$REPLY
    {
      _auto_test_expect READY || exit 3
      _auto_test_expect "FRAME|0|one|1|0|0|0|1|0|2|_|0" || exit 4
      _auto_test_key f "FRAME|0|one|1|0|0|0|1|0|2|f|0" || exit 5
      _auto_test_key $'\''\e[C'\'' "FRAME|1|one|1|0|0|0|1|0|2|f|0" || exit 6
      _auto_test_key $'\''\e[B'\'' "FRAME|1|one|1|0|0|0|1|0|2|f|1" || exit 7

      # A surviving selected diff replaces the reader in one ordinary frame.
      # No key wakes this transition: the shared idle deadline must do it.
      print -r -- two >> "$HOME/repo/file"
      _auto_test_expect "FRAME|1|two|1|0|1|0|1|0|2|f|1" "FRAME|1|none|" || exit 8

      # Ctrl-A pauses this screen session without changing the snapshot.
      _auto_test_key $'\''\x01'\'' "FRAME|1|two|0|1|0|0|0|1|2|f|1" || exit 9
      print -r -- three >> "$HOME/repo/file"
      command sleep 0.45
      while zselect -r $efd -t 0 && IFS= read -r -t 0 -u $efd event; do
        events+=("$event")
        [[ $event != FRAME\|1\|three\|* ]] || exit 10
      done
      _auto_test_key $'\''\x01'\'' "FRAME|1|two|1|0|0|0|1|0|2|f|1" || exit 11
      _auto_test_expect "FRAME|1|three|1|0|1|0|1|0|2|f|1" "FRAME|1|none|" || exit 12

      # When the exact path/change kind disappears, keep the old reader and
      # advertise a pending snapshot. Returning to files applies it; automatic
      # refresh never yanks focus away while the user is reading.
      git -C "$HOME/repo" checkout -q -- file || exit 13
      _auto_test_expect "FRAME|1|three|1|0|0|1|1|0|2|f|1" "FRAME|1|none|" || exit 14
      _auto_test_key $'\''\x02'\'' "FRAME|0|none|1|0|1|0|1|0|1|f|0" || exit 15
      zpty -w -n auto-review $'\''\e'\''
      _auto_test_expect DONE:1 || exit 16

      local item=""
      local -i busy_count=0 clear_count=0
      for item in "${events[@]}"; do
        [[ $item == BUSY ]] && (( ++busy_count ))
        [[ $item == CLEAR ]] && (( ++clear_count ))
      done
      # One busy frame and one clear belong to initial synchronous entry only.
      (( busy_count == 1 && clear_count == 1 )) || {
        print -u2 -- "unexpected busy/clear lifecycle: ${(j:,:)events}"; exit 17
      }
      [[ $trace == *"$enter"*"$leave"* && ${trace#*"$enter"} != *"$enter"* ]] || exit 18
    } always {
      zpty -d auto-review
    }
    print refreshed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refreshed "$output"
}
test_case 'Git Working changes auto-refreshes atomically and preserves an active reader' \
  _test_git_auto_refresh_native

_test_git_auto_refresh_ages() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local -i _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=0
    local -i _git_auto_failed=0 _git_auto_checked_at=$(( EPOCHSECONDS - 5 ))
    local -i _git_auto_updated_at=$(( EPOCHSECONDS - 305 ))
    local _git_review_refresh_status="" _git_review_event_status=""
    local _GIT_REVIEW_SUMMARY=changes _GIT_REVIEW_DOCUMENT_SUMMARY=""
    local _ZLE_PICKER_DOCUMENT_KEY="" _ZLE_PICKER_BROWSE_LABEL=""
    _git_review_status_apply >/dev/null
    print -r -- "$_ZLE_PICKER_BROWSE_LABEL"
    _ZLE_PICKER_AUTO_REFRESH=0
    _git_review_status_apply >/dev/null
    print -r -- "$_ZLE_PICKER_BROWSE_LABEL"
    _ZLE_PICKER_AUTO_REFRESH=0 _git_auto_failed=1
    _git_review_status_apply >/dev/null
    print -r -- "$_ZLE_PICKER_BROWSE_LABEL"
    _git_auto_updated_at=0
    _git_review_status_apply >/dev/null
    print -r -- "$_ZLE_PICKER_BROWSE_LABEL"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'auto on · checked now · updated 5m ago' || return
  test_assert_contains "$output" 'auto off · snapshot updated 5m ago' || return
  test_assert_contains "$output" 'auto paused · checked now · snapshot updated 5m ago' || return
  test_assert_contains "$output" 'auto paused · checked now · snapshot unavailable'
}
test_case 'Git auto-refresh indicator distinguishes checks from visible updates' \
  _test_git_auto_refresh_ages

_test_git_auto_refresh_filtered_selection() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.git-review"
    local -i _git_auto_candidate_match=1
    local -a _git_auto_candidate_labels=(file.zsh)
    local -a _git_auto_candidate_contexts=("Staged M")
    local _ZLE_PICKER_QUERY=unstaged
    _git_review_auto_candidate_visible
    print -r -- $?
    _ZLE_PICKER_QUERY=file
    _git_review_auto_candidate_visible
    print -r -- $?
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal $'1\n0' "$output"
}
test_case 'Git auto-refresh defers a selected change that leaves the active filter' \
  _test_git_auto_refresh_filtered_selection

_test_git_auto_refresh_pending_wording() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local -i _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=1
    local -i _git_auto_failed=0 _git_auto_checked_at=$EPOCHSECONDS _git_auto_updated_at=$EPOCHSECONDS
    local _git_review_refresh_status="" _git_review_event_status="selected change resolved or moved"
    local _GIT_REVIEW_SUMMARY=changes _GIT_REVIEW_DOCUMENT_SUMMARY=""
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_BROWSE_LABEL=""
    _git_review_status_apply >/dev/null
    print -r -- "$_ZLE_PICKER_BROWSE_LABEL"
    _git_review_event_status="selected change no longer matches filter"
    _git_review_status_apply >/dev/null
    print -r -- "$_ZLE_PICKER_BROWSE_LABEL"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'update ready · current snapshot updated now · selected change resolved or moved' || return
  test_assert_contains "$output" 'update ready · current snapshot updated now · selected change no longer matches filter'
}
test_case 'Git pending refresh distinguishes resolution from filter exclusion' \
  _test_git_auto_refresh_pending_wording

_test_git_auto_refresh_pending_identity() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    local context=3 loaded="" loaded_data=""
    local -a bookmark=("" 1 0)
    local -i focus=1 _ZLE_PICKER_DOCUMENT_KEY=2 _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=1
    local -i _git_auto_candidate_diff_truncated=0 _git_auto_candidate_list_truncated=0
    local -i _git_auto_updated_at=0 _git_auto_failed=0 _ZLE_PICKER_AUTO_REFRESH=1
    local -a _GIT_REVIEW_PATHS=(wrong.zsh right.zsh)
    local -a _GIT_REVIEW_KINDS=(unstaged unstaged)
    local -a _GIT_REVIEW_LABELS=(wrong.zsh right.zsh)
    local -a _GIT_REVIEW_CONTEXTS=("Unstaged M" "Unstaged M")
    local -a _GIT_REVIEW_DETAILS=(wrong right) _GIT_REVIEW_PARENTS=("" "")
    local -a _GIT_REVIEW_CONFIG=()
    local -a _git_auto_candidate_paths=(right.zsh wrong.zsh)
    local -a _git_auto_candidate_kinds=(unstaged unstaged)
    local -a _git_auto_candidate_labels=(right.zsh wrong.zsh)
    local -a _git_auto_candidate_contexts=("Unstaged D" "Unstaged M")
    local -a _git_auto_candidate_details=(right wrong)
    local -a _git_auto_candidate_parents=("" "") _git_auto_candidate_config=()
    local _git_auto_candidate_request_name=right.zsh
    local _git_auto_candidate_request_kind=unstaged _git_auto_candidate_request_context=3
    local _git_auto_candidate_diff_data=RIGHT
    local _git_auto_candidate_summary=summary _git_auto_candidate_notice=notice
    local -A _ZLE_PICKER_DOCUMENT_ROWS=(2 1) _git_document_cache=()
    local -A _git_document_partial=() _git_document_syntax_cache=()
    local -A _git_document_syntax_notes=() _git_document_syntax_first=()
    local -A _git_document_syntax_last=() _git_document_syntax_failures=()
    local -A _git_document_contexts=() _git_document_anchors=()
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -a _git_document_order=() _ZLE_PICKER_DOCUMENT_LINES=()
    local -a _ZLE_PICKER_DOCUMENT_ROLES=() _GIT_REVIEW_DOCUMENT_OLD=()
    local -a _GIT_REVIEW_DOCUMENT_NEW=() _ZLE_PICKER_EMPTY_LINES=()
    local -i _git_review_snapshot_epoch=1 _ZLE_PICKER_DOCUMENT_PENDING=0
    local -i _GIT_REVIEW_DOCUMENT_HAS_CODE=0 _ZLE_PICKER_DOCUMENT_TARGET_ROW=0
    local -i _GIT_REVIEW_TRUNCATED=0
    local _ZLE_PICKER_DOCUMENT_TITLE=x _ZLE_PICKER_DOCUMENT_MODE=focused
    local _GIT_REVIEW_SUMMARY=old _GIT_REVIEW_NOTICE=old
    local _GIT_REVIEW_DOCUMENT_SUMMARY="" _git_review_event_status=""
    local _git_review_refresh_status="" _ZLE_PICKER_QUERY="" _ZLE_PICKER_BROWSE_LABEL=""
    _git_review_document_anchor() { REPLY=new:1; }
    _git_review_syntax_cleanup() { return 0; }
    _git_review_document_load() {
      loaded=${_GIT_REVIEW_PATHS[$2]}
      _git_review_document_cache_key "$2" "$5"
      loaded_data=${_git_document_cache[$REPLY]-}
    }
    _git_review_status_apply() { return 0; }
    _git_review_auto_publish root
    print -r -- "$loaded|$loaded_data"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal 'right.zsh|RIGHT' "$output"
}
test_case 'Git pending refresh remains bound to its exact path when focus return edits the filter' \
  _test_git_auto_refresh_pending_identity

_test_git_auto_refresh_cancel_drain() {
  test_make_temp_dir || return
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/system
    zmodload zsh/zselect
    unsetopt BG_NICE
    local _git_auto_session_dir="" _git_auto_session_fifo=""
    local _git_auto_session_buffer=stale
    local -i _git_auto_session_fd=-1 _git_auto_session_pid=0 amount=0
    local chunk=""
    _git_review_auto_session_start || exit 1
    print -rn -- partial > "$_git_auto_session_fifo" &
    _git_auto_session_pid=$!
    zselect -r $_git_auto_session_fd -t 100 || exit 2
    _git_review_auto_worker_stop
    if zselect -r $_git_auto_session_fd -t 0; then
      sysread -i $_git_auto_session_fd -s 8192 -c amount chunk
    fi
    print -r -- "${#chunk}|$_git_auto_session_buffer|$_git_auto_session_pid"
    _git_review_auto_session_stop
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '0||0' "$output"
}
test_case 'Git auto-refresh cancellation drains a partial worker packet before resume' \
  _test_git_auto_refresh_cancel_drain

_test_git_auto_refresh_packet_numbers() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    local _git_auto_session_buffer=""
    local -a packets=(
      $'"'"'compozsh-review-1\n999999999999999999999999999999999999999999:x'"'"'
      $'"'"'compozsh-review-1\n40:9999999999999999999999999999999999999999'"'"')
    local packet=""
    for packet in "${packets[@]}"; do
      _git_auto_session_buffer=$packet
      _git_review_auto_parse
      print -r -- $?
    done
  ' zsh "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal $'1\n1' "$output"
}
test_case 'Git auto-refresh rejects oversized packet numbers without terminal diagnostics' \
  _test_git_auto_refresh_packet_numbers

_test_git_auto_refresh_manual_pause_state() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local -i _ZLE_PICKER_AUTO_REFRESH=0 _git_auto_failed=0
    local -i _git_auto_checked_at=0 _git_auto_updated_at=0
    local -F _git_auto_next_at=0
    _git_review_manual_refresh_auto_state 0 0 0
    print -r -- "paused-fail:$_ZLE_PICKER_AUTO_REFRESH:$_git_auto_failed"
    _git_review_manual_refresh_auto_state 1 0 0
    print -r -- "paused-success:$_ZLE_PICKER_AUTO_REFRESH:$_git_auto_failed"
    _git_auto_failed=1
    _git_review_manual_refresh_auto_state 1 1 0
    print -r -- "auto-retry:$_ZLE_PICKER_AUTO_REFRESH:$_git_auto_failed"
    _ZLE_PICKER_AUTO_REFRESH=1 _git_auto_failed=0
    _git_review_manual_refresh_auto_state 0 0 1
    print -r -- "auto-fail:$_ZLE_PICKER_AUTO_REFRESH:$_git_auto_failed"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal $'paused-fail:0:0\npaused-success:0:0\nauto-retry:1:0\nauto-fail:0:1' "$output"
}
test_case 'Git manual refresh preserves an intentional auto-refresh pause' \
  _test_git_auto_refresh_manual_pause_state

_test_git_auto_refresh_manual_retry_controller() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i turns=0 refreshes=0
    _git_review_load() {
      _GIT_REVIEW_PATHS=(file) _GIT_REVIEW_LABELS=(file)
      _GIT_REVIEW_KINDS=(unstaged) _GIT_REVIEW_CONTEXTS=("Unstaged M")
      _GIT_REVIEW_DETAILS=(detail) _GIT_REVIEW_PARENTS=("")
      _GIT_REVIEW_SUMMARY=summary _GIT_REVIEW_NOTICE=""
      return 0
    }
    _git_review_refresh() {
      (( ++refreshes ))
      _git_review_refresh_succeeded=1
      return 0
    }
    _zle_picker_loop() {
      (( ++turns ))
      if (( turns == 1 )); then
        _git_auto_failed=1
        _ZLE_PICKER_AUTO_REFRESH=0
        _ZLE_PICKER_ACTION=document-refresh
        _ZLE_PICKER_BOOKMARK=("" 1 0)
        _ZLE_PICKER_BOOKMARK_FOCUS=0
        _ZLE_PICKER_SELECTED_VALUE=1
        return 0
      fi
      print -r -- "$_ZLE_PICKER_AUTO_REFRESH|$_git_auto_failed|$refreshes"
      return 1
    }
    _git_review_view /fixture working
    [[ $? == 1 ]] || exit 2
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '1|0|1' "$output"
}
test_case 'Git Ctrl-R controller resumes automatic checks after an automatic failure' \
  _test_git_auto_refresh_manual_retry_controller

_test_git_auto_refresh_safety_publication() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i _git_auto_candidate_ready=1 _git_auto_candidate_prepare_result=0
    local -i _git_review_reads_blocked=1
    local -a _GIT_REVIEW_CONFIG=(old) _git_auto_candidate_config=(safe)
    _git_review_auto_safety_adopt
    print -r -- "safe:$?:$_git_review_reads_blocked:${(j:,:)_GIT_REVIEW_CONFIG}"
    _git_auto_candidate_prepare_result=2
    _git_auto_candidate_config=(unsafe)
    _git_review_auto_safety_adopt
    print -r -- "failed:$?:$_git_review_reads_blocked:${(j:,:)_GIT_REVIEW_CONFIG}"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal $'safe:0:0:safe\nfailed:1:1:safe' "$output"
}
test_case 'Git automatic candidates publish filter-safety state independently' \
  _test_git_auto_refresh_safety_publication

_test_git_auto_refresh_pending_context() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local context=1000000000 _git_auto_candidate_request_context=3
    local _git_review_event_status="" _git_review_refresh_status=""
    local -i _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_GUIDE_ACTIVE=0
    local -i _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=1 _git_auto_candidate_ready=1
    local -i _git_auto_session_pid=0
    local -F _git_auto_next_at=$(( EPOCHREALTIME + 10.0 )) old_next=0 _ZLE_PICKER_IDLE_WAIT=0
    local -a _git_auto_candidate_config=(safe) _git_auto_candidate_paths=(file)
    local -a _git_auto_candidate_labels=(file) _git_auto_candidate_kinds=(unstaged)
    local -a _git_auto_candidate_contexts=("Unstaged M") _git_auto_candidate_details=(detail)
    local -a _git_auto_candidate_parents=("")
    old_next=$_git_auto_next_at
    _git_review_status_apply() { return 1; }
    _git_review_auto_idle
    print -r -- "$_ZLE_PICKER_DOCUMENT_UPDATE_PENDING|$_git_auto_candidate_ready|$_git_review_event_status|$(( _git_auto_next_at >= old_next ))"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '0|0|context changed · checking again|1' "$output"
}
test_case 'Git pending refresh keeps its context and adaptive pacing boundary' \
  _test_git_auto_refresh_pending_context

_test_git_auto_refresh_other_bookmarks() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    local context=3
    local -i _ZLE_PICKER_SELECTED=1
    local -a _ZLE_PICKER_RESULTS=(1)
    local -A _git_document_cache=(1:3 one 2:3 two)
    local -A _git_document_partial=(1:3 0 2:3 0)
    local -A _git_document_syntax_cache=(1:3 one 2:3 two)
    local -A _git_document_syntax_notes=() _git_document_syntax_first=() _git_document_syntax_last=()
    local -A _git_document_syntax_failures=()
    local -A _git_document_contexts=(1 3 2 1000000000)
    local -A _git_document_anchors=(1 new:4 2 new:9)
    local -A _ZLE_PICKER_DOCUMENT_OFFSETS=(1 5 2 8) _ZLE_PICKER_DOCUMENT_ROWS=(1 7 2 11)
    local -a _git_document_order=(1:3 2:3)
    _git_review_auto_forget_other_documents
    print -r -- "${(j:,:)${(ok)_git_document_cache}}|${(j:,:)${(ok)_git_document_contexts}}|${_git_document_anchors[1]}|${_ZLE_PICKER_DOCUMENT_OFFSETS[1]}|${_ZLE_PICKER_DOCUMENT_ROWS[1]}"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '1:3|1|new:4|5|7' "$output"
}
test_case 'Git unchanged checks retire every non-selected document bookmark' \
  _test_git_auto_refresh_other_bookmarks

_test_git_auto_refresh_selection_floor() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local root=/fixture context=3 old_next=""
    local -i _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_GUIDE_ACTIVE=0
    local -i _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=0 _git_auto_session_pid=0
    local -i _git_auto_candidate_ready=1 _git_auto_candidate_generation=4 _git_auto_generation=4
    local -i _git_auto_candidate_result=0 _git_auto_candidate_prepare_result=0
    local -i _ZLE_PICKER_SELECTED=1 _git_review_reads_blocked=0
    local -F _git_auto_next_at=$(( EPOCHREALTIME + 4.0 )) _ZLE_PICKER_IDLE_WAIT=0
    local -a _ZLE_PICKER_RESULTS=(1) _GIT_REVIEW_PATHS=(current) _GIT_REVIEW_KINDS=(unstaged)
    local -a _git_auto_candidate_config=(safe) _git_auto_candidate_paths=()
    local -a _git_auto_candidate_labels=() _git_auto_candidate_kinds=()
    local -a _git_auto_candidate_contexts=() _git_auto_candidate_details=() _git_auto_candidate_parents=()
    local _git_auto_candidate_request_name=previous _git_auto_candidate_request_kind=unstaged
    local _git_auto_candidate_request_context=3 _git_review_refresh_status="" _git_review_event_status=""
    old_next=$_git_auto_next_at
    _git_review_status_apply() { return 1; }
    _git_review_auto_idle
    (( _git_auto_next_at == old_next )) && print preserved || print changed
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'Git selection churn preserves the automatic refresh pacing floor' \
  _test_git_auto_refresh_selection_floor

_test_git_auto_refresh_immutable_views() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    local -i _ZLE_PICKER_AUTO_REFRESH=-1 launches=0
    local -F _ZLE_PICKER_IDLE_WAIT=0
    _git_review_auto_launch() { (( ++launches )); }
    _git_review_auto_idle
    print -r -- "$?|$launches"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '2|0' "$output"
}
test_case 'Git commit and comparison views never launch automatic providers' \
  _test_git_auto_refresh_immutable_views

_test_git_filter_configuration_bound() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    local fixture="" key="" driver=0
    _git_review_capture() { _GIT_REVIEW_DATA=$fixture; _GIT_REVIEW_TRUNCATED=0; return 1; }
    for driver in {1..682}; do fixture+="filter.driver${driver}.clean"$'"'"'\0'"'"'; done
    _git_review_prepare /fixture
    print -r -- "$?|${#_GIT_REVIEW_CONFIG}"
    fixture+="filter.driver683.clean"$'"'"'\0'"'"'
    _git_review_prepare /fixture
    print -r -- "$?|${#_GIT_REVIEW_CONFIG}"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal $'0|4092\n2|4092' "$output"
}
test_case 'Git filter preparation and auto transport share one entry bound' \
  _test_git_filter_configuration_bound

_test_git_filter_equals_name_fails_closed() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repo" marker="$TEST_TMP_DIR/filter-ran"
  command mkdir -p "$repo" || return
  command git -C "$repo" init -qb main || return
  command git -C "$repo" config user.name Fixture || return
  command git -C "$repo" config user.email fixture@example.invalid || return
  command git -C "$repo" config commit.gpgsign false || return
  print -r -- 'file filter=foo=bar' >| "$repo/.gitattributes"
  print -r -- base >| "$repo/file"
  command git -C "$repo" add .gitattributes file || return
  command git -C "$repo" commit -qm initial || return
  command git -C "$repo" config 'filter.foo=bar.clean' 'touch "$COMPOZSH_MARKER"; /bin/cat' || return
  command git -C "$repo" config 'filter.foo=bar.required' true || return
  print -r -- changed >> "$repo/file"
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export COMPOZSH_MARKER="$2/filter-ran"
    source "$1/.zsh.addons/.zsh.git-review"
    _git_review_prepare "$2/repo"
    local manual=$?
    local packet=$(_git_review_auto_worker "$2/repo" 4 file unstaged 3 "$2")$'"'"'\n'"'"'
    local _git_auto_session_buffer=$packet
    local -a _git_auto_candidate_config=() _git_auto_candidate_paths=()
    local -a _git_auto_candidate_labels=() _git_auto_candidate_kinds=()
    local -a _git_auto_candidate_contexts=() _git_auto_candidate_details=() _git_auto_candidate_parents=()
    local -F _git_auto_candidate_capture_duration=0
    _git_review_auto_parse || exit 2
    local marker_state=absent
    [[ -e "$COMPOZSH_MARKER" ]] && marker_state=executed
    print -r -- "$manual|$_git_auto_candidate_result|$_git_auto_candidate_prepare_result|$marker_state"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal '2|2|2|absent' "$output"
  [[ ! -e $marker ]] || test_fail 'ambiguous Git filter driver executed'
}
test_case 'Git filter names with equals fail closed in manual and automatic refresh' \
  _test_git_filter_equals_name_fails_closed

_test_git_auto_refresh_timeout() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local root=/fixture context=3 _git_review_event_status="" _git_review_refresh_status=""
    local -i _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_GUIDE_ACTIVE=0 stopped=0
    local -i _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=0 _git_auto_session_pid=42
    local -i _git_auto_failed=0 _git_review_reads_blocked=0
    local -F _git_auto_deadline_at=$(( EPOCHREALTIME - 1 )) _ZLE_PICKER_IDLE_WAIT=0
    _git_review_auto_poll() { return 1; }
    _git_review_auto_worker_stop() { stopped=1; _git_auto_session_pid=0; }
    _git_review_auto_candidate_clear() { return 0; }
    _git_review_status_apply() { return 1; }
    _git_review_auto_idle
    print -r -- "$_ZLE_PICKER_AUTO_REFRESH|$_git_auto_failed|$_git_review_reads_blocked|$stopped|$_git_review_event_status"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '0|1|1|1|automatic refresh timed out' "$output"
}
test_case 'Git hung automatic checks time out and fail closed' \
  _test_git_auto_refresh_timeout

_test_git_auto_refresh_worker_deadline() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/bin" "$TEST_TMP_DIR/home/repo" || return
  test_write_file "$TEST_TMP_DIR/bin/git" '#!/bin/zsh -df
exec /bin/sleep 30' || return
  command chmod 700 "$TEST_TMP_DIR/bin/git" || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    PATH="$2/bin:$PATH"
    export COMPOZSH_SPY_PID="$2/provider.pid"
    source "$1/.zsh.addons/.zsh.git-review"
    # Observe the worker-owned provider before exec. A first launch of a newly
    # written script can itself exceed this deliberately short deadline; the
    # deadline correctly kills it before the script can publish a sentinel.
    # Closing stdout here still exercises the liveness descriptor, even then.
    functions[_deadline_provider_git]=$functions[_git_review_git]
    _git_review_git() {
      zmodload zsh/system || return
      print -r -- $sysparams[pid] >| "$COMPOZSH_SPY_PID"
      exec 1>&-
      _deadline_provider_git "$@"
    }
    zmodload zsh/datetime
    zmodload zsh/zselect
    _GIT_REVIEW_AUTO_REFRESH_TIMEOUT=0.5
    local root="$HOME/repo" context=3
    local -i _ZLE_PICKER_SELECTED=0 _git_auto_session_fd=-1 _git_auto_session_pid=0
    local -i _git_auto_generation=0 poll_result=1 attempt=0 provider=0
    local -F _git_auto_started_at=0 _git_auto_deadline_at=0 started=$EPOCHREALTIME elapsed=0
    local -F _ZLE_PICKER_DEADLINE_AT=0
    local _git_auto_session_dir="" _git_auto_session_fifo="" _git_auto_session_buffer=""
    local _git_auto_request_name="" _git_auto_request_kind="" _git_auto_request_context=""
    local -a _ZLE_PICKER_RESULTS=()
    _git_review_auto_launch || exit 1
    for (( attempt=1; attempt<=100; ++attempt )); do
      [[ -s "$2/provider.pid" ]] && break
      zselect -t 1 2>/dev/null || true
    done
    [[ -s "$2/provider.pid" ]] || exit 2
    provider=$(<"$2/provider.pid")
    for (( attempt=1; attempt<=100; ++attempt )); do
      _git_review_auto_poll
      poll_result=$?
      (( poll_result != 1 )) && break
      zselect -t 1 2>/dev/null || true
    done
    elapsed=$(( EPOCHREALTIME - started ))
    local state=stopped
    kill -0 $provider 2>/dev/null && state=alive
    print -r -- "$poll_result|$state|$(( elapsed < 2.5 ))"
    _git_review_auto_session_stop
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal '3|stopped|1' "$output"
}
test_case 'Git automatic worker enforces its deadline without picker-idle polling' \
  _test_git_auto_refresh_worker_deadline

_test_git_auto_refresh_provider_cancellation() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/bin" "$TEST_TMP_DIR/home/repo" || return
  test_write_file "$TEST_TMP_DIR/bin/git" '#!/bin/zsh -df
exec /bin/sleep 30' || return
  command chmod 700 "$TEST_TMP_DIR/bin/git" || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    PATH="$2/bin:$PATH"
    export COMPOZSH_SPY_PID="$2/provider.pid"
    source "$1/.zsh.addons/.zsh.git-review"
    # Publish the exact owned PID before a potentially slow first exec, as in
    # the deadline fixture. No grandchild or parent-visible PID inference.
    functions[_cancel_provider_git]=$functions[_git_review_git]
    _git_review_git() {
      zmodload zsh/system || return
      print -r -- $sysparams[pid] >| "$COMPOZSH_SPY_PID"
      exec 1>&-
      _cancel_provider_git "$@"
    }
    zmodload zsh/datetime
    zmodload zsh/zselect
    local root="$HOME/repo" context=3
    local -i _ZLE_PICKER_SELECTED=0 _git_auto_session_fd=-1 _git_auto_session_pid=0
    local -i _git_auto_generation=0
    local -F _git_auto_started_at=0 _git_auto_deadline_at=0
    local _git_auto_session_dir="" _git_auto_session_fifo="" _git_auto_session_buffer=""
    local _git_auto_request_name="" _git_auto_request_kind="" _git_auto_request_context=""
    local -a _ZLE_PICKER_RESULTS=()
    _git_review_auto_launch || exit 1
    local -i attempt=0 provider=0
    for (( attempt=1; attempt<=100; ++attempt )); do
      [[ -s "$2/provider.pid" ]] && break
      zselect -t 1 2>/dev/null || true
    done
    [[ -s "$2/provider.pid" ]] || exit 2
    provider=$(<"$2/provider.pid")
    _git_review_auto_worker_stop
    if kill -0 $provider 2>/dev/null; then
      print -r -- "$provider|alive|$_git_auto_session_pid"
    else
      print -r -- "$provider|stopped|$_git_auto_session_pid"
    fi
    _git_review_auto_session_stop
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  local -a parts=("${(@s:|:)output}")
  local provider=${parts[1]-} state=${parts[2]-} worker=${parts[3]-}
  [[ $provider == <-> ]] || { test_fail 'worker did not expose the fake Git PID'; return; }
  test_assert_equal 'stopped|0' "$state|$worker"
}
test_case 'Git auto-refresh cancellation is owned and reaped by its worker' \
  _test_git_auto_refresh_provider_cancellation

_test_git_auto_refresh_narrow_status() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local -i _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=0
    local -i _git_auto_failed=0 _git_auto_checked_at=$EPOCHSECONDS _git_auto_updated_at=$EPOCHSECONDS
    local _git_review_refresh_status="" _git_review_event_status=""
    local _GIT_REVIEW_SUMMARY="12 staged · 34 unstaged · 5 untracked · 1 conflict"
    local _GIT_REVIEW_DOCUMENT_SUMMARY="+123 -456 · read-only"
    local _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_BROWSE_LABEL=""
    local -i width=0
    _git_review_status_apply >/dev/null
    for width in 59 70 80 89; do
      _zle_picker_fit "$_ZLE_PICKER_BROWSE_LABEL · 20 shown" $width
      print -r -- "$REPLY"
    done
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'auto on · checked now · updated now' || return
  local line=''
  while IFS= read -r line; do
    [[ $line == 'auto on · checked now · updated now'* ]] || {
      test_fail "narrow status lost a freshness clock: $line"
      return
    }
  done <<< "$output"
}
test_case 'Git refresh state remains visible at narrow document widths' \
  _test_git_auto_refresh_narrow_status

_test_git_auto_refresh_failure_safety_packet() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    _git_review_prepare() {
      _GIT_REVIEW_CONFIG=(-c filter.safe.clean= -c filter.safe.process= -c filter.safe.required=false)
      return 0
    }
    _git_review_changes_capture() { return 2; }
    local packet=$(_git_review_auto_worker /fixture 9 "" "" 3 /tmp)$'"'"'\n'"'"'
    local _git_auto_session_buffer=$packet
    local -i _git_auto_candidate_ready=0 _git_review_reads_blocked=1
    local -a _GIT_REVIEW_CONFIG=(old) _git_auto_candidate_config=()
    local -a _git_auto_candidate_paths=() _git_auto_candidate_labels=()
    local -a _git_auto_candidate_kinds=() _git_auto_candidate_contexts=()
    local -a _git_auto_candidate_details=() _git_auto_candidate_parents=()
    local -F _git_auto_candidate_capture_duration=0
    _git_review_auto_parse || exit 1
    _git_auto_candidate_ready=1
    _git_review_auto_safety_adopt || exit 2
    print -r -- "$_git_auto_candidate_result|$_git_auto_candidate_prepare_result|$_git_review_reads_blocked|${(j:,:)_GIT_REVIEW_CONFIG}"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '2|0|0|-c,filter.safe.clean=,-c,filter.safe.process=,-c,filter.safe.required=false' "$output"
}
test_case 'Git failed auto status retains newly validated filter overrides' \
  _test_git_auto_refresh_failure_safety_packet

_test_git_auto_refresh_maximum_config_packet() {
  local output
  output=$(/bin/zsh -fc '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local _git_auto_packet=$'"'"'compozsh-review-1\n'"'"'
    local -i index=0 driver=0 _git_auto_candidate_ready=0
    local _git_auto_session_buffer=""
    local -a config=()
    local -a _git_auto_candidate_config=() _git_auto_candidate_paths=()
    local -a _git_auto_candidate_labels=() _git_auto_candidate_kinds=()
    local -a _git_auto_candidate_contexts=() _git_auto_candidate_details=() _git_auto_candidate_parents=()
    local -F _git_auto_candidate_capture_duration=0
    _git_review_packet_add 2
    _git_review_packet_add 1
    _git_review_packet_add 0
    _git_review_packet_add 4092
    for (( driver=1; driver<=682; ++driver )); do
      config+=(-c "filter.driver${driver}.clean=" -c "filter.driver${driver}.process=" -c "filter.driver${driver}.required=false")
    done
    _git_review_packet_add "${(pj:\0:)config}"
    _git_review_packet_add 0.01
    _git_auto_packet+=$'"'"'compozsh-review-end-1\n'"'"'
    _git_auto_session_buffer=$_git_auto_packet
    _git_review_auto_parse
    print -r -- "$?|${#_git_auto_candidate_config}"
  ' zsh "$TEST_REPO_ROOT") || return
  test_assert_equal '0|4092' "$output"
}
test_case 'Git auto-refresh parses the maximum filter packet linearly' \
  _test_git_auto_refresh_maximum_config_packet

_test_git_auto_refresh_hostile_paths() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repo" colon='colon:name' newline=$'line\nname' control=$'control\x01name'
  command mkdir -p "$repo" || return
  command git -C "$repo" init -qb main || return
  command git -C "$repo" config user.name Fixture || return
  command git -C "$repo" config user.email fixture@example.invalid || return
  command git -C "$repo" config commit.gpgsign false || return
  print -r -- base >| "$repo/$colon"
  print -r -- base >| "$repo/$newline"
  print -r -- base >| "$repo/$control"
  command git -C "$repo" add -- "$colon" "$newline" "$control" || return
  command git -C "$repo" commit -qm initial || return
  print -r -- changed >> "$repo/$colon"
  print -r -- changed >> "$repo/$newline"
  print -r -- changed >> "$repo/$control"
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local session="$2/session" request=$'"'"'line\nname'"'"'
    command mkdir -m 700 "$session" || exit 1
    _git_review_prepare "$2/repo"
    local preflight=$?
    local -x GIT_TRACE=9
    _git_review_auto_worker "$2/repo" 3 "$request" unstaged 3 "$session" >| "$session/packet" || exit 2
    local packet=$(<"$session/packet")$'"'"'\n'"'"'
    local _git_auto_session_buffer=$packet
    local -a _git_auto_candidate_config=() _git_auto_candidate_paths=()
    local -a _git_auto_candidate_labels=() _git_auto_candidate_kinds=()
    local -a _git_auto_candidate_contexts=() _git_auto_candidate_details=() _git_auto_candidate_parents=()
    local -F _git_auto_candidate_capture_duration=0
    _git_review_auto_parse || exit 3
    local -i colon_seen=0 newline_seen=0 control_seen=0 index=0
    for (( index=1; index<=${#_git_auto_candidate_paths}; ++index )); do
      [[ ${_git_auto_candidate_paths[index]} == colon:name ]] && colon_seen=1
      [[ ${_git_auto_candidate_paths[index]} == "$request" ]] && newline_seen=1
      [[ ${_git_auto_candidate_paths[index]} == $'"'"'control\x01name'"'"' ]] && control_seen=1
    done
    print -r -- "$preflight|$_git_auto_candidate_result|$_git_auto_candidate_prepare_result|${#_git_auto_candidate_config}|$colon_seen$newline_seen$control_seen|$(( _git_auto_candidate_match > 0 ))"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal '0|0|0|0|111|1' "$output"
}
test_case 'Git auto-refresh transports hostile paths exactly with fd9 tracing enabled' \
  _test_git_auto_refresh_hostile_paths

_test_git_auto_refresh_untracked_inline_reader() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home" "$TEST_TMP_DIR/parent" || return
  print -r -- 'untracked body' >| "$TEST_TMP_DIR/parent/new file" || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    local _GIT_REVIEW_WORKER_DIR=owned
    local absolute="$2/parent/new file"
    absolute=${absolute:A}
    _git_review_untracked_capture "$absolute"
    local result=$?
    local -i cwd_ok=0 data_ok=0
    [[ $PWD == "${absolute:h}" ]] && cwd_ok=1
    [[ $_GIT_REVIEW_DATA == *"+untracked body"* ]] && data_ok=1
    print -r -- "$result|$cwd_ok|$data_ok"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal '0|1|1' "$output"
}
test_case 'Git automatic untracked preview runs inside its owned worker' \
  _test_git_auto_refresh_untracked_inline_reader

_test_git_auto_refresh_starts_paused() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.git-review"
    ZSH_GIT_REVIEW_AUTO_REFRESH=0
    _zle_picker_capture() { shift 3; "$@"; }
    _git_review_changes_capture() { return 2; }
    _zle_picker_loop() {
      print -r -- "$_ZLE_PICKER_AUTO_REFRESH|$_git_auto_failed|$_ZLE_PICKER_BROWSE_LABEL"
      return 1
    }
    _git_review_view /fixture working
    [[ $? == 1 ]] || exit 1
    print complete
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" '0|0|auto off · initial capture failed · snapshot unavailable'
}
test_case 'Git Working changes honors start-paused even after initial capture failure' \
  _test_git_auto_refresh_starts_paused
