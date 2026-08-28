_test_file_search_git_provider() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" repository="$TEST_TMP_DIR/repository"
  local output=''

  command git init -q "$repository" || return
  command git -C "$repository" config user.name 'Test User' || return
  command git -C "$repository" config user.email test@example.invalid || return
  test_write_file "$repository/.gitignore" '.build/' || return
  test_write_file "$repository/Sources/Network/Client.swift" 'client' || return
  test_write_file "$repository/Tests/ClientTests.swift" 'tests' || return
  test_write_file "$repository/.build/private-cache.bin" 'ignored' || return
  command git -C "$repository" add .gitignore Sources Tests || return
  command git -C "$repository" commit -qm initial || return
  test_write_file "$repository/Notes/Network plan.md" 'untracked' || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    _file_search_capture_git "$2" "net cli" || exit
    print -r -- "labels:${(j:|:)_FILE_SEARCH_LABELS}"
    print -r -- "ignored:${_FILE_SEARCH_VALUES[(I)*private-cache.bin]}"
    _file_search_capture_git "$2" srccl || exit
    print -r -- "fuzzy:${(j:|:)_FILE_SEARCH_LABELS}"
  ' "$TEST_REPO_ROOT" "$repository") || return

  test_assert_contains "$output" '· Sources/Network/Client.swift' \
    'Git search lost an unordered path-fragment match' || return
  test_assert_contains "$output" 'ignored:0' \
    'Git search exposed an ignored generated file' || return
  test_assert_contains "$output" 'fuzzy:· Sources/Network/Client.swift' \
    'Git search lost character-ordered fuzzy path matching'
}
test_case 'fuzzy file finder searches the complete relevant Git project' \
  _test_file_search_git_provider

_test_file_search_picker_ranking() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.find"
    typeset -ga _FILE_SEARCH_VALUES=(/tmp/one /tmp/two /tmp/three)
    typeset -ga _FILE_SEARCH_LABELS=(
      "· notes/alpha-project.md"
      "· src/ProjectAlpha.swift"
      "· misc/protocol-journal.md"
    )
    typeset -ga _FILE_SEARCH_MATCH_TEXTS=(
      "notes/alpha-project.md"
      "src/ProjectAlpha.swift"
      "misc/protocol-journal.md"
    )
    _file_search_picker_collect "alpha project" 10
    print -r -- "literal:${(j:|:)_ZLE_PICKER_LABELS}"
    _file_search_picker_collect ptjrnl 10
    print -r -- "fuzzy:${(j:|:)_ZLE_PICKER_LABELS}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'literal:· notes/alpha-project.md|· src/ProjectAlpha.swift' \
    'picker lost stable unordered-literal ranking' || return
  test_assert_contains "$output" 'fuzzy:· misc/protocol-journal.md' \
    'picker lost character-ordered path refinement'
}
test_case 'file picker ranks captured paths without touching providers' \
  _test_file_search_picker_ranking

_test_file_search_candidate_summary() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.find"
    typeset -ga _FILE_SEARCH_VALUES=(/tmp/one)
    _FILE_SEARCH_TRUNCATED=0
    _file_search_candidate_summary needle
    print -r -- "one:$REPLY"
    _FILE_SEARCH_VALUES+=(/tmp/two)
    _FILE_SEARCH_TRUNCATED=1
    _file_search_candidate_summary needle
    print -r -- "many:$REPLY"
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'one:1 candidate for needle' \
    'single-result picker summary used plural grammar' || return
  test_assert_contains "$output" 'many:2 candidates for needle · partial' \
    'partial multi-result picker summary lost its state'
}
test_case 'file picker describes candidate counts precisely' \
  _test_file_search_candidate_summary

_test_file_search_local_boundaries() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" root="$TEST_TMP_DIR/root"
  local outside="$TEST_TMP_DIR/outside" output=''

  command mkdir -p -- "$root/alpha/child" "$outside" || return
  test_write_file "$root/.hidden-note" 'hidden' || return
  test_write_file "$root/alpha/result.txt" 'result' || return
  test_write_file "$outside/secret.txt" 'secret' || return
  command ln -s -- "$outside" "$root/linked-outside" || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    _file_search_capture_local "$2" hidden || exit
    print -r -- "hidden:${(j:|:)_FILE_SEARCH_LABELS}"
    _file_search_capture_local "$2" secret
    print -r -- "outside:$?|${#_FILE_SEARCH_VALUES}"
    ZSH_FILE_SEARCH_MAX_VISITED=1
    _file_search_capture_local "$2" result
    print -r -- "bounded:$_FILE_SEARCH_TRUNCATED|$_FILE_SEARCH_VISITED"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_contains "$output" 'hidden:· .hidden-note' \
    'local search omitted a matching hidden file' || return
  test_assert_contains "$output" 'outside:1|0' \
    'local search followed a symbolic-link directory outside its root' || return
  test_assert_contains "$output" 'bounded:1|1' \
    'local search did not enforce and report its traversal budget'
}
test_case 'local file finder is hidden-aware, bounded, and never follows links' \
  _test_file_search_local_boundaries

