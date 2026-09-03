# Acceptance chrome follows the same current capability as native Enter.
_test_ui_chrome_acceptance() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    COLUMNS=120 LINES=100
    _ZLE_PICKER_SCREEN_ACTIVE=1
    _chrome_view() {
      local scenario=$1 query=$2
      _ZLE_PICKER_TITLE=Fixture _ZLE_PICKER_INSPECT_ACTION=use
      _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
      if [[ $scenario == choice ]]; then
        _ZLE_PICKER_RESULTS=(target) _ZLE_PICKER_LABELS=(Target)
      fi
      _zle_picker_render "$query" 1
      local title=$_ZLE_PICKER_TITLEBAR footer=${_ZLE_PICKER_DISPLAY[-1]}
      if [[ $scenario == query ]]; then
        [[ $title == *"Enter: use · Query"* && $title != *"No selection"* ]] || {
          print -u2 -- "literal query title loses acceptance meaning: $title"; return 1
        }
      elif [[ $scenario == blank ]]; then
        [[ $title == *"Enter text"* && $title != *"No selection"* ]] || {
          print -u2 -- "empty literal field presents a selection: $title"; return 2
        }
      fi
      if [[ $scenario == (empty|blank) ]]; then
        [[ $footer != *⏎* && $footer == *"Esc back"* && $footer == *"^K keys"* ]] || {
          print -u2 -- "unavailable Enter is advertised: $footer"; return 3
        }
      else
        [[ $footer == *"⏎ use"* ]] || return 4
      fi
      _ZLE_PICKER_GUIDE_ACTIVE=1
      _zle_picker_render "$query" 1
      local guide=${(j:\n:)_ZLE_PICKER_DISPLAY}
      if [[ $scenario == (empty|blank) ]]; then
        [[ $guide != *"Enter                Apply"* ]] || return 5
      else
        [[ $guide == *"Enter                Apply"* ]] || return 6
      fi
      _ZLE_PICKER_GUIDE_ACTIVE=0
      if [[ $scenario == empty ]]; then
        _zle_picker_footer 3 "$query"
        [[ $REPLY == Esc ]] || return 7
      fi
    }
    if [[ $2 == query ]]; then
      _zle_ui_view query _chrome_view query draft || exit 1
      _zle_ui_view query _chrome_view blank "  " || exit 2
    else
      _zle_ui_view choice _chrome_view empty missing || exit 3
    fi
    _zle_ui_view choice _chrome_view choice "" || exit 4
    _zle_ui_view reader _chrome_view reader missing || exit 5
    print consistent
  ' "$TEST_REPO_ROOT" "$1") || return
  test_assert_equal consistent "$output"
}
_test_ui_chrome_query_acceptance() { _test_ui_chrome_acceptance query; }
_test_ui_chrome_empty_acceptance() { _test_ui_chrome_acceptance empty; }
test_case 'UI chrome names literal query intent and preserves its submission capability' \
  _test_ui_chrome_query_acceptance
test_case 'UI chrome omits unavailable Enter from empty choice footer and guide' \
  _test_ui_chrome_empty_acceptance

_test_ui_chrome_native_acceptance() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    functions[_chrome_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _chrome_show
      print -r -u $event_fd -- FRAME
    }
    zle() {
      [[ $1 == beep ]] && print -r -u $event_fd -- BEEP
      builtin zle "$@"
    }
    _chrome_empty() { _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=(); }
    _chrome_view() {
      local scenario=$1 query=$2
      _ZLE_PICKER_COLLECTOR=_chrome_empty
      if [[ $scenario == reader* ]]; then
        _ZLE_PICKER_DOCUMENT_REFRESH=1
        _ZLE_PICKER_INSPECT_FIXED_KEY=reader _ZLE_PICKER_DOCUMENT_KEY=reader
        _ZLE_PICKER_INSPECT_TEXTS=(reader "No matching lines")
      fi
      _zle_picker_loop "$query" 10
      print -r -u $event_fd -- "$scenario|$?|$_ZLE_PICKER_ACTION|$_ZLE_PICKER_SELECTED_VALUE"
    }
    _chrome_controller() {
      _zle_ui_view query _chrome_view query draft
      _zle_ui_view query _chrome_view blank "  "
      _zle_ui_view choice _chrome_view empty missing
      _zle_ui_view reader _chrome_view reader missing
      _zle_ui_view reader _chrome_view reader-refresh missing
    }
    _chrome_driver() {
      command stty rows 24 cols 120
      _zle_picker_run 10 "" 1 0 _chrome_controller
    }
    local event="" chunk="" trace="" pty_fd=0
    _chrome_event() {
      while zselect -r $event_fd $pty_fd -t 300; do
        while zpty -r chrome chunk; do trace+=$chunk; done
        IFS= read -r -t 0 -u $event_fd event && return 0
      done
      print -u2 -- "native chrome timed out: $event"
      return 1
    }
    zpty -b chrome _chrome_driver || exit 3
    pty_fd=$REPLY
    {
      _chrome_event && [[ $event == FRAME ]] || exit 4
      zpty -w -n chrome $'\''\r'\''
      _chrome_event && [[ $event == "query|0|query|draft" ]] || exit 5
      local scenario=""
      for scenario in blank empty; do
        _chrome_event && [[ $event == FRAME ]] || exit 6
        zpty -w -n chrome $'\''\r'\''
        _chrome_event && [[ $event == BEEP ]] || exit 7
        _chrome_event && [[ $event == FRAME ]] || exit 8
        zpty -w -n chrome $'\''\x07'\''
        _chrome_event && [[ $event == "$scenario|1|select|" ]] || exit 9
      done
      _chrome_event && [[ $event == FRAME ]] || exit 10
      zpty -w -n chrome $'\''\r'\''
      _chrome_event && [[ $event == "reader|0|select|" ]] || exit 11
      _chrome_event && [[ $event == FRAME ]] || exit 12
      zpty -w -n chrome $'\''\x12'\''
      _chrome_event && [[ $event == "reader-refresh|0|document-refresh|" ]] || exit 13
    } always {
      zpty -d chrome
      exec {event_fd}>&-
    }
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'UI chrome native Enter retains literal blank choice and zero-match reader behavior' \
  _test_ui_chrome_native_acceptance

_test_ui_chrome_removed_style_map() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/support/.zsh.ui"
    local expected_query=${_COMPOZSH_COLOR_FALLBACKS[highlight:picker-query]}
    local expected_added=${_COMPOZSH_COLOR_FALLBACKS[highlight:review-added]}
    unset ZSH_HIGHLIGHT_STYLES
    local query="two words" added="two words"
    _zle_picker_style picker-query
    [[ $REPLY == "$expected_query" ]] || exit 1
    _zle_picker_review_style added
    [[ $REPLY == "$expected_added" ]] || exit 2
    (( !${+ZSH_HIGHLIGHT_STYLES} )) || exit 3
    typeset -gA ZSH_HIGHLIGHT_STYLES=(picker-query "" history-search-query "")
    _zle_picker_style picker-query
    [[ -z $REPLY ]] || exit 4
    unset "ZSH_HIGHLIGHT_STYLES[history-search-query]"
    _zle_picker_style picker-query
    [[ $REPLY == "$expected_query" ]] || exit 5
    print guarded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal guarded "$output"
}
test_case 'UI chrome uses selected defaults after the public style map is removed' \
  _test_ui_chrome_removed_style_map
