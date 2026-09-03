_test_platform_snapshot_long_help() {
  test_make_temp_dir || return
  local script="$TEST_REPO_ROOT/.agents/skills/compozsh-platform-review/scripts/snapshot-platform.zsh"
  local output='' result=0
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=()
    source "$1" --help
  ' "$script" 2> "$TEST_TMP_DIR/help.err") || return
  test_assert_contains "$output" '--help' || return
  [[ ! -s "$TEST_TMP_DIR/help.err" ]] || test_fail 'snapshot help wrote stderr' || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=()
    source "$1" -h
  ' "$script" 2> "$TEST_TMP_DIR/short-help.err") || result=$?
  test_assert_equal 2 "$result" 'snapshot accepted the removed short option' || return
  test_assert_equal '' "$output" 'invalid snapshot option captured platform data' || return
  test_assert_contains "$(<"$TEST_TMP_DIR/short-help.err")" 'Usage: snapshot-platform.zsh' || return
  local -a written=("$TEST_TMP_DIR/home"/*(ND))
  test_assert_equal 0 "${#written}" 'snapshot help or invalid option wrote files'
}
test_case 'platform snapshot accepts long help and rejects short help without capture' \
  _test_platform_snapshot_long_help

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
