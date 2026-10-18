_test_manual_cache_public_fixture() {
  # Only tests classify disposable pages as the public OS provider. Production
  # accepts Apple's /usr/share/man tree, never an arbitrary MANPATH directory.
  test_write_file "$TEST_TMP_DIR/public-provider.zsh" '
    _manual_cache_page_id() {
      REPLY=""
      [[ $2 == "$MANPATH" && $1 == "$MANPATH/"* ]] || return 1
      REPLY=${1#"$MANPATH/"}
    }
    _manual_cache_public_file() { [[ $1 == "${MANPATH:A}/"* ]]; }
  '
}

_test_manual_cache_across_shells() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Inspect local fixture data\n.SH SYNOPSIS\n'
  local phase='' output=''
  for phase in build reuse; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1/.zsh.addons/.zsh.manual"
      source "${HOME:h}/public-provider.zsh"
      local MANPATH=$2
      [[ ! -e "$HOME/.zsh.addons/support/cache" || $3 == reuse ]] || exit 1
      if [[ $3 == reuse ]]; then
        _manual_developer_roots() { print -u2 forbidden-selection; return 99; }
        _manual_configuration_roots() { print -u2 forbidden-config; return 99; }
        _manual_page_read() { print -u2 forbidden-page-read; return 99; }
      fi
      _manual_prompt_capture || exit 2
      [[ ${_MANUAL_SUMMARIES[demo]-} == "Inspect local fixture data" &&
         ${_MANUAL_SOURCES[demo]-} == "demo(1)" ]] || {
        print -u2 "manual cache did not preserve the snapshot across shells"; exit 3
      }
      [[ -f "$HOME/.zsh.addons/support/cache/.zsh.manual.cache" ]] || {
        print -u2 "manual snapshot was not persisted"; exit 4
      }
      source "$1/.zsh.addons/.zsh.manual"
      _manual_prompt_capture || exit 5
      print -r -- "${_MANUAL_SUMMARIES[demo]}|${_MANUAL_SOURCES[demo]}"
    ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual" "$phase" 2> "$TEST_TMP_DIR/errors") || {
      print -u2 -r -- "$(<"$TEST_TMP_DIR/errors")"; return 1
    }
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || test_fail 'cache hit called a provider' || return
    test_assert_equal 'Inspect local fixture data|demo(1)' "$output" || return
  done
}
test_case 'manual cache reuses complete descriptions across fresh shells without manual providers' \
  _test_manual_cache_across_shells

_test_manual_cache_live_catalog() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Public fixture\n.SH SYNOPSIS\n'
  local phase=''
  for phase in build warm added removed; do
    test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1/.zsh.addons/.zsh.manual"
      source "${HOME:h}/public-provider.zsh"
      local MANPATH=$2 phase=$3
      case $phase in
        warm)
          _manual_cache_lock() { print -u2 "warm capture waited for a builder lock"; return 99; }
          _manual_page_read() { print -u2 "warm capture read a public page"; return 99; }
          ;;
        added)
          print -r -- $'\''.SH NAME\nnewtool \\- Newly installed public fixture\n.SH SYNOPSIS\n'\'' > "$MANPATH/man1/newtool.1"
          ;;
        removed) command rm -- "$MANPATH/man1/demo.1" ;;
      esac
      _manual_prompt_capture || exit 1
      if [[ $phase == removed ]]; then
        (( ! ${+_MANUAL_SUMMARIES[demo]} )) || exit 2
        [[ ${_MANUAL_SUMMARIES[newtool]} == "Newly installed public fixture" ]] || exit 3
      else
        [[ ${_MANUAL_SUMMARIES[demo]} == "Public fixture" ]] || exit 4
      fi
      if [[ $phase == added ]]; then
        _manual_cache_key || exit 5
        _manual_cache_load "$HOME/.zsh.addons/support/cache/.zsh.manual.cache" "$REPLY" || exit 6
        [[ ${_MANUAL_CACHE_SUMMARIES[man1/newtool.1]} == "Newly installed public fixture" ]] || exit 7
      fi
      _manual_summary_lookup unknown-fixture && exit 8
      return 0
    ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual" "$phase" 2> "$TEST_TMP_DIR/errors" || return
    [[ ! -s "$TEST_TMP_DIR/errors" ]] || {
      print -u2 -r -- "$(<"$TEST_TMP_DIR/errors")"; return 1
    }
  done
}
test_case 'manual cache keeps additions removals and unknowns live without locking unchanged warm readers' \
  _test_manual_cache_live_catalog

