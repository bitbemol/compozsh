# Bootstrap the dependency-free Zsh configuration. One optional machine-local
# initializer establishes paths and vendor environments first; every remaining
# feature is an independently sourceable peer add-on.

[[ -o interactive ]] || return

# Resolve through a symlinked ~/.zshrc so the add-on directory stays beside the
# repository source. A copied ~/.zshrc naturally resolves to ~/.zsh.addons.
typeset _zsh_config_file=${(%):-%N}
typeset _zsh_shared_addons_dir=${_zsh_config_file:A:h}/.zsh.addons
typeset _zsh_user_addons_dir=${ZDOTDIR:-$HOME}/.zsh.addons

# This is the only ordered boundary. It may initialize Homebrew, PATH, Ruby,
# editor/agent hooks, environment variables, and public defaults that
# shared add-ons consume. Its basename deliberately does not match .zsh.<name>,
# so recursive peer discovery cannot source it a second time. A relative path
# would resolve against the start directory, which may be a project, so it is
# refused rather than sourced.
typeset _zsh_local_init=${ZSH_LOCAL_INIT:-$_zsh_user_addons_dir/local/init.zsh}
if [[ $_zsh_local_init != /* ]]; then
  print -u2 -r -- 'zsh: ignoring relative local initializer path' \
    "(use an absolute ZSH_LOCAL_INIT): $_zsh_local_init"
elif [[ -f $_zsh_local_init && -r $_zsh_local_init ]]; then
  if ! source "$_zsh_local_init"; then
    print -u2 -r -- "zsh: local initializer failed to load: $_zsh_local_init"
  fi
fi

# Lexical traversal makes diagnostics reproducible, but add-ons must never rely
# on it: renaming or reordering peer files must produce the same final shell.
# Only regular .zsh.<name> files are sourced, and recursive globbing does not
# follow nested symlink directories. A symlink install loads repository peers
# plus private peers from ~/.zsh.addons; a copied install naturally scans its
# single combined directory only once. The fixed support/cache directory holds
# inert module data, including .zsh.<owner>.cache files, and the installer's
# support/compiled mirror holds compiled code; neither is ever discovered, and
# no *.zwc file is a peer. Discovery runs under fixed Zsh options before any
# peer loads, so glob options set by the initializer or a peer cannot change
# the set: the .zsh. prefix matches case-sensitively and hidden folders are
# never searched. Peers are then sourced at top level, keeping ordinary
# typeset and setopt semantics.
#
# The installer may leave a compiled mirror of the shipped peers it installed
# (never private peers) in ~/.zsh.addons/support/compiled: per peer, a symlink
# named like it beside its .zwc, and a manifest of the compiling Zsh version,
# its parse context (parse-affecting options and alias tables) and each peer's
# device, inode, size, mtime and ctime. A shipped peer runs from the mirror
# only when the mirror and manifest are the user's and closed to other
# accounts, the version matches, the mirror entry links to this exact file and
# the file's metadata still equals the record; any later write moves its ctime
# past the record. The parse context must match too: when peers start loading
# (so an initializer's aliases or parse options, or a re-sourced bootstrap's
# own aliases, mean text), and across every peer loaded as text. Shipped peers
# never parse differently under each other's definitions (the peer-order
# convergence test), so compiled peers may change it. Otherwise the peer's
# text is sourced, so the mirror changes only how fast a shell starts, never
# the state it reaches.
typeset -aU _zsh_addon_dirs=(
  "${_zsh_shared_addons_dir:A}"
  "${_zsh_user_addons_dir:A}"
)
typeset -a _zsh_addon_files=() _zsh_addon_parse=()
typeset -A _zsh_addon_compiled=()
typeset _zsh_addon_file='' _zsh_addon_source=''
typeset _zsh_addon_context='' _zsh_addon_expected=''
# Set _zsh_addon_context to the current parse context, described the way
# install.zsh records the compiling shell's: the _zsh_addon_parse options, read
# before emulate resets them, then the sorted alias tables.
_zsh_addon_parse_context() {
  local _zsh_option=''
  _zsh_addon_context=options
  for _zsh_option in "${_zsh_addon_parse[@]}"; do
    _zsh_addon_context+=" $_zsh_option=${options[$_zsh_option]-}"
  done
  emulate -LR zsh
  local table='' name=''
  local -A map=()
  _zsh_addon_context+=$'\n'aliases
  for table in aliases galiases saliases; do
    map=("${(@Pkv)table}")
    _zsh_addon_context+=" $table:"
    for name in ${(ok)map}; do
      _zsh_addon_context+=" ${(qqqq)name}=${(qqqq)map[$name]}"
    done
  done
}
() {
  emulate -LR zsh
  local compiled=$1 dir='' file='' line='' base='' entry=''
  local -a lines=() fields=() link=()
  local -A facts=()
  shift
  for dir in "$@"; do
    [[ -d $dir ]] || continue
    for file in "$dir"/**/.zsh.?*(N.); do
      [[ $file == "$dir/support/cache/"* || $file == "$dir/support/compiled/"* ||
         $file == *.zwc ]] || _zsh_addon_files+=("$file")
    done
  done

  [[ -f $compiled/manifest ]] && zmodload -F zsh/stat b:zstat 2>/dev/null &&
    zstat -L -H facts -- "$compiled" 2>/dev/null &&
    (( facts[uid] == EUID && (facts[mode] & 8#170077) == 8#40000 )) &&
    zstat -L -H facts -- "$compiled/manifest" 2>/dev/null &&
    (( facts[uid] == EUID && (facts[mode] & 8#170022) == 8#100000 )) || return 0
  lines=("${(@f)$(<"$compiled/manifest")}")
  [[ ${lines[1]-} == 'compozsh-compiled 1' && ${lines[2]-} == "zsh $ZSH_VERSION" &&
     ${lines[3]-} == 'base /'* && ${lines[4]-} == 'parse '* &&
     ${lines[5]-} == 'options'* && ${lines[6]-} == 'aliases'* ]] || return 0
  base=${lines[3]#base }
  _zsh_addon_parse=(${(s: :)lines[4]#parse })
  _zsh_addon_expected=${lines[5]}$'\n'${lines[6]}
  for line in "${(@)lines[7,-1]}"; do
    fields=("${(@ps:\t:)line}")
    (( ${#fields} == 6 )) && [[ $fields[1] != /* && /$fields[1]/ != */../* ]] || continue
    file=$base/$fields[1] entry=$compiled/.zsh.addons/$fields[1]
    zstat -H facts -- "$file" 2>/dev/null &&
      [[ "$facts[device] $facts[inode] $facts[size] $facts[mtime] $facts[ctime]" ==
         "${(j: :)fields[2,6]}" ]] &&
      zstat -L -A link +link -- "$entry" 2>/dev/null && [[ ${link[1]-} == "$file" ]] &&
      _zsh_addon_compiled[$file]=$entry
  done
} "${_zsh_user_addons_dir:A}/support/compiled" "${_zsh_addon_dirs[@]}"
if (( ${#_zsh_addon_compiled} )); then
  _zsh_addon_parse_context
  [[ $_zsh_addon_context == "$_zsh_addon_expected" ]] || _zsh_addon_compiled=()
fi
for _zsh_addon_file in "${_zsh_addon_files[@]}"; do
  _zsh_addon_source=${_zsh_addon_compiled[$_zsh_addon_file]:-$_zsh_addon_file}
  if (( ${#_zsh_addon_compiled} )) && [[ $_zsh_addon_source == "$_zsh_addon_file" ]]; then
    _zsh_addon_parse_context
    _zsh_addon_expected=$_zsh_addon_context
  fi
  if ! source "$_zsh_addon_source"; then
    print -u2 -r -- "zsh: add-on failed to load: $_zsh_addon_file"
  fi
  if (( ${#_zsh_addon_compiled} )) && [[ $_zsh_addon_source == "$_zsh_addon_file" ]]; then
    _zsh_addon_parse_context
    [[ $_zsh_addon_context == "$_zsh_addon_expected" ]] || _zsh_addon_compiled=()
  fi
done

unset _zsh_config_file _zsh_shared_addons_dir _zsh_user_addons_dir
unset _zsh_local_init _zsh_addon_dirs _zsh_addon_files _zsh_addon_file
unset _zsh_addon_parse _zsh_addon_compiled _zsh_addon_source
unset _zsh_addon_context _zsh_addon_expected
unfunction _zsh_addon_parse_context
