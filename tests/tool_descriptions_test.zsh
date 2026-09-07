_test_prompt_owned_descriptions() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.navigation"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/.zsh.addons/.zsh.usb"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    source "$1/.zsh.addons/.zsh.xcode"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_plutil_raw"
    source "$1/.zsh.addons/.zsh.prompt"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    (( ${+functions[_compozsh_prompt_capture]} )) || {
      print -u2 "missing captured help descriptions"; exit 1
    }
    _compozsh_prompt_capture
    [[ ${_COMPOZSH_PROMPT_OPTIONS[g:@default]} == "Open the local recent-branch workspace" &&
       ${_COMPOZSH_PROMPT_OPTIONS[compozsh:--sudo-touch-id enable]} == "Enable Touch ID authentication for sudo" ]] || {
      print -u2 "operation descriptions must originate in help"; exit 17
    }
    _expect_description() {
      _prompt_interaction_model "$1"
      local position=${_PROMPT_INTERACTION_LABELS[(Ie)$2]}
      [[ $position != 0 && $_PROMPT_INTERACTION_VALUES[$position] == "$3" ]] || {
        print -u2 -r -- "wrong description for $1: ${_PROMPT_INTERACTION_VALUES[*]}"; return 1
      }
    }
    _expect_description cpdir ABOUT "Copy the exact current directory to the local macOS clipboard." || exit 2
    _expect_description g ACTION "Open the local recent-branch workspace" || exit 3
    _expect_description "g --review" ACTION "Open read-only review; optionally compare two local refs." || exit 4
    _expect_description "compozsh --sudo-touch-id status" ACTION "Inspect Touch ID authentication for sudo" || exit 5
    _expect_description "compozsh --sudo-touch-id enable" ACTION "Enable Touch ID authentication for sudo" || exit 6
    _expect_description "compozsh --sudo-touch-id disable" ACTION "Disable Compozsh-managed Touch ID authentication for sudo" || exit 7
    _expect_description "g --review --help" ACTION "Read help for g" || exit 8
    _expect_description "external-device --flash --help" ACTION "Read help for external-device" || exit 20
    _expect_description "xcode --export-skills --help" ACTION "Read help for xcode" || exit 21
    _expect_description "compozsh --refresh --help" ACTION "Read help for compozsh" || exit 22
    _expect_description "compozsh --enable-touch-id" ABOUT "Explore public functions loaded from Compozsh add-on directories." || exit 9
    _expect_description la EXPANSION "ls -A" || exit 10
    _expect_description la ABOUT "List entries, including hidden files except . and .." || exit 11
    _expect_description ll EXPANSION "ls -lah" || exit 12
    _expect_description .. EXPANSION "cd .." || exit 13
    [[ $_PROMPT_INTERACTION_KIND == navigate ]] || { print -u2 "parent alias must use navigation"; exit 18; }
    _expect_description "g status" ACTION "likely inspect working tree" || exit 19
    alias la="print private-alias-value"
    _prompt_interaction_model la
    [[ ${_PROMPT_INTERACTION_VALUES[*]} != *"List entries"* &&
       ${_PROMPT_INTERACTION_VALUES[*]} != *private-alias-value* ]] || exit 14
    # Redraw must reuse capture; never invoke operational tools or help.
    unfunction _compozsh_prompt_capture
    _expect_description "g --review" ACTION "Open read-only review; optionally compare two local refs." || exit 15
    functions[g]="print should-not-execute"
    _prompt_interaction_model g
    [[ ${_PROMPT_INTERACTION_VALUES[*]} != *"Open the local recent-branch workspace"* ]] || exit 16
    alias g="print private-alias-value"
    _prompt_interaction_model g
    [[ $_PROMPT_INTERACTION_KIND == run && ${_PROMPT_INTERACTION_VALUES[*]} != *branches* ]] || {
      print -u2 "custom alias retained the default Git operation"; exit 23
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'tool descriptions use captured help operations and exact aliases without edit-time execution' _test_prompt_owned_descriptions

_test_prompt_description_capture_safety() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/home/.zsh.addons/.zsh.fixture" '
demo() { print -r -- invoked > "$HOME/public-called"; }
_compozsh_help_demo() {
  print -r -- captured >> "$HOME/help-called"
  print -rl -- "usage: demo" "Read fixture metadata." "" "Options:" "  --mode  Read a mode."
}
' || return
  test_write_file "$TEST_TMP_DIR/home/.zsh.addons/.zsh.fixture2" '
demo() { print -r -- invoked > "$HOME/public-called"; }
_compozsh_help_demo() { print -rl -- "usage: demo" "Updated fixture metadata."; }
' || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.prompt"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    source "$1/.zsh.addons/.zsh.tools"
    source "$HOME/.zsh.addons/.zsh.fixture"
    [[ ! -e $HOME/help-called && ! -e $HOME/public-called ]] || exit 1
    _compozsh_prompt_capture
    _compozsh_prompt_capture
    repeat 20 _prompt_interaction_model demo
    local calls=$(<"$HOME/help-called")
    [[ $calls == captured && ! -e $HOME/public-called ]] || exit 2
    [[ ${_PROMPT_INTERACTION_VALUES[*]} == *"Read fixture metadata."* ]] || exit 3
    _tools_refresh
    _compozsh_prompt_capture
    calls=$(<"$HOME/help-called")
    [[ $calls == $'"'"'captured\ncaptured'"'"' ]] || exit 4
    functions[_compozsh_help_demo]='"'"'print -rl -- "usage: demo" "Updated fixture metadata."'"'"'
    _compozsh_prompt_description demo && exit 5
    source "$HOME/.zsh.addons/.zsh.fixture2"
    _compozsh_prompt_capture
    _compozsh_prompt_description demo || exit 6
    [[ $reply[2] == "Updated fixture metadata." ]] || exit 7
    unfunction demo
    _compozsh_prompt_capture
    (( ${+_COMPOZSH_PROMPT_SUMMARIES[demo]} )) && exit 8
    _compozsh_prompt_options_capture fixture $'"'"'  --safe  First description.\n  --safe  Later example.\n  --bad  unsafe\e[31m'"'"'
    [[ ${_COMPOZSH_PROMPT_OPTIONS[fixture:--safe]} == "First description." &&
       -z ${_COMPOZSH_PROMPT_OPTIONS[fixture:--bad]-} ]] || exit 9
    # Alias defaults remain override-preserving and use the same metadata.
    alias la="print custom"
    source "$1/.zsh.addons/.zsh.navigation"
    [[ ${aliases[la]} == "print custom" && ${aliases[ll]} == "ls -lah" ]] || exit 10
    _prompt_interaction_model "g --review | cat"
    [[ $_PROMPT_INTERACTION_KIND == pipeline && ${_PROMPT_INTERACTION_VALUES[*]} != *"Open read-only review"* ]] || exit 11
    _prompt_interaction_model "g --discard-all"
    [[ $_PROMPT_INTERACTION_KIND == caution ]] || exit 12
  ' "$TEST_REPO_ROOT"
}
test_case 'tool descriptions capture once invalidate changed help and preserve safety and overrides' _test_prompt_description_capture_safety

