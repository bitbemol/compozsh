# Bare g uses its visible folder; transparent Git arguments retain native scope.
_test_navigation_explicit_folder_scope() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.git-review"
    local repository=""
    for repository in current foreign; do
      command git init -qb main "$HOME/$repository" || exit 1
      command git -C "$HOME/$repository" config user.name Fixture
      command git -C "$HOME/$repository" config user.email fixture@example.invalid
      command git -C "$HOME/$repository" -c commit.gpgsign=false commit --allow-empty -qm initial || exit 2
    done
    command git -C "$HOME/current" switch -qc feature || exit 3
    command git -C "$HOME/current" switch -q main || exit 4
    command git -C "$HOME/foreign" switch -qc foreign-only || exit 5
    builtin cd "$HOME/current" || exit 6
    local expected_root=${PWD:A} foreign_root=${HOME:A}/foreign
    export GIT_DIR="$foreign_root/.git" GIT_WORK_TREE="$foreign_root"
    export GIT_COMMON_DIR="$foreign_root/.git" GIT_INDEX_FILE="$foreign_root/.git/index"
    export GIT_OBJECT_DIRECTORY="$foreign_root/.git/objects"
    export GIT_ALTERNATE_OBJECT_DIRECTORIES="$foreign_root/.git/objects" GIT_NAMESPACE=foreign
    local before="${GIT_DIR}|${GIT_WORK_TREE}|${GIT_COMMON_DIR}|${GIT_INDEX_FILE}|${GIT_OBJECT_DIRECTORY}|${GIT_ALTERNATE_OBJECT_DIRECTORIES}|${GIT_NAMESPACE}"
    [[ $(g rev-parse --show-toplevel) == "$foreign_root" ]] || exit 7
    _git_branch_choose() {
      [[ $1 == "$expected_root" && $_GIT_RECENT_CURRENT == main &&
         ${_GIT_RECENT_BRANCHES[(Ie)feature]} -gt 0 &&
         ${_GIT_RECENT_BRANCHES[(Ie)foreign-only]} == 0 ]] || {
        print -u2 -- "bare g captured branches from inherited foreign scope"
        return 30
      }
      (( !${+GIT_DIR} && !${+GIT_WORK_TREE} && !${+GIT_COMMON_DIR} &&
         !${+GIT_INDEX_FILE} && !${+GIT_OBJECT_DIRECTORY} &&
         !${+GIT_ALTERNATE_OBJECT_DIRECTORIES} && !${+GIT_NAMESPACE} )) || return 31
      [[ $(_git_review_git "$1" rev-parse --show-toplevel) == "$expected_root" ]] || return 32
      _ZLE_PICKER_SELECTED_VALUE=feature _ZLE_PICKER_ACTION=select
    }
    _scope_driver() {
      g
      local -i result=$?
      [[ "${GIT_DIR}|${GIT_WORK_TREE}|${GIT_COMMON_DIR}|${GIT_INDEX_FILE}|${GIT_OBJECT_DIRECTORY}|${GIT_ALTERNATE_OBJECT_DIRECTORIES}|${GIT_NAMESPACE}" == "$before" ]] || result=33
      print -r -- "SCOPE-RESULT:$result:SCOPE-DONE"
    }
    zmodload zsh/zpty
    local frame=""
    zpty scope _scope_driver || exit 8
    {
      zpty -r scope frame "*SCOPE-DONE*" || exit 9
      [[ $frame == *"SCOPE-RESULT:0:SCOPE-DONE"* ]] || {
        print -u2 -r -- "$frame"
        exit 10
      }
    } always { zpty -d scope; }
    unset GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
    unset GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE
    [[ $(command git -C "$expected_root" branch --show-current) == feature &&
       $(command git -C "$foreign_root" branch --show-current) == foreign-only ]] || exit 11
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'bare g scopes branch capture review and switching to the folder and preserves Git selectors' \
  _test_navigation_explicit_folder_scope
