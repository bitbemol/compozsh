_test_manual_summary_parser() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.manual" || exit
    local -a reply=()
    _manual_summary_parse $'"'"'.Sh NAME\n.Nm ls\n.Nd list directory contents\n.Sh DESCRIPTION\nignored'"'"' || exit 1
    [[ $REPLY == "list directory contents" ]] || exit 2
    _manual_summary_parse $'"'"'.SH "NAME"\ngit \\- the stupid content tracker\n.SH SYNOPSIS'"'"' || exit 3
    [[ $REPLY == "the stupid content tracker" ]] || exit 4
    _manual_summary_parse $'"'"'.Sh NAME\n.Nm test\n.Nd inspect\nliteral entries\n.Sh SYNOPSIS'"'"' || exit 5
    [[ $REPLY == "inspect literal entries" ]] || exit 6
    _manual_summary_parse $'"'"'.so /never/read\n'"'"' && exit 7
    _manual_summary_parse $'"'"'.Sh NAME\n.Nd first\n.sy never-execute\n.Sh SYNOPSIS'"'"' && exit 8
    local long=${(l:300::x:)}
    _manual_summary_parse $'"'"'.Sh NAME\n.Nd '"'"'"$long"$'"'"'\n.Sh SYNOPSIS'"'"' || exit 9
    (( ${#REPLY} == 240 )) || exit 10
    _manual_summary_parse $'"'"'.Sh NAME\n.Nd unsafe\e[31m\n.Sh SYNOPSIS'"'"' && exit 11
    _manual_summary_parse "${(l:8192::x:)}"$'"'"'\n.Sh NAME\n.Nd outside bound\n.Sh SYNOPSIS'"'"' && exit 12
    exit 0
  ' "$TEST_REPO_ROOT"
}
test_case 'manual summaries parse bounded NAME text without interpreting roff' _test_manual_summary_parser

_test_manual_summary_capture() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/manual/man1/ls.1" $'.Sh NAME\n.Nm ls\n.Nd list directory contents\n.Sh SYNOPSIS'
  test_write_file "$TEST_TMP_DIR/manual/man1/man.1" $'.Sh NAME\n.Nm man ,\n.Nm whatis\n.Nd display manual pages\n.Sh SYNOPSIS'
  test_write_file "$TEST_TMP_DIR/manual/man1/unsafe.1" $'.so /never/read'
  ln -s /never/read "$TEST_TMP_DIR/manual/man1/link.1"
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual" || exit
    _manual_summary_capture "$2" || exit 1
    [[ $_MANUAL_SUMMARIES[ls] == "list directory contents" && $_MANUAL_SOURCES[ls] == "ls(1)" ]] || exit 2
    [[ $_MANUAL_SUMMARIES[whatis] == "display manual pages" ]] || exit 3
    (( ! ${+_MANUAL_SUMMARIES[unsafe]} && ! ${+_MANUAL_SUMMARIES[link]} )) || exit 4
    _manual_summary_reset
    (( ! _MANUAL_SUMMARIES_READY && ! ${#_MANUAL_SUMMARIES} )) || exit 5
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual"
}
test_case 'manual summaries capture bounded regular local pages and clear on refresh' _test_manual_summary_capture

_test_manual_summary_lens() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.manual" || exit
    source "$1/.zsh.addons/.zsh.output"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.navigation"
    _MANUAL_SUMMARIES=(ls "list directory contents" man "display manual pages" git "track changes" mkcd "wrong manual")
    _MANUAL_SOURCES=(ls "ls(1)" man "man(1)" git "git(1)" mkcd "mkcd(1)")
    _manual_summary_capture() { print -u2 forbidden-capture; return 99; }
    _prompt_interaction_model "ls -la"
    [[ $_PROMPT_INTERACTION_VALUES[${_PROMPT_INTERACTION_LABELS[(i)ABOUT]}] == "list directory contents" ]] || exit 1
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} != *"likely run a shell command"* ]] || exit 2
    _prompt_interaction_model "man ls"
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"display manual pages"* ]] || exit 3
    _prompt_interaction_model "git status"
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} == *"likely inspect working tree"* ]] || exit 4
    _prompt_interaction_model "mkcd ./new"
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} != *"wrong manual"* ]] || exit 5
    ls() { :; }
    _prompt_interaction_model "ls"
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} != *"list directory contents"* ]] || exit 6
    unfunction ls
    alias ls="something-else"
    _prompt_interaction_model "ls"
    [[ ${(j:|:)_PROMPT_INTERACTION_VALUES} != *"list directory contents"* ]] || exit 7
    _tools_refresh || exit 8
    (( ! ${#_MANUAL_SUMMARIES} )) || exit 9
  ' "$TEST_REPO_ROOT"
}
test_case 'manual summaries enrich the lens while preserving owned cues and shell overrides' _test_manual_summary_lens

_test_manual_summary_lifecycle() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual" || exit
    (( ! _MANUAL_SUMMARIES_READY && ! ${#_MANUAL_SUMMARIES} )) || exit 1
    local captures=0
    _manual_summary_capture() {
      (( ++captures ))
      _MANUAL_SUMMARIES_READY=1
      _MANUAL_SUMMARIES=(ls "list directory contents")
    }
    _manual_prompt_capture
    _manual_prompt_capture
    (( captures == 1 )) || exit 2
    source "$1/.zsh.addons/.zsh.manual"
    (( _MANUAL_SUMMARIES_READY && ${#_MANUAL_SUMMARIES} == 1 )) || exit 3
    source "$1/.zsh.addons/.zsh.prompt"
    _manual_prompt_capture() { print -u2 forbidden-capture; return 99; }
    _MANUAL_SUMMARIES[ls]='"'"'literal $(print unsafe) `print unsafe` %F{red} !'"'"'
    _MANUAL_SOURCES[ls]="ls(1)"
    local COLUMNS=120 BUFFER="ls" rendered=""
    setopt PROMPT_SUBST PROMPT_BANG
    _prompt_interaction_update "$BUFFER" || :
    print -P -v rendered -r -- "$PROMPT"
    [[ $rendered == *'"'"'literal $(print unsafe) `print unsafe` %F{red} !'"'"'* ]] || exit 4
    _manual_summary_reset
    (( ! _MANUAL_SUMMARIES_READY && ! ${#_MANUAL_SUMMARIES} && ! ${#_MANUAL_SOURCES} )) || exit 5
  ' "$TEST_REPO_ROOT"
}
test_case 'manual summaries capture once preserve re-source state and render hostile text literally' _test_manual_summary_lifecycle
