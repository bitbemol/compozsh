# Worktree actions use disposable repositories and never the operator's state.
_test_worktree_fixture() {
  source "$1/.zsh.addons/.zsh.editor"
  source "$1/.zsh.addons/.zsh.navigation"
  [[ -f "$1/.zsh.addons/.zsh.git-worktree" ]] || {
    print -u2 'missing worktree workspace capability'
    return 1
  }
  source "$1/.zsh.addons/.zsh.git-worktree"
  export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  command git init -q -b main "$HOME/repo" || return
  builtin cd -- "$HOME/repo" || return
  command git config user.name Fixture
  command git config user.email fixture@example.invalid
  command git config commit.gpgsign false
  print -r -- '*.private' > .gitignore
  print -r -- initial > file
  command git add . && command git commit -qm initial || return
  command git branch feature/available
  command git worktree add -q -b feature/occupied "$HOME/occupied" || return
  _git_worktree_context "$PWD" && _git_worktree_snapshot && _git_worktree_branches
}

_test_worktree_routes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    _git_worktree_session() { print workspace; }
    g -w
    g --worktree
    g --help | /usr/bin/grep -F -- "g -w"
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" $'workspace\nworkspace' || return
  test_assert_contains "$output" 'g -w'
}
test_case 'worktree aliases route to the same workspace and appear in g help' _test_worktree_routes

_test_worktree_capture_create() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    [[ ${#_GWT_PATHS} == 2 && $_GWT_BRANCHES[1] == main &&
       ${_GWT_REFS[(Ie)feature/available]} -gt 0 ]] || exit 2
    local oid=$_GWT_HEAD destination="$HOME/new [literal] tree"
    _git_worktree_plan new "feature/new" "$oid" "$destination" || exit 3
    [[ ! -e $destination ]] || exit 4
    _GWT_ENTER=0
    _git_worktree_apply || exit 5
    [[ $PWD == $_GWT_ROOT && -f "$destination/file" ]] || exit 6
    [[ $(git -C "$destination" symbolic-ref --short HEAD) == feature/new ]] || exit 7
    [[ $(git -C "$destination" rev-parse HEAD) == $oid ]] || exit 8
    _git_worktree_snapshot || exit 9
    _git_worktree_plan existing feature/occupied "$oid" "$HOME/collision" && exit 10
    [[ ! -e "$HOME/collision" ]] || exit 11
    print created
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" created
}
test_case 'worktree captures complete local catalogs and creates exact literal destinations' _test_worktree_capture_create

_test_worktree_creation_refusals() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local oid=$_GWT_HEAD
    mkdir "$HOME/existing"
    ln -s "$HOME/existing" "$HOME/link"
    for target in "$HOME/existing" "$HOME/link" "$PWD/nested"; do
      _git_worktree_plan new feature/new "$oid" "$target" && exit 2
    done
    _git_worktree_plan new "../bad" "$oid" "$HOME/new" && exit 3
    _git_worktree_plan new main "$oid" "$HOME/new" && exit 4
    git config filter.hostile.smudge "touch $HOME/filter-ran"
    _git_worktree_plan new feature/new "$oid" "$HOME/new" && exit 5
    [[ ! -e "$HOME/filter-ran" && ! -e "$HOME/new" ]] || exit 6
    git config --remove-section filter.hostile
    _git_worktree_plan new feature/new "$oid" "$HOME/new" || exit 7
    mkdir "$HOME/new"
    print keep > "$HOME/new/keep"
    _git_worktree_apply && exit 8
    [[ $(<"$HOME/new/keep") == keep ]] || exit 9
    print refused
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" refused
}
test_case 'worktree creation refuses collisions nesting filters invalid names and stale destinations' _test_worktree_creation_refusals

_test_worktree_remove_safety() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    _git_worktree_remove_check "$PWD" && exit 2
    print secret > "$HOME/occupied/data.private"
    _git_worktree_remove_check "$HOME/occupied" && exit 3
    rm "$HOME/occupied/data.private"
    print keep > "$HOME/occupied/untracked"
    _git_worktree_remove_check "$HOME/occupied" && exit 4
    rm "$HOME/occupied/untracked"
    print changed > "$HOME/occupied/file"
    _git_worktree_remove_check "$HOME/occupied" && exit 5
    git -C "$HOME/occupied" restore file
    git -C "$HOME/occupied" update-index --assume-unchanged file
    _git_worktree_remove_check "$HOME/occupied" && exit 6
    git -C "$HOME/occupied" update-index --no-assume-unchanged file
    local metadata=$(git -C "$HOME/occupied" rev-parse --absolute-git-dir)
    mkdir "$metadata/sequencer"
    _git_worktree_remove_check "$HOME/occupied" && exit 12
    rmdir "$metadata/sequencer"
    git worktree lock "$HOME/occupied"
    _git_worktree_remove_check "$HOME/occupied" && exit 7
    git worktree unlock "$HOME/occupied"
    _git_worktree_snapshot
    _git_worktree_remove_check "$HOME/occupied" || exit 8
    _GWT_ACTION=remove _GWT_TARGET="$HOME/occupied"
    _GWT_BRANCH=feature/occupied _GWT_OID=$_GWT_HEAD
    _git_worktree_apply || exit 9
    [[ ! -e "$HOME/occupied" ]] || exit 10
    git show-ref --verify --quiet refs/heads/feature/occupied || exit 11
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" preserved
}
test_case 'worktree removal protects tracked untracked ignored locked main and hidden-index data' _test_worktree_remove_safety

