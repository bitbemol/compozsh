# Native parsers use supplied literals independently from caller-local names.
_test_usb_shared_checksum_execution() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset"; source "$1/.zsh.addons/.zsh.usb"
    for component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_checksum_*(N.); do source "$component"; done
    local digest="" windows_seen=0 raw_seen=0
    printf -v digest "%064d" 0
    _usb_progress_stage() { :; }
    _usb_windows_source_open() { (( ++windows_seen )); return 1; }
    _usb_image_revalidate() { (( ++raw_seen )); return 1; }
    _usb_windows_execute /fixture.iso disk9 diskfp imagefp 1 flash-verify "" 1 256 "$digest" 1
    [[ $? == 1 && $windows_seen == 1 ]] || exit 1
    _usb_execute /fixture.iso disk9 diskfp imagefp 1 flash-verify "" 1 256 "$digest" 1
    [[ $? == 1 && $raw_seen == 1 ]] || exit 2
    _usb_windows_execute /fixture.iso disk9 diskfp imagefp 1 flash-verify "" 1 256 invalid 1
    [[ $? == 2 && $windows_seen == 1 ]] || exit 3
    _usb_execute /fixture.iso disk9 diskfp imagefp 1 flash-verify "" 1 512 "$digest" 1
    [[ $? == 2 && $raw_seen == 1 ]] || exit 4
    print validated
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal validated "$output"
}
test_case 'USB shared checksum validation accepts valid Windows and raw inputs before stubbed preflight' _test_usb_shared_checksum_execution

_test_usb_shared_output_parser_inputs() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    for component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_{checksum_*,crc32_output_read}(N.); do source "$component"; done
    local output=poison digest="" REPLY=""
    printf -v digest "%064d" 0
    _usb_checksum_output_read "$digest  -" 256 && [[ $REPLY == "$digest" ]] || exit 1
    _usb_crc32_output_read "123 4" 4 && [[ $REPLY == 123 ]] || exit 2
    [[ $output == poison ]] || exit 3
    unset output
    _usb_checksum_output_read "$digest  -" 256 && [[ $REPLY == "$digest" ]] || exit 4
    _usb_crc32_output_read "456 8" 8 && [[ $REPLY == 456 ]] || exit 5
    _usb_crc32_output_read "456 8" 9 && exit 6
    _usb_checksum_output_read invalid 256 && exit 7
    digest=${digest//0/A}
    _usb_checksum_output_read "$digest  -" 256 && [[ $REPLY == "${digest:l}" ]] || exit 8
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'USB shared SHA and CRC output parsers ignore absent and poisoned caller output variables' _test_usb_shared_output_parser_inputs

_test_usb_shared_checksum_validator() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.usb_checksum_validate" || exit 1
    local digest="" REPLY=""
    printf -v digest "%0128d" 0
    _usb_checksum_validate 512 "$digest" && [[ $REPLY == "$digest" ]] || exit 2
    _usb_checksum_validate 256 "$digest" && exit 3
    _usb_checksum_validate 512 "${digest[1,127]}g" && exit 4
    _usb_checksum_validate 512 "${digest[1,127]}A" && exit 5
    _usb_checksum_validate 42 "$digest" && exit 6
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'USB shared checksum validator preserves lowercase hexadecimal and exact algorithm lengths' _test_usb_shared_checksum_validator

_test_usb_shared_installer_facts() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    local root="$HOME/Install macOS Fixture.app" captures=0 stat_reads=0
    command mkdir -p "$root"
    _usb_macos_installer_fingerprint() { (( ++captures )); REPLY="1:2:111:222|3:4:5:6:7"; }
    _usb_format_epoch() { REPLY=$1; }
    TRAPDEBUG() { [[ $ZSH_DEBUG_CMD == *"command /usr/bin/stat"* ]] && (( ++stat_reads )); return 0; }
    _usb_macos_installer_add "$root" || exit 1
    unfunction TRAPDEBUG
    [[ $captures == 1 && $stat_reads == 0 &&
      $_USB_IMAGE_MODIFIED[1] == 111 && $_USB_IMAGE_CREATED[1] == 222 &&
      $_USB_IMAGE_FINGERPRINTS[1] == "1:2:111:222|3:4:5:6:7" ]] || exit 2
    print captured
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal captured "$output"
}
test_case 'USB shared installer facts reuse the fingerprint without a second stat or mismatched display dates' _test_usb_shared_installer_facts

_test_usb_shared_dd_line_parser() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.usb_dd_progress_bytes" || exit 1
    local line="" REPLY=""
    for line in "123 bytes transferred in 0.1 secs" "  123 bytes (123 B) transferred 0.1s"; do
      _usb_dd_progress_bytes "$line" && [[ $REPLY == 123 ]] || exit 2
    done
    _usb_dd_progress_bytes "0 bytes transferred" && [[ $REPLY == 0 ]] || exit 3
    for line in "12 records in" "error: 123 bytes transferred" "123 bytes copied"; do
      _usb_dd_progress_bytes "$line" && exit 4
    done
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'USB shared dd parser accepts both native byte records and rejects unrelated diagnostics' _test_usb_shared_dd_line_parser

_test_usb_shared_dd_capture_characterization() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    for component in "$1/.zsh.addons/support/functions"/.zsh.pure.usb_dd_progress_bytes(N.); do source "$component"; done
    print -r -- "123 bytes (123 B) transferred 0.1s" > "$HOME/progress"
    print -r -- "456 bytes transferred in 0.2 secs" >> "$HOME/progress"
    print -r -- "12 records in" >> "$HOME/progress"
    _usb_dd_bytes_observed "$HOME/progress" && [[ $REPLY == 456 ]] || exit 1
    print -r -- "write failed" >| "$HOME/progress"
    _usb_dd_bytes_observed "$HOME/progress" && exit 2
    print observed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal observed "$output"
}
test_case 'USB shared dd capture retains the last native byte observation and ignores other records' _test_usb_shared_dd_capture_characterization

_test_usb_shared_parser_absence() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    _usb_progress_stage() { :; }
    _usb_raw_write_session_run() { print invoked > "$HOME/write-invoked"; }
    _usb_write_image /fixture.iso disk9 512
    [[ $? != 0 && ! -e "$HOME/write-invoked" &&
      $_USB_WRITE_ERROR == *"parsing support unavailable"* ]] || exit 1
    print refused
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refused "$output"
}
test_case 'USB shared missing byte parser refuses the write before starting its native worker' _test_usb_shared_parser_absence