_test_prompt_descriptions_native() {
  test_make_temp_dir || return
  command mkdir -p "$TEST_TMP_DIR/home" || return
  command mkfifo "$TEST_TMP_DIR/home/events" || return
  test_write_file "$TEST_TMP_DIR/home/.zshrc" '
HISTFILE=/dev/null
exec {event_fd}<> "$HOME/events"
for peer in help navigation tools prompt editor; do source "$DESCRIPTION_ROOT/.zsh.addons/.zsh.$peer"; done
for lexical_unit in "$DESCRIPTION_ROOT/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
_description_observe() {
  local slot=${_PROMPT_INTERACTION_LABELS[(Ie)ACTION]}
  (( slot )) || slot=${_PROMPT_INTERACTION_LABELS[(Ie)ABOUT]}
  print -r -u $event_fd -- "FRAME|$BUFFER|$_PROMPT_INTERACTION_KIND|${_PROMPT_INTERACTION_VALUES[$slot]-}"
}
autoload -Uz add-zle-hook-widget
add-zle-hook-widget line-pre-redraw _description_observe
add-zle-hook-widget line-init _description_observe
' || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    zmodload zsh/zpty
    zmodload zsh/zselect
    exec {event_fd}<> "$HOME/events"
    local event="" chunk="" trace="" pfd=0
    _description_driver() {
      export DESCRIPTION_ROOT=$1
      cd "$HOME"
      command stty rows 24 cols 100
      exec "$2" -di
    }
    _description_expect() {
      while zselect -r $event_fd $pfd -t 500; do
        while zpty -r descriptions chunk; do trace+=$chunk; done
        if IFS= read -r -t 0 -u $event_fd event; then
          [[ $event == "$1"* ]] && return 0
        fi
      done
      print -u2 -r -- "expected $1; got $event; ${(V)trace[-1200,-1]}"
      return 1
    }
    zpty -b descriptions _description_driver "$1" "$2" || exit 1
    pfd=$REPLY
    {
      _description_expect "FRAME||ready|" || exit 2
      zpty -w -n descriptions la
      _description_expect "FRAME|la|run|List entries, including hidden files except . and .." || exit 3
      zpty -w -n descriptions $'"'"'\x15'"'"'"g --review"
      _description_expect "FRAME|g --review|git|Open read-only review; optionally compare two local refs." || exit 4
      zpty -w -n descriptions $'"'"'\x15'"'"'"compozsh --sudo-touch-id enable"
      _description_expect "FRAME|compozsh --sudo-touch-id enable|environment|Enable Touch ID authentication for sudo" || exit 5
      zpty -w -n descriptions $'"'"'\x15'"'"'"compozsh --sudo-touch-id disable"
      _description_expect "FRAME|compozsh --sudo-touch-id disable|environment|Disable Compozsh-managed Touch ID authentication for sudo" || exit 6
      while zpty -r descriptions chunk; do trace+=$chunk; done
      [[ $trace == *EXPANSION* && $trace == *"Compozsh help"* &&
         $trace != *"bad math"* && $trace != *"read-only variable"* ]] || exit 7
    } always {
      zpty -d descriptions
      exec {event_fd}>&-
    }
  ' "$TEST_REPO_ROOT" "$TEST_ZSH_BIN"
}
test_case 'tool descriptions react through native ZLE without submitting aliases or privileged modes' _test_prompt_descriptions_native
