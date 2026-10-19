# Architecture pass, 2026-10-14

> **Status (2026-10-19): complete.** All six phases, the project-rule commits
> and a final security and contract review with before/after measurements
> ran on branch `architecture/2026-10-14`. The owner then answered the
> final-review questions, and a follow-up batch landed in 16 commits after
> two more review rounds (see [Follow-ups](#follow-ups-after-the-final-review)).
> The branch was then fast-forwarded into the local `main`, not pushed.
> Open items are the remaining non-blocking findings, a proposed CLAUDE.md
> change and the manual Terminal.app checks, listed below.

## Summary

- **Scope.** A structural pass on `architecture/2026-10-14`, stacked on the
  excellence run's tip `ad67877` (itself `main` at `36cdcda` plus that run's
  82 commits). Five read-only review lenses ran at `4d93c93` on 2026-10-14;
  the record started at 17:10 that day and the final measurements ended on
  2026-10-18 at about 21:40 CST, about 100 h of wall clock.
- **Units.** Planning produced 87 units. The owner dropped 9 and two were
  added for the excellence run's open questions (P4-30, P4-31), leaving 80
  units in five phases. The owner's fourth-round request added phase 6 (three
  units), and the owner then dropped P6-02 for privacy. 82 units landed as
  commits, each on the first attempt of the run that landed it. Phase 2's
  first run, slowed by laptop sleep, landed only P2-03, and its retry landed
  the other 11. P5-12 came back once for an owner decision.
- **Commits.** 101 including this one: 82 unit commits, 3 project-rule
  commits (two of them units P7-01 and P7-02), 9 final-review fixes and 7
  record commits. Product code changed in 49 files (+4,935/−3,282 lines) and
  tests in 106 files (+9,115/−917).
- **What changed.**
  - Phase 1 landed 16 breakage and safety units, for example splits on the
    caller's IFS, Ctrl-C statuses, `path` locals emptying `PATH` and
    worktree scans in large repositories. It also routed Git reads through
    one local-only entry.
  - Phase 2 made the PTY and picker test helpers linear and shared.
  - Phase 3 gave the shared engine an explicit API. Views reach it only
    through `_zle_ui_view`, so their state ends when they close.
  - Phase 4 decomposed the USB, Xcode, Git and prompt peers in four parallel
    lanes.
  - Phases 5 and 6 brought startup within its budget. Shipped peers and the
    completion dump load from a compiled mirror that is used only while
    strict file-identity checks pass and is recompiled at startup. Compozsh's
    Git reads run the Apple-signed Git directly.
- **Final review.** Six security and contract passes over three slices of
  `excellence/2026-10-12..HEAD` raised 48 findings, 11 of them blocking. Nine
  fix commits resolved all 11. F02, F05 and this record also resolved four
  non-blocking ones, so 33 remain as follow-ups.
- **Tests.** The suite went from 1,022 cases to 1,133, all passing in
  322.5 s, and `zsh tests/verify.zsh` passes. Two runs lost cases to laptop
  sleep, and each of those cases passed when run alone. The Xcode Logger
  timing flake did not occur in any recorded full run.
- **Latency.** Final tree against `main` (`36cdcda`) and against the
  excellence run's end (`ad67877`), in one session:
  - Warm isolated startup in a symlink installation went from 71.7 to
    43.3 ms (−40%; −39% against the excellence end). That is within
    performance.md's roughly 50 ms budget.
  - The warm first editable prompt went from 95.4 to 63.1 ms (−34%), and
    fresh startup is 7–11% faster.
  - Git prompt rendering is 29–34% faster, and Return in a PTY 31–34% in a
    repository.
  - The Git review chooser is 23–26% faster. Git-source Search is 46%
    faster than `main`, mostly from the excellence run, plus 6–7% here.
  - Browse, local Search, Ctrl-R history and fresh direct-layout startup
    moved within noise. Two slowdowns of under 1 ms were not investigated:
    rendering outside Git (+0.16 ms) and warm Browse (+0.85 ms).
