# Remote-tracking choices are local Git facts, never a server query.
_test_branch_remote_fixture() {
  test_make_temp_dir || return
  command git init -qb main "$TEST_TMP_DIR/repository" || return
  command git -C "$TEST_TMP_DIR/repository" -c user.name=Fixture \
    -c user.email=fixture@example.invalid -c commit.gpgsign=false commit --allow-empty -qm initial || return
  local remote
  for remote in origin upstream; do
    command git -C "$TEST_TMP_DIR/repository" remote add "$remote" "https://example.invalid/$remote.git" || return
    command git -C "$TEST_TMP_DIR/repository" update-ref "refs/remotes/$remote/bug/1232-something" HEAD || return
  done
  command git -C "$TEST_TMP_DIR/repository" symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/bug/1232-something
}

_test_branch_remote_capture_and_filter() {
  _test_branch_remote_fixture || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.zle_ui_collect "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded; do source "$unit"; done
    (( ${+functions[_git_branch_remote_capture]} )) || { print -u2 "Remote-tracking branch fallback missing"; exit 1; }
    _git_recent_branches "$2" || exit 2
    _git_branch_remote_capture "$2" || exit 3
    [[ ${#_GIT_BRANCH_REMOTE_VALUES} == 2 && ${_GIT_BRANCH_REMOTE_NAMES[remote:refs/remotes/origin/bug/1232-something]} == bug/1232-something ]] || exit 4
    _NAVIGATION_PICKER_VALUES=("${_GIT_RECENT_BRANCHES[@]}")
    _NAVIGATION_PICKER_LABELS=("${_GIT_RECENT_BRANCHES[@]}")
    _NAVIGATION_PICKER_INDEXES=(0)
    path=()
    _git_branch_collect 1232 10
    [[ ${#_ZLE_PICKER_RESULTS} == 2 && $_ZLE_PICKER_RESULTS[1] == remote:refs/remotes/origin/bug/1232-something &&
       $_ZLE_PICKER_INSPECT_ACTION == "review creation" && $_ZLE_PICKER_BROWSE_LABEL == *"remote-tracking"* ]] || exit 5
    _NAVIGATION_PICKER_VALUES+=(bug/1232-local)
    _NAVIGATION_PICKER_LABELS+=(bug/1232-local)
    _NAVIGATION_PICKER_INDEXES+=(1)
    _git_branch_collect 1232 10
    [[ ${#_ZLE_PICKER_RESULTS} == 1 && $_ZLE_PICKER_RESULTS[1] == bug/1232-local && $_ZLE_PICKER_INSPECT_ACTION == switch ]] || exit 6
    _git_branch_collect "" 10
    [[ ${#_ZLE_PICKER_RESULTS} == 2 && $_ZLE_PICKER_RESULTS[1] == main ]] || exit 7
    print captured
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/repository") || return
  test_assert_equal captured "$output"
}
test_case 'branch remote fallback captures known refs and filters them only without local matches' _test_branch_remote_capture_and_filter

_test_branch_remote_switch() {
  _test_branch_remote_fixture || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
    (( ${+functions[_git_branch_remote_switch]} )) || { print -u2 "Confirmed remote branch switching missing"; exit 1; }
    _git_recent_branches "$2" && _git_branch_remote_capture "$2" || exit 2
    local chosen=remote:refs/remotes/origin/bug/1232-something
    _git_branch_remote_switch "$2" "$chosen" > "$HOME/output" 2> "$HOME/error" || exit 3
    [[ $(command git -C "$2" symbolic-ref --short HEAD) == bug/1232-something &&
       $(command git -C "$2" config branch.bug/1232-something.remote) == origin &&
       $(command git -C "$2" config branch.bug/1232-something.merge) == refs/heads/bug/1232-something ]] || exit 4
    before=$(command git -C "$2" rev-parse HEAD)
    _git_branch_remote_switch "$2" "$chosen" > /dev/null 2>&1 && exit 5
    [[ $(command git -C "$2" rev-parse HEAD) == "$before" ]] || exit 6
    print switched
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/repository") || return
  test_assert_equal switched "$output"
}
test_case 'branch remote acceptance creates and switches with the exact selected upstream and never resets a local branch' _test_branch_remote_switch

_test_branch_remote_native() {
  _test_branch_remote_fixture || return
  local output review=${1:-review}
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.editor"
    [[ $3 == review ]] && source "$1/.zsh.addons/.zsh.git-review"
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
    builtin cd "$2"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events"
    exec {event_fd}<> "$HOME/events"
    functions[_remote_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _remote_original_show
      if [[ -z $_ZLE_PICKER_QUERY ]] && (( !_ZLE_PICKER_INSPECT_FOCUS && _ZLE_PICKER_INDEXES_VISIBLE )); then
        [[ $_ZLE_PICKER_DISPLAY[-1] == *"Option-0–9"* ]] || footer_missing=1
      fi
      print -r -u $event_fd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_INSPECT_ACTION|${#_ZLE_PICKER_RESULTS}"
    }
    _remote_driver() {
      COLUMNS=100 LINES=24
      local -i footer_missing=0
      g
      local result=$?
      [[ $(command git symbolic-ref --short HEAD) == bug/1232-something ]] || result=71
      [[ $(command git config branch.bug/1232-something.remote) == upstream ]] || result=72
      (( !${_ZLE_PICKER_SCREEN_ACTIVE:-0} )) || result=73
      (( !${#_GIT_BRANCH_REMOTE_VALUES} && !${#_GIT_BRANCH_REMOTE_NAMES} )) || result=74
      (( !footer_missing )) || result=75
      print -r -u $event_fd -- "DONE|$result"
    }
    _remote_expect() {
      local event="" trace="" chunk=""
      local -i attempt=0
      for (( attempt=0; attempt<200; ++attempt )); do
        while zpty -r remote-ui chunk; do :; done
        if IFS= read -r -t 0 -u $event_fd event; then
          trace+="$event"$'\''\n'\''
          [[ $event == "$1" ]] && return 0
        else
          zselect -t 1
        fi
      done
      print -u2 -r -- "Expected $1; received $trace"
      return 1
    }
    zpty -b remote-ui _remote_driver || exit 1
    {
      _remote_expect "FRAME|Branches||switch|1" || exit 2
      zpty -w -n remote-ui 1232
      _remote_expect "FRAME|Branches|1232|review creation|2" || exit 3
      zpty -w -n remote-ui $'\''\r'\''
      _remote_expect "FRAME|Create local branch||choose|2" || exit 4
      [[ $(command git symbolic-ref --short HEAD) == main ]] || exit 5
      zpty -w -n remote-ui $'\''\r'\''
      _remote_expect "FRAME|Branches|1232|review creation|2" || exit 6
      zpty -w -n remote-ui $'\''\e[B\r'\''
      _remote_expect "FRAME|Create local branch||choose|2" || exit 7
      [[ $(command git symbolic-ref --short HEAD) == main ]] || exit 8
      zpty -w -n remote-ui $'\''\e[B\r'\''
      _remote_expect "DONE|0" || exit 9
    } always {
      zpty -d remote-ui
      exec {event_fd}>&-
    }
    print native
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/repository" "$review") || return
  test_assert_equal native "$output"
}
test_case 'branch remote native search confirms exact upstream defaults to Back and applies only after cleanup' _test_branch_remote_native

_test_branch_remote_native_without_review() { _test_branch_remote_native no-review; }
test_case 'branch remote native confirmation works without the Git review peer' _test_branch_remote_native_without_review

_test_branch_remote_stale_and_conflicting() {
  _test_branch_remote_fixture || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
    cd "$2"
    command git switch -qc fixture-tip
    print -r -- remote > conflict
    command git add conflict
    command git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm remote-tip
    target=$(command git rev-parse HEAD)
    command git switch -q main
    _git_recent_branches "$2" && _git_branch_remote_capture "$2" || exit 1
    local chosen=remote:refs/remotes/origin/bug/1232-something
    command git update-ref refs/remotes/origin/bug/1232-something "$target"
    _git_branch_remote_switch "$2" "$chosen" > /dev/null 2>&1 && exit 2
    [[ $(command git symbolic-ref --short HEAD) == main ]] || exit 3
    _git_branch_remote_capture "$2" || exit 4
    print -r -- keep-local > conflict
    _git_branch_remote_switch "$2" "$chosen" > /dev/null 2>&1 && exit 5
    [[ $(<conflict) == keep-local && $(command git symbolic-ref --short HEAD) == main ]] || exit 6
    command git show-ref --verify --quiet refs/heads/bug/1232-something && exit 7
    command git update-ref -d refs/remotes/origin/bug/1232-something
    _git_branch_remote_switch "$2" "$chosen" > /dev/null 2>&1 && exit 8
    [[ $(<conflict) == keep-local ]] || exit 9
    print preserved
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/repository") || return
  test_assert_equal preserved "$output"
}
test_case 'branch remote creation refuses changed or deleted tips and preserves conflicting local files' _test_branch_remote_stale_and_conflicting
