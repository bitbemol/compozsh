---
paths:
  - ".zsh.addons/.zsh.xcode"
  - "tests/xcode*"
---

The Xcode workspace is specified in `engineering/workspaces/xcode.md`. Build,
test and run actions execute project code, so they run only when chosen, after
screen restoration; discovery is bounded and never runs from repaint.
