---
paths:
  - ".claude/skills/**"
  - ".claude/agents/*"
  - ".claude/rules/*"
  - ".claude/settings.json"
  - ".claude/hooks/*"
  - "tests/platform_skill_test.zsh"
  - "tests/claude_tooling_test.zsh"
---

This is the Claude Code setup. Every skill must appear as
`.claude/skills/<name>/` in both CLAUDE.md and README (checked by
`zsh tests/run.zsh 'docs:'`); the snapshot script is covered by `'platform'`.
Skills stay read-only or draft-only, and any pre-approved tool or network grant
must be disclosed in SECURITY.md's external-boundaries list. Keep rules as
short pointers to contracts and update their `paths` when files move.
Settings and hooks stay narrow — no blanket Bash grants, and any zsh grant
ends options with `--` (otherwise `+n` or `-o exec` re-enables execution) —
and are pinned by `zsh tests/run.zsh 'tooling:'`; changed settings, agents and skills load only
in a new session.
