# Living-prompt state, semantic rendering, and peer-composition contracts.

_test_living_prompt_auto_lens_tracks_exact_project_context() {
  test_make_temp_dir || return
  local plain="$TEST_TMP_DIR/home/plain"
  local first="$TEST_TMP_DIR/home/one/app"
  local second="$TEST_TMP_DIR/home/two/app"
  local output=''

  command mkdir -p -- "$plain" "$first/sub" "$second" || return
  test_write_file "$first/.fixture-project" '' || return
  test_write_file "$second/.fixture-project" '' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    TERM=dumb
    typeset -ga PROMPT_PROJECT_MARKERS=(.fixture-project)
    source "$1/.zsh.addons/.zsh.shell"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    (( ${+functions[_prompt_interaction_update]} )) || {
      print -u2 -r -- "living prompt editing transition is unavailable"
      exit 90
    }

    builtin cd -- "$2" || exit 1
    true; _prompt_update
    [[ $_PROMPT_VIEW == compact && $_PROMPT_LENS_PINNED == 0 ]] || exit 2

    # First entry opens the automatic lens. Its first nonempty edit consumes
    # that one-shot presentation; deleting the draft must not make it bloom
    # again until the semantic context changes.
    builtin cd -- "$3" || exit 3
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 0 ]] || exit 4
    BUFFER=x
    _prompt_interaction_update || exit 5
    [[ $_PROMPT_VIEW == compact && $_PROMPT_LENS_PINNED == 0 ]] || exit 6
    BUFFER=""
    _prompt_interaction_update || :
    [[ $_PROMPT_VIEW == compact ]] || exit 7
    true; _prompt_update
    [[ $_PROMPT_VIEW == compact ]] || exit 8

    # A subdirectory retains the same exact project context. A different root
    # with the same display basename is still a new project and must reopen.
    builtin cd -- "$3/sub" || exit 9
    true; _prompt_update
    [[ $_PROMPT_VIEW == compact ]] || exit 10
    builtin cd -- "$4" || exit 11
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 0 ]] || exit 12
    print -r -- project-context
  ' "$TEST_REPO_ROOT" "$plain" "$first" "$second") || return

  test_assert_equal project-context "$output"
}
test_case 'living prompt auto lens tracks exact project context and stays consumed while unchanged' \
  _test_living_prompt_auto_lens_tracks_exact_project_context

_test_living_prompt_fingerprint_uses_only_high_signal_changes() {
  test_make_temp_dir || return
  local repository="$TEST_TMP_DIR/repository"
  local runtime_project="$TEST_TMP_DIR/runtime"
  local git_only="$TEST_TMP_DIR/git-only"
  local output=''

  command git init -q "$repository" || return
  command git -C "$repository" config user.name 'Zsh Tests' || return
  command git -C "$repository" config user.email 'zsh-tests.invalid@example.invalid' || return
  test_write_file "$repository/.fixture-project" '' || return
  test_write_file "$repository/conflict.txt" baseline || return
  command git -C "$repository" add .fixture-project conflict.txt || return
  command git -C "$repository" commit -qm baseline || return
  command git -C "$repository" branch -M main || return
  command git -C "$repository" switch -qc conflict-side || return
  test_write_file "$repository/conflict.txt" side || return
  command git -C "$repository" add conflict.txt || return
  command git -C "$repository" commit -qm side || return
  command git -C "$repository" switch -q main || return
  test_write_file "$repository/conflict.txt" main || return
  command git -C "$repository" add conflict.txt || return
  command git -C "$repository" commit -qm main || return

  command mkdir -p -- "$runtime_project" || return
  test_write_file "$runtime_project/pyproject.toml" '[project]' || return
  test_write_file "$runtime_project/.python-version" '3.13' || return
  command git init -q "$git_only" || return
  command git -C "$git_only" branch -M main || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    TERM=dumb
    typeset -ga PROMPT_PROJECT_MARKERS=(.fixture-project)
    source "$1/.zsh.addons/.zsh.shell"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    (( ${+functions[_prompt_interaction_update]} )) || exit 90

    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$git_support_component"; done

    _consume_lens() {
      BUFFER=x
      _prompt_interaction_update || return 1
      BUFFER=""
      [[ $_PROMPT_VIEW == compact ]]
    }

    builtin cd -- "$2" || exit 1
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 2
    _consume_lens || exit 3

    # Counts and ordinary dirty-state details are useful compact facts, but are
    # deliberately absent from the high-signal context fingerprint.
    print -r -- one >| untracked-one
    true; _prompt_update
    [[ $_PROMPT_VIEW == compact ]] || exit 4
    print -r -- two >| untracked-two
    true; _prompt_update
    [[ $_PROMPT_VIEW == compact ]] || exit 5

    command git switch -qc feature/raw-state || exit 6
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 7
    _consume_lens || exit 8

    VIRTUAL_ENV="$HOME/venvs/alpha"
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 9
    _consume_lens || exit 10
    VIRTUAL_ENV="$HOME/venvs/beta"
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 11
    _consume_lens || exit 12
    unset VIRTUAL_ENV
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 13
    _consume_lens || exit 14

    # The branch is unchanged here; conflict/operation attention alone reopens.
    command git merge conflict-side >/dev/null 2>&1
    (( $? != 0 )) || exit 15
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 16
    _consume_lens || exit 17

    # A Git repository is meaningful context even when it has no recognized
    # language or project marker and therefore no ordinary project row.
    builtin cd -- "$4" || exit 18
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 19
    _consume_lens || exit 20

    # Runtime attention uses canonical facts rather than colored rendered text.
    typeset -g fixture_runtime=3.13
    _prompt_runtime_version() { REPLY=$fixture_runtime; }
    builtin cd -- "$3" || exit 21
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 22
    _consume_lens || exit 23
    fixture_runtime=not-installed
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 24
    _consume_lens || exit 25
    fixture_runtime=3.12
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 26
    print -r -- high-signal
  ' "$TEST_REPO_ROOT" "$repository" "$runtime_project" "$git_only") || return

  test_assert_equal high-signal "$output"
}
test_case 'living prompt fingerprint reacts to branch environment conflict and runtime attention but not dirt counts' \
  _test_living_prompt_fingerprint_uses_only_high_signal_changes

_test_living_prompt_git_operation_follows_nested_repository() {
  test_make_temp_dir || return
  local outer="$TEST_TMP_DIR/outer"
  local first="$TEST_TMP_DIR/a"
  local second="$TEST_TMP_DIR/b"
  local output=''

  command git init -q "$outer" || return
  command mkdir -p -- "$outer/inner" || return
  command git init -q "$first" || return
  command git init -q "$second" || return
  : >| "$second/.git/MERGE_HEAD" || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    TERM=dumb
    source "$1/.zsh.addons/.zsh.shell"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$git_support_component"; done

    # Visit a plain folder inside the outer repository first, so its Git
    # directory is resolved while the folder is not yet a repository.
    builtin cd -- "$2/inner" || exit 1
    true; _prompt_update

    # A repository initialized in that folder is nearer than the outer one:
    # a merge in the outer repository must not leak into the inner prompt...
    command git init -q . || exit 90
    : >| ../.git/MERGE_HEAD || exit 91
    true; _prompt_update
    [[ -z $_PROMPT_GIT_OPERATION_TEXT && -z $_PROMPT_GIT_ATTENTION ]] || {
      print -u2 -r -- "outer state leaked: [$_PROMPT_GIT_OPERATION_TEXT] [$_PROMPT_GIT_ATTENTION]"
      exit 2
    }

    # ...and an operation in the inner repository itself must be seen.
    : >| .git/REVERT_HEAD || exit 92
    true; _prompt_update
    [[ $_PROMPT_GIT_OPERATION_TEXT == revert ]] || {
      print -u2 -r -- "inner operation missed: [$_PROMPT_GIT_OPERATION_TEXT]"
      exit 3
    }

    # A relative GIT_DIR resolves against the working directory, so folders
    # that share it must not share one resolved Git directory.
    export GIT_DIR=.git
    builtin cd -- "$3" || exit 93
    true; _prompt_update
    builtin cd -- "$4" || exit 94
    true; _prompt_update
    [[ $_PROMPT_GIT_OPERATION_TEXT == merge ]] || {
      print -u2 -r -- "relative GIT_DIR reused another folder: [$_PROMPT_GIT_OPERATION_TEXT]"
      exit 4
    }
    print -r -- nearest-repository
  ' "$TEST_REPO_ROOT" "$outer" "$first" "$second") || return

  test_assert_equal nearest-repository "$output"
}
test_case 'living prompt Git operation follows a repository initialized inside a previously visited folder' \
  _test_living_prompt_git_operation_follows_nested_repository

