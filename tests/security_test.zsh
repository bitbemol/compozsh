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
  local file='' line='' trimmed='' text=''
  local -a lines=()
  local pattern='(^|[;&|[:space:]])((builtin|command|exec|noglob|env)[[:space:]]+)*(/[^[:space:]]*/)?(curl|wget|ssh|scp|sftp|nc|netcat|socat|telnet|rsync)([[:space:]]|$)'
  _security_runtime_files

  for file in "${_SECURITY_RUNTIME_FILES[@]}"; do
    # One match over the file's uncommented lines finds every line the loop
    # below would (line breaks are [[:space:]]), so only a candidate file is
    # scanned line by line for the diagnostic. A NUL would end the regex
    # subject, so it becomes a line break; an invalid or incomplete character
    # (a regex error in a UTF-8 locale) sends the file to the line scan.
    lines=("${(@f)$(<"$file")}")
    text=${(F)lines:#[[:space:]]#\#*}
    text=${text//$'\0'/$'\n'}
    [[ $text == *[[:INVALID:][:INCOMPLETE:]]* || $text =~ $pattern ]] ||
      continue
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

# The scan itself: a commented client is ignored, and an uncommented one fails
# with the file and the offending line, wherever it sits in the file.
_test_network_client_scan_names_offending_line() {
  emulate -L zsh
  local output=''
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/fixture/.zsh.ok" $'# command curl ignored\nprint ok' || return
  test_write_file "$TEST_TMP_DIR/fixture/.zsh.bad" \
    $'# command curl ignored\nprint ok\n  command curl -s x' || return
  _security_runtime_files() {
    typeset -ga _SECURITY_RUNTIME_FILES=("$TEST_TMP_DIR/fixture/.zsh.ok")
  }
  output=$(_test_runtime_has_no_network_client_invocation 2>&1) ||
    test_fail "scan rejected a file with only a commented client: $output" || return
  _security_runtime_files() {
    typeset -ga _SECURITY_RUNTIME_FILES=(
      "$TEST_TMP_DIR/fixture/.zsh.ok" "$TEST_TMP_DIR/fixture/.zsh.bad"
    )
  }
  if output=$(_test_runtime_has_no_network_client_invocation 2>&1); then
    test_fail 'scan accepted an uncommented network client'
    return 1
  fi
  test_assert_contains "$output" '.zsh.bad: command curl -s x' \
    'scan diagnostic does not name the offending line' || return
  # A NUL or an invalid UTF-8 byte earlier in the file must not hide a later
  # line from the scan.
  test_write_file "$TEST_TMP_DIR/fixture/.zsh.bytes" \
    $'print \xff\0 ok\n  command curl -s y' || return
  _security_runtime_files() {
    typeset -ga _SECURITY_RUNTIME_FILES=("$TEST_TMP_DIR/fixture/.zsh.bytes")
  }
  if output=$(_test_runtime_has_no_network_client_invocation 2>&1); then
    test_fail 'scan accepted a network client after a NUL or invalid byte'
    return 1
  fi
  test_assert_contains "$output" '.zsh.bytes: command curl -s y' \
    'scan diagnostic does not name the line after a NUL or invalid byte'
}
test_case 'security: network-client scan names the offending line of a fixture file' \
  _test_network_client_scan_names_offending_line

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
      # Raw device I/O runs only inside the fixed raw-write routine; a direct
      # sudo dd wrapper would hand root dd whatever operands its caller chose.
      if [[ $invocation == *[[:space:]]/bin/dd([[:space:]]*|) ]]; then
        test_fail "sudo runs dd outside the fixed raw-write routine: $trimmed"
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

# Zsh ties `path` to PATH (and `fpath`, `cdpath`... to theirs), and a local of
# that name stays tied: `local path=$file` rebinds PATH for every callee and
# child and empties the command hash table on entry and exit. The lexer strips
# comments and keeps continued lines and array values whole, so only names that
# a declaration or `for` loop at command position binds are reported; `-h`
# hides the special and is allowed.
_security_tied_special_names() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local file='' token='' contents='' mode='' keyword='' options=''
  local tied='(path|cdpath|fpath|manpath|module_path|mailpath|fignore|psvar|watch|zsh_eval_context)'
  local -i command_position=0 names_started=0
  for file in "$@"; do
    contents=$(<"$file")
    command_position=1 mode=''
    for token in ${(Z+C+)contents}; do
      if [[ $token == (';'|';;'|';&'|';|'|'&'|'&!'|'&|'|'&&'|'||'|'|'|'|&'|'('|')'|'()'|'{'|'}') ]]; then
        command_position=1 mode=''
        continue
      fi
      if (( command_position )); then
        command_position=0
        case $token in
          (then|do|else|elif|if|while|until|time|'!'|builtin|noglob) command_position=1 ;;
          (local|typeset|declare|integer|float|readonly|export|private)
            mode=declare keyword=$token options='' names_started=0 ;;
          (for|foreach) mode=loop keyword=$token ;;
        esac
        continue
      fi
      case $mode in
        (declare)
          if (( !names_started )) && [[ $token == [-+]* ]]; then
            [[ $token == -- ]] && names_started=1
            [[ $token == -[^-]# ]] && options+=${token#-}
            continue
          fi
          names_started=1
          [[ ${token%%[=\[]*} == ${~tied} && $options != *h* ]] &&
            print -r -- "${file#$TEST_REPO_ROOT/}: $keyword $token"
          ;;
        (loop)
          [[ $token == (in|'(('*) ]] && { mode=''; continue; }
          [[ $token == ${~tied} ]] && print -r -- "${file#$TEST_REPO_ROOT/}: $keyword $token"
          ;;
      esac
    done
  done
}

_test_runtime_never_binds_tied_special_names() {
  emulate -L zsh
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/.zsh.fixture" found=''
  local -a zsh_files=()
  test_write_file "$fixture" 'local path=$1 display=$2
f() {
  local context="" path=""
  integer count=1; local -a cdpath=(a b)
  local first=1 \
    manpath=2
  if true; then builtin typeset -g fpath; fi
  for path in a b; do :; done
  for (( i = 0; i < 2; ++i )); do declare module_path; done
  { readonly mailpath=x }
}
# local path=commented
hidden() { local -h path=1; typeset -ah fpath=(x) }
named() { local file_path=1 path_text=2 my_path= PATH=/usr/bin:/bin; }
arguments() { print -r -- local path; _append $limit path "$pattern" }
values() { local -a modes=(basename path) words=("for path in") }
case $x in (path) print path ;; esac
for name in path fpath; do :; done' || return
  found=$(_security_tied_special_names "$fixture")
  found=${(F)${(f)found}#"${fixture#$TEST_REPO_ROOT/}: "}
  test_assert_equal 'local path=$1
local path=""
local cdpath=(a b)
local manpath=2
typeset fpath
for path
declare module_path
readonly mailpath=x' "$found" 'tied special name scan reported the wrong bindings' || return
  _security_runtime_files
  zsh_files=(${(M)_SECURITY_RUNTIME_FILES:#*/(.zshrc|*.zsh|.zsh.*)})
  (( ${#zsh_files} > 20 )) || { test_fail 'runtime Zsh file inventory is unexpectedly small'; return 1; }
  found=$(_security_tied_special_names "${zsh_files[@]}")
  [[ -z $found ]] || test_fail "shipped Zsh binds a name Zsh ties to PATH or another colon-separated special; rename it (engineering/zsh.md#idioms):"$'\n'"$found"
}
test_case 'security: shipped code never declares locals tied to PATH-like specials' \
  _test_runtime_never_binds_tied_special_names

# The helpers that once declared `local path` must leave callees a resolvable
# PATH and the interactive shell's `hash name=/path` entries in place.
_test_view_helpers_keep_path_and_command_hash() {
  test_make_temp_dir || return
  local tree="$TEST_TMP_DIR/tree" output=''
  command mkdir -p "$tree/sub" || return
  test_write_file "$tree/file" x || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find" || exit
    source "$1/.zsh.addons/.zsh.navigation" || exit
    source "$1/.zsh.addons/.zsh.git-review" || exit
    probe() {
      hash compozsh-probe=/bin/echo
      "$@" >/dev/null 2>&1
      print -r -- "hash:$1:${commands[compozsh-probe]-gone}"
    }
    _file_search_match_rank() { callee_ls=${commands[ls]:-unresolved}; REPLY=1; }
    probe _file_search_consider "$2/file" file file
    print -r -- "callee-ls:$callee_ls values:${(j:,:)_FILE_SEARCH_VALUES}"
    builtin cd "$2/sub" || exit
    dirstack=("$2")
    probe _directory_stack_capture
    print -r -- "stack:${(j:,:)_ZLE_UI_CHOICE_VALUES}"
    typeset -a _GIT_REVIEW_LABELS=(file item) _GIT_REVIEW_CONTEXTS=("Unstaged M" Untracked)
    typeset -a _GIT_REVIEW_KINDS=(unstaged untracked) _GIT_REVIEW_PATHS=(dir/file new/item)
    typeset -a _GIT_REVIEW_DETAILS=(changed new)
    typeset -a _ZLE_UI_CHOICE_VALUES=() _ZLE_UI_CHOICE_LABELS=()
    typeset -a _ZLE_UI_CHOICE_SEARCH_LABELS=()
    typeset -A _ZLE_PICKER_CONTEXTS=() _ZLE_PICKER_INSPECT_TEXTS=()
    _ZLE_PICKER_DOCUMENT=1
    probe _git_review_rows
    print -r -- "rows:${(j:,:)_ZLE_UI_CHOICE_LABELS}"
  ' "$TEST_REPO_ROOT" "$tree") || return
  test_assert_contains "$output" "values:$tree/file" 'Search did not record the candidate' || return
  test_assert_contains "$output" "stack:$tree/sub,$tree" 'Recents did not capture the directory stack' || return
  test_assert_contains "$output" 'rows:file,new/item' 'Git review did not project the file rows' || return
  test_assert_contains "$output" 'callee-ls:/' \
    'a Search callee saw PATH rebound to the candidate path' || return
  local helper=''
  for helper in _file_search_consider _directory_stack_capture _git_review_rows; do
    test_assert_contains "$output" "hash:$helper:/bin/echo" \
      "$helper cleared the caller's command hash table" || return
  done
}
test_case 'security: Search, Recents and Git review rows keep PATH and the command hash (no locals tied to PATH-like specials)' \
  _test_view_helpers_keep_path_and_command_hash

# SECURITY.md's completion-dump row assumes compinit's stock audit and dump
# path: no -C/-i/-u audit bypass, no fpath entry, no completion cache, no
# compdump call, and -d only for the checked compiled mirror entry.
_test_completion_dump_call_matches_disclosure() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local security="$(<"$TEST_REPO_ROOT/SECURITY.md")"
  local file='' line='' trimmed=''
  local fpath_entry='(^|[^[:alnum:]_])(fpath|FPATH)(\[[^]]*\])?\+?='
  local compdump_call='(^|[^[:alnum:]_.])compdump([^[:alnum:]_.]|$)'
  local -a calls=()
  _security_runtime_files

  for file in "${_SECURITY_RUNTIME_FILES[@]}"; do
    while IFS= read -r line; do
      trimmed=${line##[[:space:]]#}
      [[ $trimmed == \#* ]] && continue
      if [[ $trimmed == *(use-cache|cache-path)* || $trimmed =~ $compdump_call ||
            $trimmed =~ $fpath_entry ]]; then
        test_fail "completion dump writer, cache or fpath entry entered ${file#$TEST_REPO_ROOT/}: $trimmed"
        return 1
      fi
      [[ $trimmed == *compinit* ]] && calls+=("${file#$TEST_REPO_ROOT/}:$trimmed")
    done < "$file"
  done
  test_assert_equal \
    '.zsh.addons/.zsh.editor:autoload -Uz compinit|.zsh.addons/.zsh.editor:compinit -d "$_zle_dump_mirror/zcompdump"|.zsh.addons/.zsh.editor:compinit' \
    "${(j:|:)calls}" 'compinit invocation differs from the disclosed calls' || return
  test_assert_contains "$security" '| Native completion dump | `${ZDOTDIR:-$HOME}/.zcompdump`' \
    'security inventory omits the native completion dump'
}
test_case 'security: native completion dump keeps the disclosed compinit calls' \
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
  (( calls >= 4 && calls == templates )) || {
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

# Every Git call Compozsh makes on its own (prompt, Search, branch, review,
# worktree and discard) keeps one local-only read baseline, so a wrapper copied
# into a new peer cannot silently drop a control. A `command git`,
# `command "$git_binary"`, `exec git` or `exec "$git_binary"` call needs the
# four variables inline or as `local -x` earlier in its function (opened by
# `name() {` and closed by `}` at column 0), and the pager, replace-object,
# fsmonitor and hooks controls in the call itself. Backslash-continued lines
# form one statement; comment lines are ignored. Only the transparent `git` and
# `g` arguments, which keep the user's own Git semantics, and explicit
# switches after cleanup, which keep repository hooks by design, are exempt.
# The runtime check also requires the shared `_compozsh_git_local` entry to be
# the only direct call it checks, so every passive site reaches Git through it.
_security_git_read_baseline() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local file='' line='' trimmed='' statement='' function_name='' environment=''
  local rest='' setting='' missing='' MATCH='' MBEGIN='' MEND=''
  local pattern='(^|[^[:alnum:]_-])(command|exec)[[:space:]]+(git|"\$git_binary")([[:space:]]|\)|$)'
  local -a match=() mbegin=() mend=()
  local -a variables=(GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 "GIT_ALLOW_PROTOCOL=''")
  local -a flags=(--no-pager --no-replace-objects '-c core.fsmonitor=false' '-c core.hooksPath=/dev/null')
  local -i number=0 start=0 calls=0 count=0
  for file in "$@"; do
    number=0 statement='' function_name='' environment=''
    while IFS= read -r line || [[ -n $line ]]; do
      (( ++number ))
      [[ -z $statement ]] && start=$number
      trimmed=${line##[[:space:]]#}
      [[ -z $statement && $trimmed == \#* ]] && continue
      [[ -z $statement && $line == [A-Za-z_]*'() {'* ]] &&
        function_name=${line%%'() {'*} environment=''
      if [[ $line == *\\ ]]; then
        statement+="${trimmed%\\} "
        continue
      fi
      statement+=$trimmed
      [[ $statement == local[[:space:]]##-x[[:space:]]* ]] && environment+=" $statement"
      calls=0 rest=$statement
      while [[ $rest =~ $pattern ]]; do
        (( ++calls ))
        rest=${rest[MEND+1,-1]}
      done
      if (( calls )); then
        case $function_name:$statement in
          ('git:command git "$@"'|'git:command git "${git_color_arguments[@]}" "$@"'|\
           'g:command git "$@"'|'g:command git'|\
           'g:command git -C "$root" switch --no-guess -- "$branch"'|\
           '_git_branch_remote_switch:command git -C "$root" -c submodule.recurse=false switch --no-guess --track=direct --create "$name" -- "$ref"')
            print -r -- "allow ${file#$TEST_REPO_ROOT/} $function_name: $statement"
            ;;
          (*)
            missing=''
            for setting in "${variables[@]}"; do
              [[ " $environment $statement " == *[[:space:]\(]"$setting"[[:space:]]* ]] ||
                missing+=" ${setting%%=*}"
            done
            for setting in "${flags[@]}"; do
              count=0 rest=$statement
              while [[ $rest == *"$setting"* ]]; do
                rest=${rest#*"$setting"}
                (( ++count ))
              done
              (( count >= calls )) || missing+=" ${setting#-c }"
            done
            if [[ -n $missing ]]; then
              print -r -- "gap ${file#$TEST_REPO_ROOT/}:$start ${function_name:-<top level>}: missing${missing}"
            else
              print -r -- "ok ${file#$TEST_REPO_ROOT/} $function_name"
            fi
            ;;
        esac
      fi
      [[ $line == \}* || ( $line == [A-Za-z_]*'() {'* && $line == *'}' ) ]] &&
        function_name='' environment=''
      statement=''
    done < "$file"
  done
}

_test_passive_git_calls_keep_the_read_baseline() {
  emulate -L zsh
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/.zsh.fixture" shown='' found='' expected='' entry=''
  local -a zsh_files=() lines=()
  test_write_file "$fixture" 'read_inline() {
  out=$(GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 \
    GIT_ALLOW_PROTOCOL='"''"' command git --no-pager --no-replace-objects \
    -c core.fsmonitor=false -c core.hooksPath=/dev/null status)
}
read_scoped() {
  local -x GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0
  local -x GIT_ALLOW_PROTOCOL='"''"'
  # command git log
  exec "$git_binary" --no-pager --no-replace-objects -c core.fsmonitor=false -c core.hooksPath=/dev/null "$@"
}
no_hooks() {
  local -x GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL='"''"'
  command "$git_binary" -C "$root" -c core.fsmonitor=false "$@"
}
late_environment() {
  dir=$(command git --no-pager --no-replace-objects -c core.fsmonitor=false -c core.hooksPath=/dev/null rev-parse)
  local -x GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL='"''"'
}
other_function() {
  command git --no-pager --no-replace-objects -c core.fsmonitor=false -c core.hooksPath=/dev/null status
}
two_calls() {
  local -x GIT_OPTIONAL_LOCKS=0 GIT_NO_LAZY_FETCH=1 GIT_TERMINAL_PROMPT=0 GIT_ALLOW_PROTOCOL='"''"'
  a=$(command git --no-pager --no-replace-objects -c core.fsmonitor=false -c core.hooksPath=/dev/null status) && b=$(exec git rev-parse)
}
g() {
  command git "$@"
  command git status
}' || return
  found=$(_security_git_read_baseline "$fixture")
  shown=${fixture#$TEST_REPO_ROOT/}
  found=${found//"$shown"/fixture}
  expected='ok fixture read_inline
ok fixture read_scoped
gap fixture:14 no_hooks: missing --no-pager --no-replace-objects core.hooksPath=/dev/null
gap fixture:17 late_environment: missing GIT_OPTIONAL_LOCKS GIT_NO_LAZY_FETCH GIT_TERMINAL_PROMPT GIT_ALLOW_PROTOCOL
gap fixture:21 other_function: missing GIT_OPTIONAL_LOCKS GIT_NO_LAZY_FETCH GIT_TERMINAL_PROMPT GIT_ALLOW_PROTOCOL
gap fixture:25 two_calls: missing --no-pager --no-replace-objects core.fsmonitor=false core.hooksPath=/dev/null
allow fixture g: command git "$@"
gap fixture:29 g: missing GIT_OPTIONAL_LOCKS GIT_NO_LAZY_FETCH GIT_TERMINAL_PROMPT GIT_ALLOW_PROTOCOL --no-pager --no-replace-objects core.fsmonitor=false core.hooksPath=/dev/null'
  test_assert_equal "$expected" "$found" 'Git read baseline scan reported the wrong sites' || return

  _security_runtime_files
  zsh_files=(${(M)_SECURITY_RUNTIME_FILES:#*/(.zshrc|*.zsh|.zsh.*)})
  (( ${#zsh_files} > 20 )) || { test_fail 'runtime Zsh file inventory is unexpectedly small'; return 1; }
  found=$(_security_git_read_baseline "${zsh_files[@]}")
  lines=(${(M)${(f)found}:#gap *})
  (( ${#lines} == 0 )) || {
    test_fail "a passive Git call lacks the local-only read baseline (engineering/workspaces/git.md):"$'\n'"${(F)lines}"
    return 1
  }
  # The exemptions stay exactly these transparent calls and explicit switches.
  lines=(${(u)${(M)${(f)found}:#allow *}})
  expected='allow .zsh.addons/.zsh.navigation _git_branch_remote_switch: command git -C "$root" -c submodule.recurse=false switch --no-guess --track=direct --create "$name" -- "$ref"
allow .zsh.addons/.zsh.navigation g: command git
allow .zsh.addons/.zsh.navigation g: command git "$@"
allow .zsh.addons/.zsh.navigation g: command git -C "$root" switch --no-guess -- "$branch"
allow .zsh.addons/.zsh.output git: command git "$@"
allow .zsh.addons/.zsh.output git: command git "${git_color_arguments[@]}" "$@"'
  for entry in "${(@f)expected}"; do
    (( ${lines[(Ie)$entry]} )) || { test_fail "Git read baseline exemption is missing: $entry"; return 1; }
  done
  (( ${#lines} == ${#${(@f)expected}} )) ||
    { test_fail "Git read baseline exemptions changed:"$'\n'"${(F)lines}"; return 1; }
  # The shared entry is the only checked direct Git call: every passive site,
  # prompt and discard included, reaches Git through it. This also guards
  # against a vacuous scan.
  lines=(${(u)${(M)${(f)found}:#ok *}})
  [[ ${(F)lines} == 'ok .zsh.addons/support/functions/.zsh.impure.compozsh_git_local _compozsh_git_local' ]] ||
    { test_fail "a Git call bypasses the shared local-only entry:"$'\n'"${(F)lines}"; return 1; }
  # Every caller reaches Git only through the shared local-only entry, with its
  # selector policy and folder, and makes no Git call or flag copy of its own.
  local wrapper='' file='' policy='' folder='' body='' line='' MATCH='' MBEGIN='' MEND=''
  local -a match=() mbegin=() mend=()
  local call='(command|exec)[[:space:]]+(git|"\$git_binary")'
  local controls='GIT_OPTIONAL_LOCKS|GIT_ALLOW_PROTOCOL|core\.fsmonitor|core\.hooksPath|--no-pager'
  local -i inside=0
  for entry in .zsh.git-review:_git_review_git:root:root .zsh.git-worktree:_git_worktree_git:root:root \
      .zsh.navigation:_git_branch_read:inherit:root .zsh.find:_file_search_git:root:root \
      .zsh.prompt:_prompt_git:inherit:PWD .zsh.tools:_tools_git_discard_all:inherit:root \
      support/functions/.zsh.impure.compozsh_git_filter_config:_compozsh_git_filter_config:inherit:root; do
    file=${entry%%:*} wrapper=${${entry#*:}%%:*} policy=${${entry%:*}##*:} folder=${entry##*:}
    body='' inside=0
    while IFS= read -r line || [[ -n $line ]]; do
      [[ $line == "$wrapper() {"* ]] && inside=1
      (( inside )) || continue
      body+=$line$'\n'
      [[ $line == \}* ]] && break
    done < "$TEST_REPO_ROOT/.zsh.addons/$file"
    [[ -n $body ]] || { test_fail "$wrapper is missing from $file"; return 1; }
    [[ $body == *"_compozsh_git_local $policy \"\$$folder\" "* ]] ||
      { test_fail "$wrapper does not call _compozsh_git_local with the $policy policy"; return 1; }
    [[ ! $body =~ $call && ! $body =~ $controls ]] ||
      { test_fail "$wrapper keeps its own Git call or local-only controls"; return 1; }
  done
}
test_case 'security: every passive Git call carries the local-only read baseline' \
  _test_passive_git_calls_keep_the_read_baseline
