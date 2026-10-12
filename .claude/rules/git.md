---
paths:
  - ".zsh.addons/.zsh.git-*"
  - ".zsh.addons/support/git-syntax.vim"
  - ".zsh.addons/support/functions/.zsh.*.compozsh_git_*"
  - "tests/git_*"
  - "tests/branch_*"
  - "tests/discard_*"
---

Git workspaces are specified in `engineering/workspaces/git.md`. Compozsh's
own Git captures stay local (no transport, lazy fetch, hooks, fsmonitor or
filters); an explicit confirmed `git switch` keeps the repository's hooks and
filters by design. Review never mutates, and destructive helpers are tested
only in disposable repositories.
