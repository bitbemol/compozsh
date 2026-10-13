#!/bin/zsh -df
# Cost of wrapping one long printable-ASCII line in a full-screen document
# (_zle_picker_inspect_prepare, which Git review reruns on selection, resize
# and syntax-status changes while input waits) for two trees, alternating the
# tree order run by run. Reports each tree's median, min and max over runs
# (ms) per workload, and the candidate's median change.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> [runs] \
#          [locale]
#   doc-16k, doc-64k, doc-256k  Git review settings (document, not
#              reader-only): one added diff line, `+` and minified JSON, of
#              16 KiB, 64 KiB or 262,000 bytes (under Git review's 256 KiB
#              capture bound) wrapped at width 100.
#   reader-64k the same 64 KiB line in a reader-only document (the Xcode log
#              reader), which already took the ASCII byte path.
#   Each sample is a new `zsh -df` child under `env -i` with a system-only
#   PATH, the given locale (default en_US.UTF-8) and HOME, ZDOTDIR and TMPDIR
#   in this run's disposable directory. It sources the tree's support
#   entries, makes one untimed warm-up call on a short line, then times one
#   prepare and checks that the rows rejoin to the line before reporting the
#   row count, which must match between trees. Run from a disposable TMPDIR.
emulate -LR zsh
zmodload zsh/datetime || exit

# One sample: prints "<ms> <rows>" or fails with a distinct status.
_bench_child() {
  emulate -L zsh
  local root=$1 workload=$2 entry='' unit='' line=''
  local -i bytes=0 result=1
  local -F started=0 elapsed=0
  # Source first: the shared state entry declares (and resets) these globals.
  for entry in "$root/.zsh.addons/support/ui"/.zsh.ui.*(N.) \
      "$root/.zsh.addons/support/functions"/.zsh.*(N.); do
    source "$entry" || return 3
  done
  (( ${+functions[_zle_picker_inspect_prepare]} )) || return 3
  local -i _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=0
  local _ZLE_PICKER_DOCUMENT_KEY=diff
  local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
  local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
  case $workload in
    (doc-16k) bytes=16384 ;;
    (doc-64k) bytes=65536 ;;
    (doc-256k) bytes=262000 ;;
    (reader-64k) bytes=65536 _ZLE_PICKER_READER_ONLY=1 ;;
    (*) return 2 ;;
  esac
  unit='{"id":12345,"name":"compozsh-item","tags":["alpha","beta"],"ok":true},'
  line="+[${(pl:bytes-3::$unit:)}]"
  (( ${#line} == bytes )) || return 4
  _ZLE_PICKER_DOCUMENT_LINES=("${line[1,1000]}")
  _zle_picker_inspect_prepare diff 100 || return 4
  _ZLE_PICKER_DOCUMENT_LINES=("$line")
  _ZLE_PICKER_INSPECT_KEY='' _ZLE_PICKER_INSPECT_WIDTH=0
  started=$EPOCHREALTIME
  _zle_picker_inspect_prepare diff 100
  result=$?
  elapsed=$(( EPOCHREALTIME - started ))
  (( result == 0 )) && [[ ${(j::)_ZLE_PICKER_INSPECT_LINES} == "$line" ]] || return 5
  printf '%.3f %d\n' $(( elapsed * 1000 )) ${#_ZLE_PICKER_INSPECT_LINES}
  return 0
}

if [[ ${1:-} == --child ]]; then
  shift
  _bench_child "$@"
  exit
fi

local baseline=${1:A} candidate=${2:A} locale=${4:-en_US.UTF-8}
local entry_path=.zsh.addons/support/ui/.zsh.ui.zle_picker_inspect_render
[[ -f $baseline/$entry_path && -f $candidate/$entry_path && ${3:-10} == <1-> ]] || {
  print -u2 'usage: inspect-wrap.zsh <baseline-root> <candidate-root> [runs] [locale]'
  exit 2
}
local self=${0:A} bench='' tree='' root='' workload='' line=''
local -i runs=${3:-10} run=0 sample_status=0
local -a trees=() workloads=(doc-16k doc-64k doc-256k reader-64k) values=()
local -A samples=() counts=()
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-inspect-wrap.XXXXXXXX") && [[ -d $bench ]] || exit

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

_bench_main() {
  local -F before=0
  command mkdir -p -- "$bench/home/tmp" || return
  for (( run = 1; run <= runs; ++run )); do
    trees=(baseline candidate)
    (( run % 2 )) || trees=(candidate baseline)
    for tree in $trees; do
      [[ $tree == baseline ]] && root=$baseline || root=$candidate
      for workload in $workloads; do
        line=$(command env -i HOME="$bench/home" ZDOTDIR="$bench/home" \
          TMPDIR="$bench/home/tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
          LC_ALL=$locale TERM=dumb /bin/zsh -df "$self" --child "$root" \
          "$workload")
        sample_status=$?
        (( sample_status == 0 )) && [[ $line == <->.<->' '<-> ]] || {
          print -u2 -- "sample failed: $tree $workload run $run (status $sample_status)"
          return 1
        }
        samples[$tree:$workload]+=" ${line%% *}"
        counts[$tree:$workload]=${line##* }
      done
    done
  done
  print -r -- "inspect-wrap runs=$runs locale=$locale width=100"
  printf '%-10s %5s  %-28s  %-28s  %s\n' workload rows 'baseline median (range)' \
    'candidate median (range)' delta
  for workload in $workloads; do
    [[ $counts[baseline:$workload] == $counts[candidate:$workload] ]] || {
      print -u2 -- "row counts differ for $workload"
      return 1
    }
    values=(${=$(_bench_stats ${=samples[baseline:$workload]})})
    line="$values[1] (${values[2]}-${values[3]})"
    before=$values[1]
    values=(${=$(_bench_stats ${=samples[candidate:$workload]})})
    printf '%-10s %5s  %-28s  %-28s  %+.1f%%\n' $workload $counts[baseline:$workload] \
      "$line" "$values[1] (${values[2]}-${values[3]})" \
      $(( before > 0 ? (values[1] - before) * 100.0 / before : 0 ))
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  [[ ${bench:t} == compozsh-inspect-wrap.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
