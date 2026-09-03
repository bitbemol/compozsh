# Public entry paths use the real shared ZLE. Frame observations use a FIFO;
# they never write synchronization markers into the terminal under test.
_test_git_comparison_native() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.git-review"
    mkdir -p "$HOME/repo"
    cd "$HOME/repo"
    git init -qb main
    git config user.name Fixture
    git config user.email fixture@example.invalid
    git config commit.gpgsign false
    print base > file
    git add . && git commit -qm base || exit 1
    git branch topic
    print main >> file
    git commit -qam main || exit 2
    left=$(git rev-parse HEAD)
    git switch -q topic
    print topic >> file
    git commit -qam topic || exit 3
    right=$(git rev-parse HEAD)
    git branch review-target "$right"
    # The current branch identity must stay exact when a same-named tag exists.
    git tag topic "$left"
    index_before=$(git hash-object .git/index)
    zmodload zsh/zpty
    zmodload zsh/zselect
    zmodload zsh/datetime
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    functions -c _zle_picker_show _comparison_test_show
    _zle_picker_show() {
      _comparison_test_show
      (( ${_ZLE_PICKER_BUSY:-0} )) && return 0
      if (( _ZLE_PICKER_DOCUMENT && ${#_ZLE_PICKER_RESULTS} )); then
        (( !_ZLE_PICKER_DOCUMENT_PENDING )) || return 0
        [[ ${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]} == "$_ZLE_PICKER_DOCUMENT_KEY" ]] || return 0
      fi
      if [[ $_ZLE_PICKER_TITLE == "Git comparison" ]]; then
        [[ $_git_compare_from == "$left" && $_git_compare_to == "$right" ]] || print -u $efd BAD-IDS
        if [[ $scenario == branches ]]; then
          [[ $_git_compare_from_label == main && $_git_compare_to_label == review-target ]] || print -u $efd BAD-BRANCH-CHOICES
        fi
        [[ $_ZLE_PICKER_SUBTITLE == *"${right[1,12]}"* ]] || print -u $efd BAD-CONTEXT
        [[ $_ZLE_PICKER_SUBTITLE_ROW == *" → To "* &&
           $_ZLE_PICKER_SUBTITLE_ROW == *"${right[1,12]}"* &&
           $_ZLE_PICKER_POSTDISPLAY == *"$_ZLE_PICKER_SUBTITLE_ROW"* ]] || print -u $efd BAD-PAINTED-DIRECTION
      fi
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_SELECTED|$_ZLE_PICKER_INSPECT_FOCUS|$COLUMNS|$LINES|$_ZLE_PICKER_GUIDE_ACTIVE"
    }
    _comparison_test_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "READY:$(command tty)"
      if [[ $scenario == direct ]]; then g --review refs/heads/main refs/heads/topic 2> "$HOME/session-error"
      else g --review 2> "$HOME/session-error"; fi
      local -i result=$?
      [[ $result == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 ]] || print -u $efd BAD-CLEANUP
      [[ ! -s "$HOME/session-error" ]] || print -u $efd BAD-STALE-ERROR
      print -u $efd DONE
    }
    _comparison_test_expect() {
      local wanted=$1 chunk="" event=""
      local -F deadline=$(( EPOCHREALTIME + 5 ))
      while (( EPOCHREALTIME < deadline )); do
        zselect -r $efd $pfd -t 50 || continue
        while true; do
          chunk=""
          zpty -r compare chunk && [[ -n $chunk ]] || break
          trace+=$chunk
        done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; got $event"
      return 1
    }
    _comparison_test_key() {
      zpty -w -n compare "$1"
      _comparison_test_expect "$2"
    }
    _comparison_test_journey() {
      zselect -r $efd -t 500 && IFS= read -r -u $efd event || return 4
      device=${event#READY:}
      if [[ $scenario == (setup|cancel|branches) ]]; then
        _comparison_test_expect "FRAME|Git review||1|0|120|30|0" || return 5
        _comparison_test_key 3 "FRAME|Compare branches or commits||2|0|120|30|0" || return 6
        _comparison_test_key $'\''\r'\'' "FRAME|Against · choose branch or commit||1|0|120|30|0" || return 7
        if [[ $scenario == branches ]]; then
          _comparison_test_key main "FRAME|Against · choose branch or commit|main|1|0|120|30|0" || return 34
          _comparison_test_key $'\''\r'\'' "FRAME|Compare branches or commits||4|0|120|30|0" || return 35
          _comparison_test_key 1 "FRAME|Compare · choose branch or commit||1|0|120|30|0" || return 36
          _comparison_test_key review-target "FRAME|Compare · choose branch or commit|review-target|1|0|120|30|0" || return 37
          _comparison_test_key $'\''\r'\'' "FRAME|Compare branches or commits||4|0|120|30|0" || return 38
          _comparison_test_key $'\''\r'\'' "FRAME|Git comparison||1|0|120|30|0" || return 39
        else
          _comparison_test_key 2 "FRAME|Against · enter branch or commit||0|0|120|30|0" || return 8
          if [[ $scenario == cancel ]]; then
            _comparison_test_key missing "FRAME|Against · enter branch or commit|missing|0|0|120|30|0" || return 29
            _comparison_test_key $'\''\r'\'' "FRAME|Against · enter branch or commit|missing|0|0|120|30|0" || return 30
            _comparison_test_key $'\''\e'\'' "FRAME|Against · choose branch or commit||2|0|120|30|0" || return 31
            _comparison_test_key $'\''\e'\'' "FRAME|Compare branches or commits||2|0|120|30|0" || return 32
            _comparison_test_key $'\''\e'\'' "FRAME|Git review||3|0|120|30|0" || return 33
          else
            # Digits are literal inside bracketed paste, not row actions.
            _comparison_test_key $'\''\e[200~'\''"$left"$'\''\e[201~'\'' "FRAME|Against · enter branch or commit|$left|0|0|120|30|0" || return 9
            _comparison_test_key $'\''\r'\'' "FRAME|Compare branches or commits||4|0|120|30|0" || return 10
            _comparison_test_key 3 "FRAME|Changes to show||1|0|120|30|0" || return 11
            _comparison_test_key 2 "FRAME|Compare branches or commits||3|0|120|30|0" || return 12
            _comparison_test_key 4 "FRAME|Git comparison||1|0|120|30|0" || return 13
          fi
        fi
      else
        _comparison_test_expect "FRAME|Git comparison||1|0|120|30|0" || return 14
      fi
      if [[ $scenario != cancel ]]; then
        _comparison_test_key $'\''\e[C'\'' "FRAME|Git comparison||1|1|120|30|0" || return 15
        _comparison_test_key $'\''\e[C'\'' "FRAME|Git comparison||1|1|120|30|0" || return 16
        _comparison_test_key $'\''\e[D'\'' "FRAME|Git comparison||1|1|120|30|0" || return 17
        command git branch -f main "$right"
        _comparison_test_key $'\''\x12'\'' "FRAME|Git comparison||1|1|120|30|0" || return 18
        _comparison_test_key $'\''\x0b'\'' "FRAME|Git comparison||1|1|120|30|1" || return 19
        _comparison_test_key $'\''\e'\'' "FRAME|Git comparison||1|1|120|30|0" || return 20
        local old_trace=$trace
        command stty rows 20 cols 80 < "$device"
        _comparison_test_expect "FRAME|Git comparison||1|1|80|20|0" || return 21
        [[ $trace != "$old_trace" ]] || return 22
        if [[ $scenario == (setup|branches) ]]; then
          _comparison_test_key $'\''\e'\'' "FRAME|Compare branches or commits||4|0|80|20|0" || return 23
          _comparison_test_key $'\''\e'\'' "FRAME|Git review||3|0|80|20|0" || return 24
        fi
      fi
      zpty -w -n compare $'\''\e'\''
      _comparison_test_expect DONE || return 25
      [[ -n $enter && -n $leave && $trace == *"$enter"*"$leave"* && $trace != *"read-only variable"* ]] || return 26
      (( ${#trace} - ${#${trace//"$enter"/}} == ${#enter} &&
         ${#trace} - ${#${trace//"$leave"/}} == ${#leave} )) || return 26
      [[ $(git symbolic-ref HEAD) == refs/heads/topic && $(git hash-object .git/index) == "$index_before" ]] || return 27
    }
    local scenario trace event device pfd enter=$terminfo[smcup] leave=$terminfo[rmcup]
    local -i result=0
    for scenario in setup branches direct cancel; do
      git branch -f main "$left"
      trace="" event=""
      zpty -b compare _comparison_test_driver || exit 28
      pfd=$REPLY
      { _comparison_test_journey; result=$? } always { zpty -d compare }
      (( !result )) || { print -u2 -- "comparison native assertion $result"; exit $result; }
    done
    print compared
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal compared "$output"
}
test_case 'Git comparison native setup and direct entry preserve panes endpoints refresh Back and screen cleanup' _test_git_comparison_native
