# Live discovery and safe documentation for public add-on functions.

_test_compozsh_discovers_addon_functions_without_registration() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local addon="$home/.zsh.addons/private/.zsh.custom" output=''

  test_write_file "$addon" $'_compozsh_help_documented-tool() {\n  print -r -- "usage: documented-tool"\n  print -r -- "Describe a private user tool."\n}\ndocumented-tool() {\n  print -r -- operational\n}\nundocumented-tool() {\n  print -r -- operational\n}\n_private-helper() { :; }\n' || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.help" || exit
    outside-function() { :; }
    source "$2" || exit
    compozsh --list
  ' "$TEST_REPO_ROOT" "$addon") || return

  test_assert_contains "$output" \
    'documented-tool · ✓ help · private/.zsh.custom' \
    'documented user tool was not discovered' || return
  test_assert_contains "$output" \
    'undocumented-tool · — no help · private/.zsh.custom' \
    'undocumented user tool was not identified safely' || return
  [[ $output != *'_private-helper'* ]] ||
    test_fail 'private helper leaked into tool discovery' || return
  [[ $output != *'outside-function'* ]] ||
    test_fail 'function outside an add-on tree leaked into discovery'
}
test_case 'Compozsh discovers public add-on functions without registration' \
  _test_compozsh_discovers_addon_functions_without_registration

_test_compozsh_discovery_regenerates_from_live_state() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local addon="$home/.zsh.addons/private/.zsh.dynamic" output=''

  test_write_file "$addon" \
    $'dynamic-tool() { :; }\n_compozsh_help_dynamic-tool() {\n  print -r -- "usage: dynamic-tool"\n  print -r -- "Describe a dynamic tool."\n}\n' || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.help" || exit
    before=$(compozsh --list)
    before_has=0
    [[ $before == *dynamic-tool* ]] && before_has=1
    source "$2" || exit
    during=$(compozsh --list)
    during_has=0
    [[ $during == *dynamic-tool* ]] && during_has=1
    unfunction dynamic-tool _compozsh_help_dynamic-tool
    after=$(compozsh --list)
    after_has=0
    [[ $after == *dynamic-tool* ]] && after_has=1
    print -r -- "$before_has|$during_has|$after_has"
  ' "$TEST_REPO_ROOT" "$addon") || return

  test_assert_equal '0|1|0' "$output" \
    'tool discovery retained stale state or missed a live function'
}
test_case 'Compozsh tool discovery is regenerated from live shell state' \
  _test_compozsh_discovery_regenerates_from_live_state

_test_compozsh_never_executes_an_undocumented_tool_for_help() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local addon="$home/.zsh.addons/private/.zsh.safety" output=''

  test_write_file "$addon" $'dangerous-tool() {\n  print -r -- ran >| "$HOME/dangerous-tool-ran"\n}\ndocumented-safe-tool() {\n  print -r -- ran >| "$HOME/documented-tool-ran"\n}\n_compozsh_help_documented-safe-tool() {\n  print -r -- "usage: documented-safe-tool"\n  print -r -- "Explain the tool without running it."\n}\n' || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.help" || exit
    source "$2" || exit
    dangerous_help=$(compozsh help dangerous-tool)
    dangerous_status=$?
    documented_help=$(compozsh help documented-safe-tool)
    documented_status=$?
    print -r -- "$dangerous_status|${#dangerous_help}|$documented_status"
    print -r -- "$dangerous_help"
    print -r -- "$documented_help"
    print -r -- "ran:$([[ -e $HOME/dangerous-tool-ran ]] && print yes || print no),$([[ -e $HOME/documented-tool-ran ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT" "$addon") || return

  test_assert_contains "$output" '0|' \
    'reporting unavailable help did not complete normally' || return
  test_assert_contains "$output" 'No Compozsh help is available for dangerous-tool.' \
    'undocumented tool did not receive a clear explanation' || return
  test_assert_contains "$output" 'usage: documented-safe-tool' \
    'documented tool did not use its companion help provider' || return
  test_assert_contains "$output" 'Explain the tool without running it.' \
    'companion help description was omitted' || return
  test_assert_contains "$output" 'ran:no,no' \
    'tool exploration executed an operational function'
}
test_case 'Compozsh never executes undocumented functions while showing help' \
  _test_compozsh_never_executes_an_undocumented_tool_for_help