_test_manual_cache_rejects_invalid_publication() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    _manual_cache_key || exit 1
    local key=$REPLY directory="" original=""
    _manual_cache_directory create || exit 2
    directory=$REPLY
    _MANUAL_CACHE_SUMMARIES=(man1/demo.1 "Public description")
    _MANUAL_CACHE_ALIASES=(man1/demo.1 "")
    _manual_cache_store "$directory" "$key" || exit 3
    original=$(<"$directory/.zsh.manual.cache")
    _MANUAL_CACHE_ALIASES[man1/demo.1]=${(l:256::a:)}
    _manual_cache_store "$directory" "$key" && {
      print -u2 "published an alias the reader must reject"; exit 4
    }
    [[ $(<"$directory/.zsh.manual.cache") == "$original" ]] || exit 5
  ' "$TEST_REPO_ROOT"
}
test_case 'manual cache refuses invalid publication while preserving the previous complete snapshot' \
  _test_manual_cache_rejects_invalid_publication

_test_manual_cache_refresh_and_selectors() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Original description\n.SH SYNOPSIS\n'
  test_write_file "$TEST_TMP_DIR/other/man1/demo.1" $'.SH NAME\ndemo \\- Other installation\n.SH SYNOPSIS\n'
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    source "${HOME:h}/public-provider.zsh"
    source "$1/.zsh.addons/.zsh.tools"
    local MANPATH=$2
    _manual_prompt_capture || exit 1
    [[ ${_MANUAL_SUMMARIES[demo]} == "Original description" ]] || exit 2
    print -r -- $'\''.SH NAME\ndemo \\- Updated description\n.SH SYNOPSIS\n'\'' >| "$2/man1/demo.1"
    _tools_refresh || exit 3
    (( ! _MANUAL_SUMMARIES_READY )) || exit 4
    _manual_prompt_capture || exit 5
    [[ ${_MANUAL_SUMMARIES[demo]} == "Updated description" ]] || exit 6
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual" || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    local MANPATH=$2
    _manual_prompt_capture || exit 1
    [[ ${_MANUAL_SUMMARIES[demo]} == "Other installation" ]] || exit 2
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/other"
}
test_case 'manual cache refresh replaces persisted descriptions and changed MANPATH cannot reuse them' \
  _test_manual_cache_refresh_and_selectors

_test_manual_cache_literal_roundtrip() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  local phase='' output='' original=''
  for phase in build reuse; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home" '
      export LC_ALL=en_US.UTF-8
      source "$1/.zsh.addons/.zsh.manual"
      source "${HOME:h}/public-provider.zsh"
      local MANPATH=$HOME/manual phase=$2
      command mkdir -p "$MANPATH/man1"
      local expected=$'\''Read café 界 %F{red} $(touch "$HOME/executed") `touch executed` literally'\''
      if [[ $phase == build ]]; then
        # Exercise serialization independently of roff formatting/transliteration.
        print -r -- fixture > "$MANPATH/man1/demo.1"
        print -r -- fixture > "$MANPATH/man1/origin.1"
        _MANUAL_CACHE_SUMMARIES=(man1/demo.1 "$expected" man1/origin.1 "share a manual")
        _MANUAL_CACHE_ALIASES=(man1/demo.1 "" man1/origin.1 alias-one:alias-two)
        _manual_cache_key || exit 3
        local key=$REPLY
        _manual_cache_directory create || exit 4
        _manual_cache_store "$REPLY" "$key" || exit 5
      fi
      _manual_page_read() { print -u2 forbidden-read; return 99; }
      _manual_prompt_capture || exit 1
      [[ ${_MANUAL_SUMMARIES[demo]} == "$expected" &&
         ${_MANUAL_SOURCES[alias-two]} == "origin(1)" &&
         ! -e "$HOME/executed" ]] || exit 2
      for name in "${(@ok)_MANUAL_SUMMARIES}"; do
        print -r -- "$name|${_MANUAL_SUMMARIES[$name]}|${_MANUAL_SOURCES[$name]}"
      done
    ' "$TEST_REPO_ROOT" "$phase") || return
    if [[ $phase == build ]]; then original=$output; else test_assert_equal "$original" "$output" || return; fi
  done
}
test_case 'manual cache preserves Unicode aliases and shell-looking descriptions as inert data' \
  _test_manual_cache_literal_roundtrip

