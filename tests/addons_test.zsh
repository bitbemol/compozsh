_test_every_addon_sources_independently() {
  test_make_temp_dir || return
  local file='' output=''

  for file in "$TEST_REPO_ROOT"/.zsh.addons/**/.zsh.?*(N.); do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-${file:t}" \
      'source "$1"' "$file" 2>&1) || {
        test_fail "standalone source failed for ${file:t}: $output"
        return
      }
    [[ -z $output ]] || {
      test_fail "standalone source emitted output for ${file:t}: $output"
      return
    }
  done
}
test_case 'every shipped add-on sources independently without diagnostics' \
  _test_every_addon_sources_independently

_test_abbreviation_and_sanitization_contracts() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.prompt"
    _zle_picker_abbreviate abcdefgh 5; picker=$REPLY
    _navigation_abbreviate abcdefgh 5; navigation=$REPLY
    _prompt_abbreviate abcdefgh 5 tail; prompt_tail=$REPLY
    _prompt_abbreviate abcdefgh 5 head; prompt_head=$REPLY
    _prompt_sanitize $\'a\\nb\'; sanitized=$REPLY
    print -r -- "$picker|$navigation|$prompt_tail|$prompt_head|$sanitized"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'a…fgh|a…fgh|a…fgh|ab…gh|a?b' "$output" \
    'responsive text helpers changed semantics'
}
test_case 'shared display helpers abbreviate and sanitize deterministically' \
  _test_abbreviation_and_sanitization_contracts

_test_syntax_classifier_contracts() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.highlighting"
    _zle_is_redirection ">>"; redirection=$?
    _zle_is_assignment "items[2]+=value"; assignment=$?
    _zle_is_number "0xFF"; number=$?
    _zle_is_number "12x"; not_number=$?
    _zle_command_category print; builtin_category=$REPLY
    alias test-alias="print alias"
    _zle_command_category test-alias; alias_category=$REPLY
    print -r -- "$redirection|$assignment|$number|$not_number|$builtin_category|$alias_category"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '0|0|0|1|builtin|alias' "$output" \
    'syntax semantic classification changed'
}
test_case 'syntax highlighter classifies structural and command tokens' \
  _test_syntax_classifier_contracts

_test_fuzzy_history_fragment_order() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    print -s -- "git status"
    print -s -- "swift build -c release"
    print -s -- "git switch feature/example"
    print -s -- "history visibility sentinel"
    _history_search_collect "-c swift" 8
    print -r -- "unordered:${_HISTORY_SEARCH_RESULTS[1]:-}"
    _history_search_collect gtsw 8
    print -r -- "fuzzy:${_HISTORY_SEARCH_RESULTS[1]:-}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_contains "$output" 'unordered:swift build -c release' \
    'unordered history fragments no longer match' || return
  test_assert_contains "$output" 'fuzzy:git switch feature/example' \
    'character-ordered fuzzy history no longer matches'
}
test_case 'fuzzy history finds unordered fragments and abbreviated commands' \
  _test_fuzzy_history_fragment_order

_test_editor_widgets_keep_implementation_private() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    print -r -- "${+functions[history-fuzzy-search]}|${+functions[autosuggest-accept-character]}|${widgets[history-fuzzy-search]}|${widgets[autosuggest-accept-character]}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal \
    '0|0|user:_history_fuzzy_search_widget|user:_zle_autosuggest_accept_character' \
    "$output" 'editor widget implementation leaked into the public function API'
}
test_case 'editor widgets expose stable bindings but keep functions private' \
  _test_editor_widgets_keep_implementation_private

