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
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
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

# A real resize can land while a frame is still being laid out or painted;
# ZLE's resize redraw then runs inside that frame and paints the new size
# before the outer frame resumes. Each arm issues the kernel window change at
# one point: in the browse callback during layout, or at the zle -R of a
# composed frame: the input loop's, capture status before its work, and paste
# recovery before its wait. Only a frame laid out for the current size may stay
# painted: one row width, a location trail only where it fits, and BUFFERLINES
# for one unwrapped screen.
_test_picker_resize_mid_frame() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    local arm=$2
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 1
    exec {event_fd}<> "$HOME/events" || exit 2
    functions[_layout_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _layout_original_show
      local row="" trail=0
      local -A widths=()
      for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
        [[ -n $row ]] && widths[${(m)#row}]=1
        [[ $row == Location* ]] && trail=1
      done
      # BUFFERLINES counts painted screen rows, so a row wider than the
      # terminal shows up as wrapping rather than only as layout data.
      print -r -u $event_fd -- "FRAME:${COLUMNS}:${(j:,:)${(@on)${(@k)widths}}}:${trail}:${_ZLE_PICKER_SELECTED}:${BUFFERLINES}"
    }
    _layout_resize() {
      [[ -e $HOME/resize-now ]] || return 0
      command rm -f -- "$HOME/resize-now"
      command stty cols 100 < "$device"
    }
    _layout_browse() {
      [[ $arm == layout ]] && _layout_resize
      REPLY=Browse
    }
    # Show asks ZLE to paint only after composing its whole frame.
    if [[ $arm != layout ]]; then
      zle() {
        [[ $# == 1 && $1 == -R ]] && _layout_resize
        builtin zle "$@"
      }
    fi
    _layout_collect() {
      _ZLE_PICKER_RESULTS=(alpha beta) _ZLE_PICKER_LABELS=(alpha/ beta/)
      _ZLE_PICKER_RESULT_INDEXES=(0 1)
    }
    _layout_capture() {
      : > "$HOME/resize-now"
      _zle_picker_capture Files "Search · ~" "" _layout_captured
    }
    _layout_captured() { print -r -u $event_fd -- "CAPTURED:$COLUMNS"; }
    _layout_driver() {
      command stty rows 20 cols 140
      local device=$(command tty)
      print -r -u $event_fd -- "TTY:$device"
      _ZLE_PICKER_COLLECTOR=_layout_collect
      _ZLE_PICKER_TITLE="Directory browser"
      _ZLE_PICKER_BROWSE_RENDERER=_layout_browse
      _ZLE_PICKER_TRAIL=(Location "~" "  Projects")
      _ZLE_PICKER_INSPECT_TEXTS=(alpha "Inside alpha" beta "Inside beta")
      if [[ $arm == capture ]]; then
        _zle_picker_run 10 "" 1 0 _layout_capture
      else
        _zle_picker_run 10
      fi
      print -r -u $event_fd -- "DONE:$?"
    }
    # Collect every event until the picker is quiet (half a second without a
    # new one); the last frame is the one left on the screen.
    _layout_settle() {
      local chunk=""
      local -i timeout=500
      event=""
      while zselect -r $event_fd $pty_fd -t $timeout; do
        while zpty -r layout chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd line; then
          event=$line timeout=50 events+=("$line")
          [[ $event == DONE:* ]] && break
        fi
      done
      [[ -n $event ]]
    }
    local event="" line="" trace="" pty_fd=0
    local -a events=()
    # Status frames as ZLE paints them directly at 100 columns. Capture keeps
    # the docked workspace height; the paste recovery status view is compact.
    local status_frame=FRAME:100:99:0:0:19
    [[ $arm == paste ]] && status_frame=FRAME:100:99:0:0:8
    zpty -b layout _layout_driver || exit 3
    pty_fd=$REPLY
    {
      zselect -r $event_fd -t 500 && IFS= read -r -u $event_fd event || exit 4
      [[ $event == TTY:/dev/(ttys|pts/)<-> ]] || exit 5
      _layout_settle || exit 6
      if [[ $arm == capture ]]; then
        # The capture work runs while its status frame stays on screen.
        [[ ${(j: :)events[-3,-1]} == "$status_frame CAPTURED:100 DONE:0" ]] || {
          print -u2 -r -- "resize during capture status left a stale frame: ${(j: :)events}"
          exit 7
        }
      else
        [[ $event == FRAME:140:139:1:1:19 ]] || { print -u2 -r -- "first frame: $event"; exit 7; }
        zpty -w -n layout $'\''\e[B'\''
        _layout_settle || exit 8
        [[ $event == FRAME:140:139:1:2:19 ]] || { print -u2 -r -- "selection frame: $event"; exit 9; }
        : > "$HOME/resize-now"
        events=()
        if [[ $arm == paste ]]; then
          # An unterminated paste times out after one second into recovery,
          # which waits for the closing marker before the picker resumes.
          zpty -w -n layout $'\''\e[200~x'\''
          _layout_settle || exit 10
          [[ $event == "$status_frame" ]] || {
            print -u2 -r -- "resize during paste recovery left a stale frame: ${(j: :)events}"
            exit 11
          }
          zpty -w -n layout $'\''\e[201~'\''
          _layout_settle || exit 15
          [[ $event == FRAME:100:99:0:2:19 ]] || { print -u2 -r -- "recovered frame: $event"; exit 16; }
        else
          zpty -w -n layout $'\''\e[A'\''
          _layout_settle || exit 10
          [[ $event == FRAME:100:99:0:1:19 ]] || {
            print -u2 -r -- "resize during $arm left a stale frame: ${(j: :)events}"
            exit 11
          }
        fi
        zpty -w -n layout $'\''\x07'\''
        _layout_settle || exit 12
        [[ $event == DONE:1 ]] || exit 13
      fi
      [[ $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 14
    } always {
      zpty -d layout
      exec {event_fd}>&-
    }
    print current-geometry
  ' "$TEST_REPO_ROOT" "$1") || return
  test_assert_equal current-geometry "$output"
}
_test_picker_resize_during_layout() { _test_picker_resize_mid_frame layout; }
test_case 'picker resize during frame layout leaves only current geometry painted' _test_picker_resize_during_layout
_test_picker_resize_during_paint() { _test_picker_resize_mid_frame paint; }
test_case 'picker resize during frame paint leaves only current geometry painted' _test_picker_resize_during_paint
_test_picker_resize_during_capture() { _test_picker_resize_mid_frame capture; }
test_case 'picker resize during capture status paint leaves only current geometry painted' _test_picker_resize_during_capture
_test_picker_resize_during_paste_recovery() { _test_picker_resize_mid_frame paste; }
test_case 'picker resize during paste recovery paint leaves only current geometry painted' _test_picker_resize_during_paste_recovery
