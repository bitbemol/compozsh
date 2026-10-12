#!/bin/zsh -df
# Isolated interactive startup of two immutable trees, alternating which tree
# goes first each run. Reports per-tree median, min and max over runs (ms).
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> \
#          [runs] [locale]
#   process     wall clock of `zsh -dfi -c 'source <root>/.zshrc'` without a
#               TTY, from fork to exit (the TTY-only prompt captures skip)
#   source      that shell's in-process time for sourcing .zshrc
#   editable    wall clock from spawning `zsh -di` in a 140x40 PTY, whose
#               ZDOTDIR .zshrc sources the tree, to its first ZLE line-init
#   tty-source  that PTY shell's in-process time for sourcing .zshrc
#   fresh uses a new disposable ZDOTDIR per run (no completion dump, no
#   manual cache); warm reuses one ZDOTDIR per tree, primed by unmeasured
#   startups that wrote the completion dump and finished the asynchronous
#   manual capture. Every PTY shell is left only after that capture settles,
#   so no worker outlives its run. The working directory is the disposable
#   home, outside Git; ZSH_LOCAL_INIT=/dev/null and a system-only PATH.
emulate -LR zsh
zmodload zsh/datetime zsh/zpty zsh/zselect || exit
local baseline=${1:A} candidate=${2:A} locale=${4:-en_US.UTF-8}
local -i runs=${3:-15} run=0
[[ -f $baseline/.zshrc && -f $candidate/.zshrc ]] && (( runs > 0 )) || {
  print -u2 'usage: isolated-startup.zsh <baseline-root> <candidate-root> [runs] [locale]'
  exit 2
}
local bench=''
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-startup-bench.XXXXXXXX") && [[ -d $bench ]] || exit
local -a results=()
local -i fd=-1 pfd=-1

_bench_env() {
  local zdot=$1
  shift
  command env -i HOME="$bench/home" ZDOTDIR="$zdot" TMPDIR="$bench/tmp" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color LC_ALL=$locale \
    ZSH_LOCAL_INIT=/dev/null "$@"
}

# Records process and source times for one non-TTY startup of tree $1 in $2.
_bench_process() {
  local root=$1 zdot=$2 mode=$3 version=$4 value=''
  local -F started=0 ended=0
  local -i elapsed=0
  started=$EPOCHREALTIME
  _bench_env "$zdot" /bin/zsh -dfi -c '
    zmodload zsh/datetime
    typeset -F began=$EPOCHREALTIME
    source "$1/.zshrc"
    print -r -- $(( (EPOCHREALTIME - began) * 1e6 ))
  ' bench "$root" < /dev/null > "$bench/out" 2> /dev/null || return
  ended=$EPOCHREALTIME
  value=$(< "$bench/out")
  value=${value%%.*}
  [[ $value == <-> ]] || return
  elapsed=$(( (ended - started) * 1e6 ))
  results+=("$version process $mode $elapsed" "$version source $mode $value")
}

