# A primary document can reuse the shared screen without selectable rows.
_test_editor_reader_render() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local -i _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT=1
    local -i _ZLE_PICKER_DOCUMENT_REFRESH=1 _ZLE_PICKER_COPY_ENABLED=1
    local -i _ZLE_PICKER_DIGIT_SELECT=1
    local -i _ZLE_PICKER_SCREEN_ACTIVE=1
    local _ZLE_PICKER_TITLE=Reader _ZLE_PICKER_BROWSE_LABEL="Captured document"
    local _ZLE_PICKER_INSPECT_ACTION=options _ZLE_PICKER_CANCEL_LABEL=back
    local _ZLE_PICKER_DOCUMENT_KEY=logs _ZLE_PICKER_INSPECT_FIXED_KEY=logs
    local _ZLE_PICKER_INSPECT_TITLE=Output _ZLE_PICKER_QUERY_LABEL="Filter lines"
    local -A _ZLE_PICKER_INSPECT_TEXTS=(logs "")
    local -a _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    local -a _ZLE_PICKER_DOCUMENT_LINES=()
    local row="" frame="" guide=""
    local -i index=0 anchor=0 saved_offset=0
    for (( index=1; index<=60; ++index )); do
      _ZLE_PICKER_DOCUMENT_LINES+=("record $index ${(l:150::x:)}")
    done
    LINES=30
    for COLUMNS in 140 90 40; do
      _zle_picker_render "" 0
      frame=${(j:\n:)_ZLE_PICKER_DISPLAY}
      (( _ZLE_PICKER_INSPECT_FOCUS == 1 && _ZLE_PICKER_INSPECT_WIDTH == COLUMNS-1 )) || {
        print -u2 "reader did not receive full width and focus at $COLUMNS columns"; exit 1;
      }
      [[ $_ZLE_PICKER_HEADER != *"0 shown"* && $frame != *"[--]"* &&
         $frame != *"Tab list"* && $frame != *"No matching selection"* ]] || exit 2
      (( !_ZLE_PICKER_INDEXES_VISIBLE && !${#_ZLE_PICKER_VISIBLE_KEYS} &&
         !${#_ZLE_PICKER_RESULTS} )) || exit 3
      [[ ${(j: :)_ZLE_PICKER_DISPLAY_STYLES} != *picker-selected* ]] || exit 4
      for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
        (( ${(m)#row} <= COLUMNS-1 )) || exit 5
      done
    done
    COLUMNS=140
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_TITLEBAR != *"Enter:"* && $_ZLE_PICKER_DISPLAY[-1] == *"⏎ options"* ]] || exit 6
    [[ $_ZLE_PICKER_QUERY_ROW == *"Filter lines"* &&
       ${_ZLE_PICKER_DISPLAY[-1]} == *"^Y copy"* ]] || exit 7
    _ZLE_PICKER_INSPECT_OFFSET=$(( ${_ZLE_PICKER_INSPECT_SOURCE_LINES[(i)9]} - 1 ))
    (( ++_ZLE_PICKER_INSPECT_OFFSET ))
    saved_offset=$_ZLE_PICKER_INSPECT_OFFSET
    _zle_picker_render "" 0
    _zle_picker_document_bookmark
    _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_render "" 0
    (( _ZLE_PICKER_INSPECT_OFFSET == saved_offset )) || {
      print -u2 "reentry lost the position within a wrapped record"; exit 12;
    }
    _zle_picker_render "" 0
    anchor=$_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST
    COLUMNS=40
    _zle_picker_render "" 0
    (( _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST == anchor && anchor == 9 )) || {
      print -u2 "resize lost the source-row anchor"; exit 8;
    }
    _zle_picker_document_bookmark
    _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
    COLUMNS=90
    _zle_picker_render "" 0
    (( _ZLE_PICKER_DOCUMENT_VISIBLE_FIRST == 9 )) || exit 9
    LINES=80 COLUMNS=150
    _ZLE_PICKER_GUIDE_ACTIVE=1
    _zle_picker_render "" 0
    guide=${(j:\n:)_ZLE_PICKER_DISPLAY}
    [[ $guide == *"Filter captured document"* && $guide == *"Scroll the document"* &&
       $guide == *"Copy the current document and return"* &&
       $guide != *"file navigator"* && $guide != *"Move selection"* &&
       $guide != *"Files →"* && $guide != *"Apply a visible slot"* ]] || {
      print -u2 -- "$guide"; exit 10;
    }
    _ZLE_PICKER_GUIDE_PAGE=10 _ZLE_PICKER_INSPECT_PAGE=3 _ZLE_PICKER_GUIDE_OFFSET=0
    _zle_picker_page 1 0 0
    (( _ZLE_PICKER_GUIDE_OFFSET == 9 )) || {
      print -u2 "guide paging used the document viewport"; exit 13;
    }
    _ZLE_PICKER_GUIDE_ACTIVE=0 _ZLE_PICKER_INSPECT_WIDTH=0
    _ZLE_PICKER_DOCUMENT_LINES=("${(l:32768::x:)}")
    COLUMNS=40 LINES=30
    _zle_picker_render "" 0
    (( ${#${(j::)_ZLE_PICKER_INSPECT_LINES}} == 32768 )) || {
      print -u2 "reader clipped a bounded document to preview capacity"; exit 14;
    }
    # The opt-in must not remove the ordinary picker navigator or chrome.
    _ZLE_PICKER_READER_ONLY=0 _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_GUIDE_ACTIVE=0
    _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_INSPECT_TEXTS=()
    _ZLE_PICKER_RESULTS=(alpha beta) _ZLE_PICKER_LABELS=(alpha beta)
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_HEADER == *"2 shown"* &&
       ${(j: :)_ZLE_PICKER_DISPLAY_STYLES} == *picker-selected* ]] || exit 11
    print reader-render
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal reader-render "$output"
}
test_case 'editor reader uses full width passive document chrome and source anchors' _test_editor_reader_render

_test_editor_reader_wrapping() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local -i _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT=1
    local _ZLE_PICKER_DOCUMENT_KEY=logs
    local -a _ZLE_PICKER_DOCUMENT_LINES=() expected_rows=() expected_sources=()
    local -a fixtures=()
    local percent="percent %F{red}  50% "
    fixtures=("${(l:32768::x:)}" "${(l:700::$percent:)}"
      "${(l:700::界é :)}" "${(l:700::é界 :)}" $'\''literal\t%F{red}\e]52;c;no\a'\'')
    local fixture="" expected=""
    local -i width=0
    for fixture in "${fixtures[@]}"; do
      expected=${fixture//$'\''\t'\''/    }
      expected=${(V)expected}
      expected+="Unicode tail 界 é"
      for width in 39 119; do
        _ZLE_PICKER_READER_ONLY=0
        _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
        _ZLE_PICKER_DOCUMENT_LINES=("$fixture" "Unicode tail 界 é")
        _zle_picker_inspect_prepare logs $width
        expected_rows=("${_ZLE_PICKER_INSPECT_LINES[@]}")
        expected_sources=("${_ZLE_PICKER_INSPECT_SOURCE_LINES[@]}")
        _ZLE_PICKER_READER_ONLY=1
        _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
        _zle_picker_inspect_prepare logs $width
        [[ ${(j::)_ZLE_PICKER_INSPECT_LINES} == "$expected" &&
           ${(pj:\n:)_ZLE_PICKER_INSPECT_LINES} == "${(pj:\n:)expected_rows}" &&
           ${(j:,:)_ZLE_PICKER_INSPECT_SOURCE_LINES} == "${(j:,:)expected_sources}" ]] || {
          print -u2 "reader wrapping changed native text, geometry or source rows at width $width"; exit 1;
        }
      done
    done
    print reader-wrap
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal reader-wrap "$output"
}
test_case 'editor reader wrapping preserves native ASCII Unicode control and source-row semantics' _test_editor_reader_wrapping

_test_editor_reader_follow() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local -i _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT=1
    local -i _ZLE_PICKER_DOCUMENT_FOLLOW=1 _ZLE_PICKER_DOCUMENT_REFRESH=0
    local -i _ZLE_PICKER_SCREEN_ACTIVE=1
    local _ZLE_PICKER_DOCUMENT_KEY=logs _ZLE_PICKER_INSPECT_FIXED_KEY=logs
    local _ZLE_PICKER_DOCUMENT_TITLE=Logs _ZLE_PICKER_INSPECT_ACTION=options
    local _ZLE_PICKER_CANCEL_LABEL=back
    local -A _ZLE_PICKER_INSPECT_TEXTS=(logs "")
    local -a _ZLE_PICKER_DOCUMENT_LINES=({1..100})
    local -i maximum=0 paused_offset=0
    COLUMNS=100 LINES=24
    _zle_picker_render "" 0
    maximum=$(( ${#_ZLE_PICKER_INSPECT_LINES} - _ZLE_PICKER_INSPECT_PAGE ))
    (( maximum > 0 && _ZLE_PICKER_INSPECT_OFFSET == maximum )) || {
      print -u2 "live document did not start at the newest tail"; exit 1;
    }
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"Logs · Live"* && ${_ZLE_PICKER_DISPLAY[-1]} == *"↑ pause"* ]] || exit 2
    _ZLE_PICKER_DOCUMENT_LINES+=(newest)
    _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_render "" 0
    [[ ${_ZLE_PICKER_DISPLAY[-2]} == newest* ]] || exit 3
    LINES=12 COLUMNS=40
    _zle_picker_render "" 0
    (( _ZLE_PICKER_INSPECT_OFFSET == ${#_ZLE_PICKER_INSPECT_LINES} - _ZLE_PICKER_INSPECT_PAGE )) || exit 4
    _zle_picker_step -1 0 0
    (( _ZLE_PICKER_DOCUMENT_FOLLOW == 0 )) || exit 5
    paused_offset=$_ZLE_PICKER_INSPECT_OFFSET
    _zle_picker_render "" 0
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"Logs · Paused"* ]] || exit 6
    _ZLE_PICKER_DOCUMENT_LINES+=(later)
    _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_render "" 0
    (( _ZLE_PICKER_INSPECT_OFFSET == paused_offset && !_ZLE_PICKER_DOCUMENT_FOLLOW )) || exit 7
    _zle_picker_step 2 0 0
    (( _ZLE_PICKER_DOCUMENT_FOLLOW == 1 )) || exit 8
    _zle_picker_render "" 0
    [[ ${_ZLE_PICKER_DISPLAY[-2]} == later* ]] || exit 9
    _zle_picker_page -1 0 0
    (( _ZLE_PICKER_DOCUMENT_FOLLOW == 0 )) || exit 10
    LINES=150
    _zle_picker_render "" 0
    (( _ZLE_PICKER_INSPECT_OFFSET == 0 && !_ZLE_PICKER_DOCUMENT_FOLLOW )) || {
      print -u2 "resize resumed a paused document"; exit 11;
    }
    _zle_picker_step 1 0 0
    (( _ZLE_PICKER_DOCUMENT_FOLLOW == 1 )) || exit 12
    _ZLE_PICKER_GUIDE_ACTIVE=1
    _zle_picker_page -1 0 0
    (( _ZLE_PICKER_DOCUMENT_FOLLOW == 1 )) || exit 13
    COLUMNS=100
    _zle_picker_render "" 0
    local guide=${(j:\n:)_ZLE_PICKER_DISPLAY}
    [[ $guide == *"Home"*"pause"* && $guide == *"End"*"follow"* &&
       $guide != *"Ctrl-R"* ]] || exit 14
    _ZLE_PICKER_GUIDE_ACTIVE=0 _ZLE_PICKER_DOCUMENT_FOLLOW=-1
    LINES=24
    _ZLE_PICKER_INSPECT_OFFSET=3
    _zle_picker_render "" 0
    (( _ZLE_PICKER_INSPECT_OFFSET == 3 && _ZLE_PICKER_DOCUMENT_FOLLOW == -1 )) || exit 15
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"Logs · Live"* && ${_ZLE_PICKER_DISPLAY[-1]} != *"↑ pause"* ]] || exit 16
    print reader-follow
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal reader-follow "$output"
}
test_case 'editor reader live following pins new output and resize while explicit scrolling controls pause' _test_editor_reader_follow

_test_editor_reader_keys() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    command mkfifo "$HOME/updates" || exit 1
    exec {efd}<> "$HOME/events"
    exec {updates}<> "$HOME/updates"
    local scenario="" event="" trace="" pfd=0
    local bindings=$(bindkey -L)
    _reader_collect() {
      local query=$1 row=""
      _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _ZLE_PICKER_RESULT_INDEXES=()
      _ZLE_PICKER_DOCUMENT_LINES=()
      for row in "${snapshot[@]}"; do
        [[ $row == *"$query"* ]] && _ZLE_PICKER_DOCUMENT_LINES+=("$row")
      done
      _ZLE_PICKER_COPY_ENABLED=$(( ${#_ZLE_PICKER_DOCUMENT_LINES} > 0 ))
      if [[ $query != "$last_query" ]]; then
        _ZLE_PICKER_INSPECT_WIDTH=0 _ZLE_PICKER_INSPECT_OFFSET=0
        _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=()
      fi
      last_query=$query
    }
    _reader_idle() {
      local update=""
      if IFS= read -r -t 0 -u $updates update; then
        snapshot+=("new line ${#snapshot}")
        _reader_collect "$_ZLE_PICKER_QUERY" 20
        _ZLE_PICKER_INSPECT_WIDTH=0
        return 0
      fi
      return 1
    }
    _reader_prepaint_idle() {
      (( ++idle_calls ))
      (( painted < 2 )) && return 0
      return 1
    }
    zle() {
      if [[ $1 == -R && $scenario == palette* && $_ZLE_PICKER_READER_ONLY == 1 ]]; then
        local styles=${(j: :)region_highlight} error_color=203 success_color=71
        [[ $scenario == palette-custom ]] && { error_color=123; success_color=124; }
        [[ $styles == *"fg=$error_color"* && $styles == *"fg=$success_color"* &&
           $styles != *"bg=52"* && $styles != *"bg=22"* ]] || print -r -u $efd BAD-PALETTE
      fi
      builtin zle "$@"
    }
    functions[_reader_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _reader_show
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_GUIDE_ACTIVE|$_ZLE_PICKER_INSPECT_FOCUS|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_INSPECT_OFFSET|${#_ZLE_PICKER_RESULTS}"
      if [[ $scenario == prepaint-* ]]; then
        (( ++painted ))
        print -r -u $efd -- "ORDER|$painted|$idle_calls"
      fi
      [[ $scenario == resize ]] && print -r -u $efd -- "WIDTH|$_ZLE_PICKER_INSPECT_WIDTH|$_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST"
      if [[ $scenario == follow ]]; then
        local -i at_tail=$(( _ZLE_PICKER_INSPECT_OFFSET + _ZLE_PICKER_INSPECT_PAGE >= ${#_ZLE_PICKER_INSPECT_LINES} ))
        print -r -u $efd -- "LIVE|$_ZLE_PICKER_DOCUMENT_FOLLOW|$at_tail|$_ZLE_PICKER_GUIDE_ACTIVE|${#_ZLE_PICKER_DOCUMENT_LINES}"
        print -r -u $efd -- "SIZE|$COLUMNS|$LINES|$_ZLE_PICKER_DOCUMENT_FOLLOW|$at_tail"
      fi
    }
    _reader_controller() {
      local -i _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT=1
      local -i _ZLE_PICKER_DOCUMENT_REFRESH=1 _ZLE_PICKER_COPY_ENABLED=1
      local -i _ZLE_PICKER_DOCUMENT_FOLLOW=-1
      local -i _ZLE_PICKER_DIGIT_SELECT=1
      local _ZLE_PICKER_TITLE=Reader _ZLE_PICKER_BROWSE_LABEL="Captured document"
      local _ZLE_PICKER_INSPECT_ACTION=options _ZLE_PICKER_CANCEL_LABEL=back
      local _ZLE_PICKER_DOCUMENT_KEY=logs _ZLE_PICKER_INSPECT_FIXED_KEY=logs
      local _ZLE_PICKER_INSPECT_TITLE=Output _ZLE_PICKER_QUERY_LABEL="Filter lines"
      local _ZLE_PICKER_COLLECTOR=_reader_collect last_query=unset
      local -A _ZLE_PICKER_INSPECT_TEXTS=(logs "")
      local -A _ZLE_PICKER_DOCUMENT_OFFSETS=() _ZLE_PICKER_DOCUMENT_ROWS=() _ZLE_PICKER_DOCUMENT_WIDTHS=()
      local -A ZSH_OUTPUT_COLORS=()
      local -a _ZLE_PICKER_DOCUMENT_ROLES=()
      local -a snapshot=() _ZLE_PICKER_DOCUMENT_LINES=()
      local _ZLE_PICKER_IDLE_CALLBACK=""
      local -i index=0 result=0 idle_calls=0 painted=0
      for (( index=1; index<=60; ++index )); do
        (( index % 2 )) && snapshot+=("info line $index") || snapshot+=("error line $index")
        [[ $scenario == resize ]] && snapshot[-1]+=" ${(l:150::x:)}"
      done
      [[ $scenario == palette* ]] && _ZLE_PICKER_DOCUMENT_ROLES=(error success)
      [[ $scenario == palette-custom ]] && ZSH_OUTPUT_COLORS=(error 123 success 124)
      if [[ $scenario == follow ]]; then
        _ZLE_PICKER_DOCUMENT_FOLLOW=1 _ZLE_PICKER_DOCUMENT_REFRESH=0
        _ZLE_PICKER_IDLE_CALLBACK=_reader_idle
      fi
      [[ $scenario == prepaint-* ]] && _ZLE_PICKER_IDLE_CALLBACK=_reader_prepaint_idle
      [[ $scenario == prepaint-off ]] && local -i _ZLE_PICKER_IDLE_PREPAINT=0
      _zle_picker_loop "" 20
      result=$?
      print -r -u $efd -- "RESULT|$result|$_ZLE_PICKER_ACTION|${_ZLE_PICKER_BOOKMARK[1]-}|$_ZLE_PICKER_BOOKMARK_FOCUS|${_ZLE_PICKER_DOCUMENT_ROWS[logs]:-0}|${_ZLE_PICKER_DOCUMENT_OFFSETS[logs]:-0}"
      return $result
    }
    _reader_driver() {
      command stty rows 30 cols 120
      command tty > "$HOME/terminal"
      _zle_picker_run 20 "" 1 0 _reader_controller
      [[ $_ZLE_PICKER_ACTIVE == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 &&
         $(bindkey -L) == "$bindings" ]] || print -r -u $efd BAD-CLEANUP
      print -r -u $efd DONE
    }
    _reader_expect() {
      local expected=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r reader chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* || $event == RESULT* || $event == DONE ]] && break
        fi
      done
      print -u2 -r -- "$scenario: expected $expected; got $event"
      return 1
    }
    for scenario in prepaint-default prepaint-off palette palette-custom escape options-empty refresh-empty copy meta-copy guide resize follow; do
      trace=""
      zpty -b reader _reader_driver || exit 2
      pfd=$REPLY
      {
        if [[ $scenario == follow ]]; then
          _reader_expect "LIVE|1|1|0|60" || exit 28
        else
          _reader_expect "FRAME|0|1||0|0" || exit 3
        fi
        case $scenario in
          (prepaint-*)
            if [[ $scenario == prepaint-default ]]; then
              _reader_expect "ORDER|1|1" || exit 47
              _reader_expect "ORDER|2|3" || exit 48
            else
              _reader_expect "ORDER|1|0" || exit 49
              _reader_expect "ORDER|2|1" || exit 50
            fi
            zpty -w -n reader $'\''\e'\''
            _reader_expect "RESULT|1|select||1|1|0" || exit 51 ;;
          (palette|palette-custom)
            zpty -w -n reader $'\''\e'\''
            _reader_expect "RESULT|1|select||1|1|0" || exit 29 ;;
          (escape)
            zpty -w -n reader $'\''\e[B'\''
            _reader_expect "FRAME|0|1||1|0" || exit 4
            zpty -w -n reader errorx
            _reader_expect "FRAME|0|1|errorx|0|0" || exit 25
            zpty -w -n reader $'\''\x7f'\''
            _reader_expect "FRAME|0|1|error|0|0" || exit 5
            zpty -w -n reader $'\''\x15\x37'\''
            _reader_expect "FRAME|0|1|7|0|0" || exit 26
            zpty -w -n reader $'\''\x7ferror'\''
            _reader_expect "FRAME|0|1|error|0|0" || exit 27
            zpty -w -n reader $'\''\e\x7f'\''
            _reader_expect "FRAME|0|1||0|0" || exit 20
            zpty -w -n reader $'\''\x15one two\x17\x15\e[200~error\e[201~'\''
            _reader_expect "FRAME|0|1|error|0|0" || exit 6
            # No hidden navigator may acquire focus through any old pane key.
            for key in $'\''\t'\'' $'\''\e[Z'\'' $'\''\x02'\'' $'\''\x05'\'' $'\''\e[C'\'' $'\''\e[D'\''; do
              zpty -w -n reader "$key"
              _reader_expect "FRAME|0|1|error|0|0" || exit 7
            done
            zpty -w -n reader $'\''\e[B\e'\''
            _reader_expect "RESULT|1|select|error|1|2|1" || exit 8 ;;
          (options-empty|refresh-empty)
            zpty -w -n reader nomatch
            _reader_expect "FRAME|0|1|nomatch|0|0" || exit 9
            zpty -w -n reader $'\''\x19'\''
            _reader_expect "FRAME|0|1|nomatch|0|0" || exit 10
            if [[ $scenario == options-empty ]]; then
              zpty -w -n reader $'\''\r'\''
              _reader_expect "RESULT|0|select|nomatch|1|0|0" || exit 11
            else
              zpty -w -n reader $'\''\x12'\''
              _reader_expect "RESULT|0|document-refresh|nomatch|1|0|0" || exit 12
            fi ;;
          (copy|meta-copy)
            zpty -w -n reader error
            _reader_expect "FRAME|0|1|error|0|0" || exit 13
            [[ $scenario == copy ]] && zpty -w -n reader $'\''\x19'\'' || zpty -w -n reader $'\''\ew'\''
            _reader_expect "RESULT|0|copy|error|1|1|0" || exit 14 ;;
          (guide)
            zpty -w -n reader $'\''error\x0b'\''
            _reader_expect "FRAME|1|1|error|0|0" || exit 15
            zpty -w -n reader $'\''\x19\x12x\r'\''
            _reader_expect "FRAME|0|1|error|0|0" || exit 16
            zpty -w -n reader $'\''\e'\''
            _reader_expect "RESULT|1|select|error|1|1|0" || exit 17 ;;
          (resize)
            zpty -w -n reader $'\''\e[B\e[B\e[B\e[B\e[B\e[B\e[B\e[B'\''
            _reader_expect "FRAME|0|1||8|0" || exit 21
            command stty -f "$(<"$HOME/terminal")" cols 40
            _reader_expect "WIDTH|39|5" || exit 22
            command stty -f "$(<"$HOME/terminal")" cols 120
            _reader_expect "WIDTH|119|5" || exit 23
            zpty -w -n reader $'\''\e'\''
            _reader_expect "RESULT|1|select||1|5|8" || exit 24 ;;
          (follow)
            zpty -w -n reader $'\''\e[A'\''
            _reader_expect "LIVE|0|0|0|60" || exit 30
            print -r -u $updates append
            _reader_expect "LIVE|0|0|0|61" || exit 31
            zpty -w -n reader $'\''\e[B\e[B'\''
            _reader_expect "LIVE|1|1|0|61" || exit 32
            print -r -u $updates append
            _reader_expect "LIVE|1|1|0|62" || exit 33
            zpty -w -n reader $'\''\x04'\''
            _reader_expect "LIVE|0|0|0|62" || exit 34
            zpty -w -n reader $'\''\x16'\''
            _reader_expect "LIVE|1|1|0|62" || exit 35
            for key in $'\''\e[H'\'' $'\''\eOH'\'' $'\''\e[1~'\''; do
              zpty -w -n reader "$key"
              _reader_expect "FRAME|0|1||0|0" || exit 36
              _reader_expect "LIVE|0|0|0|62" || exit 37
              case $key in
                ($'\''\e[H'\'') zpty -w -n reader $'\''\e[F'\'' ;;
                ($'\''\eOH'\'') zpty -w -n reader $'\''\eOF'\'' ;;
                (*) zpty -w -n reader $'\''\e[4~'\'' ;;
              esac
              _reader_expect "LIVE|1|1|0|62" || exit 38
            done
            zpty -w -n reader $'\''\x0b'\''
            _reader_expect "LIVE|1|1|1|62" || exit 39
            zpty -w -n reader $'\''\e[A\x04\e[F\r'\''
            _reader_expect "LIVE|1|1|0|62" || exit 40
            command stty -f "$(<"$HOME/terminal")" cols 40 rows 12
            _reader_expect "SIZE|40|12|1|1" || exit 41
            zpty -w -n reader $'\''\e[A'\''
            _reader_expect "LIVE|0|0|0|62" || exit 42
            command stty -f "$(<"$HOME/terminal")" cols 120 rows 100
            _reader_expect "SIZE|120|100|0|1" || exit 43
            zpty -w -n reader $'\''\e[B'\''
            _reader_expect "LIVE|1|1|0|62" || exit 44
            zpty -w -n reader $'\''\x12'\''
            _reader_expect "LIVE|1|1|0|62" || exit 45
            zpty -w -n reader $'\''\e'\''
            _reader_expect "RESULT|1|select||1|1|0" || exit 46 ;;
        esac
        _reader_expect DONE || exit 18
        [[ $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 19
      } always {
        zpty -d reader
      }
    done
    print reader-keys
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal reader-keys "$output"
}
test_case 'editor reader native keys filter scroll copy refresh and preserve Escape bookmarks' _test_editor_reader_keys
