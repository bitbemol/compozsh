# Independent palette and UI extraction review

Date: 2026-09-03.
Scope: the complete uncommitted palette/UI extraction, including the new
`support/.zsh.ui` peer, its feature adapters, native output consumers and tests.

The subsequent [consumer cleanup and broader code review](shared-ui-consumers-review.md)
records follow-up fixes, final combined validation and new measurements against
this review's 519-test result.

Three fresh reviewers covered architecture/code quality, UI/UX and accessibility,
and regressions/performance. The coordinating reviewer checked public extension
APIs, palette-reset boundaries, documentation and integrated validation. All
reproductions used disposable homes and synthetic data. No private configuration,
history or project data was inspected; no clipboard or GUI action was performed.

The review compared the working implementation with the frozen pre-extraction
configuration and the 508-test extraction baseline. Existing green tests were
supplemented with focused regressions for each proven finding, with observed
failure before the corresponding fix. Some findings concern behavior that
predated extraction; this review covers the complete resulting feature.

## Findings resolved

| Finding | Impact | Resolution and evidence |
| --- | --- | --- |
| Public project segments defaulted to white | P2: omitted colors bypassed the palette and could be unreadable in light mode | `prompt_add_project_segment text [color]` now reads the current tool role, with native text when unavailable; explicit native colors remain supported. Dark/light/custom/removed-role tests cover the public API. |
| Completion candidates ignored color opt-out/capability | P2: filename colors survived `NO_COLOR` and limited-color terminals while headings were plain | The deferred callback checks `NO_COLOR`, `TERM` and native color capacity. Native PTY tests verify plain candidate names and preserved explicit `LS_COLORS`/replacement `zstyle` behavior when enabled. Resolving style arrays off-terminal remains inert. |
| Removing public palette maps enabled arithmetic subscripts | P2: normal role names could expand unrelated shell variables and abort prompt, highlighting, completion, autosuggestion or UI rendering | Readers check association type before indexing and fall back without recreating maps. Tests exercise deleted, scalar and indexed maps, selected/native fallbacks, literal role names and explicit empty styles. |
| Literal query titles said “No selection” | P3: the title contradicted a valid text-submission action | Shared title chrome names the query action or asks for text when the field is blank. Native tests retain literal submission and whitespace rejection. |
| Empty choices advertised unavailable Enter | P3: footer/guide promised an action that only beeped | Title/footer/guide and Enter use the same acceptance predicate. Empty choices omit acceptance; zero-match readers retain their supported Enter and Refresh actions. Native PTY coverage verifies both. |

The selected palette values are unchanged. Existing legacy empty-style priority,
explicit empty syntax suppression, numbered result slots, exact target values,
source bookmarks and post-screen action boundaries are preserved.

## Architecture and quality conclusions

- `support/.zsh.appearance` remains the sole default writer; readers resolve roles at
  invocation without a second palette or runtime table repair.
- `support/.zsh.ui` owns shared components, keyboard decoding, painting and restoration.
  Scoped view defaults surround actual callback execution; operation/selection
  outputs escape intentionally, and readers save bookmarks before returning.
- Optional peers are checked at entry. Native nested ZLE uses the UI-owned
  `vared -i` widget without a new global line-init coordinator or loader phase.
- Providers, task matching and final effects remain feature-owned. Frame and
  resize work uses captured facts. No new file/network access, persistent cache,
  background process or component registry was introduced.
- Existing complex Files and Git document controllers retain explicit state
  composition while consuming the same shared components. Captured ref maps
  are copied once per view entry; document snapshots are not copied per frame.

## Validation

The final integrated native suite passes **519 tests, 0 failures**. All 11 new
regression cases pass, alongside the existing 508-test extraction baseline.
Syntax, whitespace and isolated bootstrap double-source checks pass.

Focused evidence includes native query/choice/reader acceptance, whitespace and
empty-result behavior, reader refresh, terminal restoration, completion color
opt-out/capacity, removed palette maps, extension defaults and explicit overrides.
An independent UI-only PTY accepted the exact second value with Down+Return and
returned cancellation on standalone Escape with editor/appearance/output absent.

The final full suite also covers public help, privacy/security documentation,
shipped-peer inventory,
symlink/copy installation discovery, four loading orders, both palettes,
custom/default maps, re-sourcing and native feature journeys.

A subsequent placement refactor moved appearance and UI into
`.zsh.addons/support/`. Both implementation bodies are byte-identical to the
reviewed versions; only their introductory ownership comments changed. The
expanded symlink/copy installation checks passed before the move, then the full
519-test suite passed again with the new paths. Support stays installed during
normal customization and follows the existing order-independent peer loader.
The performance measurements below precede this folder move.

## Performance interpretation

Measurements use native Zsh 5.9 on arm64 macOS 27.0, isolated public configuration
and synthetic fixtures. Runs are interleaved; differences are observations from
this host, not universal latency promises. Warm startup primes native completion.

Frame benchmarks call the full shared render/show pipeline with `zle -R`
stubbed. They pre-render then hold selection/content/geometry constant, measuring
warm frame and style work. They exclude physical painting, initial document
wrapping, selection-to-preview latency and resize rewrapping. Native PTY tests
validate those interactions behaviorally without asserting wall-clock deadlines.

Final-code medians, in milliseconds, from three interleaved batches (eight
starts or 100 frame/view iterations per batch):

| Workload | Dark before → final | Light before → final |
| --- | --- | --- |
| Warm bootstrap | 54.660 → 54.743 | 54.808 → 53.679 |
| Metadata frame, 10 rows, active selection | 4.411 → 4.583 | 4.338 → 4.530 |
| Metadata frame, 10 rows, inactive selection | 4.392 → 4.633 | 4.310 → 4.484 |
| Diff frame, 198 visible syntax spans | 8.090 → 7.283 | 8.041 → 7.309 |
| Choice entry, 1,000 captured refs | 0.031 → 1.201 | 0.032 → 1.202 |

Warm startup remains comparable. Metadata frames add 0.17–0.24 ms with the
shared acceptance checks and guarded palette readers. Diff frames remain about
9–10% faster than the pre-extraction implementation. The largest ref-choice
fixture adds about 1.17 ms per entry for view scoping. These bounded costs did
not produce a performance blocker in the measured workloads.

The earlier extraction benchmark is documented in
[the component design](ui-components-design.md#measured-performance). A separate
complete-prompt benchmark with a synthetic default-color extension measured
2.545 → 2.618 ms in dark mode and 2.460 → 2.591 ms in light mode, across three
interleaved batches of 100 updates/expansions. Those deltas include all changes
since the pre-extraction tree. The association guards alone changed an
eight-span syntax redraw from 0.739 to 0.752 ms; the complete prompt stayed
within run-to-run noise.

## Limits

No new manual Terminal.app fullscreen/windowed visual acceptance session was
performed. Automated PTYs exercise native ZLE and exact terminal output; the
approved palette values remain covered by the existing reference-color contrast
gates. User-remapped terminal colors, transparency, arbitrary fonts and real
device/build behavior are outside synthetic validation. No commit or push was
performed by this review.
