#!/bin/zsh -df
# First-prompt help-description capture cost of one tree, by variant,
# rotating the variant order run by run. Reports per-variant median, min and
# max over runs (ms), plus per-run paired differences.
# Usage: /bin/zsh -df <this-file> <root> [runs] [extra-companions] [locale] \
#          [override-file]
#   shipped   the tree as shipped
#   bypassed  diagnostic only: _compozsh_prompt_capture replaced by a no-op
#             after sourcing, so the first prompt reads no help guide
#   extra     shipped plus <extra-companions> (default 16) fixture commands,
#             each with a same-source help companion printing a guide of
#             about 6,200 characters (12 options, then examples), defined in
#             a disposable .zsh.addons file
#   override  only with [override-file]: a file sourced after the tree that
#             redefines _compozsh_prompt_capture (for example a prototype)
#   editable  wall clock from spawning `zsh -di` in a 140x40 PTY, whose
#             ZDOTDIR .zshrc sources the tree, to its first ZLE line-init
#   capture   in-shell time of the first _compozsh_prompt_capture call (the
#             first TTY precmd); reads counts _compozsh_prompt_read_help calls
#             (one process substitution, so one fork, each)
#   Every variant reuses one ZDOTDIR primed by an unmeasured startup (warm:
#   completion dump and manual cache written). Help snapshots are per-shell
#   memory, so every measured shell captures every companion. Each PTY shell
#   is left only after the asynchronous manual capture settles. The working
#   directory is the disposable home, outside Git; ZSH_LOCAL_INIT=/dev/null and
#   a system-only PATH.
emulate -LR zsh
zmodload zsh/datetime zsh/zpty zsh/zselect || exit
local root=${1:A} locale=${4:-en_US.UTF-8} override=${5:+${5:A}}
# At most 48 fixtures keep the shipped and fixture companions within the
# capture's 64-companion bound, so every fixture is captured.
[[ -f $root/.zshrc && ${2:-15} == <1-> && ${3:-16} == <1-48> ]] &&
  [[ -z $override || -f $override ]] || {
  print -u2 'usage: help-first-prompt.zsh <root> [runs] [extra-companions 1-48] [locale] [override-file]'
  exit 2
}
local -i runs=${2:-15} extra=${3:-16} run=0
local bench=''
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-help-bench.XXXXXXXX") && [[ -d $bench ]] || exit
local -a results=() variants=(shipped bypassed extra)
[[ -n $override ]] && variants+=(override)
local -i fd=-1 pfd=-1

# Writes $extra fixture commands and companions under a disposable
# .zsh.addons directory, so their shared source qualifies for capture.
_bench_fixture() {
  local name='' file="$bench/fixture/.zsh.addons/.zsh.bench-companions"
  local -i i=0
  command mkdir -p -- "${file:h}" || return
  for (( i = 1; i <= extra; i++ )); do
    name=bench-tool-${(l:2::0:)i}
    print -r -- "$name() { print -r -- 'bench fixture'; }
_compozsh_help_$name() {
  local -i i=0
  print -r -- 'Usage: $name [options]'
  print -r -- 'Benchmark fixture companion that prints a guide of realistic length.'
  print -r -- ''
  print -r -- 'Options:'
  for (( i = 1; i <= 12; i++ )); do
    print -r -- \"  --option-\$i  Fixture option \$i, described at a length typical of guides.\"
  done
  print -r -- ''
  print -r -- 'Examples:'
  for (( i = 1; i <= 66; i++ )); do
    print -r -- \"Example \$i runs $name with one fixture option and explains the result.\"
  done
}"
  done > "$file"
}

