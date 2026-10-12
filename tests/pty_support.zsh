# Deadline-bounded waits for tests that drive a terminal through zsh/zpty.
# Source this in the shell that owns the session; it loads zsh/zpty,
# zsh/zselect and zsh/datetime. Sessions start nonblocking, so no read waits
# for a line, and every wait ends by an absolute deadline: a marker that never
# arrives or a command that never stops painting fails instead of hanging the
# suite, silence alone never fails, and a finished command fails at once after
# its last output and events are read.
# While a session is live, never run a command substitution or other subshell
# in its owner shell: zpty hangs up the session when that subshell exits.

zmodload zsh/zpty zsh/zselect zsh/datetime || return
typeset -gA TEST_PTY_FDS=()
typeset -g TEST_PTY_OUTPUT=''
typeset -ga TEST_PTY_EVENTS=()

# Start <session> nonblocking; REPLY is its terminal descriptor.
# Usage: test_pty_start <session> <command> [argument...]
test_pty_start() {
  # No emulate or locals: the command inherits its caller's options and scope.
  (( $# >= 2 )) || {
    print -u2 -r -- 'usage: test_pty_start <session> <command> [argument...]'
    return 2
  }
  zpty -b "$@" || return
  TEST_PTY_FDS[$1]=$REPLY
}

# Wait until <wanted> arrives from a session started by test_pty_start.
# Usage: test_pty_expect [-p|-g] [-s stop] [-c line] <session> <event-fd|''>
#          <wanted> [seconds]
# With an event descriptor, <wanted> is a whole event line (with -p, a literal
# prefix, and an empty prefix takes the next event; with -g, an extended glob,
# where a bare | means alternation) and REPLY is that event; queued events are
# read in order, and a BAD-* event, or one matching the extended glob <stop>,
# fails at once. With '', <wanted> is literal text within one line of
# terminal output, ending in output this call reads (-c gives the start of the
# line the caller already read), and REPLY is that line as read so far; an
# empty <wanted> waits for the command to finish. Each call leaves exactly
# what it consumed in TEST_PTY_OUTPUT (terminal output) and TEST_PTY_EVENTS
# (event lines), so callers keep their own traces. A failure (the deadline,
# 10 s by default; a stop event; a finished command) prints a diagnostic and
# returns 1; misuse returns 2.
test_pty_expect() {
  emulate -L zsh
  # Terminal output is bytes: lengths and offsets below count bytes.
  setopt EXTENDED_GLOB NO_MULTIBYTE
  local -i misuse=0 pty_status=0 wait=0 from=0
  local match=exact stop='' context=''
  while [[ $1 == -[pgsc] ]]; do
    case $1 in
      (-p) match=prefix; shift ;;
      (-g) match=glob; shift ;;
      (-s) (( $# >= 2 )) || break; stop=$2; shift 2 ;;
      (*) (( $# >= 2 )) || break; context=$2; shift 2 ;;
    esac
  done
  local session=$1 event_fd=$2 wanted=$3 limit=${4:-10}
  local pty_fd=${TEST_PTY_FDS[$session]-} chunk='' line=${context##*$'\n'} event=''
  local reason='deadline passed'
  local -F deadline=0 slept_at=0
  REPLY='' TEST_PTY_OUTPUT='' TEST_PTY_EVENTS=()
  (( $# >= 3 && $# <= 4 )) || misuse=1
  [[ $pty_fd == <-> && $event_fd == (|<->) && $limit == <->(|.<->) ]] || misuse=1
  if [[ -n $event_fd ]]; then
    [[ ( -n $wanted || $match == prefix ) && -z $context ]] || misuse=1
  else
    [[ $match == exact && -z $stop ]] || misuse=1
  fi
  if (( misuse )); then
    print -u2 -r -- 'usage: test_pty_expect [-p|-g] [-s stop] [-c line]' \
      '<session from test_pty_start> <event-fd|""> <wanted> [seconds]'
    return 2
  fi
  (( deadline = EPOCHREALTIME + limit ))
  while :; do
    until zpty -r $session chunk; (( pty_status = $? )); do
      TEST_PTY_OUTPUT+=$chunk
      [[ -z $event_fd && -n $wanted ]] || continue
      # Only an occurrence that ends in this chunk is new.
      from=$(( ${#line} - ${#wanted} + 2 ))
      (( from >= 1 )) || from=1
      line+=$chunk
      if [[ ${line[from,-1]} == *"$wanted"* ]]; then
        REPLY=$line
        return 0
      fi
      [[ $line == *$'\n' ]] && line=''
    done
    if [[ -n $event_fd ]]; then
      while IFS= builtin read -r -t 0 -u $event_fd event; do
        TEST_PTY_EVENTS+=("$event")
        if [[ $event == "$wanted" || ( $match == prefix && $event == "$wanted"* ) ||
              ( $match == glob && $event == ${~wanted} ) ]]; then
          REPLY=$event
          return 0
        fi
        if [[ $event == BAD-* || ( -n $stop && $event == ${~stop} ) ]]; then
          reason="received $event"
          break 2
        fi
      done
    fi
    if (( pty_status == 2 )); then
      [[ -z $event_fd && -z $wanted ]] && return 0
      reason='command finished'
      break
    fi
    # Sleep in short slices: zselect restarts its whole timeout after a signal.
    (( wait = (deadline - EPOCHREALTIME) * 100 + 1 ))
    (( wait > 0 )) || break
    (( wait <= 50 )) || wait=50
    (( slept_at = EPOCHREALTIME ))
    zselect -r $pty_fd ${event_fd:+$event_fd} -t $wait && continue
    # A timeout lasts its whole slice; an earlier failure is an error.
    (( EPOCHREALTIME - slept_at + 0.05 >= wait / 100.0 )) || { reason='zselect failed'; break; }
  done
  print -u2 -r -- "test_pty_expect: $session: $reason while waiting for ${(qqq)wanted};" \
    "${event:+last event ${(qqq)event}; }output read: ${(V)TEST_PTY_OUTPUT[-800,-1]}"
  return 1
}
