# Performance

Compozsh runs in every new interactive shell, and parts of it run before every
prompt and ZLE redraw. Those paths are latency-sensitive.

## Essentials

- **Measure, don't assume.** Latency-sensitive changes carry before/after
  numbers from repeated runs; never optimize from a single sample.
- **Hot paths do no discovery.** Typing, highlighting, autosuggestion, lens
  derivation, repaint and resize launch no subprocess, touch no network, write
  no files and avoid unbounded scans; they reuse captured facts.
- **Capture at defined boundaries.** `precmd` is the prompt's fact-capture
  boundary, repeated once after an explicit in-widget directory change
  ([prompt](prompt.md#project-and-runtime-context)); workspaces capture on
  entry or explicit refresh. Approved background work is limited to the
  exceptions listed below.
- **Startup budget.** On the reference Mac, isolated startup stays in the
  tens of milliseconds and should not exceed roughly 50 ms without a measured,
  justified tradeoff.

## Choosing between designs

- When a change touches startup, `precmd`, ZLE redraw or workspace capture and
  candidate designs plausibly differ in cost, benchmark the realistic ones
  under the same workload and keep the fastest that preserves correctness,
  security and clarity. Elsewhere, choose the clearest design.
- Rank alternatives by semantic correctness, then safety and predictable
  failure, idiomatic modern Zsh, measured speed, then code size. Reject a
  faster option that weakens shell semantics or a security boundary, and a
  compact one that is slower or less clear in a hot path.
- Record measurements in the handoff: the workload, fresh versus warm or
  cache-assisted results, and several runs, so filesystem and process-startup
  noise don't decide the design.
- Measure at the affected scope: isolated startup for initialization,
  complete prompt rendering for prompt work (inside and outside
  repositories), redraw latency for ZLE work. Microbenchmarks may explain a
  result but never replace an end-to-end measurement.

## Hot-path rules

- Syntax highlighting and autosuggestions launch no subprocess, perform no
  network access, write no files and avoid unbounded scans. The highlighter's
  bounded checks of literal path tokens are its only filesystem reads.
- Prompt derivation and repaint (including the editor's line-init,
  pre-redraw, line-finish and manual Context adapters) derive from the prompt
  snapshot and ZLE state only — see [prompt](prompt.md).
- A live resize recalculates presentation from in-memory facts; it never
  reruns Git, language tools or project detection.
- Prompt code minimizes external commands and never adds a per-prompt
  subprocess when native Zsh state or an existing result suffices.
- Never recursively scan whole repositories: use bounded upward searches,
  exact marker checks and shallow conventional source directories. Never
  execute repository-local wrappers, binaries, manifests or scripts to
  discover prompt information.
- Recursive add-on discovery runs only inside the shared `.zsh.addons` beside
  the resolved `.zshrc` and the configuration base's `.zsh.addons`: one native
  glob, regular `.zsh.<name>` files in deterministic order for reproducible
  diagnostics, no nested symlink directories. Correctness never depends on
  that order.
- Bound user-controlled display work and result counts, and keep the
  existing fuzzy-history maximum and width/height-aware rendering.

## Measuring latency

- **Startup:** time several isolated `zsh -dfi` startups before and after,
  fresh and warm, and report the median and range.
- **Workspaces and providers:** measure end to end in a real PTY — from the
  entry keys (for example path + Tab, or Return in Search) to the first
  painted frame — against an immutable baseline copy, alternating runs.
- **Use realistic conditions.** The test harness forces `LC_ALL=C`, which
  hides locale-aware costs: sorting long paths under `en_US.UTF-8` can cost
  several times more than under `C`. Measure under a UTF-8 locale with
  realistic path lengths and folder sizes as well.
- Commit reusable measurement scripts under `investigations/benchmarks/` and
  record results, environment and commit in an investigation.

## Caching

- Prefer a small memoization point around a proven repeated cost; don't cache
  because caching sounds faster.
- Runtime and tool version probes cache in memory only, keyed by every
  selector that can change the answer; `compozsh --refresh` invalidates them.
- Reproducible public system data may use disposable persistent caches under
  the [caching contract](caching.md). Never persist user or project facts or
  make a feature depend on a cache. Zsh's native completion dump is not
  feature-state storage; SECURITY.md
  [discloses it](../SECURITY.md#native-completion-dump).

## Approved background work

No cache daemon, background worker, timer loop or eager startup scan exists
without an explicit architectural decision. The approved exceptions are:

| Exception | Owner | Contract |
| --- | --- | --- |
| One bounded asynchronous manual-summary capture requested at the first TTY `precmd`; the prompt returns before discovery or cache I/O | `.zsh.manual` | [manual cache](manual-cache.md#asynchronous-prompt-capture) |
| Working-changes auto-refresh worker inside the Git review screen session | `.zsh.git-review` | [Git review](workspaces/git.md#git-review-workspace-boundary) |
| One system-Vim syntax child per Git document screen session | `.zsh.git-syntax` | [Git review](workspaces/git.md#git-review-workspace-boundary) |

Help-description capture is not background work: it runs synchronously and
bounded at a TTY prompt boundary, never while editing
([prompt](prompt.md#about-and-alias-expansion)). Measure the first editable
prompt and complete-description arrival separately from source time and warm
redraw;
[terminal startup latency](../investigations/terminal-startup-latency.md)
holds the current evidence.
