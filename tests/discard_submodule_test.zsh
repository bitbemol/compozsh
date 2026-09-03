# Native cleanup must retain child working-tree contents even with recursion on.
_test_discard_preserves_submodule_edits() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.tools"
    local parent="$HOME/parent" child="$HOME/parent/child" repo=""
    command mkdir -p "$child"
    for repo in "$parent" "$child"; do
      command git -C "$repo" init -qb main || exit 1
      command git -C "$repo" config user.name Fixture
      command git -C "$repo" config user.email fixture@example.invalid
      command git -C "$repo" config commit.gpgsign false
      print -r -- baseline > "$repo/tracked"
    done
    command git -C "$child" add tracked && command git -C "$child" commit -qm baseline || exit 2
    print -rl -- "[submodule \"child\"]" $'\''\tpath = child'\'' $'\''\turl = ./child'\'' > "$parent/.gitmodules"
    command git -C "$parent" add tracked .gitmodules
    command git -C "$parent" update-index --add --cacheinfo 160000 "$(command git -C "$child" rev-parse HEAD)" child
    command git -C "$parent" commit -qm baseline || exit 3
    command git -C "$parent" config submodule.child.url ./child
    command git -C "$parent" config submodule.child.active true
    command git -C "$parent" submodule absorbgitdirs child 2>/dev/null || exit 4
    command git -C "$parent" config submodule.recurse true
    print -r -- parent-edit > "$parent/tracked"
    print -r -- child-edit > "$child/tracked"
    print -r -- preserve > "$child/untracked"
    builtin cd "$parent"
    git-discard-all <<< y > "$HOME/output" 2> "$HOME/error"
    local -i result=$?
    [[ $(<child/tracked) == child-edit && $(<child/untracked) == preserve ]] || {
      print -u2 -- "git-discard-all changed submodule contents when recursion was configured"; exit 5
    }
    [[ $(<tracked) == baseline && $result == 1 &&
       $(<"$HOME/error") == *"Some changes remain"* &&
       $(command git config submodule.recurse) == true ]] || exit 6
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'git-discard-all preserves dirty submodule contents when Git recursion is configured' \
  _test_discard_preserves_submodule_edits
