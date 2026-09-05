_test_template_is_inert() {
  emulate -L zsh
  setopt EXTENDED_GLOB

  local line=''

  while IFS= read -r line; do
    [[ -z ${line//[[:space:]]/} || $line == [[:space:]]#\#* ]] ||
      test_fail "templates/init.zsh contains active code: $line" || return
  done < "$TEST_REPO_ROOT/templates/init.zsh"

  "$TEST_ZSH_BIN" -n "$TEST_REPO_ROOT/templates/init.zsh" ||
    test_fail 'templates/init.zsh does not parse as Zsh'
}
test_case 'initializer starter is valid and completely inert' \
  _test_template_is_inert

_test_noninteractive_bootstrap_guard() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" \
    'source "$1/.zshrc"; print -r -- ${+functions[mkcd]}' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal 0 "$output" 'non-interactive shell loaded add-ons'
}
test_case 'non-interactive shells skip the complete configuration' \
  _test_noninteractive_bootstrap_guard

_test_public_surface_loads() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" \
    'ZSH_LOCAL_INIT=/dev/null; source "$1/.zshrc"; print -r -- "${+functions[mkcd]}|${+functions[cpdir]}|${+functions[git-discard-all]}|${+functions[xcode]}|${+functions[d]}|${+functions[g]}|${+functions[f]}|${+functions[compozsh]}"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal '1|1|0|1|0|1|0|1' "$output" \
    'documented public commands are missing'
}
test_case 'bootstrap exposes the shipped public command surface' \
  _test_public_surface_loads

_test_initializer_precedes_peers_and_preserves_defaults() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  test_write_file "$home/.zsh.addons/local/init.zsh" $'(( ++LOCAL_INIT_COUNT ))\ntypeset -g LOCAL_INIT_SAW_MKCD=${+functions[mkcd]}\nHISTFILE="$HOME/private-history"\nHISTSIZE=73001\nSAVEHIST=72001\nKEYTIMEOUT=7\ntypeset -gA ZSH_HIGHLIGHT_STYLES ZSH_PROMPT_COLORS\nZSH_HIGHLIGHT_STYLES[command]="fg=123,bold"\nZSH_PROMPT_COLORS[identity]=124\ntypeset -ga PROMPT_PROJECT_MARKERS\nPROMPT_PROJECT_MARKERS+=(private.marker)\nalias ll="print private-ll"' || return
  test_write_file "$home/.zsh.addons/private/.zsh.test-peer" $'(( ++PRIVATE_PEER_COUNT ))\ntypeset -g PRIVATE_PEER_SAW_INIT=${LOCAL_INIT_COUNT:-0}\n:' || return

  output=$(test_run_interactive "$home" \
    'source "$1/.zshrc"; print -r -- "$LOCAL_INIT_COUNT|$PRIVATE_PEER_COUNT|$LOCAL_INIT_SAW_MKCD|$PRIVATE_PEER_SAW_INIT|$HISTSIZE|$SAVEHIST|$KEYTIMEOUT|${ZSH_HIGHLIGHT_STYLES[command]}|${ZSH_PROMPT_COLORS[identity]}|${PROMPT_PROJECT_MARKERS[(Ie)private.marker]}|${aliases[ll]}"' \
    "$TEST_REPO_ROOT") || return

  test_assert_equal \
    '1|1|0|1|73001|72001|7|fg=123,bold|124|1|print private-ll' \
    "$output" 'initializer order or public-default preservation changed'
}
test_case 'local initializer runs once before peers and its inputs survive' \
  _test_initializer_precedes_peers_and_preserves_defaults

_test_discovery_filename_contract() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  test_write_file "$home/.zsh.addons/local/init.zsh" \
    '(( ++INIT_FILE_COUNT ))' || return
  test_write_file "$home/.zsh.addons/.zsh.enabled" \
    '(( ++ENABLED_FILE_COUNT )); :' || return
  test_write_file "$home/.zsh.addons/.disabled.zsh.ignored" \
    '(( ++DISABLED_FILE_COUNT )); :' || return
  test_write_file "$home/.zsh.addons/.zsh." \
    '(( ++EMPTY_NAME_COUNT )); :' || return

  output=$(test_run_interactive "$home" \
    'source "$1/.zshrc"; print -r -- "${INIT_FILE_COUNT:-0}|${ENABLED_FILE_COUNT:-0}|${DISABLED_FILE_COUNT:-0}|${EMPTY_NAME_COUNT:-0}"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal '1|1|0|0' "$output" 'autoload filename contract changed'
}
test_case 'only regular files with a non-empty .zsh.NAME basename autoload' \
  _test_discovery_filename_contract

