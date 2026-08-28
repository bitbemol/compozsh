# Path + Tab owns filesystem browsing/search; Recents is a separate view.
_test_files_workspace_boundary() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    (( ! ${+functions[d]} && ! ${+functions[f]} )) || exit 11
    (( ! ${+functions[_compozsh_help_d]} && ! ${+functions[_compozsh_help_f]} )) || exit 12
    for TERM in xterm-256color screen-256color; do
      source "$1/.zsh.addons/.zsh.editor"
      [[ $(bindkey "^[^I") == *files-recents* ]] || exit 13
      [[ $(bindkey "^I") == *directory-context-complete* ]] || exit 17
      [[ $(bindkey "^X^D") != *files-recents* ]] || exit 18
      [[ $(bindkey "^[[Z") == *reverse-menu-complete* ]] || exit 19
    done
    [[ $(bindkey "^D") == *delete-char-or-list* ]] || exit 14
    [[ $(bindkey "^X^E") == *edit-command-line* ]] || exit 15
    (( ${+functions[_file_search_capture]} && ${+functions[_directory_recents_choose]} )) || exit 16
    print unified
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal unified "$output"
}
test_case 'filesystem workspace replaces d and f without stealing ordinary editing keys' _test_files_workspace_boundary

_test_files_recents_missing_peer() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    local BUFFER=sentinel CURSOR=5 message="" initial_pwd=$PWD
    zle() { [[ $1 == -M ]] && message=$2; }
    _files_recents_widget
    [[ $? == 1 && $message == *"navigation add-on"* &&
       $BUFFER == sentinel && $CURSOR == 5 && $PWD == "$initial_pwd" ]] || exit 1
    print unavailable
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal unavailable "$output"
}
test_case 'Recents reports a missing peer without altering the draft or directory' _test_files_recents_missing_peer

