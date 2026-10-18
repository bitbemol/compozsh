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

# Print the complete source-time shell state that the peer configuration
# algebra compares (engineering/architecture.md): options, every alias, function
# and disabled table, keymaps and their bindings, effective styles, widgets,
# modules, traps, umask, and every parameter's name, type and value. Lines are
# sorted wherever order cannot change behavior; hook arrays and bindings keep
# their order, so a duplicate registration is never hidden by sorting. The
# child shell receives this function's text and calls it after the peers load,
# so it observes their top-level state; options are captured before emulate
# changes them.
#
# zstyle lookup order matters only between patterns that can match one context.
# A pattern without glob characters matches only its own text and is strictly
# more specific than any wildcard pattern matching that text, so its rank among
# equally specific patterns never changes a lookup: those lines are sorted,
# while wildcard lines keep zsh's lookup order.
#
# Parameter values deliberately left out (their names and types are compared):
# - _MANUAL_SOURCE_GENERATION and _MANUAL_ASYNC_GENERATION advance on every
#   re-source by design, so in-flight manual capture results are invalidated;
# - names that are not identifiers ($, !, #, 0, ...) and _, argv, ARGC, status,
#   pipestatus, LINENO and the func* traces describe this dump's own call;
# - PPID, RANDOM, SRANDOM, SECONDS, EPOCHSECONDS, EPOCHREALTIME, epochtime,
#   TTYIDLE, ERRNO, HISTCMD and sysparams are per-process or clock values;
# - parameters, options, the alias, function, builtin, reserved-word and
#   pattern-character tables, modules, widgets and keymaps are views of the
#   tables printed above;
# - commands, userdirs, usergroups, termcap, terminfo, history, historywords
#   and mapfile are system databases, history or file contents.
_test_shell_state_dump() {
  local -A __state_options=("${(@kv)options}")
  emulate -L zsh
  setopt EXTENDED_GLOB
  zmodload zsh/parameter || return
  local __state_name='' __state_table='' __state_key='' __state_line=''
  local -a __state_array=() __state_words=()
  local -A __state_map=() __state_skip=()

  __state_skip=(
    _MANUAL_SOURCE_GENERATION 1 _MANUAL_ASYNC_GENERATION 1
    _ 1 argv 1 ARGC 1 status 1 pipestatus 1 LINENO 1 funcstack 1
    funcfiletrace 1 funcsourcetrace 1 functrace 1
    PPID 1 RANDOM 1 SRANDOM 1 SECONDS 1 EPOCHSECONDS 1 EPOCHREALTIME 1
    epochtime 1 TTYIDLE 1 ERRNO 1 HISTCMD 1 sysparams 1
    parameters 1 options 1 aliases 1 galiases 1 saliases 1 dis_aliases 1
    dis_galiases 1 dis_saliases 1 functions 1 dis_functions 1
    functions_source 1 dis_functions_source 1 builtins 1 dis_builtins 1
    reswords 1 dis_reswords 1 patchars 1 dis_patchars 1 modules 1
    widgets 1 keymaps 1
    commands 1 userdirs 1 usergroups 1 termcap 1 terminfo 1 history 1
    historywords 1 mapfile 1
  )

  for __state_name in ${(ko)__state_options}; do
    print -r -- "option $__state_name=$__state_options[$__state_name]"
  done
  for __state_table in aliases galiases saliases dis_aliases dis_galiases \
      dis_saliases builtins dis_builtins modules widgets; do
    __state_map=("${(@Pkv)__state_table}")
    for __state_key in ${(ko)__state_map}; do
      print -r -- "$__state_table ${(qq)__state_key}=${(qq)__state_map[$__state_key]}"
    done
  done
  for __state_table in reswords dis_reswords patchars dis_patchars; do
    print -r -- "$__state_table ${(j: :)${(@o)${(@P)__state_table}}}"
  done
  for __state_table in functions dis_functions; do
    __state_map=("${(@Pkv)__state_table}")
    for __state_key in ${(ko)__state_map}; do
      __state_line="$__state_table ${(qq)__state_key}"
      print -rl -- "$__state_line" \
        "${(@)${(@f)__state_map[$__state_key]}/#/$__state_line: }"
    done
  done
  bindkey -lL
  for __state_key in ${(o)keymaps}; do
    bindkey -M "$__state_key" -L
  done
  for __state_key in "${(@f)$(zstyle -L)}"; do
    __state_words=(${(z)__state_key})
    __state_name=${(Q)__state_words[2]}
    [[ $__state_name != -e ]] || __state_name=${(Q)__state_words[3]}
    if [[ $__state_name == *[\(\|\*\[\<\?\#\^]* ]]; then
      print -r -- "$__state_key"
    else
      __state_array+=("$__state_key")
    fi
  done
  print -rl -- "${(@o)__state_array}"
  zmodload -L
  zmodload -La
  trap
  umask
  for __state_name in ${(ko)parameters}; do
    [[ $__state_name != __state_* ]] || continue
    __state_line="parameter ${(qq)__state_name} $parameters[$__state_name]"
    if [[ $__state_name != [[:alpha:]_][[:alnum:]_]# ]] ||
        (( ${+__state_skip[$__state_name]} )); then
      print -r -- "$__state_line"
      continue
    fi
    case $parameters[$__state_name] in
      association*)
        print -r -- "$__state_line"
        __state_map=("${(@Pkv)__state_name}")
        for __state_key in ${(ko)__state_map}; do
          print -r -- "parameter ${(qq)__state_name}[${(qq)__state_key}]=${(qq)__state_map[$__state_key]}"
        done
        ;;
      array*)
        __state_array=("${(@P)__state_name}")
        print -r -- "$__state_line (${(j: :)${(@qq)__state_array}})"
        ;;
      *)
        print -r -- "$__state_line ${(qq)${(P)__state_name}}"
        ;;
    esac
  done
}

# Every supported traversal must reach the same complete state without load
# diagnostics: lexical, reverse, both rotations (each owner before and after
# its consumers), forward then reverse (every peer repeated with others
# between), and .zshrc sourced twice (the bootstrap's own re-source path, which
# tests/verify.zsh checks for diagnostics only). Discovery mirrors the
# bootstrap's, support/cache excluded. The anchors prove the reference dump
# reaches each main table, so an empty or truncated dump cannot pass.
_test_peer_order_converges() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" mode='' anchor='' state=''
  local reference="$TEST_TMP_DIR/state-lexical"
  local script=$'files=()
for file in "$1"/.zsh.addons/**/.zsh.?*(N.); do
  [[ $file == "$1"/.zsh.addons/support/cache/* ]] || files+=("$file")
done
case $2 in
  reverse) files=(${(Oa)files}) ;;
  rotate-left) files=(${files[2,-1]} $files[1]) ;;
  rotate-right) files=($files[-1] ${files[1,-2]}) ;;
  forward-reverse) files=($files ${(Oa)files}) ;;
  bootstrap-twice) files=("$1/.zshrc" "$1/.zshrc") ;;
esac
for file in "${files[@]}"; do source "$file" || exit; done
unset files file
set --
'"$(typeset -f _test_shell_state_dump)"$'
_test_shell_state_dump'
  local -a anchors=(
    'option sharehistory=on'
    "aliases 'll'='ls -lah'"
    "functions 'mkcd'"
    'bindkey -A emacs main'
    'bindkey "^[i" compozsh-context-lens'
    "zstyle ':completion:*' menu select"
    "parameter 'precmd_functions' array"
  )

  # compinit writes .zcompdump in a fresh home and later shells load it, which
  # defines slightly different completion-system globals. A discarded warm-up
  # gives every compared order the same, ordinary later-shell start.
  test_run_interactive "$home" 'source "$1/.zshrc"' "$TEST_REPO_ROOT" \
    > /dev/null 2>&1 || test_fail 'the warm-up shell failed to load' || return
  for mode in lexical reverse rotate-left rotate-right forward-reverse \
      bootstrap-twice; do
    test_run_interactive "$home" "$script" "$TEST_REPO_ROOT" "$mode" \
      > "$TEST_TMP_DIR/state-$mode" 2> "$TEST_TMP_DIR/errors-$mode" ||
      test_fail "peer order $mode failed to load" || return
    [[ ! -s "$TEST_TMP_DIR/errors-$mode" ]] ||
      test_fail "peer order $mode produced load diagnostics: $(<"$TEST_TMP_DIR/errors-$mode")" ||
      return
    if [[ $mode == lexical ]]; then
      state=$'\n'$(<"$reference")$'\n'
      for anchor in "${anchors[@]}"; do
        [[ $state == *$'\n'"$anchor"[$'\n'\ ]* ]] ||
          test_fail "the state dump lacks: $anchor" || return
      done
    elif ! command cmp -s -- "$reference" "$TEST_TMP_DIR/state-$mode"; then
      test_fail "peer order $mode produced a different shell state:"$'\n'"$(
        command diff -a -- "$reference" "$TEST_TMP_DIR/state-$mode" |
          command head -n 40)"
      return 1
    fi
  done
}
test_case 'all supported peer traversal orders converge on the same complete shell state' \
  _test_peer_order_converges

# Re-sourcing a peer moves its ZLE hooks after any hook a caller added since,
# keeping the canonical redraw order and the exact numbered entries that
# add-zle-hook-widget stores, whichever of editor and highlighting loads first.
_test_peer_zle_hooks_reregister_after_caller_hooks() {
  test_make_temp_dir || return
  local mode='' output='' expected=$'line-init 2:_caller_hook 3:_zle_autosuggest_reset
line-pre-redraw 4:_caller_hook 5:_zle_syntax_highlight 6:_zle_autosuggest_update 7:_zle_prompt_pre_redraw
line-finish 3:_caller_hook 4:_zle_autosuggest_clear_display 5:_zle_prompt_line_finish'

  for mode in editor-first highlighting-first; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$mode" '
      source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
      local -a peers=("$1/.zsh.addons/.zsh.editor" "$1/.zsh.addons/.zsh.highlighting")
      local -a registered=()
      local peer="" hook=""
      [[ $2 == editor-first ]] || peers=("${(@Oa)peers}")
      _caller_hook() { : }
      for peer in "${peers[@]}"; do source "$peer" || exit 1; done
      for hook in line-init line-pre-redraw line-finish; do
        add-zle-hook-widget "$hook" _caller_hook || exit 2
      done
      for peer in "${peers[@]}"; do source "$peer" || exit 3; done
      for hook in line-init line-pre-redraw line-finish; do
        zstyle -g registered "zle-$hook" widgets || exit 4
        print -r -- "$hook ${registered[*]}"
      done
    ' "$TEST_REPO_ROOT" "$mode" 2>&1) ||
      test_fail "$mode hook registration failed: $output" || return
    test_assert_equal "$expected" "$output" \
      "$mode re-sourcing changed the registered ZLE hooks" || return
  done
}
test_case 'peer ZLE hooks re-register after caller hooks with exact entries in either order' \
  _test_peer_zle_hooks_reregister_after_caller_hooks

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
