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
    local -a trace=()
    _usb_hdiutil_attach_readonly() {
      command mkdir -p "$2/SOURCES" || return
      print -r -- boot >| "$2/SOURCES/BOOT.WIM"
      print -r -- install >| "$2/SOURCES/INSTALL.WIM"
      _USB_INSPECT_DEVICE=disk98 _USB_INSPECT_MOUNT=$2
    }
    _usb_windows_tree_capture() {
      trace+=(obsolete-recursive-preflight)
      return 77
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

_test_usb_windows_preflight_captures_a_fat32_compatible_tree() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" "$root/EFI/BOOT" \
    "$root/EFI/Microsoft/Boot" "$root/boot" || return
  test_write_file "$root/sources/boot.wim" boot || return
  test_write_file "$root/sources/install.esd" install || return
  test_write_file "$root/EFI/BOOT/BOOTX64.EFI" uefi || return
  test_write_file "$root/EFI/Microsoft/Boot/BCD" bcd || return
  test_write_file "$root/boot/boot.sdi" sdi || return
  test_write_file "$root/setup.exe" setup || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_windows_tree_capture "$2"
    print -r -- "status:$?|compatible:$_USB_WINDOWS_COMPATIBLE|arch:$_USB_WINDOWS_ARCHITECTURE"
    print -r -- "layout:$_USB_WINDOWS_LAYOUT|files:$_USB_WINDOWS_FILE_COUNT|minimum:$_USB_WINDOWS_REQUIRED_BYTES"
    print -r -- "tree:${(j:,:)_USB_WINDOWS_FILES}"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_contains "$output" 'status:0|compatible:1|arch:x86_64' \
    'a UEFI Windows tree with FAT32-safe files was not accepted' || return
  test_assert_contains "$output" 'layout:install.esd|files:6|minimum:5000000000' \
    'Windows preflight did not retain its layout, file count, or target minimum' || return
  test_assert_contains "$output" 'EFI/BOOT/BOOTX64.EFI' \
    'Windows preflight lost an exact source-tree path'
}
test_case 'USB Windows preflight captures a FAT32-compatible installer tree' \
  _test_usb_windows_preflight_captures_a_fat32_compatible_tree

_test_usb_windows_preflight_rejects_an_oversized_file_before_targeting() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows-large" output=''
  command mkdir -p "$root/sources" "$root/EFI/BOOT" \
    "$root/EFI/Microsoft/Boot" "$root/boot" || return
  test_write_file "$root/sources/boot.wim" boot || return
  command /usr/bin/truncate -s 4294967296 "$root/sources/install.wim" || return
  test_write_file "$root/EFI/BOOT/BOOTX64.EFI" uefi || return
  test_write_file "$root/EFI/Microsoft/Boot/BCD" bcd || return
  test_write_file "$root/boot/boot.sdi" sdi || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_windows_tree_capture "$2"
    print -r -- "status:$?|compatible:$_USB_WINDOWS_COMPATIBLE|error:$_USB_WINDOWS_ERROR"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_contains "$output" 'status:0|compatible:0' \
    'an oversized Windows installer file was not recognized and refused safely' || return
  test_assert_contains "$output" 'sources/install.wim' \
    'the FAT32 refusal did not identify the exact oversized file' || return
  test_assert_contains "$output" '4 GiB' \
    'the FAT32 refusal did not explain the native file-size boundary'
}
test_case 'USB Windows preflight refuses a file beyond FAT32 before target selection' \
  _test_usb_windows_preflight_rejects_an_oversized_file_before_targeting

_test_usb_unmountable_iso_remains_raw_flashable() {
  test_make_temp_dir || return
  local iso="$TEST_TMP_DIR/linux-hybrid.iso" output=''
  test_write_file "$iso" "${(l:20000::l:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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

_test_usb_media_dispatcher_rejects_windows_execution() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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
    _USB_IMAGE_PATHS=("$2") _USB_IMAGE_LABELS=(windows.iso)
    _USB_IMAGE_HIGHLIGHTS=("") _USB_IMAGE_DETAILS=(Windows)
    _USB_IMAGE_SIZES=(20000) _USB_IMAGE_FINGERPRINTS=(fingerprint)
    _USB_IMAGE_KINDS=(raw-image) _USB_IMAGE_CAPTURE_SCOPE=test
    local -i choices=0
    local screen_values="" screen_labels="" done_detail="" passive_lines=""
    local -a trace=()
    _usb_media_kind_capture() {
      REPLY=windows-installer
      _USB_WINDOWS_COMPATIBLE=1
      _USB_WINDOWS_ARCHITECTURE=x86_64
    }
    _usb_target_choose() { trace+=(TARGET_CAPTURE_CALLED); return 9; }
    _usb_choose() {
      (( ++choices ))
      trace+=("screen:$1")
      if (( choices == 1 )); then
        _ZLE_PICKER_SELECTED_VALUE=image:1 _ZLE_PICKER_ACTION=accept
        return 0
      fi
      if [[ $1 == "Flash USB · Windows unsupported" ]]; then
        screen_values=${(j:,:)_USB_PICKER_VALUES}
        screen_labels=${(j:|:)_USB_PICKER_LABELS}
        done_detail=${_USB_PICKER_DETAILS[1]}
        passive_lines=${(j:|:)_ZLE_PICKER_PASSIVE_LINES}
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
    'status:1|trace:screen:Flash USB · Step 1 of 3,screen:Flash USB · Windows unsupported' \
    'recognized Windows media did not end through its dedicated terminal screen' || return
  test_assert_contains "$output" 'values:done' \
    'the Windows unsupported screen did not make Done its only action' || return
  [[ $output != *'values:done,'* ]] ||
    test_fail 'the Windows explanation was exposed as numbered picker actions' || return
  test_assert_contains "$output" 'labels:[ Done ]' \
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

_test_usb_windows_copy_and_verification_cover_every_file() {
  test_make_temp_dir || return
  local source="$TEST_TMP_DIR/source" target="$TEST_TMP_DIR/target" output=''
  command mkdir -p "$source/sources" "$source/EFI/BOOT" "$target" || return
  test_write_file "$source/sources/boot.wim" 'boot-payload' || return
  test_write_file "$source/sources/install.esd" 'installer-payload' || return
  test_write_file "$source/EFI/BOOT/BOOTX64.EFI" 'uefi-payload' || return
  test_write_file "$source/setup.exe" 'setup-payload' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_progress_stage() { return 0; }
    _usb_windows_tree_capture "$2" || exit 2
    _usb_windows_copy_tree "$2" "$3" || exit 3
    _usb_windows_verify_tree "$2" "$3"
    print -r -- "verified:$?|scope:$_USB_RESULT_VERIFY_SCOPE|bytes:$_USB_RESULT_BYTES"
    print -rn -- changed >> "$3/sources/install.esd"
    _usb_windows_verify_tree "$2" "$3" >/dev/null 2>&1
    print -r -- "corrupt:$?|error:$_USB_PAYLOAD_VERIFY_ERROR"
  ' "$TEST_REPO_ROOT" "$source" "$target") || return

  test_assert_contains "$output" 'verified:0|scope:windows-file-tree' \
    'Windows verification did not validate the complete copied manifest' || return
  test_assert_contains "$output" 'corrupt:1|error:mismatch:sources/install.esd' \
    'Windows verification did not identify a corrupted installer file'
}
test_case 'USB Windows copy is followed by exact verification of every source file' \
  _test_usb_windows_copy_and_verification_cover_every_file

_test_usb_windows_prepare_uses_fat32_mbr_and_validates_the_mount() {
  test_make_temp_dir || return
  local volumes="$TEST_TMP_DIR/Volumes" output=''
  command mkdir -p "$volumes" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_VOLUME_ROOT=$2
    local volume_root=$2
    local -a trace=()
    _usb_disk_info_capture() {
      _USB_INFO_SIZE=64000000000 _USB_INFO_BLOCK_SIZE=512
      _USB_INFO_EXTERNAL=1 _USB_INFO_PHYSICAL=1 _USB_INFO_WHOLE=1
      _USB_INFO_WRITABLE=1
    }
    _usb_info_is_eligible() { return 0; }
    _usb_diskutil_erase_run() {
      trace+=("${(j:|:)@}")
      command mkdir -p "$volume_root/WINSETUP"
    }
    _usb_windows_target_validate() { return 0; }
    _usb_diskutil_plist_capture() { _USB_PLIST=plist; }
    _usb_plist_optional() {
      case $2 in
        (ParentWholeDisk) REPLY=disk9 ;;
        (DeviceIdentifier) REPLY=disk9s1 ;;
        (*) REPLY=${3:-} ;;
      esac
    }
    _usb_target_revalidate() { return 0; }
    _usb_windows_prepare_volume disk9 disk-fingerprint 5000000000
    print -r -- "status:$?|volume:$REPLY|trace:${(j:,:)trace}"
  ' "$TEST_REPO_ROOT" "$volumes") || return

  test_assert_contains "$output" \
    "status:0|volume:$volumes/WINSETUP|trace:eraseDisk|MS-DOS FAT32|WINSETUP|MBR|/dev/disk9" \
    'the Windows handler did not prepare and bind one FAT32 MBR volume'
}
test_case 'USB Windows preparation uses native FAT32 MBR and validates the mounted parent' \
  _test_usb_windows_prepare_uses_fat32_mbr_and_validates_the_mount

_test_usb_windows_prepare_revalidates_identity_inside_the_erase_boundary() {
  test_make_temp_dir || return
  local volumes="$TEST_TMP_DIR/Volumes" output=''
  command mkdir -p "$volumes" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_VOLUME_ROOT=$2
    local -i erased=0
    _usb_disk_info_capture() {
      _USB_INFO_SIZE=64000000000 _USB_INFO_BLOCK_SIZE=512
      _USB_INFO_EXTERNAL=1 _USB_INFO_PHYSICAL=1 _USB_INFO_WHOLE=1
      _USB_INFO_WRITABLE=1
    }
    _usb_info_is_eligible() { return 0; }
    _usb_target_revalidate() { return 1; }
    _usb_diskutil_erase_run() { erased=1; }
    _usb_windows_prepare_volume disk9 disk-fingerprint 5000000000 >/dev/null 2>&1
    print -r -- "status:$?|erased:$erased"
  ' "$TEST_REPO_ROOT" "$volumes") || return

  test_assert_equal 'status:1|erased:0' "$output" \
    'the Windows erase helper accepted a replacement disk at the final effect boundary'
}
test_case 'USB Windows preparation revalidates the captured disk inside the erase boundary' \
  _test_usb_windows_prepare_revalidates_identity_inside_the_erase_boundary

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
    _usb_windows_tree_capture "$2" >/dev/null 2>&1
    print -r -- "status:$?|compatible:$_USB_WINDOWS_COMPATIBLE|error:$_USB_WINDOWS_ERROR"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_equal 'status:1|compatible:0|error:' "$output" \
    'a generic UEFI removable-media loader was misclassified as partial Windows setup media'
}
test_case 'USB generic UEFI fallback loaders remain eligible for the raw image handler' \
  _test_usb_generic_uefi_loader_does_not_claim_windows_family

_test_usb_windows_fat32_boundary_and_architecture_labels() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" "$root/EFI/BOOT" \
    "$root/EFI/Microsoft/Boot" "$root/boot" || return
  test_write_file "$root/sources/boot.wim" boot || return
  command /usr/bin/truncate -s 4294967295 "$root/sources/install.wim" || return
  test_write_file "$root/EFI/BOOT/BOOTX64.EFI" x64 || return
  test_write_file "$root/EFI/BOOT/BOOTAA64.EFI" arm64 || return
  test_write_file "$root/EFI/Microsoft/Boot/BCD" bcd || return
  test_write_file "$root/boot/boot.sdi" sdi || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_windows_tree_capture "$2"
    local capture_status=$?
    _usb_image_architecture_short_label "$_USB_WINDOWS_ARCHITECTURE"
    print -r -- "status:$capture_status|compatible:$_USB_WINDOWS_COMPATIBLE|arch:$_USB_WINDOWS_ARCHITECTURE|label:$REPLY"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_equal 'status:0|compatible:1|arch:multi-architecture|label:x64 + ARM64' "$output" \
    'the exact FAT32 maximum or dual-architecture UEFI media was rejected or mislabeled'
}
test_case 'USB Windows accepts the exact FAT32 file maximum and labels dual-architecture media' \
  _test_usb_windows_fat32_boundary_and_architecture_labels

