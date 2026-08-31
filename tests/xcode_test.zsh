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

_test_xcode_container_revalidation_rejects_replaced_leaf() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/App.xcodeproj"
  local replacement="$TEST_TMP_DIR/Replacement.xcodeproj"
  test_write_file "$project/project.pbxproj" '// original' || return
  test_write_file "$replacement/project.pbxproj" '// replacement' || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_container_is_current project "$2"
    print -r -- "before:$?"
    command mv -- "$2" "$2.original" || exit
    command ln -s -- "$3" "$2" || exit
    _xcode_container_is_current project "$2"
    print -r -- "after:$?"
    _xcode_container_is_current workspace "$2.original"
    print -r -- "kind:$?"
  ' "$TEST_REPO_ROOT" "$project" "$replacement") || return

  test_assert_contains "$output" 'before:0' \
    'Xcode rejected an unchanged exact project container' || return
  test_assert_contains "$output" 'after:1' \
    'Xcode accepted a symlink replacement at the selected container' || return
  test_assert_contains "$output" 'kind:1' \
    'Xcode accepted a container whose suffix no longer matches its kind'
}
test_case 'Xcode selected-container revalidation rejects a replaced leaf' \
  _test_xcode_container_revalidation_rejects_replaced_leaf

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

_test_xcode_workspace_keeps_complete_large_scheme_list() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin"
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh -df\nlocal -a schemes=()\nlocal -i index=0\nfor (( index = 1; index <= 74; ++index )); do\n  schemes+=("\\\"Scheme $index\\\"")\ndone\nschemes+=("\\\"Special & <Final>\\\"")\nprint -r -- "{\\\"workspace\\\":{\\\"schemes\\\":[${(j:,:)schemes}]}}"' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_schemes_capture workspace /example/App.xcworkspace || exit
    print -r -- "${#_XCODE_SCHEMES}|${_XCODE_SCHEMES[1]}|${_XCODE_SCHEMES[-1]}"
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_equal '75|Scheme 1|Special & <Final>' "$output" \
    'Xcode scheme capture silently truncated the complete reported list'
}
test_case 'Xcode workspace retains every scheme in a large bounded response' \
  _test_xcode_workspace_keeps_complete_large_scheme_list

_test_xcode_workspace_rejects_pathological_scheme_count_without_partial_list() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin"
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh -df\nlocal -a schemes=()\nrepeat 4097 schemes+=("\\\"S\\\"")\nprint -r -- "{\\\"workspace\\\":{\\\"schemes\\\":[${(j:,:)schemes}]}}"' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_schemes_capture workspace /example/App.xcworkspace
    print -r -- "$?|${#_XCODE_SCHEMES}|$_XCODE_CAPTURE_ERROR"
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_equal \
    '1|0|Xcode reported more than 4096 schemes; none were retained' "$output" \
    'pathological Xcode scheme response was silently presented as partial'
}
test_case 'Xcode workspace fails closed instead of truncating a pathological scheme list' \
  _test_xcode_workspace_rejects_pathological_scheme_count_without_partial_list

