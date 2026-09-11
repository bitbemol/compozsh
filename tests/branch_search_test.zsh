# Numeric issue IDs must remain literal from the first key through acceptance.
_test_branch_numeric_filter() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
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
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
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
      _navigation_picker_collect "$@"
      # Model the caller supplying the selected document before reading keys.
      _ZLE_PICKER_DOCUMENT_KEY=${_ZLE_PICKER_RESULTS[1]-}
    }
    _numeric_view() {
      _NAVIGATION_PICKER_VALUES=(other folder/1232 file1232.txt)
      _NAVIGATION_PICKER_LABELS=("${_NAVIGATION_PICKER_VALUES[@]}")
      _NAVIGATION_PICKER_INDEXES=(1 2 3)
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
    [[ $_ZLE_PICKER_INSPECT_TEXTS[topic-450] == *"unavailable"* ]] || exit 9
    _NAVIGATION_PICKER_VALUES=("${_GIT_RECENT_BRANCHES[@]}")
    _NAVIGATION_PICKER_LABELS=("${_GIT_RECENT_BRANCHES[@]}")
    _NAVIGATION_PICKER_INDEXES=({1..452})
    _navigation_picker_collect 450 10
    [[ $_ZLE_PICKER_RESULTS[1] == topic-450 ]] || exit 10
    _navigation_picker_collect 1232 10
    [[ $_ZLE_PICKER_RESULTS[1] == bug/1232-something ]] || exit 11
    _navigation_picker_collect remote-only 10
    (( !${#_ZLE_PICKER_RESULTS} )) || exit 12
    print complete
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal complete "$output"
}
test_case 'branch search includes unvisited local names beyond viewport and detail limits without remote refs' _test_branch_complete_catalog
