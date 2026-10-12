# Focused regressions for the public SECURITY.md trust boundaries. These tests
# catch common capability additions; the documented human review remains the
# authority because keyword absence alone cannot prove behavior.

_security_runtime_files() {
  typeset -ga _SECURITY_RUNTIME_FILES=(
    "$TEST_REPO_ROOT/.zshrc"
    "$TEST_REPO_ROOT/install.zsh"
    "$TEST_REPO_ROOT/templates/init.zsh"
    "$TEST_REPO_ROOT"/.zsh.addons/**/*(ND.)
  )
}

_test_runtime_has_no_network_client_invocation() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local file='' line='' trimmed=''
  local pattern='(^|[;&|[:space:]])((builtin|command|exec|noglob|env)[[:space:]]+)*(/[^[:space:]]*/)?(curl|wget|ssh|scp|sftp|nc|netcat|socat|telnet|rsync)([[:space:]]|$)'
  _security_runtime_files

  for file in "${_SECURITY_RUNTIME_FILES[@]}"; do
    while IFS= read -r line; do
      trimmed=${line##[[:space:]]#}
      [[ $trimmed == \#* ]] && continue
      if [[ $line =~ $pattern ]]; then
        test_fail "network-capable client invocation entered ${file#$TEST_REPO_ROOT/}: $trimmed"
        return 1
      fi
    done < "$file"
  done
}
test_case 'security: runtime source contains no direct network-client invocation' \
  _test_runtime_has_no_network_client_invocation

_test_privilege_and_credential_surface_stays_bounded() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local usb="$TEST_REPO_ROOT/.zsh.addons/.zsh.usb"
  local touch_id="$TEST_REPO_ROOT/.zsh.addons/.zsh.sudo-touch-id"
  local help="$TEST_REPO_ROOT/.zsh.addons/.zsh.help" prompt="$TEST_REPO_ROOT/.zsh.addons/.zsh.prompt"
  local file='' line='' trimmed='' invocation='' contents=''
  _security_runtime_files

  for file in "${_SECURITY_RUNTIME_FILES[@]}"; do
    contents=$(<"$file")
    if [[ $file != "$usb" && $file != "$touch_id" && $file != "$help" && $file != "$prompt" && $contents == *sudo* ]]; then
      test_fail "sudo reference escaped the documented privilege peers: ${file#$TEST_REPO_ROOT/}"
      return 1
    fi
    # Help owns grouped dispatch/documentation and prompt owns literal hints;
    # neither is allowed to acquire the actual sudo invocation boundary.
    if [[ $file != "$usb" && $file != "$touch_id" && $contents == *'command /usr/bin/sudo'* ]]; then
      test_fail "sudo invocation escaped the privilege peers: ${file#$TEST_REPO_ROOT/}"
      return 1
    fi
    if [[ $contents == *'sudo -S'* || $contents == *'sudo --stdin'* ||
          $contents == *SUDO_ASKPASS* || $contents == *pbpaste* ||
          $contents == *'/usr/bin/security'* ]]; then
      test_fail "credential or clipboard-read capability entered ${file#$TEST_REPO_ROOT/}"
      return 1
    fi
  done

  for file in "$usb" "$touch_id"; do
    while IFS= read -r line; do
      [[ $line == *'command /usr/bin/sudo'* ]] || continue
      trimmed=${line##[[:space:]]#}
      invocation=${trimmed#*command /usr/bin/sudo}
      if [[ $invocation != ' -v' && $invocation != ' -n '* ]]; then
        test_fail "sudo can prompt outside an explicit validation call: $trimmed"
        return 1
      fi
    done < "$file"
  done

  contents=$(<"$touch_id")
  [[ $contents == *"command /usr/bin/sudo -n /bin/zsh -dfc"* &&
     $contents == *"command /bin/link \"\$temp_file\" /etc/pam.d/sudo_local"* &&
     $contents == *"command /bin/unlink /etc/pam.d/sudo_local"* &&
     $contents != *"sudo -n /bin/rm -f -- \"\$"* ]] || {
    test_fail 'sudo Touch ID privilege targets are not fixed and auditable'
    return 1
  }
}
test_case 'security: privilege and credential surface stays inside documented fixed boundaries' \
  _test_privilege_and_credential_surface_stays_bounded

# Zsh 5.9 writes here-string and here-document bodies, and =(...) output, to
# temporary files under ${TMPPREFIX:-/tmp/zsh}. Shipped code parses captured
# data in memory instead. The lexer strips comments but keeps $(...), <(...)
# and quoted words as single tokens, so match inside each token after removing
# single-quoted literals (the classifier's '<<<' labels) and the %<< prompt
# truncation escape. Code inside a single-quoted string (zsh -c '...') is
# invisible here; SECURITY.md's textual `<<` audit covers it.
_security_temporary_file_transports() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local file='' token='' contents=''
  for file in "$@"; do
    contents=$(<"$file")
    for token in ${(Z+C+)contents}; do
      token=${${token//\'[^\']#\'/}//\%\<\</}
      [[ $token == *\<\<* || $token == (|*[[:space:]\(\`\<\>\|\;\&])\=\(* ]] &&
        print -r -- "${file#$TEST_REPO_ROOT/}: $token"
    done
  done
}

_test_runtime_parses_captures_without_temporary_files() {
  emulate -L zsh
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/.zsh.fixture" found='' expected=''
  local -a zsh_files=()
  test_write_file "$fixture" 'case $op in ('"'"'<<<'"'"'|'"'"'<<'"'"') ;; esac # <<< note
read -r a <<< "$b"
cat <<EOF
body
EOF
read -r c 0<<- "$d"
diff =(print a) =(print b)
x=$(tr a b <<< "$y")
y="$(cat <<< "$d")"
while read -r e; do :; done < <(cat <<< "$d")
lines=(${(f)"$(sort <<< "$d")"})
v=$(diff =(print a) -)
print -r -- "%<<" '"'"'<<'"'"'
list=(one two)' || return
  found=$(_security_temporary_file_transports "$fixture")
  found=${(F)${(f)found}#"$fixture: "}
  for expected in '<<<' '<<' '0<<-' '=(print a)' '=(print b)' 'x=$(tr a b <<< "$y")' \
      'y="$(cat <<< "$d")"' '<(cat <<< "$d")' '${(f)"$(sort <<< "$d")"}' 'v=$(diff =(print a) -)'; do
    [[ $'\n'$found$'\n' == *$'\n'"$expected"$'\n'* ]] ||
      { test_fail "temporary-file transport scan missed: $expected"$'\n'"$found"; return 1; }
  done
  [[ $found != *(note|one|%|\"\"|\'\'|EOF|body)* ]] ||
    { test_fail "temporary-file transport scan flagged text, a comment or a quoted pattern:"$'\n'"$found"; return 1; }
  _security_runtime_files
  zsh_files=(${(M)_SECURITY_RUNTIME_FILES:#*/(.zshrc|*.zsh|.zsh.*)})
  (( ${#zsh_files} > 20 )) || { test_fail 'runtime Zsh file inventory is unexpectedly small'; return 1; }
  found=$(_security_temporary_file_transports "${zsh_files[@]}")
  [[ -z $found ]] || test_fail "shipped Zsh passes data through a here-string, here-document or =(...) temporary file; split it in memory (engineering/security.md#handling-sensitive-data):"$'\n'"$found"
}
test_case 'security: shipped Zsh parses captured data without here-string or here-document temporary files' \
  _test_runtime_parses_captures_without_temporary_files

# Arithmetic text reparses its subscripts: (( h[$key] )) or
# (( a[(Ie)$text] )) turns `]` or $(...) in the key into expression or
# command. Expansions such as ${h[$key]}, ${a[(Ie)$text]} and $+h[$key] are
# resolved before parsing, so they are removed before matching. The lexer
# strips comments and keeps each (( ... )) command, including multi-line ones,
# as one token; $(( ... )) bodies are found inside any token after removing
# single-quoted literals.
_security_spliced_arithmetic_subscripts() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local file='' token='' contents='' rest='' body='' char=''
  local -i depth=0 index=0
  local -a bodies=()
  for file in "$@"; do
    contents=$(<"$file")
    for token in ${(Z+C+)contents}; do
      token=${token//\'[^\']#\'/}
      bodies=()
      [[ $token == '(('* ]] && bodies+=("${token[3,-3]}")
      rest=$token
      while [[ $rest == *'$(('* ]]; do
        rest=${rest#*'$(('}
        depth=2 body=''
        for (( index = 1; index <= ${#rest} && depth > 0; ++index )); do
          char=$rest[index]
          [[ $char == '(' ]] && (( ++depth ))
          [[ $char == ')' ]] && (( --depth ))
          (( depth > 0 )) && body+=$char
        done
        bodies+=("$body")
      done
      for body in "${bodies[@]}"; do
        while [[ $body == *'${'*'}'* ]]; do
          body=${body//\$\{[^\{\}]#\}/0}
        done
        body=${body//\$(\+|\#|)[A-Za-z_][A-Za-z0-9_]#\[[^\]]#\]/0}
        [[ $body == *[A-Za-z_][A-Za-z0-9_]#\[[^\]]#[\$\`]* ]] &&
          print -r -- "${file#$TEST_REPO_ROOT/}: $token"
      done
    done
  done
}

_test_runtime_never_splices_text_into_arithmetic_subscripts() {
  emulate -L zsh
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/.zsh.fixture" found='' expected=''
  local -a zsh_files=()
  test_write_file "$fixture" '(( ++areas[d:$area] )) # (( note[$x] ))
filled=$(( (16 * areas[$area] + count - 1) / count ))
(( !paths[(Ie)$REPLY] )) && print "$(( totals[`id`] ))"
if (( verify &&
      seen[$key] )); then :; fi
(( ${+h[$k]} && $+commands[$x] && ${a[(Ie)$text]} && ranks[index] == rank ))
h[$k]=$(( ${h[$k]:-0} + 1 ))
print '"'"'$(( quoted[$x] ))'"'"'' || return
  found=$(_security_spliced_arithmetic_subscripts "$fixture")
  found=${(F)${(f)found}#"${fixture#$TEST_REPO_ROOT/}: "}
  for expected in '(( ++areas[d:$area] ))' 'filled=$(( (16 * areas[$area] + count - 1) / count ))' \
      '(( !paths[(Ie)$REPLY] ))' '"$(( totals[`id`] ))"' $'(( verify &&\n      seen[$key] ))'; do
    [[ $'\n'$found$'\n' == *$'\n'"$expected"$'\n'* ]] ||
      { test_fail "arithmetic subscript scan missed: $expected"$'\n'"$found"; return 1; }
  done
  [[ $found != *(note|'${+h'|h\[\$k\]=|quoted)* ]] ||
    { test_fail "arithmetic subscript scan flagged an expansion, comment or quoted text:"$'\n'"$found"; return 1; }
  _security_runtime_files
  zsh_files=(${(M)_SECURITY_RUNTIME_FILES:#*/(.zshrc|*.zsh|.zsh.*)})
  (( ${#zsh_files} > 20 )) || { test_fail 'runtime Zsh file inventory is unexpectedly small'; return 1; }
  found=$(_security_spliced_arithmetic_subscripts "${zsh_files[@]}")
  [[ -z $found ]] || test_fail "shipped Zsh splices an expansion into an arithmetic subscript; expand it first (engineering/zsh.md#idioms):"$'\n'"$found"
}
test_case 'security: shipped Zsh never splices text into arithmetic subscripts' \
  _test_runtime_never_splices_text_into_arithmetic_subscripts
