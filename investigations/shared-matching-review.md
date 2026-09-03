# Shared matching and continued boundary review

Date: 2026-09-03. Baseline: the 536-test working tree recorded in the
[consumer cleanup review](shared-ui-consumers-review.md). This follow-up answers
the request for reusable search over supplied data and another independent
defect/boundary review.

## Component boundary

```text
Provider reads an explicit source/scope
  → captured candidates (exact value, display label, searchable text)
  → shared matcher derives indexes from query and captured text
  → feature collector applies its ranking and duplicate policy
  → shared UI displays results
  → feature validates and applies an explicitly requested action
```

`support/.zsh.matching` is an ordinary, independently sourceable peer containing
function definitions only. Its high-level `_matching_search` takes a query,
result limit and captured texts, returning one-based indexes in the caller's
local `reply` array. Keywords can appear in any order; characters within each
keyword retain their order. Empty or whitespace-only queries select the supplied
texts up to the limit. Keyword splitting has a fixed local whitespace separator,
so an unrelated caller `IFS` cannot change its meaning.

Indexes preserve the connection between exact values and separate display/search
text. The matcher does not discover files, read Git/history, fetch metadata,
rank feature targets, paint the terminal or apply an action. It has no retained
cache or registration list. Native locale still determines character/case
handling, as it does for the existing terminal UI.

Lower-level compilation/filtering lets existing collectors reuse the same
literal escaping and subsequence algorithm without forcing one ranking policy
on every task. Files retains basename/literal/fragment tiers; history retains
newest-first ordering, deduplication, selective native history lookup and its
within-word multi-fragment fallback. Xcode retains source order. Navigation,
tool discovery and USB retain prefix/substring/fuzzy tiers. Visible match-span
styling remains a bounded presentation calculation over displayed text.

File/folder action menus use the generic index filter directly. Other collectors
retain direct bounded loops when that avoids another captured-array copy or
preserves early stopping and deduplication. The compiler replaces the duplicated
character-glob construction across history, directories, navigation, Files,
tool discovery, Xcode and USB. Files' fragment compiler and redundant pattern
arrays are also replaced by the shared fragment compilation result.

Runtime entry guards select existing native completion/history, plain lists or
explicit refusal when matching support is absent. No peer sources another peer
and no bootstrap phase changed. README inventory/layout, maintained-support
guidance and the engineering boundary are updated together.

## Confirmed defects and regression evidence

Three fresh agents reviewed matching contracts, effect boundaries and consumer
quality while the coordinator integrated consumers, documentation and testing.

| Defect | Resolution and retained regression |
| --- | --- |
| Repeated-character fuzzy misses stalled several collectors for roughly 190–220 ms with one short candidate | Shared native patterns avoid combinatorial alignment backtracking. Component tests cover punctuation, Unicode, repeated characters, later-word matches and capture-sized text. Separate benchmarks measure latency; tests do not depend on wall-clock deadlines. |
| `git-discard-all` missed active multi-commit `--no-commit` cherry-pick sequencers | Detect the native sequencer before preview and during post-confirmation revalidation. Two red-first disposable-repository cases preserve conflicted files, index bytes, untracked contents and operation metadata. |
| Branch detail capture could trigger a promisor fetch for a missing commit | One same-peer branch-read boundary disables lazy fetch, transport, prompts and optional writes for branch snapshots. A synthetic failing remote-helper spy proves no transport is invoked. |
| Initial cleanup HEAD validation could trigger the same implicit transport | Invocation-local read controls now surround initial validation as well as later cleanup stages. A second remote-helper regression confirms refusal without a fetch. |
| A selected ref named `--detach` was interpreted as a switch option | Separate native options from the exact selected branch operand. A native PTY case verifies symbolic HEAD, selected commit and unchanged main ref. |
| Xcode capture-limit text was evaluated as arithmetic before validation | Validate decimal text and signed-integer range before arithmetic; retain the default and minimum. Fifteen cases cover expressions, side effects, huge values, leading zeros, output and temporary-file cleanup. |

