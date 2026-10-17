# Synchronous Git syntax capture for tests only, sourced after
# .zsh.addons/.zsh.git-syntax. It drives the shipped request/poll lifecycle to
# completion; interactive Git review never blocks on it and polls instead.
_git_syntax_session_capture() {
  emulate -L zsh
  zmodload zsh/zselect || return 1
  local -i request_id=0 result=0
  _git_syntax_session_start || return 1
  while (( !_git_syntax_session_ready )); do
    _git_syntax_session_poll
    result=$?
    case $result in
      (2) (( _git_syntax_session_ready )) && break ;;
      (3) return 1 ;;
    esac
    zselect -r $_git_syntax_session_fd -t 1 2>/dev/null
  done
  _git_syntax_session_request "$1" || return 1
  request_id=$REPLY
  while true; do
    _git_syntax_session_poll
    result=$?
    case $result in
      (0) [[ $REPLY == $request_id ]] && return 0; return 1 ;;
      (1|2) zselect -r $_git_syntax_session_fd -t 1 2>/dev/null ;;
      (*) return 1 ;;
    esac
  done
}

# One complete capture in a private resident session that never outlives it.
_git_syntax_capture() {
  emulate -L zsh
  local _git_syntax_session_dir='' _git_syntax_session_request_fifo=''
  local _git_syntax_session_response_fifo='' _git_syntax_session_buffer=''
  local -i _git_syntax_session_fd=-1 _git_syntax_session_pid=0
  local -i _git_syntax_session_ready=0 _git_syntax_session_generation=0
  local -i _git_syntax_session_active_id=0
  local -F _git_syntax_session_deadline=0
  local -i result=0
  _GIT_SYNTAX_DATA=''
  _git_syntax_prepare_input "$@"
  [[ -n $_GIT_SYNTAX_INPUT ]] || return 0
  _GIT_SYNTAX_NOTE='plain syntax · unavailable or time limit'
  {
    _git_syntax_session_capture "$_GIT_SYNTAX_INPUT"
    result=$?
  } always {
    _git_syntax_session_stop
  }
  (( result == 0 )) || { _GIT_SYNTAX_DATA=''; return 0; }
  _GIT_SYNTAX_NOTE=$_GIT_SYNTAX_SUCCESS_NOTE
  return 0
}
