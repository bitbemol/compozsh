# Architecture pass, 2026-10-14

> **Status (2026-10-14): in progress.** Planning is done and the phases are
> being worked through on branch `architecture/2026-10-14`. The sections
> below fill in as each phase lands.

## Purpose

A structural and architectural pass, run after the
[excellence run](excellence-2026-10-12.md), to make the codebase a solid base
for new features. It fixes breakage the structural reviews reproduced, pays
down duplication and oversized functions, gives the shared engine an explicit
API, and brings startup within the performance budget. The branch is stacked
on `excellence/2026-10-12` at `ad67877`, so it carries every fix from that
run.

## Inputs

Five read-only reviews ran at `4d93c93`, one per lens. Each reported findings
with evidence, a proposed change, the tests needed first and an owner-decision
flag:

| Lens | Scope |
| --- | --- |
| A1 | `.zsh.usb` and `.zsh.xcode` |
| A2 | `.zsh.git-review`, `.zsh.prompt`, `.zsh.editor`, `.zsh.navigation`, `.zsh.git-worktree`, `.zsh.git-syntax` |
| B | The shared engine (`support/ui`, `support/functions`, `.zsh.appearance`) and its extension surface |
| C | Startup and per-prompt cost |
| D | Conventions, cross-peer duplication and test architecture |

Every review found the core design intact:
- pure entries are pure through their callees;
- no peer calls another while loading;
- full shell state converges across load orders;
- nothing transmits data.

The findings sit one level down: breakage on uncommon paths, copied plumbing,
oversized functions, and a startup cost above the budget.

## Owner decisions

The orchestrating session asked these questions in chat on 2026-10-14. The
answers below are quoted as given:

- **Scope.** Answer: "All five phases (Recommended)". The phases are:
  1. breakage and safety;
  2. test helpers;
  3. engine API and scoping;
  4. peer decomposition;
  5. performance.

  They run as sequential, time-boxed units, with a check-in after each phase.
- **Startup budget.** Warm process startup measured about 70 ms against
  roughly 50 ms. Answer: "Precompile with zcompile (Recommended)".
  - The installer generates `.zwc` files.
  - Peer discovery skips `*.zwc`.
  - `compinit` stays at startup, so completion is unchanged.
  - A freshness design must guarantee that stale compiled code never runs.
- **Approved changes.** Answer: all four of "One shared Git-read entry",
  "Larger Xcode settings bound", "Resolve the git shim once" and "Remove
  retired-name shims":
  - one support entry owns the Git read-safety environment and flags,
    replacing the per-peer copies that drifted;
  - the Build & Run settings capture gets its own bound, sized for 100
    targets and disclosed, with an actionable error beyond it;
  - `/usr/bin/git`'s real binary is resolved once per shell, with a
    root-owned check, and `compozsh --refresh` clears it;
  - the source-time cleanup that deletes aliases and functions with retired
    command names is removed, with a release note.
- **Not chosen:** deferring `compinit`, native `autoload`, splitting peers
  into several files, and caching Git filter names.

Owner-approved units run in patch-only mode. The implementing agent builds and
verifies the change, then the orchestrator, who received these answers
directly, re-verifies and commits it.

## Commits

*Filled in per phase.*

## Release notes

- Ctrl-C in a Compozsh workspace now exits with status 130 from every
  command (`g`, `compozsh`, `g --review`, `g --worktree`, `xcode`,
  `external-device` and the `--help` workspaces), instead of 2, 0 or 130
  depending on the tool (P1-11, B-04).
- Search, Recents and Git review no longer empty the shell's command hash
  table, so entries added with `hash name=/path` survive using them
  (P1-12, SEC-B-02).

## Performance results

*Filled in by performance units and the final comparison.*

## Unresolved and skipped findings

*Filled in at the end.*

## Manual Terminal.app acceptance pending

*Filled in at the end.*