_test_xcode_destination_parser_keeps_exact_usable_ids() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    long_os=${(l:5000::9:)}
    data=$'\''Available destinations for the "Example" scheme:\n\t\t{ platform:macOS, arch:arm64, id:MAC-123, name:My Mac }\n\t\t{ platform:iOS Simulator, arch:arm64, id:SIM-456, OS:27.0, name:iPhone 18 Pro }\n\t\t{ platform:iOS, name:Any iOS Device }\n\t\t{ platform:iOS Simulator, id:SIM-789, OS:27.0, name:Unavailable, error:iOS 27.0 is not installed }\n\t\t{ platform:iOS Simulator, id:bad/value, OS:27.0, name:Unsafe }'\''
    data+=$'\''\n\t\t{ platform:iOS Simulator, id:SIM-LONG, OS:'\''"$long_os"$'\'', name:Bounded }'\''
    _xcode_destinations_parse "$data"
    print -r -- "${#_XCODE_DESTINATION_IDS}"
    for (( i = 1; i <= ${#_XCODE_DESTINATION_IDS}; ++i )); do
      print -r -- "${_XCODE_DESTINATION_PLATFORMS[i]}|${_XCODE_DESTINATION_IDS[i]}|${_XCODE_DESTINATION_NAMES[i]}"
    done
  ' "$TEST_REPO_ROOT") || return

  local -a lines=("${(f)output}")
  test_assert_equal 3 "${lines[1]}" 'generic or unsafe Xcode destination was retained' || return
  test_assert_equal 'macOS|MAC-123|My Mac' "${lines[2]}" 'Mac destination changed' || return
  test_assert_equal 'iOS Simulator|SIM-456|iPhone 18 Pro · iOS 27.0' "${lines[3]}" \
    'Simulator destination changed' || return
  test_assert_equal 'iOS Simulator|SIM-LONG|Bounded' "${lines[4]}" \
    'oversized destination OS metadata escaped the final display bound'
}
test_case 'Xcode workspace accepts only exact destination identifiers' \
  _test_xcode_destination_parser_keeps_exact_usable_ids

_test_xcode_workspace_reuses_bounded_destination_snapshots() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj)
    _XCODE_CONTAINER_KINDS=(project)
    local -a captures=()
    local -i action_step=0 scheme_step=0 saw_refresh=0 saw_rebuild=0
    local -i saw_rebuild_test=0 saw_rebuild_run=0 preserved=0
    _xcode_schemes_capture() { _XCODE_SCHEMES=(A B) }
    _xcode_destinations_capture() {
      captures+=("$3")
      if [[ $3 == A && ${#captures} == 1 ]]; then
        _XCODE_DESTINATION_IDS=(A-first A-kept)
        _XCODE_DESTINATION_PLATFORMS=("iOS Simulator" "iOS Simulator")
        _XCODE_DESTINATION_NAMES=("A first" "A kept")
      elif [[ $3 == B ]]; then
        _XCODE_DESTINATION_IDS=(B-2)
        _XCODE_DESTINATION_PLATFORMS=("iOS Simulator")
        _XCODE_DESTINATION_NAMES=("B destination 2")
      else
        _XCODE_DESTINATION_IDS=(A-new A-kept)
        _XCODE_DESTINATION_PLATFORMS=("iOS Simulator" "iOS Simulator")
        _XCODE_DESTINATION_NAMES=("A new" "A kept refreshed")
      fi
    }
    _xcode_choose() {
      case $1 in
        ("Xcode / Actions")
          (( ${_XCODE_PICKER_VALUES[(Ie)refresh-destinations]} )) && saw_refresh=1
          (( ${_XCODE_PICKER_VALUES[(Ie)rebuild]} )) && saw_rebuild=1
          (( ${_XCODE_PICKER_VALUES[(Ie)rebuild-test]} )) && saw_rebuild_test=1
          (( ${_XCODE_PICKER_VALUES[(Ie)rebuild-run]} )) && saw_rebuild_run=1
          (( ++action_step ))
          case $action_step in
            (1|2|5)
              (( action_step == 5 )) &&
                [[ ${_XCODE_PICKER_LABELS[2]} == "Destination · A kept refreshed" ]] && preserved=1
              _ZLE_PICKER_SELECTED_VALUE=scheme ;;
            (3) _ZLE_PICKER_SELECTED_VALUE=destination ;;
            (4) _ZLE_PICKER_SELECTED_VALUE=refresh-destinations ;;
            (6) _ZLE_PICKER_SELECTED_VALUE=build ;;
          esac ;;
        ("Xcode / Scheme")
          (( ++scheme_step ))
          case $scheme_step in
            (1|3) _ZLE_PICKER_SELECTED_VALUE=2 ;;
            (2) _ZLE_PICKER_SELECTED_VALUE=1 ;;
          esac ;;
        ("Xcode / Destination") _ZLE_PICKER_SELECTED_VALUE=2 ;;
      esac
      return 0
    }
    _xcode_workspace_controller || exit
    print -r -- "captures:${(j:|:)captures}"
    print -r -- "refresh:$saw_refresh"
    print -r -- "rebuild:$saw_rebuild"
    print -r -- "rebuild-test:$saw_rebuild_test"
    print -r -- "rebuild-run:$saw_rebuild_run"
    print -r -- "preserved:$preserved"
    print -r -- "action:$_XCODE_REQUEST|$_XCODE_SELECTED_SCHEME|$_XCODE_SELECTED_ID|$_XCODE_SELECTED_DESTINATION"
    action_step=5
    _xcode_workspace_controller || exit
    print -r -- "reopened:${(j:|:)captures}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'captures:A|B|A' \
    'Xcode workspace repeated a cached destination provider call' || return
  test_assert_contains "$output" 'refresh:1' \
    'Xcode workspace omitted explicit destination refresh' || return
  test_assert_contains "$output" 'rebuild:1' \
    'Xcode workspace omitted explicit Rebuild recovery' || return
  test_assert_contains "$output" 'rebuild-test:1' \
    'Xcode workspace omitted explicit Rebuild & Test recovery' || return
  test_assert_contains "$output" 'rebuild-run:1' \
    'Xcode workspace omitted explicit Rebuild & Run recovery' || return
  test_assert_contains "$output" 'preserved:1' \
    'Xcode destination refresh lost an exact surviving selection' || return
  test_assert_contains "$output" 'action:build|B|B-2|B destination 2' \
    'Xcode workspace did not restore the exact cached destination snapshot' || return
  test_assert_contains "$output" 'reopened:A|B|A|A' \
    'a second Xcode workspace reused destination state from the previous task'
}
test_case 'Xcode workspace reuses destinations per scheme and refreshes explicitly' \
  _test_xcode_workspace_reuses_bounded_destination_snapshots

_test_xcode_destination_cache_evicts_lru_inside_one_workspace() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local -a _XCODE_DESTINATION_CACHE_SCHEMES=()
    local -a _XCODE_DESTINATION_CACHE_IDS=()
    local -a _XCODE_DESTINATION_CACHE_PLATFORMS=()
    local -a _XCODE_DESTINATION_CACHE_NAMES=()
    local scheme=""
    for scheme in A B C D E; do
      _XCODE_DESTINATION_IDS=("$scheme-ID")
      _XCODE_DESTINATION_PLATFORMS=(macOS)
      _XCODE_DESTINATION_NAMES=("$scheme destination")
      _xcode_destination_cache_store "$scheme" || exit
    done
    _xcode_destination_cache_restore A
    print -r -- "A:$?"
    _xcode_destination_cache_restore B || exit
    print -r -- "B:${(j:|:)_XCODE_DESTINATION_IDS}|${(j:|:)_XCODE_DESTINATION_NAMES}"
    print -r -- "lru:${(j:|:)_XCODE_DESTINATION_CACHE_SCHEMES}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'A:1' \
    'Xcode destination cache retained more than four scheme snapshots' || return
  test_assert_contains "$output" 'B:B-ID|B destination' \
    'Xcode destination cache lost a retained exact snapshot' || return
  test_assert_contains "$output" 'lru:C|D|E|B' \
    'Xcode destination cache did not update bounded LRU order'
}
test_case 'Xcode destination snapshots use a four-scheme workspace LRU' \
  _test_xcode_destination_cache_evicts_lru_inside_one_workspace

_test_xcode_destination_refresh_forgets_snapshot_before_failed_store() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local -a _XCODE_DESTINATION_CACHE_SCHEMES=()
    local -a _XCODE_DESTINATION_CACHE_IDS=()
    local -a _XCODE_DESTINATION_CACHE_PLATFORMS=()
    local -a _XCODE_DESTINATION_CACHE_NAMES=()
    _XCODE_DESTINATION_IDS=(OLD-ID)
    _XCODE_DESTINATION_PLATFORMS=(macOS)
    _XCODE_DESTINATION_NAMES=("Old destination")
    _xcode_destination_cache_store App || exit
    _xcode_destination_cache_forget App || exit
    _XCODE_DESTINATION_IDS=(NEW-ID)
    _XCODE_DESTINATION_PLATFORMS=(macOS)
    _XCODE_DESTINATION_NAMES=("${(l:4097::x:)}")
    _xcode_destination_cache_store App
    print -r -- "store:$?"
    _xcode_destination_cache_restore App
    print -r -- "restore:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'store:1' \
    'malformed refreshed destinations were cached' || return
  test_assert_contains "$output" 'restore:1' \
    'failed destination refresh resurrected the prior snapshot'
}
test_case 'Xcode failed destination refresh cannot resurrect an old snapshot' \
  _test_xcode_destination_refresh_forgets_snapshot_before_failed_store

_test_xcode_digit_select_choosers_limit_each_visible_page_to_ten() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_PICKER_VALUES=({1..11})
    _XCODE_PICKER_LABELS=({1..11})
    _XCODE_PICKER_SEARCH=({1..11})
    _XCODE_PICKER_DETAILS=({1..11})
    _zle_picker_loop() { print -r -- "limit:$2"; return 1 }
    _xcode_choose Xcode Scope Filter
    _XCODE_TEST_PASSIVE_LINES=() _XCODE_TEST_PASSIVE_STYLES=()
    _XCODE_PICKER_HIGHLIGHTS=()
    _xcode_test_result_choose Result Scope
  ' "$TEST_REPO_ROOT") || true

  test_assert_equal $'limit:10\nlimit:10' "$output" \
    'Xcode digit-select view exposed an unreachable multi-digit row'
}
test_case 'Xcode digit-select pages expose only reachable 0–9 shortcuts' \
  _test_xcode_digit_select_choosers_limit_each_visible_page_to_ten

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
     $output != *$'\nclean\n'* &&
     $output != *'-derivedDataPath'* &&
     $output != *'-disablePackageRepositoryCache'* &&
     $output != *'-skipPackagePluginValidation'* &&
     $output != *'-skipMacroValidation'* ]] ||
    test_fail 'incremental Xcode Test changed cache, clean, or execution safety policy'
}
test_case 'Xcode workspace builds exact safe xcodebuild actions' \
  _test_xcode_action_builder_preserves_target_and_safety_policy

