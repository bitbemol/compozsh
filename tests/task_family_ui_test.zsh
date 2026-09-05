_test_task_family_native() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" '#!/bin/zsh
if [[ $1 == --find && $2 == agent ]]; then
  print -r -- /example/Xcode/agent
else
  [[ $COMPOZSH_TEST_RESTORED == 1 ]] || exit 99
  print -r -- exported > "$HOME/export-called"
  exit 42
fi' || return
  test_write_file "$TEST_TMP_DIR/bin/xcodebuild" '#!/bin/zsh
print -r -- "Xcode Example"
print -r -- "Build version Example"' || return
  command chmod 700 "$TEST_TMP_DIR/bin/xcrun" "$TEST_TMP_DIR/bin/xcodebuild" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$2/bin" $path)
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    _detect_xcode_skill_vendor() { REPLY=synthetic; [[ $1 == codex ]]; }
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local event="" trace="" pfd=0 device=""
    functions[_family_show]=$functions[_zle_picker_show]
    functions[_family_run]=$functions[_zle_picker_run]
    _zle_picker_show() {
      _family_show
      [[ $_ZLE_PICKER_POSTDISPLAY == *"$_ZLE_PICKER_TITLE"* ]] || print -r -u $efd BAD-PAINT
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$COLUMNS"
    }
    _zle_picker_run() {
      export COMPOZSH_TEST_RESTORED=0
      _family_run "$@"
      local result=$?
      (( ! _ZLE_PICKER_ACTIVE && ! _ZLE_PICKER_SCREEN_ACTIVE )) || print -r -u $efd BAD-CLEANUP
      export COMPOZSH_TEST_RESTORED=1
      return $result
    }
    _usb_flash() { print -r -u $efd BAD-FLASH; return 99; }
    _usb_format() {
      (( ! _ZLE_PICKER_ACTIVE && ! _ZLE_PICKER_SCREEN_ACTIVE )) || return 99
      print -r -u $efd FORMAT-AFTER-CLEANUP
      return 17
    }
    _family_driver() {
      command stty rows 30 cols 120
      _ZLE_PICKER_BOOKMARK=(caller)
      _ZLE_PICKER_BOOKMARK_FOCUS=1
      print -r -u $efd -- "SOURCE|$(command tty)"
      external-device
      [[ $? == 17 ]] || print -r -u $efd BAD-STATUS
      [[ ${(j:|:)_ZLE_PICKER_BOOKMARK} == caller && $_ZLE_PICKER_BOOKMARK_FOCUS == 1 ]] || print -r -u $efd BAD-BOOKMARK
      external-device
      [[ $? == 0 ]] || print -r -u $efd BAD-CANCEL
      print -r -u $efd CANCELLED
      xcode --export-skills
      [[ $? == 0 && ! -e "$HOME/export-called" && ! -d "$HOME/.agents" ]] || print -r -u $efd BAD-EXPORT-CANCEL
      print -r -u $efd EXPORT-CANCELLED
      xcode --export-skills
      [[ $? == 1 && -f "$HOME/export-called" && ! -d "$HOME/.agents" ]] || print -r -u $efd BAD-EXPORT-STATUS
      [[ ${(j:|:)_ZLE_PICKER_BOOKMARK} == caller && $_ZLE_PICKER_BOOKMARK_FOCUS == 1 ]] || print -r -u $efd BAD-BOOKMARK
      print -r -u $efd DONE
    }
    _family_expect() {
      local wanted=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r family chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted"* ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; received $event; trace ${(V)trace[-1200,-1]}"
      return 1
    }
    zpty -b family _family_driver || exit 2
    pfd=$REPLY
    {
      _family_expect SOURCE || exit 3
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
      _family_expect "FRAME|External device / Tasks||120" || exit 5
      zpty -w -n family format
      _family_expect "FRAME|External device / Tasks|format|120" || exit 6
      zpty -w -n family $'"'"'\x05'"'"'
      _family_expect "FRAME|External device / Tasks|format|120" || exit 7
      command stty rows 16 cols 40 < "$device"
      _family_expect "FRAME|External device / Tasks|format|40" || exit 8
      zpty -w -n family $'"'"'\x02\r'"'"'
      _family_expect FORMAT-AFTER-CLEANUP || exit 9
      _family_expect "FRAME|External device / Tasks||40" || exit 10
      zpty -w -n family $'"'"'\e'"'"'
      _family_expect CANCELLED || exit 11
      _family_expect "FRAME|Xcode / Export skills||40" || exit 12
      zpty -w -n family $'"'"'\e'"'"'
      _family_expect EXPORT-CANCELLED || exit 13
      _family_expect "FRAME|Xcode / Export skills||40" || exit 14
      zpty -w -n family $'"'"'\r'"'"'
      _family_expect DONE || exit 15
      [[ $trace == *$'"'"'\e[?1049h'"'"'* && $trace == *$'"'"'\e[?1049l'"'"'* &&
         $trace != *"read-only variable"* && $trace != *"command not found"* ]] || exit 16
    } always {
      zpty -d family
    }
    print native
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal native "$output"
}
test_case 'task families native choices resize cancel and dispatch only after screen restoration' _test_task_family_native
