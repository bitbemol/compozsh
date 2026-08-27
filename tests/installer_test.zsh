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
  local output='' fact='' flag=''
  for flag in --help -h; do
    output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
      path=()
      source "$1/install.zsh" "$2"
    ' "$TEST_REPO_ROOT" "$flag" 2> "$TEST_TMP_DIR/help.err") || return
    [[ ! -s "$TEST_TMP_DIR/help.err" ]] || test_fail 'installer help wrote stderr' || return
    for fact in 'Install Compozsh' 'ZDOTDIR' '--symlink' '--copy' '--clean' \
        '--dry-run' '--yes' 'local/init.zsh' '.zsh-backups' 'repository' \
        'exec zsh' 'Examples:' 'tools'; do
      test_assert_contains "$output" "$fact" "installer help omits guidance: $fact" || return
    done
  done
  local -a installed=("$TEST_TMP_DIR/home"/*(ND))
  test_assert_equal 0 "${#installed}" 'installer help wrote configuration files'
}
test_case 'installer help explains installation, updates, and recovery without writes' \
  _test_installer_help_explains_lifecycle_without_installing

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
    'successful install omitted its completion message'
}
test_case 'installer creates a fresh recommended symlink installation' \
  _test_installer_fresh_symlink

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

_test_installer_clean_is_recoverable() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" backup=''
  local -a backups=()

  test_write_file "$home/.zshrc" 'old active configuration' || return
  test_write_file "$home/.zsh.addons/local/init.zsh" 'PRIVATE_INIT=archived' || return
  test_write_file "$home/.zsh.addons/work/.zsh.private" 'PRIVATE_PEER=archived' || return

  _test_run_installer "$home" "$home" --symlink --clean --yes >/dev/null || return
  backups=("$home/.zsh-backups"/compozsh-*(N/))

  (( ${#backups} == 1 )) || test_fail 'clean install did not create one recovery backup' || return
  backup=${backups[1]}
  [[ -f "$backup/.zshrc" ]] || test_fail 'clean backup omitted the bootstrap' || return
  [[ -f "$backup/.zsh.addons/local/init.zsh" ]] ||
    test_fail 'clean backup omitted the private initializer' || return
  [[ -f "$backup/.zsh.addons/work/.zsh.private" ]] ||
    test_fail 'clean backup omitted a private peer' || return
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
    'source "$HOME/.zshrc"; print -r -- "${+functions[mkcd]}|${PRIVATE_PEER:-missing}"') || return
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

  _test_run_installer "$home" "$home" --symlink --clean --yes >/dev/null || return
  test_assert_equal 'KEEP_ZSHENV=1' "$(<"$home/.zshenv")" \
    'clean mode changed .zshenv' || return
  test_assert_equal 'KEEP_ZPROFILE=1' "$(<"$home/.zprofile")" \
    'clean mode changed .zprofile'
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