_test_xcode_action_keeps_hostile_project_values_as_inert_argv() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" log="$TEST_TMP_DIR/argv.log"
  local marker="$TEST_TMP_DIR/injected" project="$TEST_TMP_DIR/Weird; App.xcodeproj"
  test_write_file "$project/project.pbxproj" '// project' || return
  test_write_file "$fake_bin/xcodebuild" \
    $'#!/bin/zsh -df\nprint -rl -- "$@" >| "$XCODE_ARGV_LOG"' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export XCODE_ARGV_LOG=$4
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    hostile="App; touch $5; \$(touch $5) *"
    _xcode_action_command project "$3" "$hostile" macOS MAC-123 build || exit
    command "${_XCODE_COMMAND[@]}"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$project" "$log" "$marker" || return

  local arguments=$(<"$log")
  test_assert_contains "$arguments" "$project" \
    'Xcode changed a hostile literal project path' || return
  test_assert_contains "$arguments" 'App; touch ' \
    'Xcode changed a hostile literal scheme value' || return
  [[ ! -e $marker ]] || test_fail 'Xcode evaluated hostile project metadata'
}
test_case 'Xcode action values remain inert quoted arguments' \
  _test_xcode_action_keeps_hostile_project_values_as_inert_argv

_test_xcode_build_modes_preserve_incremental_cache_and_order_recovery() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_action_command project /example/App.xcodeproj App macOS MAC-123 \
      build || exit
    print -r -- "incremental:${(j:|:)_XCODE_COMMAND}"
    _xcode_action_command project /example/App.xcodeproj App macOS MAC-123 \
      rebuild || exit
    print -r -- "recovery:${(j:|:)_XCODE_COMMAND}"
  ' "$TEST_REPO_ROOT") || return

  local incremental=${${(f)output}[1]} recovery=${${(f)output}[2]}
  [[ $incremental == incremental:*'|build' && $incremental != *'|clean|'* ]] ||
    test_fail 'normal Xcode Build is not an incremental native build action' || return
  [[ $recovery == recovery:*'|clean|build' ]] ||
    test_fail 'Xcode Rebuild does not order clean before build' || return
  [[ $output != *'-derivedDataPath'* &&
     $output != *'-disablePackageRepositoryCache'* &&
     $output != *'COMPILATION_CACHE_ENABLE_CACHING'* ]] ||
    test_fail 'Xcode build modes replaced or disabled broader Xcode caches'
}
test_case 'Xcode Build stays incremental while Rebuild is explicit recovery' \
  _test_xcode_build_modes_preserve_incremental_cache_and_order_recovery

