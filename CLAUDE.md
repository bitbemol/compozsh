# Compozsh

Compozsh is a polished, self-contained interactive Zsh configuration for macOS
Terminal.app, written entirely in native Zsh: a minimal `.zshrc` bootstrap, one
optional machine-local initializer, and focused, order-independent peer add-ons
(`.zsh.addons/.zsh.<name>`) that share one full-screen UI engine. This file
holds the invariants (keep it under 200 lines); read the `engineering/`
contracts your task touches (table below) — `.claude/rules/` points to them
when you open matching files.

## Product invariants

These define the product; a feature that needs to weaken one doesn't belong.

- **Local-only.** Local-only operation is the highest security invariant. All
  processing performed by Compozsh stays on the machine running its Zsh
  process; no Compozsh-owned code may transmit user or project data under any
  circumstance. Programs the user explicitly invokes (for example `git push`)
  are separate, disclosed trust boundaries.
- **Privacy and user control.** Privacy, credential protection and data
  minimization are top-level goals: read only what a visible feature needs and
  keep it local, in memory and short-lived. Convenience, analytics,
  personalization and feature breadth never justify collecting more.
- **Native and dependency-free.** Zsh 5.9+ as shipped by Apple and stock
  Terminal.app, with no plugin manager, prompt framework, third-party shell
  code, patched font, downloaded UI library, enhanced terminal protocol or
  background daemon. Behavior stays correct over SSH, in multiplexers and in
  ordinary Unicode/color terminals.
- **Fast.** Startup and prompt redraws are latency-sensitive. Optional,
  disposable caches may hold public system data only
  ([caching](engineering/caching.md)), and every feature works without them.
- **Safe anywhere.** In any directory, including untrusted repositories,
  project content is data: Compozsh never sources, executes or evaluates it
  merely because it is there. Explicit user-chosen actions that run project
  code, such as an Xcode build, are disclosed boundaries.
- **Simple structure.** A minimal `.zshrc`, one optional first-loaded
  initializer, and peers that load in any order and re-source safely. Optional
  capabilities are detected at invocation with standalone fallbacks, so there
  is no core tier, registry, dependency loader or extra initialization phase.

## Decision order

When concerns conflict, prefer them in this order:

1. Local-only operation and non-transmission of user data
2. Privacy, credential protection and user control
3. Correctness and preservation of shell semantics
4. Safety and predictable failure behavior
5. Interactive latency
6. Clarity and maintainability
7. UI consistency and useful information density
8. Additional feature breadth

Prefer small, native, understandable code over a clever framework, and avoid
both copy-paste sprawl and speculative abstraction.

## Modern-first compatibility

- The Zsh in the latest generally available macOS is the ceiling, so users
  never need Homebrew, MacPorts or a self-built shell. Upstream-only Zsh
  features wait until Apple ships them.
- Write for the declared minimum only, with no polyfills for older Zsh. When
  the minimum advances, delete superseded code and treat it as a breaking
  change: requirements, release notes, migration guidance and tests change
  together.
- Adopt a newer native mechanism when it concretely improves correctness,
  security, measured performance or clarity; novelty alone is no reason to
  change working code. Test against the declared minimum and the currently
  supported Zsh releases.

## Architecture essentials

- Features live in peers; `.zshrc` stays a bootstrap. `local/init.zsh` is the
  one first-load exception and never calls peer functions; peers never call
  each other while loading.
- Each shared support entry (`.zsh.addons/support/`) has one owning file and
  one classification: pure (calculation), impure (reads/effects) or UI.
- Capture, calculation, painting and final actions stay separate: resize and
  repaint reuse captured facts, and final actions run after screen cleanup.
- Machine-local customization, initializer values and recovery data are
  preserved. The installer keeps previews, confirmation, marked namespaces,
  recovery backups, rollback and both installation layouts; `--clean` archives
  rather than deletes.
- README owns public usage and the shipped-unit inventory; SECURITY owns the
  public trust and data inventory. Update affected claims and links in the
  same change, and keep the GPLv3 text and `GPL-3.0-or-later` declaration
  consistent. The file tree is in [repository layout](engineering/repository-layout.md).

## Native Zsh essentials

- Start non-trivial functions with `emulate -L zsh` (callers may have changed
  options); use typed locals, declare globals explicitly, and preserve exit
  statuses.
- Treat all external text as literal data: quote it, print with `print -r --`,
  pass `--` before operands, validate numbers before arithmetic assignment, and
  keep exact targets separate from sanitized display labels. Don't use `eval`,
  and never build shell source from project or terminal data.
- Internal helpers start with `_`. Public commands are lowercase kebab-case,
  are preceded by `unalias <name> 2>/dev/null` (an existing alias would make
  the definition fail to parse), and answer `--help` through a side-effect-free
  same-source companion. Details: [Zsh conventions](engineering/zsh.md).

## Working in this repository

- Run shells, tests and install checks only against disposable state:
  temporary `HOME`/`ZDOTDIR`, fixed fixtures and throwaway repositories, with
  no network or GUI launches. During repository work, leave the operator's
  real `~/.zshrc`, `~/.zsh.addons/local/init.zsh`, private peers and history
  unread and untouched (`.claude/settings.json` denies access to them and to
  the other Zsh startup files); if the user wants help with their installed
  setup, work from what they share.