_test_contextual_directory_picker_contract() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  command mkdir -p -- \
    "$home/Developer" \
    "$home/Documents" \
    "$home/AI Projects/Child & Co" \
    "$home/.config" \
    "$home/git" || return
  command ln -s -- "$home/Documents" "$home/Linked" || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.editor"
    setopt AUTO_CD
    builtin cd -- "$HOME" || exit

    _directory_picker_prepare "~/D" 3
    prepared=$?
    _directory_picker_collect "" 10
    print -r -- "visible:$prepared|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_ZLE_PICKER_LABELS}|${(j:,:)_ZLE_PICKER_RESULTS}|${(j:,:)_ZLE_PICKER_RESULT_INDEXES}"

    _directory_picker_prepare "~/." 3
    hidden=$?
    print -r -- "hidden:$hidden|${(j:,:)_DIRECTORY_PICKER_LABELS}"

    _directory_picker_quote "~/AI Projects/Child & Co/"
    print -r -- "quoted:$REPLY"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'visible:0|~/|Developer/,Documents/,Linked/|~/Developer/,~/Documents/,~/Linked/|1,2,3' \
    'path prefix did not produce stable immediate-directory choices' || return
  test_assert_contains "$output" 'hidden:0|.config/' \
    'a dot prefix did not reveal hidden directories exclusively' || return
  test_assert_contains "$output" 'quoted:~/AI\ Projects/Child\ \&\ Co/' \
    'selected paths no longer preserve tilde expansion while escaping specials'
}
test_case 'contextual Tab picker prepares safe fuzzy directory choices' \
  _test_contextual_directory_picker_contract

_test_contextual_directory_picker_fallbacks() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  command mkdir -p -- "$home/Documents" "$home/git" || return
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.editor"
    builtin cd -- "$HOME" || exit

    _directory_picker_prepare "Doc" 3; autocd_disabled=$?
    setopt AUTO_CD
    _directory_picker_prepare "Doc" 3; partial=$?
    _directory_picker_prepare "git" 3; command_name=$?
    _directory_picker_prepare "git switch" 10; multiword=$?
    _directory_picker_prepare "Doc" 2; midline=$?
    _directory_picker_prepare "missing/child" 13; missing_parent=$?
    tab_binding=$(bindkey "^I")
    print -r -- "$autocd_disabled|$partial|$command_name|$multiword|$midline|$missing_parent|${widgets[directory-context-complete]}"
    print -r -- "binding:$tab_binding"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    '1|0|1|1|1|1|user:_directory_context_complete_widget' \
    'contextual Tab stopped preserving native completion boundaries' || return
  test_assert_contains "$output" 'binding:"^I" directory-context-complete' \
    'Tab is not bound to the contextual completion widget'
}
test_case 'contextual Tab picker delegates non-directory completion contexts' \
  _test_contextual_directory_picker_fallbacks

_test_contextual_directory_picker_hierarchy() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  command mkdir -p -- \
    "$home/Developer/Remote/compozsh" \
    "$home/Developer/Empty" || return
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.editor"
    setopt AUTO_CD
    builtin cd -- "$HOME" || exit

    typeset -g _DIRECTORY_PICKER_INPUT="~/Dev"
    typeset -ga _DIRECTORY_PICKER_STACK=()
    input_length=${#_DIRECTORY_PICKER_INPUT}
    _directory_picker_prepare "$_DIRECTORY_PICKER_INPUT" $input_length || exit

    _directory_picker_transition descend "~/Developer/"
    first_status=$?
    print -r -- "first:$first_status|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_DIRECTORY_PICKER_LABELS}|$_DIRECTORY_PICKER_INPUT|${(j:,:)_DIRECTORY_PICKER_STACK}"

    _directory_picker_transition descend "~/Developer/Remote/"
    second_status=$?
    print -r -- "second:$second_status|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_DIRECTORY_PICKER_LABELS}|$_DIRECTORY_PICKER_INPUT|${(j:,:)_DIRECTORY_PICKER_STACK}"

    _directory_picker_transition parent ""
    parent_status=$?
    print -r -- "parent:$parent_status|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_DIRECTORY_PICKER_LABELS}|$_DIRECTORY_PICKER_INPUT|${(j:,:)_DIRECTORY_PICKER_STACK}"

    _directory_picker_transition descend "~/Developer/Empty/"
    empty_status=$?
    empty_notice=$REPLY
    print -r -- "empty:$empty_status|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_DIRECTORY_PICKER_LABELS}|$_DIRECTORY_PICKER_INPUT|${(j:,:)_DIRECTORY_PICKER_STACK}|$empty_notice"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" \
    'first:0|~/Developer/|Empty/,Remote/|~/Developer/|~/Dev' \
    'drilling in did not expose only the selected directory children' || return
  test_assert_contains "$output" \
    'second:0|~/Developer/Remote/|compozsh/|~/Developer/Remote/|~/Dev,~/Developer/' \
    'a second drill lost the accumulated path or parent stack' || return
  test_assert_contains "$output" \
    'parent:0|~/Developer/|Empty/,Remote/|~/Developer/|~/Dev' \
    'moving back did not restore the previous directory level' || return
  test_assert_contains "$output" \
    'empty:1|~/Developer/|Empty/,Remote/|~/Developer/|~/Dev|no visible child directories in Empty/' \
    'an empty child did not preserve its level with a useful explanation'
}
test_case 'contextual directory picker drills down and returns without recursion' \
  _test_contextual_directory_picker_hierarchy