_test_xcode_rebuild_test_orders_clean_and_test_without_global_cache_changes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_action_command workspace /example/App.xcworkspace App macOS MAC-123 \
      rebuild-test || exit
    print -rl -- "${_XCODE_COMMAND[@]}"
  ' "$TEST_REPO_ROOT") || return

  local -a command=("${(f)output}")
  test_assert_equal clean "${command[-2]}" \
    'Xcode Rebuild & Test did not clean before testing' || return
  test_assert_equal test "${command[-1]}" \
    'Xcode Rebuild & Test did not finish with the native test action' || return
  test_assert_contains "$output" '-disableAutomaticPackageResolution' \
    'Xcode Rebuild & Test weakened package resolution policy' || return
  [[ $output != *'-derivedDataPath'* &&
     $output != *'-disablePackageRepositoryCache'* &&
     $output != *'COMPILATION_CACHE_ENABLE_CACHING'* ]] ||
    test_fail 'Xcode Rebuild & Test replaced or disabled broader Xcode caches'
}
test_case 'Xcode Rebuild & Test cleans selected products and preserves broader caches' \
  _test_xcode_rebuild_test_orders_clean_and_test_without_global_cache_changes

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
    print -r -- "identifier:${_XCODE_TEST_FAILURE_IDENTIFIERS[1]}"
    print -r -- "reason:${_XCODE_TEST_FAILURE_TEXTS[1]}"
    print -r -- "file:${_XCODE_TEST_FAILURE_FILES[1]}"
    print -r -- "build:${_XCODE_TEST_BUILD_NAMES[1]}|${_XCODE_TEST_BUILD_TEXTS[1]}|${_XCODE_TEST_BUILD_FILES[1]}"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$bundle" "$summary" "$details" "$build") || return

  test_assert_contains "$output" 'result:Failed|2|1|1' \
    'Xcode test summary counts were not retained' || return
  test_assert_contains "$output" 'failure:WidgetTests.testRendering()|WidgetTests' \
    'failed Xcode test identity was not retained' || return
  test_assert_contains "$output" 'identifier:WidgetTests/testRendering()' \
    'failed Xcode test identifier was not retained' || return
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

