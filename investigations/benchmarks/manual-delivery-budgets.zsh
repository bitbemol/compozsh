#!/bin/zsh -df
# Synthetic, in-memory protocol workloads. Run with isolated HOME/ZDOTDIR/TMPDIR
# and en_US.UTF-8. Arguments: reviewed clone, small|typical|records|bytes|selectors.
# Measures the complete native reader callback, including identity validation,
# final map publication and descriptor cleanup, without a painted ZLE prompt.
_benchmark_delivery() {
emulate -L zsh
zmodload zsh/datetime
zmodload zsh/zselect
local repo=${1:A} workload=${2:-typical}
[[ ${3:-} != profile ]] || zmodload zsh/zprof
source "$repo/.zsh.addons/.zsh.manual" || exit 1
local -i count=2308 index=0 actual=0 candidate_bytes=0 callback_us=0
local prefix=demo source_text='synthetic(1)' description=${(l:80::d:)} name=''
local pending='' chunk=''
local -a times=() ordered=()
local MANPATH=/synthetic/manual
case $workload in
  small) count=32 ;;
  typical) ;;
  records) count=8192 prefix=${(l:240::n:)} source_text=${(l:245::s:)} description=${(l:240::d:)} ;;
  bytes|bytes-small|selectors)
    count=4096 prefix=${(l:250::😀:)} source_text=${(l:512::😀:)} description=${(l:240::😀:)}
    [[ $workload != bytes-small ]] || count=32
    [[ $workload != selectors ]] || MANPATH="/${(l:260000::s:)}"
    ;;
  *) exit 2 ;;
esac
command mkfifo "$HOME/delivery" || exit 3
sysopen -rw -o nonblock,cloexec -u _MANUAL_ASYNC_FD "$HOME/delivery" || exit 4
command rm -- "$HOME/delivery"
_manual_async_candidate_clear
_MANUAL_ASYNC_GENERATION=1 _MANUAL_ASYNC_STATE=running
_MANUAL_ASYNC_DEADLINE=$(( EPOCHREALTIME+60 ))
_manual_async_identity || exit 5
_MANUAL_ASYNC_IDENTITY=$REPLY
_feed() {
  local -F start=0
  syswrite -o $_MANUAL_ASYNC_FD -c actual "$chunk" || { print -u2 -- 'write failed'; return 1; }
  (( actual == ${#chunk} )) || { print -u2 -- "write bytes $actual expected ${#chunk}"; return 1; }
  (( candidate_bytes += actual ))
  start=$EPOCHREALTIME
  _manual_async_read $_MANUAL_ASYNC_FD
  callback_us=$(( (EPOCHREALTIME-start)*1000000 ))
  times+=($callback_us)
  [[ $_MANUAL_ASYNC_STATE != failed ]] || { print -u2 -- "rejected: workload=$workload bytes=$candidate_bytes callbacks=${#times}"; return 1; }
}
unsetopt MULTIBYTE
pending=$'.COMPOZSH-MANUAL-RESULT-1\t1\t'"$count"$'\n'
for (( index=1; index<=count; ++index )); do
  name="$prefix$index"
  pending+="$name"$'\t'"$source_text"$'\t'"$description"$'\n'
  while (( ${#pending} >= 8192 )); do
    chunk=${pending[1,8192]} pending=${pending[8193,-1]}
    _feed || exit 6
  done
done
pending+=$'END\t1\n'
_MANUAL_ASYNC_CONTROL_DONE=1
chunk=$pending
_feed || exit 7
[[ $_MANUAL_ASYNC_STATE == ready && $_MANUAL_ASYNC_COUNT == $count ]] || exit 8
ordered=("${(@on)times}")
local -i percentile=$(( (${#ordered}*95+99)/100 ))
printf '%s records=%d bytes=%d callbacks=%d p95_ms=%.3f max_ms=%.3f publish_ms=%.3f\n' \
  "$workload" "$count" "$candidate_bytes" "${#times}" \
  "$(( ordered[percentile]/1000.0 ))" "$(( ordered[-1]/1000.0 ))" "$(( times[-1]/1000.0 ))"
[[ ${3:-} != profile ]] || zprof
}
_benchmark_delivery "$@"
