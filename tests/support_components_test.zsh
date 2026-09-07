# Every support component remains an ordinary independently sourceable peer.
_test_support_components_standalone() {
  test_make_temp_dir || return
  local unit='' output=''
  local -a units=("$TEST_REPO_ROOT"/.zsh.addons/support/{ui,functions}/.zsh.*(N.))
  (( ${#units} )) || { test_fail 'focused support components are absent'; return 1; }
  for unit in "${units[@]}"; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1" || exit 1
      source "$1" || exit 2
      print ready
    ' "$unit") || return
    test_assert_equal ready "$output" "standalone component emitted diagnostics: ${unit:t}" || return
  done
}
test_case 'support components source independently and repeatedly without diagnostics' \
  _test_support_components_standalone

_test_support_function_entry_points() {
  test_make_temp_dir || return
  local unit='' line='' entry='' first='' output=''
  local -a units=("$TEST_REPO_ROOT"/.zsh.addons/support/functions/.zsh.*(N.))
  (( ${#units} )) || { test_fail 'classified shared functions are absent'; return 1; }
  units+=("$TEST_REPO_ROOT"/.zsh.addons/support/ui/.zsh.ui.*(N.))
  for unit in "${units[@]}"; do
    [[ ${unit:t} == .zsh.ui.state ]] && continue
    if [[ ${unit:h:t} == functions && ${unit:t} != .zsh.(pure|impure).* ]]; then
      test_fail "shared function has no purity classification: ${unit:t}"
      return 1
    fi
    entry='' first=''
    while IFS= read -r line; do
      [[ $line == '# Entry point: '* ]] && entry=${line#\# Entry point: }
      if [[ $line == *'() {' && $line != ' '* ]]; then
        first=${line%%\(\)*}
        break
      fi
    done < "$unit"
    [[ -n $entry && $entry == "$first" && ${unit:t} == *.${entry#_} ]] || {
      test_fail "entry point must be first and match filename: ${unit:t}"
      return 1
    }
    output=$(test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1" || exit 1
      source "$1" || exit 2
      print ready
    ' "$unit") || return
    test_assert_equal ready "$output" || return
  done
}
test_case 'support function filenames classify a single first entry point' \
  _test_support_function_entry_points

_test_support_private_helper_ownership() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc" || exit 1
    zmodload zsh/parameter
    local -A entries=()
    local unit line helper caller owner pattern
    for unit in "$1"/.zsh.addons/support/{functions,ui}/.zsh.*(N.); do
      while IFS= read -r line; do
        if [[ $line == "# Entry point: "* ]]; then
          entries[$unit]=${line#\# Entry point: }
          break
        fi
      done < "$unit"
    done
    for helper in ${(k)functions}; do
      owner=${functions_source[$helper]-}
      [[ -n ${entries[$owner]-} && $helper != ${entries[$owner]} ]] || continue
      pattern="(^|[^a-zA-Z0-9_-])${helper}([^a-zA-Z0-9_-]|$)"
      for caller in ${(k)functions}; do
        [[ ${functions_source[$caller]-} == "$owner" ]] && continue
        if [[ ${functions[$caller]} =~ $pattern ]]; then
          print -u2 -r -- "$caller calls private helper $helper from another file"
          exit 2
        fi
      done
    done
    print owned
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal owned "$output"
}
test_case 'support private helpers stay inside their owning production entry' \
  _test_support_private_helper_ownership
