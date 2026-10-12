# Terminal-aware native output and palette contracts.

_test_output_palette_drives_native_git_colors() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    typeset -gA ZSH_OUTPUT_COLORS=(success 123)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    _output_git_color_arguments
    print -r -- "palette:${ZSH_OUTPUT_COLORS[success]}|${ZSH_OUTPUT_COLORS[error]}|${ZSH_OUTPUT_COLORS[match]}"
    print -r -- "wrapper:${+functions[git]}"
    print -r -- "added:${_OUTPUT_GIT_COLOR_CONFIG[(r)color.status.added=*]}"
    print -r -- "removed:${_OUTPUT_GIT_COLOR_CONFIG[(r)color.diff.old=*]}"
    print -r -- "branch:${_OUTPUT_GIT_COLOR_CONFIG[(r)color.branch.current=*]}"
    _output_git_subcommand_uses_color commit
    print -r -- "commit:$?"
    _output_git_subcommand_uses_color clone
    print -r -- "clone:$?"
    _output_git_subcommand_uses_color config || print -r -- "config:$?"
  ' "$TEST_REPO_ROOT") || return

  test_assert_contains "$output" 'palette:123|203|199' \
    'output palette replaced a local role or omitted defaults' || return
  test_assert_contains "$output" 'wrapper:1' \
    'Git output wrapper is unavailable' || return
  test_assert_contains "$output" 'added:color.status.added=bold 123' \
    'Git added status does not use the shared success role' || return
  test_assert_contains "$output" 'removed:color.diff.old=203' \
    'Git removed lines do not use the shared error role' || return
  test_assert_contains "$output" 'branch:color.branch.current=bold 123' \
    'Git current branch does not use the shared success role' || return
  test_assert_contains "$output" 'commit:0' \
    'Git commit is missing native color configuration' || return
  test_assert_contains "$output" 'clone:0' \
    'Git clone is missing native color configuration' || return
  test_assert_contains "$output" 'config:1' \
    'Git configuration inspection was incorrectly decorated'
}
test_case 'native Git colors use the customizable semantic output palette' \
  _test_output_palette_drives_native_git_colors

_test_git_wrapper_preserves_plain_delegation_and_status() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/git" $'#!/bin/zsh\nprint -r -- "${(j:|:)@}"\n[[ ${@: -1} == fail ]] && exit 23\nexit 0' || return
  command chmod +x "$fake_bin/git" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    path=("$2" $path)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    git -C /tmp/example status --short
    git status fail
    print -r -- "status:$?"
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_contains "$output" '-C|/tmp/example|status|--short' \
    'non-terminal Git output did not preserve the original argv' || return
  test_assert_contains "$output" 'status|fail' \
    'Git wrapper did not delegate the failing invocation' || return
  test_assert_contains "$output" 'status:23' \
    'Git wrapper did not preserve the underlying exit status'
}
test_case 'Git wrapper leaves non-terminal output byte-compatible' \
  _test_git_wrapper_preserves_plain_delegation_and_status

