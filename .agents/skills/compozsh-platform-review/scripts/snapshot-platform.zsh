#!/bin/zsh

# Produce a stable, privacy-safe inventory for before/after platform reviews.
emulate -L zsh
setopt err_return no_unset pipe_fail no_clobber

_platform_snapshot_usage() {
  print -r -- 'Usage: snapshot-platform.zsh [--compare FILE | --output FILE]'
  print -r -- ''
  print -r -- 'Capture stock macOS, Terminal.app, Zsh, and Apple CLI facts.'
  print -r -- '  --compare FILE  Diff a prior snapshot against this Mac.'
  print -r -- '  --output FILE   Write a new snapshot; refuse an existing path.'
  print -r -- '  --help          Show this help.'
  print -r -- ''
  print -r -- 'Snapshots omit personal paths, names, host data, preferences, and hardware IDs.'
}

_platform_snapshot_fail() {
  print -u2 -r -- "snapshot-platform: $*"
  return 2
}

_platform_snapshot_line() {
  local key=$1 value=${2:-unavailable}
  value=${value//$'\r'/ }
  value=${value//$'\n'/ }
  value=${value//$'\t'/ }
  [[ -n $value ]] || value=unavailable
  print -r -- "$key"$'\t'"$value"
}

_platform_snapshot_first_line() {
  local captured=''
  captured=$("$@" 2>&1) || :
  REPLY=${captured%%$'\n'*}
  [[ -n $REPLY ]] || REPLY=unavailable
}

_platform_snapshot_module() {
  local module=$1
  local key=${module#zsh/}
  if /bin/zsh -dfc "zmodload '$module'" >/dev/null 2>&1; then
    _platform_snapshot_line "capability.zsh.${key//\//_}" 1
  else
    _platform_snapshot_line "capability.zsh.${key//\//_}" 0
  fi
}

_platform_snapshot_valid_baseline() {
  emulate -L zsh
  local file=$1 line='' key='' value=''
  local -i first=1
  local -A seen=()
  while IFS= read -r line || [[ -n $line ]]; do
    if (( first )); then
      [[ $line == $'schema\t1' ]] || return 1
      first=0
    fi
    [[ $line == *$'\t'* ]] || return 1
    key=${line%%$'\t'*}
    value=${line#*$'\t'}
    [[ $key[1] == [a-z0-9] && $key != *[^a-z0-9_.-]* &&
       $value != *$'\t'* && $value != *[^[:print:]]* &&
       ! ${+seen[$key]} -eq 1 ]] || return 1
    seen[$key]=1
  done < "$file"
  (( !first ))
}

_platform_snapshot_capture() {
  local -x PATH=/usr/bin:/bin:/usr/sbin:/sbin
  local -x LC_ALL=C LANG=C TERM=xterm-256color
  local terminal_plist='' developer_path='' developer_kind=none
  local value='' tool='' path=''
  local -a tools=(
    git /usr/bin/git vim /usr/bin/vim curl /usr/bin/curl
    ssh /usr/bin/ssh less /usr/bin/less grep /usr/bin/grep
    sed /usr/bin/sed awk /usr/bin/awk find /usr/bin/find
    mdfind /usr/bin/mdfind open /usr/bin/open pbcopy /usr/bin/pbcopy
    plutil /usr/bin/plutil man /usr/bin/man
  )

  _platform_snapshot_line schema 1
  _platform_snapshot_line platform.macos.product_version "$(/usr/bin/sw_vers -productVersion 2>/dev/null)"
  _platform_snapshot_line platform.macos.build_version "$(/usr/bin/sw_vers -buildVersion 2>/dev/null)"
  _platform_snapshot_line platform.architecture "$(/usr/bin/uname -m 2>/dev/null)"
  developer_path=$(/usr/bin/xcode-select -p 2>/dev/null) || developer_path=''
  case $developer_path in
    (/Library/Developer/CommandLineTools(|/*)) developer_kind=command-line-tools ;;
    (/Applications/Xcode*.app/Contents/Developer(|/*)) developer_kind=xcode ;;
    ('') developer_kind=none ;;
    (*) developer_kind=custom ;;
  esac
  _platform_snapshot_line platform.developer_tools.kind "$developer_kind"

  for path in \
    /System/Applications/Utilities/Terminal.app/Contents/Info.plist \
    /Applications/Utilities/Terminal.app/Contents/Info.plist; do
    [[ -f $path ]] && { terminal_plist=$path; break; }
  done
  if [[ -n $terminal_plist ]]; then
    value=$(/usr/bin/plutil -extract CFBundleShortVersionString raw -o - "$terminal_plist" 2>/dev/null) || value=unavailable
    _platform_snapshot_line platform.terminal.version "$value"
    value=$(/usr/bin/plutil -extract CFBundleVersion raw -o - "$terminal_plist" 2>/dev/null) || value=unavailable
    _platform_snapshot_line platform.terminal.build "$value"
  else
    _platform_snapshot_line platform.terminal.version unavailable
    _platform_snapshot_line platform.terminal.build unavailable
  fi

  _platform_snapshot_line runtime.zsh.path /bin/zsh
  _platform_snapshot_line runtime.zsh.version "$(/bin/zsh -dfc 'print -r -- "$ZSH_VERSION"' 2>/dev/null)"
  _platform_snapshot_first_line /usr/bin/git --version
  _platform_snapshot_line tool.git.version "$REPLY"
  _platform_snapshot_first_line /usr/bin/vim --version
  _platform_snapshot_line tool.vim.version "$REPLY"
  _platform_snapshot_first_line /usr/bin/curl --version
  _platform_snapshot_line tool.curl.version "$REPLY"
  _platform_snapshot_first_line /usr/bin/ssh -V
  _platform_snapshot_line tool.ssh.version "$REPLY"
  _platform_snapshot_first_line /usr/bin/less --version
  _platform_snapshot_line tool.less.version "$REPLY"
  _platform_snapshot_first_line /usr/bin/grep --version
  _platform_snapshot_line tool.grep.version "$REPLY"

  while (( ${#tools} )); do
    tool=$tools[1] path=$tools[2]
    tools[1,2]=()
    [[ -x $path ]] && value=1 || value=0
    _platform_snapshot_line "tool.$tool.available" "$value"
  done

  for value in zsh/system zsh/stat zsh/zpty zsh/datetime zsh/terminfo zsh/termcap zsh/complist; do
    _platform_snapshot_module "$value"
  done
  if /bin/zsh -dfc 'zmodload zsh/terminfo && [[ -n $terminfo[smcup] && -n $terminfo[rmcup] ]]' \
      >/dev/null 2>&1; then
    _platform_snapshot_line capability.terminal.alternate_screen 1
  else
    _platform_snapshot_line capability.terminal.alternate_screen 0
  fi
}

local mode=print target=''
while (( $# )); do
  case $1 in
    (--compare|--output)
      [[ $mode == print && $# -ge 2 && -n $2 ]] || {
        _platform_snapshot_usage >&2
        return 2
      }
      mode=${1#--} target=$2
      shift 2 ;;
    (--help)
      _platform_snapshot_usage
      return 0 ;;
    (*)
      _platform_snapshot_usage >&2
      return 2 ;;
  esac
done

local snapshot=''
snapshot=$(_platform_snapshot_capture) || _platform_snapshot_fail 'could not capture the native platform'

case $mode in
  (print)
    print -r -- "$snapshot" ;;
  (output)
    [[ $target != '-' && ! -e $target && -d ${target:h} ]] ||
      _platform_snapshot_fail 'output must be a new file in an existing directory'
    local old_umask=$(umask)
    umask 077
    print -r -- "$snapshot" > "$target" || {
      umask "$old_umask"
      _platform_snapshot_fail 'could not write the snapshot'
      return $?
    }
    umask "$old_umask"
    print -r -- 'Platform snapshot written.' ;;
  (compare)
    [[ -f $target && ! -L $target ]] ||
      _platform_snapshot_fail 'comparison input must be a regular non-symlink file'
    (( $(/usr/bin/wc -c < "$target") <= 131072 )) ||
      _platform_snapshot_fail 'comparison input exceeds 128 KiB'
    _platform_snapshot_valid_baseline "$target" ||
      _platform_snapshot_fail 'comparison input is not a valid inert platform snapshot'
    local temporary=''
    temporary=$(/usr/bin/mktemp "${TMPDIR:-/tmp}/compozsh-platform.XXXXXX") ||
      _platform_snapshot_fail 'could not create comparison workspace'
    trap '[[ -n $temporary && ${temporary:t} == compozsh-platform.* ]] && /bin/rm -f -- "$temporary"' EXIT INT TERM HUP
    print -r -- "$snapshot" >| "$temporary" || return 2
    local difference=''
    local -i diff_status=0
    difference=$(/usr/bin/diff -u -L previous -L current -- "$target" "$temporary") || diff_status=$?
    case $diff_status in
      (0) print -r -- 'No platform inventory changes.' ;;
      (1) print -r -- "$difference" ;;
      (*) _platform_snapshot_fail 'could not compare the snapshots' ;;
    esac ;;
esac
