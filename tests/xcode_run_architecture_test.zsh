_test_xcode_run_physical_architecture() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" $'#!/bin/zsh\nprint -r -- "${(j:|:)@}" >> "$XCODE_ARCH_LOG"' || return
  command chmod +x "$TEST_TMP_DIR/bin/xcrun" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    path=("$2/bin" $path)
    export XCODE_ARCH_LOG="$2/commands"
    _xcode_action_command() { _XCODE_COMMAND=(/usr/bin/true) }
    _xcode_build_settings_capture() {
      _XCODE_APP_PATH=/example/App.app _XCODE_BUNDLE_ID=com.example.app _XCODE_PRODUCT_KIND=app
    }
    for platform in iOS tvOS watchOS visionOS; do
      _xcode_run project /example/App.xcodeproj App "$platform" EXACT-ID run Device \
        "platform=$platform,id=EXACT-ID,arch=arm64" || exit
    done
    print -r -- "$(<"$XCODE_ARCH_LOG")"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  local -a launches=("${(@f)output}")
  local -i count=0
  local row=''
  for row in "${launches[@]}"; do
    [[ $row == 'devicectl|device|process|launch|--device|EXACT-ID|--terminate-existing|--console|--arch|arm64|com.example.app' ]] && (( ++count ))
  done
  test_assert_equal 4 "$count" 'physical launch did not preserve the captured architecture on every platform'
}
test_case 'Xcode Run architecture reaches physical device launch' _test_xcode_run_physical_architecture

_test_xcode_run_simulator_architecture() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" $'#!/bin/zsh\nprint -r -- "${(j:|:)@}" >> "$XCODE_ARCH_LOG"\ncase $2 in\n  boot) exit ${BOOT_STATUS:-0} ;;\n  getenv)\n    if [[ $4 == SIMULATOR_RUNTIME_VERSION ]]; then\n      print -r -- "$RUNTIME_VERSION"; exit ${VERSION_STATUS:-0}\n    fi\n    [[ -n $RUNNING_ARCH ]] && print -r -- "$RUNNING_ARCH"; exit ${ARCH_STATUS:-0} ;;\nesac\nexit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/xcrun" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    path=("$2/bin" $path)
    export XCODE_ARCH_LOG="$2/commands"
    _xcode_action_command() { _XCODE_COMMAND=(/usr/bin/true) }
    _xcode_build_settings_capture() {
      _XCODE_APP_PATH=/example/App.app _XCODE_BUNDLE_ID=com.example.app _XCODE_PRODUCT_KIND=app
    }
    _xcode_open_simulator() { print OPEN >> "$XCODE_ARCH_LOG" }
    for scenario in matching booted modern multiple legacy_multiple mismatch failed empty malformed substring version_failed version_invalid; do
      export RUNNING_ARCH=x86_64 BOOT_STATUS=0 ARCH_STATUS=0 RUNTIME_VERSION=18.5 VERSION_STATUS=0
      case $scenario in
        booted) BOOT_STATUS=149 ;;
        modern) RUNTIME_VERSION=26.5 ;;
        multiple) RUNTIME_VERSION=26.5 RUNNING_ARCH="arm64 x86_64" ;;
        legacy_multiple) RUNNING_ARCH="arm64 x86_64" ;;
        mismatch) BOOT_STATUS=149 RUNNING_ARCH=arm64 ;;
        failed) ARCH_STATUS=9 ;;
        empty) RUNNING_ARCH="" ;;
        malformed) RUNNING_ARCH="x86_64;invalid" ;;
        substring) RUNNING_ARCH=x86_64_extra ;;
        version_failed) VERSION_STATUS=8 ;;
        version_invalid) RUNTIME_VERSION="26.invalid" ;;
      esac
      : > "$XCODE_ARCH_LOG"
      _xcode_run project /example/App.xcodeproj App "iOS Simulator" SIM-123 run Simulator \
        "platform=iOS Simulator,id=SIM-123,arch=x86_64" 2> "$2/error"
      local result=$? logged_commands="$(<"$XCODE_ARCH_LOG")" error="$(<"$2/error")"
      [[ $logged_commands == *"simctl|boot|SIM-123|--arch=x86_64"* &&
         $logged_commands == *"simctl|getenv|SIM-123|SIMULATOR_ARCHS"* ]] || {
        print -u2 -- "$scenario: selected boot architecture was not requested and checked"; exit 1
      }
      if [[ $scenario == (matching|booted|modern|multiple) ]]; then
        [[ $result == 0 && $logged_commands == *"OPEN"* &&
           $logged_commands == *"simctl|install|SIM-123|/example/App.app"* ]] || exit 2
        if [[ $scenario == (modern|multiple) ]]; then
          [[ $logged_commands == *"simctl|launch|--arch=x86_64|SIM-123|com.example.app"* ]] || exit 5
        else
          [[ $logged_commands == *"simctl|launch|SIM-123|com.example.app"* ]] || exit 6
        fi
      else
        [[ $result != 0 && $logged_commands != *"OPEN"* &&
           $logged_commands != *"|install|"* && $logged_commands != *"|launch|"* &&
           $logged_commands != *"|shutdown|"* ]] || {
          print -u2 -- "$scenario: uncertain or mismatched runtime launched or was shut down"; exit 3
        }
        if [[ $scenario == mismatch ]]; then
          [[ $error == *"SIM-123"* && $error == *"x86_64"* && $error == *"shut down"* ]] || exit 4
        fi
      fi
      print -r -- "$scenario"
    done
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal $'matching\nbooted\nmodern\nmultiple\nlegacy_multiple\nmismatch\nfailed\nempty\nmalformed\nsubstring\nversion_failed\nversion_invalid' "$output" \
    'Simulator Run did not preserve its selected architecture and stop before mismatched effects'
}
test_case 'Xcode Run architecture verifies Simulator boot before install or launch' _test_xcode_run_simulator_architecture

_test_xcode_live_launch_architecture() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/simulator/tmp" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local simulator_root="$2/simulator"
    _xcode_capture_command() {
      if [[ $3 == getenv ]]; then
        _XCODE_CAPTURE=$simulator_root
      else
        print -r -- "${(j:|:)@}"
        return 9
      fi
    }
    _xcode_run_logs_start() { return 1 }
    _xcode_run_logs_stop() { : }
    _xcode_run_live SIM-123 com.example.app Context x86_64 2>/dev/null
    print -r -- "STATUS:$?"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_contains "$output" '|--arch=x86_64|SIM-123|com.example.app' \
    'live output launch lost the requested architecture' || return
  test_assert_contains "$output" 'STATUS:9' 'live output launch lost the native failure status' || return
  local -a leftovers=("$TEST_TMP_DIR/simulator/tmp/"*(N))
  (( !${#leftovers} )) || test_fail 'failed live launch retained its temporary output directory'
}
test_case 'Xcode Run architecture reaches live Simulator launch and preserves cleanup' _test_xcode_live_launch_architecture
