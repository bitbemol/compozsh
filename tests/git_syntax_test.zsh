# Syntax is optional metadata over an unchanged, read-only review snapshot.
_test_git_syntax_protocol() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-let old = 1\n+let new = 2\n'\''
    _git_review_document_parse
    local original=${(F)_ZLE_PICKER_DOCUMENT_LINES}
    _git_syntax_apply $'\''compozsh-syntax-1\n2 0 3 keyword\n3 10 11 number\ndone'\'' || exit 1
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[2] == "15:18:keyword " ]] || exit 2
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[3] == "25:26:number " ]] || exit 3
    local bad
    for bad in "2 -1 3 keyword" "2 0 99 string" "999 0 1 string" "2 0 3 exec" "1 0 1 keyword" "2 0 3 keyword;evil" "2 00 3 keyword"; do
      _git_syntax_apply $'\''compozsh-syntax-1\n'\''"$bad"$'\''\ndone'\'' && exit 4
      (( !${#_ZLE_PICKER_DOCUMENT_SYNTAX} )) || exit 5
    done
    _git_syntax_apply $'\''compozsh-syntax-1\n2 0 3 keyword'\'' && exit 6
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == "$original" ]] || exit 7
    print protocol
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal protocol "$output"
}
test_case 'Git syntax validates bounded token metadata without changing document text' _test_git_syntax_protocol

_test_git_syntax_native() {
  test_make_temp_dir || return
  local output
  test_write_file "$TEST_TMP_DIR/home/.vimrc" 'call writefile(["unsafe"], expand("~/vim-config-ran"))'
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    # Removed comments must not contaminate the new side. Gaps reset context.
    _GIT_REVIEW_DATA=$'\''@@ -1,3 +1,3 @@\n-/* comment\n-let old = 1\n-*/\n+let new = 42 // note\n+let text = "é界"\n+// vim: set exrc:\n@@ -90 +90 @@\n let last = 7\n'\''
    _git_review_document_parse
    # An unusable temporary prefix proves the provider does not spill source
    # through Zsh here-string temporary files, even if immediately unlinked.
    local TMPPREFIX="$HOME/no-such-directory/source"
    _git_syntax_capture sample.swift
    [[ $_GIT_SYNTAX_NOTE == "Swift syntax · fragments" ]] || { print -u2 -- "$_GIT_SYNTAX_NOTE"; exit 1; }
    _git_syntax_apply "$_GIT_SYNTAX_DATA" || exit 2
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[3] == *:comment* ]] || exit 3
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[5] == *:keyword* && $_ZLE_PICKER_DOCUMENT_SYNTAX[5] == *:number* ]] || exit 4
    [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[6] == *:string* && $_ZLE_PICKER_DOCUMENT_SYNTAX[9] == *:keyword* ]] || exit 5
    [[ ! -e $HOME/vim-config-ran ]] || exit 6
    _git_syntax_capture unknown.wonderlang
    [[ -z $_GIT_SYNTAX_DATA && $_GIT_SYNTAX_NOTE == "plain syntax · unsupported type" ]] || exit 7
    _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+'\''${(l:70000::x:)}
    _git_review_document_parse
    _git_syntax_capture large.swift
    [[ -z $_GIT_SYNTAX_DATA && $_GIT_SYNTAX_NOTE == "plain syntax · size limit" ]] || exit 8
    _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+let text = "é界"\n'\''
    _git_review_document_parse
    export LC_ALL=C
    _git_syntax_capture unicode.swift
    [[ -z $_GIT_SYNTAX_DATA && $_GIT_SYNTAX_NOTE == "plain syntax · UTF-8 locale required" ]] || exit 9
    print native
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native "$output"
}
test_case 'Git syntax uses system Vim on separate source fragments with safe fallbacks' _test_git_syntax_native

_test_git_syntax_render() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=one
    _ZLE_PICKER_DOCUMENT_LINES=($'\''               +\t"é界\e[2J"'\'')
    _ZLE_PICKER_DOCUMENT_ROLES=(success)
    _ZLE_PICKER_DOCUMENT_SYNTAX=(1 "17:25:string ")
    _ZLE_PICKER_INSPECT_TEXTS=(one ready)
    _ZLE_PICKER_RESULTS=(one) _ZLE_PICKER_LABELS=(sample.swift)
    _zle_picker_inspect_prepare one 22
    [[ $_ZLE_PICKER_INSPECT_SYNTAX[1] == "20:21:string " ]] || { print -u2 -- "${(F)_ZLE_PICKER_INSPECT_SYNTAX}"; exit 1; }
    [[ $_ZLE_PICKER_INSPECT_SYNTAX[2] == "0:8:string " ]] || exit 2
    [[ ${(F)_ZLE_PICKER_INSPECT_LINES} != *$'\''\e'\''* ]] || exit 3
    _ZLE_PICKER_SCREEN_ACTIVE=1 COLUMNS=120 LINES=30
    local captured="" original=${(F)_ZLE_PICKER_DOCUMENT_LINES}
    region_highlight=("0 1 bold memo=fixture")
    zle() { captured=${(F)region_highlight}; }
    _zle_picker_render "" 1
    _zle_picker_show
    [[ $captured == *"fg=252,bg=22"* && $captured == *"bg=22,fg=186"* ]] || { print -u2 -- "$captured"; exit 4; }
    _ZLE_PICKER_DOCUMENT_ROLES=(error) _ZLE_PICKER_INSPECT_KEY=""
    _zle_picker_render "" 1
    _zle_picker_show
    [[ $captured == *"fg=252,bg=52"* && $captured == *"bg=52,fg=186"* ]] || { print -u2 -- "removed styles: $captured"; exit 5; }
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == "$original" && ${(F)region_highlight} == "0 1 bold memo=fixture" ]] || { print -u2 -- "document or highlight cleanup changed"; exit 6; }
    _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_INSPECT_KEY=""
    _zle_picker_render "" 1
    _zle_picker_show
    [[ $captured != *bg=52* && $captured != *bg=22* ]] || { print -u2 -- "stale syntax: $captured"; exit 7; }
    print rendered
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal rendered "$output"
}
test_case 'Git syntax survives Unicode tabs control sanitization wrapping and diff backgrounds' _test_git_syntax_render

