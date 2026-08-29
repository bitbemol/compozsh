_test_xcode_refresh_replaces_managed_skill() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"

  test_write_file "$source_dir/swift/SKILL.md" 'new instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'old instructions' || return
  test_write_file "$target_dir/swift/stale.txt" 'remove me' || return
  test_write_file "$target_dir/swift/.xcode-skill-export" 'old-build' || return

  test_run_noninteractive "$home" \
    'source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" >/dev/null || return

  test_assert_equal 'new instructions' "$(<"$target_dir/swift/SKILL.md")" \
    'managed Xcode skill did not receive the new export' || return
  [[ ! -e "$target_dir/swift/stale.txt" ]] ||
    test_fail 'managed Xcode refresh retained a stale file' || return
  test_assert_equal 'new-build' "$(<"$target_dir/swift/.xcode-skill-export")" \
    'managed Xcode skill marker was not refreshed'
}
test_case 'Xcode skill refresh atomically replaces stale managed content' \
  _test_xcode_refresh_replaces_managed_skill

_test_xcode_refresh_rolls_back_partial_copy() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"
  local fake_bin="$TEST_TMP_DIR/bin"

  test_write_file "$source_dir/swift/SKILL.md" 'new instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'old instructions' || return
  test_write_file "$target_dir/swift/.xcode-skill-export" 'old-build' || return
  test_write_file "$fake_bin/cp" \
    $'#!/usr/bin/env zsh\nprint -r -- partial >| "${@[-1]}/partial.txt"\nexit 1' || return
  command chmod +x "$fake_bin/cp" || return

  local output=''
  local -i command_status=0
  output=$(test_run_noninteractive "$home" \
    'path=("$4" $path)
     rehash
     source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" "$fake_bin" 2>&1) ||
    command_status=$?

  (( command_status != 0 )) || test_fail 'partial Xcode skill copy reported success' || return
  test_assert_equal 'old instructions' "$(<"$target_dir/swift/SKILL.md")" \
    'failed Xcode refresh replaced the previous skill' || return
  test_assert_equal 'old-build' "$(<"$target_dir/swift/.xcode-skill-export")" \
    'failed Xcode refresh replaced the previous marker' || return
  [[ ! -e "$target_dir/swift/partial.txt" ]] ||
    test_fail 'failed Xcode refresh polluted the active skill' || return
  test_assert_contains "$output" 'failed to copy swift' \
    'failed Xcode refresh did not report its error'
}
test_case 'failed Xcode skill refresh preserves the previous complete skill' \
  _test_xcode_refresh_rolls_back_partial_copy

_test_xcode_failed_restore_keeps_recovery_backup() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"
  local fake_bin="$TEST_TMP_DIR/bin" count_file="$TEST_TMP_DIR/mv-count"
  local output='' recovery=''
  local -a recoveries=()

  test_write_file "$source_dir/swift/SKILL.md" 'new instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'old instructions' || return
  test_write_file "$target_dir/swift/.xcode-skill-export" 'old-build' || return
  test_write_file "$fake_bin/mv" $'#!/usr/bin/env zsh