- **Owner decisions.** These are quoted in [Owner decisions](#owner-decisions):
  - all five phases, and `zcompile` for the startup budget (kept after an
    explanation, then recompiled automatically at startup);
  - one shared Git-read entry, a larger Xcode settings bound, and the Git
    shim resolved once and only for Git that `codesign` verifies as Apple's
    `com.apple.git`;
  - retired-name shims removed, nine low-value units dropped, virtual-disk
    USB sources refused, the bare `g` catalog bounded and history size
    unchanged;
  - private-peer compiling dropped for privacy;
  - general agent rules moved to a global file, plus the recorded-approval
    rule.
- **Dropped.** P2-09, P2-10, P3-08, P3-14, P3-15, P4-15, P5-09, P5-10 and
  P5-11 were dropped by the owner on 2026-10-14, and P6-02 on 2026-10-18 for
  privacy. Not chosen at the start: deferring `compinit`, native `autoload`,
  splitting peers and caching Git filter names.

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

Later rounds, asked in chat and quoted as answered:

- **Git shim check (P5-12), 2026-10-17.** The planned ancestor-ownership
  check rejected Xcode in `/Applications` (root:admin 0775), so it would have
  saved nothing on the owner's Mac.
  - The owner asked: "can we be sure we only use official apple git? your
    change implies we could get injected a fake git".
  - The owner then answered: "1 and unit test so we are sure this works as
    expected and it blocks fake gits".
  - So Compozsh calls the real Git directly only when `/usr/bin/codesign`
    verifies it as `anchor apple and identifier "com.apple.git"`, and its
    file identity is rechecked on every use.
- **zcompile kept, 2026-10-18.** After an explanation of what `zcompile`
  writes and where, the owner answered "well let's keep it".
- **Automatic recompilation, 2026-10-18.** This reverses "installer only".
  The owner asked that "the system can detect changes and compile without
  user intervention so we are always best speed". Measurements and a web
  check followed: `zrecompile` and the common "zcompare" snippet decide by
  mtime only, and ran stale code in two local tests. The owner then chose:
  - "At startup, changed files only (Recommended)";
  - "Compozsh files + your own peers (Recommended)";
  - for `.zcompdump`, "Yes, with the strict check (Recommended)".
- **Private peers dropped, 2026-10-18.** P6-02's design recorded alias names
  and values (user data) in the manifest. Its measured gain was 0.6–2 ms.
  The owner answered "1": drop it. Private peers stay text, and no user data
  is written.
- **Project rules and approvals, 2026-10-18.**
  - Asked whether to apply the proposed `CLAUDE.md` and `.claude/` updates,
    the owner answered "yes, let's start making a global files for all agents
    and projects, this way proojects just have projecr specific rules".
    General rules now live in the owner's `~/.claude/CLAUDE.md`. This
    repository receives only the project-specific updates.
  - Asked how agents should treat chat approvals, the owner answered
    "Record, then agents may act (Recommended)". Approvals quoted and dated in
    this section are acceptance, and implementing agents may commit against
    them. Patch-only mode is no longer required.
- **Final-review owner questions and next step, 2026-10-18.** These were
  asked in chat after the final review (see
  [Owner questions from the final review](#owner-questions-from-the-final-review)):
  - **Which Zsh compiles at startup.** Answer: "Apple's /bin/zsh, run from /
    (Recommended)". The startup and dump compiles run `/bin/zsh -f` with `/`
    as the working directory. A different running Zsh version stays on text.
    The boundary is disclosed in SECURITY.md.
  - **Is `.zshrc` still a minimal bootstrap.** Answer: "Accept it
    (Recommended)". The layout contract says so.
  - **Next step.** Answer: "Fix follow-ups, then PR (Recommended)". A short
    batch handles the two answers above and the safety and privacy
    follow-ups, then a pull request is opened for review. The follow-ups
    are:
    - `.gitignore` for `support/compiled/`;
    - a bounded installer ctime wait;
    - the USB progress cleanup pattern;
    - the inherited Xcode capture bound;
    - the `g --worktree` `$REPLY` leak;
    - behavior on a Mac without developer tools;
    - the disclosure-accuracy items from the final review.

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

### Phase 3: engine API and scoping

All 12 units landed on their first attempt, at 12–27 minutes each, about 4
hours in all. Every unit touched the shared UI engine, so every unit ran the
full suite, all with zero failures (P3-01: 1,051 passed).

Views now:
- reach the engine only through `_zle_ui_view`, so their state ends when they
  close;
- pass bookmarks by name;
- use one choice adapter and one shared ranked collector;
- reposition documents through an explicit API;
- supply their own options label, guide facts and plan-heading roles.

The inline fallback frame now fits below the living prompt.

| Commit | Unit | Subject |
| --- | --- | --- |
| `6673c31` | P3-01 (B-09) | Replace the result-index array with an explicit zero-based flag |
| `12c88bf` | P3-02 (B-06) | Route Browse and Recents through _zle_ui_view so view state ends |
| `d190046` | P3-03 (B-06) | Route Search through _zle_ui_view and scope g and help view state |
| `0351913` | P3-04 (B-06) | Route USB browse and Git review through _zle_ui_view |
| `7f2e63e` | P3-05 (B-11) | Promote the generic ranked collector into shared UI support |
| `f091f14` | P3-06 (B-10) | Pass picker bookmarks by name, with focus as field seven |
| `26dce74` | P3-07 (B-10) | Move remaining loop callers to named bookmarks; drop positional form |
| `a24b8bc` | P3-09 (B-10) | Add one choice adapter for value, detail and label lists |
| `00500ab` | P3-10 (B-12) | Give documents an invalidate and position API instead of raw maps |
| `c156e96` | P3-11 (B-07, B-08) | Let callers supply the options label and drop the dead atlas kind |
| `15d4e36` | P3-12 (B-07) | Move Files guide facts and plan heading roles out of the engine |
| `4ed0cfe` | P3-13 (B-05) | Fit the inline fallback frame below the living prompt |

### Phase 4: peer decomposition and duplication (parallel lanes)

The owner approved running phase 4 in four parallel git worktree lanes. Each
lane owned disjoint peer files:

- USB: `.zsh.usb`;
- Xcode: `.zsh.xcode`;
- Git and editor: Git review, navigation and the editor;
- Prompt: `.zsh.prompt`, plus the Git operation and filter support.

Inside a lane, units ran one at a time under the same rules as the other
phases, and lane agents did not edit this record. All 27 commit units landed
on their first attempt, at 3–28 minutes each. Every lane ended with a green
full suite. The lanes took about 2.5 hours, against about 7.5 hours
sequentially.

The orchestrator then integrated the work:

1. It fast-forwarded the USB lane and cherry-picked the other three onto this
   branch. There were no conflicts; SECURITY.md merged automatically.
2. It ran the full suite on the combined tree: 1,099 passed, 0 failed.
3. It applied the three owner-approved patches, P4-30, P4-31 and P4-29,
   re-checking red against the prior HEAD and green, plus focused filters,
   for each.
4. It ran a final full suite: 1,104 passed, 0 failed.

| Commit | Unit | Lane | Subject |
| --- | --- | --- | --- |
| `bebc361` | P4-01 (A1-04, A1-05) | usb | Branch USB recovery on an error kind and delete dead USB helpers |
| `e246694` | P4-02 (A1-06) | usb | Drop USB load globals that the flash and format tasks scope locally |
| `08c320e` | P4-03 (A1-06, SEC-C-02) | usb | Make the remaining USB capture state invocation-local |
| `976eb4b` | P4-04 (A1-10) | usb | Extract pure USB write-geometry and failure-mapping records |
| `146e52a` | P4-05 (A1-10) | usb | Extract pure USB review rows, progress parsing and media labels |
| `a8debc5` | P4-06 (A1-09) | usb | Share the USB execution prologue and epilogue |
| `8cc78c9` | P4-07 (A1-09) | usb | Run USB workers through one progress loop |
| `aedefea` | P4-08 (A1-11) | xcode | Add an Xcode optional plist helper and one export vendor table |
| `1399ad7` | P4-09 (A1-11) | xcode | Key the Xcode destination cache by scheme records |
| `d576e74` | P4-10 (A1-11) | xcode | Build Xcode test results from one pure model |
| `13ce4e6` | P4-11 (U65, XCODE-05, A1-11) | xcode | Format each retained Xcode log line once per collection |
| `615a8c5` | P4-12 (A1-08) | xcode | Stop Xcode child processes through one grace-period helper |
| `4c6d3f4` | P4-13 (A1-07) | xcode | Share the Xcode run Copy-and-reopen screen loop |
| `6b1470a` | P4-14 (A1-07) | xcode | Own Xcode Run session state in one function for both modes |
| `2ce7ee8` | P4-17 (A2-11, D-08) | git | Rebind Git review selection through one refresh helper |
| `49cdd2b` | P4-18 (A2-10) | git | Prefix Git review session names that engine hooks read |
| `40dfbb4` | P4-19 (A2-10) | git | Pass navigation context explicitly and open review through one entry |
| `eb93a5a` | P4-20 (A2-12) | git | Match directory picker candidates through the shared collector |
| `37f5924` | P4-21 (A2-13) | git | Capture the alias option at widget entry; disclose in-widget hooks |
| `2f724b2` | P4-22 (A2-09) | prompt | Lay out the prompt context row only at capture and resize |
| `a63c783` | P4-23 (D-09) | prompt | Pin Interaction kind precedence with a neighbor matrix |
| `272869b` | P4-24 (D-09) | prompt | Split the Interaction model into lex, heads, rows and enrich steps |
| `c773e5b` | P4-25 (D-09) | prompt | Classify Interaction kinds through ordered matcher functions |
| `dae4cce` | P4-26 (C-06, U62, PROMPT-04) | prompt | Characterize prompt project detection across project folders |
| `2cba80c` | P4-27 (C-06, U62, A2-decomposition) | prompt | Classify project languages, tools and frameworks from marker tables |
| `a1727c4` | P4-28 (C-06, U62, PROMPT-04) | prompt | Read each conventional project folder once during detection |
| `d2eb3cf` | P4-16 (A2-06) | prompt | Check Git operation markers from one table with two policies |
| `7bd92c0` | P4-30 (U11 follow-up, excellence open owner question 2), patch | usb | Refuse USB image sources that sit on a virtual disk |
| `70203b0` | P4-31 (Git audit note, excellence open owner question 4), patch | git | Bound the bare g branch catalog with an honest partial notice |
| `450393e` | P4-29 (A2-05, D-05), patch | prompt | Route prompt, filter and discard Git reads through the shared entry |

### Phase 5: performance and compiled startup

P5-01 to P5-08 landed on their first attempt, at 13–26 minutes each. P5-09
to P5-11 were dropped by owner decision.

Two units were owner-approved patches. The orchestrator re-verified each one
(red at the prior HEAD, then green) and committed it after a full suite:

- P5-13 (zcompile) had 1,119 passed, 0 failed.
- P5-12 (the git shim) came back for an owner decision on its signature
  check, was rerun with the owner's answer, then had 1,123 passed, 0 failed.

Measured results:

| Change | Result |
| --- | --- |
| `zcompile` | Warm process startup 72 → 49 ms (−32%), first editable prompt 94 → 74 ms (−21%) |
| Git shim | Prompt render 23.2 → 16.4 ms in a clean repository (−29%), 24.8 → 18.1 ms dirty (−27%), 40.6 → 33.7 ms large (−17%) |

| Commit | Unit | Subject |
| --- | --- | --- |
| `5979387` | P5-01 (C-02, C-04, C-05, C-11) | Record the performance baseline and let startup runs use installs |
| `9229ac2` | P5-02 (C-04, U68) | Clean up the manual async transport with zsh/files builtins |
| `a740b01` | P5-03 (C-05, U69) | Validate help-description identity in parts each prompt |
| `a498176` | P5-04 (C-07, U64) | Look up highlighter command categories with keyed existence tests |
| `5d6f6c5` | P5-05 (A2-07) | Key the prompt Git-directory memo by repository, not folder |
| `86a2917` | P5-06 (C-08) | Parse prompt Git status in a pure helper with array counting |
| `2bb16a1` | P5-07 (A1-12) | Capture diskutil plists in memory instead of a temporary file |
| `c2642ca` | P5-08 (C-11) | Delete startup ZLE hooks only when they are registered |
| `2ae4be2` | P5-13 (C-02a, C-09), patch | Precompile shipped peers with fresh-only zcompile; skip .zwc files |
| `4a037b3` | P5-12 (A2-08a), patch | Run the Apple-signed Git behind /usr/bin/git directly for Compozsh reads |

### Phase 6: automatic recompilation

These units came from the owner's fourth-round request. Each was a patch that
the orchestrator re-verified and committed after a full suite.

- **P6-01:** shipped peers that are new or changed are recompiled at startup,
  under a lock, with atomic writes, a 300 ms box, a 512 KiB bound and silent
  text fallback.
  - Full suite: 1,128 passed, 0 failed.
  - Warm startup was unchanged.
  - A one-time cost falls on the first shell after an edit: about 104 ms for
    the largest peer, about 280 ms for all 88.
- **P6-02** (private peers) was dropped by the owner (see Owner decisions).
- **P6-03:** a compiled completion dump is loaded from the private mirror
  only while the dump is provably unchanged. Its manifest holds no user data.
  - Full suite: 1,130 passed, 0 failed.
  - Warm process startup 50.0 → 45.5 ms (−9%), first editable prompt
    73.7 → 69.1 ms (−6%).
  - The compiled dump is used only when no alias is defined before the editor
    peer runs `compinit`, so an initializer alias means the plain dump.

| Commit | Unit | Subject |
| --- | --- | --- |
| `bf10351` | P6-01, patch | Recompile changed shipped peers at startup into the private mirror |
| `ee38661` | P6-03, patch | Load a strictly checked compiled completion dump from the private mirror |

### Project rules

These three commits follow the owner's answers under "Project rules and
approvals, 2026-10-18" (see [Owner decisions](#owner-decisions)). Under the
recorded-approval rule, the implementing agents committed them directly:

- `e2c957a` records the approval rule in CLAUDE.md and the contract
  reviewer: an owner answer quoted and dated in the run's record is
  acceptance. It extends security.md's persistent-storage rule from caches
  to every file Compozsh generates, and refreshes the suite note to about
  1,130 cases in about 5 minutes. General workflow rules went to the owner's
  global `~/.claude/CLAUDE.md`, outside the repository.
- `27e6cbc` (P7-01) is a static view-state test. It checks that peers outside
  `support/ui` reach the picker engine only through `_zle_ui_view`, or
  through a `_zle_picker_run` that opens a screen session. It names five
  helpers as exceptions, with reasons.
- `0e31ea3` (P7-02) fixes a review finding. `support/compile.zsh` recorded
  the compiling shell's alias tables, which `/etc/zshenv` can fill, in the
  mirror's manifests and baked them into the wordcode. It now resets the
  alias tables to Zsh's built-in `run-help` and `which-command` and records
  only that public context, so a shell with any other alias loads text.

| Commit | Unit | Subject |
| --- | --- | --- |
| `e2c957a` | rules | Record approval rules and the generated-file data rule in contracts |
| `27e6cbc` | P7-01 | Guard that peers reach the picker engine only through _zle_ui_view |
| `0e31ea3` | P7-02 | Record only Zsh's built-in aliases in the compiled mirror manifests |

### Final review

Six read-only passes (security and contract, one each for slices A, B and C)
ran at `0e31ea3` over `excellence/2026-10-12..HEAD`:

- **A:** the bootstrap, the installer, compiled startup and the prompt.
- **B:** Git workspaces, navigation and shared UI.
- **C:** USB, Xcode, tests, investigations and agent tooling.

They raised 48 findings, 11 of them blocking. Triage grouped the blocking
ones into nine tasks, and each landed on its first attempt in 2–27 minutes.
F01 and F07 ran the full suite (1,133 passed, 0 failed, both times). The
others ran focused filters: F02, F04, F08 and F09 changed documentation
only, F03 and F05 tests only, and F06 one collector branch in
`.zsh.navigation`.

| Commit | Task (findings) | Subject |
| --- | --- | --- |
| `cfb03f5` | F01 (SEC-A-01) | Drop the compiled copy of a removed or renamed peer at the next shell |
| `7372eff` | F02 (SEC-A-01, SEC-A-02, CON-A-01) | Disclose which peers compile and stock compdump as the mirror's other writer |
| `082977e` | F03 (SEC-B-01) | Pin that inherited zero-based and cancel-bookmark flags are discarded |
| `bc2375d` | F04 (SEC-C-01, CON-C-01) | Describe where the USB progress files' cleanup lives |
| `40d6735` | F05 (CON-B-01, SEC-B-02) | Widen the view-state snapshots to the choice, branch and review globals |
| `399fd9d` | F06 (CON-B-04) | Keep the partial label when no branch matches in a partial catalog |
| `c9a6416` | F07 (CON-C-02) | Return 1, not 130, when Escape cancels Xcode's Run product choice |
| `fe442d8` | F08 (CON-B-02) | Name the shared choice collector in the worktree contract |
| `3056c45` | F09 (CON-B-03) | Record the engine-held Git guide paragraphs as a known exception |
### Follow-ups after the final review

The owner chose "Fix follow-ups, then PR" on 2026-10-18 (Owner decisions),
then changed the delivery: "we dont need the pr, we can push to main, but do
not push wait for me to push, just make the commit on main and i can check it
tomorrow". So no pull request was opened. The branch was fast-forwarded into
the local `main`, and nothing was pushed.

The batch ran in five steps:

1. **FU-01 to FU-08** ran in two parallel worktree lanes and landed on the
   first attempt. The integrated suite passed 1,141 with 0 failures.
2. **A security and contract review** of those eight commits found three
   blocking items, which FU-09 fixed:
   - a README claim that only Git could bring up the developer-tools offer;
   - a README mock label;
   - a compile-child count in the security contract.
3. **FU-10** fixed three issues FU-09's agent reported: a non-macOS
   regression of the Git gate, `.zsh_sessions/`, and Apple's `java` stub.
4. **A second review** of FU-09 and FU-10 found one blocking item, which
   FU-11 fixed: a `PATH` link to `/usr/bin/git` skipped the developer-tools
   gate.
5. **Instead of a third review round,** the orchestrator reviewed FU-11's
   diff itself, so the review cycle would converge.

Every unit was test-first, with red evidence quoted in its commit or report.
The final full suite passed 1,145 with 0 failures.

| Commit | Unit (findings) | Subject |
| --- | --- | --- |
| `e95015b` | FU-01 (SEC-A-03, CON-A-03) | Compile with Apple's /bin/zsh from / and skip mismatched shells |
| `9c8e3f1` | FU-02 (SEC-A-08, CON-A-06, SEC-A-06, CON-A-04) | Ignore the compiled mirror in Git and bound the install clock wait |
| `7199e9c` | FU-03 (SEC-A-05) | Recheck each compiled peer's identity just before sourcing it |
| `dedae56` | FU-04 (SEC-A-07, SEC-A-09, CON-A-05, SEC-B-04, CON-B-07, CON-A-07, CON-A-09, CON-A-10) | Correct the compiled-mirror, shared Git entry and README disclosures |
| `c51fdbc` | FU-05 (SEC-C-02) | Narrow the USB progress cleanup to its two disclosed templates |
| `c551963` | FU-06 (SEC-C-03) | Pass the Xcode settings capture bound explicitly, not by scope |
| `997bf54` | FU-07 (SEC-B-03) | Keep g --worktree from leaving values in the caller's REPLY |
| `01f8b36` | FU-08 (no-developer-tools item) | Skip passive Git reads when Apple's developer tools are missing |
| `74d92d3` | FU-09 (SEC-FU-01, SEC-FU-05, CON-FU-03) | Leave Apple's runtime launchers unrun without developer tools |
| `383a40a` | FU-09 (SEC-FU-04, CON-FU-07) | Ignore clone-root shell state and name a missing /bin/zsh |
| `7996a54` | FU-09 (SEC-FU-02, SEC-FU-03, CON-FU-01, CON-FU-02, CON-FU-05, CON-FU-06, CON-FU-08) | Correct compile, mirror and branch-view disclosures |
| `0a58bd5` | FU-10 (non-Darwin regression from 01f8b36) | Gate passive Git on developer tools only on macOS |
| `9e009c2` | FU-10 (`.zsh_sessions/`) | Ignore Terminal's session state at the clone root |
| `40b37a4` | FU-10 (`/usr/bin/java` stub) | Leave Apple's java stub unrun without a JDK |
| `28166cf` | FU-11 (SEC-L-02, CON-L-02, SEC-L-07) | Ignore history residue; qualify the mirror's state claim |
| `7c52460` | FU-11 (SEC-L-01, CON-L-01, SEC-L-04, SEC-L-05, SEC-L-06, CON-L-03, CON-L-04, CON-L-05) | Gate a PATH link to /usr/bin/git and a JAVA_HOME of the stub |

Measured cost of the follow-ups: `839dce0` (before them) against the final
tree, en_US.UTF-8, alternating.

- **Startup**, symlink install, 11 runs: warm process 44.9 → 41.4 ms, first
  editable prompt 63.3 → 61.5 ms, fresh process 186.7 → 185.9 ms. There is
  no cost, and the gain is near noise.
- **Prompt render**, 11 shells × 40 renders: outside 7.31 → 7.29 ms, clean
  15.41 → 15.65 ms, dirty 16.95 → 17.09 ms, large 31.3 → 32.4 ms. All ranges
  overlap, so these are within noise. The new per-prompt developer-tools
  check is file tests only: about 34 µs per call, as the contract reviewer
  measured.

Not changed on purpose: the missing-`/bin/zsh` installer message (SEC-L-03)
has no test. `/bin/zsh` cannot be removed or shadowed in a test, and a seam
that lets the installer read an overridable Zsh path would weaken the "never
a `PATH` zsh" boundary for a message-only gain.

The record itself has seven commits: `d859737`, `6e0c652`, `8632534`,
`2a04e48`, `1ab553f`, `f507cb6` and the commit that completes it.

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
- The Files keyboard guide (Ctrl-K in Browse, Search and Recents) now states
  the walk and match limits from `ZSH_FILE_SEARCH_MAX_VISITED` and
  `ZSH_FILE_SEARCH_MAX_CANDIDATES` instead of always saying 20,000 and 2,000.
  Action plans emphasize exactly the headings their tool names, so
  `FROM REMOTE-TRACKING REF` and `COMMIT` (creating a branch from `g`) and
  `SOURCE` and `DESTINATIONS` (`xcode --export-skills`) are now headings,
  while a draft, path or other captured value that equals a heading word or
  starts with "Safety" stays ordinary text. Review colours and the "use Git
  for the remaining text" truncation note now belong to Git review documents
  only (P3-12, B-07).
- `external-device --flash` and `--format` keep every capture, helper result
  and picker selection or filter bookmark local to the task. Nothing from a
  USB session (disk names, sizes, checksums, filter text) is left in the
  shell afterwards (P4-02, P4-03).
- `external-device --flash` refuses media stored on a virtual disk (a mounted
  disk image, sparsebundle or RAID set) before any drive is listed. macOS
  does not report which drives hold such a disk, so they could not be kept
  out of the target list. Copy the media to a regular drive and choose the
  copy. Physical drives, including Apple silicon internal storage and Fusion
  drives, work as before (P4-30).
- Xcode test results list each source location of a failed test on its own
  line. Before, a stray `$'\n  '` appeared between them (P4-10).
- Xcode Logs filtering is faster: each retained log line is formatted once
  per update instead of twice (P4-11).
- `xcode --export-skills --help` lists one aligned row per supported agent
  and skill folder, generated from the same table the export uses (P4-08).
- `g --discard-all` also refuses when only a merge autostash or bisect-start
  marker remains, or when an operation marker has an unexpected file type.
  Worktree move and removal use the same check (P4-16).
- `g` reads at most 5,000 local branches (512 KiB of names), current branch
  first. In larger repositories its header says "partial", filtering covers
  the captured branches only, and remote-tracking suggestions are off. Use
  `g switch <name>` or `g branch --list <pattern>` for other branches.
  Branch details are built only for the selected row (P4-31).
- After a Browse or Recents Change directory, the Interaction lens no longer
  previews alias expansion while `ALIASES` is off. `PROMPT_PROJECT_CONTEXT_FUNCTIONS`
  hooks are documented as also running after such a change (P4-21).
- Typing at the living prompt no longer rebuilds the compact context row on
  every keystroke (P4-22).
- Project detection reads each conventional source folder once instead of
  once per rule. The indicative median drops from about 3 ms to 1.4 ms per
  prompt for a small project, and from about 16 ms to 4.6 ms for a flat
  `src/` of 800 files (P4-27, P4-28).
- The prompt's Git status, Git filter discovery and every Git command of
  `g --discard-all` go through the shared local-only Git entry. They now also
  disable commit-signature verification and the untracked cache. If shared
  support is missing, `g --discard-all` refuses before running Git (P4-29).
- `external-device` no longer writes diskutil property lists (the external
  disk list, disk or volume info and the filesystem catalog) to
  `compozsh-usb.*` files in `TMPDIR`. It reads them into memory with a 1 MiB
  limit, which saves about 4 ms per capture, and `external-device --format`
  no longer requires `mktemp` or `rm` (P5-07).
- Smaller speedups:
  - the first prompt's manual-description capture starts about 4 ms sooner
    (P5-02);
  - checking help descriptions saves about 0.7 ms per prompt (P5-03);
  - syntax highlighting redraws 1.4 to 2 times faster (P5-04);
  - the first render in a new folder of a known repository is about 7.6 ms
    faster (P5-05);
  - the prompt's Git status in a repository with 3,000 changes is about
    5 ms faster (P5-06).
- Startup is faster. Both installation modes compile the shipped peers with
  Zsh's `zcompile` into a marked, owner-only `~/.zsh.addons/support/compiled`
  mirror, and the installation plan shows a `Compiled:` line.
  - A shell uses a peer's compiled code only while that file is unchanged
    since compilation (same file, size, mtime and ctime), the Zsh version
    matches and nothing that ran first has added aliases or changed parse
    options. Otherwise it loads the text as before.
  - The installer refuses an unmarked `support/compiled` before any change,
    and `--clean` archives the mirror.
  - `.zwc` files are never sourced as peers. Before, a private peer compiled
    with `zcompile` printed errors at startup (P5-13).
- Changed shipped peers are recompiled automatically. After `git pull`, an
  edit of a shipped peer or a Zsh update, the next shell recompiles just the
  changed peers and uses them at once, so the installer need not run again.
  - That shell is slower once, by up to about 300 ms after a full update
    (the time box), and a large update can take a few shells.
  - Peers over 512 KiB stay text, and a missing mirror is recreated.
  - Compiled code is used only from an owner-only mirror that carries its
    `.managed-by-compozsh` marker (P6-01).
- After `compinit` has run once, later shells load a compiled copy of
  `~/.zcompdump` from the mirror, only while the dump is provably unchanged.
  `compinit` still rewrites the dump when `fpath` changes, and no
  `.zcompdump.zwc` appears beside it (P6-03).
- The mirror's manifests record only Zsh's built-in aliases (`run-help` and
  `which-command`). An alias that `/etc/zshenv`, the initializer or an
  earlier private peer defines is never written to disk, and such a shell
  loads peers and the dump as text (P7-02).
- When `git` on your `PATH` is Apple's `/usr/bin/git`, Compozsh's own Git
  reads run the Apple Git behind it directly. That covers the prompt's
  status and the review, branch, Search, worktree and discard reads.
  - Once per shell, `/usr/bin/codesign` must verify the file as Apple's
    `com.apple.git`, and its file identity is rechecked before every run.
  - A typical repository prompt draws about 7 ms faster, and a new shell's
    first Git prompt pays about 9 ms once.
  - If any check fails, Compozsh keeps using `/usr/bin/git`.
    `compozsh --refresh` forgets the choice.
  - Git commands you run yourself are unchanged, and so is a different Git
    that comes earlier on `PATH` (P5-12).
- Removing or renaming a shipped peer (after `git pull`, for example) now
  removes its compiled copy too: the next shell that can compile deletes the
  old mirror entry, its `.zwc` wordcode and its manifest record, even when no
  other peer changed. Before, they stayed in `~/.zsh.addons/support/compiled`
  until the next installation (F01, SEC-A-01).
- Pressing Escape in Xcode's **Run product** choice (Build & Run with several
  runnable products) now makes `xcode` exit with status 1, the cancel status
  of every other workspace, instead of 130, which is reserved for Ctrl-C.
  Nothing is launched either way, and Ctrl-C still exits 130 (F07, CON-C-02).
- Shells started in any folder compile with Apple's `/bin/zsh`, run from `/`.
  A `zsh` found on `PATH` is never used. A shell of another Zsh version loads
  text, and after the first refused attempt it starts no compile child (FU-01).
- Git ignores the compiled mirror, `.zsh_history*`, `.zsh_sessions/`,
  `.zcompdump*` and `.zsh-backups/` when your configuration base is a clone
  (FU-02, FU-09, FU-10, FU-11).
- On a Mac without Apple's developer tools, the prompt's Git context, its
  runtime probes of Apple's `/usr/bin` launchers (`python3`, `swift`, `clang`,
  `cc`, `c++`), the `java` stub without a JDK, and Search's default source no
  longer bring up macOS's install offer. Those runtimes show `not-installed`.
  Git and runtime commands you run yourself still can bring up the offer, and
  so can a version-manager shim elsewhere on `PATH`. Outside macOS,
  `/usr/bin/git` works as before (FU-08 to FU-11).
- `g --worktree` no longer leaves a worktree path or name in your `$REPLY`
  (FU-07).

## Tests

Full-suite runs at the end of each phase and at the orchestrator's
re-verifications. Every unit ran the full suite or the focused filters its
plan required, and logs are kept with the run's local artifacts (not
distributed).

