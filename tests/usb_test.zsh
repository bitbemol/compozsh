# Native bootable external-media creation and raw-image verification.

_test_usb_media_classifier_routes_supported_families() {
  test_make_temp_dir || return
  local installer="$TEST_TMP_DIR/Install macOS Tahoe.app"
  local raw="$TEST_TMP_DIR/linux.iso" windows="$TEST_TMP_DIR/windows.iso" output=''
  command mkdir -p "$installer/Contents/Resources" || return
  test_write_file "$installer/Contents/Resources/createinstallmedia" '#!/bin/zsh' || return
  command chmod +x "$installer/Contents/Resources/createinstallmedia" || return
  test_write_file "$raw" "${(l:20000::r:)}" || return
  test_write_file "$windows" "${(l:20000::w:)}" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_windows_installer_detect() { [[ $1 == */windows.iso ]]; }
    _usb_media_kind_capture "$2" || exit 2
    print -r -- "macos:$REPLY"
    _usb_media_kind_capture "$3" || exit 3
    print -r -- "raw:$REPLY"
    _usb_media_kind_capture "$4" || exit 4
    print -r -- "windows:$REPLY"
  ' "$TEST_REPO_ROOT" "$installer" "$raw" "$windows") || return

  test_assert_contains "$output" 'macos:macos-installer' \
    'a full macOS installer application was not routed to createinstallmedia' || return
  test_assert_contains "$output" 'raw:raw-image' \
    'a non-Windows ISO was not routed to the raw image handler' || return
  test_assert_contains "$output" 'windows:windows-installer' \
    'recognized Windows installer media was not routed to the refusal handler'
}
test_case 'USB media classifier routes raw, macOS, and Windows families explicitly' \
  _test_usb_media_classifier_routes_supported_families

_test_usb_named_windows_media_skips_native_attachment() {
  test_make_temp_dir || return
  local windows="$TEST_TMP_DIR/Win11_25H2_English_x64_v2.iso" output=''
  local linux="$TEST_TMP_DIR/ubuntu-windows-tools.iso"
  test_write_file "$windows" "${(l:20000::w:)}" || return
  test_write_file "$linux" "${(l:20000::l:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local -a trace=()
    _usb_windows_installer_detect() {
      trace+=("inspect:${1:t}")
      [[ ${1:t} == ubuntu-windows-tools.iso ]] && return 1
      return 77
    }
    _usb_media_kind_capture "$2"
    print -r -- "windows:$?:$REPLY"
    _usb_media_kind_capture "$3"
    print -r -- "linux:$?:$REPLY"
    print -r -- "trace:${(j:,:)trace}"
  ' "$TEST_REPO_ROOT" "$windows" "$linux") || return

  test_assert_contains "$output" 'windows:0:windows-installer' \
    'an unmistakably named Windows ISO did not route directly to unsupported handling' || return
  test_assert_contains "$output" 'linux:0:raw-image' \
    'a non-Windows filename containing a generic windows fragment was misclassified' || return
  test_assert_equal 'trace:inspect:ubuntu-windows-tools.iso' "${${(f)output}[-1]}" \
    'the Windows filename fast path still attached its ISO or skipped ambiguous inspection'
}
test_case 'USB unmistakable Windows filenames bypass native ISO attachment' \
  _test_usb_named_windows_media_skips_native_attachment

_test_usb_ambiguous_iso_uses_native_archive_table_without_attachment() {
  test_make_temp_dir || return
  local windows_root="$TEST_TMP_DIR/windows-tree" linux_root="$TEST_TMP_DIR/linux-tree"
  local windows_iso="$TEST_TMP_DIR/trust-me.iso" linux_iso="$TEST_TMP_DIR/rescue.iso"
  local output=''
  command mkdir -p "$windows_root/sources" "$windows_root/efi/microsoft/boot" \
    "$linux_root/boot" || return
  test_write_file "$windows_root/sources/boot.wim" boot || return
  test_write_file "$windows_root/sources/install.wim" install || return
  test_write_file "$windows_root/efi/microsoft/boot/bcd" bcd || return
  test_write_file "$linux_root/boot/kernel" linux || return
  command /usr/bin/hdiutil makehybrid -quiet -o "$windows_iso" \
    "$windows_root" -iso -joliet || return
  command /usr/bin/hdiutil makehybrid -quiet -o "$linux_iso" \
    "$linux_root" -iso -joliet || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local -a trace=()
    _usb_hdiutil_attach_readonly() {
      trace+=("attach:${1:t}")
      return 1
    }
    _usb_media_kind_capture "$2"
    print -r -- "windows:$?:$REPLY"
    _usb_media_kind_capture "$3"
    print -r -- "linux:$?:$REPLY"
    print -r -- "trace:${(j:,:)trace}"
  ' "$TEST_REPO_ROOT" "$windows_iso" "$linux_iso") || return

  test_assert_contains "$output" 'windows:0:windows-installer' \
    'an ambiguously named Windows ISO was not recognized from its archive table' || return
  test_assert_contains "$output" 'linux:0:raw-image' \
    'a parseable non-Windows ISO did not remain eligible for raw flashing' || return
  test_assert_equal 'trace:' "${${(f)output}[-1]}" \
    'a parseable ISO still entered the slow native attach/detach fallback'
}
test_case 'USB parseable ISO tables avoid native attachment without weakening detection' \
  _test_usb_ambiguous_iso_uses_native_archive_table_without_attachment

_test_usb_windows_detection_is_structural_and_always_detaches() {
  test_make_temp_dir || return
  local iso="$TEST_TMP_DIR/arbitrary-name.iso" output=''
  test_write_file "$iso" "${(l:20000::w:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local -a trace=()
    _usb_hdiutil_attach_readonly() {
      trace+=(attach-readonly)
      command mkdir -p "$2/sources" "$2/EFI/BOOT" \
        "$2/EFI/Microsoft/Boot" "$2/boot" || return
      print -r -- boot >| "$2/sources/boot.wim"
      print -r -- install >| "$2/sources/install.wim"
      print -r -- uefi >| "$2/EFI/BOOT/BOOTX64.EFI"
      print -r -- bcd >| "$2/EFI/Microsoft/Boot/BCD"
      print -r -- sdi >| "$2/boot/boot.sdi"
      _USB_INSPECT_DEVICE=disk99 _USB_INSPECT_MOUNT=$2
    }
    _usb_hdiutil_detach() {
      trace+=("detach:$1")
      command /bin/rm -f -- "$_USB_INSPECT_MOUNT/sources/boot.wim" \
        "$_USB_INSPECT_MOUNT/sources/install.wim" \
        "$_USB_INSPECT_MOUNT/EFI/BOOT/BOOTX64.EFI" \
        "$_USB_INSPECT_MOUNT/EFI/Microsoft/Boot/BCD" \
        "$_USB_INSPECT_MOUNT/boot/boot.sdi"
      command /bin/rmdir "$_USB_INSPECT_MOUNT/sources" \
        "$_USB_INSPECT_MOUNT/EFI/Microsoft/Boot" \
        "$_USB_INSPECT_MOUNT/EFI/Microsoft" "$_USB_INSPECT_MOUNT/EFI/BOOT" \
        "$_USB_INSPECT_MOUNT/EFI" "$_USB_INSPECT_MOUNT/boot"
    }
    _usb_windows_installer_detect "$2"
    print -r -- "detected:$?|${(j:,:)trace}"
    _usb_hdiutil_detach() {
      command /bin/rm -f -- "$_USB_INSPECT_MOUNT/sources/boot.wim" \
        "$_USB_INSPECT_MOUNT/sources/install.wim" \
        "$_USB_INSPECT_MOUNT/EFI/BOOT/BOOTX64.EFI" \
        "$_USB_INSPECT_MOUNT/EFI/Microsoft/Boot/BCD" \
        "$_USB_INSPECT_MOUNT/boot/boot.sdi"
      command /bin/rmdir "$_USB_INSPECT_MOUNT/sources" \
        "$_USB_INSPECT_MOUNT/EFI/Microsoft/Boot" \
        "$_USB_INSPECT_MOUNT/EFI/Microsoft" "$_USB_INSPECT_MOUNT/EFI/BOOT" \
        "$_USB_INSPECT_MOUNT/EFI" "$_USB_INSPECT_MOUNT/boot"
      return 1
    }
    _usb_windows_installer_detect "$2"
    print -r -- "detach-failure:$?"
  ' "$TEST_REPO_ROOT" "$iso") || return

  test_assert_contains "$output" 'detected:0|attach-readonly,detach:disk99' \
    'Windows detection did not require setup payload markers or release its read-only mount' || return
  test_assert_contains "$output" 'detach-failure:2' \
    'a failed read-only inspection detach did not stop the workflow safely'
}
test_case 'USB Windows detection uses setup markers and always detaches its probe' \
  _test_usb_windows_detection_is_structural_and_always_detaches

_test_usb_windows_detection_avoids_obsolete_tree_preflight() {
  test_make_temp_dir || return
  local iso="$TEST_TMP_DIR/arbitrary-name.iso" output=''
  test_write_file "$iso" "${(l:20000::w:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local -a trace=()
    _usb_hdiutil_attach_readonly() {
      command mkdir -p "$2/SOURCES" || return
      print -r -- boot >| "$2/SOURCES/BOOT.WIM"
      print -r -- install >| "$2/SOURCES/INSTALL.WIM"
      _USB_INSPECT_DEVICE=disk98 _USB_INSPECT_MOUNT=$2
    }
    _usb_hdiutil_detach() {
      trace+=("detach:$1")
      command /bin/rm -f -- "$_USB_INSPECT_MOUNT/SOURCES/BOOT.WIM" \
        "$_USB_INSPECT_MOUNT/SOURCES/INSTALL.WIM"
      command /bin/rmdir "$_USB_INSPECT_MOUNT/SOURCES"
    }
    _usb_windows_installer_detect "$2"
    print -r -- "status:$?|trace:${(j:,:)trace}"
  ' "$TEST_REPO_ROOT" "$iso") || return

  test_assert_equal 'status:0|trace:detach:disk98' "$output" \
    'Step 1 Windows detection still traversed and statted the complete ISO tree'
}
test_case 'USB Step 1 Windows detection checks bounded markers without tree preflight' \
  _test_usb_windows_detection_avoids_obsolete_tree_preflight

_test_usb_windows_partial_attach_failure_stops_classification() {
  test_make_temp_dir || return
  local iso="$TEST_TMP_DIR/windows.iso" output=''
  test_write_file "$iso" image || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local -a trace=()
    _usb_hdiutil_attach_readonly() {
      _USB_INSPECT_DEVICE=disk77
      return 2
    }
    _usb_hdiutil_detach() { trace+=("detach:$1"); return 0; }
    _usb_windows_installer_detect "$2"
    print -r -- "status:$?|trace:${(j:,:)trace}"
  ' "$TEST_REPO_ROOT" "$iso") || return

  test_assert_contains "$output" 'status:2|trace:detach:disk77' \
    'a partial ISO attach was treated as an ordinary non-Windows raw image'
}
test_case 'USB Windows classification stops after a partial ISO attach failure' \
  _test_usb_windows_partial_attach_failure_stops_classification

_test_usb_unmountable_iso_remains_raw_flashable() {
  test_make_temp_dir || return
  local iso="$TEST_TMP_DIR/linux-hybrid.iso" output=''
  test_write_file "$iso" "${(l:20000::l:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_hdiutil_attach_readonly() { return 1; }
    _usb_media_kind_capture "$2"
    print -r -- "status:$?|kind:$REPLY|error:$_USB_MEDIA_ERROR"
  ' "$TEST_REPO_ROOT" "$iso") || return

  test_assert_contains "$output" 'status:0|kind:raw-image|error:' \
    'an ISO that macOS cannot mount was blocked instead of remaining raw-flashable'
}
test_case 'USB classifier keeps an unmountable hybrid ISO eligible for raw flashing' \
  _test_usb_unmountable_iso_remains_raw_flashable

_test_usb_capture_accepts_full_macos_installer_apps() {
  test_make_temp_dir || return
  local installer="$TEST_TMP_DIR/Install macOS Tahoe.app" output=''
  command mkdir -p "$installer/Contents/Resources" || return
  test_write_file "$installer/Contents/Resources/createinstallmedia" '#!/bin/zsh' || return
  command chmod +x "$installer/Contents/Resources/createinstallmedia" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_images_capture "$2" || exit 2
    print -r -- "kind:${_USB_IMAGE_KINDS[1]}|path:${_USB_IMAGE_PATHS[1]}"
    print -r -- "label:${_USB_IMAGE_LABELS[1]}"
    print -r -- "minimum:${_USB_IMAGE_SIZES[1]}"
  ' "$TEST_REPO_ROOT" "$installer") || return

  test_assert_contains "$output" "kind:macos-installer|path:${installer:A}" \
    'explicit full macOS installer capture lost its handler identity' || return
  test_assert_contains "$output" 'label:Install macOS Tahoe.app · macOS installer' \
    'macOS installer media was not recognizable in Step 1' || return
  test_assert_contains "$output" 'minimum:15000000000' \
    'macOS target capture did not enforce Apple’s documented 16 GiB baseline'
}
test_case 'USB capture accepts full macOS installer applications as media' \
  _test_usb_capture_accepts_full_macos_installer_apps

_test_usb_apple_signature_boundary_rejects_unsigned_tools() {
  test_make_temp_dir || return
  local unsigned="$TEST_TMP_DIR/createinstallmedia" output=''
  test_write_file "$unsigned" '#!/bin/zsh' || return
  command chmod +x "$unsigned" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_codesign_is_apple /usr/bin/hdiutil
    print -r -- "apple:$?"
    _usb_codesign_is_apple "$2" >/dev/null 2>&1
    print -r -- "unsigned:$?"
  ' "$TEST_REPO_ROOT" "$unsigned") || return

  test_assert_contains "$output" 'apple:0' \
    'the Apple signature boundary rejected a native Apple code object' || return
  test_assert_contains "$output" 'unsigned:1' \
    'the Apple signature boundary accepted an unsigned createinstallmedia executable'
}
test_case 'USB macOS handler accepts Apple code and rejects unsigned tools' \
  _test_usb_apple_signature_boundary_rejects_unsigned_tools

# Ad-hoc signatures may declare any designated requirement and live under any
# path; only a requirement the caller supplies to codesign establishes Apple.
_test_usb_apple_signature_boundary_rejects_declared_requirements() {
  test_make_temp_dir || return
  local installer="$TEST_TMP_DIR/Install macOS Example.app" output='' name=''
  local -A requirements=(
    self 'designated => anchor apple'
    generic 'designated => anchor apple generic and certificate leaf[subject.OU] = "ABCDE12345"'
    store 'designated => anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */'
  )
  for name in self 'anchor apple' generic store; do
    command mkdir -p "$TEST_TMP_DIR/$name" || return
    command cp /usr/bin/true "$TEST_TMP_DIR/$name/createinstallmedia" || return
    if [[ -n ${requirements[$name]} ]]; then
      command /usr/bin/codesign -f -s - -r="${requirements[$name]}" \
        "$TEST_TMP_DIR/$name/createinstallmedia" >/dev/null 2>&1 || return
    else
      command /usr/bin/codesign -f -s - \
        "$TEST_TMP_DIR/$name/createinstallmedia" >/dev/null 2>&1 || return
    fi
  done
  command mkdir -p "$installer/Contents/MacOS" "$installer/Contents/Resources" || return
  test_write_file "$installer/Contents/Info.plist" '<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>main</string>
<key>CFBundleIdentifier</key><string>com.example.install-macos</string>
</dict></plist>' || return
  command cp /usr/bin/true "$installer/Contents/MacOS/main" || return
  command cp /usr/bin/true "$installer/Contents/Resources/createinstallmedia" || return
  command /usr/bin/codesign -f -s - -r="${requirements[self]}" \
    "$installer/Contents/Resources/createinstallmedia" >/dev/null 2>&1 || return
  command /usr/bin/codesign -f -s - -r="${requirements[self]}" \
    "$installer" >/dev/null 2>&1 || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_codesign_is_apple /usr/bin/hdiutil
    print -r -- "hdiutil:$?"
    _usb_codesign_is_apple "$2/self/createinstallmedia"
    print -r -- "self:$?"
    _usb_codesign_is_apple "$2/anchor apple/createinstallmedia"
    print -r -- "path:$?"
    _usb_codesign_is_apple "$2/generic/createinstallmedia"
    print -r -- "generic:$?"
    _usb_macos_codesign_verify "$3"
    print -r -- "bundle:$?"
    _usb_codesign_is_apple_application /usr/bin/hdiutil
    print -r -- "application-apple:$?"
    _usb_codesign_is_apple_application "$2/store/createinstallmedia"
    print -r -- "application-store:$?"
    _usb_codesign_is_apple_application "$2/generic/createinstallmedia"
    print -r -- "application-generic:$?"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" "$installer" 2>&1) || return

  test_assert_contains "$output" 'hdiutil:0' \
    'the Apple signature boundary rejected a native Apple code object' || return
  test_assert_contains "$output" 'self:1' \
    'a self-declared anchor apple requirement passed as Apple-signed' || return
  test_assert_contains "$output" 'path:1' \
    'an anchor apple path component passed as Apple-signed' || return
  test_assert_contains "$output" 'generic:1' \
    'a Developer ID-shaped requirement passed as Apple-signed' || return
  test_assert_contains "$output" 'bundle:1' \
    'a self-signed installer bundle passed as Apple-signed' || return
  test_assert_contains "$output" 'application-apple:0' \
    'the installer application boundary rejected native Apple code' || return
  test_assert_contains "$output" 'application-store:1' \
    'a self-declared Mac App Store requirement passed the installer application boundary' || return
  test_assert_contains "$output" 'application-generic:1' \
    'a Developer ID-shaped requirement passed the installer application boundary'
}
test_case 'USB Apple signature boundary rejects self-declared, path-borne and Developer ID requirements' \
  _test_usb_apple_signature_boundary_rejects_declared_requirements

_test_usb_media_dispatcher_rejects_windows_execution() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local -a trace=()
    _usb_execute() { trace+=(raw); return 0; }
    _usb_macos_execute() { trace+=(macos); return 0; }
    _usb_windows_execute() { trace+=(windows); return 0; }
    _usb_media_execute raw-image a b c || exit 2
    _usb_media_execute macos-installer a b c || exit 3
    _usb_media_execute windows-installer a b c
    print -r -- "windows-status:$?|trace:${(j:,:)trace}|error:$_USB_RESULT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'windows-status:2|trace:raw,macos|error:' \
    'the execution dispatcher still invoked the discarded Windows writer' || return
  test_assert_contains "$output" 'Windows media is unsupported on stock macOS; nothing was written' \
    'the execution boundary did not retain the Windows no-effect guarantee'
}
test_case 'USB media execution rejects the discarded Windows writer' \
  _test_usb_media_dispatcher_rejects_windows_execution

_test_usb_workspace_ends_on_windows_media_before_target_capture() {
  test_make_temp_dir || return
  local image="$TEST_TMP_DIR/windows.iso" output=''
  test_write_file "$image" "${(l:20000::w:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _USB_IMAGE_PATHS=("$2") _USB_IMAGE_LABELS=(windows.iso)
    _USB_IMAGE_HIGHLIGHTS=("") _USB_IMAGE_DETAILS=(Windows)
    _USB_IMAGE_SIZES=(20000) _USB_IMAGE_FINGERPRINTS=(fingerprint)
    _USB_IMAGE_KINDS=(raw-image) _USB_IMAGE_CAPTURE_SCOPE=test
    local -i choices=0
    local screen_values="" screen_labels="" done_detail="" passive_lines=""
    local -a trace=()
    _usb_media_kind_capture() {
      REPLY=windows-installer
    }
    _usb_target_choose() { trace+=(TARGET_CAPTURE_CALLED); return 9; }
    _usb_choose() {
      (( ++choices ))
      trace+=("screen:$1")
      if (( choices == 1 )); then
        _ZLE_PICKER_SELECTED_VALUE=image:1 _ZLE_PICKER_ACTION=accept
        return 0
      fi
      if [[ $1 == "External device / Flash · Windows unsupported" ]]; then
        screen_values=${(j:,:)_USB_PICKER_VALUES}
        screen_labels=${(j:|:)_USB_PICKER_LABELS}
        done_detail=${_USB_PICKER_DETAILS[1]}
        passive_lines=${(j:|:)_USB_PICKER_PASSIVE_LINES}
        _ZLE_PICKER_SELECTED_VALUE=done _ZLE_PICKER_ACTION=accept
        return 0
      fi
      return 1
    }
    _usb_workspace_controller >/dev/null 2>&1
    print -r -- "status:$?|trace:${(j:,:)trace}"
    print -r -- "values:$screen_values"
    print -r -- "labels:$screen_labels"
    print -r -- "passive:$passive_lines"
    print -r -- "done-detail:$done_detail"
  ' "$TEST_REPO_ROOT" "$image") || return

  test_assert_contains "$output" \
    'status:1|trace:screen:External device / Flash · Step 1 of 3,screen:External device / Flash · Windows unsupported' \
    'recognized Windows media did not end through its dedicated terminal screen' || return
  test_assert_contains "$output" 'values:done' \
    'the Windows unsupported screen did not make Done its only action' || return
  [[ $output != *'values:done,'* ]] ||
    test_fail 'the Windows explanation was exposed as numbered picker actions' || return
  test_assert_contains "$output" 'labels:Done' \
    'the Windows unsupported screen exposed selectable explanation rows' || return
  test_assert_contains "$output" 'passive:Windows USB creation is unavailable on stock macOS' \
    'the Windows explanation was not rendered as passive content' || return
  test_assert_contains "$output" 'Windows USB creation is unavailable on stock macOS' \
    'the Windows unsupported screen did not state the product boundary' || return
  test_assert_contains "$output" 'Windows Setup requires FAT32' \
    'the Windows unsupported screen omitted the portable boot requirement' || return
  test_assert_contains "$output" 'install.wim larger than 4 GiB' \
    'the Windows unsupported screen omitted the WIM size conflict' || return
  test_assert_contains "$output" 'Microsoft requires DISM on Windows' \
    'the Windows unsupported screen omitted Microsoft’s supported resolution' || return
  test_assert_contains "$output" 'Nothing was written or targeted' \
    'the Windows unsupported screen did not state its no-effect guarantee' || return
  [[ $output != *TARGET_CAPTURE_CALLED* ]] || test_fail 'Windows refusal mutated or captured a target'
}
test_case 'USB workspace ends on all Windows media before target capture' \
  _test_usb_workspace_ends_on_windows_media_before_target_capture