_test_usb_windows_non_install_wim_oversize_has_precise_recovery() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" "$root/EFI/BOOT" \
    "$root/EFI/Microsoft/Boot" "$root/boot" || return
  command /usr/bin/truncate -s 4294967296 "$root/sources/boot.wim" || return
  test_write_file "$root/sources/install.esd" install || return
  test_write_file "$root/EFI/BOOT/BOOTX64.EFI" uefi || return
  test_write_file "$root/EFI/Microsoft/Boot/BCD" bcd || return
  test_write_file "$root/boot/boot.sdi" sdi || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_windows_tree_capture "$2"
    print -r -- "status:$?|compatible:$_USB_WINDOWS_COMPATIBLE|error:$_USB_WINDOWS_ERROR"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_contains "$output" 'status:0|compatible:0|error:FAT32 cannot store sources/boot.wim' \
    'an oversized non-install WIM did not receive a precise refusal' || return
  [[ $output != *'split'* ]] || test_fail \
    'the non-install WIM refusal incorrectly recommended splitting install.wim'
}
test_case 'USB Windows oversized non-install files do not recommend an invalid WIM split' \
  _test_usb_windows_non_install_wim_oversize_has_precise_recovery

_test_usb_windows_family_without_uefi_fails_closed() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" || return
  test_write_file "$root/sources/boot.wim" boot || return
  test_write_file "$root/sources/install.esd" install || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_windows_tree_capture "$2"
    print -r -- "status:$?|compatible:$_USB_WINDOWS_COMPATIBLE|error:$_USB_WINDOWS_ERROR"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_contains "$output" 'status:0|compatible:0' \
    'recognized Windows setup media without a UEFI loader escaped to raw flashing' || return
  test_assert_contains "$output" 'UEFI' \
    'the incompatible Windows result did not explain the UEFI-only boundary'
}
test_case 'USB Windows family detection refuses non-UEFI media instead of raw flashing' \
  _test_usb_windows_family_without_uefi_fails_closed

_test_usb_windows_preflight_requires_the_uefi_boot_chain() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" "$root/EFI/BOOT" || return
  test_write_file "$root/sources/boot.wim" boot || return
  test_write_file "$root/sources/install.esd" install || return
  test_write_file "$root/EFI/BOOT/BOOTX64.EFI" uefi || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_windows_tree_capture "$2"
    print -r -- "status:$?|compatible:$_USB_WINDOWS_COMPATIBLE|error:$_USB_WINDOWS_ERROR"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_contains "$output" 'status:0|compatible:0' \
    'a Windows tree without its BCD and boot SDI was accepted as bootable' || return
  test_assert_contains "$output" 'boot chain' \
    'the incomplete Windows boot chain did not receive a precise refusal'
}
test_case 'USB Windows preflight requires BCD and boot SDI for UEFI media' \
  _test_usb_windows_preflight_requires_the_uefi_boot_chain

_test_usb_windows_copy_rejects_a_symlink_target() {
  test_make_temp_dir || return
  local source="$TEST_TMP_DIR/source" victim="$TEST_TMP_DIR/victim"
  local target="$TEST_TMP_DIR/target" output=''
  command mkdir -p "$source/sources" "$source/EFI/BOOT" "$victim" || return
  test_write_file "$source/sources/boot.wim" boot || return
  test_write_file "$source/sources/install.esd" install || return
  test_write_file "$source/EFI/BOOT/BOOTX64.EFI" uefi || return
  command ln -s "$victim" "$target" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_progress_stage() { return 0; }
    _usb_windows_tree_capture "$2" || exit 2
    _usb_windows_copy_tree "$2" "$3" >/dev/null 2>&1
    print -r -- "status:$?|victim:${#${(f)$(command find "$4" -mindepth 1 -print)}}"
  ' "$TEST_REPO_ROOT" "$source" "$target" "$victim") || return

  test_assert_contains "$output" 'status:2|victim:0' \
    'Windows copy followed a symlink outside the selected target volume'
}
test_case 'USB Windows copy rejects a symlinked target before any file effect' \
  _test_usb_windows_copy_rejects_a_symlink_target

_test_usb_windows_verification_distinguishes_mismatch_and_read_failure() {
  test_make_temp_dir || return
  local source="$TEST_TMP_DIR/source" target="$TEST_TMP_DIR/target" output=''
  command mkdir -p "$source/sources" "$source/EFI/BOOT" "$target/sources" \
    "$target/EFI/BOOT" || return
  test_write_file "$source/sources/boot.wim" boot || return
  test_write_file "$source/sources/install.esd" install || return
  test_write_file "$source/EFI/BOOT/BOOTX64.EFI" uefi || return
  command /usr/bin/ditto "$source/" "$target" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_progress_stage() { return 0; }
    _usb_windows_tree_capture "$2" || exit 2
    _usb_windows_cmp_run() { return 1; }
    _usb_windows_verify_tree "$2" "$3" >/dev/null 2>&1
    print -r -- "mismatch:$?|$_USB_PAYLOAD_VERIFY_ERROR"
    _usb_windows_cmp_run() { return 2; }
    _usb_windows_verify_tree "$2" "$3" >/dev/null 2>&1
    print -r -- "read:$?|$_USB_PAYLOAD_VERIFY_ERROR"
  ' "$TEST_REPO_ROOT" "$source" "$target") || return

  test_assert_contains "$output" 'mismatch:1|mismatch:EFI/BOOT/BOOTX64.EFI' \
    'Windows verification lost a true content mismatch' || return
  test_assert_contains "$output" 'read:2|read-failed:EFI/BOOT/BOOTX64.EFI' \
    'Windows verification misreported an I/O failure as corruption'
}
test_case 'USB Windows verification distinguishes mismatch from read failure' \
  _test_usb_windows_verification_distinguishes_mismatch_and_read_failure

_test_usb_windows_preflight_rejects_fat32_reserved_paths() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/windows" output=''
  command mkdir -p "$root/sources" "$root/EFI/BOOT" || return
  test_write_file "$root/sources/boot.wim" boot || return
  test_write_file "$root/sources/install.esd" install || return
  test_write_file "$root/EFI/BOOT/BOOTAA64.EFI" uefi || return
  test_write_file "$root/CON.txt" reserved || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_windows_tree_capture "$2"
    print -r -- "status:$?|compatible:$_USB_WINDOWS_COMPATIBLE|arch:$_USB_WINDOWS_ARCHITECTURE|error:$_USB_WINDOWS_ERROR"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_contains "$output" 'status:0|compatible:0|arch:arm64' \
    'Windows ARM64 media with a reserved FAT32 path was accepted' || return
  test_assert_contains "$output" 'FAT32-incompatible' \
    'the FAT32 path refusal did not explain its compatibility boundary'
}
test_case 'USB Windows preflight rejects reserved FAT32 paths for ARM64 media' \
  _test_usb_windows_preflight_rejects_fat32_reserved_paths

