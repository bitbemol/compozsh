_test_compose_contract() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    [[ -f "$1/.zsh.addons/.zsh.compose" ]] || { print -u2 missing-composer; exit 1; }
    source "$1/.zsh.addons/.zsh.compose"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.tools"
    _compozsh_compose_capability g || exit 2
    [[ $REPLY == git-review ]] || exit 3
    _compozsh_compose_capability mkcd || exit 4
    [[ $REPLY == directory ]] || exit 5
    _compozsh_template_fake() { REPLY=directory; }
    fake() { :; }
    if _compozsh_compose_capability fake; then exit 6; fi
    _compozsh_compose_seed "g --review --merge-base main HEAD"
    [[ $_compose_recipe == git-review && $_compose_method == ancestor && $_compose_base == main && $_compose_head == HEAD ]] || exit 7
    _compozsh_compose_seed "g --review; touch /never"
    [[ -z $_compose_recipe ]] || exit 8
    _compozsh_compose_seed "mkcd"
    _compozsh_compose_seed "mkcd -- ./example"
    [[ $_compose_recipe == directory && $_compose_path == ./example ]] || exit 14
    _compose_path=$'"'"'./literal $(never-run); [x] %F{red}\nfile'"'"'
    _compozsh_compose_build || exit 9
    local -a words=("${(@z)REPLY}")
    words=("${(@Q)words}")
    [[ ${#words} == 3 && $words[1] == mkcd && $words[2] == -- && $words[3] == "$_compose_path" ]] || exit 10
    _compose_path=""
    if _compozsh_compose_build; then exit 11; fi
    _compozsh_compose_seed "g --review"
    _compose_base=main _compose_head=HEAD
    _compozsh_compose_build || exit 12
    [[ $REPLY == "g --review main HEAD" ]] || exit 13
    print composed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal composed "$output"
}
test_case 'command composer uses trusted templates and literal quoted drafts without execution' _test_compose_contract

_test_compose_journey() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    [[ -f "$1/.zsh.addons/.zsh.compose" ]] || exit 1
    source "$1/.zsh.addons/.zsh.compose"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/support/.zsh.ui"
    local _COMPOZSH_COMPOSE_RESULT="" visits=0
    _zle_picker_loop() {
      (( ++visits ))
      _ZLE_PICKER_BOOKMARK=("" 1 0) _ZLE_PICKER_BOOKMARK_FOCUS=0
      case $visits in
        1) [[ $_ZLE_PICKER_TITLE == "Compose / mkcd" && $_ZLE_PICKER_ACTION_CONTEXT == *"mkcd"* ]] || return 11
           _ZLE_PICKER_SELECTED_VALUE=path ;;
        2) (( _ZLE_PICKER_QUERY_SUBMIT )) || return 12
           _ZLE_PICKER_SELECTED_VALUE="./a b" ;;
        3) [[ $_ZLE_PICKER_ACTION_CONTEXT == *"./a"* && $_ZLE_PICKER_ACCEPT_LABELS[apply] == "replace draft" ]] || return 13
           _ZLE_PICKER_SELECTED_VALUE=apply ;;
        *) return 19 ;;
      esac
      return 0
    }
    _compozsh_compose_open mkcd "$PWD" || exit $?
    [[ $_COMPOZSH_COMPOSE_RESULT == "mkcd -- ./a\\ b" && ! -e "./a b" ]] || exit 2
    # Widget applies only after screen cleanup; Escape preserves exact cursor.
    BUFFER=mkcd CURSOR=2
    _zle_picker_screen_session() { _COMPOZSH_COMPOSE_RESULT="mkcd -- ./draft"; }
    zle() { :; }
    _draft_inspect_widget
    [[ $BUFFER == "mkcd -- ./draft" && $CURSOR == ${#BUFFER} ]] || exit 3
    BUFFER=original CURSOR=2
    _zle_picker_screen_session() { return 1; }
    _draft_inspect_widget
    [[ $BUFFER == original && $CURSOR == 2 ]] || exit 4
    _zle_picker_loop() { _ZLE_PICKER_SELECTED_VALUE=apply; return 0; }
    _compozsh_compose_open " mkcd ./example" "$PWD" || exit 5
    [[ $_COMPOZSH_COMPOSE_RESULT == " mkcd -- ./example" ]] || exit 6
    print journey
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal journey "$output"
}
test_case 'command composer edits fields previews drafts and applies after cleanup with cancellation' _test_compose_journey

_test_compose_help_entry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/support/.zsh.ui"
    [[ -f "$1/.zsh.addons/.zsh.compose" ]] || exit 1
    source "$1/.zsh.addons/.zsh.compose"
    local _COMPOZSH_COMPOSE_RESULT="" opened=0
    _zle_picker_loop() {
      [[ $_HELP_COMPOSE_INDEX -gt 0 ]] || return 11
      [[ $_ZLE_PICKER_ACCEPT_LABELS[$_HELP_COMPOSE_INDEX] == compose ]] || return 12
      _compozsh_help_collect "Compose example" 20
      [[ $_ZLE_PICKER_RESULTS[1] == "$_HELP_COMPOSE_INDEX" ]] || return 15
      _ZLE_PICKER_SELECTED_VALUE=$_HELP_COMPOSE_INDEX
      _ZLE_PICKER_BOOKMARK=(example 1 0)
      return 0
    }
    _compozsh_compose_open() { [[ $1 == mkcd ]] || return 13; (( ++opened )); _COMPOZSH_COMPOSE_RESULT="mkcd -- ./example"; }
    _compozsh_help_workspace "$(_compozsh_help_mkcd)" mkcd || exit $?
    [[ $opened == 1 && $_COMPOZSH_COMPOSE_RESULT == "mkcd -- ./example" ]] || exit 2
    # Prose that names a real command is not template authority.
    _zle_picker_loop() { (( _HELP_COMPOSE_INDEX == 0 )) || return 14; return 1; }
    _compozsh_help_workspace "$(_compozsh_help_mkcd)"
    [[ $? == 1 ]] || exit 3
    print help
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal help "$output"
}
test_case 'command composer help action requires explicit command identity not parsed prose' _test_compose_help_entry

_test_compose_mkcd_separator() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.tools"
    builtin cd "$HOME"
    mkcd -- ./--help || exit 1
    [[ $PWD == "$HOME/--help" ]] || exit 2
  ' "$TEST_REPO_ROOT"
}
test_case 'command composer directory drafts use a literal path after the option separator' _test_compose_mkcd_separator

_test_compose_literal_fallback() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.compose"
    source "$1/.zsh.addons/support/.zsh.ui"
    local _compose_scope=$PWD _compose_recipe=git-review _compose_method=exact
    local _compose_base=main _compose_head=HEAD _compose_field=head _compose_endpoint_label=""
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_TITLE == "Compose / Compare" && ${(j:|:)_ZLE_PICKER_EMPTY_LINES} == *"revision"* &&
         ${(j:|:)_ZLE_PICKER_EMPTY_LINES} != *"absolute path"* ]] || return 12
      _compozsh_compose_field_collect topic
      [[ $_ZLE_PICKER_BROWSE_LABEL == "Draft · g --review main topic" ]] || return 13
      _ZLE_PICKER_SELECTED_VALUE=topic
      return 0
    }
    _compozsh_compose_endpoint To HEAD || exit $?
    [[ $REPLY == topic && $_compose_endpoint_label == topic ]] || exit 1
  ' "$TEST_REPO_ROOT"
}
test_case 'command composer missing Git peer retains explicit literal revision entry and reactive preview' _test_compose_literal_fallback