_test_compozsh_help_providers_are_the_direct_help_source() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.xcode"
    zmodload -F zsh/parameter p:functions_source || exit

    typeset -a public_commands=(
      mkcd
      cpdir
      git-discard-all
      prompt-refresh
      d
      g
      f
      update_xcode_skills
      compozsh
    )
    for public_command in "${public_commands[@]}"; do
      helper="_compozsh_help_${public_command}"
      direct=$("$public_command" --help)
      direct_status=$?
      provided=$("$helper")
      provider_status=$?
      same=different
      [[ $direct == "$provided" ]] && same=same
      same_source=different-source
      [[ ${functions_source[$helper]-} == ${functions_source[$public_command]-} ]] && same_source=same-source
      print -r -- "$public_command|${+functions[$helper]}|$direct_status|$provider_status|$same|$same_source"
    done
  ' "$TEST_REPO_ROOT") || return

  local public_command=''
  for public_command in mkcd cpdir git-discard-all prompt-refresh d g f \
      update_xcode_skills compozsh; do
    test_assert_contains "$output" "$public_command|1|0|0|same|same-source" \
      "$public_command does not share one canonical help provider" || return
  done
}
test_case 'direct help and explorer help share one provider per command' \
  _test_compozsh_help_providers_are_the_direct_help_source

_test_compozsh_discovery_is_independent_of_source_order() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local addon="$home/.zsh.addons/private/.zsh.order" first='' second=''

  test_write_file "$addon" $'ordered-tool() { :; }\n_compozsh_help_ordered-tool() {\n  print -r -- "usage: ordered-tool"\n  print -r -- "Describe an order-independent tool."\n}\n' || return

  first=$(test_run_interactive "$home/first" \
    'source "$1/.zsh.addons/.zsh.help"; source "$2"; compozsh --list' \
    "$TEST_REPO_ROOT" "$addon") || return
  second=$(test_run_interactive "$home/second" \
    'source "$2"; source "$1/.zsh.addons/.zsh.help"; compozsh --list' \
    "$TEST_REPO_ROOT" "$addon") || return

  test_assert_equal "$first" "$second" \
    'tool discovery depends on add-on source order'
}
test_case 'Compozsh tool discovery is independent of add-on source order' \
  _test_compozsh_discovery_is_independent_of_source_order

_test_compozsh_rejects_a_cross_file_help_provider() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local command_addon="$home/.zsh.addons/private/.zsh.command"
  local provider_addon="$home/.zsh.addons/private/.zsh.provider" output=''

  test_write_file "$command_addon" $'split-tool() {\n  print -r -- ran >| "$HOME/split-tool-ran"\n}\n' || return
  test_write_file "$provider_addon" $'_compozsh_help_split-tool() {\n  print -r -- "usage: split-tool"\n  print -r -- "This provider belongs to the wrong add-on."\n}\n' || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.help" || exit
    source "$2" || exit
    source "$3" || exit
    compozsh --list
    compozsh help split-tool
    print -r -- "ran:$([[ -e $HOME/split-tool-ran ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT" "$command_addon" "$provider_addon") || return

  test_assert_contains "$output" \
    'split-tool · — no help · private/.zsh.command' \
    'cross-file provider was accepted as an atomic capability' || return
  test_assert_contains "$output" \
    'No Compozsh help is available for split-tool.' \
    'cross-file provider changed the safe no-help result' || return
  [[ $output != *'wrong add-on'* ]] ||
    test_fail 'cross-file help provider was executed' || return
  test_assert_contains "$output" 'ran:no' \
    'cross-file provider handling executed the public function'
}
test_case 'Compozsh accepts help providers only from the command add-on' \
  _test_compozsh_rejects_a_cross_file_help_provider

_test_compozsh_picker_fuzzily_filters_the_live_catalog() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local addon="$home/.zsh.addons/private/.zsh.search" output=''

  test_write_file "$addon" $'memory-search() { :; }\nproject-find() { :; }\n' || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.help" || exit
    source "$2" || exit
    _compozsh_tool_capture || exit
    _compozsh_tool_picker_collect msrch 10
    print -r -- "$_ZLE_PICKER_RESULTS"
  ' "$TEST_REPO_ROOT" "$addon") || return

  test_assert_equal 'memory-search' "$output" \
    'tool picker did not apply ordered-character fuzzy matching'
}
test_case 'Compozsh tool picker fuzzily filters the live catalog' \
  _test_compozsh_picker_fuzzily_filters_the_live_catalog