_test_xcode_test_report_contains_complete_retained_diagnostics() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_TEST_SCHEME="Example App"
    _XCODE_TEST_CONTAINER="/project/Example App.xcworkspace"
    _XCODE_TEST_PLATFORM="iOS Simulator"
    _XCODE_TEST_DESTINATION_ID="SIM-456"
    _XCODE_TEST_DESTINATION="iPhone 18 Pro · iOS 27.0"
    _XCODE_TEST_MODE="Rebuild & Test"
    _XCODE_TEST_RESULT=Failed
    _XCODE_TEST_TOTAL=5 _XCODE_TEST_PASSED=1 _XCODE_TEST_FAILED=2
    _XCODE_TEST_SKIPPED=1 _XCODE_TEST_EXPECTED_FAILURES=1
    _XCODE_TEST_CAPTURE_ERROR="Only the bounded structured result was retained."
    _XCODE_TEST_FAILURE_NAMES=("WidgetTests.testRendering()")
    _XCODE_TEST_FAILURE_TARGETS=(WidgetTests)
    _XCODE_TEST_FAILURE_IDENTIFIERS=("WidgetTests/testRendering()")
    _XCODE_TEST_FAILURE_TEXTS=($'\''Expected matching output.\nActual value was blue.'\'')
    _XCODE_TEST_FAILURE_FILES=($'\''/project/Tests/WidgetTests.swift:42\n/project/Sources/Widget.swift:18'\'')
    _XCODE_TEST_BUILD_NAMES=("Swift Compiler Error · App")
    _XCODE_TEST_BUILD_ERROR_TOTAL=3
    _XCODE_TEST_BUILD_TEXTS=($'\''\e[31mCannot find WidgetFactory in scope\e[0m'\'')
    _XCODE_TEST_BUILD_FILES=("/project/Sources/App.swift#StartingLineNumber=12")
    _xcode_test_report_build 65 || exit
    print -rn -- "$REPLY"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'Xcode test report' \
    'copied Xcode report omitted its identity' || return
  test_assert_contains "$output" 'Result: Failed' \
    'copied Xcode report omitted its result' || return
  test_assert_contains "$output" 'xcodebuild exit status: 65' \
    'copied Xcode report omitted the native status' || return
  test_assert_contains "$output" 'Mode: Rebuild & Test' \
    'copied Xcode report omitted its build-freshness mode' || return
  test_assert_contains "$output" 'Scheme: Example App' \
    'copied Xcode report omitted its scheme' || return
  test_assert_contains "$output" 'Container: /project/Example App.xcworkspace' \
    'copied Xcode report omitted its project container' || return
  test_assert_contains "$output" 'Destination: iPhone 18 Pro · iOS 27.0' \
    'copied Xcode report omitted its destination' || return
  test_assert_contains "$output" 'Platform: iOS Simulator' \
    'copied Xcode report omitted its platform' || return
  test_assert_contains "$output" 'Destination ID: SIM-456' \
    'copied Xcode report omitted its exact destination identifier' || return
  test_assert_contains "$output" \
    'Tests: 5 total · 1 passed · 2 failed · 1 skipped · 1 expected failure' \
    'copied Xcode report omitted summary totals' || return
  test_assert_contains "$output" \
    'native console output, attachments, and source contents are not included' \
    'copied Xcode report concealed its diagnostic scope' || return
  test_assert_contains "$output" 'Failed tests: 1 captured of 2 reported' \
    'copied Xcode report concealed bounded failed-test coverage' || return
  test_assert_contains "$output" 'WidgetTests.testRendering()' \
    'copied Xcode report omitted the failed test name' || return
  test_assert_contains "$output" 'Target: WidgetTests' \
    'copied Xcode report omitted the failed test target' || return
  test_assert_contains "$output" 'Identifier: WidgetTests/testRendering()' \
    'copied Xcode report omitted the failed test identifier' || return
  test_assert_contains "$output" $'Expected matching output.\nActual value was blue.' \
    'copied Xcode report changed a multiline failure reason' || return
  test_assert_contains "$output" '/project/Tests/WidgetTests.swift:42' \
    'copied Xcode report omitted a test source location' || return
  test_assert_contains "$output" '/project/Sources/Widget.swift:18' \
    'copied Xcode report omitted an additional test source location' || return
  test_assert_contains "$output" 'Build errors: 1 captured of 3 reported' \
    'copied Xcode report omitted its build-error section' || return
  test_assert_contains "$output" 'Cannot find WidgetFactory in scope' \
    'copied Xcode report omitted a build failure reason' || return
  [[ $output != *$'\e'* ]] ||
    test_fail 'copied Xcode report retained terminal control bytes' || return
  test_assert_contains "$output" 'Only the bounded structured result was retained.' \
    'copied Xcode report omitted its structured-result limitation'
}
test_case 'Xcode copy report retains target totals failures files and limits' \
  _test_xcode_test_report_contains_complete_retained_diagnostics

_test_xcode_test_result_screen_offers_report_only_with_clipboard() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/pbcopy" $'#!/bin/zsh -df\n/bin/cat >/dev/null' || return
  command chmod +x "$fake_bin/pbcopy" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_TEST_SCHEME=App _XCODE_TEST_DESTINATION="My Mac"
    _XCODE_TEST_RESULT=Failed _XCODE_TEST_TOTAL=1 _XCODE_TEST_FAILED=1
    _XCODE_TEST_FAILURE_NAMES=("AppTests.testLaunch()")
    _XCODE_TEST_FAILURE_TARGETS=(AppTests)
    _XCODE_TEST_FAILURE_TEXTS=("Launch failed")
    _XCODE_TEST_FAILURE_FILES=("/project/Tests/AppTests.swift:9")
    _XCODE_TEST_BUILD_NAMES=() _XCODE_TEST_BUILD_TEXTS=() _XCODE_TEST_BUILD_FILES=()
    local _XCODE_TEST_CLIPBOARD_BINARY=$2/pbcopy
    local scenario=available
    _zle_picker_loop() {
      print -r -- "$scenario-labels:${(j:|:)_XCODE_PICKER_LABELS}"
      print -r -- "copy-action:${_ZLE_PICKER_ACCEPT_LABELS[copy-report]}"
      return 0
    }
    _xcode_test_result_screen 65
    scenario=unavailable
    _XCODE_TEST_CLIPBOARD_BINARY=
    _xcode_test_result_screen 65
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_contains "$output" \
    'available-labels:[ Done ]|[ Copy report and done ]|Test failed · AppTests.testLaunch() · AppTests.swift:9' \
    'Xcode result screen omitted the explicit copy-report action' || return
  test_assert_contains "$output" 'copy-action:copy report and done' \
    'Xcode result screen did not name the copy acceptance effect' || return
  test_assert_contains "$output" \
    'unavailable-labels:[ Done ]|Test failed · AppTests.testLaunch() · AppTests.swift:9' \
    'Xcode result screen changed its non-clipboard fallback' || return
  [[ $output != *'unavailable-labels:'*'[ Copy report and done ]'* ]] ||
    test_fail 'Xcode result screen advertised a missing clipboard action'
}
test_case 'Xcode result window offers copy report when the clipboard is available' \
  _test_xcode_test_result_screen_offers_report_only_with_clipboard

