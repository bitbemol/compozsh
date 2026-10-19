#!/usr/bin/env zsh

# Safe native installer for Compozsh. Existing shell state is
# preserved by default and clean installations archive it for recovery.

emulate -LR zsh
setopt PIPE_FAIL
typeset -gr _INSTALLER_REPOSITORY=${0:A:h}

_installer_usage() {
  print -r -- 'usage: zsh install.zsh (--symlink | --copy) [--clean] [--dry-run] [--yes]'
}

_installer_help() {
  _installer_usage
  print -rl -- 'Install Compozsh while preserving or archiving existing shell configuration.' \
    '' \
    'Mode and options:' \
    '  --symlink  Link the active .zshrc to this repository (recommended).' \
    '  --copy     Copy .zshrc and shared peers into .zsh.addons/compozsh.' \
    '  --clean    Archive existing .zshrc AND the entire private .zsh.addons,' \
    '             then create fresh configuration. Old data stays in backup.' \
    '  --dry-run  Inspect and print the plan without changing files.' \
    '  --yes      Accept the plan without asking; review --dry-run first.' \
    '  --help     Show this guide without inspecting or installing files.' \
    '  Choose one mode. With neither, an interactive terminal offers a menu;' \
    '  noninteractive use requires an explicit mode. Changes normally require' \
    '  y/Y at [y/N]; unattended installation additionally requires --yes.' \
    '' \
    'Location and private files:' \
    '  Run from the clone with zsh install.zsh, or pass the full script path' \
    '  from another directory. Source files are resolved beside the script.' \
    '  Destination is ${ZDOTDIR:-$HOME}; keep it separate from the repository.' \
    '  You do not need to create, empty, or delete an existing .zshrc.' \
    '  Normal installation preserves private add-ons and local/init.zsh.' \
    '  Generated source caches are excluded; normal updates preserve the' \
    '  destination support/cache directory. --clean archives it with add-ons.' \
    '  It copies an inert starter to .zsh.addons/local/init.zsh only if absent.' \
    '  A replaced .zshrc or managed copy is archived under .zsh-backups with' \
    '  a timestamp. --clean archives the entire add-on tree, including init.' \
    '  Normal mode refuses unmarked conflicts at .zsh.addons/compozsh.' \
    '  Both modes compile the shipped peers into the marked, owner-only' \
    '  .zsh.addons/support/compiled mirror for faster startup; private peers' \
    '  are never compiled. The next shell after a change recompiles just the' \
    '  changed shipped peers there; deleting the mirror is always safe.' \
    '' \
    'Updating and recovery:' \
    '  Symlink mode requires the repository to stay at its installed path.' \
    '  Update that clone with git pull, then run exec zsh in each terminal;' \
    '  the first shell recompiles the updated peers for fast startup.' \
    '  Copy mode keeps a snapshot; update the clone and rerun --copy to refresh.' \
    '  Both modes leave private data separate from shipped configuration.' \
    '  Failures and interruptions (Ctrl-C, hangup, termination) roll back;' \
    '  any printed recovery path holds replaced state for manual recovery.' \
    '  Installs only Compozsh configuration, never tools or package managers.' \
    '  Other startup files such as .zprofile and .zshenv remain untouched.' \
    '' \
    'Examples:' \
    '  Run these installer examples from the repository directory.' \
    '  zsh install.zsh --symlink --dry-run   Preview a preserving installation.' \
    '  zsh install.zsh --symlink             Install after confirmation.' \
    '  zsh install.zsh --copy                Install or refresh a copied setup.' \
    '  zsh install.zsh --symlink --clean --dry-run   Preview a fresh setup.' \
    '  exec zsh                             Load the installed configuration.'
}

_installer_choose_mode() {
  print -r -- 'Choose an installation mode:'
  print -r -- '  1) Symlink (recommended; repository updates apply immediately)'
  print -r -- '  2) Copy (shared add-ons live in a managed namespaced directory)'
  print -r -- '  3) Cancel'
  local answer=''
  read -r 'answer?Selection [1]: '
  case ${answer:-1} in
    1) REPLY=symlink ;;
    2) REPLY=copy ;;
    *) return 1 ;;
  esac
}

