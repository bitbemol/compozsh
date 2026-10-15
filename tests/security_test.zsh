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

# `emulate -L zsh` keeps the caller's IFS, so ${=text} and $=text split on
# whatever a line loop or `IFS= read` left. Each such split must follow a
# `local IFS=` declaration in the same function, which opens with `name() {`
# and closes with `}` at column 0; otherwise split on an explicit separator
# such as ${(s: :)text}. Comment lines are ignored.
_security_caller_ifs_splits() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local file='' line='' trimmed=''
  local -i number=0 in_function=0 local_ifs=0
  for file in "$@"; do
    number=0 in_function=0 local_ifs=0
    while IFS= read -r line || [[ -n $line ]]; do
      (( ++number ))
      trimmed=${line##[[:space:]]#}
      [[ $trimmed == \#* ]] && continue
      [[ $line == [A-Za-z_]*'() {'* ]] && in_function=1 local_ifs=0
      [[ $line == (|*[[:space:]\{\;])local[[:space:]]##([^\;]#[[:space:]])#IFS=* ]] &&
        local_ifs=1
      [[ $line == *('${='|'$='[A-Za-z_])* ]] && (( !in_function || !local_ifs )) &&
        print -r -- "${file#$TEST_REPO_ROOT/}:$number: $trimmed"
      [[ $line == \}* || ( $line == [A-Za-z_]*'() {'* && $line == *'}' ) ]] &&
        in_function=0 local_ifs=0
    done < "$file"
  done
}

_test_runtime_splits_without_caller_ifs() {
  emulate -L zsh
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/.zsh.fixture" found='' expected=''
  local -a zsh_files=()
  test_write_file "$fixture" 'words=(${=top})
# words=(${=commented})
unset_first() {
  words=(${=early})
  local IFS=$'"'"' \t\n'"'"'
}
declared() {
  local count=0 IFS=$'"'"' \t\n'"'"'
  words=(${=fine} $=also_fine ${(s: :)explicit})
}
reset_after() {
  words=($=bare)
}
not_a_declaration() {
  local x='"''"'; IFS= read -r x
  words=(${=read_only})
}
one_line() { local IFS=$'"'"'\n'"'"'; words=(${=one}); }
after_one_line() { words=(${=next}); }
explicit() { words=(${(s: :)separator}); }
redirected() {
  local IFS=$'"'"' \t\n'"'"'
} 2>/dev/null
words=(${=after_redirect})' || return
  found=$(_security_caller_ifs_splits "$fixture")
  found=${(F)${(f)found}#"${fixture#$TEST_REPO_ROOT/}:"}
  for expected in '1: words=(${=top})' '4: words=(${=early})' '12: words=($=bare)' \
      '16: words=(${=read_only})' '19: after_one_line() { words=(${=next}); }' \
      '24: words=(${=after_redirect})'; do
    [[ $'\n'$found$'\n' == *$'\n'"$expected"$'\n'* ]] ||
      { test_fail "caller IFS split scan missed: $expected"$'\n'"$found"; return 1; }
  done
  [[ $found != *(commented|fine|explicit|\{=one\}|separator)* ]] ||
    { test_fail "caller IFS split scan flagged a comment, a declared IFS or an explicit separator:"$'\n'"$found"; return 1; }
  _security_runtime_files
  zsh_files=(${(M)_SECURITY_RUNTIME_FILES:#*/(.zshrc|*.zsh|.zsh.*)})
  (( ${#zsh_files} > 20 )) || { test_fail 'runtime Zsh file inventory is unexpectedly small'; return 1; }
  found=$(_security_caller_ifs_splits "${zsh_files[@]}")
  [[ -z $found ]] || test_fail "shipped Zsh word-splits on the caller's IFS; declare local IFS first or use an explicit separator (engineering/zsh.md#idioms):"$'\n'"$found"
}
test_case 'security: shipped code word-splits only under a local IFS or an explicit separator' \
  _test_runtime_splits_without_caller_ifs

# SECURITY.md's completion-dump row assumes a bare compinit call: no -d path,
# -C/-i/-u audit bypass, fpath entry, compiled dump or completion cache.
_test_completion_dump_call_matches_disclosure() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local security="$(<"$TEST_REPO_ROOT/SECURITY.md")"
  local file='' line='' trimmed=''
  local fpath_entry='(^|[^[:alnum:]_])(fpath|FPATH)(\[[^]]*\])?\+?='
  local -a calls=()
  _security_runtime_files

  for file in "${_SECURITY_RUNTIME_FILES[@]}"; do
    while IFS= read -r line; do
      trimmed=${line##[[:space:]]#}
      [[ $trimmed == \#* ]] && continue
      if [[ $trimmed == *(compdump|use-cache|cache-path)* || $trimmed =~ $fpath_entry ]]; then
        test_fail "completion dump, cache or fpath entry entered ${file#$TEST_REPO_ROOT/}: $trimmed"
        return 1
      fi
      [[ $trimmed == *compinit* ]] && calls+=("${file#$TEST_REPO_ROOT/}:$trimmed")
    done < "$file"
  done
  test_assert_equal \
    '.zsh.addons/.zsh.editor:autoload -Uz compinit|.zsh.addons/.zsh.editor:compinit' \
    "${(j:|:)calls}" 'compinit invocation differs from the disclosed bare call' || return
  test_assert_contains "$security" '| Native completion dump | `${ZDOTDIR:-$HOME}/.zcompdump`' \
    'security inventory omits the native completion dump'
}
test_case 'security: native completion dump keeps the disclosed bare compinit call' \
  _test_completion_dump_call_matches_disclosure

_test_completion_dump_records_names_without_paths() {
  test_make_temp_dir || return
  local root=$TEST_TMP_DIR output=''
  test_write_file "$root/fixture-fpath/_fixture_tool" $'#compdef fixture-tool\n_arguments' || return
  test_write_file "$root/init.zsh" "umask 077; fpath=(${(q)root}/fixture-fpath \$fpath)" || return
  command mkdir -p "$root/zdotdir" || return
  # A group-writable runner umask would make compaudit prompt for this entry.
  command chmod 755 "$root/fixture-fpath" || return

  # ZDOTDIR differs from HOME, the initializer adds a private fpath entry and
  # tightens the umask; the dump must keep its names, not its directory path,
  # and take the umask-derived mode.
  output=$(test_run_interactive "$root/home" '
    ZDOTDIR=$2 ZSH_LOCAL_INIT=$3
    source "$1/.zshrc" || exit 1
    typeset dump=$ZDOTDIR/.zcompdump header="" contents=""
    typeset -a mode=() staging=() facts=()
    [[ $_comp_dumpfile == "$dump" && -f $dump && ! -e $HOME/.zcompdump ]] || exit 3
    IFS= read -r header < "$dump"
    contents=$(<"$dump")
    zmodload -F zsh/stat b:zstat || exit 4
    zstat -o -A mode +mode -- "$dump" || exit 5
    staging=( "$dump".*(N) )
    [[ $header == "#files: "<->[[:blank:]]"version: $ZSH_VERSION" ]] && facts+=(header)
    [[ $contents == *"$5"* ]] && facts+=(names)
    [[ $contents == *"$4"* ]] && facts+=(path-leak)
    facts+=("mode=${mode[1][-3,-1]}" "staging=${#staging}")
    zstyle -t ":completion:*" use-cache && facts+=(use-cache)
    command rm -f -- "$dump"
    source "$1/.zshrc" || exit 6
    [[ -e $dump ]] && facts+=(rewritten-on-resource)
    print -r -- "${(j:|:)facts}"' \
    "$TEST_REPO_ROOT" "$root/zdotdir" "$root/init.zsh" "$root" \
    "'fixture-tool' '_fixture_tool'") || return
  test_assert_equal 'header|names|mode=600|staging=0' "$output" \
    'native completion dump left its disclosed path, contents, mode or once-per-shell write'
}
test_case 'security: native completion dump records fpath names without paths at the configuration base' \
  _test_completion_dump_records_names_without_paths

# A relative initializer path would resolve against whichever directory a new
# shell or a re-source starts in, so project files there must never run. The
# absolute control proves the same loop still loads an explicit initializer.
_test_relative_local_initializer_is_refused() {
  test_make_temp_dir || return
  local root=$TEST_TMP_DIR output='' marker='typeset -g PROJECT_INIT_RAN=1'
  local notice='zsh: ignoring relative local initializer path (use an absolute ZSH_LOCAL_INIT): '
  test_write_file "$root/project/machine-init.zsh" "$marker" || return
  test_write_file "$root/project/.config/zsh/machine-init.zsh" "$marker" || return
  test_write_file "$root/project/~/machine-init.zsh" "$marker" || return

  # .zsh.shell sets NO_CLOBBER, so later loads replace stderr with 2>|.
  output=$(test_run_interactive "$root/home" '
    cd -- "$2" || exit 1
    typeset -a seen=()
    for ZSH_LOCAL_INIT in machine-init.zsh .config/zsh/machine-init.zsh "~/machine-init.zsh" "$2/machine-init.zsh"; do
      unset PROJECT_INIT_RAN
      source "$1/.zshrc" 2>|"$3" || exit 2
      seen+=("${PROJECT_INIT_RAN:-0}:$(<"$3")")
    done
    print -r -- "${(j:|:)seen}"' \
    "$TEST_REPO_ROOT" "$root/project" "$root/stderr") || return
  test_assert_equal \
    "0:${notice}machine-init.zsh|0:${notice}.config/zsh/machine-init.zsh|0:${notice}~/machine-init.zsh|1:" \
    "$output" 'a relative ZSH_LOCAL_INIT was resolved against the start directory'
}
test_case 'security: a relative ZSH_LOCAL_INIT never sources a file from the start directory' \
  _test_relative_local_initializer_is_refused

# Every external-media mktemp call must use a literal name that the public
# disclosure section lists, so a new temporary file cannot ship unlisted.
_test_external_media_temporary_names_are_disclosed() {
  emulate -L zsh
  local file='' line='' MATCH='' name='' section=''
  local -a match=() mbegin=() mend=() names=() files=(
    "$TEST_REPO_ROOT/.zsh.addons/.zsh.usb"
    "$TEST_REPO_ROOT"/.zsh.addons/support/functions/.zsh.*usb*(N.)
  )
  local -i calls=0 templates=0 in_section=0

  while IFS= read -r line; do
    if [[ $line == ('## '|'### ')* ]]; then
      (( in_section )) && break
      [[ $line == '### External media temporary files' ]] && in_section=1
      continue
    fi
    (( in_section )) && section+=$line$'\n'
  done < "$TEST_REPO_ROOT/SECURITY.md"
  [[ -n $section ]] ||
    { test_fail 'SECURITY.md has no External media temporary files section'; return 1; }
  for file in "${files[@]}"; do
    while IFS= read -r line; do
      [[ $line == *'command /usr/bin/mktemp'* ]] && (( ++calls ))
      [[ $line =~ '/(compozsh-[a-z-]+)\.XXXXXX' ]] || continue
      names+=("$match[1]")
      (( ++templates ))
    done < "$file"
  done
  (( calls >= 5 && calls == templates )) || {
    test_fail "external-media mktemp calls ($calls) and literal compozsh-* names ($templates) differ"
    return 1
  }
  for name in ${(ou)names}; do
    test_assert_contains "$section" "\`$name.*\`" \
      "SECURITY.md does not disclose the external-media temporary name $name" || return
  done
}
test_case 'security: every external-media temporary name is disclosed' \
  _test_external_media_temporary_names_are_disclosed

# Installer staging lives in the configuration base, so its residue must carry
# a compozsh name that the inventory and the residue section both disclose.
_test_installer_temporary_names_are_disclosed() {
  emulate -L zsh
  local line='' name='' current='' inventory='' residue=''
  local -a match=() mbegin=() mend=() names=()
  local -i calls=0 templates=0

  while IFS= read -r line; do
    if [[ $line == ('## '|'### ')* ]]; then
      current=$line
      continue
    fi
    case $current in
      ('## Complete local data inventory') [[ $line == '| '* ]] && inventory+=$line$'\n' ;;
      ('### Installer backups and temporary residue') residue+=$line$'\n' ;;
    esac
  done < "$TEST_REPO_ROOT/SECURITY.md"
  [[ -n $inventory && -n $residue ]] || {
    test_fail 'SECURITY.md lacks its inventory table or installer residue section'
    return 1
  }
  while IFS= read -r line; do
    [[ $line == *mktemp* ]] && (( ++calls ))
    [[ $line =~ '/(\.?compozsh-[a-z-]+)\.XXXXXX' ]] || continue
    names+=("$match[1]")
    (( ++templates ))
  done < "$TEST_REPO_ROOT/install.zsh"
  (( calls >= 1 && calls == templates )) || {
    test_fail "installer mktemp calls ($calls) and literal compozsh-* names ($templates) differ"
    return 1
  }
  for name in ${(ou)names}; do
    test_assert_contains "$inventory" "\`\${ZDOTDIR:-\$HOME}/$name.*\`" \
      "SECURITY.md inventory has no row for the installer name $name" || return
    test_assert_contains "$residue" "\`\${ZDOTDIR:-\$HOME}/$name.*\`" \
      "SECURITY.md residue section does not disclose the installer name $name" || return
  done
}
test_case 'security: installer temporary names are compozsh-named and disclosed' \
  _test_installer_temporary_names_are_disclosed
