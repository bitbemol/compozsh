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
    source "$1/.zsh.addons/.zsh.appearance"
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
        source "$1/.zsh.addons/.zsh.appearance"
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
        source "$1/.zsh.addons/.zsh.appearance"
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
    'light|fg=231,bg=25,bold|fg=236,bg=194|28|25|160|exfxgxdxcxbxbxhbhfadabdx' \
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
        source "$1/.zsh.addons/.zsh.appearance"
        source "$1/.zsh.addons/.zsh.editor"
        ;;
      appearance-last)
        source "$1/.zsh.addons/.zsh.editor"
        source "$1/.zsh.addons/.zsh.appearance"
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
  test_assert_contains "$expected" 'ex=1;38;5;28' \
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
    source "$1/.zsh.addons/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.editor"
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
    source "$1/.zsh.addons/.zsh.appearance"
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
    source "$1/.zsh.addons/.zsh.appearance"
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
      source "$1/.zsh.addons/.zsh.appearance"
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
    source "$1/.zsh.addons/.zsh.appearance"
    ZSH_COLOR_SCHEME=dark
    source "$1/.zsh.addons/.zsh.appearance"
    print -r -- "$_COMPOZSH_COLOR_SCHEME|${ZSH_OUTPUT_COLORS[text]}"

    unset _COMPOZSH_COLOR_SCHEME
    ZSH_COLOR_SCHEME=""
    source "$1/.zsh.addons/.zsh.appearance"
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
    source "$1/.zsh.addons/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.editor"
    _zle_picker_output_color heading 75
    heading=$REPLY
    _zle_picker_output_color info 111
    info=$REPLY
    ZSH_OUTPUT_COLORS[warning]=invalid
    _zle_picker_output_color warning 221
    print -r -- "$heading|$info|$REPLY"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal '25|24|130' "$output" \
    'standalone editor ignored adaptive output roles or accepted a malformed override'
}
test_case 'editor degrades to adaptive output roles when output peer is disabled' \
  _test_editor_uses_light_output_roles_without_output_peer
