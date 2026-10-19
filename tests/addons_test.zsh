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
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.prompt"
    _zle_picker_abbreviate abcdefgh 5; picker=$REPLY
    _zle_picker_abbreviate abcdefgh 5; navigation=$REPLY
    _zle_picker_abbreviate abcdefgh 5 tail; prompt_tail=$REPLY
    _zle_picker_abbreviate abcdefgh 5 head; prompt_head=$REPLY
    _zle_picker_abbreviate 漢字abcdef 6 tail; prompt_wide=$REPLY
    _zle_picker_abbreviate $\'e\\u0301abc\' 4 tail; prompt_combining=$REPLY
    _compozsh_sanitize $\'a\\nb\'; sanitized=$REPLY
    print -r -- "$picker|$navigation|$prompt_tail|$prompt_head|$prompt_wide|${(m)#prompt_wide}|$prompt_combining|${(m)#prompt_combining}|$sanitized"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'a…fgh|a…fgh|a…fgh|ab…gh|…cdef|5|éabc|4|a?b' "$output" \
    'responsive text helpers changed semantics'
}
test_case 'shared display helpers abbreviate and sanitize deterministically' \
  _test_abbreviation_and_sanitization_contracts

_test_syntax_classifier_contracts() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$unit"; done
    _compozsh_is_redirection ">>"; redirection=$?
    _compozsh_is_assignment "items[2]+=value"; assignment=$?
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

_test_syntax_highlighter_bounds_redraw_work() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    typeset -gi probes=0
    _zle_command_category() { (( ++probes )); return 1; }
    _zle_path_category() { (( ++probes )); return 1; }
    BUFFER="print ${(l:600::x:)}"
    region_highlight=(
      "0 1 bold memo=fixture"
      "0 2 fg=75 memo=compozsh"
    )
    _zle_syntax_highlight
    print -r -- "$probes|${(j:|:)region_highlight}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal '0|0 1 bold memo=fixture' "$output" \
    'oversized syntax highlighting performed classification or removed foreign state'
}
test_case 'syntax highlighting bounds oversized redraw work' \
  _test_syntax_highlighter_bounds_redraw_work

_test_fuzzy_history_fragment_order() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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

_test_autosuggestion_search_is_bounded_and_newest_first() {
  test_make_temp_dir || return
  local history_file="$TEST_TMP_DIR/history" history_contents='old-prefix target'
  local output=''
  local -i index=0

  for (( index = 1; index <= 600; ++index )); do
    history_contents+=$'\n'"unrelated history $index"
  done
  history_contents+=$'\n''git switch newest'$'\n''terminal sentinel'
  test_write_file "$history_file" "$history_contents" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    HISTSIZE=1000
    fc -p "$2"
    _zle_autosuggest_find old-prefix
    print -r -- "older:$_ZLE_AUTOSUGGEST_CACHE_FULL"
    _zle_autosuggest_find "git sw"
    print -r -- "newest:$_ZLE_AUTOSUGGEST_CACHE_FULL"
  ' "$TEST_REPO_ROOT" "$history_file") || return

  test_assert_equal $'older:\nnewest:git switch newest' "$output" \
    'autosuggestion search lost its newest-first bound'
}
test_case 'autosuggestions inspect only bounded recent history' \
  _test_autosuggestion_search_is_bounded_and_newest_first

_test_editor_widgets_keep_implementation_private() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    print -r -- "${+functions[history-fuzzy-search]}|${+functions[autosuggest-accept-character]}|${widgets[history-fuzzy-search]}|${widgets[autosuggest-accept-character]}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal \
    '0|0|user:_history_fuzzy_search_widget|user:_zle_autosuggest_accept_character' \
    "$output" 'editor widget implementation leaked into the public function API'
}
test_case 'editor widgets expose stable bindings but keep functions private' \
  _test_editor_widgets_keep_implementation_private