_test_living_prompt_manual_lens_and_transcript_state() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/home/project"
  local plain="$TEST_TMP_DIR/home/plain"
  local output=''

  command mkdir -p -- "$project" "$plain" || return
  test_write_file "$project/.fixture-project" '' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    TERM=dumb
    typeset -ga PROMPT_PROJECT_MARKERS=(.fixture-project)
    source "$1/.zsh.addons/.zsh.shell"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.editor"
    for capability in _prompt_interaction_update _prompt_toggle_lens _prompt_prepare_transcript; do
      (( ${+functions[$capability]} )) || exit 90
    done

    builtin cd -- "$2" || exit 1
    true; _prompt_update
    BUFFER=x; _prompt_interaction_update || exit 2

    BUFFER="draft value" CURSOR=3 MARK=1
    PREDISPLAY=prefix POSTDISPLAY=suffix
    region_highlight=("0 1 bold memo=fixture")
    _prompt_toggle_lens || exit 3
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 1 ]] || exit 4
    _prompt_interaction_update || :
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 1 &&
       $BUFFER == "draft value" && $CURSOR == 3 && $MARK == 1 &&
       $PREDISPLAY == prefix && $POSTDISPLAY == suffix &&
       ${(j: :)region_highlight} == "0 1 bold memo=fixture" ]] || exit 5
    _prompt_toggle_lens || exit 6
    [[ $_PROMPT_VIEW == compact && $_PROMPT_LENS_PINNED == 0 &&
       $BUFFER == "draft value" && $CURSOR == 3 ]] || exit 7

    # The manual lens remains useful outside a recognized project.
    builtin cd -- "$3" || exit 8
    true; _prompt_update
    [[ $_PROMPT_VIEW == compact ]] || exit 9
    _prompt_toggle_lens || exit 10
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 1 ]] || exit 11
    local lens=$(print -P -r -- "$PROMPT")
    [[ $lens == *CONTEXT* && $lens == *PATH* &&
       $lens == *"Option-I"* && $lens == *"❯"* ]] || exit 12

    local command_text='"'"'print "safe % value"'"'"'
    BUFFER=$command_text
    _prompt_prepare_transcript || exit 13
    [[ $_PROMPT_VIEW == transcript && $_PROMPT_LENS_PINNED == 0 &&
       $PROMPT == '"'"'%D{%H:%M} › '"'"' && -z $RPROMPT &&
       $BUFFER == "$command_text" ]] || exit 14
    local transcript=$(print -P -r -- "$PROMPT")
    [[ $transcript == [0-9][0-9]:[0-9][0-9]'"'"' › '"'"' ]] || exit 15

    true; _prompt_update
    [[ $_PROMPT_VIEW == compact && -z $RPROMPT ]] || exit 16

    # Empty and whitespace-only submissions use the same literal receipt.
    local blank=""
    for blank in "" "   " $'"'"'\t'"'"'; do
      BUFFER=$blank
      _prompt_prepare_transcript || { print -u2 "blank submission refused receipt"; exit 17; }
      [[ $_PROMPT_VIEW == transcript && $PROMPT == '"'"'%D{%H:%M} › '"'"' &&
         -z $RPROMPT && $BUFFER == "$blank" ]] || exit 18
    done
    print -r -- manual-transcript
  ' "$TEST_REPO_ROOT" "$project" "$plain") || return

  test_assert_equal manual-transcript "$output"
}
test_case 'living prompt manual lens preserves editing and transcript uses one exact inert prefix' \
  _test_living_prompt_manual_lens_and_transcript_state

