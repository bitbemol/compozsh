#!/bin/zsh -df
# Cost of splitting NUL-dense packets in _compozsh_capture_bounded, the shared
# entry behind every foreground Git workspace capture, for two trees,
# alternating the tree order run by run. Reports each tree's median, min and
# max over runs (ms) per workload, and the candidate's median change.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> [runs] \
#          [locale]
#   nul-2000, nul-8000  a shell function prints 2,000 or 8,000 records of
#              `refs/remotes/origin/a-name` plus NUL (54,000 and 216,000
#              bytes, under the 256 KiB bound); the clock covers one
#              _compozsh_capture_bounded call.
#   remote-999 _git_branch_remote_capture (every bare `g` open) in a
#              throwaway repository with 999 remote-tracking refs.
#   review-4000 _git_review_changes_capture (Git review's file list) in a
#              throwaway repository with 4,000 short untracked paths (the
#              list keeps 1,000; the capture splits every record).
#   Each sample is a new `zsh -df` child under `env -i` with a system-only
#   PATH, the given locale (default en_US.UTF-8), system and global Git
#   configuration disabled, and HOME, ZDOTDIR and TMPDIR in this run's
#   disposable directory. It sources the tree's support entries and the
#   owning peer, makes one untimed warm-up call, then times one call and
#   checks the result (exact payload, or the record count) before reporting.
#   Run from a disposable TMPDIR; the repositories are built once per run.
emulate -LR zsh
zmodload zsh/datetime || exit

# One sample: prints "<ms> <records>" or fails with a distinct status.
_bench_child() {
  emulate -L zsh
  local root=$1 workload=$2 repos=$3 payload='' unit='' entry=''
  local -a reply=()
  local -i i=0 result=1 records=0
  local -F started=0 elapsed=0
  for entry in "$root/.zsh.addons/support/functions"/.zsh.*(N.); do
    source "$entry" || return 3
  done
  (( ${+functions[_compozsh_capture_bounded]} )) || return 3
  case $workload in
    (nul-*)
      records=${workload#nul-}
      for (( i = 0; i < records; ++i )); do
        unit+=$'refs/remotes/origin/a-name\0'
      done
      payload=$unit
      _bench_fixture() { print -rn -- "$payload"; }
      _compozsh_capture_bounded 262144 _bench_fixture || return 4
      started=$EPOCHREALTIME
      _compozsh_capture_bounded 262144 _bench_fixture
      result=$?
      elapsed=$(( EPOCHREALTIME - started ))
      (( result == 0 )) && [[ $reply[1] == "$payload" && $reply[2] == complete &&
        $reply[3] == 0 ]] || return 5
      ;;
    (remote-999)
      source "$root/.zsh.addons/.zsh.navigation" || return 3
      # Bare `g` reads the local catalog first; remote names exclude it.
      _git_recent_branches "$repos/remote" || return 4
      _git_branch_remote_capture "$repos/remote" || return 4
      started=$EPOCHREALTIME
      _git_branch_remote_capture "$repos/remote"
      result=$?
      elapsed=$(( EPOCHREALTIME - started ))
      records=${#_GIT_BRANCH_REMOTE_VALUES}
      (( result == 0 && records == 999 )) || return 5
      ;;
    (review-4000)
      source "$root/.zsh.addons/.zsh.git-review" || return 3
      _git_review_changes_capture "$repos/review" || return 4
      started=$EPOCHREALTIME
      _git_review_changes_capture "$repos/review"
      result=$?
      elapsed=$(( EPOCHREALTIME - started ))
      # The list keeps the first 1,000 paths; the capture splits all 4,000.
      records=${#${(0)_GIT_REVIEW_DATA}}
      (( result == 0 && records == 4000 && ${#_GIT_REVIEW_PATHS} == 1000 )) || return 5
      ;;
    (*) return 2 ;;
  esac
  printf '%.3f %d\n' $(( elapsed * 1000 )) $records
  return 0
}

if [[ ${1:-} == --child ]]; then
  shift
  _bench_child "$@"
  exit
fi

local baseline=${1:A} candidate=${2:A} locale=${4:-en_US.UTF-8}
local entry_path=.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded
[[ -f $baseline/$entry_path && -f $candidate/$entry_path && ${3:-10} == <1-> ]] || {
  print -u2 'usage: bounded-capture.zsh <baseline-root> <candidate-root> [runs] [locale]'
  exit 2
}
local self=${0:A} bench='' tree='' root='' workload='' line='' oid=''
local -i runs=${3:-10} run=0 i=0 sample_status=0
local -a trees=() workloads=(nul-2000 nul-8000 remote-999 review-4000) values=()
local -A samples=() counts=()
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-bounded-capture.XXXXXXXX") && [[ -d $bench ]] || exit

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

# Throwaway repositories: 999 remote-tracking refs, and 4,000 untracked files.
_bench_repositories() {
  local repo=''
  for repo in remote review; do
    command git init -qb main "$bench/repos/$repo" || return
    command git -C "$bench/repos/$repo" -c user.name=Fixture \
      -c user.email=fixture@example.invalid -c commit.gpgsign=false \
      commit --allow-empty -qm initial || return
  done
  command git -C "$bench/repos/remote" remote add origin \
    https://example.invalid/origin.git || return
  oid=$(command git -C "$bench/repos/remote" rev-parse HEAD) || return
  for (( i = 1; i <= 999; ++i )); do
    print -r -- "create refs/remotes/origin/topic-$i $oid"
  done | command git -C "$bench/repos/remote" update-ref --stdin || return
  command mkdir -p -- "$bench/repos/review/u" || return
  for (( i = 1; i <= 4000; ++i )); do
    : > "$bench/repos/review/u/f$i" || return
  done
}

_bench_main() {
  local -F before=0
  command mkdir -p -- "$bench/home/tmp" || return
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  _bench_repositories || return
  for (( run = 1; run <= runs; ++run )); do
    trees=(baseline candidate)
    (( run % 2 )) || trees=(candidate baseline)
    for tree in $trees; do
      [[ $tree == baseline ]] && root=$baseline || root=$candidate
      for workload in $workloads; do
        line=$(command env -i HOME="$bench/home" ZDOTDIR="$bench/home" \
          TMPDIR="$bench/home/tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
          GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
          LC_ALL=$locale TERM=dumb /bin/zsh -df "$self" --child "$root" \
          "$workload" "$bench/repos")
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
  print -r -- "bounded-capture runs=$runs locale=$locale"
  printf '%-11s %7s  %-28s  %-28s  %s\n' workload records 'baseline median (range)' \
    'candidate median (range)' delta
  for workload in $workloads; do
    [[ $counts[baseline:$workload] == $counts[candidate:$workload] ]] || {
      print -u2 -- "record counts differ for $workload"
      return 1
    }
    values=(${=$(_bench_stats ${=samples[baseline:$workload]})})
    line="$values[1] (${values[2]}-${values[3]})"
    before=$values[1]
    values=(${=$(_bench_stats ${=samples[candidate:$workload]})})
    printf '%-11s %7s  %-28s  %-28s  %+.1f%%\n' $workload $counts[baseline:$workload] \
      "$line" "$values[1] (${values[2]}-${values[3]})" \
      $(( before > 0 ? (values[1] - before) * 100.0 / before : 0 ))
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  [[ ${bench:t} == compozsh-bounded-capture.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