_test_autosuggestion_reset_owns_only_its_display() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    region_highlight=(
      "0 1 bold memo=fixture"
      "P1 4 fg=242 memo=my-zsh-autosuggestion"
      "P0 2 fg=33 memo=my-zsh-picker"
    )
    POSTDISPLAY=suffix
    _ZLE_AUTOSUGGEST_DISPLAY=suffix
    _ZLE_AUTOSUGGEST_SUFFIX=suffix
    _ZLE_PICKER_POSTDISPLAY=picker
    _ZLE_PICKER_ACTIVE=1

    _zle_autosuggest_reset

    print -r -- "state:${(qqq)POSTDISPLAY}|${(qqq)_ZLE_AUTOSUGGEST_DISPLAY}|${(qqq)_ZLE_PICKER_POSTDISPLAY}|$_ZLE_PICKER_ACTIVE"
    print -r -- "highlights:${(j:|:)region_highlight}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal \
    $'state:""|""|"picker"|1\nhighlights:0 1 bold memo=fixture|P0 2 fg=33 memo=my-zsh-picker' \
    "$output" \
    'autosuggestion reset changed picker ownership or retained its own display'
}
test_case 'autosuggestion reset removes only its owned display state' \
  _test_autosuggestion_reset_owns_only_its_display

_test_editor_styles_without_highlighting_peer() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    # An undeclared palette treats a role subscript as arithmetic, including
    # this dynamically scoped query. Standalone fallback must remain literal.
    query="two words"
    _zle_picker_style picker-query
    print -r -- "$REPLY"
    ZSH_HIGHLIGHT_STYLES[picker-query]=fg=75
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _zle_picker_style picker-query
    print -r -- "$REPLY"
  ' "$TEST_REPO_ROOT" 2>&1) || {
    test_fail "standalone picker styles failed: $output"
    return 1
  }
  test_assert_equal $'fg=87,bg=235,bold\nfg=75' "$output"
}
test_case 'shared UI palette works without the highlighting peer and preserves overrides' \
  _test_editor_styles_without_highlighting_peer

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
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    setopt AUTO_CD
    builtin cd -- "$HOME" || exit

    _directory_picker_prepare "~/D" 3
    prepared=$?
    _directory_picker_collect "" 10
    _zle_picker_render "" 1
    print -r -- "visible:$prepared|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_ZLE_PICKER_LABELS}|${(j:,:)_ZLE_PICKER_RESULTS}|${(j:,:)_ZLE_PICKER_VISIBLE_KEYS}"

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
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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

# A trailing slash names a folder. If it is missing there is no parent filter
# to fall back to: the prefix would be cut mid-name (~/P + Projects/).
_test_contextual_directory_picker_missing_folder() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  command mkdir -p -- "$home/Projects/app" "$home/Other" || return
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    setopt AUTO_CD
    builtin cd -- "$HOME" || exit

    _directory_picker_prepare "~/Projcts/" 10; tab=$?
    _directory_picker_prepare "~/Projcts/" 10 1 1; internal=$?
    _directory_picker_prepare "Projcts/" 8; relative=$?
    _directory_picker_prepare "~/Projects/apx/" 15; nested=$?
    print -r -- "missing:$tab|$internal|$relative|$nested|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_DIRECTORY_PICKER_VALUES}"
    _directory_picker_prepare "~/Projcts" 9; control=$?
    print -r -- "control:$control|$_DIRECTORY_PICKER_LOCATION|${(j:,:)_DIRECTORY_PICKER_VALUES}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'missing:1|1|1|1||' \
    'a missing folder ending in a slash became a filter on its parent' || return
  test_assert_contains "$output" 'control:0|~/|~/Other/,~/Projects/' \
    'a missing final name without a slash no longer filters its parent'
}
test_case 'contextual Tab picker delegates a missing folder ending in a slash instead of filtering its parent' \
  _test_contextual_directory_picker_missing_folder

