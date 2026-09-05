_test_task_family_entries() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for retired in flash-usb format-external-device update-xcode-skills prompt-refresh; do
      functions[$retired]="return 99"
      functions[_compozsh_help_$retired]="return 99"
      aliases[$retired]=obsolete
    done
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    for retired in flash-usb format-external-device update-xcode-skills prompt-refresh; do
      (( ! ${+functions[$retired]} && ! ${+functions[_compozsh_help_$retired]} && ! ${+aliases[$retired]} )) || exit 1
    done
    (( ${+functions[external-device]} )) || exit 2
    _usb_flash() { [[ $# == 1 && $1 == "literal [a] text.iso" ]] || return 90; print flash; return 17; }
    _usb_format() { (( $# == 0 )) || return 91; print format; return 18; }
    _xcode_export_skills() { (( $# == 0 )) || return 92; print export; return 19; }
    external-device --flash "literal [a] text.iso"
    [[ $? == 17 ]] || exit 3
    external-device --format
    [[ $? == 18 ]] || exit 4
    xcode --export-skills
    [[ $? == 19 ]] || exit 5
    typeset -gA _PROMPT_RUNTIME_VERSION_CACHE=(test stale) _PROMPT_GIT_DIR_CACHE=(test stale)
    typeset -g _GREP_SUPPORTS_COLOR=1 _GREP_COLOR_BINARY=stale
    compozsh --refresh || exit 6
    [[ ${#_PROMPT_RUNTIME_VERSION_CACHE} == 0 && ${#_PROMPT_GIT_DIR_CACHE} == 0 &&
       $_GREP_SUPPORTS_COLOR == -1 && -z $_GREP_COLOR_BINARY ]] || exit 7
    _compozsh_tool_capture
    for retired in flash-usb format-external-device update-xcode-skills prompt-refresh; do
      (( ! ${_COMPOZSH_TOOL_NAMES[(Ie)$retired]} )) || exit 8
    done
    (( ${_COMPOZSH_TOOL_NAMES[(Ie)external-device]} )) || exit 9
    print families
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'flash\nformat\nexport\nfamilies' "$output"
}
test_case 'task families have one canonical entry per operation and no retired catalog names' _test_task_family_entries

_test_task_family_help_and_errors() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    _usb_flash() { print -u2 forbidden; return 99; }
    _usb_format() { print -u2 forbidden; return 99; }
    _xcode_export_skills() { print -u2 forbidden; return 99; }
    for invocation in "external-device --help" "external-device --flash --help" "external-device --format --help" "xcode --export-skills --help" "compozsh --refresh --help"; do
      args=( ${(z)invocation} )
      "${args[@]}" > "$HOME/out" 2> "$HOME/error"
      [[ $? == 0 && ! -s "$HOME/error" && $(<"$HOME/out") == usage:* ]] || exit 1
    done
    for invocation in "external-device --flash a b" "external-device --flash --format" "external-device --flash --unknown" "external-device --format extra" "external-device --unknown" "xcode --export-skills extra" "compozsh --refresh extra"; do
      args=( ${(z)invocation} )
      "${args[@]}" > "$HOME/out" 2> "$HOME/error"
      [[ $? == 2 && ! -s "$HOME/out" && $(<"$HOME/error") == usage:* && $(<"$HOME/error") != *forbidden* ]] || exit 2
    done
    # Bare device use cannot begin discovery in a pipe.
    external-device > "$HOME/out" 2> "$HOME/error"
    [[ $? == 1 && $(<"$HOME/error") == *"interactive terminal"* ]] || exit 3
    compozsh --refresh > "$HOME/out" 2> "$HOME/error"
    [[ $? == 1 && $(<"$HOME/error") == *".zsh.tools"* ]] || exit 4
    print safe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal safe "$output"
}
test_case 'task families expose inert mode help and reject malformed modes before effects' _test_task_family_help_and_errors

_test_task_family_device_cards() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.usb"
    _usb_images_capture() { return 99; }
    _usb_disks_capture() { return 99; }
    _zle_picker_loop() {
      (( _ZLE_PICKER_ACTION_VIEW )) || return 10
      [[ $_ZLE_PICKER_TITLE == "External device / Tasks" &&
         $_ZLE_PICKER_ACCEPT_LABELS[flash] == "choose media" &&
         $_ZLE_PICKER_ACCEPT_LABELS[format] == "choose drive" &&
         $_ZLE_PICKER_INSPECT_TEXTS[format] == *"ERASE diskN"* ]] || return 11
      _usb_picker_collect "format" 10
      [[ ${(j:|:)_ZLE_PICKER_RESULTS} == format ]] || return 12
      _ZLE_PICKER_SELECTED_VALUE=format
    }
    _usb_task_choose || exit $?
    [[ $_ZLE_PICKER_SELECTED_VALUE == format ]] || exit 13
    print cards
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal cards "$output"
}
test_case 'task families device chooser uses shared action plans without provider discovery' _test_task_family_device_cards

_test_task_family_prompt() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    for draft in "external-device --flash" "external-device --format"; do
      _prompt_interaction_model "$draft"
      [[ $_PROMPT_INTERACTION_KIND == caution ]] || exit 1
    done
    for draft in "external-device --help" "external-device --format --help" "external-device"; do
      _prompt_interaction_model "$draft"
      [[ $_PROMPT_INTERACTION_KIND != caution ]] || exit 2
    done
    _prompt_interaction_model "xcode --export-skills"
    [[ $_PROMPT_INTERACTION_KIND == environment && ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"export Apple"* ]] || exit 3
    _prompt_interaction_model "xcode"
    [[ $_PROMPT_INTERACTION_KIND == run && ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"workspace"* ]] || exit 4
    _prompt_interaction_model "compozsh --refresh"
    [[ $_PROMPT_INTERACTION_KIND == environment && ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"cached"* ]] || exit 5
    _prompt_interaction_model "xcode --export-skills --help"
    [[ $_PROMPT_INTERACTION_KIND == run && ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"help"* ]] || exit 6
    _prompt_interaction_model "compozsh --sudo-touch-id enable"
    [[ $_PROMPT_INTERACTION_KIND == environment && ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"Touch ID"* ]] || exit 7
    _prompt_interaction_model "compozsh --sudo-touch-id --help"
    [[ $_PROMPT_INTERACTION_KIND == run && ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"help"* ]] || exit 8
    print lens
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal lens "$output"
}
test_case 'task families reactive lens distinguishes device selection from destructive modes' _test_task_family_prompt

_test_task_family_export_plan() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/.zsh.xcode"
    local -a agent_names=("Example agent") skill_dirs=("/example/literal [skills]")
    local agent_path="/example/Xcode/agent"
    _zle_picker_loop() {
      (( _ZLE_PICKER_ACTION_VIEW )) || return 10
      [[ $_ZLE_PICKER_TITLE == "Xcode / Export skills" &&
         $_ZLE_PICKER_ACTION_CONTEXT == *"/example/literal [skills]"* &&
         $_ZLE_PICKER_INSPECT_TEXTS[export] == *".xcode-skill-export"* &&
         $_ZLE_PICKER_ACCEPT_LABELS[export] == "export skills" ]] || return 11
      _xcode_picker_collect "update" 10
      [[ ${(j:|:)_ZLE_PICKER_RESULTS} == export ]] || return 12
      _ZLE_PICKER_SELECTED_VALUE=export
      print plan
    }
    _xcode_export_review || exit $?
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal plan "$output"
}
test_case 'task families Xcode export reviews exact destinations and replacement policy before writing' _test_task_family_export_plan

_test_task_family_identity() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.usb"
    _zle_picker_loop() { print -r -- "$_ZLE_PICKER_TITLE"; }
    _usb_read_image_path
    _usb_read_volume_name
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'External device / Flash / Add media\nExternal device / Format / Volume name' "$output"
}
test_case 'task families nested device views retain their shared task identity' _test_task_family_identity