_test_usb_ships_no_retired_windows_writer() {
  local line='' retired=''
  local -a retired_markers=(
    _usb_windows_execute _usb_windows_source_open _usb_windows_tree_capture
    compozsh-usb-windows compozsh-windows-readonly compozsh-windows-verify
    /usr/bin/ditto /bin/sync
  )
  local -a found=()
  local -i line_number=0
  while IFS= read -r line || [[ -n $line ]]; do
    (( ++line_number ))
    for retired in "${retired_markers[@]}"; do
      if [[ $line == *"$retired"* ]]; then
        found+=("$line_number:$retired")
      fi
    done
  done < "$TEST_REPO_ROOT/.zsh.addons/.zsh.usb"
  (( ${#found} == 0 )) ||
    test_fail "the unreachable Windows writer still ships: ${(j:, :)found[1,8]}"
}
test_case 'USB ships no retired Windows writer' \
  _test_usb_ships_no_retired_windows_writer

_test_usb_windows_partial_family_fails_closed_in_dispatch() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" "$root/EFI/BOOT" \
    "$root/EFI/Microsoft/Boot" "$root/boot" || return
  test_write_file "$root/sources/boot.wim" boot || return
  test_write_file "$root/EFI/BOOT/BOOTX64.EFI" uefi || return
  test_write_file "$root/EFI/Microsoft/Boot/BCD" bcd || return
  test_write_file "$root/boot/boot.sdi" sdi || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local fixture=$3
    _usb_hdiutil_attach_readonly() {
      _USB_INSPECT_DEVICE=disk88 _USB_INSPECT_MOUNT=$2
      command /bin/cp -R "$fixture/." "$2"
    }
    _usb_hdiutil_detach() {
      command /bin/rm -rf -- "$_USB_INSPECT_MOUNT"/*(DN)
    }
    _usb_media_kind_capture "$2/image.iso"
    print -r -- "status:$?|kind:$REPLY"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" "$root") || return

  test_assert_equal 'status:0|kind:windows-installer' "$output" \
    'a partially recognizable Windows family escaped into the raw-image handler'
}
test_case 'USB partial Windows setup markers route to unsupported handling' \
  _test_usb_windows_partial_family_fails_closed_in_dispatch

_test_usb_generic_uefi_loader_does_not_claim_windows_family() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/linux" output=''
  command mkdir -p "$root/EFI/BOOT" "$root/boot" || return
  test_write_file "$root/EFI/BOOT/BOOTX64.EFI" generic-uefi || return
  test_write_file "$root/boot/boot.sdi" unrelated-name || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_windows_setup_markers_detect "$2" >/dev/null 2>&1
    print -r -- "status:$?"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_equal 'status:1' "$output" \
    'a generic UEFI removable-media loader was misclassified as partial Windows setup media'
}
test_case 'USB generic UEFI fallback loaders remain eligible for the raw image handler' \
  _test_usb_generic_uefi_loader_does_not_claim_windows_family

_test_usb_windows_family_without_uefi_fails_closed() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" || return
  test_write_file "$root/sources/boot.wim" boot || return
  test_write_file "$root/sources/install.esd" install || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_windows_setup_markers_detect "$2"
    print -r -- "status:$?"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_equal 'status:0' "$output" \
    'recognized Windows setup media without a UEFI loader escaped to raw flashing'
}
test_case 'USB Windows family detection refuses non-UEFI media instead of raw flashing' \
  _test_usb_windows_family_without_uefi_fails_closed

_test_usb_partial_inspection_cleanup_is_retriable_and_wired_outermost() {
  test_make_temp_dir || return
  local mount="$TEST_TMP_DIR/compozsh-usb-inspect.test" output=''
  command mkdir -p "$mount" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=${2:h}
    _USB_INSPECT_DEVICE=disk77 _USB_INSPECT_MOUNT=$2
    local -i detach_status=1
    _usb_hdiutil_detach() { return $detach_status; }
    _usb_inspect_cleanup >/dev/null 2>&1
    print -r -- "failed:$?|device:$_USB_INSPECT_DEVICE|mount:$_USB_INSPECT_MOUNT"
    detach_status=0
    _usb_inspect_cleanup >/dev/null 2>&1
    print -r -- "retried:$?|device:$_USB_INSPECT_DEVICE|mount:$_USB_INSPECT_MOUNT"
    print -r -- "wired:$([[ ${functions[_usb_flash]} == *_usb_inspect_cleanup* ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT" "$mount") || return

  test_assert_contains "$output" "failed:1|device:disk77|mount:$mount" \
    'failed inspection cleanup discarded its device or mount identity' || return
  test_assert_contains "$output" 'retried:0|device:|mount:' \
    'inspection cleanup did not clear state after a successful retry' || return
  test_assert_contains "$output" 'wired:yes' \
    'the public outer cleanup does not retry retained ISO inspection state'
}
test_case 'USB partial ISO inspection cleanup retains ownership through the outer boundary' \
  _test_usb_partial_inspection_cleanup_is_retriable_and_wired_outermost

_test_usb_new_iso_inspection_cannot_discard_prior_cleanup_ownership() {
  test_make_temp_dir || return
  local retained_mount="$TEST_TMP_DIR/compozsh-usb-inspect.retained"
  local next_mount="$TEST_TMP_DIR/compozsh-usb-inspect.next" output=''
  command mkdir -p "$retained_mount" "$next_mount" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=${2:h}
    _USB_INSPECT_DEVICE=disk77 _USB_INSPECT_MOUNT=$2
    _usb_hdiutil_detach() { return 1; }
    _usb_hdiutil_attach_readonly /images/next.iso "$3" >/dev/null 2>&1
    print -r -- "status:$?|device:$_USB_INSPECT_DEVICE|mount:$_USB_INSPECT_MOUNT"
  ' "$TEST_REPO_ROOT" "$retained_mount" "$next_mount") || return

  test_assert_equal "status:2|device:disk77|mount:$retained_mount" "$output" \
    'a second ISO inspection discarded retained cleanup ownership from the first'
}
test_case 'USB ISO inspection refuses a new attach while prior cleanup remains owned' \
  _test_usb_new_iso_inspection_cannot_discard_prior_cleanup_ownership

_test_usb_macos_handler_revalidates_before_destructive_effects() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local -a trace=()
    _usb_progress_stage() { return 0; }
    _usb_macos_installer_revalidate() { trace+=(installer-check); return ${installer_status:-0}; }
    _usb_target_revalidate() { trace+=(target-check); return 0; }
    _usb_macos_prepare_volume() { trace+=(prepare); REPLY=/Volumes/CompozshInstaller; return 0; }
    _usb_createinstallmedia_run() { trace+=(createinstallmedia); return 0; }
    _usb_eject() { trace+=(eject); return 0; }
    _usb_macos_execute /Applications/Install\ macOS\ Tahoe.app disk7 disk-fingerprint \
      installer-fingerprint 17179869184 flash-verify "" 1 "" "" 64000000000 || exit 2
    print -r -- "success:${(j:,:)trace}|outcome:$_USB_RESULT_OUTCOME"
    trace=() installer_status=1
    _usb_macos_execute /Applications/Install\ macOS\ Tahoe.app disk7 disk-fingerprint \
      installer-fingerprint 17179869184 flash-verify "" 1 "" "" 64000000000 >/dev/null 2>&1
    print -r -- "changed:$?|${(j:,:)trace}|started:$_USB_RESULT_STARTED"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'success:installer-check,target-check,target-check,prepare,installer-check,createinstallmedia,eject|outcome:complete' \
    'the macOS handler did not preserve its validated native-tool sequence' || return
  test_assert_contains "$output" 'changed:1|installer-check|started:0' \
    'a changed macOS installer reached a destructive handler effect'
}
test_case 'USB macOS handler closes installer and target races before erasing' \
  _test_usb_macos_handler_revalidates_before_destructive_effects

_test_usb_createinstallmedia_progress_is_live_and_temporary() {
  test_make_temp_dir || return
  local installer="$TEST_TMP_DIR/Install macOS Tahoe.app"
  local volume="$TEST_TMP_DIR/CompozshVolume" output=''
  command mkdir -p "$installer/Contents/Resources" "$volume" || return
  test_write_file "$installer/Contents/Resources/createinstallmedia" '#!/bin/zsh' || return
  command chmod +x "$installer/Contents/Resources/createinstallmedia" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$4
    local -a frames=() leftovers=()
    _usb_progress_stage() { frames+=("$1|$3|$5"); }
    _usb_createinstallmedia_command_run() {
      print -r -- $'\''Erasing disk: 0%\rErasing disk: 42%\rCopying to disk: 87%\rInstall media now available'\''
    }
    _usb_createinstallmedia_run "$2" "$3" || exit 2
    leftovers=("$4"/compozsh-createinstallmedia.*(N))
    print -r -- "frames:${(j:;:)frames}"
    print -r -- "leftovers:${#leftovers}"
  ' "$TEST_REPO_ROOT" "$installer" "$volume" "$TEST_TMP_DIR") || return

  test_assert_contains "$output" 'Creating macOS installer|' \
    'Apple createinstallmedia did not publish progress on the Step 3 status view' || return
  test_assert_contains "$output" 'leftovers:0' \
    'Apple createinstallmedia left its bounded progress capture behind'
}
test_case 'USB createinstallmedia publishes live progress and cleans its capture' \
  _test_usb_createinstallmedia_progress_is_live_and_temporary

_test_usb_result_dispatch_preserves_media_and_status() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    _usb_result_present() { print -r -- "$1:$2"; return 7; }
    local kind="" result=0
    for kind in macos-installer raw-image unknown; do
      _usb_media_result_screen "$kind" 4
      result=$?
      (( result == 7 )) || exit 1
    done
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'macos-installer:4\nraw:4\nraw:4' "$output"
}
test_case 'USB result dispatch preserves media, unknown raw fallback and presenter status' \
  _test_usb_result_dispatch_preserves_media_and_status

_test_usb_macos_result_screen_reports_native_outcome() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    _usb_result_choose() {
      print -r -- "title:$1|trail:$2"
      print -r -- "labels:${(j:|:)_USB_PICKER_LABELS}"
      print -r -- "styles:${(j:|:)_USB_PICKER_HIGHLIGHTS}"
    }
    _USB_RESULT_OUTCOME=complete _USB_RESULT_SECONDS=75 _USB_RESULT_SOURCE_VALIDATED=1
    _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1 _USB_RESULT_SOURCE_VALIDATED=1
    _usb_media_result_screen macos-installer 0
    _USB_RESULT_OUTCOME=failed _USB_RESULT_ERROR="Apple createinstallmedia failed: media is too small"
    _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _usb_media_result_screen macos-installer 1
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'macOS installer complete · Apple createinstallmedia succeeded' \
    'the macOS completion screen reused raw byte-verification language' || return
  test_assert_contains "$output" \
    'Source validation · Verified · Apple-signed full installer' \
    'the macOS completion screen omitted its source-integrity evidence' || return
  test_assert_contains "$output" \
    'macOS installer failed · Apple createinstallmedia failed: media is too small' \
    'the macOS failure screen hid Apple’s retained diagnostic' || return
  [[ $output == *picker-success*picker-error* ]] ||
    test_fail 'macOS completion and failure evidence lacked semantic colors'
}
test_case 'USB macOS result screen reports Apple-native completion and failure' \
  _test_usb_macos_result_screen_reports_native_outcome

_test_usb_result_screens_keep_facts_passive() {
  test_make_temp_dir || return
  local output='' line=''
  local -i screens=0

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    _usb_choose() {
      print -r -- "$1|values:${(j:,:)_USB_PICKER_VALUES}|labels:${(j:,:)_USB_PICKER_LABELS}|passive:${(j:|:)_USB_PICKER_PASSIVE_LINES}"
    }

    _USB_RESULT_OUTCOME=complete _USB_RESULT_BYTES=1048576 _USB_RESULT_SECONDS=1
    _USB_RESULT_RATE="1.0 MiB/s" _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _USB_RESULT_VERIFIED=1 _USB_RESULT_VERIFY_SCOPE=full
    _USB_RESULT_CHECKSUM_VALIDATED=0 _USB_RESULT_VERIFY_REASON=""
    _usb_media_result_screen raw-image 0
    _USB_RESULT_OUTCOME=failed _USB_RESULT_ERROR="raw failure"
    _USB_RESULT_STARTED=0 _USB_RESULT_EJECTED=0 _USB_RESULT_VERIFIED=0
    _usb_media_result_screen raw-image 1

    _USB_RESULT_OUTCOME=complete _USB_RESULT_SECONDS=2 _USB_RESULT_STARTED=1
    _USB_RESULT_EJECTED=1 _USB_RESULT_SOURCE_VALIDATED=1
    _usb_media_result_screen macos-installer 0
    _USB_RESULT_OUTCOME=failed _USB_RESULT_ERROR="macOS failure"
    _USB_RESULT_STARTED=0 _USB_RESULT_EJECTED=0 _USB_RESULT_SOURCE_VALIDATED=0
    _usb_media_result_screen macos-installer 1
  ' "$TEST_REPO_ROOT") || return

  for line in "${(@f)output}"; do
    (( ++screens ))
    [[ $line == *'|values:done|labels:Done|passive:'* ]] || {
      test_fail "USB result exposed a passive fact as an action: $line"
      return
    }
    [[ $line != *'|passive:' ]] || {
      test_fail "USB result omitted its passive outcome evidence: $line"
      return
    }
  done
  (( screens == 4 )) || test_fail "expected four USB result states, saw $screens"
}
test_case 'USB result screens expose only Done as an action' \
  _test_usb_result_screens_keep_facts_passive

_test_usb_attention_and_review_screens_index_only_actions() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_choose() {
      print -r -- "values:${(j:,:)_USB_PICKER_VALUES}|passive:${(j:|:)_USB_PICKER_PASSIVE_LINES}|styles:${(j:|:)_USB_PICKER_PASSIVE_STYLES}|search:${#_USB_PICKER_SEARCH}"
    }
    _usb_media_attention_choose /img.iso "Media inspection failed · x" detail
    _USB_DISK_IDS=(disk7) _USB_DISK_LABELS=(DriveA) _USB_DISK_DETAILS=(DetailsA)
    _USB_IMAGE_PATHS=(/fixture.app) _USB_IMAGE_DETAILS=(Installer)
    _usb_macos_review_choose /fixture.app 1
    (( ! ${+_USB_PICKER_PASSIVE_LINES} && ! ${+_USB_PICKER_PASSIVE_STYLES} )) ||
      print -r -- leaked-passive-rows
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal \
    'values:back|passive:Media inspection failed · x|styles:picker-error|search:1'$'\n''values:flash-verify,image,target|passive:Source validation · Verified · Apple-signed full installer|styles:picker-success|search:3' \
    "$output"
}
test_case 'USB attention and macOS review screens index only actions' \
  _test_usb_attention_and_review_screens_index_only_actions

_test_usb_image_capture_is_bounded_and_exact() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" work="$TEST_TMP_DIR/work" output=''
  local canonical_home=${home:A} canonical_work=${work:A}
  command mkdir -p "$home/Downloads" "$work/nested" || return
  test_write_file "$work/current.iso" "${(l:20000::c:)}" || return
  test_write_file "$work/SECOND.IMG" "${(l:20000::s:)}" || return
  test_write_file "$work/nested/hidden.iso" "${(l:20000::h:)}" || return
  test_write_file "$home/Downloads/download.img" "${(l:20000::d:)}" || return
  test_write_file "$work/Dropped Image.iso" "${(l:20000::p:)}" || return
  command ln -s "$work/current.iso" "$work/link.iso" || return

  output=$(test_run_interactive "$home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    builtin cd -- "$2" || exit
    _usb_images_capture || exit 2
    print -r -- "count:${#_USB_IMAGE_PATHS}"
    print -rl -- "${_USB_IMAGE_PATHS[@]}"
    _usb_images_capture "$2/current.iso" || exit 3
    print -r -- "exact:${_USB_IMAGE_PATHS[1]}"
    _usb_image_from_query "$2/Dropped\\ Image.iso" || exit 4
    print -r -- "dropped:${_USB_IMAGE_PATHS[-1]}"
    _usb_image_from_query "$2/current.iso" || exit 5
    print -r -- "reselected:$REPLY"
    _usb_images_capture "$2/link.iso" >/dev/null 2>&1
    print -r -- "symlink:$?"
    _usb_images_capture "$2/current.dmg" >/dev/null 2>&1
    print -r -- "dmg:$?"
    command mkdir -p "$2/empty-home/Downloads" "$2/empty" || exit 5
    HOME="$2/empty-home"
    builtin cd -- "$2/empty" || exit 6
    _usb_images_capture
    print -r -- "empty:$?|${#_USB_IMAGE_PATHS}"
  ' "$TEST_REPO_ROOT" "$work") || return

  test_assert_contains "$output" 'count:4' 'image discovery was not shallow and bounded' || return
  test_assert_contains "$output" "$canonical_work/current.iso" 'current-folder ISO was not captured' || return
  test_assert_contains "$output" "$canonical_work/SECOND.IMG" 'case-insensitive IMG was not captured' || return
  test_assert_contains "$output" "$canonical_home/Downloads/download.img" 'Downloads image was not captured' || return
  [[ $output != *hidden.iso* && $output != *link.iso* ]] ||
    test_fail 'image discovery followed a link or descended recursively' || return
  test_assert_contains "$output" "exact:$canonical_work/current.iso" 'explicit image was not resolved exactly' || return
  test_assert_contains "$output" "dropped:$canonical_work/Dropped Image.iso" \
    'Finder-style escaped drag-and-drop path was not decoded exactly' || return
  test_assert_contains "$output" "reselected:$canonical_work/current.iso" \
    'reselecting a captured path returned a different image' || return
  test_assert_contains "$output" 'symlink:1' 'explicit image selection followed a symbolic link' || return
  test_assert_contains "$output" 'dmg:2' 'unsupported image extension did not return a usage error' || return
  test_assert_contains "$output" 'empty:0|0' 'an empty discovery prevented the drop-path workspace'
}
test_case 'USB image capture is shallow, exact, and limited to raw image formats' \
  _test_usb_image_capture_is_bounded_and_exact

_test_usb_home_index_capture_is_newest_first_with_metadata() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" work="$TEST_TMP_DIR/work" output=''
  local canonical_home=${home:A}
  command mkdir -p "$home/Downloads" "$home/Archive/Nested" "$work" || return
  test_write_file "$home/Archive/Nested/old.iso" "${(l:20000::o:)}" || return
  test_write_file "$home/Archive/Nested/new.img" "${(l:30000::n:)}" || return
  test_write_file "$work/local.iso" "${(l:25000::l:)}" || return
  output=$(test_run_interactive "$home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    builtin cd -- "$2" || exit
    _usb_spotlight_run() {
      [[ $1 == -0 && $2 == -onlyin && $3 == "${HOME:A}" ]] || return 9
      print -rn -- "$HOME/Archive/Nested/old.iso"$'\''\0'\''
      print -rn -- "$HOME/Archive/Nested/new.img"$'\''\0'\''
    }
    _usb_image_stat_capture() {
      local image_path=$1 created=100 modified=110 size=20000
      [[ $image_path == */new.img ]] && { created=300; modified=310; size=30000; }
      [[ $image_path == */local.iso ]] && { created=200; modified=210; size=25000; }
      _USB_STAT_SIZE=$size _USB_STAT_MODIFIED=$modified _USB_STAT_CREATED=$created
      _USB_STAT_FINGERPRINT="1:2:${size}:${modified}:${created}"
    }
    _usb_format_epoch() { REPLY="date-$1"; }
    _usb_images_capture || exit 2
    local -a names=( ${_USB_IMAGE_PATHS:t} )
    local -a detail_lines=("${(@f)_USB_IMAGE_DETAILS[1]}")
    print -r -- "order:${(j:,:)names}"
    print -r -- "scope:${_USB_IMAGE_CAPTURE_SCOPE}|partial:${_USB_IMAGE_CAPTURE_PARTIAL}"
    print -r -- "visible:${(j:|:)detail_lines[1,8]}"
    print -r -- "detail:${_USB_IMAGE_DETAILS[1]}"
  ' "$TEST_REPO_ROOT" "$work") || return

  test_assert_contains "$output" 'order:new.img,local.iso,old.iso' \
    'home-indexed images were not ordered by newest creation date' || return
  test_assert_contains "$output" 'scope:Spotlight index under ~ + current folder + ~/Downloads + installed macOS installers|partial:0' \
    'home image capture hid its indexed and direct source scope' || return
  test_assert_contains "$output" "visible:new.img||Path|  $canonical_home/Archive/Nested/new.img" \
    'the selected image path fell below the passive detail-panel viewport' || return
  for fact in 'new.img' 'Format · IMG raw disk image' 'Size · 29.3 KiB' \
      'Created · date-300' 'Modified · date-310' 'Path' "$home/Archive/Nested/new.img"; do
    test_assert_contains "$output" "$fact" \
      'image detail panel omitted a captured metadata fact' || return
  done
}
test_case 'USB home image capture uses Spotlight metadata and newest-first ordering' \
  _test_usb_home_index_capture_is_newest_first_with_metadata

_test_usb_step_one_alone_has_secondary_image_details() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_PICKER_VALUES=(custom-path image:1)
    _USB_PICKER_LABELS=(Custom Linux)
    _USB_PICKER_HIGHLIGHTS=("" "7:12:picker-size")
    _USB_PICKER_SEARCH=(custom linux)
    _USB_PICKER_DETAILS=("Browse from home" $'\''Linux image\n\nPath · /images/linux.iso'\'')
    _show_view() {
      print -r -- "details:${#_ZLE_PICKER_INSPECT_TEXTS}|${_ZLE_PICKER_INSPECT_TEXTS[image:1]-}"
      print -r -- "row-style:${_ZLE_PICKER_LABEL_HIGHLIGHTS[image:1]-}"
    }
    source "$1/tests/picker_support.zsh"
    test_picker_script observe _show_view -- select image:1
    _usb_choose "External device / Flash · Step 1 of 3" "IMAGE  ›  Drive  ›  Flash" "Filter images" 1 0 1
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'details:2|Linux image' \
    'Step 1 did not expose the requested small captured image-info panel' || return
  test_assert_contains "$output" 'row-style:7:12:picker-size' \
    'Step 1 did not pass semantic image metadata into the shared renderer'
}
test_case 'USB Step 1 alone exposes a captured image detail panel' \
  _test_usb_step_one_alone_has_secondary_image_details

_test_usb_long_image_path_stays_in_passive_details() {
  test_make_temp_dir || return
  local image="$TEST_TMP_DIR/[Nintendo Wii] Super Smash Bros Brawl [NTSC, Multi2].iso"
  local output=''
  test_write_file "$image" "${(l:20000::i:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor" || exit
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_image_add "$2" || exit 2
    typeset -A _ZLE_PICKER_INSPECT_TEXTS=()
    _ZLE_PICKER_INSPECT_TEXTS[image]=$_USB_IMAGE_DETAILS[1]
    _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_inspect_prepare image 38 || exit 3
    print -r -- "rows:${#_ZLE_PICKER_INSPECT_LINES}"
    print -r -- "visible:${_ZLE_PICKER_INSPECT_LINES[4]}|${_ZLE_PICKER_INSPECT_LINES[5]}"
  ' "$TEST_REPO_ROOT" "$image") || return

  test_assert_contains "$output" 'visible:Path|  /' \
    'a wrapping image name pushed the path label or value below the passive panel'
}
test_case 'USB long image names keep the path visible in passive details' \
  _test_usb_long_image_path_stays_in_passive_details

_test_usb_image_architecture_is_passive_context() {
  test_make_temp_dir || return
  local amd="$TEST_TMP_DIR/ubuntu-live-server-amd64.iso"
  local windows="$TEST_TMP_DIR/Win11_25H2_English_x64_v2.iso"
  local arm="$TEST_TMP_DIR/proxmox-ve-arm64.iso" unknown="$TEST_TMP_DIR/rescue.iso" output=''
  test_write_file "$amd" "${(l:20000::a:)}" || return
  test_write_file "$windows" "${(l:20000::w:)}" || return
  test_write_file "$arm" "${(l:20000::b:)}" || return
  test_write_file "$unknown" "${(l:20000::c:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_image_add "$2" || exit 2
    _usb_image_add "$3" || exit 3
    _usb_image_add "$4" || exit 4
    _usb_image_add "$5" || exit 5
    print -rl -- "${_USB_IMAGE_LABELS[@]}"
    print -r -- "styles:${(j:|:)_USB_IMAGE_HIGHLIGHTS}"
    _USB_SELECTED_IMAGE_ARCHITECTURE=""
    _usb_image_architecture_capture "$4"
    print -r -- "selected:$_USB_SELECTED_IMAGE_ARCHITECTURE"
    print -r -- "unknown-detail:${_USB_IMAGE_DETAILS[4]}"
  ' "$TEST_REPO_ROOT" "$amd" "$windows" "$arm" "$unknown") || return

  test_assert_contains "$output" 'ubuntu-live-server-amd64.iso · x86-64 ·' \
    'recognized x86-64 architecture was not visible in the image row' || return
  test_assert_contains "$output" 'Win11_25H2_English_x64_v2.iso · x86-64 ·' \
    'the standard Windows x64 filename token was not recognized as x86-64' || return
  test_assert_contains "$output" 'proxmox-ve-arm64.iso · ARM64 ·' \
    'recognized ARM64 architecture was not given equal passive prominence' || return
  test_assert_contains "$output" 'styles:' \
    'image rows did not publish semantic metadata spans' || return
  [[ $output == *styles:*picker-architecture*picker-size*'|'*picker-architecture*picker-size*'|'*picker-architecture*picker-size*'|'*picker-size* ]] ||
    test_fail 'architecture and size did not receive distinct neutral row roles' || return
  test_assert_contains "$output" 'selected:arm64' \
    'selected architecture was not retained for review and progress context' || return
  test_assert_contains "$output" 'Architecture · Not declared in filename' \
    'unknown architecture was presented as a compatibility fact'
}
test_case 'USB image architecture is equal passive context without warnings' \
  _test_usb_image_architecture_is_passive_context

# A local named `path` stays special in Zsh: it would rebind PATH for every
# child and clear the interactive shell's command hash table on entry and exit.
_test_usb_helpers_keep_caller_path_and_command_hash() {
  test_make_temp_dir || return
  local image="$TEST_TMP_DIR/x.img" log="$TEST_TMP_DIR/progress.log"
  local output='' helper=''
  test_write_file "$image" "${(l:20000::x:)}" || return
  test_write_file "$log" '20000 bytes transferred · 40%' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for usb_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$usb_component"; done
    _usb_spotlight_run() { return 0; }
    _usb_disk_info_read() { return 1; }
    probe() {
      hash compozsh-probe=/bin/echo
      "$@" >/dev/null 2>&1
      print -r -- "hash:$1:${commands[compozsh-probe]-gone}"
    }
    probe _usb_media_kind_capture "$2"
    probe _usb_image_stat_capture "$2"
    probe _usb_image_add "$2"
    probe _usb_macos_installer_add "$2"
    probe _usb_media_add "$2"
    probe _usb_spotlight_images_capture
    probe _usb_image_filesystem_device_capture "$2"
    probe _usb_image_source_disk_capture "$2"
    probe _usb_image_revalidate "$2" unknown 20000
    probe _usb_createinstallmedia_progress_read "$3"
    caller_path=$PATH child_path=unobserved
    _usb_macos_installer_tool() {
      child_path=$(command /usr/bin/env | command /usr/bin/grep "^PATH=")
      return 1
    }
    _usb_media_kind_capture "$2"
    [[ $child_path == "PATH=$caller_path" ]] && child_path=same
    print -r -- "child-path:$child_path"
  ' "$TEST_REPO_ROOT" "$image" "$log") || return

  for helper in _usb_media_kind_capture _usb_image_stat_capture _usb_image_add \
      _usb_macos_installer_add _usb_media_add _usb_spotlight_images_capture \
      _usb_image_filesystem_device_capture _usb_image_source_disk_capture \
      _usb_image_revalidate _usb_createinstallmedia_progress_read; do
    test_assert_contains "$output" "hash:$helper:/bin/echo" \
      "$helper cleared the caller's command hash table" || return
  done
  test_assert_contains "$output" 'child-path:same' \
    'a USB helper started a child with PATH rebound to the media path'
}
test_case 'USB helpers keep the caller PATH and command hash table intact' \
  _test_usb_helpers_keep_caller_path_and_command_hash

