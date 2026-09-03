# Per-paint reuse must preserve focus surfaces and read fresh public overrides.
_test_ui_paint_styles_follow_current_roles() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    local painted=""
    zle() { painted=${(j:|:)region_highlight}; }
    BUFFER="" PREDISPLAY="" POSTDISPLAY="" region_highlight=()
    ZSH_HIGHLIGHT_STYLES=(
      picker-selected "fg=231,bg=24,bold"
      picker-selected-inactive "fg=16,bg=253"
      picker-row "fg=250"
      picker-architecture "fg=123,bold"
      picker-architecture-selected "fg=124,bg=99"
      picker-architecture-selected-inactive "fg=125,bg=99"
    )
    _ZLE_PICKER_DISPLAY=(arm64 arm64 arm64 arm64)
    _ZLE_PICKER_DISPLAY_STYLES=(picker-selected picker-selected-inactive picker-row picker-row)
    _ZLE_PICKER_DISPLAY_HIGHLIGHTS=(
      "0:5:picker-architecture" "0:5:picker-architecture"
      "0:5:picker-architecture" "0:5:picker-architecture"
    )
    _zle_picker_show || exit 1
    local first=$painted
    [[ $first == *"bg=24,bold,fg=124"* && $first == *"bg=253,fg=125"* &&
       $first == *"fg=123,bold"* && $first != *"bg=99"* ]] || {
      print -u2 -- "semantic labels lost their focus surface: $first"; exit 2
    }
    ZSH_HIGHLIGHT_STYLES[picker-selected]="fg=231,bg=25,bold"
    ZSH_HIGHLIGHT_STYLES[picker-architecture-selected]="fg=126"
    ZSH_HIGHLIGHT_STYLES[picker-architecture]="fg=127"
    _zle_picker_show || exit 3
    local second=$painted
    [[ $second == *"bg=25,bold,fg=126"* && $second == *"fg=127"* &&
       $second != *"fg=124"* && $second != *"fg=123"* ]] || {
      print -u2 -- "next paint retained stale semantic roles: $second"; exit 4
    }
    print fresh
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal fresh "$output"
}
test_case 'UI paint semantic styles preserve each focus surface and refresh between paints' \
  _test_ui_paint_styles_follow_current_roles
