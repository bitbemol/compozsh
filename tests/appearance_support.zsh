# Numeric contrast checks for synthetic standard xterm cube/grayscale colors.
# No terminal profile is read; a reference background may also be an RGB triple.
_test_palette_luminance() {
  emulate -L zsh
  local color=$1 component=''
  local -i index=0 cube=0
  local -a levels=(0 95 135 175 215 255) components=()
  local -a weights=(0.2126 0.7152 0.0722)
  local -F linear=0 luminance=0

  if [[ $color == <0-255>,<0-255>,<0-255> ]]; then
    components=("${(@s:,:)color}")
  elif [[ $color == <16-231> ]]; then
    cube=$(( color - 16 ))
    components=("${levels[cube / 36 + 1]}" "${levels[(cube / 6) % 6 + 1]}" "${levels[cube % 6 + 1]}")
  elif [[ $color == <232-255> ]]; then
    component=$(( 8 + (color - 232) * 10 ))
    components=("$component" "$component" "$component")
  else
    print -u2 -r -- "invalid fixed-palette color: $color"
    return 1
  fi
  for component in "${components[@]}"; do
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

_test_palette_assert_style() {
  emulate -L zsh
  local label=$1 style=$2 background=$3 foreground='' attribute=''
  local -F minimum=${4:-4.5} foreground_luminance=0 background_luminance=0 contrast=0
  for attribute in "${(@s:,:)style}"; do
    case $attribute in
      (fg=*) foreground=${attribute#fg=} ;;
      (bg=*) background=${attribute#bg=} ;;
    esac
  done
  _test_palette_luminance "$foreground" || return
  foreground_luminance=$REPLY
  _test_palette_luminance "$background" || return
  background_luminance=$REPLY
  if (( foreground_luminance > background_luminance )); then
    (( contrast = (foreground_luminance + 0.05) / (background_luminance + 0.05) ))
  else
    (( contrast = (background_luminance + 0.05) / (foreground_luminance + 0.05) ))
  fi
  (( contrast >= minimum )) || {
    print -u2 -r -- "$label: foreground $foreground on $background has contrast $contrast; needs $minimum"
    return 1
  }
}
