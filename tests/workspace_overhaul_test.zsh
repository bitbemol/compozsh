# The screen is a task workspace above an anchored, real-cursor input dock.
_test_overhaul_dock() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    BUFFER="" CURSOR=0 PREDISPLAY="" POSTDISPLAY=""
    local frame="" painted_prefix="" painted_styles=""
    zle() { frame="$PREDISPLAY$BUFFER$POSTDISPLAY"; painted_prefix=$PREDISPLAY; painted_styles=${(j:|:)region_highlight}; }
    _ZLE_PICKER_RESULTS=(one two) _ZLE_PICKER_LABELS=(One Two)
    _ZLE_PICKER_INSPECT_ACTION=insert
    for _ZLE_PICKER_TITLE in History Files Branches "Tool explorer" "Xcode / Actions" "External device / Flash / Review"; do
      _zle_picker_render "literal % [x]" 1
      _zle_picker_show
      lines=("${(@f)frame}")
      [[ $lines[-2] == "$_ZLE_PICKER_QUERY_ROW" && $lines[-1] == "$_ZLE_PICKER_DISPLAY[-1]" ]] || { print -u2 -- "input is not docked: $_ZLE_PICKER_TITLE"; exit 1; }
      [[ $painted_prefix == *"literal % [x]" && -z $PREDISPLAY && -z $POSTDISPLAY && -z $BUFFER && $CURSOR == 0 ]] || exit 2
      [[ $frame == "$_ZLE_PICKER_POSTDISPLAY" && $frame != *$'\''\e'\''* ]] || exit 3
      (( ${#lines} == LINES-1 )) || exit 4
      [[ $_ZLE_PICKER_TITLEBAR == "  $_ZLE_PICKER_TITLE"* && $_ZLE_PICKER_TITLEBAR != *"Enter:"* && $_ZLE_PICKER_TITLEBAR == *COMPOZSH ]] || exit 5
    done
    _ZLE_PICKER_SCREEN_ACTIVE=0
    _zle_picker_render "inline" 1; _zle_picker_show
    [[ -z $painted_prefix && $frame == *"Search ‹inline›"* ]] || exit 6
    print dock
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal dock "$output"
}
test_case 'overhaul docks input with a real cursor across tooling while preserving inline fallback' _test_overhaul_dock

_test_overhaul_density() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    _ZLE_PICKER_VIEW_LIMIT=10 _ZLE_PICKER_DIGIT_SELECT=1
    _ZLE_PICKER_RESULTS=(item-{01..20}) _ZLE_PICKER_LABELS=(item-{01..20})
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_DISPLAY[2] == "[ 1] ▸ item-01"* && -z $_ZLE_PICKER_DISPLAY[3] && $_ZLE_PICKER_DISPLAY[4] == "[ 2]   item-02"* ]] || exit 1
    (( _ZLE_PICKER_VISIBLE_COUNT == 10 && _ZLE_PICKER_DISPLAY_INDEX_ENDS[3] == 0 && _ZLE_PICKER_DISPLAY_MATCH_STARTS[3] == -1 )) || exit 2
    _ZLE_PICKER_RESULTS=(item-01) _ZLE_PICKER_LABELS=(item-01)
    _zle_picker_render "" 1
    [[ -z $_ZLE_PICKER_DISPLAY[3] ]] || exit 3
    LINES=16 _ZLE_PICKER_RESULTS=(item-{01..20}) _ZLE_PICKER_LABELS=(item-{01..20})
    _zle_picker_render "" 1
    (( _ZLE_PICKER_VISIBLE_COUNT == 10 )) || exit 4
    [[ $_ZLE_PICKER_DISPLAY[3] == "[ 2]   item-02"* ]] || exit 5
    print density
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal density "$output"
}
test_case 'overhaul breathes between choices only when all visible slots still fit' _test_overhaul_density

_test_overhaul_action_surface() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=240 LINES=30
    _ZLE_PICKER_RESULTS=(one) _ZLE_PICKER_LABELS=(One)
    _ZLE_PICKER_INSPECT_TEXTS=(one Details)
    _ZLE_PICKER_INSPECT_ACTION=insert _ZLE_PICKER_COPY_ENABLED=1 _ZLE_PICKER_DIGIT_SELECT=1
    _zle_picker_render "" 1
    [[ $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[-1] == *picker-action* ]] || exit 1
    footer=$_ZLE_PICKER_DISPLAY[-1]
    fragments=("${(@s: · :)footer}")
    (( ${#fragments} <= 7 )) || exit 2
    [[ $footer == *"⏎ insert"* && $footer == *"Esc cancel"* && $footer == *"^K keys"* ]] || exit 3
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_picker_render "" 0
    [[ $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[-1] != *picker-action* && $_ZLE_PICKER_DISPLAY[-1] != *⏎* ]] || exit 4
    print action
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal action "$output"
}
test_case 'overhaul separates the real primary action from a bounded shortcut dock' _test_overhaul_action_surface

_test_overhaul_palette() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    ZSH_COLOR_SCHEME=dark
    source "$1/.zsh.addons/support/.zsh.appearance"
    [[ $ZSH_HIGHLIGHT_STYLES[picker-selected] == "fg=255,bg=238,bold" && $ZSH_HIGHLIGHT_STYLES[picker-surface] == "fg=252,bg=235" && $ZSH_HIGHLIGHT_STYLES[picker-title] == "fg=252,bold" ]] || exit 1
    print palette
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal palette "$output"
}
test_case 'overhaul uses neutral task surfaces with focused accents' _test_overhaul_palette
# A short navigator must not paint its former footer onto reader-only space.
_test_workspace_overhaul_reader_action() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.appearance"
    COLUMNS=120 LINES=30
    _ZLE_PICKER_SCREEN_ACTIVE=1
    _ZLE_PICKER_RESULTS=(one two) _ZLE_PICKER_LABELS=(one two)
    _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_DOCUMENT=1
    _ZLE_PICKER_INSPECT_FOCUS=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_INSPECT_TEXTS=([one]="")
    _ZLE_PICKER_DOCUMENT_LINES=(first second third fourth fifth)
    _zle_picker_render "" 1
    local -i i=0 actions=0
    for (( i=1; i<=${#_ZLE_PICKER_DISPLAY}; ++i )); do
      if [[ ${_ZLE_PICKER_DISPLAY_HIGHLIGHTS[i]} == *picker-action* ]]; then
        (( ++actions ))
        (( i == ${#_ZLE_PICKER_DISPLAY} )) || exit 1
      fi
    done
    (( actions == 1 )) || exit 2
    print clean
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal clean "$output"
}
test_case 'workspace reader keeps action emphasis exclusively in the dock' _test_workspace_overhaul_reader_action