_test_usb_windows_handler_revalidates_before_erase_and_verifies_after_copy() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    local -a trace=()
    _usb_progress_stage() { return 0; }
    _usb_windows_source_open() {
      trace+=(source-open)
      _USB_WINDOWS_COMPATIBLE=1 _USB_WINDOWS_REQUIRED_BYTES=5000000000
      _USB_WINDOWS_TOTAL_BYTES=3000000000 _USB_WINDOWS_FILE_COUNT=20
      _USB_WINDOWS_ARCHITECTURE=x86_64 _USB_WINDOWS_LAYOUT=install.esd
      _USB_WINDOWS_SOURCE_DEVICE=disk88 _USB_WINDOWS_SOURCE_MOUNT=/Volumes/WINDOWSISO
      REPLY=/Volumes/WINDOWSISO
    }
    _usb_windows_source_close() { trace+=(source-close); }
    _usb_image_revalidate() { trace+=(image-check); return ${image_status:-0}; }
    _usb_target_revalidate() { trace+=(target-check); return 0; }
    _usb_authorization_valid() { trace+=(authorization-check); return 0; }
    _usb_windows_prepare_volume() {
      trace+=(prepare)
      _USB_RESULT_STARTED=1
      _USB_WINDOWS_TARGET_PARTITION=disk9s1
      REPLY=/Volumes/WINSETUP
    }
    _usb_windows_target_validate() { trace+=(volume-check:$4); return 0; }
    _usb_windows_copy_tree() { trace+=(copy); }
    _usb_windows_sync_run() { trace+=(sync); }
    _usb_windows_unmount_run() { trace+=(unmount); }
    _usb_windows_verify_mount_open() {
      trace+=(readonly-mount)
      _USB_WINDOWS_VERIFY_MOUNT=/tmp/compozsh-windows-readonly.test
      REPLY=$_USB_WINDOWS_VERIFY_MOUNT
    }
    _usb_windows_verify_mount_cleanup() { trace+=(mount-cleanup); }
    _usb_windows_verify_tree() {
      trace+=(verify)
      _USB_RESULT_VERIFY_SCOPE=windows-file-tree _USB_RESULT_BYTES=3000000000
    }
    _usb_eject() { trace+=(eject); }
    _usb_windows_execute /images/windows.iso disk9 disk-fingerprint image-fingerprint \
      20000 flash-verify "" 1 "" "" 8000000000 || exit 2
    print -r -- "success:${(j:,:)trace}|outcome:$_USB_RESULT_OUTCOME|verified:$_USB_RESULT_VERIFIED"
    trace=() image_status=1
    _usb_windows_execute /images/windows.iso disk9 disk-fingerprint image-fingerprint \
      20000 flash-verify "" 1 "" "" 8000000000 >/dev/null 2>&1
    print -r -- "changed:$?|${(j:,:)trace}|started:$_USB_RESULT_STARTED"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'success:source-open,image-check,target-check,target-check,authorization-check,target-check,prepare,image-check,target-check,volume-check:writable,copy,sync,image-check,target-check,volume-check:writable,unmount,readonly-mount,target-check,verify,source-close,eject,mount-cleanup|outcome:complete|verified:1' \
    'the Windows handler skipped a validation, copy, verification, cleanup, or eject boundary' || return
  test_assert_contains "$output" 'changed:1|source-open,image-check,source-close|started:0' \
    'a changed Windows ISO reached a destructive target effect'
}
test_case 'USB Windows handler closes source and target races around verified creation' \
  _test_usb_windows_handler_revalidates_before_erase_and_verifies_after_copy

_test_usb_windows_authorization_swap_never_reaches_prepare() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    local -i target_checks=0 prepared=0
    _usb_progress_stage() { return 0; }
    _usb_windows_source_open() {
      _USB_WINDOWS_REQUIRED_BYTES=5000000000
      _USB_WINDOWS_TOTAL_BYTES=100 _USB_WINDOWS_FILE_COUNT=5
      _USB_WINDOWS_SOURCE_DEVICE=disk88 _USB_WINDOWS_SOURCE_MOUNT=/Volumes/WINDOWSISO
      REPLY=/Volumes/WINDOWSISO
    }
    _usb_windows_source_close() { return 0; }
    _usb_image_revalidate() { return 0; }
    _usb_target_revalidate() {
      (( ++target_checks ))
      (( target_checks < 3 ))
    }
    _usb_authorization_valid() { return 0; }
    _usb_windows_prepare_volume() { prepared=1; return 0; }
    _usb_windows_execute /images/windows.iso disk9 disk-fingerprint image-fingerprint \
      20000 flash-verify "" 1 "" "" 8000000000 >/dev/null 2>&1
    print -r -- "status:$?|checks:$target_checks|prepared:$prepared|started:$_USB_RESULT_STARTED|error:$_USB_RESULT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'status:1|checks:3|prepared:0|started:0' \
    'a disk swapped during authorization reached Windows target preparation' || return
  test_assert_contains "$output" 'changed during authorization' \
    'the authorization-time disk replacement did not receive a precise refusal'
}
test_case 'USB Windows handler rejects a disk replacement after authorization' \
  _test_usb_windows_authorization_swap_never_reaches_prepare

_test_usb_windows_source_cleanup_preserves_identity_until_detach_succeeds() {
  test_make_temp_dir || return
  local mount="$TEST_TMP_DIR/compozsh-usb-windows.test" output=''
  command mkdir -p "$mount" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    TMPDIR=${2:h}
    _USB_WINDOWS_SOURCE_DEVICE=disk88 _USB_WINDOWS_SOURCE_MOUNT=$2
    local -i detach_status=1
    _usb_hdiutil_detach() { return $detach_status; }
    _usb_windows_source_close
    print -r -- "failed:$?|device:$_USB_WINDOWS_SOURCE_DEVICE|mount:$_USB_WINDOWS_SOURCE_MOUNT"
    detach_status=0
    _usb_windows_source_close
    print -r -- "retried:$?|device:$_USB_WINDOWS_SOURCE_DEVICE|mount:$_USB_WINDOWS_SOURCE_MOUNT|exists:$([[ -d $2 ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT" "$mount") || return

  test_assert_contains "$output" "failed:1|device:disk88|mount:$mount" \
    'failed Windows source cleanup discarded the identity required for retry' || return
  test_assert_contains "$output" 'retried:0|device:|mount:|exists:no' \
    'Windows source cleanup did not clear state after a successful retry'
}
test_case 'USB Windows source cleanup retains failed detach identity for retry' \
  _test_usb_windows_source_cleanup_preserves_identity_until_detach_succeeds

_test_usb_windows_partial_source_attach_retains_cleanup_identity() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    TMPDIR=$2
    local -i detach_status=1
    _usb_hdiutil_attach_readonly() {
      _USB_INSPECT_DEVICE=disk88 _USB_INSPECT_MOUNT=$2
      return 2
    }
    _usb_hdiutil_detach() { return $detach_status; }
    _usb_windows_source_open /images/windows.iso >/dev/null 2>&1
    print -r -- "open:$?|device:$_USB_WINDOWS_SOURCE_DEVICE|mount:${_USB_WINDOWS_SOURCE_MOUNT:t}"
    detach_status=0
    _usb_windows_source_close >/dev/null 2>&1
    print -r -- "retry:$?|device:$_USB_WINDOWS_SOURCE_DEVICE|mount:$_USB_WINDOWS_SOURCE_MOUNT"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return

  test_assert_contains "$output" 'open:2|device:disk88|mount:compozsh-usb-windows.' \
    'a failed partial Windows source attach discarded cleanup ownership' || return
  test_assert_contains "$output" 'retry:0|device:|mount:' \
    'retained partial Windows source cleanup could not be retried successfully'
}
test_case 'USB Windows partial source attachment retains identity for outer cleanup retry' \
  _test_usb_windows_partial_source_attach_retains_cleanup_identity

_test_usb_partial_inspection_cleanup_is_retriable_and_wired_outermost() {
  test_make_temp_dir || return
  local mount="$TEST_TMP_DIR/compozsh-usb-inspect.test" output=''
  command mkdir -p "$mount" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    TMPDIR=${2:h}
    _USB_INSPECT_DEVICE=disk77 _USB_INSPECT_MOUNT=$2
    local -i detach_status=1
    _usb_hdiutil_detach() { return $detach_status; }
    _usb_inspect_cleanup >/dev/null 2>&1
    print -r -- "failed:$?|device:$_USB_INSPECT_DEVICE|mount:$_USB_INSPECT_MOUNT"
    detach_status=0
    _usb_inspect_cleanup >/dev/null 2>&1
    print -r -- "retried:$?|device:$_USB_INSPECT_DEVICE|mount:$_USB_INSPECT_MOUNT"
    print -r -- "wired:$([[ ${functions[flash-usb]} == *_usb_inspect_cleanup* ]] && print yes || print no)"
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
    source "$1/.zsh.addons/.zsh.usb" || exit
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

_test_usb_macos_result_screen_reports_native_outcome() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_result_choose() {
      print -r -- "title:$1|trail:$2"
      print -r -- "labels:${(j:|:)_USB_PICKER_LABELS}"
      print -r -- "styles:${(j:|:)_USB_PICKER_HIGHLIGHTS}"
    }
    _USB_RESULT_OUTCOME=complete _USB_RESULT_SECONDS=75 _USB_RESULT_SOURCE_VALIDATED=1
    _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1 _USB_RESULT_SOURCE_VALIDATED=1
    _usb_macos_result_screen 0
    _USB_RESULT_OUTCOME=failed _USB_RESULT_ERROR="Apple createinstallmedia failed: media is too small"
    _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _usb_macos_result_screen 1
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

_test_usb_windows_result_screen_reports_file_tree_evidence() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_result_choose() {
      print -r -- "title:$1|trail:$2"
      print -r -- "labels:${(j:|:)_USB_PICKER_LABELS}"
      print -r -- "styles:${(j:|:)_USB_PICKER_HIGHLIGHTS}"
    }
    _USB_RESULT_OUTCOME=complete _USB_RESULT_SECONDS=90 _USB_RESULT_WRITE_SECONDS=50
    _USB_RESULT_VERIFY_SECONDS=40 _USB_RESULT_BYTES=3000000000
    _USB_RESULT_RATE="60.0 MiB/s" _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _USB_RESULT_SOURCE_VALIDATED=1 _USB_RESULT_VERIFIED=1
    _USB_RESULT_VERIFY_SCOPE=windows-file-tree _USB_RESULT_CHECKSUM_VALIDATED=0
    _usb_media_result_screen windows-installer 0
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'Windows installer complete · complete FAT32 file tree verified' \
    'Windows completion reused raw-image language' || return
  test_assert_contains "$output" \
    'USB verification · Every captured installer file byte-for-byte matched' \
    'Windows completion omitted its file-tree verification scope' || return
  [[ $output == *picker-success* ]] ||
    test_fail 'Windows completion evidence lacked semantic success color'
}
test_case 'USB Windows result screen reports file-tree verification evidence' \
  _test_usb_windows_result_screen_reports_file_tree_evidence

