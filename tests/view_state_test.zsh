# View state ends with its view: configuration, results, labels and bookmarks
# are scoped to the journey that opened them (SECURITY.md, engineering/zsh.md).

# Each journey's names, types and values, plus REPLY, are compared with a
# snapshot taken before it opened; the scripted picker follows the engine's
# protocol (tests/picker_support.zsh), so the views' own scoping is what runs.
_test_view_state_files_journeys() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/tree/alpha/inner" "$TEST_TMP_DIR/home/tree/beta" || return
  test_write_file "$TEST_TMP_DIR/home/tree/notes.txt" 'names only' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    source "$1/tests/picker_support.zsh"
    builtin cd -- "$HOME" || exit
    dirstack=("$HOME/tree" "$HOME/tree/beta")
    # Sorted: the listing follows the parameter table, not declaration order.
    _view_state_snapshot() {
      local -a lines=("${(@f)$(typeset -p -m "_ZLE_PICKER_*")}")
      print -rl -- "${(@o)lines}"
      typeset -p REPLY
    }
    local REPLY=unchanged before="" after="" journey=""
    local -a old=() new=() changed=() dropped=()
    local -i result=0
    # Install the scripted engine before taking the baseline.
    test_picker_script cancel
    before=$(_view_state_snapshot)
    for journey in browse-cancel browse-accept browse-descend browse-actions-back \
        recents-cancel recents-accept recents-to-browse; do
      case $journey in
        (browse-cancel) test_picker_script cancel ;;
        (browse-accept) test_picker_script select "~/tree/alpha/" ;;
        (browse-descend) test_picker_script select "~/tree/alpha/" descend -- cancel ;;
        (recents-cancel) test_picker_script cancel ;;
        (recents-accept) test_picker_script select "$HOME/tree" ;;
        (browse-actions-back) test_picker_script select "~/tree/beta/" actions -- cancel -- cancel ;;
        (recents-to-browse)
          test_picker_script select "$HOME/tree" actions -- select view-browse -- cancel -- \
            select "$HOME/tree/beta" ;;
      esac
      result=0
      if [[ $journey == recents-* ]]; then
        _directory_browser_session ./ insert command recents || result=$?
      else
        _directory_browser_session "~/tree/" insert command || result=$?
      fi
      after=$(_view_state_snapshot)
      old=("${(@f)before}") new=("${(@f)after}")
      changed=("${(@)new:|old}") dropped=("${(@)old:|new}")
      if [[ $after == "$before" ]]; then
        print -r -- "${journey}:${result}:released"
      else
        print -r -- "${journey}:${result}:kept ${(j: | :)changed} dropped ${(j: | :)dropped}"
      fi
    done
  ' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal 'browse-cancel:1:released
browse-accept:0:released
browse-descend:1:released
browse-actions-back:1:released
recents-cancel:1:released
recents-accept:0:released
recents-to-browse:0:released' "$output"
}
test_case 'view state: Browse and Recents leave no picker configuration, results or bookmark behind' \
  _test_view_state_files_journeys

