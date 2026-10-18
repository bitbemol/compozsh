#!/bin/zsh -df
# Cost of building the Xcode / Logs reader document from the retained tail
# (_xcode_logs_collect, which the shared picker reruns on every Find or
# Exclude keystroke and the followed idle turn reruns when the tail changes)
# for two trees, alternating the tree order run by run. Reports each tree's
# median, min and max over runs (ms) per workload, and the candidate's median
# change.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> [runs] \
#          [locale] [workloads]
#   The tail is the 200-line bound, mixed as a chatty app writes it: 163
#   native compact records (60 Default, 51 Info, 18 Error, 17 Fault, 17
#   Debug), 27 plain lines and 10 blank lines.
#   rebuild-all   one collection with no filter that rebuilds the document
#                 (reader entry, newly followed output)
#   rebuild-view  the same with the fuzzy query `view`
#   rebuild-rv12  the same with the narrower fuzzy query `rv12`
#   unchanged     a collection whose matching text did not change, so the
#                 prepared document is kept
#   typing-change, typing-same  the closest end-to-end metric: a new
#                 `zsh -dfi` in a 100x40 PTY sources the tree's shared UI and
#                 .zsh.xcode and opens the reader over the same tail through
#                 the shared picker (capture stubbed to return the tail). It
#                 types `view`, erases it, types `12` and erases it, one key
#                 at a time, timing each key from its write until the reader
#                 painted that query's frame (an instrumented
#                 _zle_picker_show reports it). typing-change is the median
#                 over the keys that changed the match count (6 per sample),
#                 typing-same over the keys that kept it (6 per sample).
#                 Both come from one session; select either to run it.
#   workloads defaults to all of them, comma-separated. Each in-process
#   sample is a new `zsh -df` child under `env -i` with a system-only PATH,
#   the given locale (default en_US.UTF-8) and HOME, ZDOTDIR and TMPDIR in
#   this run's disposable directory. It sources the tree's .zsh.xcode and
#   matching entries, makes one untimed collection, then reports the mean of
#   20 timed collections plus the document's row count and total size, which
#   must match between trees. Run from a disposable TMPDIR.
emulate -LR zsh
setopt EXTENDED_GLOB
zmodload zsh/datetime zsh/zpty zsh/zselect || exit

# The retained tail: 200 lines, deterministic, shared by every workload.
_bench_tail() {
  local -a levels=(Df In Df Er Df In Ft Db Df In)
  local -a scopes=(com.example:network com.example:view com.example:store)
  local -i i=0
  REPLY=''
  for (( i = 1; i <= 200; ++i )); do
    if (( i % 20 == 10 )); then
      REPLY+=$'\n'
    elif (( i % 7 == 0 )); then
      REPLY+="plain stdout line $i: retry scheduled for item $(( i * 13 ))"$'\n'
    else
      REPLY+="2026-09-02 22:44:$(( 10 + i % 50 )).$(( 100 + i )) ${levels[i % 10 + 1]} Example[4242:1a2b] [${scopes[i % 3 + 1]}] Request $i finished with status $(( 200 + i % 5 )) after $(( i * 3 )) ms"$'\n'
    fi
  done
}

