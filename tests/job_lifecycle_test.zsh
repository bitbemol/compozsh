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
    zmodload zsh/parameter
    zmodload zsh/zpty
    zmodload zsh/zselect
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
    local chunk="" trace=""
    zpty -b cleanup _cleanup_driver || exit 1
    local pfd=$REPLY
    {
      while zselect -r $pfd -t 300; do
        while zpty -r cleanup chunk; do trace+=$chunk; done
        [[ $trace == *VERIFIED* || $trace == *BAD-* ]] && break
      done
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
    zmodload zsh/parameter
    zmodload zsh/zpty
    zmodload zsh/zselect
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
        _git_syntax_reap_child 99999999 || { print BAD-ABSENT; return 8; }
        _git_syntax_session_stop
      } always {
        _git_syntax_session_stop
      }
      print VERIFIED
    }
    local chunk="" trace=""
    zpty -b finished _finished_driver || exit 1
    local pfd=$REPLY
    {
      while zselect -r $pfd -t 300; do
        while zpty -r finished chunk; do trace+=$chunk; done
        [[ $trace == *VERIFIED* || $trace == *BAD-* ]] && break
      done
      [[ $trace == *VERIFIED* && $trace != *BAD-* ]] || { print -u2 -r -- "$trace"; exit 2; }
    } always {
      zpty -d finished
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'job lifecycle syntax cleanup handles completed and absent children and restores enabled options' _test_syntax_finished_job_cleanup