_test_usb_disk_capture_filters_unsafe_targets() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_disk_ids_capture() {
      _USB_DISK_IDS=(disk7 disk8 disk9 disk10 disk11 disk12 disk13)
    }
    _usb_disk_info_capture() {
      _USB_INFO_ID=$1 _USB_INFO_SIZE=12000000 _USB_INFO_NAME="Fixture $1"
      _USB_INFO_PROTOCOL=USB _USB_INFO_EXTERNAL=1 _USB_INFO_WHOLE=1
      _USB_INFO_PHYSICAL=1 _USB_INFO_WRITABLE=1
      case $1 in
        disk8) _USB_INFO_SIZE=4000 ;;
        disk9) _USB_INFO_PHYSICAL=0 ;;
        disk10) _USB_INFO_EXTERNAL=0 ;;
        disk11) _USB_INFO_WRITABLE=0 ;;
        disk12) _USB_INFO_WHOLE=0 ;;
      esac
      _USB_INFO_FINGERPRINT="${_USB_INFO_ID}|${_USB_INFO_SIZE}|${_USB_INFO_NAME}|${_USB_INFO_PROTOCOL}"
    }
    _usb_disks_capture 5000 || exit 2
    print -r -- "ids:${(j:,:)_USB_DISK_IDS}"
    print -r -- "label:${_USB_DISK_LABELS[1]}"
    print -r -- "details:${_USB_DISK_DETAILS[1]}"
    _usb_disks_capture 5000 disk7 || exit 3
    print -r -- "source-excluded:${(j:,:)_USB_DISK_IDS}"
    _usb_disk_ids_capture() { _USB_DISK_IDS=(disk7); }
    _usb_disks_capture 5000 disk7 >/dev/null 2>&1
    print -r -- "source-only:$?|${_USB_CAPTURE_ERROR}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'ids:disk7' 'unsafe or undersized disks remained eligible' || return
  test_assert_contains "$output" 'Fixture disk7' 'disk label omitted captured media identity' || return
  test_assert_contains "$output" '/dev/disk7' 'disk details omitted the exact whole device' || return
  test_assert_contains "$output" 'external physical' 'disk details omitted the safety boundary' || return
  test_assert_contains "$output" 'source-excluded:disk13' \
    'disk containing the selected image remained an eligible write target' || return
  test_assert_contains "$output" \
    'source-only:1|the only attached external disk contains the selected image; attach another external disk or move the image to a different disk' \
    'a source-only attachment did not explain how to provide a separate target'
}
test_case 'USB target capture keeps only writable whole external physical disks' \
  _test_usb_disk_capture_filters_unsafe_targets

_test_usb_plist_capture_uses_whole_disk_facts() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    list_plist="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>AllDisks</key><array><string>disk7</string><string>disk7s1</string><string>disk9</string></array></dict></plist>"
    _usb_disk_list_read() { _USB_PLIST=$list_plist; }
    _usb_disk_ids_capture || exit 2
    print -r -- "ids:${(j:,:)_USB_DISK_IDS}"
    info_plist="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>DeviceIdentifier</key><string>disk7</string><key>ParentWholeDisk</key><string>disk7</string><key>TotalSize</key><integer>64000000000</integer><key>DeviceBlockSize</key><integer>4096</integer><key>MediaName</key><string>External SSD</string><key>BusProtocol</key><string>Thunderbolt</string><key>Internal</key><false/><key>VirtualOrPhysical</key><string>Physical</string><key>WholeDisk</key><true/><key>WritableMedia</key><true/><key>DeviceTreePath</key><string>IOService:/fixture</string></dict></plist>"
    _usb_disk_info_read() { _USB_PLIST=$info_plist; }
    _usb_disk_info_capture disk7 || exit 3
    _usb_info_is_eligible || exit 4
    print -r -- "info:${_USB_INFO_ID}|${_USB_INFO_SIZE}|${_USB_INFO_BLOCK_SIZE}|${_USB_INFO_NAME}|${_USB_INFO_PROTOCOL}|${_USB_INFO_FINGERPRINT}"
    _usb_image_filesystem_device_capture() { _USB_IMAGE_DEVICE=/dev/disk7s2; }
    _usb_image_source_disk_capture /images/linux.iso || exit 5
    print -r -- "source:${_USB_IMAGE_SOURCE_DISK}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'ids:disk7,disk9' \
    'diskutil list plist did not exclude partition slices' || return
  test_assert_contains "$output" \
    'info:disk7|64000000000|4096|External SSD|Thunderbolt|disk7|64000000000|External SSD|Thunderbolt|IOService:/fixture' \
    'diskutil info plist did not retain external physical disk identity' || return
  test_assert_contains "$output" 'source:disk7' \
    'selected image filesystem did not resolve to its parent whole disk'
}
test_case 'USB providers parse native plists into exact whole-disk facts' \
  _test_usb_plist_capture_uses_whole_disk_facts

# diskutil names an APFS volume's synthesized (Virtual) container as its
# ParentWholeDisk; only APFSPhysicalStores leads to the physical disk a target
# could be. Every effect after the source guards is a recording stand-in,
# because _usb_unmount and _usb_eject call /usr/sbin/diskutil directly.
_test_usb_apfs_source_run() {
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    local -a trace=()
    local volume_keys="" effect=""
    plist() { print -rn -- "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict>$1</dict></plist>"; }
    key() { print -rn -- "<key>$1</key><string>$2</string>"; }
    stores() {
      local store=""
      REPLY="$(key DeviceIdentifier disk5s1)$(key ParentWholeDisk disk5)$(key APFSContainerReference disk5)<key>APFSPhysicalStores</key><array>"
      for store; do REPLY+="<dict>$(key APFSPhysicalStore "$store")</dict>"; done
      REPLY+="</array>"
    }
    whole() {
      plist "$(key DeviceIdentifier $1)$(key ParentWholeDisk $1)<key>TotalSize</key><integer>$2</integer><key>DeviceBlockSize</key><integer>512</integer>$(key MediaName "$3")$(key BusProtocol USB)<key>Internal</key><false/>$(key VirtualOrPhysical Physical)<key>WholeDisk</key><true/><key>WritableMedia</key><true/>"
    }
    _usb_image_filesystem_device_capture() { _USB_IMAGE_DEVICE=/dev/disk5s1; }
    _usb_diskutil_run() {
      case "$*" in
        ("list -plist external physical")
          plist "<key>AllDisks</key><array><string>disk4</string><string>disk4s1</string><string>disk4s2</string><string>disk6</string></array>" ;;
        ("info -plist /dev/disk5s1") plist "$volume_keys" ;;
        ("info -plist /dev/disk4s2") plist "$(key DeviceIdentifier disk4s2)$(key ParentWholeDisk disk4)" ;;
        ("info -plist /dev/disk4s3") plist "$(key DeviceIdentifier disk4s3)$(key ParentWholeDisk disk4)" ;;
        ("info -plist /dev/disk7s2") plist "$(key DeviceIdentifier disk7s2)$(key ParentWholeDisk disk7)" ;;
        ("info -plist /dev/disk8s2") plist "$(key DeviceIdentifier disk8s2)" ;;
        ("info -plist /dev/disk4") whole disk4 1000204886016 "Example SSD holding the image" ;;
        ("info -plist /dev/disk6") whole disk6 64023257088 "Example empty stick" ;;
        (*) return 1 ;;
      esac
    }
    for effect in _usb_progress_stage _usb_authorize _usb_authorization_valid \
        _usb_macos_installer_revalidate _usb_image_revalidate _usb_target_revalidate \
        _usb_macos_prepare_volume _usb_createinstallmedia_run _usb_unmount \
        _usb_write_image _usb_eject \
        _usb_diskutil_erase_run; do
      functions[$effect]="trace+=($effect); return 0"
    done
    '"$1" "$TEST_REPO_ROOT" "$TEST_TMP_DIR"
}

_test_usb_source_exclusion_resolves_apfs_physical_store() {
  test_make_temp_dir || return
  local output=''
  output=$(_test_usb_apfs_source_run '
    stores disk4s2; volume_keys=$REPLY
    _usb_image_source_disk_capture "/Volumes/SSD/Install macOS Tahoe.app"
    print -r -- "capture:$?|source:$_USB_IMAGE_SOURCE_DISK|error:$_USB_CAPTURE_ERROR"
    source_disk=$_USB_IMAGE_SOURCE_DISK
    _usb_external_disks_capture 2147483648 "$source_disk" raw-image
    print -r -- "targets:$?|${(j:,:)_USB_DISK_IDS}"
    trace=()
    _usb_macos_execute "/Volumes/SSD/Install macOS Tahoe.app" disk4 disk-fingerprint \
      installer-fingerprint 17179869184 flash-verify "$source_disk" 1 "" "" 1000204886016 >/dev/null 2>&1
    print -r -- "macos:$?|$_USB_RESULT_ERROR|trace:${(j:,:)trace}"
    trace=()
    _usb_execute /Volumes/SSD/linux.iso disk4 disk-fingerprint image-fingerprint \
      1048576 flash-only "$source_disk" 1 "" "" 1000204886016 >/dev/null 2>&1
    print -r -- "raw:$?|$_USB_RESULT_ERROR|trace:${(j:,:)trace}"
  ') || return

  test_assert_contains "$output" 'capture:0|source:disk4|error:' \
    'an APFS image source resolved to its synthesized container instead of its physical disk' || return
  test_assert_contains "$output" 'targets:0|disk6' \
    'the physical disk holding an APFS image source remained a write target' || return
  test_assert_contains "$output" \
    'macos:1|The selected drive contains the macOS installer source; nothing was written.|trace:' \
    'the macOS handler reached an effect on the disk holding its APFS installer source' || return
  test_assert_contains "$output" \
    'raw:1|The selected drive contains the image source; nothing was written.|trace:' \
    'the raw writer reached an effect on the disk holding its APFS image source'
}
test_case 'USB source exclusion resolves APFS volumes to their physical store disk' \
  _test_usb_source_exclusion_resolves_apfs_physical_store

_test_usb_source_exclusion_covers_every_store_and_fails_closed() {
  test_make_temp_dir || return
  local output='' probe=''
  output=$(_test_usb_apfs_source_run '
    stores disk4s2 disk7s2 disk4s3; volume_keys=$REPLY
    _usb_image_source_disk_capture /Volumes/Fusion/linux.iso
    print -r -- "fusion:$?|source:$_USB_IMAGE_SOURCE_DISK"
    source_disk=$_USB_IMAGE_SOURCE_DISK
    _usb_external_disks_capture 2147483648 "$source_disk" raw-image
    print -r -- "fusion-targets:$?|${(j:,:)_USB_DISK_IDS}"
    trace=()
    _usb_execute /Volumes/Fusion/linux.iso disk7 disk-fingerprint image-fingerprint \
      1048576 flash-only "$source_disk" 1 "" "" 1000204886016 >/dev/null 2>&1
    print -r -- "fusion-raw:$?|$_USB_RESULT_ERROR|trace:${(j:,:)trace}"
    trace=()
    _usb_macos_execute "/Volumes/Fusion/Install macOS Tahoe.app" disk4 disk-fingerprint \
      installer-fingerprint 17179869184 flash-verify "$source_disk" 1 "" "" 1000204886016 >/dev/null 2>&1
    print -r -- "fusion-macos:$?|trace:${(j:,:)trace}"
    probe() {
      volume_keys=$2
      _usb_image_source_disk_capture /Volumes/SSD/linux.iso
      print -r -- "$1:$?|source:$_USB_IMAGE_SOURCE_DISK|error:${_USB_CAPTURE_ERROR:+present}"    }
    stores disk9s2; probe unreadable-store "$REPLY"
    print -r -- "unreadable-error:$_USB_CAPTURE_ERROR"
    stores disk8s2; probe store-without-whole-disk "$REPLY"
    stores "disk4s2/../disk6"; probe malformed-store "$REPLY"
    stores; probe empty-store-list "$REPLY"
    local -a many=(); repeat 17 many+=(disk4s2)
    stores "${many[@]}"; probe over-bound-store-list "$REPLY"
    probe missing-store-list "$(key DeviceIdentifier disk5s1)$(key ParentWholeDisk disk5)$(key APFSContainerReference disk5)"
    probe store-dictionary "$(key DeviceIdentifier disk5s1)$(key ParentWholeDisk disk5)<key>APFSPhysicalStores</key><dict>$(key APFSPhysicalStore disk4s2)</dict>"
  ') || return

  test_assert_contains "$output" 'fusion:0|source:disk4 disk7' \
    'a multi-store APFS source did not resolve each physical whole disk once' || return
  test_assert_contains "$output" 'fusion-targets:0|disk6' \
    'a physical disk holding one APFS store remained a write target' || return
  test_assert_contains "$output" \
    'fusion-raw:1|The selected drive contains the image source; nothing was written.|trace:' \
    'the raw writer reached an effect on a later APFS store disk' || return
  test_assert_contains "$output" 'fusion-macos:1|trace:' \
    'the macOS handler reached an effect on the first APFS store disk' || return
  test_assert_contains "$output" 'unreadable-error:diskutil could not inspect /dev/disk9s2' \
    'an unreadable APFS physical store did not name the store that failed' || return
  for probe in unreadable-store store-without-whole-disk malformed-store \
      empty-store-list over-bound-store-list missing-store-list store-dictionary; do
    test_assert_contains "$output" "$probe:1|source:|error:present" \
      "an APFS source whose physical store is unestablished ($probe) was not refused" || return
  done
}
test_case 'USB source exclusion covers every APFS store and fails closed when unresolved' \
  _test_usb_source_exclusion_covers_every_store_and_fails_closed

# Integer assignment evaluates arithmetic, including $(...) in a subscript, and
# 19 or more digits truncate or wrap; validate plist text before either.
_test_usb_plist_capture_rejects_hostile_numbers() {
  test_make_temp_dir || return
  local output='' exit_status=0 REPLY=''
  _test_usb_invocation_state_script
  output=$(test_run_interactive "$TEST_TMP_DIR/home" "$REPLY"'
    source "$1/.zsh.addons/.zsh.usb" || exit
    _test_usb_invocation_state declare
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    head="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict>"
    _usb_disk_list_read() { _USB_PLIST="${head}<key>AllDisks</key><string>99999999999999999999</string></dict></plist>"; }
    _usb_disk_ids_capture
    print -r -- "ids:$?|${#_USB_DISK_IDS}"
    probe() {
      local fixture_size=$1 fixture_block=$2
      _usb_disk_info_read() {
        _USB_PLIST="${head}<key>DeviceIdentifier</key><string>disk7</string><key>TotalSize</key><string>$fixture_size</string><key>DeviceBlockSize</key><string>$fixture_block</string><key>MediaName</key><string>External SSD</string><key>BusProtocol</key><string>USB</string><key>Internal</key><false/><key>VirtualOrPhysical</key><string>Physical</string><key>WholeDisk</key><true/><key>WritableMedia</key><true/><key>DeviceTreePath</key><string>IOService:/fixture</string></dict></plist>"
      }
      _usb_disk_info_capture disk7
      print -r -- "info:$?|$_USB_INFO_SIZE|$_USB_INFO_BLOCK_SIZE"
    }
    probe '"'"'path[$(: >| $HOME/size-marker)1]'"'"' 512
    probe 64000000000 '"'"'path[$(: >| $HOME/block-marker)1]'"'"'
    probe 99999999999999999999 512
    probe 64000000000 99999999999999999999
    probe 64000000000 4096
    [[ ! -e $HOME/size-marker && ! -e $HOME/block-marker ]] ||
      print -r -- "diskutil text ran a command substitution"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
ids:1|0
info:1|0|512
info:1|0|512
info:1|0|512
info:1|0|512
info:0|64000000000|4096' "status:$exit_status"$'\n'"$output" \
    'diskutil numbers were evaluated or accepted after overflowing'
}
test_case 'USB providers reject hostile and overflowing diskutil numbers before arithmetic' \
  _test_usb_plist_capture_rejects_hostile_numbers

# Media names come from Downloads, Spotlight, folders and pasted paths. A
# lookup spliced into arithmetic text would reparse the name as an expression.
_test_usb_media_lookups_keep_hostile_names_literal() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -ga _USB_IMAGE_PATHS=()
    _usb_image_add "$HOME/a\$(: >| \$HOME/image-marker).iso"
    _usb_image_add "$HOME/y]+path[\$(: >| \$HOME/breakout-marker)1]+x[z.iso"
    _usb_macos_installer_add "$HOME/Install macOS \$(: >| \$HOME/installer-marker).app"
    local -i chooses=0
    _usb_choose() {
      (( ++chooses == 1 )) || return 1
      _ZLE_PICKER_SELECTED_VALUE=custom-path _ZLE_PICKER_ACTION=""
    }
    _usb_browse_image_path() { REPLY="$HOME/b\$(: >| \$HOME/browse-marker).iso"; }
    _usb_image_from_query() { print -r -- "lookup:$1"; return 1; }
    _usb_workspace_controller
    print -r -- "controller:$?|$chooses"
    local -a markers=($HOME/*-marker(N)); print -r -- "markers:${#markers}"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal "status:0
lookup:$TEST_TMP_DIR/home/b\$(: >| \$HOME/browse-marker).iso
controller:1|2
markers:0" "status:$exit_status"$'\n'"$output" \
    'a media file name ran as arithmetic or a command substitution'
}
test_case 'USB media lookups keep hostile file names literal' \
  _test_usb_media_lookups_keep_hostile_names_literal

# Image bytes, native tool output and writer status lines are text. Each is
# validated before arithmetic, which would run $(...) in a subscript and
# truncate or wrap 19 or more digits; the writer stage is a word, not math.
_test_usb_native_numbers_stay_text_until_validated() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    cd "$HOME" || exit
    TMPDIR=$HOME

    print -r -- "123 bytes transferred in 1 secs" >| dd.log
    print -r -- "Copying 50%" >| installer.log
    local stat_text=""
    command() {
      if [[ $1 == /usr/bin/stat ]]; then print -r -- "$stat_text"; else builtin command "$@"; fi
    }
    for stat_text in '"'"'path[$(: >| $HOME/stat-marker)1]'"'"' 99999999999999999999; do
      _usb_dd_progress_read dd.log 1024 $SECONDS
      print -r -- "progress:$?|$REPLY"
      _usb_createinstallmedia_progress_read installer.log
      print -r -- "installer:$?|$REPLY"
    done
    unfunction command
    print -r -- "Copying 99999999999999999999% of the installer" >| installer.log
    _usb_createinstallmedia_progress_read installer.log
    print -r -- "percent:$?"

    _usb_progress_stage() { :; }
    _usb_raw_write_session_run() {
      print -u2 -r -- compozsh-write-stage:image
      print -u2 -r -- compozsh-write-verify-bytes:99999999999999999999
      return 1
    }
    _usb_write_image /images/linux.iso disk7 8388608 8388608 1
    print -r -- "write:$?|$_USB_WRITE_VERIFY_BYTES_OBSERVED"
    _usb_raw_write_session_run() {
      print -u2 -r -- '"'"'compozsh-write-stage:path[$(: >| $HOME/stage-marker)1]'"'"'
      return 1
    }
    _usb_write_image /images/linux.iso disk7 8388608 8388608 1
    print -r -- "stage:$?"

    head="<?xml version=\"1.0\"?><plist version=\"1.0\">"
    _usb_diskutil_plist_capture() {
      _USB_PLIST="${head}<array><dict><key>Personality</key><string>ExFAT</string><key>MinimumSize</key><string>99999999999999999999</string></dict><dict><key>Personality</key><string>APFS</string><key>MaximumSize</key><string>9223372036854775808</string></dict><dict><key>Personality</key><string>JHFS+</string></dict></array></plist>"
    }
    _usb_formats_capture
    print -r -- "formats:$?|${(j:,:)_USB_FORMAT_PERSONALITIES}"
    local -a markers=($HOME/*-marker(N)); print -r -- "markers:${#markers}"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
progress:0|Preparing the first write block…
installer:0|Preparing Apple createinstallmedia…
progress:0|Preparing the first write block…
installer:0|Preparing Apple createinstallmedia…
percent:0
write:1|0
stage:1
formats:0|JHFS+
markers:0' "status:$exit_status"$'\n'"$output" \
    'USB native numbers were evaluated, wrapped or treated as arithmetic words'
}
test_case 'USB native tool numbers stay text until validated' \
  _test_usb_native_numbers_stay_text_until_validated

_test_usb_disk_info_capture_without_device_tree() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    info_plist="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>DeviceIdentifier</key><string>disk7</string><key>TotalSize</key><integer>64000000000</integer><key>DeviceBlockSize</key><integer>512</integer><key>MediaName</key><string>External SSD</string><key>BusProtocol</key><string>USB</string><key>Internal</key><false/><key>VirtualOrPhysical</key><string>Physical</string><key>WholeDisk</key><true/><key>WritableMedia</key><true/></dict></plist>"
    _usb_disk_info_read() { _USB_PLIST=$info_plist; }
    _usb_disk_info_capture disk7
    print -r -- "capture:$?|${_USB_INFO_FINGERPRINT}"
    _usb_disk_ids_capture() { _USB_DISK_IDS=(disk7); }
    _usb_disks_capture 5000 >/dev/null 2>&1
    print -r -- "list:$?|${(j:,:)_USB_DISK_IDS}|${_USB_DISK_FINGERPRINTS[1]}"
    _usb_target_revalidate disk7 "disk7|64000000000|External SSD|USB" 5000
    print -r -- "revalidate:$?"
    _usb_target_revalidate disk7 "disk7|64000000000|External SSD|USB|IOService:/fixture" 5000
    print -r -- "lost-tree:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" $'capture:0|disk7|64000000000|External SSD|USB\n' \
    'a valid disk without DeviceTreePath failed capture or changed fingerprint format' || return
  test_assert_contains "$output" $'list:0|disk7|disk7|64000000000|External SSD|USB\n' \
    'a valid disk without DeviceTreePath was dropped from eligible targets' || return
  test_assert_contains "$output" 'revalidate:0' \
    'an unchanged disk without DeviceTreePath failed target revalidation' || return
  test_assert_contains "$output" 'lost-tree:1' \
    'a target that lost its captured DeviceTreePath passed revalidation'
}
test_case 'USB disk capture accepts a valid disk without DeviceTreePath' \
  _test_usb_disk_info_capture_without_device_tree

_test_usb_plist_capture_ignores_custom_path() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/capture" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    path=()
    TMPDIR=$2
    _usb_diskutil_run() {
      print -rn -- "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>AllDisks</key><array/></dict></plist>"
    }
    _usb_diskutil_plist_capture list -plist external physical || exit 2
    print -r -- "plist:${_USB_PLIST}"
    leftovers=("$2"/compozsh-usb.*(N))
    print -r -- "leftovers:${#leftovers}"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" '<key>AllDisks</key>' \
    'bounded plist capture depended on the customized command path' || return
  test_assert_contains "$output" 'leftovers:0' \
    'bounded plist capture did not remove its native temporary file'
}
test_case 'USB plist capture uses absolute native tool paths' \
  _test_usb_plist_capture_ignores_custom_path

_test_usb_diskutil_capture_reports_empty_output() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/capture" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    TMPDIR=$2
    _usb_diskutil_run() { return 0; }
    _usb_disk_list_read
    print -r -- "empty:$?|error:[$_USB_CAPTURE_ERROR]|plist:[$_USB_PLIST]"
    _USB_PLIST_MAX_BYTES=16
    _usb_diskutil_run() { print -rn -- "<?xml version=\"1.0\"?><plist/>"; }
    _usb_disk_list_read
    print -r -- "oversized:$?|error:[$_USB_CAPTURE_ERROR]|plist:[$_USB_PLIST]"
    # Losing the capture file leaves its size unknown, which is neither case.
    _usb_diskutil_run() { command /bin/rm -f -- "$TMPDIR"/compozsh-usb.*(N); }
    _usb_disk_list_read
    print -r -- "unmeasured:$?|error:[$_USB_CAPTURE_ERROR]|plist:[$_USB_PLIST]"
    leftovers=("$2"/compozsh-usb.*(N))
    print -r -- "leftovers:${#leftovers}"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" 'empty:1|error:[diskutil returned no output]|plist:[]' \
    'empty diskutil output was not reported as missing data' || return
  test_assert_contains "$output" \
    'oversized:1|error:[diskutil output exceeded the 16-byte capture limit]|plist:[]' \
    'oversized diskutil output lost its capture-limit diagnostic' || return
  test_assert_contains "$output" \
    'unmeasured:1|error:[cannot measure the bounded diskutil capture file]|plist:[]' \
    'an unmeasurable diskutil capture was misreported' || return
  test_assert_contains "$output" 'leftovers:0' \
    'a refused diskutil capture left its temporary file behind'
}
test_case 'USB diskutil capture reports empty output as no data' \
  _test_usb_diskutil_capture_reports_empty_output

_test_usb_custom_path_browses_from_home() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''
  local canonical_home=${home:A}
  command mkdir -p "$home/Downloads" || return
  test_write_file "$home/Downloads/linux.iso" "${(l:20000::i:)}" || return
  output=$(test_run_interactive "$home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    choose_call=0
    _usb_browse_choose() {
      (( ++choose_call ))
      print -r -- "view${choose_call}:${_ZLE_PICKER_SUBTITLE}|${(j:,:)_USB_PICKER_VALUES}"
      if (( choose_call == 1 )); then
        _ZLE_PICKER_ACTION=descend
        _ZLE_PICKER_SELECTED_VALUE="$HOME/Downloads/"
      else
        _ZLE_PICKER_ACTION=choose
        _ZLE_PICKER_SELECTED_VALUE="$HOME/Downloads/linux.iso"
      fi
    }
    _usb_browse_image_path || exit 2
    print -r -- "selected:$REPLY"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'view1:~/|' \
    'custom image browser did not start at the visible home path' || return
  test_assert_contains "$output" 'paste-path' \
    'custom image browser did not preserve exact drag-and-drop entry' || return
  test_assert_contains "$output" "$canonical_home/Downloads/" \
    'custom image browser omitted a selectable child folder' || return
  test_assert_contains "$output" "view2:~/Downloads/|" \
    'opening a folder did not update the visible path' || return
  test_assert_contains "$output" "selected:$canonical_home/Downloads/linux.iso" \
    'selecting an image did not finish custom target resolution'
}
test_case 'USB custom image path is a home-rooted arrow-key browser' \
  _test_usb_custom_path_browses_from_home

_test_usb_custom_path_matches_tab_navigation_contract() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output='' hidden_off=''
  command mkdir -p "$home/folder" || return
  test_write_file "$home/visible.iso" "${(l:20000::v:)}" || return
  test_write_file "$home/.hidden.img" "${(l:20000::h:)}" || return
  output=$(test_run_interactive "$home" '
    source "$1/.zsh.addons/.zsh.editor" || exit
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -a _USB_PICKER_VALUES=(middle exact fuzzy)
    typeset -a _USB_PICKER_LABELS=(my-linux.iso linux.iso lxinux.iso)
    typeset -a _USB_PICKER_SEARCH=("" "" "")
    _usb_picker_collect linux 20 || exit 2
    print -r -- "rank:${(j:,:)_ZLE_PICKER_RESULTS}"
    typeset -a _USB_PICKER_VALUES=() _USB_PICKER_LABELS=() _USB_PICKER_HIGHLIGHTS=()
    typeset -a _USB_PICKER_SEARCH=() _USB_PICKER_DETAILS=()
    typeset -i _USB_BROWSER_SHOW_HIDDEN=0 _USB_BROWSER_PARTIAL=0
    _usb_browser_capture "$HOME" || exit 3
    print -r -- "hidden-off:${(j:,:)_USB_PICKER_LABELS}"
    print -r -- "size-style:${(j:,:)_USB_PICKER_HIGHLIGHTS}"
    _USB_BROWSER_SHOW_HIDDEN=1
    _usb_browser_capture "$HOME" || exit 4
    print -r -- "hidden-on:${(j:,:)_USB_PICKER_LABELS}"
    typeset -a _USB_BROWSER_RESUME=("" 1 0)
    _zle_picker_loop() {
      print -r -- "nav:${_ZLE_PICKER_HIERARCHY_ENABLED}|${_ZLE_PICKER_DIRECTORY_ACTIONS}|${_ZLE_PICKER_BROWSE_LABEL}"
    }
    _usb_browse_choose
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'rank:exact,middle,fuzzy' \
    'custom image browser did not rank prefix, substring, then fuzzy matches like Tab navigation' || return
  hidden_off=${${(M)${(f)output}:#hidden-off:*}[1]-}
  [[ $hidden_off == *visible.iso* && $hidden_off != *.hidden.img* ]] || {
    test_fail 'custom image browser showed hidden images before the Tab-style toggle'
    return
  }
  test_assert_contains "$output" 'hidden-on:' \
    'custom image browser did not recapture after toggling hidden items' || return
  test_assert_contains "$output" '.hidden.img' \
    'custom image browser hidden toggle did not reveal an applicable image' || return
  test_assert_contains "$output" 'size-style:' \
    'custom image browser did not publish image-size presentation metadata' || return
  test_assert_contains "$output" 'picker-size' \
    'custom image browser size did not use the shared semantic size role' || return
  test_assert_contains "$output" 'nav:1|0|Hidden: on · ← parent · → open folder · Return select' \
    'custom image browser did not expose only the Tab hierarchy and hidden-item controls'
}
test_case 'USB custom image browser matches Tab fuzzy and hierarchy navigation' \
  _test_usb_custom_path_matches_tab_navigation_contract

# The real shared loop drives the browser: folder-only keys stay inert on an
# image (same key, same action), and only Return chooses it.
_test_usb_custom_path_keeps_folder_keys_inert_on_images() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''
  command mkdir -p "$home/folder" || return
  test_write_file "$home/test.iso" "${(l:20000::v:)}" || return
  output=$(test_run_interactive "$home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/tests/pty_support.zsh" || exit 2
    command mkfifo "$HOME/events" || exit 3
    exec {efd}<> "$HOME/events"
    local name="" bel=$'\''\a'\''
    local -i bells=0
    local -A keys=(
      ctrl-x $'\''\x18'\'' ctrl-o $'\''\x0f'\'' right $'\''\e[C'\'' tab $'\''\t'\''
      left $'\''\e[D'\'' up $'\''\e[A'\'' down $'\''\e[B'\'' guide $'\''\x0b'\''
      enter $'\''\r'\'')
    functions[_inert_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      setopt LOCAL_OPTIONS EXTENDED_GLOB
      _inert_show
      local shown=""
      # Painted footer and guide text: hints present, folder-only actions absent.
      [[ $_ZLE_PICKER_POSTDISPLAY == *(\^K\ all\ keys|Right\ /\ Tab*Enter\ selected\ folder)* ]] &&
        shown=hints
      [[ $_ZLE_PICKER_POSTDISPLAY == *(#i)(\^[XO]|ctrl-[XOE]|preview|folder\ actions)* ]] &&
        print -r -- "advertised:$_ZLE_PICKER_GUIDE_ACTIVE" >> "$HOME/advertised"
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_SUBTITLE|$_ZLE_PICKER_SELECTED|${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]:t}|$_ZLE_PICKER_GUIDE_ACTIVE|$shown"
    }
    _inert_browse() {
      _usb_browse_image_path
      local -i browse_status=$?
      print -r -u $efd -- "RESULT|$browse_status|$_ZLE_PICKER_ACTION|$REPLY"
      return $browse_status
    }
    _inert_driver() {
      command stty rows 60 cols 120
      _zle_picker_run 20 "" 1 0 _inert_browse
      print -r -u $efd -- "DONE|$?"
    }
    # Count terminal bells in all output, so none depends on read timing.
    _inert_expect() {
      local rest=""
      {
        test_pty_expect "$@" || return
      } always {
        rest=$TEST_PTY_OUTPUT
        while [[ $rest == *$bel* ]]; do rest=${rest#*$bel}; (( ++bells )); done
      }
    }
    test_pty_start usb-inert _inert_driver || exit 4
    {
      _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/|1|paste-path|0|hints" || exit 5
      zpty -w -n usb-inert "$keys[guide]"
      _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/|1|paste-path|1|hints" || exit 6
      # Right on the paste row is inert too; only Return opens the paste field.
      zpty -w -n usb-inert "$keys[guide]$keys[right]$keys[down]"
      _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/|2|folder|0|hints" || exit 7
      zpty -w -n usb-inert "$keys[down]"
      _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/|3|test.iso|0|hints" || exit 7
      for name in ctrl-x ctrl-o right tab; do
        zpty -w -n usb-inert "$keys[$name]$keys[up]"
        _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/|2|folder|0|hints" || {
          print -u2 -r -- "$name chose or moved the highlighted image"; exit 8; }
        zpty -w -n usb-inert "$keys[down]"
        _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/|3|test.iso|0|hints" || exit 9
      done
      zpty -w -n usb-inert "$keys[up]$keys[right]"
      _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/folder/|1|paste-path|0|hints" || exit 10
      zpty -w -n usb-inert "$keys[left]"
      _inert_expect -s "RESULT*" usb-inert $efd "FRAME|~/|2|folder|0|hints" || exit 11
      zpty -w -n usb-inert "$keys[down]$keys[enter]"
      _inert_expect -g usb-inert $efd "RESULT[|]0[|]*[|]*/test.iso" || exit 12
      _inert_expect usb-inert $efd "DONE|0" || exit 13
    } always {
      zpty -d usb-inert 2>/dev/null
    }
    print -r -- "bells:$bells"
    if [[ -f $HOME/advertised ]]; then
      print -r -- "advertised:${(j:,:)${(f)"$(<"$HOME/advertised")"}}"
    else
      print -r -- advertised:
    fi
    print -r -- inert-journey-complete
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'inert-journey-complete' \
    'the custom image browser journey did not finish' || return
  test_assert_contains "$output" 'bells:5'$'\n' \
    'each inert folder-only key did not signal once that it is inert' || return
  test_assert_contains "$output" $'advertised:\n' \
    'the custom image browser footer or guide advertised folder-only actions'
}
test_case 'USB custom image browser keeps folder keys inert on an image' \
  _test_usb_custom_path_keeps_folder_keys_inert_on_images

_test_usb_steps_use_clean_single_pane_choices() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_PICKER_VALUES=(one two)
    _USB_PICKER_LABELS=(One Two)
    _USB_PICKER_SEARCH=(one two)
    _USB_PICKER_DETAILS=(secret-one secret-two)
    _show_view() {
      print -r -- "title:${_ZLE_PICKER_TITLE}"
      print -r -- "subtitle:${_ZLE_PICKER_SUBTITLE}"
      print -r -- "details:${#_ZLE_PICKER_INSPECT_TEXTS}"
    }
    source "$1/tests/picker_support.zsh"
    test_picker_script observe _show_view -- select one
    _usb_choose "External device / Flash · Step 1 of 3" "IMAGE  ›  Drive  ›  Flash" "Filter images"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'title:External device / Flash · Step 1 of 3' \
    'step title did not expose the staged workflow' || return
  test_assert_contains "$output" 'subtitle:IMAGE  ›  Drive  ›  Flash' \
    'step subtitle did not expose progress through the workflow' || return
  test_assert_contains "$output" 'details:0' \
    'ordinary step choices retained the oversized details pane'
}
test_case 'USB step choices use a clean single-pane workflow' \
  _test_usb_steps_use_clean_single_pane_choices

_test_usb_workspace_requires_explicit_image_target_action() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _USB_IMAGE_PATHS=(/images/older.iso /images/newer.iso)
    _USB_IMAGE_LABELS=(older newer)
    _USB_IMAGE_DETAILS=(older-details newer-details)
    _USB_IMAGE_SIZES=(20000 30000)
    _USB_IMAGE_FINGERPRINTS=(older-fingerprint newer-fingerprint)
    _usb_image_source_disk_capture() { _USB_IMAGE_SOURCE_DISK=""; }
    capture_call=0
    _usb_disks_capture() {
      (( ++capture_call ))
      if (( capture_call == 1 )); then
        _USB_DISK_IDS=(disk7)
        _USB_DISK_LABELS=(external-target)
        _USB_DISK_DETAILS=(target-details)
        _USB_DISK_SIZES=(90000)
        _USB_DISK_FINGERPRINTS=(disk-fingerprint)
      else
        _USB_DISK_IDS=(disk9)
        _USB_DISK_LABELS=(new-target)
        _USB_DISK_DETAILS=(new-target-details)
        _USB_DISK_SIZES=(100000)
        _USB_DISK_FINGERPRINTS=(new-disk-fingerprint)
      fi
    }
    call=0
    _usb_choose() {
      (( ++call ))
      print -r -- "view${call}:${(j:,:)_USB_PICKER_VALUES}|${(j:,:)_USB_PICKER_LABELS}"
      (( call == 3 || call == 5 )) &&
        print -r -- "integrity-style:${_USB_PICKER_HIGHLIGHTS[2]-}|semantic:${6:-0}"
      case $call in
        1) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        2) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        3) _ZLE_PICKER_SELECTED_VALUE=target ;;
        4) return 1 ;;
        5) _ZLE_PICKER_SELECTED_VALUE=flash-verify ;;
        *) return 2 ;;
      esac
    }
    _usb_workspace_controller || exit 2
    print -r -- "selected:${_USB_SELECTED_IMAGE}|${_USB_SELECTED_DISK}|${_USB_REQUEST}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'view1:custom-path,image:1,image:2' \
    'Step 1 did not place Custom Path before captured images' || return
  test_assert_contains "$output" 'view2:1' 'Target view did not establish an exact disk' || return
  test_assert_contains "$output" 'view3:flash-verify,checksum,image,target,flash-only' \
    'Action view did not make verification the default explicit action' || return
  test_assert_contains "$output" 'integrity-style:0:' \
    'the no-checksum integrity state did not cover its complete visible row' || return
  test_assert_contains "$output" ':picker-error|semantic:1' \
    'the no-checksum integrity state did not request the shared red error role' || return
  test_assert_contains "$output" 'view4:1' 'target refresh did not show its new captured snapshot' || return
  test_assert_contains "$output" 'view5:flash-verify,checksum,image,target,flash-only' \
    'cancelling target refresh did not restore the prior action workspace' || return
  test_assert_contains "$output" 'view5:flash-verify,checksum,image,target,flash-only|Start flash & verify,Image integrity · Not verified · no checksum provided,Change image · older.iso,Change drive · external-target' \
    'cancelling target refresh paired the old selection with new disk metadata' || return
  test_assert_contains "$output" 'selected:/images/older.iso|disk7|flash-verify' \
    'workspace inferred a newer image instead of retaining the explicit selection'
}
test_case 'USB workspace explicitly composes image, target, and action' \
  _test_usb_workspace_requires_explicit_image_target_action

