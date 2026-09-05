# Native ZLE coverage for living-prompt painting and terminal lifecycle.

_test_living_prompt_native_lens_transcript_and_manual_toggle() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" project="$TEST_TMP_DIR/home/project"
  local output=''

  command mkdir -p -- "$home/.zsh.addons/private" "$project" || return
  command ln -s "$TEST_REPO_ROOT/.zshrc" "$home/.zshrc" || return
  test_write_file "$project/.fixture-project" '' || return
  command git init -q "$project" || return
  command git -C "$project" config user.name 'Zsh Tests' || return
  command git -C "$project" config user.email 'zsh-tests.invalid@example.invalid' || return
  command git -C "$project" add .fixture-project || return
  command git -C "$project" commit -qm baseline || return
  command git -C "$project" branch -M main || return
  command mkfifo "$home/events" || return

  test_write_file "$home/.zsh.addons/local/init.zsh" '
typeset -ga PROMPT_PROJECT_MARKERS=(.fixture-project)
ZSH_AUTOSUGGEST_ENABLED=1
HISTFILE=/dev/null
' || return
  test_write_file "$home/.zsh.addons/private/.zsh.living-prompt-observer" '
zmodload zsh/parameter || return 1
setopt MULTIBYTE
typeset -gi _PROMPT_TEST_EVENT_FD=0
exec {_PROMPT_TEST_EVENT_FD}<> "$HOME/events" || return 1

