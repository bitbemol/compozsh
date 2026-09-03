# Self-documenting public command contracts.

_test_public_commands_support_help() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''

  test_write_file "$fake_bin/git" \
    $'#!/bin/zsh\nprint -r -- delegated-git-help\n' || return
  command chmod +x "$fake_bin/git" || return

  output=$(test_run_interactive "$home" $'
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    builtin cd -- "$HOME" || exit

    typeset -a help_lines=()
    typeset -a public_commands=(
      mkcd
      cpdir
      git-discard-all
      prompt-refresh
      compozsh-sudo-touch-id
      g
      flash-usb
      format-external-device
      xcode
      update-xcode-skills
      compozsh
    )
    for public_command in "${public_commands[@]}"; do
      stdout_file="$HOME/${public_command}.stdout"
      stderr_file="$HOME/${public_command}.stderr"
      "$public_command" --help >| "$stdout_file" 2>| "$stderr_file"
      command_status=$?
      stdout=$(<"$stdout_file")
      stderr=$(<"$stderr_file")
      help_lines=("${(f)stdout}")
      description=${help_lines[2]-}
      description_present=0
      [[ -n $description ]] && description_present=1
      stayed_put=0
      [[ $PWD == $HOME ]] && stayed_put=1
      print -r -- "$public_command|$command_status|${stdout[(f)1]:-}|$description_present|${#stderr}|$stayed_put"
      builtin cd -- "$HOME" || exit
    done
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  local public_command='' output_line='' record=''
  for public_command in mkcd cpdir git-discard-all prompt-refresh compozsh-sudo-touch-id g flash-usb format-external-device xcode \
      update-xcode-skills compozsh; do
    record=''
    for output_line in ${(f)output}; do
      if [[ $output_line == "$public_command|"* ]]; then
        record=$output_line
        break
      fi
    done
    test_assert_contains "$record" "$public_command|0|usage: $public_command" \
      "$public_command --help did not succeed on stdout" || return
    [[ $record == *'|1|0|1' ]] || {
      test_fail "$public_command --help lacks a description, emitted stderr, or changed state"
      return
    }
  done
}
test_case 'every direct Compozsh command supports side-effect-free --help' \
  _test_public_commands_support_help

_test_public_command_names_use_kebab_case() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    local helper command
    local -a invalid=()
    for helper in ${(k)functions[(I)_compozsh_help_*]}; do
      command=${helper#_compozsh_help_}
      [[ $command == *_* ]] && invalid+=("$command")
    done
    print -r -- "${(j:,:)${(on)invalid}}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '' "$output" \
    'public Compozsh commands with help providers must use kebab-case'
}
test_case 'public Compozsh command names use kebab-case' \
  _test_public_command_names_use_kebab_case

_test_file_finder_help_explains_search() {
  test_make_temp_dir || return
  local output='' fact=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    compozsh --help
  ' "$TEST_REPO_ROOT") || return

  # Protect the answers users need, without snapshotting the whole document.
  local -a facts=(
    'path + Tab' 'repository root' 'current directory'
    '~/ then Tab' 'Recents' 'Option-Tab' 'Option as Meta' 'directory stack'
    'vim ~/Developer + Tab' 'preserve the command' 'replaces only that argument'
    'Spotlight index' 'longest query fragment' 'Unindexed'
    'any order' 'file contents' 'initial query' 'captured paths'
    '20,000' '2,000' '10 rows' 'Partial'
    'ZSH_FILE_SEARCH_MAX_VISITED' 'ZSH_FILE_SEARCH_MAX_CANDIDATES'
    'ZSH_FILE_SEARCH_MAX_RESULTS' 'shell-quoted' 'Option-W' 'Ctrl-Y'
    'file-action picker' 'Open with default app' 'Reveal in Finder'
    'exact selected file, folder or link' 'Current folder operations'
    'registered app' 'normally Finder for folders' 'containing folder'
    'selects the exact item in Finder'
    'Git within a worktree' 'home/root on macOS' 'Filesystem elsewhere'
    'Searching' 'synchronous' 'failed source' 'No fallback scan'
    'Insert path' 'Enter linked directory' 'same' 'selected row'
    'broken link' 'only items you trust' 'after picker cleanup'
  )
  for fact in "${facts[@]}"; do
    test_assert_contains "$output" "$fact" "compozsh --help omits guidance: $fact" || return
  done
}
test_case 'file finder help explains scopes, discovery limits, and practical use' \
  _test_file_finder_help_explains_search

