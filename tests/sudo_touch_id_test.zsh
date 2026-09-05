# Focused regressions for the opt-in macOS sudo Touch ID configuration.

_test_sudo_touch_id_grouped_entry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    local guide=$(compozsh --sudo-touch-id --help)
    [[ $guide == "usage: compozsh --sudo-touch-id [status|enable|disable]"$'\''\n'\''* ]] || exit 1
    [[ $guide == $(_compozsh_help_compozsh sudo-touch-id) ]] || exit 2
    compozsh --sudo-touch-id > "$HOME/out" 2> "$HOME/err"
    [[ $? == 1 && ! -s "$HOME/out" && $(<"$HOME/err") == *"enable .zsh.sudo-touch-id"* ]] || exit 3
    functions[compozsh-sudo-touch-id]="return 99"
    functions[_compozsh_help_compozsh-sudo-touch-id]="return 99"
    aliases[compozsh-sudo-touch-id]=obsolete
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    (( !${+functions[compozsh-sudo-touch-id]} && !${+functions[_compozsh_help_compozsh-sudo-touch-id]} &&
       !${+aliases[compozsh-sudo-touch-id]} )) || exit 4
    local calls=0
    _sudo_touch_id_run() { (( ++calls )); print -r -- "$1|$2"; return 23; }
    local action="" actual=""
    for action in status enable disable; do
      compozsh --sudo-touch-id "$action" > "$HOME/out"
      [[ $? == 23 && $(<"$HOME/out") == "$action|/etc/pam.d" ]] || exit 5
    done
    compozsh --sudo-touch-id > "$HOME/out"
    [[ $? == 23 && $(<"$HOME/out") == "status|/etc/pam.d" && $calls == 4 ]] || exit 6
    compozsh --sudo-touch-id --help > "$HOME/out" 2> "$HOME/err"
    [[ $? == 0 && $calls == 4 && ! -s "$HOME/err" && $(<"$HOME/out") == "$guide" ]] || exit 7
    local args=""
    for args in "--sudo-touch-id invalid" "--sudo-touch-id enable disable" "--sudo-touch-id --help extra" "--sudo-touch-id enable --help"; do
      compozsh ${=args} > "$HOME/out" 2> "$HOME/err"
      [[ $? == 2 && $calls == 4 && ! -s "$HOME/out" && $(<"$HOME/err") == "${guide[(f)1]}" ]] || exit 8
    done
    _compozsh_tool_capture
    (( !${_COMPOZSH_TOOL_NAMES[(Ie)compozsh-sudo-touch-id]} )) || exit 9
    print grouped
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal grouped "$output"
}
test_case 'sudo Touch ID grouped entry owns help validation optional peer and exact dispatch without a retired command' _test_sudo_touch_id_grouped_entry

_test_sudo_touch_id_classifies_only_its_exact_managed_file() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" managed='' output=''
  command mkdir -p -- "$pam_dir" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    pam_dir=$2

    _sudo_touch_id_state "$pam_dir"
    print -r -- "absent:$REPLY"

    _sudo_touch_id_managed_text
    managed=$REPLY
    [[ $managed == *"use compozsh --sudo-touch-id disable"* ]] || exit 11
    print -r -- "$REPLY" >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    print -r -- "managed:$REPLY"

    { print -r -- "$managed"; print; } >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    print -r -- "changed-managed:$REPLY"

    local previous=${managed//compozsh --sudo-touch-id/compozsh-sudo-touch-id}
    print -r -- "$previous" >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    [[ $REPLY == managed ]] || exit 12
    { print -r -- "$previous"; print; } >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    [[ $REPLY == enabled-external ]] || exit 13

    print -r -- "auth sufficient pam_tid.so" >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    print -r -- "external:$REPLY"

    print -r -- "auth sufficient pam_tid.so debug # local note" >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    print -r -- "external-options:$REPLY"

    print -r -- "auth sufficient pam_tid.so unmatched=\"" >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    print -r -- "external-untrusted:$REPLY"

    print -r -- "auth required pam_opendirectory.so" >| "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    print -r -- "conflict:$REPLY"

    command rm -f -- "$pam_dir/sudo_local"
    command ln -s -- "$pam_dir/missing" "$pam_dir/sudo_local"
    _sudo_touch_id_state "$pam_dir"
    print -r -- "symlink:$REPLY"
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_equal $'absent:absent\nmanaged:managed\nchanged-managed:enabled-external\nexternal:enabled-external\nexternal-options:enabled-external\nexternal-untrusted:enabled-external\nconflict:conflicting\nsymlink:unsafe' \
    "$output" 'sudo Touch ID ownership states are not fail-closed'
}
test_case 'sudo Touch ID recognizes only its exact managed policy' \
  _test_sudo_touch_id_classifies_only_its_exact_managed_file

