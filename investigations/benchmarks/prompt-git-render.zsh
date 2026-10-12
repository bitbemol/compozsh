#!/bin/zsh -df
# Complete prompt rendering outside and inside Git repositories, alternating
# two immutable trees. Reports the median, min and max of per-shell medians.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> \
#          [render|fresh|pty] [shells-per-version] [samples-per-shell] [locale]
#   render: every precmd hook plus PROMPT/RPROMPT expansion, timed in-process
#           without a TTY (the TTY-only manual and help captures are skipped);
#           three warm-up renders are discarded per shell.
#   fresh:  the same, but only the first render of each new shell (cold
#           Git-directory cache); samples is ignored.
#   pty:    Return on an empty line until the next zle line-init, in a real
#           PTY, after the first prompt's background work has settled.
emulate -LR zsh
zmodload zsh/datetime zsh/zpty zsh/zselect || exit
local baseline=${1:A} candidate=${2:A} mode=${3:-render} locale=${6:-en_US.UTF-8}
local -i shells=${4:-5} samples=${5:-40} run=0
[[ -f $baseline/.zshrc && -f $candidate/.zshrc && $mode == (render|fresh|pty) ]] || {
  print -u2 'usage: prompt-git-render.zsh <baseline-root> <candidate-root> [render|fresh|pty] [shells] [samples] [locale]'
  exit 2
}
[[ $mode == fresh ]] && samples=1
local bench=''
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-prompt-bench.XXXXXXXX") && [[ -d $bench ]] || exit
local -a fixtures=(outside clean dirty large) order=() results=()
local version='' fixture='' root='' value=''

_bench_fixtures() {
  export HOME=$bench GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  local name='' file=''
  local -i count=0 i=0
  command mkdir -p "$bench/outside/folder" "$bench/home" "$bench/tmp" || return
  for name count in clean 20 dirty 200 large 3000; do
    command git init -q -b main "$bench/$name" && builtin cd -- "$bench/$name" || return
    command git config user.name Bench && command git config user.email bench@example.invalid &&
      command git config commit.gpgsign false || return
    for (( i = 1; i <= count; i++ )); do
      file="src/dir-$(( i % 50 ))/file-$i.txt"
      command mkdir -p -- "${file:h}" && print -r -- "$i" > "$file" || return
    done
    command git add -A && command git commit -qm base && command git branch upstream &&
      command git branch -q -u upstream || return
  done
  builtin cd -- "$bench/dirty" || return
  for (( i = 1; i <= 40; i++ )); do print -r -- changed >> "src/dir-$(( i % 50 ))/file-$i.txt"; done
  command git stash -q && for (( i = 1; i <= 40; i++ )); do
    print -r -- changed >> "src/dir-$(( i % 50 ))/file-$i.txt"
    print -r -- new > "src/dir-$(( i % 50 ))/new-$i.txt"
  done
  command git add -- src/dir-{1..10}/file-{1..10}.txt(N) || return
  builtin cd -- "$bench/large" || return
  for (( i = 1; i <= 1000; i++ )); do print -r -- changed >> "src/dir-$(( i % 50 ))/file-$i.txt"; done
  for (( i = 1; i <= 2000; i++ )); do print -r -- new > "src/dir-$(( i % 50 ))/new-$i.txt"; done
}

_bench_env() {
  command env -i HOME="$bench/home" ZDOTDIR="$bench/home" TMPDIR="$bench/tmp" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color LC_ALL=$locale \
    ZSH_LOCAL_INIT=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null "$@"
}

