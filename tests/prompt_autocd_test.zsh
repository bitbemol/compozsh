_test_prompt_autocd_native_semantics() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/program" '#!/bin/sh
printf executed'
  chmod +x "$TEST_TMP_DIR/home/program"
  mkdir -p "$TEST_TMP_DIR/home/folder" "$TEST_TMP_DIR/home/collision"
  mkfifo "$TEST_TMP_DIR/home/events"
  test_write_file "$TEST_TMP_DIR/home/.zshrc" '
setopt AUTO_CD
HISTFILE=/dev/null
exec {event_fd}<> "$HOME/events"
source "$AUTOCD_TEST_ROOT/.zsh.addons/.zsh.prompt"
source "$AUTOCD_TEST_ROOT/.zsh.addons/.zsh.editor"
source "$AUTOCD_TEST_ROOT/.zsh.addons/.zsh.highlighting"
source "$AUTOCD_TEST_ROOT/.zsh.addons/support/.zsh.appearance"
precmd() { local result=$?; print -r -u $event_fd -- "READY|$PWD|$result"; }
collision() { print -r -u $event_fd COLLISION; }
_autocd_frame() {
  print -r -u $event_fd -- "FRAME|$BUFFER|$_PROMPT_INTERACTION_KIND|$COLUMNS|$CURSOR"
}
add-zle-hook-widget line-pre-redraw _autocd_frame
zle -N autocd-probe _autocd_frame
bindkey "^X^Z" autocd-probe
print -r -u $event_fd -- "SOURCE|$(command tty)"
'
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    zmodload zsh/zpty
    zmodload zsh/zselect
    exec {event_fd}<> "$HOME/events"
    local event="" trace="" chunk="" device="" pfd=0
    _autocd_driver() {
      cd "$HOME"
      command stty rows 30 cols 120
      export AUTOCD_TEST_ROOT=$2
      exec "$1" -di
    }
    _autocd_expect() {
      while zselect -r $event_fd $pfd -t 300; do
        while zpty -r autocd chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          [[ $event == "$1"* ]] && return 0
        fi
      done
      print -u2 -r -- "expected $1; got $event; ${(V)trace[-500,-1]}"
      return 1
    }
    zpty -b autocd _autocd_driver "$1" "$2"
    pfd=$REPLY
    {
      _autocd_expect "SOURCE|" || exit 1
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 11
      _autocd_expect "READY|$HOME|0" || exit 12
      zpty -w -n autocd ./folder
      _autocd_expect "FRAME|./folder|navigate|120|8" || exit 13
      command stty rows 16 cols 40 < "$device"
      zpty -w -n autocd $'"'"'\x18\x1a'"'"'
      _autocd_expect "FRAME|./folder|navigate|40|8" || exit 14
      [[ $trace == *NAVIGATE* && $trace == *DESTINATION* ]] || exit 15
      zpty -w -n autocd $'"'"'\r'"'"'
      _autocd_expect "READY|$HOME/folder|0" || exit 2
      zpty -w autocd "cd .."
      _autocd_expect "READY|$HOME|0" || exit 3
      zpty -w autocd collision
      _autocd_expect COLLISION || exit 4
      _autocd_expect "READY|$HOME|0" || exit 5
      zpty -w autocd ./program
      _autocd_expect "READY|$HOME|0" || exit 6
      [[ $trace == *executed* ]] || exit 7
      zpty -w autocd "./folder extra"
      _autocd_expect "READY|$HOME|126" || exit 8
      zpty -w autocd "unsetopt AUTO_CD"
      _autocd_expect "READY|$HOME|0" || exit 9
      zpty -w autocd ./folder
      _autocd_expect "READY|$HOME|126" || exit 10
    } always {
      zpty -d autocd
      exec {event_fd}>&-
    }
  ' "$TEST_ZSH_BIN" "$TEST_REPO_ROOT"
}
test_case 'bare directory navigation follows native AUTO_CD without overriding commands' _test_prompt_autocd_native_semantics

