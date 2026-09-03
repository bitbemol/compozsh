# Fixed xterm selection colors must remain readable in both pane-focus states.
_test_appearance_selection_metadata_contrast() {
  test_make_temp_dir || return
  local scheme='' order='' output=''
  for scheme in dark light; do
    for order in first last; do
      output=$(test_run_interactive "$TEST_TMP_DIR/$scheme-$order" '
        ZSH_COLOR_SCHEME=$2
        [[ $3 == first ]] && source "$1/.zsh.addons/support/.zsh.appearance"
        source "$1/.zsh.addons/.zsh.highlighting"
        source "$1/.zsh.addons/.zsh.editor"
        source "$1/.zsh.addons/support/.zsh.ui"
        [[ $3 == last ]] && source "$1/.zsh.addons/support/.zsh.appearance"
        _selection_luminance() {
          local -i color=$1 cube=0 component=0
          local -a levels=(0 95 135 175 215 255) channels=()
          local -F linear=0 luminance=0
          if (( color >= 232 )); then
            component=$(( 8 + (color - 232) * 10 ))
            channels=($component $component $component)
          elif (( color >= 16 )); then
            cube=$(( color - 16 ))
            channels=(${levels[cube / 36 + 1]} ${levels[(cube / 6) % 6 + 1]} ${levels[cube % 6 + 1]})
          else
            print -u2 -- "selection uses profile-dependent ANSI color $color"
            return 1
          fi
          local -a weights=(0.2126 0.7152 0.0722)
          local -i index=0
          for component in $channels; do
            (( ++index, linear = component / 255.0 ))
            if (( linear <= 0.04045 )); then
              (( linear /= 12.92 ))
            else
              (( linear = ((linear + 0.055) / 1.055) ** 2.4 ))
            fi
            (( luminance += linear * weights[index] ))
          done
          REPLY=$luminance
        }
        local role="" selection="" style="" field="" foreground="" background=""
        local -F foreground_luminance=0 background_luminance=0 contrast=0
        local -i selected=0
        for selection in picker-selected picker-selected-inactive; do
          selected=1
          [[ $selection == picker-selected-inactive ]] && selected=2
          for role in architecture size error success; do
            _zle_picker_label_highlight_style "picker-$role" $selected "${ZSH_HIGHLIGHT_STYLES[$selection]}"
            style=$REPLY foreground="" background=""
            for field in "${(@s:,:)style}"; do
              case $field in
                (fg=*) [[ -z $foreground ]] || exit 3; foreground=${field#fg=} ;;
                (bg=*) [[ -z $background ]] || exit 4; background=${field#bg=} ;;
              esac
            done
            [[ $foreground == <16-255> && $background == <16-255> ]] || exit 5
            _selection_luminance $foreground || exit 6
            foreground_luminance=$REPLY
            _selection_luminance $background || exit 7
            background_luminance=$REPLY
            if (( foreground_luminance > background_luminance )); then
              (( contrast = (foreground_luminance + 0.05) / (background_luminance + 0.05) ))
            else
              (( contrast = (background_luminance + 0.05) / (foreground_luminance + 0.05) ))
            fi
            (( contrast >= 4.5 )) || {
              print -u2 -- "$2 $selection $role has contrast $contrast: $style"
              exit 8
            }
          done
        done
        print readable
      ' "$TEST_REPO_ROOT" "$scheme" "$order") || return
      test_assert_equal readable "$output" || return
    done
  done
}
test_case 'appearance selection metadata stays readable in active and inactive panes' \
  _test_appearance_selection_metadata_contrast

_test_appearance_selection_metadata_customization() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    ZSH_COLOR_SCHEME=light
    typeset -gA ZSH_HIGHLIGHT_STYLES=(
      picker-error-selected "fg=123,bg=40,underline"
      picker-error-selected-inactive "fg=124,bg=41,underline"
    )
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    _zle_picker_label_highlight_style picker-error 1 "fg=231,bg=25,bold"
    print -r -- "$REPLY"
    _zle_picker_label_highlight_style picker-error 2 "fg=236,bg=250"
    print -r -- "$REPLY"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal $'bg=25,bold,fg=123,underline\nbg=250,fg=124,underline' "$output"
}
test_case 'appearance selection metadata preserves distinct initializer overrides and row backgrounds' \
  _test_appearance_selection_metadata_customization

_test_appearance_inactive_row_overlay_backgrounds() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    ZSH_COLOR_SCHEME=light
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    BUFFER="" PREDISPLAY="" POSTDISPLAY=""
    _ZLE_PICKER_HEADER="" _ZLE_PICKER_QUERY_ROW="" _ZLE_PICKER_QUERY=example
    _ZLE_PICKER_DISPLAY=("example context")
    _ZLE_PICKER_DISPLAY_STYLES=(picker-selected-inactive)
    _ZLE_PICKER_DISPLAY_INDEX_ENDS=(0)
    _ZLE_PICKER_DISPLAY_LEFT_ENDS=(-1)
    _ZLE_PICKER_DISPLAY_HIGHLIGHTS=("0:7:picker-error")
    _ZLE_PICKER_DISPLAY_CONTEXT_STARTS=(8)
    _ZLE_PICKER_DISPLAY_MATCH_STARTS=(0)
    local -a captured=() fields=()
    zle() { captured=("${region_highlight[@]}"); }
    _zle_picker_show
    local span="" found_match=0 found_metadata=0
    for span in "${captured[@]}"; do
      fields=( ${=span} )
      [[ ${fields[1]#P} == <-> ]] || continue
      (( ${fields[1]#P} >= 3 )) || continue
      [[ $fields[3] == *bg=* ]] || {
        print -u2 -- "inactive selection overlay erased its background: $span"
        exit 1
      }
      [[ $fields[3] == *underline* ]] && found_match=1
      [[ $fields[3] == *fg=88* ]] && found_metadata=1
    done
    (( found_match && found_metadata )) || exit 2
    print preserved
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal preserved "$output"
}
test_case 'appearance inactive selection keeps its background beneath metadata context and matches' \
  _test_appearance_inactive_row_overlay_backgrounds

_test_appearance_native_selection_and_status() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/session.zsh" '
    ZSH_COLOR_SCHEME=$2
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    [[ $3 == output ]] && source "$1/.zsh.addons/.zsh.output"
    PROMPT="fixture> " RPROMPT=""
    exec {event_fd}<> "$HOME/events"
    zle() {
      local frame_event="" span="" header="" expected=""
      if [[ $1 == -R && -n $POSTDISPLAY ]]; then
        if (( _ZLE_PICKER_STATUS_VIEW )); then
          header="P$(( ${#_ZLE_PICKER_TITLEBAR} + 1 )) "
          expected=75
          [[ $ZSH_COLOR_SCHEME == light ]] && expected=25
          [[ ${region_highlight[(r)${header}*]} == *"fg=$expected,bold"* ]] || {
            print -r -u $event_fd -- BAD-STATUS
            return 1
          }
          frame_event=STATUS
        elif (( _ZLE_PICKER_INSPECT_FOCUS )); then
          expected=237
          [[ $ZSH_COLOR_SCHEME == light ]] && expected=253
          [[ ${(j:|:)region_highlight} == *"bg=$expected,underline"* ]] || {
            print -r -u $event_fd -- BAD-INACTIVE-MATCH
            return 1
          }
          expected=224
          [[ $ZSH_COLOR_SCHEME == light ]] && expected=88
          [[ ${(j:|:)region_highlight} == *"fg=$expected,"* ]] || {
            print -r -u $event_fd -- BAD-INACTIVE-METADATA
            return 1
          }
          frame_event=INACTIVE
        else
          [[ ${(j:|:)region_highlight} == *"fg=224,bg=24,bold"* ]] || {
            print -r -u $event_fd -- BAD-ACTIVE-METADATA
            return 1
          }
          frame_event=ACTIVE
        fi
      fi
      builtin zle "$@"
      [[ -n $frame_event ]] && print -r -u $event_fd -- "$frame_event"
      return 0
    }
    _appearance_collect() {
      _ZLE_PICKER_RESULTS=(example)
      _ZLE_PICKER_LABELS=("example failed")
    }
    _appearance_status_collect() {
      _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    }
    _appearance_launch() {
      local -A _ZLE_PICKER_INSPECT_TEXTS=(example "Captured detail")
      local -A _ZLE_PICKER_LABEL_HIGHLIGHTS=(example "8:14:picker-error")
      local -A _ZLE_PICKER_CONTEXTS=(example "local fixture")
      local _ZLE_PICKER_COLLECTOR=_appearance_collect
      local -i _ZLE_PICKER_STATUS_VIEW=0
      BUFFER="draft" CURSOR=3
      _zle_picker_loop example 5
      (( $? == 1 && CURSOR == 3 )) && [[ $BUFFER == draft ]] || {
        print -r -u $event_fd -- BAD-RESTORE
        return 1
      }
      print -r -u $event_fd -- RESTORED
    }
    _appearance_status() {
      local -A _ZLE_PICKER_INSPECT_TEXTS=()
      local _ZLE_PICKER_COLLECTOR=_appearance_status_collect _ZLE_PICKER_BROWSE_LABEL=Working
      local -i _ZLE_PICKER_STATUS_VIEW=1
      local -a _ZLE_PICKER_EMPTY_LINES=("Build staged")
      _zle_picker_loop "" 5
      (( $? == 1 )) || return 1
      print -r -u $event_fd -- RESTORED
    }
    zle -N appearance-launch _appearance_launch
    zle -N appearance-status _appearance_status
    bindkey "^X^P" appearance-launch
    bindkey "^X^T" appearance-status
    command stty rows 24 cols 120
    print -r -u $event_fd -- READY
  ' || return
  local scheme='' peer='' output=''
  for scheme in dark light; do
    for peer in standalone output; do
      output=$(test_run_interactive "$TEST_TMP_DIR/$scheme-$peer" '
        export LC_ALL=en_US.UTF-8
        zmodload zsh/zpty
        zmodload zsh/zselect
        command mkfifo "$HOME/events" || exit 1
        exec {event_fd}<> "$HOME/events" || exit 2
        local event="" trace="" chunk="" pty_fd=0
        _appearance_event() {
          while zselect -r $event_fd $pty_fd -t 500; do
            while zpty -r appearance chunk; do trace+=$chunk; done
            IFS= read -r -t 0 -u $event_fd event && return 0
          done
          print -u2 -- "appearance event timeout: $event"
          return 1
        }
        zpty -b appearance "$2" -dfi || exit 3
        pty_fd=$REPLY
        {
          zpty -w appearance "source ${(q)3} ${(q)1} ${(q)4} ${(q)5}"
          _appearance_event && [[ $event == READY ]] || exit 4
          zpty -w -n appearance $'\''\x18\x10'\''
          _appearance_event && [[ $event == ACTIVE ]] || { print -u2 -- "$event"; exit 5; }
          zpty -w -n appearance $'\''\x05'\''
          _appearance_event && [[ $event == INACTIVE ]] || { print -u2 -- "$event"; exit 6; }
          zpty -w -n appearance $'\''\x07'\''
          _appearance_event && [[ $event == RESTORED ]] || exit 7
          zpty -w -n appearance $'\''\x18\x14'\''
          _appearance_event && [[ $event == STATUS ]] || { print -u2 -- "$event"; exit 8; }
          zpty -w -n appearance $'\''\x07'\''
          _appearance_event && [[ $event == RESTORED ]] || exit 9
          while zpty -r appearance chunk; do trace+=$chunk; done
          [[ $trace == *$'\''\e[48;5;24m'\''* ]] || { print -u2 -- "active selection was not painted"; exit 10; }
          local inactive_background=237 status_foreground=75
          [[ $4 == light ]] && inactive_background=253 status_foreground=25
          [[ $trace == *$'\''\e[48;5;'\''"${inactive_background}m"* &&
             $trace == *$'\''\e[38;5;'\''"${status_foreground}m"* ]] || {
            print -u2 -- "native palette colors were not painted"
            exit 11
          }
          [[ $trace != *"bad math expression"* && $trace != *"read-only variable"* ]] || exit 12
        } always {
          zpty -d appearance
          exec {event_fd}>&-
        }
        print painted
      ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN" "$TEST_TMP_DIR/session.zsh" "$scheme" "$peer") || return
      test_assert_equal painted "$output" || return
    done
  done
}
test_case 'appearance native ZLE paints selection focus and status palettes with optional output peer' \
  _test_appearance_native_selection_and_status