_test_file_finder_help_is_static_and_errors_stay_short() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    builtin cd -- "$HOME" || exit
    path=()
    _FILE_SEARCH_VALUES=(/example/kept)
    _FILE_SEARCH_ROOT=/example/original
    _file_search_capture_git() { print -u2 -- unexpected-capture; return 99; }
    _file_search_capture_local() { print -u2 -- unexpected-capture; return 99; }
    _file_search_capture_spotlight() { print -u2 -- unexpected-capture; return 99; }
    _file_search_copy() { print -u2 -- unexpected-copy; return 99; }
    compozsh --help > "$HOME/help.out" 2> "$HOME/help.err" || exit 10
    help_text=$(<"$HOME/help.out")
    [[ ! -s "$HOME/help.err" && $PWD == $HOME &&
       $_FILE_SEARCH_VALUES[1] == /example/kept &&
       $_FILE_SEARCH_ROOT == /example/original ]] || exit 11
    ZSH_FILE_SEARCH_MAX_VISITED=1
    ZSH_FILE_SEARCH_MAX_CANDIDATES=1
    ZSH_FILE_SEARCH_MAX_RESULTS=1
    TERM=dumb
    [[ $(compozsh --help) == "$help_text" ]] || exit 12
    [[ $help_text == $(_compozsh_help_compozsh) ]] || exit 13
    compozsh --invalid --invalid > "$HOME/invalid.out" 2> "$HOME/invalid.err"
    [[ $? == 2 && ! -s "$HOME/invalid.out" ]] || exit 14
    usage_text=$(<"$HOME/invalid.err")
    [[ $usage_text == "${help_text[(f)1]}" ]] || exit 15
    print -r -- static-help-and-short-errors
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal 'static-help-and-short-errors' "$output"
}
test_case 'file finder help stays static without tools and usage errors stay concise' \
  _test_file_finder_help_is_static_and_errors_stay_short