# Real Git under a PTY: the user's color.ui/color.<command> decides whether Git
# colors, and a piped stdout gets native bytes even while stderr is a terminal.
_test_git_wrapper_defers_color_enablement_to_git() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    source "$1/tests/pty_support.zsh" || exit 1
    export GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL="$HOME/user.gitconfig"
    local esc="" cr="" nl=""
    printf -v esc "\033"; printf -v cr "\r"; printf -v nl "\n"
    : > "$GIT_CONFIG_GLOBAL" || exit 2
    mkdir -p "$HOME/repo" && cd "$HOME/repo" || exit 2
    command git -c init.defaultBranch=main init -q || exit 2
    print -r -- before > file && command git add file || exit 2
    command git -c user.name=Fixture -c user.email=fixture@example.invalid \
      -c commit.gpgsign=false commit -qm initial || exit 2
    print -r -- after > file
    _git_color_fixture() {
      print -r -- BEGIN-WRAPPER-TTY; git --no-pager diff
      print -r -- BEGIN-NATIVE-TTY; command git --no-pager diff
      print -r -- BEGIN-WRAPPER-PIPE; git --no-pager diff | cat
      print -r -- BEGIN-NATIVE-PIPE; command git --no-pager diff | cat
      print -r -- END-GIT-COLOR
    }
    _git_color_capture() {
      local captured=""
      test_pty_start git-color _git_color_fixture || return 1
      {
        test_pty_expect git-color "" END-GIT-COLOR
        captured=$TEST_PTY_OUTPUT
        [[ $captured == *END-GIT-COLOR* ]] || return 1
        captured=${captured//$cr/}
        reply=(
          "${${captured#*BEGIN-WRAPPER-TTY$nl}%%BEGIN-NATIVE-TTY*}"
          "${${captured#*BEGIN-NATIVE-TTY$nl}%%BEGIN-WRAPPER-PIPE*}"
          "${${captured#*BEGIN-WRAPPER-PIPE$nl}%%BEGIN-NATIVE-PIPE*}"
          "${${captured#*BEGIN-NATIVE-PIPE$nl}%%END-GIT-COLOR*}"
        )
      } always {
        zpty -d git-color
      }
    }
    _git_color_state() {
      if [[ $1 == *"${esc}[38;5;"* ]]; then
        REPLY=palette
      elif [[ $1 == *"${esc}["* ]]; then
        REPLY=color
      else
        REPLY=plain
      fi
    }
    local mode="" key="" value="" wrapper_tty="" native_tty="" native_pipe="" pipe=""
    for mode key value in empty "" "" never color.ui never \
      always color.ui always diff-always color.diff always; do
      : > "$GIT_CONFIG_GLOBAL" || exit 3
      [[ -z $key ]] || command git config --file "$GIT_CONFIG_GLOBAL" "$key" "$value" || exit 3
      _git_color_capture || exit 4
      [[ ${reply[2]} == *"diff --git"* && ${reply[4]} == *"diff --git"* ]] || exit 5
      _git_color_state "${reply[1]}"; wrapper_tty=$REPLY
      _git_color_state "${reply[2]}"; native_tty=$REPLY
      _git_color_state "${reply[4]}"; native_pipe=$REPLY
      pipe=different
      [[ ${reply[3]} == "${reply[4]}" ]] && pipe=same
      print -r -- "$mode|tty $wrapper_tty/$native_tty|pipe $native_pipe $pipe"
    done
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal 'empty|tty palette/color|pipe plain same
never|tty plain/plain|pipe plain same
always|tty palette/color|pipe color same
diff-always|tty palette/color|pipe color same' "$output" \
    'Git wrapper overrode the user color configuration or changed piped bytes'
}
test_case 'Git wrapper defers color enablement to the user Git configuration and keeps pipes byte-compatible' \
  _test_git_wrapper_defers_color_enablement_to_git

_test_man_uses_semantic_output_palette() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/man" $'#!/bin/zsh
typeset -i heading=0 warning=0 match=0 selected=0
[[ $LESS_TERMCAP_md == $'"'"'\e[1;38;5;123m'"'"' ]] && heading=1
[[ $LESS_TERMCAP_us == $'"'"'\e[4;38;5;124m'"'"' ]] && warning=1
[[ $LESS_TERMCAP_mb == $'"'"'\e[1;38;5;125m'"'"' ]] && match=1
[[ $LESS_TERMCAP_so == $'"'"'\e[1;38;5;16;48;5;123m'"'"' ]] && selected=1
print -r -- "$heading|$warning|$match|$selected|${(j:|:)@}"' || return
  command chmod +x "$fake_bin/man" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    path=("$2" $path)
    typeset -gA ZSH_OUTPUT_COLORS=(heading 123 warning 124 match 125)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    man git-status
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_equal '1|1|1|1|git-status' "$output" \
    'manual-page styles did not use the semantic output palette'
}
test_case 'manual-page styling shares the semantic output palette' \
  _test_man_uses_semantic_output_palette