New component APIs began with failing capability tests. Adapter refactors began
with green characterization. A native missing-matcher regression failed before
new guards and passes afterward. The first combined run also caught a missed
Folder actions call to a removed helper; existing native browser, workspace and
grouped-action regressions reproduced it. The caller now compiles once and uses
the shared index filter; no assertion was weakened.

Independent evidence includes 85,410 generated whole-query/word-gap comparisons
and 972 complete collector comparisons against the baseline, covering empty and
whitespace queries, literal punctuation, Unicode, multiple result limits,
duplicate values, empty labels and required path filters. Nested API checks
verify caller-local results without leaking parameters or changing outer reply
values/options. Folder actions was added to the final differential review after
the integration finding.

## Performance and final validation

The final unfiltered native suite passed **550 tests, 0 failures** in 127.8
seconds, including 14 new cases beyond the 536-test baseline. All 102 native
Zsh files passed syntax checks. Whitespace checks and isolated bootstrap
double-sourcing passed without diagnostics. The combined suite covers native
journeys, the previously failing callers, missing-peer fallbacks, safety/help
contracts, inventory, installation and four peer orders in both color schemes.
Component microbenchmarks alone are not evidence of complete-view latency.

Complete collector measurements use five alternating batches of three calls,
with identical captured data, ranking and result construction on both sides:

| Workload | Before → after, ms |
| --- | ---: |
| Repeated 40-character miss/hit, navigation | 0.124 → 0.125 |
| Same repeated-character query, tool discovery | 188.710 → 0.110 |
| Same repeated-character query, directories | 190.000 → 0.120 |
| Same repeated-character query, File actions | 189.290 → 0.079 |
| Same repeated-character query, history | 190.950 → 0.153 |
| Normal navigation, 1,000 candidates, limit 11 | 8.282 → 8.174 |
| Navigation, 262K ASCII characters, near-end match | 30.191 → 9.176 |
| Navigation, 130K Unicode characters, near-end match | 26.312 → 9.801 |

These measurements include filtering/ranking/result construction, but exclude
provider acquisition, input, rendering and terminal painting. Navigation already
used a bounded subsequence algorithm, so its small repeated-character case stays
unchanged. Other collectors lose the combinatorial stall; ordinary navigation
stays comparable. Warm bootstrap medians from three alternating batches of eight
isolated starts remain comparable: dark 53.845 → 53.727 ms, light
53.867 → 53.507 ms. Native completion is primed only in disposable homes.

Xcode/USB complete warm setup, collect/render/show measurements use five
alternating batches of 30 synthetic views with physical painting stubbed:

| Workload | Before → after, ms |
| --- | ---: |
| USB empty query, 500 choices | 1.619 → 1.637 |
| USB with details | 4.819 → 4.844 |
| USB fuzzy hit / ordinary miss | 7.527 → 7.422 / 8.240 → 8.435 |
| Xcode empty query, 20 choices | 2.701 → 2.692 |
| Xcode fuzzy hit / ordinary miss | 3.510 → 3.489 / 1.237 → 1.246 |

These approximately ±2% changes do not establish a general speedup. A generic
filter alternative added a captured-text array without a consistent benefit
for Xcode, so its direct bounded collection loop remains. Measurements exclude
provider acquisition, physical terminal painting, initial wrapping and real
input timing. They are observations from native Zsh 5.9 on this arm64 macOS host.

All fixtures are local and synthetic. Destructive behavior is tested only in
disposable repositories; native tools that could affect real devices or launch
applications are replaced by test stand-ins. No private configuration/history,
real clipboard, remote transport, real disk formatting, commit, push or deployment
is involved. The earlier browser validation remains applicable: this follow-up
does not change website assets. No additional manual Terminal.app fullscreen or
windowed visual acceptance is claimed.