_test_tool_help_explains_real_boundaries() {
  test_make_temp_dir || return
  local output='' tool='' fact=''
  local -a facts=()
  for tool in mkcd cpdir git-discard-all prompt-refresh compozsh-sudo-touch-id g flash-usb format-external-device xcode \
      update-xcode-skills compozsh; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1/.zsh.addons/.zsh.tools"
      source "$1/.zsh.addons/.zsh.navigation"
      source "$1/.zsh.addons/.zsh.sudo-touch-id"
      source "$1/.zsh.addons/.zsh.usb"
      source "$1/.zsh.addons/.zsh.xcode"
      source "$1/.zsh.addons/.zsh.help"
      "$2" --help
    ' "$TEST_REPO_ROOT" "$tool") || return
    case $tool in
      (mkcd) facts=('parent directories' 'existing directory' 'spaces' './--help' 'Examples:') ;;
      (cpdir) facts=('logical' 'newline' 'shell-quoted' 'pbcopy' 'SSH' 'Examples:') ;;
      (git-discard-all) facts=('repository root' 'HEAD' 'staged' 'untracked'
        '[y/N]' 'ignored' 'submodule' 'rebase' 'rollback' 'stash'
        'content filters' 'After confirmation' 'Examples:') ;;
      (prompt-refresh) facts=('current shell' 'next use' 'exec zsh' 'reload' 'Examples:') ;;
      (compozsh-sudo-touch-id) facts=('/etc/pam.d/sudo_local' 'default' 'root-owned'
        'Custom PAM policy' 'pam_opendirectory.so authenticator' 'sudo permission' 'SSH'
        'macOS Sonoma 14' 'ACL-free' '/usr/bin/sudo -v' 'timestamp' 'sudo -n'
        'persists' 'No backup' 'uncertain enable error' 'Apple-supported'
        'Apple supports this interface' 'Compozsh additionally requires'
        'entirely local' 'no network' 'Secure Enclave' "sudo's exit status"
        'reusable biometric token' 'successful Touch ID authentication'
        'password keystrokes' 'credential capture'
        'same terminal session' 'sudo -k' 'managed work Mac' 'PAM policy'
        'never other links' \
        'does not verify that a command is safe' 'never enabled automatically'
        'Examples:') ;;
      (g) facts=('200' 'reflog' 'remote' 'g branch' 'character order'
        'git switch --no-guess' 'worktree' 'pbcopy' 'Ctrl-Y' 'SSH'
        'empty' 'Ctrl-U' 'noninteractive' 'Examples:' 'Ctrl-X review' 'read-only'
        'Right: files' 'Left reverses' 'Ctrl-R refreshes' 'one reading level'
        'file list and selected diff' 'no results' 'manual' 'first match'
        'previous snapshot' 'captured commit ID'
        'g --review' 'All differences' 'Changes since common ancestor' '1,000 refs'
        'Against' 'Both choices' 'Enter chooses the best matching ref'
        'full object IDs' '512 characters' 'nothing is fetched'
        'staged' 'unstaged' 'first parent' '256 KiB' 'filters' 'hunks'
        '800 ms child'
        'untracked regular text' 'NUL' 'Symlinks' 'new-file snapshot'
        'inside new directories' 'Ignored files remain excluded'
        'Nested repositories stay separate') ;;
      (flash-usb) facts=('regular .iso or .img' 'Finder-indexed' '500' 'current-folder' '~/Downloads' 'drag'
        'creation time' 'newest first' 'format, size' 'in-order' 'Spotlight exclusions'
        'Custom path' 'bounded browser' 'Left moves' 'Right or Return'
        'Removable Volumes' 'Retry' 'source during dd'
        'external physical' 'internal' 'virtual' 'read-only' 'partition-slice'
        'Thunderbolt' '1 MiB' '4,096' '64 whole' 'Step 2 Ctrl-R'
        'physically plugged' 'Ctrl-R cannot reactivate' 'unplug and reconnect'
        'Step 3' 'bold error red' 'bold success green' 'ERASE diskN' 'mismatch'
        'writes nothing' 'warning color' 'NO_COLOR' 'sudo' '/dev/rdiskN' '4 MiB'
        'determinate progress' 'dedicated status view' 'no query or bottom footer' 'disconnect warning' 'semantic heading' 'current comparison pass' 'aligned 4 MiB reads' 'final screen' 'average'
        'raw handler does not pre-format' 'held write session' 'every image byte'
        'physical-tail cleanup' 'short reads' 'pre-mount proof' 'checksum' 'createinstallmedia'
        'Windows Setup media' 'Windows unsupported' 'FAT32' '4 GiB' 'DISM'
        'install.swm' 'bounded archive table' 'attach fallback'
        'Nothing was written or targeted' 'Apple code signature'
        'cannot roll back' 'Examples:') ;;
      (format-external-device) facts=('whole external physical' 'Internal' 'virtual'
        'read-only' 'partition-slice' '1 MiB' '4,096' '64 whole' 'Ctrl-R'
        'temporary snapshot' 'listFilesystems -plist' 'every filesystem personality'
        'Free Space' 'size bounds' 'passed unchanged' 'eraseDisk' 'External'
        'Step 3' 'custom name' '11-character' '255 printable' 'Invalid input'
        '256-color' 'live stages' 'field labels' 'NO_COLOR' 'exit status'
        'ERASE diskN' 'administrator authorization' 'immediately before'
        'permanently destroys' 'cannot restore' 'Examples:') ;;
      (xcode) facts=('nearest' 'workspace' 'project' 'scheme' 'destination'
        'Build' 'Test' 'Analyze' 'Clean' 'Simulator' 'read-only discovery'
        'build scripts' 'package plugins' 'automatic package resolution'
        'provisioning updates' 'xcodebuild' 'Copy report and done' 'pbcopy'
        'clipboard of the machine running Zsh' 'four schemes'
        'Refresh destinations' 'reopening xcode' 'Rebuild & Test'
        'Build & Run' 'Rebuild & Run' 'incremental' 'buildable folder'
        'target membership' 'test mode' 'slower recovery' 'Examples:') ;;
      (update-xcode-skills) facts=('xcode-select' 'DEVELOPER_DIR' 'PATH'
        '~/.agents/skills' '~/.claude/skills' '~/.gemini/config/skills'
        '~/.kiro/skills' 'CodingAssistant/codex/skills/__xcode'
        '.xcode-skill-export' 'conflicts' 'per skill' 'session' 'Examples:') ;;
      (compozsh) facts=('loaded' '.zsh.addons' 'same file' 'no help'
        'never runs' 'character order' 'empty' 'Ctrl-U' '--list'
        'ZSH_TOOL_PICKER_MAX_RESULTS' 'Examples:') ;;
    esac
    for fact in "${facts[@]}"; do
      test_assert_contains "$output" "$fact" "$tool --help omits guidance: $fact" || return
    done
  done
}
test_case 'tool help explains defaults, scope, examples, and safety boundaries' \
  _test_tool_help_explains_real_boundaries

