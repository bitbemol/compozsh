_test_shared_effects_exact_targets() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/open" $'#!/bin/zsh\nprint -rl -- "$@" > "$HOME/opened"\n' || return
  command chmod +x "$TEST_TMP_DIR/open" || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_effect_*(N.); do source "$support_component"; done || exit 1
    local text="literal [path] %F{red}; \$(do-not-run)
second line"
    _compozsh_effect_copy "$text" /bin/cat > "$HOME/copied" || exit 2
    [[ $(<"$HOME/copied") == "$text" && $(command wc -c < "$HOME/copied") -eq ${#text} ]] || exit 3
    _compozsh_effect_copy "$text" /usr/bin/false && exit 4
    _compozsh_effect_copy "$text" / && exit 5
    # A successful receiver that closes early must not hide a partial write.
    _compozsh_effect_copy "${(l:131072::x:)}" /usr/bin/true 2>/dev/null && exit 12
    print -rn -- fixture > "$HOME/[literal] file"
    _compozsh_effect_open open "$HOME/[literal] file" "$2" || exit 6
    [[ $(<"$HOME/opened") == "--
$HOME/[literal] file" ]] || exit 7
    command ln -s absent "$HOME/link"
    _compozsh_effect_open reveal "$HOME/link" "$2" || exit 8
    [[ $(<"$HOME/opened") == "-R
--
$HOME/link" ]] || exit 9
    _compozsh_effect_open open "$HOME/link" "$2" && exit 10
    _compozsh_effect_open reveal relative "$2" && exit 11
    print preserved
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/open") || return
  test_assert_equal preserved "$output"
}
test_case 'shared effects preserve exact clipboard bytes and revalidate app targets' _test_shared_effects_exact_targets

_test_shared_effects_runtime_capabilities() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    print -rn -- fixture > "$HOME/target"
    local captured=""
    _zle_picker_run() { captured="${(j:|:)_file_action_values}"; }
    _file_search_actions "$HOME/target" /bin/cat /usr/bin/true || exit 1
    [[ $captured == insert ]] || exit 2
    cpdir >/dev/null 2> "$HOME/error" && exit 3
    [[ $(<"$HOME/error") == *"shared local effects are unavailable"* ]] || exit 4
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_effect_*(N.); do source "$support_component"; done
    _file_search_actions "$HOME/target" /bin/cat /usr/bin/true || exit 5
    [[ $captured == "open|reveal|copy|insert" ]] || exit 6
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_effect_*(N.); do source "$support_component"; done
    _file_search_actions "$HOME/target" /bin/cat /usr/bin/true || exit 7
    [[ $captured == "open|reveal|copy|insert" ]] || exit 8
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared effects missing capabilities stay inert and become available after later sourcing' \
  _test_shared_effects_runtime_capabilities
