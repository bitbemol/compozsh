---
paths:
  - ".zsh.addons/.zsh.prompt"
  - ".zsh.addons/.zsh.compose"
  - ".zsh.addons/support/functions/.zsh.*.prompt_*"
  - ".zsh.addons/support/functions/.zsh.*.runtime_*"
  - "tests/prompt_*"
  - "tests/runtime_*"
  - "tests/compose*"
  - "tests/inspector_test.zsh"
  - "tests/fixtures/compose-*"
---

Living prompt, receipts, Draft inspector, composer and runtime context are
specified in `engineering/prompt.md` — read its Essentials (and "Adding an
Interaction kind" for new lens kinds) before changing behavior. Lens
derivation and repaint stay provider-free: no subprocess, file read or network
work while editing (`engineering/performance.md`).
