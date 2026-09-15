# Repository instructions

These are Compozsh's contributor requirements, independent of any personal
global instructions. Follow the user's authorized task and preserve the
product contracts below. Read the relevant engineering references before
changing their behavior; do not load every contract for every task.
Keep this root file within 16 KiB; place detailed contracts in `engineering/`.

## Product contract

This project is a polished, self-contained interactive Zsh configuration. Its
core promises are:

- Local-only operation is the highest security invariant. All processing
  performed by Compozsh remains on the machine running its Zsh process. No
  Compozsh-owned code may transmit user or project data under any circumstance.
- Privacy, credential protection, data minimization, and user control are
  top-level product goals. Handle only the minimum information required for a
  visible feature, keep it local and ephemeral whenever possible, and never
  trade privacy for convenience, analytics, personalization, or feature breadth.
- Zsh 5.9 or newer; compatibility with older Zsh releases is not a goal.
- No plugin manager, prompt framework, third-party shell code, patched font, or
  background daemon.
- macOS-first ergonomics with correct behavior in SSH sessions, multiplexers,
  and ordinary Unicode/color terminals.
- Target stock macOS Terminal.app and Apple's supported Zsh for new terminal
  UI. Do not require another emulator, enhanced terminal protocol, downloaded
  UI library, or replacement shell. Existing fallbacks remain intact.
- Fast startup and prompt redraws with no project-specific persistent cache or
  background state.
- A minimal stable `.zshrc` bootstrap, one optional first-loaded machine
  initializer, and focused order-independent peer add-ons.
- Safe behavior in arbitrary directories, including untrusted repositories.

Do not weaken one of these promises merely to add broader feature coverage.

## Modern-first compatibility policy

The declared minimum Zsh version is a product boundary, not a suggestion:

- Treat the Zsh version included with the latest generally available macOS as
  the compatibility ceiling. Never require Homebrew, MacPorts, or a
  user-compiled replacement shell merely to run Compozsh.
- Review the declared minimum and newly available native features after macOS
  major updates and relevant point releases. Use the repository-scoped
  `compozsh-platform-review` skill for this evidence-gathering pass. Do not
  adopt upstream-only Zsh behavior until Apple ships it in a generally
  available macOS release.
- Do not add compatibility branches, polyfills, or lowest-common-denominator
  syntax for Zsh releases older than the declared minimum.
- Prefer a newer native mechanism only when it concretely improves correctness,
  security, measured performance, or clarity. Novelty alone is not a reason to
  change working code.
- When the minimum advances, remove superseded implementations instead of
  retaining permanent legacy paths.
- Treat a minimum-version increase as a breaking change. Update requirements,
  release notes, migration guidance, and tests in the same unit of work.
- Test against the declared minimum and current supported Zsh releases; do not
  spend project complexity validating versions outside the support contract.

## Decision order

When concerns conflict, prefer them in this order:

1. Local-only operation and non-transmission of user data
2. Privacy, credential protection, and user control
3. Correctness and preservation of shell semantics
4. Safety and predictable failure behavior
5. Interactive latency
6. Clarity and maintainability
7. UI consistency and useful information density
8. Additional feature breadth

Small, native, understandable code is preferred to a clever framework. Avoid
both copy-paste sprawl and speculative abstraction.

## Essential repository boundaries

- The configuration base is `${ZDOTDIR:-$HOME}`. `.zshrc` only guards interactive
  startup, loads the optional machine initializer, discovers peers and reports
  diagnostics. Features belong in `.zsh.addons/` peers named `.zsh.<name>`.
- The optional `local/init.zsh` is the sole first-load exception. Peer setup
  must be order-independent and re-source safe. No core tier, registry,
  dependency loader or additional initialization phases. Resolve optional
  capabilities at invocation and retain standalone fallbacks.
- Preserve machine-local customization, initializer values and recovery data.
  Never read or modify real private peers, history or the active initializer
  during repository work. Installation tests use disposable locations.
- Keep installer previews, confirmation, marked namespaces, recovery backups,
  rollback and both installation layouts. `--clean` archives; it never deletes.
- README owns public usage and the shipped-unit inventory; SECURITY owns the
  public trust/data inventory and self-audit. Update affected claims and links
  with the change. `engineering/` holds detailed contributor contracts;
  `docs/` is the published website, not the engineering-document directory.