_test_contextual_directory_argument() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Developer/Example & Co" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
    builtin cd -- "$HOME" || exit
    unsetopt AUTO_CD
    local BUFFER="vim ~/Developer" CURSOR=15
    local -i captures=0 fallback=0
    # Keep the real context parser, capture and insertion dispatcher; replace
    # only terminal ownership and selection for this deterministic regression.
    zle() { [[ $1 == expand-or-complete ]] && (( ++fallback )); return 0; }
    _zle_picker_screen_session() {
      (( ++captures ))
      [[ $_DIRECTORY_PICKER_LOCATION == "~/Developer/" ]] || return 4
      _ZLE_PICKER_ACTION=select
      _ZLE_PICKER_SELECTED_VALUE="~/Developer/Example & Co/"
    }
    _directory_context_complete_widget
    [[ $BUFFER == "vim ~/Developer/Example\\ \\&\\ Co/" && $CURSOR == ${#BUFFER} &&
       $captures == 1 && $fallback == 0 && $PWD == "$HOME" ]] || {
      print -u2 -r -- "path argument was not completed: $BUFFER|$captures|$fallback"
      exit 1
    }
    print argument
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal argument "$output"
}
test_case 'contextual Tab completes a directory argument without replacing its command' \
  _test_contextual_directory_argument

_test_contextual_directory_picker_hierarchy() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  command mkdir -p -- \
    "$home/Developer/Remote/compozsh" \
    "$home/Developer/Empty" || return
  output=$(test_run_interactive "$home" $'
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit
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
    'empty:0|~/Developer/Empty/||~/Developer/Empty/|~/Dev,~/Developer/|' \
    'an empty child must be a usable level with Back and current-folder actions'
}
test_case 'contextual directory picker drills down and returns without recursion' \
  _test_contextual_directory_picker_hierarchy

_test_navigation_fuzzy_ranking() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.navigation"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect_choices"
    typeset -ga _ZLE_UI_CHOICE_VALUES=(/tmp/swift-project /tmp/git-tools /tmp/project-swift)
    typeset -ga _ZLE_UI_CHOICE_LABELS=(swift-project git-tools project-swift)
    typeset -ga _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_ui_collect_choices swift 10
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect_choices"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_git_local"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect_choices"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_git_local"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
    _git_recent_branches "$2"
    result_status=$?
    print -r -- "$result_status|${(j:|:)_GIT_RECENT_BRANCHES}"
  ' "$TEST_REPO_ROOT" "$repository") || return
  test_assert_equal '0|recently-used|main|never-checked-out' "$output" \
    'an unvisited local branch was missing from the branch picker'
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
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    print -r -- "${ZSH_HIGHLIGHT_STYLES[command]}|${ZSH_HIGHLIGHT_STYLES[argument]}|${ZSH_HIGHLIGHT_STYLES[picker-selected-inactive]}|${ZSH_HIGHLIGHT_STYLES[picker-focus]}|${ZSH_PROMPT_COLORS[identity]}|${ZSH_PROMPT_COLORS[path]}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'fg=123,bold|fg=252|fg=252,bg=235|fg=75,bold|124|80' "$output" \
    'palette defaults replaced an explicit initializer role'
}
test_case 'palette owner fills missing roles without replacing local inputs' \
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_runtime_version zig "$3"
    [[ -e $2 ]]; executed=$(( !$? ))
    print -r -- "$REPLY|$executed"
  ' "$TEST_REPO_ROOT" "$sentinel" "$project") || return

  test_assert_equal 'not-installed|0' "$output" \
    'prompt executed a runtime resolved from the untrusted project'
}
test_case 'prompt never executes a runtime from the detected project' \
  _test_prompt_rejects_project_controlled_runtime

