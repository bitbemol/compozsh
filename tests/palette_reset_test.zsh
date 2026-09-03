# Runtime palette resets must not turn role names into arithmetic subscripts.

_test_palette_reset_consumer() {
  test_make_temp_dir || return
  local peer=$1 scheme='' table_state='' output=''
  local -i result=0
  for scheme in dark light; do
    for table_state in absent scalar indexed; do
      result=0
      output=$(test_run_interactive "$TEST_TMP_DIR/home-$peer-$scheme-$table_state" '
        ZSH_COLOR_SCHEME=$3
        source "$1/.zsh.addons/support/.zsh.appearance"
        source "$1/.zsh.addons/.zsh.$2"
        local peer=$2 expected="" role=""
        case $peer in
          prompt) role=path; expected=${_COMPOZSH_COLOR_FALLBACKS[prompt:path]} ;;
          output) role=heading; expected=${_COMPOZSH_COLOR_FALLBACKS[output:heading]} ;;
          highlighting) role=global-alias; expected=${_COMPOZSH_COLOR_FALLBACKS[highlight:global-alias]} ;;
        esac
        unset ZSH_PROMPT_COLORS ZSH_OUTPUT_COLORS ZSH_HIGHLIGHT_STYLES
        case $4 in
          scalar)
            ZSH_PROMPT_COLORS=123 ZSH_OUTPUT_COLORS=124 ZSH_HIGHLIGHT_STYLES=invalid ;;
          indexed)
            typeset -ga ZSH_PROMPT_COLORS=(123) ZSH_OUTPUT_COLORS=(124) ZSH_HIGHLIGHT_STYLES=(invalid) ;;
        esac
        local prompt_type=${(t)ZSH_PROMPT_COLORS} output_type=${(t)ZSH_OUTPUT_COLORS}
        local highlight_type=${(t)ZSH_HIGHLIGHT_STYLES}
        local prompt_value=${ZSH_PROMPT_COLORS-} output_value=${ZSH_OUTPUT_COLORS-}
        local highlight_value=${ZSH_HIGHLIGHT_STYLES-}
        # These ordinary variables must never be expanded as arithmetic when
        # a formerly associative palette has been removed or replaced.
        local heading="two words" global="two words" alias="two words"
        local -a region_highlight=()
        local -i result=0
        case $peer in
          prompt) _prompt_color "$role" || exit 1; [[ $REPLY == "$expected" ]] || exit 2 ;;
          output) _output_color "$role" || exit 1; [[ $REPLY == "$expected" ]] || exit 2 ;;
          highlighting)
            _zle_add_highlight 0 9 "$role" || exit 1
            [[ $region_highlight == "0 9 $expected memo=compozsh" ]] || exit 2 ;;
        esac
        unset _COMPOZSH_COLOR_FALLBACKS
        region_highlight=()
        case $peer in
          prompt) _prompt_color "$role" || result=$? ;;
          output) _output_color "$role" || result=$? ;;
          highlighting) _zle_add_highlight 0 9 "$role" || result=$? ;;
        esac
        (( result == 1 )) || exit 3
        if [[ $peer == highlighting ]]; then
          (( !${#region_highlight} )) || exit 4
        else
          [[ -z $REPLY ]] || exit 4
        fi
        [[ ${(t)ZSH_PROMPT_COLORS} == "$prompt_type" &&
           ${(t)ZSH_OUTPUT_COLORS} == "$output_type" &&
           ${(t)ZSH_HIGHLIGHT_STYLES} == "$highlight_type" &&
           ${ZSH_PROMPT_COLORS-} == "$prompt_value" &&
           ${ZSH_OUTPUT_COLORS-} == "$output_value" &&
           ${ZSH_HIGHLIGHT_STYLES-} == "$highlight_value" ]] || exit 5
        (( !${+_COMPOZSH_COLOR_FALLBACKS} )) || exit 6
        print preserved
      ' "$TEST_REPO_ROOT" "$peer" "$scheme" "$table_state" 2>| "$TEST_TMP_DIR/stderr") || result=$?
      test_assert_equal '' "$(<"$TEST_TMP_DIR/stderr")" "$peer $scheme $table_state emitted diagnostics" || return
      test_assert_equal 0 "$result" "$peer $scheme $table_state failed after palette reset" || return
      test_assert_equal preserved "$output" || return
    done
  done
}

_test_palette_reset_prompt() { _test_palette_reset_consumer prompt; }
test_case 'palette reset prompt reads central or native colors without recreating public tables' \
  _test_palette_reset_prompt

_test_palette_reset_output() { _test_palette_reset_consumer output; }
test_case 'palette reset output reads central or native colors without recreating public tables' \
  _test_palette_reset_output

_test_palette_reset_highlighting() { _test_palette_reset_consumer highlighting; }
test_case 'palette reset syntax roles remain literal without recreating public tables' \
  _test_palette_reset_highlighting
