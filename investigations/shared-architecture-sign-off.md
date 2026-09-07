# Shared architecture review and sign-off

Recorded 2026-09-06. Baseline: commit `749400f`, before the shared-data
extraction and support organization changes. The final tree includes the three
duplication follow-ups and the small simplifications recorded here.

## Review conclusion

Three agents independently reviewed UI composition, shared functionality and
support conventions against the baseline. The primary reviewer checked scope,
test migration, production size and performance evidence. No concrete
architecture or correctness blocker remains in the reviewed changes.

The design improves ownership and fixes demonstrated bugs. It does not improve
every metric: more files and shared calls have a cost, production text is nearly
unchanged in size, and some hot paths are slower. Unknown defects cannot be
classified as unimportant merely because these reviews did not find them.

## Demonstrated changes

| Axis | Evidence and practical implication |
| --- | --- |
| Organization | The largest support file falls from 2,924 to 795 lines. Classified entries have one declared first function and exclusive helpers. A responsibility can be reviewed without reading the old UI/runtime monoliths. |
| Composition | Existing view scope, input loops, rendering and screen ownership remain recognizable. The split adds no registry, loader phases, dependency graph, runtime sourcing or universal execution controller. |
| Reuse | Matching/projection, display calculations, palette lookup, Git filter overrides/capture, native scalar reads, effects and checksum parsing now have owning implementations used by existing callers. |
| Correctness | Regressions cover ambiguous Git filter names, root commits, combining accents and source offsets, inherited Zsh locals, checksum validation, decimal counts and regex/IFS isolation. Shared callers receive the same corrections. |
| Privacy/effects | Exact targets remain separate from display labels; provider capture, action validation and post-cleanup effects retain their owners. Purity labels document input/effect contracts rather than sandbox arbitrary input. |
| Compatibility | Native tests exercise independent/repeated sourcing, different peer orders, missing support, copied/symlinked installations and PTY interactions. The bootstrap is unchanged. |
| Development | First-entry naming and private-helper ownership are checked mechanically. Runtime extraction preserves all 13 original runtime function bodies. Faster future debugging is an expected benefit, not a measured claim. |

Production peer counts and physical lines were measured recursively, including
new files and excluding tests/docs/assets:

| Metric | Baseline | Final |
| --- | ---: | ---: |
| Peers | 21 | 78 |
| Physical lines | 26,050 | 26,240 |
| Nonblank, noncomment lines | 23,447 | 23,366 |
| Largest support file | 2,924 | 795 |

Physical lines grow by 190; nonblank, noncomment lines shrink by 81. These
counts do not measure semantic complexity. The main gain is shared ownership
and consistent behavior, not a substantial reduction in code volume. More
support files make explicit test fixture loading more verbose; no new test
loader framework was introduced to hide that dependency.

## Final simplifications and rejected abstractions

- Removed three USB result functions that only forwarded to the shared
  presenter. The media dispatcher now calls it directly, with the same raw
  fallback and return behavior. Characterization was green before the refactor.
- Removed a redundant palette-resolver preload from the peer-order experiment.
  Every peer now enters that experiment through its tested order. The richer
  palette/completion/re-source assertions pass without the preload.
- Aligned SECURITY's documented client-keyword scan with the native test's
  exclusion of full-line comments. An existing prompt-classifier comment had
  contradicted the documented empty-output expectation; executable checks stay
  intact.
- Kept two-ended abbreviation separate from prefix-only clipping. Bias/tail
  behavior and prefix privacy differ; another shared hot-path call has no
  established net benefit. Different Git policies and asynchronous process
  ownership likewise remain with their callers.
- Retained small shared entries that have actual independent consumers, such
  as document direction, action metadata and acceptance. No speculative
  configurable framework or wrapper was added just to remove similar lines.

## Performance and costs

A fresh whole-change startup comparison used 14 retained interleaved samples
after three warmups, stock Zsh 5.9, UTF-8, minimal PATH and separate disposable
HOME/ZDOTDIR environments with no private initializer. Median launch/bootstrap
time was **64.86 → 67.18 ms**, approximately **2.32 ms added**. This is a local
observation, not a compatibility threshold or a startup speedup.

Earlier bounded measurements and differential checks are retained with their
specific baselines rather than combined into a misleading overall percentage:

- [Data/effects extraction](shared-data-and-effects.md): lazy matching avoids
  eager catalog copying; several full-scan workloads improved. The eager
  prototype was rejected on measured latency grounds.
- [First cleanup](production-duplication-audit.md#verification-and-measurements):
  prompt middle abbreviation improved, while shared projection adds roughly
  0.05–0.06 ms for short queries. Shared Git safety is principally a correctness
  gain. Differential coverage compared 144 collector and 7,344 display cases.
- [Second cleanup](production-duplication-audit-second-pass.md#integration-and-performance-evidence):
  metadata reuse eliminates one repeated stat subprocess per installer
  candidate. Regex-state isolation adds approximately 2–3 µs per assignment
  check; no general speedup is claimed.
- [Third cleanup](production-duplication-audit-third-pass.md#performance-observations):
  prompt prefix clipping improves about 60–67% in the measured cases, while
  truncated picker fitting adds 10–19 µs. Correct Unicode reader preparation
  adds about 9.29 ms per 100 long Unicode lines; ASCII preparation remains
  close to baseline. Cached repaint was not measured.

Memory use, developer time and manual Terminal.app visual quality were not
benchmarked. The reviewed design is accepted for its ownership/correctness
benefits with these documented costs, not as a universal performance upgrade.

## Verification and sign-off

Final native suite: **732 passed, 0 failed**, 166.3 seconds, including actual
PTY journeys, peer-order convergence, support ownership, security boundaries
and installation layouts. The original extraction baseline had 684 passing
tests; the increase adds regression/contract coverage rather than replacing
existing assertions with implementation-only checks.

Shell syntax checks, whitespace checks and an additional isolated interactive
double bootstrap load passed. The README inventory covers all 78 peers. The
documented network-client keyword check has no executable matches; this is
supporting evidence, not proof by keyword absence.

Engineering sign-off: the reviewed changes are suitable to commit, with the
performance costs above explicitly accepted. Manual Terminal.app visual
acceptance remains unperformed and is not implied by the native PTY results.
No real device operation, private history/configuration access, push or
deployment was performed.
