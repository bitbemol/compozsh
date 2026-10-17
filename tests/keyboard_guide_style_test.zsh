_test_keyboard_guide_semantic_styles() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_GUIDE_ACTIVE=1
    _ZLE_PICKER_RESULTS=(main) _ZLE_PICKER_LABELS=(main)
    _ZLE_PICKER_SELECTED=1 _ZLE_PICKER_INSPECT_ACTION=read
    _ZLE_PICKER_EXCLUSION_ENABLED=1
    _ZLE_PICKER_GUIDE_CONTEXT=("Captured path with  literal spaces and 界界")
    local width index label span
    local -a fields=()
    LINES=100
    for width in 8 39 119; do
      COLUMNS=$(( width + 1 ))
      _ZLE_PICKER_GUIDE_OFFSET=0
      _zle_picker_guide_render $width
      index=${_ZLE_PICKER_DISPLAY[(I)Type *]}
      (( index )) || exit 1
      [[ $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index] == "0:4:picker-header" &&
         $_ZLE_PICKER_DISPLAY_STYLES[index] == picker-text ]] || {
        print -u2 -r -- "Keyboard labels need semantic emphasis separate from descriptions"
        exit 2
      }
      for (( index=1; index<=${#_ZLE_PICKER_DISPLAY}; ++index )); do
        (( ${(m)#_ZLE_PICKER_DISPLAY[index]} <= width )) || exit 3
        for span in ${=_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index]}; do
          fields=("${(@s.:.)span}")
          (( fields[1] >= 0 && fields[2] <= ${#_ZLE_PICKER_DISPLAY[index]} )) || exit 4
        done
      done
    done
    index=${_ZLE_PICKER_DISPLAY[(I)Control shortcuts*]}
    [[ $_ZLE_PICKER_DISPLAY_STYLES[index] == picker-muted &&
       -z $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index] ]] || exit 5
    index=${_ZLE_PICKER_DISPLAY[(I)Captured path*]}
    [[ $_ZLE_PICKER_DISPLAY_STYLES[index] == picker-text &&
       -z $_ZLE_PICKER_DISPLAY_HIGHLIGHTS[index] ]] || exit 6
    LINES=12 _ZLE_PICKER_GUIDE_OFFSET=5
    _zle_picker_guide_render 39
    [[ ${(j: :)_ZLE_PICKER_DISPLAY_HIGHLIGHTS} == *picker-header* &&
       $_ZLE_PICKER_GUIDE_OFFSET == 5 && $_ZLE_PICKER_SELECTED == 1 &&
       $_ZLE_PICKER_INDEXES_VISIBLE == 0 ]] || exit 7
    # Public palette overrides still control the actual span paint.
    ZSH_HIGHLIGHT_STYLES[picker-header]="fg=123,bold"
    local painted=""
    zle() { painted=${(j:|:)region_highlight}; }
    BUFFER="" PREDISPLAY="" POSTDISPLAY="" region_highlight=()
    _zle_picker_show
    [[ $painted == *"fg=123,bold"* ]] || exit 8
    ZSH_HIGHLIGHT_STYLES[picker-header]=bold
    _zle_picker_show
    [[ $painted != *"fg=123"* ]] || exit 9
  ' "$TEST_REPO_ROOT"
}
test_case 'keyboard guide distinguishes labels descriptions and notes with bounded semantic spans' _test_keyboard_guide_semantic_styles

_test_keyboard_guide_sanitizes_context() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    local esc="" bel="" nl="" row=""
    local -i visible=0
    printf -v esc "\033"; printf -v bel "\a"; printf -v nl "\n"
    _ZLE_PICKER_SCREEN_ACTIVE=1 _ZLE_PICKER_GUIDE_ACTIVE=1
    _ZLE_PICKER_RESULTS=(main) _ZLE_PICKER_LABELS=(main)
    _ZLE_PICKER_SELECTED=1
    # Callers pass raw captured facts, such as a repository folder name that
    # may hold terminal controls or a newline; the renderer sanitizes them.
    _ZLE_PICKER_GUIDE_CONTEXT=(
      "Method · repo${esc}[2Jname${bel} · committed content"
      "Line with${nl}newline")
    LINES=40 COLUMNS=60 _ZLE_PICKER_GUIDE_OFFSET=1000
    _zle_picker_guide_render 59
    for row in "${_ZLE_PICKER_DISPLAY[@]}"; do
      [[ $row != *[[:cntrl:]]* ]] || {
        print -u2 -r -- "Guide row keeps a control character: ${(qqqq)row}"
        exit 1
      }
      (( ${(m)#${(V)row}} <= 59 )) || {
        print -u2 -r -- "Guide row exceeds the frame width: ${(qqqq)row}"
        exit 2
      }
      [[ $row == *"repo^[[2Jname^G · committed"* ||
         $row == *"Line with\\nnewline"* ]] && (( ++visible ))
    done
    (( visible == 2 )) || {
      print -u2 -r -- "Caller context must stay visible as literal text"
      exit 3
    }
  ' "$TEST_REPO_ROOT"
}
test_case 'keyboard guide sanitizes caller-owned context lines' _test_keyboard_guide_sanitizes_context

# Characterize every Ctrl-X caller: the footer destination and the guide's
# Ctrl-X key lines come from capabilities plus the caller's options label.
_test_keyboard_guide_options_callers() {
  test_make_temp_dir || return
  local output
  output=$(test_run_interactive "$TEST_TMP_DIR/home" '
    export LC_ALL=en_US.UTF-8
    source "$1/.zshrc"
    setopt EXTENDED_GLOB
    local spec name row
    local -a fields=() keys=()
    _options_reset() {
      _ZLE_PICKER_DOCUMENT=0 _ZLE_PICKER_READER_ONLY=0 _ZLE_PICKER_DOCUMENT_REFRESH=0
      _ZLE_PICKER_AUTO_REFRESH=-1 _ZLE_PICKER_DOCUMENT_FOLLOW=-1 _ZLE_PICKER_DOCUMENT_MODE=""
      _ZLE_PICKER_WORKSPACE_ACTIONS=0 _ZLE_PICKER_DIRECTORY_ACTIONS=0
      _ZLE_PICKER_HIERARCHY_ENABLED=0 _ZLE_PICKER_SEARCH_ACTION="" _ZLE_PICKER_COPY_ENABLED=0
      _ZLE_PICKER_OPTIONS_KIND="" _ZLE_PICKER_OPTIONS_LABEL="" _ZLE_PICKER_CANCEL_BOOKMARK=0
      _ZLE_PICKER_INSPECT_ACTION=choose _ZLE_PICKER_CANCEL_LABEL=back
      _ZLE_PICKER_INSPECT_FOCUS=0 _ZLE_PICKER_EXCLUSION_ENABLED=1 _ZLE_PICKER_DIGIT_SELECT=0
      _ZLE_PICKER_RESULTS=(main) _ZLE_PICKER_LABELS=(main) _ZLE_PICKER_SELECTED=1
      _ZLE_PICKER_INSPECT_TEXTS=(main details) _ZLE_PICKER_DOCUMENT_BRANCHES=()
      _ZLE_PICKER_ACCEPT_LABELS=() _ZLE_PICKER_GUIDE_CONTEXT=()
    }
    for spec in \
      "branches|_ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=git _ZLE_PICKER_OPTIONS_LABEL=review _ZLE_PICKER_INSPECT_ACTION=switch _ZLE_PICKER_COPY_ENABLED=1" \
      "branches without review|_ZLE_PICKER_OPTIONS_KIND=git _ZLE_PICKER_OPTIONS_LABEL=review _ZLE_PICKER_INSPECT_ACTION=switch" \
      "git file views|_ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_REFRESH=1 _ZLE_PICKER_AUTO_REFRESH=1 _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=file-views _ZLE_PICKER_OPTIONS_LABEL=views _ZLE_PICKER_CANCEL_BOOKMARK=1 _ZLE_PICKER_INSPECT_ACTION=read _ZLE_PICKER_DOCUMENT_MODE=focused" \
      "git file views empty|_ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_REFRESH=1 _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=file-views _ZLE_PICKER_OPTIONS_LABEL=views _ZLE_PICKER_CANCEL_BOOKMARK=1 _ZLE_PICKER_INSPECT_ACTION=read _ZLE_PICKER_RESULTS=() _ZLE_PICKER_SELECTED=0" \
      "document without options|_ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_DOCUMENT_REFRESH=1 _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_INSPECT_ACTION=read _ZLE_PICKER_DOCUMENT_MODE=focused" \
      "reader|_ZLE_PICKER_DOCUMENT=1 _ZLE_PICKER_READER_ONLY=1 _ZLE_PICKER_INSPECT_ACTION=read" \
      "worktree options|_ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_OPTIONS_KIND=worktree _ZLE_PICKER_INSPECT_ACTION=inspect" \
      "worktree actions|_ZLE_PICKER_OPTIONS_KIND=worktree _ZLE_PICKER_INSPECT_ACTION=create" \
      "folder browser|_ZLE_PICKER_DIRECTORY_ACTIONS=1 _ZLE_PICKER_HIERARCHY_ENABLED=1 _ZLE_PICKER_SEARCH_ACTION=search-local" \
      "files browse|_ZLE_PICKER_DIRECTORY_ACTIONS=1 _ZLE_PICKER_HIERARCHY_ENABLED=1 _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_SEARCH_ACTION=search-local" \
      "files results|_ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_INSPECT_ACTION=insert" \
      "recents|_ZLE_PICKER_DIRECTORY_ACTIONS=2 _ZLE_PICKER_WORKSPACE_ACTIONS=1 _ZLE_PICKER_INSPECT_ACTION=insert" \
      "plain choice|"; do
      fields=("${(@s:|:)spec}")
      name=$fields[1]
      _options_reset
      for row in ${=fields[2]}; do
        [[ $row == *"=()" ]] || typeset -g -- "${row%%=*}=${row#*=}"
      done
      [[ $fields[2] == *"_ZLE_PICKER_RESULTS=()"* ]] && _ZLE_PICKER_RESULTS=() _ZLE_PICKER_LABELS=()
      _ZLE_PICKER_GUIDE_ACTIVE=0 _ZLE_PICKER_SCREEN_ACTIVE=0
      _zle_picker_footer 299 ""
      print -r -- "$name|wide|$REPLY"
      _ZLE_PICKER_SCREEN_ACTIVE=1
      _zle_picker_footer 119 ""
      print -r -- "$name|screen|$REPLY"
      _ZLE_PICKER_GUIDE_ACTIVE=1 _ZLE_PICKER_GUIDE_OFFSET=0 LINES=200 COLUMNS=200
      _zle_picker_guide_render 199
      keys=("${(@M)_ZLE_PICKER_DISPLAY:#Ctrl-X*}")
      row=${(M)_ZLE_PICKER_DISPLAY:#Keyboard guide ·*}
      print -r -- "$name|guide|${row%%[[:space:]]#}|${(j:;:)${(@)keys%%[[:space:]]#}}"
    done
  ' "$TEST_REPO_ROOT") || return
  local -a expected=(
    'branches|wide|⏎ switch · Esc back · ^] filter/exclude · ^X review · ^Y copy · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'branches|screen|⏎ switch · Esc back · ^] filter/exclude · ^X review · ^Y copy · ↑/↓ move · ^K all keys'
    'branches|guide|Keyboard guide · 1/29|Ctrl-X               Review: working changes, branch commits or comparisons'
    'branches without review|wide|⏎ switch · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'branches without review|screen|⏎ switch · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · ^K all keys'
    'branches without review|guide|Keyboard guide · 1/24|'
    'git file views|wide|⏎ read · Esc back · ^] filter/exclude · ^R refresh · ^A pause auto · ^X views · → read · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'git file views|screen|⏎ read · Esc back · ^] filter/exclude · ^R refresh · ^A pause auto · ^X views · ^K all keys'
    'git file views|guide|Keyboard guide · 1/42|Ctrl-X               View options: All files / Tree / Jump to ancestor / Change atlas'
    'git file views empty|wide|Esc back · ^] filter/exclude · ^R refresh · ^X views · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'git file views empty|screen|Esc back · ^] filter/exclude · ^R refresh · ^X views · ↑/↓ move · ^K all keys'
    'git file views empty|guide|Keyboard guide · 1/39|Ctrl-X               View options: All files / Tree / Jump to ancestor / Change atlas'
    'document without options|wide|⏎ read · Esc back · ^] filter/exclude · ^R refresh · → read · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'document without options|screen|⏎ read · Esc back · ^] filter/exclude · ^R refresh · → read · ↑/↓ move · ^K all keys'
    'document without options|guide|Keyboard guide · 1/33|'
    'reader|wide|⏎ read · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'reader|screen|⏎ read · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · ^K all keys'
    'reader|guide|Keyboard guide · 1/23|'
    'worktree options|wide|⏎ inspect · Esc back · ^] filter/exclude · ^X options · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'worktree options|screen|⏎ inspect · Esc back · ^] filter/exclude · ^X options · ↑/↓ move · Tab details · ^K all keys'
    'worktree options|guide|Keyboard guide · 1/31|Ctrl-X               Options for the selected worktree'
    'worktree actions|wide|⏎ create · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'worktree actions|screen|⏎ create · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · ^K all keys'
    'worktree actions|guide|Keyboard guide · 1/30|'
    'folder browser|wide|⏎ choose · Esc back · ^] filter/exclude · ^X options · ^F search · ^O preview · ↑/↓ move · → open / ← back · ^T hidden · ^E details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'folder browser|screen|⏎ choose · Esc back · ^] filter/exclude · ^X options · ^F search · ^O preview · ^K all keys'
    'folder browser|guide|Keyboard guide · 1/29|Ctrl-X               Options: folder actions, including current folder'
    'files browse|wide|⏎ choose · Esc back · ^] filter/exclude · ^X options · ^F search · ^O preview · ↑/↓ move · → open / ← back · ^T hidden · ^E details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'files browse|screen|⏎ choose · Esc back · ^] filter/exclude · ^X options · ^F search · ^O preview · ^K all keys'
    'files browse|guide|Keyboard guide · 1/41|Ctrl-X               Options: folder actions, including current folder;Ctrl-X               Options: actions, sources, Browse and Recents'
    'files results|wide|⏎ insert · Esc back · ^] filter/exclude · ^X options · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'files results|screen|⏎ insert · Esc back · ^] filter/exclude · ^X options · ↑/↓ move · Tab details · ^K all keys'
    'files results|guide|Keyboard guide · 1/36|Ctrl-X               Options: actions, sources, Browse and Recents'
    'recents|wide|⏎ insert · Esc back · ^] filter/exclude · ^X options · ^O browse · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'recents|screen|⏎ insert · Esc back · ^] filter/exclude · ^X options · ^O browse · ↑/↓ move · ^K all keys'
    'recents|guide|Keyboard guide · 1/37|Ctrl-X               Options: actions, sources, Browse and Recents'
    'plain choice|wide|⏎ choose · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · type filter · ^U clear · ^K all keys'
    'plain choice|screen|⏎ choose · Esc back · ^] filter/exclude · ↑/↓ move · Tab details · Fn/Option ↑/↓ page · ^K all keys'
    'plain choice|guide|Keyboard guide · 1/24|'
  )
  test_assert_equal "${(F)expected}" "$output"
}
test_case 'keyboard guide and footer keep Ctrl-X destinations for every options caller' _test_keyboard_guide_options_callers
