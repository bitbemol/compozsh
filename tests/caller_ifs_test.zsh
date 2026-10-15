# `emulate -L zsh` does not reset IFS, so a function runs under whatever IFS
# its caller left: a newline from a line-reading loop, or empty from an
# `IFS= read`. Internally generated records and Git's fixed single-space
# headers are split on an explicit separator, and text whose blanks and tabs
# must collapse is split under a local IFS, so fields never depend on that
# value. Each probe runs in a subshell under the default IFS, a newline and an
# empty IFS, and must print the same result each time; the security: scan
# keeps every other shipped split from relying on the caller's IFS.

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

# Typed queries, composer drafts, manual NAME lines and pasted checksums
# collapse blanks and tabs, so their splits run under local IFS=$' \t\n'.
_caller_ifs_history_probe() {
  local IFS=$1
  _history_search_collect '-c swift' 8
  print -r -- "history ${_HISTORY_SEARCH_RESULTS[1]-}"
}

_caller_ifs_search_seed_probe() {
  local IFS=$1
  _file_search_spotlight_seed 'ab longest c'
  print -r -- "seed $REPLY"
}

_caller_ifs_compose_probe() {
  local IFS=$1
  _compozsh_compose_seed 'g --review --merge-base main HEAD'
  print -r -- "compose $_compose_recipe $_compose_method $_compose_base $_compose_head"
}

_caller_ifs_manual_probe() {
  local IFS=$1
  _manual_summary_parse $'.Sh NAME\n.Nm sample\n.Nd Inspect output from\n.Xr other 1\n.Sh SYNOPSIS\n' ||
    print -rn -- 'declined '
  print -r -- "manual $REPLY"
}

_caller_ifs_checksum_probe() {
  local IFS=$1
  _usb_checksum_parse "SHA256 (linux.iso) = ${(l:64::a:)}" || print -rn -- 'rejected '
  print -r -- "checksum $_USB_CHECKSUM_ALGORITHM ${#REPLY}"
}

_test_caller_ifs_peer_text_splits() {
  test_make_temp_dir || return
  local output='' REPLY=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/caller_ifs_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.editor" && test_source_support "$1" || exit 2
    for peer in find compose navigation tools manual usb; do
      source "$1/.zsh.addons/.zsh.$peer" || exit 3
    done
    print -s -- "git status"
    print -s -- "swift build -c release"
    print -s -- "history visibility sentinel"
    _caller_ifs_each _caller_ifs_history_probe _caller_ifs_search_seed_probe \
      _caller_ifs_compose_probe _caller_ifs_manual_probe _caller_ifs_checksum_probe
  ' "$TEST_REPO_ROOT" 2>&1) || return
  _caller_ifs_expected 'history swift build -c release' 'seed longest' \
    'compose git-review ancestor main HEAD' 'manual Inspect output from other(1)' 'checksum 256 64'
  test_assert_equal "$REPLY" "$output" 'a typed or pasted text split depended on the caller IFS'
}
test_case 'caller IFS: history fragments, file-search fragments, composer words, manual cross-references and checksum tokens survive a newline or empty IFS' \
  _test_caller_ifs_peer_text_splits

# PAM policy lines separate fields with runs of blanks and tabs.
_caller_ifs_touch_id_probe() {
  local IFS=$1
  _sudo_touch_id_state "$TEST_PAM_DIR"
  print -rn -- "state $REPLY "
  _sudo_touch_id_enable_preflight "$TEST_PAM_DIR" 2>/dev/null && print -r -- 'preflight ok' ||
    print -r -- 'preflight refused'
}

_test_caller_ifs_touch_id_policy_reads() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output='' REPLY=''
  test_write_file "$pam_dir/sudo" \
    $'# sudo\nauth       include        sudo_local\nauth\trequired\tpam_opendirectory.so' || return
  test_write_file "$pam_dir/sudo_local.template" \
    $'# sudo_local\n#auth       sufficient     pam_tid.so' || return
  test_write_file "$pam_dir/sudo_local" $'auth\tsufficient   pam_tid.so # local note' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/caller_ifs_test.zsh" || exit 1
    source "$1/.zsh.addons/.zsh.sudo-touch-id" || exit 2
    typeset -g TEST_PAM_DIR=$2
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }
    _caller_ifs_each _caller_ifs_touch_id_probe
  ' "$TEST_REPO_ROOT" "$pam_dir" 2>&1) || return
  _caller_ifs_expected 'state enabled-external preflight ok'
  test_assert_equal "$REPLY" "$output" 'a Touch ID policy read depended on the caller IFS'
}
test_case 'caller IFS: sudo Touch ID policy reads survive a newline or empty IFS' \
  _test_caller_ifs_touch_id_policy_reads

# Tool version output and requirement files separate words with blanks.
_caller_ifs_runtime_probe() {
  local IFS=$1 language='' line=''
  for language in lua go; do
    _prompt_runtime_version "$language" "$TEST_PROJECT"
    line+="$language=$REPLY "
  done
  for language in node ruby go; do
    _prompt_expected_runtime_version "$language" "$TEST_PROJECT"
    line+="$language>$REPLY "
  done
  print -r -- "runtime ${line% }"
}

_test_caller_ifs_runtime_versions() {
  test_make_temp_dir || return
  local output='' REPLY=''
  test_write_file "$TEST_TMP_DIR/bin/luajit" $'#!/bin/sh\nprintf "LuaJIT 2.1.0 -- fixture\\n"' || return
  test_write_file "$TEST_TMP_DIR/bin/go" $'#!/bin/sh\nprintf "go version go1.22.3 darwin/arm64\\n"' || return
  command chmod +x "$TEST_TMP_DIR/bin/luajit" "$TEST_TMP_DIR/bin/go" || return
  test_write_file "$TEST_TMP_DIR/project/.node-version" '20.11.0' || return
  test_write_file "$TEST_TMP_DIR/project/.tool-versions" $'ruby\t3.3.0' || return
  test_write_file "$TEST_TMP_DIR/project/go.mod" $'module example\n\ngo  1.22' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/support.zsh" && source "$1/tests/caller_ifs_test.zsh" || exit 1
    path=("$2/bin" /usr/bin /bin)
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do
      source "$support_component" || exit 2
    done
    typeset -g TEST_PROJECT="$2/project"
    _caller_ifs_each _caller_ifs_runtime_probe
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2>&1) || return
  _caller_ifs_expected 'runtime lua=luajit 2.1.0 go=1.22.3 node>20.11.0 ruby>3.3.0 go>1.22'
  test_assert_equal "$REPLY" "$output" 'a runtime version split depended on the caller IFS'
}
test_case 'caller IFS: runtime versions and requirements survive a newline or empty IFS' \
  _test_caller_ifs_runtime_versions
