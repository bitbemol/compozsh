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