_test_living_prompt_standalone_and_noninteractive_fallbacks() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/home/project" output='' noninteractive=''
  command mkdir -p -- "$project" || return
  test_write_file "$project/.fixture-project" '' || return

  noninteractive=$(test_run_noninteractive "$TEST_TMP_DIR/noninteractive" '
    source "$1/.zshrc"
    print -r -- "${+functions[_prompt_update]}|${+functions[_prompt_toggle_lens]}|${+functions[_zle_prompt_pre_redraw]}"
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal '0|0|0' "$noninteractive" \
    'noninteractive bootstrap installed living-prompt capabilities' || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    TERM=dumb
    unset SSH_CONNECTION SSH_TTY
    typeset -ga PROMPT_PROJECT_MARKERS=(.fixture-project)
    source "$1/.zsh.addons/.zsh.shell"
    source "$1/.zsh.addons/.zsh.prompt"
    builtin cd -- "$2" || exit 1
    true; _prompt_update
    [[ $_PROMPT_VIEW == compact && $_PROMPT_LENS_PINNED == 0 &&
       -z $RPROMPT && $PROMPT == *$'"'"'\n'"'"'* ]] || exit 2
    local rendered=""
    print -P -v rendered -r -- "$PROMPT"
    (( ${#${(f)rendered}} == 2 )) && [[ $rendered == *"❯"* ]] || exit 3
    [[ $_PROMPT_CONTEXT_SEGMENT == *$_PROMPT_PATH_TEXT* ]] || exit 4
    if (( EUID != 0 )); then
      [[ $_PROMPT_CONTEXT_SEGMENT != *$_PROMPT_IDENTITY_TEXT* ]] || exit 5
    fi
    (( ! ${+functions[_zle_prompt_pre_redraw]} &&
       ! ${+functions[_zle_prompt_line_finish]} )) || exit 6
    print -r -- standalone-compact
  ' "$TEST_REPO_ROOT" "$project") || return

  test_assert_equal standalone-compact "$output"
}
test_case 'living prompt stays inert noninteractively and compact without its editor capability' \
  _test_living_prompt_standalone_and_noninteractive_fallbacks

_test_living_prompt_outcome_receipt_policy() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    TERM=dumb
    source "$1/.zsh.addons/.zsh.prompt"
    (( ${+functions[_prompt_outcome_receipt]} )) || exit 90

    local fast_success="" rounded_fast_success="" slow_success=""
    local fast_failure="" slow_failure=""
    local -i fast_success_status=0 rounded_fast_success_status=0 slow_success_status=0
    local -i fast_failure_status=0 slow_failure_status=0
    fast_success=$(_prompt_outcome_receipt 0 0.4)
    fast_success_status=$?
    rounded_fast_success=$(_prompt_outcome_receipt 0 1.96)
    rounded_fast_success_status=$?
    slow_success=$(_prompt_outcome_receipt 0 2.3)
    slow_success_status=$?
    fast_failure=$(_prompt_outcome_receipt 7 0.4)
    fast_failure_status=$?
    slow_failure=$(_prompt_outcome_receipt 9 2.3)
    slow_failure_status=$?

    [[ -z $fast_success && $fast_success_status == 1 &&
       -z $rounded_fast_success && $rounded_fast_success_status == 1 &&
       $slow_success == "✓ 2.3s" && $slow_success_status == 0 &&
       $fast_failure == "× exit 7" && $fast_failure_status == 0 &&
       $slow_failure == "× exit 9 · 2.3s" && $slow_failure_status == 0 ]] || {
      print -u2 -r -- "unexpected outcome policy: ${(qqq)fast_success}:$fast_success_status|${(qqq)rounded_fast_success}:$rounded_fast_success_status|${(qqq)slow_success}:$slow_success_status|${(qqq)fast_failure}:$fast_failure_status|${(qqq)slow_failure}:$slow_failure_status"
      exit 1
    }

    # Re-sourcing while an accepted compound command is running must retain
    # the preexec timestamp so that command can still receive its outcome.
    _PROMPT_COMMAND_STARTED=42.5
    source "$1/.zsh.addons/.zsh.prompt"
    (( _PROMPT_COMMAND_STARTED == 42.5 )) || exit 2

    # A forced interactive shell without a terminal must never receive prompt
    # titles or receipts on stdout. Those bytes belong only to a terminal.
    TERM=xterm-256color
    _prompt_command_started fixture-command
    _PROMPT_COMMAND_STARTED=$(( EPOCHREALTIME - 3.0 ))
    false
    _prompt_update
    print -r -- outcome-policy
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal outcome-policy "$output"
}
test_case 'living prompt outcome receipt appears only for slow success or any failure' \
  _test_living_prompt_outcome_receipt_policy

# Float conversion of inherited text evaluates arithmetic, including $(...) in
# a subscript; only the prompt's own running-command timestamp survives.
_test_living_prompt_discards_inherited_command_start() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export _PROMPT_COMMAND_STARTED='"'"'path[$(: >| $HOME/substituted)1]'"'"'
    source "$1/.zsh.addons/.zsh.prompt" || print -r -- "load failed"
    [[ ! -e $HOME/substituted ]] || print -r -- "inherited start ran a command substitution"
    print -r -- "${(t)_PROMPT_COMMAND_STARTED} $(( _PROMPT_COMMAND_STARTED ))"
    unset _PROMPT_COMMAND_STARTED
    export _PROMPT_COMMAND_STARTED=1234.5
    source "$1/.zsh.addons/.zsh.prompt"
    print -r -- "${(t)_PROMPT_COMMAND_STARTED} $(( _PROMPT_COMMAND_STARTED ))"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
float 0.
float 0.' "status:$exit_status"$'\n'"$output" \
    'living prompt evaluated or kept an inherited command start'
}
test_case 'living prompt discards an inherited command start without evaluating it' \
  _test_living_prompt_discards_inherited_command_start

# An inherited EPOCHREALTIME stops zsh/datetime from loading and stays plain
# text; command timing must then be skipped rather than evaluate that text.
_test_living_prompt_never_times_with_inherited_epoch() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export EPOCHREALTIME='"'"'path[$(: >| $HOME/epoch-marker)1]'"'"'
    source "$1/.zsh.addons/.zsh.prompt" 2>/dev/null
    _prompt_command_started fixture-command
    print -r -- "started:$(( _PROMPT_COMMAND_STARTED ))"
    false
    _prompt_update
    print -r -- "outcome:${_PROMPT_LAST_OUTCOME_TEXT:-none}"
    local -a markers=($HOME/*-marker(N)); print -r -- "markers:${#markers}"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
started:0.
outcome:none
markers:0' "status:$exit_status"$'\n'"$output" \
    'the living prompt evaluated an inherited EPOCHREALTIME'
}
test_case 'living prompt never times commands with an inherited EPOCHREALTIME' \
  _test_living_prompt_never_times_with_inherited_epoch

# An alias named like the documented extension API would expand in its
# definition and abort the rest of the peer, so the hooks would never register.
_test_living_prompt_loads_after_extension_api_alias() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    alias prompt_add_project_segment="print aliased"
    source "$1/.zsh.addons/.zsh.prompt"
    print -r -- "load:$?"
    print -r -- "hook:$(( ${precmd_functions[(Ie)_prompt_update]:-0} > 0 )) function:${+functions[prompt_add_project_segment]} alias:${+aliases[prompt_add_project_segment]}"
    REPLY=""
    prompt_add_project_segment x white
    print -r -- "segment:$REPLY"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
load:0
hook:1 function:1 alias:0
segment:%F{white}x%f' "status:$exit_status"$'\n'"$output" \
    'a same-name alias aborted the living prompt peer'
}
test_case 'living prompt peer loads after a same-name alias of its extension API' \
  _test_living_prompt_loads_after_extension_api_alias

# The running-command title is a second display of the draft; it names only
# the command word and fails closed to the identity when that word is unknown.
_test_living_prompt_title_omits_assignment_values() {
  test_make_temp_dir || return
  local output='' exit_status=0
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_is_assignment"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/tests/pty_support.zsh" || exit 90
    _test_title() {
      local out="" title=""
      test_pty_start prompt-title "_prompt_command_started ${(q)1}; print -rn -- END; sleep 1" || return
      test_pty_expect prompt-title "" END || :
      out=$TEST_PTY_OUTPUT
      zpty -d prompt-title
      title=${${out#*$'"'"'\e]0;'"'"'}%%$'"'"'\a'"'"'*}
      [[ $out == *$'"'"'\e]0;'"'"'* ]] || title="no title"
      print -r -- "[${title#${(%):-%n@%m}}]"
    }
    _test_title "API_TOKEN=fixture-secret-value true"
    _test_title "FOO=bar BAZ=qux print ok"
    _test_title "secrets=(fixture-array-value)"
    _test_title "FOO=fixture-chain-value; true"
    _test_title "make test"
    unfunction _compozsh_is_assignment
    _test_title "make test"
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 'status:0
[: true]
[: print]
[]
[]
[: make]
[]' "status:$exit_status"$'\n'"$output" \
    'the running-command title repeated an assignment value or guessed a command'
}
test_case 'living prompt running-command title never repeats leading assignment values' \
  _test_living_prompt_title_omits_assignment_values

_test_living_prompt_interaction_lens_ready_morphs_and_returns_to_base() {
  test_make_temp_dir || return
  local project="$TEST_TMP_DIR/home/project" output=''

  command mkdir -p -- "$project" || return
  test_write_file "$project/.fixture-project" '' || return
  command git init -q "$project" || return
  command git -C "$project" config user.name 'Zsh Tests' || return
  command git -C "$project" config user.email 'zsh-tests.invalid@example.invalid' || return
  command git -C "$project" add .fixture-project || return
  command git -C "$project" commit -qm baseline || return
  command git -C "$project" branch -M main || return

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE PROMPT_SUBST PROMPT_BANG
    TERM=dumb COLUMNS=120 LINES=30
    typeset -ga PROMPT_PROJECT_MARKERS=(.fixture-project)
    source "$1/.zsh.addons/.zsh.shell"
    source "$1/.zsh.addons/.zsh.prompt"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    source "$1/.zsh.addons/.zsh.editor"

    for git_support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.compozsh_git_*(N.) "$1/.zsh.addons/support/functions"/.zsh.impure.compozsh_capture_bounded(N.); do source "$git_support_component"; done

    _focus_render() {
      _prompt_interaction_update || :
      print -P -v REPLY -r -- "$PROMPT"
    }
    _focus_has_row() {
      local rendered=$1 label=$2 value=$3 row=''
      for row in "${(f)rendered}"; do
        [[ $row == *"│"*"$label"*"$value"* ]] && return 0
      done
      print -u2 -r -- "missing $label row containing ${(qqq)value}: ${(V)rendered}"
      return 1
    }
    _focus_has_advisory_action() {
      local rendered=$1 row=''
      for row in "${(f)rendered}"; do
        [[ $row == *"│"*ACTION* ]] || continue
        [[ ${row:l} == *likely* || ${row:l} == *appears* || ${row:l} == *may* ]] && return 0
      done
      print -u2 -r -- "interaction ACTION was presented as fact: ${(V)rendered}"
      return 1
    }
    _focus_require_frame() {
      local rendered=$1 mode=$2
      local -a rows=("${(@f)rendered}")
      [[ $rows[1] == *"╭─ ${mode}"* &&
         $rows[-1] == *"╰─ "* && $rows[-1] == *"❯"* ]] || {
        print -u2 -r -- "bad $mode interaction frame: ${(V)rendered}"
        return 1
      }
      (( ${#rows} > 2 )) || {
        print -u2 -r -- "$mode interaction lens had no useful fact rows"
        return 1
      }
      local openings=${rendered//[^╭]/}
      (( ${#openings} == 1 )) || {
        print -u2 -r -- "$mode painted more than one active prompt: ${(V)rendered}"
        return 1
      }
    }

    builtin cd -- "$2" || exit 1
    true; _prompt_update
    [[ $_PROMPT_VIEW == lens ]] || exit 2
    BUFFER=x; CURSOR=1
    _prompt_interaction_update || exit 3

    # The base interaction lens retains the last command outcome as captured
    # prompt state. It does not need to poll after the command has completed.
    BUFFER="" CURSOR=0
    _PROMPT_COMMAND_STARTED=$EPOCHREALTIME
    false
    _prompt_update
    [[ $_PROMPT_VIEW == compact ]] || exit 4
    local ready=''
    print -P -v ready -r -- "$PROMPT"
    _focus_require_frame "$ready" READY || exit 5
    _focus_has_row "$ready" PROJECT project || exit 6
    _focus_has_row "$ready" PATH "~/project" || exit 7
    _focus_has_row "$ready" GIT main || exit 8
    _focus_has_row "$ready" LAST "× exit 1" || exit 9

    # Editing turns the same active prompt into an operation-specific lens.
    # Returning to an empty buffer removes inferred rows and restores READY.
    BUFFER='"'"'printf hello'"'"'; CURSOR=${#BUFFER}
    _focus_render
    local running=$REPLY
    _focus_require_frame "$running" RUN || exit 10
    _focus_has_row "$running" "COMMAND TEXT" printf || exit 11
    _focus_has_advisory_action "$running" || exit 12
    _focus_has_row "$running" PROJECT project || exit 13

    BUFFER="" CURSOR=0
    _focus_render
    local restored=$REPLY
    _focus_require_frame "$restored" READY || exit 14
    _focus_has_row "$restored" LAST "× exit 1" || exit 15
    [[ $restored != *COMMAND\ TEXT* && $restored != *ACTION* &&
       $restored != *ARGUMENT\ TEXT* && $restored != *QUERY\ TEXT* &&
       $restored != *ENDPOINT\ TEXT* && $restored != *OUTPUT\ TEXT* ]] || exit 16

    _prompt_toggle_lens || exit 28
    local pinned_ready=''
    print -P -v pinned_ready -r -- "$PROMPT"
    [[ $pinned_ready == *CONTEXT* && $pinned_ready != *"├─ READY"* ]] || exit 29
    _prompt_toggle_lens || exit 30

    # Manual disclosure remains reversible and preserves the live buffer.
    BUFFER='"'"'git status'"'"'; CURSOR=4
    _focus_render
    _prompt_toggle_lens || exit 17
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 1 &&
       $BUFFER == '"'"'git status'"'"' && $CURSOR == 4 ]] || exit 18
    local disclosed=''
    print -P -v disclosed -r -- "$PROMPT"
    [[ $disclosed == *CONTEXT* && $disclosed == *PATH* &&
       $disclosed == *GIT* && $disclosed == *status* &&
       $disclosed == *"❯"* ]] || exit 19

    # Pinning Context does not freeze the interaction portion of the prompt.
    BUFFER='"'"'git diff --stat'"'"'; CURSOR=${#BUFFER}
    _prompt_interaction_update || :
    [[ $_PROMPT_VIEW == lens && $_PROMPT_LENS_PINNED == 1 ]] || exit 26
    print -P -v disclosed -r -- "$PROMPT"
    [[ $disclosed == *CONTEXT* && $disclosed == *diff* &&
       $disclosed != *"OPERATION TEXT"*status* ]] || exit 27
    _prompt_toggle_lens || exit 20
    [[ $_PROMPT_VIEW == compact && $_PROMPT_LENS_PINNED == 0 &&
       $BUFFER == '"'"'git diff --stat'"'"' && $CURSOR == ${#BUFFER} ]] || exit 21
    local resumed=''
    print -P -v resumed -r -- "$PROMPT"
    _focus_require_frame "$resumed" GIT || exit 22

    # Acceptance leaves exactly the fixed inert prefix and unchanged BUFFER;
    # no part of an interaction lens is copied into scrollback.
    _prompt_prepare_transcript || exit 23
    [[ $_PROMPT_VIEW == transcript && $PROMPT == '"'"'%D{%H:%M} › '"'"' &&
       -z $RPROMPT && $BUFFER == '"'"'git diff --stat'"'"' &&
       $CURSOR == ${#BUFFER} ]] || exit 24
    local transcript=''
    print -P -v transcript -r -- "$PROMPT"
    [[ $transcript == [0-9][0-9]:[0-9][0-9]'"'"' › '"'"' &&
       $transcript != *[╭│╰]* && $transcript != *READY* &&
       $transcript != *ACTION* ]] || exit 25
    print -r -- interaction-base
  ' "$TEST_REPO_ROOT" "$project") || return

  test_assert_equal interaction-base "$output"
}
test_case 'living prompt interaction lens morphs in real time and restores cached READY context' \
  _test_living_prompt_interaction_lens_ready_morphs_and_returns_to_base

_test_living_prompt_interaction_lenses_cover_local_work_intents() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE PROMPT_SUBST PROMPT_BANG
    TERM=dumb COLUMNS=140 LINES=30
    source "$1/.zsh.addons/.zsh.prompt"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done

    # Establish one captured snapshot. Every edit below must derive only from
    # these exact facts and the literal BUFFER.
    _PROMPT_VIEW=compact
    _PROMPT_PATH_TEXT="~/project"
    _PROMPT_FULL_PATH_TEXT="~/project"
    _PROMPT_PROJECT_ROOT_TEXT="$HOME/project"
    _PROMPT_PROJECT_NAME_TEXT=project
    _PROMPT_GIT_TEXT='"'"'main ✓'"'"'
    _PROMPT_GIT_BRANCH_TEXT=main
    _PROMPT_GIT_UPSTREAM_TEXT=origin/main
    _PROMPT_PROJECT_ITEMS=('"'"'swift 6.4'"'"' swiftpm)
    _PROMPT_PROJECT_ITEM_WIDTHS=(9 7)
    _PROMPT_ENV_TEXT=existing-env
    _PROMPT_ENV_KEY="venv:$HOME/venvs/existing-env"
    _prompt_layout
    _prompt_base

    _focus_render() {
      BUFFER=$1 CURSOR=${#1}
      _prompt_interaction_update || :
      print -P -v REPLY -r -- "$PROMPT"
    }
    _focus_row() {
      local rendered=$1 label=$2 value=$3 row=''
      for row in "${(f)rendered}"; do
        [[ $row == *"│"*"$label"*"$value"* ]] && return 0
      done
      print -u2 -r -- "missing exact $label fact ${(qqq)value}: ${(V)rendered}"
      return 1
    }
    _focus_advisory() {
      local rendered=$1 row=''
      for row in "${(f)rendered}"; do
        [[ $row == *"│"*ACTION* ]] || continue
        [[ ${row:l} == *likely* || ${row:l} == *appears* || ${row:l} == *may* ]] && return 0
      done
      print -u2 -r -- "missing advisory ACTION row: ${(V)rendered}"
      return 1
    }
    _focus_case() {
      local buffer=$1 mode=$2 label=$3 exact=$4 rendered=''
      _focus_render "$buffer"; rendered=$REPLY
      local -a rows=("${(@f)rendered}")
      [[ $rows[1] == *"╭─ ${mode}"* &&
         $rows[-1] == *"╰─ "* && $rows[-1] == *"❯"* ]] || {
        print -u2 -r -- "wrong interaction mode $mode: ${(V)rendered}"
        return 1
      }
      _focus_row "$rendered" "$label" "$exact" || return
      _focus_advisory "$rendered" || return
      [[ $rendered == *project* || $rendered == *main* ]] || {
        print -u2 -r -- "$mode omitted all cached project/Git context"
        return 1
      }
      REPLY=$rendered
    }

    _focus_case '"'"'printf hello'"'"' RUN "COMMAND TEXT" printf || exit 1
    _focus_row "$REPLY" "ARGUMENT TEXT" hello || exit 14
    _focus_case '"'"'git status --short'"'"' GIT "OPERATION TEXT" status || exit 2
    _focus_row "$REPLY" BRANCH main || exit 3
    _focus_case '"'"'git -C ../other-repo status'"'"' GIT "OPERATION TEXT" status || exit 18
    [[ $REPLY != *"OPERATION TEXT"*"../other-repo"* ]] || exit 19
    _focus_case '"'"'g --review'"'"' GIT "OPERATION TEXT" review || exit 20
    _focus_case '"'"'cd ../other-space'"'"' NAVIGATE "DESTINATION TEXT" ../other-space || exit 4
    _focus_row "$REPLY" FROM "~/project" || exit 5
    _focus_case '"'"'rg FIXME-needle src'"'"' SEARCH "QUERY TEXT" FIXME-needle || exit 6
    _focus_row "$REPLY" SCOPE project || exit 7
    _focus_case '"'"'rg -g "*.zsh" FIXME-needle src'"'"' SEARCH "QUERY TEXT" FIXME-needle || exit 15
    [[ $REPLY != *"QUERY TEXT"*"*.zsh"* ]] || exit 16
    _focus_case '"'"'find src -name "*.zsh"'"'"' SEARCH "QUERY TEXT" "*.zsh" || exit 17
    _focus_case '"'"'swift build --configuration release'"'"' BUILD "TASK TEXT" build || exit 8
    _focus_row "$REPLY" TOOLCHAIN '"'"'swift 6.4'"'"' || exit 9
    _focus_case '"'"'swift test --filter ParserTests'"'"' TEST "TASK TEXT" ParserTests || exit 10
    _focus_row "$REPLY" TOOLCHAIN '"'"'swift 6.4'"'"' || exit 11
    _focus_case '"'"'conda activate analytics'"'"' ENVIRONMENT "ARGUMENT TEXT" analytics || exit 12
    _focus_row "$REPLY" CURRENT existing-env || exit 13
    _focus_case '"'"'# explain this migration'"'"' COMMENT "COMMENT TEXT" "explain this migration" || exit 21

    print -r -- local-interactions
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal local-interactions "$output"
}
test_case 'living prompt interaction lenses expose exact local Git navigation search build test and environment facts' \
  _test_living_prompt_interaction_lenses_cover_local_work_intents

_test_living_prompt_interaction_lenses_cover_remote_flow_and_caution() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    TERM=dumb COLUMNS=140 LINES=30
    source "$1/.zsh.addons/.zsh.prompt"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    _PROMPT_VIEW=compact
    _PROMPT_PATH_TEXT="~/project"
    _PROMPT_FULL_PATH_TEXT="~/project"
    _PROMPT_PROJECT_ROOT_TEXT="$HOME/project"
    _PROMPT_PROJECT_NAME_TEXT=project
    _PROMPT_GIT_TEXT='"'"'main ✓'"'"'
    _PROMPT_GIT_BRANCH_TEXT=main
    _prompt_layout
    _prompt_base

    _focus_render() {
      BUFFER=$1 CURSOR=${#1}
      _prompt_interaction_update || :
      print -P -v REPLY -r -- "$PROMPT"
    }
    _focus_row() {
      local rendered=$1 label=$2 value=$3 row=''
      for row in "${(f)rendered}"; do
        [[ $row == *"│"*"$label"*"$value"* ]] && return 0
      done
      print -u2 -r -- "missing $label ${(qqq)value}: ${(V)rendered}"
      return 1
    }
    _focus_advisory() {
      local rendered=$1 row=''
      for row in "${(f)rendered}"; do
        [[ $row == *"│"*ACTION* ]] || continue
        [[ ${row:l} == *likely* || ${row:l} == *appears* || ${row:l} == *may* ]] && return 0
      done
      return 1
    }
    _focus_header() {
      local -a rows=("${(@f)1}")
      [[ $rows[1] == *"╭─ $2"* &&
         $rows[-1] == *"╰─ "* && $rows[-1] == *"❯"* ]]
    }

    _focus_render '"'"'ssh deploy@example.invalid'"'"'; local remote=$REPLY
    _focus_header "$remote" REMOTE || exit 1
    _focus_row "$remote" "ENDPOINT TEXT" deploy@example.invalid || exit 2
    _focus_advisory "$remote" || exit 3
    [[ ${remote:l} != *connected* && ${remote:l} != *'"'"'active connection'"'"'* ]] || {
      print -u2 -r -- "editable ssh text was presented as a completed connection"
      exit 4
    }

    _focus_render '"'"'ssh -i ~/.ssh/id_ed25519 deploy@example.invalid uptime'"'"'
    local ssh_options=$REPLY
    _focus_row "$ssh_options" "ENDPOINT TEXT" deploy@example.invalid || exit 27
    [[ $ssh_options != *id_ed25519* ]] || exit 28

    _focus_render '"'"'curl -H "Authorization: Bearer local-secret" https://example.invalid'"'"'
    local curl_options=$REPLY
    _focus_header "$curl_options" REMOTE || exit 29
    [[ $curl_options != *local-secret* &&
       $curl_options != *"ENDPOINT TEXT"* ]] || exit 30

    _focus_render '"'"'curl https://user:local-secret@example.invalid/private?token=also-secret'"'"'
    local curl_bare=$REPLY
    _focus_row "$curl_bare" "ENDPOINT TEXT" https://example.invalid || exit 31
    [[ $curl_bare != *local-secret* && $curl_bare != *also-secret* &&
       $curl_bare != *private* ]] || exit 32

    _focus_render '"'"'git status && npm test'"'"'; local chain=$REPLY
    _focus_header "$chain" CHAIN || exit 21
    _focus_row "$chain" FLOW git || exit 22
    _focus_row "$chain" FLOW npm || exit 23
    _focus_row "$chain" STEPS 2 || exit 24
    _focus_row "$chain" CONTROL '"'"'&&'"'"' || exit 25
    _focus_advisory "$chain" || exit 26

    _focus_render '"'"'rg TODO src | sort > report.txt'"'"'; local pipeline=$REPLY
    _focus_header "$pipeline" PIPELINE || exit 5
    _focus_row "$pipeline" FLOW rg || exit 6
    _focus_row "$pipeline" FLOW sort || exit 19
    _focus_row "$pipeline" STAGES 2 || exit 20
    _focus_row "$pipeline" "OUTPUT TEXT" report.txt || exit 7
    _focus_advisory "$pipeline" || exit 8

    _focus_render '"'"'printf data >> audit.log'"'"'; local redirect=$REPLY
    _focus_header "$redirect" REDIRECT || exit 15
    _focus_row "$redirect" "OPERATOR TEXT" '"'"'>>'"'"' || exit 16
    _focus_row "$redirect" "OUTPUT TEXT" audit.log || exit 17
    _focus_advisory "$redirect" || exit 18

    _focus_render '"'"'cat < input.txt | sort'"'"'; local input_pipeline=$REPLY
    _focus_header "$input_pipeline" PIPELINE || exit 33
    _focus_row "$input_pipeline" "INPUT TEXT" input.txt || exit 34
    [[ $input_pipeline != *"OUTPUT TEXT"*input.txt* ]] || exit 35

    _focus_render '"'"'cat 2>&1 | sort'"'"'; local descriptor_pipeline=$REPLY
    _focus_header "$descriptor_pipeline" PIPELINE || exit 36
    _focus_row "$descriptor_pipeline" "DESCRIPTOR TEXT" 1 || exit 37

    _focus_render '"'"'rm -rf ./build-cache'"'"'; local caution=$REPLY
    _focus_header "$caution" CAUTION || exit 9
    _focus_row "$caution" "ARGUMENT TEXT" ./build-cache || exit 10
    _focus_advisory "$caution" || exit 11

    # Caution has precedence over an otherwise ordinary Git interaction.
    _focus_render '"'"'git reset --hard HEAD~1'"'"'; local git_caution=$REPLY
    _focus_header "$git_caution" CAUTION || exit 12
    _focus_row "$git_caution" "ARGUMENT TEXT" HEAD~1 || exit 13
    _focus_advisory "$git_caution" || exit 14

    _focus_render '"'"'g reset --hard HEAD~1'"'"'; local g_caution=$REPLY
    _focus_header "$g_caution" CAUTION || exit 42
    _focus_row "$g_caution" "OPERATION TEXT" reset || exit 43

    _focus_render '"'"'time -p rm -rf ./build-cache'"'"'; local timed_caution=$REPLY
    _focus_header "$timed_caution" CAUTION || exit 38
    _focus_row "$timed_caution" "COMMAND TEXT" rm || exit 39

    _focus_render '"'"'git status | sort && rm -rf /'"'"'; local mixed_caution=$REPLY
    _focus_header "$mixed_caution" CAUTION || exit 40
    _focus_row "$mixed_caution" "COMMAND TEXT" rm || exit 41

    print -r -- composed-interactions
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal composed-interactions "$output"
}
test_case 'living prompt interaction lenses qualify remote pipeline redirection and caution intent' \
  _test_living_prompt_interaction_lenses_cover_remote_flow_and_caution

_test_living_prompt_interaction_precommand_heads() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$unit"; done
    local draft=""

    # Every pipeline and chain command skips the same leading assignments,
    # precommand modifiers (env with its options and NAME=value operands
    # included), and redirections before naming its head.
    for draft in "env rm -rf build" "true && env rm -rf build" \
      "ls | env rm -rf build" "true && env -i rm -rf build" \
      "ls | time rm -rf build" "true && command rm -rf build" \
      "true && env -u HOME -i rm -rf build" "ls |& nocorrect rm -rf build" \
      "true && 2>/dev/null rm -rf build" "true; env API_TOKEN=never-shown rm -rf build"; do
      _prompt_interaction_model "$draft"
      [[ $_PROMPT_INTERACTION_KIND == caution &&
         ${_PROMPT_INTERACTION_LABELS[1]} == "COMMAND TEXT" &&
         ${_PROMPT_INTERACTION_VALUES[1]} == rm &&
         ${(j:|:)_PROMPT_INTERACTION_VALUES} != *never-shown* ]] || {
        print -u2 -r -- "precommand head missed for ${(qqq)draft}: $_PROMPT_INTERACTION_KIND ${(j:|:)_PROMPT_INTERACTION_VALUES}"
        exit 1
      }
    done

    _prompt_interaction_model "git status && env -i npm test | time -p sort"
    [[ $_PROMPT_INTERACTION_KIND == chain &&
       ${_PROMPT_INTERACTION_VALUES[1]} == "git → npm → sort" ]] || {
      print -u2 -r -- "flow heads kept a precommand: ${(j:|:)_PROMPT_INTERACTION_VALUES}"
      exit 2
    }

    # A redirection alone still reads as a redirection. Only assignments alone
    # read as an environment update, without disclosing their values.
    _prompt_interaction_model "> out.txt"
    [[ $_PROMPT_INTERACTION_KIND == redirect ]] || exit 3
    _prompt_interaction_model "API_TOKEN=never-shown"
    [[ $_PROMPT_INTERACTION_KIND == environment &&
       ${(j:|:)_PROMPT_INTERACTION_VALUES} != *never-shown* ]] || exit 4
    _prompt_interaction_model "env -i"
    [[ $_PROMPT_INTERACTION_KIND != environment ]] || exit 5
    print -r -- precommand-heads
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal precommand-heads "$output"
}
test_case 'living prompt interaction lens finds precommand heads after chains and pipelines' \
  _test_living_prompt_interaction_precommand_heads

_test_living_prompt_interaction_edits_are_inert_and_reuse_autosuggestion_state() {
  test_make_temp_dir || return
  local bin="$TEST_TMP_DIR/forbidden-bin"
  local external_marker="$TEST_TMP_DIR/external-command-ran"
  local substitution_marker="$TEST_TMP_DIR/substitution-ran"
  local backtick_marker="$TEST_TMP_DIR/backtick-ran"
  local command_name='' output=''

  command mkdir -p -- "$bin" || return
  test_write_file "$bin/forbidden" "#!/bin/sh
printf called > '$external_marker'
exit 97" || return
  command chmod +x "$bin/forbidden" || return
  for command_name in git rg grep find swift npm make cargo conda ssh scp sftp rm sort stat; do
    command ln -s forbidden "$bin/$command_name" || return
  done

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    # Hostile text names its markers relative to the fixture root, so any
    # evaluation would land beside the absolute markers checked below.
    builtin cd -- "${4:h}" || exit 23
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE PROMPT_SUBST PROMPT_BANG
    TERM=dumb COLUMNS=60 LINES=30
    source "$1/.zsh.addons/.zsh.prompt"
    for unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$unit"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    source "$1/.zsh.addons/.zsh.editor"

    _PROMPT_VIEW=compact
    _PROMPT_PATH_TEXT="~/project"
    _PROMPT_FULL_PATH_TEXT="~/project"
    _PROMPT_PROJECT_ROOT_TEXT="$HOME/project"
    _PROMPT_PROJECT_NAME_TEXT=project
    _PROMPT_GIT_TEXT='"'"'main ✓'"'"'
    _PROMPT_GIT_BRANCH_TEXT=main
    _PROMPT_PROJECT_ITEMS=('"'"'swift 6.4'"'"')
    _PROMPT_PROJECT_ITEM_WIDTHS=(9)
    _prompt_layout
    _prompt_base

    # Context text is escaped once for the final PROMPT_SUBST pass. It must
    # remain inert without exposing the protective escapes as visible text in
    # either the compact context or expanded Context lens. Short relative
    # markers keep it untruncated at COLUMNS=240 whatever the fixture path.
    local -i saved_columns=$COLUMNS
    COLUMNS=240
    local hostile_context="\$(printf pwned > \"${4:t}\")%!\`printf pwned > \"${5:t}\"\`"
    _PROMPT_PROJECT_NAME_TEXT=$hostile_context
    _PROMPT_PATH_TEXT="~/$hostile_context"
    _PROMPT_FULL_PATH_TEXT="/fixture/$hostile_context"
    _PROMPT_VIEW=compact
    _prompt_layout
    _prompt_base
    local hostile_context_render=""
    print -P -v hostile_context_render -r -- "$PROMPT"
    [[ $hostile_context_render == *"$hostile_context"* &&
       $hostile_context_render == "${hostile_context_render//\\/}" &&
       ! -e $4 && ! -e $5 ]] || {
      print -u2 -r -- "compact Context was not literal and inert: ${(V)hostile_context_render}"
      exit 19
    }
    _PROMPT_VIEW=lens
    _prompt_layout
    _prompt_base
    print -P -v hostile_context_render -r -- "$PROMPT"
    [[ $hostile_context_render == *"$hostile_context"* &&
       $hostile_context_render == "${hostile_context_render//\\/}" &&
       ! -e $4 && ! -e $5 ]] || {
      print -u2 -r -- "expanded Context was not literal and inert: ${(V)hostile_context_render}"
      exit 20
    }
    _PROMPT_PROJECT_NAME_TEXT=project
    _PROMPT_PATH_TEXT="~/project"
    _PROMPT_FULL_PATH_TEXT="~/project"
    _PROMPT_VIEW=compact
    COLUMNS=$saved_columns
    _prompt_layout
    _prompt_base

    # Public project extensions cannot inject prompt syntax through their
    # optional color. Invalid colors fall back to a validated role or plain
    # text before BUILD/TEST can reuse the segment in an Interaction lens.
    local hostile_color="red}\$(printf pwned > \"$6\")%F{red"
    local -a _PROMPT_PROJECT_EXTRA_SEGMENTS=() _PROMPT_PROJECT_EXTRA_WIDTHS=()
    prompt_add_project_segment custom-tool "$hostile_color" || exit 21
    _PROMPT_PROJECT_ITEMS=("${_PROMPT_PROJECT_EXTRA_SEGMENTS[@]}")
    _PROMPT_PROJECT_ITEM_WIDTHS=("${_PROMPT_PROJECT_EXTRA_WIDTHS[@]}")
    _PROMPT_INTERACTION_ACTIVE=1
    BUFFER=make CURSOR=${#BUFFER}
    _prompt_layout
    _prompt_base
    local hostile_color_render=""
    print -P -v hostile_color_render -r -- "$PROMPT"
    [[ $hostile_color_render == *custom-tool* && ! -e $6 ]] || {
      print -u2 -r -- "project color entered prompt syntax: ${(V)hostile_color_render}"
      exit 22
    }
    _PROMPT_INTERACTION_ACTIVE=0
    _PROMPT_PROJECT_ITEMS=("swift 6.4")
    _PROMPT_PROJECT_ITEM_WIDTHS=(9)
    BUFFER="" CURSOR=0
    _prompt_layout
    _prompt_base

    # Any interaction-time use of captured-fact providers, directory/history
    # collectors, or the filesystem helper is a contract violation.
    typeset -gi _PROMPT_TEST_FORBIDDEN_READS=0
    local provider=''
    for provider in _prompt_git _prompt_project_context _prompt_runtime_version \
        _prompt_resolve_project_root _directory_picker_collect \
        _directory_browser_collect _history_search_collect \
        _zle_autosuggest_find _zle_path_category zstat; do
      functions[$provider]="(( ++_PROMPT_TEST_FORBIDDEN_READS )); return 97"
    done
    path=("$2")
    rehash

    _focus_edit() {
      BUFFER=$1 CURSOR=${#1}
      _prompt_interaction_update || :
      print -P -v REPLY -r -- "$PROMPT"
    }
    local candidate=''
    for candidate in \
        "git status" \
        "cd ../missing-literal" \
        "rg needle src" \
        "swift test" \
        "conda activate demo" \
        "ssh host.invalid" \
        "rg needle | sort > result.txt" \
        "rm -rf ./build"; do
      _focus_edit "$candidate"
    done
    (( _PROMPT_TEST_FORBIDDEN_READS == 0 )) || {
      print -u2 -r -- "an edit called $_PROMPT_TEST_FORBIDDEN_READS forbidden providers"
      exit 1
    }
    [[ ! -e $3 ]] || {
      print -u2 -r -- "an edit launched an external command"
      exit 2
    }

    # Lexing hostile-looking text is inert. A control byte in the displayed
    # command head becomes ?, while prompt expansion renders literal % and !.
    local escape=''
    printf -v escape "\\033"
    BUFFER="deploy%!${escape}command \$(printf pwned > \"$4\") \`printf pwned > \"$5\"\`"
    CURSOR=${#BUFFER}
    _prompt_interaction_update || :
    local hostile_buffer=$BUFFER hostile=''
    print -P -v hostile -r -- "$PROMPT"
    local -a hostile_rows=("${(@f)hostile}")
    [[ $hostile_rows[1] == *"╭─ RUN"* &&
       $hostile == *"COMMAND TEXT"*"deploy%!?command"* &&
       $hostile != *"deploy%!${escape}command"* &&
       $BUFFER == "$hostile_buffer" ]] || {
      print -u2 -r -- "hostile literal was evaluated or rendered unsafely: ${(V)hostile}"
      exit 3
    }
    [[ ! -e $4 && ! -e $5 && ! -e $3 ]] || {
      print -u2 -r -- "editable substitution or command text executed"
      exit 4
    }
    (( _PROMPT_TEST_FORBIDDEN_READS == 0 )) || exit 5

    # Leading assignments may help locate the command token, but their values
    # are potentially credentials and must never become prompt presentation.
    BUFFER="API_TOKEN=never-display-this git status" CURSOR=${#BUFFER}
    _prompt_interaction_update || :
    local assigned=''
    print -P -v assigned -r -- "$PROMPT"
    [[ $assigned == *"╭─ GIT"* && $assigned != *never-display-this* ]] || {
      print -u2 -r -- "an assignment value leaked into the interaction lens: ${(V)assigned}"
      exit 10
    }
    (( _PROMPT_TEST_FORBIDDEN_READS == 0 )) || exit 11

    BUFFER="env API_TOKEN=also-never-display-this git status" CURSOR=${#BUFFER}
    _prompt_interaction_update || :
    print -P -v assigned -r -- "$PROMPT"
    [[ $assigned == *"╭─ GIT"* &&
       $assigned != *also-never-display-this* ]] || {
      print -u2 -r -- "an env assignment value leaked: ${(V)assigned}"
      exit 16
    }

    # Analysis stays bounded even when the entire prefix is whitespace. Such
    # a long draft must never masquerade as the empty READY state.
    local blank_prefix=${(l:512:: :)}
    BUFFER="${blank_prefix}rm -rf /" CURSOR=${#BUFFER}
    _prompt_interaction_update || :
    local bounded=''
    print -P -v bounded -r -- "$PROMPT"
    [[ $bounded == *"╭─ RUN"* && $bounded == *ANALYSIS*"512"* &&
       $bounded != *"╭─ READY"* ]] || {
      print -u2 -r -- "a beyond-bound draft appeared empty: ${(V)bounded}"
      exit 17
    }
    (( _PROMPT_TEST_FORBIDDEN_READS == 0 )) || exit 18

    # Autosuggestion already has a bounded editor-owned state surface. The
    # interaction lens may disclose its suffix without searching history or
    # copying the unseen private tail into the visible prompt. Native menu
    # completion intentionally has no corresponding persistent adapter state.
    BUFFER="git st" CURSOR=${#BUFFER}
    local padding=${(l:100::x:)}
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    _ZLE_AUTOSUGGEST_CACHE_BUFFER=$BUFFER
    _ZLE_AUTOSUGGEST_SUFFIX="atus --short ${padding} PRIVATE-TAIL"
    _ZLE_AUTOSUGGEST_DISPLAY=$_ZLE_AUTOSUGGEST_SUFFIX
    POSTDISPLAY=$_ZLE_AUTOSUGGEST_DISPLAY
    local suggestion_display=$POSTDISPLAY suggested=''
    _prompt_interaction_update || :
    print -P -v suggested -r -- "$PROMPT"
    [[ $suggested == *SUGGESTION*"atus --short"* &&
       $suggested != *PRIVATE-TAIL* &&
       $BUFFER == "git st" && $POSTDISPLAY == "$suggestion_display" ]] || {
      print -u2 -r -- "cached autosuggestion was not disclosed safely: ${(V)suggested}"
      exit 12
    }
    (( _PROMPT_TEST_FORBIDDEN_READS == 0 )) || exit 13

    _ZLE_AUTOSUGGEST_SUFFIX=""
    _ZLE_AUTOSUGGEST_DISPLAY=""
    POSTDISPLAY=""
    _prompt_interaction_update || :
    local without_suggestion=''
    print -P -v without_suggestion -r -- "$PROMPT"
    [[ $without_suggestion != *SUGGESTION* ]] || exit 14
    (( _PROMPT_TEST_FORBIDDEN_READS == 0 )) || exit 15

    print -r -- inert-interactions
  ' "$TEST_REPO_ROOT" "$bin" "$external_marker" \
    "$substitution_marker" "$backtick_marker" "$TEST_TMP_DIR/color-ran") || return

  test_assert_equal inert-interactions "$output"
}
test_case 'living prompt interaction edits are inert provider-free and reuse bounded autosuggestion state' \
  _test_living_prompt_interaction_edits_are_inert_and_reuse_autosuggestion_state

_test_living_prompt_interaction_lens_unicode_rows_fit_terminal_cells() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    TERM=dumb COLUMNS=28 LINES=12
    source "$1/.zsh.addons/.zsh.prompt"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    _PROMPT_VIEW=compact
    _PROMPT_PATH_TEXT="~/專案/非常に長い資料"
    _PROMPT_FULL_PATH_TEXT="~/專案/非常に長い資料"
    _PROMPT_PROJECT_ROOT_TEXT="/tmp/專案"
    _PROMPT_PROJECT_NAME_TEXT=專案
    _PROMPT_GIT_TEXT="機能/長い分支 ✓"
    _PROMPT_GIT_BRANCH_TEXT="機能/長い分支"
    _PROMPT_PROJECT_ITEMS=("工具鏈 6.4")
    _PROMPT_PROJECT_ITEM_WIDTHS=(10)
    _prompt_layout
    _prompt_base

    BUFFER="rg 針を探す 非常に長い資料" CURSOR=${#BUFFER}
    _prompt_interaction_update || :
    local rendered='' row=''
    print -P -v rendered -r -- "$PROMPT"
    local -a rows=("${(@f)rendered}")
    [[ $rows[1] == *"╭─ SEARCH"* && $rendered == *"QUERY TEXT"*針* &&
       $rows[-1] == *"╰─ "* && $rows[-1] == *"❯"* ]] || {
      print -u2 -r -- "Unicode interaction lens lost its semantic frame: ${(V)rendered}"
      exit 1
    }
    setopt EXTENDED_GLOB
    local escape_character='' plain_row=''
    printf -v escape_character "\\033"
    for row in "${rows[@]}"; do
      plain_row=${row//${escape_character}\[[0-9\;]#m/}
      (( ${(m)#plain_row} <= COLUMNS )) || {
        print -u2 -r -- "28-cell interaction row overflowed (${(m)#plain_row}): ${(V)row}"
        exit 2
      }
    done

    # A cached resize reflows and contracts the same interaction without
    # reparsing external state or splitting a wide/combining character.
    COLUMNS=20
    _prompt_layout
    _prompt_base
    print -P -v rendered -r -- "$PROMPT"
    rows=("${(@f)rendered}")
    [[ $rows[1] == *"╭─ SEARCH"* &&
       $rows[-1] == *"╰─ "* && $rows[-1] == *"❯"* ]] || exit 3
    for row in "${rows[@]}"; do
      plain_row=${row//${escape_character}\[[0-9\;]#m/}
      (( ${(m)#plain_row} <= COLUMNS )) || {
        print -u2 -r -- "20-cell interaction row overflowed (${(m)#plain_row}): ${(V)row}"
        exit 4
      }
    done

    # Long mode names contract too; the header itself must never wrap just
    # because the terminal is narrower than "ENVIRONMENT".
    COLUMNS=12
    BUFFER="conda activate x" CURSOR=${#BUFFER}
    _prompt_interaction_update || :
    print -P -v rendered -r -- "$PROMPT"
    rows=("${(@f)rendered}")
    for row in "${rows[@]}"; do
      plain_row=${row//${escape_character}\[[0-9\;]#m/}
      (( ${(m)#plain_row} <= COLUMNS )) || {
        print -u2 -r -- "12-cell interaction row overflowed (${(m)#plain_row}): ${(V)row}"
        exit 5
      }
    done

    LINES=1
    _prompt_layout
    _prompt_base
    print -P -v rendered -r -- "$PROMPT"
    rows=("${(@f)rendered}")
    (( ${#rows} == 1 )) || {
      print -u2 -r -- "one-row terminal received ${#rows} prompt rows: ${(V)rendered}"
      exit 6
    }
    print -r -- unicode-interaction
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal unicode-interaction "$output"
}
test_case 'living prompt interaction lens contracts Unicode rows to terminal cell width' \
  _test_living_prompt_interaction_lens_unicode_rows_fit_terminal_cells

_test_living_prompt_unicode_layout_respects_terminal_cells() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    TERM=dumb
    source "$1/.zsh.addons/.zsh.prompt"

    _PROMPT_PATH_TEXT="~/漢字"
    _PROMPT_FULL_PATH_TEXT="~/漢字/資料"
    _PROMPT_PROJECT_ROOT_TEXT="/tmp/專案"
    _PROMPT_PROJECT_ITEMS=(工具)
    _PROMPT_PROJECT_ITEM_WIDTHS=(4)
    _PROMPT_SESSION_TEXT="使用者@主機 · zsh 5.9"
    _PROMPT_VIEW=compact
    COLUMNS=13
    _prompt_layout
    (( ${(m)#_PROMPT_CONTEXT_SEGMENT} <= COLUMNS )) || exit 1
    [[ $_PROMPT_CONTEXT_SEGMENT != *工具* ]] || exit 2

    _PROMPT_VIEW=lens
    _PROMPT_LENS_REASON="project changed"
    COLUMNS=18 LINES=8
    _prompt_layout
    local row=""
    for row in "${(f)_PROMPT_LENS_SEGMENT}"; do
      (( ${(m)#row} <= COLUMNS )) || exit 3
    done
    print -r -- unicode-layout
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal unicode-layout "$output"
}
test_case 'living prompt Unicode layout respects terminal cell widths' \
  _test_living_prompt_unicode_layout_respects_terminal_cells

_test_living_prompt_edit_repaints_context_row_like_full_reflow() {
  test_make_temp_dir || return
  local output=''

  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    setopt MULTIBYTE
    setopt EXTENDED_GLOB
    TERM=xterm-256color
    source "$1/.zsh.addons/.zsh.prompt"

    _PROMPT_PATH_TEXT="~/a-deliberately-long-workspace-name/project"
    _PROMPT_FULL_PATH_TEXT=$_PROMPT_PATH_TEXT
    _PROMPT_GIT_TEXT="feature/cache-safe-resize ✓"
    _PROMPT_GIT_BRANCH_TEXT=feature/cache-safe-resize
    _PROMPT_ENV_TEXT=demo
    _PROMPT_JOBS_TEXT="1 job"
    _PROMPT_PROJECT_ITEMS=("swift 6.4")
    _PROMPT_PROJECT_ITEM_WIDTHS=(9)
    _PROMPT_VIEW=compact
    _PROMPT_INTERACTION_ACTIVE=1
    LINES=20

    # The expected paint is a complete reflow of the captured snapshot at the
    # current width, as capture and resize produce it.
    _full_reflow() {
      COLUMNS=$1 BUFFER=$2 CURSOR=${#2}
      _prompt_layout
      _prompt_base
      REPLY=$PROMPT
    }
    # An edit after the width changed with no resize relayout, such as under a
    # later-installed WINCH handler that never calls the prompt.
    _edit_after_width_change() {
      COLUMNS=$1 BUFFER="" CURSOR=0
      _prompt_layout
      _prompt_base
      COLUMNS=$2 BUFFER=$3 CURSOR=${#3}
      _prompt_interaction_update "$3" || :
      REPLY=$PROMPT
    }

    local expected="" actual="" first_row="" step="" rest="" draft=""
    local -i from=0 to=0
    for step in 140:140:x 140:10:xy 10:10:xyz 10:8:xyz 8:11:xy 11:140:x \
        140:9: 9:140:; do
      from=${step%%:*} rest=${step#*:}
      to=${rest%%:*} draft=${rest#*:}
      _full_reflow "$to" "$draft"
      expected=$REPLY
      _edit_after_width_change "$from" "$to" "$draft"
      actual=$REPLY
      [[ $actual == "$expected" ]] || {
        print -u2 -r -- "edit at $step painted ${(V)actual} instead of ${(V)expected}"
        exit 2
      }
      # Below twelve columns the Interaction lens yields to one context row
      # that fits the window.
      if (( to < 12 )); then
        print -P -v first_row -r -- "${actual%%$'"'"'\n'"'"'*}"
        first_row=${first_row//$'"'"'\e'"'"'\[[0-9;]#m/}
        [[ -z $_PROMPT_INTERACTION_SEGMENT &&
           $actual == "${_PROMPT_CONTEXT_SEGMENT}"$'"'"'\n'"'"'* &&
           -n $first_row ]] || exit 3
        (( ${(m)#first_row} <= to )) || {
          print -u2 -r -- "context row ${(V)first_row} overflows at $step"
          exit 4
        }
      else
        [[ $actual == *"╭─"* ]] || exit 5
      fi
    done
    print -r -- edit-context-row
  ' "$TEST_REPO_ROOT") || return

  test_assert_equal edit-context-row "$output"
}
test_case 'living prompt edits repaint the small-window context row exactly as a full reflow at the current width' \
  _test_living_prompt_edit_repaints_context_row_like_full_reflow

_test_living_prompt_peer_hooks_converge_and_missing_capabilities_noop() {
  test_make_temp_dir || return
  local mode='' output='' expected=''

  for mode in editor-first prompt-first highlighting-first; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$mode" '
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
      case $2 in
        (editor-first)
          source "$1/.zsh.addons/.zsh.editor"
          source "$1/.zsh.addons/.zsh.prompt"
          source "$1/.zsh.addons/.zsh.highlighting"
          ;;
        (prompt-first)
          source "$1/.zsh.addons/.zsh.prompt"
          source "$1/.zsh.addons/.zsh.highlighting"
          source "$1/.zsh.addons/.zsh.editor"
          ;;
        (highlighting-first)
          source "$1/.zsh.addons/.zsh.highlighting"
          source "$1/.zsh.addons/.zsh.editor"
          source "$1/.zsh.addons/.zsh.prompt"
          ;;
      esac
      # A separated repeat must not duplicate hooks or change their order.
      source "$1/.zsh.addons/.zsh.prompt"
      source "$1/.zsh.addons/.zsh.highlighting"
      source "$1/.zsh.addons/.zsh.editor"
      zmodload zsh/parameter

      local -a pre_redraw_hooks=() finish_hooks=()
      zstyle -a zle-line-pre-redraw widgets pre_redraw_hooks
      zstyle -a zle-line-finish widgets finish_hooks
      pre_redraw_hooks=("${(@)pre_redraw_hooks#<->:}")
      finish_hooks=("${(@)finish_hooks#<->:}")
      # Syntax and the bounded history suffix establish final editor-owned
      # state first. The prompt adapter then sees that same state on this
      # redraw, rather than showing an autosuggestion one keypress late.
      [[ ${(j:,:)pre_redraw_hooks} ==
         _zle_syntax_highlight,_zle_autosuggest_update,_zle_prompt_pre_redraw ]] || exit 1
      # The editor removes its own suggestion display at every line finish,
      # before the optional top-level transcript adapter.
      [[ ${(j:,:)finish_hooks} ==
         _zle_autosuggest_clear_display,_zle_prompt_line_finish ]] || exit 2
      [[ ${widgets[compozsh-context-lens]} == user:_zle_prompt_toggle_widget ]] || exit 3
      [[ $(bindkey $'"'"'\ei'"'"') == *compozsh-context-lens ]] || exit 4

      # Hook adapters must return success when their optional prompt provider is
      # absent, or add-zle-hook-widget would stop the remaining hook chain.
      unfunction _prompt_interaction_update _prompt_prepare_transcript 2>/dev/null
      _zle_prompt_pre_redraw || exit 5
      _zle_prompt_line_finish || exit 6
      print -r -- "${(j:,:)pre_redraw_hooks}|${(j:,:)finish_hooks}|${widgets[compozsh-context-lens]}|$(bindkey $'"'"'\ei'"'"')"
    ' "$TEST_REPO_ROOT" "$mode") || return
    if [[ -z $expected ]]; then
      expected=$output
    else
      test_assert_equal "$expected" "$output" \
        "living prompt peer setup changed in $mode order" || return
    fi
  done
}
test_case 'living prompt peer hooks and Option-I converge while missing providers remain a successful no-op' \
  _test_living_prompt_peer_hooks_converge_and_missing_capabilities_noop
