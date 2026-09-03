# Ref names are captured data, including names created through Git plumbing.
_test_navigation_literal_option_branch() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    local repo="$HOME/repository" original="" selected="" frame=""
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" config user.name Fixture
    command git -C "$repo" config user.email fixture@example.invalid
    command git -C "$repo" config commit.gpgsign false
    command git -C "$repo" commit --allow-empty -qm first || exit 2
    original=$(command git -C "$repo" rev-parse HEAD)
    command git -C "$repo" commit --allow-empty -qm second || exit 3
    selected=$(command git -C "$repo" rev-parse HEAD)
    command git -C "$repo" update-ref refs/heads/--detach "$selected" || exit 4
    command git -C "$repo" update-ref -m "checkout: moving from --detach to main" HEAD "$original" || exit 5
    builtin cd "$repo" || exit 6
    _git_branch_choose() {
      (( ${_GIT_RECENT_BRANCHES[(Ie)--detach]} )) || return 40
      _ZLE_PICKER_SELECTED_VALUE=--detach _ZLE_PICKER_ACTION=select
      return 0
    }
    _literal_branch_driver() {
      g
      print -r -- "RESULT:$?:LITERAL-BRANCH-DONE"
    }
    zmodload zsh/zpty
    zpty literal-branch _literal_branch_driver || exit 7
    {
      zpty -r literal-branch frame "*LITERAL-BRANCH-DONE*" || exit 8
      [[ $frame == *"RESULT:0:LITERAL-BRANCH-DONE"* ]] || exit 9
    } always { zpty -d literal-branch; }
    [[ $(command git symbolic-ref --quiet HEAD) == refs/heads/--detach &&
       $(command git rev-parse HEAD) == "$selected" &&
       $(command git rev-parse refs/heads/main) == "$original" ]] || {
      print -u2 -- "g interpreted a selected branch name as a switch option"
      exit 10
    }
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'bare g switches to option-shaped branch names as exact literal targets' \
  _test_navigation_literal_option_branch
