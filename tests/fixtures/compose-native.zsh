export LC_ALL=en_US.UTF-8
local repo=$1
source "$repo/.zsh.addons/.zsh.editor"
source "$repo/.zsh.addons/.zsh.tools"
source "$repo/.zsh.addons/.zsh.navigation"
source "$repo/.zsh.addons/.zsh.git-review"
source "$repo/.zsh.addons/.zsh.help"
source "$repo/.zsh.addons/.zsh.compose"
source "$repo/.zsh.addons/support/.zsh.ui"
source "$repo/.zsh.addons/support/.zsh.appearance"
source "$repo/.zsh.addons/support/.zsh.matching"
command git init -qb main "$HOME/repo"
print -r -- base > "$HOME/repo/file"
command git -C "$HOME/repo" add file
command git -C "$HOME/repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm base
local base_oid=$(command git -C "$HOME/repo" rev-parse HEAD)
command git -C "$HOME/repo" switch -qc topic
print -r -- head >> "$HOME/repo/file"
command git -C "$HOME/repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qam head
local head_oid=$(command git -C "$HOME/repo" rev-parse HEAD)
zmodload zsh/zpty
zmodload zsh/zselect
command mkfifo "$HOME/events" || exit 1
exec {efd}<> "$HOME/events"
local event='' trace='' device='' pfd=0
functions[_compose_native_show]=$functions[_zle_picker_show]
_zle_picker_show() {
  _compose_native_show || return $?
  print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$COLUMNS"
  if [[ $_ZLE_PICKER_TITLE == 'Compose / Directory' && $_ZLE_PICKER_QUERY == './a b' ]]; then
    [[ $_ZLE_PICKER_BROWSE_LABEL == 'Draft · mkcd -- ./a\ b' ]] || print -u $efd BAD-PREVIEW
  fi
  if [[ $_ZLE_PICKER_TITLE == 'Compose / g --review' && $_compose_base == "$base_oid" && $_compose_head == "$head_oid" ]]; then
    [[ $_compose_labels[base] == *main* && $_compose_labels[head] == *topic* ]] || print -u $efd BAD-REF-LABELS
  fi
}
_compose_native_probe() {
  [[ ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 &&
     -z ${_COMPOZSH_COMPOSE_RESULT-} && -z ${_compose_path-} &&
     $BUFFER == "$expected" && $CURSOR == $expected_cursor && ! -e "$HOME/a b" ]] || {
    print -r -u $efd -- "BAD-RESTORE|${(V)BUFFER}|$CURSOR|${(V)expected}|$expected_cursor|screen=${_ZLE_PICKER_SCREEN_ACTIVE:-unset}|active=${_ZLE_PICKER_ACTIVE:-unset}|result=${_COMPOZSH_COMPOSE_RESULT:-empty}|path=${_compose_path:-empty}"
    return
  }
  print -u $efd RESTORED
}
_compose_native_help() {
  local _COMPOZSH_COMPOSE_RESULT=''
  _zle_picker_screen_session _compose_native_help_view
  if [[ -n $_COMPOZSH_COMPOSE_RESULT ]]; then
    BUFFER=$_COMPOZSH_COMPOSE_RESULT CURSOR=${#BUFFER}
  fi
  print -u $efd CLOSED
}
_compose_native_help_view() { _compozsh_help_workspace "$(_compozsh_help_mkcd)" mkcd; }
_compose_native_open() { _draft_inspect_widget; print -u $efd CLOSED; }
_compose_native_init() {
  # vared does not pop the ordinary prompt buffer stack automatically.
  [[ ${_compose_pop:-0} == 1 ]] && zle .get-line
  CURSOR=2
  print -u $efd READY
}
zle -N zle-line-init _compose_native_init
zle -N compose-native-help _compose_native_help
zle -N compose-native-probe _compose_native_probe
zle -N compozsh-inspect _compose_native_open
bindkey '^X^H' compose-native-help
bindkey '^X^Z' compose-native-probe
_compose_native_driver() {
  command stty rows 30 cols 120
  builtin cd "$HOME"
  local draft=mkcd expected='mkcd -- ./a\ b' expected_cursor=0
  expected_cursor=${#expected}
  print -r -u $efd -- "SOURCE|$(command tty)"
  vared draft
  [[ $draft == "$expected" ]] || print -u $efd BAD-DRAFT
  expected=mkcd expected_cursor=2 draft=mkcd
  vared draft
  [[ $draft == mkcd ]] || print -u $efd BAD-CANCEL
  builtin cd "$HOME/repo"
  draft='g --review' expected="g --review $base_oid $head_oid" expected_cursor=${#expected}
  vared draft
  [[ $draft == "$expected" && $(command git symbolic-ref --short HEAD) == topic &&
     -z $(command git status --porcelain) ]] || print -u $efd BAD-GIT-DRAFT
  mkcd --help
  local _compose_pop=1
  draft='' expected='mkcd -- ./from-help' expected_cursor=2
  vared draft
  [[ $draft == "$expected" && ! -e ./from-help ]] || print -u $efd BAD-DIRECT-HELP
  print -u $efd DONE
}
_compose_native_expect() {
  local wanted=$1 chunk=''
  while zselect -r $efd $pfd -t 500; do
    while zpty -r compose-native chunk; do trace+=$chunk; done
    if IFS= read -r -t 0 -u $efd event; then
      [[ $event == "$wanted"* ]] && return 0
      [[ $event == BAD-* ]] && break
    fi
  done
  print -u2 -r -- "expected $wanted; received $event; trace ${(V)trace[-1500,-1]}"
  return 1
}
zpty -b compose-native _compose_native_driver || exit 2
pfd=$REPLY
{
  _compose_native_expect SOURCE || exit 3
  device=${event#SOURCE|}
  [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
  _compose_native_expect READY || exit 5
  zpty -w -n compose-native $'\x18\x08'
  _compose_native_expect 'FRAME|Help / mkcd||120' || exit 6
  zpty -w -n compose-native example
  _compose_native_expect 'FRAME|Help / mkcd|example|120' || exit 7
  # Examples is also a matching topic: select the explicitly labeled action.
  zpty -w -n compose-native $'\x15Compose example\r'
  _compose_native_expect 'FRAME|Compose / mkcd||120' || exit 8
  zpty -w -n compose-native $'\r'
  _compose_native_expect 'FRAME|Compose / Directory||120' || exit 9
  zpty -w -n compose-native './a b'
  _compose_native_expect 'FRAME|Compose / Directory|./a b|120' || exit 10
  command stty rows 16 cols 40 < "$device"
  _compose_native_expect 'FRAME|Compose / Directory|./a b|40' || exit 11
  zpty -w -n compose-native $'\r'
  _compose_native_expect 'FRAME|Compose / mkcd||40' || exit 12
  zpty -w -n compose-native $'apply\r'
  # Labels are the searchable text; choose by the visible action wording.
  _compose_native_expect 'FRAME|Compose / mkcd|apply|40' || exit 13
  zpty -w -n compose-native $'\x15Replace draft\r'
  _compose_native_expect CLOSED || exit 14
  zpty -w -n compose-native $'\x18\x1a'
  _compose_native_expect RESTORED || exit 15
  zpty -w -n compose-native $'\r'
  _compose_native_expect READY || exit 16
  command stty rows 30 cols 120 < "$device"
  zpty -w -n compose-native $'\e\r'
  _compose_native_expect 'FRAME|Draft / Inspect||120' || exit 17
  zpty -w -n compose-native $'Compose\r'
  _compose_native_expect 'FRAME|Compose / mkcd||120' || exit 18
  zpty -w -n compose-native $'\e'
  _compose_native_expect 'FRAME|Draft / Inspect|Compose|120' || exit 23
  zpty -w -n compose-native $'\e'
  _compose_native_expect CLOSED || exit 19
  zpty -w -n compose-native $'\x18\x1a'
  _compose_native_expect RESTORED || exit 20
  zpty -w -n compose-native $'\r'
  _compose_native_expect READY || exit 24
  zpty -w -n compose-native $'\e\r'
  _compose_native_expect 'FRAME|Draft / Inspect||120' || exit 25
  zpty -w -n compose-native $'Compose\r'
  _compose_native_expect 'FRAME|Compose / g --review||120' || exit 26
  zpty -w -n compose-native 2
  _compose_native_expect 'FRAME|Against · choose branch or commit||120' || exit 27
  zpty -w -n compose-native $'main\r'
  _compose_native_expect 'FRAME|Compose / g --review||120' || exit 28
  zpty -w -n compose-native 3
  _compose_native_expect 'FRAME|Compare · choose branch or commit||120' || exit 29
  zpty -w -n compose-native $'topic\r'
  _compose_native_expect 'FRAME|Compose / g --review||120' || exit 30
  zpty -w -n compose-native $'Replace draft\r'
  _compose_native_expect CLOSED || exit 31
  zpty -w -n compose-native $'\x18\x1a'
  _compose_native_expect RESTORED || exit 32
  zpty -w -n compose-native $'\r'
  _compose_native_expect 'FRAME|Help / mkcd||120' || exit 33
  zpty -w -n compose-native $'Compose example\r'
  _compose_native_expect 'FRAME|Compose / mkcd||120' || exit 34
  zpty -w -n compose-native $'\r'
  _compose_native_expect 'FRAME|Compose / Directory||120' || exit 35
  zpty -w -n compose-native $'./from-help\r'
  _compose_native_expect 'FRAME|Compose / mkcd||120' || exit 36
  zpty -w -n compose-native $'Replace draft\r'
  _compose_native_expect READY || exit 37
  zpty -w -n compose-native $'\x18\x1a'
  _compose_native_expect RESTORED || exit 38
  zpty -w -n compose-native $'\r'
  _compose_native_expect DONE || exit 21
  [[ $trace == *$'\e[?1049h'* && $trace == *$'\e[?1049l'* &&
     $trace != *'command not found'* && $trace != *'read-only variable'* ]] || exit 22
} always {
  zpty -d compose-native
}
print native
