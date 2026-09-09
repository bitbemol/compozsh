# Critical-path performance

This pass optimizes the behavior shipped in `ff58981` (`Make Xcode discovery
lazy and cancellable`). Measurements compare an immutable archive of that
commit with the modified implementation. Prototypes from the preceding
investigation were remeasured after implementation. These are measurements of
the final local changes, not estimates from the prototypes.

## Implemented changes

- Manual capture normalizes only the formatted lines needed for the first
  NAME paragraph. A newline followed by a backspace retains the original
  whole-buffer normalization, preserving unusual line-joining behavior.
  Captured input/output limits, native formatter isolation and cleanup, and
  first-TTY capture timing remain unchanged.
- Shared matching keeps the existing per-candidate path for nearby matches,
  then uses Zsh's indexed pattern search to skip nonmatching text. Ranking,
  exclusions, deduplication, limits and source indexes retain their existing
  boundaries. Populated fallback and append policies retain their existing
  algorithm.
- Autosuggestions compare a bounded literal slice directly from native history
  before copying a candidate. Drafts longer than 256 characters first compare
  64 characters, then compare the complete prefix. Ordinary drafts need one
  literal comparison. Exact-only entries remain ineligible; the complete prefix
  still decides, with the same newest-first 512-slot history window and
  control-character rejection.
- Numeric highlighting rejects a clearly nonnumeric first character before
  running the existing numeric grammar.
- Tool discovery selects candidate public keys in native Zsh before sorting
  and traversing them. Complete name/source/companion validation still runs,
  and every invocation reads live function metadata.

## Fresh measurements

Times below are medians in milliseconds on the same arm64 Mac, running macOS
27.0 and native Zsh 5.9 (`arm64-apple-darwin26.0`). Fixtures use
isolated homes, explicit system PATH, no private initializer or user history,
and synthetic captured lists/history. No system caches were flushed.

| Path and workload | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| First editable prompt, complete configuration | 3968.82 | 3159.82 | 20.4% |
| Manual summary capture | 3415 | 2624 | 23.2% |
| Picker, 10,000 ASCII paths, narrow query | 137.65 | 18.10 | 86.9% |
| Picker, 10,000 ASCII paths, no match | 191.43 | 13.32 | 93.0% |
| Picker, 10,000 long Unicode paths, narrow query | 232.29 | 75.53 | 67.5% |
| Picker, 10,000 long Unicode paths, no match | 344.64 | 112.88 | 67.2% |
| Picker, 10,000 ASCII paths, broad query | 6.74 | 6.71 | approximately unchanged |
| Picker, 10,000 long Unicode paths, broad query | 8.33 | 8.48 | approximately unchanged |
| Editing a 4 KiB draft | 18.11 | 3.64 | 79.9% |
| Editing a dense 361-character command | 18.71 | 16.12 | 13.8% |
| Editing a short command | 3.16 | 3.14 | approximately unchanged |
| Editing a multiline draft | 3.53 | 3.51 | approximately unchanged |
| Editing with dense repeated-prefix history | 42.24 | 15.14 | 64.2% |
| Short draft with long Unicode history entries | 41.89 | 5.64 | 86.5% |
| Long draft with long unrelated history entries | 56.66 | 6.50 | 88.5% |
| Tool catalog plus help-preview preparation | 12.71 | 8.33 | 34.4% |
| Tool catalog capture alone | 4.82 | 0.56 | 88.3% |

Picker measurements use three alternating real-PTY samples per case, from
filter input to the emitted frame. Separate five-run collect/render timings
confirmed the gains: narrow ASCII collection/render fell from 126.25 to
8.87 ms; no-match from 191.99 to 12.01 ms. Broad collection/render stayed at
about 1.8 ms. Rendering alone was already inexpensive in the initial profile.
Long Unicode matching still has meaningful residual cost; these changes do
not make every query instantaneous.

Catalog measurements use five alternating isolated shells per version, each
measuring 200 captures and 30 complete catalog/help preparations. Every sample
produced the same catalog. Source-time and first editable prompt timings are
distinct: source-only timings omit first-prompt provider work.

