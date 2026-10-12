#!/usr/bin/env zsh
# Handoff baseline that complements `zsh tests/run.zsh`: syntax-check every
# shipped Zsh file, reject whitespace errors in the diff and in new untracked
# files, and source the bootstrap twice in an isolated interactive shell.

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

test_home=$(mktemp -d) || exit 1
if env -i PATH=$PATH TERM=xterm-256color LC_ALL=C HOME=$test_home \
   ZDOTDIR=$test_home ZSH_LOCAL_INIT=/dev/null \
   zsh -dfi -c 'source ./.zshrc; source ./.zshrc'; then
  print -r -- 're-source: ok'
else
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
