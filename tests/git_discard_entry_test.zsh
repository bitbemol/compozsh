_test_git_discard_entry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    git-discard-all() { return 99; }
    _compozsh_help_git-discard-all() { return 99; }
    alias git-discard-all=obsolete
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.help"
    [[ ${+aliases[git-discard-all]} == 0 &&
       ${+functions[git-discard-all]} == 0 &&
       ${+functions[_compozsh_help_git-discard-all]} == 0 ]] || exit 1
    local -x GIT_DIR=/unrelated GIT_WORK_TREE=/unrelated-tree
    _tools_git_discard_all() {
      [[ -z ${GIT_DIR-} && -z ${GIT_WORK_TREE-} ]] || return 91
      print -r -- dispatched; return 17
    }
    g --discard-all
    [[ $? == 17 && $GIT_DIR == /unrelated && $GIT_WORK_TREE == /unrelated-tree ]] || exit 2
    _compozsh_tool_capture
    [[ ${_COMPOZSH_TOOL_NAMES[(Ie)git-discard-all]} == 0 &&
       ${_COMPOZSH_TOOL_NAMES[(Ie)g]} != 0 ]] || exit 3
    g --discard-all --yes > "$HOME/out" 2> "$HOME/error"
    [[ $? == 2 && ! -s "$HOME/out" && $(<"$HOME/error") == "usage: g [git-arguments ...]" ]] || exit 4
    unfunction _tools_git_discard_all
    g --discard-all > "$HOME/out" 2> "$HOME/error"
    [[ $? == 1 && $(<"$HOME/error") == *"enable .zsh.tools"* ]] || exit 5
    g --discard-all --help > "$HOME/out" 2> "$HOME/error"
    [[ $? == 0 && ! -s "$HOME/error" && $(<"$HOME/out") == *"Discard all changes:"* ]] || exit 6
    print entry
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'dispatched\nentry' "$output"
}
test_case 'Git discard entry composes under g without duplicate catalog commands or forced confirmation' _test_git_discard_entry

_test_git_discard_prompt() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_interaction_model "g --discard-all"
    [[ $_PROMPT_INTERACTION_KIND == caution ]] || exit 1
    _prompt_interaction_model "g --discard-all --help"
    [[ $_PROMPT_INTERACTION_KIND == git && ${(j:|:)_PROMPT_INTERACTION_VALUES} == *help* ]] || exit 2
    _prompt_interaction_model "git-discard-all"
    [[ $_PROMPT_INTERACTION_KIND == run ]] || exit 3
    print canonical
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal canonical "$output"
}
test_case 'Git discard entry receives the caution lens while help and retired names stay distinct' _test_git_discard_prompt
