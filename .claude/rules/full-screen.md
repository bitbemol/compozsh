---
paths:
  - ".zsh.addons/.zsh.help"
  - ".zsh.addons/support/ui/.zsh.ui.*"
  - ".zsh.addons/support/functions/.zsh.*.zle_*"
  - ".zsh.addons/support/functions/.zsh.pure.matching_*"
  - "tests/picker_*"
  - "tests/ui_*"
  - "tests/help_*"
  - "tests/fullscreen_*"
  - "tests/panel_*"
  - "tests/shortcut_*"
  - "tests/support_components_test.zsh"
---

This is the shared full-screen UI engine (and the help workspace built on it).
Read `engineering/full-screen.md` (layout, key map, filters, focus, help topic
workspace) and `engineering/keyboard-zle.md` (decoding, screen lifecycle).
Changes here affect history, files, Git, Xcode, help and external-device views
at once, so cover them with shared tests and a real PTY journey.
