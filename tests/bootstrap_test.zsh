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

# Uncommenting a guarded starter example must not make the bootstrap report a
# load failure merely because the guarded tool is absent. The disposable home
# never contains the example hook, so its guard is false on every machine.
_test_template_guarded_example_succeeds_when_absent() {
  emulate -L zsh
  test_make_temp_dir || return

  local home="$TEST_TMP_DIR/home" output='' line=''
  local -a template_lines example_lines
  local -i index=0 found=0

  template_lines=("${(@f)$(<"$TEST_REPO_ROOT/templates/init.zsh")}")
  for (( index = 1; index <= $#template_lines; index++ )); do
    line=${template_lines[index]}
    if (( found )); then
      [[ -n $line ]] || break
      [[ $line == '# '* ]] ||
        test_fail "starter example line is not commented: $line" || return
      example_lines+=("${line#\# }")
    elif [[ $line == *'A trusted machine-installed hook'* ]]; then
      found=1
    fi
  done
  (( found && $#example_lines )) ||
    test_fail 'templates/init.zsh lacks the trusted hook example' || return

  test_write_file "$home/.zsh.addons/local/init.zsh" "${(F)example_lines}" ||
    return
  output=$(test_run_interactive "$home" \
    'source "$1/.zshrc"; print -r -- done' "$TEST_REPO_ROOT" 2>&1)
  test_assert_equal done "$output" \
    'uncommented starter example reported a failure'
}
test_case 'initializer starter examples succeed when their guards are false' \
  _test_template_guarded_example_succeeds_when_absent

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

# Zsh owns the ordinary-prompt key timeout: the bootstrap keeps its default and
# never replaces an initializer's choice, including an explicit unset.
_test_bootstrap_keeps_zsh_keytimeout() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  output=$(test_run_interactive "$home" \
    'ZSH_LOCAL_INIT=/dev/null; source "$1/.zshrc"; print -r -- "$KEYTIMEOUT"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal 40 "$output" \
    'bootstrap changed the Zsh KEYTIMEOUT default' || return

  test_write_file "$home/.zsh.addons/local/init.zsh" 'unset KEYTIMEOUT' ||
    return
  output=$(test_run_interactive "$home" \
    'source "$1/.zshrc"; print -r -- "${+KEYTIMEOUT}"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal 0 "$output" \
    'bootstrap replaced an initializer KEYTIMEOUT unset'
}
test_case 'local initializer can leave KEYTIMEOUT unset and the Zsh default stays' \
  _test_bootstrap_keeps_zsh_keytimeout

# BSD ls colors whenever CLICOLOR exists, even as 0 or empty, so the only
# persistent opt-out is leaving it unset. The shell peer runs after the
# initializer and must not undo a NO_COLOR choice, also when re-sourced.
_test_listing_colors_honor_no_color() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  output=$(test_run_interactive "$home" \
    'ZSH_LOCAL_INIT=/dev/null; source "$1/.zshrc"; print -r -- "${CLICOLOR-}|${(t)CLICOLOR}"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal '1|scalar-export' "$output" \
    'listing colors are no longer enabled by default' || return

  test_write_file "$home/.zsh.addons/local/init.zsh" 'export NO_COLOR=1' ||
    return
  output=$(test_run_interactive "$home" \
    'source "$1/.zshrc"; print -r -- "${+CLICOLOR}"; source "$1/.zsh.addons/.zsh.shell"; print -r -- "${+CLICOLOR}"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal $'0\n0' "$output" \
    'a NO_COLOR initializer still enabled BSD listing colors'
}
test_case 'listing colors honor a NO_COLOR initializer opt-out' \
  _test_listing_colors_honor_no_color

# Stock macOS /etc/zshrc sets HISTSIZE=2000 and SAVEHIST=1000 before ~/.zshrc;
# -f skips it, so the script emulates those values. The shell peer keeps limits
# no initializer chose and supplies only the history file /etc/zshrc would set.
_test_history_limits_keep_stock_values() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  output=$(test_run_interactive "$home" \
    'HISTSIZE=2000; SAVEHIST=1000; ZSH_LOCAL_INIT=/dev/null; source "$1/.zshrc"; print -r -- "$HISTSIZE|$SAVEHIST|$HISTFILE"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal "2000|1000|$home/.zsh_history" "$output" \
    'shell history limits or default history file changed'
}
test_case 'shell history limits keep stock macOS values when no initializer chooses them' \
  _test_history_limits_keep_stock_values

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

# Discovery must not depend on glob options an initializer or a previously
# loaded peer left set: GLOB_DOTS would descend into hidden folders (and walk
# a versioned .git) and NO_CASE_GLOB would accept .ZSH.* names. The user's own
# options survive loading unchanged.
_test_discovery_ignores_glob_options() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/init" output=''

  test_write_file "$home/.zsh.addons/local/init.zsh" \
    'setopt GLOB_DOTS NO_CASE_GLOB' || return
  test_write_file "$home/.zsh.addons/.archive/.zsh.old-peer" \
    '(( ++HIDDEN_LOADS )); :' || return
  test_write_file "$home/.zsh.addons/private/.ZSH.upper" \
    '(( ++UPPER_LOADS )); :' || return
  output=$(test_run_interactive "$home" \
    'source "$1/.zshrc"; print -r -- "${HIDDEN_LOADS:-0}|${UPPER_LOADS:-0}|${+functions[mkcd]}|${options[globdots]}|${options[caseglob]}|${+_zsh_addon_files}"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal '0|0|1|on|off|0' "$output" \
    'initializer glob options changed the discovered peer set' || return

  home="$TEST_TMP_DIR/peer"
  test_write_file "$home/.zsh.addons/private/.zsh.options" \
    'setopt GLOB_DOTS; :' || return
  test_write_file "$home/.zsh.addons/.archive/.zsh.old-peer" \
    '(( ++HIDDEN_LOADS )); :' || return
  output=$(test_run_interactive "$home" \
    'source "$1/.zshrc"; source "$1/.zshrc"; print -r -- "${HIDDEN_LOADS:-0}|${+functions[mkcd]}"' \
    "$TEST_REPO_ROOT") || return
  test_assert_equal '0|1' "$output" \
    'a peer glob option changed the set discovered on re-source'
}
test_case 'peer discovery ignores glob options set before or during loading' \
  _test_discovery_ignores_glob_options

_test_cache_data_never_autoloads() {
  test_make_temp_dir || return
  local layout='' output='' base=''
  for layout in symlink copy; do
    base="$TEST_TMP_DIR/$layout"
    test_write_file "$base/.zsh.addons/support/cache/.zsh.manual.cache" 'CACHE_EXECUTED=yes; :' || return
    test_write_file "$base/.zsh.addons/support/cache/nested/.zsh.xcode.cache" 'CACHE_EXECUTED=yes; :' || return
    test_write_file "$base/.zsh.addons/support/.zsh.neighbor" 'CACHE_NEIGHBOR=loaded; :' || return
    if [[ $layout == symlink ]]; then
      command ln -s "$TEST_REPO_ROOT/.zshrc" "$base/.zshrc" || return
    else
      command cp "$TEST_REPO_ROOT/.zshrc" "$base/.zshrc" || return
      command cp -R "$TEST_REPO_ROOT/.zsh.addons" "$base/.zsh.addons/compozsh" || return
    fi
    output=$(test_run_interactive "$base" '
      source "$HOME/.zshrc" || exit 1
      source "$HOME/.zshrc" || exit 2
      print -r -- "${CACHE_EXECUTED:-never}|$CACHE_NEIGHBOR|${+functions[mkcd]}"
    ' 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail 'cache produced loader diagnostics' || return
    test_assert_equal 'never|loaded|1' "$output" 'bootstrap executed module cache data' || return
  done
}
test_case 'bootstrap excludes module cache data while preserving neighboring peers in both layouts' \
  _test_cache_data_never_autoloads

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
    output=$(test_run_interactive "$home" "$script" "$TEST_REPO_ROOT" "$mode" \
      2> "$TEST_TMP_DIR/errors-$mode") || return
    [[ ! -s "$TEST_TMP_DIR/errors-$mode" ]] ||
      test_fail "peer order $mode produced load diagnostics: $(<"$TEST_TMP_DIR/errors-$mode")" ||
      return
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

# Retiring a public name removes only Compozsh's own definition. A user's alias
# or function that reuses a retired name stays theirs in every load order, and
# a peer's top-level unalias is only the guard before its own public command.
_test_retired_names_stay_user_owned() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" mode='' output='' file='' line='' name=''
  local definition=''
  local -a peers=() lines=() words=() found=()
  local -i index=0 defined_at=0 status_code=0
  local script=$'retired=(b git-discard-all prompt-refresh flash-usb format-external-device compozsh-sudo-touch-id update-xcode-skills)
for name in "${retired[@]}"; do
  aliases[$name]="mine-$name"
  functions[$name]="print -r -- mine-$name"
done
aliases[external-device]=mine-external-device
files=("$1"/.zsh.addons/**/.zsh.?*(N.))
[[ $2 == reverse ]] && files=(${(Oa)files})
for file in "${files[@]}"; do source "$file" || exit; done
for name in "${retired[@]}"; do
  [[ ${aliases[$name]-} == "mine-$name" ]] || print -r -- "lost alias $name"
  [[ ${functions[$name]-} == *"mine-$name"* ]] || print -r -- "lost function $name"
done
(( ! ${+aliases[external-device]} && ${+functions[external-device]} &&
   ! ${+functions[mine-external-device]} )) || print -r -- "external-device guard failed"
print -r -- kept'

  for mode in lexical reverse; do
    status_code=0
    output=$(test_run_interactive "$home" "$script" "$TEST_REPO_ROOT" "$mode" \
      2> "$TEST_TMP_DIR/errors-$mode") || status_code=$?
    (( ! status_code )) && [[ ! -s "$TEST_TMP_DIR/errors-$mode" ]] ||
      test_fail "peers failed to load over user-owned names in $mode order (status $status_code): $output $(<"$TEST_TMP_DIR/errors-$mode")" ||
      return
    test_assert_equal kept "$output" \
      "loading peers in $mode order removed user-owned names" || return
  done

  peers=("$TEST_REPO_ROOT"/.zsh.addons/**/.zsh.?*(N.))
  (( $#peers )) || test_fail 'no peers found' || return
  for file in "${peers[@]}"; do
    lines=("${(@f)$(<"$file")}")
    for (( index = 1; index <= $#lines; index++ )); do
      line=$lines[index]
      # Top-level statements start in column one; function bodies are indented.
      [[ $line == (unalias|unfunction)' '* ]] || continue
      words=(${=line})
      case $line in
        ('unalias '*)
          [[ $#words == 3 && $words[3] == '2>/dev/null' &&
             $lines[index+1] == "$words[2]() {" ]] ||
            found+=("${file#$TEST_REPO_ROOT/}:$index: $line")
          ;;
        ('unfunction '*)
          # A peer may drop a one-shot helper it defined above, nothing else.
          for name in "${(@)words[2,-1]}"; do
            [[ $name == '2>/dev/null' ]] && continue
            definition="$name() {"
            defined_at=${lines[(ie)$definition]}
            (( defined_at < index )) && continue
            found+=("${file#$TEST_REPO_ROOT/}:$index: $line")
            break
          done
          ;;
      esac
    done
  done
  (( ! $#found )) ||
    test_fail "peers remove names they do not define: ${(j:; :)found}"
}
test_case 'retired command names stay user-owned when peers load in any order' \
  _test_retired_names_stay_user_owned
