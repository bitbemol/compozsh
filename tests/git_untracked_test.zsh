_test_git_untracked_nested_discovery() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo" "$HOME/outside"
    cd "$HOME/repo"
    git init -qb main
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    git config status.showUntrackedFiles no
    print -rl -- ignored/ "*.secret" > .gitignore
    git add .gitignore && git commit -qm fixture
    local index_before=$(git hash-object --no-filters .git/index)
    local config_before=$(git hash-object --no-filters .git/config)
    local name=$'\''new dir/inner/note*[x]\n.swift'\''
    mkdir -p "${name:h}" "new dir/.hidden" ignored
    print -r -- "let greeting = 42" > "$name"
    print -r -- second > "new dir/another.swift"
    print -r -- hidden > "new dir/.hidden/value"
    print -r -- excluded > "new dir/private.secret"
    print -r -- excluded > ignored/file
    print -r -- outside > "$HOME/outside/sentinel"
    ln -s "$HOME/outside" "new dir/link"
    _git_review_prepare "$PWD" || exit 1
    _git_review_changes_capture "$PWD" || exit 2
    local selected=${_GIT_REVIEW_PATHS[(Ie)$name]}
    (( selected > 0 && ${#_GIT_REVIEW_PATHS} == 4 )) || {
      print -u2 "new-directory files must be individually selectable"; exit 3
    }
    [[ $_GIT_REVIEW_KINDS[selected] == untracked &&
       $_GIT_REVIEW_CONTEXTS[selected] == "Untracked · new dir/inner/" ]] || exit 4
    [[ ${_GIT_REVIEW_PATHS[(Ie)new dir/.hidden/value]} -gt 0 &&
       ${_GIT_REVIEW_PATHS[(Ie)new dir/link]} -gt 0 ]] || exit 5
    _git_review_diff_capture "$PWD" untracked "$name" || exit 6
    [[ $_GIT_REVIEW_DATA == *"+let greeting = 42"* ]] || exit 7
    _git_review_diff_capture "$PWD" untracked "new dir/link" || exit 8
    [[ $_GIT_REVIEW_DATA == *"Symbolic link"* && $_GIT_REVIEW_DATA != *outside* ]] || exit 9
    _ZLE_PICKER_DOCUMENT=1
    _git_review_rows
    [[ $_ZLE_PICKER_CONTEXTS[$selected] == New &&
       $_NAVIGATION_PICKER_LABELS[selected] == "$name" &&
       $_GIT_REVIEW_CONTEXTS[selected] == "Untracked · new dir/inner/" ]] || exit 18
    _navigation_picker_collect "new dir/inner" 10
    # Literal full-path matches rank ahead of other legitimate fuzzy matches.
    [[ $_ZLE_PICKER_RESULTS[1] == "$selected" &&
       $_NAVIGATION_PICKER_SEARCH_LABELS[selected] == "$name "* ]] || exit 10
    [[ $(git hash-object --no-filters .git/index) == "$index_before" &&
       $(git hash-object --no-filters .git/config) == "$config_before" ]] || exit 11
    # An embedded repository is still a separate boundary, not a folder crawl.
    mkdir embedded
    git -C embedded init -q
    print -r -- separate-repository > embedded/file
    git -C embedded add file
    git -C embedded -c user.name=Fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false commit -qm fixture
    _git_review_changes_capture "$PWD" || exit 14
    [[ ${_GIT_REVIEW_PATHS[(Ie)embedded/]} -gt 0 && ${_GIT_REVIEW_PATHS[(Ie)embedded/file]} == 0 ]] || exit 15
    _git_review_diff_capture "$PWD" untracked embedded/ || exit 16
    [[ $_GIT_REVIEW_DATA == *"review that repository separately"* ]] || exit 17
    # Expansion keeps the existing result cap and truthful partial status.
    mkdir many
    local i=0
    for (( i=1; i<=1005; ++i )); do : > "many/$i"; done
    _git_review_changes_capture "$PWD" || exit 12
    [[ ${#_GIT_REVIEW_PATHS} == 1000 && $_GIT_REVIEW_SUMMARY == *partial* ]] || exit 13
    print discovered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal discovered "$output"
}
test_case 'Git untracked discovery gives nested files compact row context while retaining canonical facts paths and bounds' _test_git_untracked_nested_discovery

_test_git_untracked_text() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -q
    local name=$'\''new*[x]\nfile.zsh'\''
    local content=$'\''#!/bin/zsh\nprintf should-never-run\n\n@@ -1 +1 @@\n+++ header-like code\nlast line café 界'\''
    print -rn -- "$content" > "$name"
    chmod +x "$name"
    _git_review_git() { print -u2 "untracked content must not invoke Git or its filters"; return 2; }
    _git_review_diff_capture "$PWD" untracked "$name" || exit 1
    [[ $_GIT_REVIEW_DATA == *"+printf should-never-run"* ]] || { print -u2 -r -- "untracked text must be previewed: ${(qqq)_GIT_REVIEW_DATA}"; exit 2; }
    _git_review_document_parse
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY == "+6 -0"* ]] || exit 3
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"+@@ -1 +1 @@"* && $_GIT_REVIEW_DOCUMENT_NEW[-2] == 6 ]] || exit 4
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY != *partial* && $_GIT_REVIEW_DATA == *"No newline at end of file"* ]] || exit 5
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"last line café 界"* ]] || exit 11
    [[ $(<"$name") == "$content" && ! -e .git/index ]] || exit 6
    # Actual blank lines and the trailing newline retain their exact meaning.
    print -rn -- $'\''\n\n'\'' > blanks
    _git_review_diff_capture "$PWD" untracked blanks || exit 7
    _git_review_document_parse
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY == "+2 -0"* && $_GIT_REVIEW_DOCUMENT_NEW[-1] == 2 ]] || exit 8
    : > empty
    _git_review_diff_capture "$PWD" untracked empty || exit 9
    [[ $_GIT_REVIEW_DATA == *"Empty untracked file"* && $_GIT_REVIEW_TRUNCATED == 0 ]] || exit 10
    print previewed
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal previewed "$output"
}
test_case 'Git untracked preview shows complete new text literally with line numbers and newline fidelity' _test_git_untracked_text

