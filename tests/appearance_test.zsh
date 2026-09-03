# Terminal appearance detection and palette-selection contracts.

_test_light_palette_preserves_initializer_roles() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    ZSH_COLOR_SCHEME=light
    typeset -gA ZSH_HIGHLIGHT_STYLES=(command "fg=77,bold")
    typeset -gA ZSH_PROMPT_COLORS=(identity 109)
    typeset -gA ZSH_OUTPUT_COLORS=(success 71)
    LSCOLORS=ExFxgxDxCxBxbxHbHfadabdx
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.output"
    source "$1/.zsh.addons/.zsh.shell"
    print -r -- "$_COMPOZSH_COLOR_SCHEME|${ZSH_HIGHLIGHT_STYLES[command]}|${ZSH_HIGHLIGHT_STYLES[argument]}|${ZSH_PROMPT_COLORS[identity]}|${ZSH_PROMPT_COLORS[path]}|${ZSH_OUTPUT_COLORS[success]}|${ZSH_OUTPUT_COLORS[text]}|$LSCOLORS"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal \
    'light|fg=77,bold|fg=236|109|25|71|236|ExFxgxDxCxBxbxHbHfadabdx' \
    "$output" 'light palette replaced explicit initializer roles'
}
test_case 'light palette fills missing roles and preserves initializer choices' \
  _test_light_palette_preserves_initializer_roles

_test_automatic_light_palette_is_order_independent() {
  test_make_temp_dir || return
  local mode='' output='' expected=''
  local script=$'
    COLORFGBG="0;15"
    case $2 in
      appearance-first)
        source "$1/.zsh.addons/support/.zsh.appearance"
        source "$1/.zsh.addons/.zsh.highlighting"
        source "$1/.zsh.addons/.zsh.output"
        source "$1/.zsh.addons/.zsh.prompt"
        source "$1/.zsh.addons/.zsh.shell"
        ;;
      appearance-last)
        source "$1/.zsh.addons/.zsh.shell"
        source "$1/.zsh.addons/.zsh.prompt"
        source "$1/.zsh.addons/.zsh.output"
        source "$1/.zsh.addons/.zsh.highlighting"
        source "$1/.zsh.addons/support/.zsh.appearance"
        ;;
    esac
    ZSH_OUTPUT_COLORS[error]=invalid
    _output_color error 203
    print -r -- "$_COMPOZSH_COLOR_SCHEME|${ZSH_HIGHLIGHT_STYLES[picker-selected]}|${ZSH_HIGHLIGHT_STYLES[review-added]}|${ZSH_PROMPT_COLORS[success]}|${ZSH_OUTPUT_COLORS[heading]}|$REPLY|$LSCOLORS"
  '

  for mode in appearance-first appearance-last; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$mode" "$script" \
      "$TEST_REPO_ROOT" "$mode") || return
    if [[ -z $expected ]]; then
      expected=$output
    else
      test_assert_equal "$expected" "$output" \
        'appearance peer changed semantics with peer load order' || return
    fi
  done

  test_assert_equal \
    'light|fg=231,bg=24,bold|fg=236,bg=194|22|25|160|exfxgxdxcxbxbxhbhfadabdx' \
    "$expected" 'terminal light signal did not select the coherent light palette'
}
test_case 'automatic light palette converges in every peer load order' \
  _test_automatic_light_palette_is_order_independent

_test_light_completion_colors_are_order_independent() {
  test_make_temp_dir || return
  local mode='' output='' expected=''
  local script=$'
    ZSH_COLOR_SCHEME=light
    case $2 in
      appearance-first)
        source "$1/.zsh.addons/support/.zsh.appearance"
        source "$1/.zsh.addons/.zsh.editor"
        source "$1/.zsh.addons/support/.zsh.ui"
        ;;
      appearance-last)
        source "$1/.zsh.addons/.zsh.editor"
        source "$1/.zsh.addons/support/.zsh.ui"
        source "$1/.zsh.addons/support/.zsh.appearance"
        ;;
    esac
    local -a colors=()
    zstyle -a ":completion:*" list-colors colors
    print -r -- "${(j:|:)colors}"
  '

  for mode in appearance-first appearance-last; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$mode" "$script" \
      "$TEST_REPO_ROOT" "$mode") || return
    if [[ -z $expected ]]; then
      expected=$output
    else
      test_assert_equal "$expected" "$output" \
        'completion colors changed with peer load order' || return
    fi
  done

  test_assert_contains "$expected" 'di=1;38;5;25' \
    'light completion palette retained the bright dark-background directory color' || return
  test_assert_contains "$expected" 'ex=1;38;5;22' \
    'light completion palette retained the bright dark-background executable color'
}
test_case 'light completion file colors converge in every peer load order' \
  _test_light_completion_colors_are_order_independent

