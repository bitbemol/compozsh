_test_git_tree_literal_space_labels() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_CONTEXT_MIN_WIDTH=11
    _ZLE_PICKER_DOCUMENT_KEY=1 _ZLE_PICKER_DOCUMENT_LINES=(code)
    _ZLE_PICKER_DOCUMENT_ROLES=(text)
    _ZLE_PICKER_RESULTS=(1 2 d:folder/)
    _ZLE_PICKER_LABELS=("                    meaningful.swift" "                        other.swift" "    ▸ very-long-directory-name/")
    local -A _ZLE_PICKER_LABEL_PREFIXES=(2 "    " d:folder/ "    ▸ ")
    _ZLE_PICKER_DOCUMENT_BRANCHES=(d:folder/ 1)
    _ZLE_PICKER_INSPECT_TEXTS=(1 ready 2 ready d:folder/ directory)
    _ZLE_PICKER_CONTEXTS=(1 "Unstaged M" 2 "Unstaged M" d:folder/ "12 changes")
    _ZLE_PICKER_SCREEN_ACTIVE=1 LINES=30
    local width row
    for width in 120 90 40; do
      COLUMNS=$width
      _zle_picker_render "" 1
      [[ $_ZLE_PICKER_DISPLAY[2] == *".swift"*"Unstaged M"* &&
         $_ZLE_PICKER_DISPLAY[3] == *"    "*ift*"Unstaged M"* &&
         $_ZLE_PICKER_DISPLAY[4] == *"    ▸ "* ]] || {
        print -u2 -r -- "literal filename whitespace consumed the visible name at $width columns"
        print -u2 -r -- "${(F)_ZLE_PICKER_DISPLAY}"
        exit 1
      }
      for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
        (( ${(m)#row} < width )) || exit 2
      done
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree rendering distinguishes structural prefixes from literal leading filename spaces' _test_git_tree_literal_space_labels
