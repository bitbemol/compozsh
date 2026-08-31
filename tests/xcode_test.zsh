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

_test_xcode_test_result_capture_retains_failures_and_files() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" bundle="$TEST_TMP_DIR/Test.xcresult"
  local summary="$TEST_TMP_DIR/summary.json" details="$TEST_TMP_DIR/details.json"
  local build="$TEST_TMP_DIR/build.json"
  command mkdir -p -- "$bundle" || return
  test_write_file "$summary" '{
    "result":"Failed","totalTestCount":2,"passedTests":1,
    "failedTests":1,"skippedTests":0,"expectedFailures":0,
    "testFailures":[{
      "testName":"WidgetTests.testRendering()","targetName":"WidgetTests",
      "failureText":"Expected the rendered value to match.",
      "testIdentifierString":"WidgetTests/testRendering()"
    }]
  }' || return
  test_write_file "$details" '{
    "testRuns":[{
      "nodeType":"Test Case Run","name":"testRendering()","children":[{
        "nodeType":"Failure Message","name":"Expected the rendered value to match.",
        "sourceLocation":{"filePath":"/project/Tests/WidgetTests.swift","lineNumber":42}
      }]
    }]
  }' || return
  test_write_file "$build" '{
    "errors":[{
      "issueType":"Swift Compiler Error","message":"Cannot find WidgetFactory in scope",
      "targetName":"App","sourceURL":"file:///project/Sources/Widget.swift#StartingLineNumber=12"
    }]
  }' || return
  test_write_file "$fake_bin/xcrun" $'#!/bin/zsh -df\ncase "${(j: :)@}" in\n  (*"test-results summary"*) command cat -- "$XCODE_SUMMARY" ;;\n  (*"test-results test-details"*) command cat -- "$XCODE_DETAILS" ;;\n  (*"build-results"*) command cat -- "$XCODE_BUILD" ;;\n  (*) exit 2 ;;\nesac' || return
  command chmod +x "$fake_bin/xcrun" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export XCODE_SUMMARY=$4 XCODE_DETAILS=$5 XCODE_BUILD=$6
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_test_result_capture "$3" 65 || exit
    print -r -- "result:$_XCODE_TEST_RESULT|$_XCODE_TEST_TOTAL|$_XCODE_TEST_PASSED|$_XCODE_TEST_FAILED"
    print -r -- "failure:${_XCODE_TEST_FAILURE_NAMES[1]}|${_XCODE_TEST_FAILURE_TARGETS[1]}"
    print -r -- "reason:${_XCODE_TEST_FAILURE_TEXTS[1]}"
    print -r -- "file:${_XCODE_TEST_FAILURE_FILES[1]}"
    print -r -- "build:${_XCODE_TEST_BUILD_NAMES[1]}|${_XCODE_TEST_BUILD_TEXTS[1]}|${_XCODE_TEST_BUILD_FILES[1]}"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$bundle" "$summary" "$details" "$build") || return

  test_assert_contains "$output" 'result:Failed|2|1|1' \
    'Xcode test summary counts were not retained' || return
  test_assert_contains "$output" 'failure:WidgetTests.testRendering()|WidgetTests' \
    'failed Xcode test identity was not retained' || return
  test_assert_contains "$output" 'reason:Expected the rendered value to match.' \
    'failed Xcode test reason was not retained' || return
  test_assert_contains "$output" 'file:/project/Tests/WidgetTests.swift:42' \
    'failed Xcode test source location was not retained' || return
  test_assert_contains "$output" \
    'build:Swift Compiler Error · App|Cannot find WidgetFactory in scope|/project/Sources/Widget.swift#StartingLineNumber=12' \
    'Xcode build-stage failure and involved file were not retained'
}
test_case 'Xcode test results retain failure reasons and involved files' \
  _test_xcode_test_result_capture_retains_failures_and_files

_test_xcode_test_result_screen_uses_shared_semantic_roles() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_TEST_SCHEME=App _XCODE_TEST_DESTINATION="iPhone 18 Pro"
    _XCODE_TEST_RESULT=Failed _XCODE_TEST_TOTAL=2 _XCODE_TEST_PASSED=1
    _XCODE_TEST_FAILED=1 _XCODE_TEST_SKIPPED=0 _XCODE_TEST_EXPECTED_FAILURES=0
    _XCODE_TEST_FAILURE_NAMES=("WidgetTests.testRendering()")
    _XCODE_TEST_FAILURE_TARGETS=(WidgetTests)
    _XCODE_TEST_FAILURE_TEXTS=("Expected matching output")
    _XCODE_TEST_FAILURE_FILES=("/project/Tests/WidgetTests.swift:42")
    _XCODE_TEST_BUILD_NAMES=() _XCODE_TEST_BUILD_TEXTS=() _XCODE_TEST_BUILD_FILES=()
    _zle_picker_loop() {
      print -r -- "title:$_ZLE_PICKER_TITLE"
      print -r -- "subtitle:$_ZLE_PICKER_SUBTITLE"
      print -r -- "labels:${(j:|:)_XCODE_PICKER_LABELS}"
      print -r -- "failure-style:${_ZLE_PICKER_LABEL_HIGHLIGHTS[failure:1]}"
      print -r -- "details:${_ZLE_PICKER_INSPECT_TEXTS[failure:1]}"
      return 0
    }
    _xcode_test_result_screen 65
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'title:Xcode Test · Failed' \
    'failed Xcode test result title is not explicit' || return
  test_assert_contains "$output" 'subtitle:App · iPhone 18 Pro · FAILED' \
    'failed Xcode test result lost its exact target' || return
  test_assert_contains "$output" 'failure-style:0:' \
    'failed Xcode test row has no semantic highlight' || return
  test_assert_contains "$output" ':picker-error' \
    'failed Xcode test row does not use the shared error role' || return
  test_assert_contains "$output" 'Expected matching output' \
    'failed Xcode test details omit the reason' || return
  test_assert_contains "$output" '/project/Tests/WidgetTests.swift:42' \
    'failed Xcode test details omit the involved file'
}
test_case 'Xcode test failure window uses shared error styling and exact details' \
  _test_xcode_test_result_screen_uses_shared_semantic_roles

