_test_manual_formatted_paragraph_characterization() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.manual"
    local TMPDIR=$HOME rendered="" expected=""
    # Feed controlled formatter bytes through the existing bounded pipeline.
    # Native mandoc safety and actual formatting are covered separately below.
    command() {
      if [[ $1 == /usr/bin/mandoc ]]; then
        print -rn -- "$rendered"
      else
        builtin command "$@"
      fi
    }
    rendered=$'\''TITLE\n\nN\bNA\bAM\bME\bE\n  demo - read A\bAB\bB text\n\nDESCRIPTION\n'\''"${(l:60000::x:):-}"
    _manual_summary_format NAME || exit 1
    [[ $REPLY == "read AB text" ]] || exit 2
    rendered=$'\''Name\n\ttool - first\n continued text\n\nLater\n'\''
    _manual_summary_format NAME || exit 3
    [[ $REPLY == "first continued text" ]] || exit 4
    # Removing an overstrike can join lines. Preserve this existing behavior,
    # including rejecting a control left by a single normalization pass.
    rendered=$'\''NAME\n tool - first\n\b joined text\n\nBODY\n'\''
    _manual_summary_format NAME || exit 5
    [[ $REPLY == "first joined text" ]] || exit 6
    rendered=$'\''TITLE\n\bPREFIX\nNAME\n tool - a b\b\bZ\n\n'\''
    _manual_summary_format NAME && exit 7
    rendered=$'\''NAME\n tool - unsafe\e[31m\n\n'\''
    _manual_summary_format NAME && exit 8
    rendered=$'\''TITLE\n no section - no summary\n'\''
    _manual_summary_format NAME && exit 9
    expected=${(l:300::x:):-}
    rendered=$'\''NAME\n tool - '\''"$expected"$'\''\n\n'\''
    _manual_summary_format NAME || exit 10
    [[ $REPLY == "${expected[1,239]}…" && ${#REPLY} == 240 ]] || exit 11
    local -a leftovers=("$HOME"/compozsh-manual.*(N))
    (( !${#leftovers} )) || exit 12
  ' "$TEST_REPO_ROOT"
}
test_case 'manual formatter preserves paragraph boundaries overstrikes controls and truncation' \
  _test_manual_formatted_paragraph_characterization

_test_manual_formatted_large_page() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    local TMPDIR=$HOME text=$'\''.TH DEMO 1\n.SH NAME\n.B demo\n\\- Read formatted fixture data\n.SH DESCRIPTION\n'\''
    text+="${(l:60000::x:):-}"
    _manual_summary_format "$text" || exit 1
    [[ $REPLY == "Read formatted fixture data" ]] || exit 2
    local -a leftovers=("$HOME"/compozsh-manual.*(N))
    (( !${#leftovers} )) || exit 3
  ' "$TEST_REPO_ROOT"
}
test_case 'manual formatter preserves native NAME output before a large document tail' \
  _test_manual_formatted_large_page
