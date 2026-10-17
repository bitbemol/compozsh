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

A second round of questions came out of planning. The planner produced 87
units rather than about 45, and raised four new owner questions. The answers
below are quoted as given (2026-10-14):

- **Plan size.** Answer: "Drop the 9 low-value units (Recommended)". The
  dropped units are a second Git-fixture migration, a shared bookmark stack,
  golden frames and a row-append helper, promotion of two parsers, and three
  micro-optimizations (U63, U66, U67). That leaves 80 units.
- **Compiled startup in the symlink layout.** Answer: "Rerun the installer
  (Recommended)". The installer regenerates the compiled code;
  `compozsh --refresh` does not. After a repository update, startup falls
  back to sourcing text until `./install.zsh` runs again.
- **USB sources on a virtual disk** (mounted disk image, sparsebundle, RAID
  set). Answer: "Refuse such sources (Recommended)". This fails closed, with
  a message to copy the image to a regular drive first.
- **Bare `g` branch catalog.** Answer: "Bound it with a notice
  (Recommended)". It becomes a bounded read with the standard partial
  notice, and inspector text is built only for the selected branch.
- **History size:** unchanged (stock values), per the recommendation.

Owner-approved units run in patch-only mode. The implementing agent builds and
verifies the change, then the orchestrator, who received these answers
directly, re-verifies and commits it.

## Commits

### Phase 1: breakage and safety

All 16 units landed, each on its first attempt (9–24 minutes each). Every
unit ran the full suite with zero failures. P1-14 to P1-16 are owner-approved
patch units: their agents built and verified them, and the orchestrator
re-verified each one (red at the prior HEAD, then green), reran the focused
filters and committed it.

The full suite over the three patch commits passed 1,044 cases. One case
failed: *PTY expectation fails at its deadline while output never stops*
measured 248 s against a 2–3 s window, because the Mac slept mid-run on
battery power. Run alone, it passed 3 times out of 3.

| Commit | Unit | Subject |
| --- | --- | --- |
| `d6c2070` | P1-01 (D-01, D-02) | Isolate test children's TMPDIR and fix two TMPDIR-sensitive tests |
| `3fed5a8` | P1-02 (A2-01, B-03) | Split Git review, syntax and prompt records on explicit separators |
| `26d6e60` | P1-03 (A2-01, B-03) | Split remaining peer and support text without the caller's IFS |
| `f4144af` | P1-04 (A2-02) | Apply precommand heads after chains and pipes in the prompt lens |
| `d62d5e7` | P1-05 (A2-03) | Release the Git syntax response when a review session ends |
| `564e61d` | P1-06 (A2-04) | Stream the worktree submodule scan so large repositories work |
| `e7b9ab6` | P1-07 (A2-04) | Stream the worktree removal index scan and disclose its bound |
| `5d6a1f4` | P1-08 (A1-02, A1-03) | Show USB Step 3 refusals and report empty diskutil output |
| `32f1f4e` | P1-09 (B-01) | Keep folder-only keys inert on images in the USB image browser |
| `95795de` | P1-10 (B-02) | Keep unbound cursor and function keys inert in picker views |
| `5ba73f2` | P1-11 (B-04) | Return status 130 from every workspace on Ctrl-C |
| `d3450e9` | P1-12 (SEC-B-02) | Stop locals named path from emptying PATH in Find and Git views |
| `a638476` | P1-13 (D-05) | Require the Git read-safety baseline at every passive Git call |
| `05991b0` | P1-14 (A1-01), patch | Bound the Build & Run settings capture for 100 targets |
| `8319374` | P1-15 (D-06), patch | Stop deleting user aliases and functions that reuse retired names |
| `e38fb40` | P1-16 (A2-05), patch | Route explicit-root Git reads through one local-only entry |

### Phase 2: test helpers and harness

The first run of phase 2 landed only P2-03. The laptop was on battery and
slept between maintenance wakes: the power log shows 1,187 sleep entries,
and one full-suite gate took 9,104 s instead of about 225 s. Each other unit
reached its wall-clock time box while the machine slept, so its work was
discarded with notes and, for P2-01, a saved patch.

