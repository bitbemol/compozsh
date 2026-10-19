# Compile shipped peers, and Zsh's completion dump, into Compozsh's private
# compiled mirror. Not a peer: its name does not match .zsh.<name>, so
# discovery never sources it. The installer, the bootstrap and .zsh.editor run
# it with Apple's /bin/zsh by that absolute path, never a zsh found on PATH,
# with / as the working directory:
#
#   /bin/zsh -f compile.zsh <install|startup> <mirror> <base> <zsh-version|''> <relative>...
#   /bin/zsh -f compile.zsh dump <mirror> <dump> <zsh-version> [settle]
#
# A <zsh-version> other than this Zsh's is refused (exit 3): nothing is
# compiled, and the checked mirror's zsh note records this /bin/zsh's version
# and device, inode, size, mtime and ctime, so the callers start no further
# compile child until /bin/zsh changes.
#
# Each <base>/<relative> peer gets <mirror>/.zsh.addons/<relative>, a symlink to
# the peer, and that symlink's .zwc; .zshrc's comment describes how the
# manifest is checked. zcompile only parses, never runs, a peer. Compilation
# uses Zsh's default options and only its built-in aliases (run-help and
# which-command, whatever /etc/zshenv defined), which the manifest records as
# the parse context, and a 077 umask. A peer is compiled only after the clock
# has passed its ctime, so any later write moves ctime past the recorded
# value; a peer that changes while it compiles is left out. A peer over
# 512 KiB, or one that fails to compile, gets a text record so startup does
# not retry it until it changes. New wordcode and the manifest are written
# under temporary names and renamed into place, so an interrupted run leaves
# nothing a shell uses. Once a peer manifest is in place, every mirror entry
# and .zwc it does not name (a removed or renamed peer's, or one from a
# previous base) is deleted.
#
# install: <mirror> must not exist; it is created, and every peer is compiled,
# waiting for the clock where needed, but at most 2 s in total from the start:
# a peer whose ctime is still ahead of the clock then (the clock moved back,
# or a network volume's server runs fast) gets no record and loads as text
# until a shell compiles it once the clock has passed it.
#
# startup: an existing mirror is used only when it is a directory of this
# user's with no group or other access and the .managed-by-compozsh marker; a
# missing one is created. Work happens under a lock directory, which a
# concurrent run leaves alone (its shell loads text); a lock older than a
# minute is treated as abandoned. Only the listed peers are
# compiled, peers edited this second are left for the next shell, and no new
# peer starts compiling after 300 ms. Still-valid records are kept.
#
# dump: checks or creates the mirror as startup does and compiles the absolute
# <dump> (compinit's ${ZDOTDIR:-$HOME}/.zcompdump) as <mirror>/zcompdump, a
# symlink to it, beside zcompdump.zwc and a zcompdump.manifest that records the
# same header fields and only the dump's device, inode, size, mtime and ctime.
# The same clock, change, size and failure rules apply. With settle, compinit
# just loaded through the mirror but rewrote its dump at the entry path (fpath
# changed): that new dump is renamed to <dump>, where compinit itself would
# have written it, or deleted if the rename fails, before anything else.
emulate -R zsh
# Zsh reads /etc/zshenv even under zsh -f. Reset the alias tables to Zsh's
# built-in defaults before reading further, so this file, every compile and
# the manifest's record share a fixed, public context, never a startup file's
# aliases; when that fails, write nothing.
builtin unalias -m '*' 2> /dev/null
builtin unalias -s -m '*' 2> /dev/null
builtin alias run-help=man which-command=whence 2> /dev/null
(( ${#aliases} == 2 && ! ${#galiases} && ! ${#saliases} )) &&
  [[ ${aliases[run-help]-} == man && ${aliases[which-command]-} == whence ]] || exit 1
umask 077
[[ $# -ge 4 && $1 == (install|startup|dump) && $2 == /* && $3 == /* ]] || exit 2
[[ $1 != dump || ( $3 == */.zcompdump && /$3/ != */../* && $3 != *[[:cntrl:]]* &&
   -n $4 && ( $# == 4 || ( $# == 5 && $5 == settle ) ) ) ]] || exit 2
unset EPOCHSECONDS EPOCHREALTIME
zmodload -F zsh/stat b:zstat &&
  zmodload -F zsh/datetime p:EPOCHSECONDS p:EPOCHREALTIME &&
  zmodload -F zsh/zselect b:zselect &&
  zmodload -F zsh/files b:zf_mkdir b:zf_ln b:zf_rm b:zf_mv b:zf_rmdir || exit 1

typeset mode=$1 mirror=$2 base=$3 relative='' temp='' line=''
typeset table='' name='' recorded_options='' recorded_aliases='' identity=''
typeset lock=$2/.lock
typeset -F deadline=0
typeset -i limit=524288 locked=0 refused=0
typeset -a parse=(aliases posixaliases ignorebraces ignoreclosebraces
  rcquotes cshjunkiequotes cshjunkieloops kshglob shglob shortloops
  shortrepeat multifuncdef posixidentifiers posixstrings multibyte)
typeset -a header=() records=() lines=() fields=() link=() residue=()
typeset -A before=() after=() facts=() kept=() handled=() map=() named=()
[[ -z $4 || $4 == "$ZSH_VERSION" ]] || refused=1
shift 4

# The same description as _zsh_addon_parse_context in .zshrc.
for name in "${parse[@]}"; do
  recorded_options+=" $name=${options[$name]-}"
done
for table in aliases galiases saliases; do
  map=("${(@Pkv)table}")
  recorded_aliases+=" $table:"
  for name in ${(ok)map}; do
    recorded_aliases+=" ${(qqqq)name}=${(qqqq)map[$name]}"
  done
done
header=("compozsh-compiled 1" "zsh $ZSH_VERSION" "base $base"
  "parse ${parse[*]}" "options$recorded_options" "aliases$recorded_aliases")
[[ $mode != dump ]] || header[1,3]=("compozsh-compiled-dump 1" "zsh $ZSH_VERSION" "dump $base")

if [[ $mode == install ]]; then
  zf_mkdir -m 0700 -- "$mirror" &&
    print -r -- version=1 > "$mirror/.managed-by-compozsh" || exit 1
  (( deadline = EPOCHREALTIME + 2 ))
else
  if ! zstat -L -H facts -- "$mirror" 2> /dev/null; then
    # Create support/ only inside an add-on directory that is this user's.
    if ! zstat -L -H facts -- "${mirror:h}" 2> /dev/null; then
      zstat -L -H facts -- "${mirror:h:h}" 2> /dev/null &&
        (( facts[uid] == EUID && (facts[mode] & 8#170000) == 8#40000 )) || exit 1
      zf_mkdir -m 0700 -- "${mirror:h}" 2> /dev/null
    fi
    zf_mkdir -m 0700 -- "$mirror" 2> /dev/null &&
      print -r -- version=1 > "$mirror/.managed-by-compozsh" || exit 1
  fi
  zstat -L -H facts -- "$mirror" 2> /dev/null &&
    (( facts[uid] == EUID && (facts[mode] & 8#170077) == 8#40000 )) &&
    zstat -L -H facts -- "$mirror/.managed-by-compozsh" 2> /dev/null &&
    (( facts[uid] == EUID && (facts[mode] & 8#170000) == 8#100000 )) || exit 1
  (( deadline = EPOCHREALTIME + 0.3 ))
fi

# settle: compinit replaced the entry symlink with its new dump; move it home.
if [[ $mode == dump && ${1-} == settle ]] &&
    zstat -L -H facts -- "$mirror/zcompdump" 2> /dev/null &&
    (( facts[uid] == EUID && (facts[mode] & 8#170000) == 8#100000 )); then
  zf_mv -f -- "$mirror/zcompdump" "$base" 2> /dev/null ||
    zf_rm -f -- "$mirror/zcompdump" 2> /dev/null
fi

# Accept a relative path below <base> without control characters or ..
# components. Usage: _compile_relative <relative>
_compile_relative() {
  [[ -n $1 && $1 != /* && /$1/ != */../* && $1 != *[[:cntrl:]]* ]]
}

# Compile <file> through <entry>, a mirror symlink to it, into <entry>.zwc and
# add its record, led by <name> when given, to records: identity only after a
# compile during which the file did not change, or a "-" text record. A file
# whose ctime the clock has not passed waits (install, until the deadline) or
# is left, without a record, for the next shell.
# Usage: _compile_file <file> <entry> [<name>]
_compile_file() {
  local file=$1 entry=$2 name=${3:+$3$'\t'} temp=$2.compozsh-tmp-$$.zwc
  zstat -H before -- "$file" 2> /dev/null || return 1
  while (( EPOCHSECONDS <= before[ctime] )); do
    [[ $mode == install ]] && (( EPOCHREALTIME < deadline )) || return 1
    zselect -t 10
    zstat -H before -- "$file" 2> /dev/null || return 1
  done
  identity="$before[device]"$'\t'"$before[inode]"$'\t'"$before[size]"
  identity+=$'\t'"$before[mtime]"$'\t'"$before[ctime]"
  if (( before[size] > limit )); then
    records+=("-"$'\t'"$name$identity")
    return 0
  fi
  link=()
  zstat -L -A link +link -- "$entry" 2> /dev/null
  if [[ ${link[1]-} != "$file" ]]; then
    zf_rm -f -- "$entry" "$entry.zwc" 2> /dev/null
    zf_mkdir -p -- "${entry:h}" && zf_ln -s -- "$file" "$entry" || return 1
  fi
  if zcompile -R -- "$temp" "$entry" 2> /dev/null; then
    zstat -H after -- "$file" 2> /dev/null &&
      [[ "$after[device] $after[inode] $after[size] $after[mtime] $after[ctime]" ==
         "${identity//$'\t'/ }" ]] && zf_mv -f -- "$temp" "$entry.zwc" &&
      records+=("$name$identity")
  else
    zstat -H after -- "$file" 2> /dev/null &&
      [[ "$after[device] $after[inode] $after[size] $after[mtime] $after[ctime]" ==
         "${identity//$'\t'/ }" ]] && records+=("-"$'\t'"$name$identity")
  fi
  zf_rm -f -- "$temp" 2> /dev/null
  return 0
}

# Remove every mirror entry and wordcode file that the records do not name:
# those of a removed or renamed peer, or of a peer under a previous base. Runs
# only inside a real .zsh.addons directory of this user's; ** never follows a
# symlinked directory. Usage: _compile_prune
_compile_prune() {
  local entry=''
  named=() residue=()
  zstat -L -H facts -- "$mirror/.zsh.addons" 2> /dev/null &&
    (( facts[uid] == EUID && (facts[mode] & 8#170000) == 8#40000 )) || return 0
  for entry in "${records[@]}"; do
    entry=${entry#-$'\t'}
    named[${entry%%$'\t'*}]=1
  done
  for entry in "$mirror"/.zsh.addons/**/*(D@N); do
    (( ${+named[${entry#"$mirror"/.zsh.addons/}]} )) || residue+=("$entry")
  done
  for entry in "$mirror"/.zsh.addons/**/*.zwc(D.N); do
    [[ $entry == *.compozsh-tmp-* ]] ||
      (( ${+named[${${entry#"$mirror"/.zsh.addons/}%.zwc}]} )) || residue+=("$entry")
  done
  (( ! $#residue )) || zf_rm -f -- "${residue[@]}"
}

TRAPINT() { return $(( 128 + $1 )) }
TRAPHUP() { return $(( 128 + $1 )) }
TRAPTERM() { return $(( 128 + $1 )) }
if ! zf_mkdir -m 0700 -- "$lock" 2> /dev/null; then
  zstat -L -H facts -- "$lock" 2> /dev/null &&
    (( (facts[mode] & 8#170000) == 8#40000 &&
       ( EPOCHSECONDS - facts[mtime] > 60 || facts[mtime] - EPOCHSECONDS > 60 ) )) &&
    zf_rmdir -- "$lock" 2> /dev/null &&
    zf_mkdir -m 0700 -- "$lock" 2> /dev/null || exit 0
fi
locked=1
{
  # Temporary files left by an interrupted run are never used; drop them, and
  # compinit's own zcompdump.<host>.<pid> staging once it is a minute old.
  lines=("$mirror"/(manifest|zsh).compozsh-tmp-*(N) "$mirror"/.zsh.addons/**/*.compozsh-tmp-*.zwc(ND)
    "$mirror"/zcompdump*.compozsh-tmp-*(N))
  residue=("$mirror"/zcompdump.*(N.mm+0))
  lines+=("${(@)${(@)residue:#*/zcompdump.(zwc|manifest)}:#*.compozsh-tmp-*}")
  (( ! $#lines )) || zf_rm -f -- "${lines[@]}"

  # Another shell's version: record which Zsh this /bin/zsh is instead.
  if (( refused )); then
    if zstat -H facts -- /bin/zsh 2> /dev/null; then
      identity="$facts[device]"$'\t'"$facts[inode]"$'\t'"$facts[size]"
      identity+=$'\t'"$facts[mtime]"$'\t'"$facts[ctime]"
      temp=$mirror/zsh.compozsh-tmp-$$
      print -rl -- "compozsh-zsh 1" "zsh $ZSH_VERSION" "$identity" > "$temp" &&
        zf_mv -f -- "$temp" "$mirror/zsh"
    fi
  elif [[ $mode == dump ]]; then
    if _compile_file "$base" "$mirror/zcompdump" && (( $#records )); then
      temp=$mirror/zcompdump.manifest.compozsh-tmp-$$
      print -rl -- "${header[@]}" "${records[@]}" > "$temp" &&
        zf_mv -f -- "$temp" "$mirror/zcompdump.manifest"
    fi
  # Keep the previous manifest's records whose peers are still unchanged.
  elif [[ $mode == startup ]] && zstat -L -H facts -- "$mirror/manifest" 2> /dev/null &&
      (( facts[uid] == EUID && (facts[mode] & 8#170000) == 8#100000 )); then
    lines=("${(@f)$(<"$mirror/manifest")}")
    if [[ ${(pj:\n:)lines[1,6]} == ${(pj:\n:)header} ]]; then
      for line in "${(@)lines[7,-1]}"; do
        fields=("${(@ps:\t:)line}")
        [[ ${fields[1]-} == - ]] && fields=("${(@)fields[2,-1]}")
        (( ${#fields} == 6 )) && _compile_relative "$fields[1]" &&
          zstat -H facts -- "$base/$fields[1]" 2> /dev/null &&
          [[ "$facts[device] $facts[inode] $facts[size] $facts[mtime] $facts[ctime]" ==
             "${(j: :)fields[2,6]}" ]] && kept[$fields[1]]=$line
      done
    fi
  fi

  if (( ! refused )) && [[ $mode != dump ]]; then
    for relative in "$@"; do
      _compile_relative "$relative" || continue
      [[ $mode == install ]] || (( EPOCHREALTIME < deadline )) || break
      handled[$relative]=1
      _compile_file "$base/$relative" "$mirror/.zsh.addons/$relative" "$relative"
    done

    for relative line in "${(@kv)kept}"; do
      (( ${+handled[$relative]} )) || records+=("$line")
    done
    temp=$mirror/manifest.compozsh-tmp-$$
    print -rl -- "${header[@]}" "${records[@]}" > "$temp" &&
      zf_mv -f -- "$temp" "$mirror/manifest" && _compile_prune
  fi
} always {
  trap '' INT HUP TERM
  lines=("$mirror"/(manifest|zsh).compozsh-tmp-$$(N) "$mirror"/.zsh.addons/**/*.compozsh-tmp-$$.zwc(ND)
    "$mirror"/zcompdump*.compozsh-tmp-$$(N) "$mirror"/zcompdump.compozsh-tmp-$$.zwc(N))
  (( ! $#lines )) || zf_rm -f -- "${lines[@]}"
  (( locked )) && zf_rmdir -- "$lock" 2> /dev/null
}
(( ! refused )) || exit 3