_test_all_tool_help_is_static_without_optional_tools() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    builtin cd -- "$HOME" || exit
    path=()
    TERM=dumb
    # Any accidental operational dispatch emits a diagnostic and fails.
    for helper in _directory_stack_capture _git_branch_stack_load \
        _detect_xcode_skill_vendor _compozsh_tool_capture; do
      functions[$helper]="print -u2 -- unexpected-operation; return 99"
    done
    for tool in mkcd cpdir git-discard-all prompt-refresh compozsh-sudo-touch-id g flash-usb format-external-device xcode \
        update-xcode-skills compozsh; do
      "$tool" --help >| "$HOME/help.out" 2>| "$HOME/help.err" || exit 10
      help_text=$(<"$HOME/help.out")
      [[ ! -s "$HOME/help.err" && $PWD == $HOME ]] || exit 11
      [[ $help_text != *$'\''\e'\''* ]] || exit 12
      [[ $help_text == $("_compozsh_help_$tool") ]] || exit 13
      TERM=xterm-256color
      [[ $help_text == $("$tool" --help) ]] || exit 14
      TERM=dumb
      # g and xcode delegate argument-bearing calls; other tools own errors.
      if [[ $tool != g && $tool != xcode ]]; then
        "$tool" --invalid --invalid >| "$HOME/help.out" 2>| "$HOME/help.err"
        [[ $? == 2 && ! -s "$HOME/help.out" ]] || exit 15
        [[ $(<"$HOME/help.err") == "${help_text[(f)1]}" ]] || exit 16
      fi
    done
    print -r -- static-help-without-tools
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal static-help-without-tools "$output"
  local -a created=("$TEST_TMP_DIR/home"/*(ND))
  test_assert_equal 2 "${#created}" 'help created files beyond test stdout/stderr'
}
test_case 'all tool help remains plain, deterministic, and available without tools' \
  _test_all_tool_help_is_static_without_optional_tools

_test_help_terminal_colors_and_plain_fallbacks() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    setopt EXTENDED_GLOB
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.sudo-touch-id"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/.zsh.xcode"
    # Load output last: no help provider may depend on its source order.
    typeset -gA ZSH_OUTPUT_COLORS=(heading 123 accent 124 info 125 warning 126)
    source "$1/.zsh.addons/.zsh.output"
    path=()
    zmodload zsh/zpty || exit 10
    _help_test_driver() {
      local tool
      for tool in mkcd cpdir git-discard-all prompt-refresh compozsh-sudo-touch-id g flash-usb format-external-device xcode \
          update-xcode-skills compozsh; do
        "$tool" --help || return
      done
      compozsh help g
      print -r -- END-HELP-COLOR-TEST
    }
    _help_test_capture() {
      local capture="" line=""
      zpty help-color _help_test_driver || return
      {
        # Read bounded lines rather than repeatedly matching a growing guide.
        while zpty -r help-color line; do
          capture+=$line
          [[ $line == *END-HELP-COLOR-TEST* ]] && break
        done
        [[ $capture == *END-HELP-COLOR-TEST* ]] || return 1
        REPLY=${capture//$'\''\r'\''/}
        REPLY=${REPLY%$'\''\n'\''}
      } always {
        zpty -d help-color
      }
    }
    plain=$(_help_test_driver) || exit 11
    [[ $plain != *$'\''\e'\''* ]] || exit 12
    _help_test_capture || exit 13
    colored=$REPLY
    for tool in mkcd cpdir git-discard-all prompt-refresh compozsh-sudo-touch-id g flash-usb format-external-device xcode \
        update-xcode-skills compozsh; do
      [[ $colored == *$'\''\e[1;38;5;123m'\''"usage: $tool"* ]] || {
        print -u2 -- "$tool help is missing the heading palette color"
        exit 14
      }
    done
    [[ $colored == *$'\''\e[38;5;124m--list'\''* ]] || { print -u2 missing-option-color; exit 15; }
    [[ $colored == *$'\''\e[1;38;5;126mSafety and limitations:'\''* ]] || { print -u2 missing-warning-color; exit 15; }
    [[ $colored == *$'\''\e[38;5;125mcompozsh help g'\''* ]] || { print -u2 missing-example-color; exit 15; }
    stripped=${colored//$'\''\e'\''\[[0-9\;]#m/}
    [[ $stripped == $plain ]] || {
      print -u2 -- "styling changed help text, line breaks, or explorer output"
      exit 16
    }
    # A supported terminal still emits exact plain bytes when redirected.
    _help_test_driver > "$HOME/redirected"
    [[ $(<"$HOME/redirected") == $plain ]] || exit 17
    NO_COLOR=1
    _help_test_capture || exit 18
    [[ $REPLY == $plain ]] || exit 19
    unset NO_COLOR
    for TERM in dumb vt100; do
      _help_test_capture || exit 20
      [[ $REPLY == $plain ]] || exit 21
    done
    TERM=xterm-256color
    unfunction _output_print_help
    _help_test_capture || exit 22
    [[ $REPLY == $plain ]] || exit 23
    print -r -- terminal-colors-and-exact-plain-fallbacks
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal terminal-colors-and-exact-plain-fallbacks "$output"
}
test_case 'help uses semantic terminal colors with byte-identical plain fallbacks' \
  _test_help_terminal_colors_and_plain_fallbacks

_test_help_color_treats_text_and_overrides_as_data() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    setopt EXTENDED_GLOB PROMPT_SUBST
    source "$1/.zsh.addons/.zsh.output"
    path=()
    _help_test_side_effect() { print -r -- executed > "$HOME/unexpected"; }
    ZSH_OUTPUT_COLORS[heading]=$'\''$(_help_test_side_effect)'\''
    ZSH_OUTPUT_COLORS[accent]=999999999999999999999999999999
    _help_test_literal() {
      _output_print_help "usage: literal" \
        $'\''$(_help_test_side_effect) %F{red} \\n literal'\'' \
        "  --flag  Explanation" ""
      print -r -- END-LITERAL-HELP
    }
    plain=$(_help_test_literal)
    zmodload zsh/zpty || exit 10
    zpty literal-help _help_test_literal || exit 11
    {
      zpty -r literal-help colored "*END-LITERAL-HELP*" || exit 12
    } always {
      zpty -d literal-help
    }
    colored=${colored//$'\''\r'\''/}
    colored=${colored%$'\''\n'\''}
    [[ $colored == *$'\''\e[1;38;5;75musage: literal'\''* &&
       $colored == *$'\''\e[38;5;81m--flag'\''* ]] || exit 13
    stripped=${colored//$'\''\e'\''\[[0-9\;]#m/}
    [[ $stripped == $plain && ! -e "$HOME/unexpected" ]] || exit 14
    print -r -- help-text-and-palette-remain-inert
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal help-text-and-palette-remain-inert "$output"
}
test_case 'help colors validate palette overrides and never expand help text' \
  _test_help_color_treats_text_and_overrides_as_data
