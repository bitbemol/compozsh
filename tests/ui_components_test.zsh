# Shared UI ownership, optional editor integration and scoped view contracts.

_test_ui_components_have_one_owner() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    (( !${+functions[_zle_picker_render]} && !${+functions[_zle_picker_run]} )) || exit 1
    source "$1/.zsh.addons/support/.zsh.ui"
    zmodload zsh/parameter
    for component in _zle_picker_titlebar _zle_picker_footer _zle_picker_guide_render \
        _zle_picker_inspect_render _zle_picker_render _zle_picker_show \
        _zle_picker_loop _zle_picker_screen_session _zle_picker_run _zle_ui_view; do
      [[ ${functions_source[$component]} == "$1/.zsh.addons/support/.zsh.ui" ]] || exit 2
    done
    [[ ${widgets[compozsh-picker-init]} == user:_zle_picker_line_init ]] || exit 3
    (( !${zle_line_init_functions[(Ie)_zle_picker_line_init]:-0} )) || exit 4
    print -r -- owned
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal owned "$output"
}
test_case 'UI components have one owner and nested entry has its own native widget' \
  _test_ui_components_have_one_owner

_test_ui_components_missing_editor_fallbacks() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    zle() { print -r -- "$*"; }
    BUFFER="./" CURSOR=2
    _history_fuzzy_search_widget
    _directory_context_complete_widget
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'.history-incremental-search-backward\nexpand-or-complete' \
    "$output" 'missing UI did not preserve native editing'
}
test_case 'UI components are optional for normal history and directory completion' \
  _test_ui_components_missing_editor_fallbacks

