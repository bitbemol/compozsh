---
paths:
  - ".zsh.addons/support/functions/.zsh.*"
---

This is a classified shared support entry. Its `pure`/`impure` label is a
contract: follow "Pure entries stay pure" and "Shared support organization" in
`engineering/architecture.md`. When a request puts a read, effect or state in a
pure entry, say so and place it in an impure entry or the caller; ask the user
before making a pure entry impure. Run `zsh tests/run.zsh 'support pure'` and
the other support checks in `engineering/verification.md`, and review what the
scan can't see (listed in the architecture section).
