# Palette quality gates use actual public roles and renderer-composed styles.
# Reference surfaces model black / #1c1c1c and white / #f5f5f5, not every profile.

_test_appearance_palette_readable_text() {
  test_make_temp_dir || return
  local scheme='' output=''
  for scheme in dark light; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$scheme" $'
      source "$1/tests/appearance_support.zsh"
      ZSH_COLOR_SCHEME=$2
      source "$1/.zsh.addons/support/.zsh.appearance"
      source "$1/.zsh.addons/.zsh.highlighting"
      source "$1/.zsh.addons/.zsh.prompt"
      source "$1/.zsh.addons/.zsh.output"
      local -a backgrounds=(16 234)
      [[ $2 == light ]] && backgrounds=(231 245,245,245)
      local role="" background="" style="" minimum=4.5
      for background in "${backgrounds[@]}"; do
        for role in ${(k)ZSH_HIGHLIGHT_STYLES}; do
          # Explicit surfaces and composited metadata are checked below.
          [[ $role == review-* || $role == *-selected* ||
             $role == picker-query ]] && continue
          minimum=4.5
          [[ $role == argument || $role == picker-text ]] && minimum=7
          _test_palette_assert_style "$2 highlight:$role" "${ZSH_HIGHLIGHT_STYLES[$role]}" "$background" "$minimum" || exit 1
        done
        for role in ${(k)ZSH_PROMPT_COLORS}; do
          _test_palette_assert_style "$2 prompt:$role" "fg=${ZSH_PROMPT_COLORS[$role]}" "$background" || exit 2
        done
        for role in ${(k)ZSH_OUTPUT_COLORS}; do
          minimum=4.5
          [[ $role == text ]] && minimum=7
          _test_palette_assert_style "$2 output:$role" "fg=${ZSH_OUTPUT_COLORS[$role]}" "$background" "$minimum" || exit 3
        done
      done
      print -r -- readable-text
    ' "$TEST_REPO_ROOT" "$scheme") || return
    test_assert_equal readable-text "$output" || return
  done
}
test_case 'appearance palette meaningful text contrasts on reference dark and light surfaces' \
  _test_appearance_palette_readable_text

_test_appearance_palette_composed_surfaces() {
  test_make_temp_dir || return
  local scheme='' output=''
  for scheme in dark light; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$scheme" $'
      source "$1/tests/appearance_support.zsh"
      ZSH_COLOR_SCHEME=$2
      source "$1/.zsh.addons/support/.zsh.appearance"
      source "$1/.zsh.addons/.zsh.highlighting"
      source "$1/.zsh.addons/.zsh.editor"
      source "$1/.zsh.addons/support/.zsh.ui"
      local -a backgrounds=(16 234) attributes=()
      [[ $2 == light ]] && backgrounds=(231 245,245,245)
      local role="" background="" row="" style="" token="" attribute=""
      local -i selected=0
      for role in picker-selected picker-selected-inactive picker-query; do
        _zle_picker_style "$role"
        _test_palette_assert_style "$2 $role" "$REPLY" 16 7 || exit 1
      done
      for selected in 1 2; do
        role=picker-selected
        (( selected == 2 )) && role=picker-selected-inactive
        _zle_picker_style "$role"
        row=$REPLY
        for role in picker-architecture picker-size picker-error picker-success; do
          _zle_picker_label_highlight_style "$role" "$selected" "$row"
          _test_palette_assert_style "$2 selected:$selected:$role" "$REPLY" 16 || exit 2
        done
      done
      for role in added removed; do
        _zle_picker_review_style "$role"
        row=$REPLY
        _test_palette_assert_style "$2 review:$role" "$row" 16 7 || exit 3
        attributes=("${(@s:,:)row}")
        attributes=("${(@)attributes:#fg=*}")
        for token in keyword string number comment type function variable; do
          _zle_picker_review_style "$token"
          # Same background-preserving composition as the document painter.
          style="${(j:,:)attributes},$REPLY"
          _test_palette_assert_style "$2 review:$role:$token" "$style" 16 || exit 4
        done
      done
      for background in "${backgrounds[@]}"; do
        for token in keyword string number comment type function variable; do
          _zle_picker_review_style "$token"
          _test_palette_assert_style "$2 review:context:$token" "$REPLY" "$background" || exit 5
        done
      done
      print -r -- readable-surfaces
    ' "$TEST_REPO_ROOT" "$scheme") || return
    test_assert_equal readable-surfaces "$output" || return
  done
}
test_case 'appearance palette composed selection and review surfaces preserve readable text' \
  _test_appearance_palette_composed_surfaces

_test_appearance_palette_completion_surfaces() {
  test_make_temp_dir || return
  local scheme='' output=''
  for scheme in dark light; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$scheme" $'
      source "$1/tests/appearance_support.zsh"
      ZSH_COLOR_SCHEME=$2
      source "$1/.zsh.addons/support/.zsh.appearance"
      source "$1/.zsh.addons/.zsh.editor"
      source "$1/.zsh.addons/support/.zsh.ui"
      local -a backgrounds=(16 234) colors=() fields=()
      [[ $2 == light ]] && backgrounds=(231 245,245,245)
      zstyle -a ":completion:*" list-colors colors
      local color="" role="" style="" background="" value="" minimum=4.5
      local -i index=0 count=0
      for color in "${colors[@]}"; do
        role=${color%%=*} value=${color#*=}
        fields=("${(@s:;:)value}")
        style="" minimum=4.5
        for (( index = 1; index <= ${#fields}; ++index )); do
          case ${fields[index]} in
            (38|48)
              [[ ${fields[index+1]} == 5 && ${fields[index+2]} == <16-255> ]] || exit 1
              [[ ${fields[index]} == 38 ]] && style+="fg=${fields[index+2]}," || {
                style+="bg=${fields[index+2]},"
                minimum=7
              }
              (( index += 2 ))
              ;;
          esac
        done
        [[ $style == *fg=* ]] || exit 2
        for background in "${backgrounds[@]}"; do
          _test_palette_assert_style "$2 completion:$role" "$style" "$background" "$minimum" || exit 3
        done
        (( ++count ))
      done
      (( count >= 15 )) || exit 4
      print -r -- readable-completion
    ' "$TEST_REPO_ROOT" "$scheme") || return
    test_assert_equal readable-completion "$output" || return
  done
}
test_case 'appearance palette completion file names contrast on plain and highlighted surfaces' \
  _test_appearance_palette_completion_surfaces
