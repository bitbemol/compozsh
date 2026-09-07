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
       ${_PROMPT_INTERACTION_VALUES[*]} == *private-alias-value* ]] || exit 14
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

_test_prompt_custom_alias_expansion() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    local name="" position=0 definition=""
    # No navigation/help peer or alias registration is required.
    aliases[my-status]="git status --short"
    aliases[git]="print custom-git"
    aliases[npm]="print custom-npm"
    aliases[nested]="my-status"
    aliases[literal]=$'"'"'print "$(touch $HOME/alias-executed)" `touch $HOME/backtick-executed` %F{red} 雪\n\e[31m'"'"'
    for name in my-status git npm nested literal; do
      definition=${aliases[$name]}
      _prompt_interaction_model "$name"
      position=${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}
      [[ $position != 0 && ${_PROMPT_INTERACTION_VALUES[$position]} == "$definition" &&
         $_PROMPT_INTERACTION_KIND == run ]] || {
        print -u2 -r -- "missing literal custom expansion for $name"; exit 1
      }
      [[ ${_PROMPT_INTERACTION_VALUES[*]} == *"Shell alias · custom definition"* ]] || exit 2
    done
    COLUMNS=200 LINES=12
    _prompt_interaction_layout
    [[ $_PROMPT_INTERACTION_SEGMENT == *EXPANSION* &&
       $_PROMPT_INTERACTION_SEGMENT == *"%%F{red}"* &&
       $_PROMPT_INTERACTION_SEGMENT != *$'"'"'\e[31m'"'"'* &&
       ! -e $HOME/alias-executed && ! -e $HOME/backtick-executed ]] || {
      print -u2 "alias rendering executed a definition or emitted control text"; exit 3
    }
    aliases[my-status]="print changed"
    _prompt_interaction_model my-status
    [[ ${_PROMPT_INTERACTION_VALUES[*]} == *"print changed"* ]] || exit 4
    unalias my-status
    _prompt_interaction_model my-status
    (( ! ${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]} )) || exit 5
    aliases[large]="${(l:10000::x:)}"
    _prompt_interaction_model large
    position=${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}
    [[ $position != 0 && ${#_PROMPT_INTERACTION_VALUES[$position]} == 240 &&
       ${_PROMPT_INTERACTION_VALUES[$position]} == *… ]] || {
      print -u2 "alias display prefix exceeded its bound or lost its omission marker"; exit 6
    }
    for definition in "\\nested" "\"nested\"" "command nested" "print nested"; do
      _prompt_interaction_model "$definition"
      (( ! ${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]} )) || exit 7
    done
  ' "$TEST_REPO_ROOT"
}
test_case 'tool descriptions show bounded literal custom alias expansions without evaluating definitions' _test_prompt_custom_alias_expansion

