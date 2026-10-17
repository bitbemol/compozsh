# Modal shortcuts must not impose human chord delays or change shell bindings.
_test_picker_keyboard_escape() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/tests/pty_support.zsh" || exit 18
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local bindings=$(bindkey -L) scenario="" event="" trace=""
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
      {
        test_pty_expect keys $efd "$1" || {
          print -u2 -r -- "$scenario: expected $1"
          return 1
        }
      } always { trace+=$TEST_PTY_OUTPUT }
    }
    for scenario in escape old-preview old-guide old-actions old-browse old-hidden transport meta-copy disabled; do
      test_pty_start keys _keys_driver || exit 2
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

# A complete cursor or function key without a meaning in the current view is
# inert: it neither cancels nor edits the field, none of its bytes reaches the
# filter and it never swallows the next key. Escape, Ctrl-G and Meta-letters
# still cancel.
_test_picker_keyboard_inert_keys() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    source "$1/tests/pty_support.zsh" || exit 2
    command mkfifo "$HOME/events" || exit 3
    exec {efd}<> "$HOME/events"
    local view="" key="" trace=""
    local -i index=0
    # Left/Right in normal and application cursor mode, Home and End in three
    # encodings each, F1, Insert, F5, Ctrl-Delete and Shift-Right.
    local -a keys=(
      $'\''\e[D'\'' $'\''\e[C'\'' $'\''\eOD'\'' $'\''\eOC'\''
      $'\''\e[H'\'' $'\''\eOH'\'' $'\''\e[1~'\'' $'\''\e[F'\'' $'\''\eOF'\'' $'\''\e[4~'\''
      $'\''\eOP'\'' $'\''\e[2~'\'' $'\''\e[15~'\'' $'\''\e[3;5~'\'' $'\''\e[1;2C'\'')
    functions -c _zle_picker_show _inert_real_show
    _zle_picker_show() {
      _inert_real_show
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY"
    }
    _inert_collect() { _ZLE_PICKER_RESULTS=(alpha beta) _ZLE_PICKER_LABELS=(alpha beta) }
    _inert_query() { _ZLE_PICKER_TITLE=Name; _zle_picker_loop "" 10 }
    _inert_choice() {
      _ZLE_PICKER_TITLE=Choice _ZLE_PICKER_COLLECTOR=_inert_collect
      _zle_picker_loop "" 10
    }
    _inert_controller() {
      local kind=""
      for kind in query choice query; do
        _zle_ui_view $kind _inert_$kind
        print -r -u $efd -- "RESULT|$kind|$?|$_ZLE_PICKER_ACCEPTED"
      done
      return 1
    }
    _inert_driver() {
      command stty rows 24 cols 100
      _zle_picker_run 10 "" 1 0 _inert_controller
      print -r -u $efd -- "DONE|$?|${_ZLE_PICKER_SCREEN_ACTIVE:-0}"
    }
    _inert_expect() {
      {
        test_pty_expect -s "RESULT*" inert $efd "$1"
      } always { trace+=$TEST_PTY_OUTPUT }
    }
    test_pty_start inert _inert_driver || exit 4
    {
      for view in Name Choice; do
        _inert_expect "FRAME|$view|" || exit 5
        zpty -w -n inert abc
        _inert_expect "FRAME|$view|abc" || exit 6
        for (( index=1; index<=${#keys}; ++index )); do
          key=$keys[index]
          # The next key follows at once: it must arrive as typed text.
          zpty -w -n inert "${key}x"
          _inert_expect "FRAME|$view|abcx" || {
            print -u2 -r -- "$view: ${(V)key} was not inert"; exit 7; }
          zpty -w -n inert $'\''\x7f'\''
          _inert_expect "FRAME|$view|abc" || exit 8
        done
        if [[ $view == Name ]]; then
          # Meta-letters remain cancellation, not commands.
          zpty -w -n inert $'\''\eq'\''
          _inert_expect "RESULT|query|1|0" || exit 9
        else
          zpty -w -n inert $'\''\e'\''
          _inert_expect "RESULT|choice|1|0" || exit 10
        fi
      done
      _inert_expect "FRAME|Name|" || exit 11
      # An endless parameter run is not a key: decoding stops at its bound and
      # the view stays open for the next key.
      zpty -w -n inert "abc"$'\''\e['\''"${(l:40::;:):-}x"
      test_pty_expect -g -s "RESULT*" inert $efd "FRAME[|]Name[|]abc*x" || exit 15
      trace+=$TEST_PTY_OUTPUT
      zpty -w -n inert $'\''\x07'\''
      _inert_expect "RESULT|query|1|0" || exit 12
      _inert_expect "DONE|1|0" || exit 13
      [[ $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 14
    } always {
      zpty -d inert
    }
    print inert
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal inert "$output"
}
test_case 'picker keys without a meaning stay inert in query and choice views' _test_picker_keyboard_inert_keys

_test_picker_keyboard_help() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect_choices"
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
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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
      for token in "Esc cancel" "^K all keys"; do
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
