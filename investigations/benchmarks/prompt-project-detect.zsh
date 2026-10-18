#!/bin/zsh -df
# Prompt project detection outside Git, alternating two immutable trees.
# Reports the median, min and max of per-shell medians (ms) per fixture for
# _prompt_project_context alone and for the complete _prompt_update.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> \
#          [shells-per-version] [samples-per-shell] [locale]
#   small    package.json, tsconfig.json and ten src/*.ts files.
#   c-tree   CMakeLists.txt and 40 files each in src/ (.c) and include/ (.h).
#   tsx-800  package.json and 800 flat src/*.tsx files.
#   json-5k  package.json and 5,000 flat src/*.json files.
#   public   package.json and 800 flat public/*.png files.
#   outside  a folder with no project, walked up to `/`.
#   Each shell is a new `zsh -df` under `env -i` with a system-only PATH, the
#   given locale (default en_US.UTF-8) and HOME, ZDOTDIR and TMPDIR in this
#   run's disposable directory. It sources only the tree's prompt peer (no
#   runtime support, so no language tool runs), discards three warm-up
#   samples, and checks that both trees report the same project items. Run
#   from a disposable TMPDIR.
emulate -LR zsh
zmodload zsh/datetime || exit
local baseline=${1:A} candidate=${2:A} locale=${5:-en_US.UTF-8}
local -i shells=${3:-5} samples=${4:-40} run=0
[[ -f $baseline/.zsh.addons/.zsh.prompt && -f $candidate/.zsh.addons/.zsh.prompt ]] || {
  print -u2 'usage: prompt-project-detect.zsh <baseline-root> <candidate-root> [shells] [samples] [locale]'
  exit 2
}
local bench=''
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-project-bench.XXXXXXXX") && [[ -d $bench ]] || exit
local -a fixtures=(small c-tree tsx-800 json-5k public outside) order=() results=()
local version='' fixture='' root='' value=''

_bench_fixtures() {
  local -i i=0
  command mkdir -p "$bench/home" "$bench/tmp" "$bench/outside/a/b" \
    "$bench"/{small,tsx-800,json-5k}/src "$bench"/c-tree/{src,include} \
    "$bench/public/public" || return
  : >| "$bench/small/package.json" && : >| "$bench/small/tsconfig.json" || return
  for (( i = 1; i <= 10; i++ )); do : >| "$bench/small/src/file-$i.ts" || return; done
  : >| "$bench/c-tree/CMakeLists.txt" || return
  for (( i = 1; i <= 40; i++ )); do
    : >| "$bench/c-tree/src/file-$i.c" && : >| "$bench/c-tree/include/file-$i.h" || return
  done
  for fixture in tsx-800 json-5k public; do : >| "$bench/$fixture/package.json" || return; done
  for (( i = 1; i <= 800; i++ )); do
    : >| "$bench/tsx-800/src/file-$i.tsx" && : >| "$bench/public/public/file-$i.png" || return
  done
  for (( i = 1; i <= 5000; i++ )); do : >| "$bench/json-5k/src/file-$i.json" || return; done
}

# Prints "<context-us> <update-us> <items>" for one fresh shell: the medians
# of $3 samples after three discarded warm-ups.
_bench_shell() {
  command env -i HOME="$bench/home" ZDOTDIR="$bench/home" TMPDIR="$bench/tmp" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color LC_ALL=$locale \
    ZSH_LOCAL_INIT=/dev/null /bin/zsh -df -c '
    zmodload zsh/datetime
    source "$1/.zsh.addons/.zsh.prompt" && builtin cd -- "$2" || exit 1
    local -a context=() update=()
    local -F start=0
    local -i i=0
    for (( i = 0; i < $3 + 3; i++ )); do
      start=$EPOCHREALTIME
      _prompt_project_context
      (( i >= 3 )) && context+=($(( (EPOCHREALTIME - start) * 1e6 )))
      start=$EPOCHREALTIME
      _prompt_update
      (( i >= 3 )) && update+=($(( (EPOCHREALTIME - start) * 1e6 )))
    done
    context=(${(n)context%.*}) update=(${(n)update%.*})
    print -r -- ${context[(${#context} + 1) / 2]} ${update[(${#update} + 1) / 2]} \
      "${(j:,:)_PROMPT_PROJECT_ITEMS}"
  ' bench "$1" "$2" "$samples" < /dev/null 2> /dev/null
}

_bench_main() {
  local -a values=() fields=()
  local metric='' items_key=''
  local -A items=()
  _bench_fixtures || { print -u2 'fixture setup failed'; return 1; }
  for (( run = 1; run <= shells; run++ )); do
    order=(baseline candidate)
    (( run % 2 )) || order=(candidate baseline)
    for version in $order; do
      root=$baseline
      [[ $version == candidate ]] && root=$candidate
      for fixture in $fixtures; do
        value=$(_bench_shell "$root" "$bench/$fixture") &&
          fields=(${=value}) && [[ ${fields[1]} == <-> && ${fields[2]} == <-> ]] ||
          { print -u2 "measurement failed: $version $fixture"; return 1; }
        items_key=$fixture
        if (( ${+items[$items_key]} )) && [[ ${items[$items_key]} != ${fields[3]-} ]]; then
          print -u2 "project items differ: $fixture"
          return 1
        fi
        items[$items_key]=${fields[3]-}
        results+=("$version $fixture context ${fields[1]}" "$version $fixture update ${fields[2]}")
      done
    done
  done
  print -r -- "locale=$locale shells=$shells samples=$samples zsh=$ZSH_VERSION"
  printf '%-8s %-8s %-10s %10s %10s %10s\n' fixture metric version median_ms min_ms max_ms
  for fixture in $fixtures; do
    for metric in context update; do
      for version in baseline candidate; do
        values=(${(n)${${(M)results:#$version $fixture $metric *}##* }})
        printf '%-8s %-8s %-10s %10.3f %10.3f %10.3f\n' "$fixture" "$metric" "$version" \
          $(( values[(${#values} + 1) / 2] / 1000.0 )) $(( values[1] / 1000.0 )) $(( values[-1] / 1000.0 ))
      done
    done
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  [[ ${bench:t} == compozsh-project-bench.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
