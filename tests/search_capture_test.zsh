# Search source choice is scoped and resolved once, before query submission.
_test_search_default_sources() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Repo/Sub" "$TEST_TMP_DIR/home/Ordinary" || return
  test_write_file "$TEST_TMP_DIR/bin/git" $'#!/bin/zsh\nprint -rl -- "$@" >| "$HOME/git-args"\n[[ $2 == "$HOME/Repo" || $2 == "$HOME/Repo/"* ]] || exit 1\nprint true' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2" "${path[@]}")
    source "$1/.zshrc"
    (( ${+functions[_file_search_default_provider]} )) || { print -u2 "Missing scoped default-source selection"; exit 1; }
    local root="" expected="" mode=insert
    local _directory_browser_clipboard="" _directory_browser_open=""
    local -i queries=0 captures=0
    _files_read_query() {
      (( ++queries ))
      [[ $2 == "$expected · $root" && $captures == 0 ]] || return 20
      return 1
    }
    _file_search_capture() { (( ++captures )); return 21; }
    for root expected in "$HOME/Repo/Sub" git "$HOME" spotlight / spotlight "$HOME/Ordinary" local; do
      _file_search_default_provider "$root"
      [[ $REPLY == "$expected" ]] || exit 2
      _file_search_choose "$root" "" auto
      (( $? == 1 && captures == 0 )) || exit 3
    done
    # An explicit source stays explicit; a cancelled query does no discovery.
    root=$HOME expected=local
    _file_search_choose "$root" "" local
    (( $? == 1 && queries == 5 && captures == 0 )) || exit 4
    path=("$2")
    _file_search_default_provider "$HOME"
    [[ $REPLY == spotlight ]] || exit 5
    _file_search_capture_spotlight "$HOME" needle
    (( $? == 2 && captures == 0 )) || exit 6
    OSTYPE=linux-gnu
    _file_search_default_provider "$HOME"
    [[ $REPLY == local ]] || exit 7
    print defaults
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin") || return
  test_assert_equal defaults "$output"
}
test_case 'search defaults keep Git scoped and use Spotlight for home and root without eager capture' _test_search_default_sources

