_test_manual_custom_paths() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    command mkdir -p "$HOME/custom docs/man" "$HOME/tool/bin" "$HOME/tool/share/man"
    local -a captured=()
    _manual_summary_capture() { captured=("$@"); _MANUAL_SUMMARIES_READY=1; }
    _manual_developer_roots() { reply=(); return 1; }
    _manual_configuration_roots() { reply=(); }
    local PATH="$HOME/tool/bin:/usr/bin:/bin"
    local MANPATH="$HOME/custom docs/man"
    _manual_prompt_capture
    [[ $#captured == 1 && $captured[1] == "$MANPATH" ]] || {
      print -u2 "explicit MANPATH did not establish the manual scope"; exit 1
    }
    _manual_summary_reset
    MANPATH="$HOME/custom docs/man:"
    _manual_prompt_capture
    [[ $captured[1] == "$HOME/custom docs/man" &&
       ${captured[*]} == *"$HOME/tool/share/man"* ]] || exit 2
    _manual_summary_reset
    MANPATH=":$HOME/custom docs/man"
    _manual_prompt_capture
    [[ $captured[-1] == "$HOME/custom docs/man" ]] || exit 3
    _manual_summary_reset
    unset MANPATH
    _manual_prompt_capture
    [[ $captured[1] == "$HOME/tool/share/man" ]] || exit 4
  ' "$TEST_REPO_ROOT"
}
test_case 'manual coverage honors custom MANPATH ordering and PATH installation roots' _test_manual_custom_paths

_test_manual_links_and_compression() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/pages/man1/target.1" $'.SH NAME\ntarget \\- Inspect local fixture data\n.SH SYNOPSIS\n'
  command ln -s target.1 "$TEST_TMP_DIR/pages/man1/linked.1"
  test_write_file "$TEST_TMP_DIR/pages/man1/forward.1" $'.so man1/target.1\n'
  test_write_file "$TEST_TMP_DIR/pages/man1/loop-a.1" $'.so man1/loop-b.1\n'
  test_write_file "$TEST_TMP_DIR/pages/man1/loop-b.1" $'.so man1/loop-a.1\n'
  command gzip -c "$TEST_TMP_DIR/pages/man1/target.1" > "$TEST_TMP_DIR/pages/man1/packed.1.gz"
  test_write_file "$TEST_TMP_DIR/pages/man1/packed-forward.1" $'.so man1/packed.1\n'
  command bzip2 -c "$TEST_TMP_DIR/pages/man1/target.1" > "$TEST_TMP_DIR/pages/man1/bzip.1.bz2"
  command ln -s packed.1.gz "$TEST_TMP_DIR/pages/man1/compressed-link.1"
  command mkfifo "$TEST_TMP_DIR/pages/man1/pipe.1"
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _manual_summary_capture "$2"
    local name=""
    for name in target linked forward packed packed-forward bzip compressed-link; do
      [[ ${_MANUAL_SUMMARIES[$name]} == "Inspect local fixture data" &&
         ${_MANUAL_SOURCES[$name]} == "$name(1)" ]] || {
        print -u2 -r -- "missing linked or compressed manual: $name"; exit 1
      }
    done
    (( ! ${+_MANUAL_SUMMARIES[pipe]} && ! ${+_MANUAL_SUMMARIES[loop-a]} &&
       ! ${+_MANUAL_SUMMARIES[loop-b]} )) || exit 2
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/pages"
}
test_case 'manual coverage reads symlinks compressed pages and bounded manual forwarders' _test_manual_links_and_compression

_test_manual_section_precedence() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/first/man8/demo.8" $'.SH NAME\ndemo \\- Administrative fixture\n.SH SYNOPSIS\n'
  test_write_file "$TEST_TMP_DIR/second/man1/demo.1" $'.SH NAME\ndemo \\- Custom command fixture\n.SH SYNOPSIS\n'
  test_write_file "$TEST_TMP_DIR/second/man1/café.1" $'.SH NAME\ncafé \\- Unicode command fixture\n.SH SYNOPSIS\n'
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _manual_summary_capture "$2" "$3"
    [[ ${_MANUAL_SUMMARIES[demo]} == "Custom command fixture" &&
       ${_MANUAL_SOURCES[demo]} == "demo(1)" ]] || {
      print -u2 "manual lookup did not prioritize command sections across all roots"; exit 1
    }
    [[ ${_MANUAL_SUMMARIES[café]} == "Unicode command fixture" ]] || exit 2
    local MANSECT=8:1
    _manual_summary_capture "$2" "$3"
    [[ ${_MANUAL_SUMMARIES[demo]} == "Administrative fixture" ]] || exit 3
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/first" "$TEST_TMP_DIR/second"
}
test_case 'manual coverage preserves native section precedence across installation roots' _test_manual_section_precedence

