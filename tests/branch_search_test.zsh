# Numeric issue IDs must remain literal from the first key through acceptance.
_test_branch_numeric_filter() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.navigation"
    _GIT_RECENT_BRANCHES=(main other bug/1232-something)
    _GIT_RECENT_CURRENT=main
    unfunction _git_branch_inspector_capture
    _git_branch_inspector_capture() { :; }
    local -a keys=(1 2 3 2 $'\''\r'\'')
    read() { (( ${#keys} )) || return 1; key=$keys[1]; keys[1]=(); }
    zle() { :; }
    _zle_picker_show() { :; }
    _zle_picker_run() { _zle_picker_loop "" 10; }
    _ZLE_PICKER_SESSION=1 _ZLE_PICKER_SCREEN_ACTIVE=1
    COLUMNS=80 LINES=24
    _git_branch_choose /fixture/repository "" || exit 1
    [[ $_ZLE_PICKER_SELECTED_VALUE == bug/1232-something &&
       $_ZLE_PICKER_BOOKMARK[1] == 1232 && ${#keys} == 0 ]] || {
      print -u2 -- "Numeric filter accepted $_ZLE_PICKER_SELECTED_VALUE before the full query and Enter"
      exit 2
    }
    print numeric
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal numeric "$output"
}
test_case 'branch search treats an initial numeric issue ID as literal input until Enter' _test_branch_numeric_filter

_test_picker_numeric_filter() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.navigation"
    local -a keys=()
    read() {
      (( ${#keys} )) || return 1
      if [[ $* == *sequence* ]]; then sequence=$keys[1]; else key=$keys[1]; fi
      keys[1]=()
    }
    zle() { :; }
    _zle_picker_show() { :; }
    _numeric_collect() {
      _zle_ui_collect_choices "$@"
      # Model the caller supplying the selected document before reading keys.
      _ZLE_PICKER_DOCUMENT_KEY=${_ZLE_PICKER_RESULTS[1]-}
    }
    _numeric_view() {
      _ZLE_UI_CHOICE_VALUES=(other folder/1232 file1232.txt)
      _ZLE_UI_CHOICE_LABELS=("${_ZLE_UI_CHOICE_VALUES[@]}")
      _ZLE_PICKER_COLLECTOR=_numeric_collect
      _zle_picker_loop "" 10
    }
    _ZLE_PICKER_SESSION=1 _ZLE_PICKER_SCREEN_ACTIVE=1
    COLUMNS=80 LINES=24
    for kind in choice action reference document; do
      keys=(1 2 3 2 $'\''\r'\'')
      _zle_ui_view "$kind" _numeric_view || exit 1
      [[ $_ZLE_PICKER_BOOKMARK[1] == 1232 &&
         $_ZLE_PICKER_SELECTED_VALUE == folder/1232 && ${#keys} == 0 ]] || {
        print -u2 -- "$kind consumed a numeric search as a shortcut"; exit 2
      }
      keys=($'\''\e'\'' 2)
      _zle_ui_view "$kind" _numeric_view || { print -u2 -- "$kind lost Option-digit acceptance"; exit 3; }
      [[ $_ZLE_PICKER_BOOKMARK[1] == "" && $_ZLE_PICKER_SELECTED_VALUE == folder/1232 ]] || exit 4
    done
    print numeric
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal numeric "$output"
}
test_case 'shared numeric search stays literal across picker kinds and Option-digits select explicit slots' _test_picker_numeric_filter

_test_branch_complete_catalog() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect_choices"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_git_local"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
    command git init -qb main "$HOME/repository" || exit 1
    builtin cd "$HOME/repository"
    command git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit --allow-empty -qm initial || exit 2
    oid=$(command git rev-parse HEAD)
    local branch
    for branch in topic-{001..450} bug/1232-something; do
      print -r -- "create refs/heads/$branch $oid"
    done | command git update-ref --stdin || exit 3
    command git update-ref refs/remotes/origin/remote-only "$oid" || exit 4
    # No checkout history: every unvisited local name must still be captured.
    _git_recent_branches "$PWD" || exit 5
    (( ${#_GIT_RECENT_BRANCHES} == 452 )) || exit 6
    [[ $_GIT_RECENT_BRANCHES[1] == main && $_GIT_RECENT_BRANCHES[-1] == topic-450 ]] || exit 7
    _git_branch_inspector_capture "$PWD" || exit 8
    _git_branch_inspect_text topic-450
    [[ $REPLY == *"unavailable"* ]] || exit 9
    _ZLE_UI_CHOICE_VALUES=("${_GIT_RECENT_BRANCHES[@]}")
    _ZLE_UI_CHOICE_LABELS=("${_GIT_RECENT_BRANCHES[@]}")
    _zle_ui_collect_choices 450 10
    [[ $_ZLE_PICKER_RESULTS[1] == topic-450 ]] || exit 10
    _zle_ui_collect_choices 1232 10
    [[ $_ZLE_PICKER_RESULTS[1] == bug/1232-something ]] || exit 11
    _zle_ui_collect_choices remote-only 10
    (( !${#_ZLE_PICKER_RESULTS} )) || exit 12
    print complete
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal complete "$output"
}
test_case 'branch search includes unvisited local names beyond viewport and detail limits without remote refs' _test_branch_complete_catalog

# Above the row bound the catalog keeps Git's first names, current branch
# first, and both the browse and no-match labels say it is partial.
_test_branch_catalog_row_bound() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.navigation"
    command git init -qb main "$HOME/repository" || exit 1
    builtin cd "$HOME/repository"
    command git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit --allow-empty -qm initial || exit 2
    local oid=$(command git rev-parse HEAD) branch=""
    {
      print -r -- "# pack-refs with: peeled fully-peeled sorted"
      for branch in topic-{0001..5001} zz-current; do print -r -- "$oid refs/heads/$branch"; done
      print -r -- "$oid refs/remotes/origin/remote-only"
    } > .git/packed-refs || exit 3
    command git remote add origin https://example.invalid/origin.git || exit 3
    command git switch -q zz-current || exit 4
    _git_recent_branches "$PWD" || exit 5
    (( ${#_GIT_RECENT_BRANCHES} == 5000 && ${_GIT_RECENT_PARTIAL:-0} == 1 )) || {
      print -u2 -- "captured ${#_GIT_RECENT_BRANCHES} names, partial=${_GIT_RECENT_PARTIAL-unset}"
      exit 6
    }
    [[ $_GIT_RECENT_CURRENT == zz-current && $_GIT_RECENT_BRANCHES[1] == zz-current ]] || exit 7
    (( ${_GIT_RECENT_BRANCHES[(Ie)topic-5001]} == 0 )) || exit 8
    # A partial catalog cannot rule out a local branch, so no remote fallback.
    _git_branch_remote_capture "$PWD" && exit 11
    (( !${#_GIT_BRANCH_REMOTE_VALUES} )) && [[ $_GIT_BRANCH_REMOTE_NOTICE == *partial* ]] || exit 12
    _ZLE_UI_CHOICE_VALUES=("${_GIT_RECENT_BRANCHES[@]}")
    _ZLE_UI_CHOICE_LABELS=("${_GIT_RECENT_BRANCHES[@]}")
    _git_branch_collect "" 10
    [[ $_ZLE_PICKER_BROWSE_LABEL == *partial* ]] || exit 9
    _git_branch_collect qqq 10
    [[ $_ZLE_PICKER_EMPTY_LABEL == *captured* ]] || exit 10
    [[ $_ZLE_PICKER_BROWSE_LABEL == *partial* && $_ZLE_PICKER_INSPECT_ACTION == switch ]] || {
      print -u2 -r -- "no-match label: $_ZLE_PICKER_BROWSE_LABEL; action: $_ZLE_PICKER_INSPECT_ACTION"
      exit 14
    }
    [[ $(_git_branch_stack_print) == *$'\''\nPartial: captured branches only'\''* ]] || exit 13
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'Git branch catalog bounds rows, keeps the current branch and labels matching partial' \
  _test_branch_catalog_row_bound

# A byte-bounded read keeps only complete names; a cut name never matches.
_test_branch_catalog_byte_bound() {
  test_make_temp_dir || return
  local output
  test_write_file "$TEST_TMP_DIR/bin/git" $'#!/bin/zsh\n[[ $* == *for-each-ref* ]] || exit 0\nprint -r -- "*"$\'\\t\'"refs/heads/current"\nfor i in {1..3000}; do print -r -- " "$\'\\t\'"refs/heads/${(l:200::x:)}-$i"; done' || return
  command chmod +x "$TEST_TMP_DIR/bin/git" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.navigation"
    path=("$2" "${path[@]}")
    _git_recent_branches /fixture || exit 1
    (( ${_GIT_RECENT_PARTIAL:-0} == 1 && ${#_GIT_RECENT_BRANCHES} > 1000 &&
       ${#_GIT_RECENT_BRANCHES} < 3001 )) || exit 2
    [[ $_GIT_RECENT_CURRENT == current ]] || exit 3
    local name=""
    for name in "${(@)_GIT_RECENT_BRANCHES[2,-1]}"; do
      [[ $name == ${(l:200::x:)}-<1-3000> ]] || { print -u2 -r -- "cut name: ${name[-12,-1]}"; exit 4; }
    done
    print bounded
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin") || return
  test_assert_equal bounded "$output"
}
test_case 'Git branch catalog bounds bytes and keeps only complete names' \
  _test_branch_catalog_byte_bound

# Details keep captured facts; the inspector holds text for one branch at a
# time: the first result after filtering, then the selection while idle.
_test_branch_inspector_selected_only() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.navigation"
    command git init -qb main "$HOME/repository" || exit 1
    builtin cd "$HOME/repository"
    command git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit --allow-empty -qm initial || exit 2
    command git branch topic && command git branch other || exit 3
    _git_recent_branches "$PWD" || exit 4
    _git_branch_inspector_capture "$PWD" || exit 5
    (( ${#_ZLE_PICKER_INSPECT_TEXTS} == 0 )) || {
      print -u2 -- "capture built ${#_ZLE_PICKER_INSPECT_TEXTS} inspector texts"; exit 6
    }
    _ZLE_UI_CHOICE_VALUES=("${_GIT_RECENT_BRANCHES[@]}")
    _ZLE_UI_CHOICE_LABELS=("${_GIT_RECENT_BRANCHES[@]}")
    _git_branch_collect "" 10
    (( ${#_ZLE_PICKER_RESULTS} == 3 && ${#_ZLE_PICKER_INSPECT_TEXTS} == 1 )) || exit 7
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[$_ZLE_PICKER_RESULTS[1]]} == *"Current branch"*"Latest commit:"* ]] || exit 8
    _ZLE_PICKER_SELECTED=2
    _git_branch_inspect_idle; (( $? == 0 )) || exit 9
    (( ${#_ZLE_PICKER_INSPECT_TEXTS} == 1 )) || exit 10
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[$_ZLE_PICKER_RESULTS[2]]} == *"Local branch"*"Latest commit:"* ]] || exit 11
    _git_branch_inspect_idle; (( $? == 2 )) || exit 12
    _git_branch_collect qqq 10
    (( !${#_ZLE_PICKER_RESULTS} && ${#_ZLE_PICKER_INSPECT_TEXTS} == 1 )) || exit 13
    print selected
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal selected "$output"
}
test_case 'Git branch catalog builds inspector text only for the selected branch' \
  _test_branch_inspector_selected_only
