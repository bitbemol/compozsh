# Scripted picker outcomes for tests that drive a workspace's own views,
# collectors and decisions without a terminal. The stubs follow the protocol of
# _zle_picker_loop, _zle_picker_run and _zle_picker_screen_session in
# .zsh.addons/support/ui, so a protocol change there is made here once.
#
# Usage: test_picker_script STEP [-- STEP]...
#   select VALUE [ACTION]       accept VALUE, which the view's collector must
#                               return, with ACTION (default select): status 0
#   cancel                      Escape or back: status 1
#   abort                       Ctrl-C: status 130, recorded for _zle_picker_run
#   observe FUNCTION [ARG]...   run FUNCTION in the view's scope after its
#                               collector, then take the next step for the same
#                               view; a failing FUNCTION's status ends the view
#
# Each call replaces the engine entry points (call it once the support and
# peers under test are loaded), sets the script and clears the observation log.
# Every view appends its title, subtitle, page size and visible labels (one per
# line) to TEST_PICKER_TITLES, TEST_PICKER_SUBTITLES, TEST_PICKER_LIMITS and
# TEST_PICKER_LABELS. A view with no step left, an unknown step or a selection
# its collector did not return fails with status 2 and a diagnostic on stderr.
# Outputs and bookmarks are set as the engine sets them; the stubs read no keys
# and do not paint, run idle or deadline callbacks, preview documents or keep
# document positions. Tests of those engine behaviors keep the real loop.

typeset -ga TEST_PICKER_STEPS=() TEST_PICKER_TITLES=() TEST_PICKER_SUBTITLES=()
typeset -ga TEST_PICKER_LIMITS=() TEST_PICKER_LABELS=()

test_picker_script() {
  TEST_PICKER_STEPS=("$@")
  TEST_PICKER_TITLES=() TEST_PICKER_SUBTITLES=() TEST_PICKER_LIMITS=() TEST_PICKER_LABELS=()
  _zle_picker_loop() { _test_picker_loop "$@"; }
  _zle_picker_run() { _test_picker_run "$@"; }
  _zle_picker_screen_session() { _test_picker_screen_session "$@"; }
}

