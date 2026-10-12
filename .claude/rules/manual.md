---
paths:
  - ".zsh.addons/.zsh.manual"
  - "tests/manual_*"
  - "tests/fixtures/manual-*"
---

Manual descriptions, async capture and the public OS cache are specified in
`engineering/manual-cache.md` under `engineering/caching.md`. Nothing here may
run at source time or block the first editable prompt; measure cold and warm
first-prompt latency for changes.
