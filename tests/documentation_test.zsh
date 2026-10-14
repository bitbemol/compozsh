_test_readme_inventory_matches_shipped_units() {
  local file='' line='' name=''
  local -a actual=() documented=()

  for file in "$TEST_REPO_ROOT"/.zsh.addons/**/.zsh.?*(N.); do
    [[ $file == "$TEST_REPO_ROOT/.zsh.addons/support/cache/"* ]] && continue
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
test_case 'docs: README inventory exactly matches the shipped peer files' \
  _test_readme_inventory_matches_shipped_units

_test_repository_skill_inventory_is_documented() {
  local directory='' MATCH=''
  local readme="$(<"$TEST_REPO_ROOT/README.md")"
  local agents="$(<"$TEST_REPO_ROOT/CLAUDE.md")"
  local remaining=$readme
  local -a actual=() documented=() match=() mbegin=() mend=()

  for directory in "$TEST_REPO_ROOT"/.claude/skills/*(N/); do
    [[ -f $directory/SKILL.md ]] || continue
    actual+=("${directory:t}")
    test_assert_contains "$agents" ".claude/skills/${directory:t}/" \
      "agent contract omits the ${directory:t} repository skill" || return
  done
  (( ${#actual} )) || { test_fail 'no repository skills found in .claude/skills'; return 1; }
  while [[ $remaining =~ '\.claude/skills/(compozsh-[a-z0-9-]+)/' ]]; do
    documented+=("$match[1]")
    remaining=${remaining#*"$MATCH"}
  done

  actual=(${(ou)actual})
  documented=(${(ou)documented})
  test_assert_equal "${(j:|:)actual}" \
    "${(j:|:)documented}" \
    'README repository-skill inventory is stale'
}
test_case 'docs: README and agent contract inventory exactly match repository skills' \
  _test_repository_skill_inventory_is_documented

_test_private_initializer_is_not_in_repository_tree() {
  [[ ! -e "$TEST_REPO_ROOT/.zsh.addons/local/init.zsh" ]] ||
    test_fail 'private initializer exists inside the repository add-on tree'
}
test_case 'docs: repository never contains the private active initializer' \
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
test_case 'docs: public project branding is consistent' \
  _test_public_branding_is_consistent

_test_security_contract_is_public_and_auditable() {
  local readme="$(<"$TEST_REPO_ROOT/README.md")"
  local security="$(<"$TEST_REPO_ROOT/SECURITY.md")"
  local site="$(<"$TEST_REPO_ROOT/docs/index.html")"
  local agents="$(<"$TEST_REPO_ROOT/CLAUDE.md")"$'\n'"$(<"$TEST_REPO_ROOT/engineering/security.md")"

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
  test_assert_contains "$security" 'bounded Xcode test report' \
    'security contract omits Xcode diagnostic clipboard data' || return
  test_assert_contains "$readme" 'Copy report and done' \
    'README omits the Xcode result clipboard action' || return
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
test_case 'docs: security and privacy contract stays public and auditable' \
  _test_security_contract_is_public_and_auditable

# Each filter in the table is a published audit command, so deleting a test
# must not leave one that selects nothing. The runner sources every test file
# before running any case, so TEST_CASE_NAMES is complete here. Column 1 holds
# boundary labels, some of which also use code spans.
_test_security_focused_filters_select_tests() {
  local line='' cells='' remaining='' filter='' MATCH=''
  local -i in_section=0 row=0 found=0
  local -a match=() mbegin=() mend=() names=("${(@L)TEST_CASE_NAMES}") dead=()

  while IFS= read -r line; do
    if (( ! in_section )); then
      [[ $line == '### Focused regression checks' ]] && in_section=1
      continue
    fi
    [[ $line == '#'* ]] && break
    [[ $line == '| '*' |' ]] || continue
    (( ++row > 2 )) || continue
    cells=${${line#'| '}%' |'}
    [[ $cells == *' | '* ]] || {
      test_fail "focused regression row has no filter column: $line"
      return 1
    }
    remaining=${cells#*' | '}
    found=0
    while [[ $remaining =~ '`([^`]+)`' ]]; do
      filter=${match[1]:l}
      (( ${names[(I)*${(b)filter}*]} )) || dead+=("$match[1]")
      remaining=${remaining#*"$MATCH"}
      (( ++found ))
    done
    (( found )) || {
      test_fail "focused regression row lists no filter: $line"
      return 1
    }
  done < "$TEST_REPO_ROOT/SECURITY.md"

  (( row > 2 )) || {
    test_fail 'SECURITY.md has no Focused regression checks table'
    return 1
  }
  (( ! ${#dead} )) ||
    test_fail "SECURITY focused regression filters select no test: ${(j:, :)${(@qqq)dead}}"
}
test_case 'docs: every SECURITY focused regression filter selects at least one test' \
  _test_security_focused_filters_select_tests

_test_xcode_skill_export_residue_is_disclosed() {
  local security="$(<"$TEST_REPO_ROOT/SECURITY.md")"

  test_assert_contains "$security" 'Xcode skill-export staging (`compozsh-xcode-skills.*`' \
    'security inventory omits the Xcode skill-export staging directory' || return
  test_assert_contains "$security" '`${TMPDIR:-/tmp}/compozsh-xcode-skills.*` staging directory' \
    'Apple skill export omits its temporary staging name' || return
  test_assert_contains "$security" 'built in a sibling `.xcode-skill-stage.*` directory' \
    'Apple skill export omits its agent-folder staging directories' || return
  test_assert_contains "$security" 'deliberately keeps `.xcode-skill-backup.*/previous`' \
    'Apple skill export omits its retained recovery backup' || return
  test_assert_contains "$security" 'installation can leave a `.xcode-skill-stage.*` or `.xcode-skill-backup.*`' \
    'Apple skill export omits agent-folder residue after interruption' || return
  test_assert_contains "$security" 'Xcode skill staging and its agent skill-folder siblings' \
    'temporary residue list omits Xcode skill staging'
}
test_case 'docs: Xcode skill export staging and residue stay disclosed' \
  _test_xcode_skill_export_residue_is_disclosed

_test_living_prompt_contract_is_synchronized() {
  local readme="$(<"$TEST_REPO_ROOT/README.md")"
  local security="$(<"$TEST_REPO_ROOT/SECURITY.md")"
  local site="$(<"$TEST_REPO_ROOT/docs/index.html")"
  local agents="$(<"$TEST_REPO_ROOT/engineering/prompt.md")"

  test_assert_contains "$readme" '## Living prompt' \
    'README omits the living prompt behavior' || return
  test_assert_contains "$readme" 'Option-I' \
    'README omits the manual Context lens entry point' || return
  test_assert_contains "$readme" '14:26 › swift build' \
    'README omits the timestamped transcript contract' || return
  test_assert_contains "$readme" '× exit 1 · 2.3s' \
    'README omits the slow-failure outcome receipt' || return
  test_assert_contains "$readme" 'SESSION   user@host · zsh 5.9' \
    'README omits the lens-only local session identity' || return
  test_assert_contains "$readme" 'do not reopen the lens by themselves' \
    'README does not distinguish attention changes from dirty-count noise' || return
  test_assert_contains "$agents" '`compact`, `lens`, and `transcript`' \
    'agent contract omits the living prompt state model' || return
  test_assert_contains "$agents" '`compozsh-context-lens`' \
    'agent contract omits the Context lens widget boundary' || return
  test_assert_contains "$security" 'Living prompt receipts' \
    'security inventory omits terminal receipt data' || return
  test_assert_contains "$security" 'privacy or redaction boundary' \
    'security contract presents prompt compaction as redaction' || return
  test_assert_contains "$site" 'data-prompt-state="lens"' \
    'website omits the fixed Context lens example' || return
  test_assert_contains "$site" 'data-prompt-state="transcript"' \
    'website omits the fixed transcript example'
}
test_case 'docs: living prompt documentation stays synchronized across public surfaces' \
  _test_living_prompt_contract_is_synchronized

_test_public_guidance_keeps_help_derived_intent_wording() {
  local file='' text=''

  for file in README.md SECURITY.md docs/README.md docs/index.html; do
    text="$(<"$TEST_REPO_ROOT/$file")"
    [[ $text != *'An `ACTION` row is always a qualified'* &&
       $text != *'ACTION</code> always says'* &&
       ! $text =~ '`ACTION` is a lexical advisory[[:space:]]+expressed as' ]] || {
      test_fail "$file restores the superseded universal ACTION rule"
      return 1
    }
    [[ ${text:l} =~ 'help-derived|help description|documented intent' ]] || {
      test_fail "$file omits help-derived intent wording"
      return 1
    }
  done
  for file in README.md SECURITY.md .zsh.addons/.zsh.help; do
    text="$(<"$TEST_REPO_ROOT/$file")"
    [[ ${text:l} =~ 'help[[:space:]-]+description' ]] || {
      test_fail "$file omits the help-description snapshot invalidation"
      return 1
    }
  done
}
test_case 'docs: public guidance keeps help-derived intent and refresh wording' \
  _test_public_guidance_keeps_help_derived_intent_wording

# The picker copies Zsh's loaded history, so its bound is HISTSIZE (2,000 on
# stock macOS); no Compozsh code applies a fixed count of its own.
_test_history_picker_states_effective_bound() {
  local line='' paragraph=''
  local -i found=0

  while IFS= read -r line; do
    if (( found )); then
      [[ -n $line ]] || break
      paragraph+=" $line"
    elif [[ $line == 'The picker searches '* ]]; then
      found=1
      paragraph=$line
    fi
  done < "$TEST_REPO_ROOT/README.md"
  (( found )) ||
    test_fail 'README omits the history picker scope paragraph' || return
  [[ ! $paragraph =~ 'up to [0-9,]+ entries' ]] ||
    test_fail "README claims a fixed history bound: $paragraph" || return
  test_assert_contains "$paragraph" '`HISTSIZE`' \
    'README does not tie the history picker bound to HISTSIZE'
}
test_case 'docs: history picker states the effective HISTSIZE bound' \
  _test_history_picker_states_effective_bound

_test_claude_rule_paths_match_repository_files() {
  setopt EXTENDED_GLOB GLOB_DOTS
  local rule='' line='' pattern=''
  local -i in_paths=0 count=0
  local -a matches=()

  for rule in "$TEST_REPO_ROOT"/.claude/rules/*.md(N.); do
    in_paths=0
    while IFS= read -r line; do
      [[ $line == 'paths:' ]] && { in_paths=1; continue; }
      (( in_paths )) || continue
      [[ $line == '  - "'*'"' ]] || break
      pattern=${${line#'  - "'}%'"'}
      matches=("$TEST_REPO_ROOT"/${~pattern}(N))
      (( ${#matches} )) || {
        test_fail "${rule:t} path matches no repository file: $pattern"
        return 1
      }
      (( ++count ))
    done < "$rule"
  done
  (( count )) || { test_fail 'no path-scoped rules found in .claude/rules'; return 1; }
}
test_case 'docs: path-scoped Claude rules match repository files' \
  _test_claude_rule_paths_match_repository_files

_test_picker_index_affordance_is_documented() {
  local agents="$(<"$TEST_REPO_ROOT/engineering/full-screen.md")"

  test_assert_contains "$agents" \
    'visible `[n]` prefix is reserved for actionable candidates' \
    'agent contract does not reserve picker indexes for real actions' || return
  test_assert_contains "$agents" \
    'Information-only text must use passive rows' \
    'agent contract lets explanatory text masquerade as picker actions' || return
  test_assert_contains "$agents" \
    'must not enter the result/candidate array' \
    'agent contract does not separate passive text from selectable values'
}
test_case 'docs: agent UI contract reserves picker indexes for actionable rows' \
  _test_picker_index_affordance_is_documented

_test_root_guidance_is_bounded() {
  local LC_ALL=C
  local instructions="$(<"$TEST_REPO_ROOT/CLAUDE.md")"
  local -a lines=("${(@f)instructions}")
  (( ${#instructions} <= 16384 )) ||
    test_fail 'root guidance exceeds its 16 KiB budget; move detail to routed contracts' || return
  (( ${#lines} <= 200 )) ||
    test_fail "root guidance has ${#lines} lines; keep CLAUDE.md under 200 lines"
}
test_case 'docs: root agent guidance stays within its context budget' \
  _test_root_guidance_is_bounded

_test_engineering_contracts_are_discoverable() {
  local remaining="$(<"$TEST_REPO_ROOT/CLAUDE.md")"
  local MATCH='' file='' relative=''
  local -a match=() mbegin=() mend=() routed=()
  while [[ $remaining =~ '\]\((engineering/[^)#]+\.md)(#[^)]*)?\)' ]]; do
    routed+=("$match[1]")
    [[ -f "$TEST_REPO_ROOT/$match[1]" ]] || {
      test_fail "agent guidance links a missing contract: $match[1]"
      return 1
    }
    remaining=${remaining#*"$MATCH"}
  done
  (( ${#routed} )) || { test_fail 'agent guidance has no engineering routes'; return 1; }
  for file in "$TEST_REPO_ROOT"/engineering/**/*.md(N.); do
    relative=${file#"$TEST_REPO_ROOT/"}
    (( ${routed[(Ie)$relative]} )) || {
      test_fail "engineering contract has no root guidance route: $relative"
      return 1
    }
  done
}
test_case 'docs: engineering contracts remain discoverable from root agent guidance' \
  _test_engineering_contracts_are_discoverable
