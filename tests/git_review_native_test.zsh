# Exercise real g, its nested ZLE, and the terminal control stream. Fixture
# observations travel through a FIFO so no diagnostic can corrupt the screen.
_test_git_review_native() {
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
    print -r -- initial > file
    repeat 400; do print -r -- context >> file; done
    git add . && git commit -qm initial || exit 1
    git branch feature/review
    git switch -q feature/review && git switch -q main || exit 2
    print -r -- staged >> file
    git add file
    print -r -- unstaged >> file
    mkdir new-dir
    print -r -- review-new-content > new-dir/new.txt
    local index_before=$(git hash-object --no-filters .git/index)
    zmodload zsh/zpty
    zmodload zsh/zselect
    zmodload zsh/datetime
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions -c _zle_picker_show _review_test_show
    _zle_picker_show() {
      _review_test_show
      (( ${_ZLE_PICKER_BUSY:-0} )) && return 0
      if (( _ZLE_PICKER_DOCUMENT && ${#_ZLE_PICKER_RESULTS} )); then
        [[ ${_ZLE_PICKER_RESULTS[_ZLE_PICKER_SELECTED]} == "$_ZLE_PICKER_DOCUMENT_KEY" ]] || return 0
        if [[ ${_GIT_REVIEW_KINDS[$_ZLE_PICKER_DOCUMENT_KEY]} == untracked ]]; then
          if [[ $scenario == journey ]]; then
            [[ $_ZLE_PICKER_DOCUMENT_TITLE == new-dir/new.txt &&
               $_ZLE_PICKER_CONTEXTS[$_ZLE_PICKER_DOCUMENT_KEY] == New &&
               $_NAVIGATION_PICKER_LABELS[$_ZLE_PICKER_DOCUMENT_KEY] == new-dir/new.txt ]] ||
              print -r -u $efd BAD-NEW-PATH
          fi
          [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *"+review-new-content"* &&
             $_ZLE_PICKER_DOCUMENT_ROLES[2] == success && $_GIT_REVIEW_DOCUMENT_NEW[2] == 1 ]] ||
            print -r -u $efd BAD-NEW-PREVIEW
        fi
        local -i source_row=${_ZLE_PICKER_INSPECT_SOURCE_LINES[_ZLE_PICKER_INSPECT_OFFSET+1]:-0}
        print -r -u $efd -- "DOC|$_ZLE_PICKER_DOCUMENT_KEY|$_ZLE_PICKER_INSPECT_OFFSET|$_ZLE_PICKER_INSPECT_WIDTH|$context|${_GIT_REVIEW_DOCUMENT_NEW[source_row]:-0}"
      fi
      if [[ $_ZLE_PICKER_TITLE == Branches && $scenario != fallback ]]; then
        [[ ${_ZLE_PICKER_DISPLAY[-1]} == *"^X review"* ]] || print -r -u $efd BAD-REVIEW-HINT
      fi
      if [[ $_ZLE_PICKER_TITLE == Branches && $scenario == unborn ]]; then
        [[ $_ZLE_PICKER_SUBTITLE != *"detached HEAD"* ]] || print -r -u $efd BAD-UNBORN
      fi
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_TITLE|$_ZLE_PICKER_QUERY|$_ZLE_PICKER_SELECTED|$_ZLE_PICKER_INSPECT_FOCUS|$COLUMNS|$LINES"
    }
    functions -c _git_review_git _review_test_git
    _git_review_git() {
      # Counts stay visible across the bounded-capture subshell.
      print -r -- capture >> "$HOME/captures"
      _review_test_git "$@"
    }
    functions -c _git_review_untracked_capture _review_test_untracked
    _git_review_untracked_capture() {
      print -r -- capture >> "$HOME/new-captures"
      _review_test_untracked "$@"
    }
    zle() {
      builtin zle "$@"
      local -i result=$?
      if [[ $scenario == abort && $1 == .redisplay && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 ]]; then
        (( !_ZLE_PICKER_ACTIVE && !_ZLE_AUTOSUGGEST_SUSPENDED )) || print -r -u $efd BAD-ABORT
        print -r -u $efd RESTORED
      fi
      return $result
    }
    _review_test_driver() {
      command stty rows 30 cols 120
      print -r -u $efd -- "READY:$(command tty)"
      g
      local -i result=$?
      [[ $result == 0 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 ]] || print -r -u $efd -- "BAD-CLEANUP:$result:${_ZLE_PICKER_SCREEN_ACTIVE:-0}:$_ZLE_PICKER_ACTIVE"
      print -r -u $efd DONE
    }
    _review_test_expect() {
      local wanted=$1 chunk=""
      local -F deadline=$(( EPOCHREALTIME + 5.0 ))
      while (( EPOCHREALTIME < deadline )) && zselect -r $efd $pfd -t 50; do
        while zpty -r review chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == DOC\|* ]] && { doc_event=$event; continue; }
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -r -- "expected $wanted; got $event"
      return 1
    }
    _review_test_key() {
      zpty -w -n review "$1"
      _review_test_expect "$2" || return
      [[ $trace == *"$enter"* && ${trace#*"$enter"} != *"$enter"* && $trace != *"$leave"* ]] || {
        print -u2 -- "review exposed the main terminal"
        return 1
      }
    }
    local trace="" event="" device="" pfd=0 captures="" scenario=journey doc_event="" saved_doc=""
    zpty -b review _review_test_driver || exit 3
    pfd=$REPLY
    {
      zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 4
      device=${event#READY:}
      _review_test_expect "FRAME|Branches||1|0|120|30" || exit 5
      # Select a different branch, but working changes still refer to main.
      _review_test_key $'\''\e[B'\'' "FRAME|Branches||2|0|120|30" || exit 6
      _review_test_key $'\''\x18'\'' "FRAME|Git review||1|0|120|30" || exit 7
      _review_test_key $'\''\r'\'' "FRAME|Working changes||1|0|120|30" || exit 8
      [[ $doc_event == DOC\|1\|0\|*\|3\|* ]] || { print -u2 "review must open focused"; exit 59; }
      # Expanding a change near EOF reveals that area, not the start of the file.
      _review_test_key $'\''\e[C'\'' "FRAME|Working changes||1|1|120|30" || exit 60
      _review_test_key $'\''\eOC'\'' "FRAME|Working changes||1|1|120|30" || exit 61
      [[ $doc_event == *\|1000000000\|* ]] && (( ${doc_event##*|} > 370 )) || {
        print -u2 "full context lost source position: $doc_event"; exit 62
      }
      # Each pane owns its scroll. Revisiting a cached file restores its reader.
      captures=$(<"$HOME/captures")
      _review_test_key $'\''\e[C'\'' "FRAME|Working changes||1|1|120|30" || exit 44
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 75
      _review_test_key $'\''\x16'\'' "FRAME|Working changes||1|1|120|30" || exit 45
      saved_doc=$doc_event
      [[ $saved_doc != DOC\|1\|0\|* ]] || exit 46
      _review_test_key $'\''\t'\'' "FRAME|Working changes||1|0|120|30" || exit 47
      _review_test_key $'\''\e[B'\'' "FRAME|Working changes||2|0|120|30" || exit 48
      captures=$(<"$HOME/captures")
      _review_test_key $'\''\e[A'\'' "FRAME|Working changes||1|0|120|30" || exit 49
      [[ $doc_event == "$saved_doc" ]] || { print -u2 "scroll lost: $saved_doc -> $doc_event"; exit 50; }
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 51
      _review_test_key $'\''\t'\'' "FRAME|Working changes||1|1|120|30" || exit 52
      _review_test_key $'\''\eOD'\'' "FRAME|Working changes||1|1|120|30" || exit 53
      [[ $doc_event == *\|3\|* ]] || exit 54
      [[ $doc_event == DOC\|1\|0\|* ]] || exit 55
      captures=$(<"$HOME/captures")
      saved_doc=$doc_event
      _review_test_key $'\''\x18'\'' "FRAME|Git / Change atlas||1|0|120|30" || exit 56
      _review_test_key new-dir "FRAME|Git / Change atlas|new-dir|1|0|120|30" || exit 96
      _review_test_key $'\''\r'\'' "FRAME|Git / Change atlas||1|0|120|30" || exit 97
      _review_test_key $'\''\e'\'' "FRAME|Git / Change atlas|new-dir|1|0|120|30" || exit 98
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 99
      _review_test_key $'\''\x15'\'' "FRAME|Git / Change atlas||1|0|120|30" || exit 100
      _review_test_key $'\''\r'\'' "FRAME|Atlas / Read change||1|1|120|30" || exit 101
      [[ $doc_event == *\|3\|* ]] || exit 102
      _review_test_key $'\''\e[C'\'' "FRAME|Atlas / Read change||1|1|120|30" || exit 103
      [[ $doc_event == *\|1000000000\|* ]] || exit 104
      _review_test_key $'\''\e'\'' "FRAME|Git / Change atlas||1|0|120|30" || exit 105
      _review_test_key $'\''\e'\'' "FRAME|Working changes||1|1|120|30" || exit 106
      [[ $doc_event == "$saved_doc" ]] || exit 107
      _review_test_key $'\''\e[D'\'' "FRAME|Working changes||1|0|120|30" || exit 57
      _review_test_key $'\''\e[D'\'' "FRAME|Working changes||1|0|120|30" || exit 58
      _review_test_key new.txt "FRAME|Working changes|new.txt|1|0|120|30" || exit 63
      [[ $doc_event == DOC\|3\|* && $(<"$HOME/new-captures") == capture ]] || exit 64
      _review_test_key $'\''\e[C'\'' "FRAME|Working changes|new.txt|1|1|120|30" || exit 65
      _review_test_key $'\''\e[C'\'' "FRAME|Working changes|new.txt|1|1|120|30" || exit 66
      [[ $(<"$HOME/new-captures") == capture ]] || exit 67
      _review_test_key $'\''\e[D'\'' "FRAME|Working changes|new.txt|1|0|120|30" || exit 68
      _review_test_key $'\''\e[D'\'' "FRAME|Working changes|new.txt|1|0|120|30" || exit 69
      [[ $(<"$HOME/new-captures") == capture ]] || exit 70
      _review_test_key $'\''\x12'\'' "FRAME|Working changes|new.txt|1|0|120|30" || exit 72
      [[ $(<"$HOME/new-captures") == $'\''capture\ncapture'\'' ]] || exit 73
      _review_test_key $'\''\x15'\'' "FRAME|Working changes||1|0|120|30" || exit 74
      _review_test_key unstaged "FRAME|Working changes|unstaged|1|0|120|30" || exit 9
      _review_test_key $'\''\r'\'' "FRAME|Working changes|unstaged|1|1|120|30" || exit 10
      captures=$(<"$HOME/captures")
      _review_test_key $'\''\x16'\'' "FRAME|Working changes|unstaged|1|1|120|30" || exit 11
      command stty rows 16 cols 70 < "$device"
      _review_test_expect "FRAME|Working changes|unstaged|1|1|70|16" || exit 12
      _review_test_key $'\''\x0b'\'' "FRAME|Working changes|unstaged|1|1|70|16" || exit 13
      _review_test_key $'\''\x12'\'' "FRAME|Working changes|unstaged|1|1|70|16" || exit 76
      _review_test_key $'\''\e'\'' "FRAME|Working changes|unstaged|1|1|70|16" || exit 14
      _review_test_key $'\''\x02'\'' "FRAME|Working changes|unstaged|1|0|70|16" || exit 15
      [[ $(<"$HOME/captures") == "$captures" ]] || exit 16
      # Direct pane focus retains density; arrows always enter focused first.
      _review_test_key $'\''\e[C'\'' "FRAME|Working changes|unstaged|1|1|70|16" || exit 77
      _review_test_key $'\''\e[C'\'' "FRAME|Working changes|unstaged|1|1|70|16" || exit 78
      [[ $doc_event == *\|1000000000\|* ]] || exit 79
      _review_test_key $'\''\x02'\'' "FRAME|Working changes|unstaged|1|0|70|16" || exit 80
      _review_test_key $'\''\e[C'\'' "FRAME|Working changes|unstaged|1|1|70|16" || exit 81
      [[ $doc_event == *\|3\|* ]] || exit 82
      captures=$(<"$HOME/captures")
      _review_test_key $'\''\x12'\'' "FRAME|Working changes|unstaged|1|1|70|16" || exit 83
      # Refresh rechecks filter safety, captures the list and the selected diff.
      [[ $(<"$HOME/captures") == "$captures"$'\''\ncapture\ncapture\ncapture'\'' ]] || exit 84
      _review_test_key $'\''\e'\'' "FRAME|Branches||2|0|70|16" || exit 18
      _review_test_key $'\''\x18'\'' "FRAME|Git review||1|0|70|16" || exit 19
      _review_test_key 2 "FRAME|Branch commits||1|0|70|16" || exit 20
      _review_test_key $'\''\r'\'' "FRAME|Commit files||1|0|70|16" || exit 21
      _review_test_key $'\''\r'\'' "FRAME|Commit files||1|1|70|16" || exit 22
      _review_test_key $'\''\e'\'' "FRAME|Branch commits||1|0|70|16" || exit 24
      _review_test_key $'\''\e'\'' "FRAME|Branches||2|0|70|16" || exit 25
      zpty -w -n review $'\''\e'\''
      _review_test_expect DONE || exit 26
      [[ $trace == *"$enter"*"$leave"* &&
         $trace != *$'\''\e[3J'\''* && $trace != *"read-only variable"* ]] || exit 27
      # Literal substitution counts the boundary without shortest-prefix glob
      # removal, which becomes quadratic over a long Unicode terminal trace.
      (( ${#trace} - ${#${trace//"$leave"/}} == ${#leave} )) || exit 27
      [[ $(git symbolic-ref --short HEAD) == main && $(git hash-object --no-filters .git/index) == "$index_before" ]] || exit 28
    } always {
      zpty -d review
    }
    for scenario in atlas switch abort unborn fallback; do
      if [[ $scenario == unborn ]]; then
        mkdir -p "$HOME/unborn"
        cd "$HOME/unborn"
        git init -qb main
      else
        cd "$HOME/repo"
      fi
      [[ $scenario == fallback ]] && unfunction _git_review_branch_choose
      trace="" event=""
      zpty -b review _review_test_driver || exit 29
      pfd=$REPLY
      {
        zselect -r $efd -t 500 && IFS= read -r -u $efd event || exit 30
        if [[ $scenario == unborn ]]; then
          _review_test_expect "FRAME|Branches||0|0|120|30" || exit 31
          _review_test_key $'\''\x18'\'' "FRAME|Git review||1|0|120|30" || exit 32
          _review_test_key $'\''\r'\'' "FRAME|Working changes||0|0|120|30" || exit 33
          _review_test_key $'\''\x12'\'' "FRAME|Working changes||0|0|120|30" || exit 85
          print -r -- review-new-content > "$HOME/unborn/new.txt"
          _review_test_key $'\''\x12'\'' "FRAME|Working changes||1|0|120|30" || exit 88
          [[ $doc_event == DOC\|1\|* ]] || exit 89
          command rm -- "$HOME/unborn/new.txt"
          _review_test_key $'\''\x12'\'' "FRAME|Working changes||0|0|120|30" || exit 90
          _review_test_key $'\''\e[C'\'' "FRAME|Working changes||0|0|120|30" || exit 86
          _review_test_key $'\''\e[D'\'' "FRAME|Working changes||0|0|120|30" || exit 87
          _review_test_key $'\''\e'\'' "FRAME|Branches||0|0|120|30" || exit 34
        else
          _review_test_expect "FRAME|Branches||1|0|120|30" || exit 35
        fi
        if [[ $scenario == atlas ]]; then
          _review_test_key $'\''\x18'\'' "FRAME|Git review||1|0|120|30" || exit 108
          _review_test_key atlas "FRAME|Git review|atlas|1|0|120|30" || exit 109
          _review_test_key $'\''\r'\'' "FRAME|Git / Change atlas||1|0|120|30" || exit 110
          _review_test_key $'\''\e'\'' "FRAME|Git review|atlas|1|0|120|30" || exit 111
          _review_test_key $'\''\e'\'' "FRAME|Branches||1|0|120|30" || exit 112
          zpty -w -n review $'\''\e'\''
        elif [[ $scenario == switch ]]; then
          _review_test_key $'\''\e[B'\'' "FRAME|Branches||2|0|120|30" || exit 36
          zpty -w -n review $'\''\r'\''
        elif [[ $scenario == abort ]]; then
          _review_test_key $'\''\x18'\'' "FRAME|Git review||1|0|120|30" || exit 37
          _review_test_key $'\''\r'\'' "FRAME|Working changes||1|0|120|30" || exit 38
          _review_test_key $'\''\r'\'' "FRAME|Working changes||1|1|120|30" || exit 39
          zpty -w -n review $'\''\x03'\''
        else
          zpty -w -n review $'\''\e'\''
        fi
        if [[ $scenario == abort ]]; then _review_test_expect RESTORED || exit 40
        else _review_test_expect DONE || exit 41; fi
        [[ $trace == *"$enter"*"$leave"* ]] || exit 42
        (( ${#trace} - ${#${trace//"$leave"/}} == ${#leave} )) || exit 42
        if [[ $scenario == switch ]]; then
          [[ $(git symbolic-ref --short HEAD) == feature/review ]] || exit 43
        fi
      } always {
        zpty -d review
      }
    done
    print reviewed
  ' "$TEST_REPO_ROOT") || { print -u2 -r -- "Native Git review failed at assertion $?"; return 1; }
  test_assert_equal reviewed "$output"
}
test_case 'Git review native g preserves screens bookmarks resize abort switching unborn review and peer fallback' _test_git_review_native

# Terminal.app sends repeated arrows as ordinary cursor byte sequences; it does
# not expose key-release events. Feed a complete queued burst through a real PTY
# and use the final document load as the quiescence barrier. The controller may
# paint lightweight selection frames while consuming the burst, but it must not
# resolve any intermediate preview. Once the final preview is installed, the
# immediately following Right key must focus that same document: any unread
# arrow tail would move or load another selection first.
_test_git_review_native_burst_settle() {
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
    local -i index=0
    for (( index=1; index<=15; ++index )); do
      print -r -- "let value = $index" > "file-${(l:2::0:)index}.swift"
    done
    git add . && git commit -qm initial || exit 1
    for (( index=1; index<=15; ++index )); do
      print -r -- "let changed = $index" >> "file-${(l:2::0:)index}.swift"
    done

    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" || exit 2
    exec {efd}<> "$HOME/events" || exit 3
    functions -c _git_review_document_load _burst_original_document_load
    _git_review_document_load() {
      _burst_original_document_load "$@"
      local -i result=$?
      print -r -u $efd -- "LOAD|$2|$_ZLE_PICKER_DOCUMENT_KEY"
      return $result
    }
    functions -c _zle_picker_show _burst_original_show
    _zle_picker_show() {
      _burst_original_show
      [[ $_ZLE_PICKER_TITLE == "Working changes" ]] || return 0
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_SELECTED|$_ZLE_PICKER_DOCUMENT_KEY|$_ZLE_PICKER_INSPECT_FOCUS"
    }
    _burst_driver() {
      command stty rows 30 cols 120
      print -r -u $efd READY
      _git_review_view "$HOME/repo" working
      local -i result=$?
      print -r -u $efd -- "DONE|$result"
    }
    _burst_event() {
      local chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r burst chunk; do trace+=$chunk; done
        IFS= read -r -t 0 -u $efd event && return 0
      done
      print -u2 -r -- "burst event timed out after ${(qqq)event}"
      return 1
    }
    _burst_until() {
      local wanted=$1
      while _burst_event; do
        case $event in
          (LOAD\|*) loads+=("${${(s:|:)event}[2]}") ;;
        esac
        [[ $event == "$wanted" ]] && return 0
        [[ $event == DONE\|* ]] && break
      done
      print -u2 -r -- "expected $wanted; got ${(qqq)event}; loads=${(j:,:)loads}"
      return 1
    }

    local trace="" event="" burst_bytes="" key_down="" key_left="" key_right="" key_abort="" pfd=0
    local -a loads=()
    printf -v key_down "\\033[B"
    printf -v key_left "\\033[D"
    printf -v key_right "\\033[C"
    printf -v key_abort "\\007"
    zpty -b burst _burst_driver || exit 4
    pfd=$REPLY
    {
      _burst_until READY || exit 5
      _burst_until "LOAD|1|1" || exit 6
      _burst_until "FRAME|1|1|0" || exit 7

      repeat 8; do burst_bytes+=$key_down; done
      zpty -w -n burst "$burst_bytes"
      _burst_until "LOAD|9|9" || exit 8
      _burst_until "FRAME|9|9|0" || exit 9
      [[ ${(j:,:)loads} == 1,9 ]] || {
        print -u2 -r -- "burst resolved intermediate documents: ${(j:,:)loads}"
        exit 10
      }

      # LOAD|9 can only be emitted after the picker declares the burst settled.
      # Right therefore becomes the next input operation and must focus file 9
      # without another selection or document load appearing first.
      zpty -w -n burst "$key_right"
      _burst_until "FRAME|9|9|1" || exit 11
      [[ ${(j:,:)loads} == 1,9 ]] || {
        print -u2 -r -- "unread arrow tail followed the final load: ${(j:,:)loads}"
        exit 12
      }

      # Repeat the same contract with Terminal.app-like transport cadence.
      # The 80 ms sleeps only deliver bytes inside the 120 ms quiet
      # window; assertions remain event/order based rather than performance
      # thresholds. No intermediate file may resolve while input continues.
      zpty -w -n burst "$key_left"
      _burst_until "FRAME|9|9|0" || exit 13
      repeat 5; do
        zpty -w -n burst "$key_down"
        command sleep 0.08
      done
      _burst_until "LOAD|14|14" || exit 14
      _burst_until "FRAME|14|14|0" || exit 15
      [[ ${(j:,:)loads} == 1,9,14 ]] || {
        print -u2 -r -- "paced repeat resolved intermediate documents: ${(j:,:)loads}"
        exit 16
      }
      zpty -w -n burst "$key_right"
      _burst_until "FRAME|14|14|1" || exit 17
      [[ ${(j:,:)loads} == 1,9,14 ]] || {
        print -u2 -r -- "paced repeat left an unread movement tail: ${(j:,:)loads}"
        exit 18
      }
      zpty -w -n burst "$key_abort"
      _burst_until "DONE|1" || exit 19
      [[ $trace != *"read-only variable"* && $trace != *"bad math expression"* ]] || exit 20
    } always {
      zpty -d burst 2>/dev/null
      exec {efd}>&-
    }
    print burst-settled
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal burst-settled "$output"
}
test_case 'Git review coalesces buffered and paced arrow bursts with no unread movement tail' \
  _test_git_review_native_burst_settle

# The prepaint callback must never get ahead of terminal input that Zsh can
# already return. Queue two complete Down sequences while the child is held at
# a gate, then start the real picker loop. The first two frames may show the
# intermediate selections, but the deliberately slow optional callback must
# run exactly once and only for the final selection after both keys are read.
# Sleep makes an accidental callback expensive enough to expose in manual
# traces; correctness is asserted solely from event order and callback count.
_test_git_review_native_queued_input_precedes_idle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.ui"
    source "$1/.zsh.addons/support/.zsh.matching"
    source "$1/.zsh.addons/support/.zsh.appearance"
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events" "$HOME/gate" || exit 1
    exec {efd}<> "$HOME/events" || exit 2
    exec {gfd}<> "$HOME/gate" || exit 3

    _queued_collect() {
      _ZLE_PICKER_RESULTS=(one two three)
      _ZLE_PICKER_LABELS=(one.swift two.swift three.swift)
    }
    _queued_idle() {
      (( ++idle_calls ))
      print -r -u $efd -- "IDLE|$_ZLE_PICKER_SELECTED|$idle_calls"
      command sleep 0.15
      return 2
    }
    _zle_picker_show() {
      print -r -u $efd -- "FRAME|$_ZLE_PICKER_SELECTED"
    }
    _queued_driver() {
      command stty rows 30 cols 120
      local -i _ZLE_PICKER_SESSION=1 _ZLE_PICKER_DOCUMENT=0 idle_calls=0
      local _ZLE_PICKER_COLLECTOR=_queued_collect
      local _ZLE_PICKER_IDLE_CALLBACK=_queued_idle
      local -A _ZLE_PICKER_INSPECT_TEXTS=()
      print -r -u $efd READY
      local go=""
      IFS= read -r -u $gfd go || return 90
      [[ $go == GO ]] || return 91
      _zle_picker_loop "" 10 1 0
      print -r -u $efd -- "DONE|$?|$idle_calls"
    }
    _queued_event() {
      local chunk=""
      while zselect -r $efd $pfd -t 500; do
        while zpty -r queued chunk; do trace+=$chunk; done
        IFS= read -r -t 0 -u $efd event && return 0
      done
      print -u2 -r -- "queued-input event timed out after ${(qqq)event}"
      return 1
    }
    _queued_expect() {
      local wanted=$1
      _queued_event || return
      events+=($event)
      [[ $event == "$wanted" ]] || {
        print -u2 -r -- "expected $wanted; got ${(qqq)event}; events=${(j:,:)events}"
        return 1
      }
    }

    local trace="" event="" pfd=0 key_down="" key_abort=""
    local -a events=()
    printf -v key_down "\\033[B"
    printf -v key_abort "\\007"
    zpty -b queued _queued_driver || exit 4
    pfd=$REPLY
    {
      _queued_expect READY || exit 5
      # The child cannot touch the picker until both sequences are buffered.
      zpty -w -n queued "$key_down$key_down"
      print -r -u $gfd GO
      _queued_expect "FRAME|1" || exit 6
      _queued_expect "FRAME|2" || exit 7
      _queued_expect "IDLE|3|1" || exit 8
      _queued_expect "FRAME|3" || exit 9
      zpty -w -n queued "$key_abort"
      _queued_expect "DONE|1|1" || exit 10
    } always {
      zpty -d queued 2>/dev/null
      exec {efd}>&-
      exec {gfd}>&-
    }
    print queued-before-idle
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal queued-before-idle "$output"
}
test_case 'Git review consumes queued navigation before optional idle prepaint work' \
  _test_git_review_native_queued_input_precedes_idle
