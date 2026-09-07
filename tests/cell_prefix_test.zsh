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

_test_cell_prefix_reader_accent_offsets() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    local peer=""
    for peer in "$1"/.zsh.addons/support/ui/.zsh.ui.* "$1"/.zsh.addons/support/functions/.zsh.{pure,impure}.*; do source "$peer"; done
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
