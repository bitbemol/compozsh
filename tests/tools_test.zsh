_test_mkcd_contract() {
  test_make_temp_dir || return
  local target="$TEST_TMP_DIR/new/nested" output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" \
    'source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"; mkcd "$2"; print -r -- "$PWD|${PWD:P}"' \
    "$TEST_REPO_ROOT" "$target") || return
  test_assert_equal "$target|${target:P}" "$output" \
    'mkcd did not create and enter the requested directory'
}
test_case 'mkcd creates and enters exactly one requested directory' \
  _test_mkcd_contract

_test_cpdir_contract() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" target="$TEST_TMP_DIR/path with spaces"
  local output='' copied='' copied_size=''
  command mkdir -p "$fake_bin" "$target" || return
  test_write_file "$fake_bin/pbcopy" $'#!/bin/zsh\nIFS= read -r -d \'\' value\nprint -rn -- "$value" >| "$HOME/clipboard"\n' || return
  command chmod +x "$fake_bin/pbcopy" || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    PATH="$2"
    rehash
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd "$3" || exit
    cpdir
  ' "$TEST_REPO_ROOT" "$fake_bin" "$target") || return
  copied=$(<"$TEST_TMP_DIR/home/clipboard") || return
  copied_size=$(command wc -c < "$TEST_TMP_DIR/home/clipboard") || return
  copied_size=${copied_size//[[:space:]]/}

  test_assert_equal "$target" "$copied" \
    'cpdir did not copy the exact logical working directory' || return
  test_assert_equal "${#target}" "$copied_size" \
    'cpdir appended bytes such as a trailing newline' || return
  test_assert_equal "Copied ${target} to the clipboard." "$output" \
    'cpdir did not confirm the copied directory'
}
test_case 'cpdir copies the current directory without a trailing newline' \
  _test_cpdir_contract