integer count=0
[[ -f $FAKE_MV_COUNT ]] && count=$(<$FAKE_MV_COUNT)
(( ++count ))
print -r -- $count >| $FAKE_MV_COUNT
(( count == 1 )) && exec /bin/mv "$@"
exit 1' || return
  command chmod +x "$fake_bin/mv" || return

  output=$(test_run_noninteractive "$home" \
    'path=("$4" $path)
     export FAKE_MV_COUNT=$5
     rehash
     source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" "$fake_bin" \
    "$count_file" 2>&1) || true

  recoveries=("$target_dir"/.xcode-skill-backup.*/previous(N/))
  (( ${#recoveries} == 1 )) ||
    test_fail 'failed Xcode restore deleted its only recovery backup' || return
  recovery=${recoveries[1]}
  test_assert_equal 'old instructions' "$(<"$recovery/SKILL.md")" \
    'Xcode recovery backup does not contain the previous skill' || return
  test_assert_contains "$output" "$recovery" \
    'failed Xcode restore did not print its recovery path'
}
test_case 'failed Xcode rollback retains and reports the previous skill' \
  _test_xcode_failed_restore_keeps_recovery_backup

_test_xcode_install_preserves_unmarked_conflict() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local source_dir="$TEST_TMP_DIR/export"
  local target_dir="$home/.agents/skills"

  test_write_file "$source_dir/swift/SKILL.md" 'Apple instructions' || return
  test_write_file "$target_dir/swift/SKILL.md" 'personal instructions' || return

  local output=''
  output=$(test_run_noninteractive "$home" \
    'source "$1/.zsh.addons/.zsh.xcode"
     _install_xcode_skills_for_agent "$2" "$3" TestAgent new-build' \
    "$TEST_REPO_ROOT" "$source_dir" "$target_dir" 2>&1) || true

  test_assert_equal 'personal instructions' "$(<"$target_dir/swift/SKILL.md")" \
    'Xcode installer replaced an unmarked personal skill' || return
  test_assert_contains "$output" 'kept existing personal skill swift' \
    'Xcode installer did not report the preserved conflict'
}
test_case 'Xcode skill installation preserves unmarked personal conflicts' \
  _test_xcode_install_preserves_unmarked_conflict

_test_xcode_workspace_discovers_only_nearest_containers() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/project" nested="$TEST_TMP_DIR/project/Sources/Feature"

  test_write_file "$root/App.xcworkspace/contents.xcworkspacedata" '<Workspace/>' || return
  test_write_file "$root/App.xcodeproj/project.pbxproj" '// project' || return
  test_write_file "$TEST_TMP_DIR/Outer.xcodeproj/project.pbxproj" '// outer' || return
  command mkdir -p -- "$nested" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_container_discover "$2" || exit
    print -r -- "${#_XCODE_CONTAINERS}"
    print -r -- "${_XCODE_CONTAINER_KINDS[1]}|${_XCODE_CONTAINERS[1]}"
    print -r -- "${_XCODE_CONTAINER_KINDS[2]}|${_XCODE_CONTAINERS[2]}"
  ' "$TEST_REPO_ROOT" "$nested") || return

  local -a lines=("${(f)output}")
  test_assert_equal 2 "${lines[1]}" 'nearest Xcode container count changed' || return
  test_assert_equal "workspace|$root/App.xcworkspace" "${lines[2]}" \
    'workspace was not preferred at the nearest project root' || return
  test_assert_equal "project|$root/App.xcodeproj" "${lines[3]}" \
    'project container was not retained beside its workspace'
}
test_case 'Xcode workspace discovers literal containers at the nearest scope' \
  _test_xcode_workspace_discovers_only_nearest_containers

_test_xcode_workspace_captures_bounded_schemes_without_update_flags() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" log="$TEST_TMP_DIR/xcodebuild.log"
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh\nprint -rl -- "$@" >| "$XCODE_TEST_LOG"\nprint -r -- '\''{"workspace":{"schemes":["Example App","Example Tests"]}}'\''' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export XCODE_TEST_LOG=$3
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_schemes_capture workspace "/example/Example App.xcworkspace" || exit
    print -r -- "${(j:|:)_XCODE_SCHEMES}"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$log") || return

  test_assert_equal 'Example App|Example Tests' "$output" \
    'Xcode scheme capture lost JSON array values' || return
  local invocation=$(<"$log")
  test_assert_contains "$invocation" '-workspace' 'workspace selector missing' || return
  test_assert_contains "$invocation" '/example/Example App.xcworkspace' \
    'literal workspace path changed' || return
  test_assert_contains "$invocation" '-list' 'scheme discovery did not use list' || return
  test_assert_contains "$invocation" '-json' 'scheme discovery did not request JSON' || return
  test_assert_contains "$invocation" '-disableAutomaticPackageResolution' \
    'scheme discovery allows automatic package resolution' || return
  test_assert_contains "$invocation" '-onlyUsePackageVersionsFromResolvedFile' \
    'scheme discovery allows package version drift' || return
  [[ $invocation != *'-allowProvisioningUpdates'* ]] ||
    test_fail 'scheme discovery enabled provisioning writes'
}
test_case 'Xcode workspace captures schemes through bounded native JSON' \
  _test_xcode_workspace_captures_bounded_schemes_without_update_flags

_test_xcode_destination_parser_keeps_exact_usable_ids() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    data=$'\''Available destinations for the "Example" scheme:\n\t\t{ platform:macOS, arch:arm64, id:MAC-123, name:My Mac }\n\t\t{ platform:iOS Simulator, arch:arm64, id:SIM-456, OS:27.0, name:iPhone 18 Pro }\n\t\t{ platform:iOS, name:Any iOS Device }\n\t\t{ platform:iOS Simulator, id:SIM-789, OS:27.0, name:Unavailable, error:iOS 27.0 is not installed }\n\t\t{ platform:iOS Simulator, id:bad/value, OS:27.0, name:Unsafe }'\''
    _xcode_destinations_parse "$data"
    print -r -- "${#_XCODE_DESTINATION_IDS}"
    for (( i = 1; i <= ${#_XCODE_DESTINATION_IDS}; ++i )); do
      print -r -- "${_XCODE_DESTINATION_PLATFORMS[i]}|${_XCODE_DESTINATION_IDS[i]}|${_XCODE_DESTINATION_NAMES[i]}"
    done
  ' "$TEST_REPO_ROOT") || return

  local -a lines=("${(f)output}")
  test_assert_equal 2 "${lines[1]}" 'generic or unsafe Xcode destination was retained' || return
  test_assert_equal 'macOS|MAC-123|My Mac' "${lines[2]}" 'Mac destination changed' || return
  test_assert_equal 'iOS Simulator|SIM-456|iPhone 18 Pro · iOS 27.0' "${lines[3]}" \
    'Simulator destination changed'
}
test_case 'Xcode workspace accepts only exact destination identifiers' \
  _test_xcode_destination_parser_keeps_exact_usable_ids

_test_xcode_action_builder_preserves_target_and_safety_policy() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_action_command project "/example/Example App.xcodeproj" \
      "Example App" "iOS Simulator" "SIM-456" test || exit
    print -rl -- "${_XCODE_COMMAND[@]}"
  ' "$TEST_REPO_ROOT") || return

  local -a command=("${(f)output}")
  test_assert_equal xcodebuild "${command[1]}" 'Xcode action does not call xcodebuild' || return
  test_assert_equal '-project' "${command[2]}" 'project selector changed' || return
  test_assert_equal '/example/Example App.xcodeproj' "${command[3]}" 'project path changed' || return
  test_assert_contains "$output" 'Example App' 'scheme missing from action' || return
  test_assert_contains "$output" 'platform=iOS Simulator,id=SIM-456' \
    'exact destination missing from action' || return
  test_assert_contains "$output" '-disableAutomaticPackageResolution' \
    'action allows automatic package resolution' || return
  test_assert_contains "$output" '-onlyUsePackageVersionsFromResolvedFile' \
    'action allows package version drift' || return
  test_assert_equal test "${command[-1]}" 'requested Xcode action changed' || return
  [[ $output != *'-allowProvisioningUpdates'* &&
     $output != *'-skipPackagePluginValidation'* &&
     $output != *'-skipMacroValidation'* ]] ||
    test_fail 'Xcode action weakened provisioning, plugin, or macro safety'
}
test_case 'Xcode workspace builds exact safe xcodebuild actions' \
  _test_xcode_action_builder_preserves_target_and_safety_policy

_test_xcode_command_delegates_arguments_and_preserves_status() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin"
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh\nprint -rl -- "$@"\nexit 23' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    xcode -showBuildSettings -scheme "Example App"
    print -r -- "status=$?"
  ' "$TEST_REPO_ROOT" "$fake_bin") || return
  local -a lines=("${(f)output}")
  test_assert_equal '-showBuildSettings' "${lines[1]}" 'delegated option changed' || return
  test_assert_equal '-scheme' "${lines[2]}" 'delegated scheme option changed' || return
  test_assert_equal 'Example App' "${lines[3]}" 'delegated literal scheme changed' || return
  test_assert_equal 'status=23' "${lines[4]}" 'xcodebuild status was not preserved'
}
test_case 'Xcode command delegates advanced arguments without reinterpretation' \
  _test_xcode_command_delegates_arguments_and_preserves_status

_test_xcode_noninteractive_fallback_lists_the_nearest_container_safely() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" root="$TEST_TMP_DIR/project"
  local nested="$root/Sources/Feature" log="$TEST_TMP_DIR/xcodebuild.log"
  test_write_file "$root/App.xcodeproj/project.pbxproj" '// project' || return
  command mkdir -p -- "$nested" || return
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh\nprint -rl -- "$@" >| "$XCODE_TEST_LOG"\nprint -r -- listed' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export XCODE_TEST_LOG=$4 TERM=dumb
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    builtin cd -- "$3" || exit
    xcode
  ' "$TEST_REPO_ROOT" "$fake_bin" "$nested" "$log") || return
  test_assert_equal listed "$output" 'noninteractive fallback changed native output' || return
  local invocation=$(<"$log")
  test_assert_contains "$invocation" '-project' 'fallback lost project selector' || return
  test_assert_contains "$invocation" "$root/App.xcodeproj" 'fallback changed project path' || return
  test_assert_contains "$invocation" '-list' 'fallback did not request the native list' || return
  test_assert_contains "$invocation" '-disableAutomaticPackageResolution' \
    'fallback permits automatic package resolution' || return
  [[ $invocation != *'-allowProvisioningUpdates'* ]] ||
    test_fail 'fallback enabled provisioning writes'
}
test_case 'Xcode noninteractive fallback lists one nearest container safely' \
  _test_xcode_noninteractive_fallback_lists_the_nearest_container_safely

