_test_xcode_log_format_compact_records() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    (( ${+functions[_xcode_logs_format_line]} )) || { print -u2 "missing compact log formatter"; exit 1; }
    local -a reply=()
    local level="" label="" role="" raw=""
    for level label role in Df Default info Db Debug muted In Info info Er Error error Ft Fault error; do
      raw="2026-09-03 14:07:08.123 $level Example App[4312:aB90] [com.example.app:network]  exact message %F{red} [*]"
      _xcode_logs_format_line "$raw" || exit 2
      [[ $REPLY == "$label" && ${#reply} == 4 &&
         ${reply[1]} == "14:07:08.123 · $label · com.example.app:network" &&
         ${reply[2]} == " exact message %F{red} [*]" &&
         ${(j:,:)reply[3,4]} == "$role,text" ]] || {
        print -u2 "incorrect compact $level presentation"; exit 3
      }
    done
    _xcode_logs_format_line "2026-09-03 14:07:08.123456 In Example[12:ab] body without scope"
    [[ $REPLY == Info && ${reply[1]} == "14:07:08.123 · Info · Example" &&
       ${reply[2]} == "body without scope" ]] || exit 4
    _xcode_logs_format_line "2026-09-03 14:07:08 Db Example[12:ab]"
    [[ $REPLY == Debug && ${#reply} == 4 &&
       ${reply[1]} == "14:07:08 · Debug · Example" &&
       -z ${reply[2]} && ${(j:,:)reply[3,4]} == "muted,text" ]] || exit 5
    print compact
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal compact "$output"
}
test_case 'Xcode log formatting separates native metadata from exact message bodies' _test_xcode_log_format_compact_records

_test_xcode_log_format_literal_fallback() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    cd -- "$HOME" || exit 1
    (( ${+functions[_xcode_logs_format_line]} )) || { print -u2 "missing compact log formatter"; exit 1; }
    local -a reply=()
    local raw=""
    local -a fixtures=("" "Error: plain stdout stays plain" "  a multiline continuation"
      "2026-09-03 14:07:08.123 Wn Example[12:ab] unknown level"
      "2026-09-03 14:07:08.123 In Example[not-a-pid:ab] malformed"
      $'\''literal %(text) [*] $(touch formatter-executed)\t\e]52;c;no\a'\'')
    for raw in "${fixtures[@]}"; do
      _xcode_logs_format_line "$raw" || exit 2
      [[ -z $REPLY && ${#reply} == 2 && ${reply[1]} == "$raw" &&
         ${reply[2]} == text ]] || { print -u2 "changed literal stdout"; exit 3; }
    done
    _xcode_logs_format_line "2026-09-03 14:07:08.123 Er Example[12:ab] [ordinary bracket] message"
    [[ $REPLY == Error && ${reply[1]} == "14:07:08.123 · Error · Example" &&
       ${reply[2]} == "[ordinary bracket] message" ]] || exit 4
    _xcode_logs_format_line "2026-09-03 14:07:08.123 In Example[12:ab] message Other[98:ff] tail"
    [[ ${reply[1]} == "14:07:08.123 · Info · Example" &&
       ${reply[2]} == "message Other[98:ff] tail" ]] || exit 5
    [[ ! -e formatter-executed ]] || exit 6
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'Xcode log formatting preserves stdout continuations and hostile text without severity guesses' _test_xcode_log_format_literal_fallback

_test_xcode_log_format_scoped_results() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    (( ${+functions[_xcode_logs_format_line]} )) || { print -u2 "missing compact log formatter"; exit 1; }
    local -a reply=() _xcode_logs_format_lines=(caller) _xcode_logs_format_roles=(caller)
    local MATCH=caller
    local -a match=(caller) mbegin=(3) mend=(7)
    local -i MBEGIN=3 MEND=7
    _xcode_capture_command() { print -u2 "unexpected provider"; return 99; }
    _xcode_logs_format_line "2026-09-03 14:07:08.123 Ft Example[12:ab] [com.example:storage] literal body"
    [[ $MATCH == caller && ${(j:,:)match} == caller && $MBEGIN == 3 && $MEND == 7 &&
       ${(j:,:)mbegin} == 3 && ${(j:,:)mend} == 7 ]] || exit 2
    # Results leave only through REPLY and reply.
    [[ $REPLY == Fault && ${#reply} == 4 && $_xcode_logs_format_lines == caller &&
       $_xcode_logs_format_roles == caller ]] || { print -u2 "results escaped REPLY and reply"; exit 4; }
    _xcode_logs_format_line "${(l:32768::x:)}"
    [[ -z $REPLY && ${#reply[1]} == 32768 && ${#reply} == 2 && ${reply[2]} == text ]] || exit 3
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'Xcode log formatter keeps matching state local and handles the retained line bound' _test_xcode_log_format_scoped_results
