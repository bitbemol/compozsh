#!/bin/zsh -df
# Cost of reading the Git and Spotlight file-search provider streams
# (_file_search_capture_git and _file_search_capture_spotlight in
# .zsh.addons/.zsh.find) for two trees, alternating the tree order run by run.
# Reports each tree's median, min and max over runs (ms) per workload, and the
# candidate's median change.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> [runs] \
#          [locale]
#   git-2400      a throwaway repository with the 2,400 tracked paths of the
#                 search-git frame scenario (empty files) and its query
#                 `controller`; real /usr/bin/git.
#   git-50k       a stub git that prints a fixed 50,000-path NUL list
#                 (about 2.5 MB) that the query `zzqx` never matches.
#   spotlight-5k  a stub mdfind that prints 5,000 existing paths under the
#                 run's HOME (about 0.9 MB), query `zzqx` (no matches).
#   spotlight-5k-match  the same list, query `note 42` (some matches).
#   Each sample is a new `zsh -df` child under `env -i` with a system-only
#   PATH (the stub directory first for git-50k), the given locale (default
#   en_US.UTF-8), system and global Git configuration disabled, and HOME,
#   ZDOTDIR and TMPDIR in this run's disposable directory. It sources the
#   tree's support entries and .zsh.find, makes one untimed warm-up call, then
#   times one capture and reports its status and result count, which must
#   match between the trees. Run from a disposable TMPDIR; the fixtures are
#   built once per run.
emulate -LR zsh
zmodload zsh/datetime || exit