_test_xcode_capture_rejects_oversized_provider_output() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin"
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh\nrepeat 5000 print -n x' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    ZSH_XCODE_CAPTURE_MAX_BYTES=4096
    _xcode_schemes_capture workspace /example/App.xcworkspace
    print -r -- "$?|${#_XCODE_SCHEMES}|$_XCODE_CAPTURE_ERROR"
  ' "$TEST_REPO_ROOT" "$fake_bin") || return
  test_assert_contains "$output" '1|0|output exceeded the 4096-byte capture limit' \
    'oversized Xcode output was retained or parsed'
}
test_case 'Xcode provider capture rejects oversized output before parsing' \
  _test_xcode_capture_rejects_oversized_provider_output

_test_xcode_simulator_run_uses_one_validated_built_application() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" products="$TEST_TMP_DIR/Products"
  local app="$products/Example App.app" xcode_log="$TEST_TMP_DIR/xcode.log"
  local xcrun_log="$TEST_TMP_DIR/xcrun.log" open_log="$TEST_TMP_DIR/open.log"
  command mkdir -p -- "$app" || return
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh\nprint -r -- "${(j:|:)@}" >> "$XCODE_TEST_LOG"\nif [[ " ${(j: :)@} " == *" -showBuildSettings "* ]]; then\n  print -r -- "[{\\"buildSettings\\":{\\"WRAPPER_EXTENSION\\":\\"app\\",\\"TARGET_BUILD_DIR\\":\\"$XCODE_PRODUCTS\\",\\"FULL_PRODUCT_NAME\\":\\"Example App.app\\",\\"PRODUCT_BUNDLE_IDENTIFIER\\":\\"com.example.app\\"}}]"\nfi' || return
  test_write_file "$fake_bin/xcrun" $'#!/bin/zsh\nprint -r -- "${(j:|:)@}" >> "$XCRUN_TEST_LOG"' || return
  test_write_file "$fake_bin/open" $'#!/bin/zsh\nprint -r -- "${(j:|:)@}" >> "$OPEN_TEST_LOG"' || return
  command chmod +x "$fake_bin/xcodebuild" "$fake_bin/xcrun" "$fake_bin/open" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export XCODE_PRODUCTS=$3 XCODE_TEST_LOG=$4 XCRUN_TEST_LOG=$5 OPEN_TEST_LOG=$6
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_run_simulator project /example/App.xcodeproj App \
      "iOS Simulator" SIM-456
  ' "$TEST_REPO_ROOT" "$fake_bin" "$products" "$xcode_log" "$xcrun_log" "$open_log") || return
  test_assert_equal '' "$output" 'simulator coordinator emitted captured provider output' || return
  local xcrun_invocations=$(<"$xcrun_log")
  test_assert_contains "$xcrun_invocations" 'simctl|boot|SIM-456' 'simulator was not booted' || return
  test_assert_contains "$xcrun_invocations" 'simctl|bootstatus|SIM-456|-b' 'boot was not awaited' || return
  test_assert_contains "$xcrun_invocations" "simctl|install|SIM-456|$app" \
    'exact built app was not installed' || return
  test_assert_contains "$xcrun_invocations" 'simctl|launch|SIM-456|com.example.app' \
    'validated bundle was not launched' || return
  test_assert_equal '-a|Simulator' "$(<"$open_log")" 'Apple Simulator app was not opened explicitly'
}
test_case 'Xcode Simulator run builds installs and launches one validated app' \
  _test_xcode_simulator_run_uses_one_validated_built_application
