# An incomplete paste retains terminal ownership until its closing marker.
_test_picker_paste_boundary() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/ui/.zsh.ui.zle_picker_loop"
    local scenario="" stream="" result=0 delivered=0 notices=0 recovery_visible=0
    local -i _ZLE_PICKER_GUIDE_ACTIVE=1 _ZLE_PICKER_INSPECT_FOCUS=1 _ZLE_PICKER_VIEW_OFFSET=17
    local eof_fd=0
    exec {eof_fd}< /dev/null
    # Keep timing deterministic. The transport spy injects one timeout, then
    # returns the rest of the literal paste, including action-looking bytes.
    read() {
      (( ++delivered ))
      if [[ $scenario == eof ]]; then
        (( delivered <= 3 )) || { print -u2 repeated-fatal-read; exit 8; }
        builtin read -r -k 1 -u $eof_fd character
        return $?
      fi
      if (( delivered == 1 )); then
        [[ $scenario == timeout ]] && return 1
        # Exercise the storage boundary without a million mocked calls.
        if [[ $scenario == complete-limit ]]; then
          character=${(pl:1048576::x:)}
        elif [[ $scenario == closing-prefix ]]; then
          character=$'\''literal\e[20'\''
        else
          character=${(pl:1048582::x:)}
        fi
        return 0
      fi
      [[ $scenario == closing-prefix && $delivered == 2 ]] && return 1
      [[ -n $stream ]] || return 1
      character=$stream[1]
      stream=$stream[2,-1]
      return 0
    }
    _zle_picker_render() {
      (( ++notices ))
      (( !_ZLE_PICKER_GUIDE_ACTIVE && !_ZLE_PICKER_INSPECT_FOCUS )) && recovery_visible=1
      _ZLE_PICKER_VIEW_OFFSET=0
    }
    _zle_picker_show() { return 0; }
    _zle_ui_view() { shift; "$@"; }
    for scenario in timeout oversized closing-prefix; do
      stream=$'\''not-a-command\r\x03\x07\e[201~AFTER'\''
      [[ $scenario == closing-prefix ]] && stream="1~AFTER"
      delivered=0 notices=0 recovery_visible=0 REPLY=unchanged
      if _zle_picker_read_bracketed_paste; then result=0; else result=$?; fi
      [[ $result == 2 && -z $REPLY && $stream == AFTER && $notices -ge 1 ]] || {
        print -u2 -r -- "$scenario: status=$result remainder=${(V)stream} notices=$notices"
        exit 1
      }
      [[ $recovery_visible == 1 && $_ZLE_PICKER_GUIDE_ACTIVE == 1 &&
         $_ZLE_PICKER_INSPECT_FOCUS == 1 && $_ZLE_PICKER_VIEW_OFFSET == 17 ]] || {
        print -u2 -r -- "$scenario: recovery must replace the guide, then restore focus and viewport"
        exit 2
      }
    done
    scenario=complete-limit stream=$'\''\e[201~AFTER'\'' delivered=0 notices=0
    if _zle_picker_read_bracketed_paste; then result=0; else result=$?; fi
    [[ $result == 0 && ${#REPLY} == 1048576 && $stream == AFTER && $notices == 0 ]] || {
      print -u2 -r -- "exact limit: status=$result length=${#REPLY} notices=$notices"
      exit 3
    }
    scenario=eof delivered=0
    if _zle_picker_read_bracketed_paste; then result=0; else result=$?; fi
    [[ $result == 1 && -z $REPLY && $delivered == 2 ]] || exit 4
    exec {eof_fd}<&-
    print paste-boundary
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal paste-boundary "$output"
}
test_case 'picker interrupted paste discards bounded data through the closing marker' _test_picker_paste_boundary

_test_picker_paste_transport() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for f in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$f"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/support/.zsh.appearance"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    zmodload zsh/system
    local event="" trace="" chunk="" scenario="" pfd=0 timed_out=0 signalled=0
    functions[_paste_transport]=$functions[_zle_picker_read_bracketed_paste]
    _zle_picker_read_bracketed_paste() {
      local transport_result=0
      _paste_transport "$@" || transport_result=$?
      # Returning the consumed "2" used to drop transport signal ownership
      # before a second call read the opener. Inject SIGINT at that handoff.
      if [[ $scenario == handoff-signal && $1 == suffix &&
            $transport_result == 0 && $REPLY == 2 ]]; then
        kill -INT $sysparams[pid]
      fi
      return $transport_result
    }
    read() {
      if [[ $scenario == (partial-csi|partial-csi-signal) && $timed_out == 0 &&
            ( ${@[-1]} == suffix || ( ${@[-1]} == character && ${mode-} == suffix ) ) ]]; then
        timed_out=1
        [[ $scenario == partial-csi-signal ]] && kill -INT $sysparams[pid]
        print -r -u $efd TIMEOUT
        return 1
      fi
      if [[ ${@[-1]} == character && $timed_out == 0 &&
            ( $3 == 1 || ( $scenario == partial-opening && ${mode-} == opening ) ) ]]; then
        timed_out=1
        if [[ $scenario == signal ]]; then
          kill -INT $sysparams[pid]
        elif [[ $scenario == real-timeout ]]; then
          builtin read "$@" && return 0
        fi
        print -r -u $efd TIMEOUT
        return 1
      fi
      builtin read "$@"
    }
    _paste_collect() { _ZLE_PICKER_RESULTS=(alpha beta); _ZLE_PICKER_LABELS=(alpha beta); }
    functions[_paste_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _paste_show
      if (( ${_ZLE_PICKER_BUSY:-0} )) && [[ $scenario == narrow ]]; then
        [[ "${(j: :)_ZLE_PICKER_DISPLAY}" == *"Resume: Escape then [201~"* ]] ||
          print -r -u $efd BAD-HIDDEN-RECOVERY
      fi
      if (( ${_ZLE_PICKER_BUSY:-0} && !signalled )) && [[ $scenario == signal ]]; then
        signalled=1
        kill -INT $sysparams[pid]
        kill -WINCH $sysparams[pid]
      fi
      print -r -u $efd -- "FRAME|${_ZLE_PICKER_BUSY:-0}|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_SELECTED|$_ZLE_PICKER_GUIDE_ACTIVE|${_ZLE_PICKER_EXCLUDE_FOCUS:-0}"
    }
    _paste_driver() {
      command stty rows 30 cols 120
      [[ $scenario == narrow ]] && command stty rows 10 cols 32
      _ZLE_PICKER_COLLECTOR=_paste_collect _ZLE_PICKER_TITLE=Paste
      TRAPINT() { print -r -u $efd BAD-OUTER-INT; return 0; }
      TRAPWINCH() { zle compozsh-picker-redraw }
      local old_int=$functions[TRAPINT] old_winch=$functions[TRAPWINCH]
      _zle_picker_run 10
      local result=$?
      [[ $functions[TRAPINT] == "$old_int" && $functions[TRAPWINCH] == "$old_winch" ]] ||
        print -r -u $efd BAD-TRAP-RESTORE
      print -r -u $efd -- "DONE|$result|$_ZLE_PICKER_ACCEPTED|$_ZLE_PICKER_ACTION"
    }
    _paste_expect() {
      local expected=$1
      while zselect -r $efd $pfd -t 500; do
        while zpty -r paste chunk; do trace+=$chunk; done
        if IFS= builtin read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == (DONE*|BAD-*) ]] && break
        fi
      done
      print -u2 -r -- "expected $expected; got $event"
      return 1
    }
    for scenario in timeout real-timeout signal handoff-signal partial-csi partial-csi-signal partial-opening guide exclusion narrow; do
      zpty -b paste _paste_driver || exit 2
      pfd=$REPLY
      {
      _paste_expect "FRAME|0||1|0|0" || exit 3
      if [[ $scenario == guide ]]; then
        zpty -w -n paste $'\''\x0b'\''
        _paste_expect "FRAME|0||1|1|0" || exit 9
      elif [[ $scenario == exclusion ]]; then
        zpty -w -n paste $'\''\x1d'\''
        _paste_expect "FRAME|0||1|0|1" || exit 10
      fi
      if [[ $scenario == (partial-csi|partial-csi-signal) ]]; then
        zpty -w -n paste $'\''\e['\''
      elif [[ $scenario == partial-opening ]]; then
        zpty -w -n paste $'\''\e[2'\''
      else
        zpty -w -n paste $'\''\e[200~'\''
      fi
      _paste_expect TIMEOUT || exit 4
      _paste_expect "FRAME|1||0|0|0" || exit 5
      # A resumed paste may contain Enter, Ctrl-C/G and nested opening bytes.
      # None can accept a result, cancel the owner, or become a shell draft.
      zpty -w -n paste $'\''oops\r\x03\x07\e[200~\e[201~'\''
      if [[ $scenario == guide ]]; then
        _paste_expect "FRAME|0||1|1|0" || exit 6
        zpty -w -n paste $'\''\x0b'\''
        _paste_expect "FRAME|0||1|0|0" || exit 11
      elif [[ $scenario == exclusion ]]; then
        _paste_expect "FRAME|0||1|0|1" || exit 6
      else
        _paste_expect "FRAME|0||1|0|0" || exit 6
      fi
      zpty -w -n paste $'\''\x07'\''
      _paste_expect "DONE|1|0|select" || exit 7
      [[ $trace != *"bad math"* && $trace != *"read-only variable"* ]] || exit 8
      } always { zpty -d paste }
    done
    exec {efd}>&-
    print paste-transport
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal paste-transport "$output"
}
test_case 'picker interrupted paste keeps resumed Enter and cancellation bytes inside native ZLE' _test_picker_paste_transport

_test_picker_paste_abort_scope() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/ui/.zsh.ui.zle_picker_screen_session"
    zmodload zsh/system
    local scenario="" restored=""
    zle() { return 0; }
    _abort_registration() {
      [[ ${+functions[TRAPINT]} == 1 ]] || {
        print -u2 -r -- "$scenario: incorrect screen abort registration"
        return 1
      }
    }
    for scenario in absent function static ignored; do
      (
        trap - INT TERM
        case $scenario in
          function) TRAPINT() { restored=function; return 0; } ;;
          static) trap "restored=static" INT ;;
          ignored) trap "" INT ;;
        esac
        _zle_picker_screen_session _abort_registration || exit 1
        if [[ $scenario == function ]]; then
          [[ ${+functions[TRAPINT]} == 1 ]] || exit 2
        else
          [[ ${+functions[TRAPINT]} == 0 ]] || exit 2
        fi
        if [[ $scenario != absent ]]; then
          kill -INT $sysparams[pid]
          [[ $scenario == ignored && -z $restored || $restored == $scenario ]] || {
            print -u2 -r -- "$scenario: caller trap was not restored"
            exit 3
          }
        fi
      ) || exit 1
    done
    print abort-scope
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal abort-scope "$output"
}
test_case 'picker paste screen abort scope restores absent function static and ignored signal registrations' _test_picker_paste_abort_scope

_test_picker_paste_outer_editor() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local root=$1 event="" trace="" chunk="" pfd=0
    # A fresh interactive shell is essential: Ctrl-C can normally terminate
    # a zpty-created subshell running vared, even without any product code.
    print -r -- "_outer_root=${(q)root}" > "$HOME/outer.zsh"
    print -r -- '\''
      exec {_outer_event_fd}<> "$HOME/events"
      for f in "$_outer_root/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$_outer_root/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$_outer_root/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$f"; done
      source "$_outer_root/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
      source "$_outer_root/.zsh.addons/support/.zsh.appearance"
      _outer_collect() { _ZLE_PICKER_RESULTS=(alpha beta); _ZLE_PICKER_LABELS=(alpha beta); }
      functions[_outer_show]=$functions[_zle_picker_show]
      _zle_picker_show() {
        _outer_show
        print -r -u $_outer_event_fd -- "FRAME|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_SELECTED"
      }
      _outer_picker() {
        local result=0
        _ZLE_PICKER_COLLECTOR=_outer_collect _ZLE_PICKER_TITLE=Paste
        _zle_picker_screen_session _zle_picker_loop "" 10 || result=$?
        print -r -u $_outer_event_fd -- "RETURN|$result|$BUFFER|${+functions[TRAPINT]}"
      }
      _outer_ready() { print -r -u $_outer_event_fd READY; }
      zle -N outer-picker _outer_picker
      zle -N zle-line-init _outer_ready
      bindkey "^X^P" outer-picker
    '\'' >> "$HOME/outer.zsh"
    _outer_expect() {
      local expected=$1
      while zselect -r $efd $pfd -t 500; do
        while zpty -r outer chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
        fi
      done
      print -u2 -r -- "expected $expected; got $event"
      return 1
    }
    local -x PS1="> " PS2="> "
    zpty -b outer "$2" -dfi || exit 2
    pfd=$REPLY
    {
      zpty -w outer "source ${(q)HOME}/outer.zsh"
      _outer_expect READY || exit 3
      zpty -w -n outer $'\''original\x18\x10'\''
      _outer_expect "FRAME||1" || exit 4
      zpty -w -n outer $'\''\e[200~literal\e[201~'\''
      _outer_expect "FRAME|literal|1" || exit 5
      zpty -w -n outer $'\''\x07'\''
      _outer_expect "RETURN|1|original|0" || exit 6
      zpty -w -n outer $'\''\x03'\''
      _outer_expect READY || exit 7
      zpty -w outer '\''print -r -u $_outer_event_fd VERIFIED'\''
      _outer_expect VERIFIED || exit 8
      [[ $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 9
    } always { zpty -d outer; exec {efd}>&-; }
    print outer-editor
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN") || return
  test_assert_equal outer-editor "$output"
}
test_case 'picker paste restores native Ctrl-C in the outer interactive shell' _test_picker_paste_outer_editor
