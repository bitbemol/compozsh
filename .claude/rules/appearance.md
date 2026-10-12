---
paths:
  - ".zsh.addons/support/.zsh.appearance"
  - ".zsh.addons/.zsh.output"
  - ".zsh.addons/support/functions/.zsh.impure.compozsh_palette_color"
  - "tests/appearance_*"
  - "tests/palette_*"
  - "tests/shared_palette_test.zsh"
---

Palette ownership is the Palette row of `engineering/architecture.md`: only
`support/.zsh.appearance` authors color defaults; consumers resolve public
overrides at invocation and never copy palettes or write fallback keys. Check
both schemes and `NO_COLOR`/plain fallbacks.