_installer_backup_path() {
  emulate -L zsh
  zmodload -F zsh/datetime b:strftime

  local backup_root=$1 stamp='' candidate=''
  local -i suffix=0
  # No epoch operand: strftime then reads the clock itself. Only the builtin
  # is loaded, so $EPOCHSECONDS would be unset or inherited environment text.
  strftime -s stamp '%Y%m%d-%H%M%S' || return 1
  candidate="$backup_root/compozsh-$stamp"
  while [[ -e $candidate || -L $candidate ]]; do
    (( ++suffix ))
    candidate="$backup_root/compozsh-${stamp}-${suffix}"
  done
  REPLY=$candidate
}

# Recursive removal is restricted to exact installer-owned boundaries. This is
# used only for staging cleanup and transaction rollback, never as installation
# behavior or as the meaning of --clean.
_installer_remove_tree() {
  emulate -L zsh

  local target=${1:A} expected_parent=${2:A} expected_name=$3
  [[ ${target:h} == $expected_parent && ${target:t} == ${~expected_name} ]] || {
    print -u2 -r -- "installer: refused unsafe cleanup target: $target"
    return 1
  }
  [[ -e $target || -L $target ]] || return 0
  command rm -rf -- "$target"
}

# Rollback moves an archived item back only when it reached the backup and its
# original location is free, so an interrupted step is never nested into or
# written over. An occupied original is a failed restore and keeps the backup.
_installer_restore() {
  emulate -L zsh

  local archived=$1 original=$2
  [[ -e $archived || -L $archived ]] || return 0
  [[ ! -e $original && ! -L $original ]] || return 1
  command mv -- "$archived" "$original"
}

