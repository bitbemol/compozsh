# Ignore-file changes must never turn unpreviewed private data into cleanup targets.
_test_discard_ignore_transition() {
  test_make_temp_dir || return
  local variant=$1 output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    source "$1/.zsh.addons/.zsh.tools"
    for component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded; do source "$component"; done
    source "$1/.zsh.addons/.zsh.navigation"
    git init -qb main "$HOME/repo" || exit 1
    cd "$HOME/repo" || exit 2
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print baseline > tracked
    mkdir -p nested/deep
    print "# baseline" > .gitignore
    git add . && git commit -qm baseline || exit 3
    case $2 in
      modified|cancelled)
        print -rl -- "private*" "nested/deep/private" >> .gitignore ;;
      staged)
        print -rl -- "private*" "nested/deep/private" >> .gitignore
        git add .gitignore || exit 4 ;;
      untracked|new-staged)
        print -r -- "private*" > nested/.gitignore
        print -r -- "private*" > nested/deep/.gitignore
        [[ $2 == new-staged ]] && git add nested/.gitignore nested/deep/.gitignore ;;
    esac
    if [[ $2 == (untracked|new-staged) ]]; then private="nested/private [literal]"
    else private="private [literal]"; fi
    print preserve > "$private"
    print preserve-deep > nested/deep/private
    print disposable > "nested/deep/remove [literal]"
    print changed > tracked
    git check-ignore -q -- "$private" && git check-ignore -q nested/deep/private || exit 5
    before=$(git status --porcelain=v1)
    answer=y
    [[ $2 == cancelled ]] && answer=n
    g --discard-all <<< "$answer" > "$HOME/output" 2> "$HOME/error"
    result=$?
    [[ -f $private && $(<"$private") == preserve &&
       -f nested/deep/private && $(<nested/deep/private) == preserve-deep ]] || {
      print -u2 "discard deleted content ignored in its preview ($2)"; exit 6
    }
    if [[ $2 == cancelled ]]; then
      [[ $result == 1 && $(git status --porcelain=v1) == "$before" &&
         $(<tracked) == changed && -f "nested/deep/remove [literal]" ]] || exit 7
    else
      [[ $result == 1 && $(<tracked) == baseline && ! -e "nested/deep/remove [literal]" &&
         $(<"$HOME/error") == *"Some changes remain"* ]] || exit 8
      git diff --quiet && git diff --cached --quiet || exit 9
    fi
    print preserved
  ' "$TEST_REPO_ROOT" "$variant") || return
  test_assert_equal preserved "$output"
}

_test_discard_modified_ignore() { _test_discard_ignore_transition modified; }
test_case 'g --discard-all preserves ignored data when restoring modified ignore rules' _test_discard_modified_ignore
_test_discard_staged_ignore() { _test_discard_ignore_transition staged; }
test_case 'g --discard-all preserves ignored data when restoring staged ignore rules' _test_discard_staged_ignore
_test_discard_new_staged_ignore() { _test_discard_ignore_transition new-staged; }
test_case 'g --discard-all preserves ignored data when removing new staged ignore files' _test_discard_new_staged_ignore
_test_discard_untracked_ignore() { _test_discard_ignore_transition untracked; }
test_case 'g --discard-all preserves ignored data when cleaning nested untracked ignore files' _test_discard_untracked_ignore
_test_discard_cancelled_ignore() { _test_discard_ignore_transition cancelled; }
test_case 'g --discard-all cancellation preserves ignore rules and all previewed data' _test_discard_cancelled_ignore

_test_discard_empty_head() {
  test_make_temp_dir || return
  local variant=$1 output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    source "$1/.zsh.addons/.zsh.tools"
    for component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded; do source "$component"; done
    source "$1/.zsh.addons/.zsh.navigation"
    git init -qb main "$HOME/repo" || exit 1
    cd "$HOME/repo" || exit 2
    git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit --allow-empty -qm baseline || exit 3
    print disposable > "untracked [literal]"
    printf -v unusual "line\nbreak"
    print disposable > "$unusual"
    print disposable > ./--force
    print disposable > ":(glob)*"
    print preserve-outside > "$HOME/outside"
    ln -s "$HOME/outside" untracked-link
    if [[ $2 == staged ]]; then
      print added > added
      git add added || exit 4
    fi
    g --discard-all <<< y > "$HOME/output" 2> "$HOME/error" || {
      print -u2 "discard failed with an empty HEAD ($2): $(<"$HOME/error")"; exit 5
    }
    [[ ! -e "untracked [literal]" && ! -e added && ! -e $unusual &&
       ! -e ./--force && ! -e ":(glob)*" && ! -L untracked-link &&
       $(<"$HOME/outside") == preserve-outside && -z $(git status --porcelain=v1) ]] || exit 6
    print discarded
  ' "$TEST_REPO_ROOT" "$variant") || return
  test_assert_equal discarded "$output"
}

_test_discard_empty_head_untracked() { _test_discard_empty_head untracked; }
test_case 'g --discard-all cleans an empty HEAD with only untracked files' _test_discard_empty_head_untracked
_test_discard_empty_head_staged() { _test_discard_empty_head staged; }
test_case 'g --discard-all cleans an empty HEAD with staged additions' _test_discard_empty_head_staged

_test_discard_index_lock() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    source "$1/.zsh.addons/.zsh.tools"
    for component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded; do source "$component"; done
    source "$1/.zsh.addons/.zsh.navigation"
    git init -qb main "$HOME/repo" || exit 1
    cd "$HOME/repo" || exit 2
    print baseline > tracked
    git add tracked && git -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm baseline || exit 3
    print changed > tracked
    print disposable > untracked
    print owned-by-another-operation > .git/index.lock
    g --discard-all <<< y > "$HOME/output" 2> "$HOME/error"
    [[ $? == 1 && $(<tracked) == changed && -f untracked &&
       $(<.git/index.lock) == owned-by-another-operation ]] || {
      print -u2 "discard removed data despite a locked index blocking restoration"; exit 4
    }
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'g --discard-all refuses a locked index before untracked cleanup' _test_discard_index_lock
