# Arbitrary pasted directory-stack numbers remain literal until safely bounded.
_test_highlighting_stack_bounds() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.highlighting"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    source "$1/.zsh.addons/support/.zsh.appearance"
    command mkdir -p "$HOME/current" "$HOME/previous"
    builtin cd "$HOME/current"
    dirstack=("$HOME/previous")
    local word="" zeros=${(l:40::0:):-}
    for word in "~999999999999999999999999999999999999999999" \
        "~18446744073709551615" "~18446744073709551616" "~2"; do
      _zle_path_category "$word" 2> "$HOME/diagnostics"
      [[ $? == 1 && -z $REPLY && ! -s "$HOME/diagnostics" ]] || {
        print -u2 -- "out-of-range stack index emitted diagnostics or resolved a path"; exit 1
      }
      BUFFER="print $word" region_highlight=()
      _zle_syntax_highlight 2> "$HOME/diagnostics"
      [[ ! -s "$HOME/diagnostics" ]] || exit 2
    done
    for word in "~0" "~1" "~${zeros}" "~${zeros}1" "~${zeros}1/"; do
      _zle_path_category "$word" 2> "$HOME/diagnostics"
      [[ $? == 0 && $REPLY == directory && ! -s "$HOME/diagnostics" ]] || {
        print -u2 -- "valid decimal stack index lost its directory classification"; exit 3
      }
    done
    print bounded
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded "$output"
}
test_case 'syntax highlighting bounds directory-stack numbers before arithmetic and preserves leading zeros' \
  _test_highlighting_stack_bounds

_test_highlighting_stack_bounds_native() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.highlighting"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    source "$1/tests/pty_support.zsh" || exit 7
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    local pasted="print ~999999999999999999999999999999999999999999"
    _bounds_probe() {
      _zle_syntax_highlight 2> "$HOME/diagnostics"
      zle -R
      [[ $BUFFER == "$pasted" && ! -s "$HOME/diagnostics" ]] || {
        print -r -u $event_fd -- BAD-PAINT; return
      }
      print -r -u $event_fd -- PAINTED
    }
    zle -N bounds-probe _bounds_probe
    _bounds_editor() {
      local draft=$pasted
      command stty rows 24 cols 100
      vared -i bounds-probe draft
      local -i result=$?
      [[ $result == 0 && $draft == "$pasted" && ! -s "$HOME/diagnostics" ]] || {
        print -r -u $event_fd -- BAD-EDITOR; return
      }
      print -r -u $event_fd -- DONE
    }
    _bounds_event() {
      test_pty_expect bounds $event_fd "$1" && return
      print -u2 -- "native highlighting expected $1; diagnostics $(<"$HOME/diagnostics")"
      return 1
    }
    test_pty_start bounds _bounds_editor || exit 3
    {
      _bounds_event PAINTED || exit 5
      zpty -w -n bounds $'\''\r'\''
      _bounds_event DONE || exit 6
    } always {
      zpty -d bounds
      exec {event_fd}>&-
    }
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'syntax highlighting preserves a native editable buffer with oversized stack numbers' \
  _test_highlighting_stack_bounds_native

# Command, global-alias and named-directory lookups resolve the exact key,
# including names that look like subscript flags, patterns or brackets.
_test_highlighting_lookup_kinds() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.highlighting"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    # A runtime global alias would expand in later lines of this script, so
    # its name never appears literally here.
    local global_name=lookup odd_function="f]" name=""
    global_name+=global
    alias lookup-alias="print alias" "@=print at" "x]y=print odd"
    alias -g "$global_name"=value
    alias -s txt=cat
    lookup-function() { :; }
    functions[$odd_function]=":"
    for name in lookup-alias "$global_name" if lookup-function print ls \
        notes.txt "@" "x]y" "$odd_function" "*" "" "(i)a" "(Ie)ls"; do
      _zle_command_category "$name"
      print -rn -- "$?:$REPLY|"
    done
    command mkdir -p "$HOME/p/sub"
    hash -d proj="$HOME/p"
    _zle_path_category "~proj/sub"; print -rn -- "$?:$REPLY|"
    _zle_path_category "~missing/sub"; print -rn -- "$?:$REPLY|"
    typeset -gA ZSH_HIGHLIGHT_STYLES=(global-alias fg=201)
    BUFFER="print $global_name" region_highlight=()
    _zle_syntax_highlight
    print -r -- "${(j:,:)region_highlight}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal \
    '0:alias|0:global-alias|0:keyword|0:function|0:builtin|0:command|0:suffix-alias|0:alias|0:alias|0:function|1:|1:|1:|1:|0:directory|1:|6 18 fg=201 memo=compozsh' \
    "$output" 'command, global-alias or named-directory lookup changed'
}
test_case 'syntax highlighting command, global-alias and named-directory lookups classify every kind and odd name identically' \
  _test_highlighting_lookup_kinds

# Every redraw classifies words, so shell tables (about 1,700 functions with
# completion loaded, more than 1,000 commands) are looked up by exact key and
# never scanned through a reverse subscript.
_test_highlighting_lookups_scan_no_shell_table() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local source='' line=''
  local -a scans=()
  source=$(<"$TEST_REPO_ROOT/.zsh.addons/.zsh.highlighting") || return
  for line in "${(@f)source}"; do
    [[ $line == *(aliases|functions|builtins|commands|nameddirs)\[\([^\)]#[iIrR]* ]] &&
      scans+=("${line##[[:space:]]#}")
  done
  (( ! $#scans )) ||
    test_fail "the highlighter scans shell tables on redraw: ${(j: ; :)scans}"
}
test_case 'syntax highlighting looks up shell tables by key instead of scanning them' \
  _test_highlighting_lookups_scan_no_shell_table
