---
paths:
  - ".zshrc"
  - "install.zsh"
  - "templates/init.zsh"
  - ".zsh.addons/.zsh.*"
  - ".zsh.addons/support/.zsh.*"
  - ".zsh.addons/support/functions/.zsh.*"
  - ".zsh.addons/support/ui/.zsh.*"
---

This is product shell code. Follow `engineering/zsh.md` (idioms, naming, the
`--help` contract) and `engineering/architecture.md`: peers stay
order-independent and re-source safe, and capture, pure calculation, painting
and post-cleanup actions stay separate. Change behavior test-first; a new
public command needs a same-source `_compozsh_help_<command>` companion and a
README entry.
