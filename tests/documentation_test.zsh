_test_readme_inventory_matches_shipped_units() {
  local file='' line='' name=''
  local -a actual=() documented=()

  for file in "$TEST_REPO_ROOT"/.zsh.addons/**/.zsh.?*(N.); do
    actual+=("${file#$TEST_REPO_ROOT/.zsh.addons/}")
  done
  while IFS= read -r line; do
    [[ $line == '| `'*'` |'* ]] || continue
    name=${line#'| `'}
    name=${name%%'` |'*}
    [[ ${name:t} == .zsh.?* ]] || continue
    documented+=("$name")
  done < "$TEST_REPO_ROOT/README.md"

  actual=(${(on)actual})
  documented=(${(on)documented})
  test_assert_equal "${(j:|:)actual}" \
    "${(j:|:)documented}" \
    'README shipped-unit inventory is stale'
}
test_case 'README inventory exactly matches the shipped peer files' \
  _test_readme_inventory_matches_shipped_units

_test_private_initializer_is_not_in_repository_tree() {
  [[ ! -e "$TEST_REPO_ROOT/.zsh.addons/local/init.zsh" ]] ||
    test_fail 'private initializer exists inside the repository add-on tree'
}
test_case 'repository never contains the private active initializer' \
  _test_private_initializer_is_not_in_repository_tree

_test_public_branding_is_consistent() {
  local file='' contents=''

  for file in README.md install.zsh templates/init.zsh \
              .zsh.addons/.zsh.highlighting; do
    contents+="$(<"$TEST_REPO_ROOT/$file")"
    contents+=$'\n'
  done

  test_assert_contains "$(<"$TEST_REPO_ROOT/README.md")" \
    '# Compozsh' 'README does not use the public project name' || return
  test_assert_contains "$(<"$TEST_REPO_ROOT/README.md")" \
    'https://github.com/bitbemol/compozsh.git' \
    'README does not use the public clone URL' || return
  [[ $contents != *my-zsh-configuration* ]] ||
    test_fail 'public files retain the previous project name'
}
test_case 'public project branding is consistent' \
  _test_public_branding_is_consistent