_test_git_untracked_safety() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo/folder" "$HOME/outside"
    cd "$HOME/repo"
    print -rn -- $'\''binary\0payload'\'' > binary
    print -r -- outside-sentinel > "$HOME/outside/file"
    ln -s "$HOME/outside/file" link
    ln -s "$HOME/outside" parent
    mkfifo fifo
    _git_review_diff_capture "$PWD" untracked binary || exit 1
    [[ $_GIT_REVIEW_DATA == *"Binary"* && $_GIT_REVIEW_DATA != *payload* ]] || { print -u2 "binary preview must explain omitted content"; exit 2; }
    _git_review_diff_capture "$PWD" untracked link || exit 3
    [[ $_GIT_REVIEW_DATA == *"Symbolic link"* && $_GIT_REVIEW_DATA != *outside-sentinel* ]] || exit 4
    _git_review_diff_capture "$PWD" untracked folder/ || exit 5
    [[ $_GIT_REVIEW_DATA == *"Untracked folder"* ]] || exit 6
    _git_review_diff_capture "$PWD" untracked parent/file && exit 7
    _git_review_diff_capture "$PWD" untracked fifo && exit 8
    _git_review_diff_capture "$PWD" untracked missing && exit 9
    _git_review_diff_capture "$PWD" untracked ../outside/file && exit 10
    [[ $PWD == "$HOME/repo" ]] || exit 11
    print protected
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal protected "$output"
}
test_case 'Git untracked preview handles binary and folder entries without following links or opening special paths' _test_git_untracked_safety