# Ship reviewed code/assets, never generated machine-local module data or
# compiled code.
_installer_stage_addons() {
  emulate -L zsh
  local source_dir=$1 destination=$2 item=''
  local -a items=() support_items=()
  for item in "$source_dir"/*(ND); do
    if [[ $item != "$source_dir/support" || ! -d $item || -L $item ]]; then
      items+=("$item")
    fi
  done
  command mkdir -p -- "$destination" || return 1
  (( ! $#items )) || command cp -R "${items[@]}" "$destination/" || return 1
  if [[ -d $source_dir/support && ! -L $source_dir/support ]]; then
    for item in "$source_dir/support"/*(ND); do
      [[ ${item:t} == (cache|compiled) ]] || support_items+=("$item")
    done
    command mkdir -p -- "$destination/support" || return 1
    (( ! $#support_items )) || command cp -R "${support_items[@]}" "$destination/support/" || return 1
  fi
  return 0
}

# List the peers the bootstrap discovers beneath <directory>, the way it does:
# regular .zsh.<name> files, never support/cache, support/compiled or *.zwc.
_installer_peers() {
  emulate -L zsh
  local directory=$1 file=''
  reply=()
  for file in "$directory"/**/.zsh.?*(N.); do
    [[ $file == "$directory"/support/(cache|compiled)/* || $file == *.zwc ]] ||
      reply+=("$file")
  done
}

# Build the compiled mirror of shipped peers in <mirror>, which must not exist,
# with the same .zsh.addons/support/compile.zsh that startup uses to recompile
# changed peers; that file describes the mirror. Install mode compiles every
# listed peer, waiting at most about 2 s in total for the clock to pass a
# just-edited peer's ctime (a peer still ahead of it gets no record and loads
# as text). Like startup, it runs Apple's /bin/zsh from /, never a zsh found
# on PATH.
# Usage: _installer_compile <mirror> <base> <relative>...
_installer_compile() {
  emulate -L zsh
  ( builtin cd -q -- / &&
      exec /bin/zsh -f -- "$_INSTALLER_REPOSITORY/.zsh.addons/support/compile.zsh" \
        install "$1" "$2" '' "${@[3,-1]}" ) < /dev/null
}

_installer_main() {
  emulate -L zsh
  setopt PIPE_FAIL

  local mode='' argument='' answer=''
  local -i clean=0 dry_run=0 assume_yes=0
  for argument in "$@"; do
    case $argument in
      --symlink)
        [[ -z $mode || $mode == symlink ]] || {
          print -u2 -r -- 'installer: choose only one installation mode'
          return 2
        }
        mode=symlink
        ;;
      --copy)
        [[ -z $mode || $mode == copy ]] || {
          print -u2 -r -- 'installer: choose only one installation mode'
          return 2
        }
        mode=copy
        ;;
      --clean) clean=1 ;;
      --dry-run) dry_run=1 ;;
      --yes) assume_yes=1 ;;
      --help)
        _installer_help
        return 0
        ;;
      *)
        print -u2 -r -- "installer: unknown option: $argument"
        _installer_usage >&2
        return 2
        ;;
    esac
  done

  if [[ -z $mode ]]; then
    if [[ -t 0 && -t 1 ]]; then
      _installer_choose_mode || {
        print -r -- 'Cancelled; no files were changed.'
        return 1
      }
      mode=$REPLY
    else
      print -u2 -r -- 'installer: choose --symlink or --copy'
      return 2
    fi
  fi

  local repository=$_INSTALLER_REPOSITORY
  local source_zshrc="$repository/.zshrc"
  local source_addons="$repository/.zsh.addons"
  local source_initializer="$repository/templates/init.zsh"
  local source_file=''
  local -a source_peers=()
  _installer_peers "$source_addons"
  source_peers=("${reply[@]}")
  [[ -s $source_zshrc && -d $source_addons && -s $source_initializer ]] || {
    print -u2 -r -- 'installer: repository components are incomplete'
    return 1
  }
  (( ${#source_peers} )) || {
    print -u2 -r -- 'installer: repository contains no shared add-ons'
    return 1
  }
  for source_file in "$source_zshrc" "$source_initializer" \
                     "${source_peers[@]}"; do
    /bin/zsh -n -- "$source_file" || {
        print -u2 -r -- \
          "installer: repository Zsh file does not parse: $source_file"
        return 1
      }
  done

  local config_base=${${ZDOTDIR:-$HOME}:A}
  [[ -n $config_base && $config_base != / ]] || {
    print -u2 -r -- 'installer: refusing an unsafe configuration base'
    return 1
  }
  local active_zshrc="$config_base/.zshrc"
  local user_addons="$config_base/.zsh.addons"
  local initializer="$user_addons/local/init.zsh"
  local managed_addons="$user_addons/compozsh"
  local managed_marker="$managed_addons/.managed-by-compozsh"
  local compiled="$user_addons/support/compiled"
  local backup_root="$config_base/.zsh-backups"
  local rc_action=install addons_action=preserve initializer_action=create
  local compiled_action=build
  local -i backup_rc=0 backup_addons=0 backup_managed=0

  if [[ $repository == $config_base || $config_base == "$repository"/* ||
        $repository == $user_addons ||
        $repository == "$user_addons"/* ]]; then
    print -u2 -r -- \
      'installer: configuration base overlaps the repository source'
    return 1
  fi

  if (( clean )); then
    [[ -e $active_zshrc || -L $active_zshrc ]] && backup_rc=1
    [[ -e $user_addons || -L $user_addons ]] && backup_addons=1
    addons_action='archive all existing add-ons and create a fresh directory'
  else
    if [[ $mode == symlink && -L $active_zshrc &&
          ${active_zshrc:A} == ${source_zshrc:A} ]]; then
      rc_action=keep
    elif [[ $mode == copy && -f $active_zshrc && ! -L $active_zshrc &&
            "$(<"$active_zshrc")" == "$(<"$source_zshrc")" ]]; then
      rc_action=keep
    elif [[ -e $active_zshrc || -L $active_zshrc ]]; then
      backup_rc=1
    fi

    if [[ $mode == symlink && ( -e $managed_addons || -L $managed_addons ) ]]; then
      if [[ -L $managed_addons || ! -d $managed_addons ||
            ! -f $managed_marker || -L $managed_marker ]]; then
        print -u2 -r -- \
          "installer: $managed_addons is not managed by this installer"
        print -u2 -r -- \
          'Move it elsewhere before switching to the symlink installation.'
        return 1
      fi
      backup_managed=1
      addons_action='archive the previous managed copy; preserve private add-ons'
    elif [[ $mode == copy ]]; then
      if [[ -L $user_addons ]]; then
        print -u2 -r -- \
          'installer: copy mode will not write through a symlinked .zsh.addons'
        print -u2 -r -- 'Use --symlink, or use --copy --clean to archive it first.'
        return 1
      fi
      if [[ -e $managed_addons || -L $managed_addons ]]; then
        if [[ -L $managed_addons || ! -d $managed_addons ||
              ! -f $managed_marker || -L $managed_marker ]]; then
          print -u2 -r -- \
            "installer: $managed_addons is not managed by this installer"
          print -u2 -r -- \
            'Move it elsewhere, or use --copy --clean to archive all existing add-ons.'
          return 1
        fi
        backup_managed=1
        addons_action='refresh the managed shared-add-on namespace'
      else
        addons_action='create the managed shared-add-on namespace'
      fi
    fi
  fi
  [[ -e $initializer || -L $initializer ]] && initializer_action=keep
  (( clean )) && initializer_action=create
  # The compiled mirror is regenerated derived data, so a marked one is
  # replaced without a backup; anything else at its path is refused.
  if (( ! clean )) && [[ -e $compiled || -L $compiled ]]; then
    if [[ -L $compiled || ! -d $compiled ||
          ! -f $compiled/.managed-by-compozsh || -L $compiled/.managed-by-compozsh ]]; then
      print -u2 -r -- "installer: $compiled is not managed by this installer"
      print -u2 -r -- 'Move it elsewhere, or use --clean to archive all existing add-ons.'
      return 1
    fi
    compiled_action=rebuild
  fi

  print -r -- 'Compozsh installation plan'
  print -r -- "  Mode:        $mode"
  print -r -- "  Config base: $config_base"
  print -r -- "  Bootstrap:   $rc_action $active_zshrc"
  print -r -- "  Add-ons:     $addons_action"
  print -r -- "  Initializer: $initializer_action $initializer"
  print -r -- "  Compiled:    $compiled_action $compiled"
  if (( clean )); then
    print -r -- '  Clean mode:  existing state will be archived, never deleted'
  elif (( backup_rc || backup_managed )); then
    print -r -- '  Recovery:    replaced managed state will be timestamp-backed up'
  fi

  if (( dry_run )); then
    print -r -- 'Dry run; no files were changed.'
    return 0
  fi
  if (( ! assume_yes )); then
    [[ -t 0 && -t 1 ]] || {
      print -u2 -r -- 'installer: confirmation requires a terminal; inspect --dry-run, then use --yes'
      return 2
    }
    read -r 'answer?Proceed with this plan? [y/N] '
    [[ $answer == [yY] ]] || {
      print -r -- 'Cancelled; no files were changed.'
      return 1
    }
  fi

  command mkdir -p -- "$config_base" || {
    print -u2 -r -- "installer: cannot create configuration base: $config_base"
    return 1
  }

  local stage_dir='' staged_addons='' backup_dir='' compiled_stage='' compiled_base=''
  local -i rc_moved=0 addons_moved=0 managed_moved=0
  local -i rc_created=0 addons_created=0 managed_created=0
  local -i compiled_moved=0 compiled_created=0 support_created=0
  local -i initializer_created=0 transaction_ok=0 result=0

  # From here Ctrl-C, a hangup or a termination signal unwinds through the
  # always list like a handled failure, and a diagnostic written to a closed
  # pipe cannot end the installer. LOCAL_TRAPS (emulate -L) scopes all four.
  # Each step is recorded before it runs, so a signal that lands after a step
  # completed still undoes it. A new destination is checked free again just
  # before it is recorded, so an entry that appeared after planning is refused
  # instead of being replaced, nested into or removed by rollback.
  TRAPINT() { return $(( 128 + $1 )) }
  TRAPHUP() { return $(( 128 + $1 )) }
  TRAPTERM() { return $(( 128 + $1 )) }
  trap '' PIPE

  {
    # Prepare copy-mode content before moving any active state.
    if [[ $mode == copy ]]; then
      stage_dir=$(command mktemp -d "$config_base/.compozsh-install.XXXXXX") || {
        print -u2 -r -- 'installer: cannot create a staging directory'
        result=1
        return 1
      }
      staged_addons="$stage_dir/compozsh"
      _installer_stage_addons "$source_addons" "$staged_addons" &&
        print -r -- 'version=1' >| \
          "$staged_addons/.managed-by-compozsh" || {
          print -u2 -r -- 'installer: could not stage shared add-ons'
          result=1
          return 1
        }
    fi

    if (( backup_rc || backup_addons || backup_managed )); then
      _installer_backup_path "$backup_root" || {
        print -u2 -r -- 'installer: could not calculate a backup location'
        result=1
        return 1
      }
      backup_dir=$REPLY
      command mkdir -p -- "$backup_dir" || {
        print -u2 -r -- "installer: cannot create backup: $backup_dir"
        result=1
        return 1
      }
    fi

    if (( backup_rc )); then
      rc_moved=1
      command mv -- "$active_zshrc" "$backup_dir/.zshrc" || {
        print -u2 -r -- 'installer: could not archive the existing .zshrc'
        result=1
        return 1
      }
    fi
    if (( backup_addons )); then
      addons_moved=1
      command mv -- "$user_addons" "$backup_dir/.zsh.addons" || {
        print -u2 -r -- 'installer: could not archive the existing .zsh.addons'
        result=1
        return 1
      }
    fi
    if (( backup_managed )); then
      managed_moved=1
      command mv -- "$managed_addons" "$backup_dir/copied-addons" || {
        print -u2 -r -- 'installer: could not archive copied shared add-ons'
        result=1
        return 1
      }
    fi

    if [[ $rc_action == install ]]; then
      [[ ! -e $active_zshrc && ! -L $active_zshrc ]] || {
        print -u2 -r -- "installer: $active_zshrc appeared during installation"
        result=1
        return 1
      }
      rc_created=1
      if [[ $mode == symlink ]]; then
        command ln -s "$source_zshrc" "$active_zshrc"
      else
        command cp "$source_zshrc" "$active_zshrc"
      fi || {
        print -u2 -r -- 'installer: could not install the active .zshrc'
        result=1
        return 1
      }
    fi

    # A fresh add-on directory exists only where the old tree was archived.
    (( backup_addons )) && addons_created=1
    command mkdir -p -- "$user_addons" || {
      print -u2 -r -- 'installer: could not create the add-on directory'
      result=1
      return 1
    }
    if [[ $mode == copy ]]; then
      [[ ! -e $managed_addons && ! -L $managed_addons ]] || {
        print -u2 -r -- "installer: $managed_addons appeared during installation"
        result=1
        return 1
      }
      managed_created=1
      command mv -- "$staged_addons" "$managed_addons" || {
        print -u2 -r -- 'installer: could not activate copied shared add-ons'
        result=1
        return 1
      }
    fi

    if [[ $initializer_action == create ]]; then
      initializer_created=1
      command mkdir -p -- "${initializer:h}" &&
        command cp "$source_initializer" "$initializer" || {
          print -u2 -r -- 'installer: could not create the local initializer'
          result=1
          return 1
        }
    fi

    # Compile the peers this layout's bootstrap discovers as shared: the
    # repository's for a symlink install, the managed namespace's for a copy.
    if [[ $mode == symlink ]]; then
      compiled_base=${source_addons:A}
      _installer_peers "$compiled_base"
    else
      compiled_base=${user_addons:A}
      _installer_peers "$compiled_base/compozsh"
    fi
    [[ -d $user_addons/support ]] || support_created=1
    command mkdir -p -- "$user_addons/support" &&
      compiled_stage=$(command mktemp -d "$config_base/.compozsh-compiled.XXXXXX") &&
      _installer_compile "$compiled_stage/compiled" "$compiled_base" \
        "${(@)reply#"$compiled_base"/}" || {
        print -u2 -r -- 'installer: could not compile shared add-ons'
        result=1
        return 1
      }
    if [[ -e $compiled || -L $compiled ]]; then
      compiled_moved=1
      command mv -- "$compiled" "$compiled_stage/previous" || {
        print -u2 -r -- 'installer: could not replace the compiled add-ons'
        result=1
        return 1
      }
    fi
    [[ ! -e $compiled && ! -L $compiled ]] || {
      print -u2 -r -- "installer: $compiled appeared during installation"
      result=1
      return 1
    }
    compiled_created=1
    command mv -- "$compiled_stage/compiled" "$compiled" || {
      print -u2 -r -- 'installer: could not activate the compiled add-ons'
      result=1
      return 1
    }

    transaction_ok=1
  } always {
    # Cleanup is bounded local work; a repeated signal must not abandon it.
    trap '' INT HUP TERM
    if (( ! transaction_ok )); then
      print -u2 -r -- 'installer: rolling back the incomplete installation'
      if (( compiled_created )); then
        _installer_remove_tree "$compiled" "$user_addons/support" 'compiled' || result=1
      fi
      if (( compiled_moved )); then
        _installer_restore "$compiled_stage/previous" "$compiled" || result=1
      fi
      (( support_created )) && command rmdir -- "$user_addons/support" 2>/dev/null
      (( initializer_created )) && command rm -f -- "$initializer"
      if (( managed_created )); then
        _installer_remove_tree "$managed_addons" "$user_addons" \
          'compozsh' || result=1
      fi
      if (( managed_moved )); then
        _installer_restore "$backup_dir/copied-addons" "$managed_addons" || result=1
      fi
      if (( addons_created )); then
        _installer_remove_tree "$user_addons" "$config_base" '.zsh.addons' || result=1
      fi
      if (( addons_moved )); then
        _installer_restore "$backup_dir/.zsh.addons" "$user_addons" || result=1
      fi
      (( rc_created )) && command rm -f -- "$active_zshrc"
      if (( rc_moved )); then
        _installer_restore "$backup_dir/.zshrc" "$active_zshrc" || result=1
      fi
      if [[ -n $backup_dir && -d $backup_dir ]] &&
          ! command rmdir -- "$backup_dir" 2>/dev/null; then
        print -u2 -r -- "installer: rollback incomplete; replaced state remains in $backup_dir"
      fi
      result=1
    fi

    if [[ -n $stage_dir && ( -d $stage_dir || -L $stage_dir ) ]]; then
      _installer_remove_tree "$stage_dir" "$config_base" '.compozsh-install.*' || result=1
    fi
    # The superseded mirror, or one rollback could not put back, is derived
    # data the next installation regenerates.
    if [[ -n $compiled_stage && ( -d $compiled_stage || -L $compiled_stage ) ]]; then
      _installer_remove_tree "$compiled_stage" "$config_base" \
        '.compozsh-compiled.*' || result=1
    fi
  }

  (( result == 0 && transaction_ok )) || return 1
  print -r -- 'Installation complete.'
  [[ -n $backup_dir ]] && print -r -- "Recovery backup: $backup_dir"
  print -r -- 'Start a clean shell with: exec zsh'
}

_installer_main "$@"
typeset -i _installer_status=$?
unfunction _installer_usage _installer_help _installer_choose_mode _installer_backup_path
unfunction _installer_remove_tree _installer_restore _installer_peers
unfunction _installer_compile _installer_main
exit $_installer_status