# Search runs inside the Files journey; bare g and the tool explorer require a
# terminal, so they run in a PTY with the same scripted engine and snapshots,
# which also cover the branch catalog that g captures for its view.
_test_view_state_search_branch_help_journeys() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/tree/alpha/inner" "$TEST_TMP_DIR/home/tree/beta" || return
  test_write_file "$TEST_TMP_DIR/home/tree/notes.txt" 'names only' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    source "$1/.zshrc"
    source "$1/tests/picker_support.zsh"
    source "$1/tests/pty_support.zsh" || exit
    local repo="$HOME/repository"
    command git init -qb main "$repo" || exit
    command git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid \
      -c commit.gpgsign=false commit --allow-empty -qm first || exit
    command git -C "$repo" branch feature || exit
    builtin cd -- "$HOME" || exit
    dirstack=("$HOME/tree")
    _view_state_snapshot() {
      local -a lines=("${(@f)$(typeset -p -m "(_ZLE_PICKER|_NAVIGATION_PICKER|_GIT_RECENT)_*")}")
      print -rl -- "${(@o)lines}"
      typeset -p REPLY
    }
    # A query view returns the submitted text; the scripted engine selects a
    # result its collector returned, so the step offers the text first.
    _view_state_offer() { _ZLE_PICKER_RESULTS=("$1") _ZLE_PICKER_LABELS=("$1"); }
    _view_state_compare() {
      local after=$(_view_state_snapshot)
      local -a old=("${(@f)before}") new=("${(@f)after}")
      local -a changed=("${(@)new:|old}") dropped=("${(@)old:|new}")
      if [[ $after == "$before" ]]; then
        print -r -- "${journey}:${result}:released"
      else
        print -r -- "${journey}:${result}:kept ${(j: | :)changed} dropped ${(j: | :)dropped}"
      fi
    }
    _view_state_journeys() {
      local REPLY=unchanged before="" journey=""
      local -i result=0
      test_picker_script cancel
      before=$(_view_state_snapshot)
      for journey in $@; do
        case $journey in
          (search-cancel)
            test_picker_script select "~/tree/alpha/" search-local -- \
              observe _view_state_offer alpha -- select alpha -- cancel -- cancel ;;
          (search-accept)
            test_picker_script select "~/tree/alpha/" search-local -- \
              observe _view_state_offer alpha -- select alpha -- select "${HOME:A}/tree/alpha" ;;
          (search-file-actions)
            test_picker_script select "~/tree/alpha/" search-local -- \
              observe _view_state_offer notes -- select notes -- \
              select "${HOME:A}/tree/notes.txt" -- cancel -- cancel -- cancel ;;
          (recents-to-search)
            test_picker_script select "$HOME/tree" actions -- select search-local -- \
              observe _view_state_offer alpha -- select alpha -- cancel -- cancel ;;
          (g-cancel) test_picker_script cancel ;;
          (g-accept) test_picker_script select feature ;;
          (tools-cancel) test_picker_script cancel ;;
          (tools-read) test_picker_script select g -- select 1 -- cancel -- cancel -- cancel ;;
          (help-direct) test_picker_script select 1 -- cancel -- cancel ;;
        esac
        result=0
        case $journey in
          (recents-*) _directory_browser_session ./ insert command recents || result=$? ;;
          (search-*) _directory_browser_session "~/tree/" insert command || result=$? ;;
          (g-*) builtin cd -- "$repo" && { g || result=$?; }; builtin cd -- "$HOME" ;;
          (tools-*) compozsh || result=$? ;;
          (help-direct) compozsh --help || result=$? ;;
        esac
        _view_state_compare
      done
    }
    _view_state_journeys search-cancel search-accept search-file-actions recents-to-search
    _view_state_terminal() {
      _view_state_journeys g-cancel g-accept tools-cancel tools-read help-direct
      print -r -- VIEW-STATE-DONE
    }
    test_pty_start view-state _view_state_terminal || exit
    {
      test_pty_expect view-state "" VIEW-STATE-DONE 20 || exit
    } always { zpty -d view-state; }
    print -rl -- ${(M)${(f)TEST_PTY_OUTPUT//$'\''\r'\''}:#(g|tools|help)-*}
  ' "$TEST_REPO_ROOT" 2>&1) || return
  test_assert_equal 'search-cancel:1:released
search-accept:0:released
search-file-actions:1:released
recents-to-search:1:released
g-cancel:0:released
g-accept:0:released
tools-cancel:0:released
tools-read:0:released
help-direct:0:released' "$output"
}
test_case 'view state: Search, branches and help browse leave no picker state behind' \
  _test_view_state_search_branch_help_journeys

# The USB image browser, Git review (its menu and the working-changes document)
# and xcode run with the same scripted engine and snapshots. The browser's
# caller owns its REPLY and loop results, as the external-device task does;
# xcode's controller is replaced by one accepting view, so the snapshot pins
# what the xcode invocation owns. g --review and xcode require a terminal.
_test_view_state_usb_review_xcode_journeys() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home/Downloads" "$TEST_TMP_DIR/bin" || return
  test_write_file "$TEST_TMP_DIR/home/Downloads/linux.iso" "${(l:20000::i:)}" || return
  test_write_file "$TEST_TMP_DIR/bin/xcodebuild" $'#!/bin/zsh -f\nexit 0' || return
  command chmod +x "$TEST_TMP_DIR/bin/xcodebuild" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8 GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null
    path=("$2" $path)
    rehash
    source "$1/.zshrc"
    source "$1/tests/picker_support.zsh"
    source "$1/tests/pty_support.zsh" || exit
    local repo="$HOME/repository"
    command git init -qb main "$repo" || exit
    command git -C "$repo" -c user.name=Fixture -c user.email=fixture@example.invalid \
      -c commit.gpgsign=false commit --allow-empty -qm first || exit
    print -r -- changed >| "$repo/notes.txt"
    builtin cd -- "$HOME" || exit
    _view_state_snapshot() {
      local -a lines=("${(@f)$(typeset -p -m "_ZLE_PICKER_*")}")
      print -rl -- "${(@o)lines}"
      typeset -p REPLY
    }
    _view_state_compare() {
      local after=$(_view_state_snapshot)
      local -a old=("${(@f)before}") new=("${(@f)after}")
      local -a changed=("${(@)new:|old}") dropped=("${(@)old:|new}")
      if [[ $after == "$before" ]]; then
        print -r -- "${journey}:${result}:released"
      else
        print -r -- "${journey}:${result}:kept ${(j: | :)changed} dropped ${(j: | :)dropped}"
      fi
    }
    # The task that opens the browser owns what it reads afterwards.
    _view_state_usb_task() {
      local REPLY="" _ZLE_PICKER_ACTION=select _ZLE_PICKER_SELECTED_VALUE=""
      local -a _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=() _ZLE_PICKER_BOOKMARK=()
      local -i _ZLE_PICKER_ACCEPTED=0 _ZLE_PICKER_BOOKMARK_FOCUS=0
      _usb_browse_image_path
    }
    _view_state_xcode_collect() { _ZLE_PICKER_RESULTS=(build) _ZLE_PICKER_LABELS=(Build); }
    _view_state_xcode_view() {
      _ZLE_PICKER_TITLE=Xcode _ZLE_PICKER_COLLECTOR=_view_state_xcode_collect
      _zle_picker_loop "" 10
    }
    _xcode_container_discover() {
      _XCODE_CONTAINERS=(/synthetic/App.xcodeproj) _XCODE_CONTAINER_KINDS=(project)
    }
    _xcode_container_is_current() { return 0; }
    _xcode_workspace_controller() { _zle_ui_view choice _view_state_xcode_view; }
    _view_state_journeys() {
      local REPLY=unchanged before="" journey=""
      local -i result=0
      test_picker_script cancel
      before=$(_view_state_snapshot)
      for journey in $@; do
        case $journey in
          (usb-cancel|review-cancel|xcode-cancel) test_picker_script cancel ;;
          (usb-accept)
            test_picker_script select "${HOME:A}/Downloads/" -- \
              select "${HOME:A}/Downloads/linux.iso" ;;
          (review-working) test_picker_script select working -- cancel -- cancel ;;
          (xcode-accept) test_picker_script select build ;;
        esac
        result=0
        case $journey in
          (usb-*) _view_state_usb_task || result=$? ;;
          (review-*) builtin cd -- "$repo" && { g --review || result=$?; }; builtin cd -- "$HOME" ;;
          (xcode-*) xcode || result=$? ;;
        esac
        _view_state_compare
      done
    }
    _view_state_journeys usb-cancel usb-accept
    _view_state_terminal() {
      _view_state_journeys review-cancel review-working xcode-cancel xcode-accept
      print -r -- VIEW-STATE-DONE
    }
    test_pty_start view-state _view_state_terminal || exit
    {
      test_pty_expect view-state "" VIEW-STATE-DONE 20 || exit
    } always { zpty -d view-state; }
    print -rl -- ${(M)${(f)TEST_PTY_OUTPUT//$'\''\r'\''}:#(review|xcode)-*}
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/bin" 2>&1) || return
  test_assert_equal 'usb-cancel:1:released
usb-accept:0:released
review-cancel:0:released
review-working:0:released
xcode-cancel:0:released
xcode-accept:0:released' "$output"
}
test_case 'view state: USB browse, Git review and xcode leave no picker state behind' \
  _test_view_state_usb_review_xcode_journeys

# Views reach the picker engine only through _zle_ui_view, which scopes every
# view default to its configure function's call (engineering/architecture.md,
# shared behavior ownership). The scan prints one record per statement in
# FILES that names a word of NAMES, skipping comments, function heads and
# ${+functions[...]} capability tests:
#   opens FILE FUNCTION NAME    NAME is _zle_ui_view's configure argument
#   view FILE FUNCTION NAME     FUNCTION is a configure function
#   session FILE FUNCTION NAME  _zle_picker_run given a session controller,
#                               which opens the screen that its views share
#   other FILE:LINE FUNCTION NAME
# Configure functions are the words after `_zle_ui_view KIND`; -c adds them
# to NAMES. Names built at run time ("$callback") are invisible to the scan.
# Usage: _view_state_engine_references [-c] NAMES FILE...
_view_state_engine_references() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  local -i add_configures=0 number=0 start=0 index=0
  [[ $1 == -c ]] && { add_configures=1; shift; }
  local file='' line='' statement='' trimmed='' function_name='' word='' rest=''
  local record='' scan='' kind='' shown=''
  local -a records=() found=() words=() arguments=()
  local -A names=() configures=()
  for word in ${(s: :)1}; do
    names[$word]=1
  done
  shift
  for file in "$@"; do
    number=0 statement='' function_name=''
    for line in "${(@f)$(<"$file")}"; do
      (( ++number ))
      [[ -z $statement ]] && start=$number
      trimmed=${line##[[:space:]]#}
      [[ -z $statement && $trimmed == \#* ]] && continue
      [[ -z $statement && $line == [A-Za-z_][A-Za-z0-9_-]#'() {'* ]] &&
        function_name=${line%%'() {'*}
      if [[ $line == *\\ ]]; then
        statement+="${trimmed%\\} "
        continue
      fi
      statement+=$trimmed
      records+=("${file#$TEST_REPO_ROOT/}"$'\t'$start$'\t'$function_name$'\t'$statement)
      rest=$statement
      while [[ $rest == *_zle_ui_view* ]]; do
        rest=${rest#*_zle_ui_view}
        [[ $rest == (#b)[[:space:]]##[^[:space:]]##[[:space:]]##([A-Za-z_][A-Za-z0-9_]#)(|[^A-Za-z0-9_]*) ]] &&
          configures[$match[1]]=1
      done
      [[ $line == \}* || ( $line == [A-Za-z_]*'() {'* && $line == *'}' ) ]] &&
        function_name=''
      statement=''
    done
  done
  (( add_configures )) && for word in ${(k)configures}; do names[$word]=1; done
  for record in "${records[@]}"; do
    shown=${record%%$'\t'*} rest=${record#*$'\t'}
    start=${rest%%$'\t'*} rest=${rest#*$'\t'}
    function_name=${rest%%$'\t'*} statement=${rest#*$'\t'}
    scan=${statement//functions\[[A-Za-z0-9_]##\]/}
    [[ $scan == [A-Za-z_][A-Za-z0-9_-]#'() {'* ]] && scan=${scan#*'() {'}
    found=()
    for word in ${(s: :)${scan//[^A-Za-z0-9_]/ }}; do
      (( ${+names[$word]} )) && found+=("$word")
    done
    for word in ${(u)found}; do
      if [[ $statement == *_zle_ui_view[[:space:]]##[^[:space:]]##[[:space:]]##$word(|[^A-Za-z0-9_]*) ]]; then
        kind=opens
      elif (( ${+configures[$function_name]} )); then
        kind=view
      else
        kind=other
        if [[ $word == _zle_picker_run ]]; then
          words=(${(z)statement})
          index=${words[(ie)_zle_picker_run]}
          arguments=("${(@)words[index+1,index+5]}")
          (( ${#arguments} == 5 )) && [[ -z ${(M)arguments:#[\;\&\|\)\}]##} &&
            ${arguments[5]} == [A-Za-z_][A-Za-z0-9_]# ]] && kind=session
        fi
      fi
      if [[ $kind == other ]]; then
        print -r -- "other $shown:$start ${function_name:-<top level>} $word"
      else
        print -r -- "$kind $shown $function_name $word"
      fi
    done
  done
}

_test_view_state_engine_calls_go_through_views() {
  emulate -L zsh
  setopt EXTENDED_GLOB
  test_make_temp_dir || return
  local fixture="$TEST_TMP_DIR/.zsh.fixture" found='' expected='' entry='' shown=''
  local -a files=() lines=() helpers=() unexpected=()
  test_write_file "$fixture" '_fixture_open() {
  _zle_ui_view choice _fixture_view "$@"
}
_fixture_view() {
  # A comment that names _zle_picker_loop is not a call.
  (( ${+functions[_zle_picker_loop]} )) || return 1
  _fixture_pick 10
  _zle_picker_loop '"''"' 10
}
_fixture_pick() {
  _zle_picker_loop --bookmark bookmark "$1"
}
_fixture_session() {
  _zle_picker_run 10 '"''"' 1 \
    0 _fixture_controller
}
_fixture_controller() {
  _fixture_open && _fixture_view
}
_fixture_direct() {
  if _zle_picker_loop "$1" 10; then return 0; fi
  REPLY=$(_zle_picker_run 10 '"''"')
}' || return
  found=$(_view_state_engine_references -c '_zle_picker_loop _zle_picker_run _fixture_pick' "$fixture")
  shown=${fixture#$TEST_REPO_ROOT/}
  found=${found//"$shown"/fixture}
  expected='opens fixture _fixture_open _fixture_view
view fixture _fixture_view _fixture_pick
view fixture _fixture_view _zle_picker_loop
other fixture:11 _fixture_pick _zle_picker_loop
session fixture _fixture_session _zle_picker_run
other fixture:18 _fixture_controller _fixture_view
other fixture:21 _fixture_direct _zle_picker_loop
other fixture:22 _fixture_direct _zle_picker_run'
  test_assert_equal "$expected" "$found" 'view entry scan reported the wrong sites' || return

  # Helpers that call the engine inside a view they do not configure. Each
  # entry is FILE FUNCTION; the scan below checks that every reference to it
  # sits in a configure function or in another helper listed here.
  local -a allowed=(
    # One bookmarked pass shared by Browse (_directory_browser_view) and its
    # Folder actions (_directory_browser_actions_view), which configure it.
    '.zsh.addons/.zsh.editor _directory_browser_pick'
    # Bare g's branch session hands its view to Git review, which adds the
    # review options to the view _git_branch_view configured.
    '.zsh.addons/.zsh.git-review _git_review_branch_choose'
    # The tool catalog's session controller: _compozsh_view configures the
    # view and runs it in place or through _zle_picker_run.
    '.zsh.addons/.zsh.help _compozsh_browse_loop'
    # Bare g's session controller, which _git_branch_view runs through
    # _zle_picker_run inside its own view.
    '.zsh.addons/.zsh.navigation _git_branch_session'
    # One pass of the image browser, repeated by _usb_browse_image_path_view
    # inside its own view.
    '.zsh.addons/.zsh.usb _usb_browse_choose'
  )
  helpers=(${allowed##* })
  files=("$TEST_REPO_ROOT/.zshrc" "$TEST_REPO_ROOT"/.zsh.addons/**/.zsh.?*(N.))
  files=(${files:#$TEST_REPO_ROOT/.zsh.addons/support/(ui|cache|compiled)/*})
  (( ${#files} > 40 )) || { test_fail 'peer file inventory is unexpectedly small'; return 1; }
  found=$(_view_state_engine_references -c "_zle_picker_loop _zle_picker_run ${helpers[*]}" "${files[@]}")
  # Guard against a vacuous scan: most views and every workspace session.
  lines=(${(M)${(f)found}:#view * _zle_picker_loop})
  (( ${#lines} >= 20 )) || { test_fail "the scan found only ${#lines} view loops"; return 1; }
  lines=(${(M)${(f)found}:#session *})
  (( ${#lines} >= 10 )) || { test_fail "the scan found only ${#lines} workspace sessions"; return 1; }
  # A direct engine call outside a view must open one through _zle_ui_view.
  for entry in ${(M)${(f)found}:#other * _zle_picker_(loop|run)}; do
    entry=${${entry#other }% *}
    (( ${allowed[(Ie)${entry/:<-> / }]} )) || unexpected+=("$entry")
  done
  (( ! ${#unexpected} )) || {
    test_fail "a peer calls the picker engine outside a _zle_ui_view view (engineering/architecture.md):"$'\n'"${(F)unexpected}"
    return 1
  }
  for entry in "${allowed[@]}"; do
    lines=(${(M)${(f)found}:#other ${entry% *}:<-> ${entry##* } _zle_picker_(loop|run)})
    (( ${#lines} )) ||
      { test_fail "allowlisted engine caller no longer calls the engine: $entry"; return 1; }
  done
  # Allowlisted helpers run only inside views, and configure functions only
  # through _zle_ui_view, so neither runs the engine outside a view's scope.
  for entry in ${${(f)found}:#* _zle_picker_(loop|run)}; do
    if (( ${helpers[(Ie)${entry##* }]} )); then
      [[ $entry == (opens|view)\ * ]] && continue
      [[ $entry == other\ * ]] && (( ${helpers[(Ie)${${entry% *}##* }]} )) && continue
    else
      [[ $entry == opens\ * ]] && continue
    fi
    unexpected+=("$entry")
  done
  (( ! ${#unexpected} )) ||
    test_fail "a view helper or configure function runs outside _zle_ui_view:"$'\n'"${(F)unexpected}"
}
test_case 'view state: peers reach the picker engine only through _zle_ui_view views' \
  _test_view_state_engine_calls_go_through_views