_test_sudo_touch_id_enable_disable_flow_is_bounded_and_reversible() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output=''
  command mkdir -p -- "$pam_dir" || return
  test_write_file "$pam_dir/sudo" \
    $'# sudo\nauth       include        sudo_local\nauth       required       pam_opendirectory.so' || return
  test_write_file "$pam_dir/sudo_local.template" \
    $'# sudo_local\n#auth       sufficient     pam_tid.so' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    typeset -g TEST_PAM_DIR=$2
    typeset -gi TEST_AUTHORIZE_CALLS=0 TEST_INSTALL_CALLS=0 TEST_REMOVE_CALLS=0
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }
    _sudo_touch_id_authorize() { (( ++TEST_AUTHORIZE_CALLS )); }
    _sudo_touch_id_install() {
      (( ++TEST_INSTALL_CALLS ))
      _sudo_touch_id_managed_text
      print -r -- "$REPLY" >| "$TEST_PAM_DIR/sudo_local"
    }
    _sudo_touch_id_remove() {
      (( ++TEST_REMOVE_CALLS ))
      command rm -f -- "$TEST_PAM_DIR/sudo_local"
    }

    _sudo_touch_id_run status "$TEST_PAM_DIR" >| "$HOME/status-before" || exit 10
    _sudo_touch_id_run enable "$TEST_PAM_DIR" >| "$HOME/enable" || exit 11
    _sudo_touch_id_state "$TEST_PAM_DIR"
    [[ $REPLY == managed ]] || exit 12
    _sudo_touch_id_run enable "$TEST_PAM_DIR" >| "$HOME/enable-again" || exit 13
    _sudo_touch_id_run disable "$TEST_PAM_DIR" >| "$HOME/disable" || exit 14
    [[ ! -e "$TEST_PAM_DIR/sudo_local" ]] || exit 15
    _sudo_touch_id_run disable "$TEST_PAM_DIR" >| "$HOME/disable-again" || exit 16

    print -r -- "$TEST_AUTHORIZE_CALLS|$TEST_INSTALL_CALLS|$TEST_REMOVE_CALLS"
    print -r -- "before:$(<"$HOME/status-before")"
    print -r -- "enable:$(<"$HOME/enable")"
    print -r -- "again:$(<"$HOME/enable-again")"
    print -r -- "disable:$(<"$HOME/disable")"
    print -r -- "disabled:$(<"$HOME/disable-again")"
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_contains "$output" '2|1|1' \
    'idempotent enable/disable requested unnecessary administrator access' || return
  test_assert_contains "$output" 'before:No sudo_local policy is installed.' \
    'status did not report the absent policy' || return
  test_assert_contains "$output" 'Enabled Touch ID for sudo; password authentication remains available.' \
    'enable did not report its authentication boundary' || return
  test_assert_contains "$output" 'again:The Compozsh-managed sudo_local policy is already installed.' \
    'repeat enable was not idempotent' || return
  test_assert_contains "$output" 'disable:Disabled the Compozsh-managed Touch ID policy for sudo.' \
    'disable did not report the exact removed policy' || return
  test_assert_contains "$output" 'disabled:No Compozsh-managed sudo_local policy is installed.' \
    'repeat disable was not idempotent'
}
test_case 'sudo Touch ID enable and disable are bounded, idempotent, and reversible' \
  _test_sudo_touch_id_enable_disable_flow_is_bounded_and_reversible