_test_completion_colors_preserve_ls_colors() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    ZSH_COLOR_SCHEME=light
    LS_COLORS="di=38;5;123:ex=38;5;124"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    local -a colors=()
    zstyle -a ":completion:*" list-colors colors
    print -r -- "${(j:|:)colors}"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal 'di=38;5;123|ex=38;5;124' "$output" \
    'adaptive completion replaced an explicit LS_COLORS palette'
}
test_case 'adaptive completion preserves an explicit LS_COLORS palette' \
  _test_completion_colors_preserve_ls_colors

_test_light_manual_selection_uses_contrasting_text() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/man" $'#!/bin/zsh\nif [[ $LESS_TERMCAP_so == *"38;5;231;48;5;25m" ]]; then\n  print -r -- contrasting-selection\nelse\n  print -r -- noncontrasting-selection\nfi' || return
  command chmod +x "$fake_bin/man" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    path=("$2" $path)
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.output"
    man example
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_equal contrasting-selection "$output" \
    'light manual selection used dark text on the deep selection background'
}
test_case 'light manual selection uses contrasting text and background roles' \
  _test_light_manual_selection_uses_contrasting_text

_test_color_scheme_detection_precedence_and_index_classification() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/.zsh.appearance"
    local index classifications=""
    for index in 9 12 15 16 231 232 255; do
      _appearance_scheme_from_color_index "$index"
      classifications+="${classifications:+,}$index:$REPLY"
    done
    COLORFGBG="15;0"
    ZSH_COLOR_SCHEME=auto
    _appearance_detect_color_scheme
    indexed=$REPLY
    COLORFGBG="0;15"
    ZSH_COLOR_SCHEME=dark
    _appearance_detect_color_scheme
    explicit=$REPLY
    ZSH_COLOR_SCHEME=unsupported
    _appearance_detect_color_scheme
    invalid=$REPLY
    COLORFGBG="0;1;255"
    ZSH_COLOR_SCHEME=auto
    _appearance_detect_color_scheme
    multifield=$REPLY
    COLORFGBG="0;bogus"
    _appearance_detect_color_scheme
    malformed=$REPLY
    print -r -- "$classifications|$indexed|$explicit|$invalid|$multifield|$malformed"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal '9:dark,12:dark,15:light,16:dark,231:light,232:dark,255:light|dark|dark|dark|light|dark' \
    "$output" 'appearance detection lost indexed-color classification or override precedence'
}
test_case 'appearance detection classifies passive indexed colors and honors explicit mode' \
  _test_color_scheme_detection_precedence_and_index_classification

_test_appearance_source_preserves_queued_terminal_input() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    zmodload zsh/zpty || exit 2
    zmodload zsh/zselect || exit 2
    _appearance_test_driver() {
      unset COLORFGBG
      ZSH_COLOR_SCHEME=auto
      SSH_CONNECTION="example"
      TMUX="example"
      TERM=screen-256color
      local gate="" queued=""
      IFS= read -r -k 1 gate || exit 6
      source "$1/.zsh.addons/support/.zsh.appearance"
      IFS= read -r -k 8 queued || exit 7
      print -r -- "RESULT:$_COMPOZSH_COLOR_SCHEME:$queued"
    }
    local chunk="" trace="" pty_fd=0
    local -i attempts=0
    zpty -b appearance _appearance_test_driver "$1" || exit 3
    pty_fd=$REPLY
    zpty -w -n appearance xsentinel
    for (( attempts = 0; attempts < 50; ++attempts )); do
      zselect -r $pty_fd -t 1 || continue
      while zpty -r appearance chunk; do trace+=$chunk; done
      [[ $trace == *RESULT:* ]] && break
    done
    zpty -d appearance
    trace=${trace//$'\''\r'\''/}
    trace=${trace%$'\''\n'\''}
    [[ $trace == "RESULT:dark:sentinel" ]] || {
      print -u2 -r -- "appearance source emitted output or consumed queued input: ${(qqq)trace}"
      exit 5
    }
    print -r -- terminal-input-preserved
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal terminal-input-preserved "$output" \
    'appearance source wrote to the terminal or consumed queued user input'
}
test_case 'appearance source performs no terminal I/O and preserves queued input' \
  _test_appearance_source_preserves_queued_terminal_input