| Point | Commit | Passed | Failed | Time |
| --- | --- | ---: | ---: | ---: |
| Start (excellence run final) | `1a8b868` | 1,022 | 0 | 227.8 s |
| P1-01 | `d6c2070` | 1,023 | 0 | 220.7 s |
| Phase 1 commit units (P1-13) | `a638476` | 1,041 | 0 | 260.9 s |
| Phase 1 patches (orchestrator) | `e38fb40` | 1,044 | 1 | — |
| Phase 2 first-run gate | `e026df7` | 1,041 | 5 | 9,104.5 s |
| End of phase 2 (P2-14) | `4964137` | 1,049 | 0 | 240.2 s |
| End of phase 3 (P3-13) | `4ed0cfe` | 1,062 | 0 | 248.3 s |
| Phase 4 lanes integrated | `d2eb3cf` | 1,099 | 0 | 254.2 s |
| End of phase 4 (patches) | `450393e` | 1,104 | 0 | 258.8 s |
| Phase 5 commit units (P5-08) | `c2642ca` | 1,113 | 0 | 267.5 s |
| P5-13 (orchestrator) | `2ae4be2` | 1,119 | 0 | 283.0 s |
| P5-12 (orchestrator) | `4a037b3` | 1,123 | 0 | 280.0 s |
| P6-01 (orchestrator) | `bf10351` | 1,128 | 0 | 306.2 s |
| P6-03 (orchestrator) | `ee38661` | 1,130 | 0 | 310.1 s |
| P7-02 | `0e31ea3` | 1,132 | 0 | 320.6 s |
| F01 | `cfb03f5` | 1,133 | 0 | 320.6 s |
| F07 | `c9a6416` | 1,133 | 0 | 321.8 s |
| **Final** | `3056c45` | **1,133** | **0** | **322.5 s** |

Failures and flakes:

- **Laptop sleep in phase 1.** The run over the three patch commits had one
  failure. *PTY expectation fails at its deadline while output never stops*
  measured 248 s against its 2–3 s window, because the Mac slept mid-run on
  battery power. Run alone, it passed 3 times out of 3.
