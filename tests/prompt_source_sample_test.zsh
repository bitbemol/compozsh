# A bounded sample retains separate filenames when conventional sources saturate.
_test_prompt_saturated_sample_languages() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    command mkdir -p "$HOME/project"
    local -i index=0
    for (( index=1; index<=65; ++index )); do
      print -r -- fixture > "$HOME/project/$index.c"
      print -r -- fixture > "$HOME/project/$index.swift"
    done
    # Any 128 of these 130 entries contain both languages, regardless of
    # filesystem enumeration order. No sorting or broader scan is needed.
    _prompt_scan_source_languages "$HOME/project"
    (( _PROMPT_SOURCE_SCAN_SATURATED &&
       ${#_PROMPT_SOURCE_SCAN_LANGUAGES} == 2 &&
       ${_PROMPT_SOURCE_SCAN_LANGUAGES[(Ie)c-cpp]} &&
       ${_PROMPT_SOURCE_SCAN_LANGUAGES[(Ie)swift]} )) || {
      print -u2 -- "saturated sample lost distinct source languages"; exit 1
    }
    local -a runtime_languages=()
    _prompt_runtime_version() { runtime_languages+=("$1"); REPLY=1.0; }
    builtin cd "$HOME/project"
    _prompt_project_context
    (( _PROMPT_RESOLVED_SOURCE_SCAN_SATURATED &&
       ${runtime_languages[(Ie)c-cpp]} && ${runtime_languages[(Ie)swift]} &&
       ${#_PROMPT_PROJECT_ITEMS} == 2 )) || exit 2
    [[ $_PROMPT_PROJECT_NAME_TEXT == project ]] || exit 3
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'prompt saturated source samples preserve every observed language through full project context' \
  _test_prompt_saturated_sample_languages
