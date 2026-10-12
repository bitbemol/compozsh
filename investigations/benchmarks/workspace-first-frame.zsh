#!/bin/zsh -df
# First painted full-screen frame in a real PTY, alternating two immutable
# trees. Reports per-tree median, min and max over runs, in milliseconds.
# Usage: /bin/zsh -df <this-file> <baseline-root> <candidate-root> \
#          [scenarios] [runs] [warm-samples] [locale]
#   scenarios: all (default) or a comma-separated subset of
#   browse         Tab after `cd ~/Downloads/` (241 folders, 1,800 files)
#   browse-large   Tab after a 20-folder, 20,000-file photo export path
#   search         Return on a submitted Search descendants query: local walk
#                  over a non-Git project of about 10,500 entries
#   search-large   the same over the 20,020-entry photo export (visit cap)
#   search-git     the same with the Git source in the review repository
#   history        Ctrl-R at an empty prompt with a 20,000-command history
#   review         Return on `g --review` in a dirty 2,400-file repository
#                  (15 staged, 45 unstaged, 25 untracked), until the chooser
#   review-changes Return on the chooser's working changes, until its list
#   Each run starts one new `zsh -di` per scenario and tree in a 140x40 PTY,
#   alternating which tree goes first, after one unmeasured priming shell per
#   tree built its completion dump and manual cache. Keys before the entry
#   keys are typed and settled first. The clock starts just before the entry
#   keys are written and stops when the escape-stripped PTY output contains a
#   marker that only the populated frame paints (not a busy frame). fresh is
#   each new shell's first entry; warm is the median of the next warm-samples
#   entries in that shell. Defaults: 11 runs, 5 warm samples, en_US.UTF-8.
#   Set BENCH_TRACE to a directory to keep the stripped output of each frame.
emulate -LR zsh
setopt EXTENDED_GLOB
zmodload zsh/datetime zsh/zpty zsh/zselect || exit
local baseline=${1:A} candidate=${2:A} scenario_list=${3:-all} locale=${6:-en_US.UTF-8}
local -i runs=${4:-11} warm=${5:-5} run=0
local -a all_scenarios=(browse browse-large search search-large search-git history review review-changes)
local -a scenarios=(${(s:,:)scenario_list})
[[ $scenario_list == all ]] && scenarios=($all_scenarios)
[[ -f $baseline/.zshrc && -f $candidate/.zshrc && ${#scenarios} -gt 0 &&
   -z ${scenarios:|all_scenarios} ]] && (( runs > 0 && warm >= 0 )) || {
  print -u2 'usage: workspace-first-frame.zsh <baseline-root> <candidate-root> [scenarios|all] [runs] [warm-samples] [locale]'
  exit 2
}
local bench=''
bench=$(command mktemp -d "${TMPDIR:-/tmp}/compozsh-frame-bench.XXXXXXXX") && [[ -d $bench ]] || exit
local trace_dir=${BENCH_TRACE:-}
local -a results=()
local -i fd=-1 pfd=-1
local raw='' step_name=''

# Deterministic synthetic fixtures under $bench/home. Names are realistic:
# long paths, spaces, Unicode and mixed case.
_bench_fixtures() {
  export HOME=$bench/home GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
  export GIT_AUTHOR_NAME=Bench GIT_AUTHOR_EMAIL=bench@example.invalid
  export GIT_COMMITTER_NAME=Bench GIT_COMMITTER_EMAIL=bench@example.invalid
  local downloads=$HOME/Downloads camera="$HOME/Pictures/Exports/Camera Roll 2026"
  local clients=$HOME/Developer/Clients/northwind-traders
  local mono=$clients/ios-app-monorepo repo=$clients/web-storefront
  local name='' area='' kind='' package='' directory='' file='' text=''
  local -i i=0 line=0
  local -a areas=(Account Analytics Authentication Billing Catalog Checkout Loyalty
    Notifications Onboarding Payments Profile Search Settings Shipping Subscriptions)
  local -a kinds=(Feature Service Repository Client Kit Interface Model Store Coordinator
    Networking Persistence Testing Mocks Previews Localization Telemetry Widgets Intents Sync Cache)
  local -a months=(January February March April May June July August September
    October November December) files=()
  command mkdir -p -- "$downloads/2026-Tax-Documents" "$camera" "$mono/Packages" \
    "$mono/App/NorthwindApp/Resources/Assets.xcassets" "$repo" "$bench/tmp" || return

  # browse: a busy Downloads folder.
  for (( i = 1; i <= 240; i++ )); do
    case $(( i % 4 )) in
      (0) name="Project archive $i – Northwind Traders" ;;
      (1) name="invoice-batch-2026-${(l:4::0:)i}" ;;
      (2) name="Xcode Release Notes $i (Übersicht)" ;;
      (3) name="Photos from São Paulo trip $i" ;;
    esac
    command mkdir -p -- "$downloads/$name" && : > "$downloads/$name/README.txt" || return
  done
  for (( i = 1; i <= 1800; i++ )); do
    case $(( i % 6 )) in
      (0) name="Screenshot 2026-09-$(( i % 28 + 1 )) at 10.$(( i % 60 )).${i}.png" ;;
      (1) name="Invoice NWT-$i.pdf" ;;
      (2) name="Résumé – Ana García (v$i).pdf" ;;
      (3) name="northwind-ios-build-$i.zip" ;;
      (4) name="Meeting notes $i – Q3 planning.docx" ;;
      (5) name="InstallAssistant-27.0.$i.pkg" ;;
    esac
    : > "$downloads/$name" || return
  done

  # browse-large and search-large: a 20,000-photo export with 20 folders.
  for (( i = 1; i <= 12; i++ )); do
    command mkdir -p -- "$camera/2026-${(l:2::0:)i} ${months[i]}" || return
  done
  for name in Edited Favorites 'Live Photos' Panoramas Portraits Screenshots Selfies Videos; do
    command mkdir -p -- "$camera/$name" || return
  done
  for (( i = 1; i <= 20000; i++ )); do : > "$camera/IMG_${(l:5::0:)i}.HEIC" || return; done

  # search: a non-Git iOS project export of about 10,600 entries.
  for area in $areas; do
    for kind in $kinds; do
      package=$area$kind directory=$mono/Packages/$area$kind
      command mkdir -p -- "$directory/Sources/$package" "$directory/Tests/${package}Tests" || return
      for file in "$directory/Package.swift" "$directory/README.md" \
          "$directory/Sources/$package/"{$package,${package}View,${package}ViewModel,$package+Formatting,${package}Error,${package}Configuration}.swift \
          "$directory/Tests/${package}Tests/"{${package}Tests,${package}ViewModelTests}.swift; do
        : > "$file" || return
      done
    done
  done
  for (( i = 1; i <= 1500; i++ )); do
    directory="$mono/App/NorthwindApp/Resources/Assets.xcassets/${areas[i % 15 + 1]}Illustration$i.imageset"
    command mkdir -p -- "$directory" &&
      : > "$directory/Contents.json" && : > "$directory/illustration-$i@2x.png" &&
      : > "$directory/illustration-$i@3x.png" || return
  done

  # search-git, review and review-changes: a dirty TypeScript repository.
  command git init -q -b main "$repo" && builtin cd -- "$repo" || return
  command git config commit.gpgsign false || return
  for area in $areas; do
    for kind in $kinds; do
      directory=src/features/${(L)area}/${(L)kind}
      files+=("$directory/$area${kind}Controller.ts" "$directory/$area${kind}View.tsx"
        "$directory/$area$kind.test.ts" "$directory/index.ts")
    done
  done
  for (( i = 1; i <= 600; i++ )); do files+=("src/shared/${(L)kinds[i % 20 + 1]}/utility-$i.ts"); done
  for (( i = 1; i <= 300; i++ )); do files+=("docs/guides/${(L)areas[i % 15 + 1]}/guide-$i.md"); done
  for (( i = 1; i <= 300; i++ )); do files+=("public/assets/${(L)areas[i % 15 + 1]}/banner-$i.svg"); done
  for file in $files; do
    command mkdir -p -- "${file:h}" || return
    text=''
    for (( line = 1; line <= 40; line++ )); do
      text+="export const ${${file:t:r}//[^[:alnum:]]/_}_$line = '${file:t} line $line';"$'\n'
    done
    print -rn -- "$text" > "$file" || return
  done
  export GIT_AUTHOR_DATE='2026-09-01T09:00:00Z' GIT_COMMITTER_DATE='2026-09-01T09:00:00Z'
  command git add -A && command git commit -qm 'Initial storefront' || return
  for (( i = 1; i <= 400; i += 4 )); do print -r -- '// reviewed' >> "$files[i]"; done
  export GIT_AUTHOR_DATE='2026-09-02T09:00:00Z' GIT_COMMITTER_DATE='2026-09-02T09:00:00Z'
  command git commit -qam 'Review feature modules' || return
  command git branch upstream && command git branch -q -u upstream || return
  # 45 modified (two hunks), 12 staged, 3 deleted, 25 untracked in a new folder.
  for (( i = 2; i <= 2 + 44 * 20; i += 20 )); do
    file=$files[i]
    text=$(< "$file")
    text=${text/line 5\'/line 5 (edited)\'}
    print -r -- "$text"$'\n''// follow-up' > "$file" || return
  done
  for (( i = 1203; i <= 1203 + 11 * 30; i += 30 )); do
    print -r -- '// staged' >> "$files[i]" && command git add -- "$files[i]" || return
  done
  command git rm -q -- "$files[1500]" "$files[1600]" "$files[1700]" || return
  command mkdir -p src/features/gift-cards || return
  for (( i = 1; i <= 25; i++ )); do
    print -r -- "export const giftCard$i = $i;" > "src/features/gift-cards/GiftCard$i.ts" || return
  done

  # history: 20,000 unique commands in extended history format.
  local -a commands=(
    'git blame -L %d,+20 src/app.ts' 'git switch feature/checkout-tax-%d' 'git log --oneline -n %d'
    'cd ~/Developer/Clients/northwind-traders/web-storefront/src/features/checkout/%d'
    'xcodebuild -scheme NorthwindApp -destination "platform=iOS Simulator,name=iPhone 17"'\
' -only-testing:CheckoutTests/%d test'
    'npm run test -- --testNamePattern="tax rounding %d"' 'ls -la ~/Downloads/invoice-batch-2026-%d'
    'open "Invoice NWT-%d.pdf"' 'ssh deploy@staging-%d.northwind.invalid' 'git diff --stat HEAD~%d'
    'swift test --filter CheckoutFeatureTests/test%d' 'brew info zsh # %d'
  )
  text=''
  for (( i = 1; i <= 19999; i++ )); do
    text+=": $(( 1760000000 + i * 37 )):0;${commands[i % 12 + 1]//\%d/$i}"$'\n'
  done
  text+=": $(( 1760000000 + 20000 * 37 )):0;git switch release/2026.10-hotfix-17"$'\n'
  print -rn -- "$text" > "$bench/history" || return
}

# REPLY is the median of integer arguments; an even count truncates the mean.
_bench_median() {
  local -a sorted=(${(n)@})
  local -i n=${#sorted}
  if (( n % 2 )); then
    REPLY=${sorted[n / 2 + 1]}
  else
    REPLY=$(( (sorted[n / 2] + sorted[n / 2 + 1]) / 2 ))
  fi
}

# Removes terminal escapes and control bytes, keeping printed text.
_bench_strip() {
  local text=$1
  text=${text//$'\e'\[[0-9:;<=>?]#[ -\/]#[@-~]/}
  text=${text//$'\e'\][^$'\a']#$'\a'/}
  text=${text//$'\e'[\(\)\*+][[:alnum:]]/}
  text=${text//$'\e'?/}
  REPLY=${text//[$'\x00'-$'\x09\x0b'-$'\x1f']/}
}

# Drains the PTY and event FIFO once, waiting up to $1 hundredths of a second.
_bench_pump() {
  local chunk='' event=''
  zselect -r $fd $pfd -t ${1:-5} || return 1
  while zpty -r bench_frame chunk 2> /dev/null; do raw+=$chunk; done
  while IFS= read -r -t 0 -u $fd event; do events+=("$event"); done
  return 0
}

# Waits up to $2 seconds for an event line starting with $1; REPLY is the rest.
_bench_event() {
  local -F deadline=$(( EPOCHREALTIME + $2 ))
  while (( EPOCHREALTIME < deadline )); do
    _bench_pump 5 || :
    if (( ${#events} )); then
      local event=$events[1]
      shift events
      [[ $event == "$1"* ]] && { REPLY=${event#"$1"}; REPLY=${REPLY# }; return 0; }
    fi
  done
  return 1
}

# Waits until no PTY output arrived for $1 hundredths of a second.
_bench_quiet() {
  local -i before=0 i=0
  for (( i = 0; i < 400; i++ )); do
    before=${#raw}
    _bench_pump $1 || return 0
    (( ${#raw} == before )) && return 0
  done
  return 1
}

# Waits up to $2 seconds for marker $1 in the escape-stripped output since
# the last reset; REPLY is the arrival time of the chunk that completed it.
# ZLE repaints only changed cells, so markers name text that the new frame
# writes on several rows the previous frame did not show.
_bench_marker() {
  local -F deadline=$(( EPOCHREALTIME + $2 )) now=0
  local -i seen=0
  while (( EPOCHREALTIME < deadline )); do
    _bench_pump 2 || continue
    now=$EPOCHREALTIME
    (( ${#raw} > seen )) || continue
    _bench_strip "${raw[$(( seen > 256 ? seen - 256 : 1 )),-1]}"
    seen=${#raw}
    [[ $REPLY == *"$1"* ]] && { REPLY=$now; return 0; }
  done
  return 1
}

_bench_save() {
  [[ -n $trace_dir ]] || return 0
  _bench_strip "$raw"
  print -r -- "== $step_name"$'\n'"$REPLY" >> "$trace_dir/${1}.txt"
}

# Sends text at the prompt and waits until ZLE has processed it.
_bench_type() {
  zpty -w -n bench_frame "$1"
  zpty -w -n bench_frame $'\x18\x1a'
  _bench_event IDLE 30 || return
  _bench_quiet 5
}

# Sends keys inside a full-screen view and waits for its marker to settle.
_bench_view() {
  raw=''
  zpty -w -n bench_frame "$1"
  _bench_marker "$2" 60 || { print -u2 -r -- "missing marker: $2"; _bench_save missing; return 1; }
  _bench_quiet 10
}

# Sends text to a full-screen query field and waits for its repaints to end.
_bench_input() {
  local -F deadline=$(( EPOCHREALTIME + 30 ))
  raw=''
  zpty -w -n bench_frame "$1"
  while [[ -z $raw ]] && (( EPOCHREALTIME < deadline )); do _bench_pump 2 || :; done
  _bench_quiet 15
}

# Times keys $1 until marker $2; REPLY is the latency in microseconds.
_bench_measure() {
  local -F sent=0
  local -i elapsed=0
  raw=''
  sent=$EPOCHREALTIME
  zpty -w -n bench_frame "$1"
  _bench_marker "$2" 120 || { print -u2 -r -- "missing marker: $2"; _bench_save missing; return 1; }
  elapsed=$(( (REPLY - sent) * 1e6 ))
  REPLY=$elapsed
  _bench_quiet 10
}

# Leaves views with $1, then waits for the prompt and clears the draft.
_bench_leave() {
  raw=''
  zpty -w -n bench_frame "$1"
  if [[ $2 == prompt ]]; then
    _bench_event PROMPT 60 || return
  else
    local -F deadline=$(( EPOCHREALTIME + 60 ))
    while [[ $raw != *$'\e[?1049l'* ]] && (( EPOCHREALTIME < deadline )); do _bench_pump 2 || :; done
    [[ $raw == *$'\e[?1049l'* ]] || { print -u2 'screen did not close'; return 1; }
  fi
  _bench_type $'\x15'
}

# One entry for scenario $1: prepares, measures, leaves. REPLY is microseconds.
_bench_sample() {
  local value=''
  step_name=$1
  case $1 in
    (browse)
      _bench_type 'cd ~/Downloads/' && _bench_measure $'\t' 2026-Tax-Documents &&
        value=$REPLY && _bench_save $1 && _bench_leave $'\x07' ;;
    (browse-large)
      _bench_type 'cd ~/Pictures/Exports/Camera\ Roll\ 2026/' &&
        _bench_measure $'\t' 2026-01 && value=$REPLY && _bench_save $1 && _bench_leave $'\x07' ;;
    (search)
      _bench_type 'cd ~/Developer/Clients/northwind-traders/ios-app-monorepo/' &&
        _bench_view $'\t' Packages && _bench_input $'\x06' && _bench_input viewmodel &&
        _bench_measure $'\r' ViewModel.swift && value=$REPLY && _bench_save $1 &&
        _bench_leave $'\x07\x07' ;;
    (search-large)
      _bench_type 'cd ~/Pictures/Exports/Camera\ Roll\ 2026/' &&
        _bench_view $'\t' 2026-01 && _bench_input $'\x06' && _bench_input img_0042 &&
        _bench_measure $'\r' .HEIC && value=$REPLY && _bench_save $1 &&
        _bench_leave $'\x07\x07' ;;
    (search-git)
      _bench_type 'cd ~/Developer/Clients/northwind-traders/web-storefront/' &&
        _bench_view $'\t' public && _bench_input $'\x06' && _bench_input controller &&
        _bench_measure $'\r' Controller.ts && value=$REPLY && _bench_save $1 &&
        _bench_leave $'\x07\x07' ;;
    (history)
      _bench_measure $'\x12' release/2026.10-hotfix-17 && value=$REPLY && _bench_save $1 &&
        _bench_leave $'\x07' ;;
    (review)
      _bench_type 'g --review' && _bench_measure $'\r' 'Review working changes' && value=$REPLY &&
        _bench_save $1 && _bench_leave $'\x07' prompt ;;
    (review-changes)
      _bench_type 'g --review' && _bench_view $'\r' 'Review working changes' &&
        _bench_measure $'\r' 'Unstaged M' && value=$REPLY && _bench_save $1 &&
        _bench_leave $'\x07\x07' prompt ;;
  esac || return
  REPLY=$value
}

# Measures one new shell for tree $1 and scenario $2 (prime: setup only).
_bench_shell() {
  local root=$1 scenario=$2 version=$3 zdot="$bench/zdot-$3" directory="$bench/home"
  local -a events=() samples=()
  local -i i=0
  [[ $scenario == (search-git|review|review-changes) ]] &&
    directory="$bench/home/Developer/Clients/northwind-traders/web-storefront"
  local stale=''
  while IFS= read -r -t 0 -u $fd stale; do :; done
  command cp -f -- "$bench/history" "$zdot/.zsh_history" || return
  zpty -b bench_frame "command env -i HOME=${(q)bench}/home ZDOTDIR=${(q)zdot} \
    TMPDIR=${(q)bench}/tmp PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color \
    LC_ALL=${(q)locale} ZSH_LOCAL_INIT=/dev/null GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null \
    BENCH_ROOT=${(q)root} BENCH_DIR=${(q)directory} BENCH_EVENTS=${(q)bench}/events /bin/zsh -di" || return
  pfd=$REPLY
  {
    _bench_event PROMPT 60 || { print -u2 'no first prompt'; return 1; }
    # Let the first prompt's asynchronous manual capture finish.
    for (( i = 0; i < 300; i++ )); do
      _bench_type '' || return
      [[ $REPLY == running* ]] || break
      _bench_quiet 10
    done
    [[ -z $trace_dir ]] || print -r -- "settled after $i polls: $REPLY" >> "$trace_dir/$version-$scenario.txt"
    [[ $scenario == prime ]] && return 0
    for (( i = 0; i <= warm; i++ )); do
      _bench_sample $scenario || { print -u2 -r -- "sample failed: $version $scenario"; return 1; }
      samples+=($REPLY)
    done
    print -r -- "$version $scenario fresh ${samples[1]}"
    if (( warm )); then
      _bench_median ${samples[2,-1]}
      print -r -- "$version $scenario warm $REPLY"
    fi
  } always {
    # Hang up the idle shell, as prompt-git-render.zsh does. Polling it with
    # `zpty -t` before `zpty -d` lost the driver's own output in testing.
    zpty -d bench_frame
  }
}

_bench_main() {
  local version='' root='' scenario='' mode=''
  local -a order=() values=() lines=()
  ( _bench_fixtures ) || { print -u2 'fixture setup failed'; return 1; }
  [[ -z $trace_dir ]] || command mkdir -p -- "$trace_dir" || return
  command mkfifo "$bench/events" && exec {fd}<> "$bench/events" || return
  for version in baseline candidate; do
    command mkdir -p -- "$bench/zdot-$version" || return
    print -r -- 'command stty rows 40 cols 140
source "$BENCH_ROOT/.zshrc"; builtin cd -- "$BENCH_DIR"
zmodload zsh/datetime; autoload -Uz add-zle-hook-widget
exec {_bench_fd}> "$BENCH_EVENTS"
_bench_line_init() { print -r -- "PROMPT $EPOCHREALTIME" >&$_bench_fd; }
_bench_idle() { print -r -- "IDLE ${_MANUAL_ASYNC_STATE-none} ${COLUMNS}x$LINES" >&$_bench_fd; }
zle -N bench-idle _bench_idle; bindkey "^X^Z" bench-idle
add-zle-hook-widget line-init _bench_line_init' > "$bench/zdot-$version/.zshrc" || return
    root=$baseline
    [[ $version == candidate ]] && root=$candidate
    _bench_shell "$root" prime $version || { print -u2 "priming failed: $version"; return 1; }
  done
  for (( run = 1; run <= runs; run++ )); do
    order=(baseline candidate)
    (( run % 2 )) || order=(candidate baseline)
    for scenario in $scenarios; do
      for version in $order; do
        root=$baseline
        [[ $version == candidate ]] && root=$candidate
        lines=("${(@f)$(_bench_shell "$root" $scenario $version)}") && [[ -n ${lines[1]} ]] ||
          { print -u2 "measurement failed: $version $scenario"; return 1; }
        results+=($lines)
      done
    done
  done
  print -r -- "runs=$runs warm=$warm locale=$locale zsh=$ZSH_VERSION git=${$(command git --version)#git version } size=140x40"
  printf '%-15s %-6s %-10s %10s %10s %10s\n' scenario mode version median_ms min_ms max_ms
  for scenario in $scenarios; do
    for mode in fresh warm; do
      [[ $mode == warm ]] && (( !warm )) && continue
      for version in baseline candidate; do
        values=(${(n)${${(M)results:#$version $scenario $mode *}##* }})
        (( ${#values} )) || continue
        _bench_median $values
        printf '%-15s %-6s %-10s %10.3f %10.3f %10.3f\n' "$scenario" "$mode" "$version" \
          $(( REPLY / 1000.0 )) $(( values[1] / 1000.0 )) $(( values[-1] / 1000.0 ))
      done
    done
  done
}

# `exit` inside a try-list would skip the always-list, so failures return.
local -i bench_status=0
{
  _bench_main || bench_status=$?
} always {
  (( fd < 0 )) || exec {fd}<&-
  [[ ${bench:t} == compozsh-frame-bench.* && -d $bench ]] && command rm -rf -- "$bench"
}
exit $bench_status
