# Self-documenting public command contracts.

_test_public_commands_support_help() {
  test_make_temp_dir || return
  local home="$TEST_TMP_DIR/home" fake_bin="$TEST_TMP_DIR/bin" output=''

  test_write_file "$fake_bin/git" \
    $'#!/bin/zsh\nprint -r -- delegated-git-help\n' || return
  command chmod +x "$fake_bin/git" || return

  output=$(test_run_interactive "$home" $'
    path=("$2" $path)
    rehash
    source "$1/.zsh.addons/.zsh.find"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.xcode"
    builtin cd -- "$HOME" || exit

    typeset -a help_lines=()
    typeset -a public_commands=(
      mkcd
      cpdir
      git-discard-all
      prompt-refresh
      d
      g
      f
      update_xcode_skills
      compozsh
    )
    for public_command in "${public_commands[@]}"; do
      stdout_file="$HOME/${public_command}.stdout"
      stderr_file="$HOME/${public_command}.stderr"
      "$public_command" --help >| "$stdout_file" 2>| "$stderr_file"
      command_status=$?
      stdout=$(<"$stdout_file")
      stderr=$(<"$stderr_file")
      help_lines=("${(f)stdout}")
      description=${help_lines[2]-}
      description_present=0
      [[ -n $description ]] && description_present=1
      stayed_put=0
      [[ $PWD == $HOME ]] && stayed_put=1
      print -r -- "$public_command|$command_status|${stdout[(f)1]:-}|$description_present|${#stderr}|$stayed_put"
      builtin cd -- "$HOME" || exit
    done
  ' "$TEST_REPO_ROOT" "$fake_bin") || return

  local public_command='' output_line='' record=''
  for public_command in mkcd cpdir git-discard-all prompt-refresh d g f \
      update_xcode_skills compozsh; do
    record=''
    for output_line in ${(f)output}; do
      if [[ $output_line == "$public_command|"* ]]; then
        record=$output_line
        break
      fi
    done
    test_assert_contains "$record" "$public_command|0|usage: $public_command" \
      "$public_command --help did not succeed on stdout" || return
    [[ $record == *'|1|0|1' ]] || {
      test_fail "$public_command --help lacks a description, emitted stderr, or changed state"
      return
    }
  done
}
test_case 'every direct Compozsh command supports side-effect-free --help' \
  _test_public_commands_support_help