# Native man chooses its pager from MANPAGER, then MANCOLOR (less -sR), then
# PAGER, then less -s. The wrapper adds styles only and never picks a pager.
_test_man_wrapper_keeps_native_pager_precedence() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/man" $'#!/bin/zsh\nprint -r -- "MANPAGER=${MANPAGER-<unset>}|MANCOLOR=${MANCOLOR-<unset>}|PAGER=${PAGER-<unset>}|${1-}"' || return
  command chmod +x "$fake_bin/man" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    path=("$2" $path)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    export PAGER=most
    unset MANPAGER MANCOLOR
    man ls
    export MANPAGER=custom; man ls; unset MANPAGER
    export MANCOLOR=1; man ls
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_equal 'MANPAGER=<unset>|MANCOLOR=<unset>|PAGER=most|ls
MANPAGER=custom|MANCOLOR=<unset>|PAGER=most|ls
MANPAGER=<unset>|MANCOLOR=1|PAGER=most|ls' "$output" \
    'man wrapper replaced the native pager choice'
}
test_case 'man wrapper keeps the native pager precedence' \
  _test_man_wrapper_keeps_native_pager_precedence

# The palette and its plain text-attribute defaults stay out of the
# environment under NO_COLOR or without 256 colors; explicit values still pass.
_test_man_palette_honors_no_color_and_terminal_colors() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output=''
  test_write_file "$fake_bin/man" $'#!/bin/zsh\ntypeset name=\'\'\ntypeset -a styles=()\nfor name in mb md me so se us ue; do\n  (( ${+parameters[LESS_TERMCAP_$name]} )) && styles+=("$name=${(V)${(P)${:-LESS_TERMCAP_$name}}}")\ndone\nprint -r -- "${#styles}:${(j:,:)styles}"' || return
  command chmod +x "$fake_bin/man" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    path=("$2" $path)
    typeset -gA ZSH_OUTPUT_COLORS=(heading 123)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    local mode=""
    for mode in default no-color limited unsupported no-color-explicit; do
      TERM=xterm-256color
      unset NO_COLOR LESS_TERMCAP_md
      case $mode in
        no-color) export NO_COLOR=1 ;;
        limited) TERM=xterm ;;
        unsupported) TERM=dumb ;;
        no-color-explicit) export NO_COLOR=1 LESS_TERMCAP_md=custom ;;
      esac
      print -r -- "$mode|$(man example)"
    done
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  test_assert_equal 'default|7:mb=^[[1;38;5;199m,md=^[[1;38;5;123m,me=^[[0m,so=^[[1;38;5;16;48;5;123m,se=^[[0m,us=^[[4;38;5;221m,ue=^[[0m
no-color|0:
limited|0:
unsupported|0:
no-color-explicit|1:md=custom' "$output" \
    'man palette ignored NO_COLOR or the terminal color count'
}
test_case 'man palette stays plain under NO_COLOR or without 256 colors' \
  _test_man_palette_honors_no_color_and_terminal_colors

