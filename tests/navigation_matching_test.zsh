# Ref catalogs share the navigation ranker with branches and directory choices.
_test_navigation_matching_literals() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.matching"
    _NAVIGATION_PICKER_VALUES=(fuzzy substring prefix short)
    _NAVIGATION_PICKER_LABELS=(f-o-o aFoo FooBar f-o)
    _NAVIGATION_PICKER_INDEXES=(1 2 3 4)
    _navigation_picker_collect FOO 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == prefix,substring,fuzzy ]] || exit 1
    _navigation_picker_collect FOO 2
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == prefix,substring ]] || exit 2
    _NAVIGATION_PICKER_VALUES=(literal unicode reversed)
    _NAVIGATION_PICKER_LABELS=("a*b[c?d" "ä---Ω" "Ω---ä")
    _NAVIGATION_PICKER_INDEXES=(1 2 3)
    _navigation_picker_collect "*[?" 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == literal ]] || exit 3
    _navigation_picker_collect Äω 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == unicode ]] || exit 4
    _NAVIGATION_PICKER_SEARCH_LABELS=("hidden/x---y" "" "")
    _navigation_picker_collect xy 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == literal && $_ZLE_PICKER_LABELS[1] == "a*b[c?d" ]] || exit 5
    _NAVIGATION_PICKER_VALUES=(spaced escaped reversed)
    _NAVIGATION_PICKER_LABELS=("a path" "a path\\b*literal" "*b\\path a")
    _NAVIGATION_PICKER_INDEXES=(1 2 3) _NAVIGATION_PICKER_SEARCH_LABELS=()
    _navigation_picker_collect " \\*" 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == escaped ]] || exit 6
    _navigation_picker_collect "a h" 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == spaced,escaped ]] || exit 7
    print matched
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal matched "$output"
}
test_case 'navigation matching preserves ranks literal characters Unicode and search labels' _test_navigation_matching_literals

_test_navigation_matching_repeated_characters() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.matching"
    _NAVIGATION_PICKER_VALUES=(long repeated)
    _NAVIGATION_PICKER_LABELS=("feature/${(l:130::x:)}" "x-x-x-x-x-x-x-x-z")
    _NAVIGATION_PICKER_INDEXES=(1 2)
    # Many possible earlier character alignments must not cause backtracking.
    _navigation_picker_collect xxxxxxxxz 10
    [[ ${(j:,:)_ZLE_PICKER_RESULTS} == repeated ]] || exit 1
    _navigation_picker_collect xxxxxxxxxz 10
    (( !${#_ZLE_PICKER_RESULTS} )) || exit 2
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'navigation matching consumes repeated characters without combinatorial backtracking' _test_navigation_matching_repeated_characters

_test_navigation_matching_long_labels() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/support/.zsh.matching"
    _NAVIGATION_PICKER_VALUES=(long) _NAVIGATION_PICKER_INDEXES=(1)
    # Each label fits the ref capture byte bound. Near-end matches require
    # character-order matching rather than the earlier substring rank.
    for label in "${(l:262000::x:)}zyxz" "${(l:130000::é:)}zyxz"; do
      _NAVIGATION_PICKER_LABELS=("$label")
      _navigation_picker_collect yz 10
      [[ ${(j:,:)_ZLE_PICKER_RESULTS} == long ]] || exit 1
      _navigation_picker_collect yaz 10
      (( !${#_ZLE_PICKER_RESULTS} )) || exit 2
    done
    print long-labels
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal long-labels "$output"
}
test_case 'navigation matching scans capture-sized ASCII and Unicode labels through near-end matches' _test_navigation_matching_long_labels
