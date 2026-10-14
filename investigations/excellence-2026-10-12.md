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

## Owner decisions

### OD1: in-widget directory change recaptures prompt facts (PROMPT-03)

**Decision (attributed to the owner, 2026-10-12): option (a), "Recapture".**
This record does not hold the owner's own words. The decision is attributed
to the commit that implements it, `677a473`, whose message states
`Owner decision OD1, option (a) "Recapture", chosen by the owner in chat on 2026-10-12.`
Owner confirmation is pending ([CON-A-01](#unresolved-findings)).

**Options.** Browse, Recents, Search and the Draft inspector's Files actions
run builtin `cd` inside a ZLE widget for Change directory and Enter linked
directory, so no `precmd` follows. The commit record names only the chosen
option, recapture in the widget. The known alternative is the behavior it
replaced: keep `precmd` as the prompt's only capture boundary, so the prompt,
Context rows and window title describe the previous folder until the next
accepted line.

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
As with OD1, this record does not hold the owner's own words. The decision is
attributed to the commit that implements it, `7541987`, whose message states
`Owner decision OD3, option (a) "Delete it", chosen by the owner in chat on 2026-10-12.`

**Options.** The commit record names only the chosen option. The known
alternative is the state it replaced: keep the writer in the tree,
unreachable.

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

## Unresolved findings

*Pending* for the rest of the audit. Recorded so far:

- **CON-A-01: owner confirmation of OD1 (blocking review finding).**
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

## Manual acceptance pending

*Pending.*

## Proposed CLAUDE.md and .claude changes

*Pending.*