_test_xcode_test_report_copy_writes_exact_report_without_newline() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" clipboard="$TEST_TMP_DIR/clipboard"
  test_write_file "$fake_bin/pbcopy" \
    $'#!/bin/zsh -df\n/bin/cat >| "$XCODE_CLIPBOARD"' || return
  command chmod +x "$fake_bin/pbcopy" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export XCODE_CLIPBOARD=$3
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_TEST_SCHEME=App _XCODE_TEST_DESTINATION="My Mac"
    _XCODE_TEST_RESULT=Passed _XCODE_TEST_TOTAL=3 _XCODE_TEST_PASSED=3
    _xcode_test_report_copy 0 "$commands[pbcopy]" || exit
  ' "$TEST_REPO_ROOT" "$fake_bin" "$clipboard") || return

  test_assert_equal 'Copied Xcode test report to the clipboard.' "$output" \
    'Xcode report copy omitted its post-screen confirmation' || return
  local copied=$(<"$clipboard")
  test_assert_contains "$copied" 'Result: Passed' \
    'clipboard did not receive the rendered Xcode test report' || return
  test_assert_contains "$copied" 'Tests: 3 total · 3 passed · 0 failed' \
    'successful copied report omitted its totals' || return
  local last_byte=$(command tail -c 1 -- "$clipboard" | command od -An -tu1)
  last_byte=${last_byte//[[:space:]]/}
  [[ $last_byte != 10 ]] ||
    test_fail 'Xcode copied report gained a trailing newline'
}
test_case 'Xcode copy report writes exact plain text and confirms after cleanup' \
  _test_xcode_test_report_copy_writes_exact_report_without_newline