_test_sudo_touch_id_preserves_custom_and_unsafe_policy() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output=''
  command mkdir -p -- "$pam_dir" || return
  test_write_file "$pam_dir/sudo" \
    $'# sudo\nauth       include        sudo_local\nauth       required       pam_opendirectory.so' || return
  test_write_file "$pam_dir/sudo_local.template" \
    $'# sudo_local\n#auth       sufficient     pam_tid.so' || return
  test_write_file "$pam_dir/sudo_local" \
    $'# private policy\nauth sufficient pam_tid.so\nauth optional pam_krb5.so' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    typeset -g TEST_PAM_DIR=$2
    typeset -gi TEST_PRIVILEGED_CALLS=0
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }
    _sudo_touch_id_authorize() { (( ++TEST_PRIVILEGED_CALLS )); }
    _sudo_touch_id_install() { (( ++TEST_PRIVILEGED_CALLS )); return 99; }
    _sudo_touch_id_remove() { (( ++TEST_PRIVILEGED_CALLS )); return 99; }

    _sudo_touch_id_run status "$TEST_PAM_DIR" >| "$HOME/status" || exit 10
    _sudo_touch_id_run enable "$TEST_PAM_DIR" >| "$HOME/enable" || exit 11
    _sudo_touch_id_run disable "$TEST_PAM_DIR" >| "$HOME/disable.out" 2>| "$HOME/disable.err"
    disable_status=$?
    print -r -- "$TEST_PRIVILEGED_CALLS|$disable_status|$(<"$HOME/status")|$(<"$HOME/enable")|$(<"$HOME/disable.err")"
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_contains "$output" \
    '0|1|A custom sudo_local policy contains a sufficient pam_tid rule.|An existing custom policy already contains a sufficient pam_tid rule; nothing was changed.' \
    'custom Touch ID policy was not preserved without administrator access' || return
  test_assert_contains "$output" \
    'Refusing to remove /etc/pam.d/sudo_local because Compozsh does not own its exact contents.' \
    'disable did not fail closed around a custom policy'
}
test_case 'sudo Touch ID leaves custom PAM policy untouched' \
  _test_sudo_touch_id_preserves_custom_and_unsafe_policy

_test_sudo_touch_id_revalidates_after_authorization() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output=''
  command mkdir -p -- "$pam_dir" || return
  test_write_file "$pam_dir/sudo" \
    $'# sudo\nauth       include        sudo_local\nauth       required       pam_opendirectory.so' || return
  test_write_file "$pam_dir/sudo_local.template" \
    $'# sudo_local\n#auth       sufficient     pam_tid.so' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    typeset -g TEST_PAM_DIR=$2
    typeset -gi TEST_INSTALL_CALLS=0
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }
    _sudo_touch_id_authorize() {
      print -r -- "auth optional pam_krb5.so" >| "$TEST_PAM_DIR/sudo_local"
    }
    _sudo_touch_id_install() { (( ++TEST_INSTALL_CALLS )); return 99; }

    _sudo_touch_id_run enable "$TEST_PAM_DIR" >| "$HOME/enable.out" 2>| "$HOME/enable.err"
    command_status=$?
    print -r -- "$command_status|$TEST_INSTALL_CALLS|$(<"$TEST_PAM_DIR/sudo_local")|$(<"$HOME/enable.err")"
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_equal \
    '1|0|auth optional pam_krb5.so|compozsh --sudo-touch-id: sudo_local changed during authorization; nothing was installed' \
    "$output" 'enable overwrote policy created while authorization was visible'
}
test_case 'sudo Touch ID revalidates policy after visible authorization' \
  _test_sudo_touch_id_revalidates_after_authorization

_test_sudo_touch_id_privileged_routine_is_static_and_parseable() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    _sudo_touch_id_privileged_install_script
    print -rn -- "$REPLY" >| "$HOME/install-routine.zsh"
    command /bin/zsh -n "$HOME/install-routine.zsh" || exit 10
    [[ $REPLY == *"/usr/bin/mktemp /etc/pam.d/.compozsh-sudo-touch-id.XXXXXX"* &&
       $REPLY == *"/bin/chmod -N \"\$temp_file\""* &&
       $REPLY == *"/bin/link \"\$temp_file\" /etc/pam.d/sudo_local"* &&
       $REPLY != *"eval"* ]] || exit 11
    _sudo_touch_id_privileged_remove_script
    print -rn -- "$REPLY" >| "$HOME/remove-routine.zsh"
    command /bin/zsh -n "$HOME/remove-routine.zsh" || exit 12
    [[ $REPLY == *"/usr/bin/stat -f \"%u:%g:%Lp:%z:%l\" /etc/pam.d/sudo_local"* &&
       $REPLY == *"/bin/ls -lde /etc/pam.d/sudo_local"* &&
       $REPLY == *"/bin/unlink /etc/pam.d/sudo_local"* &&
       $REPLY != *"eval"* ]] || exit 13
    print -r -- static-parseable-install-and-remove
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal static-parseable-install-and-remove "$output"
}
test_case 'sudo Touch ID privileged routine is static, fixed-target, and parseable' \
  _test_sudo_touch_id_privileged_routine_is_static_and_parseable

