# Compile shipped peers into Compozsh's private compiled mirror. Not a peer:
# its name does not match .zsh.<name>, so discovery never sources it. The
# installer and the bootstrap both run it in a separate zsh -f:
#
#   zsh -f compile.zsh <install|startup> <mirror> <base> <zsh-version|''> <relative>...
#
# Each <base>/<relative> peer gets <mirror>/.zsh.addons/<relative>, a symlink to
# the peer, and that symlink's .zwc; .zshrc's comment describes how the
# manifest is checked. zcompile only parses, never runs, a peer. Compilation
# uses Zsh's default options and aliases, which the manifest records as the
# parse context, and a 077 umask. A peer is compiled only after the clock has
# passed its ctime, so any later write moves ctime past the recorded value; a
# peer that changes while it compiles is left out. A peer over 512 KiB, or one
# that fails to compile, gets a text record so startup does not retry it until
# it changes. New wordcode and the manifest are written under temporary names
# and renamed into place, so an interrupted run leaves nothing a shell uses.
#
# install: <mirror> must not exist; it is created, and every peer is compiled,
# waiting for the clock where needed. startup: an existing mirror is used only
# when it is a directory of this user's with no group or other access and the
# .managed-by-compozsh marker; a missing one is created. Work happens under a
# lock directory, which a concurrent run leaves alone (its shell loads text);
# a lock older than a minute is treated as abandoned. Only the listed peers are
# compiled, peers edited this second are left for the next shell, and no new
# peer starts compiling after 300 ms. Still-valid records are kept.
emulate -R zsh
umask 077
[[ $# -ge 4 && $1 == (install|startup) && $2 == /* && $3 == /* &&
   ( -z $4 || $4 == "$ZSH_VERSION" ) ]] || exit 2
unset EPOCHSECONDS EPOCHREALTIME
zmodload -F zsh/stat b:zstat &&
  zmodload -F zsh/datetime p:EPOCHSECONDS p:EPOCHREALTIME &&
  zmodload -F zsh/zselect b:zselect &&
  zmodload -F zsh/files b:zf_mkdir b:zf_ln b:zf_rm b:zf_mv b:zf_rmdir || exit 1

typeset mode=$1 mirror=$2 base=$3 relative='' peer='' entry='' temp='' line=''
typeset table='' name='' recorded_options='' recorded_aliases='' identity=''
typeset lock=$2/.lock
typeset -F deadline=0
typeset -i limit=524288 locked=0
typeset -a parse=(aliases posixaliases ignorebraces ignoreclosebraces
  rcquotes cshjunkiequotes cshjunkieloops kshglob shglob shortloops
  shortrepeat multifuncdef posixidentifiers posixstrings multibyte)
typeset -a header=() records=() lines=() fields=() link=()
typeset -A before=() after=() facts=() kept=() handled=() map=()
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

if [[ $mode == install ]]; then
  zf_mkdir -m 0700 -- "$mirror" &&
    print -r -- version=1 > "$mirror/.managed-by-compozsh" || exit 1
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

# Accept a relative path below <base> without control characters or ..
# components. Usage: _compile_relative <relative>
_compile_relative() {
  [[ -n $1 && $1 != /* && /$1/ != */../* && $1 != *[[:cntrl:]]* ]]
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
  # Temporary files left by an interrupted run are never used; drop them.
  lines=("$mirror"/manifest.compozsh-tmp-*(N) "$mirror"/.zsh.addons/**/*.compozsh-tmp-*.zwc(ND))
  (( ! $#lines )) || zf_rm -f -- "${lines[@]}"

  # Keep the previous manifest's records whose peers are still unchanged.
  if [[ $mode == startup ]] && zstat -L -H facts -- "$mirror/manifest" 2> /dev/null &&
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

  for relative in "$@"; do
    _compile_relative "$relative" || continue
    [[ $mode == install ]] || (( EPOCHREALTIME < deadline )) || break
    handled[$relative]=1
    peer=$base/$relative entry=$mirror/.zsh.addons/$relative
    temp=$entry.compozsh-tmp-$$.zwc
    zstat -H before -- "$peer" 2> /dev/null || continue
    while (( EPOCHSECONDS <= before[ctime] )); do
      [[ $mode == install ]] || continue 2
      zselect -t 10
      zstat -H before -- "$peer" 2> /dev/null || continue 2
    done
    identity="$before[device]"$'\t'"$before[inode]"$'\t'"$before[size]"
    identity+=$'\t'"$before[mtime]"$'\t'"$before[ctime]"
    if (( before[size] > limit )); then
      records+=("-"$'\t'"$relative"$'\t'"$identity")
      continue
    fi
    link=()
    zstat -L -A link +link -- "$entry" 2> /dev/null
    if [[ ${link[1]-} != "$peer" ]]; then
      zf_rm -f -- "$entry" "$entry.zwc" 2> /dev/null
      zf_mkdir -p -- "${entry:h}" && zf_ln -s -- "$peer" "$entry" || continue
    fi
    if zcompile -R -- "$temp" "$entry" 2> /dev/null; then
      zstat -H after -- "$peer" 2> /dev/null &&
        [[ "$after[device] $after[inode] $after[size] $after[mtime] $after[ctime]" ==
           "${identity//$'\t'/ }" ]] && zf_mv -f -- "$temp" "$entry.zwc" &&
        records+=("$relative"$'\t'"$identity")
    else
      zstat -H after -- "$peer" 2> /dev/null &&
        [[ "$after[device] $after[inode] $after[size] $after[mtime] $after[ctime]" ==
           "${identity//$'\t'/ }" ]] && records+=("-"$'\t'"$relative"$'\t'"$identity")
    fi
    zf_rm -f -- "$temp" 2> /dev/null
  done

  for relative line in "${(@kv)kept}"; do
    (( ${+handled[$relative]} )) || records+=("$line")
  done
  temp=$mirror/manifest.compozsh-tmp-$$
  print -rl -- "${header[@]}" "${records[@]}" > "$temp" &&
    zf_mv -f -- "$temp" "$mirror/manifest"
} always {
  trap '' INT HUP TERM
  lines=("$mirror"/manifest.compozsh-tmp-$$(N) "$mirror"/.zsh.addons/**/*.compozsh-tmp-$$.zwc(ND))
  (( ! $#lines )) || zf_rm -f -- "${lines[@]}"
  (( locked )) && zf_rmdir -- "$lock" 2> /dev/null
}