_test_xcode_test_success_screen_uses_shared_semantic_role() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_TEST_SCHEME=App _XCODE_TEST_DESTINATION="My Mac"
    _XCODE_TEST_RESULT=Passed _XCODE_TEST_TOTAL=24 _XCODE_TEST_PASSED=24
    _XCODE_TEST_FAILED=0 _XCODE_TEST_SKIPPED=0 _XCODE_TEST_EXPECTED_FAILURES=0
    _XCODE_TEST_FAILURE_NAMES=() _XCODE_TEST_FAILURE_TARGETS=()
    _XCODE_TEST_FAILURE_TEXTS=() _XCODE_TEST_FAILURE_FILES=()
    _XCODE_TEST_BUILD_NAMES=() _XCODE_TEST_BUILD_TEXTS=() _XCODE_TEST_BUILD_FILES=()
    _zle_picker_loop() {
      print -r -- "title:$_ZLE_PICKER_TITLE"
      print -r -- "summary:${_ZLE_PICKER_PASSIVE_LINES[1]}"
      print -r -- "style:${_ZLE_PICKER_PASSIVE_STYLES[1]}"
      return 0
    }
    _xcode_test_result_screen 0
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'title:Xcode Test · Passed' \
    'successful Xcode test result title is not explicit' || return
  test_assert_contains "$output" 'summary:All tests passed · 24 of 24 passed' \
    'successful Xcode test result omitted its totals' || return
  test_assert_contains "$output" 'style:picker-success' \
    'successful Xcode test result does not use the shared success role'
}
test_case 'Xcode test success window uses the shared success styling' \
  _test_xcode_test_success_screen_uses_shared_semantic_role

_test_xcode_test_execution_streams_and_cleans_result_bundle() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" invocation="$TEST_TMP_DIR/invocation"
  local bundle_log="$TEST_TMP_DIR/bundle-path" temp_root="$TEST_TMP_DIR/temp"
  command mkdir -p -- "$temp_root" || return
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh -df\nprint -rl -- "$@" >| "$XCODE_INVOCATION"\nprevious=""\nfor argument in "$@"; do\n  if [[ $previous == -resultBundlePath ]]; then\n    command mkdir -p -- "$argument" || exit 9\n    print -r -- "$argument" >| "$XCODE_BUNDLE_LOG"\n  fi\n  previous=$argument\ndone\nprint -r -- "native xcodebuild output"\nexit 65' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export TMPDIR=$3 XCODE_INVOCATION=$4 XCODE_BUNDLE_LOG=$5
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_test_result_capture() {
      [[ -d $1 && $2 == 65 ]] || return 99
      _XCODE_TEST_RESULT=Failed
    }
    _xcode_test_execute project /example/App.xcodeproj App macOS MAC-123 "My Mac"
    print -r -- "status=$?"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$temp_root" "$invocation" "$bundle_log") || return

  test_assert_contains "$output" 'native xcodebuild output' \
    'Xcode test execution hid the native stream' || return
  test_assert_contains "$output" 'status=65' \
    'Xcode test execution did not preserve the native failure status' || return
  local arguments=$(<"$invocation") bundle=$(<"$bundle_log")
  test_assert_contains "$arguments" '-resultBundlePath' \
    'Xcode test execution did not request a structured result bundle' || return
  test_assert_contains "$arguments" $'-collect-test-diagnostics\nnever' \
    'Xcode test execution permits verbose failure diagnostics in its transient bundle' || return
  test_assert_equal test "${${(f)arguments}[-1]}" \
    'Xcode test action no longer follows its result-bundle option' || return
  [[ ! -e $bundle && ! -e ${bundle:h} ]] ||
    test_fail 'Xcode test execution retained its temporary result bundle'
}
test_case 'Xcode test execution preserves native output status and temporary cleanup' \
  _test_xcode_test_execution_streams_and_cleans_result_bundle

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
