_test_xcode_run_dispatches_mac_and_devices() {
  test_make_temp_dir || return
  local output=''
  test_write_file "$TEST_TMP_DIR/bin/xcodebuild" $'#!/bin/zsh\nprint -r -- "build:${(j:|:)@}"\nexit ${BUILD_STATUS:-0}' || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" $'#!/bin/zsh\n[[ $1 == --find ]] && exit ${FIND_STATUS:-0}\nprint -r -- "device:${(j:|:)@}"\n[[ $3 == install ]] && exit ${INSTALL_STATUS:-0}\nexit ${LAUNCH_STATUS:-0}' || return
  test_write_file "$TEST_TMP_DIR/bin/open" $'#!/bin/zsh\nprint -r -- "open:${(j:|:)@}"\nexit ${LAUNCH_STATUS:-0}' || return
  command chmod +x "$TEST_TMP_DIR/bin/"* || return
  command mkdir -p "$TEST_TMP_DIR/Example App.app" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2/bin" $path)
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_build_settings_capture() {
      print -r -- "settings:$4:$5"
      _XCODE_APP_PATH="$2/../Example App.app" _XCODE_BUNDLE_ID=com.example.app
      _XCODE_PRODUCT_KIND=app
    }
    for platform in macOS iOS tvOS watchOS visionOS; do
      print -r -- "PLATFORM:$platform"
      _xcode_run project "$2/Example.xcodeproj" "Example App" "$platform" EXACT-ID run "Exact destination" || exit
      _xcode_run project "$2/Example.xcodeproj" "Example App" "$platform" EXACT-ID rebuild-run "Exact destination" || exit
    done
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_contains "$output" 'open:-n|-a|' 'Mac app was not launched by exact path' || return
  for platform in iOS tvOS watchOS visionOS; do
    test_assert_contains "$output" "platform=$platform,id=EXACT-ID" 'build lost its exact platform/device' || return
  done
  test_assert_contains "$output" '|clean|build' 'Rebuild & Run omitted the ordered clean' || return
  test_assert_contains "$output" 'device:devicectl|device|install|app|--device|EXACT-ID|' 'physical app was not installed' || return
  test_assert_contains "$output" 'device:devicectl|device|process|launch|--device|EXACT-ID|--terminate-existing|--console|com.example.app' 'physical app was not launched on the exact device' || return
  [[ $output != *simctl* && $output != *allowProvisioning* ]] || test_fail 'Mac/device Run used Simulator or changed signing policy'
}
test_case 'Xcode destination Run builds and launches Mac and physical applications' _test_xcode_run_dispatches_mac_and_devices

_test_xcode_run_stops_at_failed_boundaries() {
  test_make_temp_dir || return
  local output=''
  test_write_file "$TEST_TMP_DIR/bin/xcodebuild" $'#!/bin/zsh\nprint BUILD\nexit ${BUILD_STATUS:-0}' || return
  test_write_file "$TEST_TMP_DIR/bin/xcrun" $'#!/bin/zsh\n[[ $1 == --find ]] && exit ${FIND_STATUS:-0}\n[[ $3 == install ]] && { print INSTALL; exit ${INSTALL_STATUS:-0}; }\nprint LAUNCH\nexit ${LAUNCH_STATUS:-0}' || return
  test_write_file "$TEST_TMP_DIR/bin/open" $'#!/bin/zsh\nprint OPEN\nexit ${LAUNCH_STATUS:-0}' || return
  command chmod +x "$TEST_TMP_DIR/bin/"* || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2/bin" $path)
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_build_settings_capture() {
      print SETTINGS
      _XCODE_APP_PATH=/example/App.app _XCODE_BUNDLE_ID=com.example.app _XCODE_PRODUCT_KIND=app
      return ${SETTINGS_STATUS:-0}
    }
    for failure in FIND BUILD SETTINGS INSTALL LAUNCH; do
      export FIND_STATUS=0 BUILD_STATUS=0 SETTINGS_STATUS=0 INSTALL_STATUS=0 LAUNCH_STATUS=0
      export "${failure}_STATUS=7"
      print -r -- "CASE:$failure"
      _xcode_run project /example/App.xcodeproj App iOS DEVICE-123 run 2>/dev/null
      print -r -- "STATUS:$?"
    done
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal $'CASE:FIND\nSTATUS:1\nCASE:BUILD\nBUILD\nSTATUS:7\nCASE:SETTINGS\nBUILD\nSETTINGS\nSTATUS:7\nCASE:INSTALL\nBUILD\nSETTINGS\nINSTALL\nSTATUS:7\nCASE:LAUNCH\nBUILD\nSETTINGS\nINSTALL\nLAUNCH\nSTATUS:7' "$output" \
    'Run continued after a failed boundary or lost its native failure status'
}
test_case 'Xcode destination Run stops on missing tools and build product install launch failures' _test_xcode_run_stops_at_failed_boundaries

