_test_xcode_capture_live_disk_bounds() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/provider.zsh" '#!/bin/zsh -df
exec {events}<> "$HOME/events"
exec {gate}<> "$HOME/gate"
print -rn -- "${(l:20000::o:):-}"
print -u2 -rn -- "${(l:20000::e:):-}"
print -r -u $events ready
IFS= read -r -u $gate release
exit 7' || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    zmodload zsh/stat
    unsetopt MONITOR NOTIFY BG_NICE
    export TMPDIR=$HOME
    command mkfifo "$HOME/events" "$HOME/gate"
    exec {events}<> "$HOME/events"
    exec {gate}<> "$HOME/gate"
    local -i capture=0 total=0 result=0 ready=0
    local file="" event=""
    local -a details=() captures=()
    ZSH_XCODE_CAPTURE_MAX_BYTES=4096
    {
      _xcode_capture_command /bin/zsh -df "$HOME/provider.zsh"
      print -r -- "$?|${#_XCODE_CAPTURE}|$_XCODE_CAPTURE_ERROR" > "$HOME/result"
    } &
    capture=$!
    {
      IFS= read -r -t 3 -u $events event && [[ $event == ready ]] && ready=1
      # Observe physical retained bytes while the native provider is still
      # waiting for release. Include every regular file in its capture scope.
      for file in "$HOME"/compozsh-xcode.*/*(N.); do
        zstat -A details +size -- "$file" || exit 2
        (( total += details[1] ))
      done
      print -r -u $gate release
      wait $capture 2>/dev/null
      capture=0
      (( ready )) || { print -u2 "capture provider did not reach its live gate"; exit 3; }
      (( total <= 4096 + 8192 + 64 )) || {
        print -u2 "live provider retained $total bytes beyond its stream budgets"; exit 4
      }
      [[ $(<"$HOME/result") == "1|0|output exceeded the 4096-byte capture limit" ]] || exit 5
      captures=("$HOME"/compozsh-xcode.*(N))
      (( !${#captures} )) || exit 6
      print bounded-live
    } always {
      (( capture > 1 )) && { print -r -u $gate release; wait $capture 2>/dev/null; }
      exec {events}>&-
      exec {gate}>&-
    }
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal bounded-live "$output"
}
test_case 'Xcode capture bounds physical stdout and stderr storage while the provider runs' \
  _test_xcode_capture_live_disk_bounds

_test_xcode_capture_stream_semantics() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    export TMPDIR=$HOME
    local payload=$'\''literal [*] $(no-eval)\ninput tail'\'' arg=$'\''spaces * [ ] $literal'\''
    print -rn -- "$payload" > "$HOME/input"
    _xcode_capture_command /bin/zsh -dfc '\''
      input=$(cat)
      print -r -- "$1|$input"
      print -u2 -rn -- "${(l:20000::e:):-}"
      exit 7
    '\'' capture "$arg" < "$HOME/input"
    [[ $? == 7 && -z $_XCODE_CAPTURE && ${#_XCODE_CAPTURE_ERROR} == 8192 &&
       $_XCODE_CAPTURE_ERROR == ${(l:8192::e:):-} ]] || exit 1
    _xcode_capture_command /bin/zsh -dfc '\''
      input=$(cat)
      print -r -- "$1|$input"
      print -u2 -rn -- "${(l:20000::e:):-}"
      exit 0
    '\'' capture "$arg" < "$HOME/input"
    [[ $? == 0 && $_XCODE_CAPTURE == "$arg|$payload" && -z $_XCODE_CAPTURE_ERROR ]] || exit 2
    print semantics
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal semantics "$output"
}
test_case 'Xcode capture preserves literal argv stdin status and independent bounded diagnostics' \
  _test_xcode_capture_stream_semantics

_test_xcode_capture_interrupted_provider() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/provider.zsh" '#!/bin/zsh -df
trap '\''exit 130'\'' INT
exec {events}<> "$HOME/events"
exec {gate}<> "$HOME/gate"
print -r -- partial-output
print -u2 -r -- interrupted-diagnostic
print -r -u $events -- "$$"
IFS= read -r -t 3 -u $gate release
exit 0' || return
  local output=''
  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.xcode"
    unsetopt MONITOR NOTIFY BG_NICE
    export TMPDIR=$HOME
    command mkfifo "$HOME/events" "$HOME/gate"
    exec {events}<> "$HOME/events"
    exec {gate}<> "$HOME/gate"
    local -i capture=0 provider=0
    local -a captures=()
    {
      _xcode_capture_command /bin/zsh -df "$HOME/provider.zsh"
      print -r -- "$?|${#_XCODE_CAPTURE}|$_XCODE_CAPTURE_ERROR" > "$HOME/result"
    } &
    capture=$!
    {
      IFS= read -r -t 3 -u $events provider || exit 1
      (( provider > 1 )) || exit 2
      kill -INT $provider
      wait $capture 2>/dev/null
      capture=0
      [[ $(<"$HOME/result") == "130|0|interrupted-diagnostic" ]] || {
        print -u2 "interrupted capture lost native status or diagnostic"; exit 3
      }
      captures=("$HOME"/compozsh-xcode.*(N))
      (( !${#captures} )) || exit 4
      kill -0 $provider 2>/dev/null && exit 5
      print interrupted-and-clean
    } always {
      (( capture > 1 )) && { print -r -u $gate release; wait $capture 2>/dev/null; }
      exec {events}>&-
      exec {gate}>&-
    }
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal interrupted-and-clean "$output"
}
test_case 'Xcode capture preserves interrupted provider status and cleans both stream sinks' \
  _test_xcode_capture_interrupted_provider
