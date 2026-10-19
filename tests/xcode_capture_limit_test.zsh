_test_xcode_capture_limit_validates_before_arithmetic() {
  test_make_temp_dir || return
  local output='' error_file="$TEST_TMP_DIR/stderr"
  local -i result=0
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
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

_test_xcode_capture_limit_helper_normalizes_explicit_text() {
  test_make_temp_dir || return
  local output='' error_file="$TEST_TMP_DIR/stderr"
  local -i result=0
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    (( ${+functions[_xcode_capture_limit]} )) || exit 9
    local limit="" expected="" audit_marker=0 failures=""
    local -a cases=(
      "" 262144
      262144 262144
      000262144 262144
      4097 4097
      9223372036854775807 9223372036854775807
      1000000000000000000 1000000000000000000
      9223372036854775808 262144
      9999999999999999999999999999999999999999 262144
      "1/0" 262144
      "audit_marker=1" 262144
      "3.14" 262144
      "1+1" 262144
      " 4096" 262144
      0 4096
      0000000000000000000000000000000000000000 4096
      4095 4096
      4096 4096
      0000000000000000000000000000000000004096 4096
    )
    # The helper reads only its explicit operand, whatever the caller options.
    ZSH_XCODE_CAPTURE_MAX_BYTES=audit_marker=1
    setopt KSH_ARRAYS SH_WORD_SPLIT NO_UNSET
    for limit expected in "${cases[@]}"; do
      REPLY=stale
      _xcode_capture_limit "$limit" || failures+=" status:$limit"
      [[ $REPLY == "$expected" ]] || failures+=" [$limit]=$REPLY"
    done
    (( audit_marker == 0 )) || exit 10
    [[ -z $failures ]] || { print -r -- "${failures# }"; exit 11; }
    print -r -- normalized
  ' "$TEST_REPO_ROOT" 2> "$error_file") || result=$?
  test_assert_equal '' "$(<"$error_file")" \
    'Xcode capture-limit helper emitted diagnostics' || return
  test_assert_equal 0 "$result" "Xcode capture-limit helper failed: $output" || return
  test_assert_equal normalized "$output" \
    'Xcode capture-limit helper did not return the default, minimum or exact limit'
}
test_case 'Xcode capture limit helper normalizes explicit decimal text without arithmetic' \
  _test_xcode_capture_limit_helper_normalizes_explicit_text

_test_xcode_capture_ignores_inherited_bound() {
  test_make_temp_dir || return
  local output='' error_file="$TEST_TMP_DIR/stderr" expected=''
  local -i result=0
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    # An inherited environment value arrives as an exported global. Neither a
    # smaller nor a larger one may replace the user limit of an ordinary capture.
    export _XCODE_CAPTURE_BOUND=4096
    source "$1/.zsh.addons/.zsh.xcode"
    export TMPDIR=$2
    local payload=${(l:5000::x:)} limit="" bound=""
    local -a cases=("" 4096 4096 9223372036854775807)
    for limit bound in "${cases[@]}"; do
      ZSH_XCODE_CAPTURE_MAX_BYTES=$limit _XCODE_CAPTURE_BOUND=$bound
      _XCODE_CAPTURE=stale _XCODE_CAPTURE_ERROR=stale
      _xcode_capture_command /bin/zsh -dfc '\''print -rn -- "$1"'\'' capture "$payload"
      print -r -- "${limit:-default}:$?:${#_XCODE_CAPTURE}:$_XCODE_CAPTURE_ERROR"
    done
    local -a leftovers=("$2"/compozsh-xcode.*(N))
    print -r -- "leftovers:${#leftovers}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2> "$error_file") || result=$?
  test_assert_equal '' "$(<"$error_file")" \
    'Xcode capture with an inherited bound emitted diagnostics' || return
  test_assert_equal 0 "$result" 'Xcode capture with an inherited bound aborted' || return
  expected=$'default:0:5000:\n'
  expected+=$'4096:1:0:output exceeded the 4096-byte capture limit\n'
  expected+='leftovers:0'
  test_assert_equal "$expected" "$output" \
    'an inherited _XCODE_CAPTURE_BOUND replaced the user capture limit'
}
test_case 'Xcode capture ignores an inherited capture bound and keeps the user limit' \
  _test_xcode_capture_ignores_inherited_bound

_test_xcode_build_settings_capture_bounds_targets() {
  test_make_temp_dir || return
  local output='' error_file="$TEST_TMP_DIR/stderr" expected=''
  local -i result=0
  # Xcode reports about 42 KiB of settings per target. The stub emits about
  # 40 KiB per framework target and puts the one app last, so resolution must
  # parse every index; COMPOZSH_TEST_KEYS enlarges each target instead.
  test_write_file "$TEST_TMP_DIR/bin/xcodebuild" '#!/bin/zsh -df
emulate zsh
local -i targets=${COMPOZSH_TEST_TARGETS:-1} keys=${COMPOZSH_TEST_KEYS:-500} index=0
local filler=${(l:64::x:)} products=${COMPOZSH_TEST_PRODUCTS:?} body=""
local -a settings=("\"SETTING_"{1..$keys}"\":\"$filler\"")
body=${(j:,:)settings}
print -rn -- "["
for (( index = 1; index <= targets; ++index )); do
  (( index > 1 )) && print -rn -- ","
  if (( index == targets )); then
    print -rn -- "{\"target\":\"App\",\"buildSettings\":{$body,\"WRAPPER_EXTENSION\":\"app\",\"PRODUCT_BUNDLE_IDENTIFIER\":\"com.example.app\",\"TARGET_BUILD_DIR\":\"$products\",\"FULL_PRODUCT_NAME\":\"App.app\"}}"
  else
    print -rn -- "{\"target\":\"Kit$index\",\"buildSettings\":{$body,\"WRAPPER_EXTENSION\":\"framework\",\"TARGET_BUILD_DIR\":\"$products\",\"FULL_PRODUCT_NAME\":\"Kit$index.framework\"}}"
  fi
done
print -r -- "]"' || return
  command chmod 700 "$TEST_TMP_DIR/bin/xcodebuild" || return
  command mkdir -p "$TEST_TMP_DIR/products/App.app" "$TEST_TMP_DIR/capture" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    export TMPDIR=$2/capture PATH="$2/bin:$PATH" COMPOZSH_TEST_PRODUCTS=$2/products
    export COMPOZSH_TEST_TARGETS="" COMPOZSH_TEST_KEYS=""
    local limit=""
    # Cases: user limit, targets, settings keys per target. The 4,096-byte
    # user limit cannot lower the settings bound; an 8-MiB one raises it. The
    # settings document must not outlive the call in the shared capture global.
    local -a cases=("" 7 500 "" 10 500 "" 100 500 4096 7 500 "" 140 500
      8388608 2 37000)
    for limit COMPOZSH_TEST_TARGETS COMPOZSH_TEST_KEYS in "${cases[@]}"; do
      ZSH_XCODE_CAPTURE_MAX_BYTES=$limit _XCODE_CAPTURE=""
      _xcode_build_settings_capture project /example/App.xcodeproj App macOS MAC-123
      print -r -- "$COMPOZSH_TEST_TARGETS:$?:${#_XCODE_CAPTURE}:${_XCODE_APP_PATH#$2/}:$_XCODE_BUNDLE_ID:$_XCODE_CAPTURE_ERROR"
    done
    # Every other capture keeps the ordinary user bound.
    ZSH_XCODE_CAPTURE_MAX_BYTES="" COMPOZSH_TEST_TARGETS=7 COMPOZSH_TEST_KEYS=500
    _xcode_capture_command xcodebuild -showBuildSettings -json
    print -r -- "other:$?:${#_XCODE_CAPTURE}:$_XCODE_CAPTURE_ERROR"
    local -a leftovers=("$2"/capture/*(DN))
    print -r -- "leftovers:${#leftovers}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2> "$error_file") || result=$?
  test_assert_equal '' "$(<"$error_file")" \
    'Build & Run settings capture emitted diagnostics' || return
  test_assert_equal 0 "$result" 'Build & Run settings capture aborted' || return
  expected=$'7:0:0:products/App.app:com.example.app:\n'
  expected+=$'10:0:0:products/App.app:com.example.app:\n'
  expected+=$'100:0:0:products/App.app:com.example.app:\n'
  expected+=$'7:0:0:products/App.app:com.example.app:\n'
  expected+='140:1:0:::build settings exceeded the 5242880-byte Build & Run bound'
  expected+=' (about 100 targets); choose a scheme with fewer targets or raise'
  expected+=$' ZSH_XCODE_CAPTURE_MAX_BYTES\n'
  expected+=$'2:0:0:products/App.app:com.example.app:\n'
  expected+=$'other:1:0:output exceeded the 262144-byte capture limit\n'
  expected+='leftovers:0'
  test_assert_equal "$expected" "$output" \
    'Build & Run settings did not resolve up to 100 targets within an explained bound'
}
test_case 'Xcode Build & Run resolves products for schemes up to 100 targets and explains a larger capture' \
  _test_xcode_build_settings_capture_bounds_targets
