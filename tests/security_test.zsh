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
test_case 'runtime source contains no direct network-client invocation' \
  _test_runtime_has_no_network_client_invocation

_test_privilege_and_credential_surface_stays_bounded() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local usb="$TEST_REPO_ROOT/.zsh.addons/.zsh.usb"
  local file='' line='' trimmed='' invocation='' contents=''
  _security_runtime_files

  for file in "${_SECURITY_RUNTIME_FILES[@]}"; do
    contents=$(<"$file")
    if [[ $file != "$usb" && $contents == *sudo* ]]; then
      test_fail "sudo reference escaped the external-media peer: ${file#$TEST_REPO_ROOT/}"
      return 1
    fi
    if [[ $contents == *'sudo -S'* || $contents == *'sudo --stdin'* ||
          $contents == *SUDO_ASKPASS* || $contents == *pbpaste* ||
          $contents == *'/usr/bin/security'* ]]; then
      test_fail "credential or clipboard-read capability entered ${file#$TEST_REPO_ROOT/}"
      return 1
    fi
  done

  while IFS= read -r line; do
    [[ $line == *'command /usr/bin/sudo'* ]] || continue
    trimmed=${line##[[:space:]]#}
    invocation=${trimmed#*command /usr/bin/sudo}
    if [[ $invocation != ' -v' && $invocation != ' -n '* ]]; then
      test_fail "sudo can prompt outside the single validation call: $trimmed"
      return 1
    fi
  done < "$usb"
}
test_case 'privilege and credential surface stays inside the documented USB boundary' \
  _test_privilege_and_credential_surface_stays_bounded