_test_xcode_test_result_apply_preserves_native_failure_status() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" clipboard="$TEST_TMP_DIR/clipboard"
  test_write_file "$fake_bin/pbcopy" \
    $'#!/bin/zsh -df\n/bin/cat >| "$XCODE_CLIPBOARD"' || return
  command chmod +x "$fake_bin/pbcopy" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export XCODE_CLIPBOARD=$3
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_TEST_SCHEME=App _XCODE_TEST_DESTINATION="My Mac"
    _XCODE_TEST_RESULT=Failed _XCODE_TEST_TOTAL=1 _XCODE_TEST_FAILED=1
    _XCODE_TEST_FAILURE_NAMES=("AppTests.testLaunch()")
    _XCODE_TEST_FAILURE_TARGETS=(AppTests)
    _XCODE_TEST_FAILURE_IDENTIFIERS=("AppTests/testLaunch()")
    _XCODE_TEST_FAILURE_TEXTS=("Launch failed")
    _XCODE_TEST_FAILURE_FILES=("/project/Tests/AppTests.swift:9")
    _xcode_test_result_apply 65 copy-report "$commands[pbcopy]"
    print -r -- "status=$?"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$clipboard") || return

  test_assert_contains "$output" 'Copied Xcode test report to the clipboard.' \
    'post-screen report action did not perform its explicit copy' || return
  test_assert_contains "$output" 'status=65' \
    'post-screen report action replaced the native test failure status' || return
  test_assert_contains "$(<"$clipboard")" 'AppTests.testLaunch()' \
    'post-screen report action did not copy the failed test'
}
test_case 'Xcode post-screen copy preserves the native failing test status' \
  _test_xcode_test_result_apply_preserves_native_failure_status

_test_xcode_test_result_copy_rechecks_clipboard_capability() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_TEST_RESULT=Passed _XCODE_TEST_SCHEME=App
    _XCODE_TEST_DESTINATION="My Mac"
    _xcode_test_result_apply 0 copy-report "$HOME/disappeared-pbcopy" 2>&1
    print -r -- "status=$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'pbcopy is unavailable' \
    'post-screen Xcode copy did not recheck clipboard availability' || return
  test_assert_contains "$output" 'status=1' \
    'passed Xcode test concealed a requested clipboard failure'
}
test_case 'Xcode post-screen copy fails clearly if the clipboard disappears' \
  _test_xcode_test_result_copy_rechecks_clipboard_capability

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

_test_xcode_test_execution_rejects_symlinked_result_bundle() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" temp_root="$TEST_TMP_DIR/temp"
  local old_bundle="$TEST_TMP_DIR/Old.xcresult"
  command mkdir -p -- "$temp_root" "$old_bundle" || return
  test_write_file "$old_bundle/evidence" 'keep' || return
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh -df\nprevious=""\nfor argument in "$@"; do\n  if [[ $previous == -resultBundlePath ]]; then\n    command ln -s -- "$XCODE_OLD_BUNDLE" "$argument" || exit 9\n  fi\n  previous=$argument\ndone\nexit 65' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export TMPDIR=$3 XCODE_OLD_BUNDLE=$4
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_test_result_capture() { print -r -- capture-called }
    _xcode_test_execute project /example/App.xcodeproj App macOS MAC-123 "My Mac"
    print -r -- "status:$?"
    print -r -- "result:$_XCODE_TEST_RESULT"
    print -r -- "limit:$_XCODE_TEST_CAPTURE_ERROR"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$temp_root" "$old_bundle") || return

  [[ $output != *'capture-called'* ]] ||
    test_fail 'Xcode parsed a symlinked result bundle' || return
  test_assert_contains "$output" 'status:65' \
    'Xcode lost the native status after rejecting a symlinked result' || return
  test_assert_contains "$output" 'Xcode produced no readable result bundle' \
    'Xcode did not disclose the rejected result bundle' || return
  test_assert_equal 'keep' "$(<"$old_bundle/evidence")" \
    'Xcode cleanup followed and removed a symlinked bundle target'
}
test_case 'Xcode test results reject symlink substitution without following cleanup' \
  _test_xcode_test_execution_rejects_symlinked_result_bundle

