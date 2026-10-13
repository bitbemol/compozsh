#!/usr/bin/env zsh
# Handoff baseline that complements `zsh tests/run.zsh`: syntax-check every
# shipped Zsh file, reject whitespace errors in the diff and in new untracked
# files, and source the bootstrap twice in an isolated interactive shell, which
# must exit 0 without printing anything.

emulate -LR zsh
setopt EXTENDED_GLOB PIPE_FAIL

typeset -r repo_root=${0:A:h:h}
cd -- "$repo_root" || exit 1

typeset -i failed=0
typeset syntax_file='' test_home=''

for syntax_file in .zshrc install.zsh templates/init.zsh tests/*.zsh(N.) \
                   .zsh.addons/**/.zsh.?*(N.) .claude/skills/*/scripts/*.zsh(N.); do
  [[ $syntax_file == .zsh.addons/support/cache/* ]] && continue
  zsh -n "$syntax_file" || { print -u2 -r -- "syntax: $syntax_file"; failed=1; }
done
(( failed )) || print -r -- 'syntax: ok'

typeset whitespace='' new_file=''
whitespace=$(git diff --check 2>&1)
for new_file in ${(0)"$(git ls-files -z --others --exclude-standard)"}; do
  [[ -f $new_file ]] || continue
  whitespace+=$(git diff --no-index --check -- /dev/null "$new_file" 2>&1)
done
if [[ -z $whitespace ]]; then
  print -r -- 'whitespace: ok'
else
  print -u2 -r -- "$whitespace"
  failed=1
fi

# The bootstrap reports a failing peer and keeps going, and a peer can print a
# diagnostic yet return 0, so any output fails the check, not only the status.
typeset reload_output=''
typeset -i reload_status=0
test_home=$(mktemp -d) || exit 1
reload_output=$(env -i PATH=$PATH TERM=xterm-256color LC_ALL=C HOME=$test_home \
  ZDOTDIR=$test_home ZSH_LOCAL_INIT=/dev/null \
  zsh -dfi -c 'source ./.zshrc; source ./.zshrc' 2>&1) || reload_status=$?
if (( reload_status == 0 )) && [[ -z $reload_output ]]; then
  print -r -- 're-source: ok'
else
  [[ -z $reload_output ]] || print -u2 -r -- "$reload_output"
  print -u2 -r -- 're-source: failed'
  failed=1
fi
if [[ -d $test_home && ${test_home:t} == tmp.* ]]; then
  rm -rf -- "$test_home" || failed=1
else
  print -u2 -r -- "Refusing unsafe test cleanup: $test_home"
  failed=1
fi

(( failed == 0 ))
