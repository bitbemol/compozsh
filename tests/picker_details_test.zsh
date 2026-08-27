# Contracts for reusing the inspector without changing a tool's action.
_test_details_labels() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_RESULTS=(main)
    _ZLE_PICKER_LABELS=(main)
    _ZLE_PICKER_RESULT_INDEXES=(0)
    _ZLE_PICKER_INSPECT_TEXTS=(main "main\nCurrent branch")
    _ZLE_PICKER_INSPECT_TITLE=Branch
    _ZLE_PICKER_INSPECT_ACTION=switch
    _ZLE_PICKER_COPY_ENABLED=1
    for COLUMNS in 120 80 60; do
      for _ZLE_PICKER_INSPECT_FOCUS in 0 1; do
        _zle_picker_render "" 1
        [[ ${_ZLE_PICKER_DISPLAY[-1]} == *"switch"* ]] || exit 1
        [[ ${_ZLE_PICKER_DISPLAY[-1]} == *"^Y copy"* ]] || exit 2
        [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"print help"* ]] || exit 3
      done
    done
    COLUMNS=120
    _zle_picker_render "" 1
    [[ ${_ZLE_PICKER_DISPLAY[1]#*│} == *"Branch"* &&
       ${_ZLE_PICKER_DISPLAY[1]#*│} != *main* ]] || exit 4
    _ZLE_PICKER_COPY_ENABLED=0
    _zle_picker_render "" 1
    [[ ${_ZLE_PICKER_DISPLAY[-1]} != *"copy"* ]] || exit 5
    hostile=$'\''/snapshot/\e]52;c;invalid\a/name'\''
    _ZLE_PICKER_RESULTS=("$hostile")
    _ZLE_PICKER_LABELS=("$hostile")
    _ZLE_PICKER_INSPECT_TEXTS=("$hostile" "Literal path")
    _zle_picker_render "" 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *$'\''\e'\''* &&
       ${(j: :)_ZLE_PICKER_DISPLAY} != *$'\''\a'\''* ]] || exit 6
    long_path="/snapshot/${(l:200::nested/:)}target.md"
    _ZLE_PICKER_RESULTS=("$long_path")
    _ZLE_PICKER_LABELS=("$long_path")
    _ZLE_PICKER_INSPECT_TEXTS=("$long_path" "$(print -rl -- {1..40})")
    _zle_picker_render "" 1
    [[ ${_ZLE_PICKER_DISPLAY[1]} == *"1/40"* ]] || exit 7
    print labels
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal labels "$output"
}
test_case 'detail panels retain caller actions and clipboard hints' _test_details_labels

_test_branch_details_snapshot() {
  test_make_temp_dir || return
  local repository="$TEST_TMP_DIR/repository" output
  command git init -q "$repository" || return
  command git -C "$repository" -c user.name=Fixture -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit --allow-empty -qm $'Literal %F{red} $(never-run)\tmetadata' || return
  command git -C "$repository" branch -M main || return
  command git -C "$repository" switch -qc topic || return
  command git -C "$repository" branch --set-upstream-to=main topic >/dev/null || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    _git_recent_branches "$2" || exit 1
    _git_branch_inspector_capture "$2" || exit 2
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[topic]} == *"Current branch"* ]] || exit 3
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[topic]} == *"Upstream:"*$'\''\n  main'\''* ]] || exit 4
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[main]} == *"not configured"* ]] || exit 5
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[main]} == *'"'"'Literal %F{red} $(never-run)'"'"'* ]] || exit 6
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[main]} == *"Latest commit:"* ]] || exit 7
    path=()
    _git_branch_inspector_capture "$2" || exit 8
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[topic]} == *"Current branch"*"unavailable"* ]] || exit 9
    print branches
  ' "$TEST_REPO_ROOT" "$repository") || return
  test_assert_equal branches "$output"
}
test_case 'branch detail snapshots contain literal commit and upstream data' _test_branch_details_snapshot

_test_branch_details_bounds() {
  test_make_temp_dir || return
  local output
  test_write_file "$TEST_TMP_DIR/bin/git" $'#!/bin/zsh\n\
print -r -- called >> "$HOME/git-calls"\n\
print -rn -- "refs/heads/main"$\'\\0\'"origin/main"$\'\\0\'"abc123"$\'\\0\'${(l:600::x:)}$\'\\0\\n\'\n\
print -rn -- "refs/heads/topic"$\'\\0\'$\'\\0\'"def456"$\'\\0\'${(l:300000::y:)}$\'\\0\'\n' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    path=("$2" "${path[@]}")
    _GIT_RECENT_BRANCHES=(main topic)
    _GIT_RECENT_CURRENT=topic
    _git_branch_inspector_capture /fixture || exit 1
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[main]} == *"[truncated]"* ]] || exit 2
    (( ${#_ZLE_PICKER_INSPECT_TEXTS[main]} < 1000 )) || exit 3
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[topic]} == *"Current branch"*"read limit"* ]] || exit 4
    [[ $(<"$HOME/git-calls") == called ]] || exit 5
    print bounded
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin") || return
  test_assert_equal bounded "$output"
}
test_case 'branch details bound the bulk read and label incomplete metadata' _test_branch_details_bounds