_test_prompt_autocd_snapshot() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/support/.zsh.appearance"
    setopt AUTO_CD
    mkdir -p "$HOME/folder" "$HOME/space dir" "$HOME/collision" "$HOME/printf" "$HOME/g"
    ln -s folder "$HOME/link"
    cd "$HOME"
    local BUFFER="" CURSOR=0 REGION_ACTIVE=0 draft="" rendered=""
    local -a region_highlight=()
    _PROMPT_FULL_PATH_TEXT="~" COLUMNS=120 LINES=30
    for draft in ./folder folder ./link "~/folder" "~" ../ "\"./space dir\"" "./space\\ dir" g; do
      BUFFER=$draft CURSOR=${#draft}
      _zle_syntax_highlight
      _prompt_interaction_update "$BUFFER" || :
      [[ $_PROMPT_INTERACTION_KIND == navigate ]] || {
        print -u2 -r -- "expected NAVIGATE for $draft, got $_PROMPT_INTERACTION_KIND"; exit 1
      }
      [[ $_PROMPT_INTERACTION_VALUES[${_PROMPT_INTERACTION_LABELS[(i)DESTINATION TEXT]}] == "${(Q)draft}" ]] || exit 2
      [[ $_PROMPT_INTERACTION_VALUES[${_PROMPT_INTERACTION_LABELS[(i)ACTION]}] == *AUTO_CD* ]] || exit 3
      [[ ${(j:|:)region_highlight} == *"$ZSH_HIGHLIGHT_STYLES[directory]"* ||
         ${(j:|:)region_highlight} == *"$ZSH_HIGHLIGHT_STYLES[symlink-directory]"* ]] || exit 4
      print -P -v rendered -r -- "$PROMPT"
      [[ $rendered == *NAVIGATE* && $rendered == *DESTINATION* ]] || exit 5
    done
    collision() { :; }
    alias folder="print collision"
    alias -s special="print suffix"
    mkdir "$HOME/suffix.special"
    for draft in collision folder printf /bin/zsh ./missing ./suffix.special "./folder extra" "command ./folder" "./folder && pwd" "./folder > file" "./folder/*"; do
      BUFFER=$draft
      _zle_syntax_highlight
      _prompt_interaction_update "$BUFFER" || :
      [[ $_PROMPT_INTERACTION_KIND != navigate ]] || { print -u2 -r -- "false navigation: $draft"; exit 6; }
    done
    BUFFER=./folder
    unsetopt AUTO_CD
    _zle_syntax_highlight
    _prompt_interaction_update "$BUFFER" || :
    [[ $_PROMPT_INTERACTION_KIND == run ]] || exit 7
    setopt AUTO_CD
    _zle_syntax_highlight
    _prompt_interaction_update "$BUFFER" || :
    [[ $_PROMPT_INTERACTION_KIND == navigate ]] || exit 8
    # Prompt-only redraw consumes the exact snapshot, never the path provider.
    _zle_path_category() { print -u2 unexpected-path-read; return 99; }
    COLUMNS=40
    _prompt_interaction_update "$BUFFER" || :
    [[ $_PROMPT_INTERACTION_KIND == navigate ]] || exit 9
    BUFFER=./different
    _prompt_interaction_update "$BUFFER" || :
    [[ $_PROMPT_INTERACTION_KIND == run ]] || exit 10
    BUFFER=./folder
    cd "$HOME/folder"
    _prompt_interaction_update "$BUFFER" || :
    [[ $_PROMPT_INTERACTION_KIND == run ]] || exit 11
    # Clearing/skipping decoration must not expose a previous draft fact.
    cd "$HOME"
    BUFFER=./folder REGION_ACTIVE=1
    _zle_syntax_highlight
    _prompt_interaction_update "$BUFFER" || :
    [[ $_PROMPT_INTERACTION_KIND == run ]] || exit 12
  ' "$TEST_REPO_ROOT"
}
test_case 'bare directory navigation lens reuses exact highlighter facts and rejects stale or ambiguous drafts' _test_prompt_autocd_snapshot