_test_xcode_destination_parser_retains_variants() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _xcode_destinations_parse "$(print -rl -- \
      "{ platform:macOS, arch:arm64, id:MAC-123, name:My Mac }" \
      "{ platform:macOS, arch:x86_64, id:MAC-123, name:My Mac }" \
      "{ platform:macOS, arch:arm64, variant:macOS, id:MAC-123, name:My Mac }" \
      "{ platform:macOS, arch:arm64, variant:Mac Catalyst, id:MAC-123, name:My Mac }" \
      "{ platform:macOS, arch:arm64, variant:Designed for [iPad,iPhone], id:MAC-123, name:My Mac }" \
      "{ platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }")" || exit
    print -rl -- "${_XCODE_DESTINATION_SPECS[@]}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'platform=macOS,id=MAC-123,arch=arm64' 'native Mac destination was lost' || return
  test_assert_contains "$output" 'platform=macOS,id=MAC-123,arch=x86_64' 'Rosetta destination was deduplicated by ID' || return
  test_assert_contains "$output" 'variant=macOS' 'documented native macOS variant was rejected' || return
  test_assert_contains "$output" 'variant=Mac Catalyst' 'Mac Catalyst destination was deduplicated by ID' || return
  test_assert_contains "$output" 'variant=Designed for iPad' 'Designed for iPad destination was lost' || return
  [[ $output != *placeholder* ]] || test_fail 'generic build-only placeholder was offered as a concrete destination'
}
test_case 'Xcode destination capture preserves architecture and Mac variants as distinct choices' _test_xcode_destination_parser_retains_variants

_test_xcode_destination_vision_compatible_variants() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    for platform in visionOS "visionOS Simulator"; do
      _xcode_destinations_parse "{ platform:$platform, arch:arm64, variant:Designed for [iPad,iPhone], id:VISION-123, OS:2.0, name:Apple Vision Pro }" || exit 1
      local spec="platform=$platform,id=VISION-123,arch=arm64,variant=Designed for iPad"
      [[ ${_XCODE_DESTINATION_SPECS[1]} == "$spec" ]] || exit 2
      for action in build test; do
        _xcode_action_command project /example/App.xcodeproj App "$platform" VISION-123 "$action" "$spec" || exit 3
        [[ ${_XCODE_COMMAND[7]} == "$spec" ]] || exit 4
      done
      print -r -- "$spec"
    done
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'platform=visionOS,id=VISION-123,arch=arm64,variant=Designed for iPad\nplatform=visionOS Simulator,id=VISION-123,arch=arm64,variant=Designed for iPad' "$output" \
    'compatible iPad destinations on Vision Pro were dropped or changed'
}
test_case 'Xcode destination retains compatible iPad variants on Vision Pro and Simulator' _test_xcode_destination_vision_compatible_variants

