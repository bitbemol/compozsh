---
paths:
  - "README.md"
  - "SECURITY.md"
  - "CLAUDE.md"
  - "engineering/**/*.md"
  - "investigations/README.md"
---

`tests/documentation_test.zsh` pins exact phrases in README.md, SECURITY.md,
CLAUDE.md and some contracts, and each must stay on one line. It also requires
every `engineering/**/*.md` to be linked from CLAUDE.md and the README unit
inventory to match the shipped files. Run `zsh tests/run.zsh 'docs:'` after
editing.