_test_navigation_fuzzy_ranking() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.navigation"
    typeset -ga _NAVIGATION_PICKER_VALUES=(/tmp/swift-project /tmp/git-tools /tmp/project-swift)
    typeset -ga _NAVIGATION_PICKER_LABELS=(swift-project git-tools project-swift)
    typeset -ga _NAVIGATION_PICKER_INDEXES=(1 2 3)
    typeset -ga _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _ZLE_PICKER_RESULT_INDEXES=()
    _navigation_picker_collect swift 10
    print -r -- "${(j:|:)_ZLE_PICKER_LABELS}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'swift-project|project-swift' "$output" \
    'navigation prefix and substring ranking changed'
}
test_case 'navigation fuzzy ranking keeps prefix matches ahead of substrings' \
  _test_navigation_fuzzy_ranking

_test_git_branch_recency_contract() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" repository="$TEST_TMP_DIR/repository"
  local output=''

  command git init -q "$repository" || return
  command git -C "$repository" config user.name 'Test User' || return
  command git -C "$repository" config user.email test@example.invalid || return
  test_write_file "$repository/README.md" 'fixture' || return
  command git -C "$repository" add README.md || return
  command git -C "$repository" commit -qm initial || return
  command git -C "$repository" branch -M main || return
  command git -C "$repository" switch -qc alpha || return
  command git -C "$repository" switch -qc beta main || return
  command git -C "$repository" switch -q main || return
  command git -C "$repository" switch -q alpha || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.navigation"
    _git_recent_branches "$2"
    print -r -- "${(j:|:)_GIT_RECENT_BRANCHES}"
  ' "$TEST_REPO_ROOT" "$repository") || return
  test_assert_equal 'alpha|main|beta' "$output" \
    'Git branch recency order changed'
}
test_case 'Git branch stack keeps current and recent branches in order' \
  _test_git_branch_recency_contract

_test_git_branch_recency_tolerates_unvisited_branches() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" repository="$TEST_TMP_DIR/repository"
  local output=''

  command git init -q "$repository" || return
  command git -C "$repository" config user.name 'Test User' || return
  command git -C "$repository" config user.email test@example.invalid || return
  test_write_file "$repository/README.md" 'fixture' || return
  command git -C "$repository" add README.md || return
  command git -C "$repository" commit -qm initial || return
  command git -C "$repository" branch -M main || return
  command git -C "$repository" branch never-checked-out || return
  command git -C "$repository" switch -qc recently-used || return

  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.navigation"
    _git_recent_branches "$2"
    result_status=$?
    print -r -- "$result_status|${(j:|:)_GIT_RECENT_BRANCHES}"
  ' "$TEST_REPO_ROOT" "$repository") || return
  test_assert_equal '0|recently-used|main' "$output" \
    'an unvisited local branch made successful recency inspection fail'
}
test_case 'Git branch stack tolerates local branches absent from the reflog' \
  _test_git_branch_recency_tolerates_unvisited_branches