_test_prompt_disables_repository_git_filters() {
  test_make_temp_dir || return
  local repository="$TEST_TMP_DIR/repository"
  local filter="$TEST_TMP_DIR/filter" probe="$TEST_TMP_DIR/filter-ran"
  local output=''

  command git init -q "$repository" || return
  command git -C "$repository" config user.name 'Zsh Tests' || return
  command git -C "$repository" config user.email 'zsh-tests.invalid@example.invalid' || return
  test_write_file "$repository/.gitattributes" '*.txt filter=fixture' || return
  test_write_file "$repository/tracked.txt" 'baseline' || return
  command git -C "$repository" add .gitattributes tracked.txt || return
  command git -C "$repository" commit -qm baseline || return
  test_write_file "$filter" $'#!/bin/sh\n: > "$FILTER_PROBE"\n/bin/cat' || return
  command chmod +x "$filter" || return
  command git -C "$repository" config filter.fixture.clean "$filter" || return
  command git -C "$repository" config filter.fixture.required true || return
  # Keep the worktree size unchanged so status must compare filtered content
  # instead of deciding from the stat size alone.
  test_write_file "$repository/tracked.txt" 'changed!' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    export FILTER_PROBE=$2
    source "$1/.zsh.addons/.zsh.prompt"
    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_{capture_bounded,developer_dir}(N.); do source "$git_support_component"; done
    builtin cd -- "$3" || exit
    _prompt_git
    [[ -e $2 ]]; filter_ran=$(( !$? ))
    print -r -- "$filter_ran|$REPLY"
  ' "$TEST_REPO_ROOT" "$probe" "$repository") || return

  [[ $output == 0\|*'!1'* ]] ||
    test_fail "prompt executed a repository Git filter or lost status: $output"
}
test_case 'prompt Git status never executes repository filters' \
  _test_prompt_disables_repository_git_filters

