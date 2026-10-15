# `emulate -L zsh` does not reset IFS, so a function runs under whatever IFS
# its caller left: a newline from a line-reading loop, or empty from an
# `IFS= read`. Internally generated records and Git's fixed single-space
# headers are split on an explicit separator, so their fields never depend on
# that value. Each probe runs in a subshell under the default IFS, a newline
# and an empty IFS, and must print the same result each time.

typeset -gA _CALLER_IFS_VALUES=(default $' \t\n\0' newline $'\n' empty '')

# Runs inside the shell under test: every probe under every IFS value.
_caller_ifs_each() {
  local label='' probe=''
  for label in default newline empty; do
    for probe in "$@"; do
      print -r -- "$label: $("$probe" "$_CALLER_IFS_VALUES[$label]" 2>&1)"
    done
  done
}

# The expected output of _caller_ifs_each: the same lines under every IFS.
_caller_ifs_expected() {
  local label='' line=''
  local -a lines=()
  for label in default newline empty; do
    for line in "$@"; do lines+=("$label: $line"); done
  done
  REPLY=${(F)lines}
}

# A small captured change set, its review document and an identical
# auto-refresh candidate, set once under the default IFS.
_caller_ifs_review_fixture() {
  _GIT_REVIEW_DATA=$'@@ -1 +1 @@\n-let old = 1\n+let new = 2\n'
  _git_review_document_parse
  typeset -ga _GIT_REVIEW_PATHS=(src/a src/b README)
  typeset -ga _GIT_REVIEW_KINDS=(staged unstaged untracked)
  typeset -ga _GIT_REVIEW_LABELS=(a b README) _GIT_REVIEW_CONTEXTS=(A M '?')
  typeset -ga _GIT_REVIEW_DETAILS=(1 2 3) _GIT_REVIEW_PARENTS=('' '' '')
  typeset -ga _git_auto_candidate_paths=("${_GIT_REVIEW_PATHS[@]}")
  typeset -ga _git_auto_candidate_kinds=("${_GIT_REVIEW_KINDS[@]}")
  typeset -ga _git_auto_candidate_labels=("${_GIT_REVIEW_LABELS[@]}")
  typeset -ga _git_auto_candidate_contexts=("${_GIT_REVIEW_CONTEXTS[@]}")
  typeset -ga _git_auto_candidate_details=("${_GIT_REVIEW_DETAILS[@]}")
  typeset -ga _git_auto_candidate_parents=("${_GIT_REVIEW_PARENTS[@]}")
  typeset -g _GIT_REVIEW_SUMMARY=summary _git_auto_candidate_summary=summary
  typeset -g _GIT_REVIEW_NOTICE='' _git_auto_candidate_notice='' _git_auto_candidate_request_name=''
  typeset -ga _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _atlas_values=() _atlas_labels=()
  typeset -gA _ZLE_PICKER_DOCUMENT_BRANCHES=() _ZLE_PICKER_CONTEXTS=()
  typeset -gA _ZLE_PICKER_INSPECT_TEXTS=() _ZLE_PICKER_ACCEPT_LABELS=()
  typeset -gA _ZLE_PICKER_LABEL_PREFIXES=() _git_tree_depths=() expanded=()
  typeset -gA _atlas_details=() _atlas_groups=()
}

_caller_ifs_syntax_probe() {
  local IFS=$1
  _git_syntax_apply $'compozsh-syntax-1\n2 0 3 keyword\n3 10 11 number\ndone' ||
    print -rn -- 'rejected '
  print -r -- "syntax ${${_ZLE_PICKER_DOCUMENT_SYNTAX[2]-}% }|${${_ZLE_PICKER_DOCUMENT_SYNTAX[3]-}% }"
}

_caller_ifs_tree_probe() {
  local IFS=$1
  _git_review_tree_rows '' 0 1 2 3 || print -rn -- 'failed '
  print -r -- "tree ${(j:|:)_ZLE_PICKER_RESULTS} ${_ZLE_PICKER_CONTEXTS[d:src/]-}"
}

_caller_ifs_atlas_probe() {
  local IFS=$1
  _git_review_atlas_rows '' || print -rn -- 'failed '
  print -r -- "atlas ${(j:|:)_atlas_labels}"
}

_caller_ifs_auto_probe() {
  local IFS=$1
  _git_review_auto_candidate_changed && print -r -- 'auto changed' ||
    print -r -- 'auto unchanged'
}

_test_caller_ifs_git_review_records() {
  test_make_temp_dir || return
  local output='' REPLY=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/caller_ifs_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.git-review" || exit 2
    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$git_support_component" || exit 3; done
    source "$1/.zsh.addons/.zsh.git-syntax" || exit 4
    _caller_ifs_review_fixture
    _caller_ifs_each _caller_ifs_syntax_probe _caller_ifs_tree_probe \
      _caller_ifs_atlas_probe _caller_ifs_auto_probe
  ' "$TEST_REPO_ROOT" 2>&1) || return
  _caller_ifs_expected 'syntax 15:18:keyword|25:26:number' 'tree d:src/|1|2|3 2 changes' \
    'atlas src/ · 2 entries ▰▰▰▰▰▰▰▰▰▰▰▰|README · untracked' 'auto unchanged'
  test_assert_equal "$REPLY" "$output" 'a Git review record split depended on the caller IFS'
}
test_case 'caller IFS: Git syntax spans, review tree and atlas rows and auto-refresh comparison survive a newline or empty IFS' \
  _test_caller_ifs_git_review_records

_caller_ifs_prompt_probe() {
  local IFS=$1
  _prompt_git
  print -r -- "$_PROMPT_GIT_TEXT|$_PROMPT_GIT_UPSTREAM_TEXT"
}

_test_caller_ifs_prompt_ahead_count() {
  test_make_temp_dir || return
  local output='' REPLY=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/caller_ifs_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.prompt" || exit 2
    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$git_support_component" || exit 3; done
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    export GIT_AUTHOR_DATE=2026-01-02T03:04:05Z GIT_COMMITTER_DATE=2026-01-02T03:04:05Z
    command git init -q -b main "$HOME/repository" && builtin cd -- "$HOME/repository" || exit 4
    command git config user.name Fixture && command git config user.email fixture@example.invalid &&
      command git config commit.gpgsign false || exit 5
    print -r -- base > tracked
    command git add tracked && command git commit -qm base && command git branch base || exit 6
    print -r -- ahead >> tracked
    command git commit -qam ahead && command git branch -q -u base || exit 7
    _caller_ifs_each _caller_ifs_prompt_probe
  ' "$TEST_REPO_ROOT" 2>&1) || return
  _caller_ifs_expected 'main ⇡1|base'
  test_assert_equal "$REPLY" "$output" 'the prompt ahead count depended on the caller IFS'
}
test_case 'caller IFS: the prompt Git ahead count survives a newline or empty IFS' \
  _test_caller_ifs_prompt_ahead_count
