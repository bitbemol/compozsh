_test_git_tree_folder_summary_render() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=1
    _ZLE_PICKER_DOCUMENT_MODE=full _ZLE_PICKER_DOCUMENT_TITLE=src/file.swift
    _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    local n
    for n in {1..60}; do
      _ZLE_PICKER_DOCUMENT_LINES+=("retained file line $n")
      _ZLE_PICKER_DOCUMENT_ROLES+=(text)
    done
    _ZLE_PICKER_RESULTS=(d:src/ 1) _ZLE_PICKER_LABELS=("▾ src/" file.swift)
    _ZLE_PICKER_DOCUMENT_BRANCHES=(d:src/ 1)
    local -a summary=("Captured folder: src/" "2 changes" "No directory discovery")
    for n in {1..40}; do summary+=("folder detail $n"); done
    _ZLE_PICKER_INSPECT_TEXTS=(d:src/ "${(F)summary}" 1 ready)
    _ZLE_PICKER_ACCEPT_LABELS=(d:src/ collapse)
    _ZLE_PICKER_INSPECT_ACTION=read
    _ZLE_PICKER_BROWSE_LABEL="old file stats and syntax"
    _ZLE_PICKER_BROWSE_RENDERER=_test_folder_browse
    _test_folder_browse() {
      REPLY=$_ZLE_PICKER_BROWSE_LABEL
      [[ -n ${_ZLE_PICKER_DOCUMENT_BRANCHES[${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]}]-} ]] && REPLY="captured folder changes"
      return 0
    }
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    _zle_picker_render "" 2
    _ZLE_PICKER_INSPECT_OFFSET=10
    _zle_picker_render "" 2
    _zle_picker_render "" 1
    [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Folder summary"* &&
       ${(F)_ZLE_PICKER_DISPLAY} == *"Captured folder: src/"* &&
       ${(F)_ZLE_PICKER_DISPLAY} != *"retained file line"* &&
       $_ZLE_PICKER_DOCUMENT_OFFSETS[1] == 10 &&
       $_ZLE_PICKER_INSPECT_OFFSET == 0 &&
       $_ZLE_PICKER_DOCUMENT_VISIBLE_FIRST == 0 &&
       $_ZLE_PICKER_DOCUMENT_VISIBLE_LAST == 0 &&
       $_ZLE_PICKER_HEADER == "captured folder changes"* &&
       -z ${(j::)_ZLE_PICKER_DISPLAY_RIGHT_SYNTAX} ]] || {
      print -u2 -r -- "folder selection did not replace the reader with a captured summary"
      print -u2 -r -- "${(F)_ZLE_PICKER_DISPLAY}"
      exit 1
    }
    local width focus
    for width in 120 40; do
      COLUMNS=$width
      for focus in 0 1; do
        _ZLE_PICKER_INSPECT_FOCUS=$focus
        _zle_picker_render "" 1
        [[ ${(F)_ZLE_PICKER_DISPLAY} != *"Full file"* &&
           ${_ZLE_PICKER_DISPLAY[-1]} != *"full file"* &&
           ${_ZLE_PICKER_DISPLAY[-1]} != *"focused diff"* ]] || exit 2
        if (( focus )); then
          [[ ${(F)_ZLE_PICKER_DISPLAY} == *"Captured folder: src/"* &&
             ${_ZLE_PICKER_DISPLAY[-1]} != *⏎* ]] || exit 3
        else
          [[ ${_ZLE_PICKER_DISPLAY[-1]} == *collapse* ]] || exit 5
        fi
      done
    done
    COLUMNS=120 _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render "" 2
    [[ $_ZLE_PICKER_INSPECT_OFFSET == 10 &&
       ${(F)_ZLE_PICKER_DISPLAY} == *"retained file line 11"* ]] || exit 4
    _zle_picker_render "" 1
    _ZLE_PICKER_INSPECT_OFFSET=3
    _zle_picker_render "" 1
    _zle_picker_render "" 2
    [[ $_ZLE_PICKER_DOCUMENT_OFFSETS[d:src/] == 3 &&
       $_ZLE_PICKER_INSPECT_OFFSET == 10 ]] || exit 6
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_INSPECT_OFFSET == 3 ]] || exit 7
  ' "$TEST_REPO_ROOT"
}
test_case 'Git tree folders show captured summaries without file disclosure syntax or lost reading offsets' _test_git_tree_folder_summary_render
