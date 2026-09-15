#!/bin/zsh -df
# Production async readiness, accepted draft and complete parent catalog.
# Usage: /bin/zsh -df <this-file> <reviewed-clone> [cold|warm]
emulate -LR zsh
local repo=${1:A} mode=${2:-cold}
local bench_home=$(mktemp -d /tmp/compozsh-async-bench.XXXXXXXX) || exit
{
  command env -i HOME=$bench_home ZDOTDIR=$bench_home TMPDIR=$bench_home \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color LC_ALL=en_US.UTF-8 \
    ZSH_LOCAL_INIT=/dev/null /bin/zsh -dfc '
      builtin cd -- "$HOME"
      if [[ $2 == warm ]]; then
        /bin/zsh -dfi -c '\''source "$1/.zsh.addons/.zsh.manual"; _manual_prompt_capture'\'' warm "$1" || exit 1
      fi
      zmodload zsh/zpty
      zmodload zsh/zselect
      command mkfifo "$HOME/events"
      exec {event_fd}<> "$HOME/events"
      local event="" chunk="" trace="" pfd=0 edited=0 gathered=0
      print -r -- '\''
        zmodload zsh/datetime
        typeset -F _bench_started=$EPOCHREALTIME
        source "$1/.zshrc"
        typeset -F _bench_arrived=0 _bench_callback_max=0
        typeset -i _bench_callback_depth=0 _bench_callback_count=0 _bench_reported=0
        functions[_bench_publish]=$functions[_manual_async_publish]
        _manual_async_publish() {
          _bench_publish || return
          _bench_arrived=$(( (EPOCHREALTIME-_bench_started)*1000 ))
        }
        functions[_bench_read]=$functions[_manual_async_read]
        functions[_bench_control]=$functions[_manual_async_control]
        _bench_callback() {
          local -F began=$EPOCHREALTIME elapsed=0
          local fn=$1
          shift
          (( ++_bench_callback_depth ))
          "$fn" "$@"
          (( --_bench_callback_depth ))
          if (( !_bench_callback_depth )); then
            elapsed=$(( (EPOCHREALTIME-began)*1000 ))
            (( ++_bench_callback_count ))
            (( elapsed > _bench_callback_max )) && _bench_callback_max=$elapsed
            if [[ $_MANUAL_ASYNC_STATE == ready && $_bench_reported == 0 ]]; then
              _bench_reported=1
              printf "GATHERED elapsed_ms=%.3f names=%d chars=%d cursor=%d callbacks=%d max_callback_ms=%.3f\n" \
                "$_bench_arrived" "$_MANUAL_ASYNC_COUNT" "$#BUFFER" "$CURSOR" \
                "$_bench_callback_count" "$_bench_callback_max" > "$HOME/events"
            fi
          fi
          return 0
        }
        _manual_async_read() { _bench_callback _bench_read "$@"; }
        _manual_async_control() { _bench_callback _bench_control "$@"; }
        _bench_ready() {
          printf "READY elapsed_ms=%.3f names=%d\n" \
            "$(( (EPOCHREALTIME-_bench_started)*1000 ))" "${#_MANUAL_SUMMARIES}" > "$HOME/events"
        }
        _bench_edit() {
          printf "EDITED elapsed_ms=%.3f chars=%d\n" \
            "$(( (EPOCHREALTIME-_bench_started)*1000 ))" "$#BUFFER" > "$HOME/events"
        }
        zle -N bench-edit _bench_edit
        bindkey "^X^Z" bench-edit
        add-zle-hook-widget line-init _bench_ready
      '\'' > "$HOME/start.zsh"
      zpty -b startup /bin/zsh -dfi || exit 2
      pfd=$REPLY
      {
        zpty -w startup "source ${(q)HOME}/start.zsh ${(q)1}"
        while zselect -r $event_fd $pfd -t 3500; do
          while zpty -r startup chunk; do trace+=$chunk; done
          if IFS= read -r -t 0 -u $event_fd event; then
            print -r -- "$2 $event"
            case $event in
              READY*) zpty -w -n startup $'\''ls -la\x18\x1a'\'' ;;
              EDITED*) edited=1 ;;
              GATHERED*) gathered=1 ;;
            esac
            (( edited && gathered )) && exit 0
          fi
        done
        local diagnostic=${(V)trace[-1000,-1]}
        diagnostic=${diagnostic//${1}/\$\{REPO_ROOT\}}
        diagnostic=${diagnostic//${HOME}/\$\{TEST_HOME\}}
        [[ -z ${USERNAME:-} ]] || diagnostic=${diagnostic//${USERNAME}/example-user}
        [[ -z ${HOST:-} ]] || diagnostic=${diagnostic//${HOST}/example-host}
        [[ -z ${HOST%%.*} ]] || diagnostic=${diagnostic//${HOST%%.*}/example-host}
        print -u2 -r -- "No completion: $diagnostic"
        exit 3
      } always {
        zpty -d startup
      }
    ' benchmark "$repo" "$mode"
} always {
  [[ -d $bench_home && ${bench_home:t} == compozsh-async-bench.* ]] && command rm -rf -- "$bench_home"
}
