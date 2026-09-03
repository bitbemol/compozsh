# Worktree actions use disposable repositories and never the operator's state.
_test_worktree_fixture() {
  source "$1/.zsh.addons/.zsh.editor"
  source "$1/.zsh.addons/support/.zsh.ui"
  source "$1/.zsh.addons/support/.zsh.matching"
  source "$1/.zsh.addons/support/.zsh.appearance"
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
    source "$1/.zsh.addons/support/.zsh.matching"
    _git_worktree_session() { print workspace; }
    [[ $(g --worktree) == workspace ]] || exit 1
    command git -w > "$HOME/native-out" 2> "$HOME/native-err"
    local native_status=$?
    g -w > "$HOME/wrapper-out" 2> "$HOME/wrapper-err"
    local wrapper_status=$?
    [[ $wrapper_status == $native_status &&
       $(<"$HOME/wrapper-out") == $(<"$HOME/native-out") &&
       $(<"$HOME/wrapper-err") == $(<"$HOME/native-err") ]] || exit 2
    local help=$(g --help)
    [[ $help == *"g --worktree"* && $help != *"g -w"* &&
       $help != *"-w/--worktree"* && $help != *"with -w "* ]] || exit 3
    print routed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal routed "$output"
}
test_case 'worktree entry uses only --worktree and preserves native Git options' _test_worktree_routes

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
    g --worktree unexpected > "$HOME/out" 2> "$HOME/err"
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

_test_worktree_remove_menu() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    # Captured metadata excludes ineligible targets without reading their files.
    _GWT_PATHS+=("$HOME/locked" "$HOME/missing" "$HOME/detached")
    _GWT_BRANCHES+=(locked missing "")
    _GWT_OIDS+=("$_GWT_HEAD" "$_GWT_HEAD" "$_GWT_HEAD")
    _GWT_STATES+=("locked " "missing " "detached ")
    local -i steps=0
    _zle_picker_loop() {
      (( ++steps ))
      [[ -d "$HOME/occupied" ]] || return 70
      _ZLE_PICKER_BOOKMARK=("ocpd" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      _ZLE_PICKER_ACTION=select
      case $steps in
        (1) [[ ${(j:,:)_NAVIGATION_PICKER_VALUES} == create,enter,move,remove,refresh &&
               $_NAVIGATION_PICKER_LABELS[4] == "Remove worktree…" &&
               $_ZLE_PICKER_WORKSPACE_ACTIONS == 0 ]] || return 71
            _ZLE_PICKER_BOOKMARK=("remove" 1 0)
            _ZLE_PICKER_SELECTED_VALUE=remove ;;
        (2|4|6)
            [[ $_ZLE_PICKER_TITLE == "Choose worktree to remove" &&
               $_ZLE_PICKER_COLLECTOR == _navigation_picker_collect &&
               ${#_NAVIGATION_PICKER_VALUES} == 1 &&
               $_NAVIGATION_PICKER_VALUES[1] == "$HOME/occupied" &&
               $_ZLE_PICKER_ACCEPT_LABELS[$HOME/occupied] == "check removal" ]] || return 72
            if (( steps == 4 )); then
              [[ $1 == ocpd ]] || return 73
              return 1
            fi
            _ZLE_PICKER_SELECTED_VALUE="$HOME/occupied" ;;
        (3|7)
            [[ $_ZLE_PICKER_TITLE == "Remove worktree" &&
               $_ZLE_PICKER_INSPECT_TEXTS[remove] == *"$HOME/occupied"* &&
               $_ZLE_PICKER_INSPECT_TEXTS[remove] == *"Keep branch: feature/occupied"* ]] || return 74
            (( steps == 3 )) && return 1
            _ZLE_PICKER_SELECTED_VALUE=remove ;;
        (5) [[ $_ZLE_PICKER_TITLE == Worktrees && $1 == remove ]] || return 75
            _ZLE_PICKER_SELECTED_VALUE=remove ;;
        (*) return 77 ;;
      esac
      return 0
    }
    _git_worktree_controller || { print -u2 "remove-menu:$?:$_GWT_ERROR"; exit 2; }
    [[ $_GWT_ACTION == remove && $_GWT_TARGET == "$HOME/occupied" &&
       -d "$HOME/occupied" && $steps == 7 ]] || exit 3
    _git_worktree_apply || exit 4
    [[ ! -e "$HOME/occupied" ]] || exit 5
    git show-ref --verify --quiet refs/heads/feature/occupied || exit 6
    print removal-menu
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" removal-menu
}
test_case 'worktree main removal menu retains targets and Back context before deferred deletion' _test_worktree_remove_menu

_test_worktree_remove_menu_empty() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    builtin cd "$HOME/occupied"
    local -A _GWT_DETAILS=() _GWT_LABELS=()
    _zle_picker_loop() {
      [[ ${#_NAVIGATION_PICKER_VALUES} == 1 &&
         $_NAVIGATION_PICKER_VALUES[1] == back &&
         $_ZLE_PICKER_INSPECT_TEXTS[back] == *"No eligible worktrees"* ]] || return 72
      return 130
    }
    _git_worktree_target_pick remove
    [[ $? == 130 && -d "$HOME/occupied" ]] || exit 2
    print empty
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal empty "$output"
}
test_case 'worktree main removal menu explains an empty eligible catalog and propagates abort' _test_worktree_remove_menu_empty

_test_worktree_move() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local target="$HOME/occupied" destination="$HOME/renamed [literal]"
    print changed >> "$target/file"
    print keep > "$target/untracked"
    print private > "$target/ignored.private"
    mkdir "$HOME/hooks"
    print -rl -- "#!/bin/zsh" "touch $HOME/hook-ran" > "$HOME/hooks/post-checkout"
    chmod +x "$HOME/hooks/post-checkout"
    git config core.hooksPath "$HOME/hooks"
    git config filter.hostile.smudge "touch $HOME/filter-ran; cat"
    _git_worktree_move_plan "$target" "$destination" || exit 2
    [[ -d $target && ! -e $destination && $_GWT_ACTION == move ]] || exit 3
    _git_worktree_apply || exit 4
    [[ ! -e $target && $(<"$destination/file") == *changed &&
       $(<"$destination/untracked") == keep && $(<"$destination/ignored.private") == private &&
       $(git -C "$destination" symbolic-ref --short HEAD) == feature/occupied &&
       $PWD == "$HOME/repo" && ! -e "$HOME/hook-ran" && ! -e "$HOME/filter-ran" ]] || exit 5
    print moved
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" moved
}
test_case 'worktree move preserves branch edits untracked ignored files and exact destination' _test_worktree_move

