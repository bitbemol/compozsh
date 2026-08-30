# Native external-disk image writing and verification.

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
  test_assert_contains "$output" 'scope:Spotlight index under ~ + current folder + ~/Downloads|partial:0' \
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
  local arm="$TEST_TMP_DIR/proxmox-ve-arm64.iso" unknown="$TEST_TMP_DIR/rescue.iso" output=''
  test_write_file "$amd" "${(l:20000::a:)}" || return
  test_write_file "$arm" "${(l:20000::b:)}" || return
  test_write_file "$unknown" "${(l:20000::c:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_image_add "$2" || exit 2
    _usb_image_add "$3" || exit 3
    _usb_image_add "$4" || exit 4
    print -rl -- "${_USB_IMAGE_LABELS[@]}"
    print -r -- "styles:${(j:|:)_USB_IMAGE_HIGHLIGHTS}"
    _USB_SELECTED_IMAGE_ARCHITECTURE=""
    _usb_image_architecture_capture "$3"
    print -r -- "selected:$_USB_SELECTED_IMAGE_ARCHITECTURE"
    print -r -- "unknown-detail:${_USB_IMAGE_DETAILS[3]}"
  ' "$TEST_REPO_ROOT" "$amd" "$arm" "$unknown") || return

  test_assert_contains "$output" 'ubuntu-live-server-amd64.iso · x86-64 ·' \
    'recognized x86-64 architecture was not visible in the image row' || return
  test_assert_contains "$output" 'proxmox-ve-arm64.iso · ARM64 ·' \
    'recognized ARM64 architecture was not given equal passive prominence' || return
  test_assert_contains "$output" 'styles:' \
    'image rows did not publish semantic metadata spans' || return
  [[ $output == *styles:*picker-architecture*picker-size*'|'*picker-architecture*picker-size*'|'*picker-size* ]] ||
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
    info_plist="<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>DeviceIdentifier</key><string>disk7</string><key>ParentWholeDisk</key><string>disk7</string><key>TotalSize</key><integer>64000000000</integer><key>MediaName</key><string>External SSD</string><key>BusProtocol</key><string>Thunderbolt</string><key>Internal</key><false/><key>VirtualOrPhysical</key><string>Physical</string><key>WholeDisk</key><true/><key>WritableMedia</key><true/><key>DeviceTreePath</key><string>IOService:/fixture</string></dict></plist>"
    _usb_disk_info_read() { _USB_PLIST=$info_plist; }
    _usb_disk_info_capture disk7 || exit 3
    _usb_info_is_eligible || exit 4
    print -r -- "info:${_USB_INFO_ID}|${_USB_INFO_SIZE}|${_USB_INFO_NAME}|${_USB_INFO_PROTOCOL}|${_USB_INFO_FINGERPRINT}"
    _usb_image_filesystem_device_capture() { _USB_IMAGE_DEVICE=/dev/disk7s2; }
    _usb_image_source_disk_capture /images/linux.iso || exit 5
    print -r -- "source:${_USB_IMAGE_SOURCE_DISK}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'ids:disk7,disk9' \
    'diskutil list plist did not exclude partition slices' || return
  test_assert_contains "$output" \
    'info:disk7|64000000000|External SSD|Thunderbolt|disk7|64000000000|External SSD|Thunderbolt|IOService:/fixture' \
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

_test_usb_native_checksum_boundaries() {
  test_make_temp_dir || return
  local image_a="$TEST_TMP_DIR/image-a.img" image_b="$TEST_TMP_DIR/image-b.img" output=''
  test_write_file "$image_a" "${(l:17408::a:)}${(l:4096::p:)}" || return
  test_write_file "$image_b" "${(l:17408::b:)}${(l:4096::p:)}" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_payload_checksum "$2" 21504 256 0 || exit 2
    first=$REPLY
    _usb_payload_checksum "$3" 21504 256 0 || exit 3
    second=$REPLY
    print -r -- "payload:${#first}|$([[ $first == $second ]] && print match || print mismatch)"
    print -rn -- abc >| "$HOME/abc"
    _usb_image_checksum "$HOME/abc" 256 || exit 4
    print -r -- "full:$REPLY"
  ' "$TEST_REPO_ROOT" "$image_a" "$image_b") || return

  test_assert_contains "$output" 'payload:64|match' \
    'payload hashing included the mutable partition prefix' || return
  test_assert_contains "$output" \
    'full:ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad' \
    'native full-image SHA-256 output was parsed incorrectly'
}
test_case 'USB native checksums separate the full image from its stable payload' \
  _test_usb_native_checksum_boundaries

