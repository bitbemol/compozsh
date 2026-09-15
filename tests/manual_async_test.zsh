_test_manual_async_frame_validation() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.manual"
    (( ${+functions[_manual_async_consume]} && ${+functions[_manual_async_publish]} )) || {
      print -u2 "missing bounded asynchronous frame validation and publication"; exit 1
    }
    local expected=$'\''.COMPOZSH-MANUAL-RESULT-1\t7\t2\nls\tls(1)\tRead café 界 literally\nother\torigin(1)\t$(touch unsafe) %F{red}\nEND\t7\n'\''
    local variant="" frame="" chunk=""
    for variant in valid truncated duplicate count generation control nul oversized trailing duplicate_end blank_record; do
      _manual_async_candidate_clear
      _MANUAL_ASYNC_GENERATION=7 _MANUAL_ASYNC_STATE=running
      _manual_async_identity || exit 2
      _MANUAL_ASYNC_IDENTITY=$REPLY
      _MANUAL_SUMMARIES=(sentinel retained) _MANUAL_SOURCES=(sentinel sentinel)
      _MANUAL_SUMMARIES_READY=0
      frame=$expected
      case $variant in
        truncated) frame=${frame%$'\''END\t7\n'\''} ;;
        duplicate) frame=${frame/other$'\''\t'\''/ls$'\''\t'\''} ;;
        count) frame=${frame/$'\''\t2\n'\''/$'\''\t1+1\n'\''} ;;
        generation) frame=${frame/$'\''\t7\t'\''/$'\''\t6\t'\''} ;;
        control) frame=${frame/Read café 界 literally/$'\''Bad\e[31m'\''} ;;
        nul) frame=${frame/Read café 界 literally/$'\''Bad\0text'\''} ;;
        oversized) frame=${frame/Read café 界 literally/${(l:241::x:)}} ;;
        trailing) frame+=extra ;;
        duplicate_end) frame+=$'\''END\t7\n'\'' ;;
        blank_record) frame=${frame/other/$'\''\nother'\''} ;;
      esac
      # Deliberately split inside UTF-8 bytes and every protocol field.
      unsetopt MULTIBYTE
      local -i result=0
      while [[ -n $frame ]]; do
        chunk=${frame[1,3]} frame=${frame[4,-1]}
        _manual_async_consume "$chunk" || { result=1; break; }
        if [[ -n $frame ]]; then
          [[ ${_MANUAL_SUMMARIES[sentinel]} == retained && ! $_MANUAL_SUMMARIES_READY == 1 ]] || exit 3
          _manual_summary_lookup sentinel && [[ $REPLY == retained ]] || exit 3
          _manual_summary_lookup ls && exit 3
        fi
      done
      setopt MULTIBYTE
      if [[ $variant == valid ]]; then
        (( !result )) && _manual_async_publish || exit 4
        _manual_summary_lookup ls && [[ $REPLY == "Read café 界 literally" ]] || exit 5
        _manual_summary_lookup other && [[ $reply[2] == "origin(1)" &&
           $_MANUAL_ASYNC_COUNT == 2 && $_MANUAL_SUMMARIES_READY == 1 ]] || exit 5
        _manual_summary_lookup sentinel && exit 5
      else
        if (( !result )) && _manual_async_publish; then
          print -u2 -- "published invalid asynchronous candidate: $variant"; exit 6
        fi
        [[ ${_MANUAL_SUMMARIES[sentinel]} == retained && ${#_MANUAL_SUMMARIES} == 1 ]] || exit 7
      fi
    done
    _manual_async_candidate_clear
    _MANUAL_ASYNC_STATE=running
    _MANUAL_SUMMARIES=(sentinel retained) _MANUAL_SUMMARIES_READY=0
    _manual_async_consume "$expected" || exit 8
    _manual_async_consume extra && exit 9
    _manual_async_publish && { print -u2 "published a rejected completed candidate"; exit 10; }
    return 0
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async validates split literal frames and never publishes partial malformed or stale results' \
  _test_manual_async_frame_validation

_test_manual_async_identity_invalidation() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    (( ${+functions[_manual_async_identity]} )) || {
      print -u2 "missing in-memory capture identity"; exit 1
    }
    local original="" relative=""
    local MANPATH=/system/manual MANSECT=1:8 DEVELOPER_DIR=/system/developer
    _manual_async_identity || exit 2
    original=$REPLY
    builtin cd "$HOME"
    _manual_async_identity || exit 3
    [[ $REPLY == "$original" ]] || exit 4
    MANPATH=relative-manual
    _manual_async_identity || exit 5
    relative=$REPLY
    builtin cd "${HOME:h}"
    _manual_async_identity || exit 6
    [[ $REPLY != "$relative" ]] || exit 7
    _MANUAL_ASYNC_GENERATION=9 _MANUAL_ASYNC_STATE=running
    _manual_async_identity
    _MANUAL_ASYNC_IDENTITY=$REPLY
    _manual_async_candidate_clear
    _manual_async_consume $'\''.COMPOZSH-MANUAL-RESULT-1\t9\t1\ndemo\tdemo(1)\tOld selection\nEND\t9\n'\'' || exit 8
    DEVELOPER_DIR=/changed/developer
    _manual_async_publish && { print -u2 "accepted an obsolete developer selection"; exit 9; }
    (( ! _MANUAL_SUMMARIES_READY )) || exit 10
    return 0
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async identities follow discovery selectors and relative roots and reject obsolete completion' \
  _test_manual_async_identity_invalidation

_test_manual_async_background_lifecycle() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    (( ${+functions[_manual_prompt_request]} )) || {
      print -u2 "missing nonblocking prompt capture lifecycle"; exit 1
    }
    zmodload zsh/zselect
    command mkfifo "$HOME/events" "$HOME/release"
    local -i10 event_fd=-1 release_fd=-1
    exec {event_fd}<> "$HOME/events"
    exec {release_fd}<> "$HOME/release"
    local event="" old_generation=0 old_fd=-1
    _manual_prompt_capture() {
      local gate=""
      print -r -u $event_fd -- STARTED
      IFS= read -r -t 5 -u $release_fd gate || return 1
      _MANUAL_SUMMARIES=(demo "Collected in background")
      _MANUAL_SOURCES=(demo "demo(1)")
      _MANUAL_SUMMARIES_READY=1
    }
    _manual_prompt_request || exit 2
    [[ $_MANUAL_ASYNC_STATE == running && $_MANUAL_SUMMARIES_READY == 0 ]] || exit 3
    IFS= read -r -t 5 -u $event_fd event && [[ $event == STARTED ]] || exit 4
    old_generation=$_MANUAL_ASYNC_GENERATION old_fd=$_MANUAL_ASYNC_FD
    _manual_prompt_request || exit 5
    (( _MANUAL_ASYNC_GENERATION == old_generation )) || exit 6
    print -r -u $release_fd -- GO
    while [[ $_MANUAL_ASYNC_STATE == running ]]; do
      zselect -r $_MANUAL_ASYNC_FD $_MANUAL_ASYNC_CONTROL_FD -t 500 || exit 7
      _manual_async_read $_MANUAL_ASYNC_FD
      _manual_async_control $_MANUAL_ASYNC_CONTROL_FD
    done
    _manual_summary_lookup demo || exit 8
    [[ $_MANUAL_ASYNC_STATE == ready && $_MANUAL_SUMMARIES_READY == 1 &&
       $REPLY == "Collected in background" ]] || exit 8
    (( _MANUAL_ASYNC_FD < 0 && _MANUAL_ASYNC_CONTROL_FD < 0 )) || exit 9
    zle -F -L $old_fd >/dev/null && exit 10
    _manual_summary_reset
    _manual_prompt_request || exit 11
    IFS= read -r -t 5 -u $event_fd event && [[ $event == STARTED ]] || exit 12
    old_generation=$_MANUAL_ASYNC_GENERATION
    _manual_summary_reset
    [[ $_MANUAL_ASYNC_STATE == idle && $_MANUAL_SUMMARIES_READY == 0 &&
       $_MANUAL_ASYNC_GENERATION -gt $old_generation && -z $_MANUAL_ASYNC_NAME ]] || exit 13
    (( _MANUAL_ASYNC_FD < 0 && _MANUAL_ASYNC_CONTROL_FD < 0 )) || exit 14
    exec {event_fd}>&-
    exec {release_fd}>&-
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async returns before a blocked provider merges once and refresh cancels owned descriptors' \
  _test_manual_async_background_lifecycle

_test_manual_async_control_fragments() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _MANUAL_ASYNC_STATE=running _MANUAL_ASYNC_CONTROL_FD=42
    _MANUAL_ASYNC_CONTROL_BUFFER="" _MANUAL_ASYNC_NAME=fixture
    local -a pieces=(D O $'\''NE\r\n'\'')
    local piece=""
    local -i reads=0 closed=0
    zpty() { message=$pieces[1]; shift pieces; return 0; }
    _manual_async_read() { (( ++reads )); }
    _manual_async_close() { (( ++closed )); }
    for piece in 1 2; do
      _manual_async_control 42
      [[ $_MANUAL_ASYNC_STATE == running && $reads == 0 && $closed == 0 ]] || {
        print -u2 "partial control delivery incorrectly failed or read results"; exit 1
      }
    done
    _manual_async_control 42
    (( reads == 1 && !closed )) || exit 2
    pieces=($'\''FAILED\r\n'\'')
    _manual_async_control 42
    [[ $_MANUAL_ASYNC_STATE == failed && $closed == 1 ]] || exit 3
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async tolerates fragmented control delivery and rejects explicit worker failure' \
  _test_manual_async_control_fragments

_test_manual_async_editor_delivery() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" "$HOME/release"
    local -i10 event_fd=-1 release_fd=-1 pfd=-1
    exec {event_fd}<> "$HOME/events"
    exec {release_fd}<> "$HOME/release"
    local event="" chunk="" trace="" device=""
    _expect() {
      while zselect -r $event_fd $pfd -t 1000; do
        while zpty -r editor chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          [[ $event == "$1"* ]] && return 0
        fi
      done
      local diagnostic="$event ${(V)trace[-1500,-1]}"
      diagnostic=${diagnostic//${HOME}/\$\{TEST_HOME\}}
      diagnostic=${diagnostic//${COMPOZSH_TEST_REPO}/\$\{REPO_ROOT\}}
      [[ -z ${USERNAME:-} ]] || diagnostic=${diagnostic//${USERNAME}/example-user}
      [[ -z ${HOST:-} ]] || diagnostic=${diagnostic//${HOST}/example-host}
      [[ -z ${HOST%%.*} ]] || diagnostic=${diagnostic//${HOST%%.*}/example-host}
      print -u2 -r -- "Missing $1: $diagnostic"
      return 1
    }
    export COMPOZSH_TEST_REPO=$1
    zpty -b editor /bin/zsh -dfi || exit 1
    pfd=$REPLY
    {
      zpty -w editor "source ${(q)1}/tests/fixtures/manual-async-editor.zsh ${(q)1}"
      _expect READY || exit 2
      device=${event#READY|}
      zpty -w -n editor $'\''ls -la\x02\x18\x1a'\''
      _expect "FRAME|120|ls -la|5|0|" || exit 3
      [[ $event != *"Asynchronous café description"* ]] || exit 4
      if [[ $2 == nested ]]; then
        zpty -w -n editor $'\''\x18\x06'\''
        _expect NESTED || exit 9
      fi
      print -r -u $release_fd GO
      # No keypress after release: delivery itself must repaint and report.
      _expect "FRAME|120|ls -la|5|1|" || exit 5
      if [[ $2 == nested ]]; then
        [[ $event != *"Asynchronous café description"* ]] || exit 10
        zpty -w -n editor $'\''\r\x18\x1a'\''
        _expect RESTORED || exit 11
        _expect "FRAME|120|ls -la|5|1|" || exit 12
      fi
      [[ $event == *"Asynchronous café description"* && $event == *"ls(1)"* ]] || exit 6
      command stty rows 18 cols 60 < "$device"
      zpty -w -n editor $'\''\x18\x1a'\''
      _expect "FRAME|60|ls -la|5|1|" || exit 7
      [[ $trace == *"Asynchronous café description"* && $trace != *"bad file descriptor"* &&
         $trace != *"widgets can only"* && $trace != *"parse error"* ]] || exit 8
      [[ $trace != *"DELIVERY CHANGED EDITOR STATE"* ]] || exit 13
      zpty -w -n editor $'\''\x15print -r -u $fixture_events -- STATUS:$?\r'\''
      _expect "STATUS:1" || exit 14
      zpty -w -n editor $'\''\x15exit\r'\''
    } always {
      zpty -d editor
    }
  ' "$TEST_REPO_ROOT" "${1:-ordinary}"
}
test_case 'manual async native ZLE delivers while typing without changing draft cursor or resize behavior' \
  _test_manual_async_editor_delivery

_test_manual_async_nested_delivery() { _test_manual_async_editor_delivery nested; }
test_case 'manual async native ZLE defers prompt painting in nested fullscreen ownership and restores the draft' \
  _test_manual_async_nested_delivery

_test_manual_async_cancellation_ownership() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    unsetopt BG_NICE
    zmodload zsh/zselect
    zmodload zsh/datetime
    command mkfifo "$HOME/events" "$HOME/release"
    local -i10 event_fd=-1 release_fd=-1 unrelated_fd=-1
    exec {event_fd}<> "$HOME/events"
    exec {release_fd}<> "$HOME/release"
    exec {unrelated_fd}<> "$HOME/events"
    _unrelated_handler() { :; }
    zle -F $unrelated_fd _unrelated_handler
    # Caller coprocess must survive starting and cancelling the owned worker.
    coproc { local line=""; while IFS= read -r line; do print -r -- "USER:$line"; done; }
    local -i user_pid=$!
    export TMPDIR=$HOME
    local jobs_before="$(jobs -l)" event="" caller_reply="" operation=""
    local -a owned=()
    _manual_prompt_capture() {
      # Native descendant ignores TERM; cancellation must include its group.
      ( trap "" TERM HUP; print -r -u $event_fd -- "CHILD:$sysparams[pid]";
        /bin/sleep 60 &
        print -r -u $event_fd -- "CHILD:$!"
        wait ) &
      wait
    }
    functions[_fixture_capture]=$functions[_manual_prompt_capture]
    for operation in refresh selectors resource preexec deadline; do
      functions[_manual_prompt_capture]=$functions[_fixture_capture]
      _MANUAL_SUMMARIES_READY=0
      _manual_prompt_request || exit 1
      owned=()
      repeat 2; do
        IFS= read -r -t 5 -u $event_fd event && [[ $event == CHILD:<-> ]] || exit 2
        owned+=("${event#CHILD:}")
      done
      case $operation in
        refresh) _manual_summary_reset ;;
        selectors) MANSECT=8; _manual_async_read $_MANUAL_ASYNC_FD ;;
        resource) source "$1/.zsh.addons/.zsh.manual" ;;
        preexec) _manual_async_preexec ;;
        deadline) _MANUAL_ASYNC_DEADLINE=0; _manual_async_read $_MANUAL_ASYNC_FD ;;
      esac
      [[ -z $_MANUAL_ASYNC_NAME && $_MANUAL_ASYNC_FD == -1 && $_MANUAL_ASYNC_CONTROL_FD == -1 ]] || exit 3
      local -F limit=$((EPOCHREALTIME+5))
      local pid="" remaining=1
      while (( remaining && EPOCHREALTIME < limit )); do
        remaining=0
        for pid in $owned; do kill -0 $pid 2>/dev/null && remaining=1; done
        (( !remaining )) || zselect -t 1
      done
      (( !remaining )) || { print -u2 -- "owned descendants survived $operation: $owned"; exit 4; }
      [[ $(jobs -l) == "$jobs_before" ]] || exit 5
      zle -F -L $unrelated_fd | /usr/bin/grep -q _unrelated_handler || exit 6
      print -p -- "$operation"
      IFS= read -r -t 5 -p caller_reply && [[ $caller_reply == "USER:$operation" ]] || exit 7
      local -a residue=("$HOME"/compozsh-manual-async.*(N))
      (( ! ${#residue} )) || exit 8
    done
    kill $user_pid
    wait $user_pid 2>/dev/null
    zle -F $unrelated_fd
    return 0
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async cancellation kills owned descendants across refresh selectors reload command and deadline without touching caller resources' \
  _test_manual_async_cancellation_ownership

_test_manual_async_deadline_owner() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    (( ${+functions[_manual_async_owner]} )) || {
      print -u2 "missing process identity keeper across worker deadline"; exit 1
    }
    zmodload zsh/zselect
    command mkfifo "$HOME/events"
    local -i10 event_fd=-1
    exec {event_fd}<> "$HOME/events"
    functions[_fixture_owner]=$functions[_manual_async_owner]
    _manual_async_owner() {
      _MANUAL_ASYNC_DEADLINE=$((EPOCHREALTIME+1))
      _fixture_owner
    }
    _manual_prompt_capture() {
      print -r -u $event_fd -- "$sysparams[pid]"
      /bin/sleep 60
    }
    local worker="" outcome=""
    _manual_prompt_request
    IFS= read -r -t 5 -u $event_fd worker || exit 2
    zselect -r $_MANUAL_ASYNC_CONTROL_FD -t 500 || exit 3
    zpty -r "$_MANUAL_ASYNC_NAME" outcome || exit 4
    [[ $outcome == $'\''FAILED\r\n'\'' ]] || exit 5
    # Deadline has stopped the worker; the native owner remains registered
    # and alive until this shell acknowledges failure and releases it.
    zpty -t "$_MANUAL_ASYNC_NAME" || exit 6
    local -F limit=$((EPOCHREALTIME+5))
    while kill -0 $worker 2>/dev/null && (( EPOCHREALTIME < limit )); do zselect -t 1; done
    kill -0 $worker 2>/dev/null && exit 7
    _manual_async_cancel
    [[ -z $_MANUAL_ASYNC_NAME ]] || exit 8
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async deadline stops capture while retaining the native owner identity until acknowledgement' \
  _test_manual_async_deadline_owner

_test_manual_async_failed_transport() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    local variant="" generation=0
    functions[_fixture_capture_worker]=$functions[_manual_async_capture_worker]
    _manual_prompt_capture() {
      _MANUAL_SUMMARIES=(demo valid) _MANUAL_SOURCES=(demo "demo(1)")
      _MANUAL_SUMMARIES_READY=1
    }
    _manual_async_capture_worker() {
      local -i _MANUAL_WORKER_CANCELLED=0
      local frame=$'\''.COMPOZSH-MANUAL-RESULT-1\t'\''"$_MANUAL_ASYNC_GENERATION"$'\''\t1\ndemo\tdemo(1)\tvalid\nEND\t'\''"$_MANUAL_ASYNC_GENERATION"$'\''\n'\''
      case $variant in
        failure) return 1 ;;
        truncated) _manual_async_write "${frame%END*}" ;;
        trailing) _manual_async_write "${frame}extra" ;;
        valid) _fixture_capture_worker ;;
      esac
    }
    for variant in failure truncated trailing valid; do
      _manual_summary_reset
      _manual_prompt_request
      generation=$_MANUAL_ASYNC_GENERATION
      while [[ $_MANUAL_ASYNC_STATE == running ]]; do
        zselect -r $_MANUAL_ASYNC_FD $_MANUAL_ASYNC_CONTROL_FD -t 500 || {
          print -u2 -- "unfinished $variant candidate was not rejected"; exit 1
        }
        _manual_async_read $_MANUAL_ASYNC_FD
        _manual_async_control $_MANUAL_ASYNC_CONTROL_FD
      done
      if [[ $variant == valid ]]; then
        _manual_summary_lookup demo && [[ $_MANUAL_ASYNC_STATE == ready && $REPLY == valid ]] || exit 2
      else
        [[ $_MANUAL_ASYNC_STATE == failed && $_MANUAL_SUMMARIES_READY == 0 && ${#_MANUAL_SUMMARIES} == 0 ]] || exit 3
        _manual_prompt_request
        [[ $_MANUAL_ASYNC_GENERATION == $generation && $_MANUAL_ASYNC_STATE == failed ]] || exit 4
      fi
    done
    _manual_summary_reset
    _manual_async_start() { return 1; }
    _manual_prompt_request
    [[ $_MANUAL_SUMMARIES_READY == 1 && ${_MANUAL_SUMMARIES[demo]} == valid && -z $_MANUAL_ASYNC_NAME ]] || exit 5
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async rejects failed truncated and trailing transports without retry loops and preserves capability fallback' \
  _test_manual_async_failed_transport

_test_manual_async_exit_cleanup() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    command mkfifo "$HOME/events"
    local -i10 event_fd=-1
    exec {event_fd}<> "$HOME/events"
    _manual_prompt_capture() {
      print -r -u $event_fd -- "$sysparams[pid]"
      /bin/sleep 60
    }
    local worker=""
    _manual_prompt_request
    IFS= read -r -t 5 -u $event_fd worker || exit 1
    print -r -- "$worker" > "$HOME/owned-pid"
    # Exercise native shell exit, not an explicit helper call.
    exit 0
  ' "$TEST_REPO_ROOT" || return
  local worker=$(<"$TEST_TMP_DIR/home/owned-pid")
  [[ $worker == <-> ]] || return 1
  zmodload zsh/zselect
  local -F limit=$(( EPOCHREALTIME + 5 ))
  while kill -0 "$worker" 2>/dev/null && (( EPOCHREALTIME < limit )); do zselect -t 1; done
  ! kill -0 "$worker" 2>/dev/null
}
test_case 'manual async shell exit terminates its in-flight capture' _test_manual_async_exit_cleanup

_test_manual_async_actual_byte_budget() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    local -i records=0 bytes=0 complete=0
    _manual_prompt_capture() {
      local name=""
      local -i index=0
      for (( index=1; index<=7000; ++index )); do
        name="${(l:240::n:)}$index"
        _MANUAL_SUMMARIES[$name]="${(l:240::d:)}"
        _MANUAL_SOURCES[$name]="${(l:245::s:)}(1)"
      done
      _MANUAL_SUMMARIES_READY=1
    }
    _manual_async_write() {
      emulate -L zsh
      local text=$1
      unsetopt MULTIBYTE
      (( bytes += ${#text} ))
      [[ $text != n* ]] || (( ++records ))
      [[ $text != END$'\''\t'\''* ]] || complete=1
      return 0
    }
    _MANUAL_ASYNC_GENERATION=1
    _manual_async_capture_worker || { print -u2 "valid catalog was refused before the 16-MiB byte limit"; exit 1; }
    (( records == 7000 && complete && bytes > 4194304 && bytes < 16777216 )) || exit 2
  ' "$TEST_REPO_ROOT"
}
test_case 'manual async accepts a complete valid catalog above four MiB within its actual byte budget' \
  _test_manual_async_actual_byte_budget

_test_manual_description_metadata() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _MANUAL_SUMMARIES=(demo "Literal description") _MANUAL_SOURCES=(demo "origin(1)")
    local -a reply=()
    _manual_summary_lookup demo || exit 1
    [[ $REPLY == "Literal description" && $reply[1] == "$REPLY" && $reply[2] == "origin(1)" ]] || {
      print -u2 "description lookup does not return its matching source"; exit 2
    }
    _manual_summary_lookup missing && exit 3
    [[ -z $REPLY && ${#reply} == 0 ]] || exit 4
  ' "$TEST_REPO_ROOT"
}
test_case 'manual description lookup returns one matching description and source without leaking a prior result' \
  _test_manual_description_metadata
