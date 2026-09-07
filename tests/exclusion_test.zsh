# Two literal fields refine one captured candidate source; no query operators.
_test_exclusion_footer_priority() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_DOCUMENT=1
    _ZLE_PICKER_DOCUMENT_REFRESH=1 _ZLE_PICKER_AUTO_REFRESH=1
    _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=file-views
    _ZLE_PICKER_INSPECT_ACTION=read _ZLE_PICKER_CANCEL_LABEL=back
    _ZLE_PICKER_DOCUMENT_MODE=focused _ZLE_PICKER_EXCLUSION_ENABLED=1
    local value width focus footer
    local -a fragments=()
    for value in 1 d:src/ empty; do
      _ZLE_PICKER_RESULTS=("$value") _ZLE_PICKER_SELECTED=1
      _ZLE_PICKER_DOCUMENT_BRANCHES=() _ZLE_PICKER_ACCEPT_LABELS=()
      if [[ $value == d:* ]]; then
        _ZLE_PICKER_DOCUMENT_BRANCHES[$value]=1
        _ZLE_PICKER_ACCEPT_LABELS[$value]=collapse
      elif [[ $value == empty ]]; then
        _ZLE_PICKER_RESULTS=() _ZLE_PICKER_SELECTED=0
      fi
      for focus in 0 1; do
        _ZLE_PICKER_INSPECT_FOCUS=$focus
        for width in 69 119 179; do
          _zle_picker_footer $width ""
          footer=$REPLY fragments=("${(@s: · :)REPLY}")
          [[ $footer == *"^K keys · ^] filter/exclude"* ]] || {
            print -u2 -r -- "Missing filter control for $value focus=$focus width=$width: $footer"
            exit 1
          }
          (( ${(m)#footer} <= width && ${#fragments} <= 7 )) || exit 2
        done
        _zle_picker_footer 39 ""
        [[ $REPLY == *"^K keys"* && $REPLY != *"^] filter/" ]] || exit 3
        (( ${(m)#REPLY} <= 39 )) || exit 4
      done
    done
    _ZLE_PICKER_EXCLUSION_ENABLED=0
    _zle_picker_footer 179 ""
    [[ $REPLY != *"^]"* ]] || exit 5
  ' "$TEST_REPO_ROOT"
}
test_case 'exclusion footer stays discoverable with files folders empty results and reader focus' _test_exclusion_footer_priority

_test_exclusion_matching() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    export LC_ALL=en_US.UTF-8
    setopt EXTENDED_GLOB
    local -a reply=() values=(one two three four five) texts=("Node.swift" "new/other/data.swift" "APP.swift" "old backup.swift" "[*].swift")
    local REPLY="" pattern=""
    _matching_select ranked swift 2 values texts "" text nod || exit 1
    [[ ${(j:,:)reply} == 2,3 ]] || exit 2
    _matching_select source "" 20 values texts "" text NOD || exit 3
    [[ ${(j:,:)reply} == 2,3,4,5 ]] || exit 4
    _matching_select source "" 20 values texts "" text "old backup" || exit 5
    [[ ${(j:,:)reply} == 1,2,3,5 ]] || exit 6
    _matching_exclusion "[*]" || exit 7
    pattern=$REPLY
    [[ "[*].swift" != ${~pattern} && "App.swift" == ${~pattern} ]] || exit 8
    _matching_exclusion "" || exit 9
    [[ "" == ${~REPLY} && anything == ${~REPLY} ]] || exit 10
    _matching_exclusion "Äω" || exit 11
    [[ "prefixäΩsuffix" != ${~REPLY} ]] || exit 12
    _matching_exclusion "\$(touch sentinel)" || exit 13
    [[ ! -e sentinel && ordinary == ${~REPLY} ]] || exit 14
    print matching
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal matching "$output"
}
test_case 'exclusion matching combines literal case-insensitive rejection with existing ranking and limits' _test_exclusion_matching

_test_exclusion_collectors() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    for unit in editor navigation find help git-review; do source "$1/.zsh.addons/.zsh.$unit"; done
    local _ZLE_PICKER_EXCLUDE=nod
    local -a _NAVIGATION_PICKER_VALUES=(a b c) _NAVIGATION_PICKER_LABELS=(node good noddy) _NAVIGATION_PICKER_SEARCH=()
    _navigation_picker_collect "" 1
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == b ]] || exit 1
    local -A _history_search_source=(3 "echo nod" 2 "echo safe" 1 "echo node")
    _history_search_collect "" 1
    [[ ${(j:,:)_HISTORY_SEARCH_RESULTS} == "echo safe" ]] || exit 2
    _DIRECTORY_PICKER_PATH_QUERY=""
    _DIRECTORY_PICKER_VALUES=(/node /good /noddy) _DIRECTORY_PICKER_LABELS=(node good noddy)
    _directory_picker_collect "" 1
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == /good ]] || exit 3
    _FILE_SEARCH_VALUES=(/node.swift /good.swift /noddy.swift)
    _FILE_SEARCH_LABELS=(node.swift good.swift noddy.swift)
    _FILE_SEARCH_MATCH_TEXTS=(node.swift good.swift noddy.swift)
    _file_search_picker_collect swift 1
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == /good.swift ]] || exit 4
    local -a _HELP_TOPIC_LABELS=(Node Good "Complete guide") _HELP_TOPIC_TEXTS=(node good everything)
    _compozsh_help_collect "" 1
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == 2 ]] || exit 5
    local -a _atlas_values=(a b) _atlas_labels=(node good)
    _git_review_atlas_collect "" 1
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == b ]] || exit 6
    print collectors
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal collectors "$output"
}
test_case 'exclusion covers shared and specialized candidate collectors before visible limits' _test_exclusion_collectors