_test_ui_components_scoped_view_defaults() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_DOCUMENT_FOLLOW=1
    _ZLE_PICKER_COPY_ENABLED=1 _ZLE_PICKER_REFRESH_ENABLED=1 _ZLE_PICKER_INSPECT_FALLBACK=secret-context
    _ZLE_PICKER_INSPECT_TEXTS=(outer "outer document")
    _ui_test_choice() {
      (( !_ZLE_PICKER_DOCUMENT && !_ZLE_PICKER_READER_ONLY &&
          _ZLE_PICKER_DOCUMENT_FOLLOW == -1 && !_ZLE_PICKER_COPY_ENABLED &&
          !_ZLE_PICKER_REFRESH_ENABLED && _ZLE_PICKER_DIGIT_SELECT == 1 )) || return 2
      [[ -z $_ZLE_PICKER_INSPECT_FALLBACK && ${#_ZLE_PICKER_INSPECT_TEXTS} == 0 ]] || return 3
      _ZLE_PICKER_INSPECT_TEXTS=(inner "inner details")
      _ZLE_PICKER_SELECTED_VALUE="literal selection"
      _ZLE_PICKER_ACTION=select
      _ZLE_PICKER_BOOKMARK=(query 2 1)
    }
    _zle_ui_view choice _ui_test_choice || exit 1
    (( _ZLE_PICKER_DOCUMENT && _ZLE_PICKER_READER_ONLY && _ZLE_PICKER_DOCUMENT_FOLLOW == 1 &&
        _ZLE_PICKER_COPY_ENABLED && _ZLE_PICKER_REFRESH_ENABLED )) || exit 2
    [[ $_ZLE_PICKER_INSPECT_FALLBACK == secret-context &&
       ${_ZLE_PICKER_INSPECT_TEXTS[outer]} == "outer document" &&
       ${#_ZLE_PICKER_INSPECT_TEXTS} == 1 &&
       $_ZLE_PICKER_SELECTED_VALUE == "literal selection" &&
       ${(j:|:)_ZLE_PICKER_BOOKMARK} == "query|2|1" ]] || exit 3
    _ui_test_query() {
      [[ $_ZLE_PICKER_COLLECTOR == _zle_picker_query_collect ]] || return 1
      (( _ZLE_PICKER_QUERY_SUBMIT && !_ZLE_PICKER_DIGIT_SELECT && !_ZLE_PICKER_DOCUMENT ))
    }
    _zle_ui_view query _ui_test_query || exit 4
    print -r -- scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'UI components scope view defaults while preserving operation and bookmark outputs' \
  _test_ui_components_scoped_view_defaults

_test_ui_components_neutral_palette_fallback() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '\
    source "$1/.zsh.addons/support/.zsh.ui"
    _zle_picker_style picker-selected
    print -r -- "$REPLY"
    _zle_picker_style picker-selected-inactive
    print -r -- "$REPLY"
    _zle_picker_review_style added
    print -r -- "$REPLY"
    _zle_picker_output_color warning 221
    print -r -- "${REPLY}|$?"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'standout,bold\nunderline\nnone\n|1' "$output" \
    'missing appearance retained a duplicated colored palette or lost selection cues'
}
test_case 'UI components retain neutral focus cues without a duplicate fallback palette' \
  _test_ui_components_neutral_palette_fallback

_test_ui_components_neutral_overlay() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    _zle_picker_label_highlight_style picker-size 1 "fg=231,bg=24,bold"
    [[ $REPLY == *fg=231* && $REPLY == *bg=24* && $REPLY != *none* ]] || exit 1
    _zle_ui_overlay_style "fg=231,bg=22" none
    [[ $REPLY == "fg=231,bg=22" ]] || exit 2
    _zle_ui_overlay_style "fg=231,bg=22" "fg=189,bg=52,bold"
    [[ $REPLY == *fg=189* && $REPLY == *bg=22* &&
       $REPLY != *fg=231* && $REPLY != *bg=52* ]] || exit 3
    print -r -- preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'UI components compose semantic overlays without losing the selected row surface' \
  _test_ui_components_neutral_overlay

_test_ui_completion_reads_palette_at_invocation() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    LS_COLORS="di=38;5;123:ex=38;5;124"
    local -a colors=()
    zstyle -a ":completion:*" list-colors colors
    [[ ${(j:|:)colors} == "di=38;5;123|ex=38;5;124" ]] || exit 1
    unset LS_COLORS
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    zstyle -a ":completion:*" list-colors colors
    [[ ${(j:|:)colors} == *"di=1;38;5;25"* ]] || exit 2
    zstyle ":completion:*" list-colors "di=38;5;128"
    source "$1/.zsh.addons/support/.zsh.appearance"
    zstyle -a ":completion:*" list-colors colors
    [[ ${(j:|:)colors} == "di=38;5;128" ]] || exit 3
    print -r -- deferred
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal deferred "$output"
}
test_case 'UI completion resolves current palette data without appearance overwriting registrations' \
  _test_ui_completion_reads_palette_at_invocation

_test_ui_command_views_clear_previous_reader() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_QUERY_SUBMIT=1
    _ZLE_PICKER_IDLE_CALLBACK=outer _ZLE_PICKER_INSPECT_FIXED_KEY=outer
    _ZLE_PICKER_PASSIVE_LINES=(outer)
    _compozsh_tool_inspector_capture() { _ZLE_PICKER_INSPECT_TEXTS=(tool help); }
    _git_branch_inspector_capture() { _ZLE_PICKER_INSPECT_TEXTS=(branch details); }
    _GIT_RECENT_BRANCHES=(branch) _GIT_RECENT_CURRENT=branch
    local fixture=tools result=0
    _zle_picker_run() {
      (( !_ZLE_PICKER_DOCUMENT && !_ZLE_PICKER_READER_ONLY && !_ZLE_PICKER_QUERY_SUBMIT &&
          !_ZLE_PICKER_COPY_ENABLED && _ZLE_PICKER_DIGIT_SELECT )) || return 31
      [[ -z $_ZLE_PICKER_IDLE_CALLBACK && -z $_ZLE_PICKER_INSPECT_FIXED_KEY &&
         ${#_ZLE_PICKER_PASSIVE_LINES} == 0 ]] || return 32
      if [[ $fixture == tools ]]; then
        [[ $_ZLE_PICKER_TITLE == "Tool explorer" && ${_ZLE_PICKER_INSPECT_TEXTS[tool]} == help ]] || return 33
      else
        [[ $_ZLE_PICKER_TITLE == Branches && ${_ZLE_PICKER_INSPECT_TEXTS[branch]} == details &&
           $_NAVIGATION_PICKER_VALUES[1] == branch ]] || return 34
      fi
      _ZLE_PICKER_SELECTED_VALUE=literal _ZLE_PICKER_ACTION=select
      return 17
    }
    _compozsh_choose; result=$?
    (( result == 17 )) || exit 1
    fixture=branches
    _git_branch_choose /example ""; result=$?
    (( result == 17 )) || exit 2
    [[ $_ZLE_PICKER_DOCUMENT == 1 && $_ZLE_PICKER_IDLE_CALLBACK == outer &&
       $_ZLE_PICKER_SELECTED_VALUE == literal ]] || exit 3
    print isolated
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal isolated "$output"
}
test_case 'UI direct tool and branch views clear prior reader capabilities before entry' \
  _test_ui_command_views_clear_previous_reader

_test_ui_palette_source_order_and_resource_convergence() {
  test_make_temp_dir || return
  local scheme='' overrides='' order='' output='' expected=''
  for scheme in dark light; do
    for overrides in defaults custom; do
      expected=''
      for order in lexical reverse rotate-left rotate-right; do
        output=$(test_run_interactive "$TEST_TMP_DIR/home-$scheme-$overrides-$order" '
          ZSH_COLOR_SCHEME=$2
          if [[ $3 == custom ]]; then
            typeset -gA ZSH_PROMPT_COLORS=(path 123)
            typeset -gA ZSH_OUTPUT_COLORS=(heading 124)
            typeset -gA ZSH_HIGHLIGHT_STYLES=(command "" picker-selected "fg=125,bg=24,bold")
          fi
          local -a files=("$1"/.zsh.addons/**/.zsh.?*(N.)) colors=()
          case $4 in
            reverse) files=("${(Oa)files[@]}") ;;
            rotate-left) files=("${(@)files[2,-1]}" "$files[1]") ;;
            rotate-right) files=("$files[-1]" "${(@)files[1,-2]}") ;;
          esac
          _ui_state() {
            local role=""
            local -a prompt_pre_redraw_hooks=() prompt_finish_hooks=()
            for role in ${(ok)_COMPOZSH_COLOR_FALLBACKS}; do
              print -r -- "$role=${_COMPOZSH_COLOR_FALLBACKS[$role]}"
            done
            for role in ${(ok)ZSH_HIGHLIGHT_STYLES}; do
              print -r -- "$role=${ZSH_HIGHLIGHT_STYLES[$role]}"
            done
            _prompt_base
            print -r -- "$PROMPT|$RPROMPT"
            _zle_picker_style picker-selected
            print -r -- "$REPLY"
            _zle_picker_review_style added
            print -r -- "$REPLY"
            _output_color heading
            print -r -- "$REPLY"
            zstyle -a ":completion:*" list-colors colors
            print -r -- "${(j:|:)colors}"
            print -r -- "$LSCOLORS|${widgets[compozsh-picker-init]}|${widgets[compozsh-picker]}"
            print -r -- "${precmd_functions[*]}|${preexec_functions[*]}|${zle_line_init_functions[*]}|${zle_line_pre_redraw_functions[*]}"
            zstyle -a zle-line-pre-redraw widgets prompt_pre_redraw_hooks
            zstyle -a zle-line-finish widgets prompt_finish_hooks
            prompt_pre_redraw_hooks=("${(@)prompt_pre_redraw_hooks#<->:}")
            prompt_finish_hooks=("${(@)prompt_finish_hooks#<->:}")
            print -r -- "${(j:,:)prompt_pre_redraw_hooks}|${(j:,:)prompt_finish_hooks}|${widgets[compozsh-context-lens]-}"
            bindkey "^R"
            bindkey "^I"
            bindkey "^[i"
          }
          local file="" first="" second=""
          for file in "${files[@]}"; do source "$file" || exit 1; done
          zmodload zsh/parameter
          first=$(_ui_state)
          for file in "${files[@]}"; do source "$file" || exit 2; done
          second=$(_ui_state)
          [[ $first == "$second" ]] || { print -u2 "re-source changed configured UI"; exit 3; }
          print -r -- "$second"
        ' "$TEST_REPO_ROOT" "$scheme" "$overrides" "$order") || return
        if [[ -z $expected ]]; then expected=$output
        else test_assert_equal "$expected" "$output" "$scheme $overrides $order changed configured UI" || return
        fi
      done
    done
  done
}
test_case 'UI and palette converge across four peer orders and double sourcing in both schemes' \
  _test_ui_palette_source_order_and_resource_convergence