_test_usb_checksum_input_accepts_one_modern_digest() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    sha256=${(l:64::a:)}
    sha512=${(l:128::b:)}
    _usb_checksum_parse "$sha256" || exit 2
    print -r -- "bare:$_USB_CHECKSUM_ALGORITHM|$REPLY"
    _usb_checksum_parse "SHA512 (linux.iso) = $sha512" || exit 3
    print -r -- "bsd:$_USB_CHECKSUM_ALGORITHM|$REPLY"
    _usb_checksum_parse "$sha256  linux.iso" || exit 4
    print -r -- "shasum:$_USB_CHECKSUM_ALGORITHM|$REPLY"
    _usb_checksum_parse "not-a-checksum" >/dev/null 2>&1
    print -r -- "invalid:$?"
    _usb_checksum_parse "$sha256 $sha512" >/dev/null 2>&1
    print -r -- "multiple:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" "bare:256|${(l:64::a:)}" \
    'bare SHA-256 input was not normalized' || return
  test_assert_contains "$output" "bsd:512|${(l:128::b:)}" \
    'BSD SHA-512 input was not parsed' || return
  test_assert_contains "$output" 'shasum:256|' \
    'standard shasum input was not parsed' || return
  test_assert_contains "$output" 'invalid:1' \
    'invalid checksum input was accepted' || return
  test_assert_contains "$output" 'multiple:1' \
    'ambiguous multiple-checksum input was accepted'
}
test_case 'USB checksum input accepts one SHA-256 or SHA-512 digest' \
  _test_usb_checksum_input_accepts_one_modern_digest

_test_usb_workspace_retains_optional_checksum() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    digest=${(l:64::d:)}
    _USB_IMAGE_PATHS=(/images/linux.iso)
    _USB_IMAGE_LABELS=(linux)
    _USB_IMAGE_DETAILS=(image-details)
    _USB_IMAGE_SIZES=(30000)
    _USB_IMAGE_FINGERPRINTS=(image-fingerprint)
    _usb_image_source_disk_capture() { _USB_IMAGE_SOURCE_DISK=""; }
    _usb_disks_capture() {
      _USB_DISK_IDS=(disk7)
      _USB_DISK_LABELS=(external-target)
      _USB_DISK_DETAILS=(target-details)
      _USB_DISK_SIZES=(90000)
      _USB_DISK_FINGERPRINTS=(disk-fingerprint)
    }
    call=0
    _usb_choose() {
      (( ++call ))
      case $call in
        (1) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        (2) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (3) _ZLE_PICKER_SELECTED_VALUE=checksum ;;
        (4)
          print -r -- "review:${(j:|:)_USB_PICKER_LABELS}"
          print -r -- "integrity-style:${_USB_PICKER_HIGHLIGHTS[2]-}|semantic:${6:-0}"
          _ZLE_PICKER_SELECTED_VALUE=flash-verify ;;
        (*) return 2 ;;
      esac
    }
    _usb_read_checksum() { _ZLE_PICKER_SELECTED_VALUE="SHA256 (linux.iso) = $digest"; }
    _usb_image_revalidate() { return 0; }
    _usb_image_checksum() { REPLY=$digest; }
    _usb_progress_stage() { print -r -- "integrity-stage:$1"; }
    _usb_workspace_controller || exit 2
    print -r -- "selected:$_USB_SELECTED_CHECKSUM_ALGORITHM|$_USB_SELECTED_CHECKSUM"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'integrity-stage:Checking image SHA-256' \
    'Step 3 did not visibly hash the local image after checksum entry' || return
  test_assert_contains "$output" 'review:Start flash & verify · SHA-256|Image integrity · Verified · SHA-256 matched|Remove image checksum' \
    'Step 3 did not retain a visible verified image-integrity state' || return
  test_assert_contains "$output" 'integrity-style:0:' \
    'the verified integrity state did not cover its complete visible row' || return
  test_assert_contains "$output" ':picker-success|semantic:1' \
    'the verified integrity state did not request the shared green success role' || return
  test_assert_contains "$output" "selected:256|${(l:64::d:)}" \
    'the selected checksum did not cross the action boundary'
}
test_case 'USB Step 3 retains an optional image checksum in review state' \
  _test_usb_workspace_retains_optional_checksum

_test_usb_step3_blocks_a_mismatched_image_checksum() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    expected=${(l:64::d:)} actual=${(l:64::e:)}
    _USB_IMAGE_PATHS=(/images/linux.iso) _USB_IMAGE_LABELS=(linux)
    _USB_IMAGE_DETAILS=(image-details) _USB_IMAGE_SIZES=(30000)
    _USB_IMAGE_FINGERPRINTS=(image-fingerprint)
    _usb_image_source_disk_capture() { _USB_IMAGE_SOURCE_DISK=""; }
    _usb_disks_capture() {
      _USB_DISK_IDS=(disk7) _USB_DISK_LABELS=(external-target)
      _USB_DISK_DETAILS=(target-details) _USB_DISK_SIZES=(90000)
      _USB_DISK_FINGERPRINTS=(disk-fingerprint)
    }
    _usb_image_revalidate() { return 0; }
    _usb_image_checksum() { REPLY=$actual; }
    _usb_progress_stage() { return 0; }
    _usb_read_checksum() { _ZLE_PICKER_SELECTED_VALUE=$expected; }
    call=0
    _usb_choose() {
      (( ++call ))
      case $call in
        (1) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        (2) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (3) _ZLE_PICKER_SELECTED_VALUE=checksum ;;
        (4)
          print -r -- "mismatch:${(j:|:)_USB_PICKER_LABELS}"
          _ZLE_PICKER_SELECTED_VALUE=flash-verify ;;
        (5)
          print -r -- blocked-after-flash
          _ZLE_PICKER_SELECTED_VALUE=remove-checksum ;;
        (6) _ZLE_PICKER_SELECTED_VALUE=flash-verify ;;
        (*) return 2 ;;
      esac
    }
    _usb_workspace_controller || exit 2
    print -r -- "selected:$call|${_USB_SELECTED_CHECKSUM:-none}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'Image integrity · FAILED · SHA-256 mismatch' \
    'Step 3 did not show the expected and actual image mismatch' || return
  test_assert_contains "$output" 'Resolve image integrity check before flashing' \
    'Step 3 left a destructive action looking enabled after checksum failure' || return
  test_assert_contains "$output" 'blocked-after-flash' \
    'a checksum-mismatched image crossed the action boundary' || return
  test_assert_contains "$output" 'selected:6|none' \
    'removing a failed checksum did not explicitly restore the no-checksum action'
}
test_case 'USB Step 3 blocks a mismatched image checksum' \
  _test_usb_step3_blocks_a_mismatched_image_checksum

# A refused flash returns to the same review screen, so the refusal itself
# must be visible there, and only until the user's next action.
_test_usb_step3_shows_the_checksum_refusal() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    expected=${(l:64::d:)} actual=${(l:64::e:)}
    _USB_IMAGE_PATHS=(/images/linux.iso) _USB_IMAGE_LABELS=(linux)
    _USB_IMAGE_DETAILS=(image-details) _USB_IMAGE_SIZES=(30000)
    _USB_IMAGE_FINGERPRINTS=(image-fingerprint)
    _usb_image_source_disk_capture() { _USB_IMAGE_SOURCE_DISK=""; }
    _usb_disks_capture() {
      _USB_DISK_IDS=(disk7) _USB_DISK_LABELS=(external-target)
      _USB_DISK_DETAILS=(target-details) _USB_DISK_SIZES=(90000)
      _USB_DISK_FINGERPRINTS=(disk-fingerprint)
    }
    _usb_image_revalidate() { return 0; }
    _usb_image_checksum() { REPLY=$actual; }
    _usb_progress_stage() { return 0; }
    _usb_read_checksum() { _ZLE_PICKER_SELECTED_VALUE=$expected; }
    call=0
    _usb_choose() {
      (( ++call ))
      print -r -- "view$call:${(j:|:)${_USB_PICKER_PASSIVE_LINES[@]-}}|style:${(j:|:)${_USB_PICKER_PASSIVE_STYLES[@]-}}"
      case $call in
        (1) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        (2) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (3) _ZLE_PICKER_SELECTED_VALUE=checksum ;;
        (4) _ZLE_PICKER_SELECTED_VALUE=flash-only ;;
        (5) _ZLE_PICKER_SELECTED_VALUE=image ;;
        (6) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        (7) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (8) _ZLE_PICKER_SELECTED_VALUE=flash-only ;;
        (*) return 2 ;;
      esac
    }
    _usb_workspace_controller
    print -r -- "end:$?|$call|${_USB_REQUEST:-none}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'view4:|style:' \
    'Step 3 showed a refusal before any flash action was chosen' || return
  test_assert_contains "$output" \
    'view5:The image integrity check must match before flashing' \
    'Step 3 silently ignored a flash action refused by the checksum' || return
  test_assert_contains "$output" \
    'view5:The image integrity check must match before flashing; correct or remove the checksum|style:picker-error' \
    'the Step 3 refusal did not use the shared error role' || return
  test_assert_contains "$output" 'view6:|style:' \
    'the Step 3 refusal leaked into the next screen' || return
  test_assert_contains "$output" 'view8:|style:' \
    'the Step 3 refusal outlived the action that caused it' || return
  test_assert_contains "$output" 'end:0|8|flash-only' \
    'choosing the image again did not clear the refused checksum'
}
test_case 'USB Step 3 shows the checksum refusal before flashing' \
  _test_usb_step3_shows_the_checksum_refusal

_test_usb_step3_hashing_never_claims_early_success() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    _zle_picker_capture() { print -r -- "lines:${(j:|:)_ZLE_PICKER_BUSY_LINES}"; }
    _usb_step3_checksum_progress /images/linux.iso disk7 external-target \
      ${(l:64::a:)} 256 x86_64
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'IMAGE INTEGRITY|  Checking · SHA-256' \
    'the in-progress checksum frame claimed the image was already verified' || return
  [[ $output != *'Verified in Step 3'* ]] || {
    test_fail 'the checksum progress frame presented success before hashing completed'
    return
  }
}
test_case 'USB Step 3 checksum progress remains pending until matched' \
  _test_usb_step3_hashing_never_claims_early_success

_test_usb_native_image_checksum() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    print -rn -- abc >| "$HOME/abc"
    _usb_image_checksum "$HOME/abc" 256 || exit 2
    print -r -- "full:$REPLY"
    _usb_image_checksum /definitely/missing 256 >/dev/null 2>&1
    print -r -- "missing:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'full:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' \
    'native full-image SHA-256 output was parsed incorrectly' || return
  test_assert_contains "$output" 'missing:1' \
    'a missing image became a successful empty-input digest'
}
test_case 'USB native image checksum parses exact full-image evidence' \
  _test_usb_native_image_checksum

_test_usb_unmounts_immediately_after_write() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    _usb_progress_stage() { return 0; }
    _usb_authorize() { trace+=(authorize); }
    _usb_authorization_valid() { return 0; }
    _usb_image_revalidate() { trace+=(image-revalidate); }
    _usb_target_revalidate() { trace+=(target-revalidate); }
    _usb_unmount() { trace+=(unmount); }
    _usb_write_image() {
      trace+=(write)
      _USB_WRITE_BYTES_OBSERVED=$3 _USB_WRITE_VERIFIED=1
    }
    _usb_eject() { trace+=(eject); }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify >/dev/null 2>&1
    print -r -- "status:$?|${(j:,:)trace}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'status:0|authorize,image-revalidate,target-revalidate,unmount,target-revalidate,write,unmount,image-revalidate,eject' \
    'the target was not unmounted immediately after dd and before slower source checks'
}
test_case 'USB execution immediately unmounts after writing before source checks' \
  _test_usb_unmounts_immediately_after_write

_test_usb_privileged_verification_never_hides_a_prompt() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    print -r -- "session:${functions[_usb_raw_write_session_run]}"
  ' "$TEST_REPO_ROOT") || return
  [[ $output == *'/usr/bin/sudo -n /bin/zsh'* ]] || {
    test_fail 'USB in-session read-back can prompt invisibly after the sudo timestamp expires'
    return
  }
  return 0
}
test_case 'USB verification uses noninteractive retained authorization' \
  _test_usb_privileged_verification_never_hides_a_prompt

_test_usb_expired_write_authorization_is_refreshed_before_unmount() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    _usb_progress_stage() { trace+=("stage:$1"); }
    _usb_image_revalidate() { trace+=(image-revalidate); return 0; }
    _usb_target_revalidate() { trace+=(target-revalidate); return 0; }
    _usb_authorization_valid() { trace+=(auth-check); return 1; }
    _usb_authorize() { trace+=(auth-prompt); return 1; }
    _usb_unmount() { trace+=(unmount); return 0; }
    _usb_write_image() { trace+=(write); return 0; }
    _usb_eject() { trace+=(eject); return 0; }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 >/dev/null 2>&1
    print -r -- "status:$?|${(j:,:)trace}|started:$_USB_RESULT_STARTED|$_USB_RESULT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'auth-check,stage:Authorization required for writing,auth-prompt' \
    'expired authorization was not refreshed immediately before the destructive boundary' || return
  [[ $output != *',unmount,'* && $output != *',write,'* ]] || {
    test_fail 'the target was changed after write authorization refresh failed'
    return
  }
  test_assert_contains "$output" \
    'started:0|Administrator authorization expired before writing; nothing was written.' \
    'write authorization failure did not retain a precise nothing-written result'
}
test_case 'USB execution refreshes expired authorization before unmounting for write' \
  _test_usb_expired_write_authorization_is_refreshed_before_unmount

