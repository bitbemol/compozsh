_test_manual_summary_native() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/manual/man1/ls.1" $'.Sh NAME\n.Nm ls\n.Nd list directory contents\n.Sh SYNOPSIS'
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.manual"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _manual_summary_capture "$2" || exit 1
    # Everything after this point is real ZLE editing over captured facts.
    _manual_summary_capture() { print -u2 unexpected-manual-read; return 99; }
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 2
    exec {efd}<> "$HOME/events"
    local event="" trace="" chunk="" pfd=0 device=""
    _manual_probe() {
      _PROMPT_INTERACTION_ACTIVE=1
      _prompt_interaction_update "$BUFFER" || :
      zle reset-prompt
      zle -R
      local rendered=""
      print -P -v rendered -r -- "$PROMPT"
      print -r -u $efd -- "FRAME|$COLUMNS|${(V)BUFFER}|$CURSOR|${(V)rendered}"
    }
    _manual_init() { print -r -u $efd READY; }
    zle -N zle-line-init _manual_init
    zle -N manual-probe _manual_probe
    bindkey "^X^Z" manual-probe
    _manual_driver() {
      command stty rows 24 cols 120
      print -r -u $efd -- "SOURCE|$(command tty)"
      local draft=""
      vared draft
      print -r -u $efd -- "DONE|$draft"
    }
    _manual_expect() {
      while zselect -r $efd $pfd -t 500; do
        while zpty -r manual chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$1"* ]] && return 0
        fi
      done
      print -u2 -r -- "Missing $1; ${event}; ${(V)trace[-600,-1]}"
      return 1
    }
    zpty -b manual _manual_driver || exit 3
    pfd=$REPLY
    {
      _manual_expect SOURCE || exit 4
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 5
      _manual_expect READY || exit 6
      zpty -w -n manual $'"'"'ls -la\x18\x1a'"'"'
      _manual_expect "FRAME|120|ls -la|6|" || exit 7
      [[ $event == *ABOUT* && $event == *"list directory contents"* && $event == *"ls(1)"* ]] || exit 8
      command stty rows 14 cols 40 < "$device"
      zpty -w -n manual $'"'"'\x18\x1a'"'"'
      _manual_expect "FRAME|40|ls -la|6|" || exit 9
      [[ $event == *ABOUT* && $event == *SOURCE* ]] || exit 10
      zpty -w -n manual $'"'"'\x15unknown-command\x18\x1a'"'"'
      _manual_expect "FRAME|40|unknown-command|15|" || exit 11
      [[ $event != *ABOUT* ]] || exit 12
      zpty -w -n manual $'"'"'\r'"'"'
      _manual_expect "DONE|unknown-command" || exit 13
      [[ $trace != *unexpected-manual-read* ]] || exit 14
    } always {
      zpty -d manual
    }
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual"
}
test_case 'manual summaries native ZLE preserves editing and resize without new capture' _test_manual_summary_native
