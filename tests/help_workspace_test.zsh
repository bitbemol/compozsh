_test_help_workspace_topics() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    local -a _HELP_TOPIC_LABELS=() _HELP_TOPIC_TEXTS=()
    local _HELP_DESCRIPTION="" _HELP_USAGE=""
    local text=$'"'"'usage: example [--safe]\nExplain this tool.\n\nOptions:\n  --safe  Keep literal $(never-run) and %F{red}.\n  Continuation preserves details.\n  --other <path>  Another option.\n\nSafety:\n  No writes occur.\n\nExamples:\n  example --safe  Read only.'"'"'
    _compozsh_help_topics "$text" || exit 1
    [[ $_HELP_DESCRIPTION == "Explain this tool." && $_HELP_USAGE == "usage: example [--safe]" ]] || exit 2
    [[ $_HELP_TOPIC_LABELS[1] == Overview && ${_HELP_TOPIC_LABELS[(Ie)--safe]} != 0 &&
       ${_HELP_TOPIC_LABELS[(Ie)Safety]} != 0 && ${_HELP_TOPIC_LABELS[(Ie)Examples]} != 0 ]] || exit 3
    local index=${_HELP_TOPIC_LABELS[(Ie)--safe]}
    [[ $_HELP_TOPIC_TEXTS[index] == *'"'"'$(never-run)'"'"'* && $_HELP_TOPIC_TEXTS[index] == *"Continuation preserves details."* &&
       $_HELP_TOPIC_TEXTS[index] != *"Another option"* ]] || exit 4
    index=${_HELP_TOPIC_LABELS[(Ie)Options]}
    [[ $_HELP_TOPIC_TEXTS[index] == *"Another option"* ]] || exit 5
    _compozsh_help_topics "$text"$'"'"'\n\nExamples:\n  example --other ./file\n\nOptions:\n  --safe  Second description.'"'"'
    [[ ${#${(M)_HELP_TOPIC_LABELS:#Examples}} == 1 && ${#${(M)_HELP_TOPIC_LABELS:#--safe}} == 1 ]] || exit 7
    index=${_HELP_TOPIC_LABELS[(Ie)--safe]}
    [[ $_HELP_TOPIC_TEXTS[index] == *"Continuation preserves details."* && $_HELP_TOPIC_TEXTS[index] == *"Second description."* ]] || exit 8
    _compozsh_help_topics "${(r:40000::x:)text}"
    [[ $_HELP_TOPIC_TEXTS[-1] == *"32,768"* ]] || exit 6
    print topics
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal topics "$output"
}
test_case 'help workspace derives overview options and complete sections from literal bounded text' _test_help_workspace_topics

_test_help_workspace_surface() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.help"
    COLUMNS=120 LINES=30 _ZLE_PICKER_SCREEN_ACTIVE=1
    _zle_picker_loop() {
      (( _ZLE_PICKER_REFERENCE_VIEW && !_ZLE_PICKER_DOCUMENT )) || return 10
      [[ $_ZLE_PICKER_SUBTITLE == "Explain this tool." && $_ZLE_PICKER_QUERY_LABEL == "Find a topic" ]] || return 11
      _compozsh_help_collect "writes" 10
      [[ ${#_ZLE_PICKER_RESULTS} == 1 ]] || return 12
      _compozsh_help_collect "" 10
      _zle_picker_render "" 1
      (( _ZLE_PICKER_DISPLAY_LEFT_ENDS[2] > 0 && _ZLE_PICKER_DISPLAY_LEFT_ENDS[2] < 45 )) || return 13
      [[ $_ZLE_PICKER_INSPECT_ROLES[3] == text ]] || return 17
      [[ $_ZLE_PICKER_POSTDISPLAY != *never-run* ]] || return 14
      COLUMNS=40 _ZLE_PICKER_INSPECT_FOCUS=1
      _zle_picker_render "" 1
      [[ ${(j:|:)_ZLE_PICKER_INSPECT_LINES} == *"Explain this tool."* ]] || return 15
      return 1
    }
    _compozsh_help_workspace $'"'"'usage: example\nExplain this tool.\n\nSafety:\n  No writes occur.'"'"'
    [[ $? == 1 && ${_ZLE_PICKER_REFERENCE_VIEW:-0} == 0 && ! ${+parameters[_HELP_TOPIC_TEXTS]} == 1 ]] || exit 16
    print surface
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal surface "$output"
}
test_case 'help workspace shares primary reader geometry and scopes topic state' _test_help_workspace_surface

_test_help_workspace_dispatch() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/.zsh.help"
    _compozsh_help_show() { print -r -- "${(j: :)@}"; }
    for tool in mkcd cpdir g external-device xcode compozsh; do
      [[ $("$tool" --help) == "_compozsh_help_$tool" ]] || exit 1
    done
    [[ $(external-device --flash --help) == "_compozsh_help_external-device flash" &&
       $(external-device --format --help) == "_compozsh_help_external-device format" &&
       $(xcode --export-skills --help) == "_compozsh_help_xcode export-skills" &&
       $(compozsh --refresh --help) == "_compozsh_help_compozsh" &&
       $(compozsh --sudo-touch-id --help) == "_compozsh_help_compozsh sudo-touch-id" &&
       $(compozsh help g) == "_compozsh_help_g" ]] || exit 2
    print dispatch
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal dispatch "$output"
}
test_case 'help workspace receives every owned public help mode without executing operations' _test_help_workspace_dispatch

_test_help_workspace_argument_index() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.tools"
    local -a _HELP_TOPIC_LABELS=() _HELP_TOPIC_TEXTS=()
    local _HELP_USAGE="" _HELP_DESCRIPTION="" label=""
    _compozsh_help_topics "$(_compozsh_help_g)"
    for label in "--review [base head]" --worktree --discard-all; do
      (( ${_HELP_TOPIC_LABELS[(Ie)$label]} )) || exit 1
    done
    _compozsh_help_topics "$(_compozsh_help_mkcd)"
    (( ${_HELP_TOPIC_LABELS[(Ie)<directory>]} )) || exit 2
    _compozsh_help_collect "complete guide" 20
    [[ ${#_ZLE_PICKER_RESULTS} == 1 ]] || exit 3
    print arguments
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal arguments "$output"
}
test_case 'help workspace indexes explicit Git modes and positional arguments' _test_help_workspace_argument_index

_test_help_workspace_argument_colors() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.help"
    _zle_picker_loop() {
      local label="" id=""
      for label in "--review [base head]" "<directory>" status; do
        id=${_HELP_TOPIC_LABELS[(Ie)$label]}
        [[ ${_ZLE_PICKER_LABEL_HIGHLIGHTS[$id]-} == "0:${#label}:picker-header" ]] || {
          print -u2 -- "missing help argument color: $label"; return 8
        }
      done
      for label in Overview Options Safety "Complete guide"; do
        id=${_HELP_TOPIC_LABELS[(Ie)$label]}
        [[ -z ${_ZLE_PICKER_LABEL_HIGHLIGHTS[$id]-} ]] || return 9
      done
      _compozsh_help_collect "--review" 20
      id=${_HELP_TOPIC_LABELS[(Ie)--review [base head]]}
      local -i row=${_ZLE_PICKER_RESULTS[(Ie)$id]}
      (( row )) && [[ $_ZLE_PICKER_LABELS[row] == "--review [base head]" ]] || return 10
      COLUMNS=36 LINES=18
      _zle_picker_render "--review" "$row"
      [[ $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[row] == *:picker-header &&
         $_ZLE_PICKER_DISPLAY[row] != *$'\''\e'\''* ]] || return 11
      return 1
    }
    _compozsh_help_workspace $'\''usage: example\nRead the guide.\n\nOptions:\n  --review [base head]  Review changes.\n  <directory>  Select a folder.\n  status  Read status.\n\nSafety:\n  No writes.'\''
    [[ $? == 1 && ${#_ZLE_PICKER_LABEL_HIGHLIGHTS} == 0 ]] || exit 1
    _zle_picker_label_highlight_style picker-header 0
    [[ $REPLY == "$ZSH_HIGHLIGHT_STYLES[picker-header]" ]] || exit 2
    ZSH_HIGHLIGHT_STYLES[picker-header]=fg=125,bold
    _zle_picker_label_highlight_style picker-header 0
    [[ $REPLY == fg=125,bold ]] || exit 3
    local selected="" focus=0
    for selected in "fg=16,bg=75,bold" "fg=231,bg=25,bold" "fg=252,bg=238"; do
      for focus in 1 2; do
        _zle_picker_label_highlight_style picker-header "$focus" "$selected"
        [[ $REPLY == "$selected" ]] || exit 4
      done
    done
    print colors
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal colors "$output"
}
test_case 'help workspace argument colors use the shared palette and preserve selection and literal targets' _test_help_workspace_argument_colors

_test_help_workspace_explanation_colors() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/.zsh.help"
    local -i _ZLE_PICKER_REFERENCE_VIEW=1 _ZLE_PICKER_DOCUMENT=0
    local -A _ZLE_PICKER_INSPECT_TEXTS=(topic "  --discard-all  Preview and confirm loss.")
    _zle_picker_inspect_prepare topic 80
    [[ $_ZLE_PICKER_INSPECT_SYNTAX[1] == "2:15:picker-header " &&
       $_ZLE_PICKER_INSPECT_ROLES[1] == text ]] || {
      print -u2 -- "missing right-pane argument accent: $_ZLE_PICKER_INSPECT_SYNTAX[1]"; exit 1
    }
    local text=$'\''usage: demo [--review] <base>\n  demo --review  Read only.\nRead 界 --review and --help, literally $(never-run).\n  --review <base head>  Explain values.'\''
    _ZLE_PICKER_INSPECT_TEXTS[topic]=$text
    local -i width=0 row=0 start=0 end=0
    local span="" colored="" line=""
    local -a fields=()
    for width in 80 17 9; do
      _ZLE_PICKER_INSPECT_KEY=""
      _zle_picker_inspect_prepare topic "$width"
      colored=""
      for (( row=1; row<=${#_ZLE_PICKER_INSPECT_LINES}; ++row )); do
        line=$_ZLE_PICKER_INSPECT_LINES[row]
        for span in ${=_ZLE_PICKER_INSPECT_SYNTAX[row]}; do
          fields=( "${(@s.:.)span}" )
          start=$fields[1] end=$fields[2]
          colored+=${line[$((start+1)),$end]}
        done
      done
      [[ ${colored// /} == "--review<base>demo--review--review--help--review<basehead>" ]] || {
        print -u2 -- "misaligned help accents at width $width: $colored"; exit 2
      }
      [[ ${(j::)_ZLE_PICKER_INSPECT_LINES} == *'\''$(never-run)'\''* ]] || exit 3
    done
    local MATCH=preserved MBEGIN=7 MEND=9
    local -a match=(preserved) mbegin=(7) mend=(9) reply=()
    _zle_picker_help_spans "${(pl:4000:: --help:)}"
    (( ${#reply} == 128 )) || exit 6
    [[ $MATCH == preserved && $MBEGIN == 7 && $MEND == 9 &&
       $match[1] == preserved && $mbegin[1] == 7 && $mend[1] == 9 ]] || exit 7
    _zle_picker_loop() {
      [[ $_ZLE_PICKER_REFERENCE_VIEW == "$expected" ]] || return 10
      _zle_ui_text_collect --help 10
      _zle_picker_inspect_prepare text 20
      if (( expected )); then
        [[ ${(j::)_ZLE_PICKER_INSPECT_SYNTAX} == *picker-header* ]] || return 11
      else
        [[ -z ${(j::)_ZLE_PICKER_INSPECT_SYNTAX} ]] || return 12
      fi
      return 1
    }
    local expected=1
    _zle_ui_read_text Help Captured "$text" reference
    [[ $? == 1 ]] || exit 4
    expected=0
    _zle_ui_read_text Draft Literal "$text"
    [[ $? == 1 ]] || exit 5
    print explanation-colors
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal explanation-colors "$output"
}
test_case 'help workspace explanation colors survive wrapping filtering and reader isolation' _test_help_workspace_explanation_colors