_test_public_palettes_preserve_initializer_roles() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    typeset -gA ZSH_HIGHLIGHT_STYLES=(command "fg=123,bold")
    typeset -gA ZSH_PROMPT_COLORS=(identity 124)
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.highlighting"
    print -r -- "${ZSH_HIGHLIGHT_STYLES[command]}|${ZSH_HIGHLIGHT_STYLES[argument]}|${ZSH_PROMPT_COLORS[identity]}|${ZSH_PROMPT_COLORS[path]}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'fg=123,bold|fg=252|124|80' "$output" \
    'palette defaults replaced an explicit initializer role'
}
test_case 'palette owners fill missing roles without replacing local inputs' \
  _test_public_palettes_preserve_initializer_roles

_test_prompt_rejects_project_controlled_runtime() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/project" sentinel="$TEST_TMP_DIR/executed"
  local output=''

  test_write_file "$project/build.zig" '' || return
  test_write_file "$project/zig" $'#!/bin/sh\n: > "$PROJECT_EXECUTION_SENTINEL"\nprintf "99.0.0\\n"' || return
  command chmod +x "$project/zig" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    export PROJECT_EXECUTION_SENTINEL=$2
    path=($3 $path)
    rehash
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_runtime_version zig "$3"
    [[ -e $2 ]]; executed=$(( !$? ))
    print -r -- "$REPLY|$executed"
  ' "$TEST_REPO_ROOT" "$sentinel" "$project") || return

  test_assert_equal 'not-installed|0' "$output" \
    'prompt executed a runtime resolved from the untrusted project'
}
test_case 'prompt never executes a runtime from the detected project' \
  _test_prompt_rejects_project_controlled_runtime

_test_prompt_rejects_runtime_from_enclosing_repository() {
  test_make_temp_dir || return
  local repository="$TEST_TMP_DIR/repository"
  local package="$repository/packages/app"
  local sentinel="$TEST_TMP_DIR/executed" output=''

  command mkdir -p -- "$repository/.git" "$repository/bin" || return
  test_write_file "$package/build.zig" '' || return
  test_write_file "$repository/bin/zig" \
    $'#!/bin/sh\n: > "$PROJECT_EXECUTION_SENTINEL"\nprintf "99.0.0\\n"' || return
  command chmod +x "$repository/bin/zig" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    export PROJECT_EXECUTION_SENTINEL=$2
    path=($3 $path)
    rehash
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_runtime_version zig "$4"
    [[ -e $2 ]]; executed=$(( !$? ))
    print -r -- "$REPLY|$executed"
  ' "$TEST_REPO_ROOT" "$sentinel" "$repository/bin" "$package") || return

  test_assert_equal 'not-installed|0' "$output" \
    'prompt executed a runtime from an enclosing untrusted repository'
}
test_case 'prompt rejects runtimes controlled by an enclosing repository' \
  _test_prompt_rejects_runtime_from_enclosing_repository

