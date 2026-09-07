_test_git_tree_native() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    ZSH_GIT_REVIEW_AUTO_REFRESH=0
    mkdir -p "$HOME/repo/src/deep/more/next"
    cd "$HOME/repo"
    git init -q
    local file
    for file in README src/a src/deep/b src/deep/more/c src/deep/more/next/d; do print initial > "$file"; done
    git add .
    git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm initial
    for file in README src/a src/deep/b src/deep/more/c src/deep/more/next/d; do print changed >> "$file"; done
    local before=$(git hash-object --no-filters .git/index)
    zmodload zsh/zpty
    zmodload zsh/zselect
    zmodload zsh/datetime
    command mkfifo "$HOME/events"
    local efd pfd event="" trace="" device="" chunk="" summary_event=""
    exec {efd}<> "$HOME/events"
    functions -c _zle_picker_show _tree_native_show
    functions -c _git_review_diff_capture _tree_native_capture
    _git_review_diff_capture() {
      print -r -- capture >> "$HOME/captures"
      _tree_native_capture "$@"
    }
    _zle_picker_show() {
      _tree_native_show
      (( ${_ZLE_PICKER_BUSY:-0} )) && return 0
      local selected=${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]-}
      if [[ $selected == d:* ]]; then
        local summary_ok=0
        [[ ${(F)_ZLE_PICKER_INSPECT_LINES} == *"Where changes are"* &&
           ${(F)_ZLE_PICKER_INSPECT_LINES} != *"Reading selected file"* &&
           $_ZLE_PICKER_SUBTITLE_ROW != *"focused diff"* && $_ZLE_PICKER_SUBTITLE_ROW != *syntax* &&
           $_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST == 0 ]] && summary_ok=1
        print -r -u $efd -- "SUMMARY|$summary_ok"
      fi
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|${_git_file_view:-}|${_git_tree_scope:-}|$selected|${_ZLE_PICKER_ACCEPT_LABELS[$selected]-}|$_ZLE_PICKER_DOCUMENT_KEY|$_ZLE_PICKER_INSPECT_FOCUS|$_ZLE_PICKER_QUERY|$COLUMNS"
    }
    _tree_native_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "READY:$(command tty)"
      _tree_native_widget() {
        _git_review_prepare "$PWD" || return 2
        _zle_picker_screen_session _git_review_view "$PWD" working
        local outcome=$?
        [[ $outcome == 1 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 ]] || print -r -u $efd "BAD-CLEANUP:$outcome:$_ZLE_PICKER_SCREEN_ACTIVE:$_ZLE_PICKER_ACTIVE"
        zle .accept-line
      }
      zle -N _tree_native_widget
      local draft=""
      vared -i _tree_native_widget draft
      print -r -u $efd DONE
    }
    _tree_native_expect() {
      local wanted=$1
      local -F deadline=$(( EPOCHREALTIME + 5 ))
      while (( EPOCHREALTIME < deadline )) && zselect -r $efd $pfd -t 50; do
        while zpty -r tree chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          if [[ $event == SUMMARY\|* ]]; then summary_event=$event; continue; fi
          [[ $event == "$wanted" || ( $wanted == *\* && $event == "${wanted%\*}"* ) ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; got $event"
      print -u2 -r -- "terminal tail: ${trace[-1000,-1]}"
      return 1
    }
    _tree_native_key() { zpty -w -n tree "$1"; _tree_native_expect "$2"; }
    zpty -b tree _tree_native_driver
    pfd=$REPLY
    {
      zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 1
      device=${event#READY:}
      _tree_native_expect "FRAME|Working changes|tree||1||1|0||120" || exit 2
      _tree_native_key $'\''\e[B'\'' "FRAME|Working changes|tree||d:src/|collapse|1|0||120" || exit 3
      [[ $summary_event == SUMMARY\|1 ]] || exit 32
      local summary_captures=$(<"$HOME/captures")
      _tree_native_key $'\''\e[C'\'' "FRAME|Working changes|tree||d:src/|collapse|1|1||120" || exit 33
      _tree_native_key $'\''\e[C'\'' "FRAME|Working changes|tree||d:src/|collapse|1|1||120" || exit 34
      _tree_native_key $'\''\r'\'' "FRAME|Working changes|tree||d:src/|collapse|1|1||120" || exit 35
      _tree_native_key $'\''\e[D'\'' "FRAME|Working changes|tree||d:src/|collapse|1|0||120" || exit 36
      [[ $(<"$HOME/captures") == "$summary_captures" ]] || exit 37
      _tree_native_key $'\''\r'\'' "FRAME|Working changes|tree||d:src/|expand|1|0||120" || exit 4
      _tree_native_key 2 "FRAME|Working changes|tree||d:src/|collapse|1|0||120" || exit 5
      _tree_native_key $'\''\x18'\'' "FRAME|Git / View options|*" || exit 6
      _tree_native_key 2 "FRAME|Working changes|flat||1||1|0||120" || exit 7
      _tree_native_key $'\''\x18'\'' "FRAME|Git / View options|*" || exit 26
      _tree_native_key 1 "FRAME|Working changes|tree||d:src/|collapse|1|0||120" || exit 27
      _tree_native_key $'\''\x18'\'' "FRAME|Git / View options|*" || exit 28
      _tree_native_key 1 "FRAME|Working changes|tree||d:src/|collapse|1|0||120" || exit 29
      _tree_native_key $'\''\x18'\'' "FRAME|Git / View options|*" || exit 30
      _tree_native_key 2 "FRAME|Working changes|flat||1||1|0||120" || exit 31
      _tree_native_key $'\''\e[B'\'' "FRAME|Working changes|flat||2||2|0||120" || exit 8
      _tree_native_key $'\''\x18'\'' "FRAME|Git / View options|*" || exit 9
      _tree_native_key 1 "FRAME|Working changes|tree||2||2|0||120" || exit 10
      _tree_native_key $'\''\e[B\e[B\e[B'\'' "FRAME|Working changes|tree||d:src/deep/more/|collapse|2|0||120" || exit 11
      _tree_native_key $'\''\r'\'' "FRAME|Working changes|tree||d:src/deep/more/|expand|2|0||120" || exit 38
      _tree_native_key $'\''\r'\'' "FRAME|Working changes|tree||d:src/deep/more/|collapse|2|0||120" || exit 39
      _tree_native_key $'\''\e[B\e[B'\'' "FRAME|Working changes|tree||d:src/deep/more/next/|open folder|2|0||120" || exit 40
      local captures=$(<"$HOME/captures")
      _tree_native_key $'\''\r'\'' "FRAME|Working changes|tree|src/deep/more/next/|d:src/deep/more/next/|collapse|2|0||120" || exit 12
      _tree_native_key $'\''\e'\'' "FRAME|Working changes|tree||d:src/deep/more/next/|open folder|2|0||120" || exit 13
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 24
      _tree_native_key $'\''\x12'\'' "FRAME|Working changes|tree||d:src/deep/more/next/|open folder|2|0||120" || exit 14
      _tree_native_key $'\''\x18'\'' "FRAME|Git / View options|*" || exit 15
      captures=$(<"$HOME/captures")
      _tree_native_key 3 "FRAME|Git / Jump to ancestor|*" || exit 16
      _tree_native_key 1 "FRAME|Working changes|tree||2||2|0||120" || exit 17
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 25
      _tree_native_key next/d "FRAME|Working changes|tree||5||5|0|next/d|120" || exit 18
      _tree_native_key $'\''\t'\'' "FRAME|Working changes|tree||5||5|1|next/d|120" || exit 19
      command stty -f "$device" rows 14 cols 40
      _tree_native_expect "FRAME|Working changes|tree||5||5|1|next/d|40" || exit 20
      _tree_native_key $'\''\e'\'' DONE || exit 21
      while zpty -r tree chunk; do trace+=$chunk; done
      [[ $trace != *"bad math"* && $trace != *"not found"* && $trace != *"read-only variable"* &&
         $trace == *"$terminfo[smcup]"* && ${trace#*"$terminfo[smcup]"} != *"$terminfo[smcup]"* &&
         $trace == *"$terminfo[rmcup]"* ]] || exit 22
      [[ $(git hash-object --no-filters .git/index) == "$before" ]] || exit 23
    } always {
      zpty -d tree
      exec {efd}>&-
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree native journey toggles views folds deep scopes ancestors filtering refresh and resize' _test_git_tree_native
