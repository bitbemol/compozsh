# Shared display calculations keep exact values outside their presentation.
_test_shared_display_highlight_inputs() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_highlights_shift"
    local REPLY IFS=$'"'"' \t\n'"'"' spans="0:2:picker-match 3:9:picker-dim"
    _zle_picker_highlights_shift "$spans" 1 5 || exit 1
    [[ $REPLY == "1:3:picker-match 4:6:picker-dim" ]] || exit 2
    IFS=,
    _zle_picker_highlights_shift "$spans" 1 5 || exit 3
    [[ $REPLY == "1:3:picker-match 4:6:picker-dim" && $IFS == , ]] || exit 4
    local sentinel=7
    _zle_picker_highlights_shift "$spans" "sentinel=99" 5
    [[ $? == 2 && -z $REPLY && $sentinel == 7 ]] || exit 5
    _zle_picker_highlights_shift "08:09:picker-match" 01 010 || exit 6
    [[ $REPLY == "9:10:picker-match" ]] || exit 7
    print isolated
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal isolated "$output"
}
test_case 'shared display highlight spans use explicit inputs and preserve caller IFS' \
  _test_shared_display_highlight_inputs

_test_shared_display_navigation_width() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    COLUMNS=14
    local row=$(_stack_print_entry 0 current "界界界界界界")
    (( ${(m)#row} <= COLUMNS )) || exit 1
    [[ $row == *…* ]] || exit 2
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'shared display navigation respects terminal cells for wide directory labels' \
  _test_shared_display_navigation_width

_test_shared_display_literal_contract() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize" || exit 1
    local REPLY text=$'"'"'a\n\tb\e%F{red}$(print unsafe)`print unsafe`'"'"'
    _compozsh_sanitize "$text"
    [[ $REPLY == '"'"'a??b?%F{red}$(print unsafe)`print unsafe`'"'"' ]] || exit 2
    [[ $text == *$'"'"'\n\t'"'"'* ]] || exit 3
    _zle_picker_abbreviate abcdefgh 5 head
    [[ $REPLY == ab…gh ]] || exit 4
    _zle_picker_abbreviate abcdefgh 5 tail
    [[ $REPLY == a…fgh ]] || exit 5
    _zle_picker_abbreviate $'"'"'界界\u0301ab'"'"' 5 tail
    [[ $REPLY == …ab && ${(m)#REPLY} -le 5 ]] || exit 6
    _zle_picker_abbreviate $'"'"'aae\u0301abcdefghi'"'"' 6 head
    [[ $REPLY == $'"'"'aae\u0301…hi'"'"' ]] || exit 8
    _zle_picker_abbreviate '"'"'%F{red}$(print unsafe)`print unsafe`'"'"' 100
    [[ $REPLY == '"'"'%F{red}$(print unsafe)`print unsafe`'"'"' ]] || exit 7
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared display preserves literal text bias combining boundaries and input ownership' \
  _test_shared_display_literal_contract

_test_shared_display_optional_support() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.navigation"
    local REPLY text=$'"'"'a\nb'"'"'
    local -a reply=()
    _prompt_escape "$text"
    [[ $REPLY != *$'"'"'\n'"'"'* && $REPLY == *a*b ]] || exit 1
    _prompt_render_abbreviated path abcdefgh 5
    [[ $reply[2] == … ]] || exit 2
    COLUMNS=14
    local row=$(_stack_print_entry 0 current "界界界界界界")
    (( ${(m)#row} <= COLUMNS )) || exit 3
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    _prompt_escape "$text"
    [[ $REPLY == a?b ]] || exit 4
    _prompt_render_abbreviated path abcdefgh 5
    [[ $reply[2] == a…fgh ]] || exit 5
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_render_abbreviated path abcdefgh 5 head
    [[ $reply[2] == ab…gh && $text == *$'"'"'\n'"'"'* ]] || exit 6
    print deferred
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal deferred "$output"
}
test_case 'shared display missing support stays bounded and late loading restores presentation' \
  _test_shared_display_optional_support
