_test_xcode_discovery_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home" || return
  command mkfifo "$TEST_TMP_DIR/home/events" "$TEST_TMP_DIR/home/gate" \
    "$TEST_TMP_DIR/home/unrelated" "$TEST_TMP_DIR/home/writer-ready" || return
  test_write_file "$TEST_TMP_DIR/home/provider.zsh" '#!/bin/zsh -df
trap '\''exit 143'\'' TERM
exec {events}<> "$HOME/events"
exec {gate}<> "$HOME/gate"
print -r -u $events -- "PROVIDER:$$"
print -r -- "literal [*] destination"
print -u2 -r -- "native diagnostic"
IFS= read -r -u $gate release
case $1 in
  failure)
    print -u2 -rn -- "${(l:20000::e:):-}"
    exit 7 ;;
  overflow)
    print -rn -- "${(l:20000::o:):-}"
    print -u2 -rn -- "${(l:20000::e:):-}" ;;
  descendant|held-writer)
    [[ $1 == held-writer ]] && print -rn -- "${(l:131072::t:):-}"
    /bin/zsh -dfc '\''
      trap "" TERM
      exec {events}<> "$HOME/events"
      exec {gate}<> "$HOME/gate"
      exec {ready}<> "$HOME/writer-ready"
      print -r -u $events -- "DESCENDANT:$$"
      print -r -u $ready ready
      # This writer never closes on its own. Completion must stop the owned
      # descendant while this gate remains held, independent of elapsed time.
      IFS= read -r -u $gate release
    '\'' &!
    # The provider cannot publish completion before its inherited writer has
    # announced ownership; the controller must observe that exact child.
    exec {ready}<> "$HOME/writer-ready"
    IFS= read -r -u $ready writer_ready
    [[ $1 == descendant ]] && IFS= read -r -u $gate release
    ;;
