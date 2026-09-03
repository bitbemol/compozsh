# A failed Git transition presents its own notice and preserves the parent view.
_test_git_notice_scoped_content() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    local root=/fixture/repository
    _ZLE_PICKER_TITLE=Branches _ZLE_PICKER_SUBTITLE="repository · local branches"
    _ZLE_PICKER_QUERY_LABEL="Filter branches"
    _ZLE_PICKER_COLLECTOR=_navigation_picker_collect
    _ZLE_PICKER_INSPECT_ACTION=switch
    _NAVIGATION_PICKER_VALUES=(main) _NAVIGATION_PICKER_LABELS=(main)
    _zle_picker_loop() {
      "$_ZLE_PICKER_COLLECTOR" "" 10
      (( !${#_ZLE_PICKER_RESULTS} )) || return 71
      [[ $_ZLE_PICKER_TITLE == "Git review" &&
         $_ZLE_PICKER_QUERY_LABEL == "Filter notice" &&
         $_ZLE_PICKER_SUBTITLE == "repository · read-only" &&
         ${_ZLE_PICKER_EMPTY_LINES[1]} == "Unable to establish safe local Git inspection." ]] || {
        print -u2 -- "Git notice retained parent task labels: $_ZLE_PICKER_QUERY_LABEL; $_ZLE_PICKER_SUBTITLE"
        return 72
      }
      return 130
    }
    _git_review_unavailable
    [[ $? == 130 && $_ZLE_PICKER_TITLE == Branches &&
       $_ZLE_PICKER_QUERY_LABEL == "Filter branches" &&
       $_ZLE_PICKER_SUBTITLE == "repository · local branches" &&
       $_NAVIGATION_PICKER_VALUES[1] == main ]] || exit 1
    print restored
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal restored "$output"
}
test_case 'Git unavailable notice owns its task labels and preserves parent content and abort status' \
  _test_git_notice_scoped_content

_test_git_review_explicit_root_selectors() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    local repo="" selector="" expected="" original=""
    for repo in primary foreign; do
      command git init -qb "$repo" "$HOME/$repo" || exit 1
      command git -C "$HOME/$repo" config user.name Fixture
      command git -C "$HOME/$repo" config user.email fixture@example.invalid
      command git -C "$HOME/$repo" config commit.gpgsign false
      print -r -- "$repo" > "$HOME/$repo/$repo"
      command git -C "$HOME/$repo" add .
      command git -C "$HOME/$repo" commit -qm "$repo" || exit 2
    done
    print -r -- changed >> "$HOME/primary/primary"
    expected=$(command git -C "$HOME/primary" rev-parse HEAD)
    local -a selectors=(GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE
      GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE)
    local -A values=(GIT_DIR "$HOME/foreign/.git" GIT_WORK_TREE "$HOME/foreign"
      GIT_COMMON_DIR "$HOME/foreign/.git" GIT_INDEX_FILE "$HOME/foreign/.git/index"
      GIT_OBJECT_DIRECTORY "$HOME/foreign/.git/objects"
      GIT_ALTERNATE_OBJECT_DIRECTORIES "$HOME/foreign/.git/objects" GIT_NAMESPACE foreign)
    for selector in "${selectors[@]}"; do
      original=$values[$selector]
      export "$selector=$original"
      _git_review_resolve "$HOME/primary" HEAD && [[ $REPLY == "$expected" ]] || {
        print -u2 -- "explicit review root redirected by $selector"; exit 3
      }
      _git_review_prepare "$HOME/primary" && _git_review_changes_capture "$HOME/primary" || exit 4
      [[ ${#_GIT_REVIEW_PATHS} == 1 && $_GIT_REVIEW_PATHS[1] == primary &&
         $_GIT_REVIEW_KINDS[1] == unstaged ]] || {
        print -u2 -- "review snapshot scope redirected by $selector"; exit 5
      }
      [[ ${(P)selector} == "$original" ]] || exit 6
      unset "$selector"
    done
    # The public review entry resolves this folder before the first screen.
    # All foreign selectors coexist, and cancellation restores them unchanged.
    for selector in "${selectors[@]}"; do export "$selector=$values[$selector]"; done
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 7
    exec {event_fd}<> "$HOME/events" || exit 8
    _zle_picker_run() {
      [[ $root == "${HOME:A}/primary" && $_git_compare_branch == primary ]] || return 73
      _git_review_resolve "$root" HEAD && [[ $REPLY == "$expected" ]] || return 74
      return 1
    }
    _git_review_entry_driver() {
      builtin cd "$HOME/primary" || return
      g --review 2> "$HOME/direct-error"
      local -i result=$?
      [[ $result == 0 && ! -s "$HOME/direct-error" ]] || {
        print -r -u $event_fd -- "BAD-ENTRY|$result"; return
      }
      for selector in "${selectors[@]}"; do
        [[ ${(P)selector} == "$values[$selector]" ]] || {
          print -r -u $event_fd -- BAD-ENVIRONMENT; return
        }
      done
      print -r -u $event_fd -- DIRECT-SCOPED
    }
    local event=""
    zpty -b review-entry _git_review_entry_driver || exit 9
    {
      zselect -r $event_fd -t 300 && IFS= read -r -u $event_fd event || exit 10
      [[ $event == DIRECT-SCOPED ]] || { print -u2 -- "$event"; exit 11; }
    } always {
      zpty -d review-entry
      exec {event_fd}>&-
    }
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'Git review captures the explicit root while preserving inherited Git selectors' \
  _test_git_review_explicit_root_selectors

_test_git_notice_native() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    functions -c _zle_picker_show _git_notice_show
    _zle_picker_show() {
      _git_notice_show
      [[ $_ZLE_PICKER_POSTDISPLAY == *"Unable to establish safe local Git inspection."* ||
         $_ZLE_PICKER_GUIDE_ACTIVE == 1 ]] || print -r -u $event_fd -- BAD-CONTENT
      [[ $_ZLE_PICKER_QUERY_ROW == *"Filter notice"* &&
         $_ZLE_PICKER_SUBTITLE_ROW == "repository · read-only" ]] || print -r -u $event_fd -- BAD-SCOPE
      print -r -u $event_fd -- "FRAME|$_ZLE_PICKER_GUIDE_ACTIVE"
    }
    _git_notice_controller() {
      local root=/fixture/repository
      local _ZLE_PICKER_QUERY_LABEL="Filter branches" _ZLE_PICKER_TITLE=Branches
      _git_review_unavailable
      local -i result=$?
      [[ $result == 1 && $_ZLE_PICKER_TITLE == Branches &&
         $_ZLE_PICKER_QUERY_LABEL == "Filter branches" ]] || print -r -u $event_fd -- BAD-RETURN
    }
    _git_notice_driver() {
      command stty rows 24 cols 120
      _zle_picker_run 10 "" 1 0 _git_notice_controller 2> "$HOME/session-error"
      (( !_ZLE_PICKER_ACTIVE && !_ZLE_PICKER_SCREEN_ACTIVE )) || print -r -u $event_fd -- BAD-CLEANUP
      [[ ! -s "$HOME/session-error" ]] || print -r -u $event_fd -- BAD-DIAGNOSTICS
      print -r -u $event_fd -- DONE
    }
    local event="" chunk="" trace="" pty_fd=0
    _git_notice_expect() {
      while zselect -r $event_fd $pty_fd -t 300; do
        while zpty -r notice chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          [[ $event == "$1" ]] && return 0
          print -u2 -- "expected $1; got $event"
          return 1
        fi
      done
      print -u2 -- "native Git notice timed out: $1"
      return 1
    }
    zpty -b notice _git_notice_driver || exit 3
    pty_fd=$REPLY
    {
      _git_notice_expect "FRAME|0" || exit 4
      zpty -w -n notice $'\''\x0b'\''
      _git_notice_expect "FRAME|1" || exit 5
      zpty -w -n notice $'\''\x07'\''
      _git_notice_expect "FRAME|0" || exit 6
      zpty -w -n notice $'\''\x07'\''
      _git_notice_expect DONE || exit 7
    } always {
      zpty -d notice
      exec {event_fd}>&-
    }
    print restored
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal restored "$output"
}
test_case 'Git unavailable notice uses native guide Back and terminal restoration' _test_git_notice_native
