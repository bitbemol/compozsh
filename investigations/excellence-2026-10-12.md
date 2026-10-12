# Excellence run, 2026-10-12

> **Status (2026-10-12): in progress.** Phase 1 (baseline) is complete:
> suite, verification and latency baselines with their A/A noise floor. Later
> phases fill the sections marked *Pending*.

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

*Pending.*

## Commits

*Pending.* Phase 1: this record and the two benchmark scripts.

## Performance results

*Pending.*

## Owner decisions

*Pending.*

## Unresolved findings

*Pending.*

## Manual acceptance pending

*Pending.*

## Proposed CLAUDE.md and .claude changes

*Pending.*