_test_scheme_selection_is_one_shot_and_preserves_empty_initializer_value() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    ZSH_COLOR_SCHEME=dark
    source "$1/.zsh.addons/support/.zsh.appearance"
    print -r -- "$_COMPOZSH_COLOR_SCHEME|${ZSH_OUTPUT_COLORS[text]}"

    unset _COMPOZSH_COLOR_SCHEME
    ZSH_COLOR_SCHEME=""
    source "$1/.zsh.addons/support/.zsh.appearance"
    print -r -- "${+ZSH_COLOR_SCHEME}|${(qqq)ZSH_COLOR_SCHEME}|$_COMPOZSH_COLOR_SCHEME"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal $'light|236\n1|""|dark' "$output" \
    'appearance re-source changed the selected scheme or replaced an empty initializer value'
}
test_case 'appearance selection is one-shot and preserves initializer ownership' \
  _test_scheme_selection_is_one_shot_and_preserves_empty_initializer_value

_test_editor_uses_light_output_roles_without_output_peer() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    _zle_picker_output_color heading 75
    heading=$REPLY
    _zle_picker_output_color info 111
    info=$REPLY
    ZSH_OUTPUT_COLORS[warning]=invalid
    _zle_picker_output_color warning 221
    print -r -- "$heading|$info|$REPLY"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal '25|24|94' "$output" \
    'standalone editor ignored adaptive output roles or accepted a malformed override'
}
test_case 'editor degrades to adaptive output roles when output peer is disabled' \
  _test_editor_uses_light_output_roles_without_output_peer

_test_palette_owners_restore_selected_scheme_after_unset() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    for peer in highlighting prompt output shell; do
      source "$1/.zsh.addons/.zsh.$peer" || exit 1
    done
    # Consumers read central fallbacks; only appearance fills public keys again.
    ZSH_HIGHLIGHT_STYLES[command]="fg=123"
    ZSH_PROMPT_COLORS[path]=123
    ZSH_OUTPUT_COLORS[heading]=123
    LSCOLORS=custom
    for mode in role palette; do
      if [[ $mode == role ]]; then
        unset "ZSH_HIGHLIGHT_STYLES[command]" "ZSH_PROMPT_COLORS[path]" \
          "ZSH_OUTPUT_COLORS[heading]" LSCOLORS
      else
        unset ZSH_HIGHLIGHT_STYLES ZSH_PROMPT_COLORS ZSH_OUTPUT_COLORS LSCOLORS
      fi
      for peer in highlighting prompt output shell; do
        source "$1/.zsh.addons/.zsh.$peer" || exit 2
      done
      source "$1/.zsh.addons/support/.zsh.appearance" || exit 2
      [[ ${ZSH_HIGHLIGHT_STYLES[command]} == "fg=22,bold" &&
         ${ZSH_PROMPT_COLORS[path]} == 25 &&
         ${ZSH_OUTPUT_COLORS[heading]} == 25 &&
         $LSCOLORS == exfxgxdxcxbxbxhbhfadabdx ]] || {
        print -u2 -r -- "removing $mode restored colors from another scheme"
        exit 3
      }
    done
    # Re-sourcing the sole owner must still preserve later user choices.
    ZSH_HIGHLIGHT_STYLES[command]="fg=124"
    ZSH_PROMPT_COLORS[path]=124
    ZSH_OUTPUT_COLORS[heading]=124
    LSCOLORS=custom
    source "$1/.zsh.addons/support/.zsh.appearance"
    [[ ${ZSH_HIGHLIGHT_STYLES[command]} == "fg=124" &&
       ${ZSH_PROMPT_COLORS[path]} == 124 &&
       ${ZSH_OUTPUT_COLORS[heading]} == 124 && $LSCOLORS == custom ]] || exit 4
    print -r -- selected-scheme-restored
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal selected-scheme-restored "$output"
}
test_case 'palette owner restores the selected scheme after public overrides are removed' \
  _test_palette_owners_restore_selected_scheme_after_unset