- **Laptop sleep in phase 2's first run.** Its one gate took 9,104 s instead
  of about 225 s, and five PTY deadline or timing cases failed:
  - *Action matching missing capability uses public native and refusal
    fallbacks*;
  - *file actions navigate directories, require explicit file actions, and
    restore a paged search*;
  - *Git Working changes survives worker exit during native auto-refresh*;
  - *Git review native g preserves screens bookmarks resize abort switching
    unborn review and peer fallback*;
  - *tool descriptions react through native ZLE without submitting aliases
    or privileged modes*.

  Each passed when rerun alone at `e026df7`, and so did the group reruns.
  Nine other units of that run reached their time boxes and two were
  skipped, so none of their changes was kept (see
  [Run notes](#run-notes)).
- **Xcode Logger.** The cleanup timing test did not flake in any recorded
  full run of the pass, so nothing was rerun for it.
- **Caught inside units.** Some failures were caught and fixed before their
  unit committed:
  - P1-13: a Find test stub;
  - P3-04: a load-time unset approach (71 failures), reverted, then one
    support-subset rule;
  - P3-12: six tests that built Git review documents or plans by hand;
  - P4-03: the support-subset harness rule;
  - P4-30: a test pinning the old `--flash` help phrase;
  - F01: the convergence case caught a `{ … }` block that did not parse
    under an initializer with `IGNORE_BRACES`.

  None of these reached a commit.
- **Stray stderr, no failing case.** Two lines appear in full logs:
  - `tests/support.zsh:6: read-only variable: TEST_ZSH_BIN` predates the
    pass (see the [excellence run](excellence-2026-10-12.md#tests)).
  - `_git_review_view:1: command not found: _zle_ui_view` has appeared since
    P3-04 (`0351913`). It comes from *Git syntax response is released when
    the review session ends*, whose fixture loads Git review without the
    shared UI.

The net change is 111 cases (1,022 → 1,133). Behavior fixes added or
tightened tests, and the phase 2 migrations kept each migrated assertion's
meaning or made it stricter. The last full run printed no `FAIL` line, and
`zsh tests/verify.zsh` gave syntax ok, whitespace ok and re-source ok.

## Performance results

### Final comparison: main, the excellence run's end and the final tree

The final tree (`3056c45`) was measured against `main` at `36cdcda` and
against the excellence run's end at `ad67877`. Both baselines were scratch
copies checked blob for blob against those commits. The same scripts ran on
the same Mac (Apple M3 Max on AC power, Darwin 27.0.0, `/bin/zsh` 5.9, Git
2.54.0 (Apple Git-157), `LC_ALL=en_US.UTF-8`), with `TMPDIR` in a disposable
directory, load 1.5–4.3 and runs sequential.

Each benchmark call compares one pair of trees and alternates them run by
run. Across pairs, the first pair alternated per metric. Each pair has its
own *Final* column. Milliseconds; median (min–max).

*Verdict* is *faster* or *slower* when the ranges do not overlap and the
change exceeds that metric's A/A difference. It is *noise* when the ranges
overlap or the change is within A/A, and *marginal* when the two pairs
disagree.

Startup used `isolated-startup.zsh` with 15 runs per tree. *Symlink* means
each tree installed by its own installer, unmeasured, into the run's
`ZDOTDIR`. *Direct* sources the tree's `.zshrc`.

| Metric | Mode | Runs | Main `36cdcda` | Final | Δ | Excellence end `ad67877` | Final | Δ | Verdict |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Startup process, symlink | fresh | 15 | 209.81 (208.16–211.67) | 188.19 (185.37–194.65) | −10.3% | 209.81 (207.55–211.90) | 189.26 (187.90–195.78) | −9.8% | faster |
| Startup process, symlink | warm | 15 | 71.71 (68.95–76.22) | 43.34 (41.08–67.97) | −39.6% | 71.04 (68.50–73.93) | 43.45 (40.95–63.02) | −38.8% | faster |
| Startup source, symlink | fresh | 15 | 205.21 (203.65–207.24) | 183.48 (180.52–189.46) | −10.6% | 205.16 (203.11–207.17) | 184.24 (183.27–190.64) | −10.2% | faster |
| Startup source, symlink | warm | 15 | 65.47 (63.05–69.16) | 37.10 (35.34–61.34) | −43.3% | 64.32 (62.41–66.90) | 37.18 (35.28–57.02) | −42.2% | faster |
| Startup editable, symlink | fresh | 15 | 231.37 (229.13–233.95) | 213.44 (211.03–223.67) | −7.7% | 231.51 (228.03–237.84) | 215.18 (212.85–221.89) | −7.1% | faster |
| Startup editable, symlink | warm | 15 | 95.40 (93.34–96.05) | 63.12 (62.66–65.49) | −33.8% | 94.32 (92.81–95.40) | 63.59 (61.68–67.77) | −32.6% | faster |
| Startup tty-source, symlink | warm | 15 | 62.26 (61.13–62.67) | 33.81 (33.40–36.81) | −45.7% | 60.76 (60.35–61.27) | 33.95 (33.57–37.47) | −44.1% | faster |
| Startup process, direct | fresh | 15 | 214.23 (211.74–220.79) | 212.77 (209.71–215.73) | −0.7% | 213.12 (208.74–215.51) | 212.05 (208.59–213.70) | −0.5% | noise |
| Startup process, direct | warm | 15 | 71.49 (69.67–75.01) | 42.22 (40.48–298.25) | −40.9% | 69.70 (67.26–73.17) | 43.07 (41.05–295.46) | −38.2% | faster |
| Startup editable, direct | warm | 15 | 95.51 (93.65–97.52) | 63.18 (61.48–64.16) | −33.8% | 94.68 (92.47–98.25) | 64.06 (61.97–67.94) | −32.3% | faster |
| Prompt render, outside | render | 11×40 | 7.08 (7.05–7.15) | 7.23 (7.21–7.30) | +2.2% | 7.17 (7.14–7.20) | 7.23 (7.21–7.30) | +0.9% | slower, small |
| Prompt render, clean | render | 11×40 | 23.80 (23.58–23.97) | 15.71 (15.55–15.85) | −34.0% | 23.79 (23.64–24.23) | 15.64 (15.51–16.28) | −34.2% | faster |
| Prompt render, dirty | render | 11×40 | 25.88 (25.65–26.03) | 17.10 (16.97–17.32) | −33.9% | 25.90 (25.76–26.38) | 17.08 (16.95–17.24) | −34.1% | faster |
| Prompt render, large | render | 11×40 | 45.56 (44.88–47.09) | 32.50 (31.29–32.84) | −28.7% | 46.53 (45.19–47.08) | 32.28 (31.34–32.97) | −30.6% | faster |
| Prompt Return, outside | pty | 11×15 | 9.80 (9.77–9.95) | 9.20 (9.14–9.66) | −6.1% | 9.74 (9.67–10.77) | 8.94 (8.91–9.44) | −8.2% | faster |
| Prompt Return, clean | pty | 11×15 | 28.48 (27.90–28.76) | 18.75 (18.50–18.93) | −34.2% | 26.74 (26.61–32.72) | 17.64 (17.41–21.46) | −34.0% | faster |
| Prompt Return, dirty | pty | 11×15 | 30.91 (30.49–31.60) | 20.32 (20.06–20.58) | −34.3% | 28.91 (28.69–34.30) | 19.25 (18.93–27.79) | −33.4% | faster |
| Prompt Return, large | pty | 11×15 | 51.00 (49.87–56.74) | 35.36 (35.12–35.63) | −30.7% | 48.27 (47.76–53.01) | 33.68 (33.18–36.98) | −30.2% | faster |
| Frame browse | fresh | 11 | 82.25 (81.77–83.01) | 83.40 (80.53–84.53) | +1.4% | 83.11 (82.16–84.44) | 83.37 (82.23–83.90) | +0.3% | noise |
| Frame browse | warm | 11×5 | 84.63 (84.11–84.98) | 85.48 (85.06–86.95) | +1.0% | 84.30 (83.95–85.21) | 85.00 (84.59–85.87) | +0.8% | marginal |
| Frame search | fresh | 11 | 518.82 (511.89–526.96) | 509.45 (496.62–511.89) | −1.8% | 512.58 (508.82–513.27) | 510.18 (506.25–514.88) | −0.5% | noise |
| Frame search | warm | 11×5 | 498.85 (496.55–502.56) | 491.78 (488.91–507.06) | −1.4% | 492.97 (488.70–495.89) | 491.28 (488.04–496.64) | −0.3% | noise |
| Frame search-git | fresh | 11 | 210.86 (195.19–215.37) | 114.08 (107.45–118.96) | −45.9% | 122.89 (109.97–125.51) | 115.65 (112.76–118.93) | −5.9% | faster than main; noise against excellence |
| Frame search-git | warm | 11×5 | 209.92 (205.67–212.99) | 112.21 (109.01–113.51) | −46.5% | 120.95 (117.95–123.68) | 112.19 (106.68–114.43) | −7.2% | faster |
| Frame history | fresh | 11 | 7.47 (7.16–7.79) | 7.56 (7.36–7.69) | +1.2% | 7.82 (7.62–8.02) | 7.67 (7.43–8.01) | −1.9% | noise |
| Frame history | warm | 11×5 | 15.32 (14.45–16.40) | 15.44 (13.77–16.42) | +0.8% | 14.74 (11.82–15.73) | 15.21 (14.84–16.73) | +3.2% | noise |
| Frame review | fresh | 11 | 64.58 (60.14–75.68) | 48.96 (48.30–56.84) | −24.2% | 65.34 (61.80–71.16) | 48.40 (46.99–49.42) | −25.9% | faster |
| Frame review | warm | 11×5 | 59.31 (58.54–72.40) | 45.83 (44.92–53.28) | −22.7% | 59.21 (58.86–59.86) | 45.65 (45.08–47.36) | −22.9% | faster |

*Frame browse* is Tab after `cd ~/Downloads/`. *Frame search* is a local
walk of about 10,500 entries, and *search-git* the Git source in the review
repository. *Frame history* is Ctrl-R over 20,000 commands, and *frame
review* the `g --review` chooser in a dirty 2,400-file repository.

Where the A/A was missing or marginal, same-session A/As (final against
final) were run: render outside −0.015 ms, Browse +0.11/+0.19 ms, Search
+2.21/−0.84 ms. The other A/As are the recorded ones in
[P5-01](#p5-01-performance-baseline-at-the-end-of-phase-4-c-02-c-04-c-05-c-11)
and the unit sections.

- **Startup.** Compiled loading (P5-13, P6-01, P6-03) accounts for the
  startup rows.
  - Warm process startup, 43.3 ms, is within performance.md's roughly 50 ms
    budget.
  - The warm first editable prompt, which adds the first prompt's capture,
    is 63 ms.
  - Fresh symlink startup gains about 21 ms, partly because the installer's
    unmeasured precompile runs before the first shell.
  - A fresh direct `ZDOTDIR` has no mirror, so its peers load as text, and
    that row moved within noise.
- **Startup maxima.** The final tree's maxima in the warm startup rows come
  from run 1 paying a one-time compile that priming leaves for later. In the
  symlink layout the ctime barrier defers the dump compile to the first
  shell that starts in a later second: a probe gave 67.8 ms, then 33–35 ms.
  In the direct layout the priming PTY's manual cache creates
  `ZDOTDIR/.zsh.addons`, which makes the mirror eligible, so run 1 compiles
  every peer: a probe gave 275 ms, then 46 ms. Medians are unaffected.
- **Prompt.** The Git rows come mostly from the Git shim (P5-12), and the
  large repository also from the pure status parser (P5-06). The prompt and
  frame scripts load the final tree's peers as text, so those rows measure
  runtime, not compiled loading.
- **Git-source Search.** Most of the gain against `main` came in the
  excellence run (about 211 → 123 ms). Within this pass, warm is a further
  8.8 ms with ranges that do not overlap, consistent with the Git shim.
- **Small slowdowns, not investigated.** Rendering outside Git is
  +0.06–0.16 ms. That is beyond its 0.02 ms A/A but close to the 0.12 ms
  drift the final tree showed between sessions, and Return outside Git is
  0.6 ms faster. Warm Browse is +0.70–0.85 ms (about 1%).
- **Earlier observations not reproduced.** P5-01 noted outside-Git
  rendering at 7.67 ms against 4.11 ms at `36cdcda`, and Ctrl-R fresh at
  11.1 ms. In this harness `main` itself renders outside Git in 7.08 ms, so
  that comparison mixed harnesses, and every tree's Ctrl-R fresh is about
  7.5 ms.
- **Idle gaps.** Back-to-back warm non-TTY startups of the final tree reach
  33–35 ms. The benchmark's roughly 43 ms reflects shells that start after
  idle gaps, about 14 ms slower in probes. This environment effect applies
  to every tree.

Reproduce with the [P5-01 commands](#p5-01-performance-baseline-at-the-end-of-phase-4-c-02-c-04-c-05-c-11),
using `git archive` copies of `36cdcda` and `ad67877` as `<before>` and the
tree at `3056c45` as `<after>`. Use the `symlink` and `direct` layouts, and
for `workspace-first-frame.zsh` the scenarios `browse,history`, `search` and
`search-git,review` with 11 runs and 5 warm samples.

The sections below are the per-unit measurements, recorded as each unit
landed. The phase 5 and 6 summaries are also in [Commits](#commits).

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

### P4-27 and P4-28: project detection from marker tables, one read per folder (C-06, U62, PROMPT-04)

These numbers are indicative only, because the other phase 4 lanes were
loading the machine. The before tree was a `git archive` of each unit's
parent and the after tree the lane's working tree, with `TMPDIR` in the
scratch area and `en_US.UTF-8`.

P4-27 alone reached parity. Per `_prompt_project_context` call (300 calls
after 20 warm-up calls, runtime probe stubbed), a small Node project went
from 3.27 to 3.21 ms and a Swift/Xcode project from 2.79 to 2.84 ms. Its
first table-walking version cost 8.6 ms. Two changes restored parity:
filtering rows by the evidence present, in one match, and deriving the 282
capture tokens once per shell from the constant table.

P4-28 added `investigations/benchmarks/prompt-project-detect.zsh`. It
reports the median of per-shell medians (5 shells × 30 samples) of project
detection (*context*) and of the complete prompt update outside Git
(*update*). Its A/A (2 shells × 10 samples) differed by about 3–6%.
Milliseconds:

| Fixture | Context before | Context after | Update before | Update after |
| --- | ---: | ---: | ---: | ---: |
| small | 3.05 | 1.39 | 3.33 | 1.66 |
| C (`src/` and `include/`, 40 files each) | 3.86 | 2.86 | 4.16 | 3.19 |
| 800 `.tsx` files in `src/` | 16.33 | 4.60 | 16.60 | 4.92 |
| 5,000 `.json` files in `src/` | 91.92 | 23.23 | 91.99 | 23.53 |
| 800 `.png` files in `public/` | 4.36 | 3.21 | 4.68 | 3.54 |
| no project (walks to `/`) | 5.82 | 5.84 | | |

Decision: kept.
- **Regression check.** `prompt-git-render.zsh render` (5 shells × 20
  samples) gave outside 7.94 → 8.10 ms (within noise), clean 29.02 → 28.02,
  dirty 31.26 → 29.88 and large 52.72 → 50.85.
- **Against the hypothesis.** The small project reached 1.4 ms rather than
  about 1 ms, and 5,000 `.json` files 23 ms rather than about 6 ms. The
  rest is the resolver's own bounded scan of `src/` and its root-marker
  checks at each level, which are outside these units. The same reason
  leaves the no-project fixture unchanged.
- **Not rerun.** P4-28 asked phase 5 to rerun this benchmark on a quiet
  machine. That did not happen, and the final comparison does not cover
  project detection.

### P5-01: performance baseline at the end of phase 4 (C-02, C-04, C-05, C-11)

Baseline for the phase 5 units, at `1ab553f` (the end of phase 4). Every
comparison is A/A: the baseline is `git archive 1ab553f`, the candidate the
working tree at the same commit (only this unit's benchmark and record edits
differ, and no benchmark measures them). Apple M3 Max on AC power, macOS
27.0.1, `/bin/zsh` 5.9, Git 2.54.0 (Apple Git-157); benchmark shells under
`LC_ALL=en_US.UTF-8` with `TMPDIR` in the scratch area; load averages
1.95–3.31 (an ordinary desktop session); runs sequential. Milliseconds:
*median (range)* is the baseline tree's; *A/A* is the candidate median minus
the baseline median, with its share of the baseline median.

`isolated-startup.zsh` now takes an optional layout: `direct` (the default and
the earlier behavior) sources `<root>/.zshrc`; `copy` and `symlink` first run
that tree's `install.zsh --<layout> --yes` into the run's disposable
`ZDOTDIR`, unmeasured, and then source the installed `.zshrc`, so P5-13 can
measure installer-generated files as an installation loads them. The PTY
shell now reads a fixed wrapper `.zshrc` from its own directory, which points
`ZDOTDIR` at the run's directory before sourcing, so the installed `.zshrc` is
never overwritten. A check run confirmed that peers load from
`ZDOTDIR/.zsh.addons/compozsh/` (copy) and from the tree (symlink).

| Startup metric | Mode | Runs | direct | A/A | copy | A/A | symlink | A/A |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| process | fresh | 15 | 221.88 (218.15–230.20) | −0.37 (0.2%) | 226.54 (223.77–238.42) | +3.85 (1.7%) | 219.49 (216.75–231.88) | −0.11 (0.0%) |
| process | warm | 15 | 71.33 (68.95–74.60) | +0.06 (0.1%) | 74.08 (71.33–75.50) | +0.05 (0.1%) | 72.58 (70.61–76.47) | −1.43 (2.0%) |
| source | fresh | 15 | 214.85 (211.51–223.04) | −0.15 (0.1%) | 220.86 (218.29–232.84) | +3.56 (1.6%) | 214.02 (211.83–226.40) | +0.27 (0.1%) |
| source | warm | 15 | 64.80 (62.84–67.01) | −0.55 (0.8%) | 66.98 (64.77–68.09) | +0.15 (0.2%) | 65.63 (63.89–68.97) | −1.44 (2.2%) |
| editable | fresh | 15 | 242.44 (237.99–250.98) | +0.59 (0.2%) | 256.36 (253.80–269.01) | +9.23 (3.6%) | 242.55 (238.82–253.54) | +0.33 (0.1%) |
| editable | warm | 15 | 99.62 (96.75–104.07) | −0.68 (0.7%) | 101.26 (99.90–104.76) | +1.76 (1.7%) | 100.21 (98.80–106.59) | −1.12 (1.1%) |
| tty-source | fresh | 15 | 205.94 (201.04–212.94) | +1.02 (0.5%) | 219.66 (217.70–232.93) | +7.74 (3.5%) | 206.85 (203.34–216.12) | −0.68 (0.3%) |
| tty-source | warm | 15 | 62.95 (61.35–64.53) | −0.94 (1.5%) | 64.52 (63.32–67.33) | +0.75 (1.2%) | 63.48 (62.52–67.48) | −1.25 (2.0%) |

Every A/A pair's ranges overlap in all three layouts, the self-check the unit
plan asked for.

| Metric | Mode | Runs | Median (range) | A/A |
| --- | --- | ---: | ---: | ---: |
| Prompt render, outside | render | 11×40 | 7.67 (7.57–7.88) | −0.01 (0.1%) |
| Prompt render, clean | render | 11×40 | 25.17 (24.48–26.39) | −0.39 (1.6%) |
| Prompt render, dirty | render | 11×40 | 26.84 (26.14–28.74) | +0.38 (1.4%) |
| Prompt render, large | render | 11×40 | 47.60 (46.80–49.78) | +0.63 (1.3%) |
| Prompt Return, outside | pty | 11×15 | 10.24 (10.07–10.46) | +0.07 (0.7%) |
| Prompt Return, clean | pty | 11×15 | 29.09 (27.72–29.79) | −0.11 (0.4%) |
| Prompt Return, dirty | pty | 11×15 | 30.99 (29.05–37.46) | −0.16 (0.5%) |
| Prompt Return, large | pty | 11×15 | 50.77 (49.85–50.96) | −0.06 (0.1%) |
| Help, editable shipped | warm | 9 | 101.70 (100.37–103.60) | +1.18 (1.2%) |
| Help, editable bypassed | warm | 9 | 87.53 (86.62–89.62) | +1.46 (1.7%) |
| Help, first capture shipped | warm | 9 | 14.25 (13.93–14.94) | +0.30 (2.1%) |
| Help, first capture with 16 extra | warm | 9 | 46.40 (45.28–47.73) | +1.86 (4.0%) |
| Help, capture per extra companion | warm | 9 | 2.01 (1.90–2.10) | +0.06 (2.8%) |
| Frame browse | fresh | 9 | 84.16 (79.01–85.16) | +0.51 (0.6%) |
| Frame browse | warm | 9×5 | 84.02 (82.97–84.65) | −0.40 (0.5%) |
| Frame history | fresh | 9 | 11.11 (6.80–12.36) | +0.33 (3.0%) |
| Frame history | warm | 9×5 | 11.76 (11.10–12.76) | +0.30 (2.5%) |
| Frame review | fresh | 9 | 80.73 (66.91–83.44) | −1.28 (1.6%) |
| Frame review | warm | 9×5 | 74.01 (69.10–78.40) | −0.23 (0.3%) |

`help-first-prompt.zsh` measures one tree, so its A/A is two invocations, the
`git archive` copy first and then the working tree.

Observations, none investigated in this unit:

- **Startup is where the excellence run left it.** Warm direct sourcing is
  64.8 ms and fork to exit 71.3 ms (excellence `36cdcda`: 64.7 and 71.8), and
  the warm first editable prompt 99.6 ms (98.6), against the contract's
  roughly 50 ms. This is the baseline for P5-13's compiled startup.
- **The copy layout is slower than the symlink layout.** Fresh, it sources
  about 6 ms slower and reaches the editable prompt about 14 ms later, with
  the widest A/A deltas here (3.5–3.6%); warm, it sources about 1.4 ms slower.
- **Outside a repository, prompt work grew.** The outside render is 7.67 ms
  against 4.11 ms at `36cdcda` and lens C's 4.5 ms, and Return outside is
  10.24 ms against 7.18 ms; inside repositories the medians are within about
  1 ms of the excellence run. The disposable home is the outside fixture, so
  project detection or another per-prompt read outside Git is the likely
  place to look.
- **First frames.** Ctrl-R fresh is 11.1 ms (excellence 7.4 ms; its range
  still reaches 6.8 ms) and the `g --review` chooser fresh 80.7 ms (65.3 ms),
  both noisy metrics; Browse is 84.2 ms (79.2 ms).

Reproduction, from the repository root with `TMPDIR` set to a disposable
directory, `<before>` the `git archive` copy and `<after>` the working tree:

```zsh
/bin/zsh -df investigations/benchmarks/isolated-startup.zsh <before> <after> 15 en_US.UTF-8 direct
/bin/zsh -df investigations/benchmarks/isolated-startup.zsh <before> <after> 15 en_US.UTF-8 copy
/bin/zsh -df investigations/benchmarks/isolated-startup.zsh <before> <after> 15 en_US.UTF-8 symlink
/bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <before> <after> render 11 40
/bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <before> <after> pty 11 15
/bin/zsh -df investigations/benchmarks/help-first-prompt.zsh <before> 9
/bin/zsh -df investigations/benchmarks/help-first-prompt.zsh <after> 9
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <before> <after> browse,history,review 9 5
```

### P5-02: manual async transport cleanup without forks (C-04, U68, HELP-04)

`_manual_async_start` unlinked its FIFO and its directory with
`command /bin/rm` and `command /bin/rmdir`, two fork-and-exec helpers in the
first TTY `precmd`. It now loads only the prefixed `zf_rm` and `zf_rmdir`
builtins of `zsh/files` (`zmodload -F`) and calls them through `builtin`, so
the user's `rm` and `rmdir` stay external, and a later `zmodload zsh/files` of
the user's own still enables every builtin. `mktemp` and `mkfifo` stay
external, and worker-side commands are unchanged. The plan placed the load at
source time beside `zsh/system` and `zsh/stat`; it sits instead beside the
`zsh/zpty`, `zsh/zselect` and `zsh/datetime` checks in `_manual_async_start`,
so source time is unchanged and a failed load falls back to synchronous
capture like those, before any temporary name exists. The FIFO and directory
are still mode 0600 and 0700 and both unlinked once opened, so SECURITY.md's
transport row holds unchanged. A new case, `manual async cancellation removes
its transport without shadowing rm or rmdir`, passed before and after the
change: command lookup for `rm`, `rmdir`, `mkdir`, `mv` and `ln` is unchanged,
and no `compozsh-manual-async.*` name survives a running start and its
cancellation, a failure after the FIFO exists, or an interrupt while the owner
starts. It fails for a full `zmodload zsh/files` and for a dropped `rmdir`.

Before tree `git archive 5979387`, after tree the working tree; environment as
in P5-01, load averages 2.8–6.2. The focused rows come from a scratch script:
each run starts one `env -i … LC_ALL=en_US.UTF-8 /bin/zsh -dfi` shell per
tree, alternating which goes first, with `TMPDIR` in the scratch area. Each
shell sources that tree's `.zsh.manual`, stubs `_manual_prompt_capture` to fail
at once, and times with `EPOCHREALTIME` its first `_manual_async_start`
(module loads included, as at the first prompt) and nine more start/cancel
cycles. Its A/A (baseline against baseline, 21 runs) differed by −0.07 ms
(first call) and −0.04 ms (later calls). Milliseconds, *median (range)*:

| Metric | Mode | Runs | Before | After | Delta |
| --- | --- | ---: | ---: | ---: | ---: |
| `_manual_async_start`, first call | focused | 21 | 13.97 (11.72–16.65) | 9.25 (8.41–10.78) | −4.72 (−33.8%) |
| `_manual_async_start`, median of 9 later calls | focused | 21 | 9.73 (8.29–11.51) | 5.89 (4.92–6.97) | −3.84 (−39.5%) |
| editable | warm | 15 | 98.77 (92.34–113.37) | 94.13 (89.40–105.23) | −4.64 (−4.7%) |
| editable | warm, second pass | 15 | 96.93 (94.90–111.57) | 92.88 (90.67–115.61) | −4.05 (−4.2%) |
| editable | fresh | 15 | 236.60 (229.02–271.88) | 231.41 (221.90–266.17) | −5.18 (−2.2%) |
| editable | fresh, second pass | 15 | 233.42 (231.82–267.17) | 232.80 (227.18–264.71) | −0.62 (−0.3%) |

Decision: kept. The focused ranges do not overlap, and the A/A noise is under
0.1 ms. The warm first editable prompt gains 4.0–4.6 ms in both passes, at the
excellence run's 3× warm A/A threshold of 4.47 ms (P5-01's warm editable A/A
was −0.68 ms). Fresh editable startup is dominated by the completion dump and
too noisy to resolve the gain. Process, source and tty-source never start
capture and moved within noise (warm: −2.07, −1.42 and −0.99 ms).

```zsh
TMPDIR=<scratch>/tmp /bin/zsh -df investigations/benchmarks/isolated-startup.zsh <before> <after> 15 en_US.UTF-8 direct
```

### P5-03: help-description identity validated in parts (C-05, U69, HELP-03)

Every TTY prompt's `_compozsh_prompt_capture`, and every redraw that describes
a Compozsh command, rebuilt one joined signature per command (source path,
command definition, companion definition), measured its multibyte length and
compared it with the stored copy. `.zsh.help` now keeps the identity in parts:
`_COMPOZSH_PROMPT_SIGNATURES` holds the source path, beside
`_COMPOZSH_PROMPT_COMMANDS`, `_COMPOZSH_PROMPT_HELPERS` and
`_COMPOZSH_PROMPT_SIZES`. `_compozsh_prompt_signature` is a status-only
validator that compares both `functions_source` entries and both `functions`
entries with the stored parts. An unchanged pair is charged its stored size,
expanded and matched against `<1-262144>` before any arithmetic uses it; any
other pair goes through the unchanged source guard and 65,536-character
definition bounds, and its size (source, both definitions and two separators,
the old signature's length) counts against the 64-pair / 262,144-character
budget. `_compozsh_prompt_reset` clears the three new maps, and one helper,
`_compozsh_prompt_forget`, releases a command's parts, summary and options.
The same data stays in memory, so SECURITY.md's prompt-description row (64
pairs, 262,144 characters of identity) holds unchanged. Option (b) of the
excellence record's owner question 5, lazy validation from edit time, was not
done; it remains an owner proposal.

`tool descriptions bound definition size and identity budget`, added first,
passed before and after the change: five pairs of about 60,000 characters and
one over-bound command, captured twice, describe exactly the first four with
one help read each; a redefined command or companion from the same file is
stale until the next capture, which rereads only that pair; removing one
command releases its identity and lets the fifth pair in. It fails when an
unchanged pair is not charged against the budget or when the validator skips
the companion definition. The refresh case now also covers the three new maps
(it failed with the old `_compozsh_prompt_reset`).

Before tree `git archive 9229ac2`, after tree a copy of the working tree;
environment as in P5-01, load averages 3.4–3.9. The focused rows come from a
scratch script: each run starts one `env -i … LC_ALL=en_US.UTF-8 /bin/zsh
-dfi` shell per tree that sources the tree's `.zshrc`, alternating which goes
first, captures twice to warm up, then times 200 more captures and 200
`_compozsh_prompt_description g --review main HEAD` calls (the redraw path)
with `EPOCHREALTIME`. Its A/A (baseline against baseline, 12 runs, run later
under more load, at a 1.62 ms capture) differed by −0.01 ms (capture) and
−0.00 ms (description). The *A/A* column of the PTY rows is a separate
baseline-against-baseline run of the same benchmark. Milliseconds, *median
(range)*:

| Metric | Mode | Runs | Before | After | Delta | A/A |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `_compozsh_prompt_capture`, warm | focused | 12×200 | 1.484 (1.478–1.501) | 0.777 (0.774–0.791) | −0.71 (−47.7%) | −0.01 (0.5%) |
| `_compozsh_prompt_description g --review main HEAD` | focused | 12×200 | 0.414 (0.413–0.416) | 0.204 (0.203–0.207) | −0.21 (−50.8%) | −0.00 (0.2%) |
| Prompt Return, outside | pty | 11×15 | 9.97 (9.70–10.32) | 9.23 (8.95–9.39) | −0.75 (−7.5%) | +0.27 (2.7%) |
| Prompt Return, clean | pty | 11×15 | 25.91 (24.72–26.89) | 25.38 (23.91–26.19) | −0.54 (−2.1%) | −1.66 (6.2%) |
| Prompt Return, dirty | pty | 11×15 | 27.89 (26.39–29.05) | 26.99 (25.38–27.95) | −0.90 (−3.2%) | +0.03 (0.1%) |
| Prompt Return, large | pty | 11×15 | 47.46 (45.29–48.53) | 46.84 (44.95–47.66) | −0.62 (−1.3%) | +0.04 (0.1%) |

Decision: kept. The focused ranges do not overlap and halve both paths, as
the plan expected (capture about 1.54 → 0.78 ms). End to end, Return outside a
repository gains 0.75 ms with disjoint ranges, beyond its 0.27 ms A/A; inside
repositories every fixture gains 0.5–0.9 ms, consistent with the focused
saving, but Git work makes those ranges overlap, and the clean fixture's A/A
(1.66 ms) is wider than its gain. The table predates the stored-size check
that the `security:` arithmetic scan required; a 6-run focused recheck of the
final tree, under more load, gave capture 1.589 → 0.843 ms (−46.9%) and
description 0.446 → 0.217 ms, the same halving.

```zsh
TMPDIR=<scratch>/tmp /bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <before> <after> pty 11 15
TMPDIR=<scratch>/tmp /bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <before> <before> pty 11 15
```

### P5-04: highlighter command categories by keyed lookup (C-07, U64, PROMPT-07)

`_zle_command_category` found each command word's kind with `(Ie)` reverse
subscripts, which scan every key of `aliases`, `galiases`, `functions`,
`builtins`, `commands` and `saliases`; with completion loaded `functions` has
about 1,750 entries and `commands` about 1,270 on a system `PATH`. It now tests
existence by key (`${+functions[$name]}` and so on); `reswords` is an ordinary
array and keeps its `(Ie)` search. The named-directory check in
`_zle_path_category` and the global-alias check for arguments in
`_zle_syntax_highlight` changed the same way. A miss in `commands` fills the
command hash once under `HASH_LIST_ALL`, exactly as the scan did, so the
highlighter reads nothing new.

`syntax highlighting command, global-alias and named-directory lookups
classify every kind and odd name identically`, added first, passed before and
after the change: an alias, a global alias, a keyword, functions, a builtin, a
command, a suffix alias, and the names `@`, `x]y`, `f]`, `*`, the empty
string, `(i)a` and `(Ie)ls`, a named directory and a missing one, and a global
alias argument's region. `syntax highlighting looks up shell tables by key
instead of scanning them`, a source check, failed on the eight scans before
the change.

Before tree `git archive a740b01`, after tree the working tree; environment
as in P5-01, load averages 2.3–4.3. The rows come from a scratch script: each
run starts one `env -i … LC_ALL=en_US.UTF-8 /bin/zsh -dfi` shell per tree,
alternating which goes first, with `TMPDIR` in the scratch area and a warmed
disposable home per tree. Each shell sources the tree's `.zshrc` (every peer
and `compinit`), then for each draft sets `BUFFER`, calls
`_zle_syntax_highlight` 20 times unmeasured and times 400 calls with
`EPOCHREALTIME`. The drafts are `git status`, `ls`, the pipeline
`ls -la | grep -v total | sort -k5 -n > sizes.txt` and an in-bound worst case
of 60 unknown command words (`nosuch; ` repeated: 480 characters, 120 tokens).
The A/A ran first, the baseline against the working tree before the
production change. Microseconds per redraw, *median (range)*:

| Draft | Runs | Before | After | Delta | A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| `git status` | 11×400 | 292.37 (289.68–300.15) | 211.32 (208.74–214.48) | −81.05 (−27.7%) | −3.37 (1.1%) |
| `ls` | 11×400 | 244.19 (240.12–248.57) | 120.95 (119.38–123.92) | −123.23 (−50.5%) | +2.35 (1.0%) |
| pipeline | 11×400 | 1275.47 (1267.72–1306.01) | 938.80 (929.96–945.38) | −336.67 (−26.4%) | −2.46 (0.2%) |
| 60 unknown command words | 11×400 | 14686.55 (14564.35–14756.39) | 8205.83 (8116.74–8307.91) | −6480.72 (−44.1%) | −1.71 (0.0%) |

Decision: kept. Every range is disjoint and each gain is at least 24 times its
A/A difference, matching the plan's estimate of about 0.1 ms per command word.
Startup and prompt rendering do not call the highlighter, so they were not
remeasured.

### P5-05: prompt Git-directory memo keyed by repository (A2-07)

`_prompt_git` keyed `_PROMPT_GIT_DIR_CACHE` by `PWD`, the nearest `.git`
marker, `GIT_DIR` and `GIT_WORK_TREE`, so each new folder of a known
repository ran `git rev-parse --absolute-git-dir` again, and the memo listed
every repository folder visited. With neither variable set, the nearest
marker alone is now the key. `PWD` stays in the key, as before, when either
variable is set (a relative value resolves against `PWD`), and when a folder
between `PWD` and the marker's parent holds a `HEAD`: Git discovers a Git
directory that `PWD` is inside before the marker, and every Git directory has
a `HEAD`. A marker-only key, tried first, served the enclosing repository's
metadata in an absorbed submodule's `.git/modules/<name>` and in a nested Git
directory with `core.worktree`, where Git's own status succeeds. The check
costs one `stat` per folder level below the repository root on each prompt in
a repository. `compozsh --refresh` still clears the
memo, which now holds one entry per repository, plus one per folder visited
inside a Git directory. SECURITY.md's prompt-facts row (Git state and paths in
shell memory) holds unchanged.

`living prompt resolves the Git directory once per repository across its
folders` failed first: six folders of one repository ran 6 resolutions and
kept 6 entries; it expects 1 and 1. It also checks that the submodule-metadata
and nested-metadata folders keep their own operation labels (`revert`,
`cherry-pick`) after the enclosing repository (`merge`) is memoized, which the
marker-only key failed. The relative `GIT_DIR` and nested-repository cases of
`living prompt Git operation follows a repository initialized inside a
previously visited folder` pass unchanged.

Before tree `git archive a498176`, after tree the working tree; environment as
in P5-01, load averages 1.5–2.7. The focused rows come from a scratch script:
each run starts one `env -i … LC_ALL=en_US.UTF-8 /bin/zsh -dfi` shell per tree,
alternating which goes first, with `TMPDIR` in the scratch area. Each shell
sources the tree's `.zshrc`, renders three times at the root of a 200-file
repository with an upstream, then times the first render (every `precmd` hook
plus `PROMPT`/`RPROMPT` expansion) in each of its 50 subfolders, reporting the
median. Its A/A (baseline against baseline, 11 runs) ran first. Milliseconds,
*median (range)*:

| Metric | Mode | Runs | Before | After | Delta | A/A |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| First render in a new subfolder of a known repository | focused | 11×50 | 31.14 (30.92–31.35) | 23.48 (23.21–23.64) | −7.65 (−24.6%) | −0.03 (0.1%) |
| Prompt render, outside | fresh | 11 | 12.65 (12.41–14.08) | 12.64 (12.45–12.91) | −0.01 (−0.1%) | |
| Prompt render, clean | fresh | 11 | 33.66 (33.07–78.70) | 33.31 (32.62–33.68) | −0.34 (−1.0%) | |
| Prompt render, dirty | fresh | 11 | 34.81 (34.36–35.08) | 34.40 (34.26–34.84) | −0.41 (−1.2%) | |
| Prompt render, large | fresh | 11 | 54.63 (53.65–57.72) | 54.14 (52.65–55.16) | −0.49 (−0.9%) | |

Decision: kept. The focused ranges are disjoint, and the gain matches one Git
process (the plan's 7.4 ms) against an A/A of 0.03 ms. The fresh rows, the
first render of a new shell at a repository root, must miss the memo in both
trees; they moved within noise, so the `HEAD` checks cost nothing measurable.

```zsh
TMPDIR=<scratch>/tmp /bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <before> <after> fresh 11
```

### P5-06: prompt Git status parsed by a pure helper (C-08, A2-decomposition)

`_prompt_git` matched every line of `git status --porcelain=v2 --branch
--show-stash` against a `case` statement, so a repository with 3,000 changed
or untracked files ran 3,000 shell iterations per prompt. The new private pure
`_prompt_git_parse` in `.zsh.prompt` takes the status text as its argument and
returns the branch head, commit, upstream and the ahead, behind, stash,
staged, modified, untracked and conflicted counts through `reply`, which
`_prompt_git` now declares local. It splits the text in memory once, matches
only the `#` header lines one by one (the ahead, behind and stash text checks
are unchanged), and counts file records by kind with array filters
(`${(M)lines:#u *}`), taking staged and modified as the ordinary and renamed
records whose third or fourth character is not `.`. The counts are plain
assignments: inside arithmetic or double quotes a nested filter's result is
joined and its length measured instead. The filter read, its bounds and the
status capture are unchanged; caching the filter names stays rejected (C-08
(b)).

`in-memory parsing: prompt Git porcelain parsing keeps counts for clean,
dirty, conflicted, stashed and detached states`, added first, passed before
and after the change. It stubs the Git entries to return twelve fixed status
texts and pins the rendered summary, color role, branch, upstream and
attention values, including widest valid counts, oversized, missing and
hostile `$(...)` ahead, behind and stash fields (never evaluated) and a branch
name with prompt escapes. A scratch differential check also compared the old
loop with the helper on 6,000 random mixes of header, record, malformed,
duplicate, short and invalid-byte lines under `C` and `en_US.UTF-8`, with no
difference.

Before tree `git archive 5d6f6c5`, after tree a copy of the working tree;
environment as in P5-01, load averages 2.7–3.3. The focused rows come from a
scratch script: each run starts one `env -i … LC_ALL=en_US.UTF-8 /bin/zsh
-dfi` shell per tree, alternating which goes first, with `TMPDIR` in the
scratch area. Each shell sources the tree's `.zsh.prompt`, stubs the Git
entries to print a status text saved from the benchmark's own fixtures, and
times 40 `_prompt_git` calls after three warm-up calls (the stub's command
substitution included). Its A/A (baseline against baseline, 11 runs, large
fixture) differed by +0.11 ms. The *A/A* column of the render rows is a
separate baseline-against-baseline run of the same benchmark. Milliseconds,
*median (range)*:

| Metric | Mode | Runs | Before | After | Delta | A/A |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| `_prompt_git`, large status (3,004 lines) | focused | 11×40 | 16.68 (16.28–16.83) | 11.59 (11.28–11.94) | −5.09 (−30.5%) | +0.11 (0.7%) |
| `_prompt_git`, dirty status (85 lines) | focused | 11×40 | 2.06 (2.01–2.12) | 2.00 (1.90–2.06) | −0.06 (−3.1%) | |
| Prompt render, outside | render | 11×40 | 7.70 (7.62–7.87) | 7.77 (7.61–8.02) | +0.07 (0.8%) | +0.08 (1.0%) |
| Prompt render, clean | render | 11×40 | 26.09 (25.13–27.63) | 26.36 (25.09–27.67) | +0.27 (1.0%) | +0.46 (1.8%) |
| Prompt render, dirty | render | 11×40 | 28.40 (27.15–29.73) | 28.03 (26.84–29.82) | −0.37 (−1.3%) | +0.04 (0.1%) |
| Prompt render, large | render | 11×40 | 48.62 (47.11–50.69) | 43.29 (42.17–45.54) | −5.33 (−11.0%) | −0.51 (1.0%) |

Decision: kept. In the large fixture the focused and end-to-end ranges are
disjoint, and the render gain is about ten times its A/A difference. It
exceeds the review's estimate (8.6 → 6.8 ms for the parse, about 1.8 ms),
because only the few header lines still pass through shell code. The other
fixtures moved within their A/A noise, as expected for small status texts.

```zsh
TMPDIR=<scratch>/tmp /bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <before> <after> render 11 40
TMPDIR=<scratch>/tmp /bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <before> <before> render 11 40
```

### P5-07: diskutil plists captured in memory (A1-12)

`_usb_diskutil_plist_capture` wrote every `diskutil … -plist` answer (the
external disk list, each disk or volume info and the filesystem catalog) to a
`compozsh-usb.*` file in `TMPDIR`, measured it with `stat` and removed it with
`rm`: three process launches per call, and disk identity data on disk while
diskutil ran. It now reads the answer through the shared
`_compozsh_capture_bounded` with room for the reader's NUL and status, counts
the payload in bytes under `LC_ALL=C`, and keeps the empty-output, over-limit
and failed-command results. A failed command still returns its own status, and
trailing newlines are still dropped. The `compozsh-usb.*` row leaves
SECURITY.md, and `--format` no longer requires `mktemp` and `rm`. diskutil now
runs under the reader's `LC_ALL=C`. A scratch check of this Mac's
`diskutil listFilesystems -plist` gave byte-identical output with no locale
and with `C`, `de_DE`, `fr_FR` and `ja_JP` UTF-8 locales.

`USB diskutil capture limits bytes, keeps the command status and drops
trailing newlines`, added first, passed before and after the change. It pins
the byte limit at and over the bound, including a two-byte character, a failed
command's status, trailing and newline-only output. After the change it also
refuses a missing shared reader by name; that case failed before. `USB
temporary disk metadata, ISO listing, mount and progress files are owner-only
and removed` now expects no name while the diskutil stand-in runs, and failed
before on `compozsh-usb:600`. Diskutil stand-ins in the USB tests now run in
the reader's subshell. None of them recorded state in shell variables, and the
tests that capture through them now source the reader.

Before tree `git archive 86a2917`, after tree the working tree; environment as
in P5-01. A scratch script runs one `env -i … LC_ALL=en_US.UTF-8 /bin/zsh -df`
child per tree, alternating which goes first, with `HOME` and `TMPDIR` in the
scratch area. Each child sources the tree's bounded reader and `.zsh.usb`,
stubs `_usb_diskutil_run` to print a 6,665-byte `diskutil info`-shaped plist
(*builtin*) or to run `/bin/cat` on it (*cat*, one process like diskutil),
makes three warm-up calls and times 40, then checks the plist and an empty
`TMPDIR`. Load averages were 31–42 during the final runs (a system media
analysis job); an earlier run of the same tree at 2.4–2.6 gave builtin
5.60 → 1.71 ms and cat 7.50 → 3.10 ms. Milliseconds per call, *median
(range)*:

| Metric | Runs | Before | After | Delta | A/A |
| --- | ---: | ---: | ---: | ---: | ---: |
| `_usb_diskutil_plist_capture`, builtin stub | 11×40 | 5.67 (5.53–5.75) | 1.65 (1.62–1.73) | −4.02 (−70.9%) | −0.02 (0.4%) |
| `_usb_diskutil_plist_capture`, cat stub | 11×40 | 7.36 (7.12–7.89) | 2.97 (2.92–3.02) | −4.39 (−59.6%) | |

Decision: kept. Ranges are disjoint and the gain is about 180 times the A/A
difference, matching the review's 5.4 → 1.5 ms. Step 2 capture and refresh
pay it once for the list and once per disk. Larger output trades the other
way: the in-memory reader costs more per byte than a file. Spot runs (two
per size, 3–10 calls each, builtin stub without a trailing newline) gave 64 KiB
6.2–6.6 → 4.4–4.5 ms, 256 KiB 8.2–8.5 → 15.0 ms, 1 MiB − 64 bytes 15.8–16.4
→ 55.1 ms and 1 MiB + 1 byte (refused) 8.1–9.5 → 49.3–50.3 ms. The
crossover is near 100 KiB, far above any diskutil answer seen here (7.6 KB
for the filesystem catalog). Over-limit output is no longer written to disk
in full: the reader stops after 1 MiB + 5 bytes.

### P5-08: startup hook deletes only for registered hooks (C-11)

`.zsh.editor` and `.zsh.highlighting` delete and re-add their ZLE hooks so
that any peer order and any re-source end with one canonical hook order. Every
delete ran at every startup as a hook-function call with a `/dev/null`
redirection, although most of the named widgets are not registered yet: in
lexical order the editor's six deletes and highlighting's delete of
`_zle_syntax_highlight` change nothing. A hook's deletes now run only when
`zstyle -m` finds one of the peer's widget names in that hook's style. At
lexical startup that skips the editor's six; highlighting still runs its three,
one of them a no-op. Deleting an absent widget changes nothing, so the stored
lists, numbering included, stay the same. The redirections are gone because a
delete with valid arguments never prints. `peer ZLE hooks re-register after caller hooks with
exact entries in either order` was added first and passed before and after
the change, as did the complete-state convergence case. It pins the exact
numbered entries after a caller hook and a re-source in both peer orders.

The plan's skip when the hooks are already in canonical order was not used.
At lexical startup the second peer always finds an incomplete list: the
editor registers before `_zle_syntax_highlight` exists. So that skip would
save work only on a re-source, while guarding the deletes saves it at
startup.

`support/ui/.zsh.ui.zle_picker_show` no longer loads `zsh/terminfo` at source
time. As the other peers do, `_zle_picker_screen_session` loads `p:terminfo`
when a session opens, and `_compozsh_help_show` loads it before reading
`smcup`/`rmcup`. The editor still loads the whole module at top level, so the
complete shell state is unchanged in every order.

Not changed: computing `_MANUAL_CACHE_IMPLEMENTATION` on first cache use. That
moves the moment the identity is captured, so code redefined after sourcing
enters the key. The manual-cache tests' provider stand-ins did, and three
cases then failed with a cache miss in the reuse shell. A performance unit
must not change behavior, and the source-time deparse costs about 0.1 ms, so
the identity stays as it is. `manual cache identity follows the loaded owning
code across shells and re-sourcing`, added as characterization, pins the same
key across fresh shells and after a re-source, and a new key after
re-sourcing changed owning code.

Before tree `git archive 2bb16a1`, after tree the working tree; environment as
in P5-01, load averages 2.6–4.1. The focused metric is a scratch script that
copies each tree's hook block (from `autoload -Uz add-zle-hook-widget` to the
end of `.zsh.editor` and of `.zsh.highlighting`). For each run and tree it
starts one `env -i … LC_ALL=en_US.UTF-8 /bin/zsh -dfi` child with `zsh/zle`
loaded and stub widgets. The child times the editor block, then defines
`_zle_syntax_highlight` and times the highlighting block, which is the lexical
startup order. The first `add-zle-hook-widget` call in each child also loads
the function, as at startup. The trees alternate which goes first, and the
script checks that both trees leave identical hook styles. The startup rows
come from `isolated-startup.zsh … 15 en_US.UTF-8 direct`, and their A/A is
the baseline tree against itself. Milliseconds, *median (range)*:

| Metric | Mode | Runs | Before | After | Delta | A/A |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| Hook blocks, editor then highlighting | fresh child | 31 | 2.947 (2.856–3.169) | 2.690 (2.593–3.061) | −0.257 (−8.7%) | −0.008 (0.3%) |
| source | warm | 15 | 64.51 (63.50–68.62) | 64.07 (60.92–66.81) | −0.44 (−0.7%) | +0.04 (0.1%) |
| tty-source | warm | 15 | 63.09 (61.94–65.15) | 61.96 (60.63–63.82) | −1.14 (−1.8%) | +0.27 (0.4%) |
| process | warm | 15 | 71.49 (69.88–78.12) | 71.11 (67.26–74.69) | −0.38 (−0.5%) | −0.10 (0.1%) |
| editable | warm | 15 | 96.22 (93.75–99.93) | 94.08 (92.35–96.63) | −2.14 (−2.2%) | +1.16 (1.2%) |

An earlier before/after startup run gave warm source 64.08 → 62.16 ms and
tty-source 61.81 → 60.24 ms. The fresh rows moved within their noise in both
runs.

Decision: kept. The focused gain is about 30 times its A/A difference, with
identical hook state. Warm sourcing moved the same way in both startup runs,
by more than its A/A difference, but its ranges overlap. The gain is about a
quarter of the review's 1 ms estimate, because the canonical-order skip would
not apply at startup and the deparse item was left unchanged.

### P5-13: compiled shipped peers (C-02a, C-09)

Method: the before tree was `git archive c2642ca` and the after tree the
patched working tree, using `isolated-startup.zsh … 15 en_US.UTF-8 <layout>`.
Each tree's own installer ran unmeasured first. *A/A* is the before tree
against itself. Milliseconds, *median (range)*:

| Metric | Layout | Mode | Runs | Before | After | Delta | A/A |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: |
| process | symlink | warm | 15 | 72.12 (68.00–79.54) | 49.08 (45.90–58.22) | −23.04 (−31.9%) | −0.28 |
| source | symlink | warm | 15 | 65.16 (61.97–71.64) | 42.13 (39.80–48.66) | −23.03 (−35.3%) | −1.12 |
| editable | symlink | warm | 15 | 94.36 (90.02–108.89) | 74.15 (68.31–84.28) | −20.21 (−21.4%) | −0.73 |
| process | symlink | fresh | 15 | 217.32 (208.60–240.53) | 197.45 (187.44–219.84) | −19.87 (−9.1%) | +2.02 |
| editable | symlink | fresh | 15 | 238.15 (225.63–268.35) | 237.29 (215.45–250.78) | −0.86 (−0.4%) | +2.52 |
| process | copy | warm | 15 | 70.92 (68.11–80.59) | 51.06 (47.34–56.05) | −19.86 (−28.0%) | |
| source | copy | warm | 15 | 64.23 (62.34–74.05) | 44.36 (41.40–48.62) | −19.87 (−30.9%) | |
| editable | copy | warm | 15 | 93.75 (91.70–102.20) | 71.37 (70.25–83.42) | −22.38 (−23.9%) | |
| editable | copy | fresh | 15 | 244.45 (239.93–259.79) | 219.12 (215.90–254.65) | −25.33 (−10.4%) | |

Decision: kept. Warm startup moved far beyond its A/A in both layouts.
Fresh editable startup is dominated by `compinit` and stayed within noise
in the symlink layout.

The parse context is compared only where peers load as text, never at each
compiled peer. A first version that compared it at every compiled peer cost
about 8 ms: warm process startup was 57.6 ms instead of 49.1 ms.

### P5-12: the Apple-signed Git run directly (A2-08a)

Method: the before tree was `git archive 2ae4be2` and the after tree the
patched working tree, using `prompt-git-render.zsh` in render (11 shells ×
40 samples), pty (11 × 15) and fresh (21 first renders) modes. The render
A/A differed by +2.1% (clean), −1.2% (dirty), −2.8% (large) and +1.6%
(outside). Milliseconds, *median (range)*:

| Metric | Mode | Runs | Before | After | Delta |
| --- | --- | ---: | ---: | ---: | ---: |
| Prompt render, clean | render | 11×40 | 23.17 (22.46–26.51) | 16.43 (15.51–20.44) | −29.1% |
| Prompt render, dirty | render | 11×40 | 24.84 (23.43–30.71) | 18.06 (17.12–19.80) | −27.3% |
| Prompt render, large | render | 11×40 | 40.55 (38.71–45.40) | 33.71 (31.85–36.66) | −16.9% |
| Prompt render, outside | render | 11×40 | 7.50 (7.42–8.30) | 7.48 (7.42–8.21) | −0.3% |
| Prompt Return, clean | pty | 11×15 | 25.54 (25.25–31.83) | 18.85 (18.50–19.26) | −26.2% |
| Prompt Return, dirty | pty | 11×15 | 27.46 (26.82–34.22) | 20.38 (20.21–22.97) | −25.8% |
| Prompt Return, large | pty | 11×15 | 42.34 (41.55–50.19) | 35.26 (34.86–38.34) | −16.7% |
| Prompt Return, outside | pty | 11×15 | 9.21 (9.13–9.90) | 9.17 (9.11–13.26) | −0.4% |
| First render, clean | fresh | 21 | 36.68 (35.53–81.76) | 45.44 (44.09–58.84) | +23.9% |
| First render, dirty | fresh | 21 | 38.21 (37.01–44.74) | 47.00 (46.13–54.05) | +23.0% |
| First render, large | fresh | 21 | 53.78 (51.96–60.00) | 61.43 (60.41–69.19) | +14.2% |
| First render, outside | fresh | 21 | 13.20 (13.04–14.41) | 13.24 (12.95–14.34) | +0.3% |

Decision: kept. Inside repositories every steady-state row gains 7–7.5 ms,
far beyond its A/A. A shell's first Git prompt pays the owner-approved one
`xcrun --find git` and one `codesign` check, about +8.8 ms, and the second
prompt recovers it. Outside Git nothing is resolved.

### P6-01: startup recompilation (owner request, 2026-10-18)

Method: the before tree was `git archive 4a037b3`, where a changed peer
stays text until the installer runs again, and the after tree the patched
working tree, in a symlink installation. Warm isolated startup with every
peer fresh stayed the same (15 runs):
- process: 47.89 (46.17–52.75) → 47.40 (44.55–54.41) ms, −1.0%;
- first editable prompt: 70.34 (68.05–81.46) → 69.33 (68.24–81.29) ms,
  −1.4%.

The cost falls on the shells after a shipped peer changes. These are
process wall-clock times in milliseconds over 10 runs, *median (range)*:

| Change | Shell | Before | After | Delta |
| --- | --- | ---: | ---: | ---: |
| Largest peer touched | first | 49.3 (47.7–82.7) | 103.6 (100.2–139.7) | +110% |
| Largest peer touched | second | 48.8 (47.1–51.2) | 45.6 (43.7–46.5) | −6.6% |
| Five largest peers touched | first | 61.6 (60.2–95.0) | 220.9 (206.3–253.9) | +259% |
| Five largest peers touched | second | 60.9 (59.3–63.2) | 44.1 (43.9–45.5) | −27.6% |
| All 88 peers touched | first | 78.3 (70.6–106.7) | 279.9 (256.5–329.5) | +258% |
| All 88 peers touched | second | 73.5 (69.1–83.3) | 49.2 (45.8–52.9) | −33.1% |
| All 88 peers touched | third | 75.5 (69.7–78.6) | 48.9 (45.6–54.2) | −35.2% |

Decision: kept. The first shell after a change pays the compile once,
within the 300 ms box, as the owner accepted. Every later shell is compiled
without running the installer.

### P6-03: compiled completion dump (owner request, 2026-10-18)

Method: the before tree was `git archive bf10351` and the after tree the
patched working tree, using `isolated-startup.zsh … symlink` with 12
alternating runs. Milliseconds, *median (range)*:

| Metric | Mode | Runs | Before | After | Delta |
| --- | --- | ---: | ---: | ---: | ---: |
| process | warm | 12 | 49.96 (48.70–53.26) | 45.47 (43.73–67.24) | −9.0% |
| source | warm | 12 | 43.06 (42.36–46.16) | 38.54 (37.32–60.85) | −10.5% |
| editable | warm | 12 | 73.67 (72.94–80.05) | 69.08 (68.45–70.27) | −6.2% |
| process | fresh | 12 | 198.28 (195.06–213.43) | 198.05 (194.70–201.12) | −0.1% |

Decision: kept.
- The after median of warm process startup is below the before minimum,
  and the editable ranges do not overlap. This unit recorded no A/A; P5-01's
  symlink warm A/A was −1.43 ms.
- The after maxima are the first warm run compiling the dump once.
- A fresh shell has no dump yet, so nothing is compiled and no child runs.

## Unresolved and skipped findings

### Dropped units

The owner dropped these units on 2026-10-14, quoted under
[Owner decisions](#owner-decisions):

| Unit | Finding | Title |
| --- | --- | --- |
| P2-09 | D-10 | Add a `test_git_repo` fixture helper and use it in Git tests |
| P2-10 | D-10 | Use `test_git_repo` in the remaining fixture setups |
| P3-08 | B-10 | Share one per-level bookmark stack for the folder browsers |
| P3-14 | B-13 | Pin golden frames for four view kinds at three widths |
| P3-15 | B-13 | Build picker frames through one row-append helper |
| P4-15 | A1-13 | Promote the USB progress and Xcode destination parsers to support |
| P5-09 | U63, GIT-05 | Exclude local branch names from the remote fallback with a set |
| P5-10 | U66, USB-07 | Read Custom-path image sizes with `zstat` instead of `stat` forks |
| P5-11 | U67, USB-08 | Scan ISO archive listings in bounded chunks, not per line |

On 2026-10-18 the owner also dropped P6-02, *Compile private peers at
startup under the same strict checks*. Its manifest would have recorded
alias names and values, which are user data, for a measured 0.6–2 ms. The
patch is not applied, and private peers stay text.

Planning also left out some findings:
- C-01, deferring `compinit`; C-02 (b), loading peer internals on first
  call; C-03, native `autoload`; C-08 (b), caching Git filter names; and the
  A1-13 and A2 peer splits. The owner did not choose these.
- D-09's engine part. No unit splits `_zle_picker_loop` or
  `_zle_picker_render` directly.
- A2's unnumbered proposals, kept as follow-up candidates: split
  `_git_review_syntax_idle`, `_git_review_view` and
  `_git_worktree_create_choose`, and add a pure action builder for
  `_directory_browser_actions_view`.

### Final review findings not fixed

*Update 2026-10-19:* the follow-up batch closed the following, so they are no
longer open: SEC-A-03, SEC-A-05 to SEC-A-09, SEC-B-03, SEC-B-04, SEC-C-02,
SEC-C-03, CON-A-03 to CON-A-07, CON-A-09, CON-A-10, CON-B-07, CON-B-10, and
the no-developer-tools item. The list below is kept as written at the final
review.

F01–F09 fixed all 11 blocking findings. Four non-blocking ones are also
resolved:
- SEC-B-02, by F05;
- CON-A-08, by F02;
- CON-A-11 and CON-C-03, by this record (the phase 5 and 6 release notes,
  commit tables and performance sections above).

The other 33 are left for follow-up, grouped by consequence. Items without
an ID are observations from the review passes and the fix units.

Safety and privacy:

- **SEC-A-03, CON-A-03.** Startup runs the first `zsh` on `PATH`, from the
  start directory. That directory is often a project, and none of the
  safeguards for the prompt's other `PATH` commands apply. If that `zsh`
  reports another version than the running shell, every startup forks a
  compile child that refuses at once. See the owner question below.
- **SEC-A-08, CON-A-06.** `.gitignore` covers `support/cache/` but not
  `.zsh.addons/support/compiled/`. With `ZDOTDIR` at a clone, the mirror
  lands in the working tree. Its `zcompdump.manifest` holds the home path,
  and `zcompdump.zwc` the dump's private completion names. Add the path to
  `.gitignore`.
- **SEC-A-06, CON-A-04.** In install mode, a peer whose ctime is in the
  future makes `compile.zsh` poll every 10 ms until the clock catches up,
  with no bound, after the user confirmed. Cap the wait (about 2 s), leave
  that peer without a record, and add a test seam.
- **SEC-C-02.** `_usb_worker_progress_run` deletes any `compozsh-?*.?*` name
  directly in `TMPDIR`. Before, each site deleted only its own template.
  Narrow the check to the two disclosed progress templates and test that
  another `compozsh-*` file is left alone.
- **SEC-C-03.** An inherited `_XCODE_CAPTURE_BOUND` replaces the stdout
  bound of every Xcode capture. Pass the bound explicitly, or shadow it in
  `xcode()`, and test an exported value.
- **SEC-B-03.** `g --worktree` can leave a worktree path or name in the
  user's `$REPLY`. Make `REPLY` and `reply` local in
  `_git_worktree_session`, and add cancel and accept journeys to the
  view-state snapshot.
- **No developer tools.** On a Mac without developer tools, the prompt's
  `/usr/bin/git` reads and the new `xcrun --find git` can make macOS offer
  its command line developer tools dialog. The reviewer did not test this,
  and SECURITY.md does not mention it.

Disclosure and documentation accuracy:

- **SEC-A-05.** Freshness is checked for all peers before the loop. A
  same-second edit right after this shell's own startup compile can run the
  pre-edit wordcode once, which SECURITY.md's "never differs" wording does
  not allow for. Either `zstat` each peer again before sourcing it (one more
  `zstat` per compiled peer, and update performance.md), or disclose the
  window.
- **SEC-A-07.** The mirror's owner-only check reads the POSIX mode bits only.
  Extended ACLs, which the mirror can inherit from `support/`, are not
  inspected. Disclose this in the mirror section.
- **SEC-A-09, CON-A-05.** Three accuracy gaps in SECURITY.md's mirror text:
  - compiled loading changes the function source paths Zsh reports;
  - the audit script's "fresh (used)" omits the version and parse-context
    conditions;
  - the Focused regression checks table has no rows for `compiled peers`
    or `compiled completion dump`.
- **SEC-B-04, CON-B-07.** The README unit list and architecture.md's
  ownership table describe the shared Git entry too narrowly. It also
  serves the prompt, filter discovery and discard, uses a root/inherit
  selector policy and runs the verified Apple Git.
- **CON-A-07.** README's add-on authoring example returns 0 after
  `_compozsh_help_show`, which discards the 130 from Ctrl-C. Its definition
  also lacks the `unalias` line before it, a gap that predates the pass.
- **CON-A-09.** caching.md's "Public data only" rule covers the mirror,
  whose `zcompdump.zwc` holds private completion names. State the
  generated-artifact carve-out from security.md#persistent-storage there,
  and see the CLAUDE.md proposal below.
- **CON-A-10.** README says compiled code is skipped when something "has
  added aliases". Removing or redefining one, as with the common
  `unalias run-help`, also sends every peer and the dump to text.
- **CON-A-12.** "Compiled mirror" is used across contracts, but the
  glossary does not define it.
- **CON-B-10.** README's mock of the `g` branch picker shows `Search ‹›`,
  but the view shows `Filter choices`. This predates the pass.
- **SEC-C-04.** A USB test description still promises disk-metadata
  temporary files, which `2bb16a1` removed. Only contributors see it.

Correctness and contracts:

- **CON-B-06.** The branch inspector fills in the selected row only while
  input is idle. During key repeat, frames can paint "Details unavailable in
  this snapshot." for rows whose details were captured, and git.md says that
  never happens. Either build text for the bounded result prefix or reword
  the contract.
- **CON-B-08.** If the shared Git entry is missing, bare `g` reports "not
  inside a Git working tree" instead of naming the missing support.
- **SEC-A-04, CON-A-13, CON-B-11.** The recorded parse context omits some
  lexer inputs:
  - the comment character `${histchars[3]}`;
  - reserved words disabled with `disable -r` (the known limit below);
  - `.zshrc` takes its option list from the manifest instead of pinning
    its own.

  The proposal is to add `${histchars[3]}` and the sorted
  `${(k)dis_reswords}` to the context in all three places, written
  identically, at no fork cost.

Test coverage:

- **CON-A-02.** `tests/verify.zsh` claims to syntax-check every shipped Zsh
  file but skips `.zsh.addons/support/compile.zsh`.
- **SEC-B-05.** No test checks SECURITY.md's claim that the inline picker
  sizes itself from the prompt without running the prompt's substitutions.
- **CON-C-04.** Two phase 4 Xcode tests stub `_zle_picker_run` by hand
  instead of using `test_picker_script`.
- **CON-C-05.** No test covers Ctrl-C → 130 after an Xcode test run, or
  Ctrl-C (not Escape) in the Run product choice, and P1-11's status matrix
  leaves out `xcode`.
- **Settle branch.** The branch that deletes a rewritten dump when its
  rename fails has no test (security review, slice A).
- **Stray stderr.** The `_zle_ui_view` line in [Tests](#tests) comes from a
  fixture that loads Git review without the shared UI. Load the support
  there.

Performance:

- **CON-C-06.** With the 5 MiB Build & Run bound, product resolution can pipe
  the whole settings document to `plutil` hundreds of times. Measure a
  100-target resolution, and if it is slow, convert once. P1-14 estimated a
  pause of about 0.12 s per 40-KiB target.
- **Small slowdowns.** Non-TTY rendering outside Git (+0.16 ms) and warm
  Browse (+0.85 ms) were not investigated.
- **Benchmark priming.** Proposal: `isolated-startup.zsh` could prime with
  one more unmeasured shell after a second boundary, so that run 1 no longer
  pays a deferred compile.

Code hygiene and proposals:

- **CON-B-05, CON-B-09.** Stale comments: three in `.zsh.find` still say
  the loop clears capabilities between passes, and one in `.zsh.navigation`
  calls the bounded branch catalog "complete".
- **F03 proposal.** Read `_ZLE_PICKER_ZERO_BASED` and
  `_ZLE_PICKER_CANCEL_BOOKMARK` as text instead of in arithmetic. That
  removes the evaluation hazard even if the load-time unset list drifts,
  but it departs from the rest of the flag family.
- **F09 proposal.** Move the Git review, worktree and file-view guide
  paragraphs out of `support/ui/.zsh.ui.zle_picker_guide_render` into
  `_ZLE_PICKER_GUIDE_FACTS`, set by the Git peers. That changes the visible
  guide order and touches `support/ui`, so it needs its own unit and the
  full suite.
- **F01 proposal.** A peer with a `-` text record keeps the unused `.zwc`
  from an earlier successful compile. Pruning `.zwc` files for such records
  would remove it.
- **Minor.**
  - `_usb_diskutil_plist_capture` strips trailing newlines one at a time, a
    quadratic cost only for pathological output.
  - `/bin/df -P` runs without `--`. This predates the pass, and the path is
    always absolute.
  - F02's commit subject is 76 characters, over the 72-character limit. It
    was not amended, because commits are not rewritten.
  - `27e6cbc`'s message cites an Owner decisions entry that does not name
    the view-state guard. No decision depends on it.

### Owner questions from the final review

1. **Which Zsh compiles at startup (SEC-A-03, CON-A-03).** The bootstrap and
   `.zsh.editor` run `${commands[zsh]} -f` in the start directory.
   - (a) Run `/bin/zsh -f` from `/`. That is the platform Zsh the product
     targets, and `compile.zsh` already refuses a version mismatch, so a
     different running Zsh stays on text.
   - (b) Keep the `PATH` lookup, but run from `/` and skip a candidate
     inside `$PWD`'s repository.
   - (c) Keep the current behavior and list the startup `zsh -f` among
     SECURITY.md's external boundaries.

   *Recommendation:* (a), together with the disclosure from (c). It runs
   no project-chosen binary, adds no fork and stops the refusing child on
   every startup. It changes which program executes, so it is your
   decision.
2. **Is the bootstrap still minimal (contract review, slice A).** `.zshrc`
   grew from 62 lines to 212 for the mirror check, and repository-layout's
   Essentials now name that check as bootstrap duty.
   - (a) Accept it as minimal and say so in the layout contract.
   - (b) Ask for a smaller design.

   *Recommendation:* (a). The check is fork-free and falls back to text on
   every failure. Moving it into a sourced support file would come close to
   the extra initialization phase that CLAUDE.md's Simple structure rules
   out.

### Proposed CLAUDE.md change

This phase may not edit CLAUDE.md, so the change is listed here. CLAUDE.md's
*Fast* invariant says optional caches may hold public system data only. The
compiled mirror's `zcompdump.zwc`, however, holds the dump's private
completion names, which security.md#persistent-storage permits as "its
source in another form". The proposal is a parenthetical such as: *(a
generated artifact may also hold its own source in another form; see
`engineering/security.md#persistent-storage`)*. Its wording and placement
are the owner's decision (CON-A-09).

The slice B contract reviewer also proposed refreshing CLAUDE.md's suite
note. `e2c957a` already did that, and the note now says about 1,130 cases in
about 5 minutes.

### Known limits

- **Aliases and parse options.** Compiled loading assumes Zsh's built-in
  aliases and a clean parse context. If an initializer, `/etc/zshenv` or an
  earlier private peer defines, removes or changes an alias (including
  `unalias run-help`), or changes a parse option, every peer loads as text.
  The completion dump then loads as text too, as a plain `.zcompdump`.
  This is correct, only slower.
- **`disable -r`.** Disabled reserved words are not recorded in the parse
  context, so a startup file that runs `disable -r` can make a peer's text
  parse differently from its compiled wordcode, which would still load. See
  SEC-A-04 above.
- **Concurrent prune.** If a peer is edited between one shell's validation
  and its `source`, and another shell's compile prunes that entry in the same
  window, the first shell prints "add-on failed to load" once instead of
  loading the peer. It never runs stale code (F01).
- **One-time costs, owner-accepted.** A shell's first Git prompt costs about
  9 ms more for `xcrun` and `codesign` (P5-12). The first shell after a
  shipped-peer update costs up to about 300 ms more (P6-01).

## Manual Terminal.app acceptance pending

PTY tests can't judge how Terminal.app looks. These checks come from the
unit results, deduplicated, plus one from the final review (item 21). Use
disposable folders, repositories and media, and a disposable USB stick for
any write. Items marked *optional* are not required by a contract.

Prompt and editing:

1. **Narrow context row** (P4-22, `2f724b2`).
   - In a Git project, type a draft, then drag the window narrower than 12
     columns. The prompt shows the single context row, abbreviated with …,
     above the `❯` input line with no wrapping. Further typing leaves that
     row unchanged.
   - Widen the window again. The Interaction lens comes back with the draft
     intact.
   - At a normal width, Option-I while typing still opens and closes the
     pinned Context lens with no flicker or stale context row.
2. **Prompt Git summary through the shared entry and Apple Git** (P4-29,
   `450393e`; P5-12, `4a037b3`).
   - In clean, dirty (staged, modified, untracked, stash), detached-HEAD and
     mid-rebase repositories, the Git summary text and colour match the
     previous build, and the prompt redraws promptly.
   - With `GIT_DIR` and `GIT_WORK_TREE` exported to another repository, the
     prompt follows them.

Full-screen and shared UI:

3. **Ctrl-C status** (P1-11, `5ba73f2`). In a disposable repository, run
   `g` and press Ctrl-C. The alternate screen closes cleanly with the prompt
   and draft restored, and `echo $?` prints 130. Do the same for
   `external-device` (Tasks screen) and `g --help`. Escape still gives 0 in
   each.
4. **Unbound keys stay inert** (P1-10, `95795de`). Open a query view (for
   example the volume-name field) and a plain choice list, and type some
   text in each.
   - Left, Right, Home, End and F1 (Fn-F1 where needed) each beep or do
     nothing, and the view stays open with the typed text kept.
   - Escape, Ctrl-G and an Option-letter chord such as Option-Q (with Option
     as Meta) still cancel.
5. **Inline fallback below the prompt** (P3-13, `4ed0cfe`). Use a profile
   that declares the terminal as vt100 (no alternate screen) and a 16-row
   window.
   - At a multi-line living prompt, press Ctrl-R. Nothing scrolls, the
     prompt's first line stays visible and at least one spare row remains
     below the frame.
   - Enlarge the window to 24 rows. The frame grows without scrolling.
   - Ctrl-G restores the prompt and draft.
6. **Alternate screen after the terminfo move** (P5-08, `c2642ca`). Ctrl-R
   history and `compozsh --help` still open on the alternate screen and give
   back the prompt and scrollback unchanged on exit.
7. **Guide limits and plan headings** (P3-12, `15d4e36`).
   - Set `ZSH_FILE_SEARCH_MAX_VISITED=5000` and
     `ZSH_FILE_SEARCH_MAX_CANDIDATES=300`, open Browse (path + Tab) and
     press Ctrl-K. The Limits row reads "Walk: 5,000 entries; captured
     matches: 300", with its label in heading style and in the same column
     as the key rows.
   - In bare `g`, choose a remote-tracking branch to create. LOCAL BRANCH,
     FROM REMOTE-TRACKING REF and COMMIT show in heading style in the plan
     pane.
   - In the composer, a draft line "TARGET" or "Safety first" is neither
     bold nor warning-coloured in the plan.
   - In `g --review` Working changes, added and removed diff lines keep
     their review colours.

Git:

8. **Review and navigation entries** (P3-04, `0351913`; P4-19, `40dfbb4`).
   - In a Git working tree, press Option-Return and choose "Review this
     working tree". The Git review menu opens for the repository root, and
     Escape returns to Draft / Inspect with the draft and cursor unchanged.
   - Do the same in a folder outside any repository. "Git / Unavailable"
     shows "This folder is not in a Git working tree. Your draft is
     unchanged.", and Escape returns.
   - In bare `g`:
     - Branches shows the repository name, and copy is offered when
       `pbcopy` is available.
     - Ctrl-X opens review choices, and Back returns to Branches.
     - With no local match, a remote-tracking ref opens "Create local
       branch", with the repository name as subtitle.
   - In Recents (Option-Tab), copy is offered, and Actions lists Insert path
     or Change directory to match how Files was opened.
   - `g --review` opens the same menu as before. In Working changes, these
     behave as before: Option-number selection, Ctrl-R refresh,
     auto-refresh, the file views (All files, Tree) and Escape back to the
     menu.
9. **Bounded branch catalog** (P4-31, `70203b0`; F06, `399fd9d`).
   - In an ordinary repository, run `g`, press Tab for details, then hold
     Down and Up through the list. Details follow the selection with no
     visible flashes of "Details unavailable in this snapshot." on
     intermediate frames. CON-B-06 predicts such flashes while keys are
     queued.
   - Type a filter. Details switch to the first result at once. Clear the
     filter, and details match the selected row.
   - Press Ctrl-X, open review, then go back. The same selection and its
     details return.
   - Use a repository with more than 5,000 local branches, for example
     generated with packed-refs:
     - the header reads "local branches · recent first · partial";
     - the current branch is first, even if it sorts last by name;
     - a non-matching filter shows the partial notice that points to
       `g switch` and `g branch --list`, with no remote rows, and the header
       keeps "partial";
     - Tab details end with the "Partial catalog" paragraph.
10. **Discard** (P4-29, `450393e`). In a dirty repository, `g --discard-all`
    shows the same printed status, confirmation picker and result message as
    before, and discards after confirmation. On cancel it reports
    "Cancelled; nothing was changed."

Xcode:

11. **Build & Run with 7 or more targets** (P1-14, `05991b0`). Open `xcode`
    in a real project whose scheme builds 7 or more targets (an app plus
    frameworks or extensions). Choose My Mac, then Build & Run. The app
    launches with no capture-limit error. Expect a pause after the build
    while products resolve, roughly 0.12 s per 40-KiB target (see CON-C-06).
12. **Run monitor and reader positions** (P3-10, `00500ab`).
    - During an Xcode Run, with the inspector not focused, make the window
      shorter, then taller. The run monitor keeps the newest app output
      visible both times.
    - Open Read output. It opens at the tail.
    - Scroll up so the reader pauses, then resize narrow, wide and narrow
      again. The same log line stays at the top.
    - Type a filter. The reader jumps to the first matching line.
    - In Git review, scroll a folder summary and let an automatic refresh
      happen with no other change. The folder summary keeps its position.
13. **LLDB and device cleanup** (P4-14, `6b1470a`).
    - Run Build & Run on a booted Simulator, choose Enter LLDB, then quit
      LLDB. The prompt comes back cleanly with no "[1] done" job notice, the
      app stops, and no `compozsh-xcode-run.*` directory remains under the
      Simulator's `data/tmp`. The unit's note said the opposite, but the
      contract requires this cleanup.
    - Run Build & Run on a paired device, then press Escape. The console
      stops, and no `compozsh-xcode-device.*` directory remains under
      `TMPDIR`.
14. **Test results with several locations** (P4-10, `d576e74`). Run
    `xcode`, then Test, on a project where one failing test reports at least
    two source locations, for example an assertion in a helper the test
    calls.
    - The Done overview lists each location on its own indented line under
      the test name.
    - The failure inspector lists each location under "Involved files".
    - "Copy report and done" pastes one `- path:line` line per location.
    - The passing and empty-bundle windows look unchanged: success colour,
      passive lines and Limits.
15. **Cancel and result actions** (P3-04, `0351913`). Run bare `xcode` in a
    project and cancel. Then run a test action and choose a result action.
    The screen restores and the chosen action runs.
16. *Optional:* **export-skills help** (P4-08, `aedefea`). With colour on,
    check that `xcode --export-skills --help` renders the indented vendor
    rows readably. That includes the `Codex in Xcode:` line, whose path is
    on the next line. Check both the help workspace and the printed help.

External devices:

17. **Step 3 refusal line** (P1-08, `5d6a1f4`). Check at 80 columns and at a
    wide width. Run `external-device`, choose an image and a drive, add a
    checksum that does not match, then choose Flash without verification.
    - Step 3 shows one red passive line starting "The image integrity check
      must match before flashing". At 80 columns it is truncated cleanly.
    - The line has no `[n]` index and no selection stop.
    - The line disappears after the next action, for example Remove image
      checksum.
18. **Image browser keys** (P1-09, `32f1f4e`; P3-04, `0351913`). Run
    `external-device --flash`, choose Custom path to media… and highlight an
    `.iso`.
    - Ctrl-X, Ctrl-O, Right and Tab each give the bell (or visual bell) and
      keep the same row highlighted.
    - The footer shows no ^X or ^O hints, and the Ctrl-K guide lists no
      Ctrl-O, Ctrl-X or Ctrl-E lines.
    - Right on a folder still opens it, and Left returns with its selection
      restored.
    - Hidden toggling and the filter behave as before.
    - Return on the `.iso` goes to Step 2, and Escape returns cleanly.
19. **Worker progress** (P4-07, `8cc78c9`).
    - Flash with verification. Step 3 progress still advances every quarter
      second, and the title switches from "Writing image" to "Verifying USB
      against image".
    - Ctrl-C during the write leaves no `compozsh-usb-progress.*` file in
      `$TMPDIR`.
    - Flash a macOS installer. "Creating macOS installer" shows live
      `createinstallmedia` lines, and the final line remains after it exits.
20. **Virtual-disk refusal** (P4-30, `7bd92c0`).
    - Attach a small `.dmg` or sparsebundle that holds an `.iso`, for
      example with `hdiutil attach`. Run
      `external-device --flash /Volumes/<image>/<file>.iso` and choose it.
      The Media compatibility screen shows the red line "Media on a virtual
      disk · Nothing can be written", the detail text and only "Choose
      another media". Return or Escape goes back to Step 1 with no drive
      list.
    - Put an `.iso` on the internal disk and on an external USB disk. Both
      reach Step 2, and the drive holding the image is not listed.
    - *Optional:* media on an AppleRAID set is refused the same way.
21. **Localized filesystem names** (P5-07, `2bb16a1`; raised by the final
    review). diskutil now runs under `LC_ALL=C`. On a Mac whose system
    language is not English, compare the filesystem names in
    `external-device --format`'s format choice with the previous build.
    P5-07's scratch check varied only the `LC_*` locale, not the system
    language.

Startup:

22. **Compiled startup and recompilation** (P5-13, `2ae4be2`; P6-01,
    `bf10351`).
    - After `zsh install.zsh --symlink`, a new window shows no load
      diagnostics. `compozsh --list` shows the same labels as before, for
      example `mkcd · ✓ help · .zsh.tools`.
    - Edit a shipped peer in the clone, or `git pull` a change, then open a
      new tab. Its prompt appears slightly later, once, with no output or
      diagnostics, and the edit takes effect. The next tab is fast.
      `ls -la ~/.zsh.addons/support/compiled` shows no `.lock` and no
      `*.compozsh-tmp-*` file.
    - In that first slower tab, type ahead at once. No keystrokes are lost.
    - After an update, open two tabs at the same moment. Neither shows
      diagnostics, and both prompts work.
    - After an update, press Ctrl-C while the first tab starts, then open
      another tab. It starts normally with no diagnostics, and the mirror
      holds no temporary files. A leftover `.lock` clears after a minute.

## Run notes

**Timeline (CST).** *Unit time* is the sum of the units' own elapsed
minutes from their result files.

| Phase | Window | Units landed | Unit time | Notes |
| --- | --- | ---: | ---: | --- |
| Reviews and planning | 2026-10-14, until 17:10 | — | — | Five read-only lenses at `4d93c93`, then a plan of 87 units |
| 1 | 10-14 17:10 → 10-15 09:46 | 16 | 4.0 h | Commit units 17:55–20:49; the three patch units committed 04:06–08:20 |
| 2, first run | 10-15 09:46 → 10-16 20:08 | 1 | 25.1 h | Time boxes reached while the Mac slept on battery |
| 2, retry | 10-17 11:32 → 13:54 | 11 | 2.3 h | On AC power |
| 3 | 10-17 13:54 → 17:54 | 12 | 3.9 h | |
| 4 | 10-17 17:54 → 20:40 | 30 | 7.8 h | Four lanes in about 2.5 h, then integration and three patches |
| 5 | 10-17 20:40 → 10-18 01:09 | 10 | 4.0 h | Includes P5-12's rerun after its owner decision |
| 6 | 10-18 01:09 → 18:19 | 2 | 1.6 h | Includes dropped P6-02. P6-03 started after the owner's answers of about 17:37 |
| Project rules | 10-18 18:19 → 19:05 | 3 commits | — | |
| Final review | 10-18 19:05 → about 21:40 | 9 fixes | 1.2 h | Six review passes, triage, fixes, final suite and measurements |

Unit time adds up to about 50 h, and half of it is phase 2's lost first
run. The pass took about 100 h of wall clock, which includes waits for
owner answers and the nights.

**Laptop sleep.** Phase 1's patch re-verification and phase 2's first run
ran on battery, and the Mac slept between maintenance wakes. The power log
showed 1,187 sleep entries during phase 2's first run. Unit time boxes count
wall clock, so nine units of that run timed out with nothing kept, apart
from a saved patch for P2-01. P2-06 and P2-07 were skipped because P2-04 had
not landed, and the run's one gate took 9,104 s. Some of those units also
reported stalled tool calls, classifier timeouts and cut-off responses
during the gaps. Phase 1 lost only one PTY case. The retry on AC power
landed all 11 units in 2.4 h of wall clock, which bears out the excellence
run's proposal to keep the machine awake. No later unit reported sleep.

**Parallel lanes.** With the owner's approval, phase 4 ran in four git
worktree lanes (`lane/p4-usb`, `lane/p4-xcode`, `lane/p4-git` and
`lane/p4-prompt`), each owning disjoint peer files. Inside a lane, units ran
one at a time, and lane agents did not edit this record. The orchestrator
fast-forwarded the USB lane and cherry-picked the other three without
conflicts, so the Xcode, Git and prompt units have new commit IDs on this
branch. The lane worktrees are gone, and the four lane branches remain in
the local repository.

**From patch mode to recorded approvals.** Until 2026-10-18, owner-approved
units ran in patch-only mode: P1-14 to P1-16, P4-29 to P4-31, P5-12, P5-13
and P6-01 to P6-03.
- The agent built and verified the change, saved a patch and reset the
  tree.
- The orchestrator had the owner's answers directly. It applied the patch,
  re-verified red at the prior HEAD and then green, ran the full suite and
  committed.

On 2026-10-18 the owner answered "Record, then agents may act
(Recommended)". From then on, implementing agents committed against the
dated quotes in [Owner decisions](#owner-decisions): P7-01, P7-02 and
F01–F09. Agents still treated approvals relayed only in workflow text as
carrying no authority.

**Global rules file.** At the owner's request on 2026-10-18, general agent
rules moved into the owner's global `~/.claude/CLAUDE.md`, outside the
repository. This repository received only the project-specific updates
(`e2c957a`). That file is not part of the repository or of this record's
evidence.

**Scratch cleanup by macOS.** The run's scratch area lives under
`/private/tmp`, and macOS's own `/tmp` cleanup removed older scratch files
there mid-run. The unit result files and logs this record draws on were
intact.

**Processes.** Twelve idle `/bin/zsh -dfi` shells from P5-02's focused
benchmark were still running at the end of the run (PIDs 7051–9124, started
2026-10-17 21:12, 0% CPU). Each sources `.zsh.manual` and times
`_manual_async_start`. F06 reported them. They were left for the
orchestrator to stop, because no later agent had started them. They used no
CPU, so measurements were unaffected.

**Reviews.** Delegation was forbidden inside units, so each unit applied the
`security-reviewer` and `contract-reviewer` checklists itself. The final
review ran them as six separate read-only passes, and each pass confirmed
an unchanged tree and diff hash at its start and end.
