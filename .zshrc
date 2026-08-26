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
# so recursive peer discovery cannot source it a second time.
typeset _zsh_local_init=${ZSH_LOCAL_INIT:-$_zsh_user_addons_dir/local/init.zsh}
if [[ -f $_zsh_local_init && -r $_zsh_local_init ]]; then
  if ! source "$_zsh_local_init"; then
    print -u2 -r -- "zsh: local initializer failed to load: $_zsh_local_init"
  fi
fi

# Lexical traversal makes diagnostics reproducible, but add-ons must never rely
# on it: renaming or reordering peer files must produce the same final shell.
# Only regular .zsh.<name> files are sourced, and recursive globbing does not
# follow nested symlink directories. A symlink install loads repository peers
# plus private peers from ~/.zsh.addons; a copied install naturally scans its
# single combined directory only once.
typeset -aU _zsh_addon_dirs=(
  "${_zsh_shared_addons_dir:A}"
  "${_zsh_user_addons_dir:A}"
)
for _zsh_addons_dir in "${_zsh_addon_dirs[@]}"; do
  [[ -d $_zsh_addons_dir ]] || continue
  for _zsh_addon_file in "$_zsh_addons_dir"/**/.zsh.?*(N.); do
    if ! source "$_zsh_addon_file"; then
      print -u2 -r -- "zsh: add-on failed to load: $_zsh_addon_file"
    fi
  done
done

unset _zsh_config_file _zsh_shared_addons_dir _zsh_user_addons_dir
unset _zsh_local_init _zsh_addon_dirs _zsh_addons_dir _zsh_addon_file