_test_usb_payload_hash_rejects_missing_and_short_reads() {
  test_make_temp_dir || return
  local short="$TEST_TMP_DIR/short.img" output=''
  test_write_file "$short" 'five' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_payload_checksum /definitely/missing 20000 256 0 >/dev/null 2>&1
    print -r -- "missing:$?"
    _usb_payload_checksum "$2" 20000 256 0 >/dev/null 2>&1
    print -r -- "short:$?"
  ' "$TEST_REPO_ROOT" "$short") || return

  test_assert_contains "$output" 'missing:1' \
    'a missing payload source became a successful empty-input digest' || return
  test_assert_contains "$output" 'short:1' \
    'a short payload source became a successful truncated digest'
}
test_case 'USB payload hashing rejects missing and short reads' \
  _test_usb_payload_hash_rejects_missing_and_short_reads

_test_usb_compare_treats_cmp_as_authoritative() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_unmount() { return 0; }
    typeset -ga statuses=()
    _usb_cmp_run() {
      print -r -- "cmp:$*"
      local rc=${statuses[1]:-0}
      shift statuses
      return $rc
    }

    statuses=(0)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "full:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    statuses=(1 0 0)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "metadata:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    statuses=(1 1)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "boot:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    statuses=(1 0 1)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "payload:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"

    statuses=(2)
    _usb_compare_written_image /images/linux.iso disk7 20000
    print -r -- "read:$?|$_USB_PAYLOAD_VERIFY_SCOPE|$_USB_PAYLOAD_VERIFY_ERROR"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'full:0|full|' \
    'an exact full-image comparison was not retained as the strongest result' || return
  test_assert_contains "$output" 'metadata:0|payload-and-boot-code|metadata-diff' \
    'documented partition-metadata changes were not distinguished from full equality' || return
  test_assert_contains "$output" 'boot:1||mismatch' \
    'a changed boot-code region was accepted as harmless metadata' || return
  test_assert_contains "$output" 'payload:1||mismatch' \
    'a changed installer payload was accepted' || return
  test_assert_contains "$output" 'read:2||drive-read-failed' \
    'an operational compare failure was mislabeled as a data mismatch'
}
test_case 'USB verification uses full cmp with a qualified metadata fallback' \
  _test_usb_compare_treats_cmp_as_authoritative

_test_usb_diagnostic_hashes_cannot_contradict_cmp_success() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    _usb_unmount() { return 0; }
    _usb_compare_written_image() {
      _USB_PAYLOAD_VERIFY_SCOPE=full _USB_PAYLOAD_VERIFY_ERROR=""
      return 0
    }
    calls=0
    _usb_payload_checksum() {
      (( ++calls ))
      (( calls == 1 )) && REPLY=${(l:64::a:)} || REPLY=${(l:64::b:)}
    }
    _usb_verify_payload_checksum /images/linux.iso disk7 20000 256
    print -r -- "status:$?|image:${_USB_PAYLOAD_IMAGE_CHECKSUM:-none}|drive:${_USB_PAYLOAD_DRIVE_CHECKSUM:-none}|scope:$_USB_PAYLOAD_VERIFY_SCOPE"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'status:0|image:none|drive:none|scope:full' \
    'contradictory optional digests were presented as matching after cmp success'
}
test_case 'USB diagnostic hashes cannot contradict authoritative cmp' \
  _test_usb_diagnostic_hashes_cannot_contradict_cmp_success

