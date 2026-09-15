#!/bin/zsh -df
# Bounded experiment, not shipped startup behavior. Run with an isolated HOME:
# env -i HOME=<disposable> ZDOTDIR=<disposable> TMPDIR=<disposable> \
#   PATH=/usr/bin:/bin:/usr/sbin:/sbin LC_ALL=en_US.UTF-8 \
#   /bin/zsh -df investigations/benchmarks/manual-parallelism.zsh <reviewed-clone>
emulate -L zsh
unsetopt BG_NICE
zmodload zsh/datetime
local repository=${1:A}
[[ -f $repository/.zsh.addons/.zsh.manual ]] || exit 2
source "$repository/.zsh.addons/.zsh.manual"
local -a selected_pages=() worker_pids=()
# Capture the exact ordered public-page workload without reading document text.
functions[_experiment_page_read]=$functions[_manual_page_read]
_manual_page_read() {
  selected_pages+=("$1")
  REPLY=$'.SH NAME\nfixture \\- Public workload selection\n.SH SYNOPSIS\n'
}
_manual_summary_capture /usr/share/man || exit 3
functions[_manual_page_read]=$functions[_experiment_page_read]
_MANUAL_CACHE_SUMMARIES=() _MANUAL_CACHE_ALIASES=()
_experiment_worker() {
  emulate -L zsh
  local -i workers=$1 slot=$2 index=0 captured=0
  local page='' text='' directory=''
  directory=$(command /usr/bin/mktemp -d "$TMPDIR/compozsh-manual.XXXXXXXX") || return 1
  {
    for (( index=slot; index <= $#selected_pages; index+=workers )); do
      page=$selected_pages[index]
      _manual_page_read "$page" /usr/share/man || continue
      text=$REPLY
      _manual_summary_parse "$text" || _manual_summary_format "$text" "$directory" || :
      (( ++captured ))
    done
    # No manual content, paths or private information crosses the output boundary.
    printf 'worker=%d pages=%d\n' "$slot" "$captured"
  } always {
    [[ -d $directory && ! -L $directory && ${directory:t} == compozsh-manual.* ]] &&
      command /bin/rmdir -- "$directory"
  }
}
local -i workers=0 slot=0 worker_pid=0 round=0 failed=0
local -F started=0 elapsed=0
print -r -- "public_pages=$#selected_pages"
# Rotate the order to reduce process/filesystem warm-up bias.
for workers in 1 2 4 4 1 2 2 4 1; do
  (( ++round ))
  worker_pids=()
  started=$EPOCHREALTIME
  for (( slot=1; slot<=workers; ++slot )); do
    _experiment_worker "$workers" "$slot" &
    worker_pids+=($!)
  done
  for worker_pid in "${worker_pids[@]}"; do
    wait $worker_pid || failed=1
  done
  elapsed=$(( (EPOCHREALTIME-started)*1000 ))
  printf 'round=%d workers=%d elapsed_ms=%.3f\n' "$round" "$workers" "$elapsed"
done
return $failed
