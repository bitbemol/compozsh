# Job-table entries can outlive their processes until Zsh reports completion.
_test_prompt_jobs_live_states() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    builtin cd "$HOME"
    _prompt_git() { :; }
    _prompt_project_context() { :; }
    : ${#jobstates}
    () {
    # Shadow the read-only parameter with native documented state strings.
    local -h -A jobstates=(1 done:+:101=killed 2 done:-:102=done)
    _prompt_update
    [[ -z $_PROMPT_JOBS_TEXT && ${#jobstates} == 2 ]] || {
      print -u2 "completed jobs counted or job records consumed"; exit 1
    }
    jobstates[3]=running::103=running:104=done
    _prompt_update
    [[ $_PROMPT_JOBS_TEXT == "1 job" && ${#jobstates} == 3 ]] || exit 2
    jobstates[4]=suspended::105=suspended
    _prompt_update
    [[ $_PROMPT_JOBS_TEXT == "2 jobs" && ${#jobstates} == 4 ]] || exit 3
    unset "jobstates[3]" "jobstates[4]"
    _prompt_update
    [[ -z $_PROMPT_JOBS_TEXT && ${#jobstates} == 2 ]] || exit 4
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'job lifecycle prompt counts running and suspended jobs without consuming completed records' _test_prompt_jobs_live_states

_test_syntax_job_cleanup() {
  test_make_temp_dir || return
  command mkfifo "$TEST_TMP_DIR/home-gate" || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-syntax"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_job_reap"
    zmodload zsh/parameter
    source "$1/tests/pty_support.zsh" || exit 3
    exec {gate_fd}<> "$2/home-gate"
    _cleanup_driver() {
      unsetopt MONITOR NOTIFY BG_NICE
      local owned=0 user_live=0 user_done=0 user_stopped=0 number state retained="" directory="" stopped=""
      local -i attempt=0
      {
        _git_syntax_session_start || return 1
        owned=$_git_syntax_session_pid directory=$_git_syntax_session_dir
        (IFS= read -r -u $gate_fd) &
        user_live=$!
        (IFS= read -r -u $gate_fd) &
        user_stopped=$!
        kill -STOP $user_stopped
        for (( attempt=0; attempt<100 && ! ${#stopped}; ++attempt )); do
          for number in ${(k)jobstates}; do
            [[ $jobstates[$number] == suspended:*":$user_stopped="* ]] && stopped=$number
          done
          [[ -n $stopped ]] || zselect -t 1
        done
        [[ -n $stopped ]] || { print BAD-STOP-FIXTURE; return 10; }
        (IFS= read -r -u $gate_fd) &
        user_done=$!
        kill -KILL $user_done
        wait $user_done 2>/dev/null
        for number in ${(k)jobstates}; do
          state=$jobstates[$number]
          [[ $state == done:*":$user_done="* ]] && retained=$number
        done
        [[ -n $retained ]] || { print BAD-FIXTURE; return 2; }
        _git_syntax_session_stop
        [[ $options[monitor] == off && $options[notify] == off ]] || { print BAD-OPTIONS; return 3; }
        for state in "${(@v)jobstates}"; do
          [[ $state != *":$owned="* ]] || { print BAD-STALE-HELPER; return 4; }
        done
        kill -0 $owned 2>/dev/null && { print BAD-LIVE-HELPER; return 5; }
        kill -0 $user_live 2>/dev/null || { print BAD-USER-LIVE; return 6; }
        [[ ${jobstates[$stopped]:-} == suspended:*":$user_stopped="* ]] || { print BAD-USER-STOPPED; return 11; }
        [[ ${jobstates[$retained]:-} == done:*":$user_done="* ]] || { print BAD-USER-NOTICE; return 7; }
        [[ ! -e $directory ]] || { print BAD-FIFOS; return 8; }
        _git_syntax_session_stop
        [[ ${jobstates[$retained]:-} == done:*":$user_done="* ]] || { print BAD-REPEAT; return 9; }
      } always {
        _git_syntax_session_stop
        (( user_live > 0 )) && kill -KILL $user_live 2>/dev/null
        (( user_stopped > 0 )) && kill -KILL $user_stopped 2>/dev/null
        (( user_live > 0 )) && wait $user_live 2>/dev/null
        (( user_stopped > 0 )) && wait $user_stopped 2>/dev/null
      }
      print VERIFIED
    }
    local trace=""
    test_pty_start cleanup _cleanup_driver || exit 1
    {
      test_pty_expect cleanup "" VERIFIED 30
      trace=$TEST_PTY_OUTPUT
      [[ $trace == *VERIFIED* && $trace != *BAD-* ]] || { print -u2 -r -- "$trace"; exit 2; }
    } always {
      zpty -d cleanup
      exec {gate_fd}>&-
    }
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR"
}
test_case 'job lifecycle syntax cleanup removes its record while retaining live jobs and prior completion notices' _test_syntax_job_cleanup

_test_syntax_finished_job_cleanup() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-syntax"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_job_reap"
    zmodload zsh/parameter
    source "$1/tests/pty_support.zsh" || exit 3
    _finished_driver() {
      unsetopt MONITOR NOTIFY BG_NICE
      local owned=0 state="" found=0
      {
        _git_syntax_session_start || return 1
        owned=$_git_syntax_session_pid
        kill -KILL $owned
        wait $owned 2>/dev/null
        for state in "${(@v)jobstates}"; do
          [[ $state == done:*":$owned="* ]] && found=1
        done
        (( found )) || { print BAD-FIXTURE; return 2; }
        _git_syntax_session_stop
        (( ${#jobstates} == 0 )) || { print BAD-DONE; return 3; }
        setopt MONITOR NOTIFY
        _git_syntax_session_start || return 4
        owned=$_git_syntax_session_pid
        _git_syntax_session_stop
        [[ $options[monitor] == on && $options[notify] == on ]] || { print BAD-OPTIONS; return 5; }
        kill -0 $owned 2>/dev/null && { print BAD-LIVE; return 6; }
        (( ${#jobstates} == 0 )) || { print BAD-RECORD; return 7; }
        _compozsh_job_reap 99999999 || { print BAD-ABSENT; return 8; }
        _git_syntax_session_stop
      } always {
        _git_syntax_session_stop
      }
      print VERIFIED
    }
    local trace=""
    test_pty_start finished _finished_driver || exit 1
    {
      test_pty_expect finished "" VERIFIED 30
      trace=$TEST_PTY_OUTPUT
      [[ $trace == *VERIFIED* && $trace != *BAD-* ]] || { print -u2 -r -- "$trace"; exit 2; }
    } always {
      zpty -d finished
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'job lifecycle syntax cleanup handles completed and absent children and restores enabled options' _test_syntax_finished_job_cleanup

_test_git_review_auto_job_cleanup() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_{capture_bounded,job_reap}(N.); do source "$git_support_component"; done
    zmodload zsh/parameter zsh/system || exit 1
    source "$1/tests/pty_support.zsh" || exit 3
    export TMPDIR=$HOME
    command mkdir -p "$HOME/repo" && builtin cd "$HOME/repo" || exit 1
    git init -qb main && git config user.name Fixture &&
      git config user.email fixture@example.invalid && git config commit.gpgsign false || exit 1
    print -r -- before > tracked && git add tracked && git commit -qm fixture || exit 1
    print -r -- after > tracked
    command mkfifo "$HOME/events" "$HOME/provider-gate" || exit 1
    exec {event_fd}<> "$HOME/events" {gate_fd}<> "$HOME/provider-gate"
    # The first check reads the real repository. The second blocks only its
    # owned worker provider, so screen exit must terminate an in-flight check.
    local -i gated=0
    functions[_lifecycle_original_git]=$functions[_git_review_git]
    _git_review_git() {
      if (( gated && ${_GIT_REVIEW_WORKER_EXEC:-0} )); then
        print -r -- $sysparams[pid] >| "$HOME/provider-pid"
        print -r -- ready >| "$HOME/events"
        IFS= read -r blocked < "$HOME/provider-gate"
        exit 1
      fi
      _lifecycle_original_git "$@"
    }
    _auto_driver() {
      unsetopt MONITOR NOTIFY BG_NICE
      local root=$HOME/repo context=3 number="" state="" retained="" event=""
      local -i _ZLE_PICKER_SELECTED=0 _git_auto_session_fd=-1 _git_auto_session_pid=0
      local -i _git_auto_generation=0 user_done=0 worker=0 provider=0 attempt=0 poll_result=1
      local -F _git_auto_started_at=0 _git_auto_deadline_at=0 _ZLE_PICKER_DEADLINE_AT=0
      local _git_auto_session_dir="" _git_auto_session_fifo="" _git_auto_session_buffer=""
      local _git_auto_request_name="" _git_auto_request_kind="" _git_auto_request_context=""
      local -a _ZLE_PICKER_RESULTS=()
      {
        sleep 30 &
        user_done=$!
        kill -KILL $user_done
        wait $user_done 2>/dev/null
        # Read the table here: a command substitution sees an empty one.
        for number in ${(k)jobstates}; do
          [[ $jobstates[$number] == done:*":$user_done="* ]] && retained=$number
        done
        [[ -n $retained ]] || { print BAD-FIXTURE; return 2; }
        _git_review_auto_launch || { print BAD-LAUNCH; return 3; }
        worker=$_git_auto_session_pid
        for (( attempt=0; attempt<300; ++attempt )); do
          poll_result=0
          _git_review_auto_poll || poll_result=$?
          (( poll_result == 1 )) || break
          zselect -r $_git_auto_session_fd -t 10 2>/dev/null
        done
        (( poll_result == 0 && ${_git_auto_candidate_ready:-0} )) || { print BAD-POLL; return 4; }
        [[ ${jobstates[$retained]:-} == done:*":$user_done="* ]] || { print BAD-USER-NOTICE-CHECK; return 5; }
        for state in "${(@v)jobstates}"; do
          [[ $state != *":$worker="* ]] || { print BAD-STALE-CHECK-WORKER; return 6; }
        done
        gated=1
        _git_review_auto_launch || { print BAD-RELAUNCH; return 7; }
        worker=$_git_auto_session_pid
        IFS= read -r -t 10 -u $event_fd event && [[ $event == ready ]] || { print BAD-READY; return 8; }
        provider=$(<"$HOME/provider-pid")
        _git_review_auto_session_stop
        [[ $options[monitor] == off && $options[notify] == off ]] || { print BAD-OPTIONS; return 9; }
        [[ ${jobstates[$retained]:-} == done:*":$user_done="* ]] || { print BAD-USER-NOTICE-STOP; return 10; }
        for state in "${(@v)jobstates}"; do
          [[ $state != *":$worker="* ]] || { print BAD-STALE-STOP-WORKER; return 11; }
        done
        kill -0 $worker 2>/dev/null && { print BAD-LIVE-WORKER; return 12; }
        kill -0 $provider 2>/dev/null && { print BAD-LIVE-PROVIDER; return 13; }
      } always {
        if (( worker > 1 )) && kill -0 $worker 2>/dev/null; then
          kill -KILL $worker 2>/dev/null
          wait $worker 2>/dev/null
        fi
        (( provider > 1 )) && kill -KILL $provider 2>/dev/null
        _git_auto_session_pid=0
        _git_review_auto_session_stop
      }
      print VERIFIED
    }
    local trace=""
    test_pty_start auto _auto_driver || exit 1
    {
      test_pty_expect auto "" VERIFIED 30
      trace=$TEST_PTY_OUTPUT
      [[ $trace == *VERIFIED* && $trace != *BAD-* ]] || { print -u2 -r -- "$trace"; exit 2; }
    } always {
      zpty -d auto
      exec {event_fd}>&- {gate_fd}>&-
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'job lifecycle Git review automatic refresh keeps unrelated completion records and retires its own' \
  _test_git_review_auto_job_cleanup

# Discovery reaps its supervisor under MONITOR; device consoles, observers and
# drainers are often reaped by native handling first, and a resumed console
# can cache its stop status ahead of the final one. All keep NOTIFY off.
_test_xcode_job_reaping() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_job_reap"
    zmodload zsh/parameter || exit 1
    source "$1/tests/pty_support.zsh" || exit 3
    _reap_settle() {
      local pid=$1 wanted=$2 state=""
      local -i attempt=0
      for (( attempt=0; attempt<300; ++attempt )); do
        for state in "${(@v)jobstates}"; do
          [[ $state == ${~wanted}:*":$pid="* ]] && return 0
        done
        zselect -t 1
      done
      return 1
    }
    _reap_driver() {
      local mode=$1 number="" state="" retained="" before="" expected=137
      local -i owned=0 user_done=0
      {
        if [[ $mode == discovery ]]; then
          setopt MONITOR
        else
          unsetopt MONITOR
        fi
        unsetopt BG_NICE NOTIFY
        { /bin/sleep 30 & owned=$! } 2>/dev/null
        { /bin/sleep 30 & user_done=$! } 2>/dev/null
        kill -KILL $user_done
        # Never wait here: the fixture itself must not scan the job table.
        _reap_settle $user_done done || { print BAD-FIXTURE; return 2; }
        for number in ${(k)jobstates}; do
          [[ $jobstates[$number] == done:*":$user_done="* ]] && retained=$number
        done
        case $mode in
          (discovery)
            kill -KILL $owned ;;
          (reaped)
            kill -KILL $owned
            _reap_settle $owned done || { print BAD-OWNED-FIXTURE; return 3; } ;;
          (stopped)
            expected=143
            kill -STOP $owned
            _reap_settle $owned suspended || { print BAD-STOP-FIXTURE; return 3; }
            kill -TERM $owned
            kill -CONT $owned
            _reap_settle $owned done || { print BAD-OWNED-FIXTURE; return 3; } ;;
        esac
        before="$options[monitor]:$options[notify]"
        _xcode_run_wait_child $owned
        [[ $REPLY == $expected ]] || { print -r -- "BAD-STATUS:$REPLY"; return 4; }
        [[ "$options[monitor]:$options[notify]" == $before ]] || { print BAD-OPTIONS; return 5; }
        [[ ${jobstates[$retained]:-} == done:*":$user_done="* ]] || { print BAD-USER-NOTICE; return 6; }
        for state in "${(@v)jobstates}"; do
          [[ $state != *":$owned="* ]] || { print BAD-STALE-OWNED; return 7; }
        done
        # A repeated reap finds no owned job: no status, no sweep.
        _xcode_run_wait_child $owned
        [[ $REPLY == 127 && ${jobstates[$retained]:-} == done:*":$user_done="* ]] ||
          { print -r -- "BAD-REPEAT:$REPLY"; return 8; }
        print -r -- "VERIFIED-$mode"
      } always {
        (( owned > 0 )) && kill -KILL $owned 2>/dev/null
      }
    }
    local mode="" trace=""
    for mode in discovery reaped stopped; do
      trace=""
      test_pty_start reap _reap_driver $mode || exit 1
      {
        test_pty_expect reap "" VERIFIED- 30
        trace=$TEST_PTY_OUTPUT
        [[ $trace == *VERIFIED-$mode* && $trace != *BAD-* &&
           $trace != *(done|killed|terminated|suspended)* ]] || {
          print -u2 -r -- "$mode: ${(V)trace}"; exit 2
        }
      } always {
        zpty -d reap
      }
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'job lifecycle Xcode reaping retires only its own job record and keeps unrelated completion notices' \
  _test_xcode_job_reaping