# Drains the PTY and waits up to $2 seconds for an event line starting with $1.
_bench_event() {
  local chunk='' event=''
  local -F deadline=$(( EPOCHREALTIME + $2 ))
  while (( EPOCHREALTIME < deadline )); do
    zselect -r $fd $pfd -t 5 || continue
    while zpty -r bench_help chunk 2> /dev/null; do :; done
    while IFS= read -r -t 0 -u $fd event; do
      [[ $event == "$1"* ]] && { REPLY=${event#"$1" }; return 0; }
    done
  done
  return 1
}

# Starts variant $1 with ZDOTDIR $2 in a PTY; records its results unless $3 is
# prime. Leaves only after the manual capture settles.
_bench_pty() {
  local variant=$1 zdot=$2 mode=$3 stale='' fixture='' replacement=''
  local -a fields=()
  local -F spawned=0
  local -i elapsed=0 i=0 status_ok=0
  [[ $variant == extra ]] && fixture="$bench/fixture/.zsh.addons/.zsh.bench-companions"
  [[ $variant == override ]] && replacement=$override
  while IFS= read -r -t 0 -u $fd stale; do :; done
  print -r -- 'zmodload zsh/datetime
typeset -gF _bench_started=$EPOCHREALTIME _bench_capture_us=-1
typeset -gi _bench_reads=0
source "$BENCH_ROOT/.zshrc"
[[ -n $BENCH_FIXTURE ]] && source "$BENCH_FIXTURE"
[[ -n $BENCH_OVERRIDE ]] && source "$BENCH_OVERRIDE"
if [[ $BENCH_VARIANT == bypassed ]]; then
  _bench_capture() { return 0; }
else
  functions[_bench_capture]=$functions[_compozsh_prompt_capture]
fi
functions[_bench_read_help]=$functions[_compozsh_prompt_read_help]
_compozsh_prompt_read_help() { (( ++_bench_reads )); _bench_read_help "$@"; }
_compozsh_prompt_capture() {
  local -F began=$EPOCHREALTIME
  _bench_capture "$@"
  local -i rc=$?
  (( _bench_capture_us >= 0 )) || _bench_capture_us=$(( (EPOCHREALTIME - began) * 1e6 ))
  return $rc
}
autoload -Uz add-zle-hook-widget
exec {_bench_fd}> "$BENCH_EVENTS"
_bench_ready() {
  print -r -- "READY $EPOCHREALTIME $_bench_capture_us $_bench_reads ${#_COMPOZSH_PROMPT_SUMMARIES}" >&$_bench_fd
  add-zle-hook-widget -d line-init _bench_ready
}
_bench_idle() { print -r -- "IDLE ${_MANUAL_ASYNC_STATE-none}" >&$_bench_fd; }
zle -N bench-idle _bench_idle; bindkey "^X^Z" bench-idle
add-zle-hook-widget line-init _bench_ready' > "$zdot/.zshrc" || return
  spawned=$EPOCHREALTIME
  zpty -b bench_help "command env -i HOME=${(q)bench}/home ZDOTDIR=${(q)zdot} \
    TMPDIR=${(q)bench}/tmp PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color \
    COLUMNS=140 LINES=40 LC_ALL=${(q)locale} ZSH_LOCAL_INIT=/dev/null \
    BENCH_ROOT=${(q)root} BENCH_EVENTS=${(q)bench}/events BENCH_VARIANT=$variant \
    BENCH_FIXTURE=${(q)fixture} BENCH_OVERRIDE=${(q)replacement} /bin/zsh -di" || return
  pfd=$REPLY
  {
    _bench_event READY 60 || { print -u2 "no editable prompt: $variant $mode"; return 1; }
    fields=(${=REPLY})
    elapsed=$(( (fields[1] - spawned) * 1e6 ))
    [[ $mode == prime ]] ||
      results+=("$variant editable $elapsed" "$variant capture ${fields[2]%%.*}"
        "$variant reads ${fields[3]}" "$variant summaries ${fields[4]}")
    for (( i = 0; i < 600; i++ )); do
      zpty -w -n bench_help $'\x18\x1a'
      _bench_event IDLE 30 || break
      [[ $REPLY == running ]] || { status_ok=1; break; }
      zselect -t 5 || :
    done
    (( status_ok )) || { print -u2 "manual capture did not settle: $variant $mode"; return 1; }
  } always {
    zpty -d bench_help
  }
}

# Prints "<label> median min max" in ms for the microsecond values in $@.
_bench_summary() {
  local label=$1
  shift
  local -a values=(${(-)@})
  local -F median=0
  (( ${#values} )) || return 0
  if (( ${#values} % 2 )); then
    median=${values[${#values} / 2 + 1]}
  else
    median=$(( (values[${#values} / 2] + values[${#values} / 2 + 1]) / 2.0 ))
  fi
  printf '%-34s %10.3f %10.3f %10.3f\n' "$label" \
    $(( median / 1000.0 )) $(( values[1] / 1000.0 )) $(( values[-1] / 1000.0 ))
}

# Values of metric $2 for variant $1, in run order.
_bench_values() {
  reply=(${${(M)results:#$1 $2 *}##* })
}

_bench_main() {
  local variant='' metric='' other=''
  local -a order=() values=() base=() deltas=()
  local -i i=0 n=${#variants}
  command mkdir -p -- "$bench/home" "$bench/tmp" && builtin cd -- "$bench/home" || return
  command mkfifo "$bench/events" && exec {fd}<> "$bench/events" || return
  _bench_fixture || return
  for variant in $variants; do
    command mkdir -p -- "$bench/zdot-$variant" &&
      _bench_pty $variant "$bench/zdot-$variant" prime ||
      { print -u2 "priming failed: $variant"; return 1; }
  done
  results=()
  for (( run = 1; run <= runs; run++ )); do
    order=(${variants[(run - 1) % n + 1,-1]} ${variants[1,(run - 1) % n]})
    for variant in $order; do
      _bench_pty $variant "$bench/zdot-$variant" measure || return
    done
  done
  print -r -- "runs=$runs extra=$extra locale=$locale zsh=$ZSH_VERSION size=140x40"
  for variant in $variants; do
    _bench_values $variant reads
    values=(${(nu)reply})
    _bench_values $variant summaries
    print -r -- "$variant: reads=${(j:,:)values} summaries=${(j:,:)${(@nu)reply}}"
  done
  printf '%-34s %10s %10s %10s\n' metric median_ms min_ms max_ms
  for metric in editable capture; do
    for variant in $variants; do
      _bench_values $variant $metric
      _bench_summary "$metric $variant" $reply
    done
  done
  # Paired per-run differences remove run-to-run drift from the comparison.
  for metric in editable capture; do
    _bench_values shipped $metric
    base=($reply)
    for other in ${variants:#shipped}; do
      _bench_values $other $metric
      deltas=()
      for (( i = 1; i <= ${#base}; i++ )); do
        deltas+=($(( base[i] - reply[i] )))
      done
      _bench_summary "$metric shipped-$other" $deltas
    done
  done
  _bench_values shipped capture
  base=($reply)
  _bench_values extra capture
  deltas=()
  for (( i = 1; i <= ${#base}; i++ )); do
    deltas+=($(( (reply[i] - base[i]) / extra )))
  done
  _bench_summary "capture per extra companion" $deltas
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  (( fd < 0 )) || exec {fd}<&-
  builtin cd -- /
  [[ ${bench:t} == compozsh-help-bench.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
