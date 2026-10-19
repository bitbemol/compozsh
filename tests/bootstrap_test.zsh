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

# A .zwc file is compiled data for its neighbor, never a peer: a private
# peer's own zcompile output, a stray file beside a shipped peer and anything
# in the support/compiled mirror stay unsourced as text.
_test_compiled_files_never_autoload() {
  test_make_temp_dir || return
  local layout='' output='' base='' shared=''
  for layout in symlink copy; do
    base="$TEST_TMP_DIR/$layout"
    test_write_file "$base/.zsh.addons/work/.zsh.private" 'PRIVATE_PEER=loaded; :' || return
    test_write_file "$base/.zsh.addons/work/.zsh.private.zwc" 'ZWC_SOURCED=private; :' || return
    test_write_file "$base/.zsh.addons/.zsh.orphan.zwc" 'ZWC_SOURCED=orphan; :' || return
    test_write_file "$base/.zsh.addons/support/compiled/.zsh.mirror" 'ZWC_SOURCED=mirror; :' || return
    if [[ $layout == symlink ]]; then
      shared="$TEST_TMP_DIR/repository"
      command mkdir -p "$shared" || return
      command cp "$TEST_REPO_ROOT/.zshrc" "$shared/.zshrc" || return
      command cp -R "$TEST_REPO_ROOT/.zsh.addons" "$shared/.zsh.addons" || return
      command ln -s "$shared/.zshrc" "$base/.zshrc" || return
      shared="$shared/.zsh.addons"
    else
      command cp "$TEST_REPO_ROOT/.zshrc" "$base/.zshrc" || return
      command cp -R "$TEST_REPO_ROOT/.zsh.addons" "$base/.zsh.addons/compozsh" || return
      shared="$base/.zsh.addons/compozsh"
    fi
    test_write_file "$shared/.zsh.tools.zwc" 'ZWC_SOURCED=shipped; :' || return
    output=$(test_run_interactive "$base" '
      source "$HOME/.zshrc" || exit 1
      print -r -- "${ZWC_SOURCED:-never}|$PRIVATE_PEER|${+functions[mkcd]}"
    ' 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] ||
      test_fail "$layout: .zwc files produced loader diagnostics: $(<"$TEST_TMP_DIR/errors")" || return
    test_assert_equal 'never|loaded|1' "$output" "$layout: bootstrap sourced a .zwc file as a peer" || return
  done
}
test_case 'compiled peers: discovery never sources .zwc files or the compiled mirror in either layout' \
  _test_compiled_files_never_autoload

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
# bootstrap's: support/cache, support/compiled and .zwc files excluded. The
# anchors prove the reference dump reaches each main table, so an empty or
# truncated dump cannot pass.
_test_peer_order_converges() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" mode='' anchor='' state=''
  local reference="$TEST_TMP_DIR/state-lexical"
  local script=$'files=()
for file in "$1"/.zsh.addons/**/.zsh.?*(N.); do
  [[ $file == "$1"/.zsh.addons/support/(cache|compiled)/* || $file == *.zwc ]] ||
    files+=("$file")
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

# Install through the real installer into a disposable home.
# Usage: _test_compiled_install <repository> <home> <symlink|copy>
_test_compiled_install() {
  test_run_noninteractive "$2" 'source "$1/install.zsh" "--$2" --yes' "$1" "$3" \
    > /dev/null 2> "$TEST_TMP_DIR/install.err" ||
    test_fail "$3 installation failed: $(<"$TEST_TMP_DIR/install.err")"
}

# Load the installed bootstrap in <home>, write every function source path to
# <output>.sources, re-source the bootstrap, then write the complete state dump
# to <output> and load diagnostics to <output>.err. The dump is defined before
# the bootstrap runs, so initializer options cannot change how it parses.
# Usage: _test_compiled_capture <home> <output>
_test_compiled_capture() {
  local script="$(typeset -f _test_shell_state_dump)"$'
source "$HOME/.zshrc" || exit 1
print -rl -- ${(v)functions_source} >| "$1"
source "$HOME/.zshrc" || exit 2
_test_shell_state_dump'
  test_run_interactive "$1" "$script" "$2.sources" > "$2" 2> "$2.err" ||
    test_fail "the installed shell failed to load: $(<"$2.err")"
}

# Count captured function source paths under <prefix>.
# Usage: _test_compiled_count <sources-file> <prefix>
_test_compiled_count() {
  local -a sources=("${(@f)$(<"$1")}")
  REPLY=${#${(M)sources:#$2*}}
}

# The compiled mirror is only an optimization: in both layouts the
# installed shell loads shipped peers and the completion dump from it and
# reaches the same complete state as text loading (the mirror replaced by an unmarked folder, which the
# bootstrap neither uses nor writes), including when sourced twice. An initializer's own aliases or parse-affecting options would change
# how text parses, so the shipped peers then load as text, and the state still
# matches; options that only matter at run time keep compiled loading.
_test_compiled_peers_match_text_state() {
  test_make_temp_dir || return
  local layout='' home='' compiled='' shared='' variant='' run=''
  local -A initializers=(
    inert ':'
    runtime 'setopt EXTENDED_GLOB NO_CASE_GLOB'
    aliases "alias rm='rm -i' ll='ls -l'; alias -g G='| grep'"
    parse 'setopt RC_QUOTES KSH_GLOB IGNORE_BRACES'
  )
  for layout in symlink copy; do
    home="$TEST_TMP_DIR/$layout"
    compiled="$home/.zsh.addons/support/compiled"
    _test_compiled_install "$TEST_REPO_ROOT" "$home" "$layout" || return
    if [[ $layout == symlink ]]; then
      shared="${TEST_REPO_ROOT:A}/.zsh.addons/"
    else
      shared="${home:A}/.zsh.addons/compozsh/"
    fi
    test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 ||
      test_fail "$layout warm-up shell failed to load" || return
    # A second warm-up, once the clock passed the dump's write, compiles it.
    _test_compiled_tick || return
    test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 ||
      test_fail "$layout second warm-up shell failed to load" || return
    [[ -L $compiled/zcompdump && -f $compiled/zcompdump.zwc ]] ||
      test_fail "$layout: the completion dump was not compiled" || return
    for variant in inert runtime aliases parse; do
      print -r -- "$initializers[$variant]" >| "$home/.zsh.addons/local/init.zsh" || return
      run="$TEST_TMP_DIR/$layout-$variant"
      _test_compiled_capture "$home" "$run-compiled" || return
      command mv -- "$compiled" "$TEST_TMP_DIR/aside" &&
        command mkdir -m 0700 -- "$compiled" || return
      _test_compiled_capture "$home" "$run-text"
      [[ -z $(print -rl -- "$compiled"/*(DN)) ]] ||
        test_fail "$layout $variant: the bootstrap wrote into an unmarked mirror" || return
      command rmdir -- "$compiled" &&
        command mv -- "$TEST_TMP_DIR/aside" "$compiled" || return
      [[ -s "$run-text" ]] || test_fail "$layout $variant text loading failed" || return
      _test_compiled_count "$run-text.sources" "${compiled:A}/"
      test_assert_equal 0 "$REPLY" "$layout $variant: text run used the mirror" || return
      _test_compiled_count "$run-compiled.sources" "${compiled:A}/"
      if [[ $variant == (inert|runtime) ]]; then
        (( REPLY > 100 )) ||
          test_fail "$layout $variant: only $REPLY functions came from compiled code" || return
        _test_compiled_count "$run-compiled.sources" "$shared"
        test_assert_equal 0 "$REPLY" "$layout $variant: a fresh shipped peer loaded as text" || return
      else
        test_assert_equal 0 "$REPLY" \
          "$layout $variant: compiled code ran under a changed parse context" || return
      fi
      if ! command cmp -s -- "$run-text" "$run-compiled"; then
        test_fail "$layout $variant: compiled loading changed the shell state:"$'\n'"$(
          command diff -a -- "$run-text" "$run-compiled" | command head -n 40)"
        return 1
      fi
      test_assert_equal "$(<"$run-text.err")" "$(<"$run-compiled.err")" \
        "$layout $variant: compiled loading changed load diagnostics" || return
      [[ $variant == parse || ! -s "$run-compiled.err" ]] ||
        test_fail "$layout $variant: load diagnostics: $(<"$run-compiled.err")" || return
    done
  done
}
test_case 'compiled peers: both layouts load fresh compiled code with the same complete state as text' \
  _test_compiled_peers_match_text_state

# Zsh itself uses a .zwc whose mtime is not older than its source, so an edit
# in the same second, a restored older mtime or a replacement file would run
# stale code. The bootstrap compares device, inode, size, mtime and ctime
# instead: any later change moves ctime past the compiled snapshot.
_test_compiled_peers_never_run_stale_code() {
  test_make_temp_dir || return
  local repository='' layout='' home='' shared='' output=''
  local script='
    source "$HOME/.zshrc" || exit 1
    local name="" origin=""
    for name in probe_a probe_b probe_c mkcd; do
      origin=text
      [[ ${functions_source[$name]} == */support/compiled/* ]] && origin=compiled
      print -rn -- "$name:$origin|"
    done
    print -r -- "$(probe_a)|$(probe_b)|$(probe_c)"'
  for layout in symlink copy; do
    home="$TEST_TMP_DIR/$layout"
    repository="$TEST_TMP_DIR/repository-$layout"
    command mkdir -p "$repository" || return
    command cp "$TEST_REPO_ROOT/.zshrc" "$TEST_REPO_ROOT/install.zsh" "$repository" || return
    command cp -R "$TEST_REPO_ROOT/templates" "$TEST_REPO_ROOT/.zsh.addons" "$repository" || return
    test_write_file "$repository/.zsh.addons/.zsh.zz-probe-a" 'probe_a() { print -r -- old-a; }' || return
    test_write_file "$repository/.zsh.addons/.zsh.zz-probe-b" 'probe_b() { print -r -- old-b; }' || return
    test_write_file "$repository/.zsh.addons/.zsh.zz-probe-c" 'probe_c() { print -r -- old-c; }' || return
    _test_compiled_install "$repository" "$home" "$layout" || return
    if [[ $layout == symlink ]]; then
      shared="$repository/.zsh.addons"
    else
      shared="$home/.zsh.addons/compozsh"
    fi
    output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$layout: $(<"$TEST_TMP_DIR/errors")" || return
    test_assert_equal 'probe_a:compiled|probe_b:compiled|probe_c:compiled|mkcd:compiled|old-a|old-b|old-c' \
      "$output" "$layout: fresh shipped peers did not load compiled code" || return

    # Same size, immediately, then the original old mtime restored.
    print -r -- 'probe_a() { print -r -- new-a; }' >| "$shared/.zsh.zz-probe-a" || return
    command touch -t 202001010000 "$shared/.zsh.zz-probe-a" || return
    # A replacement file with an old mtime, moved over the original.
    print -r -- 'probe_b() { print -r -- new-b; }' >| "$TEST_TMP_DIR/replacement" || return
    command touch -t 202001010000 "$TEST_TMP_DIR/replacement" || return
    command mv -f -- "$TEST_TMP_DIR/replacement" "$shared/.zsh.zz-probe-b" || return
    # Metadata only: content unchanged, yet the snapshot no longer matches.
    command chmod 600 "$shared/.zsh.zz-probe-c" || return

    # The next shell loads each peer's current text, or code it compiled from
    # that text once the clock passed the change; never the earlier wordcode.
    output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$layout: $(<"$TEST_TMP_DIR/errors")" || return
    [[ $output == probe_a:(text|compiled)\|probe_b:(text|compiled)\|probe_c:(text|compiled)\|mkcd:compiled\|new-a\|new-b\|old-c ]] ||
      test_fail "$layout: a changed shipped peer ran stale code: $output" || return
  done
}
test_case 'compiled peers: an edited, retimed or replaced shipped peer never runs stale compiled code' \
  _test_compiled_peers_never_run_stale_code

# A mirror that is not provably this user's private, marked folder falls back
# to text without diagnostics and is never written: group access, a missing
# marker, a symlinked marker or a symlinked mirror. Records that do not match
# (another Zsh version, a missing or group-writable manifest, an entry that
# resolves elsewhere) are never used either; the shell recompiles the peers
# into its own mirror and loads that code.
_test_compiled_peers_fall_back_to_text() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" compiled='' manifest='' entry='' condition='' output=''
  local listing=''
  local text_source="${TEST_REPO_ROOT:A}/.zsh.addons/.zsh.tools"
  compiled="$home/.zsh.addons/support/compiled"
  manifest="$compiled/manifest"
  entry="$compiled/.zsh.addons/.zsh.tools"
  _test_compiled_install "$TEST_REPO_ROOT" "$home" symlink || return
  local script='source "$HOME/.zshrc" || exit 1; print -r -- "${functions_source[mkcd]}"'
  output=$(test_run_interactive "$home" "$script") || return
  test_assert_equal "${compiled:A}/.zsh.addons/.zsh.tools" "$output" \
    'the fresh installation did not load compiled code' || return
  command cp -p -- "$manifest" "$TEST_TMP_DIR/manifest" || return
  command cp -- "$text_source" "$TEST_TMP_DIR/.zsh.tools" || return

  for condition in directory-mode unmarked marker-link mirror-link; do
    # Without a usable mirror every shipped peer lacks a record, so a
    # bootstrap that wrote here would recompile them all.
    case $condition in
      directory-mode) command chmod 0750 "$compiled" ;;
      unmarked) command mv -- "$compiled/.managed-by-compozsh" "$TEST_TMP_DIR/marker" ;;
      marker-link)
        command mv -- "$compiled/.managed-by-compozsh" "$TEST_TMP_DIR/marker" &&
          command ln -s -- "$TEST_TMP_DIR/marker" "$compiled/.managed-by-compozsh" ;;
      mirror-link)
        command mv -- "$compiled" "$TEST_TMP_DIR/elsewhere" &&
          command ln -s -- "$TEST_TMP_DIR/elsewhere" "$compiled" ;;
    esac || return
    listing=$(command ls -laRT -- "$compiled/") || return
    output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] ||
      test_fail "$condition: fallback produced diagnostics: $(<"$TEST_TMP_DIR/errors")" || return
    test_assert_equal "$text_source" "$output" "$condition: the shell ran compiled code" || return
    test_assert_equal "$listing" "$(command ls -laRT -- "$compiled/")" \
      "$condition: the shell wrote into a mirror that is not its own" || return
    case $condition in
      directory-mode) command chmod 0700 "$compiled" ;;
      unmarked) command mv -- "$TEST_TMP_DIR/marker" "$compiled/.managed-by-compozsh" ;;
      marker-link)
        command rm -f -- "$compiled/.managed-by-compozsh" &&
          command mv -- "$TEST_TMP_DIR/marker" "$compiled/.managed-by-compozsh" ;;
      mirror-link)
        command rm -f -- "$compiled" &&
          command mv -- "$TEST_TMP_DIR/elsewhere" "$compiled" ;;
    esac || return
  done

  # The retargeted copy announces itself if it ever runs. Startup compiles for
  # at most about 300 ms, so a full rebuild may take a few shells.
  print -r -- 'RETARGETED_RAN=yes' >> "$TEST_TMP_DIR/.zsh.tools" || return
  script+='; print -r -- "|${RETARGETED_RAN:-no}"'
  local -i run=0
  for condition in version missing manifest-mode retargeted; do
    case $condition in
      version)
        print -r -- "${$(<"$TEST_TMP_DIR/manifest")/$'\n'zsh /$'\n'zsh 0.0-}" >| "$manifest" ;;
      missing) command rm -f -- "$manifest" ;;
      manifest-mode) command chmod 0620 "$manifest" ;;
      retargeted) command ln -sfn -- "$TEST_TMP_DIR/.zsh.tools" "$entry" ;;
    esac || return
    for (( run = 1; run <= 4; run++ )); do
      output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
      [[ ! -s "$TEST_TMP_DIR/errors" ]] ||
        test_fail "$condition: recompiling produced diagnostics: $(<"$TEST_TMP_DIR/errors")" || return
      [[ $output == ("$text_source"|"${compiled:A}/.zsh.addons/.zsh.tools")$'\n|no' ]] ||
        test_fail "$condition: the shell used a mismatched record: $output" || return
      [[ $output == "$text_source"* ]] || break
    done
    test_assert_equal "${compiled:A}/.zsh.addons/.zsh.tools"$'\n|no' "$output" \
      "$condition: the shell did not load freshly compiled code" || return
    test_assert_equal "$text_source" "$(command readlink -- "$entry")" \
      "$condition: the mirror entry was not relinked to the peer" || return
    test_assert_equal "zsh $("$TEST_ZSH_BIN" -fc 'print -r -- $ZSH_VERSION')" \
      "${${(f)"$(<"$manifest")"}[2]}" "$condition: the manifest names another Zsh" || return
    test_assert_equal 600 "$(command stat -f %Lp -- "$manifest")" \
      "$condition: the rewritten manifest is reachable by other accounts" || return
  done
}
test_case 'compiled peers: an unsafe mirror loads text unwritten; mismatched records are recompiled, never used' \
  _test_compiled_peers_fall_back_to_text

# In a copy installation a private peer at the top of ~/.zsh.addons loads
# before the managed namespace. One that leaves the parse context alone keeps
# compiled loading; one that defines an alias or sets a parse option sends
# every later shipped peer to text.
_test_compiled_peers_follow_private_parse_changes() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" private='' output='' expected=''
  _test_compiled_install "$TEST_REPO_ROOT" "$home" copy || return
  local script='source "$HOME/.zshrc" || exit 1; print -r -- "${${functions_source[mkcd]}#${HOME:A}/.zsh.addons/}"'
  for private in 'PRIVATE_VALUE=1' "alias rm='rm -i'" 'setopt RC_QUOTES'; do
    print -r -- "$private" >| "$home/.zsh.addons/.zsh.0-private" || return
    output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$private: $(<"$TEST_TMP_DIR/errors")" || return
    expected=compozsh/.zsh.tools
    [[ $private == PRIVATE_VALUE=1 ]] && expected=support/compiled/.zsh.addons/compozsh/.zsh.tools
    test_assert_equal "$expected" "$output" "after a private peer running: $private" || return
  done
}
test_case 'compiled peers: a private peer that changes the parse context sends later shipped peers to text' \
  _test_compiled_peers_follow_private_parse_changes

# Zsh reads /etc/zshenv even under zsh -f, so the child that runs compile.zsh
# may start with a system file's aliases. Here the child defines them itself
# just before sourcing compile.zsh, as /etc/zshenv would (/etc is never
# touched). In every mode the manifests then record exactly Zsh's built-in
# defaults, never such an alias's name or value, the dump's wordcode is parsed
# without it, and a shell that has the extra alias loads text.
_test_compiled_peers_record_only_default_aliases() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" compiled='' base='' dump='' line='' file='' output=''
  local script="${TEST_REPO_ROOT:A}/.zsh.addons/support/compile.zsh"
  local zshenv='alias leaked=sentinel-value; alias -g gleaked=gsentinel; alias -s sleaked=ssentinel'
  local defaults="aliases aliases: \$'run-help'=\$'man' \$'which-command'=\$'whence' galiases: saliases:"
  local probe='source "$HOME/.zshrc" || exit 1; print -r -- "${functions_source[mkcd]}"'
  local -a clean=() lines=() fields=() relatives=()
  compiled="$home/.zsh.addons/support/compiled"
  dump="$TEST_TMP_DIR/dump/.zcompdump"
  _test_compiled_install "$TEST_REPO_ROOT" "$home" symlink || return
  clean=("${(@f)$(<"$compiled/manifest")}")
  base=${clean[3]#base }
  for line in "${(@)clean[7,-1]}"; do
    fields=("${(@ps:\t:)line}")
    [[ $fields[1] == - ]] && fields=("${(@)fields[2,-1]}")
    relatives+=("$fields[1]")
  done
  (( $#relatives > 10 )) || test_fail 'the installed manifest lists too few peers' || return

  # Rebuild the installed mirror, and compile one peer at startup and a dump,
  # each in a child that already has the extra aliases.
  command rm -rf -- "$compiled" && command mkdir -p -- "$TEST_TMP_DIR/startup" || return
  test_write_file "$dump" 'leaked; print -r -- gleaked' || return
  _test_compiled_tick || return
  test_run_noninteractive "$home" "$zshenv"'; . "$@"' "$script" \
    install "$compiled" "$base" '' "${relatives[@]}" < /dev/null 2> "$TEST_TMP_DIR/errors"
  test_run_noninteractive "$home" "$zshenv"'; . "$@"' "$script" \
    startup "$TEST_TMP_DIR/startup/support/compiled" "$base" "$ZSH_VERSION" .zsh.tools \
    < /dev/null 2>> "$TEST_TMP_DIR/errors"
  test_run_noninteractive "$home" "$zshenv"'; . "$@"' "$script" \
    dump "$TEST_TMP_DIR/dump/support/compiled" "$dump" "$ZSH_VERSION" \
    < /dev/null 2>> "$TEST_TMP_DIR/errors"
  for file in "$compiled/manifest" "$TEST_TMP_DIR/startup/support/compiled/manifest" \
      "$TEST_TMP_DIR/dump/support/compiled/zcompdump.manifest"; do
    [[ -f $file ]] ||
      test_fail "${file#$TEST_TMP_DIR/} was not written: $(<"$TEST_TMP_DIR/errors")" || return
    lines=("${(@f)$(<"$file")}")
    [[ ${(F)lines} != *(leaked|sentinel)* ]] ||
      test_fail "${file#$TEST_TMP_DIR/} records a startup file's alias: ${lines[6]-}" || return
    test_assert_equal "$defaults" "${lines[6]-}" \
      "${file#$TEST_TMP_DIR/}: the recorded aliases are not Zsh's built-in defaults" || return
    test_assert_equal "${(F)clean[4,5]}" "${(F)lines[4,5]}" \
      "${file#$TEST_TMP_DIR/}: the recorded parse options differ from a clean compile" || return
  done
  test_assert_equal "${(F)clean[1,6]}" "${(F)${(@f)$(<"$compiled/manifest")}[1,6]}" \
    'the rebuilt manifest header differs from a clean installation' || return
  file="$TEST_TMP_DIR/dump/support/compiled/zcompdump.zwc"
  [[ -f $file && $(<"$file") != *sentinel* ]] ||
    test_fail 'the dump was not compiled, or was parsed with a startup file alias' || return

  output=$(test_run_interactive "$home" "$zshenv; $probe" 2> "$TEST_TMP_DIR/errors") || return
  [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$(<"$TEST_TMP_DIR/errors")" || return
  test_assert_equal "${TEST_REPO_ROOT:A}/.zsh.addons/.zsh.tools" "$output" \
    'a shell with a startup file alias ran compiled code' || return
  output=$(test_run_interactive "$home" "$probe" 2> "$TEST_TMP_DIR/errors") || return
  [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$(<"$TEST_TMP_DIR/errors")" || return
  test_assert_equal "${compiled:A}/.zsh.addons/.zsh.tools" "$output" \
    'a shell with only the default aliases did not load the compiled code'
}
test_case 'compiled peers: a startup file alias in the compiling zsh -f is never recorded and means text' \
  _test_compiled_peers_record_only_default_aliases

# Install a copy of the repository with a probe peer into <home>.
# Sets REPLY to the directory holding the installed shipped peers.
# Usage: _test_compiled_probe_install <home> <symlink|copy>
_test_compiled_probe_install() {
  local repository="$1-repository"
  command mkdir -p -- "$repository" || return
  command cp "$TEST_REPO_ROOT/.zshrc" "$TEST_REPO_ROOT/install.zsh" "$repository" || return
  command cp -R "$TEST_REPO_ROOT/templates" "$TEST_REPO_ROOT/.zsh.addons" "$repository" || return
  test_write_file "$repository/.zsh.addons/.zsh.zz-probe" 'probe() { print -r -- old; }' || return
  _test_compiled_install "$repository" "$1" "$2" || return
  if [[ $2 == symlink ]]; then
    REPLY="$repository/.zsh.addons"
  else
    REPLY="$1/.zsh.addons/compozsh"
  fi
}

# Print the probe's origin (compiled or text) and output in a new shell.
typeset -g _test_compiled_probe_script='
  source "$HOME/.zshrc" || exit 1
  origin=text
  [[ ${functions_source[probe]} == */support/compiled/* ]] && origin=compiled
  print -r -- "$origin|$(probe)"'

# Wait until the clock has moved past the current second, so a file changed
# before the call is old enough to compile.
_test_compiled_tick() {
  zmodload -F zsh/zselect b:zselect || return
  zselect -t 110 || :
  return 0
}

# Print the manifest's inode and modification time, which change whenever a
# shell rewrites it. Usage: _test_compiled_manifest_id <mirror>
_test_compiled_manifest_id() {
  command stat -f '%i %Fm' -- "$1/manifest"
}

# A shipped peer edited after installation is recompiled by the first shell
# once the clock has passed the edit, which uses the new code at once, so no
# installer run is needed. An edit right after that compile, in the same
# second, same size and with the old mtime restored, still loads its new text,
# and a later shell finds everything fresh and rewrites nothing.
_test_compiled_peers_recompile_changed_peers() {
  test_make_temp_dir || return
  local layout='' home='' shared='' output='' before=''
  for layout in symlink copy; do
    home="$TEST_TMP_DIR/$layout"
    _test_compiled_probe_install "$home" "$layout" || return
    shared=$REPLY
    output=$(test_run_interactive "$home" "$_test_compiled_probe_script") || return
    test_assert_equal 'compiled|old' "$output" "$layout: the installed probe was not compiled" || return

    print -r -- 'probe() { print -r -- new; }' >| "$shared/.zsh.zz-probe" || return
    _test_compiled_tick || return
    output=$(test_run_interactive "$home" "$_test_compiled_probe_script" 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$layout: $(<"$TEST_TMP_DIR/errors")" || return
    test_assert_equal 'compiled|new' "$output" \
      "$layout: the first shell after an edit did not compile and use the new peer" || return

    print -r -- 'probe() { print -r -- NEW; }' >| "$shared/.zsh.zz-probe" &&
      command touch -t 202001010000 "$shared/.zsh.zz-probe" || return
    output=$(test_run_interactive "$home" "$_test_compiled_probe_script") || return
    [[ $output == (text|compiled)\|NEW ]] ||
      test_fail "$layout: a same-second edit after a compile ran stale code: $output" || return
    _test_compiled_tick || return
    output=$(test_run_interactive "$home" "$_test_compiled_probe_script") || return
    test_assert_equal 'compiled|NEW' "$output" "$layout: the retimed edit was not recompiled" || return

    before=$(_test_compiled_manifest_id "$home/.zsh.addons/support/compiled") || return
    output=$(test_run_interactive "$home" "$_test_compiled_probe_script") || return
    test_assert_equal 'compiled|NEW' "$output" "$layout: a fresh mirror was not used" || return
    test_assert_equal "$before" "$(_test_compiled_manifest_id "$home/.zsh.addons/support/compiled")" \
      "$layout: a shell rewrote a mirror that was already fresh" || return
  done
}
test_case 'compiled peers: the first shell after an edit recompiles just that peer and later shells reuse it' \
  _test_compiled_peers_recompile_changed_peers

# Fail unless the mirror <compiled> keeps no entry, wordcode or manifest record
# for the relative path <rel>.
# Usage: _test_compiled_dropped <compiled> <rel> <label>
_test_compiled_dropped() {
  local line=''
  [[ ! -L $1/.zsh.addons/$2 && ! -e $1/.zsh.addons/$2 ]] ||
    test_fail "$3: the mirror entry $2 remains" || return
  [[ ! -e $1/.zsh.addons/$2.zwc ]] || test_fail "$3: the wordcode of $2 remains" || return
  for line in "${(@)${(@f)"$(<"$1/manifest")"}[7,-1]}"; do
    line=${line#-$'\t'}
    [[ ${line%%$'\t'*} != "$2" ]] || test_fail "$3: the manifest still records $2" || return
  done
}

# A shipped peer removed or renamed after installation leaves nothing in the
# mirror: the next shell that may compile drops its entry, wordcode and record,
# even when no other shipped peer changed, and the other entries stay in use.
_test_compiled_peers_drop_removed_peers() {
  test_make_temp_dir || return
  local layout='' home='' shared='' output='' compiled='' rel=''
  local -i run=0
  local script='source "$HOME/.zshrc" || exit 1
    [[ ${functions_source[mkcd]} == */support/compiled/* ]] && print -r -- compiled'
  for layout in symlink copy; do
    home="$TEST_TMP_DIR/$layout"
    compiled="$home/.zsh.addons/support/compiled"
    _test_compiled_probe_install "$home" "$layout" || return
    shared=$REPLY
    rel=.zsh.zz-probe
    [[ $layout == symlink ]] || rel=compozsh/$rel
    [[ -L $compiled/.zsh.addons/$rel && -f $compiled/.zsh.addons/$rel.zwc ]] ||
      test_fail "$layout: the installed probe has no mirror entry" || return

    command mv -- "$shared/.zsh.zz-probe" "$shared/.zsh.zz-probe-renamed" || return
    _test_compiled_tick || return
    for (( run = 1; run <= 3; run++ )); do
      output=$(test_run_interactive "$home" "$_test_compiled_probe_script" 2> "$TEST_TMP_DIR/errors") || return
      [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$layout: $(<"$TEST_TMP_DIR/errors")" || return
      [[ $output != 'compiled|old' ]] || break
    done
    test_assert_equal 'compiled|old' "$output" "$layout: the renamed probe was not compiled" || return
    _test_compiled_dropped "$compiled" "$rel" "$layout: after a rename" || return

    command rm -f -- "$shared/.zsh.zz-probe-renamed" || return
    output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$layout: $(<"$TEST_TMP_DIR/errors")" || return
    test_assert_equal compiled "$output" "$layout: the other shipped peers left the mirror" || return
    _test_compiled_dropped "$compiled" "$rel-renamed" "$layout: after a deletion" || return
  done
}
test_case 'compiled peers: a removed or renamed shipped peer leaves no mirror entry, wordcode or record behind' \
  _test_compiled_peers_drop_removed_peers

# A missing mirror, or a missing support folder, is created by the next shell:
# a mode-0700 folder with the marker and a manifest, filled without the
# installer and used at once.
_test_compiled_peers_create_missing_mirror() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" missing='' output='' compiled=''
  local -i run=0
  compiled="$home/.zsh.addons/support/compiled"
  _test_compiled_probe_install "$home" symlink || return
  for missing in "$compiled" "$home/.zsh.addons/support"; do
    command rm -rf -- "$missing" || return
    for (( run = 1; run <= 4; run++ )); do
      output=$(test_run_interactive "$home" "$_test_compiled_probe_script" 2> "$TEST_TMP_DIR/errors") || return
      [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "${missing:t}: $(<"$TEST_TMP_DIR/errors")" || return
      [[ $output == (text|compiled)\|old ]] || test_fail "${missing:t}: $output" || return
      [[ $output == text* ]] || break
    done
    test_assert_equal 'compiled|old' "$output" "${missing:t}: the recreated mirror was not used" || return
    [[ -d $compiled && ! -L $compiled && -f $compiled/.managed-by-compozsh &&
       -f $compiled/manifest && ! -e $compiled/.lock ]] ||
      test_fail "${missing:t}: the shell did not create a marked mirror" || return
    test_assert_equal 700 "$(command stat -f %Lp -- "$compiled")" \
      "${missing:t}: the created mirror is reachable by other accounts" || return
  done
}
test_case 'compiled peers: a missing mirror is created private and marked, filled and used without the installer' \
  _test_compiled_peers_create_missing_mirror

# Startup, the dump compile and the installer run Apple's /bin/zsh by its
# absolute path, never a zsh found on PATH, which may be a version-manager
# shim or a project's own binary: a PATH zsh that records any run stays unrun
# while the installer compiles, the first shell after an edit recompiles the
# peer with /bin/zsh, and a later shell compiles the completion dump.
_test_compiled_peers_never_run_path_zsh() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake="$TEST_TMP_DIR/project/bin" output=''
  local repository="$TEST_TMP_DIR/home-repository" marker="$TEST_TMP_DIR/path-zsh-ran"
  local compiled="$TEST_TMP_DIR/home/.zsh.addons/support/compiled"
  local script='PATH=$1:$PATH; builtin cd -q -- "${1:h}" || exit 1'$'\n'$_test_compiled_probe_script
  local -i run=0
  test_write_file "$fake/zsh" "#!/bin/sh
echo ran >> ${(qq)marker}
exit 1" && command chmod 0755 "$fake/zsh" || return
  command mkdir -p -- "$repository" &&
    command cp "$TEST_REPO_ROOT/.zshrc" "$TEST_REPO_ROOT/install.zsh" "$repository" &&
    command cp -R "$TEST_REPO_ROOT/templates" "$TEST_REPO_ROOT/.zsh.addons" "$repository" || return
  test_write_file "$repository/.zsh.addons/.zsh.zz-probe" 'probe() { print -r -- old; }' || return
  test_run_noninteractive "$home" 'PATH=$3:$PATH; source "$1/install.zsh" "--$2" --yes' \
    "$repository" symlink "$fake" > /dev/null 2> "$TEST_TMP_DIR/install.err" ||
    test_fail "installation with a PATH zsh failed: $(<"$TEST_TMP_DIR/install.err")" || return
  [[ ! -e $marker ]] || test_fail 'the installer ran the zsh found on PATH' || return
  output=$(test_run_interactive "$home" "$script" "$fake") || return
  test_assert_equal 'compiled|old' "$output" 'the installer did not compile with /bin/zsh' || return

  print -r -- 'probe() { print -r -- new; }' >| "$repository/.zsh.addons/.zsh.zz-probe" || return
  _test_compiled_tick || return
  output=$(test_run_interactive "$home" "$script" "$fake" 2> "$TEST_TMP_DIR/errors") || return
  [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$(<"$TEST_TMP_DIR/errors")" || return
  test_assert_equal 'compiled|new' "$output" 'startup did not recompile with /bin/zsh' || return
  for (( run = 1; run <= 3; run++ )); do
    [[ -f $compiled/zcompdump.zwc ]] && break
    _test_compiled_tick || return
    test_run_interactive "$home" "$script" "$fake" > /dev/null || return
  done
  [[ -f $compiled/zcompdump.zwc && -f $compiled/zcompdump.manifest ]] ||
    test_fail 'the completion dump was not compiled with /bin/zsh' || return
  [[ ! -e $marker ]] || test_fail 'startup or the dump compile ran the zsh found on PATH' || return
  test_assert_equal "zsh $(/bin/zsh -fc 'print -r -- $ZSH_VERSION')" \
    "${${(f)"$(<"$compiled/manifest")"}[2]}" 'the manifest names another Zsh' || return
}
test_case 'compiled peers: startup, the dump compile and the installer never run a PATH zsh, only /bin/zsh' \
  _test_compiled_peers_never_run_path_zsh

# compile.zsh refuses to compile for a shell of another Zsh version; instead
# it records in the mirror's zsh note which version this exact /bin/zsh is.
# While the note matches /bin/zsh's device, inode, size, mtime and ctime and
# names another version, startup and the dump compile start no compile child:
# the shell loads text and nothing is written. A note for another /bin/zsh,
# as after an OS update, is ignored and the next shells compile again.
_test_compiled_peers_skip_mismatched_bin_zsh() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" compiled='' identity='' version='' output=''
  local text_source="${TEST_REPO_ROOT:A}/.zsh.addons/.zsh.tools"
  local compile="${TEST_REPO_ROOT:A}/.zsh.addons/support/compile.zsh"
  local script='source "$HOME/.zshrc" || exit 1; print -r -- "${functions_source[mkcd]}"'
  local -A facts=()
  local -i run=0
  compiled="$home/.zsh.addons/support/compiled"
  _test_compiled_install "$TEST_REPO_ROOT" "$home" symlink || return
  # The first shell writes the dump; once the clock passed it, the second
  # compiles it.
  test_run_interactive "$home" "$script" > /dev/null && _test_compiled_tick &&
    test_run_interactive "$home" "$script" > /dev/null || return
  [[ -f $compiled/zcompdump.manifest ]] || test_fail 'the dump was not compiled' || return
  zmodload -F zsh/stat b:zstat || return
  zstat -H facts -- /bin/zsh || return
  identity="$facts[device]"$'\t'"$facts[inode]"$'\t'"$facts[size]"$'\t'"$facts[mtime]"
  identity+=$'\t'"$facts[ctime]"
  version=$(/bin/zsh -fc 'print -r -- $ZSH_VERSION') || return

  command rm -f -- "$compiled/manifest" "$compiled/zcompdump.manifest" || return
  if /bin/zsh -f -- "$compile" startup "${compiled:A}" "${TEST_REPO_ROOT:A}/.zsh.addons" \
      0.0-other .zsh.tools < /dev/null > /dev/null 2>&1; then
    test_fail 'compile.zsh compiled for another Zsh version'
    return 1
  fi
  [[ ! -e $compiled/manifest ]] || test_fail 'a refused compile wrote a manifest' || return
  test_assert_equal "compozsh-zsh 1"$'\n'"zsh $version"$'\n'"$identity" \
    "$(<"$compiled/zsh")" 'a refused compile did not record /bin/zsh' || return
  test_assert_equal 600 "$(command stat -f %Lp -- "$compiled/zsh")" \
    'the zsh note is reachable by other accounts' || return

  print -rl -- 'compozsh-zsh 1' 'zsh 0.0-other' "$identity" >| "$compiled/zsh" || return
  output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
  [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$(<"$TEST_TMP_DIR/errors")" || return
  test_assert_equal "$text_source" "$output" 'a peer loaded compiled code' || return
  [[ ! -e $compiled/manifest && ! -e $compiled/zcompdump.manifest ]] ||
    test_fail 'a compile child ran although /bin/zsh is another Zsh version' || return

  print -rl -- 'compozsh-zsh 1' 'zsh 0.0-other' $'0\t0\t0\t0\t0' >| "$compiled/zsh" || return
  for (( run = 1; run <= 4; run++ )); do
    output=$(test_run_interactive "$home" "$script") || return
    [[ $output == "$text_source" ]] || break
  done
  test_assert_equal "${compiled:A}/.zsh.addons/.zsh.tools" "$output" \
    'a note for another /bin/zsh stopped compiling' || return
  [[ -f $compiled/zcompdump.manifest ]] ||
    test_fail 'a note for another /bin/zsh stopped the dump compile' || return
}
test_case 'compiled peers: a /bin/zsh recorded as another Zsh version means text with no compile child' \
  _test_compiled_peers_skip_mismatched_bin_zsh

# Two shells starting together after every shipped peer changed both load the
# new code; at most one compiles at a time (the other loads text), and the
# mirror ends consistent: no lock or temporary file is left, and later shells
# load every shipped peer compiled.
_test_compiled_peers_concurrent_shells() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" shared='' output='' compiled=''
  local -a leftovers=()
  local -i run=0
  compiled="$home/.zsh.addons/support/compiled"
  _test_compiled_probe_install "$home" symlink || return
  shared=$REPLY
  print -r -- 'probe() { print -r -- new; }' >| "$shared/.zsh.zz-probe" || return
  command chmod 0640 "$shared"/**/.zsh.?*(D.) || return
  _test_compiled_tick || return
  test_run_interactive "$home" "$_test_compiled_probe_script" > "$TEST_TMP_DIR/first" 2>&1 &
  test_run_interactive "$home" "$_test_compiled_probe_script" > "$TEST_TMP_DIR/second" 2>&1 &
  wait
  [[ $(<"$TEST_TMP_DIR/first") == (text|compiled)\|new &&
     $(<"$TEST_TMP_DIR/second") == (text|compiled)\|new ]] ||
    test_fail "concurrent shells: $(<"$TEST_TMP_DIR/first") / $(<"$TEST_TMP_DIR/second")" || return
  leftovers=("$compiled"/.lock(DN) "$compiled"/**/*compozsh-tmp*(DN))
  (( ! $#leftovers )) || test_fail "left behind: ${leftovers[*]}" || return
  local script='source "$HOME/.zshrc" || exit 1
    print -r -- ${#${(M)${(v)functions_source}:#$1/*}} $(probe)'
  for (( run = 1; run <= 4; run++ )); do
    output=$(test_run_interactive "$home" "$script" "${shared:A}") || return
    [[ $output == '0 new' ]] && break
  done
  test_assert_equal '0 new' "$output" 'shipped peers still load as text after the concurrent start'
}
test_case 'compiled peers: concurrent shells after an update load new code and leave a consistent mirror' \
  _test_compiled_peers_concurrent_shells

# Temporary wordcode or manifests from an interrupted compile are never used
# and are removed, and an abandoned lock (over a minute old) is cleared. A live
# lock means another shell is compiling: this one loads text without writing.
_test_compiled_peers_interrupted_compile() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" shared='' output='' compiled='' before=''
  local -a leftovers=()
  compiled="$home/.zsh.addons/support/compiled"
  _test_compiled_probe_install "$home" symlink || return
  shared=$REPLY
  print -r -- 'probe() { print -r -- partial; }' >| "$TEST_TMP_DIR/partial" &&
    zcompile -R -- "$compiled/.zsh.addons/.zsh.zz-probe.compozsh-tmp-99999.zwc" \
      "$TEST_TMP_DIR/partial" &&
    print -r -- 'not a manifest' >| "$compiled/manifest.compozsh-tmp-99999" &&
    command mkdir -m 0700 -- "$compiled/.lock" &&
    command touch -t 202001010000 "$compiled/.lock" || return
  print -r -- 'probe() { print -r -- new; }' >| "$shared/.zsh.zz-probe" || return
  _test_compiled_tick || return
  output=$(test_run_interactive "$home" "$_test_compiled_probe_script" 2> "$TEST_TMP_DIR/errors") || return
  [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$(<"$TEST_TMP_DIR/errors")" || return
  test_assert_equal 'compiled|new' "$output" 'an abandoned lock or partial files blocked the compile' || return
  leftovers=("$compiled"/.lock(DN) "$compiled"/**/*compozsh-tmp*(DN))
  (( ! $#leftovers )) || test_fail "interrupted residue remains: ${leftovers[*]}" || return

  command mkdir -m 0700 -- "$compiled/.lock" || return
  print -r -- 'probe() { print -r -- newer; }' >| "$shared/.zsh.zz-probe" || return
  _test_compiled_tick || return
  before=$(_test_compiled_manifest_id "$compiled") || return
  output=$(test_run_interactive "$home" "$_test_compiled_probe_script") || return
  test_assert_equal 'text|newer' "$output" 'a shell compiled while another held the lock' || return
  test_assert_equal "$before" "$(_test_compiled_manifest_id "$compiled")" \
    'a shell wrote the manifest while another held the lock' || return
  [[ -d $compiled/.lock ]] || test_fail "a shell removed another shell's live lock" || return
  command rmdir -- "$compiled/.lock" || return
  output=$(test_run_interactive "$home" "$_test_compiled_probe_script") || return
  test_assert_equal 'compiled|newer' "$output" 'the released lock did not allow compiling'
}
test_case 'compiled peers: interrupted compiles are never used, abandoned locks clear and live locks mean text' \
  _test_compiled_peers_interrupted_compile

# Startup compile work is bounded: a shipped peer over 512 KiB loads as text,
# gets a text record, and later shells neither compile it nor rewrite the
# manifest.
_test_compiled_peers_bound_startup_compile() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" shared='' output='' compiled='' before='' line=''
  local -i index=0
  local -a body=()
  compiled="$home/.zsh.addons/support/compiled"
  _test_compiled_probe_install "$home" symlink || return
  shared=$REPLY
  for (( index = 1; index <= 9000; index++ )); do
    body+=("  : 'padding line $index of a large synthetic peer for the bound test'")
  done
  print -rl -- 'huge() {' "${body[@]}" '  print -r -- huge' '}' >| "$shared/.zsh.zz-huge" || return
  (( $(command stat -f %z -- "$shared/.zsh.zz-huge") > 524288 )) ||
    test_fail 'the synthetic peer is not over the bound' || return
  _test_compiled_tick || return
  local script='source "$HOME/.zshrc" || exit 1
    print -r -- "${functions_source[huge]#$1/}|$(huge)"'
  output=$(test_run_interactive "$home" "$script" "${shared:A}") || return
  test_assert_equal '.zsh.zz-huge|huge' "$output" 'the oversized peer did not load as text' || return
  [[ -n ${(M)${(f)"$(<"$compiled/manifest")"}:#-$'\t'.zsh.zz-huge$'\t'*} &&
     ! -e $compiled/.zsh.addons/.zsh.zz-huge.zwc ]] ||
    test_fail 'the oversized peer was compiled or lacks a text record' || return
  before=$(_test_compiled_manifest_id "$compiled") || return
  output=$(test_run_interactive "$home" "$script" "${shared:A}") || return
  test_assert_equal '.zsh.zz-huge|huge' "$output" 'the oversized peer changed origin' || return
  test_assert_equal "$before" "$(_test_compiled_manifest_id "$compiled")" \
    'a later shell tried to compile the oversized peer again'
}
test_case 'compiled peers: startup compile work is bounded and an oversized peer stays text' \
  _test_compiled_peers_bound_startup_compile

# Print, from a new shell in <home>, where compinit's dump came from (PROBE is
# set only by planted wordcode or dump text), _comp_dumpfile and whether the
# mirror entry is still the symlink to the dump.
typeset -g _test_compiled_dump_script='
  source "$HOME/.zshrc" || exit 1
  local mirror=${HOME:A}/.zsh.addons/support/compiled
  print -r -- "${PROBE-none}|${_comp_dumpfile#$HOME/}|$(command readlink -- "$mirror/zcompdump")"'

# Replace the mirror's compiled dump with wordcode made from the current dump
# plus a PROBE=compiled line, keeping its manifest record, so a shell reveals
# whether it loaded the wordcode. Usage: _test_compiled_dump_plant <home>
_test_compiled_dump_plant() {
  local compiled="$1/.zsh.addons/support/compiled"
  command mkdir -p -- "$TEST_TMP_DIR/plant" &&
    command cp -- "$1/.zcompdump" "$TEST_TMP_DIR/plant/zcompdump" &&
    print -r -- 'typeset -g PROBE=compiled' >> "$TEST_TMP_DIR/plant/zcompdump" &&
    command rm -f -- "$compiled/zcompdump.zwc" &&
    zcompile -R -- "$compiled/zcompdump.zwc" "$TEST_TMP_DIR/plant/zcompdump"
}

# Zsh's own source would take <dump>.zwc whenever it is not older than the
# dump. The completion dump's wordcode lives only in the private mirror and
# loads only while the dump's device, inode, size, mtime and ctime equal the
# compiled record: an edit, a same-size edit with its mtime restored or a
# replacement with an old mtime means the plain dump. An unsafe mirror or an
# initializer alias (which changes how the dump parses) means the plain dump.
_test_compiled_dump_never_runs_stale_code() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" compiled='' output='' dump=''
  local -a lines=()
  compiled="$home/.zsh.addons/support/compiled"
  dump="$home/.zcompdump"
  _test_compiled_install "$TEST_REPO_ROOT" "$home" symlink || return
  test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 || return
  _test_compiled_tick || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script" 2> "$TEST_TMP_DIR/errors") || return
  [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$(<"$TEST_TMP_DIR/errors")" || return
  [[ -L $compiled/zcompdump && -f $compiled/zcompdump.zwc &&
     -f $compiled/zcompdump.manifest && ! -e $dump.zwc ]] ||
    test_fail 'a later shell did not compile the dump into the mirror only' || return
  test_assert_equal "${dump:A}" "$(command readlink -- "$compiled/zcompdump")" \
    'the compiled dump entry does not link to the dump' || return
  lines=("${(@f)$(<"$compiled/zcompdump.manifest")}")
  test_assert_equal "compozsh-compiled-dump 1|zsh $ZSH_VERSION|dump ${dump:A}" \
    "${(j:|:)lines[1,3]}" 'the dump manifest header differs' || return
  test_assert_equal "$(command stat -f '%d %i %z %m %c' -- "$dump")" \
    "${lines[7]//$'\t'/ }" 'the dump manifest does not record exactly its identity' || return
  test_assert_equal 7 "${#lines}" 'the dump manifest records more than the dump identity' || return

  _test_compiled_dump_plant "$home" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal "compiled|.zcompdump|${dump:A}" "$output" \
    'a fresh compiled dump was not loaded through the mirror' || return

  # An edit appends a line; the next shell loads it, never older wordcode.
  print -r -- 'typeset -g PROBE=edited' >> "$dump" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal 'edited|.zcompdump' "${output%|*}" 'an edited dump ran stale wordcode' || return

  # Same size, same second, original mtime restored.
  _test_compiled_tick || return
  test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 || return
  _test_compiled_dump_plant "$home" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal 'compiled' "${output%%|*}" 'the recompiled dump was not used' || return
  command cp -p -- "$dump" "$TEST_TMP_DIR/dump.orig" &&
    command sed -i '' -e 's/PROBE=edited/PROBE=retime/' "$dump" &&
    command touch -r "$TEST_TMP_DIR/dump.orig" "$dump" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal 'retime' "${output%%|*}" 'a retimed same-size edit ran stale wordcode' || return

  # A replacement with an old mtime, moved over the dump.
  _test_compiled_tick || return
  test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 || return
  _test_compiled_dump_plant "$home" || return
  command sed -e 's/PROBE=retime/PROBE=moved/' "$dump" >| "$TEST_TMP_DIR/replacement" &&
    command touch -t 202001010000 "$TEST_TMP_DIR/replacement" &&
    command mv -f -- "$TEST_TMP_DIR/replacement" "$dump" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal 'moved' "${output%%|*}" 'a replaced dump ran stale wordcode' || return

  # A fresh record under an initializer alias, or in a group-readable mirror.
  _test_compiled_tick || return
  test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 || return
  _test_compiled_dump_plant "$home" || return
  print -r -- "alias ll='ls -l'" >| "$home/.zsh.addons/local/init.zsh" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal 'moved|.zcompdump' "${output%|*}" \
    'the compiled dump ran under a changed parse context' || return
  print -r -- ':' >| "$home/.zsh.addons/local/init.zsh" &&
    command chmod 0750 "$compiled" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal 'moved|.zcompdump' "${output%|*}" \
    'the compiled dump loaded from an unsafe mirror' || return
  command chmod 0700 "$compiled" || return
}
test_case 'compiled completion dump: an edited, retimed or replaced dump, an alias or an unsafe mirror means the plain dump' \
  _test_compiled_dump_never_runs_stale_code

# compaudit still guards fpath while the compiled dump is fresh. When fpath
# changes, compinit regenerates its dump even while loading through the
# mirror. The new dump still lands at its usual path (never left in the
# mirror), the shell completes the new command, and later shells compile it.
_test_compiled_dump_regenerates_at_usual_path() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" compiled='' output='' dump='' run=''
  local -a residue=()
  compiled="$home/.zsh.addons/support/compiled"
  dump="$home/.zcompdump"
  _test_compiled_install "$TEST_REPO_ROOT" "$home" symlink || return
  test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 || return
  _test_compiled_tick || return
  test_run_interactive "$home" 'source "$HOME/.zshrc"' > /dev/null 2>&1 || return
  [[ -f $compiled/zcompdump.zwc ]] || test_fail 'the dump was not compiled' || return
  _test_compiled_dump_plant "$home" || return
  output=$(test_run_interactive "$home" "$_test_compiled_dump_script") || return
  test_assert_equal 'compiled' "${output%%|*}" 'the planted compiled dump was not used' || return

  local script='
    source "$HOME/.zshrc" || exit 1
    print -r -- "${PROBE-none}|${_comps[zzprobe]-}|${_comp_dumpfile#$HOME/}"'

  # compaudit still checks fpath first: an insecure entry aborts compinit
  # (no answer on standard input) before any dump loads.
  command mkdir -p -- "$TEST_TMP_DIR/insecure" &&
    command chmod 777 "$TEST_TMP_DIR/insecure" || return
  print -r -- "fpath=(${(q)TEST_TMP_DIR}/insecure \$fpath)" >| "$home/.zsh.addons/local/init.zsh" || return
  output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors" < /dev/null) || return
  test_assert_contains "$(<"$TEST_TMP_DIR/errors")" 'compinit: initialization aborted' \
    'compaudit did not check fpath before the compiled dump' || return
  test_assert_equal 'none||' "$output" 'an aborted compinit still loaded a dump' || return
  test_assert_equal "${dump:A}" "$(command readlink -- "$compiled/zcompdump")" \
    'an aborted compinit changed the compiled dump entry' || return

  # Regeneration sources no dump, so the planted wordcode never runs.
  test_write_file "$TEST_TMP_DIR/extra/_zzprobe" '#compdef zzprobe' || return
  command chmod 755 "$TEST_TMP_DIR/extra" || return
  print -r -- "fpath=(${(q)TEST_TMP_DIR}/extra \$fpath)" >| "$home/.zsh.addons/local/init.zsh" || return
  output=$(test_run_interactive "$home" "$script" 2> "$TEST_TMP_DIR/errors") || return
  [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail "$(<"$TEST_TMP_DIR/errors")" || return
  test_assert_equal 'none|_zzprobe|.zcompdump' "$output" \
    'an fpath change did not regenerate the dump' || return
  [[ -f $dump && ! -L $dump && $(<"$dump") == *zzprobe* ]] ||
    test_fail 'the regenerated dump did not replace the dump at its usual path' || return
  [[ ! -f $compiled/zcompdump || -L $compiled/zcompdump ]] ||
    test_fail 'the regenerated dump was left in the mirror' || return
  residue=("$compiled"/zcompdump.*(DN) "$home"/.zcompdump?*(DN))
  residue=("${(@)residue:#*/zcompdump.(zwc|manifest)}")
  (( ! $#residue )) || test_fail "regeneration left: ${residue[*]}" || return

  for run in 1 2 3; do
    _test_compiled_tick || return
    output=$(test_run_interactive "$home" "$script") || return
    [[ -L $compiled/zcompdump && -f $compiled/zcompdump.zwc ]] && break
  done
  test_assert_equal 'none|_zzprobe|.zcompdump' "$output" 'the regenerated dump lost the new completion' || return
  [[ -L $compiled/zcompdump && -f $compiled/zcompdump.zwc ]] ||
    test_fail 'later shells did not recompile the regenerated dump' || return
}
test_case 'compiled completion dump: an fpath change regenerates the dump at its usual path and later shells recompile it' \
  _test_compiled_dump_regenerates_at_usual_path

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
