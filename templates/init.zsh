# Local initializer starter for Compozsh.
#
# The installer copies this file to the active configuration base's
# .zsh.addons/local/init.zsh only when that private file does not already exist.
# The base is ${ZDOTDIR:-$HOME}; `~/.zsh.addons` is the normal default. This
# tracked starter is intentionally
# inert: every example is commented, so sourcing an untouched copy changes
# nothing. Delete these comments and write the machine setup you actually need,
# or uncomment only the relevant Zsh statements below.
#
# Keep one responsibility here: provide inputs and prerequisites that must exist
# before order-independent .zsh.<name> peers load. Typical examples are PATH,
# Homebrew or language-manager initialization, a selected runtime, a trusted
# vendor bootstrap hook, and documented public defaults consumed by peers.
#
# If something does not need to run first, give it a focused private peer
# instead. Examples:
#   ${ZDOTDIR:-$HOME}/.zsh.addons/.zsh.aliases
#   ${ZDOTDIR:-$HOME}/.zsh.addons/.zsh.kiro
#   ${ZDOTDIR:-$HOME}/.zsh.addons/.zsh.ruby-tools
#   ${ZDOTDIR:-$HOME}/.zsh.addons/work/.zsh.company
#
# Do not call peer functions here: they have not loaded yet. Names beginning
# with _ are private implementation details and must not be called or replaced.

# Make a machine-specific command directory available before completion and
# command detection initialize. Zsh keeps PATH and its path array synchronized.
# typeset -gU path PATH
# path=("$HOME/.local/bin" $path)

# Apple Silicon Homebrew and a Homebrew-provided Ruby, when installed.
# typeset -gU path PATH fpath FPATH
# path=(/opt/homebrew/bin /opt/homebrew/sbin $path)
# fpath=(/opt/homebrew/share/zsh/site-functions $fpath)
# [[ -d /opt/homebrew/opt/ruby/bin ]] &&
#   path=(/opt/homebrew/opt/ruby/bin $path)

# A trusted machine-installed hook that genuinely must run before peers.
# [[ -r "$HOME/.config/example-tool/zsh/init.zsh" ]] &&
#   source "$HOME/.config/example-tool/zsh/init.zsh"

# Public defaults that their owning peers will preserve when they load.
# export EDITOR='vim'
# HISTSIZE=75000
# SAVEHIST=75000
# ZSH_COLOR_SCHEME=light  # auto (COLORFGBG hint), light, or dark
# typeset -gA ZSH_HIGHLIGHT_STYLES ZSH_OUTPUT_COLORS ZSH_PROMPT_COLORS
# ZSH_HIGHLIGHT_STYLES[command]='fg=118,bold'
# ZSH_OUTPUT_COLORS[success]=118
# ZSH_PROMPT_COLORS[identity]=110

# Keep credentials out of shell files when possible. Prefer the system keychain
# or a dedicated secret store, and never put private values in the repository.