_prompt_test_text() {
  REPLY=${(V)1}
  [[ -n $REPLY ]] || REPLY="<empty>"
}
_prompt_test_emit() {
  print -r -u $_PROMPT_TEST_EVENT_FD -- "$1"
}
_prompt_test_state_event() {
  local kind=$1 event_buffer="" event_predisplay="" event_postdisplay=""
  local event_prompt="" event_rprompt="" event_rendered="" rendered_prompt=""
  local -i prompt_rows=1
  _prompt_test_text "$BUFFER"; event_buffer=$REPLY
  _prompt_test_text "$PREDISPLAY"; event_predisplay=$REPLY
  _prompt_test_text "$POSTDISPLAY"; event_postdisplay=$REPLY
  _prompt_test_text "$PROMPT"; event_prompt=$REPLY
  _prompt_test_text "$RPROMPT"; event_rprompt=$REPLY
  print -P -v rendered_prompt -r -- "$PROMPT"
  prompt_rows=${#${(f)rendered_prompt}}
  (( prompt_rows > 0 )) || prompt_rows=1
  _prompt_test_text "$rendered_prompt"; event_rendered=$REPLY
  _prompt_test_emit "$kind|${_PROMPT_VIEW:-missing}|${_PROMPT_LENS_PINNED:-0}|$event_buffer|$CURSOR|$prompt_rows|${_ZLE_AUTOSUGGEST_SUSPENDED:-0}|$event_predisplay|$event_postdisplay|${CONTEXT:-none}|$event_prompt|$event_rprompt|$event_rendered"
}
_prompt_test_line_init() { _prompt_test_state_event INIT; }
_prompt_test_pre_redraw() { _prompt_test_state_event REDRAW; }
_prompt_test_line_finish() { _prompt_test_state_event FINISH; }
_prompt_test_probe() { _prompt_test_state_event PROBE; }
_prompt_test_command() { _prompt_test_emit EXECUTED; }
_prompt_test_second() { _prompt_test_emit SECOND; }
_prompt_test_vared() {
  local value=draft
  _prompt_test_emit VARED-READY
  vared value
  _prompt_test_emit "VARED-DONE|$value"
}

# Observe provider calls to prove the ordinary shell invokes transcript
# preparation while nested vared leaves the native editor lifecycle alone.
if (( ${+functions[_prompt_prepare_transcript]} )); then
  functions[_prompt_test_prepare_transcript]=${functions[_prompt_prepare_transcript]}
  _prompt_prepare_transcript() {
    _prompt_test_emit "PREPARE|${CONTEXT:-none}"
    _prompt_test_prepare_transcript "$@"
  }
fi

autoload -Uz add-zle-hook-widget
add-zle-hook-widget -d line-init _prompt_test_line_init 2>/dev/null
add-zle-hook-widget -d line-pre-redraw _prompt_test_pre_redraw 2>/dev/null
add-zle-hook-widget -d line-finish _prompt_test_line_finish 2>/dev/null
add-zle-hook-widget line-init _prompt_test_line_init
add-zle-hook-widget line-pre-redraw _prompt_test_pre_redraw
add-zle-hook-widget line-finish _prompt_test_line_finish
zle -N prompt-test-probe _prompt_test_probe
bindkey "^X^Z" prompt-test-probe
print -s -- "_prompt_test_command-GHOST"
_prompt_test_emit "SOURCE|$(command tty)"
:' || return

  output=$(test_run_interactive "$home" '
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    # Fail before starting a PTY when the feature is absent, so the red phase is
    # a direct capability failure rather than an event timeout.
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.prompt"
    for capability in _prompt_editing_started _prompt_prepare_transcript _prompt_toggle_lens \
        _zle_prompt_pre_redraw _zle_prompt_line_finish _zle_prompt_toggle_widget; do
      (( ${+functions[$capability]} )) || {
        print -u2 -r -- "missing living prompt capability: $capability"
        exit 90
      }
    done

    zmodload zsh/zpty || exit 1
    zmodload zsh/zselect || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local event="" chunk="" trace="" all_events="" pty_fd=0 device=""

    _living_prompt_driver() {
      builtin cd -- "$2" || return 1
      exec env -i PATH="$PATH" HOME="$HOME" ZDOTDIR="$HOME" \
        TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" LC_ALL=en_US.UTF-8 \
        "$1" -di
    }
    _living_prompt_expect() {
      local wanted=$1
      while zselect -r $event_fd $pty_fd -t 500; do
        while zpty -r living-prompt chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          all_events+="$event"$'"'"'\n'"'"'
          [[ $event == "$wanted"* ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      while zpty -r living-prompt chunk; do trace+=$chunk; done
      print -u2 -r -- "expected event prefix ${(qqq)wanted}; last=${(qqq)event}"
      print -u2 -r -- "PTY trace: ${(V)trace[-1200,-1]}"
      return 1
    }
    _living_prompt_probe() {
      zpty -w -n living-prompt $'"'"'\x18\x1a'"'"'
      _living_prompt_expect "PROBE|$1|" || return
    }

    zpty -b living-prompt _living_prompt_driver "$2" "$3" || exit 3
    pty_fd=$REPLY
    {
      _living_prompt_expect "SOURCE|" || exit 4
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 5
      _living_prompt_expect "INIT|lens|0|<empty>|0|" || exit 6
      _living_prompt_probe lens || exit 8
      local -a fields=("${(@s:|:)event}")
      (( fields[6] > 2 )) || {
        print -u2 -r -- "expanded lens did not paint more than two rows: $event"
        exit 9
      }

      # The prefix has an active ghost suggestion. Typing consumes only the
      # automatic lens; the unaccepted suffix must be removed before transcript.
      zpty -w -n living-prompt _prompt_test_command
      _living_prompt_expect "REDRAW|compact|0|_prompt_test_command|" || exit 10
      fields=("${(@s:|:)event}")
      [[ $fields[9] == -GHOST && $fields[13] == *SUGGESTION* &&
         $fields[13] == *-GHOST* ]] || {
        print -u2 -r -- "autosuggestion was not disclosed by the same redraw: $event"
        exit 11
      }
      _living_prompt_probe compact || exit 12
      fields=("${(@s:|:)event}")
      (( fields[6] > 2 )) || {
        print -u2 -r -- "typed command did not paint an interaction lens: $event"
        exit 13
      }
      zpty -w -n living-prompt $'"'"'\r'"'"'
      _living_prompt_expect "PREPARE|start" || exit 14
      _living_prompt_expect "FINISH|transcript|0|_prompt_test_command|" || exit 15
      fields=("${(@s:|:)event}")
      [[ $fields[7] == 1 && $fields[8] == "<empty>" &&
         $fields[9] == "<empty>" && $fields[10] == start &&
         $fields[11] == "%D{%H:%M} › " && $fields[12] == "<empty>" &&
         $fields[13] != *SUGGESTION* && $fields[13] != *[╭│╰]* ]] || {
        print -u2 -r -- "transcript retained editor display or wrong prompt: $event"
        exit 16
      }
      _living_prompt_expect EXECUTED || exit 17
      _living_prompt_expect "INIT|compact|0|<empty>|0|" || exit 18
      fields=("${(@s:|:)event}")
      [[ $fields[7] == 0 && $fields[9] == "<empty>" ]] || exit 19

      # Option-I pins the lens while a non-end cursor and draft remain intact;
      # the same gesture closes it without touching editable state.
      zpty -w -n living-prompt draft
      _living_prompt_expect "REDRAW|compact|0|draft|5|" || exit 20
      fields=("${(@s:|:)event}")
      [[ $fields[13] == *"╭─ RUN"* &&
         $fields[13] == *"COMMAND TEXT"*draft* ]] || {
        print -u2 -r -- "generic interaction lens did not follow BUFFER: $event"
        exit 42
      }

      # Clearing a draft is an edit too: the interaction disclosure contracts
      # immediately back to READY instead of leaving stale inferred intent.
      zpty -w -n living-prompt $'"'"'\x15'"'"'
      _living_prompt_expect "REDRAW|compact|0|<empty>|0|" || exit 43
      fields=("${(@s:|:)event}")
      [[ $fields[13] == *"╭─ READY"* &&
         $fields[13] != *"COMMAND TEXT"* && $fields[13] != *ACTION* ]] || {
        print -u2 -r -- "empty BUFFER retained stale interaction facts: $event"
        exit 44
      }
      zpty -w -n living-prompt draft
      _living_prompt_expect "REDRAW|compact|0|draft|5|" || exit 45
      zpty -w -n living-prompt $'"'"'\e[D\e[D\ei'"'"'
      _living_prompt_expect "REDRAW|lens|1|draft|3|" || exit 21
      _living_prompt_probe lens || exit 22
      fields=("${(@s:|:)event}")
      [[ $fields[3] == 1 && $fields[4] == draft && $fields[5] == 3 ]] || exit 23
      (( fields[6] > 2 )) || exit 24
      zpty -w -n living-prompt $'"'"'\ei'"'"'
      _living_prompt_expect "REDRAW|compact|0|draft|3|" || exit 25
      _living_prompt_probe compact || exit 26
      fields=("${(@s:|:)event}")
      [[ $fields[4] == draft && $fields[5] == 3 ]] && (( fields[6] > 2 )) || exit 27

      # Acceptance always clears a manual pin before the next active prompt.
      zpty -w -n living-prompt $'"'"'\x15\ei'"'"'
      _living_prompt_expect "REDRAW|lens|1|<empty>|0|" || exit 28
      zpty -w -n living-prompt _prompt_test_second
      _living_prompt_expect "REDRAW|lens|1|_prompt_test_second|" || exit 29
      fields=("${(@s:|:)event}")
      [[ $fields[13] == *CONTEXT* &&
         $fields[13] == *"COMMAND TEXT"*_prompt_test_second* ]] || {
        print -u2 -r -- "pinned Context did not retain its live interaction section: $event"
        exit 46
      }
      zpty -w -n living-prompt $'"'"'\r'"'"'
      _living_prompt_expect "FINISH|transcript|0|_prompt_test_second|" || exit 30
      _living_prompt_expect SECOND || exit 31
      _living_prompt_expect "INIT|compact|0|<empty>|0|" || exit 32

      # zle-line-finish also runs for vared, but that nested editor must not
      # convert the shell prompt into another transcript entry.
      zpty -w -n living-prompt _prompt_test_vared
      _living_prompt_expect "REDRAW|compact|0|_prompt_test_vared|" || exit 33
      zpty -w -n living-prompt $'"'"'\r'"'"'
      _living_prompt_expect VARED-READY || exit 34
      zpty -w -n living-prompt $'"'"'\r'"'"'
      _living_prompt_expect "VARED-DONE|draft" || exit 35
      _living_prompt_expect "INIT|compact|0|<empty>|0|" || exit 36
      [[ $all_events != *"PREPARE|vared"* ]] || {
        print -u2 -r -- "nested vared created a transcript"
        exit 37
      }

      while zpty -r living-prompt chunk; do trace+=$chunk; done
      [[ $trace == *CONTEXT* && $trace == *PROJECT* && $trace == *PATH* &&
         $trace == *GIT* && $trace == *"Option-I"* &&
         $trace == *"›"* && $trace == *_prompt_test_command* ]] || {
        print -u2 -r -- "semantic living-prompt paint is missing from PTY trace"
        exit 38
      }
      local enter=${terminfo[smcup]:-} leave=${terminfo[rmcup]:-}
      [[ -z $enter || $trace != *"$enter"* ]] || exit 39
      [[ -z $leave || $trace != *"$leave"* ]] || exit 40
      [[ $trace != *$'"'"'\e[2J'"'"'* && $trace != *$'"'"'\e[3J'"'"'* &&
         $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 41
    } always {
      zpty -d living-prompt 2>/dev/null
      exec {event_fd}>&-
    }
    print -r -- native-living-prompt
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN" "$project") || return

  test_assert_equal native-living-prompt "$output"
}
test_case 'living prompt native ZLE journey paints Context and live interaction lenses then an exact ghost-free transcript' \
  _test_living_prompt_native_lens_transcript_and_manual_toggle

_test_living_prompt_native_resize_reflows_cached_facts() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local project="$TEST_TMP_DIR/home/a-deliberately-long-workspace-name/project"
  local output=''

  command mkdir -p -- "$home/.zsh.addons/private" "$project" || return
  command ln -s "$TEST_REPO_ROOT/.zshrc" "$home/.zshrc" || return
  test_write_file "$project/.fixture-project" '' || return
  command git init -q "$project" || return
  command git -C "$project" config user.name 'Zsh Tests' || return
  command git -C "$project" config user.email 'zsh-tests.invalid@example.invalid' || return
  command git -C "$project" add .fixture-project || return
  command git -C "$project" commit -qm baseline || return
  command git -C "$project" branch -M feature/cache-safe-resize || return
  command mkfifo "$home/events" || return

  test_write_file "$home/.zsh.addons/local/init.zsh" '
typeset -ga PROMPT_PROJECT_MARKERS=(.fixture-project)
typeset -ga PROMPT_PROJECT_CONTEXT_FUNCTIONS=(_prompt_test_extra_context)
_prompt_test_extra_context() {
  prompt_add_project_segment "swift 6.4"
  prompt_add_project_segment "swiftpm"
  prompt_add_project_segment "a-long-optional-project-fact"
}
HISTFILE=/dev/null
' || return
  test_write_file "$home/.zsh.addons/private/.zsh.living-prompt-resize-observer" '
zmodload zsh/parameter || return 1
typeset -gi _PROMPT_TEST_EVENT_FD=0
typeset -gi _PROMPT_TEST_GIT_CALLS=0
typeset -gi _PROMPT_TEST_PROJECT_CALLS=0
typeset -gi _PROMPT_TEST_PROVIDERS_LOCKED=0
exec {_PROMPT_TEST_EVENT_FD}<> "$HOME/events" || return 1

_prompt_test_emit() {
  print -r -u $_PROMPT_TEST_EVENT_FD -- "$1"
}
_prompt_test_state_event() {
  local kind=$1 rendered="" event_buffer="" rendered_prompt=""
  local -i prompt_rows=1
  print -P -v rendered -r -- "$PROMPT"
  rendered_prompt=$rendered
  rendered=${(V)rendered}
  event_buffer=${(V)BUFFER}
  [[ -n $event_buffer ]] || event_buffer="<empty>"
  prompt_rows=${#${(f)rendered_prompt}}
  (( prompt_rows > 0 )) || prompt_rows=1
  _prompt_test_emit "$kind|$COLUMNS|$LINES|${_PROMPT_VIEW:-missing}|${_PROMPT_LENS_PINNED:-0}|$event_buffer|$CURSOR|$prompt_rows|$_PROMPT_TEST_GIT_CALLS|$_PROMPT_TEST_PROJECT_CALLS|$rendered"
}

if (( ${+functions[_prompt_git]} )); then
  functions[_prompt_test_original_git]=${functions[_prompt_git]}
  _prompt_git() {
    (( _PROMPT_TEST_PROVIDERS_LOCKED )) && _prompt_test_emit BAD-PROVIDER-GIT
    (( ++_PROMPT_TEST_GIT_CALLS ))
    _prompt_test_original_git "$@"
  }
fi
if (( ${+functions[_prompt_project_context]} )); then
  functions[_prompt_test_original_project]=${functions[_prompt_project_context]}
  _prompt_project_context() {
    (( _PROMPT_TEST_PROVIDERS_LOCKED )) && _prompt_test_emit BAD-PROVIDER-PROJECT
    (( ++_PROMPT_TEST_PROJECT_CALLS ))
    _prompt_test_original_project "$@"
  }
fi

_prompt_test_line_init() {
  _prompt_test_state_event INIT
  _PROMPT_TEST_PROVIDERS_LOCKED=1
}
_prompt_test_pre_redraw() { _prompt_test_state_event REDRAW; }
_prompt_test_probe() { _prompt_test_state_event PROBE; }

autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-init _prompt_test_line_init
add-zle-hook-widget line-pre-redraw _prompt_test_pre_redraw
zle -N prompt-test-resize-probe _prompt_test_probe
bindkey "^X^Z" prompt-test-resize-probe

# Observe the real refresh requested by the installed WINCH handler. The
# wrapper is installed after widget registration and delegates every operation
# to ZLE before recording the post-refresh state.
zle() {
  local operation=${1:-}
  builtin zle "$@"
  local -i zle_status=$?
  [[ $operation == -R ]] && _prompt_test_state_event PAINT
  return $zle_status
}
_prompt_test_emit "SOURCE|$(command tty)"
:' || return

  output=$(test_run_interactive "$home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.prompt"
    for capability in _prompt_editing_started _prompt_layout _prompt_project_layout \
        _prompt_git _prompt_project_context TRAPWINCH; do
      (( ${+functions[$capability]} )) || {
        print -u2 -r -- "missing living prompt resize capability: $capability"
        exit 90
      }
    done

    zmodload zsh/zpty || exit 1
    zmodload zsh/zselect || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local event="" chunk="" trace="" all_events="" pty_fd=0 device=""

    _living_prompt_resize_driver() {
      builtin cd -- "$2" || return 1
      command stty rows 30 cols 140 || return 2
      exec env -i PATH="$PATH" HOME="$HOME" ZDOTDIR="$HOME" \
        TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" LC_ALL=en_US.UTF-8 \
        "$1" -di
    }
    _living_prompt_resize_expect() {
      local wanted=$1
      while zselect -r $event_fd $pty_fd -t 500; do
        while zpty -r living-prompt-resize chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          all_events+="$event"$'"'"'\n'"'"'
          if [[ $event == BAD-* ]]; then
            print -u2 -r -- "resize reread a locked provider: $event"
            return 2
          fi
          [[ $event == "$wanted"* ]] && return 0
        fi
      done
      while zpty -r living-prompt-resize chunk; do trace+=$chunk; done
      print -u2 -r -- "expected resize event ${(qqq)wanted}; last=${(qqq)event}"
      print -u2 -r -- "resize PTY trace: ${(V)trace[-1200,-1]}"
      return 1
    }
    _living_prompt_resize_probe() {
      zpty -w -n living-prompt-resize $'"'"'\x18\x1a'"'"'
      _living_prompt_resize_expect "PROBE|$1" || return
    }

    zpty -b living-prompt-resize _living_prompt_resize_driver "$2" "$3" || exit 3
    pty_fd=$REPLY
    {
      _living_prompt_resize_expect "SOURCE|" || exit 4
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 5
      _living_prompt_resize_expect "INIT|140|30|lens|0|<empty>|0|" || exit 6
      _living_prompt_resize_probe "140|30|lens|0|<empty>|0|" || exit 7
      local -a fields=("${(@s:|:)event}")
      [[ $fields[9] == 1 && $fields[10] == 1 ]] || {
        print -u2 -r -- "initial providers were not captured exactly once: $event"
        exit 8
      }
      (( fields[8] > 2 )) || exit 9
      local wide_render=$fields[11]
      [[ $wide_render == *CONTEXT* && $wide_render == *PROJECT* &&
         $wide_render == *PATH* && $wide_render == *GIT* &&
         $wide_render == *TOOLCHAIN* ]] || exit 10

      # A real kernel resize must repaint the current lens from cached facts.
      # With only two body slots, PATH and GIT are the rows that survive.
      command stty rows 5 cols 55 < "$device" || exit 11
      _living_prompt_resize_expect "PAINT|55|5|lens|0|<empty>|0|" || exit 12
      fields=("${(@s:|:)event}")
      [[ $fields[9] == 1 && $fields[10] == 1 &&
         $fields[11] == *PATH* && $fields[11] == *GIT* ]] || exit 13

      command stty rows 30 cols 140 < "$device" || exit 14
      _living_prompt_resize_expect "PAINT|140|30|lens|0|<empty>|0|" || exit 15
      fields=("${(@s:|:)event}")
      [[ $fields[9] == 1 && $fields[10] == 1 &&
         $fields[11] == "$wide_render" ]] || {
        print -u2 -r -- "wide resize did not restore the same cached lens: $event"
        exit 16
      }

      # Typing consumes the automatic Context lens and opens the interaction
      # lens. Further resizes keep the draft without rereading providers.
      zpty -w -n living-prompt-resize x
      _living_prompt_resize_expect "REDRAW|140|30|compact|0|x|1|" || exit 17
      _living_prompt_resize_probe "140|30|compact|0|x|1|" || exit 18
      fields=("${(@s:|:)event}")
      (( fields[8] > 2 )) && [[ $fields[11] == *"╭─ RUN"* &&
         $fields[11] == *"COMMAND TEXT"*x* ]] || exit 19
      command stty rows 20 cols 70 < "$device" || exit 20
      _living_prompt_resize_expect "PAINT|70|20|compact|0|x|1|" || exit 21
      fields=("${(@s:|:)event}")
      [[ $fields[9] == 1 && $fields[10] == 1 ]] || exit 22
      (( fields[8] > 2 )) && [[ $fields[11] == *"╭─ RUN"* &&
         $fields[11] == *"COMMAND TEXT"*x* ]] || exit 23

      while zpty -r living-prompt-resize chunk; do trace+=$chunk; done
      [[ $all_events != *BAD-PROVIDER-* ]] || exit 24
      local enter=${terminfo[smcup]:-} leave=${terminfo[rmcup]:-}
      [[ -z $enter || $trace != *"$enter"* ]] || exit 25
      [[ -z $leave || $trace != *"$leave"* ]] || exit 26
      [[ $trace != *$'"'"'\e[2J'"'"'* && $trace != *$'"'"'\e[3J'"'"'* &&
         $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 27
    } always {
      zpty -d living-prompt-resize 2>/dev/null
      exec {event_fd}>&-
    }
    print -r -- cached-resize
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN" "$project") || return

  test_assert_equal cached-resize "$output"
}
test_case 'living prompt native resize reflows the interaction lens from cached facts without provider discovery' \
  _test_living_prompt_native_resize_reflows_cached_facts