_test_xcode_mac_command_line_product() {
  test_make_temp_dir || return
  local output=''
  test_write_file "$TEST_TMP_DIR/hello tool" $'#!/bin/zsh\nprint TOOL-RAN\nexit 6' || return
  command chmod +x "$TEST_TMP_DIR/hello tool" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    # The command spy supplies bounded native settings, with no Xcode execution.
    local product_root=$2
    _xcode_capture_command() {
      _XCODE_CAPTURE="[{\"buildSettings\":{\"MACH_O_TYPE\":\"mh_execute\",\"TARGET_BUILD_DIR\":\"$product_root\",\"FULL_PRODUCT_NAME\":\"hello tool\"}}]"
    }
    _xcode_build_settings_capture project /example/App.xcodeproj Tool macOS MAC-123 || exit
    print -r -- "$_XCODE_PRODUCT_KIND|$_XCODE_APP_PATH"
    _xcode_action_command() { _XCODE_COMMAND=(/usr/bin/true) }
    _xcode_run project /example/App.xcodeproj Tool macOS MAC-123
    print -r -- "STATUS:$?"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal "tool|$TEST_TMP_DIR/hello tool"$'\nTOOL-RAN\nSTATUS:6' "$output" 'Mac command-line product was not run with its exit status'
}
test_case 'Xcode destination Run executes a built Mac command-line product and preserves its status' _test_xcode_mac_command_line_product

_test_xcode_run_rejects_ambiguous_products() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/A.app" "$TEST_TMP_DIR/B.app" || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local products=$2
    _xcode_capture_command() {
      _XCODE_CAPTURE="[{\"buildSettings\":{\"WRAPPER_EXTENSION\":\"app\",\"TARGET_BUILD_DIR\":\"$products\",\"FULL_PRODUCT_NAME\":\"A.app\",\"PRODUCT_BUNDLE_IDENTIFIER\":\"com.example.a\"}},{\"buildSettings\":{\"WRAPPER_EXTENSION\":\"app\",\"TARGET_BUILD_DIR\":\"$products\",\"FULL_PRODUCT_NAME\":\"B.app\",\"PRODUCT_BUNDLE_IDENTIFIER\":\"com.example.b\"}}]"
    }
    _xcode_build_settings_capture project /example/App.xcodeproj App macOS MAC-123
    print -r -- "$?|$_XCODE_APP_PATH|$_XCODE_CAPTURE_ERROR"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_contains "$output" '1||multiple runnable products' 'ambiguous build silently chose the first app'
}
test_case 'Xcode destination Run requires an explicit choice when multiple products are built' _test_xcode_run_rejects_ambiguous_products

_test_xcode_destination_spec_reaches_every_action() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local spec="platform=macOS,id=MAC-123,arch=arm64,variant=Mac Catalyst"
    for action in build rebuild test rebuild-test analyze clean; do
      _xcode_action_command project /example/App.xcodeproj App macOS MAC-123 "$action" "$spec" || { print -u2 -- "rejected valid action:$action:$spec"; exit 1; }
      [[ ${_XCODE_COMMAND[6]} == -destination && ${_XCODE_COMMAND[7]} == "$spec" ]] || {
        print -u2 -r -- "bad command:${(j:|:)_XCODE_COMMAND}"; exit 1
      }
    done
    for invalid in "$spec,foo=bar" "$spec,arch=x86_64" "$spec," "platform=macOS,id=OTHER" "platform=macOS,id=MAC-123,arch=arm64,,variant=Mac Catalyst"; do
      _xcode_action_command project /example/App.xcodeproj App macOS MAC-123 build "$invalid" && {
        print -u2 -r -- "accepted:$invalid"; exit 1
      }
      (( !${#_XCODE_COMMAND} )) || { print -u2 -- "retained command:$invalid"; exit 2; }
    done
    print exact
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal exact "$output" 'destination specification changed between selection and action'
}
test_case 'Xcode destination actions preserve exact variants and reject injected selectors' _test_xcode_destination_spec_reaches_every_action

_test_xcode_destination_variant_refresh_and_cache() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    _XCODE_CONTAINERS=(/example/App.xcodeproj) _XCODE_CONTAINER_KINDS=(project)
    local -i captures=0 step=0
    _xcode_schemes_capture() { _XCODE_SCHEMES=(App) }
    _xcode_destinations_capture() {
      (( ++captures ))
      local first="{ platform:macOS, arch:arm64, id:MAC-123, name:My Mac }"
      local catalyst="{ platform:macOS, arch:arm64, variant:Mac Catalyst, id:MAC-123, name:My Mac }"
      if (( captures == 1 )); then
        _xcode_destinations_parse "$first"$'\''\n'\''"$catalyst"
      else
        _xcode_destinations_parse "$catalyst"$'\''\n'\''"$first"
      fi
    }
    _xcode_choose() {
      if [[ $1 == "Xcode / Destination" ]]; then
        _ZLE_PICKER_SELECTED_VALUE=2
      elif [[ $1 == "Xcode / Scheme" ]]; then
        _ZLE_PICKER_SELECTED_VALUE=1
      else
        (( ++step ))
        case $step in
          1) _ZLE_PICKER_SELECTED_VALUE=destination ;;
          2) _ZLE_PICKER_SELECTED_VALUE=refresh-destinations ;;
          3) [[ $_XCODE_ACTION_CONTEXT == *"variant=Mac Catalyst"* ]] || return 9
             _ZLE_PICKER_SELECTED_VALUE=scheme ;;
          4) [[ $_XCODE_ACTION_CONTEXT == *"variant=Mac Catalyst"* ]] || return 10
             _ZLE_PICKER_SELECTED_VALUE=run ;;
        esac
      fi
      return 0
    }
    _xcode_workspace_controller || exit
    print -r -- "$captures|$_XCODE_SELECTED_SPEC"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '2|platform=macOS,id=MAC-123,arch=arm64,variant=Mac Catalyst' "$output" \
    'refresh or cached scheme restoration switched between same-ID Mac variants'
}
test_case 'Xcode destination refresh and cache retain the exact selected Mac variant' _test_xcode_destination_variant_refresh_and_cache

