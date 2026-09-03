# A browsing journey owns one terminal screen, including its secondary views.
# Observe the actual control stream; frame events use a separate FIFO.
_test_directory_transition_screen() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/alpha/child" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.prompt"
    setopt AUTO_CD
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions[_transition_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
    _transition_show
      (( BUFFERLINES == LINES - 1 )) || print -r -u $efd BAD-GEOMETRY
      print -r -u $efd -- "FRAME:$_ZLE_PICKER_TITLE:$COLUMNS:$LINES"
    }
    read() {
      [[ $scenario == read-fail && ${#_DIRECTORY_PICKER_STACK} == 1 &&
         $1 == -r && $2 == -k && $4 == key ]] && return 1
      builtin read "$@"
    }
    functions[_transition_capture]=$functions[_directory_picker_transition]
    _directory_picker_transition() {
      [[ $scenario == capture-fail ]] && return 2
      # A resize between input loops must not rebuild the normal shell prompt.
      if [[ $scenario == command ]]; then
        local -i in_transition_capture=1
        TRAPWINCH
      fi
      _transition_capture "$@"
    }
    zle() {
      if (( ${in_transition_capture:-0} )) &&
         [[ $1 == reset-prompt || $1 == -R || $1 == .clear-screen ]]; then
        print -r -u $efd BAD-CAPTURE-REPAINT
      fi
      builtin zle "$@"
      local -i zle_result=$?
      if [[ $scenario == abort && $1 == .redisplay && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]]; then
        [[ $_ZLE_PICKER_ACTIVE == 0 && $_ZLE_AUTOSUGGEST_SUSPENDED == 0 &&
           -z $BUFFER && -z $POSTDISPLAY ]] || print -r -u $efd BAD-ABORT-STATE
        print -r -u $efd CLOSED
      fi
      return $zle_result
    }
    _transition_widget() {
      BUFFER="~/Projects/" CURSOR=11 MARK=3
      PREDISPLAY=prefix POSTDISPLAY=suffix
      region_highlight=("0 1 bold memo=fixture")
      _directory_browser_session "$BUFFER" insert widget
      [[ $? == 1 && $BUFFER == "~/Projects/" && $CURSOR == 11 && $MARK == 3 &&
         $PREDISPLAY == prefix && $POSTDISPLAY == suffix &&
         ${(j: :)region_highlight} == "0 1 bold memo=fixture" ]] || print -r -u $efd BAD-STATE
      print -r -u $efd DONE
      zle .accept-line
    }
    zle -N transition-test _transition_widget
    bindkey "^X^T" transition-test
    _transition_ready() { print -r -u $efd ZLE-READY; }
    chpwd() {
      [[ -z ${_zle_picker_session_callback:-} && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 &&
         $_ZLE_PICKER_ACTIVE == 0 ]] || print -r -u $efd BAD-ACTION-BOUNDARY
    }
    _transition_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "READY:$(command tty)"
      if [[ $scenario == widget ]]; then
        add-zle-hook-widget line-init _transition_ready
        local draft=""
        vared draft
      else
        _directory_browser_session "~/Projects/" cd command
        local -i result=$?
        if [[ $scenario == accept ]]; then
          [[ $result == 0 && $PWD == "$HOME/Projects/alpha/child" ]] || print -r -u $efd BAD-ACCEPT
        else
          [[ $result == 1 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]] || print -r -u $efd BAD-STATE
        fi
        print -r -u $efd DONE
      fi
    }
    _transition_expect() {
      local wanted=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r transition chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; got $event"
      return 1
    }
    _transition_stays_open() {
      local tail=${trace#*"$enter"}
      [[ $trace == *"$enter"* && $tail != *"$enter"* && $trace != *"$leave"* ]] || {
        print -u2 -r -- "$scenario: directory transition exposed the main terminal"
        return 1
      }
    }
    local scenario="" trace="" event="" device="" pfd=0 key=""
    for scenario in widget command accept read-fail capture-fail abort; do
      trace=""
      zpty -b transition _transition_driver || exit 2
      pfd=$REPLY
      {
        zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 3
        device=${event#READY:}
        if [[ $scenario == widget ]]; then
          _transition_expect ZLE-READY || exit 4
          zpty -w -n transition $'\''\x18\x14'\''
        fi
        _transition_expect "FRAME:Directory browser:120:30" || exit 4
        _transition_stays_open || exit 5
        if [[ $scenario == read-fail || $scenario == capture-fail ]]; then
          zpty -w -n transition $'\''\e[C'\''
          _transition_expect DONE || exit 14
        elif [[ $scenario == abort || $scenario == accept ]]; then
          zpty -w -n transition $'\''\e[C'\''
          _transition_expect "FRAME:Directory browser:120:30" || exit 6
          _transition_stays_open || exit 7
          if [[ $scenario == abort ]]; then
            zpty -w -n transition $'\''\x03'\''
            _transition_expect CLOSED || exit 14
          else
            zpty -w -n transition $'\''\r'\''
            _transition_expect DONE || exit 14
          fi
        else
        # Child, grandchild, parent, visibility, preview: all remain in-screen.
        for key in $'\''\e[C'\'' $'\''\t'\'' $'\''\e[D'\'' $'\''\x14'\'' $'\''\x0f'\''; do
          zpty -w -n transition "$key"
          _transition_expect "FRAME:Directory browser:120:30" || exit 6
          _transition_stays_open || exit 7
        done
        zpty -w -n transition $'\''\x18'\''
        _transition_expect "FRAME:Folder actions:120:30" || exit 8
        _transition_stays_open || exit 9
        zpty -w -n transition $'\''\x07'\''
        _transition_expect "FRAME:Directory browser:120:30" || exit 10
        _transition_stays_open || exit 11
        command stty rows 14 cols 70 < "$device"
        _transition_expect "FRAME:Directory browser:70:14" || exit 12
        _transition_stays_open || exit 13
        zpty -w -n transition $'\''\x07'\''
        _transition_expect DONE || exit 14
        fi
        [[ $trace == *"$enter"*"$leave"* &&
           $trace != *$'\''\e[3J'\''* && $trace != *"read-only variable"* ]] || exit 15
        (( ${#trace} - ${#${trace//"$leave"/}} == ${#leave} )) || exit 15
      } always {
        zpty -d transition
      }
    done
    print seamless
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal seamless "$output"
}
test_case 'directory transitions keep one screen through hierarchy preview actions resize and failures' _test_directory_transition_screen