_test_path_details_snapshot() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    _FILE_SEARCH_ROOT=/snapshot
    _FILE_SEARCH_SOURCE=local
    _FILE_SEARCH_VALUES=("/snapshot/notes file" "/snapshot/directory" "/snapshot/link")
    _FILE_SEARCH_LABELS=("· notes file" "▸ directory/" "↗ link")
    # These paths do not exist. The renderer must use the captured facts only.
    path=()
    _file_search_inspector_capture || exit 1
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[/snapshot/notes file]} == *"File"* ]] || exit 2
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[/snapshot/directory]} == *"Directory"* ]] || exit 3
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[/snapshot/link]} == *"Symbolic link"* ]] || exit 4
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[/snapshot/notes file]} == *"/snapshot/notes file"* ]] || exit 5
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[/snapshot/link]} != *"Search scope:"* ]] || exit 6
    _FILE_SEARCH_ROOT=""
    _FILE_SEARCH_SOURCE=spotlight
    _file_search_inspector_capture
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[/snapshot/link]} == *"/snapshot/link"* ]] || exit 7
    print paths
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal paths "$output"
}
test_case 'path detail snapshots reuse captured kinds and the complete literal path' _test_path_details_snapshot

_test_details_native_actions() {
  test_make_temp_dir || return
  local repository="$TEST_TMP_DIR/repository" output
  test_write_file "$TEST_TMP_DIR/bin/pbcopy" $'#!/bin/zsh\n/bin/cat > "$HOME/copied"' || return
  command chmod +x "$TEST_TMP_DIR/bin/pbcopy" || return
  command git init -q "$repository" || return
  command git -C "$repository" -c user.name=Fixture -c user.email=test@example.invalid \
    -c commit.gpgsign=false commit --allow-empty -qm initial || return
  command git -C "$repository" branch -M main || return
  command git -C "$repository" switch -qc topic || return
  command git -C "$repository" switch -q main || return
  test_write_file "$repository/note one" 'must not be executed' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    path=("$3" "${path[@]}")
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.editor"
    builtin cd "$2"
    zmodload zsh/zpty
    functions[_details_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _details_original_show
      print -r -- "FRAME:$_ZLE_PICKER_INSPECT_TITLE:$_ZLE_PICKER_INSPECT_FOCUS:${_ZLE_PICKER_DISPLAY[-1]}:END-DETAIL-FRAME"
    }
    _details_driver() {
      COLUMNS=120 LINES=30
      local passed=0 inserted="" copied="" expected_path="${PWD:A}/note one"
      if [[ $scenario == branch-* ]]; then g; else f --here note; fi
      (( ${#_ZLE_PICKER_INSPECT_TEXTS} == 0 && !_ZLE_PICKER_INSPECT_FOCUS &&
         ${#_ZLE_PICKER_CONTEXTS} == 0 && _ZLE_PICKER_INSPECT_LIST_PERCENT == 33 )) || passed=1
      case $scenario in
        (branch-copy)
          copied=$(<"$HOME/copied")
          [[ $copied == topic && $(command git branch --show-current) == main ]] || passed=2 ;;
        (branch-switch|branch-enter)
          local expected_branch=topic
          [[ $scenario == branch-enter ]] && expected_branch=main
          [[ $(command git branch --show-current) == "$expected_branch" ]] || passed=3 ;;
        (file-copy)
          copied=$(<"$HOME/copied")
          [[ $copied == "$expected_path" ]] || passed=4 ;;
        (file-insert|file-enter)
          IFS= read -r -z inserted || passed=5
          _file_search_quote "$expected_path"
          [[ $inserted == "$REPLY" ]] || passed=6 ;;
      esac
      print -r -- "DONE:$passed:END-DETAIL-DONE"
    }
    _details_read() {
      while zpty -r details frame; do
        [[ $frame == *"$1"* ]] && return 0
      done
      return 1
    }
    for scenario in branch-copy branch-switch branch-enter file-copy file-insert file-enter file-cancel; do
      zpty details _details_driver || exit 1
      {
        _details_read END-DETAIL-FRAME || exit 2
        [[ $frame == *"^Y copy"* && $frame != *"print help"* ]] || exit 3
        if [[ $scenario == *-copy || $scenario == *-enter ]]; then
          if [[ $scenario == branch-copy || $scenario == branch-enter ]]; then
            zpty -w -n details $'\''\e[B'\''
            _details_read END-DETAIL-FRAME || exit 4
          fi
          zpty -w -n details $'\''\e[C'\''
          _details_read END-DETAIL-FRAME || exit 5
          [[ $frame == *":1:"* ]] || exit 6
          if [[ $scenario == *-copy ]]; then
            zpty -w -n details $'\''\x19'\''
          else
            zpty -w -n details $'\''\r'\''
          fi
        elif [[ $scenario == file-cancel ]]; then
          zpty -w -n details $'\''\e'\''
        else
          # Both selectors retain immediate empty-query digit selection.
          zpty -w -n details 1
        fi
        _details_read END-DETAIL-DONE || exit 7
        [[ $frame == *"DONE:0:"* ]] || { print -u2 -r -- "$scenario: $frame"; exit 8; }
      } always {
        zpty -d details
      }
    done
    print actions
  ' "$TEST_REPO_ROOT" "$repository" "$TEST_TMP_DIR/bin") || return
  test_assert_equal actions "$output"
}
test_case 'detail panels preserve native branch switches, path insertion, copying, and cleanup' _test_details_native_actions
