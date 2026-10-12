_test_run_installer_at() {
  local installer=$1 home=$2 zdotdir=$3
  shift 3

  command mkdir -p -- "$home" "$zdotdir" || return 1
  command env -i \
    PATH="$PATH" \
    HOME="$home" \
    ZDOTDIR="$zdotdir" \
    TERM=xterm-256color \
    TMPDIR="${TMPDIR:-/tmp}" \
    LC_ALL=C \
    "$TEST_ZSH_BIN" "$installer" "$@"
}

_test_run_installer() {
  local home=$1 zdotdir=$2
  shift 2
  _test_run_installer_at "$TEST_REPO_ROOT/install.zsh" \
    "$home" "$zdotdir" "$@"
}

_test_installer_help_explains_lifecycle_without_installing() {
  test_make_temp_dir || return
  local output='' fact=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=()
    source "$1/install.zsh" --help
  ' "$TEST_REPO_ROOT" 2> "$TEST_TMP_DIR/help.err") || return
  [[ ! -s "$TEST_TMP_DIR/help.err" ]] || test_fail 'installer help wrote stderr' || return
  for fact in 'Install Compozsh' 'ZDOTDIR' '--symlink' '--copy' '--clean' \
      '--dry-run' '--yes' '--help' 'local/init.zsh' '.zsh-backups' 'repository' \
      'exec zsh' 'Examples:' 'tools'; do
    test_assert_contains "$output" "$fact" "installer help omits guidance: $fact" || return
  done
  [[ $output != *' -h '* ]] || test_fail 'installer help advertises a short alias' || return
  local -a installed=("$TEST_TMP_DIR/home"/*(ND))
  test_assert_equal 0 "${#installed}" 'installer help wrote configuration files'
}
test_case 'installer help explains installation, updates, and recovery without writes' \
  _test_installer_help_explains_lifecycle_without_installing

_test_installer_rejects_short_help() {
  test_make_temp_dir || return
  local output='' result=0
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=()
    source "$1/install.zsh" --symlink --yes -h
  ' "$TEST_REPO_ROOT" 2> "$TEST_TMP_DIR/short-help.err") || result=$?
  test_assert_equal 2 "$result" 'installer accepted the removed short option' || return
  test_assert_equal '' "$output" 'invalid installer option printed an installation plan' || return
  test_assert_contains "$(<"$TEST_TMP_DIR/short-help.err")" 'installer: unknown option: -h' || return
  test_assert_contains "$(<"$TEST_TMP_DIR/short-help.err")" 'usage: zsh install.zsh' || return
  local -a installed=("$TEST_TMP_DIR/home"/*(ND))
  test_assert_equal 0 "${#installed}" 'invalid installer option wrote configuration files'
}
test_case 'installer rejects short help before inspecting or installing files' \
  _test_installer_rejects_short_help

_test_installer_fresh_symlink() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" active='' initializer='' output=''

  output=$(_test_run_installer "$home" "$home" --symlink --yes) || return
  active="$home/.zshrc"
  initializer="$home/.zsh.addons/local/init.zsh"

  [[ -L $active ]] || test_fail 'fresh symlink install did not create a link' || return
  test_assert_equal "${TEST_REPO_ROOT:A}/.zshrc" "${active:A}" \
    'active symlink does not resolve to the repository bootstrap' || return
  [[ -f $initializer ]] || test_fail 'initializer starter was not installed' || return
  test_assert_equal "$(<"$TEST_REPO_ROOT/templates/init.zsh")" \
    "$(<"$initializer")" 'installed initializer differs from its starter' || return
  test_assert_contains "$output" 'Installation complete' \
    'successful install omitted its completion message' || return

  output=$(test_run_interactive "$home" '
    ZSH_COLOR_SCHEME=light
    source "$HOME/.zshrc" || exit 1
    source "$HOME/.zshrc" || exit 2
    (( ${+functions[_zle_ui_view]} && ${+functions[_zle_picker_screen_session]} )) || exit 3
    _compozsh_palette_color prompt path || exit 4
    [[ $REPLY == 25 ]] || exit 5
    compozsh --list
  ' 2> "$TEST_TMP_DIR/load.err") || return
  [[ ! -s "$TEST_TMP_DIR/load.err" ]] || test_fail 'symlink bootstrap emitted diagnostics' || return
  test_assert_contains "$output" 'mkcd · ✓ help · .zsh.tools' \
    'symlink installation did not discover its public tools'
}
test_case 'installer creates a fresh recommended symlink installation' \
  _test_installer_fresh_symlink

_test_installer_excludes_generated_caches() {
  test_make_temp_dir || return
  local repository="$TEST_TMP_DIR/repository" home="$TEST_TMP_DIR/home" output=''
  command mkdir -p "$repository" || return
  command cp "$TEST_REPO_ROOT/.zshrc" "$TEST_REPO_ROOT/install.zsh" "$repository" || return
  command cp -R "$TEST_REPO_ROOT/templates" "$TEST_REPO_ROOT/.zsh.addons" "$repository" || return
  test_write_file "$repository/.zsh.addons/support/cache/.zsh.manual.cache" $'COMPOZSH\n)' || return
  test_write_file "$home/.zsh.addons/support/cache/.zsh.manual.cache" 'LOCAL-CACHE-PRESERVED' || return
  _test_run_installer_at "$repository/install.zsh" "$home" "$home" --copy --yes > "$TEST_TMP_DIR/install.out" 2> "$TEST_TMP_DIR/install.err" || {
    print -u2 -r -- "$(<"$TEST_TMP_DIR/install.err")"; return 1
  }
  [[ ! -e "$home/.zsh.addons/compozsh/support/cache" ]] || test_fail 'copy install distributed generated cache data' || return
  test_assert_equal LOCAL-CACHE-PRESERVED "$(<"$home/.zsh.addons/support/cache/.zsh.manual.cache")" || return
  output=$(test_run_interactive "$home" 'source "$HOME/.zshrc"; print -r -- ${+functions[mkcd]}') || return
  test_assert_equal 1 "$output" 'cache exclusion lost shipped peers'
}
test_case 'installer excludes generated module caches from syntax validation and copied distribution' \
  _test_installer_excludes_generated_caches

_test_installer_resolves_repository_independent_of_pwd() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" elsewhere="$TEST_TMP_DIR/elsewhere"
  local active="$home/.zshrc"
  command mkdir -p -- "$elsewhere" || return

  (
    builtin cd "$elsewhere" || return
    _test_run_installer "$home" "$home" --symlink --yes >/dev/null
  ) || return
  test_assert_equal "${TEST_REPO_ROOT:A}/.zshrc" \
    "${active:A}" 'installer resolved its repository from the caller PWD'
}
test_case 'installer resolves its source independently of the caller directory' \
  _test_installer_resolves_repository_independent_of_pwd

_test_installer_preserves_private_state() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" backup=''
  local -a backups=()

  test_write_file "$home/.zshrc" 'old active configuration' || return
  test_write_file "$home/.zsh.addons/local/init.zsh" 'PRIVATE_INIT=preserved' || return
  test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRIVATE_PEER=preserved' || return

  _test_run_installer "$home" "$home" --symlink --yes >/dev/null || return
  backups=("$home/.zsh-backups"/compozsh-*(N/))

  (( ${#backups} == 1 )) || test_fail 'existing bootstrap did not produce one backup' || return
  backup=${backups[1]}
  test_assert_equal 'old active configuration' "$(<"$backup/.zshrc")" \
    'backup did not preserve the previous bootstrap' || return
  test_assert_equal 'PRIVATE_INIT=preserved' \
    "$(<"$home/.zsh.addons/local/init.zsh")" \
    'installer replaced the private initializer' || return
  test_assert_equal 'PRIVATE_PEER=preserved' \
    "$(<"$home/.zsh.addons/work/.zsh.private")" \
    'installer replaced a private peer'
}
test_case 'default installer preserves private state and backs up the bootstrap' \
  _test_installer_preserves_private_state

# An exported EPOCHSECONDS is ordinary environment text, not the clock: it
# must neither rename the recovery backup nor abort the installation.
_test_installer_backup_stamp_ignores_inherited_epoch() {
  test_make_temp_dir || return
  local inherited='' home='' name='' error_file=''
  local -i install_status=0
  local -a backups=()

  for inherited in not-a-number 0; do
    home="$TEST_TMP_DIR/home-$inherited"
    error_file="$TEST_TMP_DIR/install-$inherited.err"
    test_write_file "$home/.zshrc" 'old active configuration' || return
    install_status=0
    command env -i \
      PATH="$PATH" \
      HOME="$home" \
      ZDOTDIR="$home" \
      TERM=xterm-256color \
      TMPDIR="${TMPDIR:-/tmp}" \
      LC_ALL=C \
      EPOCHSECONDS="$inherited" \
      "$TEST_ZSH_BIN" "$TEST_REPO_ROOT/install.zsh" --symlink --yes \
      > /dev/null 2> "$error_file" || install_status=$?
    test_assert_equal 0 "$install_status" \
      "installer failed with EPOCHSECONDS=$inherited: $(<"$error_file")" || return
    [[ $(<"$error_file") != *'could not calculate a backup location'* ]] ||
      test_fail "installer could not name a backup with EPOCHSECONDS=$inherited" || return
    backups=("$home/.zsh-backups"/compozsh-*(N/))
    (( ${#backups} == 1 )) ||
      test_fail "EPOCHSECONDS=$inherited did not produce one backup" || return
    name=${backups[1]:t}
    [[ $name =~ '^compozsh-[0-9]{8}-[0-9]{6}$' ]] ||
      test_fail "backup name is not a timestamp: $name" || return
    [[ $name != compozsh-19691231-* && $name != compozsh-19700101-* ]] ||
      test_fail "backup was stamped from EPOCHSECONDS=$inherited: $name" || return
    test_assert_equal 'old active configuration' "$(<"${backups[1]}/.zshrc")" \
      'backup did not preserve the previous bootstrap' || return
  done
}
test_case 'installer timestamps recovery backups from the clock, not an inherited EPOCHSECONDS' \
  _test_installer_backup_stamp_ignores_inherited_epoch

_test_installer_clean_is_recoverable() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" backup=''
  local -a backups=()

  test_write_file "$home/.zshrc" 'old active configuration' || return
  test_write_file "$home/.zsh.addons/local/init.zsh" 'PRIVATE_INIT=archived' || return
  test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRIVATE_PEER=archived' || return
  test_write_file "$home/.zsh.addons/support/cache/.zsh.manual.cache" 'PUBLIC_CACHE=archived' || return

  _test_run_installer "$home" "$home" --symlink --clean --yes >/dev/null || return
  backups=("$home/.zsh-backups"/compozsh-*(N/))

  (( ${#backups} == 1 )) || test_fail 'clean install did not create one recovery backup' || return
  backup=${backups[1]}
  [[ -f "$backup/.zshrc" ]] || test_fail 'clean backup omitted the bootstrap' || return
  [[ -f "$backup/.zsh.addons/local/init.zsh" ]] ||
    test_fail 'clean backup omitted the private initializer' || return
  [[ -f "$backup/.zsh.addons/work/.zsh.private" ]] ||
    test_fail 'clean backup omitted a private peer' || return
  test_assert_equal PUBLIC_CACHE=archived "$(<"$backup/.zsh.addons/support/cache/.zsh.manual.cache")" || return
  [[ ! -e "$home/.zsh.addons/support/cache" ]] || test_fail 'clean install kept the old cache active' || return
  [[ ! -e "$home/.zsh.addons/work/.zsh.private" ]] ||
    test_fail 'clean install kept private state active' || return
  test_assert_equal "$(<"$TEST_REPO_ROOT/templates/init.zsh")" \
    "$(<"$home/.zsh.addons/local/init.zsh")" \
    'clean install did not create a fresh inert initializer'
}
test_case 'clean installation archives rather than deletes existing state' \
  _test_installer_clean_is_recoverable

_test_installer_copy_is_namespaced() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRIVATE_PEER=preserved' || return
  _test_run_installer "$home" "$home" --copy --yes >/dev/null || return

  [[ -f "$home/.zshrc" && ! -L "$home/.zshrc" ]] ||
    test_fail 'copy mode did not install a regular bootstrap file' || return
  [[ -f "$home/.zsh.addons/compozsh/.zsh.tools" ]] ||
    test_fail 'copy mode omitted its namespaced shared add-ons' || return
  [[ -f "$home/.zsh.addons/compozsh/.managed-by-compozsh" ]] ||
    test_fail 'copy mode omitted its managed-namespace marker' || return
  [[ -f "$home/.zsh.addons/work/.zsh.private" ]] ||
    test_fail 'copy mode replaced a private peer' || return

  output=$(test_run_interactive "$home" \
    '
    ZSH_COLOR_SCHEME=light
    source "$HOME/.zshrc" || exit 1
    source "$HOME/.zshrc" || exit 2
    (( ${+functions[_zle_ui_view]} && ${+functions[_zle_picker_screen_session]} )) || exit 3
    _compozsh_palette_color prompt path || exit 4
    [[ $REPLY == 25 ]] || exit 5
    local catalog=$(compozsh --list)
    [[ $catalog == *"mkcd · ✓ help · compozsh/.zsh.tools"* ]] || exit 6
    print -r -- "${+functions[mkcd]}|${PRIVATE_PEER:-missing}"
    ' 2> "$TEST_TMP_DIR/load.err") || return
  [[ ! -s "$TEST_TMP_DIR/load.err" ]] || test_fail 'copied bootstrap emitted diagnostics' || return
  test_assert_equal '1|preserved' "$output" \
    'copied layout did not load shared and private peers together'
}
test_case 'copy installation keeps shared add-ons in a managed namespace' \
  _test_installer_copy_is_namespaced

_test_installer_preserves_unmarked_copy_namespace() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''
  test_write_file \
    "$home/.zsh.addons/compozsh/personal.txt" 'preserve' || return

  if output=$(_test_run_installer "$home" "$home" --copy --yes 2>&1); then
    test_fail 'installer replaced an unmarked copy namespace' || return
  fi
  test_assert_equal 'preserve' \
    "$(<"$home/.zsh.addons/compozsh/personal.txt")" \
    'installer changed an unmarked copy namespace' || return
  test_assert_contains "$output" 'not managed by this installer' \
    'installer did not explain the copy namespace conflict'
}
test_case 'copy installer preserves an unmarked same-named namespace' \
  _test_installer_preserves_unmarked_copy_namespace

_test_installer_copy_to_symlink_archives_managed_namespace() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" backup=''
  local -a backups=()
  test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRESERVE=1' || return

  _test_run_installer "$home" "$home" --copy --yes >/dev/null || return
  test_write_file \
    "$home/.zsh.addons/compozsh/stale.txt" 'old copy' || return
  _test_run_installer "$home" "$home" --symlink --yes >/dev/null || return
  backups=("$home/.zsh-backups"/compozsh-*(N/))
  backup=${backups[-1]}

  [[ -L "$home/.zshrc" ]] ||
    test_fail 'copy-to-symlink transition did not install the link' || return
  [[ ! -e "$home/.zsh.addons/compozsh" ]] ||
    test_fail 'copy-to-symlink transition left stale shared peers active' || return
  [[ -f "$backup/copied-addons/stale.txt" ]] ||
    test_fail 'copy-to-symlink transition did not archive the managed copy' || return
  test_assert_equal 'PRESERVE=1' \
    "$(<"$home/.zsh.addons/work/.zsh.private")" \
    'copy-to-symlink transition changed a private peer'
}
test_case 'symlink mode archives a previous managed copy namespace' \
  _test_installer_copy_to_symlink_archives_managed_namespace

_test_installer_symlink_preserves_unmarked_copy_collision() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''
  test_write_file \
    "$home/.zsh.addons/compozsh/personal.txt" 'preserve' || return

  if output=$(_test_run_installer "$home" "$home" --symlink --yes 2>&1); then
    test_fail 'symlink mode accepted an unmarked copy collision' || return
  fi
  test_assert_equal 'preserve' \
    "$(<"$home/.zsh.addons/compozsh/personal.txt")" \
    'symlink mode changed an unmarked copy collision' || return
  test_assert_contains "$output" 'not managed by this installer' \
    'symlink mode did not explain the copy collision'
}
test_case 'symlink mode preserves an unmarked same-named namespace' \
  _test_installer_symlink_preserves_unmarked_copy_collision

_test_installer_dry_run_is_read_only() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" output=''

  output=$(_test_run_installer "$home" "$home" --symlink --clean --dry-run) || return
  [[ ! -e "$home/.zshrc" && ! -e "$home/.zsh.addons" &&
     ! -e "$home/.zsh-backups" ]] ||
    test_fail 'dry run changed the target home' || return
  test_assert_contains "$output" 'Dry run; no files were changed' \
    'dry run did not identify itself'
}
test_case 'installer dry run performs no filesystem mutation' \
  _test_installer_dry_run_is_read_only

_test_installer_symlink_is_idempotent() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  local -a backups=()

  _test_run_installer "$home" "$home" --symlink --yes >/dev/null || return
  _test_run_installer "$home" "$home" --symlink --yes >/dev/null || return
  backups=("$home/.zsh-backups"/compozsh-*(N/))

  (( ${#backups} == 0 )) ||
    test_fail 'repeating the same symlink install created a needless backup'
}
test_case 'repeating the same symlink installation is a no-op' \
  _test_installer_symlink_is_idempotent

_test_installer_respects_zdotdir() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" zdotdir="$TEST_TMP_DIR/config/zsh"

  _test_run_installer "$home" "$zdotdir" --symlink --yes >/dev/null || return
  [[ -L "$zdotdir/.zshrc" ]] ||
    test_fail 'installer ignored the active ZDOTDIR bootstrap location' || return
  [[ -f "$zdotdir/.zsh.addons/local/init.zsh" ]] ||
    test_fail 'installer ignored the active ZDOTDIR add-on location' || return
  [[ ! -e "$home/.zshrc" && ! -e "$home/.zsh.addons" ]] ||
    test_fail 'installer wrote inactive HOME paths while ZDOTDIR was set'
}
test_case 'installer uses ZDOTDIR as the active configuration base' \
  _test_installer_respects_zdotdir

_test_installer_rolls_back_failed_activation() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$home/.zshrc" 'ORIGINAL_RC=1' || return
  test_write_file "$fake_bin/ln" $'#!/usr/bin/env zsh\nexit 1' || return
  command chmod +x "$fake_bin/ln" || return

  path=("$fake_bin" $path)
  rehash
  if output=$(_test_run_installer "$home" "$home" --symlink --yes 2>&1); then
    test_fail 'installer reported success after activation failed' || return
  fi

  test_assert_equal 'ORIGINAL_RC=1' "$(<"$home/.zshrc")" \
    'installer failed to restore the previous bootstrap' || return
  test_assert_contains "$output" 'rolling back' \
    'installer did not report its rollback'
}
test_case 'installer restores active state when activation fails' \
  _test_installer_rolls_back_failed_activation

# A stand-in tool signals its parent installer the way Ctrl-C, a closed
# terminal or `kill` would, without depending on timing.
_test_installer_rolls_back_interrupted_activation() {
  test_make_temp_dir || return
  local home='' fake_bin='' output='' signal=''
  local -a retained=()

  for signal in INT HUP TERM; do
    home="$TEST_TMP_DIR/$signal/home"
    fake_bin="$TEST_TMP_DIR/$signal/bin"
    test_write_file "$home/.zshrc" 'ORIGINAL_RC=1' || return
    test_write_file "$fake_bin/ln" \
      "#!/usr/bin/env zsh"$'\n'"kill -$signal \$PPID"$'\n''exit 130' || return
    command chmod +x "$fake_bin/ln" || return

    if output=$(path=("$fake_bin" $path); rehash
        _test_run_installer "$home" "$home" --symlink --yes 2>&1); then
      test_fail "installer reported success after SIG$signal during activation" || return
    fi
    [[ -f $home/.zshrc && ! -L $home/.zshrc ]] ||
      test_fail "SIG$signal during activation left no active .zshrc" || return
    test_assert_equal 'ORIGINAL_RC=1' "$(<"$home/.zshrc")" \
      "SIG$signal during activation did not restore the previous bootstrap" || return
    test_assert_contains "$output" 'rolling back' \
      "SIG$signal during activation did not report its rollback" || return
    retained=("$home"/.zsh-backups/compozsh-*/*(DN))
    test_assert_equal 0 "${#retained}" \
      "SIG$signal rollback left replaced state in a backup" || return
  done
}
test_case 'installer rolls back and reports recovery when interrupted during activation' \
  _test_installer_rolls_back_interrupted_activation

