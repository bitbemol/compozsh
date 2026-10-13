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
    source "$1/tests/pty_support.zsh" || exit 22
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
      {
        test_pty_expect -p repaint $event_fd "" || return
        event=$REPLY
      } always { trace+=$TEST_PTY_OUTPUT }
    }
    local event="" trace="" device="" size=""
    local -a dimensions
    test_pty_start repaint _resize_driver || exit 3
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
    source "$1/tests/pty_support.zsh" || exit 22
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
      local -i terminal_fd=0
      print -r -u $event_fd -- "TTY:$device"
      # The picker and paste recovery rest in a blocking key read, with no
      # terminal input left, once their frame is final. Report each rest with
      # the width it painted for. Poll the terminal itself, because standard
      # input is not the terminal inside the picker widget, and collect into
      # a local array so the picker keeps its own reply.
      exec {terminal_fd}< "$device" || return
      read() {
        local -a ready=()
        [[ $# == 4 && $1 == -r && $2 == -k ]] && ! zselect -a ready -t 0 -r $terminal_fd &&
          print -r -u $event_fd -- "IDLE:$COLUMNS"
        builtin read "$@"
      }
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
    # Collect every event until the wanted rest or finish (an extended glob
    # such as IDLE:100 or DONE:<->); resting at another width or finishing
    # early fails at once, and only a missing rest waits for the deadline.
    # The last event before the rest is the frame left on the screen.
    _layout_settle() {
      local -a seen=()
      { test_pty_expect -g -s "IDLE:*|DONE:*" layout $event_fd "$1" } always {
        trace+=$TEST_PTY_OUTPUT
      }
      local -i found=$?
      seen=("${(@)TEST_PTY_EVENTS:#IDLE:*}")
      events+=("${seen[@]}")
      event=${seen[-1]-}
      (( found == 0 )) && [[ -n $event ]]
    }
    local event="" trace=""
    local -a events=()
    # Status frames as ZLE paints them directly at 100 columns. Capture keeps
    # the docked workspace height; the paste recovery status view is compact.
    local status_frame=FRAME:100:99:0:0:19
    [[ $arm == paste ]] && status_frame=FRAME:100:99:0:0:8
    test_pty_start layout _layout_driver || exit 3
    {
      test_pty_expect -p layout $event_fd TTY: || exit 4
      event=$REPLY
      [[ $event == TTY:/dev/(ttys|pts/)<-> ]] || exit 5
      if [[ $arm == capture ]]; then
        _layout_settle "DONE:<->" || exit 6
        # The capture work runs while its status frame stays on screen.
        [[ ${(j: :)events[-3,-1]} == "$status_frame CAPTURED:100 DONE:0" ]] || {
          print -u2 -r -- "resize during capture status left a stale frame: ${(j: :)events}"
          exit 7
        }
      else
        _layout_settle IDLE:140 || exit 6
        [[ $event == FRAME:140:139:1:1:19 ]] || { print -u2 -r -- "first frame: $event"; exit 7; }
        zpty -w -n layout $'\''\e[B'\''
        _layout_settle IDLE:140 || exit 8
        [[ $event == FRAME:140:139:1:2:19 ]] || { print -u2 -r -- "selection frame: $event"; exit 9; }
        : > "$HOME/resize-now"
        events=()
        if [[ $arm == paste ]]; then
          # An unterminated paste times out after one second into recovery,
          # which waits for the closing marker before the picker resumes.
          zpty -w -n layout $'\''\e[200~x'\''
          _layout_settle IDLE:100 || exit 10
          [[ $event == "$status_frame" ]] || {
            print -u2 -r -- "resize during paste recovery left a stale frame: ${(j: :)events}"
            exit 11
          }
          zpty -w -n layout $'\''\e[201~'\''
          _layout_settle IDLE:100 || exit 15
          [[ $event == FRAME:100:99:0:2:19 ]] || { print -u2 -r -- "recovered frame: $event"; exit 16; }
        else
          zpty -w -n layout $'\''\e[A'\''
          _layout_settle IDLE:100 || exit 10
          [[ $event == FRAME:100:99:0:1:19 ]] || {
            print -u2 -r -- "resize during $arm left a stale frame: ${(j: :)events}"
            exit 11
          }
        fi
        zpty -w -n layout $'\''\x07'\''
        _layout_settle "DONE:<->" || exit 12
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

# The input loop waits in `IFS= read`, and a real resize repaints from inside
# that read, so the frame painted there sees an empty IFS. Span lists split on
# their own separator: that paint matches the ordinary one, and a document
# rewrapped there caches every syntax token for later paints at that width.
_test_picker_repaint_empty_ifs_spans() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    local -a painted=() ordinary=()
    zle() { painted=("${region_highlight[@]}"); }
    BUFFER="" PREDISPLAY="" POSTDISPLAY="" region_highlight=()
    ZSH_HIGHLIGHT_STYLES=(
      picker-row "fg=250"
      picker-size "fg=141" picker-error "fg=142"
      review-keyword "fg=143" review-string "fg=144"
    )
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=doc
    _ZLE_PICKER_DOCUMENT_LINES=(abcdefghij) _ZLE_PICKER_DOCUMENT_ROLES=(text)
    _ZLE_PICKER_DOCUMENT_SYNTAX=(1 "0:3:keyword 5:9:string")
    _ZLE_PICKER_INSPECT_TEXTS=(doc ready)
    IFS= _zle_picker_inspect_prepare doc 40
    [[ $_ZLE_PICKER_INSPECT_SYNTAX[1] == "0:3:keyword 5:9:string " ]] || {
      print -u2 -r -- "empty-IFS rewrap cached ${(q+)_ZLE_PICKER_INSPECT_SYNTAX[1]}"; exit 1
    }
    _ZLE_PICKER_DISPLAY=(abcdefghij) _ZLE_PICKER_DISPLAY_STYLES=(picker-row)
    _ZLE_PICKER_DISPLAY_LEFT_ENDS=(0) _ZLE_PICKER_DISPLAY_RIGHT_SYNTAX=("0:3:keyword 5:9:string ")
    _zle_picker_show || exit 2
    ordinary=("${painted[@]}")
    [[ -n ${(M)ordinary:#*fg=143*} && -n ${(M)ordinary:#*fg=144*} ]] || {
      print -u2 -r -- "ordinary syntax paint: ${(j:|:)ordinary}"; exit 3
    }
    IFS= _zle_picker_show || exit 4
    [[ ${(j:|:)painted} == "${(j:|:)ordinary}" ]] || {
      print -u2 -r -- "empty-IFS syntax paint: ${(j:|:)painted}"; exit 5
    }
    _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_DISPLAY=("alpha 12 KB 3 MB")
    _ZLE_PICKER_DISPLAY_LEFT_ENDS=() _ZLE_PICKER_DISPLAY_RIGHT_SYNTAX=()
    _ZLE_PICKER_DISPLAY_HIGHLIGHTS=("6:11:picker-size 12:16:picker-error")
    _zle_picker_show || exit 6
    ordinary=("${painted[@]}")
    [[ -n ${(M)ordinary:#*fg=141*} && -n ${(M)ordinary:#*fg=142*} ]] || {
      print -u2 -r -- "ordinary label paint: ${(j:|:)ordinary}"; exit 7
    }
    IFS= _zle_picker_show || exit 8
    [[ ${(j:|:)painted} == "${(j:|:)ordinary}" ]] || {
      print -u2 -r -- "empty-IFS label paint: ${(j:|:)painted}"; exit 9
    }
    print spans-kept
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal spans-kept "$output"
}
test_case 'picker repaint during the input reader empty IFS keeps label and syntax spans' \
  _test_picker_repaint_empty_ifs_spans

# The same journey through a real kernel resize: the reader waits for a key,
# the resize rewraps and repaints a highlighted document for the new width,
# and the next key paints from that cached wrap. Every frame must pair each
# keyword with its string and cache both tokens of the first source row.
_test_picker_resize_reader_keeps_syntax_spans() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/tests/pty_support.zsh" || exit 11
    command mkfifo "$HOME/events" || exit 1
    exec {efd}<> "$HOME/events" || exit 2
    typeset -gA ZSH_HIGHLIGHT_STYLES=(review-keyword fg=143 review-string fg=144)
    local event="" trace="" terminal=""
    # Stand in for a published Git syntax result on every captured row.
    functions[_syntax_original_collect]=$functions[_zle_ui_text_collect]
    _zle_ui_text_collect() {
      _syntax_original_collect "$@" || return
      local -i row=0
      for (( row = 1; row <= ${#_ZLE_PICKER_DOCUMENT_LINES}; ++row )); do
        _ZLE_PICKER_DOCUMENT_SYNTAX[$row]="0:3:keyword 5:9:string"
      done
    }
    # The painter clears its highlights after the refresh; observe them there.
    zle() {
      if [[ $# == 1 && $1 == -R ]] && (( _ZLE_PICKER_READER_ONLY && !_ZLE_PICKER_STATUS_VIEW )); then
        print -r -u $efd -- "FRAME|$COLUMNS|${#${(M)region_highlight:#*fg=143*}}|${#${(M)region_highlight:#*fg=144*}}|${_ZLE_PICKER_INSPECT_SYNTAX[1]-}"
      fi
      builtin zle "$@"
    }
    _syntax_reader() {
      local -a rows=()
      repeat 60 rows+=(abcdefghij)
      _zle_ui_read_text Code Literal "${(F)rows}"
    }
    _syntax_driver() {
      command stty rows 30 cols 100
      command tty > "$HOME/terminal"
      _zle_picker_run 10 "" 1 0 _syntax_reader
      print -r -u $efd -- "DONE|$?"
    }
    _syntax_expect() {
      local wanted="$1|"
      local -a fields=()
      [[ $1 == <-> ]] && wanted="FRAME|$1|"
      { test_pty_expect -p reader $efd "$wanted" } always { trace+=$TEST_PTY_OUTPUT }
      local -i found=$?
      # Every frame this wait read, through the wanted one, keeps its spans.
      for event in "${TEST_PTY_EVENTS[@]}"; do
        fields=("${(@s:|:)event}")
        [[ $fields[1] != FRAME || ( $fields[3] == <1-> && $fields[3] == "$fields[4]" &&
           $fields[5] == "0:3:keyword 5:9:string " ) ]] || {
          print -u2 -r -- "frame lost syntax spans: $event"
          return 1
        }
      done
      return found
    }
    test_pty_start reader _syntax_driver || exit 3
    {
      _syntax_expect 100 || exit 4
      terminal=$(<"$HOME/terminal")
      [[ $terminal == /dev/ttys<-> || $terminal == /dev/pts/<-> ]] || exit 5
      command stty cols 90 < "$terminal" || exit 6
      _syntax_expect 90 || exit 7
      zpty -w -n reader $'\''\e[B'\''
      _syntax_expect 90 || exit 8
      zpty -w -n reader $'\''\x07'\''
      _syntax_expect DONE || exit 9
      [[ $trace != *"read-only variable"* && $trace != *"bad math"* ]] || exit 10
    } always {
      zpty -d reader
      exec {efd}>&-
    }
    print syntax-kept
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal syntax-kept "$output"
}
test_case 'picker resize inside the input reader keeps cached document syntax spans' \
  _test_picker_resize_reader_keeps_syntax_spans