_test_manual_formatted_names() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/pages/man1/styled.1" $'.TH STYLED 1\n.SH NAME\n.B styled\n\\- read a formatted manual\n.SH SYNOPSIS\n'
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _manual_summary_capture "$2"
    [[ ${_MANUAL_SUMMARIES[styled]} == "read a formatted manual" ]] || {
      print -u2 "formatted NAME text was omitted"; exit 1
    }
    local text=$'"'"'.TH DEMO 1\n.so inside.1\n.sy touch '"'"'"$HOME/executed"$'"'"'\n.pso touch '"'"'"$HOME/piped"$'"'"'\n.SH NAME\n.B demo\n\\- Public description\n.SH SYNOPSIS\n'"'"'
    print -r -- $'"'"'.TH SECRET 1\n.SH NAME\nsecret \\- Private included description\n.SH SYNOPSIS'"'"' > "$HOME/inside.1"
    cd "$HOME"
    local TMPDIR=$HOME
    _manual_summary_format "$text" || exit 2
    [[ $REPLY == "Public description" && ! -e $HOME/executed && ! -e $HOME/piped ]] || {
      print -u2 "manual formatting evaluated a command or included caller files"; exit 3
    }
    local -a leftovers=("$HOME"/compozsh-manual.*(N))
    (( ! $#leftovers )) || exit 4
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/pages"
}
test_case 'manual coverage formats NAME text without command effects or caller-directory includes' _test_manual_formatted_names

_test_manual_literal_configuration() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/man.conf" "MANPATH $TEST_TMP_DIR/configured manuals"$'\n'"MANCONFIG $TEST_TMP_DIR/man.d/*.conf"$'\nNROFF $(touch SHOULD_NOT_EXECUTE)\n'
  test_write_file "$TEST_TMP_DIR/man.d/custom.conf" "MANPATH $TEST_TMP_DIR/extra manuals"$'\n'
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    cd "$HOME"
    _manual_configuration_roots "$2" || exit 1
    [[ ${reply[1]} == "$3/configured manuals" && ${reply[2]} == "$3/extra manuals" &&
       ! -e SHOULD_NOT_EXECUTE ]] || exit 2
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/man.conf" "$TEST_TMP_DIR"
}
test_case 'manual coverage reads configured manual roots without evaluating formatter settings' _test_manual_literal_configuration

_test_manual_header_comments() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _manual_summary_parse $'"'"'.Sh NAME    \\" Header comment\r\n.Nm sample\r\n.\\" Name comment\r\n.Nd Inspect local data\r\n.Sh SYNOPSIS\r\n'"'"' || {
      print -u2 "ordinary commented/CRLF headers required a formatter"; exit 1
    }
    [[ $REPLY == "Inspect local data" ]] || exit 2
    _manual_summary_parse $'"'"'.SH NAME\ntool \\- Inspect local data\n.\n.SH SYNOPSIS\n'"'"' || exit 3
    [[ $REPLY == "Inspect local data" ]] || exit 4
    _manual_summary_parse $'"'"'.Sh NAME\n.Nm sample\n.Nd Inspect output from\n.Xr other 1\n.Sh SYNOPSIS\n'"'"' || exit 5
    [[ $REPLY == "Inspect output from other(1)" ]] || exit 6
  ' "$TEST_REPO_ROOT"
}
test_case 'manual coverage parses native header comments and CRLF without a formatter' _test_manual_header_comments

_test_manual_available_without_summary() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/pages/man1/brief.1" $'.TH BRIEF 1\n.SH NAME\nbrief\n.SH DESCRIPTION\nA fixture with no NAME description.\n'
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _manual_summary_capture "$2"
    [[ ${_MANUAL_SUMMARIES[brief]} == "Manual page available; NAME summary unavailable" &&
       ${_MANUAL_SOURCES[brief]} == "brief(1)" ]] || {
      print -u2 "an available manual disappeared when its NAME summary was absent"; exit 1
    }
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/pages"
}
test_case 'manual coverage discloses an available page even without a NAME summary' _test_manual_available_without_summary