# One sample: prints "<ms> <status>/<count>" or fails with a distinct status.
_bench_child() {
  emulate -L zsh
  local root=$1 workload=$2 bench=$3 entry=''
  local -a capture=()
  local -i result=0
  local -F started=0 elapsed=0
  for entry in "$root/.zsh.addons/support/functions"/.zsh.*(N.); do
    source "$entry" || return 3
  done
  source "$root/.zsh.addons/.zsh.find" || return 3
  case $workload in
    (git-2400) capture=(_file_search_capture_git "$bench/repo" controller) ;;
    (git-50k)
      path=("$bench/bin" "${path[@]}")
      capture=(_file_search_capture_git "$bench/repo" zzqx)
      ;;
    (spotlight-5k) capture=(_file_search_capture_spotlight "$HOME" zzqx "$bench/bin/mdfind") ;;
    (spotlight-5k-match)
      capture=(_file_search_capture_spotlight "$HOME" 'note 42' "$bench/bin/mdfind")
      ;;
    (*) return 2 ;;
  esac
  "${capture[@]}"
  (( $? <= 1 )) || return 4
  started=$EPOCHREALTIME
  "${capture[@]}"
  result=$?
  elapsed=$(( EPOCHREALTIME - started ))
  (( result <= 1 )) || return 5
  printf '%.3f %d/%d\n' $(( elapsed * 1000 )) $result ${#_FILE_SEARCH_VALUES}
  return 0
}

if [[ ${1:-} == --child ]]; then
  shift
  _bench_child "$@"
  exit
fi

local baseline=${1:A} candidate=${2:A} locale=${4:-en_US.UTF-8}
[[ -f $baseline/.zsh.addons/.zsh.find && -f $candidate/.zsh.addons/.zsh.find &&
   ${3:-10} == <1-> ]] || {
  print -u2 'usage: file-search-stream.zsh <baseline-root> <candidate-root> [runs] [locale]'
  exit 2
}
local self=${0:A} bench='' tree='' root='' workload='' line='' area='' kind=''
local -i runs=${3:-10} run=0 i=0 sample_status=0
local -a trees=() values=() files=()
local -a workloads=(git-2400 git-50k spotlight-5k spotlight-5k-match)
local -A samples=() counts=()
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-file-search-stream.XXXXXXXX") && [[ -d $bench ]] || exit

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

# The search-git repository's 2,400 paths, a 50,000-path list, and 5,000
# indexed files under HOME.
_bench_fixtures() {
  local -a areas=(Account Billing Cart Catalog Checkout Customer Delivery Inventory
    Loyalty Notification Order Payment Profile Search Shipping)
  local -a kinds=(Address Audit Badge Banner Card Cart Chart Dialog Filter Form
    Grid Header List Menu Modal Panel Picker Summary Table Toolbar)
  local list='' directory='' entry=''
  for area in $areas; do
    for kind in $kinds; do
      directory=src/features/${(L)area}/${(L)kind}
      files+=("$directory/$area${kind}Controller.ts" "$directory/$area${kind}View.tsx"
        "$directory/$area$kind.test.ts" "$directory/index.ts")
    done
  done
  for (( i = 1; i <= 600; i++ )); do files+=("src/shared/${(L)kinds[i % 20 + 1]}/utility-$i.ts"); done
  for (( i = 1; i <= 300; i++ )); do files+=("docs/guides/${(L)areas[i % 15 + 1]}/guide-$i.md"); done
  for (( i = 1; i <= 300; i++ )); do files+=("public/assets/${(L)areas[i % 15 + 1]}/banner-$i.svg"); done
  command git init -q -b main "$bench/repo" || return
  for entry in $files; do
    command mkdir -p -- "$bench/repo/${entry:h}" && : > "$bench/repo/$entry" || return
  done
  command git -C "$bench/repo" add -A || return
  command git -C "$bench/repo" -c user.name=Fixture -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false commit -qm initial || return

  command mkdir -p -- "$bench/bin" || return
  for (( i = 1; i <= 50000; ++i )); do
    list+="src/features/module-$(( i % 97 ))/component-$i/Component$i.view.ts"$'\0'
  done
  print -rn -- "$list" > "$bench/git.list" || return
  print -r -- '#!/bin/zsh -f' > "$bench/bin/git" &&
    print -r -- 'while [[ $1 == -C || $1 == -c ]]; do shift 2; done' >> "$bench/bin/git" &&
    print -r -- '[[ $1 == rev-parse ]] && exit 0' >> "$bench/bin/git" &&
    print -r -- "/bin/cat -- ${(q)bench}/git.list" >> "$bench/bin/git" || return

  list=''
  for (( i = 1; i <= 5000; ++i )); do
    directory="$bench/home/Documents/project-$(( i % 50 ))"
    [[ -d $directory ]] || command mkdir -p -- "$directory" || return
    : > "$directory/meeting note $i.txt" || return
    list+="$directory/meeting note $i.txt"$'\0'
  done
  print -rn -- "$list" > "$bench/spotlight.list" || return
  print -r -- '#!/bin/zsh -f' > "$bench/bin/mdfind" &&
    print -r -- "/bin/cat -- ${(q)bench}/spotlight.list" >> "$bench/bin/mdfind" || return
  command chmod +x "$bench/bin/git" "$bench/bin/mdfind"
}

_bench_main() {
  local -F before=0
  local entry=''
  command mkdir -p -- "$bench/home/tmp" || return
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  _bench_fixtures || return
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
          "$workload" "$bench")
        sample_status=$?
        (( sample_status == 0 )) && [[ $line == <->.<->' '<->/<-> ]] || {
          print -u2 -- "sample failed: $tree $workload run $run (status $sample_status)"
          return 1
        }
        samples[$tree:$workload]+=" ${line%% *}"
        counts[$tree:$workload]=${line##* }
      done
    done
  done
  print -r -- "file-search-stream runs=$runs locale=$locale"
  printf '%-18s %-8s  %-28s  %-28s  %s\n' workload 'status/n' 'baseline median (range)' \
    'candidate median (range)' delta
  for workload in $workloads; do
    [[ $counts[baseline:$workload] == $counts[candidate:$workload] ]] || {
      print -u2 -- "results differ for $workload"
      return 1
    }
    values=(${=$(_bench_stats ${=samples[baseline:$workload]})})
    line="$values[1] (${values[2]}-${values[3]})"
    before=$values[1]
    values=(${=$(_bench_stats ${=samples[candidate:$workload]})})
    printf '%-18s %-8s  %-28s  %-28s  %+.1f%%\n' $workload $counts[baseline:$workload] \
      "$line" "$values[1] (${values[2]}-${values[3]})" \
      $(( before > 0 ? (values[1] - before) * 100.0 / before : 0 ))
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  [[ ${bench:t} == compozsh-file-search-stream.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