_test_sudo_touch_id_privileged_routines_execute_in_isolated_fixture() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output=''
  command mkdir -m 0700 -- "$pam_dir" || return
  test_write_file "$pam_dir/sudo" \
    $'auth include sudo_local\nauth required pam_opendirectory.so' || return
  test_write_file "$pam_dir/sudo_local.template" \
    $'#auth sufficient pam_tid.so' || return
  command chmod 0444 "$pam_dir/sudo" "$pam_dir/sudo_local.template" || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    typeset -g TEST_PAM_DIR=$2
    local user=$(command /usr/bin/id -un) group=$(command /usr/bin/id -gn)
    local uid=$(command /usr/bin/id -u) gid=$(command /usr/bin/id -g)
    local script="" install_script="" remove_script="" managed="" metadata=""
    local original_metadata="" original_contents=""
    local -i expected_size=0
    local -a lines=() artifacts=()
    _rewrite_privileged_fixture() {
      [[ ${TEST_PAM_DIR//[A-Za-z0-9_\/.-]/} == "" ]] || return 1
      [[ $1 == *"/etc/pam.d"* && $1 == *"expected_uid=0"* &&
         $1 == *"expected_gid=0"* ]] || return 1
      REPLY=${1//\/etc\/pam.d/$TEST_PAM_DIR}
      REPLY=${REPLY//root:wheel/${user}:${group}}
      REPLY=${REPLY//expected_uid=0/expected_uid=$uid}
      REPLY=${REPLY//expected_gid=0/expected_gid=$gid}
      [[ $REPLY != *"/etc/pam.d"* && $REPLY != *"root:wheel"* &&
         $REPLY != *"expected_uid=0"* && $REPLY != *"expected_gid=0"* &&
         $REPLY != *"/usr/bin/sudo"* ]] || return 1
      command /bin/zsh -n -c "$REPLY" || return 1
    }
    _sudo_touch_id_managed_text
    managed=$REPLY
    lines=("${(f)managed}")
    _sudo_touch_id_privileged_install_script
    _rewrite_privileged_fixture "$REPLY"
    script=$REPLY
    install_script=$script

    command mkdir -- "$TEST_PAM_DIR/collision" || exit 10
    command ln -s -- "$TEST_PAM_DIR/collision" "$TEST_PAM_DIR/sudo_local" || exit 11
    command /bin/zsh -dfc "$script" fixture "${lines[@]}" 2>/dev/null
    print -r -- "symlink:$?"
    artifacts=("$TEST_PAM_DIR/collision"/.compozsh-sudo-touch-id.*(N))
    (( ${#artifacts} == 0 )) || exit 12
    command rm -- "$TEST_PAM_DIR/sudo_local" || exit 13

    command chmod +a "everyone allow write" "$TEST_PAM_DIR" || exit 14
    command /bin/zsh -dfc "$script" fixture "${lines[@]}" 2>/dev/null
    print -r -- "acl:$?"
    [[ ! -e "$TEST_PAM_DIR/sudo_local" ]] || exit 15
    command chmod -N "$TEST_PAM_DIR" || exit 16

    print -r -- "auth optional pam_krb5.so" >| "$TEST_PAM_DIR/sudo_local" || exit 17
    original_contents=$(<"$TEST_PAM_DIR/sudo_local") || exit 18
    original_metadata=$(command /usr/bin/stat -f "%i:%u:%g:%Lp:%z:%l" \
      "$TEST_PAM_DIR/sudo_local") || exit 19
    command /bin/zsh -dfc "$install_script" fixture "${lines[@]}" 2>/dev/null
    print -r -- "custom:$?"
    [[ $(<"$TEST_PAM_DIR/sudo_local") == "$original_contents" ]] || exit 20
    [[ $(command /usr/bin/stat -f "%i:%u:%g:%Lp:%z:%l" \
      "$TEST_PAM_DIR/sudo_local") == "$original_metadata" ]] || exit 21
    artifacts=("$TEST_PAM_DIR"/.compozsh-sudo-touch-id.*(N))
    (( ${#artifacts} == 0 )) || exit 22
    command rm -- "$TEST_PAM_DIR/sudo_local" || exit 23

    command /bin/zsh -dfc "$install_script" fixture "${lines[@]}" || exit 24
    expected_size=$(( ${#managed} + 1 ))
    [[ -f "$TEST_PAM_DIR/sudo_local" && ! -L "$TEST_PAM_DIR/sudo_local" ]] || exit 25
    metadata=$(command /usr/bin/stat -f "%u:%g:%Lp:%z:%l" "$TEST_PAM_DIR/sudo_local") || exit 26
    [[ $(<"$TEST_PAM_DIR/sudo_local") == "$managed" ]] || exit 27
    _sudo_touch_id_acl_free "$TEST_PAM_DIR/sudo_local" || exit 28
    print -r -- "installed:$metadata"
    artifacts=("$TEST_PAM_DIR"/.compozsh-sudo-touch-id.*(N))
    (( ${#artifacts} == 0 )) || exit 29

    _sudo_touch_id_privileged_remove_script
    _rewrite_privileged_fixture "$REPLY" || exit 30
    remove_script=$REPLY

    command /bin/zsh -dfc "$remove_script" fixture wrong arguments 2>/dev/null
    print -r -- "remove-arguments:$?"
    [[ -f "$TEST_PAM_DIR/sudo_local" ]] || exit 31

    command chmod 0644 "$TEST_PAM_DIR/sudo_local" || exit 32
    command /bin/zsh -dfc "$remove_script" fixture "${lines[@]}" 2>/dev/null
    print -r -- "remove-mode:$?"
    [[ -f "$TEST_PAM_DIR/sudo_local" ]] || exit 33
    command chmod 0444 "$TEST_PAM_DIR/sudo_local" || exit 34

    command chmod 0644 "$TEST_PAM_DIR/sudo_local" || exit 35
    print -r -- "auth optional pam_krb5.so" >| "$TEST_PAM_DIR/sudo_local" || exit 36
    command chmod 0444 "$TEST_PAM_DIR/sudo_local" || exit 37
    command /bin/zsh -dfc "$remove_script" fixture "${lines[@]}" 2>/dev/null
    print -r -- "remove-bytes:$?"
    [[ -f "$TEST_PAM_DIR/sudo_local" ]] || exit 38
    command chmod 0644 "$TEST_PAM_DIR/sudo_local" || exit 39
    print -r -- "$managed" >| "$TEST_PAM_DIR/sudo_local" || exit 40
    command chmod 0444 "$TEST_PAM_DIR/sudo_local" || exit 41

    command chmod +a "everyone allow write" "$TEST_PAM_DIR/sudo_local" || exit 42
    command /bin/zsh -dfc "$remove_script" fixture "${lines[@]}" 2>/dev/null
    print -r -- "remove-acl:$?"
    [[ -f "$TEST_PAM_DIR/sudo_local" ]] || exit 43
    command chmod -N "$TEST_PAM_DIR/sudo_local" || exit 44

    command /bin/link "$TEST_PAM_DIR/sudo_local" \
      "$TEST_PAM_DIR/.compozsh-sudo-touch-id.residue" || exit 45
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }
    _sudo_touch_id_run status "$TEST_PAM_DIR" || exit 46
    command /bin/zsh -dfc "$remove_script" fixture "${lines[@]}" || exit 47
    [[ ! -e "$TEST_PAM_DIR/sudo_local" &&
       -f "$TEST_PAM_DIR/.compozsh-sudo-touch-id.residue" ]] || exit 48
    [[ $(<"$TEST_PAM_DIR/.compozsh-sudo-touch-id.residue") == "$managed" ]] || exit 49
    [[ $(command /usr/bin/stat -f "%u:%g:%Lp:%z:%l" \
      "$TEST_PAM_DIR/.compozsh-sudo-touch-id.residue") == \
      "$uid:$gid:444:$expected_size:1" ]] || exit 50
    print -r -- multi-link-recovered
    local previous=${managed/compozsh --sudo-touch-id/compozsh-sudo-touch-id}
    print -r -- "$previous" > "$TEST_PAM_DIR/sudo_local"
    command chmod 0444 "$TEST_PAM_DIR/sudo_local"
    command /bin/zsh -dfc "$remove_script" fixture "${lines[@]}" || exit 51
    [[ ! -e "$TEST_PAM_DIR/sudo_local" ]] || exit 52
    { print -r -- "$previous"; print; } > "$TEST_PAM_DIR/sudo_local"
    command chmod 0444 "$TEST_PAM_DIR/sudo_local"
    command /bin/zsh -dfc "$remove_script" fixture "${lines[@]}"
    [[ $? == 1 && -f "$TEST_PAM_DIR/sudo_local" ]] || exit 53
    print -r -- previous-policy-verified
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_contains "$output" 'symlink:1' \
    'privileged install followed or broadened a destination symlink' || return
  test_assert_contains "$output" 'acl:1' \
    'privileged install accepted an ACL-bearing PAM directory' || return
  test_assert_contains "$output" 'custom:1' \
    'privileged install replaced a preexisting regular policy' || return
  test_assert_contains "$output" \
    "installed:$(command /usr/bin/id -u):$(command /usr/bin/id -g):444:" \
    'privileged install did not publish exact owner, mode, bytes, ACL, and link state' || return
  for refusal in remove-arguments remove-mode remove-bytes remove-acl; do
    test_assert_contains "$output" "$refusal:1" \
      "privileged removal accepted unsafe $refusal state" || return
  done
  test_assert_contains "$output" 'has additional hard links; disable removes only sudo_local, then inspect remaining links.' \
    'status did not expose interrupted hard-link cleanup recovery' || return
  test_assert_contains "$output" 'multi-link-recovered' \
    'privileged removal could not recover an interrupted hard-link cleanup' || return
  test_assert_contains "$output" previous-policy-verified \
    'previous policy must remain removable only with exact bytes and metadata'
}
test_case 'sudo Touch ID privileged routines execute safely in an isolated fixture' \
  _test_sudo_touch_id_privileged_routines_execute_in_isolated_fixture

_test_sudo_touch_id_enable_requires_later_password_fallback() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output=''
  command mkdir -p -- "$pam_dir" || return
  test_write_file "$pam_dir/sudo_local.template" \
    $'# sudo_local\n#auth       sufficient     pam_tid.so' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    pam_dir=$2
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }

    print -r -- "auth include sudo_local" >| "$pam_dir/sudo"
    _sudo_touch_id_enable_preflight "$pam_dir" >/dev/null 2>&1
    print -r -- "missing:$?"

    print -rl -- \
      "auth required pam_opendirectory.so" \
      "auth include sudo_local" >| "$pam_dir/sudo"
    _sudo_touch_id_enable_preflight "$pam_dir" >/dev/null 2>&1
    print -r -- "before:$?"

    print -rl -- \
      "auth include sudo_local;other" \
      "auth required pam_opendirectory.so" >| "$pam_dir/sudo"
    _sudo_touch_id_enable_preflight "$pam_dir" >/dev/null 2>&1
    print -r -- "punctuated-include:$?"

    print -rl -- \
      "auth include sudo_local" \
      "auth required pam_opendirectory.so&&other" >| "$pam_dir/sudo"
    _sudo_touch_id_enable_preflight "$pam_dir" >/dev/null 2>&1
    print -r -- "punctuated-fallback:$?"

    print -rl -- \
      "auth include \"sudo_local\"" \
      "auth required pam_opendirectory.so" >| "$pam_dir/sudo"
    _sudo_touch_id_enable_preflight "$pam_dir" >/dev/null 2>&1
    print -r -- "quoted-include:$?"

    print -rl -- \
      "auth include sudo_local # Apple local policy" \
      "auth sufficient pam_smartcard.so" \
      "auth required pam_opendirectory.so # password fallback" >| "$pam_dir/sudo"
    _sudo_touch_id_enable_preflight "$pam_dir" >/dev/null 2>&1
    print -r -- "after:$?"
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_equal $'missing:1\nbefore:1\npunctuated-include:1\npunctuated-fallback:1\nquoted-include:1\nafter:0' "$output" \
    'enable accepted a sudo policy without a later required password fallback'
}
test_case 'sudo Touch ID enable requires a later password authenticator' \
  _test_sudo_touch_id_enable_requires_later_password_fallback

_test_sudo_touch_id_disable_survives_platform_policy_drift() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output=''
  command mkdir -p -- "$pam_dir" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    typeset -g TEST_PAM_DIR=$2
    typeset -gi TEST_AUTHORIZE_CALLS=0 TEST_REMOVE_CALLS=0
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }
    _sudo_touch_id_authorize() { (( ++TEST_AUTHORIZE_CALLS )); }
    _sudo_touch_id_remove() {
      (( ++TEST_REMOVE_CALLS ))
      command rm -f -- "$TEST_PAM_DIR/sudo_local"
    }
    _sudo_touch_id_managed_text
    print -r -- "$REPLY" >| "$TEST_PAM_DIR/sudo_local"
    # Deliberately omit sudo and sudo_local.template: disable must remain
    # available after an operating-system policy change.
    _sudo_touch_id_run disable "$TEST_PAM_DIR" || exit 10
    print -r -- "$TEST_AUTHORIZE_CALLS|$TEST_REMOVE_CALLS|${+commands[unexpected]}"
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_contains "$output" 'Disabled the Compozsh-managed Touch ID policy for sudo.' \
    'disable was stranded by unrelated Apple policy drift' || return
  test_assert_contains "$output" '1|1|0' \
    'disable did not retain its bounded authorization and removal flow'
}
test_case 'sudo Touch ID disable remains available after platform policy drift' \
  _test_sudo_touch_id_disable_survives_platform_policy_drift

_test_sudo_touch_id_rejects_acl_bearing_policy_paths() {
  test_make_temp_dir || return
  local policy="$TEST_TMP_DIR/policy" output=''
  test_write_file "$policy" 'auth required pam_opendirectory.so' || return
  command chmod +a 'everyone allow write' "$policy" || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    _sudo_touch_id_acl_free "$2"; print -r -- "with:$?"
    command chmod -N "$2" || exit 10
    _sudo_touch_id_acl_free "$2"; print -r -- "without:$?"
  ' "$TEST_REPO_ROOT" "$policy") || return

  test_assert_equal $'with:1\nwithout:0' "$output" \
    'macOS ACL mutation rights escaped trusted-path validation'
}
test_case 'sudo Touch ID rejects ACL-bearing policy paths' \
  _test_sudo_touch_id_rejects_acl_bearing_policy_paths

_test_sudo_touch_id_metadata_contract_is_exact() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    for metadata in 0:0:444:1 501:0:444:1 0:20:444:1 0:0:464:1; do
      _sudo_touch_id_metadata_safe "$metadata" 444
      print -r -- "$metadata:$?"
    done
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal $'0:0:444:1:0\n501:0:444:1:1\n0:20:444:1:1\n0:0:464:1:1' \
    "$output" 'managed policy metadata accepted unsafe ownership or mode'
}
test_case 'sudo Touch ID managed metadata contract is exact' \
  _test_sudo_touch_id_metadata_contract_is_exact

_test_sudo_touch_id_rechecks_platform_policy_after_authorization() {
  test_make_temp_dir || return
  local pam_dir="$TEST_TMP_DIR/pam.d" output=''
  command mkdir -p -- "$pam_dir" || return
  test_write_file "$pam_dir/sudo" \
    $'auth include sudo_local\nauth required pam_opendirectory.so' || return
  test_write_file "$pam_dir/sudo_local.template" \
    $'#auth sufficient pam_tid.so' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    typeset -g TEST_PAM_DIR=$2
    typeset -gi TEST_INSTALL_CALLS=0
    _sudo_touch_id_is_macos() { return 0; }
    _sudo_touch_id_root_owned() { return 0; }
    _sudo_touch_id_authorize() {
      print -r -- "auth include sudo_local" >| "$TEST_PAM_DIR/sudo"
    }
    _sudo_touch_id_install() { (( ++TEST_INSTALL_CALLS )); }
    _sudo_touch_id_run enable "$TEST_PAM_DIR" >| "$HOME/out" 2>| "$HOME/err"
    print -r -- "$?|$TEST_INSTALL_CALLS|$(<"$HOME/err")"
  ' "$TEST_REPO_ROOT" "$pam_dir") || return

  test_assert_contains "$output" '1|0|' \
    'enable mutated after Apple policy changed during authorization' || return
  test_assert_contains "$output" 'system sudo policy changed during authorization; nothing was installed' \
    'enable did not explain its post-authorization platform recheck'
}
test_case 'sudo Touch ID repeats platform validation after authorization' \
  _test_sudo_touch_id_rechecks_platform_policy_after_authorization
