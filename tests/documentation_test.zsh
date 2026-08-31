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

_test_security_contract_is_public_and_auditable() {
  local readme="$(<"$TEST_REPO_ROOT/README.md")"
  local security="$(<"$TEST_REPO_ROOT/SECURITY.md")"
  local site="$(<"$TEST_REPO_ROOT/docs/index.html")"
  local agents="$(<"$TEST_REPO_ROOT/AGENTS.md")"

  test_assert_contains "$readme" '[Security and privacy](SECURITY.md)' \
    'README does not link the security contract' || return
  test_assert_contains "$readme" 'Privacy, credential protection, data minimization' \
    'README does not expose privacy as a top-level product goal' || return
  test_assert_contains "$readme" 'never transmits user or project data under any circumstance' \
    'README does not promise local-only user data' || return
  test_assert_contains "$readme" 'User-configured synced or network-mounted storage' \
    'README hides independently controlled synchronization boundaries' || return
  test_assert_contains "$site" 'blob/main/SECURITY.md' \
    'website does not expose the security self-audit' || return
  test_assert_contains "$security" 'What the shipped project does not do' \
    'security contract omits its negative guarantees' || return
  test_assert_contains "$security" 'Privacy model' \
    'security contract omits its data-minimization model' || return
  test_assert_contains "$security" 'Non-transmission invariant' \
    'security contract omits its highest local-only invariant' || return
  test_assert_contains "$security" 'Transmission is prohibited rather' \
    'security contract permits transmission as a configurable feature' || return
  test_assert_contains "$security" 'Complete local data inventory' \
    'security contract ambiguously describes its local-only data inventory' || return
  test_assert_contains "$security" 'Compozsh creates no off-machine storage' \
    'security contract does not make its storage boundary explicit' || return
  test_assert_contains "$security" 'operating-system clipboard synchronization' \
    'security contract hides independently configured synchronization' || return
  test_assert_contains "$security" 'Administrator boundary' \
    'security contract omits the sudo boundary' || return
  test_assert_contains "$security" 'Compozsh network prohibition and external boundaries' \
    'security contract omits the network boundary' || return
  test_assert_contains "$security" 'Audit a commit before installing' \
    'security contract does not provide a self-audit workflow' || return
  test_assert_contains "$security" 'Supported versions' \
    'GitHub security policy omits its supported-version policy' || return
  test_assert_contains "$security" 'Reporting a vulnerability' \
    'security contract omits private reporting guidance' || return
  test_assert_contains "$agents" 'Before declaring any work complete' \
    'agent contract does not require a final SECURITY.md review' || return
  test_assert_contains "$agents" 'Security documentation requires full disclosure' \
    'agent contract does not require complete security disclosure' || return
  test_assert_contains "$agents" 'independently checkable against an' \
    'agent contract permits security claims without independent checks' || return
  test_assert_contains "$agents" 'Agents must never replace verifiable' \
    'agent contract permits maintainer assurances in place of evidence' || return
  test_assert_contains "$agents" 'Privacy is a top-level product goal' \
    'agent contract does not treat privacy as an implementation priority' || return
  test_assert_contains "$agents" 'Local-only operation is the highest security invariant' \
    'agent contract does not rank local-only operation first' || return
  test_assert_contains "$agents" 'There is no telemetry opt-in, consent exception' \
    'agent contract permits exceptions to non-transmission' || return
  test_assert_contains "$agents" 'never hide an' \
    'agent contract permits ambiguous always-local claims' || return
  test_assert_contains "$agents" 'New persistent storage requires an explicit' \
    'agent contract permits undocumented sensitive storage' || return
  test_assert_contains "$agents" 'No Compozsh-owned operation may transmit' \
    'agent contract permits undisclosed data transmission'
}
test_case 'security and privacy contract stays public and auditable' \
  _test_security_contract_is_public_and_auditable