_test_search_provider_failures() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/needle.txt" fixture || return
  test_write_file "$TEST_TMP_DIR/home/needle-two.txt" fixture || return
  test_write_file "$TEST_TMP_DIR/bin/git" $'#!/bin/zsh\nwhile [[ $1 == -C || $1 == -c ]]; do shift 2; done\n[[ $1 == rev-parse ]] && { print true; exit 0; }\n(( ${EMIT:-0} )) && printf "needle.txt\\0"\nexit "${FAILURE:-0}"' || return
  test_write_file "$TEST_TMP_DIR/bin/mdfind" $'#!/bin/zsh\n(( ${EMIT:-0} )) && printf "%s\\0" "$HOME/needle.txt"\n(( ${EMIT:-0} > 1 )) && printf "%s\\0" "$HOME/needle-two.txt"\nexit "${FAILURE:-0}"' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" "$TEST_TMP_DIR/bin/mdfind" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2" "${path[@]}")
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/support/.zsh.matching"
    local provider=""
    export EMIT=0 FAILURE=0
    for provider in git spotlight; do
      _file_search_capture "$HOME" needle "$provider"
      (( $? == 1 && ! ${#_FILE_SEARCH_VALUES} )) || exit 1
      FAILURE=23
      _file_search_capture "$HOME" needle "$provider"
      (( $? == 2 && ! ${#_FILE_SEARCH_VALUES} )) || { print -u2 -- "$provider failure was reported as no matches"; exit 2; }
      EMIT=1
      _file_search_capture "$HOME" needle "$provider"
      (( $? == 2 && ${#_FILE_SEARCH_VALUES} == 1 && _FILE_SEARCH_TRUNCATED )) || exit 3
      EMIT=0 FAILURE=0
    done
    ZSH_FILE_SEARCH_MAX_CANDIDATES=1 EMIT=2 FAILURE=23
    _file_search_capture "$HOME" needle spotlight
    (( $? == 0 && ${#_FILE_SEARCH_VALUES} == 1 && _FILE_SEARCH_TRUNCATED )) || exit 4
    print failures
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin") || return
  test_assert_equal failures "$output"
}
test_case 'search distinguishes successful empty sources from failures and labels partial output' _test_search_provider_failures

_test_search_capture_status() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    (( ${+functions[_zle_picker_capture]} )) || { print -u2 "Missing capture status boundary"; exit 1; }
    local -i painted=0 calls=0 _ZLE_PICKER_SCREEN_ACTIVE=1
    local _ZLE_PICKER_TITLE=Caller _ZLE_PICKER_QUERY=original
    zle() { return 0; }
    functions[_capture_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _capture_show
      (( ++painted ))
      [[ $_ZLE_PICKER_BUSY == 1 && $_ZLE_PICKER_ACTIVE == 0 &&
         $_ZLE_PICKER_POSTDISPLAY == *Searching* &&
         $_ZLE_PICKER_POSTDISPLAY != *"0 shown"* &&
         $_ZLE_PICKER_POSTDISPLAY != *"Esc back"* &&
         $_ZLE_PICKER_POSTDISPLAY != *"Enter:"* ]] || return 20
      local row
      for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
        (( ${(m)#row} < COLUMNS )) || return 21
      done
    }
    _capture_probe() {
      (( ++calls ))
      (( painted == calls && !_ZLE_PICKER_ACTIVE && _ZLE_PICKER_BUSY )) || return 22
      [[ $_ZLE_PICKER_QUERY == "literal ; * query" && $1 == "$HOME" ]] || return 23
      _zle_picker_redraw || return 24
      (( ++calls ))
      return 19
    }
    for COLUMNS LINES in 120 30 40 15 12 10; do
      _zle_picker_capture Files "spotlight · $HOME" "literal ; * query" _capture_probe "$HOME"
      (( $? == 19 && ! ${_ZLE_PICKER_BUSY:-0} )) || exit 2
      [[ $_ZLE_PICKER_TITLE == Caller && $_ZLE_PICKER_QUERY == original ]] || exit 3
    done
    print status
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal status "$output"
}
test_case 'search capture paints honest responsive status before work and restores caller state' _test_search_capture_status

# A FIFO-gated provider models first-use latency without reading private files,
# flushing system caches, or relying on arbitrary sleeps. No real mdfind runs.
_test_search_capture_native() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/Records/needle.txt" fixture || return
  test_write_file "$TEST_TMP_DIR/bin/git" $'#!/bin/zsh\nexit 1' || return
  test_write_file "$TEST_TMP_DIR/bin/mdfind" $'#!/bin/zsh\nprint -rl -- "$@" >> "$HOME/mdfind-args"\nprint STARTED > "$HOME/events"\nIFS= read -r release < "$HOME/gate"\nprintf "%s\\0" "$HOME/Records/needle.txt"' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" "$TEST_TMP_DIR/bin/mdfind" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$2" "${path[@]}")
    source "$1/.zshrc"
    [[ $commands[mdfind] == "$2/mdfind" && $commands[git] == "$2/git" ]] || exit 1
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" "$HOME/gate" || exit 2
    exec {efd}<> "$HOME/events"
    exec {gate_fd}<> "$HOME/gate"
    local event="" trace="" chunk="" device="" pfd=0 captures=0
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions[_capture_native_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _capture_native_show
      if [[ $_ZLE_PICKER_TITLE == "Search descendants" || $_ZLE_PICKER_TITLE == Files ]]; then
        [[ $_ZLE_PICKER_SUBTITLE == "spotlight · $HOME" ]] || print -r -u $efd BAD-SOURCE
      fi
      if (( ${_ZLE_PICKER_BUSY:-0} )); then
        [[ $_ZLE_PICKER_POSTDISPLAY == *Searching* &&
           $_ZLE_PICKER_POSTDISPLAY != *"0 shown"* ]] || print -r -u $efd BAD-BUSY
      elif [[ $_ZLE_PICKER_TITLE == Files ]]; then
        [[ ${_FILE_SEARCH_VALUES[1]} == "$HOME/Records/needle.txt" ]] || print -r -u $efd BAD-RESULT
      fi
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|${_ZLE_PICKER_BUSY:-0}|$COLUMNS|$LINES"
    }
    functions[_capture_native_source]=$functions[_file_search_capture_spotlight]
    _file_search_capture_spotlight() {
      (( ++captures ))
      (( !_ZLE_PICKER_ACTIVE && _ZLE_PICKER_SCREEN_ACTIVE && _ZLE_PICKER_BUSY )) || print -r -u $efd BAD-CAPTURE
      _capture_native_source "$@"
    }
    _file_search_capture_local() { print -r -u $efd BAD-WALK; return 2; }
    functions[_capture_native_widget]=$functions[_directory_context_complete_widget]
    _capture_native_test_widget() {
      _capture_native_widget
      [[ $BUFFER == "$HOME/" && $CURSOR == ${#BUFFER} && $captures == 2 &&
         $_ZLE_PICKER_ACTIVE == 0 && ${_ZLE_PICKER_BUSY:-0} == 0 &&
         ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]] || print -r -u $efd BAD-RESTORE
      print -r -u $efd RETURNED
    }
    zle -N directory-context-complete _capture_native_test_widget
    _capture_native_ready() { print -r -u $efd READY; }
    zle -N zle-line-init _capture_native_ready
    _capture_native_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "TTY:$(command tty)"
      local draft="$HOME/"
      vared draft
      print -r -u $efd DONE
    }
    _capture_native_expect() {
      local expected=$1
      while zselect -r $efd $pfd -t 500; do
        while zpty -r capture chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" || $expected == '"'"'TTY:*'"'"' && $event == TTY:* ]] && return 0
          [[ $event == BAD-* || $event == STARTED ]] && break
        fi
      done
      print -u2 -r -- "expected $expected; got $event"
      return 1
    }
    zpty -b capture _capture_native_driver || exit 3
    pfd=$REPLY
    {
      _capture_native_expect "TTY:*" || exit 4
      device=${event#TTY:}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 5
      _capture_native_expect READY || exit 6
      zpty -w -n capture $'\''\t'\''
      _capture_native_expect "FRAME|Directory browser||0|120|30" || exit 7
      zpty -w -n capture $'\''\x06needle'\''
      _capture_native_expect "FRAME|Search descendants|needle|0|120|30" || exit 8
      [[ ! -e "$HOME/mdfind-args" ]] || exit 9
      zpty -w -n capture $'\''\r'\''
      _capture_native_expect "FRAME|Files|needle|1|120|30" || exit 10
      _capture_native_expect STARTED || exit 11
      # A blocking provider read can defer SIGWINCH. Once it returns, results
      # must use the new dimensions without recapture or another screen session.
      command stty rows 18 cols 70 < "$device"
      print -r -u $gate_fd release
      _capture_native_expect "FRAME|Files||0|70|18" || exit 13
      zpty -w -n capture $'\''\x06'\''
      _capture_native_expect "FRAME|Search descendants|needle|0|70|18" || exit 14
      zpty -w -n capture $'\''\r'\''
      _capture_native_expect "FRAME|Files|needle|1|70|18" || exit 15
      _capture_native_expect STARTED || exit 16
      print -r -u $gate_fd release
      _capture_native_expect "FRAME|Files||0|70|18" || exit 17
      zpty -w -n capture $'\''\e'\''
      _capture_native_expect "FRAME|Directory browser||0|70|18" || exit 18
      zpty -w -n capture $'\''\e'\''
      _capture_native_expect RETURNED || exit 19
      zpty -w -n capture $'\''\r'\''
      _capture_native_expect DONE || exit 20
      [[ $(<"$HOME/mdfind-args") == $(printf "%s\n" -0 -onlyin "${HOME:A}" -name needle -0 -onlyin "${HOME:A}" -name needle) ]] || exit 21
      [[ $trace == *"$enter"*"$leave"* ]] || exit 22
      trace=${trace/"$enter"/}
      trace=${trace/"$leave"/}
      [[ $trace != *"$enter"* && $trace != *"$leave"* &&
         $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 23
    } always {
      print -r -u $gate_fd release
      zpty -d capture
      exec {efd}>&-
      exec {gate_fd}>&-
    }
    print native-capture
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin") || return
  test_assert_equal native-capture "$output"
}
test_case 'search native home capture paints before delayed source and survives resize and repeat' _test_search_capture_native