_test_usb_workspace_retries_transient_target_permission() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _USB_IMAGE_PATHS=(/images/linux.iso)
    _USB_IMAGE_LABELS=(linux)
    _USB_IMAGE_DETAILS=(linux-details)
    _USB_IMAGE_SIZES=(30000)
    _USB_IMAGE_FINGERPRINTS=(linux-fingerprint)
    _usb_image_source_disk_capture() { _USB_IMAGE_SOURCE_DISK=""; }
    capture_call=0
    _usb_disks_capture() {
      (( ++capture_call ))
      if (( capture_call == 1 )); then
        _USB_CAPTURE_ERROR="macOS removable-volume permission changed during capture"
        return 1
      fi
      _USB_DISK_IDS=(disk7)
      _USB_DISK_LABELS=(external-target)
      _USB_DISK_DETAILS=(target-details)
      _USB_DISK_SIZES=(90000)
      _USB_DISK_FINGERPRINTS=(disk-fingerprint)
    }
    choose_call=0
    _usb_choose() {
      (( ++choose_call ))
      print -r -- "view${choose_call}:${(j:,:)_USB_PICKER_VALUES}|$2"
      case $choose_call in
        1) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        2) _ZLE_PICKER_SELECTED_VALUE=retry ;;
        3) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        4) _ZLE_PICKER_SELECTED_VALUE=flash-verify ;;
        *) return 2 ;;
      esac
    }
    _usb_workspace_controller || exit 2
    print -r -- "capture-count:$capture_call"
    print -r -- "selected:${_USB_SELECTED_IMAGE}|${_USB_SELECTED_DISK}|${_USB_REQUEST}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'view2:retry,image|' \
    'transient target capture failure closed the workspace instead of offering retry' || return
  test_assert_contains "$output" 'macOS removable-volume permission changed during capture' \
    'retry view hid the target-capture failure reason' || return
  test_assert_contains "$output" 'capture-count:2' \
    'Retry did not recapture disks after permission changed' || return
  test_assert_contains "$output" 'selected:/images/linux.iso|disk7|flash-verify' \
    'retry lost the established image or exact target'
}
test_case 'USB workspace retries transient removable-volume permission capture' \
  _test_usb_workspace_retries_transient_target_permission

_test_usb_workspace_refreshes_after_late_attachment() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _USB_IMAGE_PATHS=(/images/linux.iso)
    _USB_IMAGE_LABELS=(linux)
    _USB_IMAGE_DETAILS=(linux-details)
    _USB_IMAGE_SIZES=(30000)
    _USB_IMAGE_FINGERPRINTS=(linux-fingerprint)
    _usb_image_source_disk_capture() { _USB_IMAGE_SOURCE_DISK=""; }
    capture_call=0
    _usb_disks_capture() {
      (( ++capture_call ))
      if (( capture_call == 1 )); then
        _USB_CAPTURE_ERROR="no external target is attached"
        return 1
      fi
      _USB_DISK_IDS=(disk9) _USB_DISK_LABELS=(late-target)
      _USB_DISK_DETAILS=(late-details) _USB_DISK_SIZES=(90000)
      _USB_DISK_FINGERPRINTS=(late-fingerprint)
    }
    choose_call=0
    _usb_choose() {
      (( ++choose_call ))
      _ZLE_PICKER_ACTION=select
      print -r -- "view${choose_call}:${(j:,:)_USB_PICKER_VALUES}|refresh:${5:-0}"
      case $choose_call in
        1) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        2) _ZLE_PICKER_ACTION=refresh ;;
        3) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        4) _ZLE_PICKER_SELECTED_VALUE=flash-verify ;;
        *) return 2 ;;
      esac
    }
    _usb_workspace_controller || exit 2
    print -r -- "captures:$capture_call"
    print -r -- "selected:${_USB_SELECTED_DISK}|${_USB_REQUEST}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'view2:retry,image|refresh:1' \
    'the no-target view did not expose its refresh capability' || return
  test_assert_contains "$output" 'view3:1|refresh:1' \
    'Ctrl-R did not replace the empty target view with the attached drive' || return
  test_assert_contains "$output" 'captures:2' \
    'Ctrl-R did not perform exactly one fresh disk capture' || return
  test_assert_contains "$output" 'selected:disk9|flash-verify' \
    'target refresh lost the selected image or newly attached drive'
}
test_case 'USB Step 2 refreshes after a drive is attached late' \
  _test_usb_workspace_refreshes_after_late_attachment

# An ejected drive leaves diskutil's external list empty. Only diskutil is a
# stand-in: the real capture chain reaches Step 2's recovery view, and a
# reworded producer message must not change which recovery it offers.
_test_usb_target_recovery_follows_the_capture_error_kind() {
  test_make_temp_dir || return
  local output='' probe='' detail_line=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$HOME
    _usb_diskutil_run() {
      [[ "$*" == "list -plist external physical" ]] || return 1
      print -rn -- "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>AllDisks</key><array/></dict></plist>"
    }
    _usb_choose() {
      print -r -- "${probe}:label:${_USB_PICKER_LABELS[1]}"
      print -r -- "${probe}:subtitle:$2"
      print -r -- "${probe}:detail:${(j: :)${(f)_USB_PICKER_DETAILS[1]}}"
      return 1
    }
    probe=shipped
    _usb_target_choose 30000 linux.iso image "Choose another image"
    print -r -- "${probe}:status:$?"
    shipped_body=$functions[_usb_disk_ids_capture]
    functions[_usb_disk_ids_capture]=${shipped_body//no whole external physical disks are attached/macOS lists no external disks right now}
    [[ $functions[_usb_disk_ids_capture] != "$shipped_body" ]] &&
      print -r -- message-reworded:yes
    probe=reworded
    _usb_target_choose 30000 linux.iso image "Choose another image"
    print -r -- "${probe}:status:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'message-reworded:yes' \
    'the probe did not reword the producer message' || return
  for probe in shipped reworded; do
    test_assert_contains "$output" \
      "${probe}:label:Make drive available · connect or replug it, then retry" \
      "the empty target view did not give the required physical recovery action ($probe message)" || return
    test_assert_contains "$output" \
      "${probe}:subtitle:DRIVE unavailable · no external disk is currently visible to macOS" \
      "the empty target status repeated an internal provider error instead of recovery guidance ($probe message)" || return
    detail_line=${(M)${(f)output}:#${probe}:detail:*}
    [[ $detail_line == *'Ctrl-R cannot reactivate an ejected drive'* ]] || {
      test_fail "the empty target details implied that refresh can recover an ejected drive ($probe message): ${(qqq)detail_line}"
      return
    }
    test_assert_contains "$output" "${probe}:status:1" \
      "leaving the empty target recovery view did not preserve cancellation ($probe message)" || return
  done
}
test_case "USB target recovery offers replug guidance from the capture's error kind" \
  _test_usb_target_recovery_follows_the_capture_error_kind

_test_usb_workspace_refreshes_images_with_spotlight_snapshot() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _USB_IMAGE_PATHS=(/images/old.iso)
    _USB_IMAGE_LABELS=(old.iso)
    _USB_IMAGE_HIGHLIGHTS=("7:15:picker-size")
    _USB_IMAGE_DETAILS=(old-details)
    _USB_IMAGE_SIZES=(30000)
    _USB_IMAGE_FINGERPRINTS=(old-fingerprint)
    _usb_image_source_disk_capture() { _USB_IMAGE_SOURCE_DISK=""; }
    image_capture_call=0
    _usb_images_capture() {
      (( ++image_capture_call ))
      _USB_IMAGE_PATHS=(/images/new.iso /images/old.iso)
      _USB_IMAGE_LABELS=(new.iso old.iso)
      _USB_IMAGE_HIGHLIGHTS=("7:15:picker-size" "7:15:picker-size")
      _USB_IMAGE_DETAILS=(new-details old-details)
      _USB_IMAGE_SIZES=(40000 30000)
      _USB_IMAGE_FINGERPRINTS=(new-fingerprint old-fingerprint)
      _USB_IMAGE_CAPTURE_SCOPE="Spotlight index under ~ + current folder + ~/Downloads"
    }
    _usb_disks_capture() {
      _USB_DISK_IDS=(disk9) _USB_DISK_LABELS=(target)
      _USB_DISK_DETAILS=(target-details) _USB_DISK_SIZES=(90000)
      _USB_DISK_FINGERPRINTS=(target-fingerprint)
    }
    choose_call=0
    _usb_choose() {
      (( ++choose_call ))
      _ZLE_PICKER_ACTION=select
      print -r -- "view${choose_call}:${(j:,:)_USB_PICKER_VALUES}|refresh:${5:-0}|label:${7:-}|query:${8:-}|initial:${9:-}"
      case $choose_call in
        1)
          _ZLE_PICKER_ACTION=refresh
          _ZLE_PICKER_SELECTED_VALUE=image:1
          _ZLE_PICKER_BOOKMARK=(iso 1 0) ;;
        2) _ZLE_PICKER_SELECTED_VALUE=image:1 ;;
        3) _ZLE_PICKER_SELECTED_VALUE=1 ;;
        4) _ZLE_PICKER_SELECTED_VALUE=flash-verify ;;
        *) return 2 ;;
      esac
    }
    _usb_workspace_controller || exit 2
    print -r -- "captures:$image_capture_call"
    print -r -- "selected:${_USB_SELECTED_IMAGE}|${_USB_SELECTED_DISK}|${_USB_REQUEST}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'view1:custom-path,image:1|refresh:1|label:captured media · Ctrl-R refresh Spotlight' \
    'Step 1 did not expose its image-refresh capability' || return
  test_assert_contains "$output" \
    'view2:custom-path,image:1,image:2|refresh:1|label:captured media · Ctrl-R refresh Spotlight|query:iso|initial:image:2' \
    'image refresh did not retain the filter and exact prior image selection' || return
  test_assert_contains "$output" 'captures:1' \
    'Ctrl-R did not perform exactly one fresh image capture' || return
  test_assert_contains "$output" 'selected:/images/new.iso|disk9|flash-verify' \
    'the refreshed image snapshot did not continue through the established workflow'
}
test_case 'USB Step 1 refreshes Spotlight images without losing filter or selection context' \
  _test_usb_workspace_refreshes_images_with_spotlight_snapshot

_test_usb_external_device_capture_is_shared_by_flash_and_format() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_disk_ids_capture() { _USB_DISK_IDS=(disk7 disk8); }
    _usb_disk_info_capture() {
      _USB_INFO_ID=$1 _USB_INFO_NAME="Drive $1" _USB_INFO_PROTOCOL=USB
      _USB_INFO_EXTERNAL=1 _USB_INFO_PHYSICAL=1 _USB_INFO_WHOLE=1
      _USB_INFO_WRITABLE=1 _USB_INFO_BLOCK_SIZE=512
      [[ $1 == disk7 ]] && _USB_INFO_SIZE=20000 || _USB_INFO_SIZE=90000
      _USB_INFO_FINGERPRINT="$1|$_USB_INFO_SIZE|Drive $1|USB"
    }
    _usb_disks_capture 30000 "" raw-image || exit 2
    print -r -- "flash:${(j:,:)_USB_DISK_IDS}|${_USB_DISK_DETAILS[1]}"
    _usb_format_disks_capture || exit 3
    print -r -- "format:${(j:,:)_USB_DISK_IDS}|${_USB_DISK_DETAILS[1]}"
    print -r -- "shared:$([[ ${functions[_usb_disks_capture]} == *_usb_external_disks_capture* && ${functions[_usb_format_disks_capture]} == *_usb_external_disks_capture* ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'flash:disk8|' \
    'flash capture did not retain its minimum-size constraint' || return
  test_assert_contains "$output" 'format:disk7,disk8|' \
    'format capture did not include every eligible external whole disk' || return
  test_assert_contains "$output" 'diskutil will replace this whole disk' \
    'format capture did not describe its exact destructive boundary' || return
  test_assert_contains "$output" 'shared:yes' \
    'flash and format did not share one external-device capture implementation'
}
test_case 'USB tools share eligible external-device capture with scoped constraints' \
  _test_usb_external_device_capture_is_shared_by_flash_and_format

_test_usb_format_catalog_comes_from_diskutil() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_diskutil_plist_capture() { _USB_PLIST=catalog; }
    _compozsh_plutil_raw() {
      local key=$2
      case $key in
        (0.Personality) REPLY=APFS ;;
        (0.UserVisibleName) REPLY=APFS ;;
        (0.MinimumSize) REPLY=8388608 ;;
        (0.MaximumSize) REPLY=9223372034707292160 ;;
        (1.Personality) REPLY="MS-DOS FAT32" ;;
        (1.UserVisibleName) REPLY="MS-DOS (FAT32)" ;;
        (1.MinimumSize) REPLY=34603008 ;;
        (1.MaximumSize) REPLY=8796093022208 ;;
        (2.Personality) REPLY="Free Space" ;;
        (2.UserVisibleName) REPLY="Free Space" ;;
        (2.MinimumSize|2.MaximumSize) REPLY=0 ;;
        (*) return 1 ;;
      esac
    }
    _usb_formats_capture || exit 2
    print -r -- "formats:${(j:|:)_USB_FORMAT_PERSONALITIES}"
    print -r -- "labels:${(j:|:)_USB_FORMAT_LABELS}"
    print -r -- "details:${_USB_FORMAT_DETAILS[2]}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'formats:APFS|MS-DOS FAT32|Free Space' \
    'format choices were hard-coded or omitted a diskutil-advertised personality' || return
  test_assert_contains "$output" 'labels:APFS|MS-DOS (FAT32)|Free Space' \
    'format choices did not use diskutil user-visible names' || return
  test_assert_contains "$output" 'diskutil personality · MS-DOS FAT32' \
    'format details hid the exact value passed back to diskutil'
}
test_case 'USB format choices are captured from diskutil listFilesystems' \
  _test_usb_format_catalog_comes_from_diskutil

_test_usb_format_workspace_reloads_drives_then_selects_a_format() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    capture_count=0 choose_count=0
    _usb_format_disks_capture() {
      (( ++capture_count ))
      _USB_DISK_IDS=(disk9) _USB_DISK_LABELS=(external-drive)
      _USB_DISK_DETAILS=(drive-details) _USB_DISK_SIZES=(9000000000)
      _USB_DISK_FINGERPRINTS=(disk-fingerprint)
    }
    _usb_formats_capture() {
      _USB_FORMAT_PERSONALITIES=(APFS ExFAT)
      _USB_FORMAT_LABELS=(APFS ExFAT)
      _USB_FORMAT_DETAILS=(apfs-details exfat-details)
      _USB_FORMAT_MINIMUM_SIZES=(8388608 1048576)
      _USB_FORMAT_MAXIMUM_SIZES=(0 0)
    }
    _usb_choose() {
      (( ++choose_count ))
      print -r -- "view$choose_count:$1|${(j:,:)_USB_PICKER_VALUES}|refresh:${5:-0}"
      case $choose_count in
        (1) _ZLE_PICKER_ACTION=refresh ;;
        (2) _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (3) _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=2 ;;
        (4) _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=default-name ;;
        (*) return 2 ;;
      esac
    }
    _usb_format_workspace_controller || exit 2
    print -r -- "captures:$capture_count"
    print -r -- "selected:$_USB_SELECTED_DISK|$_USB_SELECTED_FORMAT|$_USB_SELECTED_FORMAT_LABEL|$_USB_SELECTED_VOLUME_NAME"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'view1:External device / Format · Step 1 of 3|1|refresh:1' \
    'format drive selection did not expose Ctrl-R refresh' || return
  test_assert_contains "$output" 'view2:External device / Format · Step 1 of 3|1|refresh:1' \
    'format refresh did not return to a fresh external-device snapshot' || return
  test_assert_contains "$output" 'view3:External device / Format · Step 2 of 3|1,2|refresh:0' \
    'format selection did not follow exact drive selection' || return
  test_assert_contains "$output" \
    'view4:External device / Format · Step 3 of 3|default-name,custom-name|refresh:0' \
    'format selection did not offer default and custom volume-name choices' || return
  test_assert_contains "$output" 'captures:2' \
    'Ctrl-R did not perform exactly one fresh format-target capture' || return
  test_assert_contains "$output" 'selected:disk9|ExFAT|ExFAT|External' \
    'the default volume name did not cross the workspace boundary'
}
test_case 'USB format workspace composes drive format and default volume name' \
  _test_usb_format_workspace_reloads_drives_then_selects_a_format

_test_usb_format_workspace_validates_a_custom_volume_name() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_format_disks_capture() {
      _USB_DISK_IDS=(disk9) _USB_DISK_LABELS=(external-drive)
      _USB_DISK_DETAILS=(drive-details) _USB_DISK_SIZES=(9000000000)
      _USB_DISK_FINGERPRINTS=(disk-fingerprint)
    }
    _usb_formats_capture() {
      _USB_FORMAT_PERSONALITIES=(ExFAT) _USB_FORMAT_LABELS=(ExFAT)
      _USB_FORMAT_DETAILS=(exfat-details)
      _USB_FORMAT_MINIMUM_SIZES=(1048576) _USB_FORMAT_MAXIMUM_SIZES=(0)
    }
    choose_count=0 name_reads=0
    _usb_choose() {
      (( ++choose_count ))
      case $choose_count in
        (1) _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (2) _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=1 ;;
        (3)
          print -r -- "name-options:${(j:|:)_USB_PICKER_LABELS}"
          _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=custom-name ;;
        (*) return 2 ;;
      esac
    }
    _usb_read_volume_name() {
      (( ++name_reads ))
      print -r -- "name-read$name_reads:$1"
      if (( name_reads == 1 )); then
        _ZLE_PICKER_SELECTED_VALUE="Twelve Chars"
      else
        _ZLE_PICKER_SELECTED_VALUE="My USB"
      fi
    }
    _usb_format_workspace_controller || exit 2
    print -r -- "selected:$_USB_SELECTED_VOLUME_NAME|reads:$name_reads"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'name-options:Use default name · External|Give the volume a custom name…' \
    'the naming step did not present exactly the default and custom paths' || return
  test_assert_contains "$output" \
    'name-read2:ExFAT volume names are limited to 11 portable characters.' \
    'an invalid ExFAT label did not remain in the custom-name input with guidance' || return
  test_assert_contains "$output" 'selected:My USB|reads:2' \
    'the validated custom name did not cross the workspace boundary'
}
test_case 'USB format workspace validates and retains a custom volume name' \
  _test_usb_format_workspace_validates_a_custom_volume_name

_test_usb_format_reports_a_failed_catalog_capture() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$HOME
    _usb_external_device_choose() {
      _USB_DISK_IDS=(disk9) _USB_DISK_LABELS=(external-drive)
      _USB_DISK_SIZES=(9000000000) _USB_DISK_FINGERPRINTS=(disk-fingerprint)
      _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=1
    }
    _usb_diskutil_run() { return 1; }
    _usb_format_workspace_controller
    print -r -- "diskutil:$?|$_USB_FORMAT_ERROR"
    _usb_formats_capture() {
      _USB_CAPTURE_ERROR="diskutil reported no usable filesystem personalities"
      return 1
    }
    _usb_format_workspace_controller
    print -r -- "personalities:$?|$_USB_FORMAT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'diskutil:2|diskutil could not capture its filesystem catalog' \
    'a failed diskutil catalog capture was reported as a cancelled workspace' || return
  test_assert_contains "$output" \
    'personalities:2|diskutil reported no usable filesystem personalities' \
    'an unusable filesystem catalog was reported as a cancelled workspace'
}
test_case 'USB format reports a failed filesystem catalog capture' \
  _test_usb_format_reports_a_failed_catalog_capture

_test_usb_format_catalog_failure_is_not_a_cancel() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$HOME
    _matching_compile() { :; }
    # The format session runs for real; it opens no view before the catalog.
    source "$1/tests/picker_support.zsh"
    test_picker_script
    _usb_external_device_choose() {
      _USB_DISK_IDS=(disk9) _USB_DISK_LABELS=(external-drive)
      _USB_DISK_SIZES=(9000000000) _USB_DISK_FINGERPRINTS=(disk-fingerprint)
      _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=1
    }
    _usb_diskutil_run() { return 1; }
    _format_catalog_fixture() {
      external-device --format 2> "$HOME/error"
      print -r -- "format-status:$?"
      print -r -- END-FORMAT-CATALOG
    }
    source "$1/tests/pty_support.zsh" || exit 2
    local captured="" error=""
    test_pty_start format-catalog _format_catalog_fixture || exit 3
    {
      test_pty_expect format-catalog "" END-FORMAT-CATALOG
      captured=$TEST_PTY_OUTPUT
    } always {
      zpty -d format-catalog
    }
    [[ $captured == *END-FORMAT-CATALOG* ]] || exit 4
    error=$(<"$HOME/error")
    print -r -- "${captured//$'\''\r'\''/}"
    print -r -- "error:[$error]"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'format-status:2' \
    'external-device --format turned a failed catalog capture into success' || return
  test_assert_contains "$output" \
    'error:[external-device --format: diskutil could not capture its filesystem catalog]' \
    'external-device --format discarded the catalog capture diagnostic'
}
test_case 'USB format catalog failure is reported, not treated as cancel' \
  _test_usb_format_catalog_failure_is_not_a_cancel

# Script helper: _usb_flash and _usb_format declare their capture and result
# facts as typed locals, so nothing holds them at load. _test_usb_invocation_state
# sets reply to those names; with "declare" it also declares each globally with
# the entry point's type and initial value (arrays start empty), so a script
# that calls a USB helper directly runs it against the same typed state
# (integer assignment included).
_test_usb_invocation_state_script() {
  REPLY='
  _test_usb_invocation_state() {
    local entry="" line="" word=""
    local -a words=() flags=()
    reply=()
    for entry in _usb_flash _usb_format; do
      for line in "${(@f)functions[$entry]}"; do
        words=(${(z)line})
        [[ ${words[1]-} == local ]] || continue
        flags=("${(@M)words:#-*}")
        for word in "${(@M)words:#_USB_*}"; do
          reply+=("${word%%=*}")
          [[ ${1-} == declare ]] || continue
          if (( ${flags[(Ie)-a]} )); then
            typeset -g "${flags[@]}" -- "${word%%=*}"
            set -A "${word%%=*}"
          else
            typeset -g "${flags[@]}" -- "${(Q)word}"
          fi
        done
      done
    done
    reply=("${(@u)reply}")
  }
'
}