_test_exclusion_capture() {
  test_make_temp_dir || return
  mkdir -p "$TEST_TMP_DIR/home/tree"
  touch "$TEST_TMP_DIR/home/tree/node.swift" "$TEST_TMP_DIR/home/tree/good.swift"
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/.zsh.find"
    _file_search_capture "$HOME/tree" "" local nod || exit 1
    [[ ${#_FILE_SEARCH_VALUES} == 1 && $_FILE_SEARCH_VALUES[1] == "${HOME:A}/tree/good.swift" ]] || exit 2
    _file_search_capture "$HOME/tree" "" local "" && exit 3
    [[ $? == 2 ]] || exit 4
    print capture
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal capture "$output"
}
test_case 'exclusion-only discovery captures the bounded source while both-empty submission stays inert' _test_exclusion_capture

_test_exclusion_input() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/.zsh.navigation"
    local -a _NAVIGATION_PICKER_VALUES=(node good good2) _NAVIGATION_PICKER_LABELS=(node good good2) _NAVIGATION_PICKER_SEARCH=()
    local -a keys=( $'\''\x1d'\'' n o d $'\''\x1d'\'' 2 $'\''\r'\'' )
    local frame="" initial="" renders=0
    read() { (( ${#keys} )) || return 1; key=$keys[1]; keys[1]=(); }
    zle() { :; }
    _zle_picker_show() {
      (( ++renders ))
      [[ -n $_ZLE_PICKER_EXCLUDE ]] && frame=$_ZLE_PICKER_QUERY_ROW
    }
    _ZLE_PICKER_COLLECTOR=_navigation_picker_collect
    _ZLE_PICKER_DIGIT_SELECT=1 _ZLE_PICKER_SESSION=1 _ZLE_PICKER_SCREEN_ACTIVE=1
    COLUMNS=80 LINES=24
    _zle_picker_loop "" 10 || exit 1
    [[ $_ZLE_PICKER_SELECTED_VALUE == good2 ]] || exit 2
    [[ $_ZLE_PICKER_BOOKMARK[1] == 2 && $_ZLE_PICKER_BOOKMARK[4] == nod && $_ZLE_PICKER_BOOKMARK[5] == 0 ]] || exit 3
    [[ $frame == *"Exclude contains"*nod* && $frame == *$'\''\n'\''* ]] || exit 4
    [[ -z ${_ZLE_PICKER_EXCLUDE:-} ]] || exit 5
    keys=($'\''\x1d'\'' 2 $'\''\r'\'')
    _ZLE_PICKER_COLLECTOR=_navigation_picker_collect _ZLE_PICKER_DIGIT_SELECT=1
    _zle_picker_loop "" 10 || exit 6
    [[ $_ZLE_PICKER_BOOKMARK[1] == "" && $_ZLE_PICKER_BOOKMARK[4] == 2 && $_ZLE_PICKER_SELECTED_VALUE == node ]] || exit 7
    print input
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal input "$output"
}
test_case 'exclusion input switches fields keeps both filters and treats digits as text until both are empty' _test_exclusion_input

_test_exclusion_restore() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/.zsh.editor"
    _DIRECTORY_PICKER_VALUES=(/node /good /later) _DIRECTORY_PICKER_LABELS=(node good later)
    _DIRECTORY_PICKER_PATH_QUERY=""
    _directory_picker_restore "" /later 0 nod 1 1
    [[ $_DIRECTORY_PICKER_RESUME[2] == 2 && $_DIRECTORY_PICKER_RESUME[4] == nod && $_DIRECTORY_PICKER_RESUME[5] == 1 ]] || exit 1
    [[ -z ${_ZLE_PICKER_EXCLUDE:-} ]] || exit 2
    print restore
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal restore "$output"
}
test_case 'exclusion bookmarks resolve the exact selected directory within the restored filtered set' _test_exclusion_restore

_test_exclusion_history_fallback() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    local -A _history_search_source=(3 "swift build -c release" 2 "s-w-i-f-t -xxc")
    local _ZLE_PICKER_EXCLUDE=release
    _history_search_collect "-c swift" 20
    (( ${#_HISTORY_SEARCH_RESULTS} == 0 )) || exit 1
    print history
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal history "$output"
}
test_case 'exclusion subtracts history results without enabling a suppressed fuzzy fallback tier' _test_exclusion_history_fallback

_test_exclusion_native() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/.zsh.navigation"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    local event="" trace="" device="" pfd=0
    local bindings=$(bindkey -L)
    functions -c _zle_picker_show _exclusion_real_show
    _zle_picker_show() {
      _exclusion_real_show
      local value=${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]-}
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|${_ZLE_PICKER_EXCLUDE:-}|${_ZLE_PICKER_EXCLUDE_FOCUS:-0}|$value|$COLUMNS|$LINES|$_ZLE_PICKER_GUIDE_ACTIVE"
    }
    _exclusion_choices() {
      _ZLE_PICKER_TITLE=Choices _ZLE_PICKER_COLLECTOR=_navigation_picker_collect
      _zle_picker_loop "${1:-}" 10 "${2:-1}" "${3:-0}" "${4:-}" "${5:-0}" "${6:-0}"
    }
    _exclusion_menu() {
      local -a _NAVIGATION_PICKER_VALUES=(done) _NAVIGATION_PICKER_LABELS=(Done)
      _ZLE_PICKER_TITLE=Actions _ZLE_PICKER_COLLECTOR=_navigation_picker_collect
      _zle_picker_loop "" 10
    }
    _exclusion_controller() {
      local -a bookmark=("" 1 0)
      local -a _NAVIGATION_PICKER_VALUES=() _NAVIGATION_PICKER_LABELS=() _NAVIGATION_PICKER_SEARCH_LABELS=()
      local -i result=0 index=0
      for (( index=1; index<=20; ++index )); do _NAVIGATION_PICKER_VALUES+=("node$index"); done
      _NAVIGATION_PICKER_VALUES+=(good1 good2)
      _NAVIGATION_PICKER_LABELS=("${_NAVIGATION_PICKER_VALUES[@]}")
      while true; do
        _zle_ui_view choice _exclusion_choices "${bookmark[@]}"
        result=$?
        (( result == 0 )) || return $result
        bookmark=("${_ZLE_PICKER_BOOKMARK[@]}")
        _zle_ui_view action _exclusion_menu
        result=$?
        (( result == 1 )) || return $result
      done
    }
    _exclusion_driver() {
      command stty rows 24 cols 100
      print -r -u $efd -- "DEVICE|$(command tty)"
      _zle_picker_run 10 "" 1 0 _exclusion_controller
      local result=$?
      [[ $result == 1 && -z ${_ZLE_PICKER_EXCLUDE:-} && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $(bindkey -L) == "$bindings" ]] || print -r -u $efd BAD-CLEANUP
      print -r -u $efd DONE
    }
    _exclusion_expect() {
      local expected=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r exclusion chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" || ( $expected == DEVICE* && $event == DEVICE* ) ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $expected; got $event"
      return 1
    }
    zpty -b exclusion _exclusion_driver || exit 1
    pfd=$REPLY
    {
      _exclusion_expect "DEVICE|*" || exit 2
      device=${event#DEVICE|}
      _exclusion_expect "FRAME|Choices|||0|node1|100|24|0" || exit 3
      zpty -w -n exclusion $'\''\x1dnod'\''
      _exclusion_expect "FRAME|Choices||nod|1|good1|100|24|0" || exit 4
      zpty -w -n exclusion $'\''\x1d2'\''
      _exclusion_expect "FRAME|Choices|2|nod|0|good2|100|24|0" || exit 5
      zpty -w -n exclusion $'\''\x15\e[B\r'\''
      _exclusion_expect "FRAME|Actions|||0|done|100|24|0" || exit 6
      zpty -w -n exclusion $'\''\x07'\''
      _exclusion_expect "FRAME|Choices||nod|0|good2|100|24|0" || exit 7
      command stty rows 14 cols 40 < "$device" || exit 8
      _exclusion_expect "FRAME|Choices||nod|0|good2|40|14|0" || exit 9
      zpty -w -n exclusion $'\''\x0b\x1d'\''
      _exclusion_expect "FRAME|Choices||nod|0|good2|40|14|1" || exit 10
      zpty -w -n exclusion $'\''\x07\x1d\x15'\''
      _exclusion_expect "FRAME|Choices|||1|node1|40|14|0" || exit 11
      zpty -w -n exclusion $'\''\e[200~nod\x1d\e[201~'\''
      _exclusion_expect $'\''FRAME|Choices||nod\x1d|1|node1|40|14|0'\'' || exit 12
      zpty -w -n exclusion $'\''\x07'\''
      _exclusion_expect DONE || exit 13
      [[ $trace != *"read-only variable"* && $trace != *"bad math"* && $trace != *"command not found"* ]] || exit 14
      [[ $trace == *"Exclude contains"* ]] || exit 15
    } always {
      zpty -d exclusion
    }
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'exclusion native PTY restores fields across menus and resize and keeps guide paste and digits safe' _test_exclusion_native

_test_exclusion_empty_and_literal_entry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    local _ZLE_PICKER_EXCLUDE=node
    _DIRECTORY_PICKER_VALUES=(/node) _DIRECTORY_PICKER_LABELS=(node)
    _DIRECTORY_PICKER_CONTENT_COUNTS=(1 0 0) _DIRECTORY_PICKER_PATH_QUERY=""
    _directory_browser_collect "" 10
    [[ ${_ZLE_PICKER_EMPTY_LINES[1]} == *"match"* ]] || exit 1
    local -a _NAVIGATION_PICKER_VALUES=(main) _NAVIGATION_PICKER_LABELS=(main) _NAVIGATION_PICKER_SEARCH_LABELS=()
    _ZLE_PICKER_EXCLUDE=enter
    _git_review_ref_collect "" 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == main ]] || exit 2
    print boundaries
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal boundaries "$output"
}
test_case 'exclusion empty states distinguish hidden results and literal-entry actions honor their own label' _test_exclusion_empty_and_literal_entry

_test_exclusion_view_boundaries() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/.zsh.navigation"
    local -a keys=() _NAVIGATION_PICKER_VALUES=(node) _NAVIGATION_PICKER_LABELS=(node) _NAVIGATION_PICKER_SEARCH_LABELS=()
    local frame="" saved_buffer=unchanged
    BUFFER=$saved_buffer CURSOR=4
    zle() { :; }
    read() { (( ${#keys} )) || return 1; key=$keys[1]; keys[1]=(); }
    _zle_picker_show() { frame=$_ZLE_PICKER_QUERY_ROW; }
    _exclusion_query_fixture() { _zle_picker_loop "" 10; }
    _exclusion_choice_fixture() { _ZLE_PICKER_COLLECTOR=_navigation_picker_collect; _zle_picker_loop "" 10; }
    _ZLE_PICKER_SESSION=1 _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=80 LINES=24
    keys=($'\''\x1d'\'' n o d $'\''\r'\'')
    _zle_ui_view query _exclusion_query_fixture || exit 1
    [[ $_ZLE_PICKER_SELECTED_VALUE == nod && $frame != *"Exclude contains"* ]] || exit 2
    unfunction _matching_exclusion
    keys=($'\''\x1d'\'' n o d $'\''\r'\'')
    _zle_ui_view choice _exclusion_choice_fixture || exit 3
    [[ $_ZLE_PICKER_SELECTED_VALUE == node && $_ZLE_PICKER_BOOKMARK[1] == nod && $frame != *"Exclude contains"* ]] || exit 4
    [[ $BUFFER == "$saved_buffer" && $CURSOR == 4 ]] || exit 5
    print views
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal views "$output"
}
test_case 'exclusion stays unavailable in authored text and degrades to the original filter with its peer missing' _test_exclusion_view_boundaries

_test_exclusion_dock_geometry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 NO_COLOR=1
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    local _ZLE_PICKER_EXCLUDE=$'\''資料[*]\twithout-nod-with-a-very-long-suffix'\''
    local -i _ZLE_PICKER_EXCLUDE_SHOWN=1 _ZLE_PICKER_EXCLUDE_FOCUS=0 width=0 screen=0
    local -a rows=()
    local row="" input=$'\''literal %F{red} ! $() 資料'\''
    _ZLE_PICKER_RESULTS=(example) _ZLE_PICKER_LABELS=(example)
    for screen in 0 1; do
      _ZLE_PICKER_SCREEN_ACTIVE=$screen
      for width in 12 24 40 80 120; do
        COLUMNS=$width LINES=14
        for _ZLE_PICKER_EXCLUDE_FOCUS in 0 1; do
          _zle_picker_render "$input" 1 || exit 1
          rows=("${(@f)_ZLE_PICKER_QUERY_ROW}")
          (( ${#rows} == 2 )) || exit 2
          for row in "${rows[@]}"; do
            (( ${(m)#row} <= COLUMNS - 1 )) || exit 3
            [[ $row != *$'\''\e'\''* && $row != *$'\''\t'\''* ]] || exit 4
          done
          (( _ZLE_PICKER_QUERY_END <= ${#_ZLE_PICKER_QUERY_ROW} )) || exit 5
          if (( _ZLE_PICKER_EXCLUDE_FOCUS )); then
            (( _ZLE_PICKER_QUERY_START > ${#rows[1]} )) || exit 6
          else
            (( _ZLE_PICKER_QUERY_END <= ${#rows[1]} )) || exit 7
          fi
        done
      done
    done
    [[ $_ZLE_PICKER_EXCLUDE == $'\''資料[*]\twithout-nod-with-a-very-long-suffix'\'' ]] || exit 8
    print geometry
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal geometry "$output"
}
test_case 'exclusion dock fits two literal fields with active caret offsets across narrow inline and plain views' _test_exclusion_dock_geometry

_test_exclusion_sources() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/.zsh.find"
    mkdir -p "$HOME/repo" "$HOME/limited" "$HOME/bin"
    git init -q "$HOME/repo" || exit 1
    touch "$HOME/repo/node.swift" "$HOME/repo/good.swift" "$HOME/repo/also.swift"
    git -C "$HOME/repo" add . || exit 2
    _file_search_capture "$HOME/repo" "" git NOD || exit 3
    [[ ${#_FILE_SEARCH_VALUES} == 2 && ${(j:,:)_FILE_SEARCH_VALUES} != *node* ]] || exit 4
    ZSH_FILE_SEARCH_MAX_CANDIDATES=1
    _file_search_capture "$HOME/repo" swift git nod || exit 5
    [[ ${#_FILE_SEARCH_VALUES} == 1 && $_FILE_SEARCH_TRUNCATED == 1 ]] || exit 6
    touch "$HOME/limited/00node" "$HOME/limited/01node" "$HOME/limited/02keep"
    ZSH_FILE_SEARCH_MAX_VISITED=2
    _file_search_capture "$HOME/limited" "" local node
    [[ $? == 1 && $_FILE_SEARCH_VISITED == 2 && $_FILE_SEARCH_TRUNCATED == 1 && ${#_FILE_SEARCH_VALUES} == 0 ]] || exit 7
    print -rl -- "#!/bin/zsh -f" "print called > \"\$HOME/spotlight-called\"" > "$HOME/bin/mdfind"
    chmod +x "$HOME/bin/mdfind"
    PATH="$HOME/bin:$PATH"
    rehash
    _file_search_capture "$HOME/repo" "" spotlight nod
    [[ $? == 2 && ! -e "$HOME/spotlight-called" ]] || exit 8
    print sources
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal sources "$output"
}
test_case 'exclusion discovery keeps Git result caps filesystem visit bounds and Spotlight positive-seed requirements' _test_exclusion_sources

_test_exclusion_capture_display() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    local capture_fields="" result_fields="" displayed_summary=""
    _files_read_query() { _ZLE_PICKER_SELECTED_VALUE=""; _ZLE_PICKER_BOOKMARK=("" 1 0 nod 1 1); }
    _zle_picker_capture() {
      capture_fields="${_ZLE_PICKER_EXCLUDE:-}:${_ZLE_PICKER_EXCLUDE_SHOWN:-0}"
      _FILE_SEARCH_VALUES=(/good) _FILE_SEARCH_LABELS=(good) _FILE_SEARCH_MATCH_TEXTS=(good)
    }
    _file_search_inspector_capture() { :; }
    _zle_picker_loop() {
      result_fields="${_ZLE_PICKER_EXCLUDE:-}:${_ZLE_PICKER_EXCLUDE_SHOWN:-0}:${5:-}"
      displayed_summary=$_ZLE_PICKER_BROWSE_LABEL
      return 1
    }
    _file_search_choose "$HOME" "" local
    [[ $? == 1 && $capture_fields == nod:1 && $result_fields == :0: ]] || exit 1
    [[ $displayed_summary == *"exclude contains: nod"* ]] || exit 2
    print display
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal display "$output"
}
test_case 'exclusion capture displays discovery fields without applying them again as result filters' _test_exclusion_capture_display
