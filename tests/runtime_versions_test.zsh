# Runtime requirements are observations, not build-compatibility validation.
_test_runtime_versions_warning_severity() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/project/.swift-version" '6.3.2' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/.zsh.appearance"
    ZSH_PROMPT_COLORS[warning]=123
    ZSH_PROMPT_COLORS[danger]=124
    builtin cd "$2" || exit 1
    _prompt_runtime_version() { REPLY=$fixture_version; }
    for fixture_version in 6.4 6.1 6.3.2; do
      _prompt_project_context
      print -r -- "${(j:|:)_PROMPT_PROJECT_ITEMS}"
    done
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project") || return
  test_assert_contains "$output" '%F{123}⚠ swift wants 6.3.2 · using 6.4 — newer%f' || return
  test_assert_contains "$output" '%F{124}⚠ swift wants 6.3.2 · using 6.1 — older%f' || return
  [[ ${${(f)output}[-1]} != *'⚠'* ]] || test_fail 'matching version warned'
}
test_case 'runtime versions show requested and installed versions with directional severity' _test_runtime_versions_warning_severity

_test_runtime_versions_comparison() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    [[ -f "$1/.zsh.addons/support/functions/.zsh.pure.runtime_version_relation" ]] || { print -u2 "runtime comparison capability absent"; exit 1; }
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    check() {
      _runtime_version_relation "$1" "$2" "$3"
      [[ $REPLY == "$4" ]] || { print -u2 -- "$*: $REPLY"; return 1; }
    }
    check 6.4 6.3.2 pin newer || exit
    check 6.1 6.3.2 pin older || exit
    check 6.3.2 6.3 pin match || exit
    check 6.3 6.3.0 pin match || exit
    check 3.10 3.9 pin newer || exit
    check v22.3.0 22 pin match || exit
    check 1.25.0 1.24 minimum match || exit
    check 1.23.9 1.24 minimum older || exit
    check 1.90.0 nightly pin unknown || exit
    check 1.90.0-beta 1.89 pin unknown || exit
    check 3.13 ">=3.10,<3.14" range match || exit
    check 3.14 ">=3.10,<3.14" range outside || exit
    check 3.9 ">=3.10,<3.14" range outside || exit
    check 3.13 "~=3.10" range unknown || exit
    check 3.13 ">=3.1 0" range unknown || exit
    check 1.2 "1.2 evil" pin unknown || exit
    check 999999999999999999999999 2 pin unknown || exit
    print compared
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal compared "$output"
}
test_case 'runtime versions compare numeric pins minimums and bounded ranges without guessing' _test_runtime_versions_comparison

_test_runtime_versions_sources() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/rust/rust-toolchain.toml" $'[toolchain]\nchannel = "1.88.0"\ncomponents = ["rustfmt"]' || return
  test_write_file "$TEST_TMP_DIR/rust-legacy/rust-toolchain" $'\n  [toolchain]\nchannel = "1.87.0"' || return
  test_write_file "$TEST_TMP_DIR/go/go.mod" $'module example.invalid/test\ngo 1.24.0\ntoolchain go1.25.0' || return
  test_write_file "$TEST_TMP_DIR/swift/Package.swift" '// swift-tools-version: 6.3' || return
  test_write_file "$TEST_TMP_DIR/cargo/Cargo.toml" $'[package]\nname = "fixture"\nrust-version = "1.85"' || return
  test_write_file "$TEST_TMP_DIR/python/pyproject.toml" $'[project]\nrequires-python = ">=3.10,<3.14"' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    for pair in rust:rust go:go swift:swift rust:cargo python:python rust:rust-legacy; do
      _prompt_expected_runtime_version "${pair%%:*}" "$2/${pair#*:}"
      print -r -- "$REPLY|$_RUNTIME_REQUIREMENT_KIND|$_RUNTIME_REQUIREMENT_SOURCE"
    done
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal $'1.88.0|pin|rust-toolchain.toml\n1.24.0|minimum|go.mod\n6.3|minimum|Package.swift\n1.85|minimum|Cargo.toml\n>=3.10,<3.14|range|pyproject.toml\n1.87.0|pin|rust-toolchain' "$output"
}
test_case 'runtime versions read Rust TOML and source-specific minimum requirements' _test_runtime_versions_sources

