# Investigations

Decision records, measurements and bounded experiments behind Compozsh's
design. They are **evidence, not requirements**: shipped rules live in
[`engineering/`](../engineering/), which links here for rationale. Timings are
observations from their recorded machine and commit, never universal
thresholds. Keep records historical — when a decision is superseded, add a
status note that links forward rather than rewriting the evidence.

Add a record when a decision needs measured or researched justification, or
when work spans sessions (record progress and remaining steps there).

## Active records

| Record | What it establishes | Backs |
| --- | --- | --- |
| [arithmetic-input-validation](arithmetic-input-validation.md) | Text that reached Zsh arithmetic, the sweep's site ledger and validation bounds | [Zsh conventions](../engineering/zsh.md#idioms), [security](../engineering/security.md#handling-sensitive-data) |
| [composer-and-atlas](composer-and-atlas.md) | Command composer, help Compose example and change atlas boundaries | [interaction design](../engineering/interaction-design.md) |
| [critical-path-performance](critical-path-performance.md) | Measured hot-path optimizations and deferred provider findings | [performance](../engineering/performance.md) |
| [excellence-2026-10-12](excellence-2026-10-12.md) | In progress: unattended quality pass; suite baseline, latency baselines and their A/A noise floor | [performance](../engineering/performance.md#measuring-latency), [verification](../engineering/verification.md#required-verification) |
| [git-comparison-design](git-comparison-design.md) | Revision comparison usability revision and endpoint correctness | [Git workspaces](../engineering/workspaces/git.md#scopes-and-comparisons) |
| [git-review-key-repeat-latency](git-review-key-repeat-latency.md) | Preview settlement versus input debouncing; portability rule | [Git workspaces](../engineering/workspaces/git.md#responsive-navigation) |
| [in-memory-capture-parsing](in-memory-capture-parsing.md) | Here-string temporary files, exact in-memory replacements and prompt latency | [security](../engineering/security.md#handling-sensitive-data), [Zsh conventions](../engineering/zsh.md#idioms) |
| [manual-concurrency](manual-concurrency.md) | Async manual capture lifecycle and the unshipped worker-pool experiment | [manual cache](../engineering/manual-cache.md#asynchronous-prompt-capture) |
| [palette-perception](palette-perception.md) | Palette research, contrast targets and diff colors | [architecture](../engineering/architecture.md#shared-behavior-ownership) |
| [shared-architecture-sign-off](shared-architecture-sign-off.md) | Decision record for the shared support/UI extraction | [architecture](../engineering/architecture.md) |
| [terminal-startup-latency](terminal-startup-latency.md) | First-editable-prompt diagnosis, cache design and measurements | [caching](../engineering/caching.md), [manual cache](../engineering/manual-cache.md) |
| [tool-entry-points](tool-entry-points.md) | Task-family command consolidation and retired commands | [interaction design](../engineering/interaction-design.md#entry-points) |
| [usb-progress-integer-bounds](usb-progress-integer-bounds.md) | USB progress, phase, disk-size and GPT numbers bounded before arithmetic; native capped read | [security](../engineering/security.md), [SECURITY.md](../SECURITY.md#external-devices-and-task-routing) |
| [xcode-destination-run](xcode-destination-run.md) | Native argument evidence for Run on every concrete destination | [Xcode workspace](../engineering/workspaces/xcode.md#run-targets) |
| [xcode-discovery-performance](xcode-discovery-performance.md) | Where Xcode discovery waits; lazy destinations and cancellation | [Xcode workspace](../engineering/workspaces/xcode.md#dashboard) |
| [xcode-log-monitor](xcode-log-monitor.md) | Shared log reader, device console lifecycle, bounded matching | [Xcode workspace](../engineering/workspaces/xcode.md#run-view-and-logs) |

Benchmarks in [`benchmarks/`](benchmarks/) are standalone measurement scripts,
run separately from the suite in a disposable `HOME`/`ZDOTDIR`:
`async-first-prompt.zsh` and `manual-async-parity.zsh` measure the shipped
async manual capture (see [verification](../engineering/verification.md));
`manual-delivery-budgets.zsh` and `manual-parallelism.zsh` support the
concurrency record; `prompt-git-render.zsh` compares complete prompt rendering
of two trees inside and outside Git repositories
([in-memory parsing](in-memory-capture-parsing.md#measurements));
`isolated-startup.zsh` compares isolated interactive startup (sourcing, and
the first editable prompt in a PTY, fresh and warm) and
`workspace-first-frame.zsh` the first painted full-screen frame of Browse,
Search, Ctrl-R history and Git review in a PTY, both alternating two trees
([excellence run](excellence-2026-10-12.md#method));
`first-editable-prompt.zsh` is historical (pre-async), and
the superseded `manual-cache-parity.zsh` is in `archive/benchmarks/`.

## Open backlog

Investigated opportunities that were deliberately deferred. Each needs its own
measurement and design decision before implementation.

- **Large-folder providers.** Preparing the directory browser over 20,000
  files took about 507 ms and bounded local file search about 574–605 ms; a
  native-glob partition prototype was slower and rejected.
  ([critical path](critical-path-performance.md#deferred-findings))
  *Unreviewed lead, 2026-10-11:* a planning pass measured that most of that
  time is locale-aware sorting of full paths (≈565 ms under `en_US.UTF-8`
  versus ≈148 ms under `C` for Browse; the harness forces `LC_ALL=C`).
  Partitioning with unsorted glob qualifiers (`*(N-/oN)`, `*(N-.oN)`) and
  sorting only what is displayed reached ≈157 ms with identical output in its
  prototype; per-batch `(on)` sorting dominates local search similarly.
  Reproduce with characterization tests and PTY measurements before adopting.
  (Its other note, that nested repositories' `.git` metadata consumed the
  visit budget, is fixed: the walk skips `.git` at any depth, 2026-10-12.)
- **Native peer compilation** (`zcompile`): deferred until artifact freshness
  and loader behavior have a design. ([critical path](critical-path-performance.md#deferred-findings))
- **Xcode repeated workflows:** keeping a workspace across actions, or
  cross-invocation caching, changes the release-on-action contract and needs a
  revalidation/freshness decision. ([discovery](xcode-discovery-performance.md#recommended-implementation-order), item 3)
- **Xcode Run metadata:** a bounded single-conversion settings parser for
  larger target graphs, if broader measurements justify it. ([discovery](xcode-discovery-performance.md#recommended-implementation-order), item 4)
- **Manual capture worker pool:** the four-worker result is a measured
  candidate, kept separate from the shipped single worker. ([concurrency](manual-concurrency.md))
- **Filesystem catalog cache:** `diskutil listFilesystems -plist` at format
  entry is a possible public capability cache, pending provenance and cost
  evidence. ([startup](terminal-startup-latency.md#broader-repeated-work-audit))
- **Second reference Mac:** startup latency has not been measured directly on
  the second target Mac. ([startup](terminal-startup-latency.md))
- **USB progress polling:** replace the per-tick `/usr/bin/stat` in
  `_usb_dd_bytes_observed` with a bounded native read, and keep
  `_usb_progress_model`'s percentage from wrapping for 17–18-digit totals
  (display only). ([USB bounds](usb-progress-integer-bounds.md#proposals-not-implemented))

### Known code issues (found 2026-10-11, not yet fixed)

- User-facing errors (`_git_review_session`; `external-device`, `_usb_flash`
  and `_usb_format` in `.zsh.usb`) and `--help` text (`_usb_help_flash`,
  `_usb_help_format`) still name the retired `.zsh.ui` / `.zsh.matching`
  peers.
- `sudo` and other prefix commands are classified as the command itself, so
  `sudo rm -rf x` shows `RUN` rather than `CAUTION`.
- `g --help` says "Ctrl-X is inactive here" (`_compozsh_help_g`), which
  reads as stale; the shared UI also carries an `atlas` options kind no caller
  sets.
- Some `print` calls in `.zsh.tools`, `.zsh.sudo-touch-id` and
  `.zsh.navigation` lack `-r --`. At least one is a security issue, not
  style: `.zsh.tools:329` prints a sanitized repository path without `-r`,
  and sanitization replaces control characters but not backslash escapes, so a
  directory name containing `\e[…` could inject terminal sequences after
  `g --discard-all`.
- Leftover `my-zsh` identifiers: highlight memo tags (`my-zsh-picker`,
  `my-zsh-autosuggestion`) and the test harness's `my-zsh-tests.*`
  temporary-directory prefix.
- The real-FAT32 `hdiutil` round-trip test fails on the current macOS 27
  host; cause not yet investigated.

## Archive

[`archive/`](archive/) keeps superseded records for history only. Each file
opens with a note pointing to the contract that now holds its rules.

| Archived record | Superseded by |
| --- | --- |
| appearance-review, palette-ownership-design | palette-perception; [architecture](../engineering/architecture.md#shared-behavior-ownership) |
| ui-components-design, ui-extraction-review, shared-ui-consumers-review, shared-matching-review, shared-data-and-effects, production-duplication-audit (three passes) | shared-architecture-sign-off; [architecture](../engineering/architecture.md#shared-support-organization) |
| focus-responsive-ui, tooling-overhaul, help-workspace | [full-screen](../engineering/full-screen.md) |
| git-file-navigation | [Git workspaces](../engineering/workspaces/git.md#file-projections) |
| autocd-lens, runtime-version-advisories | [prompt](../engineering/prompt.md) |
| manual-summaries, `benchmarks/manual-cache-parity.zsh` | [manual cache](../engineering/manual-cache.md), manual-concurrency |
| showcase-prompt-fidelity | [website](../engineering/website.md) |
| xcode-run-view | [Xcode workspace](../engineering/workspaces/xcode.md#run-view-and-logs) |
