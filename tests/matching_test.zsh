# Matching consumes supplied text only; callers retain targets and ranking.

_test_matching_scoped_contract() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    (( ${+functions[_matching_compile]} && ${+functions[_matching_select]} )) || exit 2
    local -a reply=(caller)
    local REPLY=scalar before=""
    before="${(j:,:)${(ok)parameters}}"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 3
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
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

_test_matching_source_indexes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    local -a reply=() texts=("" "A*b" "a---*---b" "A*b" unrelated) empty=()
    _matching_select source "a*b" 2 texts texts || exit 2
    [[ ${(j:,:)reply} == 2,3 ]] || exit 3
    _matching_select source "a*b" 9999999999999999999999999999999999999999 texts texts || exit 4
    [[ ${(j:,:)reply} == 2,3,4 ]] || exit 5
    _matching_select source "" 0003 texts texts || exit 6
    [[ ${(j:,:)reply} == 1,2,3 && ${#texts} == 5 && $texts[1] == "" ]] || exit 7
    _matching_select source "" 0 texts texts || exit 8
    (( ${#reply} == 0 )) || exit 9
    _matching_select source "" 5 empty empty || exit 10
    (( ${#reply} == 0 )) || exit 11
    _matching_select source "" "1+2" texts texts && exit 12
    [[ $? == 2 && ${#reply} == 0 ]] || exit 13
    _matching_select source "" -1 texts texts && exit 14
    [[ $? == 2 && ${#reply} == 0 ]] || exit 15
    print indexes
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal indexes "$output"
}
test_case 'matching component returns stable captured indexes within validated result bounds' \
  _test_matching_source_indexes

_test_matching_long_and_repeated_inputs() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    setopt EXTENDED_GLOB
    local -a reply=()
    local pattern label mode
    for mode in characters word; do
      _matching_compile xxxxxxxxz "$mode" || exit 2
      pattern=$reply[2]
      [[ "feature/${(l:130::x:)}" != ${~pattern} ]] || exit 3
      [[ "x-x-x-x-x-x-x-x-z" == ${~pattern} ]] || exit 4
    done
    for label in "${(l:262000::x:)}zyxz" "${(l:130000::é:)}zyxz"; do
      _matching_compile yz || exit 5
      pattern=$reply[2]
      [[ $label == ${~pattern} ]] || exit 6
      _matching_compile yaz || exit 7
      pattern=$reply[2]
      [[ $label != ${~pattern} ]] || exit 8
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
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    (( ${+functions[_matching_compile_fragments]} )) || exit 2
    setopt EXTENDED_GLOB
    local -a reply=() texts=("alpha/project" "Project/a-l-p-h-a" "alpha/else" "project/alpha")
    local literal_pattern fuzzy_pattern query text
    _matching_compile_fragments "alpha project" || exit 3
    [[ $reply[1] == "alpha project" && ${#reply} == 3 ]] || exit 4
    literal_pattern=$reply[2] fuzzy_pattern=$reply[3]
    [[ $texts[1] == ${~literal_pattern} && $texts[2] != ${~literal_pattern} &&
       $texts[1] == ${~fuzzy_pattern} && $texts[2] == ${~fuzzy_pattern} &&
       $texts[3] != ${~fuzzy_pattern} && $texts[4] == ${~fuzzy_pattern} ]] || exit 5
    _matching_compile_fragments "project alpha" || exit 6
    fuzzy_pattern=$reply[3]
    [[ $texts[1] == ${~fuzzy_pattern} && $texts[2] == ${~fuzzy_pattern} &&
       $texts[3] != ${~fuzzy_pattern} && $texts[4] == ${~fuzzy_pattern} ]] || exit 7
    _matching_compile_fragments "Äω *[" || exit 8
    fuzzy_pattern=$reply[3]
    [[ "ä--Ω/\\*x\\[" == ${~fuzzy_pattern} && "ä--Ω/plain" != ${~fuzzy_pattern} ]] || exit 9
    for query in "" "   "; do
      _matching_compile_fragments "$query" || exit 10
      [[ ${#reply} == 3 && $reply[2] == "(#i)*" && $reply[3] == "(#i)*" ]] || exit 11
      for text in "" one two three; do
        [[ $text == ${~reply[3]} ]] || exit 12
      done
    done
    local IFS=:
    _matching_compile_fragments "project alpha" || exit 13
    fuzzy_pattern=$reply[3]
    [[ $texts[1] == ${~fuzzy_pattern} && $texts[2] == ${~fuzzy_pattern} &&
       $texts[3] != ${~fuzzy_pattern} && $texts[4] == ${~fuzzy_pattern} && $IFS == : ]] || exit 14
    print unordered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal unordered "$output"
}
test_case 'matching component searches supplied data with literal keywords in any order' \
  _test_matching_unordered_data_interface

_test_matching_selection_ranks_after_gaps() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    local -a reply=() values=(miss fuzzy duplicate prefix gap duplicate unicode tail)
    local -a texts=(unrelated "a---b" "in ab" AB nope "other AB" "日本/Äω" "a---b")
    _matching_select ranked ab 20 values texts || exit 2
    [[ ${(j:,:)reply} == 4,3,2,8 ]] || exit 3
    _matching_select source ab 20 values texts || exit 4
    [[ ${(j:,:)reply} == 2,3,4,6,8 ]] || exit 5
    _matching_select ranked ab 2 values texts "" text in || exit 6
    [[ ${(j:,:)reply} == 4,6 ]] || exit 7
    _matching_select ranked "" 3 values texts "" text unrelated || exit 8
    [[ ${(j:,:)reply} == 2,3,4 ]] || exit 9
    _matching_select ranked "" 20 values texts || exit 10
    [[ ${(j:,:)reply} == 1,2,3,4,5,6,7,8 ]] || exit 11
    local -a extras=("" "" "" none "" "" "" "")
    _matching_select ranked ab 20 values texts extras fallback || exit 12
    [[ ${(j:,:)reply} == 3,2,8 ]] || exit 13
    values=(one two three four) texts=(zz zz zz AB) extras=(ab "a--b" "" none)
    _matching_select ranked ab 20 values texts extras fallback || exit 14
    [[ ${(j:,:)reply} == 1,2 ]] || exit 15
    _matching_select ranked ab 20 values texts extras append || exit 16
    [[ ${(j:,:)reply} == 4,1,2 ]] || exit 17
    print ordered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal ordered "$output"
}
test_case 'matching selection retains ranking source indexes exclusions and text policies after gaps' \
  _test_matching_selection_ranks_after_gaps

_test_matching_selection_literal_gaps_and_short_arrays() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done || exit 1
    local -a reply=() values=(first second third fourth fifth) texts=()
    local query="" mode=""
    for query in "[]" "]^-" "\\" "(#i)" "\$(touch sentinel)" "\${value}" "Äω" "é" "👨‍👩‍👦"; do
      texts=(unrelated "before $query after" unrelated "$query")
      for mode in source ranked; do
        _matching_select "$mode" "$query" 20 values texts || exit 2
        if [[ $mode == source ]]; then
          [[ ${(j:,:)reply} == 2,4 ]] || exit 3
        else
          [[ ${(j:,:)reply} == 4,2 ]] || exit 4
        fi
      done
    done
    [[ ! -e sentinel ]] || exit 5
    texts=(unrelated unrelated match)
    _matching_select ranked match 20 values texts || exit 6
    [[ ${(j:,:)reply} == 3 ]] || exit 7
    _matching_select ranked missing 20 values texts || exit 8
    (( ${#reply} == 0 )) || exit 9
    texts=()
    _matching_select source match 20 values texts || exit 10
    (( ${#reply} == 0 )) || exit 11
    _matching_select source match 20 values absent_texts || exit 12
    (( ${#reply} == 0 )) || exit 13
    values=(one two) texts=(unrelated match match)
    setopt KSH_ARRAYS SH_WORD_SPLIT GLOB_SUBST
    _matching_select ranked match 20 values texts || exit 14
    [[ -o KSH_ARRAYS && -o SH_WORD_SPLIT && -o GLOB_SUBST ]] || exit 15
    unsetopt KSH_ARRAYS SH_WORD_SPLIT GLOB_SUBST
    [[ ${(j:,:)reply} == 2 && ${#values} == 2 && ${#texts} == 3 ]] || exit 16
    print literal
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal literal "$output"
}
test_case 'matching selection keeps skipped punctuation literal and terminates with incomplete text arrays' \
  _test_matching_selection_literal_gaps_and_short_arrays