_test_cpdir_path_color() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/pbcopy" $'#!/bin/zsh\n(( ${CLIPBOARD_STATUS:-0} )) && exit "$CLIPBOARD_STATUS"\nIFS= read -r -d \'\' value\nprint -rn -- "$value" >| "$HOME/clipboard"\n' || return
  command chmod +x "$fake_bin/pbcopy" || return
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    path=("$2" /usr/bin /bin)
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    # The palette is a runtime input; it can be loaded after this peer.
    typeset -A ZSH_PROMPT_COLORS=(path 123)
    local leaf=$'\''literal %F{red} $(cpdir_probe)\n\e'\''
    command mkdir -p "$HOME/$leaf"
    builtin cd -- "$HOME/$leaf" || exit 1
    cpdir_probe() { print executed > "$HOME/unexpected"; }
    local display=${PWD//[[:cntrl:]]/?}
    local plain="Copied $display to the clipboard."
    local colored="Copied "$'\''\e[38;5;123m'\''"$display"$'\''\e[39m'\''" to the clipboard."
    _cpdir_color_driver() {
      cpdir
      print -r -- "STATUS:$?:END-CPDIR"
    }
    zmodload zsh/zpty || exit 2
    _cpdir_color_capture() {
      local frame=""
      zpty cpdir-color _cpdir_color_driver || return
      {
        zpty -r cpdir-color frame "*END-CPDIR*" || return
        REPLY=${frame//$'\''\r'\''/}
        REPLY=${REPLY%$'\''\n'\''}
      } always { zpty -d cpdir-color; }
    }
    _cpdir_color_capture || exit 3
    [[ $REPLY == "$colored"$'\''\n'\''STATUS:0:END-CPDIR ]] || {
      print -u2 -- "cpdir must color only the sanitized path with the path palette"
      exit 4
    }
    [[ $(<"$HOME/clipboard") == "$PWD" ]] || exit 5
    local bytes=$(command wc -c < "$HOME/clipboard")
    (( bytes == ${#PWD} )) || exit 6
    # Redirection, pipes and substitutions keep exact plain output.
    [[ $(_cpdir_color_driver) == "$plain"$'\''\n'\''STATUS:0:END-CPDIR ]] || exit 7
    _cpdir_color_driver > "$HOME/confirmation"
    [[ $(<"$HOME/confirmation") == "$plain"$'\''\n'\''STATUS:0:END-CPDIR ]] || exit 8
    [[ $(_cpdir_color_driver | /bin/cat) == "$plain"$'\''\n'\''STATUS:0:END-CPDIR ]] || exit 9
    local scenario=""
    for scenario in no-color dumb limited invalid missing; do
      TERM=xterm-256color
      unset NO_COLOR
      ZSH_PROMPT_COLORS[path]=123
      case $scenario in
        (no-color) NO_COLOR=1 ;;
        (dumb) TERM=dumb ;;
        (limited) TERM=vt100 ;;
        (invalid) ZSH_PROMPT_COLORS[path]='\''$(cpdir_probe)'\'' ;;
        (missing) unset ZSH_PROMPT_COLORS ;;
      esac
      _cpdir_color_capture || exit 10
      [[ $REPLY == "$plain"$'\''\n'\''STATUS:0:END-CPDIR ]] || exit 11
    done
    [[ ! -e "$HOME/unexpected" ]] || exit 12
    typeset -A ZSH_PROMPT_COLORS=(path 123)
    export CLIPBOARD_STATUS=17
    _cpdir_color_capture || exit 13
    [[ $REPLY == "cpdir: could not copy the current directory"$'\''\n'\''STATUS:1:END-CPDIR ]] || exit 14
    print path-color
  ' "$TEST_REPO_ROOT" "$fake_bin") || return
  test_assert_equal path-color "$output"
}
test_case 'cpdir colors only its displayed path and preserves clipboard plain-output and failure contracts' \
  _test_cpdir_path_color

_test_cpdir_missing_clipboard() {
  test_make_temp_dir || return
  local empty_bin="$TEST_TMP_DIR/empty-bin" output='' exit_status=0
  command mkdir -p "$empty_bin" || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    PATH="$2"
    rehash
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    cpdir
  ' "$TEST_REPO_ROOT" "$empty_bin" 2>&1) || exit_status=$?

  (( exit_status != 0 )) || {
    test_fail 'cpdir succeeded without a clipboard command'
    return
  }
  test_assert_contains "$output" 'pbcopy is unavailable' \
    'cpdir omitted its missing-clipboard diagnostic'
}
test_case 'cpdir fails clearly when the macOS clipboard is unavailable' \
  _test_cpdir_missing_clipboard

_test_git_discard_all_scope() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repository" output=''
  command mkdir -p "$repo" || return
  command git -C "$repo" init -q || return
  command git -C "$repo" config user.name 'Zsh Tests' || return
  command git -C "$repo" config user.email 'zsh-tests.invalid@example.invalid' || return
  test_write_file "$repo/.gitignore" $'ignored/\n' || return
  test_write_file "$repo/tracked.txt" 'baseline' || return
  command git -C "$repo" add .gitignore tracked.txt || return
  command git -C "$repo" commit -qm baseline || return
  test_write_file "$repo/tracked.txt" 'changed' || return
  test_write_file "$repo/untracked.txt" 'temporary' || return
  test_write_file "$repo/ignored/keep.txt" 'preserve' || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd "$2" || exit
    g --discard-all <<< y >/dev/null 2>&1 || exit
    [[ -e untracked.txt ]]; untracked_exists=$(( !$? ))
    [[ -e ignored/keep.txt ]]; ignored_exists=$(( !$? ))
    print -r -- "$(<tracked.txt)|$untracked_exists|$ignored_exists"
  ' "$TEST_REPO_ROOT" "$repo") || return
  test_assert_equal 'baseline|0|1' "$output" \
    'g --discard-all changed data outside its documented scope'
}
test_case 'g --discard-all restores tracked data and preserves ignored files' \
  _test_git_discard_all_scope

_test_git_discard_all_disables_repository_filters() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repository"
  local filter="$TEST_TMP_DIR/filter" probe="$TEST_TMP_DIR/filter-ran"
  local output=''

  command git init -q "$repo" || return
  command git -C "$repo" config user.name 'Zsh Tests' || return
  command git -C "$repo" config user.email 'zsh-tests.invalid@example.invalid' || return
  test_write_file "$repo/.gitattributes" '*.txt filter=fixture' || return
  test_write_file "$repo/tracked.txt" 'baseline' || return
  command git -C "$repo" add .gitattributes tracked.txt || return
  command git -C "$repo" commit -qm baseline || return
  test_write_file "$filter" $'#!/bin/sh\n: > "$FILTER_PROBE"\n/bin/cat' || return
  command chmod +x "$filter" || return
  command git -C "$repo" config filter.fixture.smudge "$filter" || return
  command git -C "$repo" config filter.fixture.required true || return
  test_write_file "$repo/tracked.txt" 'changed' || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    export FILTER_PROBE=$2
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd -- "$3" || exit
    g --discard-all <<< y >/dev/null 2>&1
    discard_status=$?
    [[ -e $2 ]]; filter_ran=$(( !$? ))
    print -r -- "$discard_status|$filter_ran|$(<tracked.txt)"
  ' "$TEST_REPO_ROOT" "$probe" "$repo") || return

  test_assert_equal '0|0|baseline' "$output" \
    'g --discard-all executed a repository content filter'
}
test_case 'g --discard-all restores without repository filter execution' \
  _test_git_discard_all_disables_repository_filters

_test_git_discard_all_revalidates_after_confirmation() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repository" output='' exit_status=0

  command git init -q "$repo" || return
  command git -C "$repo" config user.name 'Zsh Tests' || return
  command git -C "$repo" config user.email 'zsh-tests.invalid@example.invalid' || return
  test_write_file "$repo/tracked.txt" 'baseline' || return
  command git -C "$repo" add tracked.txt || return
  command git -C "$repo" commit -qm baseline || return
  test_write_file "$repo/tracked.txt" 'changed' || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd -- "$2" || exit
    read() {
      [[ $* == *"answer?"* ]] && print -r -- late >| unpreviewed.txt
      builtin read "$@"
    }
    g --discard-all <<< y
  ' "$TEST_REPO_ROOT" "$repo" 2>&1) || exit_status=$?

  (( exit_status != 0 )) || {
    test_fail 'g --discard-all accepted changes introduced after its preview'
    return
  }
  [[ -f "$repo/unpreviewed.txt" && $(<"$repo/tracked.txt") == changed ]] || {
    test_fail 'g --discard-all modified the repository after revalidation failed'
    return
  }
  test_assert_contains "$output" 'changed after the preview' \
    'g --discard-all omitted its post-confirmation revalidation diagnostic'
}
test_case 'g --discard-all revalidates the preview before effects' \
  _test_git_discard_all_revalidates_after_confirmation

_test_git_discard_all_refuses_without_commit() {
  test_make_temp_dir || return
  local repo="$TEST_TMP_DIR/repository" output='' exit_status=0
  command mkdir -p "$repo" || return
  command git -C "$repo" init -q || return
  test_write_file "$repo/untracked.txt" 'keep me' || return

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    builtin cd "$2" || exit
    g --discard-all
  ' "$TEST_REPO_ROOT" "$repo" 2>&1) || exit_status=$?
  (( exit_status != 0 )) || {
    test_fail 'g --discard-all succeeded in a repository without a commit'
    return
  }
  test_assert_contains "$output" 'no commit to restore' \
    'missing no-commit refusal diagnostic' || return
  [[ -f "$repo/untracked.txt" ]] ||
    test_fail 'refused discard removed an untracked file'
}
test_case 'g --discard-all refuses repositories without a restorable commit' \
  _test_git_discard_all_refuses_without_commit

_test_prompt_refresh_invalidates_memory_only() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" $'
    typeset -gA _PROMPT_RUNTIME_VERSION_CACHE=(one value)
    typeset -gA _PROMPT_GIT_DIR_CACHE=(two value)
    typeset -gi _GREP_SUPPORTS_COLOR=1
    typeset -g _GREP_COLOR_BINARY=/usr/bin/grep
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.help"
    compozsh --refresh
    print -r -- "${#_PROMPT_RUNTIME_VERSION_CACHE}|${#_PROMPT_GIT_DIR_CACHE}|$_GREP_SUPPORTS_COLOR|${#_GREP_COLOR_BINARY}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '0|0|-1|0' "$output" \
    'compozsh --refresh did not invalidate all documented in-memory caches'
}
test_case 'compozsh --refresh clears runtime, Git, and output capability caches' \
  _test_prompt_refresh_invalidates_memory_only
