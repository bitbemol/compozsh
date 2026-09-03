# Palette consumers use semantic roles at invocation, including native fallbacks.

_test_appearance_runtime_labels_use_tool_role() {
  test_make_temp_dir || return
  local scheme='' order='' output=''
  for scheme in dark light; do
    for order in first last; do
      output=$(test_run_interactive "$TEST_TMP_DIR/$scheme-$order" '
        ZSH_COLOR_SCHEME=$2
        [[ $3 == first ]] && source "$1/.zsh.addons/support/.zsh.appearance"
        source "$1/.zsh.addons/.zsh.prompt"
        [[ $3 == last ]] && source "$1/.zsh.addons/support/.zsh.appearance"
        command mkdir "$HOME/project" || exit 1
        _prompt_resolve_project_root() {
          REPLY="$HOME/project"
          _PROMPT_RESOLVED_SOURCE_LANGUAGES=(python swift ruby)
          _PROMPT_RESOLVED_SOURCE_SCAN_SATURATED=1
        }
        _prompt_runtime_version() { REPLY=$fixture_version; }
        _prompt_expected_runtime_version() { REPLY=""; }
        local fixture_version="" mode="" item="" expected="" language=""
        for mode in default custom; do
          [[ $mode == custom ]] && ZSH_PROMPT_COLORS[tool]=123
          for fixture_version in 1.2.3 not-installed unavailable unknown; do
            _prompt_project_context
            expected=${ZSH_PROMPT_COLORS[tool]}
            [[ $fixture_version != 1.2.3 ]] && expected=${ZSH_PROMPT_COLORS[danger]}
            (( ${#_PROMPT_PROJECT_ITEMS} == 3 )) || exit 2
            for language in python swift ruby; do
              item="%F{${expected}}$language $fixture_version%f"
              (( ${_PROMPT_PROJECT_ITEMS[(Ie)$item]} )) || {
                print -u2 -- "runtime label did not use its semantic role: $language $mode $fixture_version"
                exit 3
              }
            done
          done
        done
        print semantic
      ' "$TEST_REPO_ROOT" "$scheme" "$order") || return
      test_assert_equal semantic "$output" || return
    done
  done
}
test_case 'appearance runtime labels follow tool colors and retain diagnostic text' \
  _test_appearance_runtime_labels_use_tool_role

_test_appearance_navigation_native_colors_and_plain_fallbacks() {
  test_make_temp_dir || return
  local scheme='' output=''
  for scheme in dark light; do
  output=$(test_run_interactive "$TEST_TMP_DIR/$scheme" '
    setopt EXTENDED_GLOB
    export LC_ALL=en_US.UTF-8
    ZSH_COLOR_SCHEME=$2
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.navigation"
    zmodload zsh/zpty || exit 1
    _navigation_fixture() {
      _GIT_RECENT_BRANCHES=(main feature/example)
      _GIT_RECENT_CURRENT=main
      _git_branch_stack_print
      print END-NAVIGATION
    }
    _navigation_capture() {
      local chunk="" captured=""
      zpty appearance-navigation _navigation_fixture || return 1
      {
        while zpty -r appearance-navigation chunk; do
          captured+=$chunk
          [[ $chunk == *END-NAVIGATION* ]] && break
        done
        [[ $captured == *END-NAVIGATION* ]] || return 1
        REPLY=${captured//$'\''\r'\''/}
        REPLY=${REPLY%$'\''\n'\''}
      } always {
        zpty -d appearance-navigation
      }
    }
    local plain=$'\''Branch stack\n[0] ● main\n[1] ↳ feature/example\nEND-NAVIGATION'\''
    local captured="" stripped="" role="" color="" mode=""
    _navigation_capture || exit 2
    [[ $REPLY == "$plain" ]] || { print -u2 -- "standalone navigation was not plain"; exit 3; }
    source "$1/.zsh.addons/.zsh.output"
      for mode in default custom; do
        [[ $mode == custom ]] && ZSH_OUTPUT_COLORS=(heading 123 accent 124 success 125 muted 126)
        captured=$(_navigation_fixture)
        [[ $captured == "$plain" ]] || { print -u2 -- "redirected navigation contains color"; exit 4; }
        _navigation_capture || exit 5
        captured=$REPLY
        for role in heading accent success muted; do
          _output_color "$role" 75
          color=$REPLY
          [[ $captured == *$'\''\e[38;5;'\''"${color}m"* ]] || {
            print -u2 -- "navigation did not paint semantic $role"
            exit 6
          }
        done
        stripped=${captured//$'\''\e'\''\[[0-9\;]#m/}
        [[ $stripped == "$plain" ]] || { print -u2 -- "navigation styling changed text"; exit 13; }
        NO_COLOR=1
        _navigation_capture || exit 7
        [[ $REPLY == "$plain" ]] || { print -u2 -- "NO_COLOR navigation contains color"; exit 8; }
        unset NO_COLOR
        TERM=dumb
        _navigation_capture || exit 9
        [[ $REPLY == "$plain" ]] || { print -u2 -- "dumb navigation contains color"; exit 10; }
        TERM=xterm
        _navigation_capture || exit 11
        [[ $REPLY == "$plain" ]] || { print -u2 -- "limited-color navigation contains color"; exit 12; }
        TERM=xterm-256color
      done
    print semantic
  ' "$TEST_REPO_ROOT" "$scheme") || return
  test_assert_equal semantic "$output" || return
  done
}
test_case 'appearance navigation prints semantic native colors with exact plain fallbacks' \
  _test_appearance_navigation_native_colors_and_plain_fallbacks

_test_appearance_completion_chrome_uses_runtime_palette() {
  test_make_temp_dir || return
  local scheme='' order='' output=''
  for scheme in dark light; do
    for order in first last; do
      output=$(test_run_interactive "$TEST_TMP_DIR/$scheme-$order" '
        ZSH_COLOR_SCHEME=$2
        [[ $3 == first ]] && source "$1/.zsh.addons/support/.zsh.appearance"
        source "$1/.zsh.addons/.zsh.editor"
        source "$1/.zsh.addons/support/.zsh.ui"
        [[ $3 == last ]] && source "$1/.zsh.addons/support/.zsh.appearance"
        zmodload zsh/zpty || exit 1
        _completion_fixture() {
          local description="" warning=""
          zstyle -s ":completion:*:descriptions" format description || return 1
          zstyle -s ":completion:*:warnings" format warning || return 2
          [[ $description == *"-- %d --"* ]] || return 3
          description=${description//\%d/example}
          print -P -- "$description"
          print -P -- "$warning"
          print END-COMPLETION
        }
        _completion_capture() {
          local chunk="" captured=""
          zpty appearance-completion _completion_fixture || return 1
          {
            while zpty -r appearance-completion chunk; do
              captured+=$chunk
              [[ $chunk == *END-COMPLETION* ]] && break
            done
            [[ $captured == *END-COMPLETION* ]] || return 1
            REPLY=${captured//$'\''\r'\''/}
            REPLY=${REPLY%$'\''\n'\''}
          } always {
            zpty -d appearance-completion
          }
        }
        local peer="" mode="" captured="" heading="" error="" plain=""
        # Substitute the same synthetic description in colored and plain modes.
        for peer in standalone output; do
          [[ $peer == output ]] && source "$1/.zsh.addons/.zsh.output"
          for mode in default custom invalid; do
            [[ $mode == custom ]] && ZSH_OUTPUT_COLORS=(heading 123 error 124)
            [[ $mode == invalid ]] && ZSH_OUTPUT_COLORS=(heading invalid error invalid)
            _zle_picker_output_color heading 75; heading=$REPLY
            _zle_picker_output_color error 203; error=$REPLY
            _completion_capture || exit 2
            captured=$REPLY
            [[ $captured == *$'\''\e[38;5;'\''"${heading}m"* &&
               $captured == *$'\''\e[38;5;'\''"${error}m"* ]] || {
              print -u2 -- "completion chrome ignored $peer $mode palette"
              exit 3
            }
            NO_COLOR=1
            _completion_capture || exit 4
            [[ $REPLY != *$'\''\e'\''* && $REPLY == *"no matches"* ]] || exit 5
            plain=$REPLY
            unset NO_COLOR
            TERM=dumb
            _completion_capture || exit 6
            [[ $REPLY == "$plain" ]] || exit 7
            TERM=xterm-256color
            captured=$(_completion_fixture)
            [[ $captured == "$plain" ]] || exit 8
          done
        done
        print semantic
      ' "$TEST_REPO_ROOT" "$scheme" "$order") || return
      test_assert_equal semantic "$output" || return
    done
  done
}
test_case 'appearance completion descriptions and warnings adapt at invocation in either peer order' \
  _test_appearance_completion_chrome_uses_runtime_palette

_test_appearance_completion_candidates_respect_color_capability() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.appearance"
    zmodload zsh/zpty || exit 1
    command mkdir "$HOME/alpha" "$HOME/beta" || exit 2
    builtin cd "$HOME" || exit 3
    _completion_native_init() {
      BUFFER="print ./" CURSOR=8
      zle list-choices
      zle -R
      zle .accept-line
    }
    zle -N appearance-completion-init _completion_native_init
    _completion_native_fixture() {
      command stty rows 30 cols 100
      local draft=""
      vared -i appearance-completion-init draft
      print END-COMPLETION
    }
    local mode="" chunk="" trace=""
    local color_pattern=$'\''\e'\''"\\[([0-9]+;)*(3[0-7]|4[0-7]|9[0-7]|10[0-7]|38;5;[0-9]+|48;5;[0-9]+)m"
    for mode in default no-color limited unsupported custom-ls-colors custom-style; do
      TERM=xterm-256color
      unset NO_COLOR LS_COLORS
      case $mode in
        no-color) NO_COLOR=1 ;;
        limited) TERM=xterm ;;
        unsupported) TERM=dumb ;;
        custom-ls-colors) LS_COLORS="di=38;5;123" ;;
        custom-style) zstyle ":completion:*" list-colors "di=38;5;124" ;;
      esac
      trace=""
      zpty completion-candidates _completion_native_fixture || exit 4
      {
        while zpty -r completion-candidates chunk; do
          trace+=$chunk
          [[ $chunk == *END-COMPLETION* ]] && break
        done
      } always {
        zpty -d completion-candidates
      }
      [[ $trace == *alpha* && $trace == *beta* && $trace == *END-COMPLETION* ]] || {
        print -u2 -- "$mode: native completion did not display both candidates"
        exit 5
      }
      case $mode in
        no-color|limited|unsupported)
          [[ ! $trace =~ $color_pattern ]] || {
            print -u2 -- "$mode: native completion candidates still contain color"
            exit 6
          } ;;
        default) [[ $trace == *$'\''\e[1;38;5;39m'\''* ]] || exit 7 ;;
        custom-ls-colors) [[ $trace == *$'\''\e[38;5;123m'\''* ]] || exit 8 ;;
        custom-style) [[ $trace == *$'\''\e[38;5;124m'\''* ]] || exit 9 ;;
      esac
    done
    print compatible
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal compatible "$output"
}
test_case 'appearance native completion candidates honor NO_COLOR and terminal color capability' \
  _test_appearance_completion_candidates_respect_color_capability

_test_appearance_completion_unset_output_palette() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.appearance"
    unset ZSH_OUTPUT_COLORS
    local heading="chapter title" chunk="" trace=""
    zmodload zsh/zpty || exit 1
    _completion_reset_fixture() {
      local -a reply=()
      _zle_completion_format heading || return 1
      [[ $reply[1] == "%F{75}-- %d --%f" && ! ${+ZSH_OUTPUT_COLORS} == 1 ]] || return 2
      print RESET-COMPLETION
    }
    zpty completion-reset _completion_reset_fixture || exit 2
    {
      while zpty -r completion-reset chunk; do trace+=$chunk; done
    } always {
      zpty -d completion-reset
    }
    [[ $trace == "RESET-COMPLETION"$'\''\r\n'\'' ]] || {
      print -u2 -r -- "$trace"
      exit 3
    }
    print restored
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal restored "$output"
}
test_case 'appearance completion resolves defaults after the public output palette is unset' \
  _test_appearance_completion_unset_output_palette

_test_appearance_autosuggestion_unset_highlight_palette() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    source "$1/.zsh.addons/support/.zsh.appearance"
    unset ZSH_HIGHLIGHT_STYLES
    local autosuggestion="shell variable with spaces"
    BUFFER=print CURSOR=5 PREDISPLAY="" POSTDISPLAY=""
    _zle_autosuggest_find() { _ZLE_AUTOSUGGEST_CACHE_FULL="print example"; }
    _zle_autosuggest_update
    [[ $POSTDISPLAY == " example" && ! ${+ZSH_HIGHLIGHT_STYLES} == 1 &&
       $region_highlight[-1] == "P5 13 fg=245 memo=my-zsh-autosuggestion" ]] || exit 1
    print restored
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal restored "$output"
}
test_case 'appearance autosuggestion resolves defaults after the public highlight palette is unset' \
  _test_appearance_autosuggestion_unset_highlight_palette
