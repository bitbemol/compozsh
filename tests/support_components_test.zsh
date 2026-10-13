# Every support component remains an ordinary independently sourceable peer.
_test_support_components_standalone() {
  test_make_temp_dir || return
  local unit='' output=''
  local -a units=("$TEST_REPO_ROOT"/.zsh.addons/support/{ui,functions}/.zsh.*(N.))
  (( ${#units} )) || { test_fail 'focused support components are absent'; return 1; }
  for unit in "${units[@]}"; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1" || exit 1
      source "$1" || exit 2
      print ready
    ' "$unit" 2>&1) || return
    test_assert_equal ready "$output" "standalone component emitted diagnostics: ${unit:t}" || return
  done
}
test_case 'support components source independently and repeatedly without diagnostics' \
  _test_support_components_standalone

_test_support_function_entry_points() {
  test_make_temp_dir || return
  local unit='' line='' entry='' first='' output=''
  local -a units=("$TEST_REPO_ROOT"/.zsh.addons/support/functions/.zsh.*(N.))
  (( ${#units} )) || { test_fail 'classified shared functions are absent'; return 1; }
  units+=("$TEST_REPO_ROOT"/.zsh.addons/support/ui/.zsh.ui.*(N.))
  for unit in "${units[@]}"; do
    [[ ${unit:t} == .zsh.ui.state ]] && continue
    if [[ ${unit:h:t} == functions && ${unit:t} != .zsh.(pure|impure).* ]]; then
      test_fail "shared function has no purity classification: ${unit:t}"
      return 1
    fi
    entry='' first=''
    while IFS= read -r line; do
      [[ $line == '# Entry point: '* ]] && entry=${line#\# Entry point: }
      if [[ $line == *'() {' && $line != ' '* ]]; then
        first=${line%%\(\)*}
        break
      fi
    done < "$unit"
    [[ -n $entry && $entry == "$first" && ${unit:t} == *.${entry#_} ]] || {
      test_fail "entry point must be first and match filename: ${unit:t}"
      return 1
    }
    output=$(test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1" || exit 1
      source "$1" || exit 2
      print ready
    ' "$unit") || return
    test_assert_equal ready "$output" || return
  done
}
test_case 'support function filenames classify a single first entry point' \
  _test_support_function_entry_points

_test_support_private_helper_ownership() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zshrc" || exit 1
    zmodload zsh/parameter
    local -A entries=()
    local unit line helper caller owner pattern
    for unit in "$1"/.zsh.addons/support/{functions,ui}/.zsh.*(N.); do
      while IFS= read -r line; do
        if [[ $line == "# Entry point: "* ]]; then
          entries[$unit]=${line#\# Entry point: }
          break
        fi
      done < "$unit"
    done
    for helper in ${(k)functions}; do
      owner=${functions_source[$helper]-}
      [[ -n ${entries[$owner]-} && $helper != ${entries[$owner]} ]] || continue
      pattern="(^|[^a-zA-Z0-9_-])${helper}([^a-zA-Z0-9_-]|$)"
      for caller in ${(k)functions}; do
        [[ ${functions_source[$caller]-} == "$owner" ]] && continue
        if [[ ${functions[$caller]} =~ $pattern ]]; then
          print -u2 -r -- "$caller calls private helper $helper from another file"
          exit 2
        fi
      done
    done
    print owned
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal owned "$output"
}
test_case 'support private helpers stay inside their owning production entry' \
  _test_support_private_helper_ownership

# Pure support entries compute from explicit inputs and return through
# caller-local REPLY/reply (engineering/architecture.md, "Pure entries stay
# pure"). This scan reads Zsh's normalized body of every function loaded from
# a .zsh.pure.* file and reports the usual ways purity breaks: calls into
# impure, UI or feature-peer code; commands other than effect-free builtins;
# command or process substitution; subshells and pipelines; redirections,
# here-strings and here-documents (Zsh backs both with temporary files); file
# tests; `(e)`, `(D)` and `(%%)` expansion; background jobs; global or printing
# declarations; reads of non-local parameters such as $COLUMNS, in (( )) and
# in the declaration that binds them too; and assignments, loop variables,
# shift or unset targets, option changes or match parameters that escape the
# function. It is a regression aid, not a proof: filename generation,
# `(%)` and `~` expansion, names built at run time, bare names evaluated as
# arithmetic outside (( )) and reads hidden by unusual quoting are not traced,
# so review still audits the whole call chain. Add a builtin to the allowlist
# only when it reads and writes nothing beyond the function's own locals and
# the user agrees.
_test_support_purity_scan() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local root=${1:A} name='' body='' token='' mode='' var='' needed=''
  local rest='' previous='' MATCH=''
  local -A pure=() allowed=() locals=() files=()
  local -a tokens=() pending=() problems=() match=() mbegin=() mend=() declared=()
  local -i i=0 first=0 command_position=0 global=0 depth=0 MBEGIN=0 MEND=0
  zmodload zsh/parameter || return 1
  for name in ${(k)functions}; do
    [[ ${functions_source[$name]-} == "$root"/.zsh.addons/support/functions/.zsh.pure.* ]] ||
      continue
    pure[$name]=1 files[${functions_source[$name]}]=1
  done
  for token in local typeset integer float setopt unsetopt unset shift return \
      break continue true false : repeat; do
    allowed[$token]=1
  done
  for name in ${(ko)pure}; do
    body=${functions[$name]}
    tokens=(${(z)body}) locals=(REPLY 1 reply 1 argv 1)
    for token in $tokens; do
      [[ $token == (*\$\([^\(]*|*\`*|(*=|)[\<\>=]\(*) ]] &&
        problems+=("$name runs a command or process substitution: $token")
      [[ $token == \&(|\!|\|) ]] && problems+=("$name starts a background job: $token")
    done
    for (( i = 1; i <= ${#tokens}; i++ )); do
      [[ $tokens[i] == (local|typeset|integer|float|declare) ]] || continue
      global=0 first=$(( i + 1 )) declared=()
      while (( ++i <= ${#tokens} )) && [[ $tokens[i] != (\;|\&\&|\|\||\|) ]]; do
        if [[ $tokens[i] == [-+]* ]]; then
          [[ $tokens[i] == -*g* ]] &&
            global=1 problems+=("$name declares a global: $tokens[i]")
          [[ $tokens[i] == (+*|-*[mp]*) ]] &&
            global=1 problems+=("$name prints or matches parameters with $tokens[i]")
        elif (( ! global )); then
          locals[${tokens[i]%%[=\[]*}]=1 declared+=(${tokens[i]%%[=\[]*})
        fi
      done
      # One declaration expands every right-hand side before binding, so a
      # name it declares still reads the caller's value there.
      for token in ${tokens[first,i-1]}; do
        [[ $token == *=* ]] || continue
        rest=${token#*=}
        while [[ $rest =~ '\$\{?(\([^)]*\))?[#+^=~]*([A-Za-z_][A-Za-z0-9_]*)' ]]; do
          rest=${rest#*"$MATCH"}
          (( ${declared[(Ie)$match[2]]} )) &&
            problems+=("$name reads $match[2] in the declaration that binds it")
        done
      done
      (( i-- ))
    done
    # Parameters are inputs only when local; ${+functions[...]} checks a
    # pure callee's presence. Names built at run time (${(P)...}) are not traced.
    rest=${${body//\\\$/}//\'[^\']#\'/}
    while [[ $rest =~ '\$\{?(\([^)]*\))?([#+^=~]*)([A-Za-z_][A-Za-z0-9_]*)' ]]; do
      rest=${rest#*"$MATCH"}
      [[ -n ${locals[$match[3]]-} ]] && continue
      [[ $match[3] == functions && $match[2] == *+* ]] && continue
      problems+=("$name reads non-local $match[3]")
    done
    # Arithmetic names, assigned or read, in (( )), $(( )) and for (( )).
    rest=$body
    while [[ $rest =~ '\(\(([^()]|\([^()]*\))*\)\)' ]]; do
      rest=${rest#*"$MATCH"} token=${${${MATCH//\$\{[^\}]#\}/}//\$[A-Za-z0-9_]#/}//[0-9]##\#[A-Za-z0-9_]#/}
      for var in ${(M)${=${token//[^A-Za-z0-9_]/ }}:#[A-Za-z_]*}; do
        [[ -n ${locals[$var]-} ]] || problems+=("$name uses non-local $var in arithmetic")
      done
    done
    rest=$body
    while [[ $rest =~ '\$\{\(([^)]*)\)' ]]; do
      rest=${rest#*"$MATCH"}
      [[ ${match[1]//:[^:]#:/} == *e* ]] &&
        problems+=("$name evaluates text with the (e) flag: $MATCH")
      [[ ${match[1]//:[^:]#:/} == *(D|%%)* ]] &&
        problems+=("$name reads home or prompt state with a (D) or (%%) flag: $MATCH")
    done
    needed=''
    (( ${tokens[(Ie)=~]} )) && needed='match mbegin mend MATCH MBEGIN MEND'
    [[ $body == *\(\#[^\)]#b[^\)]#\)* ]] && needed+=' match mbegin mend'
    [[ $body == *\(\#[^\)]#m[^\)]#\)* ]] && needed+=' MATCH MBEGIN MEND'
    for var in ${(us: :)needed}; do
      [[ -n ${locals[$var]-} ]] ||
        problems+=("$name sets match parameters without a local $var")
    done
    mode='' command_position=1 pending=() previous=''
    for (( i = 1; i <= ${#tokens}; i++ )); do
      token=$tokens[i]
      case $mode in
        (condition)
          if [[ $token == \]\] ]]; then
            mode='' command_position=0
          elif [[ $token == -(nt|ot|ef) ||
              ( $token == -[abcdefghkopqrstuwxLOGNS] && $previous == (\[\[|\!|\&\&|\|\||\() ) ]]; then
            problems+=("$name tests the filesystem or shell state: $token")
          fi
          previous=$token
          continue ;;
        (array) [[ $token == \) ]] && mode=''; continue ;;
        (loop) [[ $token == do ]] && mode='' command_position=1; continue ;;
        (case-word) [[ $token == in ]] && mode=pattern depth=0; continue ;;
        (pattern)
          # Count parentheses: ((#i)x*) and ((a|b)c) close at the outer ).
          [[ $token == \( ]] && (( ++depth ))
          [[ $token == \) ]] && (( --depth == 0 )) && mode='' command_position=1
          [[ $token == esac ]] && mode='' command_position=0
          continue ;;
      esac
      if [[ $token == (\;|\;\;|\;\&|\;\||\&\&|\|\||\||\|\&|\{|\(|then|do|else|elif|if|while|until|\!|\(\)|always) ]]; then
        for var in $pending; do
          [[ -n ${locals[$var]-} ]] || problems+=("$name assigns non-local $var")
        done
        [[ $token == \|(|\&) ]] && problems+=("$name forks a pipeline: $token")
        [[ $token == \( ]] && (( command_position )) &&
          problems+=("$name forks a subshell")
        pending=() command_position=1
        [[ $token == \;[\;\&\|] ]] && mode=pattern depth=0
        continue
      fi
      # A closing } or ) ends a command; anonymous-function arguments follow }.
      if [[ $token == (fi|done|esac|\}|\)) ]]; then
        command_position=0
        continue
      fi
      if [[ $token == (\<\<\<|\<\<|\<\<-) ]]; then
        problems+=("$name uses a here-string or here-document, which Zsh backs with a temporary file")
        (( ++i ))
        # A here-document body is data up to its delimiter, not commands.
        [[ $token == \<\<\< ]] || var=${(Q)tokens[i]}
        [[ $token == \<\<\< ]] ||
          while (( ++i < ${#tokens} )) && [[ $tokens[i] != "$var" ]]; do :; done
        continue
      fi
      if [[ $token == (\&|[0-9]#)[\<\>]* ]]; then
        problems+=("$name redirects to or from a file or descriptor: $token")
        (( ++i ))
        continue
      fi
      (( command_position )) || continue
      if [[ $token == [A-Za-z_][A-Za-z0-9_]#(\[*\])#(\+|)\=* ]]; then
        pending+=(${token%%[\[+=]*})
        [[ $token == *\=\( ]] && mode=array
        continue
      fi
      pending=() command_position=0
      case $token in
        (\[\[) mode=condition previous=$token ;;
        (\(\(*) ;;
        (case) mode=case-word ;;
        (for)
          while [[ $tokens[i+1] == [A-Za-z_][A-Za-z0-9_]# && $tokens[i+1] != in ]] && (( ++i )); do
            [[ -n ${locals[$tokens[i]]-} ]] || problems+=("$name loops with non-local $tokens[i]")
          done
          mode=loop ;;
        (emulate)
          [[ $tokens[i+1] == -L* ]] ||
            problems+=("$name runs emulate without -L, changing the caller's options")
          while (( ++i <= ${#tokens} )) && [[ $tokens[i] != (\;|\&\&|\|\||\|) ]]; do
            [[ $tokens[i] == -*c* ]] && problems+=("$name evaluates code with emulate -c")
          done
          (( i-- )) ;;
        (shift)
          [[ $tokens[i+1] == [A-Za-z_][A-Za-z0-9_]# && -z ${locals[$tokens[i+1]]-} ]] &&
            problems+=("$name shifts non-local $tokens[i+1]") ;;
        (setopt|unsetopt)
          [[ $body == [[:space:]]#emulate\ -L* ]] ||
            problems+=("$name changes options without emulate -L") ;;
        (unset)
          while (( ++i <= ${#tokens} )) && [[ $tokens[i] != (\;|\&\&|\|\||\|) ]]; do
            if [[ $tokens[i] == -* ]]; then
              [[ $tokens[i] == -v ]] || problems+=("$name unsets with $tokens[i]")
            else
              var=${tokens[i]%%\[*}
              [[ -n ${locals[$var]-} ]] || problems+=("$name unsets non-local $var")
            fi
          done
          (( i-- )) ;;
        (printf)
          var=${(Q)tokens[i+2]} var=${var%%\[*}
          [[ $tokens[i+1] == -v && -n ${locals[$var]-} ]] ||
            problems+=("$name prints instead of assigning with printf -v to a local") ;;
        (*)
          # Only command words are calls: strings, argv data and locals named
          # like a public command (git, g, man) are not.
          if [[ ${functions_source[$token]-} == "$root"/* && -z ${pure[$token]-} ]]; then
            problems+=("$name calls $token from ${functions_source[$token]:t}")
          elif [[ -z ${allowed[$token]-} && -z ${pure[$token]-} ]]; then
            problems+=("$name runs $token, which is not an effect-free builtin or pure entry")
          fi ;;
      esac
    done
    for var in $pending; do
      [[ -n ${locals[$var]-} ]] || problems+=("$name assigns non-local $var")
    done
  done
  print -rl -- ${(u)problems} "scanned ${#pure} functions from ${#files} files"
}

_test_support_purity_report() {
  test_run_interactive "$1" "source \"\$1/.zshrc\" || exit 1
$(typeset -f _test_support_purity_scan)
_test_support_purity_scan \"\$1\"" "$2"
}

_test_support_pure_entries_stay_pure() {
  test_make_temp_dir || return
  local output=''
  local -a pure_files=("$TEST_REPO_ROOT"/.zsh.addons/support/functions/.zsh.pure.*(N.))
  (( ${#pure_files} )) || { test_fail 'pure support entries are absent'; return 1; }
  output=$(_test_support_purity_report "$TEST_TMP_DIR/home" "$TEST_REPO_ROOT") || return
  [[ $output == "scanned "<1->" functions from ${#pure_files} files" ]] || {
    test_fail "pure support entries must compute from explicit inputs only; move the read or effect to an impure entry or the caller (making a pure entry impure needs the user's agreement; engineering/architecture.md, \"Pure entries stay pure\"). If a flagged construct is genuinely pure, fix the scan's false positive and add the construct to its clean fixture; widening the builtin allowlist is the user's decision:"$'\n'"$output"
    return 1
  }
}
test_case 'support pure entries compute from explicit inputs without effects or escaping state' \
  _test_support_pure_entries_stay_pure

_test_support_purity_scan_reports_violations() {
  test_make_temp_dir || return
  local root="$TEST_TMP_DIR/root" output='' expected=''
  local functions_dir="$root/.zsh.addons/support/functions"
  command mkdir -p -- "$functions_dir" || return
  command cp -- "$TEST_REPO_ROOT/.zshrc" "$root/.zshrc" || return
  test_write_file "$functions_dir/.zsh.impure.fixture_effect" '# Entry point: _fixture_effect
_fixture_effect() { print -r -- effect; }' || return
  test_write_file "$root/.zsh.addons/.zsh.fixture" '_fixture_peer_helper() { :; }' || return
  test_write_file "$functions_dir/.zsh.pure.fixture_clean" '# Entry point: _fixture_clean
_fixture_clean() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local text=$1 name=$2 line="" item="" MATCH=""
  local -i MBEGIN=0 MEND=0 count=0
  local -a match=() mbegin=() mend=() parts=() named=()
  [[ $name == [A-Za-z_][A-Za-z0-9_]# ]] || return 2
  named=("${(@P)name}")
  [[ $text =~ "^a" && -n $text ]] && count=1
  [[ $text == (#b)(*) ]] && parts=(${(s: :)match[1]})
  for item in $parts; do count+=1; done
  for line in "${(@f)text}"; do count+=1; done
  printf -v text "%s" "$text"
  printf -v "parts[1]" "%s" "$text"
  unset item
  for item line in a b; do (( count += ${#item} )); done
  case $text in
    ((#i)_fixture_peer_helper*) count=2 ;;
    ((a|b)c) count=3 ;;
  esac
  [[ $text == -d ]] && parts=(_fixture_peer_helper "\$HOME" '"'"'$PATH'"'"')
  () { REPLY=$1; } "$text"
  { count=5; } always { count=6; }
  (( ${+functions[_fixture_clean_helper]} )) || return 1
  _fixture_clean_helper "$text"
  reply=("$REPLY" $count ${#named})
}
_fixture_clean_helper() { REPLY=${1:u}; }' || return
  test_write_file "$functions_dir/.zsh.pure.fixture_bad" '# Entry point: _fixture_bad
_fixture_bad() {
  emulate -L zsh
  local text=$1
  _fixture_effect
  _fixture_peer_helper
  text=$(date)
  git status
  print -u2 note
  typeset -g _FIXTURE_STATE=1
  _fixture_leak=1
  for leaked_item in a; do :; done
  read -r text <<< "$text"
  unset _FIXTURE_STATE
  [[ $text =~ x ]]
  [[ -e $text ]] && text=$COLUMNS
  (( _fixture_count++ ))
  text=${(D)text}
  text=${(e)text}
  print -r -- "$text" > out.txt
  zstyle -s :fixture key text
  printf "%s" "$text"
}
_fixture_bad_options() { setopt EXTENDED_GLOB; REPLY=1; }
_fixture_bad_emulate() { emulate sh; let n=1; REPLY=$n; }
_fixture_bad_more() {
  emulate -L zsh -c :
  local text=$1
  : &
  text=${(%%)text}
  [[ $text -nt $text ]] && unset -f _fixture_bad_more
  : <<EOF
body
EOF
}
_fixture_bad_shapes() {
  emulate -L zsh
  local text=$1 label=$text
  local -a parts=()
  typeset -p COLUMNS
  shift leaked_array
  ( : )
  : | :
  REPLY=$label
}' || return

  output=$(_test_support_purity_report "$TEST_TMP_DIR/home" "$root") || return
  for expected in \
    '_fixture_bad calls _fixture_effect from .zsh.impure.fixture_effect' \
    '_fixture_bad calls _fixture_peer_helper from .zsh.fixture' \
    '_fixture_bad runs a command or process substitution: text=$(date)' \
    '_fixture_bad runs git, which is not an effect-free builtin or pure entry' \
    '_fixture_bad runs print, which' \
    '_fixture_bad runs read, which' \
    '_fixture_bad runs zstyle, which' \
    '_fixture_bad declares a global: -g' \
    '_fixture_bad assigns non-local _fixture_leak' \
    '_fixture_bad loops with non-local leaked_item' \
    '_fixture_bad unsets non-local _FIXTURE_STATE' \
    '_fixture_bad uses a here-string or here-document' \
    '_fixture_bad sets match parameters without a local MATCH' \
    '_fixture_bad tests the filesystem or shell state: -e' \
    '_fixture_bad reads non-local COLUMNS' \
    '_fixture_bad evaluates text with the (e) flag' \
    '_fixture_bad uses non-local _fixture_count in arithmetic' \
    '_fixture_bad reads home or prompt state with a (D) or (%%) flag' \
    '_fixture_bad redirects to or from a file or descriptor: >' \
    '_fixture_bad prints instead of assigning with printf -v to a local' \
    '_fixture_bad_options changes options without emulate -L' \
    '_fixture_bad_emulate runs emulate without -L' \
    '_fixture_bad_emulate runs let, which' \
    '_fixture_bad_emulate reads non-local n' \
    '_fixture_bad_more evaluates code with emulate -c' \
    '_fixture_bad_more starts a background job: &' \
    '_fixture_bad_more reads home or prompt state with a (D) or (%%) flag' \
    '_fixture_bad_more tests the filesystem or shell state: -nt' \
    '_fixture_bad_more unsets with -f' \
    '_fixture_bad_more uses a here-string or here-document' \
    '_fixture_bad_shapes reads text in the declaration that binds it' \
    '_fixture_bad_shapes prints or matches parameters with -p' \
    '_fixture_bad_shapes shifts non-local leaked_array' \
    '_fixture_bad_shapes forks a subshell' \
    '_fixture_bad_shapes forks a pipeline: |' \
    'scanned 7 functions from 2 files'; do
    test_assert_contains "$output" "$expected" "purity scan missed: $expected" || return
  done
  [[ $output != *_fixture_clean* ]] ||
    test_fail "purity scan rejected a pure fixture:"$'\n'"$output"
}
test_case 'support pure entry scan reports outside calls, commands, files and escaping state' \
  _test_support_purity_scan_reports_violations