_test_installer_copy_staging_removed_when_interrupted() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''
  local -a leftovers=()
  test_write_file "$home/.zshrc" 'ORIGINAL_RC=1' || return
  test_write_file "$fake_bin/cp" $'#!/usr/bin/env zsh\nkill -INT $PPID\nexit 130' || return
  command chmod +x "$fake_bin/cp" || return

  path=("$fake_bin" $path)
  rehash
  if output=$(_test_run_installer "$home" "$home" --copy --yes 2>&1); then
    test_fail 'copy installer reported success after an interrupted staging copy' || return
  fi
  leftovers=("$home"/.*-install.*(DN))
  (( ! $#leftovers )) ||
    test_fail "interrupted copy left staging: ${leftovers[*]}" || return
  test_assert_equal 'ORIGINAL_RC=1' "$(<"$home/.zshrc")" \
    'interrupted copy staging changed the active bootstrap'
}
test_case 'copy installer removes its staging directory when interrupted' \
  _test_installer_copy_staging_removed_when_interrupted

_test_installer_finishes_rollback_when_interrupted_again() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''
  local -a retained=()
  test_write_file "$home/.zshrc" 'ORIGINAL_RC=1' || return
  test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRIVATE=1' || return
  test_write_file "$fake_bin/ln" $'#!/usr/bin/env zsh\nkill -INT $PPID\nexit 130' || return
  test_write_file "$fake_bin/mv" $'#!/usr/bin/env zsh
/bin/mv "$@" || exit
[[ $2 == */.zsh-backups/*/.zsh.addons ]] && kill -INT $PPID
exit 0' || return
  command chmod +x "$fake_bin/ln" "$fake_bin/mv" || return

  path=("$fake_bin" $path)
  rehash
  if output=$(_test_run_installer "$home" "$home" --symlink --clean --yes 2>&1); then
    test_fail 'clean installer reported success after an interrupted activation' || return
  fi
  test_assert_equal 'ORIGINAL_RC=1' "$(<"$home/.zshrc")" \
    'a second interrupt stopped the bootstrap restore' || return
  test_assert_equal 'PRIVATE=1' \
    "$(<"$home/.zsh.addons/work/.zsh.private")" \
    'a second interrupt stopped the private add-on restore' || return
  retained=("$home"/.zsh-backups/compozsh-*/*(DN))
  test_assert_equal 0 "${#retained}" 'interrupted rollback left replaced state in a backup'
}
test_case 'installer finishes rollback when interrupted again during restore' \
  _test_installer_finishes_rollback_when_interrupted_again

# Ctrl-C under `install.zsh 2>&1 | tee log` also ends the reader, so the
# rollback's own diagnostics must not end the installer with SIGPIPE.
_test_installer_finishes_rollback_with_closed_diagnostics_pipe() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin"
  local -a retained=()
  test_write_file "$home/.zshrc" 'ORIGINAL_RC=1' || return
  test_write_file "$fake_bin/ln" $'#!/usr/bin/env zsh\nkill -INT $PPID\nexit 130' || return
  command chmod +x "$fake_bin/ln" || return

  path=("$fake_bin" $path)
  rehash
  { _test_run_installer "$home" "$home" --symlink --yes \
      2>&1 >"$TEST_TMP_DIR/plan.out" } | : || :
  test_assert_equal 'ORIGINAL_RC=1' "$(<"$home/.zshrc")" \
    'a closed diagnostics pipe stopped the bootstrap restore' || return
  retained=("$home"/.zsh-backups/compozsh-*/*(DN))
  test_assert_equal 0 "${#retained}" 'rollback left replaced state in a backup'
}
test_case 'installer finishes rollback when its diagnostics pipe is closed' \
  _test_installer_finishes_rollback_with_closed_diagnostics_pipe

# The signal lands after the stand-in's own step completed, before the
# installer records it, as when Ctrl-C reaches a tool that already acted.
_test_installer_rolls_back_steps_completed_before_interrupt() {
  test_make_temp_dir || return
  local home='' fake_bin='' output='' tool='' step=''
  local -a retained=()
  local -i scenario=0

  for tool step in \
      mv '[[ $3 == */.zsh-backups/*/.zshrc ]]' \
      mv '[[ $3 == */.zsh-backups/*/.zsh.addons ]]' \
      mkdir '[[ ${@[-1]} == */.zsh.addons ]]'; do
    home="$TEST_TMP_DIR/$(( ++scenario ))-$tool/home"
    fake_bin="${home:h}/bin"
    test_write_file "$home/.zshrc" 'ORIGINAL_RC=1' || return
    test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRIVATE=1' || return
    test_write_file "$fake_bin/$tool" "#!/usr/bin/env zsh
