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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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

# A folder of projects is not itself a worktree, so its default source is the
# walk. Nested repository metadata (gitdirs and worktree/submodule gitfiles)
# is counted as inspected but never matched or descended.
_test_file_search_local_skips_nested_git() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/root" output=''

  test_write_file "$root/.git/hooks/pre-commit.sample" 'root hook' || return
  test_write_file "$root/vendor/lib/.git/hooks/pre-commit.sample" 'hook' || return
  test_write_file "$root/vendor/lib/src/hooks.c" 'source' || return
  test_write_file "$root/sub/wt/.git" 'gitdir: x' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    _file_search_capture "$2" hooks local
    print -r -- "hooks:$?|${(j:|:)_FILE_SEARCH_LABELS}|$_FILE_SEARCH_VISITED"
    _file_search_capture "$2" git local
    print -r -- "git:$?|${#_FILE_SEARCH_VALUES}"
  ' "$TEST_REPO_ROOT" "$root") || return

  test_assert_equal $'hooks:0|· vendor/lib/src/hooks.c|9\ngit:1|0' "$output" \
    'local search matched or descended nested .git metadata'
}
test_case 'local file finder skips nested .git metadata at any depth' \
  _test_file_search_local_skips_nested_git

# Limits are settings text. Nineteen or more digits would truncate or wrap in
# arithmetic, and a count of 2^31 or more breaks the bounded `Y` glob.
_test_file_search_limits_reject_overflowing_settings() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/root" output='' exit_status=0
  command mkdir -p -- "$root/alpha" || return
  test_write_file "$root/alpha/result.txt" 'result' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    local limit=\'\'
    for limit in 99999999999999999999 2147483647 999999999; do
      ZSH_FILE_SEARCH_MAX_VISITED=$limit ZSH_FILE_SEARCH_MAX_CANDIDATES=$limit
      _file_search_capture_local "$2" result
      print -r -- "$limit:$?|${(j:|:)_FILE_SEARCH_LABELS}|$_FILE_SEARCH_VISITED"
    done
  ' "$TEST_REPO_ROOT" "$root" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
99999999999999999999:0|· alpha/result.txt|2
2147483647:0|· alpha/result.txt|2
999999999:0|· alpha/result.txt|2' "status:$exit_status"$'\n'"$output" \
    'overflowing file search limits were evaluated or broke the bounded walk'
}
test_case 'local file finder treats overflowing limit settings as their defaults' \
  _test_file_search_limits_reject_overflowing_settings

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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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

_test_file_search_spotlight_root_scope() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin"
  local outside="$TEST_TMP_DIR/outside.txt" log="$TEST_TMP_DIR/mdfind.args"
  local output='' fake_script=''

  test_write_file "$home/Documents/Final Report.txt" 'inside' || return
  test_write_file "$outside" 'outside' || return
  fake_script=$'#!/bin/zsh\n'
  fake_script+=$'print -rl -- "$@" >| "$FAKE_MDFIND_LOG"\n'
  fake_script+=$'print -rn -- "$FAKE_MDFIND_INSIDE"$\'\\0\''
  fake_script+=$'"$FAKE_MDFIND_OUTSIDE"$\'\\0\''
  test_write_file "$fake_bin/mdfind" "$fake_script" || return
  command chmod +x "$fake_bin/mdfind" || return

  # `/` contains every absolute path; the capture must keep indexed results
  # instead of reporting a successful empty search.
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    export FAKE_MDFIND_LOG="$4"
    export FAKE_MDFIND_INSIDE="$HOME/Documents/Final Report.txt"
    export FAKE_MDFIND_OUTSIDE="$3"
    _file_search_capture_spotlight / "final report" "$2/mdfind"
    print -r -- "status:$?"
    print -r -- "labels:${(j:|:)_FILE_SEARCH_LABELS}"
    print -r -- "args:${(j:,:)${(f)$(<$4)}}"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$outside" "$log") || return

  test_assert_contains "$output" 'status:0' \
    'root-scoped Spotlight search reported no matches for indexed results' || return
  test_assert_contains "$output" 'labels:· ~/Documents/Final Report.txt' \
    'root-scoped Spotlight search discarded an in-scope indexed result' || return
  test_assert_contains "$output" 'args:-0,-onlyin,/,-name,report' \
    'root-scoped Spotlight search changed its index scope or seed'
}
test_case 'Spotlight file finder keeps in-scope results when the scope is the filesystem root' \
  _test_file_search_spotlight_root_scope

