_test_shared_usb_result_reset() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.usb_result_reset" || exit 1
    local _USB_RESULT_OUTCOME=complete _USB_RESULT_ERROR=old _USB_RESULT_RATE=old
    local _USB_RESULT_VERIFY_REASON=old _USB_RESULT_VERIFY_SCOPE=old
    local -i _USB_RESULT_BYTES=9 _USB_RESULT_SECONDS=9 _USB_RESULT_WRITE_SECONDS=9
    local -i _USB_RESULT_VERIFY_SECONDS=9 _USB_RESULT_VERIFIED=1 _USB_RESULT_EJECTED=1
    local -i _USB_RESULT_STARTED=1 _USB_RESULT_CHECKSUM_VALIDATED=1
    local _USB_RESULT_CHECKSUM_ALGORITHM=sentinel _USB_RESULT_SOURCE_VALIDATED=sentinel
    _usb_result_reset
    [[ -z $_USB_RESULT_OUTCOME$_USB_RESULT_ERROR$_USB_RESULT_RATE$_USB_RESULT_VERIFY_REASON$_USB_RESULT_VERIFY_SCOPE ]] || exit 2
    (( _USB_RESULT_BYTES + _USB_RESULT_SECONDS + _USB_RESULT_WRITE_SECONDS + _USB_RESULT_VERIFY_SECONDS + _USB_RESULT_VERIFIED + _USB_RESULT_EJECTED + _USB_RESULT_STARTED + _USB_RESULT_CHECKSUM_VALIDATED == 0 )) || exit 3
    [[ $_USB_RESULT_CHECKSUM_ALGORITHM == sentinel && $_USB_RESULT_SOURCE_VALIDATED == sentinel ]] || exit 4
    print preserved
  ' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal preserved "$output"
}
test_case 'shared interaction result reset clears common evidence and leaves source-specific policy to callers' \
  _test_shared_usb_result_reset

_test_shared_idle_protocol() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/ui/.zsh.ui.zle_picker_loop"
    local -a reply=()
    local _ZLE_PICKER_IDLE_CALLBACK=_fixture_idle _ZLE_PICKER_IDLE_ACTION="" _ZLE_PICKER_ACTION=unchanged
    local requested="" result=77
    local -i callback_status=0
    _fixture_idle() {
      [[ $result == 77 ]] || return 99
      reply=(overwritten)
      _ZLE_PICKER_IDLE_ACTION=$requested
      return $callback_status
    }
    for callback_status in 0 1 2 3 130; do
      for requested in "" close; do
        _ZLE_PICKER_ACTION=unchanged
        _zle_picker_idle_call
        [[ $reply[1] == $callback_status ]] || exit 1
        if [[ -n $requested ]]; then
          [[ $reply[2] == 1 && $_ZLE_PICKER_ACTION == close ]] || exit 2
        else
          [[ $reply[2] == 0 && $_ZLE_PICKER_ACTION == unchanged ]] || exit 3
        fi
      done
    done
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared interaction idle callback status and explicit requests stay distinct in both phases' \
  _test_shared_idle_protocol

_test_shared_git_poll_guide_boundary() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload zsh/datetime
    local _git_review_refresh_status=before _git_auto_session_pid=123
    local _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_DOCUMENT_UPDATE_PENDING=0
    local _GIT_REVIEW_AUTO_REFRESH_INTERVAL=1 _git_auto_candidate_ready=0
    local _git_auto_next_at=123 _git_auto_checked_at=456
    local -F _git_auto_deadline_at=0 _ZLE_PICKER_IDLE_WAIT=0
    local -i _ZLE_PICKER_GUIDE_ACTIVE=0 fixture_status=1 expired=0 calls=0 failures=0 actual=0
    _git_review_auto_poll() { (( ++calls )); return $fixture_status; }
    _git_review_auto_fail() { (( ++failures )); return 0; }
    _git_review_auto_safety_adopt() { print unexpected-adoption; return 1; }
    for _ZLE_PICKER_GUIDE_ACTIVE in 0 1; do
      for fixture_status in 1 3; do
        for expired in 0 1; do
          calls=0 failures=0
          _git_auto_deadline_at=$(( EPOCHREALTIME + (expired ? -100 : 100) ))
          _git_review_auto_idle; actual=$?
          (( calls == 1 )) || exit 1
          if (( fixture_status == 1 && !expired )); then
            (( actual == 2 && failures == 0 && _ZLE_PICKER_IDLE_WAIT == 0.10 )) || exit 2
          else
            (( actual == 0 && failures == 1 )) || exit 3
          fi
        done
      done
    done
    _ZLE_PICKER_GUIDE_ACTIVE=1 fixture_status=0 _git_auto_candidate_ready=1
    _git_review_auto_idle; actual=$?
    (( actual == 2 && _git_auto_next_at == 123 && _git_auto_checked_at == 456 )) || exit 4
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared interaction Git polling preserves guide isolation waiting and failure outcomes' \
  _test_shared_git_poll_guide_boundary

