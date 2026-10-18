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

## Unresolved and skipped findings

*Filled in at the end.*

## Manual Terminal.app acceptance pending

*Filled in at the end.*
