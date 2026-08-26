#!/usr/bin/env zsh

# Safe native installer for Compozsh. Existing shell state is
# preserved by default and clean installations archive it for recovery.

emulate -LR zsh
setopt PIPE_FAIL
typeset -gr _INSTALLER_REPOSITORY=${0:A:h}

_installer_usage() {
  print -r -- 'usage: zsh install.zsh (--symlink | --copy) [--clean] [--dry-run] [--yes]'
  print -r -- ''
  print -r -- '  --symlink  Link the active .zshrc to this repository (recommended).'
  print -r -- '  --copy     Copy the bootstrap and shared add-ons into the Zsh config base.'
  print -r -- '  --clean    Archive existing .zshrc and .zsh.addons, then start fresh.'
  print -r -- '  --dry-run  Print the exact plan without changing files.'
  print -r -- '  --yes      Accept the displayed plan without an interactive confirmation.'
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
  strftime -s stamp '%Y%m%d-%H%M%S' $EPOCHSECONDS || return 1
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
      --help|-h)
        _installer_usage
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
  local -a source_peers=("$source_addons"/**/.zsh.?*(N.))
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
    "$commands[zsh]" -n "$source_file" || {
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
  local backup_root="$config_base/.zsh-backups"
  local rc_action=install addons_action=preserve initializer_action=create
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

  print -r -- 'Compozsh installation plan'
  print -r -- "  Mode:        $mode"
  print -r -- "  Config base: $config_base"
  print -r -- "  Bootstrap:   $rc_action $active_zshrc"
  print -r -- "  Add-ons:     $addons_action"
  print -r -- "  Initializer: $initializer_action $initializer"
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

  local stage_dir='' staged_addons='' backup_dir=''
  local -i rc_moved=0 addons_moved=0 managed_moved=0
  local -i rc_created=0 addons_created=0 managed_created=0
  local -i initializer_created=0 transaction_ok=0 result=0

  # Prepare copy-mode content before moving any active state.
  if [[ $mode == copy ]]; then
    stage_dir=$(command mktemp -d "$config_base/.my-zsh-install.XXXXXX") || {
      print -u2 -r -- 'installer: cannot create a staging directory'
      return 1
    }
    staged_addons="$stage_dir/compozsh"
    command mkdir -p -- "$staged_addons" &&
      command cp -R "$source_addons"/. "$staged_addons"/ &&
      print -r -- 'version=1' >| \
        "$staged_addons/.managed-by-compozsh" || {
        print -u2 -r -- 'installer: could not stage shared add-ons'
        _installer_remove_tree "$stage_dir" "$config_base" '.my-zsh-install.*'
        return 1
      }
  fi

  {
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
      command mv -- "$active_zshrc" "$backup_dir/.zshrc" || {
        print -u2 -r -- 'installer: could not archive the existing .zshrc'
        result=1
        return 1
      }
      rc_moved=1
    fi
    if (( backup_addons )); then
      command mv -- "$user_addons" "$backup_dir/.zsh.addons" || {
        print -u2 -r -- 'installer: could not archive the existing .zsh.addons'
        result=1
        return 1
      }
      addons_moved=1
    fi
    if (( backup_managed )); then
      command mv -- "$managed_addons" "$backup_dir/copied-addons" || {
        print -u2 -r -- 'installer: could not archive copied shared add-ons'
        result=1
        return 1
      }
      managed_moved=1
    fi

    if [[ $rc_action == install ]]; then
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

    if [[ $mode == copy ]]; then
      command mkdir -p -- "$user_addons" || {
        print -u2 -r -- 'installer: could not create the add-on directory'
        result=1
        return 1
      }
      (( backup_addons )) && addons_created=1
      command mv -- "$staged_addons" "$managed_addons" || {
        print -u2 -r -- 'installer: could not activate copied shared add-ons'
        result=1
        return 1
      }
      managed_created=1
    else
      command mkdir -p -- "$user_addons" || {
        print -u2 -r -- 'installer: could not create the add-on directory'
        result=1
        return 1
      }
      (( backup_addons )) && addons_created=1
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

    transaction_ok=1
  } always {
    if (( ! transaction_ok )); then
      print -u2 -r -- 'installer: rolling back the incomplete installation'
      (( initializer_created )) && command rm -f -- "$initializer"
      if (( managed_created )); then
        _installer_remove_tree "$managed_addons" "$user_addons" \
          'compozsh' || result=1
      fi
      if (( managed_moved )); then
        command mv -- "$backup_dir/copied-addons" "$managed_addons" || result=1
      fi
      if (( addons_created )); then
        _installer_remove_tree "$user_addons" "$config_base" '.zsh.addons' || result=1
      fi
      if (( addons_moved )); then
        command mv -- "$backup_dir/.zsh.addons" "$user_addons" || result=1
      fi
      (( rc_created )) && command rm -f -- "$active_zshrc"
      if (( rc_moved )); then
        command mv -- "$backup_dir/.zshrc" "$active_zshrc" || result=1
      fi
      [[ -n $backup_dir && -d $backup_dir ]] && command rmdir "$backup_dir" 2>/dev/null
      result=1
    fi

    if [[ -n $stage_dir && ( -d $stage_dir || -L $stage_dir ) ]]; then
      _installer_remove_tree "$stage_dir" "$config_base" '.my-zsh-install.*' || result=1
    fi
  }

  (( result == 0 && transaction_ok )) || return 1
  print -r -- 'Installation complete.'
  [[ -n $backup_dir ]] && print -r -- "Recovery backup: $backup_dir"
  print -r -- 'Start a clean shell with: exec zsh'
}

_installer_main "$@"
typeset -i _installer_status=$?
unfunction _installer_usage _installer_choose_mode _installer_backup_path
unfunction _installer_remove_tree _installer_main
exit $_installer_status