# Disk identity, image identity and writer diagnostics last only as long as
# the external-device invocation: only the USB limits exist at load, and
# afterwards every _USB_* parameter, REPLY and reply, and the picker selection
# and bookmark are back to their load-time values, whether the user leaves at
# Step 2, a write fails or a format completes.
_test_usb_invocation_state_ends_when_external_device_returns() {
  test_make_temp_dir || return
  local image="$TEST_TMP_DIR/media/compozsh-invocation.img" output='' snapshot='' REPLY=''
  # 65,535 bytes plus the trailing newline: one 64 KiB, 512-byte-aligned image.
  test_write_file "$image" "${(l:65535::x:)}" || return
  _test_usb_invocation_state_script
  # Support subset: the picker state declarations; the fixture stands in for the engine.
  output=$(test_run_interactive "$TEST_TMP_DIR/home" "$REPLY"'
    source "$1/.zsh.addons/support/ui/.zsh.ui.state" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset" || exit
    for usb_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do
      source "$usb_component" || exit
    done
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw" || exit
    TMPDIR=$HOME
    image=$2 scenario=escape
    sentinel_name="Sentinel Private Stick" sentinel_tree="IODeviceTree:/sentinel/usb@1"
    sentinel_path="$HOME/Sentinel/private-name.img"
    checksum=$(command /usr/bin/shasum -a 256 < "$image") checksum=${checksum%% *}
    list_plist="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>AllDisks</key><array><string>disk9</string></array></dict></plist>"
    info_plist="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>DeviceIdentifier</key><string>disk9</string><key>TotalSize</key><integer>64023257088</integer><key>DeviceBlockSize</key><integer>512</integer><key>MediaName</key><string>$sentinel_name</string><key>BusProtocol</key><string>USB</string><key>Internal</key><false/><key>VirtualOrPhysical</key><string>Physical</string><key>WholeDisk</key><true/><key>WritableMedia</key><true/><key>DeviceTreePath</key><string>$sentinel_tree</string></dict></plist>"
    _usb_diskutil_run() {
      case "$*" in
        ("list -plist external physical") print -r -- "$list_plist" ;;
        ("info -plist /dev/disk9") print -r -- "$info_plist" ;;
        (*) print -r -- "unexpected-diskutil:$*" >> "$HOME/trace"; return 1 ;;
      esac
    }
    _matching_compile() { :; }
    # Step 2 captures the drives; Escape or a selection follows. Like the
    # engine, an accepted view leaves its selection and bookmark (the filter
    # text included) in the caller scope. Later screens run their real
    # controller.
    _picker_outputs() {
      _ZLE_PICKER_SELECTED_VALUE=1 _ZLE_PICKER_BOOKMARK=("Sentinel filter" 1 0)
      _ZLE_PICKER_BOOKMARK_FOCUS=1
    }
    _zle_picker_run() {
      case $5 in
        (_usb_workspace_controller)
          _usb_external_disks_capture 1 "" raw-image || return 2
          _picker_outputs
          print -r -- "captured:flash:${(j:,:)_USB_DISK_IDS}" >> "$HOME/trace"
          [[ $scenario == write ]] || return 1
          _usb_workspace_request flash-verify 1 1 "${_USB_IMAGE_PATHS[1]}" disk9 "" \
            raw-image "$checksum" 256 matched
          return 0 ;;
        (_usb_format_workspace_controller)
          _usb_external_disks_capture 1 "" format || return 2
          _picker_outputs
          print -r -- "captured:format:${(j:,:)_USB_DISK_IDS}" >> "$HOME/trace"
          [[ $scenario == format ]] || return 1
          _USB_SELECTED_DISK=disk9 _USB_SELECTED_DISK_LABEL=${_USB_DISK_LABELS[1]}
          _USB_SELECTED_DISK_FINGERPRINT=${_USB_DISK_FINGERPRINTS[1]}
          _USB_SELECTED_DISK_SIZE=${_USB_DISK_SIZES[1]}
          _USB_SELECTED_FORMAT=APFS _USB_SELECTED_FORMAT_LABEL=APFS
          return 0 ;;
        (*) "$5" ;;
      esac
    }
    # Every device, privilege and terminal effect is a stand-in.
    _usb_confirm() { return 0; }
    _usb_format_confirm() { return 0; }
    _usb_authorize() { return 0; }
    _usb_authorization_valid() { return 0; }
    _usb_unmount() { return 0; }
    _usb_eject() { return 0; }
    _usb_diskutil_erase_run() {
      if [[ $scenario == format ]]; then
        print -r -- "erase:$2:$3:$4" >> "$HOME/trace"
        return 0
      fi
      print -r -- unexpected-erase >> "$HOME/trace"
      return 1
    }
    _usb_hdiutil_detach() { print -r -- unexpected-detach >> "$HOME/trace"; return 1; }
    _usb_raw_write_session_run() {
      print -u2 -r -- compozsh-write-stage:verify
      print -u2 -r -- "dd: $sentinel_path: Input/output error"
      return 1
    }
    _usb_media_result_screen() {
      print -r -- "result:$1:$2:$_USB_RESULT_VERIFY_REASON" >> "$HOME/trace"
    }
    _usb_state_snapshot() {
      local name=""
      for name in ${(ok)parameters[(I)(_USB_*|REPLY|reply|_ZLE_PICKER_SELECTED_VALUE|_ZLE_PICKER_BOOKMARK|_ZLE_PICKER_BOOKMARK_FOCUS)]}; do
        print -r -- "$name ${parameters[$name]}=${(j: :)${(@qq)${(@P)name}}}"
      done
    }
    _invocation_fixture() {
      REPLY=load-reply reply=(load-reply)
      _usb_state_snapshot >| "$HOME/baseline"
      external-device --flash "$image" 2>> "$HOME/errors"
      print -r -- "flash-escape:$?" >> "$HOME/trace"
      _usb_state_snapshot >| "$HOME/after-flash-escape"
      external-device --format 2>> "$HOME/errors"
      print -r -- "format-escape:$?" >> "$HOME/trace"
      _usb_state_snapshot >| "$HOME/after-format-escape"
      scenario=write
      external-device --flash "$image" 2>> "$HOME/errors"
      print -r -- "flash-write:$?" >> "$HOME/trace"
      _usb_state_snapshot >| "$HOME/after-flash-write"
      scenario=format
      external-device --format 2>> "$HOME/errors"
      print -r -- "format-write:$?" >> "$HOME/trace"
      _usb_state_snapshot >| "$HOME/after-format-write"
      print -r -- END-USB-INVOCATION
    }
    source "$1/tests/pty_support.zsh" || exit 2
    local captured=""
    test_pty_start usb-invocation _invocation_fixture || exit 3
    {
      test_pty_expect usb-invocation "" END-USB-INVOCATION 30
      captured=$TEST_PTY_OUTPUT
    } always {
      zpty -d usb-invocation 2>/dev/null
    }
    [[ $captured == *END-USB-INVOCATION* ]] || exit 4
    print -r -- "trace:${(j:,:)${(f)$(<"$HOME/trace")}}"
    local -a baseline=("${(@f)$(<"$HOME/baseline")}") current=() added=() removed=()
    # A name an entry point scopes has no global value (engineering/zsh.md);
    # the only USB parameters at load are its limits.
    local -a load_names=("${(@M)${(@)baseline%% *}:#_USB_*}") scoped=()
    local -a limits=(_USB_IMAGE_MAX_INDEXED _USB_IMAGE_MAX_PER_FOLDER
      _USB_ISO_TABLE_MAX_BYTES _USB_ISO_TABLE_MAX_ENTRIES
      _USB_MACOS_TARGET_MINIMUM _USB_PLIST_MAX_BYTES)
    _test_usb_invocation_state
    scoped=("${reply[@]}")
    print -r -- "scoped-names:${#scoped}"
    print -r -- "scoped-at-load:${(j:,:)${(@)load_names:*scoped}}"
    print -r -- "load-limits:${#${(@)load_names:*limits}}"
    print -r -- "load-state:${(j:,:)${(@)load_names:|limits}}"
    for snapshot in after-flash-escape after-format-escape after-flash-write after-format-write; do
      current=("${(@f)$(<"$HOME/$snapshot")}")
      added=(${current:|baseline}) removed=(${baseline:|current})
      print -r -- "${snapshot}:added:${(j:;:)added}"
      print -r -- "${snapshot}:removed:${(j:;:)removed}"
    done
    print -r -- end-of-snapshots
  ' "$TEST_REPO_ROOT" "$image") || return

  test_assert_contains "$output" \
    'trace:captured:flash:disk9,flash-escape:0,captured:format:disk9,format-escape:0,captured:flash:disk9,result:raw-image:6:drive-read-failed,flash-write:6,captured:format:disk9,erase:APFS:External:/dev/disk9,format-write:0' \
    'the external-device fixture did not capture the drive, fail the write and complete the format as staged' || return
  test_assert_contains "$output" $'\nload-limits:6\n' \
    'the parameter snapshot did not see the load-time USB limits' || return
  test_assert_contains "$output" $'\nload-state:\n' \
    'a USB parameter other than a limit has a load-time global value' || return
  [[ $output == *$'\n'scoped-names:<1->$'\n'* ]] ||
    test_fail "the USB entry points declared no invocation-local state: ${(qqq)output}" || return
  test_assert_contains "$output" $'\nscoped-at-load:\n' \
    'a name a USB entry point scopes has a load-time global value' || return
  for snapshot in after-flash-escape after-format-escape after-flash-write after-format-write; do
    test_assert_contains "$output" $'\n'"${snapshot}:added:"$'\n' \
      "external-device left new or changed USB state after $snapshot" || return
    test_assert_contains "$output" $'\n'"${snapshot}:removed:"$'\n' \
      "external-device removed or changed load-time USB state after $snapshot" || return
  done
  [[ $output != *[Ss]entinel* ]] ||
    test_fail "a captured disk name, device-tree path or writer error outlived external-device: ${(qqq)output}"
}
test_case 'USB invocation state ends when external-device returns' \
  _test_usb_invocation_state_ends_when_external_device_returns

_test_usb_volume_name_validation_is_format_aware() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_volume_name_validate "Portable 1" ExFAT
    print -r -- "fat-valid:$?|$REPLY"
    _usb_volume_name_validate "Bad.Name" "MS-DOS FAT32" >/dev/null
    print -r -- "fat-punctuation:$?|$_USB_FORMAT_ERROR"
    _usb_volume_name_validate "Trabajo ✓" APFS
    print -r -- "apfs-valid:$?|$REPLY"
    _usb_volume_name_validate "bad/name" APFS >/dev/null
    print -r -- "apfs-slash:$?|$_USB_FORMAT_ERROR"
    _usb_volume_name_validate "Third Party Volume" "Third Party FS" >/dev/null
    print -r -- "unknown-long:$?|$_USB_FORMAT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'fat-valid:0|Portable 1' \
    'a portable ExFAT name was rejected' || return
  test_assert_contains "$output" 'fat-punctuation:1|MS-DOS FAT32 names may use' \
    'an unsupported FAT punctuation character was accepted' || return
  test_assert_contains "$output" 'apfs-valid:0|Trabajo ✓' \
    'a printable APFS Unicode name was rejected' || return
  test_assert_contains "$output" 'apfs-slash:1|Volume name cannot contain' \
    'a path-separator-bearing APFS name was accepted' || return
  test_assert_contains "$output" \
    'unknown-long:1|Third Party FS volume names are limited to 11 portable characters.' \
    'an unknown advertised format bypassed conservative name validation'
}
test_case 'USB custom volume names use format-aware validation' \
  _test_usb_volume_name_validation_is_format_aware

_test_usb_format_execution_revalidates_immediately_before_erase() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    check_count=0
    _usb_target_revalidate() {
      (( ++check_count ))
      trace+=("check:$1:$2:$3")
      (( check_count <= ${allowed_checks:-2} ))
    }
    _usb_authorize() { trace+=(authorize); }
    _usb_diskutil_erase_run() { trace+=("erase:${(j:|:)@}"); }
    _usb_format_execute disk9 disk-fingerprint "MS-DOS FAT32" External 90000
    print -r -- "success:$?|${(j:,:)trace}"
    trace=() check_count=0 allowed_checks=1
    _usb_format_execute disk9 disk-fingerprint APFS External 90000 >/dev/null 2>&1
    print -r -- "changed:$?|${(j:,:)trace}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'success:0|check:disk9:disk-fingerprint:1,authorize,check:disk9:disk-fingerprint:1,erase:eraseDisk|MS-DOS FAT32|External|/dev/disk9' \
    'format execution did not revalidate and pass exact quoted operands to diskutil' || return
  test_assert_contains "$output" \
    'changed:1|check:disk9:disk-fingerprint:1,authorize,check:disk9:disk-fingerprint:1' \
    'a changed external drive was not rejected at the final erase boundary' || return
  [[ $output != *'changed:'*'erase:'* ]] ||
    test_fail 'diskutil erase ran after final target identity validation failed'
}
test_case 'USB format execution revalidates exact drive identity before eraseDisk' \
  _test_usb_format_execution_revalidates_immediately_before_erase

_test_usb_format_confirmation_is_target_bound() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_format_confirm disk9 "External SSD · /dev/disk9" ExFAT External <<< "ERASE disk8" >/dev/null
    print -r -- "wrong:$?|$_USB_CONFIRM_ERROR"
    _usb_format_confirm disk9 "External SSD · /dev/disk9" ExFAT External <<< "ERASE disk9" >/dev/null
    print -r -- "right:$?|$_USB_CONFIRM_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'wrong:1|Confirmation did not match. Expected exactly: ERASE disk9' \
    'format confirmation accepted or obscured a mismatched target phrase' || return
  test_assert_contains "$output" 'right:0|' \
    'format confirmation rejected the exact selected target phrase'
}
test_case 'USB format confirmation is bound to the exact whole disk' \
  _test_usb_format_confirmation_is_target_bound

_test_usb_format_report_uses_semantic_colors_with_plain_fallbacks() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    setopt EXTENDED_GLOB
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -gA ZSH_OUTPUT_COLORS=(heading 123 info 124 accent 125 success 126)
    TERM=xterm-256color
    source "$1/tests/pty_support.zsh" || exit 2
    _format_report_driver() {
      print -rl -- \
        "Started erase on disk28" \
        "Unmounting disk" \
        "Formatting disk28s2 as ExFAT with name KuroEx" \
        "Volume name      : KuroEx" \
        "# FAT sectors    : 4096" \
        "Finished erase on disk28" | _usb_format_output_filter
      _usb_format_print_summary disk28 ExFAT KuroEx
      print -r -- END-FORMAT-REPORT
    }
    _format_report_capture() {
      local mode=$1 capture=""
      if [[ $mode == plain ]]; then
        NO_COLOR=1 test_pty_start format-report _format_report_driver || return
      else
        test_pty_start format-report _format_report_driver || return
      fi
      {
        test_pty_expect format-report "" END-FORMAT-REPORT
        capture=$TEST_PTY_OUTPUT
        [[ $capture == *END-FORMAT-REPORT* ]] || return 1
        REPLY=${capture//$'\''\r'\''/}
        REPLY=${REPLY%$'\''\n'\''}
      } always {
        zpty -d format-report 2>/dev/null
      }
    }
    plain=$(_format_report_driver)
    [[ $plain != *$'\''\e'\''* ]] || exit 3
    _format_report_capture color || exit 4
    colored=$REPLY
    print -r -- "heading:$([[ $colored == *$'\''\e[1;38;5;123mStarted erase on disk28\e[0m'\''* ]] && print yes || print no)"
    print -r -- "stage:$([[ $colored == *$'\''\e[38;5;124mFormatting disk28s2 as ExFAT with name KuroEx\e[0m'\''* ]] && print yes || print no)"
    print -r -- "field:$([[ $colored == *$'\''\e[38;5;125mVolume name      \e[0m\e[38;5;124m: KuroEx\e[0m'\''* ]] && print yes || print no)"
    print -r -- "success:$([[ $colored == *$'\''\e[1;38;5;126mFinished erase on disk28\e[0m'\''* && $colored == *$'\''\e[1;38;5;126mFormatted /dev/disk28 as ExFAT.\e[0m'\''* ]] && print yes || print no)"
    stripped=${colored//$'\''\e'\''\[[0-9\;]#m/}
    stripped=${stripped%$'\''\n'\''}
    plain=${plain%$'\''\n'\''}
    print -r -- "same:$([[ $stripped == $plain ]] && print yes || print no)"
    _format_report_capture plain || exit 5
    print -r -- "no-color:$([[ $REPLY == $plain ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'heading:yes' \
    'format report did not style the native erase heading' || return
  test_assert_contains "$output" 'stage:yes' \
    'format report did not style the native progress stages' || return
  test_assert_contains "$output" 'field:yes' \
    'format report did not distinguish native field labels and values' || return
  test_assert_contains "$output" 'success:yes' \
    'format report did not style native and Compozsh completion lines' || return
  test_assert_contains "$output" 'same:yes' \
    'semantic styling changed the report text or line structure' || return
  test_assert_contains "$output" 'no-color:yes' \
    'NO_COLOR did not preserve the exact plain format report'
}
test_case 'USB format report uses semantic colors with exact plain fallbacks' \
  _test_usb_format_report_uses_semantic_colors_with_plain_fallbacks

_test_usb_format_report_preserves_diskutil_failure_status() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_diskutil_erase_run() {
      print -r -- "args:${(j:|:)@}"
      print -u2 -r -- native-format-error
      return 7
    }
    captured=$(_usb_format_erase_run eraseDisk ExFAT KuroEx /dev/disk28 2>&1)
    command_status=$?
    print -r -- "status:$command_status|$captured"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'status:7|args:eraseDisk|ExFAT|KuroEx|/dev/disk28' \
    'format report styling hid diskutil arguments or failure status' || return
  test_assert_contains "$output" 'native-format-error' \
    'format report styling discarded diskutil diagnostics'
}
test_case 'USB format report preserves diskutil failure status and diagnostics' \
  _test_usb_format_report_preserves_diskutil_failure_status

_test_usb_target_revalidation_detects_reuse() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_disk_info_capture() {
      _USB_INFO_ID=$1 _USB_INFO_SIZE=9000000 _USB_INFO_NAME=SameName
      _USB_INFO_PROTOCOL=USB _USB_INFO_EXTERNAL=1 _USB_INFO_WHOLE=1
      _USB_INFO_PHYSICAL=1 _USB_INFO_WRITABLE=1
      _USB_INFO_FINGERPRINT="${_USB_INFO_ID}|${_USB_INFO_SIZE}|${_USB_INFO_NAME}|${_USB_INFO_PROTOCOL}"
    }
    expected="disk7|9000000|SameName|USB"
    _usb_target_revalidate disk7 "$expected" 8000000
    print -r -- "same:$?"
    _usb_disk_info_capture() {
      _USB_INFO_ID=$1 _USB_INFO_SIZE=9000001 _USB_INFO_NAME=SameName
      _USB_INFO_PROTOCOL=USB _USB_INFO_EXTERNAL=1 _USB_INFO_WHOLE=1
      _USB_INFO_PHYSICAL=1 _USB_INFO_WRITABLE=1
      _USB_INFO_FINGERPRINT="${_USB_INFO_ID}|${_USB_INFO_SIZE}|${_USB_INFO_NAME}|${_USB_INFO_PROTOCOL}"
    }
    _usb_target_revalidate disk7 "$expected" 8000000 >/dev/null 2>&1
    print -r -- "changed:$?"
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'same:0' 'unchanged disk identity was rejected' || return
  test_assert_contains "$output" 'changed:1' 'reused or changed disk identity was accepted'
}
test_case 'USB target resolution revalidates captured device identity before writing' \
  _test_usb_target_revalidation_detects_reuse

_test_usb_confirmation_explains_exact_mismatch() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    read() { answer=ERASE; }
    _usb_confirm /images/linux.iso disk28 "DataTraveler · /dev/disk28" flash-verify >/dev/null
    print -r -- "short:$?|$_USB_CONFIRM_ERROR"
    read() { answer="ERASE disk28"; }
    _usb_confirm /images/linux.iso disk28 "DataTraveler · /dev/disk28" flash-verify >/dev/null
    print -r -- "exact:$?|$_USB_CONFIRM_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'short:1|Confirmation did not match. Expected exactly: ERASE disk28' \
    'a shortened destructive confirmation did not explain the exact required text' || return
  test_assert_contains "$output" 'exact:0|' \
    'the exact disk-bound destructive confirmation was rejected'
}
test_case 'USB confirmation explains mismatches without weakening target binding' \
  _test_usb_confirmation_explains_exact_mismatch

_test_usb_confirmation_colors_only_exact_phrase() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.output" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_confirmation_prompt "ERASE disk28"
    [[ $REPLY == "Type exactly ERASE disk28 to continue: " ]] || exit 2
    source "$1/tests/pty_support.zsh" || exit 3
    _colored_confirmation() {
      TERM=xterm-256color
      unset NO_COLOR
      _usb_confirm /images/linux.iso disk28 target flash-verify
    }
    local frame=""
    test_pty_start usb-colored _colored_confirmation || exit 4
    {
      test_pty_expect usb-colored "" "to continue: " || exit 5
      frame=$TEST_PTY_OUTPUT
      [[ $frame == *$'\''\e[1;38;5;221mERASE disk28\e[0m'\''* ]] || exit 6
      zpty -w usb-colored "ERASE disk28"
    } always { zpty -d usb-colored 2>/dev/null; }
    _plain_confirmation() {
      TERM=xterm-256color NO_COLOR=1
      _usb_confirm /images/linux.iso disk28 target flash-verify
    }
    frame=""
    test_pty_start usb-plain _plain_confirmation || exit 7
    {
      test_pty_expect usb-plain "" "to continue: " || exit 8
      frame=$TEST_PTY_OUTPUT
      [[ $frame == *"Type exactly ERASE disk28 to continue: "* && $frame != *$'\''\e'\''* ]] || exit 9
      zpty -w usb-plain "ERASE disk28"
    } always { zpty -d usb-plain 2>/dev/null; }
    print color-contract
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal color-contract "$output"
}
test_case 'USB confirmation colors only the exact phrase with plain fallbacks' \
  _test_usb_confirmation_colors_only_exact_phrase

_test_usb_execution_preserves_failures_and_ejects() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    _usb_authorize() { trace+=(authorize); }
    _usb_authorization_valid() { return 0; }
    _usb_image_revalidate() { trace+=(image-revalidate); }
    _usb_target_revalidate() { trace+=(revalidate); }
    _usb_unmount() { trace+=(unmount); }
    _usb_write_image() {
      trace+=(write)
      _USB_WRITE_STAGE=${write_stage:-image} _USB_WRITE_ERROR=''
      if (( ${write_status:-0} )); then
        [[ $_USB_WRITE_STAGE == image ]] &&
          _USB_WRITE_ERROR="dd: /dev/rdisk7: Resource busy"
      else
        _USB_WRITE_VERIFIED=1
      fi
      return ${write_status:-0}
    }
    _usb_eject() { trace+=(eject); return ${eject_status:-0}; }

    write_status=5 write_stage=verify
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100352 flash-verify >/dev/null 2>&1
    print -r -- "verify-status:$?|${(j:,:)trace}|$_USB_RESULT_VERIFY_REASON"
    trace=() write_status=7 write_stage=image
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100352 flash-verify >/dev/null 2>&1
    print -r -- "write-status:$?|${(j:,:)trace}|$_USB_RESULT_ERROR"
    trace=() write_status=0
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100352 flash-verify disk7 >/dev/null 2>&1
    print -r -- "source-status:$?|${(j:,:)trace}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'verify-status:5|authorize,image-revalidate,revalidate,unmount,revalidate,write,eject|mismatch' \
    'verification failure or eject cleanup was lost' || return
  test_assert_contains "$output" \
    'write-status:7|authorize,image-revalidate,revalidate,unmount,revalidate,write,eject|Writing failed: dd: /dev/rdisk7: Resource busy.' \
    'write failure did not stop verification or retain the actionable native diagnostic' || return
  test_assert_contains "$output" 'source-status:1|' \
    'execution allowed the image source disk to become its own write target'
}
test_case 'USB execution preserves write and verify failures while attempting eject' \
  _test_usb_execution_preserves_failures_and_ejects

_test_usb_checksum_gates_write_and_reuses_algorithm() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    expected=${(l:64::a:)}
    typeset -ga trace=()
    _usb_progress_stage() { trace+=("stage:$1"); }
    _usb_image_revalidate() { trace+=(image-revalidate); }
    _usb_image_checksum() { trace+=("image-sha:$2"); REPLY=${actual:-$expected}; }
    _usb_authorization_valid() { return 0; }
    _usb_target_revalidate() { trace+=(target-revalidate); }
    _usb_unmount() { trace+=(unmount); }
    _usb_write_image() { trace+=(write); _USB_WRITE_VERIFIED=1; }
    _usb_eject() { trace+=(eject); }

    actual=${(l:64::b:)}
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 256 "$expected" >/dev/null 2>&1
    print -r -- "mismatch:$?|${(j:,:)trace}|$_USB_RESULT_STARTED|$_USB_RESULT_ERROR"

    trace=() actual=$expected
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 256 "$expected" >/dev/null 2>&1
    print -r -- "matched:$?|${(j:,:)trace}|$_USB_RESULT_CHECKSUM_VALIDATED|$_USB_RESULT_VERIFIED"
    _usb_result_choose() { print -r -- "summary:${(j:|:)_USB_PICKER_LABELS}"; }
    _usb_media_result_screen raw-image 0
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'mismatch:1|stage:Validating image and drive,image-revalidate,stage:Checking image SHA-256,image-sha:256|0|The image SHA-256 does not match' \
    'a mismatched provided checksum reached the target or write boundary' || return
  test_assert_contains "$output" 'matched:0|' \
    'a matching provided checksum did not complete' || return
  test_assert_contains "$output" 'image-sha:256,target-revalidate,stage:Unmounting external drive,unmount,target-revalidate,stage:Writing image,write,unmount,image-revalidate,stage:Rechecking image SHA-256,image-sha:256,stage:Ejecting external drive,eject|1|1' \
    'a matching source checksum did not retain authoritative raw USB verification' || return
  test_assert_contains "$output" 'summary:Done|Flash complete' \
    'checksum completion did not retain the normal success summary' || return
  test_assert_contains "$output" 'Image integrity · Verified · SHA-256 matched|USB verification · Full image byte-for-byte matched|Safe to remove' \
    'completion summary omitted checksum and finished-drive validation'
}
test_case 'USB checksum mismatch prevents writing and a match verifies raw drive bytes' \
  _test_usb_checksum_gates_write_and_reuses_algorithm

_test_usb_native_dd_progress_is_determinate() {
  test_make_temp_dir || return
  local progress_file="$TEST_TMP_DIR/dd-progress" output=''
  test_write_file "$progress_file" $'  1048576 bytes (1049 kB, 1024 KiB) transferred 1.001s, 1048 kB/s\r  4194304 bytes (4194 kB, 4096 KiB) transferred 4.001s, 1048 kB/s\r' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    SECONDS=20
    _usb_dd_progress_read "$2" 8388608 10
    print -r -- "bar:${_USB_PROGRESS_BAR}"
    print -r -- "detail:$REPLY"
  ' "$TEST_REPO_ROOT" "$progress_file") || return

  test_assert_contains "$output" '50%' \
    'native macOS dd live status output did not produce determinate progress' || return
  test_assert_contains "$output" '4.0 MiB of 8.0 MiB' \
    'progress detail omitted exact completed and total bytes' || return
  test_assert_contains "$output" 'elapsed' \
    'progress detail omitted elapsed time'
}
test_case 'USB write progress is determinate from native dd byte output' \
  _test_usb_native_dd_progress_is_determinate

_test_usb_progress_uses_prominent_status_view() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_SELECTED_IMAGE=/Users/example/Downloads/linux.iso
    _USB_SELECTED_DISK=disk28
    _USB_SELECTED_DISK_LABEL="DataTraveler 3.0 · 57.7 GiB · USB · /dev/disk28"
    _USB_SELECTED_IMAGE_ARCHITECTURE=x86_64
    _zle_picker_capture() {
      print -r -- "mode:${_ZLE_PICKER_STATUS_VIEW}|${_ZLE_PICKER_BUSY_LABEL}"
      print -r -- "lines:${(j:|:)_ZLE_PICKER_BUSY_LINES}"
      print -r -- "styles:${(j:|:)_ZLE_PICKER_BUSY_STYLES}"
    }
    _usb_progress_stage "Writing image" progress "[========········] 50%" \
      info "768.0 MiB of 1.5 GiB · 20s elapsed" warning "KEEP THE EXTERNAL DRIVE CONNECTED"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'mode:1|● WRITING IMAGE' \
    'Step 3 did not opt into the dedicated status layout' || return
  for fact in 'IMAGE' 'linux.iso' 'TARGET' 'DataTraveler 3.0' \
      'IMAGE ARCHITECTURE' 'x86-64' '[========········] 50%' \
      'KEEP THE EXTERNAL DRIVE CONNECTED'; do
    test_assert_contains "$output" "$fact" 'Step 3 status view omitted prominent task context' || return
  done
  test_assert_contains "$output" 'picker-status-progress' \
    'Step 3 progress did not request semantic success color' || return
  test_assert_contains "$output" 'picker-status-warning' \
    'Step 3 disconnect warning did not request semantic warning color'
}
test_case 'USB Step 3 uses a prominent colored status view' \
  _test_usb_progress_uses_prominent_status_view