_test_manual_cache_rejects_invalid_data() {
  test_make_temp_dir || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    local MANPATH=$HOME/none key="" file=$HOME/snapshot original="" bad="" variant=""
    _manual_cache_key || exit 1
    key=$REPLY
    original=$'\''COMPOZSH-MANUAL-1\n'\''"$key"$'\''\n1\nman1/demo.1\t\tRead data\nEND\n'\''
    local -a variants=(truncated duplicate count version key control empty-field extra-field source nul)
    for variant in "${variants[@]}"; do
      bad=$original
      case $variant in
        truncated) bad=${bad%$'\''END\n'\''} ;;
        duplicate) bad=$'\''COMPOZSH-MANUAL-1\n'\''"$key"$'\''\n2\nman1/demo.1\t\tRead data\nman1/demo.1\t\tOther data\nEND\n'\'' ;;
        count) bad=${bad/$'\''\n1\n'\''/$'\''\n1+1\n'\''} ;;
        version) bad=${bad/COMPOZSH-MANUAL-1/COMPOZSH-MANUAL-2} ;;
        key) bad=${bad/"$key"/wrong-key} ;;
        control) bad=${bad/Read data/$'\''unsafe\e[31m'\''} ;;
        empty-field) bad=${bad/Read data/} ;;
        extra-field) bad=${bad/Read data/$'\''Read\textra'\''} ;;
        source) bad=${bad/man1\//man1\/..\/..\/} ;;
        nul) bad=${bad/Read data/$'\''Read\0data'\''} ;;
      esac
      print -rn -- "$bad" >| "$file"
      command chmod 600 "$file"
      _MANUAL_CACHE_SUMMARIES=(sentinel retained) _MANUAL_CACHE_ALIASES=(sentinel alias)
      _MANUAL_SUMMARIES_READY=0
      if _manual_cache_load "$file" "$key"; then
        print -u2 -- "accepted invalid cache: $variant"; exit 2
      fi
      [[ ${#_MANUAL_CACHE_SUMMARIES} == 1 && ${_MANUAL_CACHE_SUMMARIES[sentinel]} == retained &&
         ${_MANUAL_CACHE_ALIASES[sentinel]} == alias && $_MANUAL_SUMMARIES_READY == 0 ]] || exit 3
    done
    # Valid attacker-looking prose remains literal, never sourced or evaluated.
    bad=${original/Read data/\$(touch "$HOME/executed")}
    print -rn -- "$bad" >| "$file"
    _manual_cache_load "$file" "$key" || exit 4
    [[ ! -e "$HOME/executed" ]] || exit 5
    command chmod 644 "$file"
    _manual_cache_load "$file" "$key" && exit 6
    command chmod 600 "$file"
    command ln "$file" "$HOME/hardlink"
    _manual_cache_load "$file" "$key" && exit 7
    command ln -s "$file" "$HOME/symlink"
    _manual_cache_load "$HOME/symlink" "$key" && exit 8
    command mkfifo "$HOME/pipe"
    _manual_cache_load "$HOME/pipe" "$key" && exit 9
    command dd if=/dev/null of="$HOME/oversized" bs=1 seek=33554433 2>/dev/null
    command chmod 600 "$HOME/oversized"
    _manual_cache_load "$HOME/oversized" "$key" && exit 10
    return 0
  ' "$TEST_REPO_ROOT"
}
test_case 'manual cache rejects incomplete malformed control-bearing and unsafe files without partial state' \
  _test_manual_cache_rejects_invalid_data