_test_usb_windows_result_never_claims_a_failed_checksum_matched() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_result_choose() { print -rl -- "${_USB_PICKER_LABELS[@]}"; }
    _USB_RESULT_OUTCOME=failed _USB_RESULT_STARTED=0 _USB_RESULT_EJECTED=0
    _USB_RESULT_CHECKSUM_ALGORITHM=256
    _USB_RESULT_EXPECTED_CHECKSUM=${(l:64::a:)}
    _USB_RESULT_CHECKSUM_VALIDATED=0 _USB_RESULT_CHECKSUM_ERROR=calculation-failed
    _USB_RESULT_ERROR="The Windows ISO SHA-256 could not be calculated; nothing was written."
    _usb_windows_result_screen 1
    print -r -- ---
    _USB_RESULT_CHECKSUM_VALIDATED=0 _USB_RESULT_CHECKSUM_ERROR=changed-or-unreadable
    _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _USB_RESULT_ERROR="The Windows ISO SHA-256 changed or could not be reread; the drive must not be used."
    _usb_windows_result_screen 1
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'Image integrity · FAILED · SHA-256 could not be calculated' \
    'a checksum read failure was falsely presented as a mismatch' || return
  test_assert_contains "$output" 'Image integrity · FAILED · source changed or could not be reread' \
    'a post-copy source failure retained a false verified checksum claim' || return
  [[ $output != *'Verified · SHA-256 matched'* ]] ||
    test_fail 'a failed checksum state rendered a green matched claim'
}
test_case 'USB Windows failure results keep checksum calculation and later source failures truthful' \
  _test_usb_windows_result_never_claims_a_failed_checksum_matched

_test_usb_result_screens_keep_facts_passive() {
  test_make_temp_dir || return
  local output='' line=''
  local -i screens=0

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_choose() {
      print -r -- "$1|values:${(j:,:)_USB_PICKER_VALUES}|labels:${(j:,:)_USB_PICKER_LABELS}|passive:${(j:|:)_ZLE_PICKER_PASSIVE_LINES}"
    }

    _USB_RESULT_OUTCOME=complete _USB_RESULT_BYTES=1048576 _USB_RESULT_SECONDS=1
    _USB_RESULT_RATE="1.0 MiB/s" _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _USB_RESULT_VERIFIED=1 _USB_RESULT_VERIFY_SCOPE=full
    _USB_RESULT_CHECKSUM_VALIDATED=0 _USB_RESULT_VERIFY_REASON=""
    _usb_result_screen 0
    _USB_RESULT_OUTCOME=failed _USB_RESULT_ERROR="raw failure"
    _USB_RESULT_STARTED=0 _USB_RESULT_EJECTED=0 _USB_RESULT_VERIFIED=0
    _usb_result_screen 1

    _USB_RESULT_OUTCOME=complete _USB_RESULT_SECONDS=2 _USB_RESULT_STARTED=1
    _USB_RESULT_EJECTED=1 _USB_RESULT_SOURCE_VALIDATED=1
    _usb_macos_result_screen 0
    _USB_RESULT_OUTCOME=failed _USB_RESULT_ERROR="macOS failure"
    _USB_RESULT_STARTED=0 _USB_RESULT_EJECTED=0 _USB_RESULT_SOURCE_VALIDATED=0
    _usb_macos_result_screen 1

    _USB_RESULT_OUTCOME=complete _USB_RESULT_SECONDS=3 _USB_RESULT_STARTED=1
    _USB_RESULT_EJECTED=1 _USB_RESULT_VERIFIED=1
    _USB_RESULT_VERIFY_SCOPE=windows-file-tree _USB_RESULT_CHECKSUM_VALIDATED=0
    _USB_RESULT_EXPECTED_CHECKSUM="" _USB_RESULT_CHECKSUM_ERROR=""
    _usb_windows_result_screen 0
    _USB_RESULT_OUTCOME=failed _USB_RESULT_ERROR="Windows failure"
    _USB_RESULT_STARTED=0 _USB_RESULT_EJECTED=0 _USB_RESULT_VERIFIED=0
    _usb_windows_result_screen 1
  ' "$TEST_REPO_ROOT") || return

  for line in "${(@f)output}"; do
    (( ++screens ))
    [[ $line == *'|values:done|labels:[ Done ]|passive:'* ]] || {
      test_fail "USB result exposed a passive fact as an action: $line"
      return
    }
    [[ $line != *'|passive:' ]] || {
      test_fail "USB result omitted its passive outcome evidence: $line"
      return
    }
  done
  (( screens == 6 )) || test_fail "expected six USB result states, saw $screens"
}
test_case 'USB result screens expose only Done as an action' \
  _test_usb_result_screens_keep_facts_passive