_test_git_untracked_bound() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    local body=${(l:300000::x:)}
    print -rn -- "$body" > large
    _git_review_diff_capture "$PWD" untracked large || exit 1
    (( _GIT_REVIEW_TRUNCATED && ${#_GIT_REVIEW_DATA} <= 262144 )) || { print -u2 "new content must retain the capture bound"; exit 2; }
    _git_review_document_parse
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY == *partial* && ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *Limits:* ]] || exit 3
    # Many short lines still obey the shared logical document limit.
    repeat 12000; do print -r --; done > many
    _git_review_diff_capture "$PWD" untracked many || exit 4
    _git_review_document_parse
    (( ${#_ZLE_PICKER_DOCUMENT_LINES} <= 10001 )) || exit 5
    [[ $_GIT_REVIEW_DOCUMENT_SUMMARY == *partial* ]] || exit 6
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'Git untracked preview bounds bytes and logical lines with honest partial notices' _test_git_untracked_bound

_test_git_untracked_cache() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.git-review"
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(new.zsh) _GIT_REVIEW_KINDS=(untracked)
    local -i captures=0
    _git_review_diff_capture() {
      (( ++captures ))
      _GIT_REVIEW_DATA=$'\''@@ -0,0 +1,1 @@\n+new content\n'\''
      _GIT_REVIEW_TRUNCATED=0
    }
    _git_review_document_load /fixture 1 "" "" 3
    _ZLE_PICKER_DOCUMENT_OFFSETS[1]=5
    _git_review_document_load /fixture 1 "" "" 1000000000
    (( captures == 1 && ${#_git_document_cache} == 1 && _ZLE_PICKER_DOCUMENT_OFFSETS[1] == 5 )) || {
      print -u2 "identical new-file modes must reuse one snapshot and position"; exit 1
    }
    [[ $_ZLE_PICKER_SUBTITLE == *new-file* && $_ZLE_PICKER_SUBTITLE != *context* ]] || exit 2
    _git_review_diff_capture() {
      _GIT_REVIEW_DATA="Unavailable: the untracked path is missing or is not a regular file."
      return 2
    }
    _git_review_document_cache_key 1 3
    unset "_git_document_cache[$REPLY]"
    _git_review_document_load /fixture 1 "" "" 3
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"missing or is not a regular file"* ]] || {
      print -u2 "untracked safety failure must retain its explanation"; exit 3
    }
    print reused
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal reused "$output"
}
test_case 'Git untracked preview reuses its identical full-content snapshot across context modes' _test_git_untracked_cache

_test_git_untracked_read_safety() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    zmodload -F zsh/system b:sysopen b:sysread
    mkdir -p "$HOME/repo" "$HOME/outside"
    cd "$HOME/repo"
    local original=$PWD scenario="" calls=0 content=$'\''first line\nsecond line\nlast line\n'\''
    print -r -- outside-sentinel > "$HOME/outside/file"
    chpwd() { print -r -- hook > "$HOME/hook-ran"; }
    sysopen() {
      case $scenario in
        (link) mv ./file ./saved-link; ln -s "$HOME/outside/file" ./file ;;
        (fifo) mv ./file ./saved-fifo; mkfifo ./file ;;
      esac
      builtin sysopen "$@"
    }
    sysread() {
      [[ $scenario == link || $scenario == fifo ]] && { print -r -- unexpected-read > "$HOME/read-ran"; return 2; }
      (( ++calls ))
      [[ $scenario == fail && $calls == 2 ]] && return 2
      local -a args=("$@")
      (( args[4] > 7 )) && args[4]=7
      builtin sysread "${args[@]}"
    }
    for scenario in link fifo short fail; do
      # Each iteration gets its own ordinary file before the deliberate race.
      local target="$HOME/repo/$scenario"
      mkdir "$target"
      print -rn -- "$content" > "$target/file"
      if [[ $scenario == short ]]; then
        _git_review_diff_capture "$target" untracked file || exit 1
        [[ $_GIT_REVIEW_DATA == *"+last line"* && $_GIT_REVIEW_TRUNCATED == 0 ]] || exit 2
      else
        _git_review_diff_capture "$target" untracked file && exit 3
        [[ $_GIT_REVIEW_DATA == Unavailable:* && $_GIT_REVIEW_DATA != *outside-sentinel* ]] || exit 4
      fi
    done
    [[ $PWD == "$original" && ! -e "$HOME/hook-ran" && ! -e "$HOME/read-ran" ]] || exit 5
    print guarded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal guarded "$output"
}
test_case 'Git untracked preview guards replacement races handles short reads and distinguishes read failure' _test_git_untracked_read_safety
