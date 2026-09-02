# Path arguments retain their command and native completion escape hatches.
_test_directory_argument_boundaries() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Developer/Example & Co" || return
  test_write_file "$TEST_TMP_DIR/home/Developer/notes.txt" 'contents stay unread' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    builtin cd -- "$HOME" || exit
    unsetopt AUTO_CD
    local BUFFER="" CURSOR=0 draft=""
    local -i captures=0 fallback=0
    zle() { [[ $1 == expand-or-complete ]] && (( ++fallback )); return 0; }
    _zle_picker_screen_session() {
      (( ++captures ))
      _ZLE_PICKER_ACTION=select
      _ZLE_PICKER_SELECTED_VALUE=${_DIRECTORY_PICKER_VALUES[1]}
    }
    local -a drafts=(
      "vim -p ./Developer" "vim earlier.txt ~/Developer"
      "vim \"$HOME/Developer\"" "vim ~/Dev"
      "vim ./Developer/Example\\ \\&\\ Co/")
    local -a expected_paths=(
      "vim -p ./Developer/Example\\ \\&\\ Co/"
      "vim earlier.txt ~/Developer/Example\\ \\&\\ Co/"
      "vim $HOME/Developer/Example\\ \\&\\ Co/"
      "vim ~/Developer/" "vim ./Developer/Example\\ \\&\\ Co/")
    # The last case is an empty directory: cancellation still opens Browse.
    local -i index=0
    for draft in "${drafts[@]}"; do
      (( ++index ))
      if (( index == 5 )); then
        _zle_picker_screen_session() { (( ++captures )); return 1; }
      fi
      BUFFER=$draft CURSOR=${#BUFFER} captures=0 fallback=0
      _directory_context_complete_widget
      [[ $BUFFER == ${expected_paths[index]} && $CURSOR == ${#BUFFER} &&
         $captures == 1 && $fallback == 0 ]] || {
        print -u2 -r -- "argument context lost: $draft -> $BUFFER|$captures|$fallback"
        exit 1
      }
    done
    # Exact files, unmatched prefixes, shell syntax, trailing whitespace and
    # dynamic expansions belong to native completion, without opening Browse.
    drafts=("vim ./Developer/notes.txt" "vim ./Developer/notes"
      "vim ~/Developer " "vim --help" "git switch" "vim ~/Developer other"
      "echo > ~/Developer" "echo && ~/Developer" "vim ~/Developer/*"
      "vim \$HOME/Developer" "vim \$(touch marker)/Developer"
      "vim \\~/Developer" "vim \"~/Developer\"")
    for draft in "${drafts[@]}"; do
      BUFFER=$draft CURSOR=${#BUFFER} captures=0 fallback=0
      _directory_context_complete_widget
      [[ $BUFFER == "$draft" && $captures == 0 && $fallback == 1 ]] || {
        print -u2 -r -- "native argument completion intercepted: $draft|$captures|$fallback"
        exit 2
      }
    done
    BUFFER="vim ~/Developer" CURSOR=6 captures=0 fallback=0
    _directory_context_complete_widget
    [[ $BUFFER == "vim ~/Developer" && $CURSOR == 6 && $captures == 0 && $fallback == 1 &&
       ! -e marker ]] || exit 3
    print boundaries
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal boundaries "$output"
}
test_case 'directory argument completion preserves quoting, cancellation and native file contexts' \
  _test_directory_argument_boundaries

_test_directory_argument_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Developer/Example & Co/child" || return
  test_write_file "$TEST_TMP_DIR/home/Developer/notes.txt" 'unread fixture' || return
  test_write_file "$TEST_TMP_DIR/home/bin/pbcopy" $'#!/bin/zsh -df\n/bin/cat > "$HOME/copied"' || return
  command chmod +x "$TEST_TMP_DIR/home/bin/pbcopy" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$HOME/bin" "${path[@]}")
    source "$1/.zsh.addons/.zsh.editor"
    builtin cd -- "$HOME" || exit
    unsetopt AUTO_CD
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local scenario="" event="" trace="" chunk="" device="" pfd=0
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions[_argument_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _argument_show
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_QUERY|$COLUMNS"
    }
    functions[_argument_tab]=$functions[_directory_context_complete_widget]
    _argument_tab_test() {
      _argument_tab
      (( !_ZLE_PICKER_ACTIVE && !${_ZLE_PICKER_SCREEN_ACTIVE:-0} )) || print -r -u $efd BAD-CLEANUP
      [[ $PWD == "$HOME" ]] || print -r -u $efd BAD-CD
      print -r -u $efd -- "RETURNED|$BUFFER|$CURSOR"
    }
    zle -N directory-context-complete _argument_tab_test
    _argument_ready() { print -r -u $efd -- "READY|$scenario"; }
    zle -N zle-line-init _argument_ready
    _argument_probe() { print -r -u $efd PAINTED; }
    zle -N argument-probe _argument_probe
    bindkey "^X^P" argument-probe
    _argument_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "TTY|$(command tty)"
      local draft=""
      for scenario in cancel insert digit copy native; do
        draft="vim ~/Developer"
        [[ $scenario == native ]] && draft="vim ~/Developer/no"
        vared draft
      done
      print -r -u $efd DONE
    }
    _argument_expect() {
      local expected=$1
      while zselect -r $efd $pfd -t 500; do
        while zpty -r argument chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* || $event == RETURNED* ]] && break
        fi
      done
      print -u2 -r -- "expected $expected; got $event"
      return 1
    }
    zpty -b argument _argument_driver || exit 2
    pfd=$REPLY
    {
      zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 3
      device=${event#TTY|}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 4
      local expected="" remainder="" keys=""
      local -i sessions=0
      for scenario in cancel insert digit copy native; do
        _argument_expect "READY|$scenario" || exit 5
        zpty -w -n argument $'\''\t'\''
        expected="vim ~/Developer"
        if [[ $scenario == native ]]; then
          expected="vim ~/Developer/notes.txt "
        else
          (( ++sessions ))
          _argument_expect "FRAME||120" || exit 6
          case $scenario in
            (cancel)
              # Paste stays inside the filter; resize and Back retain the draft.
              zpty -w -n argument $'\''\e[200~Example\e[201~'\''
              _argument_expect "FRAME|Example|120" || exit 7
              command stty rows 20 cols 70 < "$device"
              _argument_expect "FRAME|Example|70" || exit 8
              command stty rows 30 cols 120 < "$device"
              _argument_expect "FRAME|Example|120" || exit 9
              keys=$'\''\e'\'' ;;
            (insert) keys=$'\''\r'\''; expected="vim ~/Developer/Example\\ \\&\\ Co/" ;;
            (digit) keys=1; expected="vim ~/Developer/Example\\ \\&\\ Co/" ;;
            (copy) keys=$'\''\x19'\'' ;;
          esac
          zpty -w -n argument "$keys"
        fi
        _argument_expect "RETURNED|$expected|${#expected}" || exit 10
        zpty -w -n argument $'\''\x0c\x18\x10'\''
        _argument_expect PAINTED || exit 11
        [[ $trace == *"${expected% }"* ]] || { print -u2 "completed $scenario command was not painted"; exit 12; }
        zpty -w -n argument $'\''\r'\''
      done
      _argument_expect DONE || exit 13
      [[ $(<"$HOME/copied") == "$HOME/Developer/Example & Co" ]] || exit 14
      remainder=${trace//$enter/}
      (( (${#trace} - ${#remainder}) / ${#enter} == sessions )) || exit 15
      remainder=${trace//$leave/}
      (( (${#trace} - ${#remainder}) / ${#leave} == sessions )) || exit 16
      [[ $trace != *"bad pattern"* && $trace != *"command not found"* && $trace != *"widgets can only"* ]] || exit 17
    } always {
      zpty -d argument 2>/dev/null
      exec {efd}>&-
    }
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'directory argument native ZLE accepts, cancels, copies, resizes and completes files' \
  _test_directory_argument_native