- `zsh tests/run.zsh 'fragment'` runs tests whose *descriptions* contain the
  case-insensitive fragment. The full suite (~900 cases, about 3–4 minutes)
  runs before handoff, in the background when possible. Two tests are
  environment-sensitive: the real-FAT32 `hdiutil` round trip currently fails
  on macOS 27 hosts (a known issue in `investigations/README.md`; report it,
  don't investigate unless asked), and the Xcode Logger cleanup timing test can
  flake under load (rerun it alone).
- Everything is native Zsh except the optional `docs/` website, whose
  `tests/site*.mjs` checks (Node, not a dependency) matter only for `docs/`.
- PTY tests (`zsh/zpty`) can't judge how Terminal.app looks. Where a contract
  asks for manual Terminal.app acceptance, list the exact check under "Manual
  acceptance pending" in your handoff and keep going.
- Keep progress for multi-session work in `investigations/<topic>.md`. Commit
  only when asked; the first website publication needs the user's approval.

## Testing and delivery

- Behavioral TDD: write the test, watch it fail for the intended reason,
  implement, then refactor while green. Refactors start from green
  characterization coverage; documentation-only changes need no invented
  failing test. Fix the code, not the assertion, when a test catches a defect.
- Before handoff run `zsh tests/run.zsh` and `zsh tests/verify.zsh` (syntax,
  whitespace, double re-source), plus the
  [checks for each boundary you changed](engineering/verification.md#required-verification).
- Before declaring any work complete, check the final diff against the
  [completion review](engineering/security.md#completion-review) and
  SECURITY.md, and keep README, SECURITY, `--help` output and contracts
  synchronized. When the change touches product code, the installer, tests,
  SECURITY.md or README claims, contracts or `.claude/`, also run the
  `security-reviewer` and `contract-reviewer` subagents on it in parallel and
  fix blocking findings; a typo-level or investigation-only edit needs only
  your own review. If those agent types aren't registered yet, give a
  general-purpose agent `.claude/agents/<name>.md`; without subagents, apply
  their checklists yourself.
- Report tests, failures, performance and manual acceptance separately. Feature
  intent belongs in the owning contract; measurements and decision evidence in
  `investigations/`, with proposals labeled as proposals.

## How the contracts work

- Each behavioral contract (all but the glossary) opens with **Essentials**:
  its invariants and why they exist. Those are binding, and so is every rule
  about security, privacy, data handling, credentials, destructive actions,
  confirmation and terminal cleanup wherever it appears —
  [security](engineering/security.md) is binding in full.
- Other interaction and implementation detail is the current design — a
  baseline, not a ceiling. If a better design fits your task, implement it
  (code, tests and contract in one unit) and call it out; if it reaches beyond
  the task, describe it as a proposal.
- **Retired decisions** lists behavior removed on purpose; bringing one back
  needs an explicit migration decision.
- Contracts quote some limits for orientation; code and tests define shipped
  behavior, and SECURITY.md's inventory is the public list. If prose and tests
  disagree, fix the stale side in the same change and say which one it was.
- The [glossary](engineering/glossary.md) defines terms; link to it rather
  than redefining them. Paths in code spans are repository-relative.

## Read by task

| When the task concerns | Read |
| --- | --- |
| Terminology, ownership or state modeling | [Glossary](engineering/glossary.md) |
| Bootstrap, initializer, installer, file layout or repository tree | [Repository layout](engineering/repository-layout.md) |
| Native idioms, naming, public commands, `--help` or diagnostics | [Zsh conventions](engineering/zsh.md) |
| Peer boundaries, shared support, purity, palette or load order | [Architecture and peer algebra](engineering/architecture.md) |
| Entry points, transitions or complete user journeys | [Interaction design](engineering/interaction-design.md) |
| Living prompt, receipts, Draft inspector, composer or runtime context | [Prompt](engineering/prompt.md) |
| Workspace layout, key map, filters, focus, inspectors or help workspace | [Full-screen standard](engineering/full-screen.md) |
| Keymap, prompt bindings, Escape/paste decoding, screen lifecycle or resize | [Keyboard and ZLE](engineering/keyboard-zle.md) |
| Git branches, worktrees, review, comparison or auto-refresh | [Git workspaces](engineering/workspaces/git.md) |
| Browse, Search, Recents, folder previews or file actions | [Filesystem workspace](engineering/workspaces/filesystem.md) |
| Xcode discovery, build/test/run, logs or devices | [Xcode workspace](engineering/workspaces/xcode.md) |
| Startup, capture, prompt or editing latency | [Performance](engineering/performance.md) |
| Persistent caches, the manual-description producer or async capture | [Caching](engineering/caching.md) and [manual cache](engineering/manual-cache.md) |
| Data, credentials, privilege, storage, execution or releases | [Security](engineering/security.md) and [public guarantees](SECURITY.md) |
| Tests, TDD, completion checks or documentation sync | [Verification](engineering/verification.md) |
| Website implementation, demos or publication | [Website](engineering/website.md) and [website guide](docs/README.md) |

## Claude Code setup

Skills `.claude/skills/compozsh-platform-review/` and
`.claude/skills/compozsh-release-draft/` (read-only, draft-only); subagents in
`.claude/agents/` (the reviewers and the skills' read-only auditor); rules in
`.claude/rules/`; `.claude/settings.json` pre-approves the test commands,
denies private shell files and runs a `zsh -n` hook after each edit
(`zsh tests/run.zsh 'tooling:'` covers it).