_test_xcode_destination_cache_rejects_missing_spec() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    local -a _XCODE_DESTINATION_CACHE_SCHEMES=(App)
    local -a _XCODE_DESTINATION_CACHE_IDS=(MAC-123)
    local -a _XCODE_DESTINATION_CACHE_PLATFORMS=(macOS)
    local -a _XCODE_DESTINATION_CACHE_NAMES=("My Mac · Mac Catalyst")
    local -a _XCODE_DESTINATION_CACHE_SPECS=("")
    _xcode_destination_cache_restore App
    print -r -- "$?"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 1 "$output" 'a missing cached specification silently selected the native Mac variant'
}
test_case 'Xcode destination cache rejects a missing exact specification' _test_xcode_destination_cache_rejects_missing_spec

_test_xcode_product_choice_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/First.app" "$TEST_TMP_DIR/home/Second.app" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.xcode"
    zmodload zsh/zpty zsh/zselect
    command mkfifo "$HOME/events"
    exec {events}<> "$HOME/events"
    local event="" trace="" chunk="" scenario="" device=""
    local -i pfd=0
    _xcode_capture_command() {
      _XCODE_CAPTURE="[{\"buildSettings\":{\"WRAPPER_EXTENSION\":\"app\",\"TARGET_BUILD_DIR\":\"$HOME\",\"FULL_PRODUCT_NAME\":\"First.app\",\"PRODUCT_BUNDLE_IDENTIFIER\":\"com.example.first\"}},{\"buildSettings\":{\"WRAPPER_EXTENSION\":\"app\",\"TARGET_BUILD_DIR\":\"$HOME\",\"FULL_PRODUCT_NAME\":\"Second.app\",\"PRODUCT_BUNDLE_IDENTIFIER\":\"com.example.second\"}}]"
    }
    functions[_product_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _product_show
      print -r -u $events -- "FRAME:$_ZLE_PICKER_TITLE:$COLUMNS:${_ZLE_PICKER_DISPLAY[-1]}"
    }
    # Inspect the actual editor payload at paint, including resize-triggered
    # refreshes, instead of treating a frame/dimension notification as proof.
    zle() {
      if [[ $1 == -R && -n ${POSTDISPLAY:-} &&
            $PREDISPLAY$POSTDISPLAY == "$_ZLE_PICKER_POSTDISPLAY" &&
            $_ZLE_PICKER_TITLE == "Xcode / Run product" ]]; then
        local painted="$PREDISPLAY$POSTDISPLAY" row=""
        [[ $painted == *"Xcode / Run product"* &&
           $painted == *First.app* && $painted == *Second.app* &&
           $painted == *"⏎ run"* && -z $BUFFER && $CURSOR == 0 ]] ||
          print -r -u $events BAD-PAINT
        for row in ${(f)painted}; do
          (( ${(m)#row} < COLUMNS )) || print -r -u $events BAD-ROW-WIDTH
        done
        print -r -u $events -- "PAINT:$COLUMNS"
      fi
      builtin zle "$@"
    }
    _driver() {
      command stty rows 24 cols 110
      local before=$(command stty -g) result=0
      local saved_buffer=$BUFFER saved_predisplay=$PREDISPLAY saved_postdisplay=$POSTDISPLAY
      local saved_prompt=$PROMPT saved_rprompt=$RPROMPT
      print -r -u $events -- "READY:$(command tty)"
      _xcode_build_settings_capture project /example/App.xcodeproj App macOS MAC-123
      result=$?
      (( result )) && print -u2 -r -- "product result: $result $_XCODE_CAPTURE_ERROR"
      (( _ZLE_PICKER_ACTIVE == 0 && _ZLE_PICKER_SCREEN_ACTIVE == 0 )) || result=99
      [[ $(command stty -g) == "$before" ]] || result=98
      [[ $BUFFER == "$saved_buffer" && $PREDISPLAY == "$saved_predisplay" &&
         $POSTDISPLAY == "$saved_postdisplay" && $PROMPT == "$saved_prompt" &&
         $RPROMPT == "$saved_rprompt" && -z $_ZLE_PICKER_POSTDISPLAY ]] || result=97
      print -r -u $events -- "DONE:$result:$_XCODE_APP_PATH:$_XCODE_BUNDLE_ID"
    }
    _event() {
      while zselect -r $events $pfd -t 300; do
        while zpty -r product chunk; do trace+=$chunk; done
        IFS= read -r -t 0 -u $events event && return 0
      done
      print -u2 -- "product view timed out: $event; ${(V)trace[-800,-1]}"
      return 1
    }
    _until() {
      while _event; do
        [[ $event == ${~1} ]] && return 0
        [[ $event == (DONE:*|BAD-*) ]] && break
      done
      print -u2 -- "expected $1; got $event; ${(V)trace[-1200,-1]}"
      return 1
    }
    {
      print -r -- "exec {events}<> ${(q)HOME}/events"
      for unit in "$1/.zsh.addons/.zsh.editor" "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.) "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix" "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw" "$1/.zsh.addons/support/.zsh.appearance" "$1/.zsh.addons/.zsh.xcode"; do
        print -r -- "source ${(q)unit}"
      done
      functions _xcode_capture_command _product_show _zle_picker_show zle _driver
      print -r -- _driver
    } > "$HOME/session.zsh"
    for scenario in choose cancel replaced; do
      zpty -b product "$2" -dfi || exit 1
      pfd=$REPLY
      zpty -w product "source ${(q)HOME}/session.zsh"
      {
        _until "READY:*" || exit 2
        device=${event#READY:}
        [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 3
        _until "FRAME:Xcode / Run product:*" || exit 4
        [[ $event == *"⏎ run"* ]] || { print -u2 "product choice did not name Run"; exit 5; }
        if [[ $scenario == choose ]]; then
          command stty rows 12 cols 40 < "$device"
          _until "PAINT:40" || exit 11
          _until "FRAME:Xcode / Run product:40:*" || exit 6
          zpty -w -n product 2
          _until "DONE:0:$HOME/Second.app:com.example.second" || exit 7
        elif [[ $scenario == cancel ]]; then
          zpty -w -n product $'\''\e'\''
          _until "DONE:130::" || exit 8
        else
          command rmdir "$HOME/Second.app"
          command ln -s "$HOME/First.app" "$HOME/Second.app"
          zpty -w -n product 2
          _until "DONE:1::" || exit 9
        fi
      } always {
        zpty -d product
      }
    done
    [[ $trace == *$'\''\e[?1049h'\''* && $trace == *$'\''\e[?1049l'\''* &&
       $trace != *"command not found"* && $trace != *"bad math"* &&
       $trace != *"read-only variable"* && $trace != *"error in flags"* ]] || exit 10
    print product-choice
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN") || return
  test_assert_equal product-choice "$output" 'native product choice lost selection cancellation or leaf revalidation'
}
test_case 'Xcode destination Run product native screen supports exact selection resize cancellation and replacement refusal' _test_xcode_product_choice_native
