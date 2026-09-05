_test_help_workspace_native() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/.zsh.help"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local event="" trace="" pfd=0 device="" captures=0 panel_color=0 reader_color=0
    zle() {
      local IFS=$'"'"' \t\n'"'"'
      if [[ $1 == -R ]] && (( _ZLE_PICKER_REFERENCE_VIEW )); then
        local mark="" piece="" before=""
        local -a fields=()
        local -i start=0 end=0
        for mark in "${region_highlight[@]}"; do
          fields=( ${=mark} )
          [[ $fields[1] == P<-> && $fields[2] == <-> ]] || continue
          start=${fields[1]#P} end=$fields[2]
          piece=${_ZLE_PICKER_POSTDISPLAY[$((start+1)),$end]}
          before=${_ZLE_PICKER_POSTDISPLAY[1,$start]}
          before=${before##*$'"'"'\n'"'"'}
          if [[ $piece == --discard-all && $fields[3] == *"$ZSH_HIGHLIGHT_STYLES[picker-header]"* ]] &&
             (( _ZLE_PICKER_READER_ONLY || ${#before} > 40 )); then
            print -r -u $efd -- "ACCENT|$_ZLE_PICKER_READER_ONLY"
          fi
        done
      fi
      builtin zle "$@"
    }
    functions[_help_native_show]=$functions[_zle_picker_show]
    functions[_help_native_provider]=$functions[_compozsh_help_g]
    _compozsh_help_g() { print -r -u $efd CAPTURE; _help_native_provider; }
    _zle_picker_show() {
      _help_native_show
      [[ $_ZLE_PICKER_POSTDISPLAY == *"$_ZLE_PICKER_TITLE"* && $_ZLE_PICKER_POSTDISPLAY == *"$_ZLE_PICKER_QUERY_LABEL"* ]] || print -r -u $efd BAD-PAINT
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_INSPECT_FOCUS|$COLUMNS"
    }
    _help_native_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "SOURCE|$(command tty)"
      _ZLE_PICKER_BOOKMARK=(caller)
      _ZLE_PICKER_BOOKMARK_FOCUS=1
      g --help
      [[ $? == 0 && $_ZLE_PICKER_BOOKMARK[1] == caller && $_ZLE_PICKER_BOOKMARK_FOCUS == 1 &&
         ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && ${_ZLE_PICKER_ACTIVE:-0} == 0 ]] || print -r -u $efd -- "BAD-CLEANUP|$?|${(j:|:)_ZLE_PICKER_BOOKMARK}|$_ZLE_PICKER_BOOKMARK_FOCUS|${_ZLE_PICKER_SCREEN_ACTIVE:-0}|${_ZLE_PICKER_ACTIVE:-0}"
      NO_COLOR=1 cpdir --help
      TERM=dumb cpdir --help
      cpdir --help < /dev/null
      print -r -u $efd PLAIN-FALLBACKS
      local tool
      for tool in mkcd cpdir external-device xcode compozsh; do
        "$tool" --help
        [[ $? == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]] || print -r -u $efd BAD-HELP
      done
      compozsh --sudo-touch-id --help
      external-device --format --help
      xcode --export-skills --help
      print -r -u $efd DONE
    }
    _help_native_expect() {
      local wanted=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r help-native chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == CAPTURE ]] && (( ++captures ))
          [[ $event == "ACCENT|0" ]] && panel_color=1
          [[ $event == "ACCENT|1" ]] && reader_color=1
          [[ $event == "$wanted"* ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; received $event; trace ${(V)trace[-1200,-1]}"
      return 1
    }
    zpty -b help-native _help_native_driver || exit 2
    pfd=$REPLY
    {
      _help_native_expect SOURCE || exit 3
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
      _help_native_expect "FRAME|Help / g||0|120" || exit 5
      zpty -w -n help-native --discard-all
      _help_native_expect "FRAME|Help / g|--discard-all|0|120" || exit 6
      zpty -w -n help-native $'"'"'\e[B\r'"'"'
      _help_native_expect "FRAME|Help / g / --discard-all" || exit 7
      zpty -w -n help-native $'"'"'\e'"'"'
      _help_native_expect "FRAME|Help / g|--discard-all|0|120" || exit 8
      zpty -w -n help-native $'"'"'\x05'"'"'
      _help_native_expect "FRAME|Help / g|--discard-all|1|120" || exit 9
      command stty rows 16 cols 40 < "$device"
      _help_native_expect "FRAME|Help / g|--discard-all|1|40" || exit 10
      zpty -w -n help-native $'"'"'\x15nomatch-xyz'"'"'
      _help_native_expect "FRAME|Help / g|nomatch-xyz|0|40" || exit 11
      zpty -w -n help-native $'"'"'\e'"'"'
      _help_native_expect PLAIN-FALLBACKS || exit 15
      for tool in mkcd cpdir external-device xcode compozsh compozsh external-device xcode; do
        _help_native_expect "FRAME|Help / $tool||0|40" || exit 12
        zpty -w -n help-native $'"'"'\e'"'"'
      done
      _help_native_expect DONE || exit 13
      local accent=${${ZSH_HIGHLIGHT_STYLES[picker-header]#fg=}%%,*}
      (( panel_color && reader_color )) || { print -u2 -- "missing painted help accents: panel=$panel_color reader=$reader_color"; exit 17; }
      [[ $trace == *$'"'"'\e[38;5;'"'"'"${accent}m--worktree"* ]] || exit 16
      [[ $captures == 1 && $trace == *$'"'"'\e[?1049h'"'"'* && $trace == *$'"'"'\e[?1049l'"'"'* &&
         $trace != *"read-only variable"* && $trace != *"command not found"* ]] || exit 14
    } always {
      zpty -d help-native
    }
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'help workspace native public modes filter read return resize cancel and capture only once' _test_help_workspace_native