_test_files_recents_acceptance() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Previous & notes" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local BUFFER=sentinel CURSOR=5 initial_pwd=$PWD
    local expected_path="$HOME/Previous & notes"
    local -a dirstack=("$expected_path")
    local -i input_calls=0 redraws=0
    zle() { [[ $1 == redisplay ]] && (( ++redraws )); return 0; }
    _zle_picker_screen_session() { "$@"; }
    _zle_picker_loop() {
      (( ++input_calls ))
      [[ $_ZLE_PICKER_INSPECT_ACTION == insert ]] || return 21
      [[ $_NAVIGATION_PICKER_VALUES[2] == "$expected_path" ]] || return 22
      _ZLE_PICKER_SELECTED_VALUE=$_NAVIGATION_PICKER_VALUES[2]
      _ZLE_PICKER_ACTION=select
      _ZLE_PICKER_BOOKMARK=("" 2 0)
    }
    _files_recents_widget
    [[ $PWD == "$initial_pwd" && $BUFFER == "${(q)expected_path}" &&
       $CURSOR == ${#BUFFER} && $input_calls == 1 && $redraws == 1 ]] || exit 23
    print editable
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal editable "$output"
}
test_case 'Recents acceptance inserts a quoted editable path without changing directory' _test_files_recents_acceptance

_test_files_workspace_scope() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/tree/inside/deeper" "$TEST_TMP_DIR/tree/outside" || return
  test_write_file "$TEST_TMP_DIR/tree/inside/deeper/needle.txt" one || return
  test_write_file "$TEST_TMP_DIR/tree/outside/needle.txt" two || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    root=${2:A}
    _file_search_capture "$root/inside" needle local || exit 1
    [[ ${#_FILE_SEARCH_VALUES} == 1 && $_FILE_SEARCH_VALUES[1] == "$root/inside/deeper/needle.txt" ]] || exit 2
    command git -C "$root" init -q || exit 3
    _file_search_capture "$root/inside" needle git || exit 4
    [[ ${#_FILE_SEARCH_VALUES} == 1 && $_FILE_SEARCH_ROOT == "$root/inside" ]] || exit 5
    _file_search_capture "$root" " " local
    [[ $? == 2 && ${#_FILE_SEARCH_VALUES} == 0 ]] || exit 6
    _file_search_capture "$root" needle unknown
    [[ $? == 2 && ${#_FILE_SEARCH_VALUES} == 0 ]] || exit 7
    print scoped
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/tree") || return
  test_assert_equal scoped "$output"
}
test_case 'filesystem workspace searches the opened scope even inside a repository' _test_files_workspace_scope

_test_files_recents_bookmark() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -a _FILES_RECENTS_BOOKMARK=("" 1 0)
    local _directory_browser_clipboard="" mode=insert
    local -i visits=0
    _zle_picker_loop() {
      (( ++visits ))
      if (( visits == 2 )); then
        [[ $1 == previous && $3 == 2 && $4 == 1 ]] || return 22
      fi
      _ZLE_PICKER_BOOKMARK=(previous 2 1)
      _ZLE_PICKER_ACTION=browse
      _ZLE_PICKER_SELECTED_VALUE=$HOME
    }
    _directory_recents_choose || exit
    _directory_recents_choose || exit
    [[ $_FILES_RECENTS_BOOKMARK[1] == previous ]] || exit 23
    print restored
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal restored "$output"
}
test_case 'Recents restores its filter selection and viewport after browsing' _test_files_recents_bookmark

_test_files_workspace_capabilities() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    local _FILES_WORKSPACE=1 _DIRECTORY_PICKER_LOCATION=./
    local _directory_browser_clipboard="" _directory_browser_open="" mode=insert
    _directory_browser_pick() {
      [[ ${(j:|:)_directory_action_values} != *search-* &&
         ${(j:|:)_directory_action_values} != *view-recents* ]] || return 25
      return 1
    }
    _directory_browser_actions "" insert
    (( $? == 1 )) || exit 1
    source "$1/.zsh.addons/.zsh.find"
    _file_search_capture() { _file_search_reset; return 2; }
    local -i actions=0
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_BROWSE_LABEL == "Source failed or unavailable"* &&
         ${_ZLE_PICKER_EMPTY_LINES[1]} == "The search source failed or is unavailable" &&
         ${#_FILE_SEARCH_VALUES} == 0 ]] || { print -u2 "Source failure lost on return from actions"; return 26; }
      _ZLE_PICKER_ACTION=actions
      return 0
    }
    _directory_browser_actions() {
      (( ++actions == 1 )) && return 1
      _ZLE_PICKER_ACTION=view-browse
    }
    _file_search_choose "$HOME" query git || exit 2
    [[ $_ZLE_PICKER_ACTION == view-browse && $actions == 2 ]] || exit 3
    print recoverable
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal recoverable "$output"
}
test_case 'filesystem workspace omits unavailable peers and lets failed searches return to Browse' _test_files_workspace_capabilities

_test_files_workspace_link_refresh() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/target" || return
  command ln -s target "$TEST_TMP_DIR/home/link" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc"
    local -i refreshed=0
    _zle_picker_screen_session() {
      _ZLE_PICKER_ACTION=enter-link
      _ZLE_PICKER_SELECTED_VALUE="$HOME/link"
    }
    zle() { [[ $1 == reset-prompt ]] && (( ++refreshed )); }
    _directory_browser_session ~/ insert widget || exit 1
    [[ $PWD -ef "$HOME/target" && $refreshed == 1 ]] || exit 2
    print refreshed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refreshed "$output"
}
test_case 'following a directory link refreshes the prompt after workspace cleanup' _test_files_workspace_link_refresh

_test_files_workspace_journey() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Projects/child/deep" "$TEST_TMP_DIR/home/Previous & notes" || return
  test_write_file "$TEST_TMP_DIR/home/Projects/child/deep/needle & notes.txt" contents || return
  test_write_file "$TEST_TMP_DIR/home/copy-path" '#!/bin/sh
cat > "$HOME/copied-path"' || return
  command chmod +x "$TEST_TMP_DIR/home/copy-path" || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    commands[pbcopy]="$HOME/copy-path"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events"
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions[_workspace_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _workspace_show
      if [[ $_ZLE_PICKER_TITLE == "Folder actions" && $_ZLE_PICKER_QUERY == "Recent directories" ]]; then
        [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"Go to · Recent directories"* ]] || print -r -u $efd BAD-GROUP-LABEL
      fi
      print -r -u $efd -- "FRAME:$_ZLE_PICKER_TITLE:$_ZLE_PICKER_QUERY"
    }
    functions[_workspace_capture]=$functions[_file_search_capture_local]
    _file_search_capture_local() {
      (( ! _ZLE_PICKER_ACTIVE && _ZLE_PICKER_SCREEN_ACTIVE )) || print -r -u $efd BAD-CAPTURE
      (( ++captures ))
      _workspace_capture "$@"
    }
    functions[_workspace_prepare]=$functions[_directory_picker_prepare]
    _directory_picker_prepare() {
      [[ $scenario == recents* ]] && print -r -u $efd BAD-CHILD-SCAN
      _workspace_prepare "$@"
    }
    chpwd() {
      (( ! ${_ZLE_PICKER_SCREEN_ACTIVE:-0} && ! $_ZLE_PICKER_ACTIVE )) || print -r -u $efd BAD-CD
    }
    _workspace_ready() { print -r -u $efd READY; }
    _workspace_assert_edit() {
      [[ $BUFFER == "$expected_draft" && $CURSOR == $expected_cursor &&
         $_ZLE_PICKER_ACTIVE == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]] || print -r -u $efd BAD-EDIT-STATE
    }
    zle() {
      builtin zle "$@"
      local result=$?
      # Ctrl-C unwinds the calling widget and vared as well. Observe the real
      # cleanup boundary, just as the shared screen-lifecycle test does.
      if [[ $scenario == recents-abort && $1 == .redisplay &&
            ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 ]]; then
        _workspace_assert_edit
        [[ $PWD == "$HOME/Projects" && $captures == 0 ]] || print -r -u $efd BAD-ABORT
        print -r -u $efd RETURNED
      fi
      return $result
    }
    functions[_workspace_recents]=$functions[_files_recents_widget]
    _files_recents_widget() {
      _workspace_recents
      _workspace_assert_edit
      [[ $PWD == "$HOME/Projects" && $captures == 0 ]] || print -r -u $efd BAD-EARLY-CD
      # Synchronize before sending Return: an immediately adjacent ESC Return
      # is a terminal sequence, not standalone Escape followed by a new edit.
      print -r -u $efd RETURNED
    }
    _workspace_driver() {
      command stty rows 30 cols 120
      builtin cd "$HOME/Projects"
      dirstack=("$HOME/Previous & notes")
      local -i captures=0
      local draft=""
      add-zle-hook-widget line-init _workspace_ready
      vared draft
      if [[ $scenario == recents || $scenario == recents-empty || $scenario == recents-enter ]]; then
        [[ $PWD == "$HOME/Projects" && $draft == "$expected_draft" && $captures == 0 ]] || print -r -u $efd BAD-RECENTS
      elif [[ $scenario == recents-* ]]; then
        [[ $PWD == "$HOME/Projects" && $draft == sentinel && $captures == 0 ]] || print -r -u $efd BAD-RECENTS-CANCEL
        if [[ $scenario == recents-copy ]]; then
          [[ $(< "$HOME/copied-path") == "$HOME/Previous & notes" ]] || print -r -u $efd BAD-COPY
        fi
      elif [[ $scenario == menu-recents ]]; then
        [[ $PWD == "$HOME/Projects" && $draft == "$expected_draft" && $captures == 0 ]] || print -r -u $efd BAD-RECENTS
      elif [[ $scenario == cancel ]]; then
        [[ $draft == "./" && $captures == 1 ]] || print -r -u $efd BAD-CANCEL
      else
        _directory_picker_quote "${HOME:A}/Projects/child/deep/needle & notes.txt"
        [[ $PWD == "$HOME/Projects" && $draft == "$REPLY" && $captures == 1 ]] || print -r -u $efd -- "BAD-INSERT:$draft:$captures"
      fi
      print -r -u $efd DONE
    }
    _workspace_expect() {
      local wanted=$1 chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r workspace chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "$scenario: expected $wanted; got $event"
      return 1
    }
    _workspace_key() {
      zpty -w -n workspace "$1"
      _workspace_expect "$2" || return 1
      [[ $trace == *"$enter"* && ${trace#*"$enter"} != *"$enter"* && $trace != *"$leave"* ]] || return 2
    }
    local scenario="" trace="" event="" pfd=0 expected_draft="" expected_cursor=0
    for scenario in search cancel recents recents-empty recents-enter recents-copy recents-escape recents-abort menu-recents; do
      trace=""
      expected_draft=sentinel expected_cursor=5
      if [[ $scenario == recents || $scenario == recents-empty || $scenario == recents-enter || $scenario == menu-recents ]]; then
        _directory_picker_quote "$HOME/Previous & notes"
        expected_draft=$REPLY expected_cursor=${#REPLY}
      fi
      zpty -b workspace _workspace_driver || exit 2
      pfd=$REPLY
      {
        _workspace_expect READY || exit 3
        if [[ $scenario == recents* ]]; then
          # Meta-Tab is ESC TAB on the wire, one Option-Tab gesture. Keep
          # an unfinished command and a non-end cursor to check replacement on
          # acceptance and exact restoration when cancelling or copying.
          if [[ $scenario == recents-empty ]]; then
            _workspace_key $'\''\e\t'\'' "FRAME:Recent directories:" || exit 4
          else
            _workspace_key $'\''sentinel\x02\x02\x02\e\t'\'' "FRAME:Recent directories:" || exit 4
          fi
          # Current is slot 0; previous is slot 1. Both acceptance gestures
          # insert a quoted path. Copy and cancellation preserve the draft.
          case $scenario in
            (recents-escape) zpty -w -n workspace $'\''\e'\'' ;;
            (recents-abort) zpty -w -n workspace $'\''\x03'\'' ;;
            (recents-enter|recents-copy)
              _workspace_key $'\''\e[B'\'' "FRAME:Recent directories:" || exit 25
              if [[ $scenario == recents-enter ]]; then
                zpty -w -n workspace $'\''\r'\''
              else
                zpty -w -n workspace $'\''\x19'\''
              fi ;;
            (*) zpty -w -n workspace 1 ;;
          esac
          _workspace_expect RETURNED || exit 24
        else
          _workspace_key $'\''./\t'\'' "FRAME:Directory browser:" || exit 5
          _workspace_key $'\''\x18'\'' "FRAME:Folder actions:" || exit 6
          if [[ $scenario == menu-recents ]]; then
            _workspace_key "Recent directories" "FRAME:Folder actions:Recent directories" || exit 16
            _workspace_key 1 "FRAME:Folder actions:Recent directories1" || exit 17
            # With a query, digits are text. Remove it before accepting.
            _workspace_key $'\''\x7f'\'' "FRAME:Folder actions:Recent directories" || exit 18
            _workspace_key $'\''\r'\'' "FRAME:Recent directories:" || exit 19
            _workspace_key $'\''\x07'\'' "FRAME:Directory browser:" || exit 20
            _workspace_key $'\''\x18'\'' "FRAME:Folder actions:" || exit 21
            _workspace_key "Recent directories" "FRAME:Folder actions:Recent directories" || exit 22
            _workspace_key $'\''\r'\'' "FRAME:Recent directories:" || exit 23
            zpty -w -n workspace 1
          else
            _workspace_key "Search filesystem" "FRAME:Folder actions:Search filesystem" || exit 7
            _workspace_key $'\''\r'\'' "FRAME:Search descendants:" || exit 8
            # Nothing searches until the query is explicitly submitted.
            _workspace_key needle "FRAME:Search descendants:needle" || exit 9
            _workspace_key $'\''\r'\'' "FRAME:Files:" || exit 10
            if [[ $scenario == cancel ]]; then
              _workspace_key $'\''\x07'\'' "FRAME:Directory browser:" || exit 11
              zpty -w -n workspace $'\''\x07'\''
            else
              _workspace_key 1 "FRAME:File actions:" || exit 12
              _workspace_key "Insert" "FRAME:File actions:Insert" || exit 13
              zpty -w -n workspace $'\''\r'\''
            fi
          fi
        fi
        if [[ $scenario != recents-abort ]]; then
          # Finish vared only; no command is evaluated by this test.
          zpty -w -n workspace $'\''\r'\''
          _workspace_expect DONE || exit 14
        fi
        [[ $trace == *"$enter"*"$leave"* && ${trace#*"$leave"} != *"$leave"* &&
           $trace != *"read-only variable"* ]] || exit 15
        if [[ $scenario == recents || $scenario == recents-empty || $scenario == recents-enter || $scenario == menu-recents ]]; then
          # Verify actual terminal painting after the alternate screen closes,
          # not just BUFFER: this regression presented as an invisible path.
          [[ ${trace#*"$leave"} == *"Previous\\ \\&\\ notes"* ]] || exit 26
        fi
      } always { zpty -d workspace; }
    done
    print journey
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal journey "$output"
}
test_case 'filesystem workspace keeps search recents file actions and cancellation in one screen' _test_files_workspace_journey