_test_prompt_runtime_probe_is_neutral_and_offline() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/project" fake_bin="$TEST_TMP_DIR/bin"
  local go_probe="$TEST_TMP_DIR/go-probe" rust_probe="$TEST_TMP_DIR/rust-probe"
  local terraform_probe="$TEST_TMP_DIR/terraform-probe"
  local dotnet_probe="$TEST_TMP_DIR/dotnet-probe"
  local output=''

  test_write_file "$project/go.mod" $'module example.invalid/app\ngo 9.9' || return
  test_write_file "$project/rust-toolchain.toml" \
    $'[toolchain]\nchannel = "nightly"' || return
  test_write_file "$fake_bin/go" \
    $'#!/bin/sh\nprintf "%s|%s" "$PWD" "${GOTOOLCHAIN-}" > "$GO_PROBE"\nprintf "go version go1.24.0 test/arch\\n"' || return
  test_write_file "$fake_bin/rustc" \
    $'#!/bin/sh\nprintf "%s|%s" "$PWD" "${RUSTUP_AUTO_INSTALL-}" > "$RUST_PROBE"\nprintf "rustc 1.85.0 (test)\\n"' || return
  test_write_file "$fake_bin/terraform" \
    $'#!/bin/sh\nprintf "%s" "${CHECKPOINT_DISABLE-}" > "$TERRAFORM_PROBE"\nprintf "Terraform v1.10.0\\n"' || return
  test_write_file "$fake_bin/dotnet" \
    $'#!/bin/sh\nprintf "%s|%s" "${DOTNET_CLI_TELEMETRY_OPTOUT-}" "${DOTNET_NOLOGO-}" > "$DOTNET_PROBE"\nprintf "9.0.100\\n"' || return
  command chmod +x "$fake_bin/go" "$fake_bin/rustc" \
    "$fake_bin/terraform" "$fake_bin/dotnet" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    export GO_PROBE=$2 RUST_PROBE=$3 TERRAFORM_PROBE=$4 DOTNET_PROBE=$5
    path=($6 $path)
    rehash
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_runtime_version go "$7"; go_version=$REPLY
    _prompt_runtime_version rust "$7"; rust_version=$REPLY
    _prompt_runtime_version terraform "$7"; terraform_version=$REPLY
    _prompt_runtime_version dotnet "$7"; dotnet_version=$REPLY
    print -r -- "$go_version|$rust_version|$terraform_version|$dotnet_version|$(<$2)|$(<$3)|$(<$4)|$(<$5)"
  ' "$TEST_REPO_ROOT" "$go_probe" "$rust_probe" "$terraform_probe" \
    "$dotnet_probe" "$fake_bin" "$project") || return

  test_assert_equal \
    '1.24.0|1.85.0|1.10.0|9.0.100|/|local|/|0|1|1|1' "$output" \
    'prompt runtime probe inherited project policy or download behavior'
}
test_case 'prompt probes installed runtimes from a neutral offline context' \
  _test_prompt_runtime_probe_is_neutral_and_offline

_test_prompt_metadata_stays_inside_project() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/project" private_file="$TEST_TMP_DIR/private"
  local output=''

  test_write_file "$private_file" 'PRIVATE-VALUE' || return
  command mkdir -p -- "$project" || return
  command ln -s "$private_file" "$project/.zig-version" || return
  command ln -s "$private_file" "$project/.tool-versions" || return
  command ln -s "$private_file" "$project/go.mod" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_expected_runtime_version zig "$2"; zig_version=$REPLY
    _prompt_expected_runtime_version python "$2"; tool_version=$REPLY
    _prompt_expected_runtime_version go "$2"; go_version=$REPLY
    print -r -- "$zig_version|$tool_version|$go_version"
  ' "$TEST_REPO_ROOT" "$project") || return
  test_assert_equal '||' "$output" \
    'prompt read runtime metadata through a project symlink' || return

  command rm -- "$project/.zig-version" "$project/.tool-versions" \
    "$project/go.mod" || return
  test_write_file "$project/.zig-version" '0.14.1' || return
  test_write_file "$project/.tool-versions" 'python 3.13.1' || return
  test_write_file "$project/go.mod" $'module example.invalid/project\ngo 1.24' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home-direct" $'
    source "$1/.zsh.addons/.zsh.prompt"
    _prompt_expected_runtime_version zig "$2"; zig_version=$REPLY
    _prompt_expected_runtime_version python "$2"; tool_version=$REPLY
    _prompt_expected_runtime_version go "$2"; go_version=$REPLY
    print -r -- "$zig_version|$tool_version|$go_version"
  ' "$TEST_REPO_ROOT" "$project") || return
  test_assert_equal '0.14.1|3.13.1|1.24' "$output" \
    'prompt rejected safe direct runtime metadata files'
}
test_case 'prompt reads bounded direct metadata but rejects symlinked files' \
  _test_prompt_metadata_stays_inside_project

