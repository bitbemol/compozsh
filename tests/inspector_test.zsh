# Regression tests for the optional tool inspector.
_test_inspector_snapshot() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.tools"
    _compozsh_tool_capture
    _compozsh_tool_inspector_capture || exit 1
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[cpdir]} == *"usage: cpdir"* ]] || exit 2
    print snapshot
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal snapshot "$output"
}
test_case "inspector captures canonical help" _test_inspector_snapshot

_test_inspector_layout() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    _ZLE_PICKER_TITLE="Tools"
    _ZLE_PICKER_RESULTS=(sample other)
    _ZLE_PICKER_LABELS=(sample other)
    _ZLE_PICKER_RESULT_INDEXES=(1 2)
    typeset -gA _ZLE_PICKER_INSPECT_TEXTS=(
      sample "$(print -rl -- "usage: sample" "Sample guide." {1..80})"
      other "usage: other")
    COLUMNS=120 LINES=30
    _zle_picker_render sample 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"Sample guide."* ]] || exit 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"│"* ]] || exit 2
    _ZLE_PICKER_INSPECT_FOCUS=1
    _ZLE_PICKER_INSPECT_OFFSET=20
    _zle_picker_render sample 1
    (( _ZLE_PICKER_INSPECT_OFFSET == 20 )) || exit 3
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"Sample guide."* ]] || exit 4
    COLUMNS=45
    _zle_picker_render sample 1
    (( !_ZLE_PICKER_INDEXES_VISIBLE )) || exit 5
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"│"* ]] || exit 6
    _ZLE_PICKER_INSPECT_FOCUS=0
    _zle_picker_render sample 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *sample* ]] || exit 7
    _zle_picker_render sample 2
    (( _ZLE_PICKER_INSPECT_OFFSET == 0 )) || exit 8
    _ZLE_PICKER_INSPECT_TEXTS=()
    _zle_picker_render sample 1
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} != *"Help"* ]] || exit 9
    print responsive
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal responsive "$output"
}
test_case 'inspector adapts panes and scrolls captured help' _test_inspector_layout

