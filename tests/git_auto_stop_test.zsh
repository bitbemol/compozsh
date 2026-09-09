_test_git_auto_refresh_suspended_worker() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/bin/git" $'#!/bin/zsh -df\nprint -r -- $$ > "$HOME/provider-pid"\nprint -r -- ready > "$HOME/events"\nIFS= read -r -u 0 blocked\n' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/git" || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/system zsh/zselect zsh/datetime zsh/parameter
    unsetopt MONITOR NOTIFY BG_NICE
    export TMPDIR=$HOME
    path=("$HOME/bin" $path)
    command mkfifo "$HOME/events" "$HOME/provider-input" "$HOME/watchdog"
    exec {event_fd}<> "$HOME/events"
    exec {provider_fd}<> "$HOME/provider-input"
    exec {watchdog_fd}<> "$HOME/watchdog"
    local root=$HOME context=3 event="" state="" session="" REPLY=""
    local -i _ZLE_PICKER_SELECTED=0 _git_auto_session_fd=-1 _git_auto_session_pid=0
    local -i _git_auto_generation=0 worker=0 provider=0 watchdog=0 attempt=0 stopped=0
    local -F _git_auto_started_at=0 _git_auto_deadline_at=0
    local _git_auto_session_dir="" _git_auto_session_fifo="" _git_auto_session_buffer=""
    local _git_auto_request_name="" _git_auto_request_kind="" _git_auto_request_context=""
    local -a _ZLE_PICKER_RESULTS=()
    # Keep a real provider alive inside the real worker. Only its input is
    # synthetic; cancellation must let the worker reap this direct child.
    _git_review_prepare() { _GIT_REVIEW_CONFIG=(); return 0; }
    functions[_stop_original_git]=$functions[_git_review_git]
    _git_review_git() { _stop_original_git "$@" < "$HOME/provider-input"; }
    {
      _git_review_auto_launch || exit 1
      worker=$_git_auto_session_pid session=$_git_auto_session_dir
      IFS= read -r -t 3 -u $event_fd event || exit 2
      [[ $event == ready ]] || exit 3
      provider=$(<"$HOME/provider-pid")
      command /bin/kill -STOP $worker || exit 4
      for (( attempt=0; attempt<200; ++attempt )); do
        for state in "${jobstates[@]}"; do
          [[ $state == *":$worker=suspended"* ]] && stopped=1
        done
        (( stopped )) && break
        zselect -t 1
      done
      (( stopped )) || exit 5
      # Rescue a buggy blocking wait by resuming its exact fixture worker;
      # never kill the owner before it has a chance to reap its provider.
      {
        if ! IFS= read -r -t 3 -u $watchdog_fd event; then
          print expired > "$HOME/expired"
          kill -CONT $worker 2>/dev/null
          kill -TERM $worker 2>/dev/null
        fi
      } &
      watchdog=$!
      _git_review_auto_worker_stop
      print -r -u $watchdog_fd complete
      wait $watchdog 2>/dev/null
      watchdog=0
      [[ ! -e "$HOME/expired" ]] || {
        print -u2 "suspended worker blocked cancellation until watchdog rescue"; exit 6
      }
      kill -0 $worker 2>/dev/null && {
        print -u2 "cancel returned while suspended worker still existed"; exit 7
      }
      kill -0 $provider 2>/dev/null && {
        print -u2 "cancel left the suspended workers provider alive"; exit 8
      }
      [[ $_git_auto_session_pid == 0 && -z $_git_auto_session_buffer ]] || exit 9
      _git_review_auto_session_stop
      [[ ! -e $session && $_git_auto_session_fd == -1 ]] || exit 10
      print stopped
    } always {
      (( watchdog > 1 )) && { kill -KILL $watchdog 2>/dev/null; wait $watchdog 2>/dev/null; }
      if (( worker > 1 )) && kill -0 $worker 2>/dev/null; then
        kill -TERM $worker 2>/dev/null
        kill -CONT $worker 2>/dev/null
        wait $worker 2>/dev/null
        wait $worker 2>/dev/null
      fi
      (( provider > 1 )) && kill -0 $provider 2>/dev/null && kill -KILL $provider 2>/dev/null
      _git_auto_session_pid=0
      _git_review_auto_session_stop
      exec {event_fd}>&- {provider_fd}>&- {watchdog_fd}>&-
    }
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal stopped "$output"
}
test_case 'Git automatic cancellation resumes a suspended worker and reaps its provider' \
  _test_git_auto_refresh_suspended_worker