_test_worktree_fallback() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    g --worktree > "$HOME/list"
    [[ $(<"$HOME/list") == *feature/occupied* ]] || exit 2
    [[ -d "$HOME/occupied" && $PWD == "$HOME/repo" ]] || exit 3
    g -w unexpected > "$HOME/out" 2> "$HOME/err"
    [[ $? == 2 && $(<"$HOME/err") == "usage: g "* ]] || exit 4
    print fallback
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal fallback "$output"
}
test_case 'worktree noninteractive fallback only lists and malformed owned invocations use status two' _test_worktree_fallback

_test_worktree_controller_contract() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local -i steps=0
    _zle_picker_loop() {
      (( ++steps ))
      [[ ! -e "$HOME/repo-feature-new" ]] || return 71
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      _ZLE_PICKER_ACTION=select
      case $steps in
        (1) [[ $_ZLE_PICKER_COLLECTOR == _navigation_picker_collect ]] || return 72
            _ZLE_PICKER_SELECTED_VALUE=create ;;
        (2) _ZLE_PICKER_SELECTED_VALUE=new ;;
        (3) [[ $_ZLE_PICKER_QUERY_SUBMIT == 1 && $_ZLE_PICKER_DIGIT_SELECT == 0 ]] || return 73
            _ZLE_PICKER_ACTION=query _ZLE_PICKER_SELECTED_VALUE=feature/new ;;
        (4) [[ $_ZLE_PICKER_ACCEPT_LABELS[apply] == "create and enter" &&
               $_ZLE_PICKER_INSPECT_TEXTS[command] == *"worktree add"* ]] || return 74
            _ZLE_PICKER_SELECTED_VALUE=apply ;;
        (*) return 75 ;;
      esac
      return 0
    }
    _git_worktree_controller || { print -u2 "controller:$?:$_GWT_ERROR"; exit 2; }
    [[ $_GWT_ACTION == create && ! -e "$_GWT_TARGET" && $steps == 4 ]] || exit 3
    _git_worktree_apply || exit 4
    [[ $PWD == "$HOME/repo-feature-new" ]] || exit 5
    print controller
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" controller
}
test_case 'worktree shared fuzzy controller composes choices and defers effects until after selection' _test_worktree_controller_contract

_test_worktree_shared_guide() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/.zsh.addons/.zsh.editor"
    _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=worktree
    _ZLE_PICKER_DIRECTORY_ACTIONS=0 _ZLE_PICKER_DOCUMENT=0
    LINES=60 _zle_picker_guide_render 100
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"worktree"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *Spotlight* ]] || exit 1
    _ZLE_PICKER_QUERY_SUBMIT=1
    LINES=60 _zle_picker_guide_render 100
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"literal text"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *"Return starts search"* ]] || exit 2
    print guide
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal guide "$output"
}
test_case 'worktree guide uses shared keys with correct worktree and literal entry semantics' _test_worktree_shared_guide