- Keep the canonical GPLv3 license and `GPL-3.0-or-later` declaration consistent.

## Native Zsh essentials

- Use native supported Zsh, locally scoped options (`emulate -L zsh`) and typed
  locals. Declare intentional globals explicitly. Preserve shell exit statuses.
- Quote literal data, use `print -r --` and supported `--` operand separators.
  Never use `eval` or construct shell source from project or terminal data.
  Validate numeric text before arithmetic assignment. Keep exact targets
  separate from sanitized display labels.
- Internal helpers use `_`; public owned commands use lowercase kebab-case
  and side-effect-free printable `--help` companions. Preserve existing wrapper
  semantics and documented extension APIs; consult the complete Zsh contract.
- Support entries have one owning file and explicit pure/impure/UI classification.
  Keep effects, capture, calculation, painting and final actions separate.
  Resize and repaint reuse captured facts; screen cleanup precedes final actions.

## Testing and delivery

- Behavioral TDD is mandatory: demonstrate the intended failing test before
  changing behavior, then implement and refactor with tests passing. Refactors
  begin from green characterization coverage; documentation needs no invented
  failing product test. Never weaken assertions to conceal defects.
- Use the native harness in `tests/support.zsh`, isolated `HOME`/`ZDOTDIR`,
  fixed fixtures and disposable repositories. Never source the operator's
  configuration or depend on network, private data or GUI launches in tests.
- From the repository root, use `zsh tests/run.zsh 'description-filter'` during
  development and `zsh tests/run.zsh` before handoff. Run `git diff --check` and
  the syntax/re-source baseline in the verification contract. Select additional
  checks by changed boundary; PTY evidence does not replace manual Terminal.app
  acceptance where that contract requires it.
- Before declaring any work complete, review the final diff against SECURITY.md
  and run the security/documentation contracts as defined in verification.
  Preserve independent audits and full disclosure of external trust boundaries.
- Keep substantial feature intent and acceptance criteria in the relevant
  engineering contract; record decisions and bounded experiments in
  `investigations/`, distinguishing proposals and historical evidence from
  shipped requirements. Record resumable progress for long tasks.
- Report tests, failures, performance measurements and manual acceptance
  separately. Commit only when requested; never stage unrelated work or push
  without authorization. First website publication requires local visual approval.

## Read by task

| When the task concerns | Read before changing the contract |
| --- | --- |
| Terminology, context, ownership or state modeling | [Glossary](engineering/glossary.md) |
| Bootstrap, initializer, installation or file layout | [Repository layout](engineering/repository-layout.md) |
| Native idioms, names, help or command interfaces | [Zsh conventions](engineering/zsh.md) |
| Peer boundaries, shared support, purity or load order | [Architecture and peer algebra](engineering/architecture.md) |
| Entry points, scope, transitions or complete user journeys | [Interaction design](engineering/interaction-design.md) |
| Prompt lenses, receipts, inspector or composer | [Prompt](engineering/prompt.md) |
| Shared screen layout, selection, focus or presentation | [Full-screen standard](engineering/full-screen.md) |
| Widgets, keys, paste, resize or terminal cleanup | [Keyboard and ZLE](engineering/keyboard-zle.md) |
| Git worktrees, review, tree navigation or refresh | [Git workspaces](engineering/workspaces/git.md) |
| Browse, search, recents or filesystem actions | [Filesystem workspace](engineering/workspaces/filesystem.md) |
| Xcode discovery, build/test/run, logs or devices | [Xcode workspace](engineering/workspaces/xcode.md) |
| Startup, capture, prompt or editing latency | [Performance](engineering/performance.md) |
| Data, credentials, privilege, storage, execution or release | [Security engineering](engineering/security.md) and [public guarantees](SECURITY.md) |
| Tests, completion checks or documentation synchronization | [Verification](engineering/verification.md) |
| Website implementation, demos or publication | [Website boundary](engineering/website.md) and [website guide](docs/README.md) |

## Repository skills

- `.agents/skills/compozsh-platform-review/`: read-only audit after platform
  updates; separates observed Apple-shipped capabilities from adoption proposals.
- `.agents/skills/compozsh-release-draft/`: read-only release evidence and draft
  notes from the actual published baseline. It grants no publication authority.
