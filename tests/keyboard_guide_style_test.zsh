_test_keyboard_guide_semantic_styles() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_GUIDE_ACTIVE=1
    _ZLE_PICKER_RESULTS=(main) _ZLE_PICKER_LABELS=(main)
    _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_INSPECT_ACTION=read
    _ZLE_PICKER_EXCLUSION_ENABLED=1
    _ZLE_PICKER_GUIDE_CONTEXT=("Captured path with  literal spaces and 界界")
    local width index label span
    local -a fields=()
    LINES=100
    for width in 8 39 119; do
      COLUMNS=$(( width + 1 ))
      _ZLE_PICKER_GUIDE_OFFSET=0
      _zle_picker_guide_render $width
      index=${_ZLE_PICKER_DISPLAY[(I)Type *]}
      (( index )) || exit 1
      [[ $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index] == "0:4:picker-header" &&
         $_ZLE_PICKER_DISPLAY_STYLES[index] == picker-text ]] || {
        print -u2 -r -- "Keyboard labels need semantic emphasis separate from descriptions"
        exit 2
      }
      for (( index=1; index<=${#_ZLE_PICKER_DISPLAY}; ++index )); do
        (( ${(m)#_ZLE_PICKER_DISPLAY[index]} <= width )) || exit 3
        for span in ${=_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index]}; do
          fields=("${(@s.:.)span}")
          (( fields[1] >= 0 && fields[2] <= ${#_ZLE_PICKER_DISPLAY[index]} )) || exit 4
        done
      done
    done
    index=${_ZLE_PICKER_DISPLAY[(I)Control shortcuts*]}
    [[ $_ZLE_PICKER_DISPLAY_STYLES[index] == picker-muted &&
       -z $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index] ]] || exit 5
    index=${_ZLE_PICKER_DISPLAY[(I)Captured path*]}
    [[ $_ZLE_PICKER_DISPLAY_STYLES[index] == picker-text &&
       -z $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index] ]] || exit 6
    LINES=12 _ZLE_PICKER_GUIDE_OFFSET=5
    _zle_picker_guide_render 39
    [[ ${(j: :)_ZLE_PICKER_DISPLAY_HIGHLIGHTS} == *picker-header* &&
       $_ZLE_PICKER_GUIDE_OFFSET == 5 && $_ZLE_PICKER_SELECTED == 1 &&
       $_ZLE_PICKER_INDEXES_VISIBLE == 0 ]] || exit 7
    # Public palette overrides still control the actual span paint.
    ZSH_HIGHLIGHT_STYLES[picker-header]="fg=123,bold"
    local painted=""
    zle() { painted=${(j:|:)region_highlight}; }
    BUFFER="" PREDISPLAY="" POSTDISPLAY="" region_highlight=()
    _zle_picker_show
    [[ $painted == *"fg=123,bold"* ]] || exit 8
    ZSH_HIGHLIGHT_STYLES[picker-header]=bold
    _zle_picker_show
    [[ $painted != *"fg=123"* ]] || exit 9
  ' "$TEST_REPO_ROOT"
}
test_case 'keyboard guide distinguishes labels descriptions and notes with bounded semantic spans' _test_keyboard_guide_semantic_styles
