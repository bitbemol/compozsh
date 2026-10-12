---
paths:
  - ".zsh.addons/.zsh.editor"
  - ".zsh.addons/.zsh.highlighting"
  - "tests/editor_*"
  - "tests/highlighting_*"
---

The editor peer owns key bindings, ZLE adapters and the filesystem workspace
entries: see `engineering/keyboard-zle.md` (keymap, decoding, screen
lifecycle), `engineering/prompt.md` (living-prompt adapters) and
`engineering/workspaces/filesystem.md` (Browse, Search, Recents).
Highlighting and autosuggestions launch no subprocess and avoid unbounded scans.
