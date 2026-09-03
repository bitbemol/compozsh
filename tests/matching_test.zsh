# Matching consumes supplied text only; callers retain targets and ranking.

_test_matching_scoped_contract() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.matching" || exit 1
    (( ${+functions[_matching_compile]} && ${+functions[_matching_filter]} )) || exit 2
    local -a reply=(caller)
    local REPLY=scalar before=""
    before="${(j:,:)${(ok)parameters}}"
    source "$1/.zsh.addons/support/.zsh.matching" || exit 3
    [[ $reply[1] == caller && $REPLY == scalar ]] || exit 4
    [[ "${(j:,:)${(ok)parameters}}" == "$before" ]] || exit 5
    setopt KSH_ARRAYS SH_WORD_SPLIT GLOB_SUBST
    _matching_compile "a *" || exit 6
    [[ -o KSH_ARRAYS && -o SH_WORD_SPLIT && -o GLOB_SUBST ]] || exit 7
    unsetopt KSH_ARRAYS SH_WORD_SPLIT GLOB_SUBST
    [[ ${#reply} == 2 && $REPLY == scalar ]] || exit 8
    _matching_compile x unknown && exit 9
    [[ $? == 2 && ${#reply} == 0 ]] || exit 10
    print scoped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal scoped "$output"
}
test_case 'matching component has only scoped outputs and preserves caller options' \
  _test_matching_scoped_contract

_test_matching_literal_contract() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.matching" || exit 1
    setopt EXTENDED_GLOB
    local -a reply=() cases=(
      "*[?" "a*xxb[yyc?z" yes
      "]^-" "a]xxb^yyc-z" yes
      "\\~!" "a\\xxb~yyc!z" yes
      "(" "\\(" yes
      "*?" "\\*xx\\?" yes
      "[]" "\\[xx\\]" yes
      "^-" "\\^xx\\-" yes
      "Äω" "ä---Ω" yes
      "ωÄ" "ä---Ω" no
      "xxxz" "x-x-x-z" yes
      "xxxxz" "x-x-x-z" no
      "a b" "ax by" yes
    )
    local query candidate expected actual pattern
    for query candidate expected in "${cases[@]}"; do
      _matching_compile "$query" || exit 2
      pattern=$reply[2] actual=no
      [[ $candidate == ${~pattern} ]] && actual=yes
      [[ $actual == "$expected" ]] || {
        print -u2 -r -- "${(qqq)query} against ${(qqq)candidate}: $actual"
        exit 3
      }
    done
    query="literal \$(touch sentinel) \\ [*] (#i) <-> ~ ^ |"
    _matching_compile "$query" || exit 4
    pattern=$reply[1]
    [[ $query == ${~pattern} && ! -e sentinel ]] || exit 5
    _matching_compile ab word || exit 6
    pattern=$reply[2]
    [[ "a-only a-b" == ${~pattern} && "a b" != ${~pattern} ]] || exit 7
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'matching component treats punctuation Unicode and shell text literally' \
  _test_matching_literal_contract

_test_matching_generated_equivalence() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.matching" || exit 1
    setopt EXTENDED_GLOB
    local -a reply=() alphabet=(a A b " " "*" "\\" "]" Ä)
    local -a queries=("") candidates=("")
    local first second third query candidate mode old current character
    local -i position expected actual checks=0
    for first in "${alphabet[@]}"; do
      queries+=("$first") candidates+=("$first")
      for second in "${alphabet[@]}"; do
        queries+=("$first$second") candidates+=("$first$second")
        for third in "${alphabet[@]}"; do
          candidates+=("$first$second$third")
        done
      done
    done
    for mode in characters word; do
      for query in "${queries[@]}"; do
        old="(#i)*" position=0
        for character in "${(@s::)query}"; do
          if (( position )); then
            [[ $mode == word ]] && old+="[^[:space:]]#" || old+="*"
          fi
          old+=${(b)character}
          (( ++position ))
        done
        (( position )) && old+="*"
        _matching_compile "$query" "$mode" || exit 2
        current=$reply[2]
        for candidate in "${candidates[@]}"; do
          expected=0 actual=0
          [[ $candidate == ${~old} ]] && expected=1
          [[ $candidate == ${~current} ]] && actual=1
          (( ++checks ))
          (( actual == expected )) || {
            print -u2 -r -- "$mode ${(qqq)query} ${(qqq)candidate}: $expected != $actual"
            exit 3
          }
        done
      done
    done
    print -r -- "$checks equivalent"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '85410 equivalent' "$output"
}
test_case 'matching component agrees with prior whole-query and word-gap semantics across generated inputs' \
  _test_matching_generated_equivalence

_test_matching_filter_indexes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/.zsh.matching" || exit 1
    local -a reply=() texts=("" "A*b" "a---*---b" "A*b" unrelated)
    local pattern
    _matching_compile "a*b" || exit 2
    pattern=$reply[2]
    _matching_filter "$pattern" 2 "${texts[@]}" || exit 3
    [[ ${(j:,:)reply} == 2,3 ]] || exit 4
    _matching_filter "$pattern" 9999999999999999999999999999999999999999 "${texts[@]}" || exit 5
    [[ ${(j:,:)reply} == 2,3,4 ]] || exit 6
    _matching_filter "*" 0003 "${texts[@]}" || exit 7
    [[ ${(j:,:)reply} == 1,2,3 && ${#texts} == 5 && $texts[1] == "" ]] || exit 8
    _matching_filter "*" 0 "${texts[@]}" || exit 9
    (( ${#reply} == 0 )) || exit 10
    _matching_filter "*" 5 || exit 11
    (( ${#reply} == 0 )) || exit 12
    _matching_filter "*" "1+2" "${texts[@]}" && exit 13
    [[ $? == 2 && ${#reply} == 0 ]] || exit 14
    _matching_filter "*" -1 "${texts[@]}" && exit 15
    [[ $? == 2 && ${#reply} == 0 ]] || exit 16
    print indexes
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal indexes "$output"
}
test_case 'matching component returns stable captured indexes within validated result bounds' \
  _test_matching_filter_indexes

_test_matching_long_and_repeated_inputs() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.matching" || exit 1
    local -a reply=()
    local pattern label mode
    for mode in characters word; do
      _matching_compile xxxxxxxxz "$mode" || exit 2
      pattern=$reply[2]
      _matching_filter "$pattern" 10 "feature/${(l:130::x:)}" "x-x-x-x-x-x-x-x-z" || exit 3
      [[ ${(j:,:)reply} == 2 ]] || exit 4
    done
    for label in "${(l:262000::x:)}zyxz" "${(l:130000::é:)}zyxz"; do
      _matching_compile yz || exit 5
      pattern=$reply[2]
      _matching_filter "$pattern" 10 "$label" || exit 6
      [[ ${(j:,:)reply} == 1 ]] || exit 7
      _matching_compile yaz || exit 8
      pattern=$reply[2]
      _matching_filter "$pattern" 10 "$label" || exit 9
      (( ${#reply} == 0 )) || exit 10
    done
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'matching component consumes repeated characters and capture-sized labels without backtracking' \
  _test_matching_long_and_repeated_inputs

_test_matching_unordered_data_interface() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/support/.zsh.matching" || exit 1
    (( ${+functions[_matching_compile_fragments]} && ${+functions[_matching_search]} )) || exit 2
    setopt EXTENDED_GLOB
    local -a reply=() texts=("alpha/project" "Project/a-l-p-h-a" "alpha/else" "project/alpha")
    local literal_pattern fuzzy_pattern
    _matching_compile_fragments "alpha project" || exit 3
    [[ $reply[1] == "alpha project" && ${#reply} == 3 ]] || exit 4
    literal_pattern=$reply[2] fuzzy_pattern=$reply[3]
    [[ $texts[1] == ${~literal_pattern} && $texts[2] != ${~literal_pattern} &&
       $texts[2] == ${~fuzzy_pattern} && $texts[3] != ${~fuzzy_pattern} ]] || exit 5
    _matching_search "alpha project" 10 "${texts[@]}" || exit 6
    [[ ${(j:,:)reply} == 1,2,4 ]] || exit 7
    _matching_search "project alpha" 2 "${texts[@]}" || exit 8
    [[ ${(j:,:)reply} == 1,2 ]] || exit 9
    _matching_search "Äω *[" 10 "ä--Ω/\\*x\\[" "ä--Ω/plain" || exit 10
    [[ ${(j:,:)reply} == 1 ]] || exit 11
    _matching_search "" 3 "" one two three || exit 12
    [[ ${(j:,:)reply} == 1,2,3 ]] || exit 13
    _matching_search "   " 3 "" one two three || exit 14
    [[ ${(j:,:)reply} == 1,2,3 ]] || exit 15
    _matching_search "alpha" 0 "${texts[@]}" || exit 16
    (( ${#reply} == 0 )) || exit 17
    local IFS=:
    _matching_search "project alpha" 10 "${texts[@]}" || exit 18
    [[ ${(j:,:)reply} == 1,2,4 && $IFS == : ]] || exit 19
    print unordered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal unordered "$output"
}
test_case 'matching component searches supplied data with literal keywords in any order' \
  _test_matching_unordered_data_interface
