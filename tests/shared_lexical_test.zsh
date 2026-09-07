_test_shared_assignment_capture_isolation() {
  test_make_temp_dir || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_{is_*,git_valid_oid}(N.); do source "$unit"; done
    local MATCH=sentinel MBEGIN=31 MEND=32
    local -a match=(kept) mbegin=(33) mend=(34)
    _compozsh_is_assignment "items[2]+=value" || exit 1
    [[ $MATCH == sentinel && $MBEGIN == 31 && $MEND == 32 &&
       $match == kept && $mbegin == 33 && $mend == 34 ]] || exit 2
  ' "$TEST_REPO_ROOT"
}
test_case 'shared assignment detection leaves caller regex captures untouched' \
  _test_shared_assignment_capture_isolation

_test_shared_lexical_existing_policies() {
  test_make_temp_dir || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_{is_*,git_valid_oid}(N.); do source "$unit"; done
    source "$1/.zsh.addons/.zsh.git-review"
    local token
    for token in NAME=value "items[2]+=value" "A="; do _compozsh_is_assignment "$token" || exit 1; done
    for token in "--name=value" "=value" "9name=value"; do _compozsh_is_assignment "$token" && exit 2; done
    for token in ">>" "2>&" "<<<" "&>>!"; do _compozsh_is_redirection "$token" || exit 3; done
    for token in word "2>file" "&&"; do _compozsh_is_redirection "$token" && exit 4; done
    _compozsh_git_valid_oid "${(l:40::a:)}" || exit 5
    _compozsh_git_valid_oid "${(l:64::F:)}" || exit 6
    for token in "" "${(l:39::a:)}" "${(l:64::g:)}"; do _compozsh_git_valid_oid "$token" && exit 7; done
    return 0
  ' "$TEST_REPO_ROOT"
}
test_case 'shared lexical predicates preserve assignment redirection and full Git object policies' \
  _test_shared_lexical_existing_policies

_test_shared_oid_root_commit() {
  test_make_temp_dir || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"; do source "$unit"; done
    command git init -q "$HOME/repo" || exit 1
    builtin cd "$HOME/repo"
    print -r -- "literal root commit content" > root.txt
    command git add root.txt || exit 2
    command git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm root || exit 3
    local oid=$(command git rev-parse HEAD)
    _git_review_prepare "$PWD" || exit 4
    local -i list_status=0 read_status=0
    _git_review_commit_files_capture "$PWD" "$oid" ""; list_status=$?
    _git_review_diff_capture "$PWD" commit root.txt "$oid" ""; read_status=$?
    (( list_status == 0 && read_status == 0 )) || {
      print -u2 -- "root commit list/read status: $list_status/$read_status"; exit 5
    }
    [[ $_GIT_REVIEW_PATHS == root.txt && -z $_GIT_REVIEW_PARENTS[1] &&
       $_GIT_REVIEW_DATA == *"+literal root commit content"* ]] || exit 6
  ' "$TEST_REPO_ROOT"
}
test_case 'shared Git object validation permits root commit capture and diff without a parent' \
  _test_shared_oid_root_commit

_test_shared_lexical_missing_support() {
  test_make_temp_dir || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.highlighting"
    BUFFER="API_TOKEN=private-value rg x > output.txt"
    region_highlight=("0 1 bold memo=other" "1 2 bold memo=compozsh")
    _zle_syntax_highlight
    [[ ${#region_highlight} == 1 && $region_highlight == *memo=other ]] || exit 1
    _prompt_interaction_model "$BUFFER"
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} != *private-value* &&
       ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"Draft details unavailable"* ]] || exit 2
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$unit"; done
    _prompt_interaction_model "$BUFFER"
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} != *private-value* &&
       ${(j:|:)_PROMPT_INTERACTION_VALUES} == *output.txt* ]] || exit 3
  ' "$TEST_REPO_ROOT"
}
test_case 'shared lexical absence protects draft values and late loading restores analysis' \
  _test_shared_lexical_missing_support

_test_prompt_project_common_finalization() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/project/Makefile" '' || return
  test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.runtime_version_relation"
    source "$1/.zsh.addons/support/functions/.zsh.pure.runtime_comparable_version"
    _prompt_runtime_version() { REPLY=6.4; }
    _prompt_expected_runtime_version() { REPLY=6.3; }
    local -i calls=0 i=0
    _fixture_project_hook() { (( ++calls )); prompt_add_project_segment "hook"; }
    PROMPT_PROJECT_CONTEXT_FUNCTIONS=(_fixture_project_hook)
    builtin cd "$2"
    _prompt_project_context
    [[ ${(j:|:)_PROMPT_PROJECT_ITEMS} == *swift*swiftpm*make*hook*newer* && $calls == 1 ]] || exit 1
    local attention=$_PROMPT_PROJECT_ATTENTION
    for (( i=0; i<130; ++i )); do : > "entry-$i"; done
    _prompt_project_context
    [[ ${(j:|:)_PROMPT_PROJECT_ITEMS} == *swift*hook*newer* &&
       ${(j:|:)_PROMPT_PROJECT_ITEMS} != *swiftpm* &&
       ${(j:|:)_PROMPT_PROJECT_ITEMS} != *make* && $calls == 2 &&
       $_PROMPT_PROJECT_ATTENTION == "$attention" && $_PROMPT_PROJECT_NAME_TEXT == project &&
       ${#_PROMPT_PROJECT_ITEMS} == ${#_PROMPT_PROJECT_ITEM_WIDTHS} ]] || exit 2
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project"
}
test_case 'prompt finalization preserves hooks warnings and saturated root decoration policy' \
  _test_prompt_project_common_finalization
