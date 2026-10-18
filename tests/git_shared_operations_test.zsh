# Shared Git mechanics retain caller policies and reject unsafe override argv.
_test_shared_git_filter_overrides() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_git_filter_overrides" || exit 1
    local names=$'"'"'filter.alpha.clean\0filter.alpha.process\0filter.beta.required\0'"'"'
    local -a reply=()
    _compozsh_git_filter_overrides "$names" clean || exit 2
    (( ${#reply} == 12 )) && [[ $reply[2] == filter.alpha.clean= &&
      $reply[12] == filter.beta.required=false ]] || exit 3
    _compozsh_git_filter_overrides "$names" restore || exit 4
    (( ${#reply} == 16 )) && [[ $reply[4] == filter.alpha.smudge= ]] || exit 5
    _compozsh_git_filter_overrides $'"'"'filter.foo=bar.clean\0'"'"' clean && exit 6
    names=""
    for index in {1..682}; do names+="filter.driver${index}.clean"$'"'"'\0'"'"'; done
    _compozsh_git_filter_overrides "$names" clean || exit 7
    (( ${#reply} == 4092 )) || exit 8
    names+=$'"'"'filter.overflow.clean\0'"'"'
    _compozsh_git_filter_overrides "$names" clean && exit 9
    (( ${#reply} <= 4096 )) || exit 10
    names=""
    for index in {1..512}; do names+="filter.driver${index}.smudge"$'"'"'\0'"'"'; done
    _compozsh_git_filter_overrides "$names" restore || exit 11
    (( ${#reply} == 4096 )) || exit 12
    names+=$'"'"'filter.overflow.smudge\0'"'"'
    _compozsh_git_filter_overrides "$names" restore && exit 13
    (( ${#reply} == 4096 )) || exit 14
    print safe
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal safe "$output"
}
test_case 'shared Git filter override builder deduplicates preserves smudge policy and bounds safe argv' _test_shared_git_filter_overrides

# Pure calculation stays in memory. Zsh backs here-strings with temporary
# files; when one couldn't be created, the builder once succeeded with no
# overrides, leaving repository filters active. An unterminated final name
# (never produced by Git's --null output) is overridden too, failing safe.
_test_shared_git_filter_overrides_in_memory() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_git_filter_overrides" || exit 1
    TMPPREFIX=$2/missing/zsh
    local -a reply=()
    _compozsh_git_filter_overrides $'"'"'filter.alpha.clean\0filter.beta.required\0'"'"' clean || exit 2
    print -r -- "${(j: :)reply}"
    _compozsh_git_filter_overrides $'"'"'filter.alpha.clean\0filter.gamma.required'"'"' clean || exit 3
    print -r -- "${(j: :)reply}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" 2>&1) || return
  test_assert_equal '-c filter.alpha.clean= -c filter.alpha.process= -c filter.alpha.required=false -c filter.beta.clean= -c filter.beta.process= -c filter.beta.required=false
-c filter.alpha.clean= -c filter.alpha.process= -c filter.alpha.required=false -c filter.gamma.clean= -c filter.gamma.process= -c filter.gamma.required=false' \
    "$output" 'filter override builder lost overrides without a temporary file or dropped an unterminated name'
}
test_case 'shared Git filter override builder keeps every override without temporary files' \
  _test_shared_git_filter_overrides_in_memory

_test_shared_git_bounded_capture() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded" || exit 1
    fixture() { print -rn -- "$1"; return "$2"; }
    local -a reply=()
    local literal=$'"'"'a\0b\n\n'"'"'
    _compozsh_capture_bounded 32 fixture "$literal" 1 || exit 2
    [[ $reply[1] == "$literal" && $reply[2] == complete && $reply[3] == 1 ]] || exit 3
    _compozsh_capture_bounded 8 fixture 123456 0 || exit 4
    [[ $reply[1] == 123456 && $reply[2] == complete && $reply[3] == 0 ]] || exit 5
    _compozsh_capture_bounded 8 fixture 12345678901234567890 0 || exit 6
    [[ $reply[1] == 12345678 && $reply[2] == truncated ]] || exit 7
    _compozsh_capture_bounded 32 fixture "" 2 || exit 8
    [[ -z $reply[1] && $reply[2] == complete && $reply[3] == 2 ]] || exit 9
    _compozsh_capture_bounded 999999999999999999999 fixture "" 0 && exit 10
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'shared Git bounded capture preserves NUL newlines exit status and caller-visible truncation' _test_shared_git_bounded_capture

_test_shared_git_bounded_capture_newline_cut() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded" || exit 1
    fixture() { print -rn -- "$1"; return "$2"; }
    local -a reply=()
    _compozsh_capture_bounded 8 fixture $'"'"'12345678\nmore'"'"' 0 || exit 2
    [[ $reply[1] == 12345678 && $reply[2] == truncated && -z $reply[3] ]] || exit 3
    _compozsh_capture_bounded 8 fixture $'"'"'1234567\n\nmore'"'"' 0 || exit 4
    [[ $reply[1] == $'"'"'1234567\n'"'"' && $reply[2] == truncated && -z $reply[3] ]] || exit 5
    _compozsh_capture_bounded 8 fixture $'"'"'12345\x000\n\nhidden'"'"' 3 || exit 6
    [[ $reply[1] == $'"'"'12345\x000\n'"'"' && $reply[2] == truncated && -z $reply[3] ]] || exit 7
    _compozsh_capture_bounded 8 fixture $'"'"'12345\n'"'"' 7 || exit 8
    [[ $reply[1] == $'"'"'12345\n'"'"' && $reply[2] == complete && $reply[3] == 7 ]] || exit 9
    _compozsh_capture_bounded 8 fixture 1234. 0 || exit 10
    [[ $reply[1] == 1234. && $reply[2] == complete && $reply[3] == 0 ]] || exit 11
    _compozsh_capture_bounded 8 fixture 1234567.. 0 || exit 12
    [[ $reply[1] == 1234567. && $reply[2] == truncated && -z $reply[3] ]] || exit 13
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output" 'a truncation cut on newlines was reported as incomplete or complete'
}
test_case 'shared Git bounded capture keeps truncation when the cut lands on newlines' \
  _test_shared_git_bounded_capture_newline_cut

# Only the private trailing NUL and status leave the packet, even when the
# payload itself ends in NUL-delimited digits or glob metacharacters.
_test_shared_git_bounded_capture_status_like_tail() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded" || exit 1
    fixture() { print -rn -- "$1"; return "$2"; }
    local -a reply=()
    local payload=""
    for payload in $'"'"'a\x000'"'"' $'"'"'x\x00255'"'"' $'"'"'\x00'"'"' $'"'"'\x00\x00'"'"' \
      $'"'"'*\x00[0]?'"'"' $'"'"'1\x002\x003'"'"'; do
      _compozsh_capture_bounded 32 fixture "$payload" 0 || exit 2
      [[ $reply[1] == "$payload" && $reply[2] == complete && $reply[3] == 0 ]] || exit 3
      _compozsh_capture_bounded 32 fixture "$payload" 255 || exit 4
      [[ $reply[1] == "$payload" && $reply[2] == complete && $reply[3] == 255 ]] || exit 5
    done
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output" 'a status-like payload tail was removed with the private status'
}
test_case 'shared Git bounded capture keeps payload tails that look like its status suffix' \
  _test_shared_git_bounded_capture_status_like_tail

# Every foreground Git capture (bare-g remote refs, review status, worktree
# ls-files) splits NUL-dense packets here. Removing the status suffix must stay
# linear in the record count: 4x the records may cost only about 4x the time.
_test_shared_git_bounded_capture_linear_split() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded" || exit 1
    zmodload zsh/datetime || exit 1
    fixture() { print -rn -- "$payload"; }
    local -a reply=() best=()
    local unit="" small="" payload=""
    local -F started=0 elapsed=0 fastest=0
    local -i index=0
    for (( index = 0; index < 1000; ++index )); do
      unit+=$'"'"'refs/remotes/origin/a-name\x00'"'"'
    done
    small=$unit$unit
    for payload in "$small" "$small$small$small$small"; do
      fastest=-1
      repeat 3; do
        started=$EPOCHREALTIME
        _compozsh_capture_bounded 262144 fixture || exit 2
        elapsed=$(( EPOCHREALTIME - started ))
        [[ $reply[1] == "$payload" && $reply[2] == complete && $reply[3] == 0 ]] || exit 3
        (( fastest < 0 || elapsed < fastest )) && fastest=$elapsed
      done
      best+=($fastest)
    done
    (( ${#small} == 54000 )) && print exact
    if (( best[2] < 6 * best[1] + 0.1 )); then
      print linear
    else
      printf "superlinear %.1f ms for 2000 records, %.1f ms for 8000\n" \
        $(( best[1] * 1000 )) $(( best[2] * 1000 ))
    fi
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'exact\nlinear' "$output" \
    'splitting the status from a NUL-dense packet grew faster than the record count'
}
test_case 'shared Git bounded capture splits NUL-dense payloads in linear time' \
  _test_shared_git_bounded_capture_linear_split

_test_shared_git_operation_state() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_git_operation" || exit 1
    local root="$HOME/metadata" REPLY="" entry="" marker="" expected="" seen=""
    local -a observed=()
    command mkdir -p "$root/sequencer" "$root/rebase-merge"
    _compozsh_git_operation "$root" fail-closed
    [[ $REPLY == rebase ]] || exit 2
    : > "$root/MERGE_HEAD"
    _compozsh_git_operation "$root" fail-closed
    [[ $REPLY == merge ]] || exit 3
    command rm "$root/MERGE_HEAD"
    command rmdir "$root/rebase-merge"
    _compozsh_git_operation "$root" label
    [[ -z $REPLY ]] || exit 4
    _compozsh_git_operation "$root" fail-closed
    [[ $REPLY == cherry-pick/revert ]] || exit 5
    command rmdir "$root/sequencer"
    # Ordinary markers keep the prompt labels under both policies; the
    # bookkeeping-only and unusual-type markers refuse without a prompt label.
    for entry in MERGE_HEAD:merge:merge CHERRY_PICK_HEAD:cherry-pick:cherry-pick \
        REVERT_HEAD:revert:revert BISECT_LOG:bisect:bisect \
        rebase-merge/:rebase:rebase rebase-apply/:rebase:rebase \
        MERGE_AUTOSTASH::merge BISECT_START::bisect sequencer/::cherry-pick/revert \
        MERGE_HEAD/::merge BISECT_LOG/::bisect MERGE_HEAD@::merge rebase-merge::rebase; do
      marker=${entry%%:*} expected=${entry#*:}
      case $marker in
        */) command mkdir -- "$root/${marker%/}" ;;
        *@) command ln -s -- missing-target "$root/${marker%@}" ;;
        *) : > "$root/$marker" ;;
      esac
      _compozsh_git_operation "$root" label || exit 6
      seen=$REPLY
      _compozsh_git_operation "$root" fail-closed || exit 7
      [[ $seen:$REPLY == "$expected" ]] || observed+=("$marker=$seen:$REPLY")
      command rm -rf -- "$root/${marker%[/@]}"
    done
    (( ${#observed} )) && print -r -- "mismatch: ${observed}"
    _compozsh_git_operation "$root" fail-closed && [[ -z $REPLY ]] || exit 8
    : > "$root/MERGE_HEAD"
    _compozsh_git_operation "$root" 1 && exit 9
    [[ -z $REPLY ]] || exit 10
    _compozsh_git_operation "$root" && exit 11
    print state
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal state "$output"
}
test_case 'shared Git operation observation preserves marker precedence and label and fail-closed policies' _test_shared_git_operation_state

_test_shared_git_ambiguous_filter_consumers() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    export FILTER_PROBE="$HOME/filter-ran"
    local repo="$HOME/repository" result=0
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" config user.name Fixture
    command git -C "$repo" config user.email fixture@example.invalid
    print -r -- "file filter=foo=bar" > "$repo/.gitattributes"
    print -r -- base > "$repo/file"
    command git -C "$repo" add . || exit 2
    command git -C "$repo" -c commit.gpgsign=false commit -qm fixture || exit 3
    command git -C "$repo" config "filter.foo=bar.clean" '"'"': > "$FILTER_PROBE"; /bin/cat'"'"'
    command git -C "$repo" config "filter.foo=bar.required" true
    print -r -- changed >> "$repo/file"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.tools"
    for component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) \
      "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$component"; done
    builtin cd "$repo" || exit 4
    _prompt_git || :
    [[ ! -e $FILTER_PROBE ]] || exit 5
    _tools_git_discard_all <<< n > "$HOME/output" 2> "$HOME/error"
    result=$?
    (( result != 0 )) && [[ ! -e $FILTER_PROBE &&
      $(<"$HOME/error") == *"could not validate repository content filters"* &&
      $(<"$repo/file") == $'"'"'base\nchanged'"'"' ]] || exit 6
    print refused
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal refused "$output"
}
test_case 'shared Git safety refuses ambiguous filter drivers in prompt and discard before configured execution' _test_shared_git_ambiguous_filter_consumers

_test_shared_git_support_fallback() {
  test_make_temp_dir || return
  local output
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-worktree"
    local provider_called=0
    _git_review_git() { provider_called=1; }
    _git_worktree_git() { provider_called=1; }
    _GIT_REVIEW_DATA=stale _GWT_DATA=stale
    _git_review_capture /fixture && exit 1
    _git_worktree_capture /fixture && exit 2
    (( ! provider_called )) && [[ -z $_GIT_REVIEW_DATA && -z $_GWT_DATA &&
      $_GWT_ERROR == *"support is unavailable"* ]] || exit 3
    # Loading dependencies later makes the same already-loaded callers usable.
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded" || exit 4
    _git_review_git() { print -rn -- captured; }
    _git_worktree_git() { print -rn -- captured; }
    _git_review_capture /fixture && [[ $_GIT_REVIEW_DATA == captured ]] || exit 5
    _git_worktree_capture /fixture && [[ $_GWT_DATA == captured ]] || exit 6
    print deferred
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal deferred "$output"
}
test_case 'shared Git capture refuses missing support and resumes after deferred peer loading' _test_shared_git_support_fallback