# One in-process sample: prints "<ms> <rows>:<bytes>" or fails with a status.
_bench_child() {
  emulate -L zsh
  local root=$1 workload=$2 query='' entry=''
  local -i i=0 result=0
  local -F started=0 elapsed=0
  source "$root/.zsh.addons/.zsh.xcode" || return 3
  for entry in "$root/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do
    source "$entry" || return 3
  done
  (( ${+functions[_xcode_logs_collect]} )) || return 3
  case $workload in
    (rebuild-all|unchanged) query='' ;;
    (rebuild-view) query=view ;;
    (rebuild-rv12) query=rv12 ;;
    (*) return 2 ;;
  esac
  _bench_tail
  local _xcode_logs_snapshot=$REPLY _xcode_logs_text='' _xcode_logs_query=''
  local _xcode_logs_notice='' _xcode_logs_severity=all _xcode_logs_exclude=''
  local _xcode_run_clipboard=/fixture/pbcopy _xcode_run_context=bench _ZLE_PICKER_EXCLUDE=''
  local -i _xcode_logs_total=0 _xcode_logs_matches=0 _xcode_logs_trimmed=0
  local -i _ZLE_PICKER_INSPECT_WIDTH=0 _ZLE_PICKER_INSPECT_OFFSET=0
  local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
  local -a _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _ZLE_PICKER_RESULT_INDEXES=()
  local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
  _xcode_logs_collect "$query" 0 || return 4
  started=$EPOCHREALTIME
  for (( i = 0; i < 20; ++i )); do
    # An emptied document forces the rebuild that new matching text causes.
    [[ $workload == unchanged ]] || _ZLE_PICKER_DOCUMENT_LINES=()
    _xcode_logs_collect "$query" 0 || result=1
  done
  elapsed=$(( EPOCHREALTIME - started ))
  (( result == 0 && ${#_ZLE_PICKER_DOCUMENT_LINES} == ${#_ZLE_PICKER_DOCUMENT_ROLES} )) || return 5
  [[ $workload == unchanged ]] && (( REPLY != 0 )) && return 5
  [[ $workload != unchanged ]] && (( REPLY != 1 )) && return 5
  printf '%.3f %d:%d\n' $(( elapsed * 1000 / 20 )) ${#_ZLE_PICKER_DOCUMENT_LINES} \
    ${#${(j:\n:)_ZLE_PICKER_DOCUMENT_LINES}}
  return 0
}

if [[ ${1:-} == --child ]]; then
  shift
  _bench_child "$@"
  exit
fi

local baseline=${1:A} candidate=${2:A} locale=${4:-en_US.UTF-8} workload_list=${5:-all}
local -a all_workloads=(rebuild-all rebuild-view rebuild-rv12 unchanged typing-change typing-same)
local -a workloads=(${(s:,:)workload_list})
[[ $workload_list == all ]] && workloads=($all_workloads)
[[ -f $baseline/.zsh.addons/.zsh.xcode && -f $candidate/.zsh.addons/.zsh.xcode &&
   ${3:-10} == <1-> && ${#workloads} -gt 0 && -z ${workloads:|all_workloads} ]] || {
  print -u2 'usage: xcode-log-collect.zsh <baseline-root> <candidate-root> [runs] [locale] [workloads]'
  exit 2
}
local self=${0:A} bench='' tree='' root='' workload='' line='' raw='' shown=''
local -i runs=${3:-10} run=0 sample_status=0 fd=0 pfd=0
local -a trees=() values=() events=()
local -A samples=() counts=()
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-xcode-logs.XXXXXXXX") && [[ -d $bench ]] || exit

# Prints "<median> <min> <max>" of the numeric arguments.
_bench_stats() {
  local -a sorted=(${(on)@})
  local -i n=${#sorted}
  local -F median=0
  if (( n % 2 )); then
    median=${sorted[n / 2 + 1]}
  else
    median=$(( (sorted[n / 2] + sorted[n / 2 + 1]) / 2.0 ))
  fi
  printf '%.2f %.2f %.2f' $median $sorted[1] $sorted[n]
}

# Drains the PTY and event FIFO once, waiting up to $1 hundredths of a second.
_bench_pump() {
  local chunk='' event=''
  zselect -r $fd $pfd -t ${1:-5} || return 1
  while zpty -r bench_logs chunk 2> /dev/null; do raw+=$chunk; done
  while IFS= read -r -t 0 -u $fd event; do events+=("$event"); done
  return 0
}

# Waits up to $2 seconds for an event line starting with $1, discarding
# earlier events; REPLY is the rest of the line.
_bench_event() {
  local -F deadline=$(( EPOCHREALTIME + $2 ))
  while (( EPOCHREALTIME < deadline )); do
    _bench_pump 5 || :
    while (( ${#events} )); do
      if [[ $events[1] == "$1"* ]]; then
        REPLY=${events[1]#"$1"}
        shift events
        return 0
      fi
      shift events
    done
  done
  print -u2 -r -- "timed out waiting for $1"
  return 1
}

# The PTY session: shared UI, matching, appearance and the tree's Xcode peer,
# with capture stubbed to the fixed tail and _zle_picker_show instrumented.
_bench_session() {
  print -r -- '
local root=$1 unit=""
source "$root/.zsh.addons/.zsh.editor"
for unit in "$root/.zsh.addons/support/ui"/.zsh.ui.*(N.) \
    "$root/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) \
    "$root/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do
  source "$unit"
done
source "$root/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
source "$root/.zsh.addons/support/.zsh.appearance"
source "$root/.zsh.addons/.zsh.xcode"
exec {bench_events}<> "$BENCH_EVENTS"
bench_tail=$(<"$BENCH_TAIL")$'\''\n'\''
_xcode_run_read_sources() { REPLY=0; }
_xcode_run_output_snapshot() { REPLY=$bench_tail; }
_xcode_run_trimmed=0 _xcode_run_context=bench _xcode_run_clipboard=""
_xcode_run_unified_status=following _xcode_run_eof=0 _xcode_run_read_error=0
functions[_bench_show]=$functions[_zle_picker_show]
_zle_picker_show() {
  _bench_show "$@"
  local state="VIEW:${_xcode_logs_query-}:${_xcode_logs_matches-}"
  [[ $_ZLE_PICKER_TITLE == "Xcode / Logs" && $state != "$bench_previous" ]] || return 0
  bench_previous=$state
  print -r -u $bench_events -- "$state"
}
_bench_controller() { _xcode_logs_capture; _xcode_logs_reader; }
_bench_driver() {
  local bench_previous=""
  _zle_picker_run 20 "" 1 0 _bench_controller
  print -r -u $bench_events -- DONE
}
command stty rows 40 cols 100
print -r -u $bench_events -- READY'
}

# One PTY session: reply is the median key-to-frame latency in ms of the keys
# that changed the match count, then of those that kept it, then the match
# counts seen (compared between trees).
_bench_typing() {
  local root=$1 key='' query='' seen=''
  local -a keys=(v i e w $'\x7f' $'\x7f' $'\x7f' $'\x7f' 1 2 $'\x7f' $'\x7f')
  local -a change=() same=()
  local -i matches=0 previous=0
  local -F started=0 latency=0
  events=() raw='' reply=()
  zpty -b bench_logs "command env -i HOME=${(q)bench}/home ZDOTDIR=${(q)bench}/home \
    TMPDIR=${(q)bench}/home/tmp PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color \
    LC_ALL=${(q)locale} BENCH_EVENTS=${(q)bench}/events BENCH_TAIL=${(q)bench}/tail \
    /bin/zsh -dfi" || return
  pfd=$REPLY
  {
    zpty -w bench_logs "source ${(q)bench}/session.zsh ${(q)root}"
    _bench_event READY 20 || return 1
    zpty -w bench_logs _bench_driver
    _bench_event VIEW:: 20 && [[ $REPLY == <-> ]] || return 1
    previous=$REPLY seen=$REPLY
    for key in $keys; do
      [[ $key == $'\x7f' ]] && query=${query%?} || query+=$key
      started=$EPOCHREALTIME
      zpty -w -n bench_logs "$key"
      _bench_event "VIEW:$query:" 10 && [[ $REPLY == <-> ]] || return 1
      latency=$(( (EPOCHREALTIME - started) * 1000 ))
      matches=$REPLY seen+=",$REPLY"
      (( matches != previous )) && change+=($latency) || same+=($latency)
      previous=$matches
    done
    zpty -w -n bench_logs $'\e'
    _bench_event DONE 10 || return 1
  } always {
    zpty -d bench_logs
  }
  (( ${#change} && ${#same} )) || return 1
  reply=(${${=$(_bench_stats $change)}[1]} ${${=$(_bench_stats $same)}[1]} "$seen")
}

_bench_main() {
  local -F before=0
  command mkdir -p -- "$bench/home/tmp" || return
  _bench_tail
  print -rn -- "${REPLY%$'\n'}" >| "$bench/tail" || return
  _bench_session >| "$bench/session.zsh" || return
  command mkfifo "$bench/events" && exec {fd}<> "$bench/events" || return
  for (( run = 1; run <= runs; ++run )); do
    trees=(baseline candidate)
    (( run % 2 )) || trees=(candidate baseline)
    for tree in $trees; do
      [[ $tree == baseline ]] && root=$baseline || root=$candidate
      for workload in $workloads; do
        if [[ $workload == typing-* ]]; then
          # One session measures both typing workloads.
          [[ $workload == typing-same && $workloads[(Ie)typing-change] -gt 0 ]] && continue
          _bench_typing "$root" || {
            print -u2 -- "sample failed: $tree typing run $run"
            return 1
          }
          samples[${tree}:typing-change]+=" $reply[1]"
          samples[${tree}:typing-same]+=" $reply[2]"
          counts[${tree}:typing-change]=$reply[3] counts[${tree}:typing-same]=$reply[3]
          continue
        fi
        line=$(command env -i HOME="$bench/home" ZDOTDIR="$bench/home" \
          TMPDIR="$bench/home/tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
          LC_ALL=$locale TERM=dumb /bin/zsh -df "$self" --child "$root" "$workload")
        sample_status=$?
        (( sample_status == 0 )) && [[ $line == <->.<->' '<->:<-> ]] || {
          print -u2 -- "sample failed: $tree $workload run $run (status $sample_status)"
          return 1
        }
        samples[$tree:$workload]+=" ${line%% *}"
        counts[$tree:$workload]=${line##* }
      done
    done
  done
  print -r -- "xcode-log-collect runs=$runs locale=$locale"
  printf '%-13s %-10s  %-26s  %-26s  %s\n' workload rows:bytes 'baseline median (range)' \
    'candidate median (range)' delta
  for workload in $workloads; do
    [[ $counts[baseline:$workload] == $counts[candidate:$workload] ]] || {
      print -u2 -- "documents differ for $workload"
      return 1
    }
    values=(${=$(_bench_stats ${=samples[baseline:$workload]})})
    line="$values[1] (${values[2]}-${values[3]})"
    before=$values[1]
    values=(${=$(_bench_stats ${=samples[candidate:$workload]})})
    shown=$counts[baseline:$workload]
    [[ $workload == typing-* ]] && shown="12 keys"
    printf '%-13s %-10s  %-26s  %-26s  %+.1f%%\n' $workload $shown \
      "$line" "$values[1] (${values[2]}-${values[3]})" \
      $(( before > 0 ? (values[1] - before) * 100.0 / before : 0 ))
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  (( fd )) && exec {fd}>&-
  [[ ${bench:t} == compozsh-xcode-logs.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