That gate's five failures were PTY deadlines that stalled during sleep. Each
passed when rerun alone, and the tree stayed clean.

On AC power the retry landed all 11 remaining units on their first attempt,
at 7–17 minutes each, about 2.4 hours in all. Every unit kept each
migrated assertion's meaning or made it stricter. Nine units ran the full
suite with zero failures (P2-01: 1,047 passed); P2-06 and P2-08 needed only
focused filters.

| Commit | Unit | Subject |
| --- | --- | --- |
| `e026df7` | P2-03 (U70, D-03) | Remove the quadratic README scan and regex loop from static tests |
| `d75ec44` | P2-01 (D-03) | Add a linear screen-session trace helper for picker PTY tests |
| `b8cdf99` | P2-02 (D-03) | Use the screen-session helper in the remaining PTY tests |
| `029b8c9` | P2-04 (D-04) | Add a picker scripting helper and migrate five pilot stubs |
| `883b643` | P2-05 (D-04) | Script Xcode picker stubs through the shared helper |
| `079b98b` | P2-06 (D-04) | Script Git picker stubs through the shared helper |
| `f0c2ae1` | P2-07 (D-04) | Script filesystem picker stubs through the shared helper |
| `063eebf` | P2-08 (D-04) | Script task, composer, help and USB picker stubs via the helper |
| `da55abf` | P2-11 (C-10) | Compare full shell state across peer orders and re-sourcing |
| `72a9548` | P2-12 (D-11) | Apply the emulate rule by entry kind and check it statically |
| `b360a64` | P2-13 (D-12) | Correct stale UI-peer, cksum, Recents and USB help wording |
| `4964137` | P2-14 (D-07, A2-14) | Move test-only Git syntax wrappers to tests and drop dead prompt state |

## Release notes

- Ctrl-C in a Compozsh workspace now exits with status 130 from every
  command (`g`, `compozsh`, `g --review`, `g --worktree`, `xcode`,
  `external-device` and the `--help` workspaces), instead of 2, 0 or 130
  depending on the tool (P1-11, B-04).
- Search, Recents and Git review no longer empty the shell's command hash
  table, so entries added with `hash name=/path` survive using them
  (P1-12, SEC-B-02).
- Search's Git discovery, the prompt's Git-directory lookup and the
  `g --discard-all` repository checks now carry the same local-only Git
  controls as every other Compozsh Git read (no lazy fetch, prompts,
  transport, optional locks, pager, replacement objects, fsmonitor or hooks),
  and a static test keeps every such call on that baseline (P1-13, D-05,
  A2-05).
- Xcode Build & Run and Rebuild & Run now work for schemes with up to about
  100 targets. Build settings are read within a 5 MiB bound, or
  `ZSH_XCODE_CAPTURE_MAX_BYTES` when that is larger. Before, a scheme with
  about 7 or more targets failed with a capture-limit error. A larger scheme
  now stops with guidance that names the bound (P1-14, A1-01).
- Loading Compozsh no longer removes aliases or functions named
  `git-discard-all`, `prompt-refresh`, `flash-usb`, `format-external-device`,
  `compozsh-sudo-touch-id`, `update-xcode-skills` or `b`, so your own
  definitions with those names are kept. After updating from a release that
  defined these commands, open a new shell: re-sourcing a running shell no
  longer removes the old definitions (P1-15, D-06).
- Search's Git discovery also turns off Git's untracked cache and
  commit-signature verification, and bare `g` branch reads turn off the
  untracked cache. Git review and the worktree workspace already did both.
  All four go through one shared entry,
  `support/functions/.zsh.impure.compozsh_git_local`. Without it they run no
  Git command, and Search falls back to a non-Git provider (P1-16, A2-05).