_test_usb_privileged_verification_never_hides_a_prompt() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    print -r -- "cmp:${functions[_usb_cmp_run]}"
    print -r -- "hash:${functions[_usb_payload_checksum_run]}"
  ' "$TEST_REPO_ROOT") || return
  [[ $output == *'/usr/bin/sudo -n /usr/bin/cmp'* ]] || {
    test_fail 'USB cmp can prompt invisibly after the sudo timestamp expires'
    return
  }
  [[ $output == *'/usr/bin/sudo -n /usr/bin/head'* ]] || {
    test_fail 'USB drive hashing can prompt invisibly after the sudo timestamp expires'
    return
  }
  return 0
}
test_case 'USB verification uses noninteractive retained authorization' \
  _test_usb_privileged_verification_never_hides_a_prompt

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
    _usb_authorization_valid() { trace+=(auth-check); return 1; }
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
    'view1:custom-path,image:1|refresh:1|label:captured images · Ctrl-R refresh Spotlight' \
    'Step 1 did not expose its image-refresh capability' || return
  test_assert_contains "$output" \
    'view2:custom-path,image:1,image:2|refresh:1|label:captured images · Ctrl-R refresh Spotlight|query:iso|initial:image:2' \
    'image refresh did not retain the filter and exact prior image selection' || return
  test_assert_contains "$output" 'captures:1' \
    'Ctrl-R did not perform exactly one fresh image capture' || return
  test_assert_contains "$output" 'selected:/images/new.iso|disk9|flash-verify' \
    'the refreshed image snapshot did not continue through the established workflow'
}
test_case 'USB Step 1 refreshes Spotlight images without losing filter or selection context' \
  _test_usb_workspace_refreshes_images_with_spotlight_snapshot

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
    _usb_write_image() { trace+=(write); return ${write_status:-0}; }
    _usb_verify_payload() { trace+=(verify); return ${verify_status:-0}; }
    _usb_eject() { trace+=(eject); return ${eject_status:-0}; }

    verify_status=9
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100000 flash-verify >/dev/null 2>&1
    print -r -- "verify-status:$?|${(j:,:)trace}"
    trace=() verify_status=0 write_status=7
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100000 flash-verify >/dev/null 2>&1
    print -r -- "write-status:$?|${(j:,:)trace}"
    trace=() write_status=0
    _usb_execute /tmp/image.iso disk7 disk-fingerprint image-fingerprint 100000 flash-verify disk7 >/dev/null 2>&1
    print -r -- "source-status:$?|${(j:,:)trace}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'verify-status:9|authorize,image-revalidate,revalidate,unmount,revalidate,write,image-revalidate,verify,eject' \
    'verification failure or eject cleanup was lost' || return
  test_assert_contains "$output" 'write-status:7|authorize,image-revalidate,revalidate,unmount,revalidate,write,eject' \
    'write failure did not stop verification and preserve status' || return
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
      trace+=("payload-sha:$4")
      _USB_PAYLOAD_IMAGE_CHECKSUM=${(l:64::c:)}
      _USB_PAYLOAD_DRIVE_CHECKSUM=$_USB_PAYLOAD_IMAGE_CHECKSUM
    }
    _usb_eject() { trace+=(eject); }

    actual=${(l:64::b:)}
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 256 "$expected" >/dev/null 2>&1
    print -r -- "mismatch:$?|${(j:,:)trace}|$_USB_RESULT_STARTED|$_USB_RESULT_ERROR"

    trace=() actual=$expected
    _usb_execute /images/linux.iso disk7 disk-fingerprint image-fingerprint \
      8388608 flash-verify "" 1 256 "$expected" >/dev/null 2>&1
    print -r -- "matched:$?|${(j:,:)trace}|$_USB_RESULT_CHECKSUM_VALIDATED|$_USB_RESULT_VERIFIED|$_USB_RESULT_DRIVE_PAYLOAD_CHECKSUM"
    _usb_result_choose() { print -r -- "summary:${(j:|:)_USB_PICKER_LABELS}"; }
    _usb_result_screen 0
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'mismatch:1|stage:Validating image and drive,image-revalidate,stage:Checking image SHA-256,image-sha:256|0|The image SHA-256 does not match' \
    'a mismatched publisher checksum reached the target or write boundary' || return
  test_assert_contains "$output" 'matched:0|' \
    'a matching publisher checksum did not complete' || return
  test_assert_contains "$output" 'image-sha:256,target-revalidate,stage:Unmounting external drive,unmount,target-revalidate,stage:Writing image,write,image-revalidate,stage:Rechecking image SHA-256,image-sha:256,stage:Verifying USB against image,payload-sha:256,stage:Ejecting external drive,eject|1|1|' \
    'the selected SHA algorithm was not reused for finished-drive payload verification' || return
  test_assert_contains "$output" "|${(l:64::c:)}" \
    'the finished-drive payload digest was not retained for the completion screen' || return
  test_assert_contains "$output" 'summary:[ Done ]|Flash complete' \
    'checksum completion did not retain the normal success summary' || return
  test_assert_contains "$output" 'Image integrity · Verified · SHA-256 matched|USB verification · Selected image bytes matched|Safe to remove' \
    'completion summary omitted checksum and finished-drive validation'
}
test_case 'USB checksum mismatch prevents writing and a match verifies the drive payload' \
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
    _usb_dd_run() {
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
    _usb_dd_run() {
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

_test_usb_dd_input_is_bounded_to_captured_sectors() {
  test_make_temp_dir || return
  local capture_root="$TEST_TMP_DIR/progress-bounded" output=''
  command mkdir -p "$capture_root" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb" || exit
    TMPDIR=$2
    _usb_progress_stage() { return 0; }
    _usb_dd_run() {
      print -r -- "args:$*"
      print -u2 -r -- "8388608 bytes transferred in 1.0 secs (8388608 bytes/sec)\r"
    }
    _usb_write_image /images/linux.iso disk7 8388608
    print -r -- "status:$?"
  ' "$TEST_REPO_ROOT" "$capture_root") || return

  test_assert_contains "$output" 'ibs=512 obs=4m count=16384' \
    'dd was allowed to read the live image path past its captured sector count' || return
  test_assert_contains "$output" 'status:0' \
    'an exact sector-bounded write did not complete'
}
test_case 'USB dd reads exactly the captured sector count' \
  _test_usb_dd_input_is_bounded_to_captured_sectors

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

  test_assert_contains "$output" 'image-race:1|image-1,target-1,unmount,target-2,write,image-2,eject|The selected image changed during writing' \
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
    _usb_result_choose() { print -r -- "labels:${(j:|:)_USB_PICKER_LABELS}"; }
    _USB_RESULT_OUTCOME=failed
    _USB_RESULT_STARTED=1 _USB_RESULT_EJECTED=1
    _USB_RESULT_ERROR="The image was written, but the finished USB could not be read completely for verification."
    _USB_RESULT_CHECKSUM_ALGORITHM=256
    _USB_RESULT_EXPECTED_CHECKSUM=${(l:64::a:)}
    _USB_RESULT_IMAGE_CHECKSUM=$_USB_RESULT_EXPECTED_CHECKSUM
    _USB_RESULT_CHECKSUM_VALIDATED=1
    _USB_RESULT_VERIFY_REASON=drive-read-failed
    _USB_RESULT_DRIVE_PAYLOAD_CHECKSUM=""
    _usb_result_screen 4

    _USB_RESULT_EXPECTED_CHECKSUM="" _USB_RESULT_IMAGE_CHECKSUM=""
    _USB_RESULT_CHECKSUM_VALIDATED=0 _USB_RESULT_VERIFY_REASON=mismatch
    _USB_RESULT_IMAGE_PAYLOAD_CHECKSUM=${(l:64::b:)}
    _USB_RESULT_DRIVE_PAYLOAD_CHECKSUM=${(l:64::c:)}
    _usb_result_screen 1
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'Image integrity · Verified · SHA-256 matched|USB verification · Could not read the finished drive' \
    'a verified image and unreadable USB were collapsed into a checksum mismatch' || return
  test_assert_contains "$output" 'Image integrity · Not verified · no checksum provided|USB verification · FAILED · confirmed byte mismatch' \
    'no-checksum image state and a true USB mismatch were not reported independently'
}
test_case 'USB result screen separates image integrity from USB fidelity' \
  _test_usb_failure_screen_separates_image_and_drive_evidence