_test_usb_write_worker_is_bounded_and_cleaned() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    job_marker="$2/job-options-on"
    setopt NOTIFY
    typeset -ga painted=()
    _usb_progress_stage() { painted+=("$1|$3"); }
    _usb_raw_write_session_run() {
      [[ -o MONITOR || -o NOTIFY ]] && print -r -- on >| "$job_marker"
      print -u2 -r -- "4194304 bytes transferred in 1.0 secs (4194304 bytes/sec)\r"
      command /bin/sleep 0.1
      print -u2 -r -- "8388608 bytes transferred in 2.0 secs (4194304 bytes/sec)\r"
    }
    _usb_write_image /images/linux.iso disk7 8388608 || exit 2
    leftovers=("$2"/compozsh-usb-progress.*(N))
    print -r -- "painted:${(j:,:)painted}"
    print -r -- "leftovers:${#leftovers}"
    print -r -- "job-options:$([[ -e $job_marker ]] && print on || print off)"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" 'Writing image|' \
    'temporary native dd worker never painted its captured progress' || return
  test_assert_contains "$output" 'leftovers:0' \
    'temporary native dd worker leaked its bounded progress file' || return
  test_assert_contains "$output" 'job-options:off' \
    'native dd worker retained visible interactive job notifications'
}
test_case 'USB native write worker is temporary bounded and cleaned' \
  _test_usb_write_worker_is_bounded_and_cleaned

_test_usb_write_rejects_successful_early_eof() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-short" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -u2 -r -- "4194304 bytes transferred in 1.0 secs (4194304 bytes/sec)\r"
      return 0
    }
    _usb_write_image /images/linux.iso disk7 8388608
    print -r -- "status:$?|bytes:${_USB_WRITE_BYTES_OBSERVED:-0}"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" 'status:3|bytes:4194304' \
    'dd exit zero with an early source EOF was reported as a complete write'
}
test_case 'USB write requires dd to report the exact captured image size' \
  _test_usb_write_rejects_successful_early_eof

_test_usb_raw_session_is_bounded_to_captured_sectors() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-bounded" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -r -- "args:$*"
      print -u2 -r -- "8388608 bytes transferred in 1.0 secs (8388608 bytes/sec)\r"
    }
    _usb_write_image /images/linux.iso disk7 8388608
    print -r -- "status:$?"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" 'args:/images/linux.iso disk7 16384 0 0' \
    'the privileged raw session was allowed past the captured sector count' || return
  test_assert_contains "$output" 'status:0' \
    'an exact sector-bounded write did not complete'
}
test_case 'USB raw write session reads exactly the captured sector count' \
  _test_usb_raw_session_is_bounded_to_captured_sectors

_test_usb_write_clears_stale_physical_tail_gpt() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-tail" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    trace_file=$2/write-calls
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -r -- "$*" >> "$trace_file"
      print -u2 -r -- "compozsh-write-stage:image"
      print -u2 -r -- "8388608 bytes transferred in 1.0 secs (8388608 bytes/sec)\r"
    }
    _usb_write_image /images/linux.iso disk7 8388608 16777216
    print -r -- "status:$?"
    print -r -- "calls:$(<$trace_file)"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" \
    'calls:/images/linux.iso disk7 16384 32735 33' \
    'the single raw-device session did not receive both the exact image bound and physical-tail cleanup range' || return
  test_assert_contains "$output" 'status:0' \
    'a successful bounded tail cleanup and image write did not complete'
}
test_case 'USB raw write session keeps tail cleanup and image output on one device open' \
  _test_usb_write_clears_stale_physical_tail_gpt

_test_usb_raw_session_writes_exact_offsets_through_one_descriptor() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source.iso"
  local target_image="$TEST_TMP_DIR/target.img"
  local expected_middle="$TEST_TMP_DIR/expected-middle"
  local expected_tail="$TEST_TMP_DIR/expected-tail"
  local fingerprint='' output=''
  /usr/bin/printf '%8192s' '' | /usr/bin/tr ' ' S >| "$source_image" || return
  /usr/bin/printf '%16384s' '' | /usr/bin/tr ' ' T >| "$target_image" || return
  /usr/bin/printf '%7680s' '' | /usr/bin/tr ' ' T >| "$expected_middle" || return
  command /bin/dd if=/dev/zero of="$expected_tail" bs=512 count=1 \
    status=none || return
  fingerprint=$(command /usr/bin/stat -f '%d:%i:%z:%m:%B' "$source_image") || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_raw_write_script_capture || exit
    script=$REPLY
    command /bin/zsh -fc "$script" compozsh-write-test \
      "$2" "$3" 16 31 1 1 512 "${10}" 2>| "$6"
    session_status=$?
    command /bin/dd if="$3" of="$7" bs=512 count=16 status=none || exit
    command /bin/dd if="$3" of="$8" bs=512 skip=16 count=15 status=none || exit
    command /bin/dd if="$3" of="$9" bs=512 skip=31 count=1 status=none || exit
    command /usr/bin/cmp -s "$2" "$7"
    prefix_status=$?
    command /usr/bin/cmp -s "$4" "$8"
    middle_status=$?
    command /usr/bin/cmp -s "$5" "$9"
    tail_status=$?
    command /bin/zsh -fc "$script" compozsh-write-mismatch \
      "$2" "$3" 16 15 1 1 512 "${10}" 2>/dev/null
    mismatch_status=$?
    command /bin/zsh -fc "$script" compozsh-write-source-size \
      "$2" "$3" 15 0 0 1 512 "${10}" 2>/dev/null
    source_status=$?
    size=$(command /usr/bin/stat -f "%z" "$3") || exit
    diagnostic=$(<"$6")
    diagnostic=${diagnostic//$'\r'/$'\n'}
    print -r -- "status:$session_status|size:$size|prefix:$prefix_status|middle:$middle_status|tail:$tail_status"
    print -r -- "diagnostic:${(j:|:)${(f)diagnostic}}"
    print -r -- "named-read:$([[ $script == *'\''if="$device"'\''* ]] && print yes || print no)"
    print -r -- "mismatch:$mismatch_status|source:$source_status"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image" \
    "$expected_middle" "$expected_tail" "$TEST_TMP_DIR/session-stderr" \
    "$TEST_TMP_DIR/prefix" "$TEST_TMP_DIR/middle" "$TEST_TMP_DIR/tail" \
    "$fingerprint") || return

  test_assert_contains "$output" \
    'status:0|size:16384|prefix:0|middle:0|tail:0' \
    'the real single-descriptor writer changed bytes outside the captured image and physical-tail ranges' || return
  test_assert_contains "$output" \
    'compozsh-write-stage:image' \
    'the real raw session did not identify the image-write stage' || return
  test_assert_contains "$output" \
    'compozsh-write-stage:tail' \
    'the real raw session did not identify the physical-tail cleanup stage' || return
  test_assert_contains "$output" \
    'compozsh-write-stage:verify' \
    'the real raw session did not verify before releasing its device descriptor' || return
  test_assert_contains "$output" \
    'compozsh-write-verified' \
    'the real raw session did not publish exact pre-mount verification evidence' || return
  test_assert_contains "$output" \
    'compozsh-write-tail-verified' \
    'the real raw session did not read back its physical-tail cleanup' || return
  [[ $output == *'compozsh-write-stage:image'*'compozsh-write-stage:tail'*'compozsh-write-stage:verify'*'compozsh-write-verified'* ]] || {
    test_fail 'the single raw session did not preserve image, tail, and verification order'
    return
  }
  [[ $output != *'Operation not permitted'* ]] || {
    test_fail 'the raw session tried to reopen an inherited descriptor through /dev/fd'
    return
  }
  test_assert_contains "$output" 'named-read:yes' \
    'Apple dd was not given the named raw device required for uncached read-back' || return
  test_assert_contains "$output" 'mismatch:5|source:7' \
    'the native verifier did not distinguish a byte mismatch from invalid source evidence'
}
test_case 'USB raw session writes exact byte ranges through one held descriptor' \
  _test_usb_raw_session_writes_exact_offsets_through_one_descriptor

_test_usb_atomic_verifier_uses_exact_multi_megabyte_reads() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source-large.iso"
  local target_image="$TEST_TMP_DIR/target-large.img"
  local fingerprint='' script='' output=''
  local -i image_size=$(( 4194304 + 4096 ))

  command /bin/dd if=/dev/zero of="$source_image" bs=4096 count=1025 \
    status=none || return
  /usr/bin/printf '%4096s' '' | /usr/bin/tr ' ' X |
    command /bin/dd of="$source_image" bs=4096 seek=1024 count=1 \
      conv=notrunc status=none || return
  command /bin/dd if=/dev/zero of="$target_image" bs=4096 count=1025 \
    status=none || return
  fingerprint=$(command /usr/bin/stat -f '%d:%i:%z:%m:%B' "$source_image") || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_raw_write_script_capture || exit
    script=$REPLY
    print -r -- "bulk:$([[ $script == *'\''verify_bulk_label=4m'\''*'\''if="$device" bs="$verify_bulk_label"'\''*'\''count="$verify_bulk_blocks" iflag=direct,fullblock'\''* ]] && print yes || print no)"
    print -r -- "tail:$([[ $script == *'\''bs="$block_size" skip="$verify_tail_skip"'\''*'\''count="$verify_tail_blocks" iflag=direct,fullblock'\''* ]] && print yes || print no)"
    print -r -- "tiny:$([[ $script == *'\''if="$device" ibs=512 obs=4m'\''* ]] && print yes || print no)"
    command /bin/zsh -fc "$script" compozsh-large-verify \
      "$2" "$3" 8200 0 0 1 4096 "$4" 2>| "$5"
    session_status=$?
    diagnostic=$(<"$5")
    diagnostic=${diagnostic//$'\''\r'\''/$'\''\n'\''}
    print -r -- "status:$session_status|diagnostic:${(j:|:)${(f)diagnostic}}"
    command /bin/zsh -fc "$script" compozsh-large-mismatch \
      "$2" "$3" 8200 8192 8 1 4096 "$4" 2>| "$6"
    mismatch_status=$?
    mismatch_diagnostic=$(<"$6")
    mismatch_diagnostic=${mismatch_diagnostic//$'\''\r'\''/$'\''\n'\''}
    print -r -- "mismatch:$mismatch_status|diagnostic:${(j:|:)${(f)mismatch_diagnostic}}"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image" "$fingerprint" \
    "$TEST_TMP_DIR/large-verify-stderr" \
    "$TEST_TMP_DIR/large-mismatch-stderr") || return

  test_assert_contains "$output" 'bulk:yes' \
    'atomic verification did not request multi-megabyte uncached raw reads' || return
  test_assert_contains "$output" 'tail:yes' \
    'atomic verification did not preserve an exact logical-block tail read' || return
  test_assert_contains "$output" 'tiny:no' \
    'atomic verification retained millions of uncached 512-byte reads' || return
  test_assert_contains "$output" \
    "status:0|diagnostic:compozsh-write-stage:open|compozsh-write-stage:image" \
    'optimized atomic verification rejected a non-4-MiB-aligned image' || return
  test_assert_contains "$output" "compozsh-write-verify-bytes:$image_size" \
    'atomic verification did not publish exact completed read evidence' || return
  test_assert_contains "$output" 'compozsh-write-verified' \
    'optimized atomic verification omitted final byte-match evidence' || return
  test_assert_contains "$output" \
    "mismatch:5|diagnostic:compozsh-write-stage:open|compozsh-write-stage:image" \
    'a real split raw read did not preserve byte-mismatch status' || return
  [[ $output == *'mismatch:5|'*"compozsh-write-verify-bytes:$image_size"* ]] || {
    test_fail 'a complete mismatched split read omitted exact read evidence'
    return
  }
}
test_case 'USB atomic verification uses exact multi-megabyte raw reads' \
  _test_usb_atomic_verifier_uses_exact_multi_megabyte_reads

_test_usb_atomic_verifier_handles_exact_bulk_blocks() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source-aligned.iso"
  local target_image="$TEST_TMP_DIR/target-aligned.img"
  local fingerprint='' output=''

  command /bin/dd if=/dev/zero of="$source_image" bs=4m count=2 \
    status=none || return
  command /bin/dd if=/dev/zero of="$target_image" bs=4m count=2 \
    status=none || return
  fingerprint=$(command /usr/bin/stat -f '%d:%i:%z:%m:%B' "$source_image") || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_raw_write_script_capture || exit
    command /bin/zsh -fc "$REPLY" compozsh-aligned-verify \
      "$2" "$3" 16384 0 0 1 512 "$4" 2>| "$5"
    session_status=$?
    diagnostic=$(<"$5")
    diagnostic=${diagnostic//$'\''\r'\''/$'\''\n'\''}
    verify_diagnostic=${diagnostic#*compozsh-write-stage:verify}
    print -r -- "status:$session_status|diagnostic:${(j:|:)${(f)verify_diagnostic}}"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image" "$fingerprint" \
    "$TEST_TMP_DIR/aligned-verify-stderr") || return

  test_assert_contains "$output" \
    'status:0|diagnostic:2+0 records in|2+0 records out' \
    'an exact 8 MiB payload did not use two complete 4 MiB raw reads' || return
  test_assert_contains "$output" 'compozsh-write-verify-bytes:8388608' \
    'an exact bulk-only read omitted complete byte evidence' || return
  test_assert_contains "$output" 'compozsh-write-verified' \
    'an exact bulk-only read omitted final match evidence'
}
test_case 'USB atomic verification handles exact bulk blocks' \
  _test_usb_atomic_verifier_handles_exact_bulk_blocks

_test_usb_atomic_split_read_progress_is_exact() {
  test_make_temp_dir || return
  local progress_file="$TEST_TMP_DIR/atomic-split-progress" output=''
  test_write_file "$progress_file" $'compozsh-write-stage:verify\n4194304 bytes transferred in 1.0 secs (4194304 bytes/sec)\r4096 bytes transferred in 0.1 secs (40960 bytes/sec)\rcompozsh-write-verify-bytes:4198400\ncompozsh-write-verified\n' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    _usb_dd_progress_read "$2" 4198400 0
    print -r -- "bytes:$_USB_WRITE_VERIFY_BYTES_OBSERVED|verified:$_USB_WRITE_VERIFIED|detail:$REPLY"
  ' "$TEST_REPO_ROOT" "$progress_file") || return

  test_assert_contains "$output" \
    'bytes:4198400|verified:1|detail:4.0 MiB of 4.0 MiB' \
    'split raw reads did not publish exact cumulative completion progress'
}
test_case 'USB atomic split-read progress is exact and cumulative' \
  _test_usb_atomic_split_read_progress_is_exact

_test_usb_atomic_split_read_preserves_mismatch_status() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-split-mismatch" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -u2 -r -- "compozsh-write-stage:image"
      print -u2 -r -- "4198400 bytes transferred in 1.0 secs (4198400 bytes/sec)\r"
      print -u2 -r -- "compozsh-write-stage:verify"
      print -u2 -r -- "4194304 bytes transferred in 1.0 secs (4194304 bytes/sec)\r"
      print -u2 -r -- "4096 bytes transferred in 0.1 secs (40960 bytes/sec)\r"
      print -u2 -r -- "compozsh-write-verify-bytes:4198400"
      return 5
    }
    _usb_write_image /images/linux.iso disk7 4198400 4198400 1 4096
    print -r -- "status:$?|read:$_USB_WRITE_VERIFY_BYTES_OBSERVED|verified:$_USB_WRITE_VERIFIED"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" 'status:5|read:4198400|verified:0' \
    'a complete split read mislabeled a byte mismatch as a short device read'
}
test_case 'USB atomic split reads preserve mismatch status' \
  _test_usb_atomic_split_read_preserves_mismatch_status

_test_usb_raw_session_pins_the_captured_source() {
  test_make_temp_dir || return
  local image="$TEST_TMP_DIR/source.iso" replacement="$TEST_TMP_DIR/replacement.iso"
  local target="$TEST_TMP_DIR/target.img" fingerprint='' output=''

  /usr/bin/printf '%512s' '' | /usr/bin/tr ' ' A >| "$image" || return
  /usr/bin/printf '%512s' '' | /usr/bin/tr ' ' B >| "$replacement" || return
  /usr/bin/printf '%512s' '' | /usr/bin/tr ' ' T >| "$target" || return
  fingerprint=$(command /usr/bin/stat -f '%d:%i:%z:%m:%B' "$image") || return
  command /bin/mv -f -- "$replacement" "$image" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_raw_write_script_capture || exit
    command /bin/zsh -fc "$REPLY" compozsh-source-race \
      "$2" "$3" 1 0 0 0 512 "$4" 2>/dev/null
    write_status=$?
    first_byte=$(command /usr/bin/head -c 1 "$3") || exit
    print -r -- "$write_status|$first_byte"
  ' "$TEST_REPO_ROOT" "$image" "$target" "$fingerprint") || return

  test_assert_equal '7|T' "$output" \
    'raw writing reopened a same-size replacement instead of the captured image'
}
test_case 'USB raw write pins the captured source identity' \
  _test_usb_raw_session_pins_the_captured_source

_test_usb_execution_uses_atomic_premount_verification() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    _usb_progress_stage() { trace+=("stage:$1"); }
    _usb_authorize() { return 0; }
    _usb_authorization_valid() { return 0; }
    _usb_image_revalidate() { trace+=(image-revalidate); return 0; }
    _usb_target_revalidate() { trace+=(target-revalidate); return 0; }
    _usb_unmount() { trace+=(unmount); return 0; }
    _usb_write_image() {
      trace+=(atomic-write-verify)
      _USB_WRITE_BYTES_OBSERVED=$3
      _USB_WRITE_VERIFIED=1
      _USB_WRITE_VERIFY_SECONDS=3
      return 0
    }
    # The stubbed write session already returned its evidence, so any further
    # privileged device primitive is a late reread.
    _usb_raw_write_session_run() { trace+=(late-verify); return 0; }
    _usb_diskutil_erase_run() { trace+=(late-verify); return 0; }
    _usb_eject() { trace+=(eject); return 0; }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 >/dev/null 2>&1
    print -r -- "status:$?|${(j:,:)trace}|verified:$_USB_RESULT_VERIFIED|scope:$_USB_RESULT_VERIFY_SCOPE|seconds:$_USB_RESULT_VERIFY_SECONDS"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'atomic-write-verify,unmount,image-revalidate' \
    'the raw session did not finish verification before its descriptor was released' || return
  [[ $output != *'late-verify'* ]] || {
    test_fail 'execution reread media after macOS could auto-mount and modify it'
    return
  }
  test_assert_contains "$output" \
    'verified:1|scope:full|seconds:3' \
    'the completion result discarded exact pre-mount verification evidence'
}
test_case 'USB execution uses atomic pre-mount verification evidence' \
  _test_usb_execution_uses_atomic_premount_verification

_test_usb_flash_verify_without_session_evidence_fails_closed() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    _usb_progress_stage() { return 0; }
    _usb_authorize() { return 0; }
    _usb_authorization_valid() { return 0; }
    _usb_image_revalidate() { return 0; }
    _usb_target_revalidate() { return 0; }
    _usb_unmount() { return 0; }
    _usb_write_image() { _USB_WRITE_BYTES_OBSERVED=$3; return 0; }
    _usb_raw_write_session_run() { trace+=(late-reread); return 0; }
    _usb_diskutil_erase_run() { trace+=(late-reread); return 0; }
    _usb_eject() { trace+=(eject); return 0; }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 >/dev/null 2>&1
    result_status=$?
    print -r -- "status:$result_status|${(j:,:)trace}|verified:$_USB_RESULT_VERIFIED|reason:$_USB_RESULT_VERIFY_REASON|outcome:$_USB_RESULT_OUTCOME"
  ' "$TEST_REPO_ROOT") || return

  [[ $output != *'late-reread'* ]] || {
    test_fail 'flash-verify reread the drive after its write session closed'
    return
  }
  test_assert_equal "$output" \
    'status:9|eject|verified:0|reason:incomplete-evidence|outcome:failed' \
    'flash-verify without in-session evidence did not fail closed'
}
test_case 'USB flash-verify without in-session evidence fails closed instead of rereading' \
  _test_usb_flash_verify_without_session_evidence_fails_closed

_test_usb_atomic_failure_retains_semantic_reason() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    _usb_progress_stage() { return 0; }
    _usb_authorize() { return 0; }
    _usb_authorization_valid() { return 0; }
    _usb_image_revalidate() { return 0; }
    _usb_target_revalidate() { _USB_INFO_BLOCK_SIZE=512; return 0; }
    _usb_unmount() { return 0; }
    _usb_write_image() {
      _USB_WRITE_STAGE=verify
      _USB_WRITE_BYTES_OBSERVED=$3
      return 5
    }
    _usb_eject() { return 0; }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 >/dev/null 2>&1
    result_status=$?
    _usb_result_choose() { print -r -- "rows:${(j:|:)_USB_PICKER_LABELS}"; }
    _usb_media_result_screen raw-image "$result_status"
    print -r -- "status:$result_status|reason:$_USB_RESULT_VERIFY_REASON"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'status:5|reason:mismatch' \
    'atomic mismatch lost its machine-readable verification reason' || return
  test_assert_contains "$output" \
    'USB verification · FAILED · installer or boot bytes differ' \
    'atomic mismatch omitted the semantic verification failure row'
}
test_case 'USB atomic failure retains its semantic verification reason' \
  _test_usb_atomic_failure_retains_semantic_reason

_test_usb_atomic_verification_distinguishes_short_reads() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-short-verify" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -u2 -r -- "compozsh-write-stage:image"
      print -u2 -r -- "8388608 bytes transferred in 1.0 secs (8388608 bytes/sec)\r"
      print -u2 -r -- "compozsh-write-stage:verify"
      print -u2 -r -- "4194304 bytes transferred in 1.0 secs (4194304 bytes/sec)\r"
      return 5
    }
    _usb_write_image /images/linux.iso disk7 8388608 8388608 1
    print -r -- "status:$?|write:$_USB_WRITE_BYTES_OBSERVED|read:$_USB_WRITE_VERIFY_BYTES_OBSERVED|verified:$_USB_WRITE_VERIFIED"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" \
    'status:6|write:8388608|read:4194304|verified:0' \
    'a short raw-device read was mislabeled as a byte mismatch'
}
test_case 'USB atomic verification distinguishes short reads from mismatches' \
  _test_usb_atomic_verification_distinguishes_short_reads

_test_usb_write_respects_target_logical_block_size() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-block-size" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -r -- "args:$*"
      print -u2 -r -- "compozsh-write-stage:image"
      print -u2 -r -- "8192 bytes transferred in 1.0 secs (8192 bytes/sec)\r"
    }
    _usb_write_image /images/linux.iso disk7 8192 32768 0 4096
    print -r -- "aligned:$?"
    _usb_write_image /images/linux.iso disk7 10240 32768 0 4096
    print -r -- "unaligned:$?"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" \
    'args:/images/linux.iso disk7 16 24 40 0 4096' \
    'physical-tail cleanup was not rounded to complete 4 KiB logical blocks' || return
  test_assert_contains "$output" 'aligned:0' \
    'a block-aligned image was rejected for a 4 KiB target' || return
  test_assert_contains "$output" 'unaligned:2' \
    'an image ending inside a 4 KiB logical block reached the raw writer'
}
test_case 'USB raw writer respects target logical block size' \
  _test_usb_write_respects_target_logical_block_size

_test_usb_atomic_progress_separates_write_and_verify() {
  test_make_temp_dir || return
  local progress_file="$TEST_TMP_DIR/atomic-progress" output=''
  test_write_file "$progress_file" $'compozsh-write-stage:image\n8388608 bytes transferred in 1.0 secs (8388608 bytes/sec)\rcompozsh-write-stage:tail\ncompozsh-write-stage:verify\n4194304 bytes transferred in 2.0 secs (2097152 bytes/sec)\r8388608 bytes transferred in 4.0 secs (2097152 bytes/sec)\rcompozsh-write-tail-verified\ncompozsh-write-verified\n' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    _usb_dd_progress_read "$2" 8388608 0
    print -r -- "stage:$_USB_WRITE_STAGE|write:$_USB_WRITE_BYTES_OBSERVED|verify:$_USB_WRITE_VERIFY_BYTES_OBSERVED|verified:$_USB_WRITE_VERIFIED|detail:$REPLY"
  ' "$TEST_REPO_ROOT" "$progress_file") || return

  test_assert_contains "$output" \
    'stage:verify|write:8388608|verify:8388608|verified:1|detail:8.0 MiB of 8.0 MiB' \
    'atomic write and verification progress records were conflated'
}
test_case 'USB atomic progress separates write and verification evidence' \
  _test_usb_atomic_progress_separates_write_and_verify

_test_usb_atomic_progress_is_incrementally_bounded() {
  test_make_temp_dir || return
  local progress_file="$TEST_TMP_DIR/long-atomic-progress" output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    print -r -- "compozsh-write-stage:image" >| "$2" || exit
    command /bin/dd if=/dev/zero bs=600000 count=1 status=none |
      command /usr/bin/tr "\0" "\n" >> "$2" || exit
    print -r -- "8388608 bytes transferred in 1.0 secs (8388608 bytes/sec)" >> "$2" || exit
    _usb_dd_progress_read "$2" 8388608 0
    command /bin/dd if=/dev/zero bs=600000 count=1 status=none |
      command /usr/bin/tr "\0" "\n" >> "$2" || exit
    print -r -- "compozsh-write-stage:verify" >> "$2" || exit
    print -r -- "8388608 bytes transferred in 2.0 secs (4194304 bytes/sec)" >> "$2" || exit
    print -r -- "compozsh-write-verified" >> "$2" || exit
    _usb_dd_progress_read "$2" 8388608 0
    size=$(command /usr/bin/stat -f "%z" "$2") || exit
    print -r -- "size:$size|offset:$_USB_WRITE_PROGRESS_OFFSET|write:$_USB_WRITE_BYTES_OBSERVED|verify:$_USB_WRITE_VERIFY_BYTES_OBSERVED|verified:$_USB_WRITE_VERIFIED|error:$_USB_WRITE_ERROR"
  ' "$TEST_REPO_ROOT" "$progress_file") || return

  test_assert_contains "$output" \
    'offset:1200' \
    'long native progress was repeatedly reparsed instead of consumed incrementally' || return
  test_assert_contains "$output" \
    'write:8388608|verify:8388608|verified:1|error:' \
    'a valid combined progress stream beyond 1 MiB produced a false failure'
}
test_case 'USB atomic progress remains bounded beyond one MiB' \
  _test_usb_atomic_progress_is_incrementally_bounded