_test_prompt_preserves_existing_winch_handler() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    typeset -gi PREEXISTING_WINCH_CALLS=0
    TRAPWINCH() { (( ++PREEXISTING_WINCH_CALLS )); }
    source "$1/.zsh.addons/.zsh.prompt"
    TRAPWINCH
    print -r -- "$PREEXISTING_WINCH_CALLS|${+functions[_prompt_previous_TRAPWINCH]}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '1|1' "$output" \
    'prompt replaced the initializer-owned WINCH handler'
}
test_case 'prompt preserves a preexisting WINCH signal handler' \
  _test_prompt_preserves_existing_winch_handler

_test_prompt_source_detection_is_bounded() {
  test_make_temp_dir || return
  local small="$TEST_TMP_DIR/small" large="$TEST_TMP_DIR/large"
  local output=''
  local -i index=0

  command mkdir -p -- "$small/src" "$large/src" || return
  test_write_file "$small/src/main.c" 'int main(void) { return 0; }' || return
  for (( index = 1; index <= 3000; ++index )); do
    print -r -- 'int value;' >| "$large/src/generated-${index}.c" || return
  done

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.prompt"
    builtin cd "$2" || exit
    _prompt_project_context
    small_saturated=$_PROMPT_RESOLVED_SOURCE_SCAN_SATURATED
    builtin cd "$3" || exit
    _prompt_project_context
    print -r -- "$small_saturated|$_PROMPT_RESOLVED_SOURCE_SCAN_SATURATED|$_PROMPT_PROJECT_NAME_TEXT|${#_PROMPT_PROJECT_ITEMS}"
  ' "$TEST_REPO_ROOT" "$small" "$large") || return
  [[ $output == 0\|1\|large\|<1-> ]] ||
    test_fail "bounded source detection lost saturation or context: $output"
}
test_case 'prompt source detection bounds saturated conventional directories' \
  _test_prompt_source_detection_is_bounded

_test_prompt_ignores_symlinked_source_directories() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/project" external="$TEST_TMP_DIR/external"
  local fake_bin="$TEST_TMP_DIR/bin" zig_probe="$TEST_TMP_DIR/zig-probe"
  local output=''

  test_write_file "$project/package.json" '{}' || return
  test_write_file "$external/code.zig" 'const value = 1;' || return
  command ln -s "$external" "$project/src" || return
  test_write_file "$fake_bin/node" $'#!/bin/sh\nprintf "v22.0.0\\n"' || return
  test_write_file "$fake_bin/zig" \
    $'#!/bin/sh\n: > "$ZIG_PROBE"\nprintf "0.14.0\\n"' || return
  command chmod +x "$fake_bin/node" "$fake_bin/zig" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    export ZIG_PROBE=$2
    path=($3 $path)
    rehash
    source "$1/.zsh.addons/.zsh.prompt"
    builtin cd "$4" || exit
    _prompt_project_context
    print -r -- "${+_PROMPT_PROJECT_NAME_TEXT}|${#_PROMPT_PROJECT_ITEMS}|${+commands[zig]}|${+commands[node]}"
  ' "$TEST_REPO_ROOT" "$zig_probe" "$fake_bin" "$project") || return

  [[ ! -e $zig_probe ]] ||
    test_fail 'prompt followed a symlinked source directory' || return
  [[ $output == 1\|<1->\|1\|1 ]] ||
    test_fail "prompt lost the manifest project while ignoring its symlink: $output"
}
test_case 'prompt never scans symlinked conventional source directories' \
  _test_prompt_ignores_symlinked_source_directories
