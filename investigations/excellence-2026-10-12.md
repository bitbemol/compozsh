# Excellence run, 2026-10-12

> **Status (2026-10-14): complete.** All five phases ran: baseline, audit and
> adversarial verification, planning, fixes, and a final review with
> before/after measurements. The owner confirmed OD1 and OD3 as shipped on
> 2026-10-14. Open items are the skipped performance units, manual
> Terminal.app checks and proposed CLAUDE.md changes, listed below.

## Summary

- **Scope.** An unattended pass on `excellence/2026-10-12`, from `main` at
  `36cdcda`, between 2026-10-12 02:36 and 2026-10-14 00:53 CST (about 46 h of
  wall clock).
- **Audit.** Nine areas yielded 82 findings, and adversarial verifiers
  confirmed all 82 (none rejected; 11 severities corrected). After correction
  that is 5 high, 24 medium and 53 low: 39 correctness, 16 performance, 11
  invariant, 9 simplification and 7 security. The plan merged 2 findings into
  others, grouped 2 in one unit and split 2 across two units each, giving 81
  units; 3 needed owner decisions.
- **Fixes.** 72 units landed as commits, resolving 73 of the 82 findings
  (OD2's by recording its cost). The 9 remaining performance units, U62–U70,
  were skipped by owner decision. The final review ran six security and
  contract passes and raised 39 findings, 8 of them blocking; seven follow-up
  commits fixed or recorded all 8. The branch holds 81 commits including this
  one. Product code changed in 25 files, +1,050/−2,350 lines, mostly deletion
  of unreachable USB code.
- **Tests.** The suite went from 961 cases (960 passed, 1 failed: the known
  real-FAT32 round trip) to 1,022 cases, all passing, in 227.8 s.
  `zsh tests/verify.zsh` passes.
- **Latency.** The Git-source Search first frame is about 95 ms faster
  (−47% fresh, −48% warm). Warm isolated startup is 2.6–2.8 ms faster
  (−3.6% to −4.3%), repeated in a second run. No metric regressed beyond
  noise. Unit benchmarks removed quadratic costs, saving up to seconds per
  call, in the Git syntax poll, bounded capture, inspector wrapping, Xcode
  scheme parsing and the search providers.
- **Owner decisions.** OD1: recapture prompt facts after an in-widget `cd`.
  OD2: keep one help-capture fork per guide. OD3: delete the retired Windows
  writer. The owner confirmed OD1 and OD3 as shipped on 2026-10-14, which
  closes [CON-A-01](#unresolved-and-skipped-findings).

## Purpose

An unattended quality pass on branch `excellence/2026-10-12`, created from
`main` at `36cdcda`: audit the product against its contracts, fix confirmed
defects, and make measured performance changes. This record keeps the
evidence. The baseline below fixes the starting point every later unit
compares against: the suite's pass/fail state, and latency medians with an
A/A noise floor, so a performance change is claimed only when it is clearly
beyond noise ([performance](../engineering/performance.md#measuring-latency)).

## Environment

- Apple M3 Max, 14 cores (10 performance, 4 efficiency), 36 GiB, on AC power.
- macOS 27.0.1 (26A434); `/bin/zsh` 5.9 (`arm64-apple-darwin26.0`);
  Git 2.54.0 (Apple Git-157).
- Commit `36cdcda`. Baseline: an immutable `git archive 36cdcda` copy.
  Candidate: the working tree at the same commit, so every comparison below is
  A/A (identical code).
- Benchmark shells ran under `LC_ALL=en_US.UTF-8`, `TERM=xterm-256color`, a
  system-only `PATH`, `ZSH_LOCAL_INIT=/dev/null` and a disposable
  `HOME`/`ZDOTDIR`/`TMPDIR`; no private configuration, history or peers. The
  drivers themselves ran under the default C locale.
- Load averages were 1.8–4.4 during the runs (an ordinary desktop session,
  not an idle machine). Filesystem caches were not flushed. Runs were
  sequential; nothing else from this pass ran concurrently.

## Suite and verification

- `zsh tests/run.zsh`: **960 passed, 1 failed**, 234,232 ms. The failure is
  `USB Windows verifier round-trips and detects corruption on real FAT32`,
  the known real-FAT32 `hdiutil` round trip on macOS 27
  ([index](README.md#known-code-issues-found-2026-10-11-not-yet-fixed)); not
  investigated. The Xcode Logger cleanup timing tests passed on the first run.
  *Since then:* `7541987` deleted that test and its index entry with the
  retired Windows writer
  ([OD3](#od3-delete-the-retired-windows-writer-usb-06)), so the index link
  above no longer lists it and the suite has no standing failure.
- `zsh tests/verify.zsh`: syntax ok, whitespace ok, re-source ok.

## Method

Every script alternates the baseline and candidate trees run by run, creates
its own `mktemp -d` workspace and removes only that directory.

- **Isolated startup** —
  [`benchmarks/isolated-startup.zsh`](benchmarks/isolated-startup.zsh), 15
  runs. *process*: wall clock of `zsh -dfi -c 'source <root>/.zshrc'` without
  a TTY, fork to exit; *source*: that shell's in-process sourcing time;
  *editable*: wall clock from spawning `zsh -di` in a 140×40 PTY (its ZDOTDIR
  `.zshrc` sources the tree) to the first ZLE line-init; *tty-source*: that
  PTY shell's sourcing time. *Fresh* is a new ZDOTDIR per run (no completion
  dump, no manual cache); *warm* reuses one primed ZDOTDIR per tree. Each PTY
  shell is closed only after the asynchronous manual capture settles, so no
  worker outlives its sample.
- **Complete prompt render** —
  [`benchmarks/prompt-git-render.zsh`](benchmarks/prompt-git-render.zsh),
  unchanged, with its outside/clean/dirty/large fixtures
  ([in-memory parsing](in-memory-capture-parsing.md#measurements)): *render*
  11 shells × 40 renders after three discarded warm-ups (median of per-shell
  medians); *fresh* the first render of 15 new shells; *pty* 11 sessions × 15
  Return-to-next-line-init samples.
- **First painted full-screen frame** —
  [`benchmarks/workspace-first-frame.zsh`](benchmarks/workspace-first-frame.zsh),
  11 runs. Each run starts one new `zsh -di` per scenario and tree in a
  140×40 PTY, after one unmeasured priming shell per tree built that tree's
  completion dump and manual cache. Keys before the entry keys are typed and
  settled first. The clock starts just before the entry keys are written and
  stops when the escape-stripped PTY output contains a marker that only the
  populated frame paints (never a busy frame). *Fresh* is each new shell's
  first entry; *warm* the median of the next five entries in that shell.
  Synthetic, realistic fixtures (long paths with spaces and Unicode):

  | Scenario | Entry keys → frame | Workload |
  | --- | --- | --- |
  | browse | Tab after `cd ~/Downloads/` → Browse | 241 folders, 1,800 files |
  | browse-large | Tab after a photo-export path → Browse | 20 folders, 20,000 files |
  | search | Return on a Search descendants query → results | local walk, non-Git project of about 10,500 entries, 600 candidates |
  | search-large | the same → results | local walk over the 20,020-entry export (visit cap, partial) |
  | search-git | the same → results | Git source, 2,400 tracked files, 300 candidates |
  | history | Ctrl-R at an empty prompt → History | 20,000-command extended history |
  | review | Return on `g --review` → chooser | dirty 2,400-file repository |
  | review-changes | Return on the chooser's working changes → file list | 15 staged, 45 unstaged, 25 untracked |

  Search scenarios include the "Searching…" busy frame in the measured time;
  review-changes stops at the list frame, before its first diff loads.

## Measurements

Milliseconds. *Median* and *range* are the baseline tree's median and min–max
over runs; *A/A* is the candidate median minus the baseline median, with its
share of the baseline median. Raw outputs and one set of stripped frames are
kept with the run's local artifacts (not distributed).

| Metric | Mode | Runs | Median | Range | A/A |
| --- | --- | ---: | ---: | ---: | ---: |
| Startup process | fresh | 15 | 217.72 | 213.77–230.04 | −3.63 (1.7%) |
| Startup process | warm | 15 | 71.77 | 69.30–77.26 | −0.55 (0.8%) |
| Startup source | fresh | 15 | 211.83 | 208.28–222.68 | −3.40 (1.6%) |
| Startup source | warm | 15 | 64.66 | 63.61–69.02 | −0.34 (0.5%) |
| Startup editable | fresh | 15 | 236.30 | 234.55–240.37 | −1.04 (0.4%) |
| Startup editable | warm | 15 | 98.64 | 97.58–100.88 | −1.49 (1.5%) |
| Startup tty-source | fresh | 15 | 201.66 | 200.35–204.96 | −1.16 (0.6%) |
| Startup tty-source | warm | 15 | 63.72 | 63.20–64.18 | −1.69 (2.7%) |
| Prompt render, outside | render | 11×40 | 4.11 | 4.09–4.14 | −0.01 (0.1%) |
| Prompt render, clean | render | 11×40 | 24.96 | 24.68–25.42 | +0.06 (0.2%) |
| Prompt render, dirty | render | 11×40 | 27.14 | 26.92–27.37 | +0.07 (0.3%) |
| Prompt render, large | render | 11×40 | 48.18 | 47.00–48.88 | −0.01 (0.0%) |
| Prompt render, outside | fresh | 15 | 4.74 | 4.67–4.93 | +0.05 (1.1%) |
| Prompt render, clean | fresh | 15 | 36.12 | 35.54–80.16 | +0.26 (0.7%) |
| Prompt render, dirty | fresh | 15 | 38.44 | 37.27–40.46 | −0.16 (0.4%) |
| Prompt render, large | fresh | 15 | 58.57 | 57.19–60.29 | −0.15 (0.2%) |
| Prompt Return, outside | pty | 11×15 | 7.18 | 7.09–7.36 | −0.06 (0.8%) |
| Prompt Return, clean | pty | 11×15 | 28.54 | 28.15–29.19 | −0.11 (0.4%) |
| Prompt Return, dirty | pty | 11×15 | 30.81 | 30.53–33.94 | −0.01 (0.0%) |
| Prompt Return, large | pty | 11×15 | 50.78 | 50.14–51.27 | −0.10 (0.2%) |
| Frame browse | fresh | 11 | 79.23 | 78.01–83.17 | −0.08 (0.1%) |
| Frame browse | warm | 11×5 | 81.60 | 81.12–82.23 | −0.15 (0.2%) |
| Frame browse-large | fresh | 11 | 808.60 | 807.76–809.67 | +0.58 (0.1%) |
| Frame browse-large | warm | 11×5 | 809.18 | 805.52–810.62 | −0.96 (0.1%) |
| Frame search | fresh | 11 | 508.34 | 491.84–515.48 | −1.19 (0.2%) |
| Frame search | warm | 11×5 | 488.82 | 484.13–493.67 | +0.31 (0.1%) |
| Frame search-large | fresh | 11 | 924.62 | 921.89–957.60 | +1.77 (0.2%) |
| Frame search-large | warm | 11×5 | 926.21 | 923.91–930.20 | +0.19 (0.0%) |
| Frame search-git | fresh | 11 | 210.09 | 206.08–217.05 | −0.07 (0.0%) |
| Frame search-git | warm | 11×5 | 207.99 | 205.95–212.17 | +0.48 (0.2%) |
| Frame history | fresh | 11 | 7.40 | 7.03–7.53 | −0.06 (0.9%) |
| Frame history | warm | 11×5 | 13.80 | 11.70–15.37 | −0.62 (4.5%) |
| Frame review | fresh | 11 | 65.27 | 62.03–72.14 | +4.03 (6.2%) |
| Frame review | warm | 11×5 | 63.28 | 60.14–68.40 | +0.73 (1.2%) |
| Frame review-changes | fresh | 11 | 122.07 | 119.43–126.77 | −1.36 (1.1%) |
| Frame review-changes | warm | 11×5 | 119.09 | 114.76–120.93 | −2.39 (2.0%) |

The A/A deltas stay within 1–3% for every metric except the two shortest or
noisiest frames: Ctrl-R warm (4.5%) and the `g --review` chooser fresh (6.2%,
with 62–78 ms ranges). Ranges with one outlier (prompt fresh, clean, 80.16 ms) show
why medians, not single samples, decide.

*Proposal* for later units: call a change clearly beyond noise when its
median moves by more than three times that metric's A/A delta and by more
than the larger of 2% and 1 ms, and a second invocation repeats the direction.

## Baseline observations

Recorded from the measurements above; none was investigated in this phase.

- **Startup budget.** Warm isolated startup sources in about 64.7 ms in
  process and 71.8 ms fork to exit, above the contract's "roughly 50 ms" on
  this Mac ([performance](../engineering/performance.md#essentials)); the warm
  first editable prompt takes 98.6 ms. Without a completion dump (fresh), the
  source time is about 212 ms. Not profiled.
- **Large folders.** Browse over 20,000 files takes about 809 ms and paints no
  busy frame first; the bounded local search takes about 489–508 ms over
  10,500 entries and 925 ms over 20,020 (visit cap reached, partial). This
  matches the open *Large-folder providers* backlog item and its
  locale-sorting lead ([index](README.md#open-backlog)).
- **Ctrl-R warm.** A repeated Ctrl-R in the same shell paints in about
  13–14 ms against 7.4 ms for the first, in both trees. Unexplained.

Harness notes for later script authors: `zpty` is blocking unless started
with `-b`, so `zpty -r` into a parameter can wait for a whole line and
`zpty -t` can block in a read. Here, polling a finished command with
`zpty -t` and then deleting it with `zpty -d 2> /dev/null` also lost the
driver's own standard output and error (consistent with one descriptor being
closed twice); a plain `zpty -d` hang-up, as `prompt-git-render.zsh` uses,
avoids both. ZLE repaints only changed cells inside a screen session, so a
frame marker must be text the new frame writes on several rows that the
previous frame did not show.

## Reproduction

From the repository root, with `<baseline-root>` an immutable `git archive`
copy of the baseline commit and `<candidate-root>` the tree under test; set
`TMPDIR` to a disposable directory. Each command took under seven minutes
here.

```zsh
/bin/zsh -df investigations/benchmarks/isolated-startup.zsh <baseline-root> <candidate-root> 15
/bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <baseline-root> <candidate-root> render 11 40
/bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <baseline-root> <candidate-root> fresh 15
/bin/zsh -df investigations/benchmarks/prompt-git-render.zsh <baseline-root> <candidate-root> pty 11 15
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> browse,history,review 11 5
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> browse-large,search 11 5
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> search-large 11 5
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> search-git,review-changes 11 5
```

Add `BENCH_TRACE=<directory>` to the frame benchmark to keep each measured
frame's stripped text; a "missing marker" failure writes the frame it saw to
`missing.txt` there.

## Audit summary

Nine auditors each read one area in full, reproduced every finding in
disposable homes and repositories, and proposed a failing test and a fix. One
adversarial verifier per finding then reran the evidence and checked it
against the contracts. The verifiers confirmed all 82 findings, rejected
none, and corrected severities or fixes where their reproduction disagreed.
For example, USB-01 moved from critical to high, and BOOT-01, BOOT-02 and
SUPPORT-05 moved down to low. A planner then turned the findings into units.
The audit, verification and planning phases took 6.7 h and 93 agents.

| Area | Findings | High / medium / low | Merges and groupings | Owner decision | Skipped |
| --- | ---: | :---: | --- | --- | --- |
| Bootstrap and installer | 8 | 0 / 0 / 8 | BOOT-01 grouped with BOOT-05 in U09 | — | — |
| Living prompt and editing | 10 | 0 / 4 / 6 | — | PROMPT-03 (OD1) | PROMPT-04, PROMPT-07 |
| Shared support | 8 | 0 / 5 / 3 | — | — | — |
| Git workspaces | 7 | 1 / 3 / 3 | GIT-07 merged into USB-11 | — | GIT-05 |
| Filesystem workspace | 10 | 1 / 4 / 5 | FS-09 split (U41 behavior, U77 refactor) | — | — |
| Xcode workspace | 8 | 0 / 2 / 6 | XCODE-03 absorbs CROSS-09 | — | XCODE-05 |
| External devices | 11 | 2 / 3 / 6 | USB-11 absorbs GIT-07 | USB-06 (OD3) | USB-07, USB-08 |
| Help and small peers | 10 | 0 / 1 / 9 | — | HELP-02 (OD2) | HELP-03, HELP-04 |
| Cross-cutting | 10 | 1 / 2 / 7 | CROSS-09 merged into XCODE-03; CROSS-03 split (U23, U24) | — | CROSS-02 |
| **Total** | **82** | **5 / 24 / 53** | 2 merges, 1 grouping, 2 splits, no drops | 3 | 9 |

The five high findings were all fixed:

- GIT-01: a repository-configured signature verifier ran during review and
  bare `g`.
- FS-01: Spotlight Search at `/` discarded every result.
- USB-01: the `createinstallmedia` signature gate accepted ad-hoc-signed
  bundles.
- USB-02: APFS image sources left their physical disk eligible for erasing.
- CROSS-01: the Git syntax poll was quadratic and froze input.

Units ran in this order:

- U01 and U02 first: test-only isolation of Git and of open/pbcopy, which
  protects every later unit's test runs.
- Then security, correctness, invariant, performance and simplification
  units.
- The owner-decision units once answered: U79 and U80 at the start of batch
  3, and U81 last ([run notes](#run-notes)).

## Commits

`git log main..HEAD`, oldest first. *Unit* names the plan unit and its
findings; T01–T07 are the final review's fix tasks. Test counts are cases
added or changed; existing tests that only moved to new helpers are summarized.

| Commit | Subject | Unit | Category | Tests added or changed |
| --- | --- | --- | --- | --- |
| `abefd6b` | Record excellence baseline measurements | Phase 1 | record | benchmarks `isolated-startup.zsh`, `workspace-first-frame.zsh` |
| `cf0d52b` | Isolate runner-level Git fixtures from inherited Git config | U01 (CROSS-04) | invariant (tests) | runner isolates fixture Git from inherited selectors and config |
| `9dab051` | Make the shared search-session test helper fail closed on effects | U02 (CROSS-07) | invariant (tests) | search session never resolves system `open`/`pbcopy`; three callers pass fakes |
| `17bbfe4` | Disable commit-signature verification in Git review and branch captures | U03 (GIT-01) | security | configured verifier never runs; `g --help` fact |
| `aea7af0` | Require a caller-owned Apple code requirement before createinstallmedia | U04 (USB-01) | security | rejects self-declared, path-borne and Developer ID requirements |
| `99da6aa` | Replace UTF-8-encoded C1 controls in the shared sanitizer in every locale | U05 (SUPPORT-04) | security | encoded C1 replaced under C, US-ASCII and UTF-8 |
| `b45eae1` | Keep assignment values out of the running-command terminal title | U06 (PROMPT-02) | security | PTY: title omits assignment values, fails closed |
| `f2222c3` | Refuse a relative ZSH_LOCAL_INIT instead of sourcing it from cwd | U07 (BOOT-04) | security | `security:` relative initializer never sourced |
| `d3efe89` | Stage Xcode skill export under a disclosed compozsh temporary name | U08 (XCODE-06) | security | staging name and cleanup; `docs:` residue disclosure |
| `4d3131c` | Roll back interrupted installs and stage copy files under compozsh name | U09 (BOOT-01, BOOT-05) | security | six interrupt and rollback cases; `security:` installer temporary names |
| `1d1b765` | Keep Spotlight results when Search descendants runs at the filesystem root | U10 (FS-01) | correctness | Spotlight at `/` keeps in-scope results |
| `0c09099` | Resolve APFS image sources to their physical store disks | U11 (USB-02) | correctness | store resolution; fail-closed store cases |
| `19c2399` | Keep bounded-capture truncation when the cut lands on newlines | U12 (SUPPORT-01) | correctness | newline cuts; Git review caller case |
| `be985d5` | Keep blank context lines in Git review under diff.suppressBlankEmpty | U13 (GIT-04) | correctness | exact line numbers with the option set |
| `1de409e` | Report a failed filesystem catalog capture from external-device --format | U14 (USB-03) | correctness | catalog failure reported (unit and PTY) |
| `c327a3a` | Skip nested .git metadata at any depth in the filesystem search walk | U15 (FS-04) | correctness | nested `.git` skipped and counted |
| `98d43a9` | Derive Git-search parent folders when exclusion rejects files | U16 (FS-03) | correctness | folders kept when the exclusion removes their files |
| `ee9ed53` | Split picker label and syntax spans on an explicit separator | U17 (SUPPORT-02) | correctness | repaint under empty `IFS`; PTY resize |
| `a086c75` | Let the Git wrapper defer color enablement to the user | U18 (HELP-01) | correctness | PTY: four `color.ui` modes; pipes byte-identical |
| `ea44686` | Clear the unaccepted autosuggestion at every line finish | U19 (PROMPT-01) | correctness | PTY: PS2 and prompt-less journeys |
| `28cc67c` | Delegate a missing folder ending in / and keep Recents on vanished entries | U20 (FS-02) | correctness | three: delegated Tab, vanished child, Recents |
| `3b98c36` | Reap the Git auto-refresh worker without consuming unrelated job records | U21 (GIT-03) | correctness | unrelated job records kept; shared reaper entry |
| `0f0ffb3` | Reap Xcode children without sweeping unrelated job records | U22 (XCODE-01) | correctness | job lifecycle in three modes |
| `57c13d8` | Stop deadline PTY waits from failing on silence or spinning on exit | U23 (CROSS-03) | correctness (tests) | four wait loops reshaped, assertions unchanged |
| `b1935eb` | Add a deadline-based PTY expectation helper and migrate test readers | U24 (CROSS-03) | correctness (tests) | nine helper cases; 58 drivers migrated |
| `4dee83c` | Rewrite the starter initializer's guarded examples in if form | U25 (BOOT-06) | correctness | starter examples with false guards |
| `a479911` | Stamp installer backups from the clock, not an inherited EPOCHSECONDS | U26 (BOOT-08) | correctness | backup names under a hostile `EPOCHSECONDS` |
| `78be007` | State the effective history limits and drop the unreachable defaults | U27 (BOOT-02) | correctness | stock limits kept; `docs:` HISTSIZE bound |
| `f85af82` | Let NO_COLOR at startup keep Compozsh from enabling listing colors | U28 (BOOT-07) | correctness | `NO_COLOR` leaves `CLICOLOR` unset |
| `b851666` | Guard every public function definition against a same-name alias | U29 (PROMPT-08) | correctness | three peers load after same-name aliases |
| `cd61e3c` | Run the autosuggestion accept widgets under emulate -L zsh | U30 (PROMPT-06) | correctness | accept widgets under unusual caller options |
| `8e4eb28` | Record the first-prompt help-capture fork cost | U80 (HELP-02, OD2) | performance (record) | benchmark `help-first-prompt.zsh` |
| `46d3882` | Key the prompt Git-directory cache on the nearest .git marker too | U31 (PROMPT-05) | correctness | operation state follows a new repository |
| `952f34e` | Make mkcd enter the directory it creates for stack-reference names | U32 (HELP-05) | correctness | `mkcd` for `-`, `-N`, `+N` |
| `b641147` | Title the help workspace with the selected tool, not a notice word | U33 (HELP-06) | correctness | explorer titles notices with the tool |
| `f55617a` | State compozsh --refresh as a two-space option line so its ACTION is captured | U34 (HELP-09) | correctness | refresh ACTION assertion |
| `8e048f9` | Restore native man pager precedence and gate grep and man colors | U35 (HELP-10) | correctness | three: pager precedence, man and grep color gates |
| `ed83cca` | Sanitize caller-owned keyboard-guide context lines like every other row | U36 (SUPPORT-08) | correctness | guide context lines sanitized |
| `2c5460d` | Label the folder preview's 40-entry filesystem-order sample truthfully | U37 (FS-10) | correctness | preview Limits note (extended) |
| `11ec595` | Spell dash- and tilde-prefixed bare-level Browse children with ./ | U38 (FS-07) | correctness | `-` and `~` children entered |
| `12ea98f` | Slice path-argument Tab and resolve paths independent of KSH_ARRAYS | U39 (FS-08) | correctness | path Tab under `KSH_ARRAYS` |
| `392ec62` | Report stale or unavailable file actions with one ZLE message | U40 (FS-06) | correctness | seven stale-action cases |
| `d38a70d` | Refuse Search Change directory on a folder that has since become a link | U41 (FS-09) | correctness | folder replaced by a link refused |
| `f68a882` | Describe the log-reader-first Run flow in Xcode Run destination text | U42 (XCODE-04) | correctness | destination text pins (extended) |
| `d35281c` | Export Simulator child environment only to launch and log stream | U43 (XCODE-02) | correctness | child-environment spies (two extended) |
| `b6858b9` | Name shared support components instead of retired peers in diagnostics | U44 (USB-11, GIT-07) | correctness | USB and `g --review` diagnostics |
| `46378c1` | Rename USB locals named path so children keep PATH and the command hash | U45 (USB-10) | correctness | 17 helpers keep `PATH` and the hash table |
| `039c99a` | End signalled test subshells after cleanup instead of continuing | U46 (CROSS-06) | correctness (tests) | runner ends a signalled test |
| `aa4cb1f` | Settle two PTY tests on child-emitted events, not wall-clock windows | U47 (CROSS-10) | correctness (tests) | two tests on child events, assertions unchanged |
| `b8fb3a4` | Scope the painted picker frame to the screen session | U48 (SUPPORT-03) | invariant | frame released on every exit |
| `e2537b1` | Scope external-device disk, image and writer state to the invocation | U49 (USB-04) | invariant | `_USB_*` snapshot unchanged after three runs |
| `175dd81` | Disclose that opening g reads remote-tracking names once | U50 (GIT-06) | invariant (docs) | none |
| `6882b22` | Clear help summaries and options on compozsh --refresh | U51 (HELP-08) | invariant | refresh clears help maps (two extended) |
| `198ce9e` | Scope the tool-explorer catalog to the compozsh invocation | U52 (HELP-07) | invariant | catalog released after `compozsh` |
| `3ede7d8` | Redraw on Ctrl-L with builtin widgets and never clear the main screen | U53 (SUPPORT-05) | invariant | PTY: Ctrl-L under xterm-256color and vt100 |
| `677a473` | Recapture prompt facts after an in-widget directory change | U79 (PROMPT-03, OD1) | correctness | two PTY recapture journeys |
| `9da2047` | Render media-attention and macOS-review facts as passive rows | U54 (USB-09) | invariant | only actions indexed |
| `3b05210` | Discover peers under fixed Zsh options | U55 (BOOT-03) | invariant | discovery ignores glob options |
| `d77f39a` | Make re-source and diagnostics-free load checks read stderr | U56 (CROSS-05) | invariant (tests) | verify fails on load diagnostics; two tightened |
| `a08c1b7` | Advance the Git syntax session buffer by offset, not a prefix strip | U57 (CROSS-01) | performance | two cases; `git-syntax-poll.zsh` |
| `b22005a` | Strip the bounded-capture status suffix literally | U58 (GIT-02) | performance | two cases; `bounded-capture.zsh` |
| `ca9d1fb` | Use the ASCII byte path for every document when wrapping inspector lines | U59 (SUPPORT-06) | performance | geometry oracle, byte-path count; `inspect-wrap.zsh` |
| `41ab17a` | Parse Xcode scheme lists with one split instead of a quadratic rescan | U60 (XCODE-03, CROSS-09) | performance | four cases; `xcode-scheme-parse.zsh` |
| `30da8fe` | Read Git and Spotlight provider streams in chunks and prefilter in memory | U61 (FS-05) | performance | three cases; `file-search-stream.zsh` |
| `c7a6045` | Delete the unreachable USB read-back fallback and fail closed | U71 (USB-05) | simplification | incomplete evidence fails closed; 20 dead-path cases deleted |
| `354be67` | Drop the dead KEYTIMEOUT default so an initializer unset survives | U72 (PROMPT-09) | simplification | `unset KEYTIMEOUT` survives |
| `4ec2f1e` | Remove write-only legacy prompt globals and dead layout wrapper | U73 (PROMPT-10) | simplification | none (two expectations follow the removals) |
| `8d714ed` | Delete the never-called matching_search support entry | U74 (SUPPORT-07) | simplification | matching tests rewritten without it |
| `b3e853b` | Sanitize Xcode copy reports with one native pattern substitution | U75 (XCODE-08) | simplification | copy-report sanitization |
| `6c102ed` | Centralize the Xcode capture-limit validation in one peer-private helper | U76 (XCODE-07) | simplification | helper over 18 inputs; hostile discovery guard |
| `5776160` | Run the search test seam through the production file-action dispatcher | U77 (FS-09) | simplification | seam inserts through the dispatcher |
| `d838ecf` | Load shared support in child test scripts through test_source_support | U78 (CROSS-08) | simplification (tests) | loader and subset guard; 242 child scripts migrated |
| `7541987` | Delete the retired Windows writer and its FAT32 round trip | U81 (USB-06, OD3) | simplification | `USB ships no retired Windows writer`; 20 writer-only cases deleted |
| `3cd7f10` | Refuse installer destinations that appear after the plan | T01 (SEC-A-01) | security | two: appeared `compozsh` entry, appeared `.zshrc` |
| `4708e97` | Limit the README file-action recheck claim to the actions that recheck | T02 (SEC-B-01) | docs | none |
| `bf0d523` | Drop the dead numeric metadata audit filter and guard the table | T03 (SEC-C-01, CON-C-01) | docs | `docs:` every SECURITY focused filter selects a test |
| `227f6b0` | Name shared support components in xcode --export-skills help | T04 (CON-C-04) | correctness | export help names support components |
| `f80a680` | Catch per-file UI support preambles and scope the subset rule | T05 (CON-C-02) | tests | widened subset scan; six subset markers |
| `258d2eb` | Record owner decisions OD1 and OD3 in the excellence record | T06 (CON-A-01, CON-C-10) | record | none |
| `1a8b868` | Propose the CLAUDE.md suite-note update and annotate the FAT32 baseline | T07 (CON-C-03) | record | none |
| this commit | Complete the excellence run record | Phase 5 | record | none |

## Tests

| Point | Commit | Passed | Failed | Time |
| --- | --- | ---: | ---: | ---: |
| Phase 1 baseline | `36cdcda` | 960 | 1 | 234.2 s |
| Gate after U30 | `cd61e3c` | 1,012 | 1 | 245.5 s |
| After U53 (orchestrator) | `3ede7d8` | 1,031 | 1 | 250.1 s |
| After U79 (orchestrator) | `677a473` | 1,033 | 1 | — |
| After U81 (orchestrator) | `7541987` | 1,018 | 0 | — |
| After T01 | `3cd7f10` | 1,020 | 0 | 227 s |
| After T04 | `227f6b0` | 1,022 | 0 | 228.1 s |
| **Final** | `1a8b868` | **1,022** | **0** | **227.8 s** |

Until `7541987`, the one failure was always `USB Windows verifier round-trips
and detects corruption on real FAT32`, the known real-FAT32 `hdiutil` round
trip, which went with the retired writer
([OD3](#od3-delete-the-retired-windows-writer-usb-06)). The final run printed
no `FAIL` line, and the Xcode Logger cleanup timing tests did not flake in the
final review's full runs, so nothing was rerun. `zsh tests/verify.zsh` gave syntax ok,
whitespace ok and re-source ok.

The net change is 61 cases (961 → 1,022):

- Every behavior fix added or tightened tests.
- U71 and U81 deleted 40 cases that exercised only unreachable USB code.
- U24 and U78 moved 58 PTY drivers and 242 child scripts onto shared helpers
  without changing assertions.

One stderr line in the final run fails no test:
`tests/support.zsh:6: read-only variable: TEST_ZSH_BIN`. It comes from
`filesystem workspace replaces d and f without stealing ordinary editing
keys` (`tests/files_workspace_test.zsh:9–12`), which sources
`tests/support.zsh` inside a two-pass `TERM` loop, so the second
`typeset -gr TEST_ZSH_BIN` is refused. It started with `d838ecf`.
*Proposal:* move the source and `test_source_support` call above the loop.

## Performance results

### Final comparison: main against the branch

Every Phase 1 metric was rerun with the [method](#method) above, using the
same scripts (unchanged since `abefd6b`) and the same machine. The baseline
was the immutable `36cdcda` copy and the candidate the working tree at
`1a8b868`. Conditions were `en_US.UTF-8`, Zsh 5.9, Git 2.54.0 and 140×40,
with the trees alternating run by run. Load was 2.6–3.4 from other processes;
nothing else from this run was active.

Before timing frames, a marker check traced every scenario. Both trees
painted byte-identical stripped frames, fresh and warm, so only timing
differs. Startup and the local Search frames ran a second time to check
direction.

Milliseconds; median (min–max). *Verdict* uses the Phase 1
[proposal](#measurements): a change is clearly beyond noise when it moves by
more than three times that metric's A/A delta and by more than the larger of
2% and 1 ms, and a second invocation repeats the direction. *Faster, below
rule* repeated but missed one condition. *Borderline* passed in the second
invocation only.

| Metric | Mode | Runs | Before (`36cdcda`) | After (`1a8b868`) | Δ | Verdict |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| Startup process | fresh | 15 | 221.99 (219.97–225.53) | 219.17 (218.12–220.98) | −1.3% | noise |
| Startup process | warm | 15 | 72.35 (72.03–73.56) | 69.74 (69.30–70.47) | −3.6% | faster |
| Startup source | fresh | 15 | 216.68 (214.63–220.31) | 214.00 (212.79–215.68) | −1.2% | noise |
| Startup source | warm | 15 | 66.75 (66.40–67.68) | 64.03 (63.80–64.84) | −4.1% | faster |
| Startup editable | fresh | 15 | 240.22 (238.58–243.56) | 238.00 (236.35–243.48) | −0.9% | noise |
| Startup editable | warm | 15 | 98.82 (97.57–102.60) | 95.97 (95.21–99.55) | −2.9% | faster, below rule |
| Startup tty-source | fresh | 15 | 207.13 (205.94–209.06) | 204.46 (203.61–209.48) | −1.3% | noise |
| Startup tty-source | warm | 15 | 65.62 (65.24–67.36) | 62.82 (62.55–64.23) | −4.3% | faster, below rule |
| Prompt render, outside | render | 11×40 | 5.02 (5.00–5.06) | 5.07 (5.05–5.09) | +0.9% | noise |
| Prompt render, clean | render | 11×40 | 24.96 (24.86–25.21) | 25.10 (24.27–25.34) | +0.6% | noise |
| Prompt render, dirty | render | 11×40 | 27.16 (27.05–27.26) | 27.27 (26.42–27.35) | +0.4% | noise |
| Prompt render, large | render | 11×40 | 47.71 (47.11–48.38) | 47.85 (46.18–48.53) | +0.3% | noise |
| Prompt render, outside | fresh | 15 | 5.36 (5.32–5.86) | 5.39 (5.34–5.60) | +0.4% | noise |
| Prompt render, clean | fresh | 15 | 34.02 (33.61–80.22) | 34.40 (33.85–35.72) | +1.1% | noise |
| Prompt render, dirty | fresh | 15 | 36.13 (35.63–36.79) | 36.14 (35.68–37.47) | +0.0% | noise |
| Prompt render, large | fresh | 15 | 55.19 (54.51–56.97) | 56.00 (54.48–58.30) | +1.5% | noise |
| Prompt Return, outside | pty | 11×15 | 8.00 (7.69–8.09) | 8.09 (7.75–8.15) | +1.2% | noise |
| Prompt Return, clean | pty | 11×15 | 28.11 (27.01–28.32) | 28.24 (27.11–28.39) | +0.5% | noise |
| Prompt Return, dirty | pty | 11×15 | 30.38 (30.13–30.75) | 30.42 (29.23–30.73) | +0.1% | noise |
| Prompt Return, large | pty | 11×15 | 50.49 (47.60–51.35) | 50.55 (48.39–51.65) | +0.1% | noise |
| Frame browse | fresh | 11 | 74.69 (74.41–75.23) | 74.83 (74.62–75.86) | +0.2% | noise |
| Frame browse | warm | 11×5 | 73.88 (73.58–74.25) | 74.14 (73.79–74.49) | +0.3% | noise |
| Frame browse-large | fresh | 11 | 846.43 (842.98–849.78) | 843.69 (841.33–850.72) | −0.3% | noise |
| Frame browse-large | warm | 11×5 | 843.46 (840.79–845.32) | 843.86 (841.29–845.72) | +0.0% | noise |
| Frame search | fresh | 11 | 509.78 (505.85–514.96) | 500.08 (497.50–507.13) | −1.9% | faster, below rule |
| Frame search | warm | 11×5 | 489.81 (487.92–498.96) | 481.96 (479.80–485.91) | −1.6% | borderline |
| Frame search-large | fresh | 11 | 950.38 (944.08–956.78) | 948.40 (938.52–953.72) | −0.2% | noise |
| Frame search-large | warm | 11×5 | 951.51 (949.74–954.06) | 948.00 (946.38–953.16) | −0.4% | noise |
| Frame search-git | fresh | 11 | 201.11 (193.18–217.71) | 106.17 (98.90–116.35) | −47.2% | faster |
| Frame search-git | warm | 11×5 | 198.88 (197.69–215.09) | 103.23 (101.75–122.08) | −48.1% | faster |
| Frame history | fresh | 11 | 5.64 (5.54–13.80) | 5.63 (5.48–5.71) | −0.2% | noise |
| Frame history | warm | 11×5 | 12.39 (12.25–12.66) | 12.32 (12.20–12.53) | −0.6% | noise |
| Frame review | fresh | 11 | 50.59 (50.32–53.06) | 51.07 (50.10–55.79) | +1.0% | noise |
| Frame review | warm | 11×5 | 49.42 (48.93–49.95) | 49.62 (49.13–50.75) | +0.4% | noise |
| Frame review-changes | fresh | 11 | 103.79 (99.13–107.83) | 103.15 (102.53–123.50) | −0.6% | noise |
| Frame review-changes | warm | 11×5 | 100.77 (99.86–101.21) | 100.20 (99.63–118.96) | −0.6% | noise |

- **Git-source Search.** About 95 ms faster, with ranges that do not overlap.
  A traced run repeated it: 200.0 → 105.8 ms fresh and 203.9 → 100.2 ms warm.
  Both trees painted 300 candidates. Measured alone from `41ab17a`, U61 cut
  31.5–32.9% of this frame ([below](#file-search-provider-streams-fs-05)).
  The rest predates it, plausibly from U16's capture-local visited-folder set
  (see [other measurements](#other-measurements-recorded-by-fix-units)). That
  attribution is an inference; no separate run measured it.
- **Warm startup.** All four warm modes are 2.6–2.8 ms faster, and the second
  invocation repeated it at 2.70–2.87 ms. *process* and *source* pass the
  rule. *editable* and *tty-source* moved only 1.7–1.9 times their A/A deltas.
  Fresh modes moved 2.2–2.8 ms, within noise.
  *Caveat:* in Phase 1's A/A run, the working-tree copy was faster than the
  identical baseline copy in every startup mode (by 0.34–3.63 ms), so part of
  this shift may come from where each tree sits. Subtracting the warm A/A
  deltas still leaves about 2.1 ms (process) and 2.4 ms (source). No single
  commit is credited.
- **Local Search.** 8–10 ms faster (−1.6% to −2.1%) across two invocations.
  The second gave −8.87 ms fresh and −10.31 ms warm, with warm ranges that do
  not overlap.
- **No regression beyond noise.** The largest slowdown is the fresh large
  prompt, +0.81 ms (+1.5%), under the 1 ms floor with overlapping ranges.
- **Drift.** Absolute medians moved since Phase 1 on both trees (uptime 5
  days, load about 3). For example, prompt render outside went 4.11 → 5.02 ms,
  frame review 65.3 → 50.6 ms, review-changes 122.1 → 103.8 ms and
  browse-large 809 → 846 ms. Compare only within a run.

Reproduce with the Phase 1 [commands](#reproduction), using a `git archive`
of `36cdcda` as `<baseline-root>` and the tree at `1a8b868` as
`<candidate-root>`. Raw outputs and traces are kept with the run's local
artifacts (not distributed).

The sections below are the per-unit measurements, recorded as each
performance unit landed.

### Git syntax response cut (CROSS-01)

`_git_syntax_session_poll` removed each completed response from the session
buffer with `${buffer#*"$suffix"}`. That shortest-prefix search is quadratic
in the suffix position, and Git review runs the poll inside the picker's
input-idle callback, so keys waited for it
([git](../engineering/workspaces/git.md#syntax-highlighting): parsing never
blocks input). The poll now advances by offset, `${#packet} + ${#suffix}`
characters, because `packet` already ends at that first suffix. The
remainder is the same; a test pins it, including a multibyte character
under UTF-8.

Measured with [`benchmarks/git-syntax-poll.zsh`](benchmarks/git-syntax-poll.zsh)
on the machine above (load 2.3–4.5). The baseline is a `git archive` of
`d77f39a`; the candidate is the working tree. The two trees alternate run by
run, with one new `zsh -df` child per sample. *Synthetic* buffers one framed
response of N spans in the real `row start end role` format. *Vim* runs a
real resident `/usr/bin/vim` over rows 1–280 of `.zsh.addons/.zsh.git-review`
(a 40-row viewport plus three spans each side), rows 1–598 (an 86-row
viewport plus the 256-row guard each side) and 280 rows of ordinary dense
JSON. The clock covers only the poll call that completes the response.
Medians (min–max) in ms over 10 runs, `en_US.UTF-8`:

| Workload | Spans | Before | After | Δ |
| --- | ---: | ---: | ---: | ---: |
| Synthetic | 500 | 159.51 (155.23–171.05) | 0.66 (0.59–0.70) | −99.6% |
| Synthetic | 1,000 | 630.60 (606.78–654.88) | 0.95 (0.92–1.15) | −99.8% |
| Synthetic | 2,000 | 2,493.52 (2,411.56–2,555.28) | 1.62 (1.53–1.85) | −99.9% |
| Synthetic | 4,096 | 10,393.87 (10,027.66–10,630.80) | 3.01 (2.91–3.24) | −100.0% |
| Vim, Zsh, 280 rows | 617 | 204.40 (203.68–206.90) | 0.65 (0.62–0.72) | −99.7% |
| Vim, Zsh, 598 rows | 1,488 | 1,206.13 (1,201.73–1,214.30) | 1.24 (1.17–1.33) | −99.9% |
| Vim, JSON, 280 rows | 3,641 | 7,212.53 (7,202.65–7,231.88) | 3.21 (3.11–3.31) | −100.0% |

A second invocation of 5 runs repeated the result. Vim under UTF-8 gave
204.53 → 0.66, 1,205.37 → 1.32 and 7,228.44 → 3.32 ms. Synthetic under
`LC_ALL=C` gave 164.07 → 0.69 and 10,522.15 → 3.15 ms at 500 and 4,096
spans, so the cost never depended on the locale. Ranges never overlap. The
remaining cost grows linearly with the response.

The end-to-end frame benchmark can't see this path. Its review scenarios stop
at the chooser and the file list, before any syntax response. It served as
the no-regression check (`review,review-changes 11 5`, medians in ms, before
→ after):

- review: fresh 63.35 → 64.69, warm 60.82 → 72.00 (ranges 59.07–75.03 and
  59.23–78.64).
- review-changes: fresh 113.80 → 115.20, warm 111.10 → 110.61.

The warm review gap did not repeat in a second invocation, which gave
75.98 → 76.42 at load 4.0–4.5. That is within the 6% A/A noise of that
frame.

Decision: kept. Reproduce from the repository root with a disposable
`TMPDIR`:

```zsh
/bin/zsh -df investigations/benchmarks/git-syntax-poll.zsh <baseline-root> <candidate-root> 10 synthetic
/bin/zsh -df investigations/benchmarks/git-syntax-poll.zsh <baseline-root> <candidate-root> 10 vim
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> review,review-changes 11 5
```

Not changed here: the audit measured `_git_syntax_apply` at about 127 ms for
the 3,641 JSON spans on the same callback. That cost is linear but above a
frame budget (a follow-up candidate).

### Bounded capture status strip (GIT-02)

`_compozsh_capture_bounded`, the shared entry behind every foreground Git
workspace capture, removed the private NUL/status suffix with
`${packet%$'\0'*}`. That shortest-suffix glob strip is quadratic in the number
of NULs, and Git packets are NUL-dense: bare `g` reads remote-tracking refs
with three NUL fields per ref, and review reads `status -z`. The entry now
removes NUL plus the already validated status literally. The result is the
same because the status is exactly the text after the last NUL; tests pin
payload tails that look like a status and the linear scaling.

Measured with [`benchmarks/bounded-capture.zsh`](benchmarks/bounded-capture.zsh)
(load 3.4–3.6). The baseline is a `git archive` of `a08c1b7`; the candidate is
the working tree. Trees alternate run by run, one new `zsh -df` child per
sample, one untimed warm-up call, then one timed call. Medians (min–max) in ms
over 11 runs, `en_US.UTF-8`:

| Workload | Records | Before | After | Δ |
| --- | ---: | ---: | ---: | ---: |
| Synthetic packet | 2,000 | 113.56 (110.85–115.19) | 3.85 (3.65–4.01) | −96.6% |
| Synthetic packet | 8,000 | 1,726.72 (1,703.34–1,745.74) | 12.99 (12.45–13.41) | −99.2% |
| Bare-`g` remote refs | 999 | 281.50 (275.23–288.41) | 59.64 (58.69–69.48) | −78.8% |
| Review file list, untracked | 4,000 | 202.21 (199.35–207.21) | 29.71 (28.20–30.78) | −85.3% |

Ranges never overlap. The remaining cost is Git itself plus linear parsing.

The end-to-end frame benchmark's Git fixtures are small, so it served as the
no-regression check (`search-git,review-changes 11 5`, load 2.7–3.4, medians
in ms, before → after):

- search-git: fresh 186.09 → 185.81, warm 183.25 → 182.68.
- review-changes: fresh 120.17 → 122.15, warm 119.19 → 118.93.

The ranges overlap almost entirely. The largest median gap, +1.98 ms (1.6%)
on fresh review-changes, is the size of that frame's A/A delta (1.1–2.0%).

Decision: kept. Reproduce from the repository root with a disposable
`TMPDIR`:

```zsh
/bin/zsh -df investigations/benchmarks/bounded-capture.zsh <baseline-root> <candidate-root> 11
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> search-git,review-changes 11 5
```

### Inspector document wrapping (SUPPORT-06)

`_zle_picker_inspect_prepare` wraps a document line into width-1-cell rows
until at most `width` cells remain. Only reader-only documents (the Xcode log
reader) sliced printable ASCII by bytes. Git review documents passed the whole
remainder to `_compozsh_cell_prefix` for every row, then copied and re-measured
it. Each wrap was quadratic in line length. Git review caps a diff at 256 KiB
but has no per-line cap, so one minified bundle, source map or one-line JSON
reaches this path. It runs synchronously on selection, resize and syntax-status
changes, so input waits for it. The byte path now applies to every document.
Document rows never word-wrap, and for printable ASCII the cell prefix is
exactly the first width-1 characters, so rows, roles, the source map and
syntax slices are unchanged. A new characterization test pins that geometry
against an in-test oracle at widths 2, 3, 40 and 100, including the
20,000-row bound reached mid-line. A second test counts cell-prefix calls
(40 before, 0 after, for a 4,000-character line at width 100).

Measured with [`benchmarks/inspect-wrap.zsh`](benchmarks/inspect-wrap.zsh)
(load 2.9–3.8). The baseline is a `git archive` of `b22005a`; the candidate is
the working tree. Trees alternate run by run, one new `zsh -df` child per
sample, one untimed warm-up on a short line, then one timed prepare at width
100. Medians (min–max) in ms over 10 runs, `en_US.UTF-8`:

| Workload | Rows | Before | After | Δ |
| --- | ---: | ---: | ---: | ---: |
| Git review document, 16 KiB line | 166 | 43.81 (42.45–45.83) | 8.51 (8.01–9.06) | −80.6% |
| Git review document, 64 KiB line | 662 | 611.16 (586.88–626.43) | 91.58 (83.55–94.38) | −85.0% |
| Git review document, 262,000-byte line | 2,647 | 9,325.73 (9,006.83–9,370.70) | 1,251.65 (1,194.21–1,345.80) | −86.6% |
| Reader-only document, 64 KiB line (control) | 662 | 89.01 (74.90–94.25) | 91.10 (84.66–97.73) | +2.3% |

The document ranges never overlap, and the row counts match. The control
already took the byte path, so it is unchanged within noise. The remaining
cost is still quadratic, because each byte slice walks the string. A linear
chunker that keeps the final row at up to `width` cells is a follow-up
candidate; the new geometry test guards it.

The end-to-end frame benchmark's review scenario stops at the file list,
before any long diff line. It served as the no-regression check
(`review 11 5`, load 3.0–3.3, medians in ms, before → after):

- review: fresh 80.19 → 80.29, warm 77.96 → 75.47 (ranges 74.71–82.73 and
  72.87–78.29).

That is within the frame's A/A noise (up to 6.2%).

Decision: kept. Reproduce from the repository root with a disposable
`TMPDIR`:

```zsh
/bin/zsh -df investigations/benchmarks/inspect-wrap.zsh <baseline-root> <candidate-root> 10
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> review 11 5
```

### Xcode scheme list parse (XCODE-03, CROSS-09)

`_xcode_plist_string_array_parse` turns plutil's XML conversion of
`xcodebuild -list -json` into the scheme catalog. It looped while the rest of
the XML still matched `*<string>*</string>*` and copied that rest twice per
value, so the cost was the number of schemes times the XML size. Discovery
runs it in the foreground after the 'Loading schemes' capture, and the
[Xcode contract](../engineering/workspaces/xcode.md#entry-and-discovery)
accepts up to 4,096 schemes, so a large or hostile workspace froze the screen
for seconds behind the last discovery frame. The parse now splits once on
`<string>`, requires exactly one value per reported scheme up front, and
decodes each value on its own. Names are unchanged; tests pin the decoded
names, the count rules, markup-like names through real plutil and the
4,096-scheme bound. Two malformed shapes plutil never emits now fail closed: an
unclosed trailing value no longer goes uncounted, and no failure leaves a
partial reply (the caller already discarded it).

Measured with [`benchmarks/xcode-scheme-parse.zsh`](benchmarks/xcode-scheme-parse.zsh)
(load 2.5–3.8). The baseline is a `git archive` of `ca9d1fb`; the candidate is
the working tree. Trees alternate run by run, one new `zsh -df` child per
sample, one untimed warm-up parse of two names, then one timed call over the
real `/usr/bin/plutil` conversion. *Capture* is one complete
`_xcode_schemes_capture` through a fake `xcodebuild` that prints the JSON, the
closest end-to-end metric (no workspace benchmark reaches Xcode discovery).
Medians (min–max) in ms over 10 runs, `en_US.UTF-8`:

| Workload | Schemes | Before | After | Δ |
| --- | ---: | ---: | ---: | ---: |
| Parse, realistic names | 1,024 | 436.85 (426.25–456.95) | 14.69 (14.47–15.57) | −96.6% |
| Parse, realistic names | 4,096 | 6,725.18 (6,552.30–6,862.84) | 62.93 (62.50–67.01) | −99.1% |
| Parse, 56 `&` per name (302 KiB XML) | 1,024 | 3,465.29 (3,400.70–3,570.02) | 48.02 (47.10–49.14) | −98.6% |
| Capture, realistic names | 4,096 | 6,784.96 (6,737.75–7,168.67) | 105.06 (102.63–108.95) | −98.5% |

A second invocation of 4 runs under `LC_ALL=C` repeated the result:
438.85 → 15.12, 6,730.65 → 62.51, 3,459.31 → 48.94 and 6,764.63 → 105.18 ms.
Ranges never overlap. The remaining cost grows linearly with the conversion;
the entity-dense worst case at 4,096 names, which the audit put near 50 s of
CPU, extrapolates to about 0.2 s (an estimate from the 1,024-name row, not
measured).

Decision: kept. Reproduce from the repository root with a disposable
`TMPDIR`:

```zsh
/bin/zsh -df investigations/benchmarks/xcode-scheme-parse.zsh <baseline-root> <candidate-root> 10
/bin/zsh -df investigations/benchmarks/xcode-scheme-parse.zsh <baseline-root> <candidate-root> 4 C
```

### File search provider streams (FS-05)

The Git and Spotlight search providers read their NUL-delimited output with
`IFS= read -r -d ''`, one record per call. On a pipe, Zsh reads one byte
per read(2) so that it never passes the delimiter, so the cost followed the
bytes listed: about 0.34 µs per byte. The Git source lists the whole project
with no visit cap, so the cost grew with repository size behind the busy
frame. Both providers now share `_file_search_stream`. It takes up to
64 KiB per `sysread`, splits the chunk with `(@0)`, carries the cut-off
record into the next read and hands each batch of complete records to the
provider. The trailer protocol is unchanged: an empty record, then the exit
status. A tail cut off at the end is still dropped, and early stop at the
candidate cap still stops reading. The Git batch is prefiltered with
`${(M)…:#pattern}`, which is the same per-record test. Spotlight still matches
the home-relative display text (`~/…`), never the raw path, and now checks it
before any filesystem test. New tests pin records split across reads (more
than 128 KiB of multibyte and newline-bearing names, failure trailer, early
stop) under C and UTF-8, every boundary from 1- to 7-byte reads, and the
Spotlight display match.

Measured with [`benchmarks/file-search-stream.zsh`](benchmarks/file-search-stream.zsh)
(load 2.5–2.7). The baseline is a `git archive` of `41ab17a`; the candidate is
the working tree. Trees alternate run by run, one new `zsh -df` child per
sample, one untimed warm-up call, then one timed capture. Status and result
count match between the trees. Medians (min–max) in ms over 10 runs,
`en_US.UTF-8`:

| Workload | Status/results | Before | After | Δ |
| --- | ---: | ---: | ---: | ---: |
| Git, search-git repository (2,400 paths), `controller` | 0/300 | 100.59 (99.28–101.89) | 68.56 (66.38–72.08) | −31.8% |
| Git, 50,000-path stub list, no matches | 1/0 | 1,307.40 (1,278.33–1,323.95) | 105.89 (104.85–107.20) | −91.9% |
| Spotlight, 5,000 indexed paths, no matches | 1/0 | 532.73 (513.87–539.72) | 71.57 (70.29–72.44) | −86.6% |
| Spotlight, 5,000 indexed paths, `note 42` | 0/780 | 596.69 (585.54–611.14) | 153.45 (150.94–156.39) | −74.3% |

An earlier invocation of 10 runs (load 3.0–3.2), before a one-line guard was
added to the Git batch handler, repeated the result: 100.02 → 68.07,
1,286.25 → 106.08, 531.07 → 72.62 and 593.76 → 152.28 ms.

The end-to-end first-frame benchmark (`search-git 11 5`, load 2.9–3.0, medians
in ms, before → after):

- search-git: fresh 180.54 (175.37–187.70) → 123.60 (120.92–126.98), −31.5%;
  warm 181.25 (179.26–183.09) → 121.59 (116.72–126.70), −32.9%.

Ranges never overlap, and the change is more than a hundred times that
frame's A/A delta (up to 0.48 ms). Both trees painted the populated results
frame (the benchmark's marker); one traced candidate frame read
`300 candidates for controller`, the count both trees captured above.

Decision: kept. Reproduce from the repository root with a disposable
`TMPDIR`:

```zsh
/bin/zsh -df investigations/benchmarks/file-search-stream.zsh <baseline-root> <candidate-root> 10
/bin/zsh -df investigations/benchmarks/workspace-first-frame.zsh <baseline-root> <candidate-root> search-git 11 5
```

### Other measurements recorded by fix units

Three fix units, which were not performance units, measured their effect.
Each compared the tree before and after its change, alternating run by run;
values are medians (min–max) in ms.

**Peer discovery under fixed options (BOOT-03, U55, `3b05210`).** This
change touches the startup path. The no-regression check used
`isolated-startup.zsh` with default options, 15 runs:

| Metric | Before | After | Δ |
| --- | ---: | ---: | ---: |
| Startup process, fresh | 216.53 (211.62–230.71) | 212.75 (208.11–231.72) | −1.7% |
| Startup source, warm | 65.64 (63.58–69.81) | 66.01 (62.33–69.05) | +0.6% |
| Startup editable, warm | 95.58 (94.71–103.81) | 94.86 (93.70–103.65) | −0.8% |
| Startup tty-source, warm | 62.65 (61.78–67.77) | 61.35 (60.98–67.36) | −2.1% |

All four are within the A/A noise above. A scratch script (not kept)
sourced `.zshrc` in-process with a `setopt GLOB_DOTS` initializer and a
4,096-file private `.git` under the user add-on folder. It went
79.46 (78.07–80.91) → 60.06 (59.15–61.01) ms, −24.4%, because hidden folders
are no longer searched. That is a side benefit of the correctness fix.

**Git-search parent folders (FS-03, U16, `98d43a9`).** The unit timed the Git
capture over a throwaway 5,000-file repository, 10 runs, as information only.
The capture-local visited set stops sibling files from rechecking the same
parent folders:

| Workload | Before | After | Δ |
| --- | ---: | ---: | ---: |
| Query `net`, no exclusion | 973.9 (967.6–985.6) | 527.2 (523.8–539.7) | −45.9% |
| Exclusion `Feature1` only | 636.4 (631.0–646.5) | 478.6 (471.7–491.7) | −24.8% |
| Query `Client`, exclusion `Module1` | 574.2 (569.0–586.4) | 375.9 (369.3–386.4) | −34.5% |
| Query `net`, every file excluded | 261.0 (259.2–263.3) | 274.7 (273.9–278.1) | +5.2% |

Results were identical. The last row is the cost of the now-correct ancestor
walk for excluded files.

**In-widget recapture (PROMPT-03, U79, `677a473`).** This change moved
`precmd`'s capture into `_prompt_capture_context`. `prompt-git-render.zsh`
render mode, 11 runs, confirmed that `precmd` did not change:

- outside: 4.45 → 4.46 ms
- clean: 23.02 → 23.03 ms
- dirty: 25.07 → 25.15 ms
- large: 44.32 → 44.48 ms

Every delta is under 0.4%, with overlapping ranges. The in-widget capture
itself has no benchmark scenario; [OD1](#od1-in-widget-directory-change-recaptures-prompt-facts-prompt-03)
estimates it.

### Skipped performance units (U62–U70)

The owner chose a time box after U53: 45 minutes per attempt, with a second
attempt only when the first failed within 20 minutes. Three units hit it and
a fourth was stopped. On 2026-10-13 the owner decided to skip the remaining
performance units to finish sooner. None of these units changed the
repository. Their plans and saved work stay with the run's local artifacts
(not distributed).

| Unit | Finding | Severity | State | Saved work |
| --- | --- | --- | --- | --- |
| U62 | PROMPT-04: project detection rereads folders once per extension | medium | Attempt 1 time-boxed at 178 min, not measured | `U62-a1.patch`: about 190-fixture characterization test (passed before and after, mutation-checked) and the one-listing-per-folder rewrite |
| U63 | GIT-05: remote fallback scans local branches per ref | low | Time-boxed at 49 min | None. The retry plan is an associative set of local names plus a `branch-remote-capture.zsh` benchmark. Zsh looks up expanded keys literally, which was confirmed. |
| U64 | PROMPT-07: highlighter `(Ie)` scans on every redraw | low | Time-boxed at 110 min, mostly gaps between tool calls | `U64-a1-characterization.diff`. Its expected tail must read `6 18`, not `6 20`. |
| U65 | XCODE-05: log collector formats every line twice | low | In progress when batch 4 stopped | `U65-a1-partial.patch`: two log-reader tests, collector change, `xcode-log-collect.zsh` |
| U66 | USB-07: `stat` forks for size-only reads | low | Not started | — |
| U67 | USB-08: ISO table `while read` loop | low | Not started | — |
| U68 | HELP-04: manual capture forks `rm`/`rmdir` | low | Not started | — |
| U69 | HELP-03: help identity rebuilt as one signature | low | Not started | — |
| U70 | CROSS-02: two static tests add about 13 s per suite | low | Not started | — |

If U69 is resumed, it must also extend `_compozsh_prompt_reset` to clear
the maps it adds (U51's note).

## Owner decisions

### OD1: in-widget directory change recaptures prompt facts (PROMPT-03)

**Decision (attributed to the owner, 2026-10-12): option (a), "Recapture".**
This record does not hold the owner's own words. The orchestrating session
received the answer in chat. Its owner-answers file records it as
`(a) Recapture -> unit U79`, and the implementing commit `677a473` states
`Owner decision OD1, option (a) "Recapture", chosen by the owner in chat on 2026-10-12.`
**Owner confirmation (2026-10-14).** In chat the orchestrating session asked
"Do you confirm OD1 (prompt recapture after an in-widget cd, 677a473) and OD3
(deleting the Windows writer, 7541987) as shipped?", and the owner answered
"Confirm both". This closes [CON-A-01](#unresolved-and-skipped-findings) and
[open question 1](#open-owner-questions). The orchestrating session wrote
this entry, quoting the owner's answer.

**How it landed.** The U79 fix agent implemented and verified the change. It
did not commit, because the approval reached it only as orchestrator-written
text, and CLAUDE.md requires the owner's own acceptance. The orchestrator
applied the saved patch with a three-way merge. One conflict, in the Browse
`cd`/enter-link dispatch, kept the newer stale-folder recheck and the new
`directory` action. The orchestrator then re-verified red and green, ran the
focused filters and ran the full suite (1,033 passed; only the FAT32 case
failed).

**Options.** Browse, Recents, Search and the Draft inspector's Files actions
run builtin `cd` inside a ZLE widget for Change directory and Enter linked
directory, so no `precmd` follows. Until the next accepted line, the prompt,
Context rows and window title described the previous folder. The plan offered
three options:

- (a) Recapture: run the prompt's fact capture from the editor's post-cleanup
  `cd` path.
- (b) No new reads: mark the snapshot as belonging to the previous folder,
  and withhold or label the PATH, GIT, PROJECT and TOOLCHAIN rows until the
  next `precmd`.
- (c) Keep the behavior and disclose it.

The plan recommended (a), because stale rows are a safety-relevant false
display.

**What changed.** Two Essentials and one contract section:

- [Performance](../engineering/performance.md#essentials), *Capture at
  defined boundaries*: `precmd` was the prompt's fact-capture boundary; it is
  now that boundary "repeated once after an explicit in-widget directory
  change".
- [Prompt](../engineering/prompt.md#essentials), *Presentation, never a
  provider*: the captured facts were "the `precmd` snapshot" and are now the
  prompt snapshot "captured at `precmd` and after an explicit in-widget
  directory change". Lens derivation, morphing, pinning, transcript repaint
  and resize still launch nothing and read nothing.
- [Prompt, project and runtime context](../engineering/prompt.md#project-and-runtime-context)
  names the new boundary and what it leaves out. The lens rules add that a
  trigger captured while a draft exists is consumed at the next repaint, and
  that a trigger never unpins a manual Option-I pin.

README, SECURITY.md (terminal title row, lens boundary, runtime and project
context, living prompt audit) and the filesystem contract changed with them.

**Data read and effects.** After a successful Change directory or Enter
linked directory (`cd` status 0), the editor's post-cleanup adapter
`_zle_prompt_directory_changed` (`.zsh.addons/.zsh.editor`, line 1642 at
`f80a680`) runs `_prompt_capture_context` when the prompt peer defines it,
inside the widget and before `zle reset-prompt`. That is the capture `precmd`
runs, for the new folder:

- Git: `git status --porcelain=v2 --branch --show-stash` with fsmonitor,
  hooks, content filters, optional locks and lazy fetches suppressed;
  `git rev-parse --absolute-git-dir` unless that folder's Git directory is
  already cached in shell memory; then the operation state from that Git
  directory.
- Project detection (bounded upward searches and marker checks) and runtime
  version probes of trusted tools on `PATH`, through the optional runtime
  support.
- Shell-memory facts (environment name, identity, path, live jobs), then the
  Context trigger, layout and base prompt.
- One terminal effect: the window title `user@host: <folder>`, written when
  standard output is a terminal and `TERM` isn't `dumb`.

It keeps the draft and adds no outcome, receipt, history entry, `precmd`,
manual catalog request or help capture request. It writes no file and keeps
everything in shell memory, as `precmd` does. A failed `cd` only repaints.

**Cost (an estimate, not a new measurement).** The in-widget capture is the
code `precmd` already ran, moved into `_prompt_capture_context`, so this
record's baseline *Prompt render* medians estimate it: about 4.1 ms outside a
repository, 25.0 ms clean, 27.1 ms dirty and 48.2 ms in the large fixture
(render mode, Git directory cached). A first visit to a folder misses that
cache; the fresh medians (4.7, 36.1, 38.4 and 58.6 ms) include the miss along
with other first-render costs. Both time `_prompt_update` (the shipped peers'
only `precmd` hook) plus prompt expansion, which the capture and its repaint
also perform, but not the title write, which needs a terminal. The benchmark
has no in-widget scenario. The cost is paid once per successful action,
after screen cleanup and before the repaint, never per keystroke or repaint.
It is an additional capture: the next accepted line still runs `precmd`'s
own.

### OD2: first-prompt help capture keeps one fork per guide (HELP-02)

**Decision (owner, 2026-10-12): option (b).** Keep one process substitution
per help guide and its 4,097-character pipe bound, and record the cost here,
rather than batch every changed companion into one child process (a) or move
the capture off the first prompt (c, new background work outside the
[approved exceptions](../engineering/performance.md#approved-background-work)).
The owner-answers file records `(b) Keep per-guide forks and record the cost
-> unit U80`. U80 recorded it in `8e4eb28`, changing no product code.

**Cost.** Help snapshots live in shell memory, so the first TTY `precmd` of
every new interactive shell captures every same-source companion before the
first editable prompt
([prompt](../engineering/prompt.md#about-and-alias-expansion)). With the
shipped peers that is six companions plus the Touch ID subguide: seven reads,
each one fork. Later prompts fork nothing until a definition changes or
`compozsh --refresh` clears the snapshot.

Measured with
[`benchmarks/help-first-prompt.zsh`](benchmarks/help-first-prompt.zsh) at
`cd61e3c` on the machine above (load 2.1–4.1): one tree, a warm ZDOTDIR per
variant, a 140×40 PTY, `en_US.UTF-8`, 15 runs per variant with the variant
order rotated each run, in two invocations. *Capture* is the in-shell time of
the first `_compozsh_prompt_capture`. *Editable* is spawn to first line-init.
The *bypassed* variant replaces the capture with a no-op and is a diagnostic
only. *Extra* adds 16 fixture commands whose companions print about 6,200
characters (12 options, then examples). Values are medians (min–max) in ms;
differences are medians of per-run paired differences.

| Metric | Invocation 1 | Invocation 2 |
| --- | ---: | ---: |
| Capture, shipped (7 reads, 6 summaries) | 12.91 (12.56–15.74) | 13.00 (12.59–13.86) |
| Editable, shipped | 96.69 (92.01–110.68) | 97.41 (96.04–102.60) |
| Editable, capture bypassed | 85.62 (79.57–92.45) | 85.28 (84.00–90.27) |
| Editable, shipped − bypassed | 12.53 (6.64–23.10) | 12.43 (9.54–17.92) |
| Capture per extra companion | 1.87 (1.82–2.32) | 1.90 (1.86–2.37) |
| Capture, single-fork prototype | 8.59 (8.40–9.08) | 8.77 (8.58–9.35) |
| Capture, shipped − prototype | 4.19 (3.89–6.92) | 4.20 (3.33–4.91) |
| Editable, shipped − prototype | 4.94 (−0.27–11.63) | 4.22 (−1.77–9.18) |

Help capture therefore costs about 13 ms, roughly an eighth of the warm first
editable prompt, on every new TTY shell. Each further private command with a
companion adds about 1.9 ms, so the 64-companion bound would put the capture
near 120 ms. A preliminary invocation (15 runs) whose fixture guides were 80
option-shaped lines measured 2.71 ms per companion: parsing, and the
invalidation loop over all captured options, grow with option count. Raw
outputs are kept with the run's local artifacts (not distributed).

**The rejected single fork.** Option (a) runs every changed companion in one
process substitution behind NUL-delimited headers, reads complete guides
under one aggregate bound, then splits and bounds each guide in memory. The
audit's prototype of it (unshipped and not distributed; it captured the same
six summaries and 16 options) saves about 4.2 ms of capture here; the audit's
own PTY comparison found 4.9 ms (14.19 to 9.28 ms, 7 runs). The first
estimate of about 10 ms left out signature and parse work and frame handling;
the batch also still forks once.

**Why per-guide forks stay.**

- *Data read.* Each guide's pipe is read to at most 4,097 characters, so the
  shipped capture reads 22,758 characters from seven pipes. A batch must read
  complete output: 74,442 characters with the shipped peers (3.3 times as
  much) and up to its aggregate bound in general. That loosens the per-guide
  bound that [SECURITY.md](../SECURITY.md#help-workspace-and-tool-descriptions)
  discloses.
- *Per-companion isolation.* Each companion, machine-local private ones
  included, runs in its own child. In one shared child, a companion that
  exits, fails or changes shell state would affect the companions after it,
  and one malformed frame would cost the descriptions behind it. Companions
  are trusted documentation, not a sandbox; this is about predictable
  failure, which [performance](../engineering/performance.md#choosing-between-designs)
  ranks above measured speed.
- *Size of the gain.* About 4 ms once per shell, about 4–5% of the warm
  editable prompt, does not outweigh either.

**Revisit** when private companions become common (about seven would double
today's cost) or when a design keeps the per-guide bound and per-companion
isolation with fewer forks. Re-measure with the same script: its `extra`
variant models private companions, and its optional override file measures
a candidate `_compozsh_prompt_capture`.

```zsh
TMPDIR=<disposable> /bin/zsh -df investigations/benchmarks/help-first-prompt.zsh <root> 15 16 en_US.UTF-8 [override-file]
```

### OD3: delete the retired Windows writer (USB-06)

**Decision (attributed to the owner, 2026-10-12): option (a), "Delete it".**
As with OD1, this record does not hold the owner's own words. The
owner-answers file records `(a) Delete the retired Windows writer -> unit
U81`, and the implementing commit `7541987` states
`Owner decision OD3, option (a) "Delete it", chosen by the owner in chat on 2026-10-12.`
The owner confirmed it as shipped on 2026-10-14, answering "Confirm both" to
the question quoted under
[OD1](#od1-in-widget-directory-change-recaptures-prompt-facts-prompt-03).

**How it landed.** U81 was first scheduled before U71. It was moved to run
last, after U71, in patch-only mode for the same reason as U79. U71 therefore
kept `_usb_dd_bytes_observed` and `_usb_cmp_drain`, and U81 removed them. The
orchestrator applied the patch and re-verified red: the static test listed
the writer's symbols at the prior HEAD. It then confirmed green, and the full
suite gave 1,018 passed, 0 failed.

**Options.** The plan offered three:

- (a) Delete the writer.
- (b) Keep it as disclosed, unreachable code and keep reporting the FAT32
  failure.
- (c) Keep the writer but retire only the failing FAT32 test.

It recommended (a): the code was unreachable, needed ongoing maintenance and
carried the suite's only standing failure.

**What was removed.**

- *Reachability.* No public path reached the writer: `_usb_media_execute`
  already refused Windows media, and the workspace controller returns on the
  Windows unsupported screen before target capture. The commit deleted
  `_usb_windows_execute` and its helpers (about 900 lines of
  `.zsh.addons/.zsh.usb`), every post-refusal Windows branch, the writer-only
  globals and result facts, and `_usb_dd_bytes_observed` and `_usb_cmp_drain`,
  which lost their last caller. Classification, the unsupported screen and the
  dispatcher refusal stay; the live ISO-table entry bound is now
  `_USB_ISO_TABLE_MAX_ENTRIES`.
- *Temporary names.* `compozsh-usb-windows.*`, `compozsh-windows-readonly.*`
  and `compozsh-windows-verify.*` left SECURITY.md's temporary-file inventory
  and its residue check, which now lists `compozsh-(usb|createinstallmedia)*`.
- *Tool requirements.* `external-device --flash` no longer requires
  `/usr/bin/ditto` or `/bin/sync`, in its availability check or its `--help`
  requirements.
- *Tests and notes.* The real-FAT32 `hdiutil` round trip, the baseline's one
  failure ([suite](#suite-and-verification)), went with the writer, and its
  notes left the verification contract and the investigations index. The
  *Native progress-capture cap* proposal in
  [USB bounds](usb-progress-integer-bounds.md#proposals-not-implemented) was
  withdrawn with `_usb_dd_bytes_observed`. The static test
  `USB ships no retired Windows writer` fails if the writer's functions,
  temporary names, `ditto` or `/bin/sync` return to `.zsh.addons/.zsh.usb`.

**Data read and effects.** The change only removes: no new read, process,
file or disclosure, and no Essential changed. Public behavior is unchanged:
Windows Setup media is still classified and refused before any drive is
chosen.

### Open owner questions

These fall under CLAUDE.md's owner-decision list. The run could not answer
them, so it reports them with options and a recommendation.

**1. Confirm OD1 (and OD3) in your own words (CON-A-01, final review).**
*Resolved 2026-10-14:* the owner answered "Confirm both", option (a) below
for OD1, and confirmed OD3
([details](#od1-in-widget-directory-change-recaptures-prompt-facts-prompt-03)).
`677a473` changed two Essentials:

- the performance Essential *Capture at defined boundaries*;
- the prompt Essential *Presentation, never a provider*.

They now allow a second prompt fact capture inside a ZLE widget after an
explicit Change directory or Enter linked directory. The only records of the
choice are agent-written: the commit message and the orchestrator's
owner-answers file.

- (a) Confirm recapture as shipped. Record your words and date under OD1.
- (b) Revert to `precmd` as the only capture boundary, using the revert path
  under [CON-A-01](#unresolved-and-skipped-findings). The prompt, Context
  rows and title then show the previous folder until the next accepted line.
- (c) A narrower recapture. After an in-widget `cd`, update only the
  PWD-derived folder label and title, and mark Git and toolchain facts as
  pending until the next `precmd`. This still changes an Essential, and it
  needs a new visible pending state, tests and docs.

*Recommendation:* (a), if it matches what you chose. The capture runs only
after an explicit user action, in the post-cleanup final action and never in
repaint. It reads exactly what the next `precmd` would read for that folder,
and it fixes a prompt and title that describe the wrong directory;
correctness ranks above latency. Choose (b) if `precmd` should stay the single
boundary. For OD3, one line suffices: it removed unreachable code and changed
no Essential.

**2. Sources on virtual disks (U11 follow-up).** U11 resolves an image's APFS
volume to its physical store disks. When the image or installer sits on a
virtual whole disk, such as a mounted disk image, a sparsebundle or an APFS
container on an AppleRAID set, exclusion stops at that virtual disk. It does
not trace the disk that holds the image file, or the RAID members. A busy
unmount usually stops the write, by accident rather than by design. The
`--flash` help still says a target "can never destroy its own source during
dd", and "during dd" is also narrower than the `createinstallmedia` path.

- (a) Trace: read `hdiutil info` and AppleRAID membership, and exclude the
  backing disks. This adds reads that list every attached image.
- (b) Refuse: fail closed when the source's whole disk is virtual and its
  physical disk can't be resolved from the `diskutil info` facts already
  read.
- (c) Keep the behavior and narrow the help and SECURITY.md wording to what is
  guaranteed.

*Recommendation:* (b), with the help sentence corrected in the same change.
It fails closed, reads nothing new and affects only unusual layouts. (a)
widens what is read to cover a rare case.

**3. History size (BOOT-02, U27).** `78be007` removed the 50,000-entry
defaults, which never applied, and documents that history keeps whatever
`HISTSIZE`/`SAVEHIST` the system or initializer sets (macOS `/etc/zshrc`:
2,000/1,000).

- (a) Keep the stock values. Users raise them in the initializer.
- (b) Raise the effective values to 50,000 when the user has not chosen any.
  This needs a heuristic that treats Zsh's 30/0 and Apple's 2,000/1,000 as
  unchosen, which misreads a deliberate value that equals a stock one, and it
  retains more history on disk.

*Recommendation:* (a). Data minimization and user control rank above breadth,
and no heuristic can tell a deliberate stock value from an unset one.

**4. Bound for the bare `g` branch catalog (Git audit note).** Bare `g` reads
the local branch catalog through an unbounded command substitution
(`.zsh.navigation`), and it builds inspector text for every branch. That
conflicts with the Git Essential *Bounded and honest*, while the Branches
section says recency must never limit matchable refs.

- (a) Read through `_compozsh_capture_bounded` with byte and row bounds and
  the standard partial notice. Matching then covers captured refs only, and
  the notice says so.
- (b) Keep the read unbounded and record the exception in the Git contract.
  Retained text then grows with the branch count.
- (c) Keep the name list complete, but build inspector text only for the
  selected branch. This bounds what is retained without limiting matching.

*Recommendation:* (a), optionally with (c). It meets the binding Essential
with an honest notice through the shared entry. A generous bound leaves
ordinary repositories unchanged.

**5. Lazy help-identity validation (HELP-03 alternative, plan note).**

- (a) Resume U69 as planned: validate help-description identity in parts each
  prompt, with no new state.
- (b) Validate lazily: write a stale mark when a definition changes at edit
  time, and check it on use. This adds state written from an edit-time path.

*Recommendation:* (a). It needs no owner decision. Revisit (b) only if (a)'s
measured cost is still visible.

## Unresolved and skipped findings

### Owner confirmation (resolved)

- **CON-A-01: owner confirmation of OD1 (blocking review finding).**
  *Resolved 2026-10-14:* the owner confirmed OD1 and OD3 as shipped
  ("Confirm both"; see
  [OD1](#od1-in-widget-directory-change-recaptures-prompt-facts-prompt-03)).
  The revert path below is kept for reference only.
  [OD1](#od1-in-widget-directory-change-recaptures-prompt-facts-prompt-03)
  rewrites two Essentials and adds an in-widget Git and project capture,
  which CLAUDE.md treats as owner decisions
  ([how the contracts work](../CLAUDE.md#how-the-contracts-work)). The tree
  records the choice only through `677a473`'s commit message; the owner's own
  words and date still need to be recorded under OD1. If the owner did not
  choose recapture, a revert path exists: remove the `_prompt_capture_context`
  call from `_zle_prompt_directory_changed` (keeping its `zle reset-prompt`;
  `precmd` can keep calling the extracted function), restore the performance
  and prompt Essentials, the *Project and runtime context* bullet and the
  README, SECURITY.md and filesystem contract lines from `677a473`, and remove
  the recapture assertions from the two `living prompt recaptures` tests in
  `tests/prompt_lens_ui_test.zsh`. Keep the stale-folder recheck, the
  pin-preservation behavior and their tests.

### Skipped audit findings

The owner chose to skip the nine performance findings of U62–U70: PROMPT-04,
GIT-05, PROMPT-07, XCODE-05, USB-07, USB-08, HELP-04, HELP-03 and CROSS-02.
Their state and saved work are listed under
[skipped performance units](#skipped-performance-units-u62u70). Every other
audit finding is resolved.

### Final review findings not fixed

The final review fixed every blocking finding (T01–T07). Its 31 non-blocking
findings were left for follow-up, apart from the ones marked resolved below.
They are grouped by consequence.

Safety and disclosure:

- **SEC-B-02, CON-B-05.** `.zsh.find` (three functions), `.zsh.navigation`
  and `.zsh.git-review` still declare a local named `path`. Zsh ties that
  name to `PATH`, so it rebinds `PATH` for children and empties the command
  hash table. U45 fixed the same pattern in USB. Rename the locals, then add
  the matching idiom to `engineering/zsh.md`.
- **CON-A-02, SEC-C-09.** Pre-existing: the `g --discard-all` success
  message prints the repository path with `print --`, not `print -r --`.
  Its index entry still cites `.zsh.tools:329`; the line is now 335, and
  SECURITY.md does not mention it.
- **SEC-B-03, SEC-C-08, CON-C-11.** When `_compozsh_job_reap` is absent, the
  Git syntax, review-worker and Xcode fallbacks signal by bare PID and use a
  bare `wait`. That contradicts SECURITY.md's job-lifecycle text and the
  Xcode contract's "never a job-table sweep". Either scope the wording to the
  shared entry, or make the fallbacks exact.
- **SEC-C-02.** `_usb_flash`/`_usb_format`, and also `xcode()`, leave
  `REPLY`, `_ZLE_PICKER_SELECTED_VALUE` and `_ZLE_PICKER_BOOKMARK` global, so
  the invocation-scope claim holds only for `_USB_*`.
- **CON-B-02, CON-B-03.** Picker results and bookmarks outlive the view for
  bare `g`, Recents/Files and Ctrl-R, against SECURITY.md's "view-local". The
  frame names keep global values in `support/ui/.zsh.ui.state`, which
  conflicts with `engineering/zsh.md`. This also makes keyboard-zle's "no
  painted text outlives the session" too broad.
- **SEC-C-04.** SECURITY.md does not say that the last signature check and
  the root `createinstallmedia` exec are separate steps by path, so they are
  not atomic.
- **SEC-C-05, SEC-C-06, SEC-C-07.** Xcode skill-export staging has three
  gaps:
  - the cleanup guard compares an unquoted `${temp_root:A}`, so a `TMPDIR`
    containing `[`, `*` or `?` leaves the staging directory;
  - no test covers handled-error or Ctrl-C cleanup;
  - SECURITY.md does not mention residue under the old
    `${TMPDIR}/xcode-skills.*` name.

  U08 also found that an interrupt during agent installation leaves a
  `.xcode-skill-stage.*` sibling. That one is disclosed; interrupt-safe
  cleanup is a follow-up.
- **SEC-A-03.** The relative-initializer diagnostic prints raw
  `ZSH_LOCAL_INIT` text; U07 proposed `${(V)…}`.
- **SEC-A-04.** No test covers an assignment value longer than the title
  lexer's 512-character bound.
- **SEC-A-02 (narrowed).** `3cd7f10` added the same-class guard on `.zshrc`.
  A small check-to-use window remains.

Contracts, docs and tests:

- **CON-B-01.** Pre-existing: loading `.zsh.navigation` removes any function
  or alias named `b`, the user's included, which breaks load-order
  independence. The fix is two lines.
- **CON-B-04.** The Recents diagnostic still names the retired grouped "UI and
  matching add-ons".
- **CON-B-06, CON-C-05.** New tests time their own runs, contrary to
  `engineering/verification.md`:
  - the bounded-capture linear-scaling case;
  - the syntax-poll case (under 1 s);
  - the 4,096-scheme parse (under 1 s).
- **CON-C-06.** The `SIMCTL_CHILD_NSUnbufferedIO` prefix sits on a shell
  function, so every child that function starts gets it. SECURITY.md says
  "only for the launch".
- **CON-C-07, CON-C-08, CON-C-09.** Three stale texts:
  - `--flash --help` says the "parent whole disk" is excluded, but APFS
    sources now exclude their store disks;
  - SECURITY.md still names `/usr/bin/cksum`, which no shipped code runs;
  - one error message still says "for verification".
- **SEC-B-04.** SECURITY.md's Appearance *Inspect* list omits `.zsh.help`,
  which holds the help `NO_COLOR` gate.
- **CON-A-03.** No release note exists for the discovery change; see the
  release-note items below.
- **CON-A-05, SEC-C-03.** CLAUDE.md's suite note is stale. The proposal is
  under [proposed changes](#proposed-claudemd-and-claude-changes).
- **Resolved here.** CON-A-04 by the U55 startup measurements under
  [other measurements](#other-measurements-recorded-by-fix-units), and
  CON-C-10 by the OD3 entry (`258d2eb`).

### Follow-up candidates

None of these was a confirmed finding. Plan verifiers and fix units noted
them, and each would need its own unit.

- **Prompt and editing:**
  - The Interaction lens copies array-assignment values into COMMAND TEXT
    (`secrets=(v)`), against SECURITY.md's lens row. U06's `*=\(` handling
    would fix it.
  - `_prompt_command_started` and `_prompt_update` overwrite the user's
    `REPLY`.
  - `_prompt_version_probe` runs `builtin cd -- /` without `-q`, so user
    `chpwd` hooks run in probe subshells.
  - The screen cleanup repaints the old prompt before an in-widget `cd`.
  - Ctrl-C leaves an unaccepted suggestion in scrollback; this is disclosed.
  - Project detection lists symlinked `lua/` and `script/` folders that point
    outside the project.
  - Under `GLOB_SUBST`, the Browse session entry respells `~`.
- **Filesystem:**
  - The Spotlight batch handler and the root check use unquoted
    `$HOME`/`$root` as patterns.
  - The local walk at `/` keeps absolute labels.
  - Back or Ctrl-T on a vanished level closes Browse like a cancel.
  - Providers order equal-rank folders differently.
  - Browse Open still needs `.zsh.find`, and the dispatcher has no
    fail-closed default branch.
- **Git:**
  - `_git_syntax_apply` takes about 127 ms for 3,641 spans.
  - `-c log.showSignature=false` could also go on `_git_worktree_git` for
    defense in depth.
  - The `.zsh.git-review` header still says "UI peer".
- **Shared UI:**
  - Inspector wrapping could use a linear chunker, and the frame benchmark
    has no long-diff-line scenario (U59).
  - Per-view `_ZLE_PICKER_DISPLAY` locals are now redundant.
  - Prepared inspector lines could move to session scope.
  - Help capture invalidation grows with companions times options.
- **Xcode:**
  - Discovery can write its `[n] pid` launch line before the first frame.
  - The Run destination text omits terminate-running-process.
  - A shared decimal-limit entry is still a proposal.
- **External devices:**
  - Full-installer codesign passes show no progress frame.
  - `_usb_macos_execute` has no authorization re-prompt.
  - Status 9 can carry an empty verify reason, and there is no
    incomplete-evidence label.
  - `_usb_disks_capture_retry` and `_usb_dd_run` have no callers.
  - The installer identifier could be pinned in the code requirement.
  - Bare waits in the USB workers and `.zsh.manual` should be audited for the
    NOTIFY-off sweep.
  - Format catalog failure could offer an in-workspace Retry.
- **Installer and bootstrap:**
  - A failed fresh install leaves an empty `.zsh.addons`.
  - A relative `HOME`/`ZDOTDIR` makes the user add-on folder relative.
  - Rollback could also require the managed marker.
- **Tests:**
  - `XDG_CONFIG_HOME` isolation for fixture Git (global ignore and
    attributes).
  - A checked-in fail-closed `open`/`pbcopy` stub directory.
  - Per-peer alias-guard tests for `compozsh`, `g`, `xcode` and
    `external-device`.
  - `git_auto_refresh_test.zsh:151` still sleeps 0.45 s.
  - Raw support loops remain in tests that never load the UI.
  - `editor_reader_test.zsh`'s fixture lacks the `(p)` flag.
  - The subset scan is line-based.
  - The `TEST_ZSH_BIN` stderr line described under [tests](#tests).
- **Contract wording (proposals):**
  - `engineering/zsh.md`: idioms for cd's `-`, `-N` and `+N` operands, and
    for locals named after special parameters.
  - `engineering/verification.md`: input paced by child-emitted events, and
    naming `help-first-prompt.zsh` for help-capture changes.
  - `engineering/repository-layout.md`: refusing a destination that appeared
    after planning.
  - An annotation of the deleted test at
    `investigations/in-memory-capture-parsing.md:218`.

### Release-note items

The repository has no release-notes file, so the next release draft should
carry these:

- A relative `ZSH_LOCAL_INIT` is now ignored with a diagnostic; export an
  absolute path (U07).
- Private peers in hidden folders, or named `.ZSH.*`, no longer load when the
  initializer sets `GLOB_DOTS` or `NO_CASE_GLOB` (U55, CON-A-03).
- The Git wrapper no longer injects `color.ui=auto`, so the user's Git color
  configuration wins. With stdout redirected, Git's stderr uses Git's own
  colors (U18).
- `man` no longer forces `MANPAGER='less -sR'` or `MANCOLOR`. `grep` and `man`
  colors follow `NO_COLOR` and need 256 colors, and `NO_COLOR` at startup
  stops `CLICOLOR` (U28, U35).
- The 50,000-entry history defaults are gone; they never applied (U27).
- Git review and bare `g` never verify commit signatures (U03).
- `external-device --flash` changes:
  - it rejects ad-hoc-signed installer bundles (U04);
  - it no longer needs `ditto` or `sync` (U81);
  - Flash & verify fails closed instead of rereading the drive (U71).

## Manual Terminal.app acceptance pending

PTY tests can't judge how Terminal.app looks. Use disposable folders,
repositories and media; items marked *optional* are not required by a
contract.

Prompt and editing:

1. **Terminal title** (U06, `b45eae1`).
   - Run `API_TOKEN=fixture-secret-value sleep 5`. While it runs, the title
     reads `<user>@<host>: sleep`, with no value in the tab bar or the Window
     menu, and it returns to `<user>@<host>: <folder>` at the next prompt.
   - `secrets=(fixture-array-value); sleep 5` shows `<user>@<host>` alone.
   - `make --version` shows `<user>@<host>: make`.
2. **Ghost text** (U19, `ea44686`).
   - Run `print -s -- 'echo GHOST-TAIL'`, type `if true; then` and Return,
     then type `echo GH` at the continuation prompt. Press Return, then type
     `fi` and Return. Scrollback shows `echo GH` with no `OST-TAIL`.
   - Repeat at the top level in a shell whose `.zshrc` sources only
     `.zsh.editor`.
3. **Accept keys under `KSH_ARRAYS`** (U30, `cd61e3c`). Set
   `setopt KSH_ARRAYS`, keep the history entry
   `print -r -- RESULT swmark-xyz tail`, and type `print -r -- RESULT swm`.
   - Ctrl-F and Right each insert `a`.
   - Option-F and Option-Right accept through `swmark-xyz` and keep the
     leading `p`.
   - Ctrl-E accepts the line.
   - With no suggestion showing, all three keep their native motions.
4. **In-widget recapture** (U79, `677a473`).
   - Type `./`, press Tab, then Ctrl-X › Change directory into a Git
     repository. The NAVIGATE lens shows FROM/PATH for the new folder and a
     GIT row, and the tab title updates. Judge whether the brief repaint with
     the old facts during cleanup distracts.
   - With an empty draft, open Option-Tab Recents, then Ctrl-X › Current
     folder · Change directory into a repository. The Context lens opens with
     "entered repository" or "branch changed".
   - With the lens pinned (Option-I), Change directory keeps it pinned and
     shows the new rows.

Full-screen and shared UI:

5. **Ctrl-L** (U53, `3ede7d8`). Ctrl-L in a picker redraws in place. With the
   profile's terminal type set to vt100 (the inline fallback), earlier
   main-screen output and scrollback stay intact.
6. **Resize keeps accents** (U17, `ee9ed53`).
   - In a Git review document whose lines hold keywords and strings, resize
     while the reader waits, then press Down. Every color stays.
   - In a picker with metadata accents (Files sizes, an external-device or
     Xcode architecture row), resize while it waits. The accents stay.
   - Resize a help topic reader. The accents stay.
7. **Frame release** (U48, `b8fb3a4`).
   - Leave Ctrl-R, Git review (`g` › Working changes with a diff selected)
     and Search with Escape, Ctrl-G, Enter and Ctrl-C. Prompt, draft and
     scrollback come back unchanged.
   - Afterwards `typeset -m '_ZLE_PICKER_DISPLAY*'` shows empty arrays, and
     `print -r -- $_ZLE_PICKER_POSTDISPLAY` prints an empty line.
   - Moving between views in one session shows no blank flash.
8. **Guide context lines** (U36, `ed83cca`). At 60 columns, open Git
   comparison or the change atlas in a repository whose folder name contains
   ESC or BEL (and, separately, a newline). Press Ctrl-K and scroll to the
   end. The row shows `^[`, `^G` or `\n` inline, with no wrap and no scroll.

Filesystem:

9. **Spotlight at `/`** (U10, `1d1b765`). Tab-browse `/`, press Ctrl-F,
   confirm the source is spotlight, and submit a fragment of a known indexed
   file under `~`. It is listed as `~/…`, not "No matching captured paths".
10. **Vanished entries** (U20, `28cc67c`), at 80 and 160 columns.
    - Run `pushd ~/gone`, `pushd` back, then `rmdir ~/gone`. Press
      Option-Tab, select `gone/` and press Ctrl-O. Recents stays open on
      `gone/`, with the header "cannot browse gone/: missing or unreadable ·
      N shown" fitted cleanly. Ctrl-X then Esc restores "this shell".
    - `~/Projcts/` plus Tab runs native completion or correction, with no
      Browse screen and no `~/PProjects/` draft.
    - Open `~/Projects/` with Tab and rmdir a child from another tab, then
      press Right on it. The level stays, and the header reads "Hidden: off
      · cannot open <name>/: missing or unreadable · N files".
11. **Preview sample** (U37, `2c5460d`). In a folder with more than 40
    entries, press Ctrl-O. "Limits: 40-entry sample in filesystem order; more
    exist. Use → to browse." renders in the warning color and wraps cleanly
    at 100–119 columns and on a narrow screen.
12. **`-` and `~` children** (U38, `11ec595`). With `AUTO_CD` set, in a folder
    holding `-x-dir/inner` and `~x/inner`, type `x` and press Tab.
    - The rows read `-x-dir/` and `~x/`.
    - Right enters each one, and Left returns to the same row.
    - Enter inserts `./-x-dir/` or `./~x/`, and Return changes into it.
13. **Stale actions** (U40, `392ec62`; U41, `d38a70d`).
    - Press Tab on `./`, select a file and choose Ctrl-X › Open, then delete
      or rename the file before accepting. One note appears below the
      prompt: "Files: the selected item changed or is unavailable; your
      draft is unchanged.", with no stale frame row and no shifted cursor.
      Reveal in Finder behaves the same.
    - Change directory on a removed folder, and Enter linked directory on a
      dangling link, each show the folder note once. PWD and the draft stay
      unchanged.
    - Recents and the Draft inspector's "Choose a path here" show the same
      note.

Git and output:

14. **Job notices** (U21, `3b98c36`). Run `sleep 1 &`, open `g` › Working
    changes with an unstaged change, wait at least 3 s, then press Escape.
    The `[n] + done sleep 1` notice appears, or `jobs` lists it. No
    `[n] + exit 129 ( zmodload zsh/system …` notice ever appears, even when
    leaving during a check.
15. **Git colors** (U18, `a086c75`). Use a disposable repository with
    `GIT_CONFIG_GLOBAL` pointing at a scratch file.
    - An empty config shows palette shades on a terminal.
    - `color.ui = never` shows no color.
    - With `color.ui = always`, `git diff | less -R` matches
      `command git diff | less -R`.
    - An interactive `git push` to a local bare repository shows palette
      shades in both light and dark schemes.
16. **`man` and `grep`** (U35, `8e048f9`). Start with `MANPAGER`, `MANCOLOR`
    and `PAGER` unset.
    - `man ls` shows palette headings and underlined arguments through less.
    - `PAGER=more man ls` pages with more.
    - `NO_COLOR=1 man ls` shows only native bold and underline.
    - `grep` highlights matches, `NO_COLOR=1 grep` shows no color, and in a
      window declared as `xterm` (8 colors) `grep` shows no color.
17. *Optional.* **`NO_COLOR` listing** (U28, `f85af82`). With
    `export NO_COLOR=1` in a disposable initializer, plain `ls` is uncolored.
    Without it, folders are colored.

Help and Xcode:

18. **Help titles** (U33, `b641147`).
    - In `compozsh`, select `git` and press Enter. The title reads
      "Help / git", and Overview reads "Help / git / Overview".
    - Escape twice restores the bookmark.
    - `mkcd --help` shows "Help / mkcd", and
      `compozsh --sudo-touch-id --help` shows "Help / compozsh".
19. **Xcode job notices** (U22, `0f0ffb3`). With `unsetopt NOTIFY`, run
    `sleep 1 &` and open `xcode` at once, then open Destination.
    - No `[n] done sleep 1` or `[n] killed ( unsetopt MONITOR; trap …` line
      appears in either discovery frame.
    - The done notice appears at the next prompt.
    - `jobs` lists no supervisor.
20. **Run descriptions** (U42, `f68a882`). Use a project with a Simulator
    destination and a paired device.
    - The Build & Run and pending Run destination texts wrap legibly at about
      80 columns and narrower.
    - On Simulator, Escape in the log reader returns to Run controls and the
      app keeps running.
    - On a device, Escape returns to Run controls, Stop or Escape there ends
      the devicectl console, and the app stays installed.
    - *Optional* (U43): a real Simulator Run still shows prompt stdout and
      Logger records.

External devices (disposable media, real hardware):

21. **Installer signatures** (U04, `aea7af0`). In a throwaway shell that
    sources `.zsh.usb`:
    - `_usb_macos_codesign_verify "/Applications/Install macOS <name>.app"`
      returns 0 for a `softwareupdate --fetch-full-installer` copy and for an
      App Store copy.
    - `codesign --verify --strict -R '=anchor apple' "<app>/Contents/Resources/createinstallmedia"`
      prints nothing and returns 0 on both.
    - `external-device --flash "<app>"` reaches Step 2 showing "Source
      validation · Verified · Apple-signed full installer".
    - An older installer with an expired certificate shows "macOS installer
      validation failed · Nothing can be written".
22. **APFS sources** (U11, `0c09099`).
    - With an `.iso`/`.img` on an external APFS SSD, that SSD is absent from
      Step 2 while a second external drive is listed.
    - The same holds with an Install macOS app on that SSD.
    - An image on an exFAT or HFS+ stick still excludes the stick.
23. **Passive rows** (U54, `9da2047`).
    - When media fails inspection or signature validation, only "[1] Choose
      another media" is numbered and selected. The red headline is an
      unnumbered passive row that never takes the arrow.
    - The macOS Step 3 of 3 review shows exactly three numbered actions. The
      green "Source validation · Verified · Apple-signed full installer" row
      is passive, the footer never shows "⏎ inspect", and inspecting Create
      shows the signature re-check paragraph.
24. *Optional.* **Format catalog failure** (U14, `1de409e`). Override
    `_usb_diskutil_run` to return 1, run `external-device --format` and pick
    a drive. The workspace closes cleanly, "external-device --format:
    diskutil could not capture its filesystem catalog" prints on its own
    line, and `print $?` gives 2.
25. *Optional.* **Flash & verify text** (U71, `c7a6045`). The Step 3 detail
    reads "…writes through /dev/rDISK, compares every image byte before the
    drive is released, and ejects." and wraps cleanly.

Two optional checks fall outside Terminal.app:

- On a C1-honoring terminal such as xterm (U05), run `LC_ALL=C zsh` inside a
  repository whose branch is `$'bx\xc2\x9c\xc2\x9b2J'`. The prompt shows
  `bx??2J`, and the screen is not cleared.
- Resize Git review on a one-line minified diff (U59).

## Proposed CLAUDE.md and .claude changes

*Proposals* for the owner: this run may not edit CLAUDE.md or `.claude/`.

### Suite note in CLAUDE.md (CON-C-03)

*Proposal.* In CLAUDE.md, *Working in this repository*, the bullet on
`zsh tests/run.zsh` still describes the suite before `7541987`:

- It says the real-FAT32 `hdiutil` round trip fails on macOS 27 and is known
  in `investigations/README.md`. That commit deleted the test with the
  retired Windows writer
  ([OD3](#od3-delete-the-retired-windows-writer-usb-06)) and removed its
  entry from the
  [index](README.md#known-code-issues-found-2026-10-11-not-yet-fixed), so
  the sentence points to nothing and the suite has no standing failure.
- It says the suite has about 950 cases. A full run at `258d2eb` passed all
  1,022 cases in 228,806 ms, against 961 cases in the
  [baseline](#suite-and-verification).

Proposed wording for that bullet, which drops the FAT32 sentence, keeps the
Xcode Logger flake note and makes CLAUDE.md two lines shorter:

```markdown
- `zsh tests/run.zsh 'fragment'` runs tests whose *descriptions* contain the
  case-insensitive fragment. The full suite (about 1,020 cases, 3–4 minutes)
  runs before handoff, in the background when possible. The Xcode Logger
  cleanup timing test can flake under load (rerun it alone).
```

Nothing under `.claude/` mentions the FAT32 test or the case count, so this
finding needs no `.claude/` change.

### Owner answers in unattended runs (U79)

*Proposal.* CLAUDE.md, *How the contracts work*, says that an agent that
can't ask should "leave it and report the question". It does not say whether
an answer relayed by an orchestrating session counts. In this run, U79 and
U81 refused relayed text, and the orchestrator, which received the answers
directly, applied their patches. Proposed continuation of that sentence,
which adds two lines and keeps CLAUDE.md at 199 lines together with the suite
note above:

```markdown
  you can't ask (subagent, unattended run), leave it and report the question;
  a relayed summary of the owner's answer is not acceptance, so finish such work
  as a verified patch and report it until the owner's own words are recorded.
```

### Harness helpers in `.claude/rules/tests.md` (U24, U78)

*Proposal.* Replace "drive PTYs with `zsh/zpty`" with "drive PTYs through
`tests/pty_support.zsh` (`test_pty_start`, `test_pty_expect`)". Also add
"load shared support with `test_source_support`, marking a deliberate subset
with `# Support subset:`". Run `zsh tests/run.zsh 'tooling:'` and `'docs:'`
afterwards.

### Audit filters in `.claude/rules/docs.md` (T03)

*Proposal.* Add that `tests/documentation_test.zsh` also requires every
filter in SECURITY.md's *Focused regression checks* table to select at least
one test.

### Checked and not needed

- Several units asked for guidance when subagents are unavailable. CLAUDE.md
  already says "without subagents, apply their checklists yourself", and
  every fix unit did.
- The operator's auto-memory test-baseline note lives outside the repository.
  It was updated during the run.

## Run notes

**Timeline (CST).**

- The run started on 2026-10-12 at about 02:36, and the Phase 1 baseline was
  committed at 04:09 (`abefd6b`).
- The audit, verification and planning workflow took 6.7 h and 93 agents.
- Fix batches:

  | Batch | Units | Wall clock | Ended |
  | --- | --- | --- | --- |
  | b1 | U01–U10 | 1.9 h | normally |
  | b2 | U11–U30 | 5 h | normally; a full-suite gate after U30 gave 1,012 passed, only the FAT32 case failing |
  | b3 | U79, U80, U31–U53 | — | stopped by the orchestrator after U53 had run about 12 h over two attempts |
  | b4 | U54–U65 | — | stopped by owner decision on 2026-10-13 |
  | b5 | U71–U78, U81 | 1.9 h | normally |

- The final review followed: six security and contract passes over three
  slices of `git diff main..HEAD`, T01–T07, and the final suite and
  measurements. It ended on 2026-10-14 at about 00:53.

**U53 (SUPPORT-05, Ctrl-L redraw).**

- Attempt 1 died after about 5 h.
- Attempt 2 reached green on its focused checks after about 7 h, when the
  orchestrator stopped the workflow.
- With the owner's approval, the orchestrator re-verified red: without the
  fix, the user `clear-screen` widget ran and vt100 cleared the main screen.
- It then ran the focused filters and the full suite (1,031 passed; only the
  FAT32 case failed) and committed `3ede7d8`.

**Relayed approvals.** Fix agents treated owner answers relayed in workflow
text as carrying no owner authority, as CLAUDE.md and the run's harness
require. U79 (OD1) returned an owner-decision status with a verified patch.
U81 (OD3) ran in patch-only mode. The orchestrator, which had the answers
directly, applied both, re-verified them and committed
([OD1](#od1-in-widget-directory-change-recaptures-prompt-facts-prompt-03),
[OD3](#od3-delete-the-retired-windows-writer-usb-06)). OD2 changed no code
and was recorded by U80.

**Time box and stalls.**

- After U53, the owner set a 45-minute time box per attempt.
- U62 took 178 min: a long focused-filter call outlived its timeout and moved
  to the background. Its `runtime` and `living prompt` filters alone took
  561.7 s and 782.2 s.
- U63 took 49 min. U64 took 110 min, mostly 6–74-minute gaps between tool
  calls, consistent with API latency.
- U52 saw focused runs take 12–30 min of wall clock at normal CPU time, then
  seconds on rerun, consistent with the machine idling while unattended.

**Background work and processes.**

- The run forbade background execution. Even so, subagents started about 19
  background shell tasks, mostly long reproducer, benchmark or focused-filter
  commands that outlived the Bash timeout and were moved to the background
  automatically. All of them finished.
- Hung reproducer processes from the audit phase were still running: one
  `term-hung.zsh`, idle 11.5 h, and eight `help04` `inner.zsh` shells, idle
  about 30 h, which several units reported. The orchestrator found and stopped
  them. None used CPU, so measurements were unaffected.
- Local residue outside the repository:
  - three reviewer `mktemp` directories in the system `TMPDIR`, holding only
    test-name lists, because the review rules allowed no `rm`;
  - four older `my-zsh-tests.*` directories;
  - one `mkdir -p` scratch folder from U62.
- Memory notes outside the repository were updated: the test baseline and
  lessons from the unattended fix loop.

**Reviews.** Delegation was forbidden inside units, so each fix unit applied
the `security-reviewer` and `contract-reviewer` checklists itself. The final
review ran them as separate passes.

**Harness lessons** (U23, U24):

- `zpty -r` on a `-b` session returns 1 on the first read after the child
  exits, and 2 on the next, when zpty closes the descriptor. A `zselect` on
  that descriptor then fails with EBADF, so waits must stop at status 2.
- Any subshell of the session's owner shell, such as `$(zpty -L)`, runs
  zpty's exit hook when it ends and hangs up live sessions. This is
  documented in `tests/pty_support.zsh`.

*Proposals* for later unattended runs (workflow, not repository):

- Keep the machine awake.
- Measure time boxes in active tool time, or give PTY-heavy units more.
- Run `runtime` and `living prompt` as separate calls.
- Allow-list one-line, read-only `zsh -c` probes (U60).
- Route owner answers so that agents receive the owner's own words; see the
  CLAUDE.md proposal above.