_test_worktree_native() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    zmodload zsh/zpty
    zmodload zsh/zselect
    zmodload zsh/datetime
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions -c _zle_picker_show _worktree_test_show
    _zle_picker_show() {
      _worktree_test_show
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_GUIDE_ACTIVE|$COLUMNS|$LINES"
    }
    functions -c _git_worktree_git _worktree_test_git
    _git_worktree_git() {
      print -r -- capture >> "$HOME/captures"
      _worktree_test_git "$@"
    }
    functions -c _git_worktree_apply _worktree_test_apply
    _git_worktree_apply() {
      (( ! ${_ZLE_PICKER_SCREEN_ACTIVE:-0} && !_ZLE_PICKER_ACTIVE )) || {
        print -r -u $efd BAD-ACTION
        return 1
      }
      _worktree_test_apply
    }
    _worktree_test_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "READY:$(command tty)"
      g --worktree
      local result=$?
      [[ $result == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 &&
         $PWD == "$HOME/repo" && -d "$HOME/repo-feature-native" ]] || {
        print -r -u $efd -- "BAD-CLEANUP:$result:$PWD"
        return 1
      }
      print -r -u $efd DONE
    }
    _worktree_test_expect() {
      local wanted=$1 chunk=""
      local -F deadline=$(( EPOCHREALTIME + 8.0 ))
      while (( EPOCHREALTIME < deadline )) && zselect -r $efd $pfd -t 50; do
        while zpty -r worktree chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; got $event"
      return 1
    }
    _worktree_test_key() {
      zpty -w -n worktree "$1"
      _worktree_test_expect "$2" || return
      [[ $trace == *"$enter"* && ${trace#*"$enter"} != *"$enter"* && $trace != *"$leave"* ]]
    }
    local trace="" event="" device="" captures="" pfd=0 chunk=""
    zpty -b worktree _worktree_test_driver || exit 2
    pfd=$REPLY
    {
      zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 3
      device=${event#READY:}
      _worktree_test_expect "FRAME|Worktrees||0|120|30" || exit 4
      captures=$(<"$HOME/captures")
      _worktree_test_key ocpd "FRAME|Worktrees|ocpd|0|120|30" || exit 5
      command stty rows 22 cols 70 < "$device"
      _worktree_test_expect "FRAME|Worktrees|ocpd|0|70|22" || exit 6
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 7
      _worktree_test_key $'\''\x0b'\'' "FRAME|Worktrees|ocpd|1|70|22" || exit 8
      _worktree_test_key $'\''\x07'\'' "FRAME|Worktrees|ocpd|0|70|22" || exit 9
      _worktree_test_key $'\''\x18'\'' "FRAME|Worktree options||0|70|22" || exit 10
      _worktree_test_key $'\''\x07'\'' "FRAME|Worktrees|ocpd|0|70|22" || exit 11
      _worktree_test_key $'\''\x15'\'' "FRAME|Worktrees||0|70|22" || exit 12
      _worktree_test_key 0 "FRAME|Create worktree||0|70|22" || exit 13
      _worktree_test_key 0 "FRAME|New worktree branch||0|70|22" || exit 14
      _worktree_test_key feature/native "FRAME|New worktree branch|feature/native|0|70|22" || exit 15
      _worktree_test_key $'\''\r'\'' "FRAME|Create worktree||0|70|22" || exit 16
      # After is the fifth visible action; selecting it returns to the summary.
      _worktree_test_key 4 "FRAME|Create worktree||0|70|22" || exit 17
      _worktree_test_key "create and stay" "FRAME|Create worktree|create and stay|0|70|22" || exit 18
      zpty -w -n worktree $'\''\r'\''
      _worktree_test_expect DONE || exit 19
      while zpty -r worktree chunk; do trace+=$chunk; done
      [[ $trace == *"$leave"* && ${trace#*"$leave"} != *"$leave"* &&
         $trace != *"command not found"* && $trace != *"bad math"* ]] || exit 20
    } always {
      zpty -d worktree 2>/dev/null
      exec {efd}>&-
    }
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'worktree native keyboard journey preserves fuzzy bookmarks resize and post-cleanup creation' _test_worktree_native

_test_worktree_execution_boundary() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    mkdir "$HOME/hooks"
    print -rl -- "#!/bin/zsh" "touch $HOME/hook-ran" > "$HOME/hooks/post-checkout"
    chmod +x "$HOME/hooks/post-checkout"
    git config core.hooksPath "$HOME/hooks"
    local oid=$_GWT_HEAD
    _git_worktree_plan existing feature/available "$oid" "$HOME/existing-branch" || exit 2
    _GWT_ENTER=0
    export GIT_DIR="$HOME/missing" GIT_INDEX_FILE="$HOME/foreign-index"
    _git_worktree_apply || exit 3
    unset GIT_DIR GIT_INDEX_FILE
    [[ ! -e "$HOME/hook-ran" && ! -e "$HOME/foreign-index" ]] || exit 4
    [[ $(git -C "$HOME/existing-branch" symbolic-ref --short HEAD) == feature/available ]] || exit 5
    git branch stale
    _git_worktree_plan existing stale "$oid" "$HOME/stale" || exit 6
    git commit -q --allow-empty -m later
    git branch -f stale HEAD
    _git_worktree_apply && exit 7
    [[ ! -e "$HOME/stale" ]] || exit 8
    _git_worktree_remove_check "$HOME/occupied" || exit 9
    _GWT_ACTION=remove _GWT_TARGET="$HOME/occupied" _GWT_BRANCH=feature/occupied _GWT_OID="$oid"
    print added > "$HOME/occupied/late.private"
    _git_worktree_apply && exit 10
    [[ -f "$HOME/occupied/late.private" ]] || exit 11
    print boundary
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" boundary
}
test_case 'worktree execution suppresses hooks ignores foreign selectors and rechecks stale targets' _test_worktree_execution_boundary

_test_worktree_failed_existence_capture() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    functions -c _git_worktree_capture _worktree_real_capture
    _git_worktree_capture() {
      [[ $2 == show-ref ]] && return 2
      _worktree_real_capture "$@"
    }
    _git_worktree_plan new feature/uncertain "$_GWT_HEAD" "$HOME/uncertain" && exit 2
    print refused
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refused "$output"
}
test_case 'worktree failed branch-existence capture cannot authorize a creation plan' _test_worktree_failed_existence_capture

_test_worktree_notice_abort() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local -A _GWT_DETAILS=() _GWT_LABELS=()
    _git_worktree_branches() { _GWT_ERROR="failed capture"; return 2; }
    _zle_picker_loop() { return 130; }
    _git_worktree_create_choose
    [[ $? == 130 ]] || exit 2
    print aborted
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal aborted "$output"
}
test_case 'worktree abort from a failed-capture notice exits the entire workspace' _test_worktree_notice_abort

_test_worktree_bounds_and_submodules() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local prior="${(j:|:)_GWT_PATHS}"
    functions -c _git_worktree_git _worktree_real_git
    _git_worktree_git() { print -rn -- ${(pl:262146::x:)}; }
    _git_worktree_snapshot && exit 2
    [[ ${(j:|:)_GWT_PATHS} == "$prior" ]] || exit 3
    functions[_git_worktree_git]=$functions[_worktree_real_git]
    git update-index --add --cacheinfo "160000,$_GWT_HEAD,nested"
    git commit -qm gitlink
    local oid=$(git rev-parse HEAD)
    _git_worktree_plan new feature/submodule "$oid" "$HOME/submodule" && exit 4
    [[ ! -e "$HOME/submodule" && $_GWT_ERROR == *submodules* ]] || exit 5
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'worktree oversized captures retain the previous catalog and submodule creation is refused' _test_worktree_bounds_and_submodules

_test_worktree_parent_bookmark() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    mkdir -p "$HOME/parents/b" "$HOME/parents/c"
    local -A _GWT_DETAILS=() _GWT_LABELS=()
    local -i steps=0
    _zle_picker_loop() {
      (( ++steps ))
      _ZLE_PICKER_BOOKMARK=("" 2 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      case $steps in
        (1) _ZLE_PICKER_ACTION=descend _ZLE_PICKER_SELECTED_VALUE="$HOME/parents/b" ;;
        (2) mkdir "$HOME/parents/a"
            _ZLE_PICKER_ACTION=parent _ZLE_PICKER_SELECTED_VALUE=use ;;
        (3) [[ $3 == 3 ]] || { print -u2 "Back selected an added sibling instead of b"; return 72; }
            _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=use ;;
      esac
      return 0
    }
    _git_worktree_folder "$HOME/parents" || exit 2
    [[ $REPLY == "$HOME/parents" ]] || exit 3
    print bookmark
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bookmark "$output"
}
test_case 'worktree parent Back retains the exact folder when siblings change' _test_worktree_parent_bookmark

_test_worktree_conditional_filters() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    print -r -- "file filter=conditional" > .gitattributes
    git add .gitattributes && git commit -qm attributes
    local oid=$(git rev-parse HEAD)
    git config --file "$HOME/conditional-config" filter.conditional.smudge "touch $HOME/filter-ran; cat"
    git config includeIf.onbranch:feature/conditional.path "$HOME/conditional-config"
    _git_worktree_plan new feature/conditional "$oid" "$HOME/conditional" || exit 2
    _GWT_ENTER=0
    _git_worktree_apply
    local result=$?
    [[ ! -e "$HOME/filter-ran" && $result != 0 ]] || {
      print -u2 "destination-only checkout filter ran or creation incorrectly succeeded"
      exit 3
    }
    print conditional
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" conditional
}
test_case 'worktree creation never executes a filter enabled only by the new branch' _test_worktree_conditional_filters

_test_worktree_materialization_collision() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    _git_worktree_plan new feature/race "$_GWT_HEAD" "$HOME/race" || exit 2
    functions -c _git_worktree_git _worktree_materialize_git
    _git_worktree_git() {
      [[ $2 == read-tree ]] && print -r -- preserve > "$1/file"
      _worktree_materialize_git "$@"
    }
    _git_worktree_apply && exit 3
    [[ $(<"$HOME/race/file") == preserve ]] || exit 4
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" preserved
}
test_case 'worktree initial checkout preserves a colliding file created after validation' _test_worktree_materialization_collision
