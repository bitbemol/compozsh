_test_shared_plutil_scalar() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw" || exit 1
    local REPLY=stale
    _compozsh_plutil_raw "{\"literal\":\"[value] ; text\",\"count\":12}" literal || exit 2
    [[ $REPLY == "[value] ; text" ]] || exit 3
    _compozsh_plutil_raw "{\"count\":12}" count || exit 4
    [[ $REPLY == 12 ]] || exit 5
    _compozsh_plutil_raw "{\"count\":12}" missing && exit 6
    [[ -z $REPLY ]] || exit 7
    _compozsh_plutil_raw malformed count && exit 8
    [[ -z $REPLY ]] || exit 9
    path=()
    _compozsh_plutil_raw "{\"count\":12}" count || exit 10
    [[ $REPLY == 12 ]] || exit 11
    print captured
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal captured "$output"
}
test_case 'shared native scalar extraction preserves literal data and rejects absent malformed fields' _test_shared_plutil_scalar

_test_shared_plutil_fallback() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.usb"
    local REPLY=stale
    _usb_plist_optional "{\"name\":\"captured\"}" name unavailable
    [[ $REPLY == unavailable ]] || exit 1
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    _usb_plist_optional "{\"name\":\"captured\"}" name unavailable
    [[ $REPLY == captured ]] || exit 2
    print deferred
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal deferred "$output"
}
test_case 'shared native scalar support preserves optional fallback and deferred loading' _test_shared_plutil_fallback