_test_file_search_spotlight_boundary() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin"
  local outside="$TEST_TMP_DIR/outside.txt" log="$TEST_TMP_DIR/mdfind.args"
  local output='' fake_script=''

  test_write_file "$home/Documents/Final Report.txt" 'inside' || return
  test_write_file "$outside" 'outside' || return
  fake_script=$'#!/bin/zsh\n'
  fake_script+=$'print -rl -- "$@" >| "$FAKE_MDFIND_LOG"\n'
  fake_script+=$'for argument in "$@"; do\n'
  fake_script+=$'  [[ $argument == -literal ]] && exit 64\n'
  fake_script+=$'done\n'
  fake_script+=$'print -rn -- "$FAKE_MDFIND_INSIDE"$\'\\0\''
  fake_script+=$'"$FAKE_MDFIND_OUTSIDE"$\'\\0\''
  test_write_file "$fake_bin/mdfind" "$fake_script" || return
  command chmod +x "$fake_bin/mdfind" || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    export FAKE_MDFIND_LOG="$4"
    export FAKE_MDFIND_INSIDE="$HOME/Documents/Final Report.txt"
    export FAKE_MDFIND_OUTSIDE="$3"
    _file_search_capture_spotlight "$HOME" "final report" "$2/mdfind" || exit
    print -r -- "labels:${(j:|:)_FILE_SEARCH_LABELS}"
    print -r -- "args:${(j:,:)${(f)$(<$4)}}"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$outside" "$log") || return

  test_assert_contains "$output" 'labels:· ~/Documents/Final Report.txt' \
    'Spotlight search lost an in-scope indexed result' || return
  [[ $output != *"· $outside"* ]] || {
    test_fail 'Spotlight search accepted an out-of-scope result'
    return
  }
  test_assert_contains "$output" 'args:-0,-onlyin,' \
    'Spotlight search stopped requesting NUL-delimited scoped output' || return
  test_assert_contains "$output" ',-name,report' \
    'Spotlight search did not seed the index with the longest query fragment'
}
test_case 'Spotlight file finder treats queries as data and enforces its root' \
  _test_file_search_spotlight_boundary

_test_file_search_command_contract() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" root="$TEST_TMP_DIR/root" output=''
  local selected_path='' expected_quoted=''

  test_write_file "$root/AI Projects/Final & Ready.md" 'result' || return
  selected_path="$root/AI Projects/Final & Ready.md"
  expected_quoted=${(q)selected_path}
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    _file_search_capture "$2" "final ready" local
    list_status=$?
    print -rl -- "${_FILE_SEARCH_VALUES[@]}"
    _file_search_quote "$2/AI Projects/Final & Ready.md"
    print -r -- "quoted:$REPLY"
    _file_search_capture "$2" "" local
    print -r -- "missing-query:$?"
    print -r -- "public:${+functions[f]}"
  ' "$TEST_REPO_ROOT" "$root" 2>&1) || return

  test_assert_contains "$output" "${root:A}/AI Projects/Final & Ready.md" \
    'list mode did not emit the complete selected path' || return
  test_assert_contains "$output" "quoted:$expected_quoted" \
    'selected path was not safely shell-quoted' || return
  test_assert_contains "$output" 'missing-query:2' \
    'a missing query did not retain the usage error status' || return
  test_assert_contains "$output" 'public:0' \
    'the retired finder command returned to the public function surface'
}
test_case 'file finder lists safely and never executes a selected path' \
  _test_file_search_command_contract

_test_file_search_path_fidelity() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" root="$TEST_TMP_DIR/root"
  local output='' filename=$'line\nbreak & notes.txt'

  test_write_file "$root/$filename" 'result' || return
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    command git -C "$2" init -q || exit
    for provider in local git; do
      _file_search_capture "$2" "notes" "$provider" || exit
      [[ ${#_FILE_SEARCH_VALUES} == 1 && $_FILE_SEARCH_VALUES[1] == "${2:A}/$3" ]] || exit 1
    done
    print literal
  ' "$TEST_REPO_ROOT" "$root" "$filename") || return
  test_assert_equal literal "$output" 'capture split a newline-bearing filename'
}
test_case 'filesystem and Git capture preserve newline-bearing paths as literal array values' \
  _test_file_search_path_fidelity

_test_editor_owns_command_picker_lifecycle() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    typeset -a hooks=()
    zstyle -a zle-line-init widgets hooks
    (( hooks[(I)*:_zle_picker_line_init] )) && registered=1
    print -r -- "${+functions[_zle_picker_run]}|${widgets[compozsh-picker]}|${registered:-0}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '1|user:_zle_picker_widget|1' "$output" \
    'the editor does not own a reusable order-independent command picker'
}
test_case 'shared editor owns the reusable command-picker lifecycle' \
  _test_editor_owns_command_picker_lifecycle
