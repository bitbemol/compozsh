# Integration coverage for requirement capture and ordinary prompt presentation.
_test_runtime_prompt_go_workspace() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/go.work" $'go 1.24.0\nuse ./service\n' || return
  test_write_file "$TEST_TMP_DIR/project/service/go.mod" $'module example.invalid/service\ngo 1.24.0\n' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    builtin cd "$2" || exit 1
    _prompt_runtime_version() { REPLY=1.23.0; }
    local phase name
    for phase in ordinary saturated; do
      if [[ $phase == saturated ]]; then
        for name in {1..130}; do : > "entry-$name"; done
      fi
      _prompt_project_context
      [[ $_PROMPT_PROJECT_ROOT_TEXT == "$2" ]] || {
        print -u2 -- "$phase: workspace root not retained"; exit 2
      }
      [[ ${(j:|:)_PROMPT_PROJECT_ITEMS} == *"go requires ≥ 1.24.0 · using 1.23.0 — older"* ]] || {
        print -u2 -- "$phase: workspace minimum warning absent"; exit 3
      }
    done
    print detected
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project") || return
  test_assert_equal detected "$output"
}
test_case 'runtime prompt detects Go workspace requirements in ordinary and saturated roots' _test_runtime_prompt_go_workspace

_test_runtime_prompt_ready_toolchain() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/project/.swift-version" '6.3.2' || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    TERM=dumb
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    builtin cd "$2" || exit 1
    _prompt_runtime_version() { REPLY=6.4; }
    COLUMNS=199 LINES=47 BUFFER=""
    _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 2
    BUFFER=ls
    _prompt_editing_started || :
    _prompt_prepare_transcript
    BUFFER=""
    _prompt_update
    local rendered row version_start path_start columns escape
    printf -v escape "\033"
    print -P -v rendered -r -- "$PROMPT"
    setopt extendedglob
    rendered=${rendered//$escape\[[0-9\;]##m/}
    [[ $_PROMPT_VIEW == compact && $rendered == *READY* &&
       $rendered == *TOOLCHAIN*"swift 6.4"* &&
       $rendered == *"using 6.4 — newer"* ]] || {
      print -u2 -- "READY lost captured toolchain or warning"; exit 3
    }
    for row in "${(@f)rendered}"; do
      [[ $row != *TOOLCHAIN* ]] || version_start=${row%%swift*}
      [[ $row != *PATH* ]] || path_start=${row%%/*}
    done
    (( ${#version_start} == ${#path_start} )) || {
      print -u2 -- "toolchain and ordinary values use different columns"; exit 4
    }
    # Repaint/resize only consumes captured values, including a cleared draft.
    _prompt_project_context() { print -u2 unexpected-project-read; return 99; }
    _runtime_read_metadata() { print -u2 unexpected-metadata-read; return 99; }
    _prompt_runtime_version() { print -u2 unexpected-runtime-read; return 99; }
    for columns in 40 20 199; do
      COLUMNS=$columns
      _prompt_interaction_update || :
      print -P -v rendered -r -- "$PROMPT"
      rendered=${rendered//$escape\[[0-9\;]##m/}
      for row in "${(@f)rendered}"; do
        (( ${(m)#row} <= COLUMNS )) || exit 5
      done
    done
    [[ $rendered == *"using 6.4 — newer"* ]] || exit 6
    # The added row must not displace an existing last outcome in a tall view.
    _PROMPT_GIT_TEXT="main" _PROMPT_ENV_TEXT="fixture-env"
    _PROMPT_LAST_OUTCOME_TEXT="× exit 1"
    _prompt_interaction_update || :
    [[ $PROMPT == *TOOLCHAIN* && $PROMPT == *LAST*"× exit 1"* &&
       $PROMPT == *ENV*fixture-env* ]] || {
      print -u2 "toolchain displaced existing outcome/environment"; exit 8
    }
    _PROMPT_PROJECT_ITEMS=() _PROMPT_PROJECT_ITEM_WIDTHS=()
    _prompt_interaction_update || :
    [[ $PROMPT != *TOOLCHAIN* ]] || exit 7
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project"
}
test_case 'runtime prompt retains toolchain in READY after acceptance and captured-only resize' _test_runtime_prompt_ready_toolchain

_test_runtime_prompt_native_clear() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/home/project/.swift-version" '6.3.2' || return
  command mkfifo "$TEST_TMP_DIR/home/events" || return
  test_write_file "$TEST_TMP_DIR/home/.zshrc" '
HISTFILE=/dev/null
exec {event_fd}<> "$HOME/events"
source "$RUNTIME_TEST_ROOT/.zsh.addons/.zsh.prompt"
source "$RUNTIME_TEST_ROOT/.zsh.addons/.zsh.editor"
for support_component in "$RUNTIME_TEST_ROOT/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
source "$RUNTIME_TEST_ROOT/.zsh.addons/support/.zsh.appearance"
_prompt_runtime_version() { REPLY=6.4; }
_runtime_frame() {
  local visible=0
  [[ $PROMPT == *TOOLCHAIN* && $PROMPT == *"using 6.4 — newer"* ]] && visible=1
  print -r -u $event_fd -- "FRAME|$BUFFER|$_PROMPT_VIEW|$_PROMPT_INTERACTION_KIND|$visible|$COLUMNS"
}
add-zle-hook-widget line-pre-redraw _runtime_frame
add-zle-hook-widget line-init _runtime_frame
zle -N runtime-probe _runtime_frame
bindkey "^X^Z" runtime-probe
print -r -u $event_fd -- "SOURCE|$(command tty)"
' || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 RUNTIME_TEST_ROOT=$2
    zmodload zsh/zpty
    zmodload zsh/zselect
    exec {event_fd}<> "$HOME/events"
    local event="" trace="" chunk="" device="" pfd=0
    _runtime_driver() {
      builtin cd "$HOME/project"
      command stty rows 30 cols 199
      exec "$1" -di
    }
    _runtime_expect() {
      while zselect -r $event_fd $pfd -t 300; do
        while zpty -r runtime-clear chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          [[ $event == "$1" ]] && return 0
        fi
      done
      print -u2 -r -- "expected $1; got $event; ${(V)trace[-500,-1]}"
      return 1
    }
    zpty -b runtime-clear _runtime_driver "$1"
    pfd=$REPLY
    {
      while IFS= read -r -t 3 -u $event_fd event; do
        [[ $event == SOURCE\|* ]] && break
      done
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 1
      _runtime_expect "FRAME||lens|ready|1|199" || exit 2
      zpty -w -n runtime-clear ls
      _runtime_expect "FRAME|ls|compact|run|0|199" || exit 3
      zpty -w -n runtime-clear $'"'"'\r'"'"'
      _runtime_expect "FRAME||compact|ready|1|199" || exit 4
      zpty -w runtime-clear clear
      _runtime_expect "FRAME||compact|ready|1|199" || exit 5
      command stty rows 16 cols 40 < "$device"
      zpty -w -n runtime-clear $'"'"'\x18\x1a'"'"'
      _runtime_expect "FRAME||compact|ready|0|40" || exit 6
      command stty rows 30 cols 199 < "$device"
      zpty -w -n runtime-clear $'"'"'\x18\x1a'"'"'
      _runtime_expect "FRAME||compact|ready|1|199" || exit 7
      [[ $trace == *TOOLCHAIN* && $trace == *"using 6.4 — newer"* &&
         $trace != *"command not found"* && $trace != *"bad pattern"* ]] || exit 8
    } always {
      zpty -d runtime-clear
      exec {event_fd}>&-
    }
  ' "$TEST_ZSH_BIN" "$TEST_REPO_ROOT"
}
test_case 'runtime prompt native command clear and resize preserve READY toolchain' _test_runtime_prompt_native_clear
