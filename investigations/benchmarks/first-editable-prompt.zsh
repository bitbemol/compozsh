#!/bin/zsh -df
# Exploration only: baseline/cold/warm measure shipped capture. skip-manual
# removes the feature for diagnosis. background forks real capture but delivers
# only a completion marker, not descriptions, to the parent. It is not a
# proposed worker protocol or a production asynchronous implementation.
# Usage: /bin/zsh -df <this-file> <reviewed-clone> [baseline|cold|warm|background]
emulate -LR zsh
setopt ERR_EXIT
local repo=${1:A} mode=${2:-baseline}
local bench_home=$(mktemp -d /tmp/compozsh-startup-home.XXXXXXXX)
{
  command env -i HOME=$bench_home ZDOTDIR=$bench_home TMPDIR=$bench_home \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color LC_ALL=en_US.UTF-8 \
    ZSH_LOCAL_INIT=/dev/null /bin/zsh -dfc '
      if [[ $2 == warm ]]; then
        /bin/zsh -dfi -c '\''cd -q -- "$HOME"; source "$1/.zsh.addons/.zsh.manual"; _manual_prompt_capture'\'' build "$1" || exit 1
      fi
      zmodload zsh/zpty
      zmodload zsh/zselect
      builtin cd -q -- "$HOME"
      command mkfifo "$HOME/events"
      exec {event_fd}<> "$HOME/events"
      local chunk="" event="" trace="" tty_fd=0 ready=0 gathered=0 edited=0
      print -r -- '\''
        zmodload zsh/datetime
        typeset -F _bench_started=$EPOCHREALTIME _bench_loaded=0
        source "$1/.zshrc"
        _bench_loaded=$EPOCHREALTIME
        [[ $2 == skip-manual ]] && _manual_prompt_capture() { return 0; }
        if [[ $2 == background ]]; then
          unsetopt MONITOR BG_NICE
          typeset -gi _bench_worker_pid=0
          functions[_bench_collect]=$functions[_manual_prompt_capture]
          _manual_prompt_capture() {
            (( _MANUAL_SUMMARIES_READY )) && return 0
            _MANUAL_SUMMARIES_READY=1
            (
              _MANUAL_SUMMARIES_READY=0
              _bench_collect
              printf "GATHERED elapsed_ms=%.3f names=%d\\n" \
                "$(( (EPOCHREALTIME-_bench_started)*1000 ))" \
                "${#_MANUAL_SUMMARIES}" > "$HOME/events"
            ) &
            _bench_worker_pid=$!
          }
          _bench_cleanup() {
            (( _bench_worker_pid > 0 )) || return 0
            kill $_bench_worker_pid 2>/dev/null
            wait $_bench_worker_pid 2>/dev/null
            _bench_worker_pid=0
          }
          add-zsh-hook zshexit _bench_cleanup
          _bench_edit() {
            printf "EDITED elapsed_ms=%.3f chars=%d\\n" \
              "$(( (EPOCHREALTIME-_bench_started)*1000 ))" "$#BUFFER" > "$HOME/events"
          }
          zle -N bench-edit _bench_edit
          bindkey "^X^Z" bench-edit
        fi
        _bench_ready() {
          printf "READY source_ms=%.3f editable_ms=%.3f names=%d cached_pages=%d\\n" \
            "$(( (_bench_loaded-_bench_started)*1000 ))" \
            "$(( (EPOCHREALTIME-_bench_started)*1000 ))" \
            "${#_MANUAL_SUMMARIES}" "${#_MANUAL_CACHE_SUMMARIES}" > "$HOME/events"
        }
        add-zle-hook-widget line-init _bench_ready
      '\'' > "$HOME/start.zsh"
      zpty -b startup /bin/zsh -dfi || exit 1
      tty_fd=$REPLY
      {
        zpty -w startup "source ${(q)HOME}/start.zsh ${(q)1} ${(q)2}"
        while zselect -r $event_fd $tty_fd -t 3000; do
          while zpty -r startup chunk; do trace+=$chunk; done
          if IFS= read -r -t 0 -u $event_fd event; then
            print -r -- "$2 $event"
            if [[ $2 != background ]]; then
              [[ $event == READY* ]] && exit 0
            else
              if [[ $event == READY* ]]; then
                ready=1
                zpty -w -n startup $'\''typing-before-descriptions\x18\x1a'\''
              elif [[ $event == GATHERED* ]]; then
                gathered=1
              elif [[ $event == EDITED* ]]; then
                edited=1
              fi
              if (( ready && gathered && edited )); then
                # Complete the owned job before closing the parent PTY.
                zpty -w -n startup $'\''\x15wait $_bench_worker_pid; _bench_worker_pid=0; exit\r'\''
                exit 0
              fi
            fi
          fi
        done
        local diagnostic=${(V)trace[-1000,-1]}
        diagnostic=${diagnostic//${1}/\$\{REPO_ROOT\}}
        diagnostic=${diagnostic//${HOME}/\$\{TEST_HOME\}}
        [[ -z ${USERNAME:-} ]] || diagnostic=${diagnostic//${USERNAME}/example-user}
        [[ -z ${HOST:-} ]] || diagnostic=${diagnostic//${HOST}/example-host}
        [[ -z ${HOST%%.*} ]] || diagnostic=${diagnostic//${HOST%%.*}/example-host}
        print -u2 -r -- "No editable prompt: $diagnostic"
        exit 1
      } always {
        zpty -d startup
      }
    ' startup "$repo" "$mode"
} always {
  [[ -d $bench_home && ${bench_home:t} == compozsh-startup-home.* ]] && command rm -rf -- "$bench_home"
}
