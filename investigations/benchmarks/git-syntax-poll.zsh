#!/bin/zsh -df
# Cost of the one _git_syntax_session_poll call that consumes a completed
# syntax response (Git review runs it inside the picker's input-idle callback,
# so keys wait for it), for two trees, alternating the tree order run by run.
# Reports each tree's median, min and max over runs (ms) per workload, and the
# candidate's median change.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> [runs] \
#          [mode] [locale]
#   synthetic  (default) one framed response of 500, 1,000, 2,000 and 4,096
#              spans in the real "row start end role" format, plus the ready
#              marker, buffered in memory. The session descriptor is
#              /dev/null, so the read loop sees end of file at once and the
#              clock covers framing, validation and the buffer cut.
#   vim        a real resident /usr/bin/vim session with each tree's own
#              adapter: rows 1-280 and 1-598 of the baseline's
#              .zsh.addons/.zsh.git-review (Zsh) and rows 1-280 of a dense,
#              ordinary JSON fixture. The clock covers only the poll call
#              that completes the response, never the waits between polls.
#   Each sample is a new `zsh -df` child under `env -i` with a system-only
#   PATH, the given locale (default en_US.UTF-8) and HOME, ZDOTDIR and TMPDIR
#   in this run's disposable directory; it sources only the tree's
#   .zsh.git-syntax and checks the published data, readiness and the empty
#   remaining buffer before reporting. Run from a disposable TMPDIR.
emulate -LR zsh
zmodload zsh/datetime zsh/zselect || exit

