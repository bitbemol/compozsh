_test_platform_review_skill_snapshot() {
  test_make_temp_dir || return
  local skill="$TEST_REPO_ROOT/.agents/skills/compozsh-platform-review"
  local script="$skill/scripts/snapshot-platform.zsh"
  local output baseline="$TEST_TMP_DIR/baseline.tsv" saved="$TEST_TMP_DIR/saved.tsv"
  local hostile="$TEST_TMP_DIR/hostile.tsv"
  [[ -f $skill/SKILL.md && -f $skill/agents/openai.yaml && -f $script ]] ||
    return 1

  output=$(/bin/zsh "$script") || return
  [[ $output == schema$'\t'1* &&
     $output == *$'\nplatform.macos.product_version\t'* &&
     $output == *$'\nplatform.terminal.version\t'* &&
     $output == *$'\nplatform.developer_tools.kind\t'* &&
     $output == *$'\nruntime.zsh.version\t'* &&
     $output == *$'\ncapability.zsh.system\t1'* &&
     $output == *$'\ncapability.zsh.stat\t1'* ]] || return 2
  [[ $output != *"${USER:-__unset_user__}"* &&
     $output != *"${HOME:-__unset_home__}"* &&
     $output != *"$(hostname)"* ]] || return 3

  print -r -- "$output" > "$baseline"
  output=$(/bin/zsh "$script" --compare "$baseline") || return
  [[ $output == 'No platform inventory changes.' ]] || return 4

  print -r -- $'tool.fixture.version\told' >> "$baseline"
  output=$(/bin/zsh "$script" --compare "$baseline") || return
  [[ $output == *'-tool.fixture.version'* &&
     $output != *"$baseline"* ]] || return 5

  print -rl -- $'schema\t1' $'tool.fake.version\t\e]0;unsafe\a' > "$hostile"
  /bin/zsh "$script" --compare "$hostile" >/dev/null 2>&1 && return 10

  output=$(/bin/zsh "$script" --output "$saved") || return
  [[ -s $saved && $output == 'Platform snapshot written.' ]] || return 6
  /bin/zsh "$script" --output "$saved" >/dev/null 2>&1 && return 7
  output=$(/bin/zsh "$script" --help) || return
  [[ $output == *'--compare'* && $output == *'--output'* &&
     $output == *'personal'* ]] || return 8
  /bin/zsh "$script" --unknown >/dev/null 2>&1 && return 9
  print verified
}
test_case 'platform review skill captures and compares a privacy-safe native inventory' \
  _test_platform_review_skill_snapshot