_test_usb_windows_round_trip_on_a_real_fat32_image() {
  test_make_temp_dir || return
  local source="$TEST_TMP_DIR/source" image="$TEST_TMP_DIR/windows-fat32.dmg"
  local target_mount="$TEST_TMP_DIR/target" verify_mount="$TEST_TMP_DIR/verify"
  local output=''
  command mkdir -p "$source/sources" "$source/EFI/BOOT" \
    "$source/EFI/Microsoft/Boot" "$source/boot" \
    "$target_mount" "$verify_mount" || return
  test_write_file "$source/sources/boot.wim" 'boot-payload' || return
  test_write_file "$source/sources/install.esd" 'installer-payload' || return
  test_write_file "$source/EFI/BOOT/BOOTX64.EFI" 'uefi-payload' || return
  test_write_file "$source/EFI/Microsoft/Boot/BCD" 'bcd-payload' || return
  test_write_file "$source/boot/boot.sdi" 'sdi-payload' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    local source=$2 image=$3 target_mount=$4 verify_mount=$5
    local attach_output="" line="" device="" partition="" verify_device=""
    local -i integration_status=1
    _usb_progress_stage() { return 0; }
    {
      if ! command /usr/bin/hdiutil create -quiet -size 512m -fs MS-DOS \
          -volname WINTEST "$image" 2>/dev/null; then
        print -r -- "integration-unavailable:DiskImages could not create the FAT32 fixture"
        return 0
      fi
      attach_output=$(command /usr/bin/hdiutil attach -nobrowse -noautoopen \
        -mountpoint "$target_mount" "$image" 2>/dev/null) || exit 3
      for line in "${(f)attach_output}"; do
        [[ ${line%%[[:space:]]*} == /dev/disk<-> ]] &&
          device=${${line%%[[:space:]]*}#/dev/}
        [[ ${line%%[[:space:]]*} == /dev/disk<->s<-> ]] &&
          partition=${${line%%[[:space:]]*}#/dev/}
      done
      [[ $device == disk<-> && $partition == ${device}s<-> ]] || exit 4
      _usb_windows_tree_capture "$source" || exit 5
      _usb_windows_target_validate "$device" "$partition" "$target_mount" writable || exit 18
      _usb_windows_copy_tree "$source" "$target_mount" || exit 6
      _usb_windows_sync_run || exit 7
      command /usr/bin/hdiutil detach "/dev/$device" >/dev/null 2>&1 || exit 8
      device=""
      _usb_hdiutil_attach_readonly "$image" "$verify_mount" || exit 9
      verify_device=$_USB_INSPECT_DEVICE
      _usb_windows_target_validate "$verify_device" "${verify_device}s1" \
        "$verify_mount" readonly || exit 19
      _usb_windows_verify_tree "$source" "$verify_mount" || exit 10
      print -r -- "verified:$?|scope:$_USB_RESULT_VERIFY_SCOPE"
      command /usr/bin/hdiutil detach "/dev/$verify_device" >/dev/null 2>&1 || exit 11
      verify_device=""
      command /bin/rmdir "$verify_mount" 2>/dev/null
      command mkdir "$verify_mount" || exit 12
      attach_output=$(command /usr/bin/hdiutil attach -nobrowse -noautoopen \
        -mountpoint "$verify_mount" "$image" 2>/dev/null) || exit 13
      for line in "${(f)attach_output}"; do
        [[ ${line%%[[:space:]]*} == /dev/disk<-> ]] || continue
        device=${${line%%[[:space:]]*}#/dev/}
        break
      done
      print -rn -- changed >> "$verify_mount/sources/install.esd" || exit 14
      command /usr/bin/hdiutil detach "/dev/$device" >/dev/null 2>&1 || exit 15
      device=""
      command /bin/rmdir "$verify_mount" 2>/dev/null
      command mkdir "$verify_mount" || exit 16
      _usb_hdiutil_attach_readonly "$image" "$verify_mount" || exit 17
      verify_device=$_USB_INSPECT_DEVICE
      _usb_windows_verify_tree "$source" "$verify_mount" >/dev/null 2>&1
      print -r -- "corrupt:$?|error:$_USB_PAYLOAD_VERIFY_ERROR"
      integration_status=0
    } always {
      [[ -n $verify_device ]] && command /usr/bin/hdiutil detach "/dev/$verify_device" >/dev/null 2>&1
      [[ -n $device ]] && command /usr/bin/hdiutil detach "/dev/$device" >/dev/null 2>&1
    }
    return $integration_status
  ' "$TEST_REPO_ROOT" "$source" "$image" "$target_mount" "$verify_mount") || return

  # DiskImages can transiently refuse synthetic device creation while another
  # macOS disk-image operation owns the service. Deterministic verifier tests
  # above remain mandatory; this lane exercises the real FAT32 provider when
  # the host can supply it.
  [[ $output == integration-unavailable:* ]] && return 0

  test_assert_contains "$output" 'verified:0|scope:windows-file-tree' \
    'a durable FAT32 detach/read-only-remount rejected an exact Windows tree' || return
  test_assert_contains "$output" 'corrupt:1|error:mismatch:sources/install.esd' \
    'the real FAT32 round trip did not detect finished-media corruption'
}
test_case 'USB Windows verifier round-trips and detects corruption on real FAT32' \
  _test_usb_windows_round_trip_on_a_real_fat32_image

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
    builtin cd -- "$2" || exit
    _usb_spotlight_run() {
      [[ $1 == -0 && $2 == -onlyin && $3 == "${HOME:A}" ]] || return 9
      print -rn -- "$HOME/Archive/Nested/old.iso"$'\''\0'\''
      print -rn -- "$HOME/Archive/Nested/new.img"$'\''\0'\''
    }
    _usb_image_stat_capture() {
      local path=$1 created=100 modified=110 size=20000
      [[ $path == */new.img ]] && { created=300; modified=310; size=30000; }
      [[ $path == */local.iso ]] && { created=200; modified=210; size=25000; }
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
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_PICKER_VALUES=(custom-path image:1)
    _USB_PICKER_LABELS=(Custom Linux)
    _USB_PICKER_HIGHLIGHTS=("" "7:12:picker-size")
    _USB_PICKER_SEARCH=(custom linux)
    _USB_PICKER_DETAILS=("Browse from home" $'\''Linux image\n\nPath · /images/linux.iso'\'')
    _zle_picker_loop() {
      print -r -- "details:${#_ZLE_PICKER_INSPECT_TEXTS}|${_ZLE_PICKER_INSPECT_TEXTS[image:1]-}"
      print -r -- "row-style:${_ZLE_PICKER_LABEL_HIGHLIGHTS[image:1]-}"
    }
    _usb_choose "Flash USB · Step 1 of 3" "IMAGE  ›  Drive  ›  Flash" "Filter images" 1 0 1
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

_test_usb_disk_capture_filters_unsafe_targets() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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

_test_usb_plist_capture_ignores_custom_path() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/capture" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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

_test_usb_custom_path_browses_from_home() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''
  local canonical_home=${home:A}
  command mkdir -p "$home/Downloads" || return
  test_write_file "$home/Downloads/linux.iso" "${(l:20000::i:)}" || return
  output=$(test_run_interactive "$home" '
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
  test_assert_contains "$output" 'nav:1|1|Hidden: on · ← parent · → open folder · Return select' \
    'custom image browser did not expose the Tab hierarchy and hidden-item controls'
}
test_case 'USB custom image browser matches Tab fuzzy and hierarchy navigation' \
  _test_usb_custom_path_matches_tab_navigation_contract

_test_usb_steps_use_clean_single_pane_choices() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_PICKER_VALUES=(one two)
    _USB_PICKER_LABELS=(One Two)
    _USB_PICKER_SEARCH=(one two)
    _USB_PICKER_DETAILS=(secret-one secret-two)
    _zle_picker_loop() {
      print -r -- "title:${_ZLE_PICKER_TITLE}"
      print -r -- "subtitle:${_ZLE_PICKER_SUBTITLE}"
      print -r -- "details:${#_ZLE_PICKER_INSPECT_TEXTS}"
    }
    _usb_choose "Flash USB · Step 1 of 3" "IMAGE  ›  Drive  ›  Flash" "Filter images"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'title:Flash USB · Step 1 of 3' \
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
  test_assert_contains "$output" 'view5:flash-verify,checksum,image,target,flash-only|[ Start flash & verify ],Image integrity · Not verified · no checksum provided,Change image · older.iso,Change drive · external-target' \
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
  test_assert_contains "$output" 'review:[ Start flash & verify · SHA-256 ]|Image integrity · Verified · SHA-256 matched|Remove image checksum' \
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
  test_assert_contains "$output" '[ Resolve image integrity check before flashing ]' \
    'Step 3 left a destructive action looking enabled after checksum failure' || return
  test_assert_contains "$output" 'blocked-after-flash' \
    'a checksum-mismatched image crossed the action boundary' || return
  test_assert_contains "$output" 'selected:6|none' \
    'removing a failed checksum did not explicitly restore the no-checksum action'
}
test_case 'USB Step 3 blocks a mismatched image checksum' \
  _test_usb_step3_blocks_a_mismatched_image_checksum

_test_usb_step3_hashing_never_claims_early_success() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
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

_test_usb_compare_treats_cmp_as_authoritative() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_unmount() { return 0; }
    typeset -ga statuses=() calls=()
    _usb_cmp_run() {
      calls+=("$*")
      local rc=${statuses[1]:-0}
      shift statuses
      return $rc
    }

    statuses=(0)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "full:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    calls=() statuses=(1 0 0)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "metadata:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
    print -r -- "metadata-calls:${(j:|:)calls}"

    statuses=(1 1)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "payload:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    statuses=(2)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "read:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'full:0|full|' \
    'an exact full-image comparison was not retained as the strongest result' || return
  test_assert_contains "$output" 'metadata:1||mismatch' \
    'an unvalidated MBR partition-map change was accepted as bootable' || return
  test_assert_contains "$output" 'metadata-calls:-n 20000 /dev/rdisk7 /images/linux.iso|-n 440 /dev/rdisk7 /images/linux.iso|-n 2 -i 510 /dev/rdisk7 /images/linux.iso' \
    'the strict MBR boundary did not check boot code and signature before rejecting metadata changes' || return
  [[ $output != *'-n 446 '* ]] || {
    test_fail 'verification treated the mutable MBR disk signature as boot code'
    return
  }
  test_assert_contains "$output" 'payload:1||mismatch' \
    'a changed installer payload was accepted' || return
  test_assert_contains "$output" 'read:2||drive-read-failed' \
    'an operational compare failure was mislabeled as a data mismatch'
}
test_case 'USB verification rejects unvalidated MBR partition-map changes' \
  _test_usb_compare_treats_cmp_as_authoritative

_test_usb_compare_uses_real_byte_boundaries() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source.iso" target_image="$TEST_TMP_DIR/target.img"
  local output=''
  test_write_file "$source_image" "${(l:20480::a:)}" || return
  command /bin/cp "$source_image" "$target_image" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source_image=$2 target_image=$3
    _usb_dd_read_run() {
      local -a arguments=("$@")
      local -i index=0
      for (( index = 1; index <= ${#arguments}; ++index )); do
        [[ ${arguments[index]} == if=/dev/rdisk7 ]] && arguments[index]="if=$target_image"
      done
      command /bin/dd "${arguments[@]}"
    }
    mutate_byte() {
      print -rn -- X | command /bin/dd of="$target_image" bs=1 seek="$1" conv=notrunc 2>/dev/null
    }
    reset_target() { command /bin/cp "$source_image" "$target_image"; }

    _usb_compare_written_image "$source_image" disk7 20480
    print -r -- "exact:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target; mutate_byte 440
    _usb_compare_written_image "$source_image" disk7 20480
    print -r -- "signature:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target; mutate_byte 500
    _usb_compare_written_image "$source_image" disk7 20480
    print -r -- "partition:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target; mutate_byte 439
    _usb_compare_written_image "$source_image" disk7 20480
    print -r -- "boot:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target; mutate_byte 17408
    _usb_compare_written_image "$source_image" disk7 20480
    print -r -- "payload:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image") || return

  test_assert_contains "$output" 'exact:0|full|' \
    'real cmp did not accept an exact image-sized copy' || return
  test_assert_contains "$output" 'signature:1||mismatch' \
    'a changed MBR disk signature was accepted without validating the partition map' || return
  test_assert_contains "$output" 'partition:1||mismatch' \
    'a changed MBR partition map was accepted as bootable' || return
  test_assert_contains "$output" 'boot:1||mismatch' \
    'real cmp accepted corruption in the preserved 440-byte boot-code region' || return
  test_assert_contains "$output" 'payload:1||mismatch' \
    'real cmp accepted corruption at the stable-payload boundary'
}
test_case 'USB verification proves strict MBR boot and partition-map boundaries' \
  _test_usb_compare_uses_real_byte_boundaries

_test_usb_write_le() {
  emulate -L zsh
  local path=$1 offset=$2 value=$3 count=$4 escaped='' byte=''
  local -i index=0
  for (( index = 0; index < count; ++index )); do
    builtin printf -v byte '%02x' $(( value & 255 ))
    escaped+="\\x$byte"
    (( value >>= 8 ))
  done
  builtin printf '%b' "$escaped" |
    command /bin/dd of="$path" bs=1 seek="$offset" conv=notrunc status=none 2>/dev/null
}

_test_usb_range_crc32() {
  emulate -L zsh
  local path=$1 offset=$2 count=$3 output=''
  output=$(command /bin/dd if="$path" bs=1 skip="$offset" count="$count" \
      status=none 2>/dev/null | command /usr/bin/cksum -o 3) || return
  REPLY=${output%% *}
  [[ $REPLY == <-> ]]
}

_test_usb_update_gpt_header_crc() {
  emulate -L zsh
  local path=$1 offset=$2
  _test_usb_write_le "$path" $(( offset + 16 )) 0 4 || return
  _test_usb_range_crc32 "$path" "$offset" 92 || return
  _test_usb_write_le "$path" $(( offset + 16 )) "$REPLY" 4
}

_test_usb_make_hybrid_gpt_fixture() {
  emulate -L zsh
  local path=$1
  command /bin/dd if=/dev/zero of="$path" bs=512 count=256 status=none || return
  builtin printf 'EFI PART' |
    command /bin/dd of="$path" bs=1 seek=512 conv=notrunc status=none 2>/dev/null || return
  builtin printf 'EFI PART' |
    command /bin/dd of="$path" bs=1 seek=130560 conv=notrunc status=none 2>/dev/null || return
  builtin printf '%b' '\x55\xaa' |
    command /bin/dd of="$path" bs=1 seek=510 conv=notrunc status=none 2>/dev/null || return
  _test_usb_write_le "$path" 524 92 4 || return
  _test_usb_write_le "$path" 520 65536 4 || return
  _test_usb_write_le "$path" 536 1 8 || return
  _test_usb_write_le "$path" 544 255 8 || return
  _test_usb_write_le "$path" 552 64 8 || return
  _test_usb_write_le "$path" 560 210 8 || return
  _test_usb_write_le "$path" 584 20 8 || return
  _test_usb_write_le "$path" 592 176 4 || return
  _test_usb_write_le "$path" 596 128 4 || return
  _test_usb_write_le "$path" 130572 92 4 || return
  _test_usb_write_le "$path" 130568 65536 4 || return
  _test_usb_write_le "$path" 130584 255 8 || return
  _test_usb_write_le "$path" 130592 1 8 || return
  _test_usb_write_le "$path" 130600 64 8 || return
  _test_usb_write_le "$path" 130608 210 8 || return
  _test_usb_write_le "$path" 130632 211 8 || return
  _test_usb_write_le "$path" 130640 176 4 || return
  _test_usb_write_le "$path" 130644 128 4 || return
  builtin printf 'P' |
    command /bin/dd of="$path" bs=1 seek=32768 conv=notrunc status=none 2>/dev/null || return
  builtin printf 'Q' |
    command /bin/dd of="$path" bs=1 seek=108031 conv=notrunc status=none 2>/dev/null || return
  _test_usb_range_crc32 "$path" 10240 22528 || return
  local entry_crc=$REPLY
  _test_usb_write_le "$path" 600 "$entry_crc" 4 || return
  _test_usb_write_le "$path" 130648 "$entry_crc" 4 || return
  _test_usb_update_gpt_header_crc "$path" 512 || return
  _test_usb_update_gpt_header_crc "$path" 130560
}

_test_usb_make_relocated_gpt_target() {
  emulate -L zsh
  local source=$1 target=$2
  command /bin/cp "$source" "$target" || return
  command /usr/bin/truncate -s 153600 "$target" || return
  command /bin/dd if="$source" of="$target" bs=512 skip=211 seek=255 count=44 \
    conv=notrunc status=none 2>/dev/null || return
  command /bin/dd if="$source" of="$target" bs=512 skip=255 seek=299 count=1 \
    conv=notrunc status=none 2>/dev/null || return
  _test_usb_write_le "$target" 544 299 8 || return
  _test_usb_write_le "$target" 560 254 8 || return
  _test_usb_write_le "$target" 153112 299 8 || return
  _test_usb_write_le "$target" 153136 254 8 || return
  _test_usb_write_le "$target" 153160 255 8 || return
  _test_usb_update_gpt_header_crc "$target" 512 || return
  _test_usb_update_gpt_header_crc "$target" 153088
}

_test_usb_make_sparse_relocated_gpt_target() {
  emulate -L zsh
  local source=$1 target=$2
  command /bin/cp "$source" "$target" || return
  command /usr/bin/truncate -s 153600 "$target" || return
  command /bin/dd if="$source" of="$target" bs=512 skip=255 seek=299 count=1 \
    conv=notrunc status=none 2>/dev/null || return
  command /bin/dd if=/dev/zero of="$target" bs=512 seek=255 count=1 \
    conv=notrunc status=none 2>/dev/null || return
  _test_usb_write_le "$target" 544 299 8 || return
  _test_usb_write_le "$target" 153112 299 8 || return
  _test_usb_write_le "$target" 153136 210 8 || return
  _test_usb_write_le "$target" 153160 211 8 || return
  _test_usb_update_gpt_header_crc "$target" 512 || return
  _test_usb_update_gpt_header_crc "$target" 153088
}

_test_usb_compare_understands_real_hybrid_gpt_geometry() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source.iso" target_image="$TEST_TMP_DIR/target.img"
  local pristine_target="$TEST_TMP_DIR/pristine-target.img"
  local output=''
  _test_usb_make_hybrid_gpt_fixture "$source_image" || return
  _test_usb_make_relocated_gpt_target "$source_image" "$target_image" || return
  command /bin/cp "$target_image" "$pristine_target" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    source_image=$2 target_image=$3 pristine_target=$4
    _usb_dd_read_run() {
      local -a arguments=("$@")
      local -i index=0
      for (( index = 1; index <= ${#arguments}; ++index )); do
        [[ ${arguments[index]} == if=/dev/rdisk7 ]] && arguments[index]="if=$target_image"
      done
      command /bin/dd "${arguments[@]}"
    }
    mutate_byte() {
      builtin printf X | command /bin/dd of="$target_image" bs=1 seek="$1" conv=notrunc status=none 2>/dev/null
    }
    reset_target() { command /bin/cp "$pristine_target" "$target_image"; }

    mutate_byte 440
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "geometry:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    reset_target; mutate_byte 439
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "boot:$?"
    reset_target; mutate_byte 510
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "signature:$?"
    reset_target; mutate_byte 32768
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "payload-start:$?"
    reset_target; mutate_byte 108031
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "payload-end:$?"
    reset_target; mutate_byte 10240
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "partition-entry:$?"
    reset_target; mutate_byte 520
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "primary-header:$?"
    reset_target; mutate_byte 130560
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "backup-entry:$?"
    reset_target; mutate_byte 153120
    _usb_compare_written_image "$source_image" disk7 131072 153600
    print -r -- "backup-header:$?"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image" "$pristine_target") || return

  test_assert_contains "$output" 'geometry:0|boot-and-installer-payload|gpt-geometry-diff' \
    'validated primary and backup GPT geometry changes caused a false USB failure' || return
  for result in 'boot:1' 'signature:1' 'payload-start:1' 'payload-end:1' \
      'partition-entry:1' 'primary-header:1' 'backup-entry:1' 'backup-header:1'; do
    test_assert_contains "$output" "$result" \
      'hybrid GPT verification accepted corruption outside validated geometry' || return
  done
}
test_case 'USB verification parses hybrid GPT bounds and preserves every boot and payload byte' \
  _test_usb_compare_understands_real_hybrid_gpt_geometry

_test_usb_compare_accepts_nonadjacent_relocated_backup_entries() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source.iso" target_image="$TEST_TMP_DIR/target.img"
  local output=''
  _test_usb_make_hybrid_gpt_fixture "$source_image" || return
  _test_usb_make_sparse_relocated_gpt_target "$source_image" "$target_image" || return
  builtin printf X |
    command /bin/dd of="$target_image" bs=1 seek=440 conv=notrunc status=none \
      2>/dev/null || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    target_image=$3
    _usb_dd_read_run() {
      local -a arguments=("$@")
      local -i index=0
      for (( index = 1; index <= ${#arguments}; ++index )); do
        [[ ${arguments[index]} == if=/dev/rdisk7 ]] && arguments[index]="if=$target_image"
      done
      command /bin/dd "${arguments[@]}"
    }
    _usb_compare_written_image "$2" disk7 131072 153600
    print -r -- "result:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image") || return

  test_assert_contains "$output" \
    'result:0|boot-and-installer-payload|gpt-geometry-diff' \
    'a valid relocated backup table ending before its header was rejected for not being adjacent'
}
test_case 'USB verification accepts nonadjacent relocated GPT backup entries' \
  _test_usb_compare_accepts_nonadjacent_relocated_backup_entries

_test_usb_compare_accepts_source_bounded_gpt_on_larger_media() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source.iso" target_image="$TEST_TMP_DIR/target.img"
  local pristine_target="$TEST_TMP_DIR/pristine-target.img"
  local output=''
  _test_usb_make_hybrid_gpt_fixture "$source_image" || return
  command /bin/cp "$source_image" "$target_image" || return
  command /usr/bin/truncate -s 153600 "$target_image" || return
  # Raw hybrid images retain their internally valid backup GPT at the end of
  # the image extent. Exercise the metadata fallback without changing GPT.
  builtin printf X |
    command /bin/dd of="$target_image" bs=1 seek=440 conv=notrunc status=none \
      2>/dev/null || return
  command /bin/cp "$target_image" "$pristine_target" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    target_image=$3 pristine_target=$4
    _usb_dd_read_run() {
      local -a arguments=("$@")
      local -i index=0
      for (( index = 1; index <= ${#arguments}; ++index )); do
        [[ ${arguments[index]} == if=/dev/rdisk7 ]] && arguments[index]="if=$target_image"
      done
      command /bin/dd "${arguments[@]}"
    }
    mutate_byte() {
      builtin printf X | command /bin/dd of="$target_image" bs=1 seek="$1" \
        conv=notrunc status=none 2>/dev/null
    }
    reset_target() { command /bin/cp "$pristine_target" "$target_image"; }

    _usb_compare_written_image "$2" disk7 131072 153600
    print -r -- "result:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    reset_target; mutate_byte 520
    _usb_compare_written_image "$2" disk7 131072 153600
    print -r -- "primary:$?|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target; mutate_byte 108032
    _usb_compare_written_image "$2" disk7 131072 153600
    print -r -- "backup-entries:$?|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target; mutate_byte 130568
    _usb_compare_written_image "$2" disk7 131072 153600
    print -r -- "backup-header:$?|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target; mutate_byte 446
    _usb_compare_written_image "$2" disk7 131072 153600
    print -r -- "hybrid-mbr:$?|$_USB_PAYLOAD_VERIFY_ERROR"
    reset_target
    builtin printf "EFI PART" | command /bin/dd of="$target_image" bs=1 \
      seek=153088 conv=notrunc status=none 2>/dev/null
    _usb_compare_written_image "$2" disk7 131072 153600
    print -r -- "stale-tail:$?|$_USB_PAYLOAD_VERIFY_ERROR"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image" "$pristine_target") || return

  test_assert_contains "$output" \
    'result:0|boot-and-installer-payload|gpt-source-bounds' \
    'a faithful image-sized GPT on larger media was rejected as an invalid device-wide GPT' || return
  for result in 'primary:1|gpt-invalid' 'backup-entries:1|gpt-invalid' \
      'backup-header:1|gpt-invalid' 'hybrid-mbr:1|mismatch'; do
    test_assert_contains "$output" "$result" \
      'source-bounded GPT verification accepted corrupt primary or backup metadata' || return
  done
  test_assert_contains "$output" 'stale-tail:1|stale-tail-gpt' \
    'source-bounded verification accepted a competing old GPT at the physical device tail'
}
test_case 'USB verification accepts a faithful source-bounded GPT on larger raw media' \
  _test_usb_compare_accepts_source_bounded_gpt_on_larger_media

_test_usb_readback_bypasses_cache_and_compares_exact_range() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/source.iso" target_image="$TEST_TMP_DIR/target.img"
  local trace_file="$TEST_TMP_DIR/readback-args" output=''
  test_write_file "$source_image" "${(l:2048::a:)}" || return
  command /bin/cp "$source_image" "$target_image" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    target_image=$3 trace_file=$4
    _usb_dd_read_run() {
      local -a arguments=("$@")
      local -i index=0
      print -r -- "${(j: :)arguments}" >| "$trace_file"
      for (( index = 1; index <= ${#arguments}; ++index )); do
        [[ ${arguments[index]} == if=/dev/rdisk7 ]] && arguments[index]="if=$target_image"
      done
      command /bin/dd "${arguments[@]}"
    }
    _usb_cmp_run -n 2 -i 510 /dev/rdisk7 "$2"
    print -r -- "unaligned:$?"
    _usb_cmp_run -n 1024 -i 512 /dev/rdisk7 "$2"
    print -r -- "exact:$?"
    builtin printf X | command /bin/dd of="$target_image" bs=1 seek=700 conv=notrunc status=none 2>/dev/null
    _usb_cmp_run -n 1024 -i 512 /dev/rdisk7 "$2" >/dev/null 2>&1
    print -r -- "changed:$?"
    short_image=$HOME/short.img
    command /bin/dd if="$target_image" of="$short_image" bs=1 count=600 status=none
    target_image=$short_image
    _usb_cmp_run -n 1024 -i 512 /dev/rdisk7 "$2" >/dev/null 2>&1
    print -r -- "short:$?"
    print -r -- "args:$(<$trace_file)"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image" "$trace_file") || return

  test_assert_contains "$output" 'unaligned:0' \
    'uncached read-back applied the wrong source offset to an unaligned range' || return
  test_assert_contains "$output" 'exact:0' \
    'uncached read-back rejected an exact range' || return
  test_assert_contains "$output" 'changed:1' \
    'uncached read-back accepted changed media' || return
  test_assert_contains "$output" 'short:2' \
    'a truncated raw read was reported as byte corruption instead of a read failure' || return
  test_assert_contains "$output" 'if=/dev/rdisk7 bs=512 skip=1 count=2 iflag=direct' \
    'finished-drive verification did not request an exact uncached raw read'
}
test_case 'USB verification reads exact raw ranges with the macOS cache disabled' \
  _test_usb_readback_bypasses_cache_and_compares_exact_range

_test_usb_large_readback_uses_aligned_multi_megabyte_blocks() {
  test_make_temp_dir || return
  local source_image="$TEST_TMP_DIR/large-source.iso"
  local target_image="$TEST_TMP_DIR/large-target.img"
  local trace_file="$TEST_TMP_DIR/large-readback-args" output=''
  command /bin/dd if=/dev/zero of="$source_image" bs=1m count=8 status=none || return
  command /bin/dd if=/dev/zero of="$source_image" bs=512 count=1 seek=16384 \
    conv=notrunc status=none || return
  command /bin/cp "$source_image" "$target_image" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    target_image=$3 trace_file=$4
    _usb_dd_read_run() {
      local -a arguments=("$@")
      local -i index=0
      print -r -- "${(j: :)arguments}" >| "$trace_file"
      for (( index = 1; index <= ${#arguments}; ++index )); do
        [[ ${arguments[index]} == if=/dev/rdisk7 ]] && arguments[index]="if=$target_image"
      done
      command /bin/dd "${arguments[@]}"
    }
    _usb_cmp_run -n 8389120 /dev/rdisk7 "$2"
    print -r -- "status:$?"
    print -r -- "args:$(<$trace_file)"
  ' "$TEST_REPO_ROOT" "$source_image" "$target_image" "$trace_file") || return

  test_assert_contains "$output" 'status:0' \
    'multi-megabyte raw comparison rejected identical media' || return
  test_assert_contains "$output" \
    'if=/dev/rdisk7 bs=4m skip=0 count=3 iflag=direct status=progress' \
    'large raw comparison regressed to millions of uncached 512-byte reads'
}
test_case 'USB large verification reads use aligned multi-megabyte blocks' \
  _test_usb_large_readback_uses_aligned_multi_megabyte_blocks

_test_usb_verification_paints_live_read_progress() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -ga frames=()
    _usb_unmount() { return 0; }
    _usb_progress_stage() { frames+=("$*"); }
    _usb_compare_written_image() {
      if [[ -n ${_USB_VERIFY_META_FILE:-} && -n ${_USB_VERIFY_PROGRESS_FILE:-} ]]; then
        builtin printf "%s\\t%s\\n" "Full image comparison" 8388608 \
          >| "$_USB_VERIFY_META_FILE"
        print -r -- "4194304 bytes (4.2 MB) transferred in 1.0 secs (4.2 MB/sec)" \
          >| "$_USB_VERIFY_PROGRESS_FILE"
      fi
      command /bin/sleep 0.6
      _USB_PAYLOAD_VERIFY_SCOPE=full
      _USB_PAYLOAD_VERIFY_ERROR=""
      return 0
    }
    _usb_verify_payload /images/linux.iso disk7 8388608 16777216
    print -r -- "status:$?|scope:$_USB_PAYLOAD_VERIFY_SCOPE"
    print -r -- "frames:${(j:|:)frames}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'status:0|scope:full' \
    'progress supervision lost the finished-drive verification result' || return
  test_assert_contains "$output" '50%' \
    'finished-drive verification remained an unobservable static screen'
}
test_case 'USB verification paints live determinate read progress' \
  _test_usb_verification_paints_live_read_progress

_test_usb_unmounts_immediately_after_write() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -ga trace=()
    _usb_progress_stage() { return 0; }
    _usb_authorize() { trace+=(authorize); }
    _usb_authorization_valid() { return 0; }
    _usb_image_revalidate() { trace+=(image-revalidate); }
    _usb_target_revalidate() { trace+=(target-revalidate); }
    _usb_unmount() { trace+=(unmount); }
    _usb_write_image() { trace+=(write); _USB_WRITE_BYTES_OBSERVED=$3; }
    _usb_verify_payload() { trace+=(verify); }
    _usb_eject() { trace+=(eject); }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify >/dev/null 2>&1
    print -r -- "status:$?|${(j:,:)trace}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'status:0|authorize,image-revalidate,target-revalidate,unmount,target-revalidate,write,unmount,image-revalidate,verify,eject' \
    'the target was not unmounted immediately after dd and before slower source checks'
}
test_case 'USB execution immediately unmounts after writing before source checks' \
  _test_usb_unmounts_immediately_after_write

_test_usb_checksum_verification_keeps_cmp_authoritative() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_unmount() { return 0; }
    _usb_compare_written_image() {
      _USB_PAYLOAD_VERIFY_SCOPE=full _USB_PAYLOAD_VERIFY_ERROR=""
      return 0
    }
    _usb_verify_payload_checksum /images/linux.iso disk7 20000 256
    print -r -- "status:$?|scope:$_USB_PAYLOAD_VERIFY_SCOPE"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'status:0|scope:full' \
    'a provided checksum displaced authoritative raw byte comparison'
}
test_case 'USB provided checksum keeps authoritative raw verification' \
  _test_usb_checksum_verification_keeps_cmp_authoritative

_test_usb_privileged_verification_never_hides_a_prompt() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    print -r -- "read:${functions[_usb_dd_read_run]}"
  ' "$TEST_REPO_ROOT") || return
  [[ $output == *'/usr/bin/sudo -n /bin/dd'* ]] || {
    test_fail 'USB raw read-back can prompt invisibly after the sudo timestamp expires'
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
    source "$1/.zsh.addons/.zsh.usb" || exit
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

_test_usb_expired_verification_authorization_is_explicit() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -ga trace=()
    _usb_progress_stage() { trace+=("stage:$1"); }
    _usb_image_revalidate() { return 0; }
    _usb_target_revalidate() { return 0; }
    _usb_unmount() { return 0; }
    _usb_write_image() { _USB_WRITE_BYTES_OBSERVED=$3; return 0; }
    auth_checks=0
    _usb_authorization_valid() {
      trace+=(auth-check)
      (( ++auth_checks == 1 )) && return 0
      return 1
    }
    _usb_authorize() { trace+=(auth-prompt); return 1; }
    _usb_verify_payload() { trace+=(verify); return 0; }
    _usb_eject() { trace+=(eject); return 0; }
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 >/dev/null 2>&1
    print -r -- "status:$?|${(j:,:)trace}|$_USB_RESULT_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'auth-check,stage:Authorization required for verification,auth-prompt,stage:Ejecting external drive,eject' \
    'expired verification authorization did not become a visible named stage' || return
  [[ $output != *',verify,'* ]] || {
    test_fail 'verification ran after administrator reauthorization failed'
    return
  }
  test_assert_contains "$output" 'Administrator authorization expired before USB verification' \
    'authorization expiry was mislabeled as a drive read or payload mismatch'
}
test_case 'USB verification handles expired authorization before read-back' \
  _test_usb_expired_verification_authorization_is_explicit

_test_usb_workspace_retries_transient_target_permission() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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

_test_usb_ejected_drive_recovery_is_explicit() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_disks_capture() {
      _USB_CAPTURE_ERROR="no whole external physical disks are attached"
      return 1
    }
    _usb_choose() {
      print -r -- "label:${_USB_PICKER_LABELS[1]}"
      print -r -- "subtitle:$2"
      print -r -- "detail:${_USB_PICKER_DETAILS[1]}"
      return 1
    }
    _usb_disks_capture_retry 30000 linux.iso image "Choose another image"
    print -r -- "status:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'label:Make drive available · connect or replug it, then retry' \
    'the empty target view did not give the required physical recovery action' || return
  test_assert_contains "$output" \
    'subtitle:DRIVE unavailable · no external disk is currently visible to macOS' \
    'the empty target status repeated an internal provider error instead of recovery guidance' || return
  test_assert_contains "$output" 'Ctrl-R cannot reactivate an ejected drive' \
    'the empty target details implied that refresh can recover an ejected drive' || return
  test_assert_contains "$output" 'status:1' \
    'leaving the empty target recovery view did not preserve cancellation'
}
test_case 'USB Step 2 explains physical recovery for an ejected drive' \
  _test_usb_ejected_drive_recovery_is_explicit

_test_usb_workspace_refreshes_images_with_spotlight_snapshot() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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
    _usb_diskutil_plist_capture() { _USB_PLIST=catalog; }
    _usb_plist_raw() {
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

  test_assert_contains "$output" 'view1:Format External Device · Step 1 of 3|1|refresh:1' \
    'format drive selection did not expose Ctrl-R refresh' || return
  test_assert_contains "$output" 'view2:Format External Device · Step 1 of 3|1|refresh:1' \
    'format refresh did not return to a fresh external-device snapshot' || return
  test_assert_contains "$output" 'view3:Format External Device · Step 2 of 3|1,2|refresh:0' \
    'format selection did not follow exact drive selection' || return
  test_assert_contains "$output" \
    'view4:Format External Device · Step 3 of 3|default-name,custom-name|refresh:0' \
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

_test_usb_volume_name_validation_is_format_aware() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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
    setopt EXTENDED_GLOB
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -gA ZSH_OUTPUT_COLORS=(heading 123 info 124 accent 125 success 126)
    TERM=xterm-256color
    zmodload zsh/zpty || exit 2
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
      local mode=$1 capture="" line=""
      if [[ $mode == plain ]]; then
        NO_COLOR=1 zpty format-report _format_report_driver || return
      else
        zpty format-report _format_report_driver || return
      fi
      {
        while zpty -r format-report line; do
          capture+=$line
          [[ $line == *END-FORMAT-REPORT* ]] && break
        done
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

_test_usb_windows_confirmation_names_filesystem_aware_action() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _USB_SELECTED_MEDIA_KIND=windows-installer
    _USB_SELECTED_IMAGE_ARCHITECTURE=x86_64
    read() { answer="ERASE disk28"; }
    _usb_confirm /images/windows.iso disk28 "DataTraveler · /dev/disk28" \
      flash-verify 256 "${(l:64::a:)}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'Action: Validate ISO SHA-256, create a UEFI FAT32 installer, verify every file, and eject' \
    'Windows confirmation described a raw flash instead of its filesystem-aware action' || return
  test_assert_contains "$output" \
    'UEFI only' \
    'Windows confirmation omitted the supported firmware boundary'
}
test_case 'USB Windows confirmation names its UEFI FAT32 file-tree workflow' \
  _test_usb_windows_confirmation_names_filesystem_aware_action

_test_usb_confirmation_colors_only_exact_phrase() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.output" || exit
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_confirmation_prompt "ERASE disk28"
    [[ $REPLY == "Type exactly ERASE disk28 to continue: " ]] || exit 2
    zmodload zsh/zpty || exit 3
    _colored_confirmation() {
      TERM=xterm-256color
      unset NO_COLOR
      _usb_confirm /images/linux.iso disk28 target flash-verify
    }
    local frame=""
    zpty usb-colored _colored_confirmation || exit 4
    {
      zpty -r usb-colored frame "*to continue: *" || exit 5
      [[ $frame == *$'\''\e[1;38;5;221mERASE disk28\e[0m'\''* ]] || exit 6
      zpty -w usb-colored "ERASE disk28"
    } always { zpty -d usb-colored 2>/dev/null; }
    _plain_confirmation() {
      TERM=xterm-256color NO_COLOR=1
      _usb_confirm /images/linux.iso disk28 target flash-verify
    }
    frame=""
    zpty usb-plain _plain_confirmation || exit 7
    {
      zpty -r usb-plain frame "*to continue: *" || exit 8
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
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -ga trace=()
    _usb_authorize() { trace+=(authorize); }
    _usb_authorization_valid() { return 0; }
    _usb_image_revalidate() { trace+=(image-revalidate); }
    _usb_target_revalidate() { trace+=(revalidate); }
    _usb_unmount() { trace+=(unmount); }
    _usb_write_image() {
      trace+=(write)
      if (( ${write_status:-0} )); then
        _USB_WRITE_ERROR="dd: /dev/rdisk7: Resource busy"
      fi
      return ${write_status:-0}
    }
    _usb_verify_payload() { trace+=(verify); return ${verify_status:-0}; }
    _usb_eject() { trace+=(eject); return ${eject_status:-0}; }

    verify_status=9
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100352 flash-verify >/dev/null 2>&1
    print -r -- "verify-status:$?|${(j:,:)trace}"
    trace=() verify_status=0 write_status=7
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100352 flash-verify >/dev/null 2>&1
    print -r -- "write-status:$?|${(j:,:)trace}|$_USB_RESULT_ERROR"
    trace=() write_status=0
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100352 flash-verify disk7 >/dev/null 2>&1
    print -r -- "source-status:$?|${(j:,:)trace}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'verify-status:9|authorize,image-revalidate,revalidate,unmount,revalidate,write,unmount,image-revalidate,verify,eject' \
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
    source "$1/.zsh.addons/.zsh.usb" || exit
    expected=${(l:64::a:)}
    typeset -ga trace=()
    _usb_progress_stage() { trace+=("stage:$1"); }
    _usb_image_revalidate() { trace+=(image-revalidate); }
    _usb_image_checksum() { trace+=("image-sha:$2"); REPLY=${actual:-$expected}; }
    _usb_authorization_valid() { return 0; }
    _usb_target_revalidate() { trace+=(target-revalidate); }
    _usb_unmount() { trace+=(unmount); }
    _usb_write_image() { trace+=(write); }
    _usb_verify_payload_checksum() {
      trace+=("raw-verify:$4")
    }
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
    _usb_result_screen 0
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'mismatch:1|stage:Validating image and drive,image-revalidate,stage:Checking image SHA-256,image-sha:256|0|The image SHA-256 does not match' \
    'a mismatched provided checksum reached the target or write boundary' || return
  test_assert_contains "$output" 'matched:0|' \
    'a matching provided checksum did not complete' || return
  test_assert_contains "$output" 'image-sha:256,target-revalidate,stage:Unmounting external drive,unmount,target-revalidate,stage:Writing image,write,unmount,image-revalidate,stage:Rechecking image SHA-256,image-sha:256,stage:Verifying USB against image,raw-verify:256,stage:Ejecting external drive,eject|1|1' \
    'a matching source checksum did not retain authoritative raw USB verification' || return
  test_assert_contains "$output" 'summary:[ Done ]|Flash complete' \
    'checksum completion did not retain the normal success summary' || return
  test_assert_contains "$output" 'Image integrity · Verified · SHA-256 matched|USB verification · Selected image bytes matched|Safe to remove' \
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
    source "$1/.zsh.addons/.zsh.usb" || exit
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
    _usb_verify_payload() { trace+=(late-verify); return 0; }
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

_test_usb_atomic_failure_retains_semantic_reason() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
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
    _usb_result_screen "$result_status"
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
    source "$1/.zsh.addons/.zsh.usb" || exit
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

_test_usb_verification_owns_subprocess_output() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_unmount() { print -r -- "Unmount of all volumes was successful"; }
    _usb_cmp_run() { return 0; }
    _usb_verify_payload /images/linux.iso disk7 8388608
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal '' "$output" \
    'verification leaked native subprocess output over the status screen'
}
test_case 'USB verification keeps native subprocess output out of the status frame' \
  _test_usb_verification_owns_subprocess_output

_test_usb_execution_reports_stages_and_completion_stats() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    typeset -ga stages=()
    _usb_progress_stage() { stages+=("$1"); }
    _usb_authorize() { return 0; }
    _usb_image_revalidate() { return 0; }
    _usb_target_revalidate() { return 0; }
    _usb_unmount() { return 0; }
    _usb_write_image() { return 0; }
    _usb_authorization_valid() { return 0; }
    _usb_verify_payload() { return 0; }
    _usb_eject() { return 0; }
    _USB_SELECTED_DISK_LABEL="External SSD · 64.0 GiB · /dev/disk7"
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint 8388608 flash-verify || exit 2
    print -r -- "stages:${(j:,:)stages}"
    print -r -- "result:${_USB_RESULT_OUTCOME}|${_USB_RESULT_BYTES}|${_USB_RESULT_VERIFIED}|${_USB_RESULT_EJECTED}"
    _usb_result_choose() {
      print -r -- "summary:${(j:|:)_USB_PICKER_LABELS}"
    }
    _usb_result_screen 0
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'stages:Validating image and drive,Unmounting external drive,Writing image,Verifying USB against image,Ejecting external drive' \
    'execution did not publish each destructive workflow stage' || return
  test_assert_contains "$output" 'result:complete|8388608|1|1' \
    'successful execution did not retain completion facts' || return
  test_assert_contains "$output" 'Flash complete' \
    'completion screen omitted its success state' || return
  test_assert_contains "$output" '8.0 MiB written' \
    'completion screen omitted the exact written size' || return
  test_assert_contains "$output" 'USB verification · Selected image bytes matched' \
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
    source "$1/.zsh.addons/.zsh.usb" || exit
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
    _usb_write_image() { trace+=(write); _USB_WRITE_BYTES_OBSERVED=$3; }
    _usb_verify_payload() { trace+=(verify); }
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
    source "$1/.zsh.addons/.zsh.usb" || exit
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
    print -r -- "wired:$([[ ${functions[flash-usb]} == *_usb_cleanup_eject* ]] && print yes || print no)"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'before:' \
    'cleanup ejected a target before writing started' || return
  test_assert_contains "$output" 'started:eject:disk7|1' \
    'cleanup did not eject the exact started target' || return
  test_assert_contains "$output" 'bounded:eject:disk7' \
    'cleanup retried an ejected target or accepted an invalid identifier' || return
  test_assert_contains "$output" 'wired:yes' \
    'flash-usb interruption cleanup is not connected to its always boundary'
}
test_case 'USB outer cleanup attempts safe eject after interruption' \
  _test_usb_outer_cleanup_ejects_only_an_started_exact_target

_test_usb_failure_screen_separates_image_and_drive_evidence() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_choose() {
      local specification="" role=""
      local -a roles=()
      for specification in "${_USB_PICKER_HIGHLIGHTS[@]}"; do
        [[ -n $specification ]] && role=${specification##*:} || role=""
        roles+=("$role")
      done
      roles+=("${_ZLE_PICKER_PASSIVE_STYLES[@]}")
      print -r -- "labels:${(j:|:)_USB_PICKER_LABELS}|${(j:|:)_ZLE_PICKER_PASSIVE_LINES}"
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
    _usb_result_screen 4

    _USB_RESULT_EXPECTED_CHECKSUM="" _USB_RESULT_IMAGE_CHECKSUM=""
    _USB_RESULT_CHECKSUM_VALIDATED=0 _USB_RESULT_VERIFY_REASON=mismatch
    _usb_result_screen 1

    _USB_RESULT_EXPECTED_CHECKSUM=${(l:64::d:)}
    _USB_RESULT_IMAGE_CHECKSUM=$_USB_RESULT_EXPECTED_CHECKSUM
    _USB_RESULT_CHECKSUM_VALIDATED=1 _USB_RESULT_VERIFY_REASON=mismatch
    _USB_RESULT_ERROR="The finished USB installer or boot bytes differ from the selected image."
    _usb_result_screen 1
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