# Status header counts are Git output: validate them as text, because integer
# assignment evaluates arithmetic ($(...) in a subscript runs) and 19 or more
# digits truncate or wrap.
_test_prompt_git_counts_stay_text_until_validated() {
  test_make_temp_dir || return
  local repository="$TEST_TMP_DIR/repository" fake_bin="$TEST_TMP_DIR/bin"
  local output='' exit_status=0
  command git init -q "$repository" || return
  test_write_file "$fake_bin/git" $'#!/bin/zsh -df\ncase " $* " in\n  (*" status "*) print -r -- "$FAKE_GIT_STATUS" ;;\n  (*) exec "$REAL_GIT" "$@" ;;\nesac' || return
  command chmod +x "$fake_bin/git" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    export REAL_GIT=${commands[git]}
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/.zsh.prompt"
    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_{capture_bounded,developer_dir}(N.); do source "$git_support_component"; done
    builtin cd -- "$3" || exit
    local header=$\'# branch.oid 0123456789abcdef\\n# branch.head main\\n# branch.upstream origin/main\'
    local counts=""
    for counts in \\
        \'# branch.ab +path[$(:>|$HOME/ahead-marker)1] -0\' \\
        \'# branch.ab +0 -path[$(:>|$HOME/behind-marker)1]\' \\
        \'# branch.ab +99999999999999999999 -0\' \\
        \'# stash path[$(: >| $HOME/stash marker)1]\' \\
        \'# stash 99999999999999999999\' \\
        $\'# branch.ab +2 -1\\n# stash 3\'; do
      export FAKE_GIT_STATUS=$header$\'\\n\'$counts
      _prompt_git
      print -r -- "$_PROMPT_GIT_TEXT"
    done
    local -a markers=($HOME/*marker(N)); print -r -- "markers:${#markers}"
  ' "$TEST_REPO_ROOT" "$fake_bin" "$repository" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
main ✓
main ✓
main ✓
main ✓
main ✓
main ≡3 ⇡2 ⇣1
markers:0' "status:$exit_status"$'\n'"$output" \
    'prompt Git counts were evaluated or accepted after overflowing'
}
test_case 'prompt Git counts stay text until validated' \
  _test_prompt_git_counts_stay_text_until_validated

# Prompt-time hooks read the shared UI's picker flags even when that UI is not
# installed. They compare the text, so a same-named variable inherited from the
# environment is never evaluated (arithmetic would run $(...) in a subscript).
_test_peers_read_inherited_picker_flags_as_text() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    local substitution='"'"'path[$(: >| $HOME/flag-marker)1]'"'"'
    export _ZLE_PICKER_ACTIVE=$substitution _ZLE_PICKER_SCREEN_ACTIVE=$substitution
    local peer=""
    for peer in editor highlighting prompt manual; do source "$1/.zsh.addons/.zsh.$peer"; done
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$support_component"; done
    local CONTEXT=start ZLE_RECURSIVE=0 BUFFER="print ok" CURSOR=8
    _zle_prompt_is_shell_editor; print -r -- "editor:$?"
    _manual_async_paint; print -r -- "manual:$?"
    _zle_syntax_highlight; print -r -- "highlight:$?"
    zle() { return 0; }
    TRAPWINCH; print -r -- "resize:$?"
    local -a markers=($HOME/*-marker(N)); print -r -- "markers:${#markers}"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
editor:0
manual:0
highlight:0
resize:0
markers:0' "status:$exit_status"$'\n'"$output" \
    'a peer evaluated an inherited picker flag as arithmetic'
}
test_case 'peers read inherited picker flags as text without the shared UI' \
  _test_peers_read_inherited_picker_flags_as_text

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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
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

# Without Apple's developer tools, the /usr/bin compilers, swift and python3
# are launchers that make macOS offer to install them. A C, Swift or Python
# project's prompt asks the developer-directory probe first (its seam,
# _compozsh_developer_dir, stands in for the machine) and shows the runtime as
# not installed without running the launcher, a link to one included, and
# remembers nothing; a python3 elsewhere on PATH still runs. With a developer
# directory the launchers are probed as before. The version-probe recorder
# answers for /usr/bin itself, so no real launcher runs here.
_test_prompt_runtime_launchers_without_developer_tools() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output='' exit_status=0
  test_write_file "$home/projects/c/CMakeLists.txt" 'project(fixture C)' || return
  test_write_file "$home/projects/c/main.c" 'int main(void) { return 0; }' || return
  test_write_file "$home/projects/swift/Package.swift" '// fixture' || return
  test_write_file "$home/projects/python/pyproject.toml" '[project]' || return
  test_write_file "$TEST_TMP_DIR/bin/python3" $'#!/bin/sh\nprintf "Python 3.99.0\\n"' || return
  command chmod +x "$TEST_TMP_DIR/bin/python3" || return
  command mkdir -p -- "$TEST_TMP_DIR/link" || return
  command ln -s /usr/bin/python3 "$TEST_TMP_DIR/link/python3" || return
  output=$(test_run_noninteractive "$home" '
    export PATH=/usr/bin:/bin
    setopt EXTENDED_GLOB
    local developer=none name="" item=""
    local -a report=() items=() probes=()
    source "$1/.zsh.addons/.zsh.prompt" || exit 1
    source "$1/tests/support.zsh"
    test_source_support "$1" || exit 1
    functions[_test_real_version_probe]=$functions[_prompt_version_probe]
    _prompt_version_probe() {
      if [[ ${1:A} == /usr/bin/* ]]; then
        print -r -- "${1:A}" >> "$HOME/probes"
      else
        print -r -- "stand-in ${1:t}" >> "$HOME/probes"
      fi
      case ${1:A} in
        (/usr/bin/python3) print -r -- "Python 3.9.6" ;;
        (/usr/bin/swift) print -r -- "Apple Swift version 6.2 (swiftlang-6.2.0.19.9)" ;;
        (/usr/bin/*) print -r -- "Apple clang version 17.0.0 (clang-1700.3.19.1)" ;;
        (*) _test_real_version_probe "$@" ;;
      esac
    }
    _compozsh_developer_dir() { [[ $developer != none ]] || return 1; REPLY=$developer; }
    _row() {
      : > "$HOME/probes"
      items=()
      for name in c swift python; do
        builtin cd -q -- "$HOME/projects/$name" || exit 2
        _prompt_project_context
        for item in "${_PROMPT_PROJECT_ITEMS[@]}"; do
          item=${item//\%F\{[^\}]##\}/}
          items+=("${item//\%f/}")
        done
      done
      probes=(${(f)"$(<$HOME/probes)"})
      (( ${#probes} )) || probes=(nothing)
      report+=("$1: ${(j:, :)items}" "$1 ran: ${(j:, :)probes}")
    }
    _row "no tools"
    PATH=$2:/usr/bin:/bin _row "no tools, linked python3"
    PATH=$3:/usr/bin:/bin _row "no tools, PATH python3"
    developer=/fixture/Developer _row "tools"
    print -rl -- "${report[@]}"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/link" "$TEST_TMP_DIR/bin" 2>&1) || exit_status=$?
  test_assert_equal 'status:0
no tools: c/c++ not-installed, cmake, swift not-installed, swiftpm, python not-installed
no tools ran: nothing
no tools, linked python3: c/c++ not-installed, cmake, swift not-installed, swiftpm, python not-installed
no tools, linked python3 ran: nothing
no tools, PATH python3: c/c++ not-installed, cmake, swift not-installed, swiftpm, python 3.99.0
no tools, PATH python3 ran: stand-in python3
tools: c/c++ clang 17.0.0, cmake, swift 6.2, swiftpm, python 3.9.6
tools ran: /usr/bin/c++, /usr/bin/swift, /usr/bin/python3' \
    "status:$exit_status"$'\n'"$output" \
    'a prompt runtime probe ran Apple'\''s launcher without developer tools'
}
test_case 'prompt runtime probes run no Apple launcher without developer tools' \
  _test_prompt_runtime_launchers_without_developer_tools

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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
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

_test_prompt_project_widths_follow_sanitized_terminal_cells() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/project" output=''
  test_write_file "$project/Package.swift" '// fixture' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_runtime_version() { REPLY=6.0; }
    _prompt_expected_runtime_version() { REPLY=$\'9\\u202e\'; }
    builtin cd -- "$2" || exit 1
    _prompt_project_context
    _compozsh_sanitize $\'⚠ swift wants 9\\u202e · using 6.0 — unverified\'
    local -i expected_width=${(m)#REPLY}
    print -r -- "${_PROMPT_PROJECT_ITEM_WIDTHS[-1]}|$expected_width"
  ' "$TEST_REPO_ROOT" "$project") || return

  test_assert_equal '41|41' "$output" \
    'project item width was measured before display sanitization'
}
test_case 'prompt project widths follow sanitized terminal cells' \
  _test_prompt_project_widths_follow_sanitized_terminal_cells

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

_test_prompt_resourcing_preserves_a_later_winch_wrapper() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    FUNCNEST=20
    typeset -gi VENDOR_WINCH_CALLS=0
    source "$1/.zsh.addons/.zsh.prompt"
    functions[_vendor_previous_winch]=${functions[TRAPWINCH]}
    TRAPWINCH() {
      (( ++VENDOR_WINCH_CALLS ))
      _vendor_previous_winch "$@"
    }
    local vendor_body=${functions[TRAPWINCH]}
    source "$1/.zsh.addons/.zsh.prompt"
    [[ ${functions[TRAPWINCH]} == "$vendor_body" ]] || exit 1
    TRAPWINCH || exit 2
    print -r -- "$VENDOR_WINCH_CALLS"
  ' "$TEST_REPO_ROOT" 2>/dev/null) || return

  test_assert_equal 1 "$output" \
    'prompt re-source recursively rewrapped a later WINCH owner'
}
test_case 'prompt re-source preserves a later WINCH wrapper without recursion' \
  _test_prompt_resourcing_preserves_a_later_winch_wrapper

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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
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
