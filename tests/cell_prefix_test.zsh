_test_cell_prefix_accent_fit() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    local peer=""
    for peer in "$1"/.zsh.addons/support/functions/.zsh.pure.*; do source "$peer"; done
    local text="${(l:38::a:)}"$'"'"'e\u0301rest'"'"' expected=""
    _prompt_prefix_abbreviate "$text" 40
    expected=$REPLY
    _zle_picker_fit "$text" 40
    [[ $REPLY == "$expected" ]] || { print -r -- "accent lost: ${(qqq)REPLY}"; exit 1; }
    (( ${(m)#REPLY} == 40 )) || exit 2
    _zle_picker_fit "界界界" 4
    [[ $REPLY == "界… " ]] || exit 3
    _zle_picker_fit "100% ready" 12
    [[ $REPLY == "100% ready  " ]] || exit 4
    _prompt_prefix_abbreviate "visible prefix unseen secret tail" 8
    [[ $REPLY == "visible…" ]] || exit 5
    _zle_picker_fit "anything" 0
    [[ -z $REPLY ]] || exit 6
    _compozsh_cell_prefix "%F{red}abcdefgh" 8
    [[ $REPLY == "%F{red}a" ]] || exit 7
    _compozsh_cell_prefix $'"'"'e\u0301\u0302xyz'"'"' 1
    [[ $REPLY == $'"'"'e\u0301\u0302'"'"' && ${#REPLY} == 3 ]] || exit 8
    _compozsh_cell_prefix "界." 4
    [[ $REPLY == "界." ]] || exit 9
    print preserved
  ' "$TEST_REPO_ROOT") || { print -r -- "$output"; return 1; }
  test_assert_equal preserved "$output"
}
test_case 'cell prefix clipping preserves boundary accents, padding and literal prefix privacy' \
  _test_cell_prefix_accent_fit

_test_support_pure_cell_prefix_width() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    exec 2>&1
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    local REPLY="" width="" sentinel=7
    local -a a=(1)
    _compozsh_cell_prefix abcdef 3 || exit 1
    [[ $REPLY == abc ]] || exit 2
    _compozsh_cell_prefix "界abc" 3 || exit 3
    [[ $REPLY == "界a" ]] || exit 4
    _compozsh_cell_prefix abcdefghijkl 010 || exit 5
    [[ $REPLY == abcdefghij ]] || exit 6
    _compozsh_cell_prefix "界abc" 999999999999999999 || exit 7
    [[ $REPLY == "界abc" ]] || exit 8
    for width in 0 -1 -999999999999999999; do
      REPLY=stale
      _compozsh_cell_prefix "界abc" $width || exit 9
      [[ -z $REPLY ]] || exit 10
    done
    COLUMNS=12
    for width in "" COLUMNS "sentinel=99" "1+1" "a[\$(print -u2 substituted)1]" - \
        9223372036854775807 -9999999999999999999; do
      REPLY=stale
      _compozsh_cell_prefix "界abc" "$width"
      [[ $? == 2 && -z $REPLY ]] || { print -r -- "accepted width ${(qqq)width}: ${(qqq)REPLY}"; exit 11; }
    done
    (( sentinel == 7 )) || exit 12
    print validated
  ' "$TEST_REPO_ROOT") || { print -r -- "$output"; return 1; }
  test_assert_equal validated "$output"
}
test_case 'support pure cell prefix validates width text before integer assignment' \
  _test_support_pure_cell_prefix_width

_test_cell_prefix_reader_accent_offsets() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT_KEY=accent
    _ZLE_PICKER_DOCUMENT_LINES=($'"'"'e\u0301abcd'"'"')
    _ZLE_PICKER_DOCUMENT_ROLES=(text)
    _ZLE_PICKER_DOCUMENT_SYNTAX=(1 "0:2:picker-header 2:3:picker-command")
    _zle_picker_inspect_prepare accent 2
    [[ $_ZLE_PICKER_INSPECT_LINES[1] == $'"'"'e\u0301'"'"' && $_ZLE_PICKER_INSPECT_LINES[2] == a ]] || {
      print -r -- "split accent: ${(j:|:)_ZLE_PICKER_INSPECT_LINES}"; exit 1
    }
    [[ $_ZLE_PICKER_INSPECT_SYNTAX[1] == "0:2:picker-header " && $_ZLE_PICKER_INSPECT_SYNTAX[2] == "0:1:picker-command " ]] || exit 2
    [[ ${(j:,:)_ZLE_PICKER_INSPECT_SOURCE_LINES} == 1,1,1,1 ]] || exit 3
    [[ ${(j::)_ZLE_PICKER_INSPECT_LINES} == $_ZLE_PICKER_DOCUMENT_LINES[1] ]] || exit 4
    _ZLE_PICKER_DOCUMENT_KEY=ascii
    _ZLE_PICKER_DOCUMENT_LINES=(abcdef)
    _ZLE_PICKER_DOCUMENT_SYNTAX=()
    _zle_picker_inspect_prepare ascii 3
    [[ ${(j:|:)_ZLE_PICKER_INSPECT_LINES} == "ab|cd|ef" ]] || exit 5
    print preserved
  ' "$TEST_REPO_ROOT") || { print -r -- "$output"; return 1; }
  test_assert_equal preserved "$output"
}
test_case 'cell prefix reader wrapping preserves combining marks and source syntax offsets' \
  _test_cell_prefix_reader_accent_offsets
