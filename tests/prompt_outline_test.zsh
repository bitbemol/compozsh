_test_prompt_outline_color() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    local COLUMNS=120 LINES=30 kind="" expected="" row=""
    local -A roles=(ready success run info caution danger git git navigate path environment environment build tool test tool)
    ZSH_PROMPT_COLORS=(success 2 info 4 danger 1 git 3 path 6 environment 5 tool 13 frame 8)
    _PROMPT_VIEW=compact _PROMPT_INTERACTION_ACTIVE=1 _PROMPT_SYMBOL_COLOR=6
    _PROMPT_PROJECT_ITEMS=("%F{13}swift%f") _PROMPT_PROJECT_ITEM_WIDTHS=(5)
    _PROMPT_INTERACTION_LABELS=("COMMAND TEXT" @TOOLCHAIN)
    _PROMPT_INTERACTION_VALUES=(example captured)
    _PROMPT_INTERACTION_ROLES=(info tool)
    for kind in ${(k)roles}; do
      _PROMPT_INTERACTION_KIND=$kind
      expected=$ZSH_PROMPT_COLORS[$roles[$kind]]
      _prompt_interaction_layout
      _prompt_base
      [[ $PROMPT == "%F{$expected}╭─ ${(U)kind}%f"* ]] || exit 1
      for row in "${(@f)_PROMPT_INTERACTION_SEGMENT[1,-1]}"; do
        [[ $row == *│* ]] || continue
        [[ $row == "%F{$expected}│%f%F{8}"* ]] || {
          print -u2 -r -- "wrong $kind outline: $row"
          exit 2
        }
      done
      [[ $_PROMPT_INPUT_SEGMENT == "%F{$expected}╰─%f %F{6}❯%f " ]] || exit 3
      [[ $PROMPT == *"%F{8}  COMMAND TEXT    %f %F{4}example%f"* ]] || exit 4
      [[ $PROMPT == *"%F{8}  TOOLCHAIN%f %F{13}swift%f"* ]] || exit 5
    done
    # Missing palette remains plain; no color may leak into labels or values.
    ZSH_PROMPT_COLORS=()
    _prompt_interaction_layout
    [[ $_PROMPT_INTERACTION_SEGMENT == "╭─ "* && $_PROMPT_INTERACTION_SEGMENT == *"│  COMMAND TEXT"* ]] || exit 6
  ' "$TEST_REPO_ROOT"
}
test_case 'living prompt outline follows its header role without recoloring labels values or input' _test_prompt_outline_color