_test_copy_layout_deduplicates_addons() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''
  command mkdir -p "$home" || return
  command cp "$TEST_REPO_ROOT/.zshrc" "$home/.zshrc" || return
  command cp -R "$TEST_REPO_ROOT/.zsh.addons" "$home/.zsh.addons" || return
  test_write_file "$home/.zsh.addons/local/init.zsh" \
    '(( ++COPY_INIT_COUNT ))' || return
  test_write_file "$home/.zsh.addons/private/.zsh.copy-peer" \
    '(( ++COPY_PEER_COUNT )); :' || return

  output=$(test_run_interactive "$home" \
    'source "$HOME/.zshrc"; print -r -- "$COPY_INIT_COUNT|$COPY_PEER_COUNT|${+functions[mkcd]}"') || return
  test_assert_equal '1|1|1' "$output" 'copied add-on directory was loaded more than once'
}
test_case 'copied installation scans its combined add-on directory once' \
  _test_copy_layout_deduplicates_addons

_test_peer_order_converges() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" mode='' output='' expected=''
  local script=$'files=("$1"/.zsh.addons/**/.zsh.?*(N.))
case $2 in
  reverse) files=(${(Oa)files}) ;;
  rotate-left) files=(${files[2,-1]} $files[1]) ;;
  rotate-right) files=($files[-1] ${files[1,-2]}) ;;
esac
for file in "${files[@]}"; do source "$file" || exit; done
zmodload zsh/parameter
typeset -a prompt_pre_redraw_hooks=() prompt_finish_hooks=()
zstyle -a zle-line-pre-redraw widgets prompt_pre_redraw_hooks
zstyle -a zle-line-finish widgets prompt_finish_hooks
prompt_pre_redraw_hooks=("${(@)prompt_pre_redraw_hooks#<->:}")
prompt_finish_hooks=("${(@)prompt_finish_hooks#<->:}")
print -r -- "history:$HISTSIZE,$SAVEHIST,$HISTFILE"
print -r -- "options:${options[noclobber]},${options[sharehistory]},${options[autopushd]}"
print -r -- "aliases:${aliases[ll]}|${aliases[la]}|${aliases[c]}|${aliases[..]}"
print -r -- "styles:${ZSH_HIGHLIGHT_STYLES[command]}|${ZSH_HIGHLIGHT_STYLES[argument]}|${ZSH_HIGHLIGHT_STYLES[operator]}|${ZSH_HIGHLIGHT_STYLES[autosuggestion]}"
print -r -- "prompt-colors:${ZSH_PROMPT_COLORS[identity]}|${ZSH_PROMPT_COLORS[path]}|${ZSH_PROMPT_COLORS[git]}|${ZSH_PROMPT_COLORS[warning]}"
print -r -- "output-colors:${ZSH_OUTPUT_COLORS[success]}|${ZSH_OUTPUT_COLORS[warning]}|${ZSH_OUTPUT_COLORS[error]}|${ZSH_OUTPUT_COLORS[match]}"
print -r -- "hooks:${precmd_functions[*]}|${preexec_functions[*]}|${zle_line_init_functions[*]}|${zle_line_pre_redraw_functions[*]}"
print -r -- "zle-hooks:${(j:,:)prompt_pre_redraw_hooks}|${(j:,:)prompt_finish_hooks}|${widgets[compozsh-context-lens]-}"
print -r -- "prompts:$PROMPT|$RPROMPT"
print -r -- "public:${+functions[mkcd]},${+functions[cpdir]},${+functions[git-discard-all]},${+functions[external-device]},${+functions[d]},${+functions[g]},${+functions[f]},${+functions[xcode]},${+functions[compozsh]}"
bindkey "^R"
bindkey "^F"
bindkey "^[f"
bindkey "^[i"
bindkey "^E"'

  for mode in lexical reverse rotate-left rotate-right; do
    output=$(test_run_interactive "$home" "$script" "$TEST_REPO_ROOT" "$mode") || return
    if [[ -z $expected ]]; then
      expected=$output
    else
      test_assert_equal "$expected" "$output" \
        "peer order produced different state for $mode" || return
    fi
  done
}
test_case 'all supported peer traversal orders converge on the same state' \
  _test_peer_order_converges
