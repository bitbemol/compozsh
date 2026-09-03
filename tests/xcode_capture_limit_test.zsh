_test_xcode_capture_limit_validates_before_arithmetic() {
  test_make_temp_dir || return
  local output='' error_file="$TEST_TMP_DIR/stderr"
  local -i result=0
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    export TMPDIR=$2
    local limit="" expected="" captured_status=0 audit_marker=0
    local payload=${(l:5000::x:)}
    local -a cases=(
      "" retained
      262144 retained
      000262144 retained
      9223372036854775807 retained
      9223372036854775808 retained
      9999999999999999999999999999999999999999 retained
      "1/0" retained
      "audit_marker=1" retained
      "3.14" retained
      "1+1" retained
      " 4096" retained
      0 limited
      0000000000000000000000000000000000000000 limited
      4096 limited
      0000000000000000000000000000000000004096 limited
    )
    for limit expected in "${cases[@]}"; do
      ZSH_XCODE_CAPTURE_MAX_BYTES=$limit
      _XCODE_CAPTURE=stale _XCODE_CAPTURE_ERROR=stale
      _xcode_capture_command /bin/zsh -dfc '\''print -rn -- "$1"'\'' capture "$payload"
      captured_status=$?
      (( audit_marker == 0 )) || exit 10
      if [[ $expected == retained ]]; then
        (( captured_status == 0 )) &&
          [[ $_XCODE_CAPTURE == "$payload" && -z $_XCODE_CAPTURE_ERROR ]] || exit 11
      else
        (( captured_status == 1 )) && [[ -z $_XCODE_CAPTURE &&
          $_XCODE_CAPTURE_ERROR == "output exceeded the 4096-byte capture limit" ]] || exit 12
      fi
    done
    local -a leftovers=("$2"/compozsh-xcode.*(N))
    (( ${#leftovers} == 0 )) || exit 13
    print -r -- validated
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2> "$error_file") || result=$?
  test_assert_equal '' "$(<"$error_file")" \
    'invalid Xcode capture limits emitted arithmetic diagnostics' || return
  test_assert_equal 0 "$result" 'Xcode capture-limit validation aborted' || return
  test_assert_equal validated "$output" \
    'Xcode capture limit did not preserve its default, minimum or exact output'
}
test_case 'Xcode capture validates decimal limits before arithmetic and preserves bounds' \
  _test_xcode_capture_limit_validates_before_arithmetic
