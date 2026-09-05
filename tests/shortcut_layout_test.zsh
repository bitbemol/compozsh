_test_shortcut_prompt_layout() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    ZSH_PROMPT_COLORS=()
    LINES=30
    _PROMPT_INTERACTION_LABELS=() _PROMPT_INTERACTION_VALUES=()
    _PROMPT_FULL_PATH_TEXT=/fixture/project
    _PROMPT_LENS_REASON="entered a long project with 界界 context"
    local width=0 kind="" header=""
    for width in 18 24 32 40 55 56 80 120; do
      COLUMNS=$width
      for kind in ready run environment caution; do
        _PROMPT_INTERACTION_KIND=$kind
        _prompt_interaction_layout
        header=${_PROMPT_INTERACTION_SEGMENT%%$'"'"'\n'"'"'*}
        (( ${(m)#header} <= width )) || exit 1
        [[ $header != *⌥* ]] || exit 2
        if (( width >= 56 )); then
          [[ $header == *"  Option-Return inspect draft" ]] || exit 3
        else
          [[ $header != *"inspect draft"* ]] || exit 4
        fi
      done
      for _PROMPT_LENS_PINNED in 0 1; do
        _prompt_lens_layout
        header=${_PROMPT_LENS_SEGMENT%%$'"'"'\n'"'"'*}
        (( ${(m)#header} <= width )) || exit 5
        [[ $header == "╭─ CONTEXT"* && $header != *⌥* ]] || exit 6
        if (( width >= 40 )); then
          [[ $header == *"  Option-I "* ]] || exit 7
        elif (( width <= 24 )); then
          [[ $header != *Option* ]] || exit 8
        fi
      done
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'shortcut layout uses readable prompt keys without crowding narrow context headings' _test_shortcut_prompt_layout

_test_shortcut_shared_chrome() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_SCREEN_ACTIVE=1
    _ZLE_PICKER_RESULTS=(fixture) _ZLE_PICKER_SELECTED=1
    _ZLE_PICKER_INSPECT_ACTION=choose
    _ZLE_PICKER_TITLE="Tool 界界 with a long title"
    local width=0 guide=0 focus=0
    for width in 8 18 24 32 40 56 80 120; do
      _zle_picker_titlebar $width
      (( ${(m)#_ZLE_PICKER_TITLEBAR} <= width )) || exit 1
      for guide in 0 1; do
        _ZLE_PICKER_GUIDE_ACTIVE=$guide
        for focus in 0 1; do
          _ZLE_PICKER_INSPECT_FOCUS=$focus
          _zle_picker_footer $width ""
          (( ${(m)#REPLY} <= width )) || exit 2
          [[ $REPLY != *↑↓* && $REPLY != *⌥* ]] || exit 3
          if [[ $REPLY == *page* ]]; then
            [[ $REPLY == *"Fn/Option ↑/↓ page"* ]] || exit 4
          fi
          if (( width == 120 )); then
            [[ $REPLY == *"↑/↓ "* ]] || exit 5
          fi
        done
      done
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'shortcut layout keeps shared hints separated whole and within terminal columns' _test_shortcut_shared_chrome
