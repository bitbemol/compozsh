_test_alias_compound_coverage() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$unit"; done
    aliases[ap]="print -r expanded"
    aliases[bp]="print second"
    aliases[trail]="print -r "
    galiases[GG]="GLOBAL"
    saliases[demo]="cat"
    local draft="" position=0
    for draft in "ap | bp" "A=private-value ap && bp" "(ap; bp)" "if ap; then bp; fi"; do
      _prompt_interaction_model "$draft"
      position=${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}
      [[ $position != 0 && ${_PROMPT_INTERACTION_VALUES[$position]} == *"print -r expanded"* &&
         ${_PROMPT_INTERACTION_VALUES[$position]} == *"print second"* &&
         ${_PROMPT_INTERACTION_VALUES[*]} != *private-value* ]] || {
        print -u2 -r -- "compound alias previews missing for $draft"; exit 1
      }
    done
    for draft in "time ap" "A=private-value ap" "trail ap"; do
      _prompt_interaction_model "$draft"
      position=${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}
      [[ $position != 0 && ${_PROMPT_INTERACTION_VALUES[$position]} == *"print -r expanded"* ]] || exit 2
    done
    for draft in "print GG" "cat < GG"; do
      _prompt_interaction_model "$draft"
      position=${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}
      [[ $position != 0 && ${_PROMPT_INTERACTION_VALUES[$position]} == *GLOBAL* ]] || exit 3
    done
    _prompt_interaction_model "ap | sample.demo"
    position=${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}
    [[ $position != 0 && ${_PROMPT_INTERACTION_VALUES[$position]} == *"sample.demo → cat"* ]] || exit 4
    for draft in "print ap" "command ap" "builtin ap" "noglob ap" "exec ap" "nocorrect ap" "env ap" "\"ap\"" "\\ap" "print \"GG\"" "# ap"; do
      _prompt_interaction_model "$draft"
      (( ! ${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]} )) || {
        print -u2 -r -- "alias preview incorrectly claimed expansion for $draft"; exit 5
      }
    done
    unsetopt ALIASES
    _prompt_interaction_model ap
    (( ! ${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]} )) || {
      print -u2 "disabled alias expansion was presented as active"; exit 6
    }
    _prompt_interaction_model "env git status"
    local expected_kind=$_PROMPT_INTERACTION_KIND
    local -a expected_values=("${_PROMPT_INTERACTION_VALUES[@]}")
    aliases[env]="print environment-alias"
    _prompt_interaction_model "env git status"
    [[ $_PROMPT_INTERACTION_KIND == "$expected_kind" &&
       "${(j:|:)_PROMPT_INTERACTION_VALUES}" == "${(j:|:)expected_values}" ]] || {
      print -u2 "disabled alias changed native precommand classification"; exit 7
    }
    BUFFER=ap COLUMNS=120 LINES=24
    _prompt_interaction_update ap || :
    (( ! ${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]} )) || {
      print -u2 "prompt update lost the caller alias option during emulation"; exit 8
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'alias coverage previews command positions global arguments and compound drafts literally' _test_alias_compound_coverage

_test_alias_expansion_position() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.navigation"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$unit"; done
    aliases[work]="cd ~/Projects/example"
    aliases[rm]="rm -i"
    galiases[GG]="GLOBAL"
    saliases[demo]="cat"
    _PROMPT_FULL_PATH_TEXT="~/Projects/current"
    _PROMPT_GIT_TEXT="main"
    local draft="" width=0 height=0
    local -a rows=()
    for draft in .. ... .... la ll work "work extra" "work | la" "print GG" sample.demo "rm file"; do
      _prompt_interaction_model "$draft"
      [[ ${_PROMPT_INTERACTION_LABELS[-1]} == EXPANSION ]] || {
        print -u2 -r -- "inconsistent expansion position for $draft: ${_PROMPT_INTERACTION_LABELS[*]}"; exit 1
      }
      for width in 100 40; do
        for height in 24 4; do
          COLUMNS=$width LINES=$height
          _prompt_interaction_layout
          rows=("${(@f)_PROMPT_INTERACTION_SEGMENT}")
          [[ $rows[-1] == *EXPANSION* ]] || {
            print -u2 -r -- "expansion was not the final visible row for $draft at $width x $height"; exit 2
          }
        done
      done
    done
    [[ $_PROMPT_INTERACTION_KIND == caution &&
       ${_PROMPT_INTERACTION_VALUES[*]} == *file* ]] || exit 3
    LINES=3
    _prompt_interaction_layout
    rows=("${(@f)_PROMPT_INTERACTION_SEGMENT}")
    [[ $rows[-1] == *ACTION* && $_PROMPT_INTERACTION_SEGMENT != *EXPANSION* ]] || {
      print -u2 "consistent expansion placement displaced the warning in a one-row prompt"; exit 4
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'alias expansion uses a consistent bottom row with warnings retained in short prompts' _test_alias_expansion_position