# One sample: prints "<poll-ms> <spans>" or fails with a distinct status.
_bench_child() {
  emulate -L zsh
  local root=$1 mode=$2 workload=$3 zsh_file=$4 json_file=$5
  local body='' input='' file='' language=''
  local -i i=0 rows=0 polls=0 result=1
  local -F started=0 elapsed=0
  local -a roles=(keyword string number comment type function variable) src=()
  source "$root/.zsh.addons/.zsh.git-syntax" || return 3
  local _git_syntax_session_dir='' _git_syntax_session_request_fifo=''
  local _git_syntax_session_response_fifo='' _git_syntax_session_buffer=''
  local -i _git_syntax_session_fd=-1 _git_syntax_session_pid=0
  local -i _git_syntax_session_ready=0 _git_syntax_session_generation=0
  local -i _git_syntax_session_active_id=0
  local -F _git_syntax_session_deadline=0
  if [[ $mode == synthetic ]]; then
    body=$'compozsh-syntax-1\n'
    for (( i = 1; i <= workload; ++i )); do
      body+="$(( 1200 + i / 4 )) $(( (i % 4) * 9 )) $(( (i % 4) * 9 + 6 )) ${roles[i % 7 + 1]}"$'\n'
    done
    body+=$'done\n'
    exec {_git_syntax_session_fd}</dev/null || return 4
    _git_syntax_session_active_id=7
    _git_syntax_session_deadline=$(( EPOCHREALTIME + 600 ))
    _git_syntax_session_buffer=$'compozsh-response-1:7\n'"$body"$'compozsh-response-end-1:7\ncompozsh-ready-1\n'
    started=$EPOCHREALTIME
    _git_syntax_session_poll
    result=$?
    elapsed=$(( EPOCHREALTIME - started ))
    exec {_git_syntax_session_fd}<&-
    (( result == 0 && _git_syntax_session_ready )) || return 5
    [[ $_GIT_SYNTAX_DATA == "$body" && -z $_git_syntax_session_buffer ]] || return 6
    printf '%.3f %d\n' $(( elapsed * 1000 )) $workload
    return 0
  fi
  language=${workload%-*} rows=${workload##*-}
  [[ $language == zsh ]] && file=$zsh_file || file=$json_file
  src=("${(@f)$(<$file)}")
  input="$language"$'\n'
  for (( i = 1; i <= rows && i <= ${#src}; ++i )); do
    input+="$i"$'\t'"$i"$'\t'"$i"$'\t'"${src[i]}"$'\n'
  done
  _GIT_SYNTAX_SCRIPT=$root/.zsh.addons/support/git-syntax.vim
  _git_syntax_session_start || return 7
  {
    while (( !_git_syntax_session_ready && polls++ < 200 )); do
      zselect -r $_git_syntax_session_fd -t 5 2>/dev/null
      _git_syntax_session_poll >/dev/null 2>&1
    done
    (( _git_syntax_session_ready )) || return 8
    _git_syntax_session_request "$input" || return 9
    polls=0
    while (( polls++ < 2000 )); do
      zselect -r $_git_syntax_session_fd -t 1 2>/dev/null
      started=$EPOCHREALTIME
      _git_syntax_session_poll >/dev/null 2>&1
      result=$?
      elapsed=$(( EPOCHREALTIME - started ))
      (( result == 1 )) || break
    done
    (( result == 0 )) || return 10
    # The ready marker may follow in a later read; only bytes other than it
    # would mean the cut kept part of the response.
    [[ -z $_git_syntax_session_buffer ||
       $_git_syntax_session_buffer == compozsh-ready-1$'\n' ]] || return 11
    printf '%.3f %d\n' $(( elapsed * 1000 )) $(( ${#${(@f)_GIT_SYNTAX_DATA}} - 2 ))
  } always {
    _git_syntax_session_stop
  }
}

if [[ $1 == --child ]]; then
  shift
  _bench_child "$@"
  exit
fi

local baseline=${1:A} candidate=${2:A} mode=${4:-synthetic} locale=${5:-en_US.UTF-8}
[[ -f $baseline/.zsh.addons/.zsh.git-syntax && -f $candidate/.zsh.addons/.zsh.git-syntax ]] &&
  [[ ${3:-10} == <1-> && $mode == (synthetic|vim) ]] || {
  print -u2 'usage: git-syntax-poll.zsh <baseline-root> <candidate-root> [runs] [synthetic|vim] [locale]'
  exit 2
}
local self=${0:A} bench='' tree='' root='' workload='' line=''
local -i runs=${3:-10} run=0 i=0 sample_status=0
local -a trees=() workloads=() values=()
local -A samples=() spans=()
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-syntax-poll.XXXXXXXX") && [[ -d $bench ]] || exit

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
  # One ordinary object per line, as a formatted API response or fixture.
  for (( i = 1; i <= 700; ++i )); do
    print -r -- "  {\"id\": $i, \"name\": \"item-$i\", \"enabled\": true, \"weight\": $(( i * 3 )).5, \"tags\": [\"a\", \"b\"], \"parent\": null},"
  done > "$bench/dense.json" || return
  case $mode in
    (synthetic) workloads=(500 1000 2000 4096) ;;
    (vim) workloads=(zsh-280 zsh-598 json-280) ;;
  esac
  for (( run = 1; run <= runs; ++run )); do
    trees=(baseline candidate)
    (( run % 2 )) || trees=(candidate baseline)
    for tree in $trees; do
      [[ $tree == baseline ]] && root=$baseline || root=$candidate
      for workload in $workloads; do
        line=$(command env -i HOME="$bench/home" ZDOTDIR="$bench/home" \
          TMPDIR="$bench/home/tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
          LC_ALL=$locale TERM=dumb /bin/zsh -df "$self" --child "$root" \
          "$mode" "$workload" "$baseline/.zsh.addons/.zsh.git-review" \
          "$bench/dense.json")
        sample_status=$?
        (( sample_status == 0 )) && [[ $line == <->.<->' '<-> ]] || {
          print -u2 -- "sample failed: $tree $workload run $run (status $sample_status)"
          return 1
        }
        samples[$tree:$workload]+=" ${line%% *}"
        spans[$tree:$workload]=${line##* }
      done
    done
  done
  print -r -- "git-syntax-poll mode=$mode runs=$runs locale=$locale"
  printf '%-9s %6s  %-28s  %-28s  %s\n' workload spans 'baseline median (range)' \
    'candidate median (range)' delta
  for workload in $workloads; do
    [[ $spans[baseline:$workload] == $spans[candidate:$workload] ]] || {
      print -u2 -- "span counts differ for $workload: $spans[baseline:$workload] vs $spans[candidate:$workload]"
      return 1
    }
    values=(${=$(_bench_stats ${=samples[baseline:$workload]})})
    line="$values[1] (${values[2]}-${values[3]})"
    before=$values[1]
    values=(${=$(_bench_stats ${=samples[candidate:$workload]})})
    printf '%-9s %6s  %-28s  %-28s  %+.1f%%\n' $workload $spans[baseline:$workload] \
      "$line" "$values[1] (${values[2]}-${values[3]})" \
      $(( before > 0 ? (values[1] - before) * 100.0 / before : 0 ))
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  [[ ${bench:t} == compozsh-syntax-poll.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