_test_manual_cache_storage_failure() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Original description\n.SH SYNOPSIS\n'
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    source "${HOME:h}/public-provider.zsh"
    local MANPATH=$2 directory=$HOME/.zsh.addons/support/cache original=""
    _manual_prompt_capture || exit 1
    [[ -f "$directory/.zsh.manual.cache" ]] || exit 6
    original=$(<"$directory/.zsh.manual.cache")
    print -r -- $'\''.SH NAME\ndemo \\- Fresh description\n.SH SYNOPSIS\n'\'' >| "$MANPATH/man1/demo.1"
    command() {
      [[ $1 == /bin/mv ]] && return 1
      builtin command "$@"
    }
    _manual_summary_reset
    _manual_prompt_capture || exit 2
    [[ ${_MANUAL_SUMMARIES[demo]} == "Fresh description" &&
       $(<"$directory/.zsh.manual.cache") == "$original" ]] || exit 3
    local -a leftovers=("$directory"/.zsh.manual.cache.*(N))
    (( ! $#leftovers )) || exit 4
    # A separate process can obtain the lock after failed publication.
    /bin/zsh -dfc '\''zmodload zsh/system; zsystem flock -t 0 "$1"'\'' fixture "$directory/.zsh.manual.lock" || exit 5
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual"
}
test_case 'manual cache publication failure retains fresh memory old disk data and releases staging and lock' \
  _test_manual_cache_storage_failure

_test_manual_cache_directory_safety() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Read the fixture\n.SH SYNOPSIS\n'
  local variant=''
  for variant in addons-link support-link cache-link public-cache unsafe-file readonly-base; do
    test_run_interactive "$TEST_TMP_DIR/$variant" '
      source "$1/.zsh.addons/.zsh.manual"
      local MANPATH=$2 variant=$3 outside=$HOME/outside directory=$HOME/.zsh.addons/support/cache
      command mkdir -p "$outside"
      case $variant in
        addons-link) command ln -s "$outside" "$HOME/.zsh.addons" ;;
        support-link)
          command mkdir -p "$HOME/.zsh.addons"
          command ln -s "$outside" "$HOME/.zsh.addons/support" ;;
        cache-link)
          command mkdir -p "$HOME/.zsh.addons/support"
          command ln -s "$outside" "$directory" ;;
        public-cache) command mkdir -p "$directory"; command chmod 755 "$directory" ;;
        unsafe-file)
          command mkdir -p "$directory"; command chmod 700 "$directory"
          print -r -- preserve > "$outside/target"
          command ln -s "$outside/target" "$directory/.zsh.manual.cache" ;;
        readonly-base) command chmod 500 "$HOME" ;;
      esac
      {
        _manual_prompt_capture || exit 1
        [[ ${_MANUAL_SUMMARIES[demo]} == "Read the fixture" ]] || exit 2
        if [[ $variant == unsafe-file ]]; then
          [[ -L "$directory/.zsh.manual.cache" && $(<"$outside/target") == preserve ]] || exit 3
        else
          [[ ! -e "$directory/.zsh.manual.cache" ]] || exit 4
          local -a touched=("$outside"/*(ND))
          (( ! $#touched )) || exit 5
        fi
      } always {
        [[ $variant != readonly-base ]] || command chmod 700 "$HOME"
      }
    ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual" "$variant" || return
  done
}
test_case 'manual cache refuses symlinked unsafe and unwritable storage while preserving descriptions' \
  _test_manual_cache_directory_safety

_test_manual_cache_never_persists_private_inputs() {
  test_make_temp_dir || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- PRIVATE-DOCUMENT-FIXTURE\n.SH SYNOPSIS\n'
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    local MANPATH=$2 key="" data="" file=""
    _manual_cache_key || exit 1
    key=$REPLY
    _manual_prompt_capture || exit 2
    [[ ${_MANUAL_SUMMARIES[demo]} == PRIVATE-DOCUMENT-FIXTURE &&
       ${#_MANUAL_CACHE_SUMMARIES} == 0 ]] || exit 3
    # Arbitrary environment inputs must not be persisted even as fingerprints.
    local PATH=/private/path-fixture MANPATH=/private/manual-fixture
    local MANSECT=8:1 DEVELOPER_DIR=/private/developer-fixture
    builtin cd "$HOME"
    _manual_cache_key || exit 4
    [[ $REPLY == "$key" ]] || exit 5
    for file in "$HOME/.zsh.addons/support/cache"/*(ND.); do
      data=$(<"$file")
      [[ $data != *PRIVATE-DOCUMENT-FIXTURE* && $data != *"$HOME"* &&
         $data != */private/* ]] || exit 6
    done
    _manual_cache_page_id "$2/man1/demo.1" "$2" && exit 7
    _manual_cache_public_file "$2/man1/demo.1" 0 33188 && exit 8
    _manual_cache_public_file /usr/share/man/man1/demo.1 501 33188 && exit 9
    _manual_cache_public_file /usr/share/man/man1/demo.1 0 33206 && exit 10
    local OSTYPE=linux-gnu
    _manual_cache_key && {
      print -u2 "allowed persistent OS manuals without the protected Apple source boundary"; exit 11
    }
    return 0
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual"
}
test_case 'manual cache never persists custom manuals private paths or their selector fingerprints' \
  _test_manual_cache_never_persists_private_inputs

_test_manual_cache_private_forwarder() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/private/man1/private.1" $'.SH NAME\nprivate \\- PRIVATE-FORWARDED-DESCRIPTION\n.SH SYNOPSIS\n'
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" ".so $TEST_TMP_DIR/private/man1/private.1" || return
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    source "${HOME:h}/public-provider.zsh"
    local MANPATH=$2
    _manual_prompt_capture || exit 1
    [[ ${_MANUAL_SUMMARIES[demo]} == PRIVATE-FORWARDED-DESCRIPTION &&
       ${#_MANUAL_CACHE_SUMMARIES} == 0 &&
       ! -e "$HOME/.zsh.addons/support/cache/.zsh.manual.cache" ]] || exit 2
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual"
}
test_case 'manual cache keeps public-page forwarding to private documents memory-only' \
  _test_manual_cache_private_forwarder

_test_manual_cache_configuration_base_and_identity() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Public fixture\n.SH SYNOPSIS\n'
  local layout=''
  for layout in symlink copy; do
    test_run_interactive "$TEST_TMP_DIR/$layout" '
      local ZDOTDIR=$HOME/config MANPATH=$2 key="" changed=""
      command mkdir -p "$ZDOTDIR"
      if [[ $3 == copy ]]; then
        command cp "$1/.zshrc" "$ZDOTDIR/.zshrc"
        command mkdir -p "$ZDOTDIR/.zsh.addons"
        command cp -R "$1/.zsh.addons" "$ZDOTDIR/.zsh.addons/compozsh"
      else
        command ln -s "$1/.zshrc" "$ZDOTDIR/.zshrc"
      fi
      source "$ZDOTDIR/.zshrc"
      source "$4/public-provider.zsh"
      _manual_prompt_capture || exit 1
      [[ -f "$ZDOTDIR/.zsh.addons/support/cache/.zsh.manual.cache" &&
         ! -e "$HOME/.zsh.addons" &&
         ! -e "$ZDOTDIR/.zsh.addons/compozsh/support/cache" ]] || exit 2
      _manual_cache_key || exit 3
      key=$REPLY
      _MANUAL_CACHE_IMPLEMENTATION+=" changed owning code"
      _manual_cache_key || exit 4
      changed=$REPLY
      [[ $changed != "$key" ]] || exit 5
      _MANUAL_SUMMARIES_READY=0
      print -r -- $'\''.SH NAME\ndemo \\- Newly parsed after invalidation\n.SH SYNOPSIS\n'\'' >| "$MANPATH/man1/demo.1"
      _manual_prompt_capture || exit 6
      [[ ${_MANUAL_SUMMARIES[demo]} == "Newly parsed after invalidation" ]] || exit 7
      local LC_ALL=POSIX
      _manual_cache_key || exit 8
      [[ $REPLY != "$changed" ]] || exit 9
      LC_ALL=private-locale-fixture
      _manual_cache_key && exit 10
      return 0
    ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual" "$layout" "$TEST_TMP_DIR" || return
  done
}
test_case 'manual cache follows ZDOTDIR in both layouts and implementation or locale changes invalidate it' \
  _test_manual_cache_configuration_base_and_identity

# The implementation identity is the loaded owning code: the same code keys the
# same in every shell and after a re-source, and re-sourcing changed owning code
# changes the key.
_test_manual_cache_identity_follows_loaded_code() {
  test_make_temp_dir || return
  local manual='' changed='' output='' expected='' run=''
  manual=$(<"$TEST_REPO_ROOT/.zsh.addons/.zsh.manual") || return
  changed=${manual/$'\n_manual_cache_record_valid() {\n'/$'\n_manual_cache_record_valid() {\n  :\n'}
  [[ $changed != "$manual" ]] ||
    test_fail 'the changed-code fixture left .zsh.manual unchanged' || return
  test_write_file "$TEST_TMP_DIR/changed/.zsh.manual" "$changed" || return

  for run in first second; do
    output=$(test_run_interactive "$TEST_TMP_DIR/home-$run" '
      local key=""
      source "$1/.zshrc" || exit 1
      _manual_cache_key || exit 2
      key=$REPLY
      source "$1/.zsh.addons/.zsh.manual" || exit 3
      _manual_cache_key || exit 4
      [[ $REPLY == "$key" ]] || exit 5
      source "$2" || exit 6
      _manual_cache_key || exit 7
      [[ $REPLY != "$key" ]] || exit 8
      print -r -- "$key"
    ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/changed/.zsh.manual" 2>&1) ||
      test_fail "the $run shell's cache identity check failed: $output" || return
    [[ ${#output} -eq 64 && $output != *[^0-9a-f]* ]] ||
      test_fail "the $run shell printed no cache key: $output" || return
    if [[ -z $expected ]]; then
      expected=$output
    else
      test_assert_equal "$expected" "$output" \
        'the same code produced a different cache key in a fresh shell' || return
    fi
  done
}
test_case 'manual cache identity follows the loaded owning code across shells and re-sourcing' \
  _test_manual_cache_identity_follows_loaded_code

_test_manual_cache_recreates_removed_data() {
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Public fixture\n.SH SYNOPSIS\n'
  local phase=''
  for phase in build removed malformed directory-removed; do
    test_run_interactive "$TEST_TMP_DIR/home" '
      source "$1/.zsh.addons/.zsh.manual"
      source "${HOME:h}/public-provider.zsh"
      local MANPATH=$2 file=$HOME/.zsh.addons/support/cache/.zsh.manual.cache
      case $3 in
        removed) command rm -- "$file" ;;
        malformed) print -r -- invalid >| "$file" ;;
        directory-removed) command rm -r -- "${file:h}" ;;
      esac
      _manual_prompt_capture || exit 1
      [[ ${_MANUAL_SUMMARIES[demo]} == "Public fixture" && -f $file ]] || exit 2
      _manual_cache_key || exit 3
      _manual_cache_load "$file" "$REPLY" || exit 4
    ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual" "$phase" || return
  done
}
test_case 'manual cache is disposable and missing or malformed data is rebuilt with complete features' \
  _test_manual_cache_recreates_removed_data

_test_manual_cache_worker() {
  test_run_interactive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.manual"
    source "${HOME:h}/public-provider.zsh"
    local MANPATH=$2 role=$3 release=""
    functions[_test_read]=$functions[_manual_page_read]
    functions[_test_lock]=$functions[_manual_cache_lock]
    _manual_cache_lock() {
      [[ $role != second ]] || print -r -- locking > "$HOME/events"
      _test_lock "$@"
    }
    _manual_page_read() {
      print -r -- "$role" >> "$HOME/reads"
      if [[ $role == first ]]; then
        print -r -- building > "$HOME/events"
        IFS= read -r -t 5 release < "$HOME/release" || return 99
      fi
      _test_read "$@"
    }
    _manual_prompt_capture || exit 1
    [[ ${_MANUAL_SUMMARIES[demo]} == "Concurrent fixture" ]] || exit 2
  ' "$TEST_REPO_ROOT" "$TEST_TMP_DIR/manual" "$1"
}

_test_manual_cache_concurrent_build() {
  setopt LOCAL_OPTIONS
  unsetopt BG_NICE
  test_make_temp_dir || return
  _test_manual_cache_public_fixture || return
  test_write_file "$TEST_TMP_DIR/manual/man1/demo.1" $'.SH NAME\ndemo \\- Concurrent fixture\n.SH SYNOPSIS\n'
  command mkdir -p "$TEST_TMP_DIR/home" || return
  command mkfifo "$TEST_TMP_DIR/home/events" "$TEST_TMP_DIR/home/release" || return
  local -i10 events_fd=-1 release_fd=-1 first_pid=0 second_pid=0
  local event=''
  exec {events_fd}<> "$TEST_TMP_DIR/home/events"
  exec {release_fd}<> "$TEST_TMP_DIR/home/release"
  {
    _test_manual_cache_worker first > "$TEST_TMP_DIR/first.out" 2> "$TEST_TMP_DIR/first.err" &
    first_pid=$!
    IFS= read -r -t 5 -u $events_fd event && [[ $event == building ]] || return 1
    _test_manual_cache_worker second > "$TEST_TMP_DIR/second.out" 2> "$TEST_TMP_DIR/second.err" &
    second_pid=$!
    IFS= read -r -t 5 -u $events_fd event && [[ $event == locking ]] || return 2
    print -r -u $release_fd -- proceed
    wait $first_pid || return 3
    first_pid=0
    wait $second_pid || return 4
    second_pid=0
    test_assert_equal first "$(<"$TEST_TMP_DIR/home/reads")" 'simultaneous shells repeated the system manual read' || return
    [[ ! -s "$TEST_TMP_DIR/first.err" && ! -s "$TEST_TMP_DIR/second.err" ]] || return 5
  } always {
    (( first_pid == 0 )) || kill $first_pid 2>/dev/null
    (( second_pid == 0 )) || kill $second_pid 2>/dev/null
    exec {events_fd}>&-
    exec {release_fd}>&-
  }
}
test_case 'manual cache coordinates simultaneous first windows and publishes one complete public snapshot' \
  _test_manual_cache_concurrent_build