_test_usb_execution_rejects_unaligned_target_before_unmount() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    _usb_progress_stage() { return 0; }
    _usb_authorize() { trace+=(authorize); return 0; }
    _usb_image_revalidate() { trace+=(image); return 0; }
    _usb_target_revalidate() {
      trace+=(target)
      _USB_INFO_BLOCK_SIZE=4096
      return 0
    }
    _usb_unmount() { trace+=(unmount); return 0; }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      10240 flash-verify "" 1 "" "" 32768 >/dev/null 2>&1
    print -r -- "status:$?|trace:${(j:,:)trace}|started:$_USB_RESULT_STARTED|error:$_USB_RESULT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'status:1|trace:image,target|started:0|' \
    'a 4 KiB-unaligned image reached the destructive unmount boundary' || return
  test_assert_contains "$output" '4096-byte logical blocks; nothing was written' \
    'the alignment refusal did not explain the safe recovery state'
}
test_case 'USB execution refuses unaligned media before unmounting' \
  _test_usb_execution_rejects_unaligned_target_before_unmount

_test_usb_write_retains_a_bounded_native_failure() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-error" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -u2 -r -- "compozsh-write-stage:image"
      print -u2 -r -- "dd: /dev/rdisk7: Resource busy"
      return 1
    }
    _usb_write_image /images/linux.iso disk7 8388608
    print -r -- "status:$?|error:$_USB_WRITE_ERROR"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" \
    'status:1|error:dd: /dev/rdisk7: Resource busy' \
    'the raw writer discarded the bounded native dd diagnostic'
}
test_case 'USB raw writer retains the exact bounded native failure diagnostic' \
  _test_usb_write_retains_a_bounded_native_failure

_test_usb_execution_reports_stages_and_completion_stats() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    typeset -ga stages=()
    _usb_progress_stage() { stages+=("$1"); }
    _usb_authorize() { return 0; }
    _usb_image_revalidate() { return 0; }
    _usb_target_revalidate() { return 0; }
    _usb_unmount() { return 0; }
    _usb_write_image() { _USB_WRITE_VERIFIED=1; return 0; }
    _usb_authorization_valid() { return 0; }
    _usb_eject() { return 0; }
    _USB_SELECTED_DISK_LABEL="External SSD · 64.0 GiB · /dev/disk7"
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint 8388608 flash-verify || exit 2
    print -r -- "stages:${(j:,:)stages}"
    print -r -- "result:${_USB_RESULT_OUTCOME}|${_USB_RESULT_BYTES}|${_USB_RESULT_VERIFIED}|${_USB_RESULT_EJECTED}"
    _usb_result_choose() {
      print -r -- "summary:${(j:|:)_USB_PICKER_LABELS}"
    }
    _usb_media_result_screen raw-image 0
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'stages:Validating image and drive,Unmounting external drive,Writing image,Ejecting external drive' \
    'execution did not publish each destructive workflow stage' || return
  test_assert_contains "$output" 'result:complete|8388608|1|1' \
    'successful execution did not retain completion facts' || return
  test_assert_contains "$output" 'Flash complete' \
    'completion screen omitted its success state' || return
  test_assert_contains "$output" '8.0 MiB written' \
    'completion screen omitted the exact written size' || return
  test_assert_contains "$output" 'USB verification · Full image byte-for-byte matched' \
    'completion screen omitted verification status' || return
  test_assert_contains "$output" 'Safe to remove' \
    'completion screen omitted eject safety status'
}
test_case 'USB burning publishes stages and a persistent completion summary' \
  _test_usb_execution_reports_stages_and_completion_stats

_test_usb_execution_closes_image_and_target_races() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,dd_progress_bytes}(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    image_checks=0 target_checks=0
    _usb_progress_stage() { return 0; }
    _usb_authorize() { return 0; }
    _usb_image_revalidate() {
      (( ++image_checks ))
      trace+=("image-$image_checks")
      (( image_checks == 1 ))
    }
    _usb_target_revalidate() {
      (( ++target_checks ))
      trace+=("target-$target_checks")
      return 0
    }
    _usb_unmount() { trace+=(unmount); }
    _usb_write_image() {
      trace+=(write)
      _USB_WRITE_BYTES_OBSERVED=$3 _USB_WRITE_VERIFIED=1
    }
    _usb_eject() { trace+=(eject); }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 >/dev/null 2>&1
    print -r -- "image-race:$?|${(j:,:)trace}|$_USB_RESULT_ERROR"

    trace=() image_checks=0 target_checks=0
    _usb_image_revalidate() { (( ++image_checks )); trace+=("image-$image_checks"); return 0; }
    _usb_target_revalidate() {
      (( ++target_checks ))
      trace+=("target-$target_checks")
      (( target_checks == 1 ))
    }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 >/dev/null 2>&1
    print -r -- "target-race:$?|${(j:,:)trace}|$_USB_RESULT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'image-race:1|image-1,target-1,unmount,target-2,write,unmount,image-2,eject|The selected image changed during writing' \
    'an image mutation during dd was allowed to reach verification or success' || return
  test_assert_contains "$output" 'target-race:1|image-1,target-1,unmount,target-2,eject|The external drive changed after unmounting' \
    'a target identity change after unmount was allowed to reach dd'
}
test_case 'USB execution revalidates image and target across the write boundary' \
  _test_usb_execution_closes_image_and_target_races

_test_usb_outer_cleanup_ejects_only_an_started_exact_target() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    typeset -ga trace=()
    _usb_eject() { trace+=("eject:$1"); return 0; }
    _USB_SELECTED_DISK=disk7 _USB_RESULT_STARTED=0 _USB_RESULT_EJECTED=0
    _usb_cleanup_eject
    print -r -- "before:${(j:,:)trace}"
    _USB_RESULT_STARTED=1
    _usb_cleanup_eject
    print -r -- "started:${(j:,:)trace}|$_USB_RESULT_EJECTED"
    _usb_cleanup_eject
    _USB_SELECTED_DISK="not-a-disk" _USB_RESULT_EJECTED=0
    _usb_cleanup_eject
    print -r -- "bounded:${(j:,:)trace}"
    print -r -- "wired:$([[ ${functions[_usb_flash]} == *_usb_cleanup_eject* ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'before:' \
    'cleanup ejected a target before writing started' || return
  test_assert_contains "$output" 'started:eject:disk7|1' \
    'cleanup did not eject the exact started target' || return
  test_assert_contains "$output" 'bounded:eject:disk7' \
    'cleanup retried an ejected target or accepted an invalid identifier' || return
  test_assert_contains "$output" 'wired:yes' \
    'external-device --flash interruption cleanup is not connected to its always boundary'
}
test_case 'USB outer cleanup attempts safe eject after interruption' \
  _test_usb_outer_cleanup_ejects_only_an_started_exact_target

_test_usb_failure_screen_separates_image_and_drive_evidence() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    _usb_choose() {
      local specification="" role=""
      local -a roles=()
      for specification in "${_USB_PICKER_HIGHLIGHTS[@]}"; do
        [[ -n $specification ]] && role=${specification##*:} || role=""
        roles+=("$role")
      done
      roles+=("${_USB_PICKER_PASSIVE_STYLES[@]}")
      print -r -- "labels:${(j:|:)_USB_PICKER_LABELS}|${(j:|:)_USB_PICKER_PASSIVE_LINES}"
      print -r -- "roles:${(j:|:)roles}|semantic:${6:-0}"
    }
    _USB_RESULT_OUTCOME=failed
    _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _USB_RESULT_ERROR="The image was written, but the finished USB could not be read completely for verification."
    _USB_RESULT_CHECKSUM_ALGORITHM=256
    _USB_RESULT_EXPECTED_CHECKSUM=${(l:64::a:)}
    _USB_RESULT_IMAGE_CHECKSUM=$_USB_RESULT_EXPECTED_CHECKSUM
    _USB_RESULT_CHECKSUM_VALIDATED=1
    _USB_RESULT_VERIFY_REASON=drive-read-failed
    _usb_media_result_screen raw-image 4

    _USB_RESULT_EXPECTED_CHECKSUM="" _USB_RESULT_IMAGE_CHECKSUM=""
    _USB_RESULT_CHECKSUM_VALIDATED=0 _USB_RESULT_VERIFY_REASON=mismatch
    _usb_media_result_screen raw-image 1

    _USB_RESULT_EXPECTED_CHECKSUM=${(l:64::d:)}
    _USB_RESULT_IMAGE_CHECKSUM=$_USB_RESULT_EXPECTED_CHECKSUM
    _USB_RESULT_CHECKSUM_VALIDATED=1 _USB_RESULT_VERIFY_REASON=mismatch
    _USB_RESULT_ERROR="The finished USB installer or boot bytes differ from the selected image."
    _usb_media_result_screen raw-image 1
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'Image integrity · Verified · SHA-256 matched|USB verification · Could not read the finished drive' \
    'a verified image and unreadable USB were collapsed into a checksum mismatch' || return
  test_assert_contains "$output" 'Image integrity · Not verified · no checksum provided|USB verification · FAILED · installer or boot bytes differ' \
    'no-checksum image state and a true USB mismatch were not reported independently' || return
  test_assert_contains "$output" 'Image integrity · Verified · SHA-256 matched|USB verification · FAILED · installer or boot bytes differ' \
    'a verified ISO and a USB payload mismatch fell through to a generic incomplete state' || return
  test_assert_contains "$output" 'roles:|picker-error|picker-success|picker-error|picker-success|semantic:1' \
    'the failure result screen did not distinguish failure, verified image, and safe eject semantically' || return
  [[ $output != *'mismatch|USB verification · Could not complete'* ]] ||
    test_fail 'a confirmed mismatch was presented as an incomplete verification'
}
test_case 'USB result screen separates image integrity from USB fidelity' \
  _test_usb_failure_screen_separates_image_and_drive_evidence

_test_usb_dd_progress_bounds_byte_counts() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.pure.usb_dd_progress_bytes" || exit
    _usb_dd_progress_bytes "999999999999999999 bytes transferred in 1.0 secs"
    print -r -- "eighteen:$?|$REPLY"
    _usb_dd_progress_bytes "1000000000000000000 bytes (1.0 EB) transferred 1.0s"
    print -r -- "nineteen:$?|$REPLY"
  ' "$TEST_REPO_ROOT" 2>&1) || return

  test_assert_equal $'eighteen:0|999999999999999999\nnineteen:1|' \
    "$output" 'dd byte counts beyond 18 digits were accepted or wrote a diagnostic'
}
test_case 'USB numeric bounds reject dd byte counts beyond 18 digits without diagnostics' \
  _test_usb_dd_progress_bounds_byte_counts

_test_usb_write_progress_bounds_byte_counts() {
  test_make_temp_dir || return
  local progress_file="$TEST_TMP_DIR/write-progress" output='' REPLY=''
  test_write_file "$progress_file" $'compozsh-write-stage:image\n4194304 bytes transferred in 1.0 secs (4194304 bytes/sec)\r12345678901234567890 bytes transferred in 1.0 secs\rcompozsh-write-stage:verify\ncompozsh-write-verify-bytes:12345678901234567890\n' || return

  _test_usb_invocation_state_script
  output=$(test_run_interactive "$TEST_TMP_DIR/home" "$REPLY"'
    source "$1/.zsh.addons/.zsh.usb" || exit
    _test_usb_invocation_state declare
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    _usb_dd_progress_read "$2" 8388608 0 2>| "$HOME/errors"
    print -r -- "write:$_USB_WRITE_BYTES_OBSERVED|verify:$_USB_WRITE_VERIFY_BYTES_OBSERVED|errors:$(<"$HOME/errors")"
  ' "$TEST_REPO_ROOT" "$progress_file") || return

  test_assert_equal 'write:4194304|verify:0|errors:' "$output" \
    'overlong write or verification byte records reached native integer arithmetic'
}
test_case 'USB numeric bounds ignore write progress byte records beyond 18 digits' \
  _test_usb_write_progress_bounds_byte_counts

_test_usb_write_stage_text_is_never_arithmetic() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-stage-text" output='' REPLY=''
  command mkdir -p "$capture_root" || return
  _test_usb_invocation_state_script
  output=$(test_run_interactive "$TEST_TMP_DIR/home" "$REPLY"'
    source "$1/.zsh.addons/.zsh.usb" || exit
    _test_usb_invocation_state declare
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    TMPDIR=$2
    local -i planted_status=0 evaluated=0
    _usb_progress_stage() { return 0; }
    _usb_raw_write_session_run() {
      print -u2 -r -- "compozsh-write-stage:image"
      print -u2 -r -- "4096 bytes transferred in 1.0 secs (4096 bytes/sec)\r"
      return 1
    }
    _usb_write_image /images/linux.iso disk7 8192 8192 1 2>| "$HOME/errors"
    print -r -- "image:$?|stage:$_USB_WRITE_STAGE|errors:$(<"$HOME/errors")"
    _usb_raw_write_session_run() {
      print -u2 -r -- '\''compozsh-write-stage:path[$(print -r -- evaluated >| "$HOME/stage-evaluated")1]'\''
      print -u2 -r -- "8192 bytes transferred in 1.0 secs (8192 bytes/sec)\r"
      return 1
    }
    _usb_write_image /images/linux.iso disk7 8192 8192 1 2>| "$HOME/errors"
    planted_status=$?
    [[ -e $HOME/stage-evaluated ]] && evaluated=1
    print -r -- "planted:$planted_status|evaluated:$evaluated|errors:$(<"$HOME/errors")"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_equal $'image:1|stage:image|errors:\nplanted:1|evaluated:0|errors:' "$output" \
    'progress-file stage text was evaluated as arithmetic or wrote a diagnostic'
}
test_case 'USB numeric bounds compare write stage text literally, never as arithmetic' \
  _test_usb_write_stage_text_is_never_arithmetic

_test_usb_createinstallmedia_progress_bounds_percent() {
  test_make_temp_dir || return
  local output='' REPLY=''
  _test_usb_invocation_state_script
  output=$(test_run_interactive "$TEST_TMP_DIR/home" "$REPLY"'
    source "$1/.zsh.addons/.zsh.usb" || exit
    _test_usb_invocation_state declare
    for progress_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$progress_component"; done
    print -r -- $'\''Erasing disk: 42%\rCopying to disk: 12345678901234567890%'\'' >| "$HOME/progress"
    _usb_createinstallmedia_progress_read "$HOME/progress" 2>| "$HOME/errors"
    print -r -- "bar:$_USB_PROGRESS_BAR|errors:$(<"$HOME/errors")"
  ' "$TEST_REPO_ROOT") || return

  [[ $output == 'bar:['*'] 42%|errors:' ]] ||
    test_fail "an overlong createinstallmedia percentage reached native integer arithmetic: ${(qqq)output}"
}
test_case 'USB numeric bounds ignore createinstallmedia percentages beyond 18 digits' \
  _test_usb_createinstallmedia_progress_bounds_percent

_test_usb_disk_info_sizes_are_validated_before_integer_assignment() {
  test_make_temp_dir || return
  local output='' REPLY=''
  _test_usb_invocation_state_script
  output=$(test_run_interactive "$TEST_TMP_DIR/home" "$REPLY"'
    source "$1/.zsh.addons/.zsh.usb" || exit
    _test_usb_invocation_state declare
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    local size="" planted=""
    local -i evaluated=0 planted_status=0
    _usb_disk_info_read() {
      _USB_PLIST="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>DeviceIdentifier</key><string>disk7</string><key>TotalSize</key>$size<key>DeviceBlockSize</key><integer>512</integer><key>MediaName</key><string>External SSD</string><key>BusProtocol</key><string>USB</string><key>Internal</key><false/><key>VirtualOrPhysical</key><string>Physical</string><key>WholeDisk</key><true/><key>WritableMedia</key><true/><key>DeviceTreePath</key><string>IOService:/fixture</string></dict></plist>"
    }
    size="<integer>64000000000</integer>"
    _usb_disk_info_capture disk7
    print -r -- "valid:$?|$_USB_INFO_SIZE|$_USB_INFO_BLOCK_SIZE"
    size="<string>1+1</string>"
    _usb_disk_info_capture disk7 2>| "$HOME/errors"
    print -r -- "expression:$?|$_USB_INFO_SIZE|errors:$(<"$HOME/errors")"
    size="<string>12345678901234567890</string>"
    _usb_disk_info_capture disk7 2>| "$HOME/errors"
    print -r -- "overlong:$?|$_USB_INFO_SIZE|errors:$(<"$HOME/errors")"
    planted='\''path[$(print -r -- evaluated >| "$HOME/info-evaluated")1]'\''
    size="<string>$planted</string>"
    _usb_disk_info_capture disk7 2>| "$HOME/errors"
    planted_status=$?
    [[ -e $HOME/info-evaluated ]] && evaluated=1
    print -r -- "planted:$planted_status|evaluated:$evaluated|errors:$(<"$HOME/errors")"
  ' "$TEST_REPO_ROOT") || test_fail "diskutil size capture aborted: ${(qqq)output}"

  test_assert_equal $'valid:0|64000000000|512\nexpression:1|0|errors:\noverlong:1|0|errors:\nplanted:1|evaluated:0|errors:' \
    "$output" 'diskutil size text was evaluated before validation'
}
test_case 'USB numeric bounds validate diskutil sizes before integer assignment' \
  _test_usb_disk_info_sizes_are_validated_before_integer_assignment

# Script helpers that record each external-media temporary name and mode present
# while a native stand-in runs, so a residue check also proves the capture
# existed. The ISO listing runs /usr/bin/tar directly, so only its removal is seen.
_test_usb_temporary_observer_script() {
  REPLY='
  _test_usb_temporary_observe() {
    local entry=""
    for entry in "$TMPDIR"/*(ND); do
      print -r -- "${${entry:t}%.*}:$(command /usr/bin/stat -f %Lp "$entry")" >> "$observed_log"
    done
  }
  _test_usb_temporary_report() {
    local -a leftovers=("$TMPDIR"/*(ND:t))
    print -r -- "$1:$2|leftovers:${(j:,:)leftovers}|end"
  }
'
}

_test_usb_temporary_capture_and_progress_files_are_removed() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/captures" observed_log="$TEST_TMP_DIR/observed"
  local tree="$TEST_TMP_DIR/tree" installer="$TEST_TMP_DIR/Install macOS Tahoe.app"
  local volume="$TEST_TMP_DIR/CompozshVolume" output='' observed='' expected='' REPLY=''
  command mkdir -p "$capture_root" "$tree/sources" "$tree/boot" \
    "$installer/Contents/Resources" "$volume" || return
  test_write_file "$tree/sources/boot.wim" boot || return
  test_write_file "$tree/boot/kernel" kernel || return
  command /usr/bin/tar -cf "$TEST_TMP_DIR/windows.iso" -C "$tree" sources || return
  command /usr/bin/tar -cf "$TEST_TMP_DIR/linux.iso" -C "$tree" boot || return
  test_write_file "$TEST_TMP_DIR/unreadable.iso" 'not an archive' || return
  test_write_file "$installer/Contents/Resources/createinstallmedia" '#!/bin/zsh' || return
  command chmod +x "$installer/Contents/Resources/createinstallmedia" || return

  _test_usb_temporary_observer_script
  output=$(test_run_interactive "$TEST_TMP_DIR/home" "$REPLY"'
    source "$1/.zsh.addons/.zsh.usb" || exit
    for parsing_component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_*(N.); do source "$parsing_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2 fixtures=$3 installer=$4 volume=$5 observed_log=$6
    _usb_progress_stage() { return 0; }
    _usb_diskutil_run() {
      _test_usb_temporary_observe
      case $plist_mode in
        (valid) print -rn -- "<?xml version=\"1.0\"?><plist version=\"1.0\"><dict/></plist>" ;;
        (oversized) builtin printf "%1048577s" "" ;;
        (*) return 1 ;;
      esac
    }
    for plist_mode in valid oversized failed; do
      _usb_diskutil_plist_capture list -plist external physical
      _test_usb_temporary_report "plist-$plist_mode" "$?"
    done

    for image in windows linux unreadable; do
      _usb_windows_iso_table_detect "$fixtures/$image.iso"
      _test_usb_temporary_report "listing-$image" "$?"
    done

    _usb_hdiutil_attach_readonly() {
      _test_usb_temporary_observe
      (( attach_ok )) || return 1
      _USB_INSPECT_DEVICE=disk88 _USB_INSPECT_MOUNT=$2
    }
    _usb_hdiutil_detach() { return 0; }
    for attach_ok in 1 0; do
      _usb_windows_installer_detect "$fixtures/linux.iso"
      _test_usb_temporary_report "inspect-$attach_ok" "$?"
    done

    _usb_raw_write_session_run() {
      _test_usb_temporary_observe
      print -u2 -r -- "4194304 bytes transferred in 1.0 secs (4194304 bytes/sec)"
      (( write_ok )) || return 1
      print -u2 -r -- "8388608 bytes transferred in 2.0 secs (4194304 bytes/sec)"
    }
    for write_ok in 1 0; do
      _usb_write_image /images/linux.iso disk7 8388608
      _test_usb_temporary_report "write-$write_ok" "$?"
    done

    _usb_createinstallmedia_command_run() {
      _test_usb_temporary_observe
      print -r -- "Erasing disk: 0%"
      return $(( !media_ok ))
    }
    for media_ok in 1 0; do
      _usb_createinstallmedia_run "$installer" "$volume"
      _test_usb_temporary_report "createinstallmedia-$media_ok" "$?"
    done
  ' "$TEST_REPO_ROOT" "$capture_root" "$TEST_TMP_DIR" "$installer" "$volume" \
    "$observed_log") || return

  for expected in 'plist-valid:0|leftovers:|end' 'plist-oversized:1|leftovers:|end' \
      'plist-failed:1|leftovers:|end' 'listing-windows:0|leftovers:|end' \
      'listing-linux:1|leftovers:|end' 'listing-unreadable:2|leftovers:|end' \
      'inspect-1:1|leftovers:|end' 'inspect-0:1|leftovers:|end' \
      'write-1:0|leftovers:|end' 'write-0:1|leftovers:|end' \
      'createinstallmedia-1:0|leftovers:|end' 'createinstallmedia-0:1|leftovers:|end'; do
    test_assert_contains "$output" "$expected" \
      'a USB capture, mount directory or progress file remained after success or handled failure' || return
  done
  observed=${(j:,:)${(ou)${(f)"$(<"$observed_log")"}}}
  test_assert_equal 'compozsh-createinstallmedia:600,compozsh-usb-inspect:700,compozsh-usb-progress:600,compozsh-usb:600' \
    "$observed" 'USB capture, mount and progress files were not the disclosed owner-only names'
}
test_case 'USB temporary disk metadata, ISO listing, mount and progress files are owner-only and removed' \
  _test_usb_temporary_capture_and_progress_files_are_removed

_test_usb_temporary_refused_inspection_removes_its_own_mount_point() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/captures" output=''
  local retained="$capture_root/compozsh-usb-inspect.retained"
  command mkdir -p "$retained" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    TMPDIR=$2
    _USB_INSPECT_DEVICE=disk77 _USB_INSPECT_MOUNT=$3
    _usb_hdiutil_detach() { return 1; }
    _usb_windows_installer_detect /images/next.iso
    print -r -- "status:$?|device:$_USB_INSPECT_DEVICE|mount:${_USB_INSPECT_MOUNT:t}"
    local -a entries=("$2"/*(ND:t))
    print -r -- "entries:${(j:,:)entries}|end"
  ' "$TEST_REPO_ROOT" "$capture_root" "$retained") || return

  test_assert_contains "$output" 'status:2|device:disk77|mount:compozsh-usb-inspect.retained' \
    'a refused ISO inspection discarded the earlier retained cleanup ownership' || return
  test_assert_contains "$output" 'entries:compozsh-usb-inspect.retained|end' \
    'a refused ISO inspection leaked its own unrecorded empty mount point'
}
test_case 'USB temporary refused ISO inspection removes only its own new mount point' \
  _test_usb_temporary_refused_inspection_removes_its_own_mount_point

# Diagnostics and help name the shared support components that provide the
# screen and matching entries, never the retired grouped peers.
_test_usb_diagnostics_and_help_name_current_support_components() {
  test_make_temp_dir || return
  local output='' diagnostics='' help='' expected=''
  local components='the shared support/ui and support/functions components'
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    for request in "" --flash --format; do
      external-device ${request:+"$request"} </dev/null 2>&1 >/dev/null
      print -r -- "status:${request:-chooser}:$?"
    done
    print -r -- --help--
    _compozsh_help_external-device
  ' "$TEST_REPO_ROOT") || return
  diagnostics=${output%%$'\n'--help--$'\n'*}
  help=${(j: :)${=output#*$'\n'--help--$'\n'}}
  expected="external-device: an interactive terminal and $components are required
status:chooser:1
external-device --flash: an interactive terminal and $components are required
status:--flash:1
external-device --format: an interactive terminal and $components are required
status:--format:1"

  test_assert_equal "$expected" "$diagnostics" \
    'noninteractive external-device tasks did not name the current support components' || return
  # The task chooser, bootable media and formatting guides each state it.
  test_assert_equal 3 $(( (${#help} - ${#${help//"$components"/}}) / ${#components} )) \
    'external-device help did not name the current support components in each requirement' || return
  [[ $output != *.zsh.matching* && $output != *.zsh.ui([^.]*|) ]] ||
    test_fail "external-device diagnostics or help name a retired peer: ${(qqq)output}"
}
test_case 'USB external-device diagnostics and help name the shared support components, not retired peers' \
  _test_usb_diagnostics_and_help_name_current_support_components
