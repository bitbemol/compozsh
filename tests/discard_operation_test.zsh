# Native --no-commit conflicts can retain a sequencer without CHERRY_PICK_HEAD.
_test_discard_sequencer_guard() {
  test_make_temp_dir || return
  local phase=$1 output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    local repo="$HOME/repository" first="" second="" before="" after=""
    command git init -qb main "$repo" || exit 1
    command git -C "$repo" config user.name Fixture
    command git -C "$repo" config user.email fixture@example.invalid
    command git -C "$repo" config commit.gpgsign false
    print base > "$repo/tracked"
    command git -C "$repo" add tracked && command git -C "$repo" commit -qm base || exit 2
    command git -C "$repo" switch -qc source || exit 3
    print source >| "$repo/tracked"
    command git -C "$repo" commit -qam source || exit 4
    first=$(command git -C "$repo" rev-parse HEAD)
    print extra > "$repo/extra"
    command git -C "$repo" add extra && command git -C "$repo" commit -qm extra || exit 5
    second=$(command git -C "$repo" rev-parse HEAD)
    command git -C "$repo" switch -q main || exit 6
    print target >| "$repo/tracked"
    command git -C "$repo" commit -qam target || exit 7
    command git -C "$repo" cherry-pick --no-commit "$first" "$second" > "$HOME/pick" 2>&1
    [[ $? != 0 && -d "$repo/.git/sequencer" && ! -e "$repo/.git/CHERRY_PICK_HEAD" ]] || exit 8
    print preserve > "$repo/untracked"
    builtin cd "$repo" || exit 9
    before=$(command git status --porcelain=v1)
    command cp tracked "$HOME/tracked-before"
    command cp .git/index "$HOME/index-before"
    if [[ $2 == confirmation ]]; then
      command mv .git/sequencer "$HOME/paused-sequencer"
      read() {
        if [[ $* == *"answer?"* ]]; then
          command mv "$HOME/paused-sequencer" .git/sequencer || return
        fi
        builtin read "$@"
      }
    else
      read() {
        [[ $* == *"answer?"* ]] && print prompted > "$HOME/prompted"
        builtin read "$@"
      }
    fi
    g --discard-all <<< y > "$HOME/output" 2> "$HOME/error"
    local -i result=$?
    after=$(command git status --porcelain=v1)
    (( result != 0 )) && [[ $before == "$after" && -d .git/sequencer && -f untracked ]] &&
      command cmp -s tracked "$HOME/tracked-before" &&
      command cmp -s .git/index "$HOME/index-before" || {
      print -u2 -- "discard modified an active no-commit cherry-pick or reported success"
      exit 10
    }
    if [[ $2 == confirmation ]]; then
      [[ $(<"$HOME/error") == *"state changed after the preview"* ]] || exit 11
    else
      [[ ! -e "$HOME/prompted" && $(<"$HOME/error") == *"refusing during an active"* ]] || exit 12
    fi
    print preserved
  ' "$TEST_REPO_ROOT" "$phase") || return
  test_assert_equal preserved "$output"
}

_test_discard_existing_sequencer() { _test_discard_sequencer_guard entry; }
test_case 'g --discard-all refuses native no-commit cherry-pick sequencers before preview' \
  _test_discard_existing_sequencer

_test_discard_late_sequencer() { _test_discard_sequencer_guard confirmation; }
test_case 'g --discard-all revalidates sequencer state after confirmation without changing conflicted data' \
  _test_discard_late_sequencer