_test_file_search_command_contract() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" root="$TEST_TMP_DIR/root" output=''
  local selected_path='' expected_quoted=''

  test_write_file "$root/AI Projects/Final & Ready.md" 'result' || return
  selected_path="$root/AI Projects/Final & Ready.md"
  expected_quoted=${(q)selected_path}
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    _file_search_capture "$2" "final ready" local
    list_status=$?
    print -rl -- "${_FILE_SEARCH_VALUES[@]}"
    # Insert runs through the production post-cleanup dispatcher in the editor.
    source "$1/.zsh.addons/.zsh.editor"
    _directory_browser_dispatch command insert insert "$2/AI Projects/Final & Ready.md"
    IFS= read -r -z quoted
    print -r -- "quoted:$quoted"
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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

# More than 128 KiB of names that each carry multibyte bytes or a newline, so
# whatever boundaries the pipe delivers fall inside records, with matches
# spread through the stream.
_test_file_search_provider_stream_chunks() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''

  test_write_file "$fake_bin/git" $'#!/bin/zsh\nwhile [[ $1 == -C || $1 == -c ]]; do shift 2; done\n[[ $1 == rev-parse ]] && exit 0\n/bin/cat -- "$FAKE_LIST"\nexit "${FAILURE:-0}"' || return
  test_write_file "$fake_bin/mdfind" $'#!/bin/zsh\n/bin/cat -- "$FAKE_LIST"\nexit "${FAILURE:-0}"' || return
  command chmod +x "$fake_bin/git" "$fake_bin/mdfind" || return
  command mkdir -p "$home/Notes" || return

  output=$(test_run_interactive "$home" '
    path=("$2" "${path[@]}")
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    local root=${HOME:A} name="" git_list="" spot_list="" provider="" locale=""
    local accent=$'"'"'\xc3\xa9'"'"' newline=$'"'"'\n'"'"' nul=$'"'"'\0'"'"'
    local -a names=() values=() labels=() unexpected=()
    local -i i=0 result=0
    for (( i = 1; i <= 12; ++i )); do
      names+=("Notes/caf$accent r${accent}sum$accent notes $i.txt" "Notes/line${newline}break notes $i.txt")
    done
    for name in "${names[@]}"; do print -rn -- x >| "$HOME/$name" || exit 9; done
    for (( i = 1; i <= 4000; ++i )); do
      name="filler/caf$accent-r${accent}sum$accent-line${newline}break-$i.md"
      git_list+=$name$nul
      spot_list+=$HOME/$name$nul
      (( i % 150 == 0 && i / 150 <= ${#names} )) || continue
      name=${names[i / 150]}
      git_list+=$name$nul
      spot_list+=$HOME/$name$nul
    done
    (( ${#git_list} > 131072 )) || exit 8
    print -rn -- "$git_list" >| "$HOME/git.list" || exit 9
    print -rn -- "$spot_list" >| "$HOME/spot.list" || exit 9
    _test_capture() {
      if [[ $provider == git ]]; then
        _file_search_capture_git "$HOME" notes
      else
        _file_search_capture_spotlight "$HOME" notes "$2/mdfind"
      fi
    }
    for locale in C en_US.UTF-8; do
      LC_ALL=$locale
      for provider in git spotlight; do
        if [[ $provider == git ]]; then
          export FAKE_LIST=$HOME/git.list
          values=("$root/Notes" "$root/${^names[@]}")
          labels=("▸ Notes/" "· ${^names[@]}")
        else
          export FAKE_LIST=$HOME/spot.list
          values=("$HOME/${^names[@]}")
          labels=("· ~/${^names[@]}")
        fi
        export FAILURE=0
        ZSH_FILE_SEARCH_MAX_CANDIDATES=2000
        _test_capture "$@"
        result=$?
        (( result == 0 && ! _FILE_SEARCH_TRUNCATED )) &&
          [[ ${(pj:\0:)${(o)_FILE_SEARCH_VALUES}} == ${(pj:\0:)${(o)values}} &&
             ${(pj:\0:)${(o)_FILE_SEARCH_LABELS}} == ${(pj:\0:)${(o)labels}} ]] ||
          { print -r -- "$locale $provider complete stream: status $result, ${#_FILE_SEARCH_VALUES} values"; exit 1; }
        FAILURE=3
        _test_capture "$@"
        result=$?
        (( result == 2 && _FILE_SEARCH_TRUNCATED )) &&
          [[ ${(pj:\0:)${(o)_FILE_SEARCH_VALUES}} == ${(pj:\0:)${(o)values}} ]] ||
          { print -r -- "$locale $provider failed source: status $result, ${#_FILE_SEARCH_VALUES} values"; exit 1; }
        ZSH_FILE_SEARCH_MAX_CANDIDATES=5
        _test_capture "$@"
        result=$?
        unexpected=("${(@)_FILE_SEARCH_VALUES:|values}")
        (( result == 0 && ${#_FILE_SEARCH_VALUES} == 5 && _FILE_SEARCH_TRUNCATED &&
           ! ${#unexpected} )) ||
          { print -r -- "$locale $provider early stop: status $result, ${#_FILE_SEARCH_VALUES} values"; exit 1; }
      done
    done
    print chunked
  ' "$TEST_REPO_ROOT" "$fake_bin") || { test_fail "$output"; return; }
  test_assert_equal chunked "$output" 'provider capture lost records split across reads'
}
test_case 'Git and Spotlight capture keep records split across read chunks' \
  _test_file_search_provider_stream_chunks

# Reads of 1 to 7 bytes from a file split every record, multibyte character
# and the trailer's NUL/status pair at a known place.
_test_file_search_stream_boundaries() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    local nul=$'"'"'\0'"'"' locale="" stream="" expected=""
    local -a records=("caf"$'"'"'\xc3\xa9'"'"' "line"$'"'"'\n'"'"'"break" plain)
    local -a collected=()
    local -i size=0 result=0
    _test_collect() { collected+=("$@"); return 0; }
    _test_stop() { collected+=("$@"); return 1; }
    _test_read() {
      local name=$1 data=$2 handler=$3 want_status=$4 want=$5
      print -rn -- "$data" >| "$HOME/stream" || exit 9
      collected=()
      _file_search_stream $size $handler < "$HOME/stream"
      result=$?
      (( result == want_status )) && [[ ${(pj:\0:)collected} == "$want" ]] ||
        { print -r -- "$locale size $size $name: status $result, ${#collected} records"; exit 1; }
    }
    stream=${(pj:\0:)records}$nul
    expected=${(pj:\0:)records}
    for locale in C en_US.UTF-8; do
      LC_ALL=$locale
      for (( size = 1; size <= 7; ++size )); do
        _test_read complete "$stream${nul}0$nul" _test_collect 0 "$expected"
        _test_read empty "${nul}0$nul" _test_collect 0 ""
        _test_read failed "$stream${nul}23$nul" _test_collect 2 "$expected"
        _test_read unterminated-status "$stream${nul}0" _test_collect 2 "$expected"
        _test_read cut-off "${stream}caf"$'"'"'\xc3'"'"' _test_collect 2 "$expected"
        _test_read stopped "$stream${nul}0$nul" _test_stop 1 "${records[1]}"
      done
    done
    size=0
    _test_read size "$stream${nul}0$nul" _test_collect 2 ""
    print boundaries
  ' "$TEST_REPO_ROOT") || { test_fail "$output"; return; }
  test_assert_equal boundaries "$output" 'file search stream handed on a partial record'
}
test_case 'file search stream hands on only complete records at every read size' \
  _test_file_search_stream_boundaries

# Spotlight filters the home-relative display text, not the raw indexed path.
_test_file_search_spotlight_display_match() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''

  test_write_file "$home/Documents/Final Report.txt" 'inside' || return
  test_write_file "$fake_bin/mdfind" $'#!/bin/zsh\nprint -rn -- "$HOME/Documents/Final Report.txt"$\'\\0\'' || return
  command chmod +x "$fake_bin/mdfind" || return

  output=$(test_run_interactive "$home" '
    source "$1/.zsh.addons/.zsh.find"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    _file_search_capture_spotlight "$HOME" "~/doc report" "$2/mdfind"
    print -r -- "tilde:$?:${(j:|:)_FILE_SEARCH_LABELS}"
    _file_search_capture_spotlight "$HOME" "${HOME:t} report" "$2/mdfind"
    print -r -- "home:$?:${(j:|:)_FILE_SEARCH_LABELS}"
  ' "$TEST_REPO_ROOT" "$fake_bin") || return
  test_assert_equal $'tilde:0:· ~/Documents/Final Report.txt\nhome:1:' "$output" \
    'Spotlight search stopped matching the home-relative display text'
}
test_case 'Spotlight search matches the home-relative display text' \
  _test_file_search_spotlight_display_match

_test_ui_owns_command_picker_lifecycle() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    [[ ${widgets[compozsh-picker-init]} == user:_zle_picker_line_init ]] && registered=1
    print -r -- "${+functions[_zle_picker_run]}|${widgets[compozsh-picker]}|${registered:-0}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '1|user:_zle_picker_widget|1' "$output" \
    'UI does not own a reusable order-independent command picker'
}
test_case 'shared UI owns the reusable command-picker lifecycle' \
  _test_ui_owns_command_picker_lifecycle