/bin/$tool \"\$@\" || exit
$step && { kill -INT \$PPID; exit 130; }
exit 0" || return
    command chmod +x "$fake_bin/$tool" || return

    if output=$(path=("$fake_bin" $path); rehash
        _test_run_installer "$home" "$home" --symlink --clean --yes 2>&1); then
      test_fail "clean installer reported success after interrupting $tool" || return
    fi
    test_assert_equal 'ORIGINAL_RC=1' "$(<"$home/.zshrc")" \
      "interrupt after $step left the bootstrap unrestored" || return
    test_assert_equal 'PRIVATE=1' \
      "$(<"$home/.zsh.addons/work/.zsh.private")" \
      "interrupt after $step left private add-ons unrestored" || return
    retained+=("$home"/.zsh-backups/compozsh-*/*(DN))
    test_assert_equal 0 "${#retained}" \
      "interrupt after $step left replaced state in a backup" || return
  done
}
test_case 'installer rolls back steps that completed just before an interrupt' \
  _test_installer_rolls_back_steps_completed_before_interrupt

# A move across volumes can be stopped after writing a partial copy but before
# removing its source; rollback must keep the intact original and say where
# the leftover backup is instead of restoring the copy over it.
_test_installer_keeps_backup_it_cannot_restore_safely() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''
  local -a retained=()
  test_write_file "$home/.zshrc" 'ORIGINAL_RC=1' || return
  test_write_file "$fake_bin/mv" $'#!/usr/bin/env zsh
if [[ $3 == */.zsh-backups/*/.zshrc ]]; then
  print -r -- PARTIAL >| "$3"
  kill -INT $PPID
  exit 130
fi
exec /bin/mv "$@"' || return
  command chmod +x "$fake_bin/mv" || return

  path=("$fake_bin" $path)
  rehash
  if output=$(_test_run_installer "$home" "$home" --symlink --yes 2>&1); then
    test_fail 'installer reported success after an interrupted archive' || return
  fi
  test_assert_equal 'ORIGINAL_RC=1' "$(<"$home/.zshrc")" \
    'rollback replaced the intact bootstrap with a partial backup' || return
  retained=("$home"/.zsh-backups/compozsh-*(/N))
  test_assert_equal 1 "${#retained}" 'rollback removed the unrestored backup' || return
  test_assert_contains "$output" "replaced state remains in ${retained[1]:A}" \
    'rollback did not name the backup it kept'
}
test_case 'installer keeps and names a backup it cannot restore safely' \
  _test_installer_keeps_backup_it_cannot_restore_safely

_test_installer_removes_partial_initializer_on_failure() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRESERVE=1' || return
  test_write_file "$fake_bin/cp" \
    $'#!/usr/bin/env zsh\nprint -r -- partial >| "${@[-1]}"\nexit 1' || return
  command chmod +x "$fake_bin/cp" || return

  path=("$fake_bin" $path)
  rehash
  if output=$(_test_run_installer "$home" "$home" --symlink --yes 2>&1); then
    test_fail 'installer reported success after initializer copy failed' || return
  fi

  [[ ! -e "$home/.zshrc" &&
     ! -e "$home/.zsh.addons/local/init.zsh" ]] ||
    test_fail 'installer left partially created active files' || return
  test_assert_equal 'PRESERVE=1' \
    "$(<"$home/.zsh.addons/work/.zsh.private")" \
    'rollback removed a pre-existing private peer' || return
  test_assert_contains "$output" 'rolling back' \
    'partial initializer failure did not trigger rollback'
}
test_case 'installer removes partial files but preserves private state on failure' \
  _test_installer_removes_partial_initializer_on_failure

_test_installer_clean_leaves_other_zsh_startup_files() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home"
  test_write_file "$home/.zshrc" 'old rc' || return
  test_write_file "$home/.zshenv" 'KEEP_ZSHENV=1' || return
  test_write_file "$home/.zprofile" 'KEEP_ZPROFILE=1' || return
  test_write_file "$home/.zcompdump" 'KEEP_ZCOMPDUMP=1' || return

  _test_run_installer "$home" "$home" --symlink --clean --yes >/dev/null || return
  test_assert_equal 'KEEP_ZSHENV=1' "$(<"$home/.zshenv")" \
    'clean mode changed .zshenv' || return
  test_assert_equal 'KEEP_ZPROFILE=1' "$(<"$home/.zprofile")" \
    'clean mode changed .zprofile' || return
  test_assert_equal 'KEEP_ZCOMPDUMP=1' "$(<"$home/.zcompdump")" \
    'clean mode changed the native completion dump'
}
test_case 'clean installer touches only the active bootstrap and add-on tree' \
  _test_installer_clean_leaves_other_zsh_startup_files

_test_installer_rejects_repository_as_configuration_base() {
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/repository" output=''
  command mkdir -p -- "$fixture" || return
  command cp "$TEST_REPO_ROOT/.zshrc" "$fixture/.zshrc" || return
  command cp "$TEST_REPO_ROOT/install.zsh" "$fixture/install.zsh" || return
  command cp -R "$TEST_REPO_ROOT/.zsh.addons" "$fixture/.zsh.addons" || return
  command cp -R "$TEST_REPO_ROOT/templates" "$fixture/templates" || return

  if output=$(_test_run_installer_at "$fixture/install.zsh" \
      "$fixture" "$fixture" --symlink --clean --yes 2>&1); then
    test_fail 'installer accepted its repository as the configuration base' || return
  fi
  [[ -f "$fixture/.zshrc" && -d "$fixture/.zsh.addons" ]] ||
    test_fail 'installer mutated its own repository source' || return
  test_assert_contains "$output" 'configuration base overlaps the repository' \
    'installer did not explain the unsafe overlap'
}
test_case 'installer refuses to install over its own repository source' \
  _test_installer_rejects_repository_as_configuration_base

_test_installer_rejects_configuration_inside_repository() {
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/repository"
  local config_base="$fixture/private-config" output=''
  command mkdir -p -- "$fixture" || return
  command cp "$TEST_REPO_ROOT/.zshrc" "$fixture/.zshrc" || return
  command cp "$TEST_REPO_ROOT/install.zsh" "$fixture/install.zsh" || return
  command cp -R "$TEST_REPO_ROOT/.zsh.addons" "$fixture/.zsh.addons" || return
  command cp -R "$TEST_REPO_ROOT/templates" "$fixture/templates" || return

  if output=$(_test_run_installer_at "$fixture/install.zsh" \
      "$TEST_TMP_DIR/home" "$config_base" --copy --dry-run 2>&1); then
    test_fail 'installer accepted private configuration inside its repository' || return
  fi
  [[ ! -e "$config_base/.zshrc" && ! -e "$config_base/.zsh.addons" ]] ||
    test_fail 'installer wrote private state inside its repository' || return
  test_assert_contains "$output" 'configuration base overlaps the repository' \
    'installer did not explain the nested source/configuration overlap'
}
test_case 'installer refuses private configuration inside its repository' \
  _test_installer_rejects_configuration_inside_repository

_test_installer_validates_nested_shared_peers() {
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/repository" home="$TEST_TMP_DIR/home"
  local output=''
  command mkdir -p -- "$fixture" || return
  command cp "$TEST_REPO_ROOT/.zshrc" "$fixture/.zshrc" || return
  command cp "$TEST_REPO_ROOT/install.zsh" "$fixture/install.zsh" || return
  command cp -R "$TEST_REPO_ROOT/.zsh.addons" "$fixture/.zsh.addons" || return
  command cp -R "$TEST_REPO_ROOT/templates" "$fixture/templates" || return
  test_write_file "$fixture/.zsh.addons/nested/.zsh.invalid" \
    'if deliberately-invalid' || return

  if output=$(_test_run_installer_at "$fixture/install.zsh" \
      "$home" "$home" --symlink --dry-run 2>&1); then
    test_fail 'installer accepted an invalid nested shared peer' || return
  fi
  [[ ! -e "$home/.zshrc" && ! -e "$home/.zsh.addons" ]] ||
    test_fail 'installer mutated state before nested syntax validation' || return
  test_assert_contains "$output" 'repository Zsh file does not parse' \
    'installer did not report nested peer syntax failure'
}
test_case 'installer syntax-checks nested shared peers before mutation' \
  _test_installer_validates_nested_shared_peers
