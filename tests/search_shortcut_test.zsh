# Search is an explicit scoped discovery step; filtering remains memory-only.
_test_search_shortcut_labels() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    [[ $(bindkey "^F") == *autosuggest-accept-character* && $(bindkey "^E") == *autosuggest-accept-all* ]] || exit 1
    local label="" row="" query="long query with fragments" footer=""
    _ZLE_PICKER_RESULTS=(example) _ZLE_PICKER_LABELS=(example)
    _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_SCREEN_ACTIVE=1
    LINES=40 COLUMNS=120
    for label in "Filter folders" "Search descendants" "Filter results"; do
      _ZLE_PICKER_QUERY_LABEL=$label
      _zle_picker_render "$query" 1
      [[ $_ZLE_PICKER_QUERY_ROW == "$label "* &&
         $_ZLE_PICKER_QUERY_START == $(( ${#label} + 1 )) ]] || exit 2
      for COLUMNS in 4 12 24 40 120; do
        _zle_picker_render "$query" 1
        (( ${(m)#_ZLE_PICKER_QUERY_ROW} < COLUMNS )) || exit 3
        (( _ZLE_PICKER_QUERY_END == ${#_ZLE_PICKER_QUERY_ROW} )) || exit 4
      done
    done
    _ZLE_PICKER_SEARCH_ACTION=search-local
    _zle_picker_footer 119 ""
    [[ $REPLY == *"^F search"* ]] || exit 5
    _ZLE_PICKER_SEARCH_ACTION=""
    _zle_picker_footer 119 ""
    [[ $REPLY != *"^F search"* ]] || exit 6
    print labels
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal labels "$output"
}
test_case 'scoped Search labels and shortcut hints distinguish discovery from filtering' _test_search_shortcut_labels

_test_search_shortcut_browser() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Root/Selected" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local _DIRECTORY_PICKER_LOCATION="$HOME/Root/" mode=insert
    local _directory_browser_clipboard="" _directory_browser_open=""
    local -a _DIRECTORY_PICKER_RESUME=(filter 2 1)
    local -i picks=0 searches=0 result_limit=10
    _directory_browser_pick() {
      (( ++picks ))
      [[ $_ZLE_PICKER_QUERY_LABEL == "Filter folders" &&
         $_ZLE_PICKER_SEARCH_ACTION == search-auto ]] || return 20
      if (( picks == 1 )); then
        _ZLE_PICKER_ACTION=search-auto
        _ZLE_PICKER_SELECTED_VALUE="$HOME/Root/Selected/"
        _ZLE_PICKER_BOOKMARK=(filter 2 1)
        _ZLE_PICKER_BOOKMARK_FOCUS=1
      else
        [[ $2 == filter && $3 == 2 && $4 == 1 && $_zle_picker_start_focus == 1 ]] || return 21
        return 1
      fi
    }
    _file_search_choose() {
      (( ++searches ))
      [[ $1 == "$HOME/Root" && -z $2 && $3 == auto ]] || return 22
      return 1
    }
    _directory_browser_choose
    [[ $? == 1 && $picks == 2 && $searches == 1 ]] || exit 1
    # Secondary menus must not inherit the browser discovery key or label.
    local _ZLE_PICKER_SEARCH_ACTION=search-local _ZLE_PICKER_QUERY_LABEL="Filter folders"
    _directory_browser_pick() {
      [[ -z $_ZLE_PICKER_SEARCH_ACTION && $_ZLE_PICKER_QUERY_LABEL == "Filter actions" ]] || return 23
      return 1
    }
    _directory_browser_actions "" insert
    [[ $? == 1 ]] || exit 2
    print scope
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scope "$output"
}
test_case 'scoped Search uses displayed folder and restores browser bookmark and focus' _test_search_shortcut_browser

_test_search_shortcut_refresh() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -i captures=0 picks=0 queries=0
    local _directory_browser_clipboard="" _directory_browser_open="" mode=insert
    _file_search_capture() {
      (( ++captures ))
      [[ $1 == "$HOME" && $3 == local ]] || return 20
      [[ $captures == 1 && $2 == original || $captures == 2 && $2 == revised ]] || return 21
      _file_search_reset
    }
    _zle_picker_loop() {
      (( ++picks ))
      [[ $_ZLE_PICKER_QUERY_LABEL == "Filter results" &&
         $_ZLE_PICKER_SEARCH_ACTION == search-local ]] || return 22
      if (( picks == 2 )); then
        [[ $1 == narrow && $3 == 2 && $4 == 1 && $captures == 1 && $_zle_picker_start_focus == 1 ]] || return 23
      elif (( picks == 3 )); then
        [[ -z $1 && $3 == 1 && $4 == 0 && $captures == 2 ]] || return 24
        return 1
      fi
      _ZLE_PICKER_ACTION=search-local
      _ZLE_PICKER_BOOKMARK=(narrow 2 1)
      _ZLE_PICKER_BOOKMARK_FOCUS=1
    }
    _files_read_query() {
      (( ++queries ))
      [[ $3 == original ]] || return 25
      (( queries == 1 )) && return 1
      _ZLE_PICKER_SELECTED_VALUE=revised
    }
    _file_search_choose "$HOME" original local
    [[ $? == 1 && $captures == 2 && $queries == 2 && $picks == 3 ]] || exit 1
    print refreshed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refreshed "$output"
}
test_case 'scoped Search resubmits explicitly and cancelling preserves captured results' _test_search_shortcut_refresh

_test_search_shortcut_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Root/Selected" "$TEST_TMP_DIR/home/Root/Other/deep" || return
  test_write_file "$TEST_TMP_DIR/home/Root/Other/deep/needle.txt" contents || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local event="" trace="" chunk="" pfd=0 captures=0
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions[_search_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _search_show
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_INSPECT_FOCUS"
    }
    functions[_search_capture]=$functions[_file_search_capture]
    _file_search_capture() {
      (( !_ZLE_PICKER_ACTIVE && _ZLE_PICKER_SCREEN_ACTIVE )) || print -r -u $efd BAD-ACTIVE-SCAN
      [[ $1 == "$HOME/Root" && $2 == needle && $3 == local ]] || print -r -u $efd BAD-SCOPE
      (( ++captures ))
      print -r -u $efd CAPTURE
      _search_capture "$@"
    }
    functions[_search_widget]=$functions[_directory_context_complete_widget]
    _search_widget_test() {
      _search_widget
      [[ $BUFFER == "$HOME/Root/" && $CURSOR == ${#BUFFER} && $captures == 1 &&
         $_ZLE_PICKER_ACTIVE == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]] ||
        print -r -u $efd -- "BAD-RESTORE|$BUFFER|$CURSOR|$captures|$_ZLE_PICKER_ACTIVE|$_ZLE_PICKER_SCREEN_ACTIVE"
      print -r -u $efd RETURNED
    }
    zle -N directory-context-complete _search_widget_test
    _search_ready() { print -r -u $efd READY; }
    zle -N zle-line-init _search_ready
    _search_driver() {
      command stty rows 30 cols 120
      local draft="$HOME/Root/"
      vared draft
      print -r -u $efd DONE
    }
    _search_expect() {
      local expected=$1
      while zselect -r $efd $pfd -t 500; do
        while zpty -r search chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* || $event == CAPTURE ]] && break
        fi
      done
      print -u2 -r -- "expected $expected; got $event"
      return 1
    }
    zpty -b search _search_driver || exit 2
    pfd=$REPLY
    {
      _search_expect READY || exit 3
      zpty -w -n search $'\''\t'\''
      _search_expect "FRAME|Directory browser||0" || exit 4
      zpty -w -n search Selected
      _search_expect "FRAME|Directory browser|Selected|0" || exit 5
      zpty -w -n search $'\''\x0f\x05'\''
      _search_expect "FRAME|Directory browser|Selected|1" || exit 6
      zpty -w -n search $'\''\x06'\''
      _search_expect "FRAME|Search descendants||0" || exit 7
      zpty -w -n search needle
      _search_expect "FRAME|Search descendants|needle|0" || exit 8
      zpty -w -n search $'\''\x0c'\''
      _search_expect "FRAME|Search descendants|needle|0" || exit 23
      # No discovery occurred while typing. Cancel restores filter and focus.
      zpty -w -n search $'\''\e'\''
      _search_expect "FRAME|Directory browser|Selected|1" || exit 9
      zpty -w -n search $'\''\x06needle'\''
      _search_expect "FRAME|Search descendants|needle|0" || exit 10
      zpty -w -n search $'\''\r'\''
      _search_expect CAPTURE || exit 11
      _search_expect "FRAME|Files||0" || exit 12
      zpty -w -n search txt
      _search_expect "FRAME|Files|txt|0" || exit 24
      zpty -w -n search $'\''\x15'\''
      _search_expect "FRAME|Files||0" || exit 25
      zpty -w -n search $'\''\x06'\''
      _search_expect "FRAME|Search descendants|needle|0" || exit 13
      zpty -w -n search $'\''\e'\''
      _search_expect "FRAME|Files||0" || exit 14
      zpty -w -n search $'\''\r'\''
      _search_expect "FRAME|File actions||0" || exit 15
      zpty -w -n search $'\''\x06'\''
      _search_expect "FRAME|File actions||0" || exit 16
      zpty -w -n search $'\''\e'\''
      _search_expect "FRAME|Files||0" || exit 17
      zpty -w -n search $'\''\e'\''
      _search_expect "FRAME|Directory browser|Selected|1" || exit 18
      zpty -w -n search $'\''\e'\''
      _search_expect RETURNED || exit 19
      zpty -w -n search $'\''\r'\''
      _search_expect DONE || exit 20
      [[ $trace == *"$enter"* && $trace == *"$leave"* ]] || exit 21
      trace=${trace/"$enter"/}
      trace=${trace/"$leave"/}
      [[ $trace != *"$enter"* && $trace != *"$leave"* &&
         $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 22
    } always {
      zpty -d search
    }
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'scoped Search native Ctrl-F journey submits once and preserves screen draft and focus' _test_search_shortcut_native