_test_inspector_bounds_and_literals() {
  test_make_temp_dir || return
  local output addon="$TEST_TMP_DIR/home/.zsh.addons/.zsh.fixture"
  test_write_file "$addon" '
    safe-tool() { print bad > "$HOME/ran"; }
    no-help() { print bad > "$HOME/ran"; }
    _compozsh_help_safe-tool() {
      print -rl -- "usage: safe-tool" "Literal %F{red} text"
      print -r -- ${(l:40000::x:)}
    }
  ' || return
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$2"
    _compozsh_tool_capture
    _compozsh_tool_inspector_capture
    [[ ! -e "$HOME/ran" ]] || exit 1
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[no-help]} == *"No Compozsh help"* ]] || exit 2
    (( ${#_ZLE_PICKER_INSPECT_TEXTS[safe-tool]} < 33000 )) || exit 3
    [[ ${_ZLE_PICKER_INSPECT_TEXTS[safe-tool]} == *truncated* ]] || exit 4
    _zle_picker_inspect_prepare safe-tool 40
    (( ${#_ZLE_PICKER_INSPECT_LINES} == 256 )) || exit 11
    [[ ${_ZLE_PICKER_INSPECT_LINES[-1]} == *truncated* ]] || exit 12
    _ZLE_PICKER_RESULTS=(safe-tool)
    _ZLE_PICKER_RESULT_INDEXES=(1)
    _ZLE_PICKER_LABELS=("界界界界界界界界界界界界界界界界界界界界")
    _ZLE_PICKER_INSPECT_TEXTS[safe-tool]=$'\''usage: safe-tool\nLiteral %F{red} $(never-run)\n\e]52;c;invalid\a\n界界界界界界界界界界界界界界界界界界界界界界界界界界界界'\''
    setopt PROMPT_SUBST
    _zle_picker_inspect_prepare safe-tool 70
    [[ ${_ZLE_PICKER_INSPECT_LINES[2]} == '"'"'Literal %F{red} $(never-run)'"'"' ]] || exit 13
    for columns in 120 100 99 45 20; do
      COLUMNS=$columns LINES=16
      for _ZLE_PICKER_INSPECT_FOCUS in 0 1; do
        _zle_picker_render "${(l:200::界:)}" 1
        (( ${(m)#_ZLE_PICKER_QUERY_ROW} < COLUMNS )) || exit 9
        for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
          (( ${(m)#row} < COLUMNS )) || { print -u2 -- "row overflow at $columns: ${(m)#row}"; exit 5; }
          [[ $row != *$'\''\e'\''* && $row != *$'\''\a'\''* ]] || exit 6
        done
        (( ${#_ZLE_PICKER_INSPECT_LINES} <= 256 )) || exit 7
      done
    done
    COLUMNS=120 LINES=10
    _ZLE_PICKER_RESULTS=({1..20})
    _ZLE_PICKER_LABELS=({1..20})
    _ZLE_PICKER_RESULT_INDEXES=({1..20})
    _zle_picker_render "" 20
    (( ${#_ZLE_PICKER_DISPLAY} <= LINES - 5 )) || exit 8
    _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
    _zle_picker_render missing 0
    [[ ${(j: :)_ZLE_PICKER_DISPLAY} == *"No matching selection."* ]] || exit 10
    print bounded-literal
  ' "$TEST_REPO_ROOT" "$addon") || return
  test_assert_equal bounded-literal "$output"
}
test_case 'inspector bounds captures and fits literal Unicode text after resize' \
  _test_inspector_bounds_and_literals

_test_inspector_native_controls() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    source "$1/.zsh.addons/.zsh.help"
    source "$1/.zsh.addons/.zsh.tools"
    source "$1/tests/pty_support.zsh" || exit 20
    command mkfifo "$HOME/events" || exit 17
    exec {event_fd}<> "$HOME/events" || exit 18
    functions[_inspector_original_show]=$functions[_zle_picker_show]
    _zle_picker_show() {
      _inspector_original_show
      print -r -u $event_fd -- "FRAME:$_ZLE_PICKER_INSPECT_FOCUS:$_ZLE_PICKER_INSPECT_OFFSET:$_ZLE_PICKER_QUERY:SOURCE:${_ZLE_PICKER_INSPECT_SOURCE_LINES[_ZLE_PICKER_INSPECT_OFFSET+1]:-0}:END-FRAME"
    }
    _inspector_driver() {
      command stty rows 30 cols 120
      COLUMNS=120 LINES=30
      compozsh
      print -r -u $event_fd -- "DONE:${#_ZLE_PICKER_INSPECT_TEXTS}:$_ZLE_PICKER_INSPECT_FOCUS:END-DONE"
    }
    local frame="" trace=""
    _inspector_event() {
      {
        test_pty_expect -p inspector $event_fd "" || return
        frame=$REPLY
      } always { trace+=$TEST_PTY_OUTPUT }
    }
    test_pty_start inspector _inspector_driver || exit 1
    {
      _inspector_event || exit 2
      [[ $frame == FRAME:* ]] || exit 3
      zpty -w -n inspector $'\''\e[C'\''
      _inspector_event || exit 4
      [[ $frame == *"FRAME:1:0:"* ]] || exit 5
      zpty -w -n inspector $'\''\e[B'\''
      _inspector_event || exit 6
      [[ $frame == *"FRAME:1:1:"* ]] || exit 7
      reading_source=${frame##*:SOURCE:}
      reading_source=${reading_source%%:END-FRAME*}
      [[ $reading_source == <-> && $reading_source -gt 0 ]] || exit 16
      zpty -w -n inspector $'\''\e[D'\''
      _inspector_event || exit 8
      [[ $frame == *"FRAME:0:"* && $frame == *":SOURCE:$reading_source:END-FRAME"* ]] || exit 9
      zpty -w -n inspector $'\''\t'\''
      _inspector_event || exit 12
      [[ $frame == *"FRAME:1:"* && $frame == *":SOURCE:$reading_source:END-FRAME"* ]] || exit 13
      zpty -w -n inspector $'\''\e[200~cpdir\e[201~'\''
      _inspector_event || exit 14
      [[ $frame == *"FRAME:0:0:cpdir:"* ]] || exit 15
      zpty -w -n inspector $'\''\x07'\''
      _inspector_event || exit 10
      [[ $frame == *"DONE:0:0:"* ]] || exit 11
      [[ $trace != *"read-only variable"* && $trace != *"bad math expression"* ]] || exit 19
    } always {
      zpty -d inspector
      exec {event_fd}>&-
    }
    print native-controls
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal native-controls "$output"
}
test_case 'inspector native ZLE supports focus, scrolling, and cancellation cleanup' \
  _test_inspector_native_controls

# Document rows never word-wrap: width-1 cells while more than a row remains,
# then a final row of up to width cells. The oracle pins rows, roles, the
# source map and syntax slices so a faster wrapper cannot shift geometry.
_test_document_wrapping_geometry() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local -i _ZLE_PICKER_READER_ONLY=0 _ZLE_PICKER_DOCUMENT=1
    local _ZLE_PICKER_DOCUMENT_KEY=diff
    local -a _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
    local -A _ZLE_PICKER_DOCUMENT_SYNTAX=()
    local -a lengths=() rows=() roles=() sources=() slices=() spans=()
    local -a role_names=(text add remove heading info)
    local raw="" expanded=""
    local -i width=0 length=0 index=0 offset=0 remaining=0
    for width in 2 3 40 100; do
      lengths=($width $(( width + 1 )) $(( 2 * (width - 1) ))
        $(( 2 * (width - 1) + 1 )) $(( 3 * (width - 1) + 1 )))
      _ZLE_PICKER_DOCUMENT_LINES=() _ZLE_PICKER_DOCUMENT_ROLES=()
      _ZLE_PICKER_DOCUMENT_SYNTAX=() rows=() roles=() sources=() slices=()
      index=0
      for length in $lengths; do
        (( ++index ))
        # A tab becomes four cells, so raw syntax offsets after it shift by 3.
        if (( length >= 6 )); then
          raw="a"$'\''\t'\''${(l:length-5::ab cd%F{x}=-:)}
          _ZLE_PICKER_DOCUMENT_SYNTAX[$index]="0:1:keyword 1:3:string $(( ${#raw} - 2 )):${#raw}:comment"
          spans=(0:1:keyword 1:6:string $(( ${#raw} + 1 )):$(( ${#raw} + 3 )):comment)
        else
          raw=${(l:length::ab cd%F{x}=-:)}
          _ZLE_PICKER_DOCUMENT_SYNTAX[$index]="0:1:keyword"
          spans=(0:1:keyword)
        fi
        _ZLE_PICKER_DOCUMENT_LINES+=("$raw")
        _ZLE_PICKER_DOCUMENT_ROLES+=($role_names[index])
        expanded=${raw//$'\''\t'\''/    }
        (( ${#expanded} == length )) || { print -u2 "fixture length $length"; exit 1; }
        offset=0 remaining=$length
        while (( remaining > width )); do
          rows+=("${expanded[offset+1,offset+width-1]}")
          roles+=($role_names[index]) sources+=($index)
          _zle_picker_syntax_slice $offset $(( offset + width - 1 )) "${spans[@]}"
          slices+=("$REPLY")
          (( offset += width - 1, remaining -= width - 1 ))
        done
        rows+=("${expanded[offset+1,-1]}")
        roles+=($role_names[index]) sources+=($index)
        _zle_picker_syntax_slice $offset $length "${spans[@]}"
        slices+=("$REPLY")
      done
      _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
      _zle_picker_inspect_prepare diff $width
      (( ${#_ZLE_PICKER_INSPECT_LINES} == ${#rows} &&
         ${#_ZLE_PICKER_INSPECT_SYNTAX} == ${#slices} )) &&
      [[ ${(pj:\n:)_ZLE_PICKER_INSPECT_LINES} == "${(pj:\n:)rows}" &&
         ${(j:,:)_ZLE_PICKER_INSPECT_ROLES} == "${(j:,:)roles}" &&
         ${(j:,:)_ZLE_PICKER_INSPECT_SOURCE_LINES} == "${(j:,:)sources}" &&
         ${(pj:\n:)_ZLE_PICKER_INSPECT_SYNTAX} == "${(pj:\n:)slices}" ]] || {
        print -u2 -- "document geometry changed at width $width"
        print -u2 -- "rows: ${(qqj:|:)_ZLE_PICKER_INSPECT_LINES}"
        print -u2 -- "want: ${(qqj:|:)rows}"
        print -u2 -- "syntax: ${(qqj:|:)_ZLE_PICKER_INSPECT_SYNTAX}"
        print -u2 -- "want: ${(qqj:|:)slices}"
        exit 2
      }
    done
    # 399 lines of 50 rows each, then a long line reaches the 20,000-row bound
    # mid-line; its last kept row becomes the notice and later lines vanish.
    _ZLE_PICKER_DOCUMENT_LINES=()
    for (( index = 1; index <= 399; ++index )); do
      _ZLE_PICKER_DOCUMENT_LINES+=("${(l:101::ab:)}")
    done
    _ZLE_PICKER_DOCUMENT_LINES+=("${(l:1000::x:)}" after)
    _ZLE_PICKER_DOCUMENT_ROLES=() _ZLE_PICKER_DOCUMENT_SYNTAX=()
    _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_inspect_prepare diff 3
    (( ${#_ZLE_PICKER_INSPECT_LINES} == 20000 &&
       ${#_ZLE_PICKER_INSPECT_SOURCE_LINES} == 20000 &&
       _ZLE_PICKER_INSPECT_SOURCE_LINES[19950] == 399 &&
       _ZLE_PICKER_INSPECT_SOURCE_LINES[19951] == 400 &&
       _ZLE_PICKER_INSPECT_SOURCE_LINES[20000] == 400 )) &&
    [[ ${_ZLE_PICKER_INSPECT_LINES[19950]} == "${${(l:101::ab:)}[99,101]}" &&
       ${_ZLE_PICKER_INSPECT_LINES[19951]} == xx &&
       ${_ZLE_PICKER_INSPECT_LINES[19999]} == xx &&
       ${_ZLE_PICKER_INSPECT_LINES[20000]} == "Limits: 20,000 wrapped lines; use Git for the remaining text." &&
       ${_ZLE_PICKER_INSPECT_ROLES[20000]} == warning &&
       -z ${_ZLE_PICKER_INSPECT_SYNTAX[20000]} ]] || {
      print -u2 -- "document row bound changed: ${#_ZLE_PICKER_INSPECT_LINES} rows"
      exit 3
    }
    print document-geometry
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal document-geometry "$output"
}
test_case 'document wrapping keeps width-1 rows with a final row of up to width cells' \
  _test_document_wrapping_geometry

# Printable ASCII occupies one cell per byte in every document, not only in
# readers, so a long Git diff line is sliced instead of re-measured per row.
_test_document_wrapping_ascii_path() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zsh.addons/.zsh.editor"
    for support_component in "$1/.zsh.addons/support/ui"/.zsh.ui.*(N.) "$1/.zsh.addons/support/functions"/.zsh.{pure,impure}.zle_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.pure.compozsh_cell_prefix"
    for support_component in "$1/.zsh.addons/support/functions"/.zsh.pure.matching_*(N.); do source "$support_component"; done
    source "$1/.zsh.addons/support/functions/.zsh.impure.zle_ui_collect"
    source "$1/.zsh.addons/support/.zsh.appearance"
    local -i _ZLE_PICKER_READER_ONLY=0 _ZLE_PICKER_DOCUMENT=1 cell_prefix_calls=0
    local _ZLE_PICKER_DOCUMENT_KEY=diff row=""
    local -a _ZLE_PICKER_DOCUMENT_LINES=("${(l:4000::x:)}" "Unicode tail 界 é")
    functions[_inspector_original_cell_prefix]=$functions[_compozsh_cell_prefix]
    _compozsh_cell_prefix() {
      (( ++cell_prefix_calls ))
      _inspector_original_cell_prefix "$@"
    }
    _zle_picker_inspect_prepare diff 100
    (( cell_prefix_calls == 0 && ${#_ZLE_PICKER_INSPECT_LINES} == 42 )) || {
      print -u2 -- "ASCII document wrapping made $cell_prefix_calls cell-prefix calls for ${#_ZLE_PICKER_INSPECT_LINES} rows"
      exit 1
    }
    [[ ${(j::)_ZLE_PICKER_INSPECT_LINES[1,41]} == "${(l:4000::x:)}" &&
       ${_ZLE_PICKER_INSPECT_LINES[42]} == "Unicode tail 界 é" ]] || exit 2
    # Wide characters still measure display cells, never bytes or characters.
    _ZLE_PICKER_DOCUMENT_LINES=("${(l:250::界:)}")
    _ZLE_PICKER_INSPECT_KEY="" _ZLE_PICKER_INSPECT_WIDTH=0
    _zle_picker_inspect_prepare diff 100
    (( cell_prefix_calls > 0 && ${#_ZLE_PICKER_INSPECT_LINES} == 6 )) || exit 3
    for row in "${_ZLE_PICKER_INSPECT_LINES[@]}"; do
      (( ${(m)#row} <= 100 )) || exit 4
    done
    print ascii-document-path
  ' "$TEST_REPO_ROOT") || return
  test_assert_equal ascii-document-path "$output"
}
test_case 'document wrapping takes the byte path for printable ASCII outside the reader' \
  _test_document_wrapping_ascii_path
