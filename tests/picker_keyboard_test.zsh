# Modal shortcuts must not impose human chord delays or change shell bindings.
_test_picker_keyboard_escape() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local bindings=$(bindkey -L) scenario="" event="" trace="" pfd=0
    local -i escape_reads=0
    read() {
      if [[ $# == 6 && $1 == -r && $2 == -t && $6 == sequence ]]; then
        # Assert the requested allowance, not scheduling-sensitive wall time.
        (( $3 > 0 && $3 <= 0.03 )) || print -r -u $efd BAD-ESC-BUDGET
        (( ++escape_reads ))
      fi
      builtin read "$@"
    }
    _keys_collect() {
      _ZLE_PICKER_RESULTS=(alpha beta)
      _ZLE_PICKER_LABELS=(alpha beta)
    }
    functions[_keys_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _keys_show
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_GUIDE_ACTIVE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_SELECTED"
    }
    _keys_driver() {
      command stty rows 30 cols 120
      _ZLE_PICKER_COLLECTOR=_keys_collect
      _ZLE_PICKER_TITLE=Keyboard _ZLE_PICKER_INSPECT_ACTION=select
      # Former Escape commands must cancel even when the capability exists.
      [[ $scenario == old-* ]] && _ZLE_PICKER_DIRECTORY_ACTIONS=1
      [[ $scenario == old-browse ]] && _ZLE_PICKER_DIRECTORY_ACTIONS=2
      [[ $scenario == old-hidden ]] && _ZLE_PICKER_HIERARCHY_ENABLED=1
      [[ $scenario == meta-copy ]] && _ZLE_PICKER_COPY_ENABLED=1
      _zle_picker_run 10
      local result=$?
      if [[ $scenario == meta-copy ]]; then
        [[ $result == 0 && $_ZLE_PICKER_ACCEPTED == 1 && $_ZLE_PICKER_ACTION == copy &&
           $_ZLE_PICKER_SELECTED_VALUE == alpha ]] || print -r -u $efd BAD-META-COPY
      else
        [[ $result == 1 && $_ZLE_PICKER_ACCEPTED == 0 && $_ZLE_PICKER_ACTION == select ]] || print -r -u $efd BAD-CANCEL
      fi
      [[ $_ZLE_PICKER_ACTIVE == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 &&
         $(bindkey -L) == "$bindings" ]] || print -r -u $efd BAD-CLEANUP
      (( escape_reads )) || print -r -u $efd BAD-NO-ESC
      print -r -u $efd DONE
    }
    _keys_expect() {
      local expected=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r keys chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "$scenario: expected $expected; got $event"
      return 1
    }
    for scenario in escape old-preview old-guide old-actions old-browse old-hidden transport meta-copy disabled; do
      zpty -b keys _keys_driver || exit 2
      pfd=$REPLY
      {
        _keys_expect "FRAME|0||1" || exit 3
        case $scenario in
          (old-preview) zpty -w -n keys $'\''\ep'\'' ;;
          (old-guide) zpty -w -n keys $'\''\e?'\'' ;;
          (old-actions) zpty -w -n keys $'\''\ea'\'' ;;
          (old-browse) zpty -w -n keys $'\''\eb'\'' ;;
          (old-hidden) zpty -w -n keys $'\''\e.'\'' ;;
          (meta-copy) zpty -w -n keys $'\''\ew'\'' ;;
          (transport)
            # Normal/application arrows and Option-Delete retain byte decoding.
            zpty -w -n keys $'\''\e[B'\''
            _keys_expect "FRAME|0||2" || exit 4
            zpty -w -n keys $'\''\eOA'\''
            _keys_expect "FRAME|0||1" || exit 5
            # Terminal.app emits xterm Meta cursor sequences when Option is
            # configured as Meta. They page without replacing Fn-Up/Down.
            zpty -w -n keys $'\''\e[1;3B'\''
            _keys_expect "FRAME|0||2" || exit 14
            zpty -w -n keys $'\''\e[1;3A'\''
            _keys_expect "FRAME|0||1" || exit 15
            # Terminal.app may encode Option as a leading Meta Escape before
            # the ordinary cursor sequence: ESC ESC [ A/B.
            zpty -w -n keys $'\''\e\e[B'\''
            _keys_expect "FRAME|0||2" || exit 16
            zpty -w -n keys $'\''\e\e[A'\''
            _keys_expect "FRAME|0||1" || exit 17
            zpty -w -n keys $'\''\x16'\''
            _keys_expect "FRAME|0||2" || exit 11
            zpty -w -n keys $'\''\ev'\''
            _keys_expect "FRAME|0||1" || exit 12
            zpty -w -n keys $'\''\e[200~pab.?\x0b\x18\x14\x04\e[201~'\''
            # New action bytes in a paste are data, never shortcuts.
            _keys_expect $'\''FRAME|0|pab.?\x0b\x18\x14\x04|1'\'' || exit 6
            zpty -w -n keys $'\''\x15one two\e\x7f'\''
            _keys_expect "FRAME|0|one |1" || exit 7
            zpty -w -n keys $'\''\e[3~'\''
            _keys_expect "FRAME|0|one|1" || exit 13
            zpty -w -n keys $'\''\e'\'' ;;
          (disabled)
            # Unsupported capability keys must stay inert; letters still type.
            zpty -w -n keys $'\''\x0f\x18\x14\x06\x05pab.?'\''
            _keys_expect "FRAME|0|pab.?|1" || exit 8
            zpty -w -n keys $'\''\e'\'' ;;
          (*) zpty -w -n keys $'\''\e'\'' ;;
        esac
        _keys_expect DONE || exit 9
        [[ $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 10
      } always {
        zpty -d keys
      }
    done
    print keyboard
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal keyboard "$output"
}
test_case 'picker keyboard gives Escape a short decoding allowance and keeps terminal sequences safe' _test_picker_keyboard_escape

_test_picker_keyboard_help() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    local tool="" help=""
    for tool in g compozsh; do
      help=$("$tool" --help) || exit 1
      [[ $help == *Ctrl-K* && $help == *Ctrl-D* &&
         $help != *"Escape then"* && $help != *"half a second"* ]] || {
        print -u2 -- "$tool help disagrees with the picker keys"; exit 2;
      }
    done
    print help
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal help "$output"
}
test_case 'picker keyboard help advertises primary Control shortcuts across public tools' _test_picker_keyboard_help

_test_picker_keyboard_shared_contract() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local spec="" footer="" guide="" token=""
    local -a fields=()
    COLUMNS=200 LINES=60
    _ZLE_PICKER_SCREEN_ACTIVE=1
    _ZLE_PICKER_RESULTS=(example) _ZLE_PICKER_LABELS=(example)
    _ZLE_PICKER_SELECTED=1
    for spec in "History|0|0|0" "Recent directories|2|0|1" "Branches|0|0|1" \
                "Files|0|0|1" "Tool explorer|0|0|0" "Directory browser|1|1|1" \
                "File actions|0|0|0" "Folder actions|0|0|0"; do
      fields=("${(@s:|:)spec}")
      _ZLE_PICKER_TITLE=$fields[1]
      _ZLE_PICKER_DIRECTORY_ACTIONS=$fields[2]
      _ZLE_PICKER_HIERARCHY_ENABLED=$fields[3]
      _ZLE_PICKER_COPY_ENABLED=$fields[4]
      _ZLE_PICKER_SEARCH_ACTION=''
      [[ $fields[1] == Files || $fields[1] == "Directory browser" ]] && _ZLE_PICKER_SEARCH_ACTION=search-local
      _ZLE_PICKER_INSPECT_TEXTS=([example]=details)
      _ZLE_PICKER_GUIDE_ACTIVE=0
      _zle_picker_footer 199 ""
      footer=$REPLY
      for token in "Esc cancel" "^K keys"; do
        [[ $footer == *"$token"* ]] || exit 1
      done
      _ZLE_PICKER_GUIDE_ACTIVE=1 _ZLE_PICKER_GUIDE_OFFSET=0
      _zle_picker_guide_render 199
      guide=${(j:,:)_ZLE_PICKER_DISPLAY}
      [[ $guide == *Ctrl-E* ]] || exit 8
      if [[ -n $_ZLE_PICKER_SEARCH_ACTION ]]; then
        [[ $footer == *"^F search"* && $guide == *Ctrl-F* ]] || exit 9
      else
        [[ $footer != *"^F search"* && $guide != *Ctrl-F* ]] || exit 10
      fi
      for token in Ctrl-K Ctrl-D Ctrl-V Ctrl-U Ctrl-W Ctrl-C Ctrl-L; do
        [[ $guide == *"$token"* ]] || exit 2
      done
      [[ $guide == *"Option-Up/Down"* && $guide == *"one-line overlap"* ]] || exit 11
      if (( _ZLE_PICKER_DIRECTORY_ACTIONS == 1 )); then
        [[ $footer == *"^O preview"* && $footer == *"^X options"* &&
           $guide == *Ctrl-O* && $guide == *Ctrl-X* && $guide == *Ctrl-T* ]] || exit 3
      elif (( _ZLE_PICKER_DIRECTORY_ACTIONS == 2 )); then
        [[ $footer == *"^O browse"* && $guide == *Ctrl-O* && $guide != *Ctrl-X* ]] || exit 4
      else
        [[ $guide != *Ctrl-O* && $guide != *Ctrl-X* && $guide != *Ctrl-T* ]] || exit 5
      fi
      if (( _ZLE_PICKER_COPY_ENABLED )); then
        [[ $footer == *"^Y copy"* && $guide == *Ctrl-Y* ]] || exit 6
      else
        [[ $footer != *"^Y copy"* && $guide != *Ctrl-Y* ]] || exit 7
      fi
    done
    print shared
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal shared "$output"
}
test_case 'picker keyboard contract keeps common and capability keys consistent across tool views' _test_picker_keyboard_shared_contract