- Browse (path + Tab) and Recents (Option-Tab) now release their view state
  when they close: the title, the status label (which can carry a folder
  name or a typed path), the empty-list label, the collector name, the
  selected path and the bookmark no longer stay in the shell, and `$REPLY`
  keeps the value it had before (P3-02, B-06, CON-B-02, CON-B-03).
- Search, bare `g` and `compozsh` (the tool explorer and every `--help`
  workspace) now release their view state too: Search's status label (which
  carries the submitted query), collector and capabilities, `g`'s branch
  catalog, choices, selected branch and bookmark, and the picker run's result
  limit no longer stay in the shell, and `$REPLY` (which `g` set to the
  repository root) keeps the value it had before (P3-03, B-06, CON-B-02).
- The external-device image browser, `g --review` (its menu and every review
  document) and `xcode` now release their view state too: the review
  document's capabilities (such as Option-number selection) no longer stay
  set in the shell, `g --review` no longer leaves the last resolved object ID
  in `$REPLY` or its final action and acceptance, and `xcode` no longer
  leaves the chosen value or acceptance behind (P3-04, B-06, SEC-C-02).
- Returning to Recents (Back from its actions menu, or from Browse) now also
  restores which pane had focus, the list or the details, as Browse, Search,
  the help workspaces and the composer already did (P3-06, B-10).

## Performance results

*Filled in by performance units and the final comparison.*

### P2-01: picker screen-session trace checks (D-03)

Metric: wall time of `zsh tests/run.zsh 'detail panels preserve native branch
switches'` (the slowest picker case; its description does not contain
"picker"), before tree `git archive e026df7`, after tree the working tree,
alternating order, the case's own en_US.UTF-8 locale.

| Test | Runs (before/after) | Before median (range) | After median (range) | Delta |
| --- | --- | --- | --- | --- |
| detail panels preserve native branch switches, path insertion, copying, and cleanup | 10/10 | 12955.95 ms (12748.7–13719.5) | 924.05 ms (877.1–1273.7) | −92.9 % |

The trace check stripped one screen marker at a time
(`${remaining%%"$leave"*}`), quadratic in the trace length; the shared
`test_pty_screen_sessions` splits the trace once per marker. A single before
run of 768 s from the unit's first attempt, during which the laptop slept on
battery, is excluded.

### P2-03: static README and network-client scans (U70, CROSS-02, D-03)

Metric: wall time of `zsh tests/run.zsh '<description>'`, before tree
`git archive 6e0c652`, after tree the working tree, alternating order. The
machine was loaded during the README runs, so absolute "before" numbers vary
widely; the gain is far beyond that noise.

| Test | Locale | Runs (before/after) | Before median (range) | After median (range) | Delta |
| --- | --- | --- | --- | --- | --- |
| security: runtime source contains no direct network-client invocation | en_US.UTF-8 | 10/10 | 2154.2 ms (1375.2–25375.0) | 427.8 ms (292.2–501.8) | −80.1 % |
| docs: README and agent contract inventory exactly match repository skills | C | 7/8 | 34198.8 ms (15774.4–117461.0) | 92.9 ms (64.5–108.9) | −99.7 % |
| docs: README and agent contract inventory exactly match repository skills | en_US.UTF-8 | 1/2 | 948750.7 ms | 66.8 ms (66.0–67.5) | −99.99 % |

The README scan was quadratic (`${remaining#*"$MATCH"}` re-matched every
prefix), far worse in a UTF-8 locale; it now slices at `MEND`. The README
"before" runs were cut short (7 C runs, 1 UTF-8 run) by the time box. The
network-client scan now matches each file's uncommented text once and runs the
per-line diagnostic loop only for a candidate file; NULs become line breaks
and a file with an invalid or incomplete character falls back to the line
scan, so the pre-filter never hides a line the old loop would report (pinned
by `security: network-client scan names the offending line of a fixture
file`, which passes against both scans in C and UTF-8).

## Unresolved and skipped findings

*Filled in at the end.*

## Manual Terminal.app acceptance pending

*Filled in at the end.*