_test_worktree_move_refusals() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local target="$HOME/occupied" destination="$HOME/moved"
    _git_worktree_move_plan "$PWD" "$destination" && exit 2
    git worktree lock "$target"
    _git_worktree_move_plan "$target" "$destination" && exit 3
    git worktree unlock "$target"
    local metadata=$(git -C "$target" rev-parse --absolute-git-dir)
    mkdir "$metadata/sequencer"
    _git_worktree_move_plan "$target" "$destination" && exit 4
    rmdir "$metadata/sequencer"
    _git_worktree_move_plan "$target" "$PWD/nested" && exit 5
    _git_worktree_move_plan "$target" "$destination" || exit 6
    mkdir "$destination"
    _git_worktree_apply && exit 7
    [[ -d $target && ! -e "$destination/occupied" ]] || exit 8
    rmdir "$destination"
    _git_worktree_move_plan "$target" "$destination" || exit 9
    git -C "$target" commit -q --allow-empty -m later
    _git_worktree_apply && exit 10
    [[ -d $target && ! -e $destination ]] || exit 11
    mkdir "$HOME/parent"
    _git_worktree_move_plan "$target" "$HOME/parent/moved" || exit 12
    mv "$HOME/parent" "$HOME/old-parent"
    mkdir "$HOME/parent"
    _git_worktree_apply && exit 13
    [[ -d $target && ! -e "$HOME/parent/moved" ]] || exit 14
    print refused
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refused "$output"
}
test_case 'worktree move refuses main locked active nested occupied and stale targets' _test_worktree_move_refusals