# Moves the next step's words, up to its `--`, from the script into reply.
_test_picker_next_step() {
  local -i end=${TEST_PICKER_STEPS[(i)--]}
  reply=("${(@)TEST_PICKER_STEPS[1,end-1]}")
  TEST_PICKER_STEPS[1,end]=()
  (( ${#reply} )) && return 0
  print -ru2 -- "test_picker_script: no step left for view ${(qq)_ZLE_PICKER_TITLE-}"
  return 2
}

_test_picker_screen_session() {
  emulate -L zsh
  local -i _ZLE_PICKER_SESSION=1 _ZLE_PICKER_SCREEN_ACTIVE=0
  "$@"
}

_test_picker_run() {
  emulate -L zsh
  local raw_limit=${1:-10}
  local _zle_picker_start_query=${2:-} _zle_picker_start_index=${3:-1}
  local _zle_picker_start_offset=${4:-0} _zle_picker_session_callback=${5:-}
  local -i _zle_picker_session_status=1 _zle_picker_aborted=0
  [[ $raw_limit == <-> && ${#raw_limit} -le 18 ]] || raw_limit=10
  (( raw_limit < 1 )) && raw_limit=1
  (( raw_limit > 20 )) && raw_limit=20
  _ZLE_PICKER_RUN_LIMIT=$raw_limit
  if [[ -n $_zle_picker_session_callback ]]; then
    _zle_picker_screen_session "$_zle_picker_session_callback"
    _zle_picker_session_status=$?
  else
    _zle_picker_loop "$_zle_picker_start_query" "$raw_limit" \
      "$_zle_picker_start_index" "$_zle_picker_start_offset"
  fi
  (( _zle_picker_aborted )) && return 130
  [[ -n $_zle_picker_session_callback ]] && return $_zle_picker_session_status
  (( _ZLE_PICKER_ACCEPTED )) && return 0
  return 1
}

_test_picker_loop() {
  emulate -L zsh
  local query=${1-} raw_limit=${2-} collector=${_ZLE_PICKER_COLLECTOR-}
  local _ZLE_PICKER_EXCLUDE=${5:-}
  local -i _ZLE_PICKER_EXCLUDE_FOCUS=0 _ZLE_PICKER_EXCLUDE_SHOWN=0
  [[ ${6:-0} == 1 ]] && _ZLE_PICKER_EXCLUDE_FOCUS=1
  [[ ${7:-0} == 1 || -n $_ZLE_PICKER_EXCLUDE ]] && _ZLE_PICKER_EXCLUDE_SHOWN=1
  local -i exclusion_default=$(( !${_ZLE_PICKER_QUERY_SUBMIT:-0} &&
    !${_ZLE_PICKER_READER_ONLY:-0} && !${_ZLE_PICKER_STATUS_VIEW:-0} ))
  local -i _ZLE_PICKER_EXCLUSION_ENABLED=${_ZLE_PICKER_EXCLUSION_ENABLED:-$exclusion_default}
  (( ${+functions[_matching_exclusion]} )) || _ZLE_PICKER_EXCLUSION_ENABLED=0
  if (( !_ZLE_PICKER_EXCLUSION_ENABLED )); then
    _ZLE_PICKER_EXCLUDE='' _ZLE_PICKER_EXCLUDE_FOCUS=0 _ZLE_PICKER_EXCLUDE_SHOWN=0
  fi
  local -i limit=8 selected=1 offset=0 count=0 index=0 focus=0 accepted=0 result=2
  local -a reply=() step=()
  [[ $raw_limit == <-> && ${#raw_limit} -le 18 ]] && limit=$raw_limit
  (( limit < 1 )) && limit=1
  (( limit > 20 )) && limit=20
  [[ -n $collector ]] && (( ${+functions[$collector]} )) || return 2
  [[ ${3:-} == <-> ]] && (( $3 > 0 )) && selected=$3
  [[ ${4:-} == <-> ]] && offset=$4
  if (( !${_ZLE_PICKER_SESSION:-0} )); then
    _zle_picker_screen_session _zle_picker_loop "$@"
    return
  fi

  _ZLE_PICKER_SELECTED_VALUE='' _ZLE_PICKER_ACCEPTED=0
  _ZLE_PICKER_ACTION=select _ZLE_PICKER_IDLE_ACTION=''
  _ZLE_PICKER_BOOKMARK=() _ZLE_PICKER_BOOKMARK_FOCUS=0
  focus=${_zle_picker_start_focus:-0}
  (( ${_ZLE_PICKER_READER_ONLY:-0} )) && focus=1
  {
    # The engine's first request covers its start row and viewport.
    "$collector" "$query" $(( (selected > offset + limit ? selected : offset + limit) + 1 ))
    count=${#_ZLE_PICKER_RESULTS}
    (( selected > count )) && selected=$count
    TEST_PICKER_TITLES+=("${_ZLE_PICKER_TITLE-}")
    TEST_PICKER_SUBTITLES+=("${_ZLE_PICKER_SUBTITLE-}")
    TEST_PICKER_LIMITS+=($limit)
    TEST_PICKER_LABELS+=("${(pj:\n:)_ZLE_PICKER_LABELS[offset+1,offset+limit]}")
    while _test_picker_next_step; do
      step=("${reply[@]}")
      case $step[1] in
        (select)
          (( ${#step} == 2 || ${#step} == 3 )) || {
            print -ru2 -- "test_picker_script: usage: select VALUE [ACTION]"; break
          }
          index=${_ZLE_PICKER_RESULTS[(Ie)$step[2]]}
          (( index )) || {
            print -ru2 -- "test_picker_script: ${(qq)step[2]} is not among the view's results"; break
          }
          selected=$index
          (( selected <= offset )) && offset=$(( selected - 1 ))
          (( selected > offset + limit )) && offset=$(( selected - limit ))
          _ZLE_PICKER_SELECTED_VALUE=$step[2] _ZLE_PICKER_ACTION=${step[3]:-select}
          _ZLE_PICKER_ACCEPTED=1 accepted=1 result=0
          break ;;
        (cancel)
          result=1
          break ;;
        (abort)
          (( ${+_zle_picker_aborted} )) && _zle_picker_aborted=1
          result=130
          break ;;
        (observe)
          (( ${#step} >= 2 )) || {
            print -ru2 -- "test_picker_script: usage: observe FUNCTION [ARG]..."; break
          }
          "${(@)step[2,-1]}" || { result=$?; break; } ;;
        (*)
          print -ru2 -- "test_picker_script: unknown step ${(qq)step[1]}"
          break ;;
      esac
    done
  } always {
    if (( accepted || ${_ZLE_PICKER_READER_ONLY:-0} )) ||
       [[ ${_ZLE_PICKER_OPTIONS_KIND-} == file-views ]]; then
      _ZLE_PICKER_BOOKMARK=("$query" "$selected" "$offset")
      (( _ZLE_PICKER_EXCLUDE_SHOWN )) &&
        _ZLE_PICKER_BOOKMARK+=("$_ZLE_PICKER_EXCLUDE" "$_ZLE_PICKER_EXCLUDE_FOCUS" "$_ZLE_PICKER_EXCLUDE_SHOWN")
      _ZLE_PICKER_BOOKMARK_FOCUS=$focus
    fi
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _ZLE_PICKER_RESULT_INDEXES=()
  }
  return $result
}