_test_status_header_uses_selected_output_palette() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    BUFFER="" PREDISPLAY="" POSTDISPLAY=""
    _ZLE_PICKER_STATUS_VIEW=1 _ZLE_PICKER_HEADER=Working
    _ZLE_PICKER_DISPLAY=()
    # Capture the frame at the paint boundary, before normal cleanup removes it.
    zle() { captured=("${region_highlight[@]}"); }
    local -a captured=()
    local mode expected
    for mode in standalone output custom explicit; do
      expected="fg=25,bold"
      case $mode in
        output) source "$1/.zsh.addons/.zsh.output" ;;
        custom) ZSH_OUTPUT_COLORS[heading]=123; expected="fg=123,bold" ;;
        explicit)
          ZSH_HIGHLIGHT_STYLES[picker-status-heading]="fg=124,underline"
          expected="fg=124,underline" ;;
      esac
      _zle_picker_show || exit 1
      [[ ${(j:|:)captured} == *" $expected memo=my-zsh-picker"* ]] || {
        print -u2 -r -- "$mode status header ignored its palette: ${(j:|:)captured}"
        exit 2
      }
    done
    print -r -- status-palette-preserved
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal status-palette-preserved "$output"
}
test_case 'light status header shares output roles and preserves explicit styling' \
  _test_status_header_uses_selected_output_palette

_test_appearance_malformed_hints_remain_inert() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.appearance"
    ZSH_COLOR_SCHEME=AuTo
    local hint="" expected="" REPLY=""
    for hint expected in \
      "0;00015" light "0;0000000000000000000000000000255" light \
      "0;08" dark "0;256" dark "0;" dark "0;-1" dark \
      "0;99999999999999999999999999999999999999" dark \
      "0;15+0" dark "0;16#ff" dark "0;15 " dark \
      '\''0;$(print unexpected)'\'' dark \
      "0;"$'\''\e[31m15'\'' dark; do
      COLORFGBG=$hint
      _appearance_detect_color_scheme
      [[ $REPLY == $expected ]] || exit 1
    done
    print -r -- hints-remain-inert
  ' "$TEST_REPO_ROOT" 2>&1) || return

  test_assert_equal hints-remain-inert "$output" \
    'passive hint parsing emitted diagnostics, evaluated text, or selected the wrong palette'
}
test_case 'appearance treats malformed and padded passive hints as inert text' \
  _test_appearance_malformed_hints_remain_inert

_test_manual_selection_contrasts_with_custom_heading() {
  test_make_temp_dir || return
  local output='' fake_bin="$TEST_TMP_DIR/bin"
  test_write_file "$fake_bin/man" '#!/bin/zsh
    print -rn -- "$LESS_TERMCAP_so"
  ' || return
  command chmod +x "$fake_bin/man" || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.output"
    local background expected actual
    # The foreground follows the background luminance, including midtone colors,
    # rather than the shell scheme or numeric color-index order.
    for background expected in 231 16 16 231 62 231 244 16; do
      ZSH_OUTPUT_COLORS[heading]=$background
      actual=$(man example)
      [[ $actual == $'\''\e[1;38;5;'\''"$expected;48;5;${background}m" ]] || {
        print -u2 -r -- "manual selection has the wrong foreground on $background"
        exit 1
      }
    done
    ZSH_OUTPUT_COLORS[heading]=1
    [[ $(man example) == $'\''\e[7m'\'' ]] || exit 2
    LESS_TERMCAP_so=custom
    [[ $(man example) == custom ]] || exit 3
    print -r -- manual-selection-contrast
  ' "$TEST_REPO_ROOT" "$fake_bin") || return
  test_assert_equal manual-selection-contrast "$output"
}
test_case 'manual selection adapts to custom backgrounds and preserves explicit standout styles' \
  _test_manual_selection_contrasts_with_custom_heading

_test_editor_review_fallback_contrast() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/tests/appearance_support.zsh"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local row="" token="" background="" row_style="" field=""
    for row in added removed; do
      _zle_picker_review_style "$row"
      row_style=$REPLY
      _test_palette_assert_style "standalone $row" "$row_style" 16 7 || exit 1
      for field in "${(@s:,:)row_style}"; do
        [[ $field == bg=* ]] && background=${field#bg=}
      done
      for token in keyword string number comment type function variable; do
        _zle_picker_review_style "$token"
        _test_palette_assert_style "standalone $row $token" "$REPLY" "$background" || exit 2
      done
    done
    print readable-fallbacks
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal readable-fallbacks "$output"
}
test_case 'appearance supplies readable shared UI review colors without other consumer peers' \
  _test_editor_review_fallback_contrast
