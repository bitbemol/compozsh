# Shared palette lookup observes current roles without installing defaults.
_test_shared_palette_resolution() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color" || exit 1
    typeset -A ZSH_OUTPUT_COLORS=(heading 123 warning invalid)
    typeset -A ZSH_PROMPT_COLORS=(path 124)
    typeset -A _COMPOZSH_COLOR_FALLBACKS=(output:heading 75 output:warning 221 prompt:path 111)
    local REPLY=sentinel
    _compozsh_palette_color output heading || exit 2
    [[ $REPLY == 123 ]] || exit 3
    _compozsh_palette_color prompt path || exit 4
    [[ $REPLY == 124 ]] || exit 5
    _compozsh_palette_color output warning || exit 6
    [[ $REPLY == 221 && $ZSH_OUTPUT_COLORS[warning] == invalid ]] || exit 7
    unset "ZSH_OUTPUT_COLORS[heading]"
    _compozsh_palette_color output heading || exit 8
    [[ $REPLY == 75 && ! ${+ZSH_OUTPUT_COLORS[heading]} == 1 ]] || exit 9
    _COMPOZSH_COLOR_FALLBACKS[output:heading]=999999999999999999999
    _compozsh_palette_color output heading && exit 10
    [[ -z $REPLY ]] || exit 11
    _compozsh_palette_color invalid heading && exit 12
    [[ -z $REPLY ]] || exit 13
    unset ZSH_OUTPUT_COLORS
    typeset -a ZSH_OUTPUT_COLORS=(malformed)
    _compozsh_palette_color output warning || exit 14
    [[ $REPLY == 221 ]] || exit 15
    _compozsh_palette_color output "literal [role]" && exit 16
    [[ -z $REPLY ]] || exit 17
    print shared
  ' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal shared "$output"
}
test_case 'shared palette resolves current overrides and fallbacks without writes or unsafe indexes' \
  _test_shared_palette_resolution

_test_shared_palette_missing_and_late_support() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.output"
    typeset -A ZSH_PROMPT_COLORS=(path 123)
    typeset -A ZSH_OUTPUT_COLORS=(heading 124)
    local REPLY=stale
    _prompt_color_text path literal
    [[ $REPLY == literal ]] || exit 1
    _output_git_color_arguments
    (( ! ${#_OUTPUT_GIT_COLOR_CONFIG} )) || exit 2
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    _prompt_color_text path literal
    [[ $REPLY == "%F{123}literal%f" ]] || exit 3
    _output_git_color_arguments
    [[ ${_OUTPUT_GIT_COLOR_CONFIG[(r)color.status.header=*]} == "color.status.header=bold 124" ]] || exit 4
    source "$1/.zsh.addons/.zsh.output"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    _compozsh_palette_color output heading || exit 5
    [[ $REPLY == 124 && ${#ZSH_OUTPUT_COLORS} == 1 ]] || exit 6
    unfunction _compozsh_palette_color
    _prompt_color_text path literal
    [[ $REPLY == literal ]] || exit 7
    _output_git_color_arguments
    (( ! ${#_OUTPUT_GIT_COLOR_CONFIG} )) || exit 8
    print preserved
  ' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal preserved "$output"
}
test_case 'shared palette consumers remain plain without support and resolve late or re-sourced entries' \
  _test_shared_palette_missing_and_late_support