_test_shared_usb_retarget_request() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    local -i fixture_status=0 actual=0
    _usb_target_choose() {
      [[ ${(j:|:)@} == "12|literal target|target|Keep current target|disk1|breadcrumb|raw-image" ]] || return 98
      _USB_DISK_IDS=(new) _USB_DISK_LABELS=(new-label) _USB_DISK_DETAILS=(new-detail)
      _USB_DISK_SIZES=(22) _USB_DISK_FINGERPRINTS=(new-fingerprint)
      return $fixture_status
    }
    for fixture_status in 0 1 130; do
      _USB_DISK_IDS=(old) _USB_DISK_LABELS=(old-label) _USB_DISK_DETAILS=(old-detail)
      _USB_DISK_SIZES=(11) _USB_DISK_FINGERPRINTS=(old-fingerprint)
      _usb_workspace_retarget 12 "literal target" target "Keep current target" disk1 breadcrumb raw-image
      actual=$?
      (( actual == fixture_status )) || exit 1
      if (( fixture_status == 1 )); then
        [[ $_USB_DISK_IDS == old && $_USB_DISK_LABELS == old-label && $_USB_DISK_DETAILS == old-detail && $_USB_DISK_SIZES == 11 && $_USB_DISK_FINGERPRINTS == old-fingerprint ]] || exit 2
      else
        [[ $_USB_DISK_IDS == new && $_USB_DISK_LABELS == new-label && $_USB_DISK_DETAILS == new-detail && $_USB_DISK_SIZES == 22 && $_USB_DISK_FINGERPRINTS == new-fingerprint ]] || exit 3
      fi
    done
    _USB_IMAGE_SIZES=(33) _USB_IMAGE_FINGERPRINTS=(image-fingerprint)
    _usb_workspace_request flash-verify 1 1 "/literal [image]" disk2 disk1 macos-installer "" "" apple-signed
    [[ $_USB_SELECTED_IMAGE == "/literal [image]" && $_USB_SELECTED_DISK == disk2 && $_USB_SELECTED_SOURCE_DISK == disk1 && $_USB_SELECTED_IMAGE_SIZE == 33 && $_USB_SELECTED_DISK_SIZE == 22 && $_USB_SELECTED_IMAGE_FINGERPRINT == image-fingerprint && $_USB_SELECTED_DISK_FINGERPRINT == new-fingerprint && $_USB_SELECTED_IMAGE_INTEGRITY == apple-signed && -z $_USB_SELECTED_CHECKSUM$_USB_SELECTED_CHECKSUM_ALGORITHM ]] || exit 4
    _usb_workspace_request flash-only 1 1 /image disk2 disk1 raw-image literal-digest 256 matched
    [[ $_USB_REQUEST == flash-only && $_USB_SELECTED_MEDIA_KIND == raw-image && $_USB_SELECTED_CHECKSUM == literal-digest && $_USB_SELECTED_CHECKSUM_ALGORITHM == 256 && $_USB_SELECTED_IMAGE_INTEGRITY == matched ]] || exit 5
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'shared interaction USB retarget restores cancellation and preserves exact accepted request data' \
  _test_shared_usb_retarget_request