_test_prompt_alias_forms() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/.zsh.manual"
    for lexical_unit in "$1/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
    aliases[ssh]="ssh -v"
    aliases[rm]="rm -i"
    aliases[empty]=""
    aliases[env]="print environment-alias"
    aliases[command]="print command-alias"
    galiases[GLOBAL]="print global"
    saliases[demo]="print suffix"
    _MANUAL_SUMMARIES[sample.demo]="Unrelated executable manual"
    local -a drafts=(ssh rm empty GLOBAL sample.demo env command)
    local -a definitions=("ssh -v" "rm -i" "\"\"" "print global" "print suffix" "print environment-alias" "print command-alias")
    local index=0 position=0
    for (( index = 1; index <= $#drafts; index++ )); do
      _prompt_interaction_model "$drafts[$index]"
      position=${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}
      [[ $position != 0 && ${_PROMPT_INTERACTION_VALUES[$position]} == "$definitions[$index]" ]] || {
        print -u2 -r -- "missing expansion for $drafts[$index]"; exit 1
      }
      [[ ${_PROMPT_INTERACTION_VALUES[*]} != *"Unrelated executable manual"* ]] || {
        print -u2 "suffix alias borrowed an executable description"; exit 4
      }
      if [[ $drafts[$index] == rm ]]; then
        [[ $_PROMPT_INTERACTION_KIND == caution ]] || exit 2
      else
        [[ $_PROMPT_INTERACTION_KIND == run ]] || exit 3
      fi
    done
    COLUMNS=100 LINES=4
    _prompt_interaction_model rm
    _prompt_interaction_layout
    [[ $_PROMPT_INTERACTION_SEGMENT == *caution-worthy* ]] || {
      print -u2 "alias expansion displaced the caution warning in a short terminal"; exit 5
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'tool descriptions cover remote caution empty global and suffix alias heads' _test_prompt_alias_forms

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
setopt PROMPT_SUBST PROMPT_BANG
exec {event_fd}<> "$HOME/events"
for peer in help navigation tools prompt editor; do source "$DESCRIPTION_ROOT/.zsh.addons/.zsh.$peer"; done
for lexical_unit in "$DESCRIPTION_ROOT/.zsh.addons/support/functions"/.zsh.pure.compozsh_is_*(N.); do source "$lexical_unit"; done
alias work-status="print custom-status"
alias work-other="print custom-other"
alias work-folder="cd ~/Projects/example"
aliases[preview-only]='"'"'print $(touch $HOME/alias-executed)'"'"'
_description_disable_aliases() {
  unsetopt ALIASES
  _zle_prompt_pre_redraw
  print -r -u $event_fd -- "ALIASES:${options[aliases]}:${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]}"
}
zle -N _description_disable_aliases
bindkey "^X^O" _description_disable_aliases
_description_observe() {
  local slot=${_PROMPT_INTERACTION_LABELS[(Ie)ACTION]}
  (( slot )) || slot=${_PROMPT_INTERACTION_LABELS[(Ie)ABOUT]}
  print -r -u $event_fd -- "FRAME|$BUFFER|$_PROMPT_INTERACTION_KIND|${_PROMPT_INTERACTION_VALUES[$slot]-}"
  if (( ${_PROMPT_INTERACTION_LABELS[(Ie)EXPANSION]} )); then
    local -a rows=("${(@f)_PROMPT_INTERACTION_SEGMENT}")
    [[ $rows[-1] == *EXPANSION* ]] &&
      print -r -u $event_fd -- "BOTTOM|$BUFFER|$COLUMNS|$CURSOR"
  fi
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
    local event="" chunk="" trace="" device="" pfd=0
    _description_driver() {
      export DESCRIPTION_ROOT=$1
      cd "$HOME"
      command stty rows 24 cols 100
      print -r -u $event_fd -- "TTY:$(command tty)"
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
    _description_painted() {
      while true; do
        while zpty -r descriptions chunk; do trace+=$chunk; done
        [[ $trace == *"$1"* ]] && return 0
        zselect -r $pfd -t 500 || break
      done
      print -u2 -r -- "expected painted $1; ${(V)trace[-1200,-1]}"
      return 1
    }
    zpty -b descriptions _description_driver "$1" "$2" || exit 1
    pfd=$REPLY
    {
      _description_expect "TTY:" || exit 15
      device=${event#TTY:}
      [[ $device == /dev/ttys<-> || $device == /dev/pts/<-> ]] || exit 16
      _description_expect "FRAME||ready|" || exit 2
      zpty -w -n descriptions la
      _description_expect "FRAME|la|run|List entries, including hidden files except . and .." || exit 3
      _description_expect "BOTTOM|la|100|2" || exit 17
      zpty -w -n descriptions $'"'"'\x15'"'"'".."
      _description_expect "BOTTOM|..|100|2" || exit 18
      trace=""
      zpty -w -n descriptions $'"'"'\x15'"'"'"work-folder"
      _description_expect "BOTTOM|work-folder|100|11" || exit 19
      _description_painted "cd ~/Projects/example" || exit 20
      trace=""
      command stty rows 12 cols 40 < "$device"
      zpty -w -n descriptions $'"'"'\x0c'"'"'
      _description_expect "BOTTOM|work-folder|40|11" || exit 21
      _description_painted "cd ~/Projects/example" || exit 22
      command stty rows 24 cols 100 < "$device"
      zpty -w -n descriptions $'"'"'\x0c'"'"'
      _description_expect "BOTTOM|work-folder|100|11" || exit 23
      zpty -w -n descriptions $'"'"'\x15'"'"'"work-status"
      _description_expect "FRAME|work-status|run|Shell alias · custom definition" || exit 8
      _description_painted "print custom-status" || {
        print -u2 "custom alias definition was not painted in native ZLE"; exit 9
      }
      zpty -w -n descriptions $'"'"'\x15'"'"'"work-status | work-other"
      _description_expect "FRAME|work-status | work-other|pipeline|likely compose literal command output" || exit 12
      _description_painted "print custom-other" || exit 13
      zpty -w -n descriptions $'"'"'\x15'"'"'"preview-only"
      _description_expect "FRAME|preview-only|run|Shell alias · custom definition" || exit 10
      _description_painted "touch" && [[ ! -e $HOME/alias-executed ]] || {
        print -u2 "native alias preview did not remain literal"; exit 11
      }
      zpty -w -n descriptions $'"'"'\x18\x0f'"'"'
      _description_expect "ALIASES:off:0" || exit 14
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