_test_xcode_rebuild_test_execution_keeps_clean_in_the_result_bundle_action() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" invocation="$TEST_TMP_DIR/invocation"
  local temp_root="$TEST_TMP_DIR/temp"
  command mkdir -p -- "$temp_root" || return
  test_write_file "$fake_bin/xcodebuild" $'#!/bin/zsh -df\nprint -rl -- "$@" >| "$XCODE_INVOCATION"\nprevious=""\nfor argument in "$@"; do\n  if [[ $previous == -resultBundlePath ]]; then\n    command mkdir -p -- "$argument" || exit 9\n  fi\n  previous=$argument\ndone\nexit 0' || return
  command chmod +x "$fake_bin/xcodebuild" || return

  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    export TMPDIR=$3 XCODE_INVOCATION=$4
    rehash
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_test_result_capture() { _XCODE_TEST_RESULT=Passed }
    _xcode_test_execute project /example/App.xcodeproj App macOS MAC-123 \
      "My Mac" rebuild-test || exit
    print -r -- "mode:$_XCODE_TEST_MODE"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$temp_root" "$invocation") || return

  local arguments=$(<"$invocation")
  test_assert_contains "$arguments" $'clean\n-collect-test-diagnostics\nnever\n-resultBundlePath' \
    'Xcode Rebuild & Test lost clean when injecting its result bundle' || return
  test_assert_equal test "${${(f)arguments}[-1]}" \
    'Xcode Rebuild & Test did not run tests after cleaning' || return
  test_assert_contains "$output" 'mode:Rebuild & Test' \
    'Xcode Rebuild & Test result lost its mode'
}
test_case 'Xcode Rebuild & Test retains ordered clean and structured results' \
  _test_xcode_rebuild_test_execution_keeps_clean_in_the_result_bundle_action

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
      "iOS Simulator" SIM-456 || exit
    _xcode_run_simulator project /example/App.xcodeproj App \
      "iOS Simulator" SIM-456 rebuild-run
  ' "$TEST_REPO_ROOT" "$fake_bin" "$products" "$xcode_log" "$xcrun_log" "$open_log") || return
  test_assert_equal '' "$output" 'simulator coordinator emitted captured provider output' || return
  local -a xcode_invocations=("${(f)$(<"$xcode_log")}")
  [[ ${xcode_invocations[1]} == *'|build' &&
     ${xcode_invocations[1]} != *'|clean|'* ]] ||
    test_fail 'Build & Run did not use the incremental Xcode build action' || return
  [[ ${xcode_invocations[3]} == *'|clean|build' ]] ||
    test_fail 'Rebuild & Run did not clean before building' || return
  [[ ${xcode_invocations[1]} != *'-derivedDataPath'* &&
     ${xcode_invocations[3]} != *'-derivedDataPath'* &&
     ${xcode_invocations[3]} != *'-disablePackageRepositoryCache'* ]] ||
    test_fail 'Simulator build modes replaced or disabled broader Xcode caches' || return
  local xcrun_invocations=$(<"$xcrun_log")
  test_assert_contains "$xcrun_invocations" 'simctl|boot|SIM-456' 'simulator was not booted' || return
  test_assert_contains "$xcrun_invocations" 'simctl|bootstatus|SIM-456|-b' 'boot was not awaited' || return
  test_assert_contains "$xcrun_invocations" "simctl|install|SIM-456|$app" \
    'exact built app was not installed' || return
  test_assert_contains "$xcrun_invocations" 'simctl|launch|SIM-456|com.example.app' \
    'validated bundle was not launched' || return
  test_assert_equal $'-a|Simulator\n-a|Simulator' "$(<"$open_log")" \
    'Apple Simulator app was not opened explicitly for both run modes'
}
test_case 'Xcode Simulator incremental and rebuild runs launch one validated app' \
  _test_xcode_simulator_run_uses_one_validated_built_application