# Drains the PTY and waits up to $2 seconds for an event line starting with $1.
_bench_event() {
  local chunk='' event=''
  local -F deadline=$(( EPOCHREALTIME + $2 ))
  while (( EPOCHREALTIME < deadline )); do
    zselect -r $fd $pfd -t 5 || continue
    while zpty -r bench_startup chunk 2> /dev/null; do :; done
    while IFS= read -r -t 0 -u $fd event; do
      [[ $event == "$1"* ]] && { REPLY=${event#"$1" }; return 0; }
    done
  done
  return 1
}

# Starts tree $1 with ZDOTDIR $2 in a PTY; records editable and tty-source
# unless $3 is prime. Leaves only after the manual capture settles.
_bench_pty() {
  local root=$1 zdot=$2 mode=$3 version=$4 stale=''
  local -a fields=()
  local -F spawned=0
  local -i elapsed=0 i=0 status_ok=0
  while IFS= read -r -t 0 -u $fd stale; do :; done
  print -r -- 'zmodload zsh/datetime
typeset -gF _bench_started=$EPOCHREALTIME _bench_loaded=0
source "$BENCH_ROOT/.zshrc"
_bench_loaded=$EPOCHREALTIME
autoload -Uz add-zle-hook-widget
exec {_bench_fd}> "$BENCH_EVENTS"
_bench_ready() {
  print -r -- "READY $EPOCHREALTIME $(( (_bench_loaded - _bench_started) * 1e6 ))" >&$_bench_fd
  add-zle-hook-widget -d line-init _bench_ready
}
_bench_idle() { print -r -- "IDLE ${_MANUAL_ASYNC_STATE-none}" >&$_bench_fd; }
zle -N bench-idle _bench_idle; bindkey "^X^Z" bench-idle
add-zle-hook-widget line-init _bench_ready' > "$zdot/.zshrc" || return
  spawned=$EPOCHREALTIME
  zpty -b bench_startup "command env -i HOME=${(q)bench}/home ZDOTDIR=${(q)zdot} \
    TMPDIR=${(q)bench}/tmp PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color \
    COLUMNS=140 LINES=40 LC_ALL=${(q)locale} ZSH_LOCAL_INIT=/dev/null \
    BENCH_ROOT=${(q)root} BENCH_EVENTS=${(q)bench}/events /bin/zsh -di" || return
  pfd=$REPLY
  {
    _bench_event READY 60 || { print -u2 "no editable prompt: $version $mode"; return 1; }
    fields=(${=REPLY})
    elapsed=$(( (fields[1] - spawned) * 1e6 ))
    [[ $mode == prime ]] ||
      results+=("$version editable $mode $elapsed" "$version tty-source $mode ${fields[2]%%.*}")
    for (( i = 0; i < 600; i++ )); do
      zpty -w -n bench_startup $'\x18\x1a'
      _bench_event IDLE 30 || break
      [[ $REPLY == running ]] || { status_ok=1; break; }
      zselect -t 5 || :
    done
    (( status_ok )) || { print -u2 "manual capture did not settle: $version $mode"; return 1; }
  } always {
    zpty -d bench_startup
  }
}

_bench_main() {
  local version='' root='' mode='' metric='' zdot=''
  local -F median=0
  local -a order=() values=()
  command mkdir -p -- "$bench/home" "$bench/tmp" && builtin cd -- "$bench/home" || return
  command mkfifo "$bench/events" && exec {fd}<> "$bench/events" || return
  for version in baseline candidate; do
    root=$baseline
    [[ $version == candidate ]] && root=$candidate
    zdot="$bench/warm-$version"
    command mkdir -p -- "$zdot" || return
    _bench_process "$root" "$zdot" prime $version && _bench_pty "$root" "$zdot" prime $version ||
      { print -u2 "priming failed: $version"; return 1; }
  done
  results=()
  for (( run = 1; run <= runs; run++ )); do
    order=(baseline candidate)
    (( run % 2 )) || order=(candidate baseline)
    for version in $order; do
      root=$baseline
      [[ $version == candidate ]] && root=$candidate
      zdot="$bench/fresh-$version-$run-process"
      command mkdir -p -- "$zdot" && _bench_process "$root" "$zdot" fresh $version || return
      zdot="$bench/fresh-$version-$run-pty"
      command mkdir -p -- "$zdot" && _bench_pty "$root" "$zdot" fresh $version || return
      _bench_process "$root" "$bench/warm-$version" warm $version &&
        _bench_pty "$root" "$bench/warm-$version" warm $version || return
    done
  done
  print -r -- "runs=$runs locale=$locale zsh=$ZSH_VERSION size=140x40"
  printf '%-11s %-6s %-10s %10s %10s %10s\n' metric mode version median_ms min_ms max_ms
  for metric in process source editable tty-source; do
    for mode in fresh warm; do
      for version in baseline candidate; do
        values=(${(n)${${(M)results:#$version $metric $mode *}##* }})
        (( ${#values} )) || continue
        if (( ${#values} % 2 )); then
          median=${values[${#values} / 2 + 1]}
        else
          median=$(( (values[${#values} / 2] + values[${#values} / 2 + 1]) / 2.0 ))
        fi
        printf '%-11s %-6s %-10s %10.3f %10.3f %10.3f\n' "$metric" "$mode" "$version" \
          $(( median / 1000.0 )) $(( values[1] / 1000.0 )) $(( values[-1] / 1000.0 ))
      done
    done
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  (( fd < 0 )) || exec {fd}<&-
  builtin cd -- /
  [[ ${bench:t} == compozsh-startup-bench.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
