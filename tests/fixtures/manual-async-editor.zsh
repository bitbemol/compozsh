# Sourced only by an isolated PTY test; provider release and observations use
# independent FIFOs so synchronization does not modify the terminal display.
command stty rows 24 cols 120
typeset fixture_device=$(command tty)
builtin cd -- "$HOME"
source "$1/.zsh.addons/.zsh.prompt"
for component in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$component"; done
source "$1/.zsh.addons/.zsh.editor"
source "$1/.zsh.addons/.zsh.manual"
source "$1/.zsh.addons/support/.zsh.appearance"
exec {fixture_events}<> "$HOME/events"
exec {fixture_release}<> "$HOME/release"
_manual_prompt_capture() {
  local release=''
  print -r -u $fixture_events STARTED
  IFS= read -r -t 10 -u $fixture_release release || return 1
  _MANUAL_SUMMARIES=(ls 'Asynchronous café description')
  _MANUAL_SOURCES=(ls 'ls(1)')
  _MANUAL_SUMMARIES_READY=1
}
_fixture_init() { print -r -u $fixture_events -- "READY|$fixture_device"; }
_fixture_probe() {
  local rendered=''
  print -P -v rendered -r -- "$PROMPT"
  print -r -u $fixture_events -- "FRAME|$COLUMNS|$BUFFER|$CURSOR|$_MANUAL_SUMMARIES_READY|${(V)rendered}"
}
_fixture_changed() {
  if (( _MANUAL_SUMMARIES_READY && ! ${fixture_reported:-0} )); then
    fixture_reported=1
    _fixture_probe
  fi
  return 0
}
_fixture_nested() {
  local _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_ACTIVE=1
  local saved_buffer=$BUFFER saved_cursor=$CURSOR
  print -r -u $fixture_events NESTED
  zle recursive-edit
  BUFFER=$saved_buffer CURSOR=$saved_cursor
  print -r -u $fixture_events RESTORED
}
zle -N fixture-probe _fixture_probe
zle -N fixture-nested _fixture_nested
bindkey '^X^Z' fixture-probe
bindkey '^X^F' fixture-nested
add-zle-hook-widget line-init _fixture_init
add-zle-hook-widget line-pre-redraw _fixture_changed
functions[_fixture_original_paint]=$functions[_manual_async_paint]
_manual_async_paint() {
  local before="$BUFFER|$CURSOR|$UNDO_CHANGE_NO|$MARK|$REGION_ACTIVE|${(j:;:)region_highlight}"
  _fixture_original_paint
  [[ $before == "$BUFFER|$CURSOR|$UNDO_CHANGE_NO|$MARK|$REGION_ACTIVE|${(j:;:)region_highlight}" ]] ||
    print -u2 -- 'DELIVERY CHANGED EDITOR STATE'
  _fixture_probe
}
# A real prior command failure must survive asynchronous editor callbacks.
false
