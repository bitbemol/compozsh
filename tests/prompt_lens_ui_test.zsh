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
  local -a rendered_rows=("${(@f)rendered_prompt}")
  prompt_rows=${#rendered_rows}
  (( prompt_rows > 0 )) || prompt_rows=1
  _prompt_test_text "$rendered_prompt"; event_rendered=$REPLY
  _prompt_test_emit "$kind|${_PROMPT_VIEW:-missing}|${_PROMPT_LENS_PINNED:-0}|$event_buffer|$CURSOR|$prompt_rows|${_ZLE_AUTOSUGGEST_SUSPENDED:-0}|$event_predisplay|$event_postdisplay|${CONTEXT:-none}|$event_prompt|$event_rprompt|$event_rendered|$_PROMPT_LAST_OUTCOME_TEXT|$_PROMPT_COMMAND_STARTED"
}
_prompt_test_preexec() { _prompt_test_emit COMMAND-STARTED; }
preexec_functions+=(_prompt_test_preexec)
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
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    # Fail before starting a PTY when the feature is absent, so the red phase is
    # a direct capability failure rather than an event timeout.
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.prompt"
    for capability in _prompt_interaction_update _prompt_prepare_transcript _prompt_toggle_lens \
        _zle_prompt_pre_redraw _zle_prompt_line_finish _zle_prompt_toggle_widget; do
      (( ${+functions[$capability]} )) || {
        print -u2 -r -- "missing living prompt capability: $capability"
        exit 90
      }
    done

    source "$1/tests/pty_support.zsh" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local event="" chunk="" trace="" all_events="" device=""

    _living_prompt_driver() {
      builtin cd -- "$2" || return 1
      exec env -i PATH="$PATH" HOME="$HOME" ZDOTDIR="$HOME" \
        TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" LC_ALL=en_US.UTF-8 \
        "$1" -di
    }
    _living_prompt_expect() {
      { test_pty_expect -p living-prompt $event_fd "$1" } always {
        trace+=$TEST_PTY_OUTPUT
        if (( ${#TEST_PTY_EVENTS} )); then
          event=${TEST_PTY_EVENTS[-1]}
          all_events+=${(F)TEST_PTY_EVENTS}$'"'"'\n'"'"'
        fi
      }
    }
    _living_prompt_probe() {
      zpty -w -n living-prompt $'"'"'\x18\x1a'"'"'
      _living_prompt_expect "PROBE|$1|" || return
    }

    test_pty_start living-prompt _living_prompt_driver "$2" "$3" || exit 3
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

      # Empty Return leaves a one-row receipt, without a command or new outcome.
      # Observe through the separate event pipe so synchronization cannot erase
      # or reposition the terminal frame being tested.
      local last_outcome=$fields[14] blank="" expected_buffer="" accepted_trace=""
      local -i trace_start=0 events_start=0
      for blank in "" "" "         "; do
        trace_start=${#trace} events_start=${#all_events}
        [[ -z $blank ]] || zpty -w -n living-prompt "$blank"
        zpty -w -n living-prompt $'"'"'\r'"'"'
        expected_buffer=${blank:-<empty>}
        _living_prompt_expect "FINISH|transcript|0|$expected_buffer|" || exit 47
        fields=("${(@s:|:)event}")
        [[ $fields[6] == 1 && $fields[8] == "<empty>" &&
           $fields[9] == "<empty>" && $fields[11] == "%D{%H:%M} › " &&
           $fields[12] == "<empty>" && $fields[13] != *[╭│╰]* ]] || { print -u2 -r -- "bad empty receipt: $event"; exit 48; }
        _living_prompt_expect "INIT|compact|0|<empty>|0|" || exit 50
        fields=("${(@s:|:)event}")
        [[ $fields[14] == "$last_outcome" && ${all_events[$((events_start+1)),-1]} != *COMMAND-STARTED* ]] &&
          (( fields[15] == 0 )) || { print -u2 -r -- "empty execution changed state: $event; $all_events"; exit 51; }
        _living_prompt_probe compact || exit 52
        while zpty -r living-prompt chunk; do trace+=$chunk; done
        accepted_trace=${trace[$((trace_start+1)),-1]}
        [[ $accepted_trace == *"›"* && $accepted_trace == *$'"'"'\e[J'"'"'* ]] || { print -u2 -r -- "missing empty repaint: ${(V)accepted_trace}"; exit 49; }
      done

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
      # No alternate screen and no full-screen clear.
      test_pty_screen_sessions "$trace" 0 || exit 39
      [[ $trace != *$'"'"'\e[3J'"'"'* &&
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
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.prompt"
    for capability in _prompt_interaction_update _prompt_layout \
        _prompt_git _prompt_project_context TRAPWINCH; do
      (( ${+functions[$capability]} )) || {
        print -u2 -r -- "missing living prompt resize capability: $capability"
        exit 90
      }
    done

    source "$1/tests/pty_support.zsh" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local event="" chunk="" trace="" all_events="" device=""

    _living_prompt_resize_driver() {
      builtin cd -- "$2" || return 1
      command stty rows 30 cols 140 || return 2
      exec env -i PATH="$PATH" HOME="$HOME" ZDOTDIR="$HOME" \
        TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" LC_ALL=en_US.UTF-8 \
        "$1" -di
    }
    _living_prompt_resize_expect() {
      { test_pty_expect -p living-prompt-resize $event_fd "$1" } always {
        trace+=$TEST_PTY_OUTPUT
        if (( ${#TEST_PTY_EVENTS} )); then
          event=${TEST_PTY_EVENTS[-1]}
          all_events+=${(F)TEST_PTY_EVENTS}$'"'"'\n'"'"'
          [[ $event != BAD-* ]] || print -u2 -r -- "resize reread a locked provider: $event"
        fi
      }
    }
    _living_prompt_resize_probe() {
      zpty -w -n living-prompt-resize $'"'"'\x18\x1a'"'"'
      _living_prompt_resize_expect "PROBE|$1" || return
    }

    test_pty_start living-prompt-resize _living_prompt_resize_driver "$2" "$3" || exit 3
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
      # No alternate screen and no full-screen clear.
      test_pty_screen_sessions "$trace" 0 || exit 25
      [[ $trace != *$'"'"'\e[3J'"'"'* &&
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

_test_editor_autosuggestion_line_finish_everywhere() {
  test_make_temp_dir || return
  local observer='
zmodload zsh/parameter || return 1
typeset -gi _PROMPT_TEST_EVENT_FD=0
exec {_PROMPT_TEST_EVENT_FD}<> "$HOME/events" || return 1

# Hooks added here run after the editor peer hooks, so each event reports
# the state that Zsh paints after the editor has finished with the line.
_prompt_test_ghost_event() {
  local event_buffer=${(V)BUFFER} event_postdisplay=${(V)POSTDISPLAY}
  local event_highlight=${(V)${(j:;:)region_highlight}}
  print -r -u $_PROMPT_TEST_EVENT_FD -- "$1|${CONTEXT:-none}|${event_buffer:-<empty>}|${event_postdisplay:-<empty>}|${event_highlight:-<empty>}"
}
_prompt_test_ghost_init() { _prompt_test_ghost_event INIT; }
_prompt_test_ghost_redraw() { _prompt_test_ghost_event REDRAW; }
_prompt_test_ghost_finish() { _prompt_test_ghost_event FINISH; }
_prompt_test_command() { print -r -u $_PROMPT_TEST_EVENT_FD -- EXECUTED; }

autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-init _prompt_test_ghost_init
add-zle-hook-widget line-pre-redraw _prompt_test_ghost_redraw
add-zle-hook-widget line-finish _prompt_test_ghost_finish
print -s -- "_prompt_test_command-GHOST"
print -r -u $_PROMPT_TEST_EVENT_FD -- SOURCE
:'
  # Type a history prefix, press Return and require the finish-time editor
  # state, which Zsh paints into scrollback, to hold no unaccepted tail.
  local journey='
    source "$3/tests/pty_support.zsh" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local event="" trace="" context=start enter=$'"'"'\r'"'"'

    _ghost_finish_driver() {
      builtin cd -- "$HOME" || return 1
      exec env -i PATH="$PATH" HOME="$HOME" ZDOTDIR="$HOME" \
        TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" LC_ALL=en_US.UTF-8 \
        "$1" -di
    }
    _ghost_finish_expect() {
      {
        test_pty_expect -p ghost-finish $event_fd "$1" || {
          print -u2 -r -- "$2: expected event prefix ${(qqq)1}"
          return 1
        }
      } always {
        trace+=$TEST_PTY_OUTPUT
        (( ${#TEST_PTY_EVENTS} )) && event=${TEST_PTY_EVENTS[-1]}
      }
    }

    test_pty_start ghost-finish _ghost_finish_driver "$1" || exit 3
    {
      _ghost_finish_expect SOURCE "$2" || exit 4
      _ghost_finish_expect "INIT|start|<empty>|" "$2" || exit 5
      if [[ $2 == continuation ]]; then
        context=cont
        zpty -w -n ghost-finish "if true; then$enter"
        _ghost_finish_expect "FINISH|start|if true; then|" "$2" || exit 6
        _ghost_finish_expect "INIT|cont|<empty>|" "$2" || exit 7
      fi
      zpty -w -n ghost-finish _prompt_test_command
      _ghost_finish_expect "REDRAW|$context|_prompt_test_command|-GHOST|" "$2" || exit 8
      [[ $event == *memo=my-zsh-autosuggestion* ]] || {
        print -u2 -r -- "$2: suggestion was not highlighted: $event"
        exit 9
      }
      zpty -w -n ghost-finish "$enter"
      _ghost_finish_expect "FINISH|$context|_prompt_test_command|" "$2" || exit 10
      local -a fields=("${(@s:|:)event}")
      [[ $fields[4] == "<empty>" && $fields[5] != *memo=my-zsh-autosuggestion* ]] || {
        print -u2 -r -- "$2: line finish kept the unaccepted suggestion: $event"
        exit 11
      }
      [[ $context == start ]] || zpty -w -n ghost-finish "fi$enter"
      _ghost_finish_expect EXECUTED "$2" || exit 12
    } always {
      zpty -d ghost-finish 2>/dev/null
      exec {event_fd}>&-
    }
    print -r -- "ghost-free $2"
  '
  local alone="$TEST_TMP_DIR/alone" full="$TEST_TMP_DIR/full"
  local alone_output='' full_output=''

  # A prompt-less install: only the editor peer and the observer.
  command mkdir -p -- "$alone" || return
  command mkfifo "$alone/events" || return
  test_write_file "$alone/observer.zsh" "$observer" || return
  test_write_file "$alone/.zshrc" "
source ${(q)TEST_REPO_ROOT}/.zsh.addons/.zsh.editor
source ${(q)alone}/observer.zsh
" || return

  # The full shipped configuration on a continuation (PS2) line.
  command mkdir -p -- "$full/.zsh.addons/private" || return
  command ln -s "$TEST_REPO_ROOT/.zshrc" "$full/.zshrc" || return
  command mkfifo "$full/events" || return
  test_write_file "$full/.zsh.addons/local/init.zsh" 'HISTFILE=/dev/null' || return
  test_write_file "$full/.zsh.addons/private/.zsh.ghost-finish-observer" "$observer" || return

  # Run both journeys before asserting so a failure reports each install.
  alone_output=$(test_run_interactive "$alone" "$journey" "$TEST_ZSH_BIN" prompt-less "$TEST_REPO_ROOT") ||
    alone_output+=" (exit $?)"
  full_output=$(test_run_interactive "$full" "$journey" "$TEST_ZSH_BIN" continuation "$TEST_REPO_ROOT") ||
    full_output+=" (exit $?)"
  test_assert_equal 'ghost-free prompt-less' "$alone_output" || return
  test_assert_equal 'ghost-free continuation' "$full_output"
}
test_case 'editor removes its unaccepted autosuggestion at every line finish, including continuation lines and prompt-less installs' \
  _test_editor_autosuggestion_line_finish_everywhere

# An explicit in-widget directory change is a fact-capture boundary: after
# Browse's Change directory the captured facts, the repainted prompt and the
# window title describe the new folder and its repository. The draft stays,
# and no precmd, receipt or history entry is produced.
_test_living_prompt_recaptures_after_browse_change_directory() {
  test_make_temp_dir || return
  # Resolve /var to /private/var: the shell computes PWD physically.
  local home="${TEST_TMP_DIR:A}/home" target="${TEST_TMP_DIR:A}/home/work/target-dir"
  local output=''

  command mkdir -p -- "$home/.zsh.addons/private" "$target" || return
  command ln -s "$TEST_REPO_ROOT/.zshrc" "$home/.zshrc" || return
  test_write_file "$target/notes.txt" '' || return
  command git init -q "$target" || return
  command git -C "$target" config user.name 'Zsh Tests' || return
  command git -C "$target" config user.email 'zsh-tests.invalid@example.invalid' || return
  command git -C "$target" add notes.txt || return
  command git -C "$target" commit -qm baseline || return
  command git -C "$target" branch -M browse-target || return
  command mkfifo "$home/events" || return
  test_write_file "$home/.zsh.addons/local/init.zsh" 'HISTFILE=/dev/null' || return
  test_write_file "$home/.zsh.addons/private/.zsh.recapture-observer" '
typeset -gi _RECAPTURE_TEST_FD=0
exec {_RECAPTURE_TEST_FD}<> "$HOME/events" || return 1
_recapture_test_emit() { print -r -u $_RECAPTURE_TEST_FD -- "$1"; }
_recapture_test_ready() { _recapture_test_emit "READY|$PWD"; }
_recapture_test_chpwd() { _recapture_test_emit "CHPWD|$PWD"; }
precmd_functions+=(_recapture_test_ready)
chpwd_functions+=(_recapture_test_chpwd)
functions[_recapture_test_show]=$functions[_zle_picker_show]
_zle_picker_show() {
  _recapture_test_show "$@"
  local -i show_status=$?
  _recapture_test_emit "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY"
  return $show_status
}
_recapture_test_probe() {
  local rendered=""
  print -P -v rendered -r -- "$PROMPT"
  _recapture_test_emit "PROBE|$PWD|$_PROMPT_FULL_PATH_TEXT|$_PROMPT_GIT_BRANCH_TEXT|$BUFFER|${#history}|${(V)rendered}"
}
zle -N recapture-test-probe _recapture_test_probe
bindkey "^X^Z" recapture-test-probe
_recapture_test_emit SOURCE
:' || return

  output=$(test_run_interactive "$home" '
    export LC_ALL=en_US.UTF-8
    setopt EXTENDED_GLOB
    source "$1/tests/pty_support.zsh" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local event="" trace="" chunk="" after="" painted=""
    local -a events=() fields=() later=()
    local -i trace_start=0 events_start=0

    _recapture_driver() {
      builtin cd -- "$HOME/work" || return 1
      command stty rows 30 cols 120
      exec env -i PATH="$PATH" HOME="$HOME" ZDOTDIR="$HOME" \
        TERM=xterm-256color TMPDIR="${TMPDIR:-/tmp}" LC_ALL=en_US.UTF-8 \
        GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 "$1" -di
    }
    _recapture_expect() {
      { test_pty_expect -p recapture $event_fd "$1" } always {
        trace+=$TEST_PTY_OUTPUT
        events+=("${TEST_PTY_EVENTS[@]}")
        (( ${#TEST_PTY_EVENTS} )) && event=${TEST_PTY_EVENTS[-1]}
      }
    }

    test_pty_start recapture _recapture_driver "$2" || exit 3
    {
      _recapture_expect SOURCE || exit 4
      _recapture_expect "READY|$HOME/work" || exit 5
      zpty -w -n recapture ./
      zpty -w -n recapture $'"'"'\t'"'"'
      _recapture_expect "FRAME|Directory browser|" || exit 6
      zpty -w -n recapture $'"'"'\x18'"'"'
      _recapture_expect "FRAME|Folder actions|" || exit 7
      zpty -w -n recapture "change dir"
      _recapture_expect "FRAME|Folder actions|change dir" || exit 8
      trace_start=${#trace} events_start=${#events}
      zpty -w -n recapture $'"'"'\r'"'"'
      _recapture_expect "CHPWD|$HOME/work/target-dir" || exit 9
      zpty -w -n recapture $'"'"'\x18\x1a'"'"'
      _recapture_expect "PROBE|" || exit 10
      while zpty -r recapture chunk; do trace+=$chunk; done

      fields=("${(@s:|:)event}")
      [[ $fields[2] == "$HOME/work/target-dir" && $fields[5] == ./ && $fields[6] == 0 ]] || {
        print -u2 -r -- "Change directory lost the draft or wrote history: $event"
        exit 11
      }
      [[ $fields[3] == "~/work/target-dir" && $fields[4] == browse-target ]] || {
        print -u2 -r -- "living prompt kept the previous folder facts: $event"
        exit 12
      }
      painted=${(j:|:)fields[7,-1]}
      painted=${painted//\^\[\[[0-9;]#m/}
      [[ $painted == *"~/work/target-dir"* ]] || {
        print -u2 -r -- "rendered prompt names the previous folder: $painted"
        exit 13
      }
      later=("${(@)events[$(( events_start + 1 )),-1]}")
      (( ${#${(M)later:#READY|*}} == 0 )) || {
        print -u2 -r -- "the directory change ran precmd: ${(j:; :)later}"
        exit 14
      }
      after=${trace[$(( trace_start + 1 )),-1]}
      [[ $after == *$'"'"'\e]0;'"'"'*": ~/work/target-dir"$'"'"'\a'"'"'* ]] || {
        print -u2 -r -- "window title still names the previous folder: ${(V)after[-600,-1]}"
        exit 15
      }
      # Screen cleanup repaints before the action; the last frame must be new.
      after=${after//$'"'"'\e]0;'"'"'[^$'"'"'\a'"'"']#$'"'"'\a'"'"'/}
      after=${after//$'"'"'\e['"'"'[0-9;?]#[A-Za-z]/}
      painted=${after##*╭─}
      [[ $painted == *"~/work/target-dir"* && $painted == *browse-target* &&
         $painted != *" ~/work"$'"'"'\r'"'"'* ]] || {
        print -u2 -r -- "repainted prompt names the previous folder: ${(V)after[-600,-1]}"
        exit 16
      }
    } always {
      zpty -d recapture 2>/dev/null
      exec {event_fd}>&-
    }
    print -r -- recaptured
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN") || return
  test_assert_equal recaptured "$output"
}
test_case 'living prompt recaptures directory facts after a Browse Change directory action' \
  _test_living_prompt_recaptures_after_browse_change_directory

# Following a directory link is the same boundary. A manual pin survives it:
# only accepting a command clears a pinned Context lens.
_test_living_prompt_recaptures_after_entering_a_link() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" repo="$TEST_TMP_DIR/home/repos/linked-repo"
  local output=''

  command mkdir -p -- "$repo" "$home/links" || return
  test_write_file "$repo/notes.txt" '' || return
  command git init -q "$repo" || return
  command git -C "$repo" config user.name 'Zsh Tests' || return
  command git -C "$repo" config user.email 'zsh-tests.invalid@example.invalid' || return
  command git -C "$repo" add notes.txt || return
  command git -C "$repo" commit -qm baseline || return
  command git -C "$repo" branch -M link-target || return
  command ln -s ../repos/linked-repo "$home/links/linked-dir" || return

  output=$(test_run_interactive "$home" '
    source "$1/.zshrc"
    builtin cd -- "$HOME/links" || exit 1
    true; _prompt_update
    [[ $_PROMPT_FULL_PATH_TEXT == "~/links" && -z $_PROMPT_GIT_BRANCH_TEXT ]] || exit 2
    _prompt_toggle_lens || exit 3
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 1 ]] || exit 4
    local -i refreshed=0
    _zle_picker_screen_session() {
      _ZLE_PICKER_ACTION=enter-link
      _ZLE_PICKER_SELECTED_VALUE="$HOME/links/linked-dir"
    }
    zle() { [[ $1 == reset-prompt ]] && (( ++refreshed )); return 0; }
    BUFFER=draft
    _directory_browser_session ./ insert widget browse || exit 5
    [[ $PWD == "$HOME/links/linked-dir" && $BUFFER == draft && $refreshed == 1 ]] || exit 6
    [[ $_PROMPT_FULL_PATH_TEXT == "~/links/linked-dir" &&
       $_PROMPT_GIT_BRANCH_TEXT == link-target ]] || {
      print -u2 -r -- "living prompt kept the previous folder facts: $_PROMPT_FULL_PATH_TEXT|$_PROMPT_GIT_BRANCH_TEXT"
      exit 7
    }
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 1 ]] || {
      print -u2 -r -- "the directory change cleared a manual pin: $_PROMPT_VIEW|$_PROMPT_LENS_PINNED"
      exit 8
    }
    local rendered=""
    print -P -v rendered -r -- "$PROMPT"
    [[ $rendered == *"~/links/linked-dir"* && $rendered == *link-target* ]] || exit 9
    print -r -- recaptured
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal recaptured "$output"
}
test_case 'living prompt recaptures directory facts after following a directory link and keeps a manual pin' \
  _test_living_prompt_recaptures_after_entering_a_link