_test_git_syntax_cache() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -A _git_document_syntax_cache=() _git_document_syntax_notes=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(one.swift two.swift three.swift four.swift five.swift)
    local -a _GIT_REVIEW_KINDS=(unstaged unstaged unstaged staged untracked)
    local -i calls=0
    _git_review_diff_capture() { _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-let old = 1\n+let new = 2\n'\''; _GIT_REVIEW_TRUNCATED=0; }
    _git_syntax_capture() { (( ++calls )); _GIT_SYNTAX_DATA=$'\''compozsh-syntax-1\n2 0 3 keyword\n3 0 3 keyword\ndone'\''; _GIT_SYNTAX_NOTE="Swift syntax · fragments"; }
    _git_review_document_load /fixture 1 "" "" 3
    _git_review_document_load /fixture 2 "" "" 3
    _git_review_document_load /fixture 1 "" "" 3
    (( calls == 2 && ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 2 )) || exit 1
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_RESULTS=(1 2) _ZLE_PICKER_LABELS=(one.swift two.swift)
    _ZLE_PICKER_INSPECT_TEXTS=(1 ready 2 ready) COLUMNS=120 LINES=30
    _zle_picker_render "" 1
    _ZLE_PICKER_INSPECT_OFFSET=1 COLUMNS=100
    _zle_picker_render "" 1
    (( calls == 2 )) || exit 2
    unset "_git_document_cache[1:3]"
    _git_review_document_load /fixture 1 "" "" 3
    (( calls == 3 )) || exit 3
    for index in 3 4 5; do _git_review_document_load /fixture $index "" "" 3; done
    (( ${#_git_document_syntax_cache} == 4 && ${#_git_document_syntax_notes} == 4 )) || exit 4
    [[ $_ZLE_PICKER_SUBTITLE == *"Swift syntax"* ]] || exit 5
    print cached
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal cached "$output"
}
test_case 'Git syntax shares snapshot eviction refresh and provider-free rendering' _test_git_syntax_cache

_test_git_syntax_failure() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/slow.vim" '
    call writefile([string(getpid())], expand("<sfile>:p:h") . "/child-pid")
    while 1
    endwhile
  '
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+let value = 1\n'\''
    _git_review_document_parse
    local _GIT_SYNTAX_SCRIPT="$HOME/slow.vim"
    _git_syntax_capture sample.swift
    [[ $_GIT_SYNTAX_NOTE == "plain syntax · unavailable or time limit" && -z $_GIT_SYNTAX_DATA ]] || exit 1
    [[ -s $HOME/child-pid ]] || exit 2
    local child=$(<"$HOME/child-pid")
    kill -0 $child 2>/dev/null && { print -u2 "syntax process survived timeout"; exit 3; }
    _git_syntax_worker() { return 130; }
    _git_syntax_capture sample.swift
    (( $? == 130 )) || { print -u2 "syntax capture swallowed interrupt"; exit 4; }
    print failure
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal failure "$output"
}
test_case 'Git syntax kills and reaps a timed-out child and preserves interruption' _test_git_syntax_failure

_test_git_syntax_languages() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    local name
    for name in sample.zsh sample.sh sample.json sample.py; do
      case $name in
        (*.zsh|*.sh) _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+echo "hello" # comment\n'\'' ;;
        (*.json) _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+{"name": "hello", "value": 42}\n'\'' ;;
        (*.py) _GIT_REVIEW_DATA=$'\''@@ -0,0 +1 @@\n+value = "hello" # comment\n'\'' ;;
      esac
      _git_review_document_parse
      _git_syntax_capture "$name"
      _git_syntax_apply "$_GIT_SYNTAX_DATA" || { print -u2 -- "$name: $_GIT_SYNTAX_NOTE"; exit 1; }
      [[ $_ZLE_PICKER_DOCUMENT_SYNTAX[2] == *:string* ]] || { print -u2 -- "$name: $_ZLE_PICKER_DOCUMENT_SYNTAX[2]"; exit 2; }
    done
    # An absent provider leaves the review usable in any peer load order.
    unfunction _git_syntax_capture _git_syntax_apply
    local -A _git_document_cache=() _git_document_partial=() _git_document_contexts=() _git_document_anchors=()
    local -a _git_document_order=() _GIT_REVIEW_PATHS=(file.swift) _GIT_REVIEW_KINDS=(unstaged)
    _git_review_diff_capture() { _GIT_REVIEW_DATA=$'\''@@ -1 +1 @@\n-old\n+new\n'\''; _GIT_REVIEW_TRUNCATED=0; }
    _git_review_document_load /fixture 1 "" "" 3 || exit 3
    [[ ${(F)_ZLE_PICKER_DOCUMENT_LINES} == *+new* && ${#_ZLE_PICKER_DOCUMENT_SYNTAX} == 0 ]] || exit 4
    print languages
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal languages "$output"
}
test_case 'Git syntax covers the initial language allowlist and remains optional' _test_git_syntax_languages

_test_git_syntax_zle() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/.zsh.highlighting"
    source "$1/.zsh.addons/.zsh.git-review"
    source "$1/.zsh.addons/.zsh.git-syntax"
    _GIT_REVIEW_DATA=$'\''@@ -1 +1,32 @@\n-let value = 1 // old\n'\''
    repeat 32; do _GIT_REVIEW_DATA+=$'\''+let value = 42 // new\n'\''; done
    _git_review_document_parse
    _git_syntax_capture example.swift
    _git_syntax_apply "$_GIT_SYNTAX_DATA" || exit 1
    _ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_KEY=1
    _ZLE_PICKER_TITLE="Working changes" _ZLE_PICKER_SUBTITLE="Synthetic syntax fixture"
    _ZLE_PICKER_DOCUMENT_TITLE=example.swift _ZLE_PICKER_INSPECT_TEXTS=(1 ready)
    _ZLE_PICKER_INSPECT_ACTION=read _ZLE_PICKER_COLLECTOR=_syntax_collect
    _syntax_collect() { _ZLE_PICKER_RESULTS=(1); _ZLE_PICKER_LABELS=(example.swift); }
    zmodload zsh/zpty
    zmodload zsh/zselect
    command mkfifo "$HOME/events"
    exec {efd}<> "$HOME/events"
    local enter=$terminfo[smcup] leave=$terminfo[rmcup]
    functions -c _zle_picker_show _syntax_original_show
    _zle_picker_show() {
      _syntax_original_show
      if (( _ZLE_PICKER_INSPECT_FOCUS )); then
        [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected-inactive]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} &&
           ${(F)_ZLE_PICKER_DISPLAY} == *" ┃ "* ]] || print -r -u $efd BAD-READER-FOCUS
      else
        [[ ${_ZLE_PICKER_DISPLAY_STYLES[(i)picker-selected]} -le ${#_ZLE_PICKER_DISPLAY_STYLES} &&
           ${(F)_ZLE_PICKER_DISPLAY} == *" │ "* ]] || print -r -u $efd BAD-LIST-FOCUS
      fi
      print -r -u $efd -- "FRAME:$_ZLE_PICKER_INSPECT_FOCUS"
    }
    _syntax_driver() {
      command stty rows 30 cols 120
      _zle_picker_run 10
      [[ $? == 1 && ${_ZLE_PICKER_SCREEN_ACTIVE:-0} == 0 && $_ZLE_PICKER_ACTIVE == 0 ]] || print -u $efd BAD-CLEANUP
      print -u $efd DONE
    }
    local trace="" chunk="" event="" pfd=0
    _syntax_expect() {
      local wanted=$1
      while zselect -r $efd $pfd -t 300; do
        while zpty -r syntax chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $efd event; then
          [[ $event == "$wanted" ]] && return 0
          [[ $event == BAD-* ]] && break
        fi
      done
      print -u2 -- "expected $wanted, got $event"
      return 1
    }
    zpty -b syntax _syntax_driver
    pfd=$REPLY
    {
      _syntax_expect FRAME:0 || exit 2
      zpty -w -n syntax $'\''\t'\''
      _syntax_expect FRAME:1 || exit 3
      zpty -w -n syntax $'\''\e[B'\''
      _syntax_expect FRAME:1 || exit 4
      [[ $trace == *"48;5;22"* && $trace == *"48;5;52"* && $trace == *"38;5;222"* ]] || { print -u2 "native terminal colors missing"; exit 5; }
      [[ $trace == *"$enter"* && ${trace#*"$enter"} != *"$enter"* && $trace != *"$leave"* ]] || exit 6
      zpty -w -n syntax $'\''\e'\''
      _syntax_expect DONE || exit 7
      while zpty -r syntax chunk; do trace+=$chunk; done
      [[ $trace == *"$leave"* ]] || exit 8
      print native-zle
    } always {
      zpty -d syntax 2>/dev/null
      exec {efd}<&-
    }
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native-zle "$output"
}
test_case 'Git syntax renders native ZLE foregrounds and diff backgrounds with pane navigation and cleanup' _test_git_syntax_zle
