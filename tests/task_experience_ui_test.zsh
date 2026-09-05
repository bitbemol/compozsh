# Real ZLE: enter from a draft, read/filter/resize, return and keep editing.
_test_task_native_draft_journey() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.help"
    _compozsh_tool_capture() {
      _COMPOZSH_TOOL_NAMES=(example) _COMPOZSH_TOOL_LABELS=(example)
      _COMPOZSH_TOOL_SEARCH_TEXTS=(example) _COMPOZSH_TOOL_INDEXES=(1)
    }
    _compozsh_tool_inspector_capture() {
      _ZLE_PICKER_INSPECT_TEXTS=(example $'"'"'usage: example\nRead a synthetic guide.'"'"')
    }
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local event="" trace="" pfd=0 device=""
    functions[_task_native_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _task_native_show
      [[ $_ZLE_PICKER_POSTDISPLAY == *"$_ZLE_PICKER_TITLE"* ]] || print -u $efd BAD-PAINT
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$COLUMNS|$_ZLE_PICKER_SELECTED"
    }
    _task_init() {
      CURSOR=4
      print -r -u $efd READY
    }
    _task_probe() {
      [[ $BUFFER == "$draft_original" && $CURSOR == 4 &&
         ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 &&
         -z ${_DRAFT_INSPECT_BUFFER-} && ${#_ZLE_PICKER_DOCUMENT_LINES} == 0 ]] || {
        print -r -u $efd -- "BAD-RESTORE|${(V)BUFFER}|$CURSOR|$_ZLE_PICKER_SCREEN_ACTIVE|$_ZLE_PICKER_ACTIVE|${(V)_DRAFT_INSPECT_BUFFER}|${#_ZLE_PICKER_DOCUMENT_LINES}"; return
      }
      print -r -u $efd RESTORED
    }
    zle -N zle-line-init _task_init
    _task_open() { _draft_inspect_widget; print -r -u $efd CLOSED; }
    zle -N compozsh-inspect _task_open
    zle -N task-probe _task_probe
    bindkey "^X^Z" task-probe
    _task_driver() {
      command stty rows 30 cols 120
      local draft_original=$'"'"'git status; $(never-run)\nsecond [literal] line'"'"'
      local draft=$draft_original
      print -r -u $efd -- "SOURCE|$(command tty)"
      vared draft
      [[ $draft == "$draft_original" ]] || print -r -u $efd BAD-DRAFT
      print -r -u $efd DONE
    }
    _task_expect() {
      local wanted=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r journey chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted"* ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; received $event; trace ${(V)trace[-1000,-1]}"
      return 1
    }
    zpty -b journey _task_driver || exit 2
    pfd=$REPLY
    {
      _task_expect SOURCE || exit 3
      device=${event#SOURCE|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
      _task_expect READY || exit 5
      zpty -w -n journey $'"'"'\e\r'"'"'
      _task_expect "FRAME|Draft / Inspect||120|1" || exit 6
      zpty -w -n journey $'"'"'\r'"'"'
      _task_expect "FRAME|Draft / Read||120|0" || exit 7
      zpty -w -n journey "[literal]"
      _task_expect "FRAME|Draft / Read|[literal]|120|0" || exit 8
      command stty rows 16 cols 40 < "$device"
      _task_expect "FRAME|Draft / Read|[literal]|40|0" || exit 9
      zpty -w -n journey $'"'"'\e'"'"'
      _task_expect "FRAME|Draft / Inspect||40|1" || exit 10
      zpty -w -n journey 4
      _task_expect "FRAME|Tool explorer||40|1" || exit 15
      zpty -w -n journey 1
      _task_expect "FRAME|Help / example||40|1" || exit 16
      zpty -w -n journey $'"'"'\e'"'"'
      _task_expect "FRAME|Tool explorer||40|1" || exit 17
      zpty -w -n journey 1
      _task_expect "FRAME|Help / example||40|1" || exit 18
      zpty -w -n journey $'"'"'\e'"'"'
      _task_expect "FRAME|Tool explorer||40|1" || exit 19
      zpty -w -n journey $'"'"'\e'"'"'
      _task_expect "FRAME|Draft / Inspect||40|4" || exit 20
      zpty -w -n journey $'"'"'\e'"'"'
      _task_expect CLOSED || exit 14
      zpty -w -n journey $'"'"'\x18\x1a'"'"'
      _task_expect RESTORED || exit 11
      zpty -w -n journey $'"'"'\r'"'"'
      _task_expect DONE || exit 12
      [[ $trace == *$'"'"'\e[?1049h'"'"'* && $trace == *$'"'"'\e[?1049l'"'"'* &&
         $trace != *"read-only variable"* && $trace != *"command not found"* ]] || exit 13
    } always {
      zpty -d journey
    }
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'task experience native draft reading resize and Back restore exact editor state' _test_task_native_draft_journey

_test_task_native_discard_journey() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.ui"
    command git init -q "$HOME/repo"
    print -r -- baseline > "$HOME/repo/tracked"
    command git -C "$HOME/repo" add tracked
    command git -C "$HOME/repo" -c user.name=Fixture -c user.email=fixture@example.invalid commit -qm baseline
    print -r -- disposable > "$HOME/repo/untracked"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    local event="" chunk="" pfd=0 scenario="" trace=""
    functions[_discard_native_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _discard_native_show
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE"
    }
    _discard_driver() {
      command stty rows 30 cols 120
      builtin cd "$HOME/repo"
      g --discard-all
      local -i result=$?
      [[ ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 ]] || print -u $efd BAD-CLEANUP
      if [[ $scenario == cancel ]]; then
        [[ $result == 1 && -f untracked ]] || print -u $efd BAD-CANCEL
      else
        [[ $result == 0 && ! -e untracked ]] || print -u $efd -- "BAD-APPLY|$result|${_ZLE_PICKER_SELECTED_VALUE}"
      fi
      print -r -u $efd DONE
    }
    _discard_expect() {
      local wanted=$1
      while zselect -r $efd $pfd -t 500; do
        while zpty -r discard chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "$scenario expected $wanted, received $event; ${(V)trace[-1300,-1]}"
      return 1
    }
    for scenario in cancel apply; do
      zpty -b discard _discard_driver || exit 1
      pfd=$REPLY
      {
        _discard_expect "FRAME|Git / Discard confirmation" || exit 2
        [[ $scenario == apply ]] && zpty -w -n discard y
        zpty -w -n discard $'"'"'\r'"'"'
        _discard_expect DONE || exit 3
      } always {
        zpty -d discard
      }
    done
    [[ $trace != *"read-only variable"* && $trace != *"command not found"* ]] || exit 4
    print confirmed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal confirmed "$output"
}
test_case 'task experience native Git confirmation cancels by default and applies only after acceptance' _test_task_native_discard_journey
