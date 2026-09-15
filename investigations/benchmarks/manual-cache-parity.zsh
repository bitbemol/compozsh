#!/bin/zsh -df
# Run in a disposable HOME/ZDOTDIR with a minimal environment. Arguments:
# reviewed baseline clone, reviewed candidate clone. Only counts are printed;
# complete descriptions and attribution are compared in shell memory.
emulate -L zsh
local baseline=${1:A} candidate=${2:A}
[[ -f $baseline/.zsh.addons/.zsh.manual && -f $candidate/.zsh.addons/.zsh.manual ]] || exit 2
source "$baseline/.zsh.addons/.zsh.manual"
_manual_prompt_capture || exit 3
local -A expected=("${(@kv)_MANUAL_SUMMARIES}") origins=("${(@kv)_MANUAL_SOURCES}")
source "$candidate/.zsh.addons/.zsh.manual"
local name='' phase=''
for phase in cold warm; do
  _manual_summary_reset
  [[ $phase != warm ]] || _MANUAL_CACHE_REFRESH=0
  _manual_prompt_capture || exit 4
  (( ${#expected} == ${#_MANUAL_SUMMARIES} && ${#origins} == ${#_MANUAL_SOURCES} )) || exit 5
  for name in "${(@k)expected}"; do
    [[ ${expected[$name]} == "${_MANUAL_SUMMARIES[$name]}" &&
       ${origins[$name]} == "${_MANUAL_SOURCES[$name]}" ]] || exit 6
  done
  printf '%s exact_descriptions_and_origins=%d public_cache_records=%d\n' \
    "$phase" "${#expected}" "${#_MANUAL_CACHE_SUMMARIES}"
done
