# Search actions retain the exact selected object across the workspace menu.
_test_search_actions_targets() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/Scope/deep/needle & notes.txt" fixture || return
  command mkdir -p "$TEST_TMP_DIR/home/Scope/deep/needle-folder" || return
  command ln -s 'needle & notes.txt' "$TEST_TMP_DIR/home/Scope/deep/needle-link" || return
  command ln -s needle-folder "$TEST_TMP_DIR/home/Scope/deep/needle-dir-link" || return
  command ln -s missing "$TEST_TMP_DIR/home/Scope/deep/needle-broken" || return
  test_write_file "$TEST_TMP_DIR/bin/open" $'#!/bin/zsh\nprint -rl -- "$@" >| "$HOME/opened"\nexit "${OPEN_STATUS:-0}"' || return
  test_write_file "$TEST_TMP_DIR/bin/pbcopy" $'#!/bin/zsh\n/bin/cat >| "$HOME/copied"' || return
  command chmod +x "$TEST_TMP_DIR/bin/open" "$TEST_TMP_DIR/bin/pbcopy" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$2" "${path[@]}")
    source "$1/.zshrc"
    [[ ${commands[open]} == "$2/open" && ${commands[pbcopy]} == "$2/pbcopy" ]] || exit 20
    local audit_target="" audit_action="" audit_group="" audit_scope="${HOME:A}/Scope"
    local audit_initial=$PWD BUFFER=sentinel CURSOR=4
    local -i audit_captures=0 audit_cancel=0 audit_picks=0
    functions[_audit_search_capture]=$functions[_file_search_capture]
    _file_search_capture() { (( ++audit_captures )); _audit_search_capture "$@"; }
    _zle_picker_screen_session() {
      local _ZLE_PICKER_SCREEN_ACTIVE=1
      _file_search_choose "$audit_scope" needle local
    }
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_TITLE == Files ]] || return 30
      (( ++audit_picks ))
      if (( audit_cancel && audit_picks > 1 )); then
        [[ $1 == narrow && $3 == 2 && $4 == 1 ]] || return 31
        return 1
      fi
      _ZLE_PICKER_SELECTED_VALUE=$audit_target
      _ZLE_PICKER_ACTION=actions
      _ZLE_PICKER_BOOKMARK=(narrow 2 1)
    }
    _directory_browser_pick() {
      local audit_index=${_directory_action_values[(Ie)$audit_action]}
      (( audit_index )) || { print -u2 -- "Missing action: $audit_action"; return 32; }
      [[ ${_directory_action_labels[audit_index]} == "$audit_group · "* &&
         ${_ZLE_PICKER_INSPECT_TEXTS[$audit_action]} == *"$audit_target"* ]] || {
        print -u2 -- "Action lost its selected target: $audit_action"; return 33
      }
      if [[ $audit_group != "Selected folder" ]]; then
        (( ! ${_directory_action_values[(Ie)cd]} && ! ${_directory_action_values[(Ie)select]} )) || return 34
      fi
      if [[ $audit_target == *needle-dir-link ]]; then
        (( ${_directory_action_values[(Ie)enter-link]} )) || return 36
      else
        (( ! ${_directory_action_values[(Ie)enter-link]} )) || return 37
      fi
      if [[ $audit_target == *needle-broken ]]; then
        (( ! ${_directory_action_values[(Ie)open]} )) || return 35
      fi
      (( audit_cancel )) && return 1
      _ZLE_PICKER_SELECTED_VALUE=$audit_action
    }
    zle() { return 0; }
    for audit_target in "$audit_scope/deep/needle & notes.txt" "$audit_scope/deep/needle-folder" "$audit_scope/deep/needle-link" "$audit_scope/deep/needle-dir-link" "$audit_scope/deep/needle-broken"; do
      audit_group="Selected file"
      [[ -d $audit_target ]] && audit_group="Selected folder"
      [[ -L $audit_target ]] && audit_group="Selected link"
      for audit_action in reveal open copy insert; do
        [[ $audit_target == *needle-broken && $audit_action == open ]] && continue
        [[ $audit_group == "Selected folder" && $audit_action == insert ]] && audit_action=select
        audit_captures=0 audit_picks=0 BUFFER=sentinel CURSOR=4
        _directory_browser_session "$audit_scope/" insert widget || exit 1
        [[ $PWD == "$audit_initial" && $audit_captures == 1 ]] || exit 2
        case $audit_action in
          (open) [[ $(< "$HOME/opened") == "--"$'\''\n'\''"$audit_target" ]] || exit 3 ;;
          (reveal) [[ $(< "$HOME/opened") == "-R"$'\''\n'\''"--"$'\''\n'\''"$audit_target" ]] || exit 4 ;;
          (copy) [[ $(< "$HOME/copied") == "$audit_target" ]] || exit 5 ;;
          (insert|select) [[ $BUFFER == "${(q)audit_target}" && $CURSOR == ${#BUFFER} ]] || exit 6 ;;
        esac
        [[ $audit_action == insert || $audit_action == select || $BUFFER == sentinel && $CURSOR == 4 ]] || exit 7
      done
    done
    audit_target="$audit_scope/deep/needle & notes.txt" audit_group="Selected file"
    audit_action=reveal audit_cancel=1 audit_captures=0 audit_picks=0
    BUFFER=sentinel CURSOR=4
    _directory_browser_session "$audit_scope/" insert widget
    [[ $? == 1 && $audit_captures == 1 && $audit_picks == 2 && $BUFFER == sentinel && $CURSOR == 4 ]] || exit 8
    audit_cancel=0 audit_action=open
    export OPEN_STATUS=19
    _directory_browser_session "$audit_scope/" insert widget
    (( $? == 19 )) || exit 9
    print exact-targets
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin") || return
  test_assert_equal exact-targets "$output"
}
test_case 'search workspace actions preserve exact file folder and link targets' _test_search_actions_targets

_test_search_actions_native() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/Root/deep/needle & notes.txt" fixture || return
  command mkdir -p "$TEST_TMP_DIR/home/Root/deep/needle-folder" || return
  test_write_file "$TEST_TMP_DIR/bin/open" $'#!/bin/zsh\nprint -rl -- "$@" >| "$HOME/opened"\nprint -r -- LAUNCHED > "$HOME/events"' || return
  command chmod +x "$TEST_TMP_DIR/bin/open" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$2" "${path[@]}")
    source "$1/.zshrc"
    [[ ${commands[open]} == "$2/open" ]] || exit 1
    zmodload zsh/zpty zsh/zselect
    command mkfifo "$HOME/events" || exit 2
    exec {efd}<> "$HOME/events"
    local event="" trace="" chunk="" scenario="" action="" pfd=0
    local root="${HOME:A}/Root" initial=$PWD
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions[_action_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _action_show
      if [[ $_ZLE_PICKER_TITLE == Files && $_ZLE_PICKER_QUERY == notes ]]; then
        [[ ${_ZLE_PICKER_DISPLAY[-1]} == *"⏎ file actions"* &&
           ${_ZLE_PICKER_DISPLAY[-1]} == *"^X options"* ]] || print -r -u $efd BAD-ACTION-HINT
      elif [[ $_ZLE_PICKER_TITLE == "Path actions" || $_ZLE_PICKER_TITLE == "Folder actions" ]]; then
        [[ ${_ZLE_PICKER_DISPLAY[-1]} != *"^X"* ]] || print -r -u $efd BAD-NESTED-OPTIONS
      fi
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY"
    }
    functions[_action_capture]=$functions[_file_search_capture]
    _file_search_capture() { (( ++captures )); _action_capture "$@"; }
    functions[_action_screen]=$functions[_zle_picker_screen_session]
    _zle_picker_screen_session() {
      _action_screen "$@"
      local result=$?
      print -r -u $efd CLEANUP
      return $result
    }
    functions[_action_widget]=$functions[_directory_context_complete_widget]
    _action_widget_test() {
      _action_widget
      local result=$? expected="--"$'\''\n'\''"$target"
      [[ $action == reveal ]] && expected="-R"$'\''\n'\''"$expected"
      [[ $result == 0 && $BUFFER == "$root/" && $CURSOR == ${#BUFFER} &&
         $PWD == "$initial" && $captures == 1 &&
         $_ZLE_PICKER_ACTIVE == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 &&
         $(< "$HOME/opened") == "$expected" ]] || print -r -u $efd BAD-RETURN
      print -r -u $efd RETURNED
    }
    zle -N directory-context-complete _action_widget_test
    _action_ready() { print -r -u $efd READY; }
    zle -N zle-line-init _action_ready
    _action_driver() {
      command stty rows 30 cols 120
      local draft="$root/" target="$root/deep/needle & notes.txt"
      local -i captures=0
      [[ $scenario == folder ]] && target="$root/deep/needle-folder"
      vared draft
      print -r -u $efd DONE
    }
    _action_expect() {
      local expected=$1
      while zselect -r $efd $pfd -t 500; do
        while zpty -r actions chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$expected" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "$scenario/$action: expected $expected; got $event"
      return 1
    }
    for scenario in file folder; do
      for action in open reveal; do
        trace=""
        zpty -b actions _action_driver || exit 3
        pfd=$REPLY
        {
          _action_expect READY || exit 4
          zpty -w -n actions $'\''\t'\''
          _action_expect "FRAME|Directory browser|" || exit 5
          zpty -w -n actions $'\''\x06'\''
          _action_expect "FRAME|Search descendants|" || exit 6
          zpty -w -n actions needle
          _action_expect "FRAME|Search descendants|needle" || exit 7
          zpty -w -n actions $'\''\r'\''
          _action_expect "FRAME|Files|" || exit 8
          query=notes title="Path actions"
          [[ $scenario == folder ]] && { query=folder; title="Folder actions"; }
          zpty -w -n actions "$query"
          _action_expect "FRAME|Files|$query" || exit 9
          zpty -w -n actions $'\''\x18'\''
          _action_expect "FRAME|$title|" || exit 10
          # Back keeps the filtered result; reopening must retain its target.
          zpty -w -n actions $'\''\e'\''
          _action_expect "FRAME|Files|$query" || exit 11
          zpty -w -n actions $'\''\x18'\''
          _action_expect "FRAME|$title|" || exit 12
          zpty -w -n actions "$action"
          _action_expect "FRAME|$title|$action" || exit 13
          zpty -w -n actions $'\''\r'\''
          _action_expect CLEANUP || exit 18
          _action_expect LAUNCHED || exit 19
          _action_expect RETURNED || exit 14
          zpty -w -n actions $'\''\r'\''
          _action_expect DONE || exit 15
          [[ $trace == *"$enter"* && $trace == *"$leave"* ]] || exit 16
          trace=${trace/"$enter"/} trace=${trace/"$leave"/}
          [[ $trace != *"$enter"* && $trace != *"$leave"* &&
             $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 17
        } always { zpty -d actions; }
      done
    done
    print native-targets
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin") || return
  test_assert_equal native-targets "$output"
}
test_case 'search actions native Tab Ctrl-F Ctrl-X opens and reveals exact files and folders' _test_search_actions_native
