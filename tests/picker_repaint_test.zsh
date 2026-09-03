# Observe actual ZLE refreshes without printing frame markers into its screen.
# Zsh 5.9 repaints BEFORE calling TRAPWINCH, so a post-trap layout check alone
# misses stale wide rows wrapping/scrolling during fullscreen transitions.
# Terminal.app acceptance: open g after clear, alternate fullscreen/windowed
# repeatedly without typing, and verify one picker, stable selection, and clean
# cancellation. Kernel PTY resizes below cover ZLE, not the app's own reflow.
_test_picker_resize_automatic_paint() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    zmodload zsh/zpty
    zmodload zsh/zselect
    local prompt_mode=$2
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    # This vendor trap runs after Zsh has refreshed, before Compozsh lays out
    # its new frame. BUFFERLINES describes the screen actually just painted.
    if [[ $prompt_mode != standalone ]]; then
      TRAPWINCH() {
        (( _ZLE_PICKER_ACTIVE )) || return 0
        print -r -u $event_fd -- "AUTO:$COLUMNS:$LINES:$BUFFERLINES"
      }
      source "$1/.zsh.addons/.zsh.prompt"
    fi
    functions[_resize_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _resize_original_show
      (( BUFFERLINES == ${#_ZLE_PICKER_DISPLAY} + 3 )) || {
        print -r -u $event_fd -- "BAD-PAINT:$BUFFERLINES"
        return 1
      }
      print -r -u $event_fd -- "FRAME:$COLUMNS:$LINES:$_ZLE_PICKER_SELECTED:$BUFFERLINES:$collections"
    }
    _resize_collect() {
      (( ++collections ))
      _ZLE_PICKER_RESULTS=(first second third fourth fifth sixth)
      _ZLE_PICKER_LABELS=(feature/first feature/second feature/third feature/fourth feature/fifth feature/sixth)
      _ZLE_PICKER_RESULT_INDEXES=(0 1 2 3 4 5)
    }
    _resize_driver() {
      command stty rows 50 cols 180
      local -i collections=0
      local device=$(command tty)
      print -r -u $event_fd -- "TTY:$device"
      _ZLE_PICKER_COLLECTOR=_resize_collect
      _ZLE_PICKER_TITLE=Branches
      _ZLE_PICKER_INSPECT_TITLE=Branch
      _ZLE_PICKER_INSPECT_TEXTS=(first "$(print -rl -- detail-{01..40})" second "$(print -rl -- detail-{01..40})")
      _zle_picker_run 10
      (( $? == 1 && !_ZLE_PICKER_ACTIVE && !${#_ZLE_PICKER_RESULTS} )) || return 1
      if [[ $prompt_mode == standalone ]]; then
        (( ! ${+functions[TRAPWINCH]} )) || return 2
      fi
      print -r -u $event_fd -- DONE
    }
    _resize_event() {
      local chunk=""
      while zselect -r $event_fd $pty_fd -t 500; do
        while zpty -r repaint chunk; do
          trace+=$chunk
        done
        if IFS= read -r -t 0 -u $event_fd event; then
          return 0
        fi
      done
      print -u2 -r -- "timed out waiting for resize event; last=$event"
      return 1
    }
    local event="" trace="" device="" size="" pty_fd=0
    local -a dimensions
    zpty -b repaint _resize_driver || exit 3
    pty_fd=$REPLY
    {
      _resize_event || exit 4
      [[ $event == TTY:* ]] || exit 5
      device=${event#TTY:}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 6
      _resize_event || exit 7
      [[ $event == FRAME:180:50:1:49:1 ]] || exit 8
      zpty -w -n repaint $'\''\e[B'\''
      _resize_event || exit 9
      [[ $event == FRAME:180:50:2:49:1 ]] || exit 10
      # No keyboard input between these real kernel window-size changes.
      for size in 120:30 180:50 102:30 180:50 70:18 180:50 120:30; do
        dimensions=("${(@s.:.)size}")
        command stty cols $dimensions[1] rows $dimensions[2] < "$device" || exit 11
        _resize_event || exit 12
        # The automatic pre-trap refresh may paint the original edit line,
        # but must not repaint a picker with the old dimensions.
        if [[ $prompt_mode != standalone ]]; then
          [[ $event == AUTO:$size:1 ]] || {
            print -u2 -r -- "stale picker painted before resize handler: $event"
            exit 13
          }
          _resize_event || exit 14
        fi
        [[ $event == FRAME:$size:2:$(( dimensions[2] - 1 )):1 ]] || exit 15
      done
      zpty -w -n repaint $'\''\x07'\''
      _resize_event || exit 16
      [[ $event == DONE ]] || exit 17
      [[ $trace != *"read-only variable"* && $trace != *"PANEL-ERROR"* ]] || exit 18
      # A dedicated screen gives resize a safe repaint boundary. Clear only
      # that screen, never the restored main screen or the users scrollback.
      local enter=$terminfo[smcup] leave=$terminfo[rmcup]
      [[ -n $enter && -n $leave && $trace == *"$enter"*"$leave"* ]] || {
        print -u2 -r -- "picker did not enter and restore its alternate screen"
        exit 19
      }
      (( ${#trace} - ${#${trace//"$leave"/}} == ${#leave} )) || exit 20
      local before=${trace%%"$enter"*} after=${trace##*"$leave"}
      local screen=${${trace#*"$enter"}%%"$leave"*}
      [[ $before != *$'\''\e[2J'\''* && $after != *$'\''\e[2J'\''* &&
         $trace != *$'\''\e[3J'\''* && $screen != *"$enter"* &&
         $after != *"$leave"* ]] || exit 20
      # One clear on entry plus one for each of the seven real resizes.
      local without_clears=${screen//$'\''\e[2J'\''/}
      (( ${#screen} - ${#without_clears} == 8 * 4 )) || {
        print -u2 -- "expected eight alternate-screen clears"
        exit 21
      }
    } always {
      zpty -d repaint
      exec {event_fd}>&-
    }
    print clean-resize
  ' "$TEST_REPO_ROOT" "${1:-prompt}") || return
  test_assert_equal clean-resize "$output"
}
test_case 'picker resize never automatically paints stale geometry before its handler' _test_picker_resize_automatic_paint

_test_picker_resize_without_prompt() {
  _test_picker_resize_automatic_paint standalone
}
test_case 'standalone editor scopes its picker resize handler and restores it on exit' _test_picker_resize_without_prompt