# Prints the median render time in microseconds for one fresh shell, after
# $3 discarded warm-up renders.
_bench_render() {
  _bench_env /bin/zsh -dfi -c '
    zmodload zsh/datetime
    source "$1/.zshrc" && builtin cd -- "$2" || exit 1
    local -a times=()
    local -F start=0
    local hook=""
    local -i i=0 elapsed=0
    for (( i = 0; i < $3 + $4; i++ )); do
      start=$EPOCHREALTIME
      for hook in $precmd_functions; do "$hook"; done
      print -rP -- "$PROMPT$RPROMPT" > /dev/null
      (( i >= $4 )) && { elapsed=$(( (EPOCHREALTIME - start) * 1e6 )); times+=($elapsed); }
    done
    times=(${(n)times})
    print -r -- ${times[(${#times} + 1) / 2]}
  ' bench "$1" "$2" "$samples" "${3:-3}" < /dev/null 2> /dev/null
}
_bench_fresh() { _bench_render "$1" "$2" 0; }

# Prints the median Return-to-line-init latency in microseconds for one PTY.
_bench_pty() {
  local root=$1 directory=$2 chunk='' zdot="$bench/zdot"
  local -a times=()
  local -F sent=0
  local -i fd=0 pfd=0 i=0 elapsed=0
  # Waits up to $1 seconds for a line-init timestamp in REPLY while draining
  # the PTY; an undrained PTY blocks the shell before it paints the prompt.
  _bench_wait() {
    local -F deadline=$(( EPOCHREALTIME + $1 ))
    REPLY=''
    while (( EPOCHREALTIME < deadline )); do
      zselect -r $fd $pfd -t 10 || continue
      while zpty -rt bench_prompt chunk 2> /dev/null; do :; done
      IFS= read -r -t 0 -u $fd REPLY && return 0
    done
    return 1
  }
  command rm -rf -- "$zdot" && command mkdir -p -- "$zdot" || return
  command mkfifo "$zdot/events" && exec {fd}<> "$zdot/events" || return
  print -r -- 'source "$BENCH_ROOT/.zshrc"; builtin cd -- "$BENCH_DIR"
zmodload zsh/datetime; autoload -Uz add-zle-hook-widget
exec {_bench_fd}> "$BENCH_EVENTS"
_bench_line_init() { print -r -- $EPOCHREALTIME >&$_bench_fd; }
add-zle-hook-widget line-init _bench_line_init' > "$zdot/.zshrc"
  zpty bench_prompt "command env -i HOME=${(q)bench}/home ZDOTDIR=${(q)zdot} \
    TMPDIR=${(q)bench}/tmp PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color \
    LC_ALL=${(q)locale} ZSH_LOCAL_INIT=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    BENCH_ROOT=${(q)root} BENCH_DIR=${(q)directory} BENCH_EVENTS=${(q)zdot}/events /bin/zsh -di" || return
  pfd=$REPLY
  if _bench_wait 30; then
    _bench_wait 3 || :
    for (( i = 0; i < samples + 3; i++ )); do
      while zpty -rt bench_prompt chunk 2> /dev/null; do :; done
      sent=$EPOCHREALTIME
      zpty -w -n bench_prompt $'\r'
      _bench_wait 30 || break
      (( i >= 3 )) && { elapsed=$(( (REPLY - sent) * 1e6 )); times+=($elapsed); }
    done
  fi
  zpty -d bench_prompt
  exec {fd}<&-
  (( ${#times} == samples )) || return 1
  times=(${(n)times})
  print -r -- ${times[(${#times} + 1) / 2]}
}

_bench_main() {
  local -a values=()
  ( _bench_fixtures ) || { print -u2 'fixture setup failed'; return 1; }
  for (( run = 1; run <= shells; run++ )); do
    order=(baseline candidate)
    (( run % 2 )) || order=(candidate baseline)
    for version in $order; do
      root=$baseline
      [[ $version == candidate ]] && root=$candidate
      for fixture in $fixtures; do
        value=$(_bench_$mode "$root" "$bench/$fixture") && [[ $value == <-> ]] ||
          { print -u2 "measurement failed: $version $fixture"; return 1; }
        results+=("$version $fixture $value")
      done
    done
  done
  print -r -- "mode=$mode locale=$locale shells=$shells samples=$samples zsh=$ZSH_VERSION git=${$(command git --version)#git version }"
  printf '%-8s %-10s %10s %10s %10s\n' fixture version median_ms min_ms max_ms
  for fixture in $fixtures; do
    for version in baseline candidate; do
      values=(${(n)${${(M)results:#$version $fixture *}##* }})
      printf '%-8s %-10s %10.3f %10.3f %10.3f\n' "$fixture" "$version" \
        $(( values[(${#values} + 1) / 2] / 1000.0 )) $(( values[1] / 1000.0 )) $(( values[-1] / 1000.0 ))
    done
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  [[ ${bench:t} == compozsh-prompt-bench.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