_test_runtime_versions_malformed_sources() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/multiline/rust-toolchain.toml" $'description = """\n[toolchain]\nchannel = "1.88"\n"""' || return
  test_write_file "$TEST_TMP_DIR/duplicate/rust-toolchain.toml" $'[toolchain]\nchannel = "1.88"\nchannel = "1.89"' || return
  test_write_file "$TEST_TMP_DIR/long/.python-version" "${(l:300::1:)}" || return
  test_write_file "$TEST_TMP_DIR/alternatives/.tool-versions" 'python 3.12 3.13' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    for pair in rust:multiline rust:duplicate python:long python:alternatives; do
      _prompt_expected_runtime_version "${pair%%:*}" "$2/${pair#*:}"
      [[ $REPLY == unknown ]] || { print -u2 -- "$pair returned $REPLY"; exit 1; }
    done
    print bounded
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal bounded "$output"
}
test_case 'runtime versions refuse malformed multiline duplicate and oversized selectors' _test_runtime_versions_malformed_sources

_test_runtime_versions_scala_probe() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/scala-cli" $'#!/bin/sh\n[ "$*" = "version --offline" ] || exit 9\nprintf "Scala CLI version: 1.8.1\\nScala version (default): 3.7.0\\n"' || return
  command chmod +x "$TEST_TMP_DIR/bin/scala-cli" || return
  command mkdir "$TEST_TMP_DIR/project" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2/bin" /usr/bin /bin)
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_runtime_version scala "$2/project"
    print -r -- "$REPLY"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal 3.7.0 "$output" 'Scala CLI version was mistaken for Scala language version'
}
test_case 'runtime versions show Scala language version rather than launcher version' _test_runtime_versions_scala_probe

_test_runtime_versions_inventory_and_order() {
  test_make_temp_dir || return
  local output='' order=''
  for order in first last rotated; do
    output=$(test_run_interactive "$TEST_TMP_DIR/$order" '
      zmodload zsh/parameter
      local -a units=("$1/.zsh.addons/.zsh.prompt" "$1/.zsh.addons"/support/functions/.zsh.{pure,impure}.{runtime,prompt}_*(N.) "$1/.zsh.addons/support/.zsh.appearance")
      case $2 in first) units=("${(Oa)units[@]}");; rotated) units=("$units[-1]" "${(@)units[1,-2]}");; esac
      for unit in "$units[@]"; do source "$unit" || exit; done
      _PROMPT_RUNTIME_VERSION_CACHE[fixture]=retained
      for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
      [[ $_PROMPT_RUNTIME_VERSION_CACHE[fixture] == retained ]] || exit 2
      [[ $functions_source[_prompt_runtime_version] == */support/functions/.zsh.impure.prompt_runtime_version &&
         $functions_source[_prompt_expected_runtime_version] == */support/functions/.zsh.impure.prompt_expected_runtime_version ]] || exit 3
      command mkdir "$HOME/project" || exit
      local language name actual=2.0
      local -a filenames
      for language in ${(ok)_RUNTIME_VERSION_FILES}; do
        filenames=(${=_RUNTIME_VERSION_FILES[$language]})
        name=$filenames[1]
        print -r -- 1.0 >| "$HOME/project/$name"
        _prompt_expected_runtime_version "$language" "$HOME/project"
        [[ $REPLY == 1.0 && $_RUNTIME_REQUIREMENT_KIND == pin ]] || exit 4
        _runtime_version_relation "$actual" "$REPLY" "$_RUNTIME_REQUIREMENT_KIND"
        [[ $REPLY == newer ]] || exit 5
        command rm "$HOME/project/$name"
      done
      print order-independent
    ' "$TEST_REPO_ROOT" "$order") || return
    test_assert_equal order-independent "$output" || return
  done
}
test_case 'runtime versions inventory shares comparison across tools in checked peer orders' _test_runtime_versions_inventory_and_order

_test_runtime_versions_missing_peer() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/project/.swift-version" '6.3.2' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    builtin cd "$2"
    _prompt_project_context
    [[ $_PROMPT_PROJECT_NAME_TEXT == project && ${(j:|:)_PROMPT_PROJECT_ITEMS} != *wants* ]] || exit 1
    (( ! ${+functions[_prompt_runtime_version]} )) || exit 2
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_runtime_version() { REPLY=6.4; }
    _prompt_project_context
    [[ ${(j:|:)_PROMPT_PROJECT_ITEMS} == *"swift wants 6.3.2 · using 6.4 — newer"* ]] || exit 3
    print deferred
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project") || return
  test_assert_equal deferred "$output"
}
test_case 'runtime versions optional peer can arrive after standalone prompt use' _test_runtime_versions_missing_peer

_test_runtime_versions_metadata_read() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/value" $'6.3.2\n' || return
  test_write_file "$TEST_TMP_DIR/first" $'6.3.2\nUNNEEDED-FIXTURE-TEXT' || return
  command ln -s "$TEST_TMP_DIR/value" "$TEST_TMP_DIR/link" || return
  command mkfifo "$TEST_TMP_DIR/pipe" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    (( ${+functions[_runtime_read_metadata]} )) || { print -u2 "bounded descriptor reader absent"; exit 1; }
    _runtime_read_metadata "$2/value" || exit 2
    [[ $REPLY == 6.3.2* ]] || exit 3
    _runtime_read_metadata "$2/first" first-line || exit 8
    [[ $REPLY == 6.3.2 ]] || { print -u2 "first-line reader retained unrelated body"; exit 9; }
    for name in link pipe missing; do
      _runtime_read_metadata "$2/$name" && exit 4
      [[ -z $REPLY ]] || exit 5
    done
    _PROMPT_METADATA_MAX_BYTES=3
    _runtime_read_metadata "$2/value" && exit 6
    [[ -z $REPLY ]] || exit 7
    print guarded
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal guarded "$output"
}
test_case 'runtime versions capture bounded regular text without following symlinks or blocking on FIFOs' _test_runtime_versions_metadata_read

_test_runtime_versions_implementation_identity() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/luajit" $'#!/bin/sh\nprintf "LuaJIT 2.1.0 -- fixture\\n"' || return
  test_write_file "$TEST_TMP_DIR/bin/godot" $'#!/bin/sh\nprintf "4.6.beta1.official.fixture\\n"' || return
  command chmod +x "$TEST_TMP_DIR/bin/luajit" "$TEST_TMP_DIR/bin/godot" || return
  command mkdir "$TEST_TMP_DIR/project" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    path=("$2/bin" /usr/bin /bin)
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_runtime_version lua "$2/project"; print -r -- "$REPLY"
    _prompt_runtime_version gdscript "$2/project"; print -r -- "$REPLY"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal $'luajit 2.1.0\n4.6.beta1.official.fixture' "$output"
}
test_case 'runtime versions preserve LuaJIT identity and Godot prerelease information' _test_runtime_versions_implementation_identity

_test_runtime_versions_native_prompt() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/Package.swift" '// fixture' || return
  test_write_file "$TEST_TMP_DIR/project/.swift-version" '6.3.2' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.prompt"
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
    source "$1/.zsh.addons/support/functions/.zsh.pure.zle_picker_abbreviate"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/.zsh.appearance"
    ZSH_PROMPT_COLORS[warning]=123 ZSH_PROMPT_COLORS[danger]=124
    zmodload zsh/zpty
    zmodload zsh/zselect
    _prompt_runtime_version() { REPLY=$fixture_version; }
    _runtime_native_driver() {
      command stty rows 30 cols 120
      builtin cd "$2"
      local fixture_version=6.4 value=""
      for fixture_version in 6.4 6.1; do
        COLUMNS=120 LINES=30
        _prompt_update
        _PROMPT_VIEW=lens
        _prompt_layout
        _prompt_base
        value=""
        vared -p "$PROMPT" value || return 1
        [[ $value == draft ]] || return 2
      done
      print -r -- VERIFIED
    }
    zpty -b runtime-native _runtime_native_driver "$1" "$2" || exit 1
    local pty_fd=$REPLY chunk="" trace="" round="newer"
    {
      while zselect -r $pty_fd -t 300; do
        while zpty -r runtime-native chunk 2>/dev/null; do trace+=$chunk; done
        if [[ $round == newer && $trace == *"— newer"* ]]; then
          [[ $trace == *"swift wants 6.3.2"* && $trace == *"using 6.4"* && $trace == *"38;5;123m"* ]] || exit 2
          zpty -w runtime-native draft
          round=older
        elif [[ $round == older && $trace == *"— older"* ]]; then
          [[ $trace == *"using 6.1"* && $trace == *"38;5;124m"* ]] || exit 3
          zpty -w runtime-native draft
          round=done
        fi
        [[ $trace == *VERIFIED* ]] && break
      done
      [[ $trace == *VERIFIED* && $trace != *"command not found"* && $trace != *"bad pattern"* ]] || { print -u2 -- "$trace"; exit 4; }
    } always {
      zpty -d runtime-native 2>/dev/null
    }
    print native
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/project") || return
  test_assert_equal native "$output"
}
test_case 'runtime versions paint semantic warnings in native ZLE and preserve entered text' _test_runtime_versions_native_prompt

_test_runtime_versions_ambiguous_scala_launcher() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/bin/scala" $'#!/bin/sh\n: > "$SCALA_PROBE"\nprintf "Scala CLI version: 1.8.1\\nScala version (default): 3.7.0\\n"' || return
  command chmod +x "$TEST_TMP_DIR/bin/scala" || return
  command mkdir "$TEST_TMP_DIR/project" || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export SCALA_PROBE="$2/scala-probe"
    path=("$2/bin" /usr/bin /bin)
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_runtime_version scala "$2/project"
    print -r -- "$REPLY"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal launcher-managed "$output" 'ambiguous Scala launcher was probed without a known offline interface' || return
  [[ ! -e "$TEST_TMP_DIR/scala-probe" ]] || test_fail 'ambiguous launcher executed'
}
test_case 'runtime versions leave ambiguous Scala launchers unprobed' _test_runtime_versions_ambiguous_scala_launcher

_test_runtime_versions_incomplete_first_line() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/.swift-version" "6.3${(l:4093:: :)}extra" || return
  test_write_file "$TEST_TMP_DIR/exact" "${(l:4096::1:)}" || return
  test_write_file "$TEST_TMP_DIR/complete" '6.3' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_expected_runtime_version swift "$2/project"
    [[ $REPLY == unknown ]] || { print -u2 -- "incomplete selector accepted: $REPLY"; exit 1; }
    _runtime_read_metadata "$2/exact" first-line && exit 2
    [[ -z $REPLY ]] || exit 3
    _runtime_read_metadata "$2/complete" first-line || exit 4
    [[ $REPLY == 6.3 ]] || exit 5
    print complete
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal complete "$output"
}
test_case 'runtime versions reject a first line whose ending was not captured' _test_runtime_versions_incomplete_first_line

_test_runtime_versions_parser_budgets() {
  test_make_temp_dir || return
  local wide="#${(l:4096:: :)}" many='' total='' index
  for (( index=0; index<257; ++index )); do many+=$'# bounded comment\n'; done
  for (( index=0; index<100; ++index )); do total+="#${(l:1023:: :)}"$'\n'; done
  local pair language filename header
  for pair in rust:rust-toolchain.toml rust:Cargo.toml python:pyproject.toml python:.tool-versions go:go.mod go:go.work; do
    language=${pair%%:*} filename=${pair#*:}
    case $filename in
      rust-toolchain.toml) header=$'[toolchain]\nchannel = "1.88"\n' ;;
      Cargo.toml) header=$'[package]\nrust-version = "1.88"\n' ;;
      pyproject.toml) header=$'[project]\nrequires-python = ">=3.10"\n' ;;
      .tool-versions) header=$'python 3.12\n' ;;
      go.mod|go.work) header=$'go 1.24\n'; wide="//${(l:4096:: :)}"; many=${many//\#/\/\/}; total=${total//\#/\/\/} ;;
    esac
    test_write_file "$TEST_TMP_DIR/$filename-wide/$filename" "$header$wide" || return
    test_write_file "$TEST_TMP_DIR/$filename-many/$filename" "$header$many" || return
    test_write_file "$TEST_TMP_DIR/$filename-total/$filename" "$header$total" || return
  done
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    local pair filename flavor
    for pair in rust:rust-toolchain.toml rust:Cargo.toml python:pyproject.toml python:.tool-versions go:go.mod go:go.work; do
      for flavor in wide many total; do
        _prompt_expected_runtime_version "${pair%%:*}" "$2/${pair#*:}-$flavor"
        [[ $REPLY == unknown ]] || { print -u2 -- "$pair $flavor exceeded parser budget but returned $REPLY"; exit 1; }
      done
    done
    _runtime_toml_scalar "$3" toolchain channel
    [[ $REPLY == unknown ]] || { print -u2 "direct TOML parser bypassed budget"; exit 2; }
    print bounded
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR" "${(l:4097:: :)}") || return
  test_assert_equal bounded "$output"
}
test_case 'runtime versions bound full metadata line length and count before parsing' _test_runtime_versions_parser_budgets

_test_runtime_versions_toml_headers_and_keys() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    local text
    for text in "$@"; do
      [[ $text == "$1" ]] && continue
      _runtime_toml_scalar "$text" toolchain channel
      [[ $REPLY == unknown ]] || { print -u2 -- "malformed or duplicate TOML accepted: $REPLY"; exit 1; }
    done
    print conservative
  ' "$TEST_REPO_ROOT" $'[toolchain\nchannel = "1.88"' \
    $'[toolchain] invalid\nchannel = "1.88"' \
    $'[toolchain]\nchannel = "1.88"\n"channel" = "1.89"' \
    $'[toolchain]\nchannel = "1.88"\n\'channel\' = "1.89"') || return
  test_assert_equal conservative "$output"
}
test_case 'runtime versions refuse malformed TOML headers and quoted duplicate keys' _test_runtime_versions_toml_headers_and_keys

_test_runtime_versions_oversized_fallback() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/project/.python-version" "${(l:1048577::1:)}" || return
  test_write_file "$TEST_TMP_DIR/project/.tool-versions" 'python 3.12' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _prompt_expected_runtime_version python "$2/project"
    print -r -- "$REPLY|$_RUNTIME_REQUIREMENT_SOURCE"
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal '3.12|.tool-versions' "$output"
}
test_case 'runtime versions keep skipping oversized files before source fallback' _test_runtime_versions_oversized_fallback

_test_runtime_versions_bounded_whitespace() {
  test_make_temp_dir || return
  local padding=${(l:2000:: :)} text
  text="${padding}[toolchain]${padding}"$'\n'
  text+="$padding"'channel = "1.88"'"$padding"$'\n'
  text+="$padding"$'\n# comment\n'
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _runtime_toml_scalar "$2" toolchain channel
    [[ $REPLY == 1.88 ]] || { print -u2 -- "bounded whitespace changed parsing: $REPLY"; exit 1; }
    print whitespace
  ' "$TEST_REPO_ROOT" "$text") || return
  test_assert_equal whitespace "$output"
}
test_case 'runtime versions preserve supported whitespace within parser bounds' _test_runtime_versions_bounded_whitespace

_test_runtime_versions_escaped_toml_key() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _runtime_toml_scalar "$2" toolchain channel
    [[ $REPLY == unknown ]] || { print -u2 -- "escaped key could conceal duplicate: $REPLY"; exit 1; }
    print unverified
  ' "$TEST_REPO_ROOT" $'[toolchain]\nchannel = "1.88"\n"chan\\u006eel" = "1.89"') || return
  test_assert_equal unverified "$output"
}
test_case 'runtime versions decline escaped quoted assignment keys in the requested TOML table' _test_runtime_versions_escaped_toml_key

_test_runtime_versions_escaped_toml_table() {
  test_make_temp_dir || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    _runtime_toml_scalar "$2" package rust-version
    [[ $REPLY == unknown ]] || { print -u2 -- "escaped table could conceal duplicate: $REPLY"; exit 1; }
    print unverified
  ' "$TEST_REPO_ROOT" $'[package]\nrust-version = "1.80"\n["pac\\u006bage"]\nrust-version = "1.90"') || return
  test_assert_equal unverified "$output"
}
test_case 'runtime versions decline escaped TOML table names that could alias the requested table' _test_runtime_versions_escaped_toml_table

_test_runtime_versions_empty_toml_requirement() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/rust/Cargo.toml" $'[package]\nrust-version = ""' || return
  test_write_file "$TEST_TMP_DIR/rust-space/Cargo.toml" $'[package]\nrust-version = "   "' || return
  test_write_file "$TEST_TMP_DIR/python/pyproject.toml" $'[project]\nrequires-python = ""' || return
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    local fixture
    for fixture in rust rust-space; do
      _prompt_expected_runtime_version rust "$2/$fixture"
      [[ $REPLY == unknown ]] || { print -u2 -- "$fixture empty requirement disappeared: $REPLY"; exit 1; }
    done
    _prompt_expected_runtime_version python "$2/python"
    [[ -z $REPLY ]] || { print -u2 "empty Python range is unconstrained"; exit 2; }
    print explicit
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal explicit "$output"
}
test_case 'runtime versions distinguish invalid empty Cargo minima from unconstrained Python ranges' _test_runtime_versions_empty_toml_requirement

_test_runtime_versions_go_directives() {
  test_make_temp_dir || return
  local name flavor
  for name in go.mod go.work; do
    test_write_file "$TEST_TMP_DIR/$name-extra/$name" $'go 1.24 invalid\n' || return
    test_write_file "$TEST_TMP_DIR/$name-duplicate/$name" $'go 1.24\ngo 1.99\n' || return
    test_write_file "$TEST_TMP_DIR/$name-comment/$name" $'go 1.24 // minimum\n// go 1.99 is a comment\n' || return
  done
  local output=''
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.{runtime,prompt}_*(N.); do source "$support_component"; done
    local name flavor expected
    for name in go.mod go.work; do
      for flavor in extra duplicate comment; do
        expected=unknown
        [[ $flavor == comment ]] && expected=1.24
        _prompt_expected_runtime_version go "$2/$name-$flavor"
        [[ $REPLY == "$expected" ]] || { print -u2 -- "$name $flavor incorrectly returned $REPLY"; exit 1; }
      done
    done
    print checked
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR") || return
  test_assert_equal checked "$output"
}
test_case 'runtime versions refuse malformed and duplicate Go minimum directives while allowing comments' _test_runtime_versions_go_directives