esac
exit 0' || return
  test_write_file "$TEST_TMP_DIR/home/session.zsh" '
    export TMPDIR=$HOME
    source "$1/.zsh.addons/.zsh.editor"
    for unit in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.) "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.xcode"
    exec {events}<> "$HOME/events"
    functions[_discovery_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _discovery_show
      local state="VIEW:$_ZLE_PICKER_TITLE:$COLUMNS"
      [[ $state == "$previous" ]] || { print -r -u $events -- "$state"; previous=$state; }
    }
    # On the old implementation exercise its synchronous behavior, so red
    # demonstrates missing responsiveness rather than a missing function.
    (( ${+functions[_xcode_discovery_capture]} )) || _xcode_discovery_capture() { shift; _xcode_capture_command "$@"; }
    _discovery_controller() {
      emulate -L zsh
      if [[ $discovery_mode == hostile ]]; then
        setopt KSH_ARRAYS SH_WORD_SPLIT NO_UNSET
      fi
      _xcode_discovery_capture "Loading schemes" /bin/zsh -df "$HOME/provider.zsh" "$discovery_mode"
      local -i captured_result=$?
      if [[ $discovery_mode == hostile ]]; then
        [[ -o KSH_ARRAYS && -o SH_WORD_SPLIT && -o NO_UNSET ]] || return 94
      fi
      return $captured_result
    }
    _driver() {
      local previous="" before=$(command stty -g) result=0 discovery_mode=$1
      local -i unrelated=0
      {
        command /bin/zsh -dfc '\''
          exec {gate}<> "$HOME/unrelated"
          IFS= read -r -u $gate release
        '\'' & unrelated=$!
      } 2>/dev/null
      ZSH_XCODE_CAPTURE_MAX_BYTES=4096
      [[ $discovery_mode == held-writer ]] && ZSH_XCODE_CAPTURE_MAX_BYTES=262144
      {
        _zle_picker_run 10 "" 1 0 _discovery_controller
        result=$?
      } always {
        (( ${_XCODE_DISCOVERY_CANCELLED:-0} == 130 )) && result=130
        kill -0 $unrelated 2>/dev/null || result=93
        kill -TERM $unrelated 2>/dev/null
        wait $unrelated 2>/dev/null
        [[ $(command stty -g) == "$before" ]] || result=98
        (( _ZLE_PICKER_ACTIVE == 0 && _ZLE_PICKER_SCREEN_ACTIVE == 0 )) || result=97
        local -a leftovers=("$HOME"/compozsh-xcode-discovery.*(N))
        (( !${#leftovers} )) || result=96
        if [[ $discovery_mode == held-writer ]]; then
          [[ $_XCODE_CAPTURE == $'\''literal [*] destination\n'\''"${(l:131072::t:):-}" ]] || result=95
          print -r -u $events -- "DONE:${result}:held-writer"
        else
          print -r -u $events -- "DONE:$result:$_XCODE_CAPTURE:${#_XCODE_CAPTURE_ERROR}"
        fi
      }
    }
    command stty rows 24 cols 100
    print -r -u $events -- "READY:$(command tty)"
  ' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    zmodload zsh/zpty zsh/zselect
    exec {events}<> "$HOME/events"
    exec {gate}<> "$HOME/gate"
    local event="" trace="" chunk="" device="" mode="" pfd=0 provider=0 descendant=0
    _until() {
      while zselect -r $events $pfd -t 400; do
        while zpty -r discovery chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $events event; then
          [[ $event == PROVIDER:* ]] && provider=${event#PROVIDER:}
          [[ $event == DESCENDANT:* ]] && descendant=${event#DESCENDANT:}
          [[ $event == ${~1} ]] && return 0
          [[ $event == DONE:* ]] && break
        fi
      done
      print -u2 -r -- "expected $1 got $event; ${(V)trace[-600,-1]}"
      return 1
    }
    for mode in ${=3}; do
      provider=0 descendant=0
      zpty -b discovery "$2" -dfi
      pfd=$REPLY
      {
        zpty -w discovery "source ${(q)HOME}/session.zsh ${(q)1}"
        _until "READY:*" || exit 1
        device=${event#READY:}
        zpty -w discovery "_driver $mode"
        _until "VIEW:Xcode / Discovery:100" || exit 2
        # Enter cannot accept an incomplete provider. A resize proves that
        # input and cached rendering remain live while that provider waits.
        zpty -w -n discovery $'\''\r'\''
        command stty rows 12 cols 45 < "$device"
        _until "VIEW:Xcode / Discovery:45" || exit 3
        case $mode in
          complete|hostile)
            print -r -u $gate release
            _until "DONE:0:*" || exit 4
            [[ $event == "DONE:0:literal [*] destination:0" ]] || exit 4 ;;
          escape|suspended)
            [[ $mode == suspended ]] && kill -STOP $provider
            zpty -w -n discovery $'\''\e'\''
            _until "DONE:1::*" || exit 5 ;;
          interrupt)
            zpty -w -n discovery $'\''\x03'\''
            _until "DONE:130::*" || exit 6 ;;
          failure)
            print -r -u $gate release
            _until "DONE:7::8192" || exit 9 ;;
          overflow)
            print -r -u $gate release
            _until "DONE:1::43" || exit 10 ;;
          descendant)
            print -r -u $gate release
            _until "DESCENDANT:*" || exit 11
            # Both the provider and a TERM-ignoring descendant remain live.
            # Cancellation must stop exactly their owned process group.
            zpty -w -n discovery $'\''\e'\''
            _until "DONE:1::*" || exit 12
            for repeat in {1..20}; do
              kill -0 $descendant 2>/dev/null || break
              zselect -t 5
            done
            kill -0 $descendant 2>/dev/null && { print -u2 "discovery descendant survived cancellation"; exit 13; }
            ;;
          held-writer)
            print -r -u $gate release
            _until "DONE:0:held-writer" || exit 14
            (( descendant > 1 )) || exit 16
            for repeat in {1..20}; do
              kill -0 $descendant 2>/dev/null || break
              zselect -t 5
            done
            kill -0 $descendant 2>/dev/null && { print -u2 "completed discovery retained an owned descendant"; exit 17; }
            ;;
        esac
        (( provider > 1 )) || exit 7
        kill -0 $provider 2>/dev/null && { print -u2 "discovery provider survived $mode"; exit 8; }
      } always {
        (( provider > 1 )) && kill -KILL $provider 2>/dev/null
        (( descendant > 1 )) && kill -KILL $descendant 2>/dev/null
        zpty -d discovery
      }
    done
    exec {events}>&-
    exec {gate}>&-
    print native-discovery
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN" "${1:-complete hostile escape suspended interrupt}") || return
  test_assert_equal native-discovery "$output"
}
test_case 'Xcode discovery native terminal remains responsive through completion Escape Ctrl-C and resize' \
  _test_xcode_discovery_native

_test_xcode_discovery_native_stream_bounds() {
  _test_xcode_discovery_native 'failure overflow'
}
test_case 'Xcode discovery bounds both streams and preserves native failure without partial catalogs' \
  _test_xcode_discovery_native_stream_bounds

_test_xcode_discovery_native_descendant_cleanup() {
  _test_xcode_discovery_native descendant
}
test_case 'Xcode discovery cancellation removes its provider and owned descendants' \
  _test_xcode_discovery_native_descendant_cleanup

_test_xcode_discovery_completed_inherited_writer() {
  _test_xcode_discovery_native held-writer
}
test_case 'Xcode discovery consumes complete queued output without waiting for an inherited writer' \
  _test_xcode_discovery_completed_inherited_writer