The final integrated startup comparison ran after the code was frozen and the
full suite passed. Three fresh homes per version used a balanced alternating
order, from source start through the final line-init hook. Baseline samples
were 4,726.356 / 3,968.821 / 3,960.073 ms; optimized samples were 3,152.842 /
3,159.819 / 3,215.561 ms. All six retained 2,308 manual names. Native completion
state was fresh in each home; system filesystem caches were left intact. The
median gain was 809 ms, and first-prompt manual work remains the largest cost.

Three paired manual captures retained identical values for all 2,308 names,
summaries and source attributions. A separate first-prompt experiment changed
only the manual peer against the baseline: median 4,022 to 3,195 ms (20.6%).
This isolates the manual improvement from other edits in this pass. Warm
manual lookups already return immediately from the shell-memory snapshot;
the gain is in fresh capture, without moving work into editing hooks.

Editing measurements use three fresh PTY sessions per version/workload and
40 alternating draft edits per session. The endpoint is completion of the last
pre-redraw hook, excluding terminal-emulator pixel presentation. Long-draft p95
fell from 18.411 to 3.925 ms; the first edit fell from 18.952 to 4.405 ms.

## Correctness and safety

These are behavior-preserving refactors. New characterization tests ran green
against the original implementation before each change and remain green
afterward; no timing threshold is embedded in product tests. The matcher also
passed 5,400 differential cases covering ranking, source order, duplicates,
exclusions, literal shell-looking text, Unicode, shortened/missing/oversized
text arrays, and all text policies. New editor tests cover full long prefixes,
newest safe matches, exact-only entries, Unicode prefix boundaries, hostile
caller options, and quoted/signed/exponent/hexadecimal/base numeric forms.
Catalog tests preserve the existing locale-sensitive ordering and name grammar
under unusual caller options.

New manual characterization covers bold/underline overstrikes, wrapped NAME
paragraphs, newline/backspace interactions, control-character rejection,
240-character truncation, actual native formatting before a large document
tail, and temporary-directory cleanup. All 22 focused manual tests pass,
including existing native editing/resize coverage.

No project disk cache, compiled peer cache, background worker or new dependency
is introduced. Matching and editing remain local computations over existing
state; discovery remains at its established capture boundary.

Independent reviews additionally checked 3,600 matcher cases, 6,750 numeric
classification cases, 4,374 manual normalization cases and 774 final
autosuggestion cases against the baseline. The history review included missing
keys, empty prefixes, combining characters, emoji, malformed UTF-8, control
characters, exact duplicates and unusual options; complete suggestions,
statuses and caller options stayed identical.
Review found a performance regression in the initial autosuggestion prototype
when many history entries shared the first 64 characters. That finding drove
additional characterization and a corrected long-draft path; the initial
prototype is not the final implementation.

Final verification passed **852 tests with zero failures** in 202,082 ms.
Native syntax checks passed for all 226 shell files; the final editor update
also passed its focused syntax checks. Isolated double sourcing, supported
peer-order checks, shared-support ownership checks, the README unit inventory,
security/documentation contracts and `git diff --check` passed. Native suite
coverage includes editing, bracketed paste, Escape/cancellation, resizing,
feature combinations and screen cleanup. This pass used PTYs; it did not add
a manual Terminal.app visual acceptance run or physical-device testing.

## Deferred findings

The preceding analysis measured about 507 ms to prepare a directory browser
over 20,000 files and 20 directories, and about 574–605 ms for bounded local
file search. A native-glob partition prototype was slower and was rejected.
Those provider paths are unchanged in this pass. Native peer compilation also
remains deferred because artifact freshness and loader behavior need a
separate design. No speedup is claimed for either area.

## Local measurement artifacts

The implementation pass retained a baseline archive, picker scripts and raw
samples, catalog measurements, manual and editor comparisons, integrated
first-prompt samples, the full-suite log, and independent history parity checks
in temporary local storage. Their machine-specific locations are omitted;
these artifacts are not distributed with the repository and their continued
availability is not guaranteed.

These were investigation artifacts, not runtime storage or a new benchmark
framework. The repository tests protect semantics; performance
comparisons are repeated separately to avoid scheduler-dependent assertions.
