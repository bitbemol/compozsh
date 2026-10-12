---
paths:
  - ".zshrc"
  - "install.zsh"
  - ".zsh.addons/.zsh.shell"
  - ".zsh.addons/.zsh.sudo-touch-id"
  - ".zsh.addons/.zsh.usb"
  - ".zsh.addons/.zsh.tools"
  - ".zsh.addons/.zsh.git-worktree"
  - ".zsh.addons/.zsh.manual"
  - ".zsh.addons/support/functions/.zsh.impure.compozsh_effect_*"
  - ".zsh.addons/support/functions/.zsh.impure.compozsh_capture_bounded"
  - ".zsh.addons/support/functions/.zsh.pure.compozsh_sanitize"
  - ".zsh.addons/support/functions/.zsh.impure.prompt_runtime_binary_is_trusted"
  - ".zsh.addons/support/functions/.zsh.*.usb_*"
  - "tests/security_test.zsh"
  - "tests/sudo_touch_id_test.zsh"
  - "tests/usb_*"
  - "SECURITY.md"
---

This file sits near a sourcing, history, privilege, destructive-action,
clipboard, persistent-storage or installation boundary. If your change touches
that boundary, follow `engineering/security.md` (binding in full) and keep
SECURITY.md's disclosure exact in the same change; the `security-reviewer`
subagent checks it at handoff. Unrelated edits here need nothing beyond the
standard handoff checks.
