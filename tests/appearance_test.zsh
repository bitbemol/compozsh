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

_test_color_scheme_detection_precedence_and_rgb() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.appearance"
    _appearance_scheme_from_rgb $'\''\e]11;rgb:ffff/eeee/dddd\a'\''
    bright=$REPLY
    _appearance_scheme_from_rgb $'\''\e]11;rgb:1111/2222/3333\a'\''
    dark=$REPLY
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
    print -r -- "$bright|$dark|$indexed|$explicit|$invalid"
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal 'light|dark|dark|dark|dark' "$output" \
    'appearance detection lost RGB, terminal fallback, or override precedence'
}
test_case 'appearance detection classifies terminal RGB and honors explicit mode' \
  _test_color_scheme_detection_precedence_and_rgb

_test_terminal_background_query_selects_light() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    zmodload zsh/zpty || exit 2
    zmodload zsh/zselect || exit 2
    _appearance_test_driver() {
      COLORFGBG="15;0"
      source "$1/.zsh.addons/.zsh.appearance"
      print -r -- "RESULT:$_COMPOZSH_COLOR_SCHEME:${ZSH_OUTPUT_COLORS[text]}"
    }
    local chunk="" trace="" pty_fd=0
    local -i answered=0 attempts=0
    zpty -b appearance _appearance_test_driver "$1" || exit 3
    pty_fd=$REPLY
    for (( attempts = 0; attempts < 20; ++attempts )); do
      zselect -r $pty_fd -t 1 || continue
      while zpty -r appearance chunk; do trace+=$chunk; done
      if (( !answered )) && [[ $trace == *$'\''\e]11;?\a'\''* ]]; then
        zpty -w -n appearance $'\''\e]11;rgb:ffff/ffff/ffff\a'\''
        answered=1
      fi
      [[ $trace == *RESULT:* ]] && break
    done
    zpty -d appearance
    (( answered )) || {
      print -u2 -r -- "missing OSC 11 query: ${(qqq)trace}"
      exit 4
    }
    [[ $trace == *"RESULT:light:236"* ]] || {
      print -u2 -r -- "unexpected appearance result: ${(qqq)trace}"
      exit 5
    }
    print -r -- terminal-query-light
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal terminal-query-light "$output" \
    'OSC 11 response did not select the light palette through a real PTY'
}
test_case 'terminal background query selects light through a real PTY' \
  _test_terminal_background_query_selects_light
