#!/bin/zsh -df
# Isolated HOME/ZDOTDIR/TMPDIR required. Compare exact serial and asynchronous
# descriptions and attribution entirely in memory; print only counts.
emulate -L zsh
local baseline=${1:A} candidate=${2:A}
source "$baseline/.zsh.addons/.zsh.manual" || exit 1
_manual_prompt_capture || exit 2
local -A expected=("${(@kv)_MANUAL_SUMMARIES}") origins=("${(@kv)_MANUAL_SOURCES}")
source "$candidate/.zsh.addons/.zsh.manual" || exit 3
local name='' phase=''
for phase in cold warm; do
  _manual_summary_reset
  [[ $phase != warm ]] || _MANUAL_CACHE_REFRESH=0
  _manual_prompt_request || exit 4
  while [[ $_MANUAL_ASYNC_STATE == running ]]; do
    zselect -r $_MANUAL_ASYNC_FD $_MANUAL_ASYNC_CONTROL_FD -t 3500 || exit 5
    _manual_async_read $_MANUAL_ASYNC_FD
    _manual_async_control $_MANUAL_ASYNC_CONTROL_FD
  done
  [[ $_MANUAL_ASYNC_STATE == ready ]] || exit 6
  (( ${#expected} == _MANUAL_ASYNC_COUNT && ${#origins} == _MANUAL_ASYNC_COUNT )) || exit 7
  for name in "${(@k)expected}"; do
    # Compare transport values directly: command lookup intentionally omits
    # names shadowed by the benchmark's own functions or shell aliases.
    [[ ${expected[$name]} == "${_MANUAL_ASYNC_SUMMARIES[$name]}" &&
       ${origins[$name]} == "${_MANUAL_ASYNC_SOURCES[$name]}" ]] || exit 8
  done
  printf '%s exact_descriptions_and_origins=%d\n' "$phase" "${#expected}"
done
