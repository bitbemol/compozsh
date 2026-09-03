# Arbitrary pasted directory-stack numbers remain literal until safely bounded.
_test_highlighting_stack_bounds() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.highlighting"
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
    zmodload zsh/zpty
    zmodload zsh/zselect
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
    local event="" chunk="" trace="" pty_fd=0
    _bounds_event() {
      while zselect -r $event_fd $pty_fd -t 300; do
        while zpty -r bounds chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          [[ $event == "$1" ]] && return 0
          [[ $event == BAD-* ]] && return 1
        fi
      done
      print -u2 -- "native highlighting expected $1; last event $event; diagnostics $(<"$HOME/diagnostics")"
      return 1
    }
    zpty -b bounds _bounds_editor || exit 3
    pty_fd=$REPLY
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
