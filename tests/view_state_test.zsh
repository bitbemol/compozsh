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
