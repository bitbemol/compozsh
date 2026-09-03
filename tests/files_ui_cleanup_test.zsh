# Secondary Files menus consume shared view defaults without changing targets.
_test_files_action_menu_empty_state() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.find"
    _ZLE_PICKER_EMPTY_LINES=("No matching captured paths" "Ctrl-F edits the search")
    _ZLE_PICKER_TRAIL=(Location parent)
    _ZLE_PICKER_SEARCH_ACTION=search-local
    _ZLE_PICKER_WORKSPACE_ACTIONS=1
    _ZLE_PICKER_INSPECT_TEXTS=(outer "Parent path details")
    _zle_picker_run() {
      "$_ZLE_PICKER_COLLECTOR" impossible-action 10
      COLUMNS=100 LINES=24
      _zle_picker_render impossible-action 1
      local painted=${(j:\n:)_ZLE_PICKER_DISPLAY}
      [[ $painted != *"No matching captured paths"* &&
         $painted != *"Ctrl-F edits the search"* &&
         ${#_ZLE_PICKER_TRAIL} == 0 ]] || {
        print -u2 -- "file actions displayed parent search instructions"
        return 30
      }
      [[ $_ZLE_PICKER_EMPTY_LABEL == "no matching actions" &&
         $_ZLE_PICKER_QUERY_LABEL == "Filter actions" &&
         -z $_ZLE_PICKER_SEARCH_ACTION && $_ZLE_PICKER_WORKSPACE_ACTIONS == 0 ]] || return 31
      _ZLE_PICKER_SELECTED_VALUE=insert _ZLE_PICKER_ACTION=select
      _ZLE_PICKER_BOOKMARK=(impossible-action 1 0)
      return 17
    }
    _file_search_actions "$HOME/note.txt" "" ""
    (( $? == 17 )) || exit 1
    [[ ${_ZLE_PICKER_EMPTY_LINES[1]} == "No matching captured paths" &&
       ${(j:|:)_ZLE_PICKER_TRAIL} == Location\|parent &&
       $_ZLE_PICKER_INSPECT_TEXTS[outer] == "Parent path details" &&
       $_ZLE_PICKER_SEARCH_ACTION == search-local &&
       $_ZLE_PICKER_WORKSPACE_ACTIONS == 1 &&
       $_ZLE_PICKER_SELECTED_VALUE == insert &&
       ${_ZLE_PICKER_BOOKMARK[1]} == impossible-action ]] || exit 2
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'Files action menus replace parent empty instructions and restore the caller view' \
  _test_files_action_menu_empty_state

_test_files_folder_menu_capabilities() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    local _DIRECTORY_PICKER_LOCATION="$HOME/current/"
    local _directory_browser_clipboard="" _directory_browser_open=""
    local target="$HOME/selected/"
    _ZLE_PICKER_INSPECT_EXPAND_KEY=$target
    _ZLE_PICKER_INSPECT_FIXED_KEY=outer
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1
    _ZLE_PICKER_REFRESH_ENABLED=1 _ZLE_PICKER_QUERY_SUBMIT=1
    _ZLE_PICKER_PASSIVE_LINES=(outer) _ZLE_PICKER_GUIDE_CONTEXT=(outer)
    _directory_browser_pick() {
      (( !_ZLE_PICKER_DOCUMENT && !_ZLE_PICKER_READER_ONLY &&
         !_ZLE_PICKER_REFRESH_ENABLED && !_ZLE_PICKER_QUERY_SUBMIT &&
         !${#_ZLE_PICKER_PASSIVE_LINES} && !${#_ZLE_PICKER_GUIDE_CONTEXT} )) &&
        [[ -z $_ZLE_PICKER_INSPECT_EXPAND_KEY && -z $_ZLE_PICKER_INSPECT_FIXED_KEY ]] || {
        print -u2 -- "folder actions inherited unrelated view capabilities"
        return 30
      }
      _ZLE_PICKER_SELECTED_VALUE=current-cd
      return 0
    }
    _directory_browser_actions "$target" insert || exit 1
    [[ $_ZLE_PICKER_ACTION == cd &&
       $_ZLE_PICKER_SELECTED_VALUE == "$_DIRECTORY_PICKER_LOCATION" &&
       $_ZLE_PICKER_INSPECT_EXPAND_KEY == "$target" &&
       $_ZLE_PICKER_INSPECT_FIXED_KEY == outer ]] || exit 2
    (( _ZLE_PICKER_DOCUMENT && _ZLE_PICKER_READER_ONLY &&
       _ZLE_PICKER_REFRESH_ENABLED && _ZLE_PICKER_QUERY_SUBMIT )) || exit 3
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'Files folder actions isolate reader capabilities while preserving exact action targets' \
  _test_files_folder_menu_capabilities

_test_files_git_capture_no_monitor() {
  test_make_temp_dir || return
  local output=''
  test_write_file "$TEST_TMP_DIR/home/monitor" \
    $'#!/bin/zsh\nprint invoked >| "$HOME/monitor-invoked"\nprint -rn -- $\'\\0\'' || return
  command chmod +x "$TEST_TMP_DIR/home/monitor" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/support/.zsh.matching"
    command git init -q "$HOME/repository" || exit 1
    print -r -- fixture > "$HOME/repository/note.txt"
    command git -C "$HOME/repository" add note.txt || exit 2
    command git -C "$HOME/repository" config core.fsmonitor "$HOME/monitor" || exit 3
    _file_search_capture_git "$HOME/repository" note || exit 4
    [[ ! -e $HOME/monitor-invoked ]] || {
      print -u2 -- "Git file capture executed repository-configured fsmonitor"
      exit 5
    }
    [[ ${(j:|:)_FILE_SEARCH_VALUES} == "${HOME:A}/repository/note.txt" &&
       ${(j:|:)_FILE_SEARCH_LABELS} == "· note.txt" &&
       $_FILE_SEARCH_SOURCE == git ]] || exit 6
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'Files Git capture never executes a repository-configured filesystem monitor' \
  _test_files_git_capture_no_monitor

_test_files_git_explicit_folder_scope() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/support/.zsh.matching"
    local name="" root=""
    for name in current foreign; do
      command git init -qb main "$HOME/$name" || exit 1
      command git -C "$HOME/$name" config user.name Fixture
      command git -C "$HOME/$name" config user.email fixture@example.invalid
      print -r -- "$name" > "$HOME/$name/$name.txt"
      command git -C "$HOME/$name" add "$name.txt" || exit 2
      command git -C "$HOME/$name" -c commit.gpgsign=false commit -qm initial || exit 3
    done
    command git -C "$HOME/current" worktree add --detach -q "$HOME/linked" || exit 4
    command git init -q "$HOME/container" || exit 4
    command git -C "$HOME/container" -c protocol.file.allow=always \
      submodule add -q "$HOME/current" module || exit 4
    command mkdir "$HOME/plain" || exit 5
    local foreign_root=${HOME:A}/foreign
    export GIT_DIR="$foreign_root/.git" GIT_WORK_TREE="$foreign_root"
    export GIT_COMMON_DIR="$foreign_root/.git" GIT_INDEX_FILE="$foreign_root/.git/index"
    export GIT_OBJECT_DIRECTORY="$foreign_root/.git/objects"
    export GIT_ALTERNATE_OBJECT_DIRECTORIES="$foreign_root/.git/objects" GIT_NAMESPACE=foreign
    export GIT_OPTIONAL_LOCKS=1 GIT_NO_LAZY_FETCH=0 GIT_TERMINAL_PROMPT=1 GIT_ALLOW_PROTOCOL=custom
    local before="${GIT_DIR}|${GIT_WORK_TREE}|${GIT_COMMON_DIR}|${GIT_INDEX_FILE}|${GIT_OBJECT_DIRECTORY}|${GIT_ALTERNATE_OBJECT_DIRECTORIES}|${GIT_NAMESPACE}"
    _file_search_default_provider "$HOME/plain"
    [[ $REPLY == local ]] || {
      print -u2 -- "Files chose Git for a non-repository folder because of inherited selectors"
      exit 6
    }
    for root in "${HOME:A}/current" "${HOME:A}/linked" "${HOME:A}/container/module"; do
      _file_search_default_provider "$root"
      [[ $REPLY == git ]] || {
        print -u2 -- "Files missed the displayed Git folder because of inherited selectors"
        exit 7
      }
      _file_search_capture_git "$root" current || exit 8
      [[ ${(j:|:)_FILE_SEARCH_VALUES} == "$root/current.txt" ]] || exit 9
    done
    [[ "${GIT_DIR}|${GIT_WORK_TREE}|${GIT_COMMON_DIR}|${GIT_INDEX_FILE}|${GIT_OBJECT_DIRECTORY}|${GIT_ALTERNATE_OBJECT_DIRECTORIES}|${GIT_NAMESPACE}" == "$before" &&
       $GIT_OPTIONAL_LOCKS == 1 && $GIT_NO_LAZY_FETCH == 0 &&
       $GIT_TERMINAL_PROMPT == 1 && $GIT_ALLOW_PROTOCOL == custom ]] || exit 10
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'Files Git detection and capture follow the displayed folder including worktrees and submodules' \
  _test_files_git_explicit_folder_scope

_test_files_fuzzy_character_contract() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    setopt EXTENDED_GLOB
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/support/.zsh.matching"
    local query="" candidate="" expected="" actual=""
    local -a cases=(
      "alpha project" "project/alpha" 3
      "nw clt" "Network/Client.swift" 4
      "*[?" "a*xxb[yyc?z" 4
      "]^-" "a]xxb^yyc-z" 4
      "\\~!" "a\\xxb~yyc!z" 4
      "(" "\\(" 2
      "*?" "\\*xx\\?" 4
      "[]" "\\[xx\\]" 4
      "^-" "\\^xx\\-" 4
      "Äω" "ä---Ω" 4
      "ωÄ" "ä---Ω" 0
      "xxxz" "x-x-x-z" 4
      "xxxxz" "x-x-x-z" 0
      "xxz" "z-x-x" 0
    )
    for query candidate expected in "${cases[@]}"; do
      _file_search_compile_query "$query"
      _file_search_match_rank "$candidate"
      actual=$REPLY
      [[ $actual == "$expected" ]] || {
        print -u2 -r -- "query ${(qqq)query}: expected rank $expected, got $actual"
        exit 1
      }
      # The discovery prefilter must agree with the ranker on eligibility.
      if [[ $candidate == ${~_FILE_SEARCH_FILTER_PATTERN} ]]; then
        (( expected )) || exit 2
      else
        (( !expected )) || exit 3
      fi
    done
    _FILE_SEARCH_VALUES=(fuzzy substring prefix fragment)
    _FILE_SEARCH_LABELS=("· p-r-o-j-e-c-t" "· notes/project.md" "· project.swift" "· alpha/project")
    _FILE_SEARCH_MATCH_TEXTS=(p-r-o-j-e-c-t notes/project.md project.swift alpha/project)
    _file_search_picker_collect project 10
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == substring\|prefix\|fragment\|fuzzy ]] || exit 4
    _file_search_picker_collect "alpha project" 10
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == fragment ]] || exit 5
    _FILE_SEARCH_VALUES=(long repeated)
    _FILE_SEARCH_LABELS=("feature/${(l:40::x:)}" "x-x-x-x-x-x-z")
    _FILE_SEARCH_MATCH_TEXTS=("${_FILE_SEARCH_LABELS[@]}")
    _file_search_picker_collect xxxxxxz 10
    [[ ${(j:|:)_ZLE_PICKER_RESULTS} == repeated ]] || exit 6
    print matched
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal matched "$output"
}
test_case 'Files fuzzy matching preserves literal punctuation Unicode repeated characters and ranking' \
  _test_files_fuzzy_character_contract