_test_worktree_options_bookmark() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local -A _GWT_DETAILS=() _GWT_LABELS=()
    local -i steps=0
    _zle_picker_loop() {
      (( ++steps ))
      case $steps in
        (1) _ZLE_PICKER_SELECTED_VALUE=move
            _ZLE_PICKER_BOOKMARK=("mo" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=1 ;;
        (2) [[ $_ZLE_PICKER_TITLE == "Move / rename worktree" ]] || return 71
            return 1 ;;
        (3) [[ $_ZLE_PICKER_TITLE == "Worktree options" && $1 == mo &&
               $_zle_picker_start_focus == 1 ]] || return 72
            return 130 ;;
        (*) return 73 ;;
      esac
      return 0
    }
    _git_worktree_options "$HOME/occupied" feature/occupied "$_GWT_HEAD"
    [[ $? == 130 && $steps == 3 && -d "$HOME/occupied" ]] || exit 2
    print options
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal options "$output"
}
test_case 'worktree contextual move returns to the same options filter and focus without effects' _test_worktree_options_bookmark

_test_worktree_shared_guide() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=worktree
    _ZLE_PICKER_DIRECTORY_ACTIONS=0 _ZLE_PICKER_DOCUMENT=0
    LINES=60 _zle_picker_guide_render 100
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"worktree"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *Spotlight* ]] || exit 1
    _ZLE_PICKER_WORKSPACE_ACTIONS=0
    LINES=60 _zle_picker_guide_render 100
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Create, Enter, Move / rename, Remove"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *"Options for the selected worktree"* ]] || exit 3
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
  local output='' journey=${1:-create}
  output=$(test_run_interactive "${TEST_TMP_DIR:A}/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    source "$1/tests/git_worktree_test.zsh"
    _test_worktree_fixture "$1" || exit 1
    local journey=$2
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
         ( $journey == enter && $PWD == "$HOME/occupied" ||
           $journey != enter && $PWD == "$HOME/repo" ) ]] || {
        print -r -u $efd -- "BAD-CLEANUP:$result:$PWD"
        return 1
      }
      if [[ $journey == enter ]]; then
        [[ -f "$PWD/file" ]] || { print -r -u $efd BAD-ENTER; return 1; }
      elif [[ $journey == remove ]]; then
        [[ ! -e "$HOME/occupied" ]] && git show-ref --verify --quiet refs/heads/feature/occupied || {
          print -r -u $efd BAD-REMOVAL
          return 1
        }
      elif [[ $journey == move ]]; then
        [[ ! -e "$HOME/occupied" && -f "$HOME/renamed checkout/file" &&
           $(git -C "$HOME/renamed checkout" symbolic-ref --short HEAD) == feature/occupied ]] || {
          print -r -u $efd BAD-MOVE
          return 1
        }
      elif [[ ! -d "$HOME/repo-feature-native" ]]; then
        print -r -u $efd BAD-CREATION
        return 1
      fi
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
      _worktree_test_key 1 "FRAME|Enter worktree||0|120|30" || exit 30
      _worktree_test_key ocpd "FRAME|Enter worktree|ocpd|0|120|30" || exit 5
      command stty rows 22 cols 70 < "$device"
      _worktree_test_expect "FRAME|Enter worktree|ocpd|0|70|22" || exit 6
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 7
      _worktree_test_key $'\''\x0b'\'' "FRAME|Enter worktree|ocpd|1|70|22" || exit 8
      _worktree_test_key $'\''\x07'\'' "FRAME|Enter worktree|ocpd|0|70|22" || exit 9
      _worktree_test_key $'\''\x18'\'' "FRAME|Worktree options||0|70|22" || exit 10
      _worktree_test_key $'\''\x07'\'' "FRAME|Enter worktree|ocpd|0|70|22" || exit 11
      if [[ $journey != enter ]]; then
        _worktree_test_key $'\''\x07'\'' "FRAME|Worktrees||0|70|22" || exit 12
      fi
      if [[ $journey == enter ]]; then
        zpty -w -n worktree $'\''\r'\''
      elif [[ $journey == remove ]]; then
        _worktree_test_key delete "FRAME|Worktrees|delete|0|70|22" || exit 21
        _worktree_test_key $'\''\r'\'' "FRAME|Choose worktree to remove||0|70|22" || exit 22
        captures=$(<"$HOME/captures")
        _worktree_test_key ocpd "FRAME|Choose worktree to remove|ocpd|0|70|22" || exit 23
        [[ $(<"$HOME/captures") == "$captures" ]] || exit 24
        _worktree_test_key $'\''\r'\'' "FRAME|Remove worktree||0|70|22" || exit 25
        _worktree_test_key $'\''\x07'\'' "FRAME|Choose worktree to remove|ocpd|0|70|22" || exit 26
        _worktree_test_key $'\''\r'\'' "FRAME|Remove worktree||0|70|22" || exit 27
        [[ -d "$HOME/occupied" ]] || exit 28
        # Confirmation starts in details; focus the list before choosing Remove.
        _worktree_test_key $'\''\x02'\'' "FRAME|Remove worktree||0|70|22" || exit 29
        zpty -w -n worktree 1
      elif [[ $journey == move ]]; then
        _worktree_test_key 2 "FRAME|Choose worktree to move||0|70|22" || exit 31
        _worktree_test_key ocpd "FRAME|Choose worktree to move|ocpd|0|70|22" || exit 32
        _worktree_test_key $'\''\r'\'' "FRAME|Move / rename worktree||0|70|22" || exit 33
        _worktree_test_key 1 "FRAME|Worktree folder name|occupied|0|70|22" || exit 34
        _worktree_test_key $'\''\x15'\'' "FRAME|Worktree folder name||0|70|22" || exit 35
        _worktree_test_key "renamed checkout" "FRAME|Worktree folder name|renamed checkout|0|70|22" || exit 36
        _worktree_test_key $'\''\r'\'' "FRAME|Move / rename worktree||0|70|22" || exit 37
        [[ -d "$HOME/occupied" && ! -e "$HOME/renamed checkout" ]] || exit 38
        zpty -w -n worktree 3
      else
        _worktree_test_key 0 "FRAME|Create worktree||0|70|22" || exit 13
        _worktree_test_key 0 "FRAME|New worktree branch||0|70|22" || exit 14
        _worktree_test_key feature/native "FRAME|New worktree branch|feature/native|0|70|22" || exit 15
        _worktree_test_key $'\''\r'\'' "FRAME|Create worktree||0|70|22" || exit 16
        # After is the fifth visible action; selecting it returns to the summary.
        _worktree_test_key 4 "FRAME|Create worktree||0|70|22" || exit 17
        _worktree_test_key "create and stay" "FRAME|Create worktree|create and stay|0|70|22" || exit 18
        zpty -w -n worktree $'\''\r'\''
      fi
      _worktree_test_expect DONE || exit 19
      while zpty -r worktree chunk; do trace+=$chunk; done
      [[ $trace == *"$leave"* &&
         $trace != *"command not found"* && $trace != *"bad math"* ]] || exit 20
      (( ${#trace} - ${#${trace//"$leave"/}} == ${#leave} )) || exit 20
    } always {
      zpty -d worktree 2>/dev/null
      exec {efd}>&-
    }
    print native
  ' "$TEST_REPO_ROOT" "$journey") || return
  test_assert_equal native "$output"
}
test_case 'worktree native keyboard journey preserves fuzzy bookmarks resize and post-cleanup creation' _test_worktree_native

_test_worktree_native_remove() { _test_worktree_native remove; }
test_case 'worktree native removal journey finds the main action and confirms deletion after cleanup' _test_worktree_native_remove

_test_worktree_native_move() { _test_worktree_native move; }
test_case 'worktree native move journey edits the destination and applies after cleanup' _test_worktree_native_move

_test_worktree_native_enter() { _test_worktree_native enter; }
test_case 'worktree native enter journey resolves a checkout and changes directory after cleanup' _test_worktree_native_enter

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
