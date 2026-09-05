# Palette defaults have one source; consumers adapt current roles at runtime.

_test_palette_owner_provisions_both_schemes() {
  test_make_temp_dir || return
  local scheme='' output='' expected=''
  for scheme in dark light; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$scheme" $'
      ZSH_COLOR_SCHEME=$2
      zstyle ":completion:*" list-colors sentinel
      source "$1/.zsh.addons/support/.zsh.appearance"
      local -a colors=()
      zstyle -a ":completion:*" list-colors colors
      [[ $colors == sentinel ]] || exit 1
      (( !${+_COMPOZSH_COLOR_MANAGED} )) || exit 2
      (( ${#_COMPOZSH_COMPLETION_LIST_COLORS} == 15 )) || exit 3
      print -r -- "${ZSH_HIGHLIGHT_STYLES[command]}|${ZSH_HIGHLIGHT_STYLES[picker-selected]}|${ZSH_PROMPT_COLORS[success]}|${ZSH_OUTPUT_COLORS[text]}|$LSCOLORS"
    ' "$TEST_REPO_ROOT" "$scheme") || return
    if [[ $scheme == dark ]]; then
      expected='fg=77,bold|fg=255,bg=238,bold|71|252|ExFxgxDxCxBxbxHbHfadabdx'
    else
      expected='fg=22,bold|fg=235,bg=189,bold|22|236|exfxgxdxcxbxbxhbhfadabdx'
    fi
    test_assert_equal "$expected" "$output" || return
  done
}
test_case 'palette ownership appearance alone provisions either scheme without completion effects' \
  _test_palette_owner_provisions_both_schemes

_test_palette_consumers_never_install_defaults() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    typeset -gA ZSH_PROMPT_COLORS=(path 123)
    typeset -gA ZSH_OUTPUT_COLORS=(custom 124)
    typeset -gA ZSH_HIGHLIGHT_STYLES=(command "fg=125,bold")
    local peer=""
    for peer in prompt output highlighting shell; do
      source "$1/.zsh.addons/.zsh.$peer"
      source "$1/.zsh.addons/.zsh.$peer"
    done
    (( ${#ZSH_PROMPT_COLORS} == 1 && ${#ZSH_OUTPUT_COLORS} == 1 && ${#ZSH_HIGHLIGHT_STYLES} == 1 )) || exit 1
    (( !${+LSCOLORS} && !${+_COMPOZSH_COLOR_MANAGED} )) || exit 2
    [[ -z $_PROMPT_GIT_COLOR && -z $_PROMPT_SYMBOL_COLOR ]] || exit 3
    _output_color custom || exit 4
    [[ $REPLY == 124 ]] || exit 5
    if _output_color missing 75; then exit 6; fi
    [[ -z $REPLY ]] || exit 7
    _prompt_color path || exit 8
    [[ $REPLY == 123 ]] || exit 9
    print -r -- consumer-readers
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal consumer-readers "$output"
}
test_case 'palette ownership independent consumers preserve explicit maps and remain neutral' \
  _test_palette_consumers_never_install_defaults

_test_palette_deleted_and_invalid_roles_resolve_at_runtime() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    ZSH_COLOR_SCHEME=light
    typeset -gA ZSH_OUTPUT_COLORS=(success 71)
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.output"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.highlighting"
    unset "ZSH_OUTPUT_COLORS[text]" "ZSH_PROMPT_COLORS[path]" "ZSH_HIGHLIGHT_STYLES[command]"
    _output_color text || exit 1
    [[ $REPLY == 236 ]] || exit 2
    _prompt_color path || exit 3
    [[ $REPLY == 25 ]] || exit 4
    local -a region_highlight=()
    _zle_add_highlight 0 2 command
    [[ $region_highlight == "0 2 fg=22,bold memo=compozsh" ]] || exit 5
    ZSH_OUTPUT_COLORS[heading]=invalid
    ZSH_PROMPT_COLORS[identity]="%F{red}"
    _output_color heading || exit 6
    [[ $REPLY == 25 ]] || exit 7
    _prompt_color identity || exit 8
    [[ $REPLY == 24 ]] || exit 9
    local peer=""
    for peer in output prompt highlighting; do source "$1/.zsh.addons/.zsh.$peer"; done
    (( !${+ZSH_OUTPUT_COLORS[text]} && !${+ZSH_PROMPT_COLORS[path]} && !${+ZSH_HIGHLIGHT_STYLES[command]} )) || exit 10
    source "$1/.zsh.addons/support/.zsh.appearance"
    [[ ${ZSH_OUTPUT_COLORS[text]} == 236 && ${ZSH_OUTPUT_COLORS[success]} == 71 && ${ZSH_OUTPUT_COLORS[heading]} == invalid ]] || exit 11
    print -r -- runtime-fallbacks
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal runtime-fallbacks "$output"
}
test_case 'palette ownership deletion and malformed roles use current central defaults without consumer writes' \
  _test_palette_deleted_and_invalid_roles_resolve_at_runtime

_test_palette_absence_native_adapters() {
  test_make_temp_dir || return
  local output='' fake_bin="$TEST_TMP_DIR/bin"
  test_write_file "$fake_bin/man" $'#!/bin/zsh\nprint -r -- "${LESS_TERMCAP_md-unset}|${LESS_TERMCAP_mb-unset}|${LESS_TERMCAP_us-unset}|${LESS_TERMCAP_so-unset}"' || return
  command chmod +x "$fake_bin/man" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.output"
    local -a reply=()
    _output_lldb_color_arguments
    (( !${#reply} )) || exit 1
    _output_git_color_arguments
    (( !${#_OUTPUT_GIT_COLOR_CONFIG} )) || exit 2
    ZSH_OUTPUT_COLORS[heading]=25
    ZSH_OUTPUT_COLORS[warning]=invalid
    _output_lldb_color_arguments
    (( ${#reply} == 4 )) || exit 3
    [[ ${(j:|:)reply} == *"38;5;25m"* && ${(j:|:)reply} != *"38;5;m"* ]] || exit 4
    _output_git_color_arguments
    [[ ${(j:|:)_OUTPUT_GIT_COLOR_CONFIG} == *"color.diff.meta=25"* && ${(j:|:)_OUTPUT_GIT_COLOR_CONFIG} != *"color.diff.frag="* ]] || exit 5
    unset "ZSH_OUTPUT_COLORS[heading]"
    path=("$2" $path)
    local result=$(man example)
    [[ $result != *"38;5;"* ]] || exit 6
    LESS_TERMCAP_md="" LESS_TERMCAP_mb=custom result=$(man example)
    [[ $result == "|custom|"* ]] || exit 7
    print -r -- native-absence
  ' "$TEST_REPO_ROOT" "$fake_bin") || return
  test_assert_equal native-absence "$output"
}
test_case 'palette ownership native adapters omit unavailable colors and preserve explicit terminal overrides' \
  _test_palette_absence_native_adapters

_test_palette_late_appearance_updates_existing_renderers() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.highlighting"
    _PROMPT_PATH_TEXT="sample%path"
    _PROMPT_TOP_BASE_WIDTH=0
    _PROMPT_GIT_TEXT=""
    local -a region_highlight=()
    _zle_add_highlight 0 2 command || :
    (( !${#region_highlight} )) || exit 1
    _prompt_layout || :
    [[ $_PROMPT_PATH_SEGMENT == "sample%%path" ]] || exit 2
    _prompt_base
    [[ $PROMPT != *"%F{}"* && $PROMPT != *%F\{[0-9]* ]] || exit 3
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    _zle_add_highlight 0 2 command
    [[ $region_highlight == "0 2 fg=22,bold memo=compozsh" ]] || exit 4
    _prompt_layout || :
    [[ $_PROMPT_PATH_SEGMENT == "%F{25}sample%%path%f" ]] || exit 5
    unset "ZSH_PROMPT_COLORS[frame]" "ZSH_PROMPT_COLORS[path]"
    ZSH_PROMPT_COLORS[identity]="%F{red}"
    _prompt_layout || :
    _prompt_base
    [[ $_PROMPT_PATH_SEGMENT == "%F{25}sample%%path%f" &&
       $PROMPT == *'${_PROMPT_CONTEXT_SEGMENT}'* &&
       $PROMPT == *'${_PROMPT_INPUT_SEGMENT}'* &&
       $PROMPT != *"%F{red}"* && -z $RPROMPT ]] || exit 6
    (( !${+ZSH_PROMPT_COLORS[frame]} && !${+ZSH_PROMPT_COLORS[path]} )) || exit 7
    print -r -- late-appearance
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal late-appearance "$output"
}
test_case 'palette ownership rendering before appearance does not cache absent or invalid roles' \
  _test_palette_late_appearance_updates_existing_renderers

_test_palette_explicit_empty_syntax_override() {
  test_make_temp_dir || return
  local scheme='' output=''
  for scheme in dark light; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$scheme" $'
      ZSH_COLOR_SCHEME=$2
      typeset -gA ZSH_HIGHLIGHT_STYLES=(comment "")
      source "$1/.zsh.addons/support/.zsh.appearance"
      source "$1/.zsh.addons/.zsh.highlighting"
      local -a region_highlight=()
      _zle_add_highlight 0 8 comment || :
      (( !${#region_highlight} )) || {
        print -u2 -r -- "explicit empty comment override acquired a highlight"
        exit 1
      }
      unset "ZSH_HIGHLIGHT_STYLES[comment]"
      _zle_add_highlight 0 8 comment || exit 2
      [[ $region_highlight == "0 8 ${_COMPOZSH_COLOR_FALLBACKS[highlight:comment]} memo=compozsh" ]] || exit 3
      region_highlight=()
      ZSH_HIGHLIGHT_STYLES[comment]=""
      source "$1/.zsh.addons/support/.zsh.appearance"
      source "$1/.zsh.addons/.zsh.highlighting"
      _zle_add_highlight 0 8 comment || :
      (( !${#region_highlight} && ${+ZSH_HIGHLIGHT_STYLES[comment]} )) || exit 4
      [[ -z ${ZSH_HIGHLIGHT_STYLES[comment]} ]] || exit 5
      print -r -- empty-syntax-preserved
    ' "$TEST_REPO_ROOT" "$scheme") || return
    test_assert_equal empty-syntax-preserved "$output" || return
  done
}
test_case 'palette ownership explicit empty syntax overrides suppress highlighting while absent roles recover defaults' \
  _test_palette_explicit_empty_syntax_override

_test_palette_project_extension_default() {
  test_make_temp_dir || return
  local scheme='' output=''
  for scheme in dark light; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$scheme" '
      source "$1/.zsh.addons/.zsh.prompt"
      local -a _PROMPT_PROJECT_EXTRA_SEGMENTS=() _PROMPT_PROJECT_EXTRA_WIDTHS=()
      prompt_add_project_segment "tool 50%"
      [[ $_PROMPT_PROJECT_EXTRA_SEGMENTS[1] == "tool 50%%" ]] || {
        print -u2 -- "missing appearance forced a color on the extension"; exit 1
      }
      ZSH_COLOR_SCHEME=$2
      source "$1/.zsh.addons/support/.zsh.appearance"
      prompt_add_project_segment "tool 50%"
      [[ $_PROMPT_PROJECT_EXTRA_SEGMENTS[2] == "%F{${ZSH_PROMPT_COLORS[tool]}}tool 50%%%f" ]] || {
        print -u2 -- "extension did not consume the selected tool role"; exit 2
      }
      ZSH_PROMPT_COLORS[tool]=123
      prompt_add_project_segment customized ""
      [[ $_PROMPT_PROJECT_EXTRA_SEGMENTS[3] == "%F{123}customized%f" ]] || exit 3
      prompt_add_project_segment explicit white
      [[ $_PROMPT_PROJECT_EXTRA_SEGMENTS[4] == "%F{white}explicit%f" ]] || exit 4
      unset "ZSH_PROMPT_COLORS[tool]"
      prompt_add_project_segment removed
      [[ $_PROMPT_PROJECT_EXTRA_SEGMENTS[5] == "%F{${_COMPOZSH_COLOR_FALLBACKS[prompt:tool]}}removed%f" ]] || exit 5
      [[ ${(j:|:)_PROMPT_PROJECT_EXTRA_WIDTHS} == "8|8|10|8|7" ]] || exit 6
      print shared
    ' "$TEST_REPO_ROOT" "$scheme") || return
    test_assert_equal shared "$output" || return
  done
}
test_case 'palette project extensions resolve omitted colors at invocation and preserve explicit native colors' \
  _test_palette_project_extension_default
