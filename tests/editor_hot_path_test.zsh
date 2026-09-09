_test_autosuggest_long_literal_prefix_characterization() {
  test_make_temp_dir || return
  local prefix='literal [*] $(print not-executed) '
  prefix+="${(l:4096::x:):-}"
  local history_contents="${prefix} oldest"$'\n'
  history_contents+="${prefix[1,64]}wrong remainder"$'\n'
  history_contents+="${prefix} newest"$'\n'
  history_contents+="${prefix}"$'\n'
  history_contents+="${prefix}"$'\t''unsafe newer entry'$'\n'
  history_contents+='terminal sentinel'
  test_write_file "$TEST_TMP_DIR/history" "$history_contents" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    HISTSIZE=1000
    fc -p "$2"
    local prefix=$3
    _zle_autosuggest_find "$prefix" || exit 1
    [[ $_ZLE_AUTOSUGGEST_CACHE_FULL == "$prefix newest" ]] || exit 2
    _zle_autosuggest_find "${prefix} missing"
    [[ $? == 1 && -z $_ZLE_AUTOSUGGEST_CACHE_FULL ]] || exit 3
    print newest-safe-literal
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/history" "$prefix") || return
  test_assert_equal newest-safe-literal "$output"
}
test_case 'autosuggestions retain full long literal prefixes and choose the newest safe longer command' \
  _test_autosuggest_long_literal_prefix_characterization

_test_autosuggest_prefix_boundaries_and_options() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    local -i length=0 result=0
    local prefix="" expected=""
    for length in 63 64 65 255 256 257 513 4097; do
      prefix="${(l:$length::é:):-}"
      expected="$prefix newest"
      print -rl -- "$prefix older" "$expected" "${prefix}different" "terminal sentinel" >| "$HOME/history"
      fc -p "$HOME/history" 1000
      # Exact matching must include text after the common long Unicode prefix.
      prefix+=" "
      setopt SH_WORD_SPLIT RC_EXPAND_PARAM GLOB_SUBST KSH_ARRAYS NO_NOMATCH NO_UNSET
      if _zle_autosuggest_find "$prefix"; then result=0; else result=$?; fi
      emulate -R zsh
      [[ $result == 0 && $_ZLE_AUTOSUGGEST_CACHE_FULL == "$expected" ]] || {
        print -u2 -- "suggestion changed at prefix length $length"; exit 1
      }
      fc -P
    done
    print exact-boundaries
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal exact-boundaries "$output"
}
test_case 'autosuggestions preserve exact Unicode prefix boundaries under unusual caller options' \
  _test_autosuggest_prefix_boundaries_and_options

_test_autosuggest_repeated_prefix_history_characterization() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    local prefix="${(l:4096::é:):-}" entry=""
    local -i index=0
    {
      print -r -- "$prefix newest safe completion"
      # Nearer entries cannot complete the whole draft, even though they share
      # the same beginning. Exact entries also cannot provide a suffix.
      for (( index=0; index<510; ++index )); do
        if (( index % 2 )); then entry=$prefix; else entry=${prefix[1,64]}; fi
        print -r -- "$entry"
      done
      print -r -- "terminal sentinel"
    } >| "$HOME/history"
    fc -p "$HOME/history" 1000
    _zle_autosuggest_find "$prefix" || exit 1
    [[ $_ZLE_AUTOSUGGEST_CACHE_FULL == "$prefix newest safe completion" ]] || exit 2
    fc -P
    # A short draft can still complete a very long Unicode history entry.
    entry="git ${prefix} tail"
    print -rl -- "$entry" "terminal sentinel" >| "$HOME/history"
    fc -p "$HOME/history" 1000
    _zle_autosuggest_find git || exit 3
    [[ $_ZLE_AUTOSUGGEST_CACHE_FULL == "$entry" ]] || exit 4
    fc -P
    print repeated-prefix-history
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal repeated-prefix-history "$output"
}
test_case 'autosuggestions retain safe completions across dense repeated prefixes and long Unicode entries' \
  _test_autosuggest_repeated_prefix_history_characterization

_test_numeric_token_grammar_characterization() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.highlighting"
    local value="" quoted="" form=""
    local -i result=0
    local -a numbers=(0 123 +123 -123 .5 -.5 +.5 1. 1.0 -1.25e+3 1E-2
      0xFF 0X10 -0xff +0XFF 2#101 16#fF -16#ff 99#underscore_)
    local -a others=(word --option . + - +. -+1 0x 0xGG 12x 1e 1e+ 1# 1#x!
      nan inf NaN Infinity １２ " 1" "1 " "\$(print 42)")
    for value in "${numbers[@]}"; do
      for form in literal quoted; do
        quoted=$value
        [[ $form == quoted ]] && quoted="\"$value\""
        setopt SH_WORD_SPLIT RC_EXPAND_PARAM GLOB_SUBST KSH_ARRAYS NO_NOMATCH NO_UNSET
        if _zle_is_number "$quoted"; then result=0; else result=$?; fi
        emulate -R zsh
        (( result == 0 )) || { print -u2 -- "number rejected: $quoted"; exit 1; }
      done
    done
    for value in "${others[@]}" ""; do
      _zle_is_number "$value"
      [[ $? == 1 ]] || { print -u2 -- "nonnumeric token accepted: $value"; exit 2; }
    done
    print numeric-grammar
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal numeric-grammar "$output"
}
test_case 'syntax numeric classification preserves signed quoted exponent hexadecimal and base grammar' \
  _test_numeric_token_grammar_characterization