# Real grep under a PTY: matches use the palette only on a 256-color terminal
# without NO_COLOR; otherwise grep runs with the exact argv and exit status.
_test_grep_wrapper_honors_no_color_and_terminal_colors() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    typeset -gA ZSH_OUTPUT_COLORS=(match 125)
    source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"
    source "$1/tests/pty_support.zsh" || exit 1
    local esc="" cr="" nl="" haystack="$HOME/haystack" mode="" trace="" state=""
    local -a states=()
    printf -v esc "\033"; printf -v cr "\r"; printf -v nl "\n"
    print -r -- "needle in haystack" > "$haystack" || exit 2
    _grep_color_fixture() {
      print -r -- BEGIN-TTY; grep needle "$haystack"
      print -r -- BEGIN-PIPE; grep needle "$haystack" | cat
      grep absent "$haystack"
      print -r -- "END-GREP-COLOR:$?"
    }
    for mode in default no-color limited unsupported; do
      TERM=xterm-256color
      unset NO_COLOR
      case $mode in
        no-color) export NO_COLOR=1 ;;
        limited) TERM=xterm ;;
        unsupported) TERM=dumb ;;
      esac
      test_pty_start grep-color _grep_color_fixture || exit 3
      {
        test_pty_expect grep-color "" END-GREP-COLOR || exit 4
        trace=${TEST_PTY_OUTPUT//$cr/}
      } always {
        zpty -d grep-color
      }
      states=()
      for state in "${${trace#*BEGIN-TTY$nl}%%BEGIN-PIPE*}" \
        "${${trace#*BEGIN-PIPE$nl}%%END-GREP-COLOR*}"; do
        if [[ $state == *"${esc}[1;38;5;125m"*needle* ]]; then
          states+=(palette)
        elif [[ $state == *"${esc}["* ]]; then
          states+=(color)
        elif [[ $state == "needle in haystack$nl" ]]; then
          states+=(plain)
        else
          states+=(missing)
        fi
      done
      [[ $trace == *END-GREP-COLOR:1* ]] && states+=(status-1)
      print -r -- "$mode|${(j:|:)states}"
    done
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal 'default|palette|plain|status-1
no-color|plain|plain|status-1
limited|plain|plain|status-1
unsupported|plain|plain|status-1' "$output" \
    'grep wrapper colored matches under NO_COLOR or without 256 colors'
}
test_case 'grep wrapper adds no color under NO_COLOR or without 256 colors' \
  _test_grep_wrapper_honors_no_color_and_terminal_colors

# A same-name alias would expand in a wrapper definition and abort the peer.
_test_output_loads_after_wrapper_aliases() {
  test_make_temp_dir || return
  local fake_bin="$TEST_TMP_DIR/bin" output='' exit_status=0
  test_write_file "$fake_bin/man" $'#!/bin/zsh\nprint -r -- "manual:$*"' || return
  command chmod +x "$fake_bin/man" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2" $path)
    alias git="print aliased-git" grep="print aliased-grep" man="print aliased-man"
    source "$1/.zsh.addons/.zsh.output"
    print -r -- "load:$?"
    print -r -- "git:${+functions[git]}${+aliases[git]} grep:${+functions[grep]}${+aliases[grep]} man:${+functions[man]}${+aliases[man]}"
    man fixture-page
  ' "$TEST_REPO_ROOT" "$fake_bin" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
load:0
git:10 grep:10 man:10
manual:fixture-page' "status:$exit_status"$'\n'"$output" \
    'a same-name alias aborted the output peer'
}
test_case 'output peer loads after same-name aliases of git grep and man' \
  _test_output_loads_after_wrapper_aliases

_test_output_palette_matches_prompt_semantics() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"; print -r -- "${ZSH_OUTPUT_COLORS[success]}|${ZSH_OUTPUT_COLORS[warning]}|${ZSH_OUTPUT_COLORS[error]}|${ZSH_OUTPUT_COLORS[match]}"' "$TEST_REPO_ROOT") || return
  test_assert_equal '71|221|203|199' "$output" \
    'output palette diverged from the established semantic colors'
}
test_case 'output palette follows established prompt semantics' \
  _test_output_palette_matches_prompt_semantics

_test_output_palette_rejects_malformed_indexes() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" $'
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
source "$1/.zsh.addons/support/.zsh.appearance"; source "$1/.zsh.addons/.zsh.output"; ZSH_OUTPUT_COLORS[success]=999999999999999999999999999999999999; _compozsh_palette_color output success 71; print -r -- "fallback:$REPLY"' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal 'fallback:71' "$output" \
    'malformed output color escaped validation or emitted a diagnostic'
}
test_case 'output palette rejects malformed color indexes safely' \
  _test_output_palette_rejects_malformed_indexes
