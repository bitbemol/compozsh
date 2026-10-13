#!/bin/zsh -df
# Cost of turning Xcode's scheme list into the scheme catalog, for two trees,
# alternating the tree order run by run. Reports each tree's median, min and
# max over runs (ms) per workload, and the candidate's median change.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> [runs] \
#          [locale]
#   parse-1024, parse-4096  _xcode_plist_string_array_parse over the real
#              `/usr/bin/plutil -extract workspace.schemes xml1` conversion of
#              1,024 or 4,096 realistic names (FeatureModuleN and
#              FeatureModuleNTests, the last one `Special & <Final>`; 88 KiB
#              of JSON and 152 KiB of XML at 4,096).
#   dense-1024 the same parse for 1,024 names of 56 ampersands each: plutil
#              writes every one as `&amp;`, the in-bound worst case per byte
#              of JSON (62 KiB of JSON, 302 KiB of XML).
#   capture-4096 one complete _xcode_schemes_capture (bounded xcodebuild
#              capture, count, conversion, parse, validation) of the 4,096
#              names through a fake xcodebuild on PATH that prints the JSON.
#   Each sample is a new `zsh -df` child under `env -i` with a system-only
#   PATH (plus the fake xcodebuild), the given locale (default en_US.UTF-8)
#   and HOME, ZDOTDIR and TMPDIR in this run's disposable directory. It
#   sources the tree's .zsh.xcode and its plutil support entry, makes one
#   untimed warm-up parse of two names, then times one call and checks the
#   count and the last decoded name before reporting. Run from a disposable
#   TMPDIR; the JSON and XML inputs are built once per invocation.
emulate -LR zsh
zmodload zsh/datetime || exit

# One sample: prints "<ms> <schemes>" or fails with a distinct status.
_bench_child() {
  emulate -L zsh
  local root=$1 workload=$2 inputs=$3 xml='' last=''
  local -a reply=()
  local -i result=1 expected=0
  local -F started=0 elapsed=0
  source "$root/.zsh.addons/.zsh.xcode" || return 3
  source "$root/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw" || return 3
  _xcode_plist_string_array_parse \
    '<array><string>A</string><string>B &amp; C</string></array>' 2 || return 4
  case $workload in
    (parse-*|dense-*)
      expected=${workload#*-}
      xml=$(<"$inputs/$workload.xml") || return 4
      [[ $workload == dense-* ]] && last=${(l:56::&:)} || last='Special & <Final>'
      started=$EPOCHREALTIME
      _xcode_plist_string_array_parse "$xml" $expected
      result=$?
      elapsed=$(( EPOCHREALTIME - started ))
      (( result == 0 && ${#reply} == expected )) && [[ $reply[-1] == "$last" ]] || return 5
      ;;
    (capture-4096)
      expected=4096
      path=("$inputs/bin" $path)
      export XCODE_BENCH_JSON=$inputs/parse-4096.json
      rehash
      started=$EPOCHREALTIME
      _xcode_schemes_capture workspace /example/App.xcworkspace
      result=$?
      elapsed=$(( EPOCHREALTIME - started ))
      (( result == 0 && ${#_XCODE_SCHEMES} == expected )) &&
        [[ $_XCODE_SCHEMES[-1] == 'Special & <Final>' ]] || return 5
      ;;
    (*) return 2 ;;
  esac
  printf '%.3f %d\n' $(( elapsed * 1000 )) $expected
  return 0
}

if [[ ${1:-} == --child ]]; then
  shift
  _bench_child "$@"
  exit
fi

local baseline=${1:A} candidate=${2:A} locale=${4:-en_US.UTF-8}
[[ -f $baseline/.zsh.addons/.zsh.xcode && -f $candidate/.zsh.addons/.zsh.xcode &&
  ${3:-10} == <1-> ]] || {
  print -u2 'usage: xcode-scheme-parse.zsh <baseline-root> <candidate-root> [runs] [locale]'
  exit 2
}
local self=${0:A} bench='' tree='' root='' workload='' line=''
local -i runs=${3:-10} run=0 i=0 sample_status=0
local -a trees=() workloads=(parse-1024 parse-4096 dense-1024 capture-4096) values=()
local -A samples=() counts=()
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-xcode-schemes.XXXXXXXX") && [[ -d $bench ]] || exit

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

# xcodebuild -list -json shape, then plutil's own XML conversion of the list.
_bench_inputs() {
  local name='' workload=''
  local -a names=()
  for workload in parse-1024 parse-4096 dense-1024; do
    names=()
    for (( i = 1; i < ${workload#*-}; ++i )); do
      if [[ $workload == dense-* ]]; then
        names+=("\"${(l:56::&:)}$i\"")
      else
        name="FeatureModule$(( (i + 1) / 2 ))"
        (( i % 2 )) || name+=Tests
        names+=("\"$name\"")
      fi
    done
    [[ $workload == dense-* ]] && names+=("\"${(l:56::&:)}\"") ||
      names+=('"Special & <Final>"')
    print -r -- "{\"workspace\":{\"name\":\"App\",\"schemes\":[${(j:,:)names}]}}" \
      >| "$bench/$workload.json" || return
    command /usr/bin/plutil -extract workspace.schemes xml1 -o "$bench/$workload.xml" -- \
      "$bench/$workload.json" || return
  done
  command mkdir -p -- "$bench/bin" || return
  print -r -- $'#!/bin/sh\nexec /bin/cat -- "$XCODE_BENCH_JSON"' >| "$bench/bin/xcodebuild" &&
    command chmod +x "$bench/bin/xcodebuild"
}

_bench_main() {
  local -F before=0
  command mkdir -p -- "$bench/home/tmp" || return
  _bench_inputs || return
  for (( run = 1; run <= runs; ++run )); do
    trees=(baseline candidate)
    (( run % 2 )) || trees=(candidate baseline)
    for tree in $trees; do
      [[ $tree == baseline ]] && root=$baseline || root=$candidate
      for workload in $workloads; do
        line=$(command env -i HOME="$bench/home" ZDOTDIR="$bench/home" \
          TMPDIR="$bench/home/tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin \
          LC_ALL=$locale TERM=dumb /bin/zsh -df "$self" --child "$root" \
          "$workload" "$bench")
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
  print -r -- "xcode-scheme-parse runs=$runs locale=$locale"
  printf '%-12s %7s  %-28s  %-28s  %s\n' workload schemes 'baseline median (range)' \
    'candidate median (range)' delta
  for workload in $workloads; do
    [[ $counts[baseline:$workload] == $counts[candidate:$workload] ]] || {
      print -u2 -- "scheme counts differ for $workload"
      return 1
    }
    values=(${=$(_bench_stats ${=samples[baseline:$workload]})})
    line="$values[1] (${values[2]}-${values[3]})"
    before=$values[1]
    values=(${=$(_bench_stats ${=samples[candidate:$workload]})})
    printf '%-12s %7s  %-28s  %-28s  %+.1f%%\n' $workload $counts[baseline:$workload] \
      "$line" "$values[1] (${values[2]}-${values[3]})" \
      $(( before > 0 ? (values[1] - before) * 100.0 / before : 0 ))
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  [[ ${bench:t} == compozsh-xcode-schemes.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
