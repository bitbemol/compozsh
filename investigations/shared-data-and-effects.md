# Shared production data and effects

Recorded 2026-09-06 on the development macOS host with Apple Zsh 5.9.
These are observations from this environment, not compatibility thresholds.

## Implemented boundaries

- Matching owns source-order and prefix/substring/fuzzy selection. Navigation,
  Help, USB and Xcode supply captured arrays and choose their existing policies.
  Explicit read-only array parameters avoid rebuilding every searchable label
  per keystroke. Outputs are caller-local indexes; exact targets remain separate.
- Shared UI owns file/folder action metadata, action-row collection and
  first-line descriptions. Feature adapters assemble their target groups.
- The effects peer owns exact clipboard writes and validated file Open/Reveal.
  Callers capture capabilities and dispatch after screen cleanup. Missing
  support omits these capabilities; direct copy requests fail safely.
- USB owns one pure result model and one presentation adapter for its three
  media result variants. Exact confirmation reading and temporary image-mount
  cleanup also share implementations within the USB peer.
- Git review shares document-cache invalidation between explicit refresh and
  automatic snapshot adoption.

Provider acquisition, directory/history matching policies, Back navigation,
privileged operations and device validation retain their domain owners. Similar
control flow with different scope, limits or effects is not interchangeable.
This extraction does not claim that every repeated line in the repository has
been removed. No universal controller, execution framework or load phase was added.

## Verification

The original full suite passed 684 tests before refactoring. The final suite
passed 690 tests with no failures (166 seconds), including native PTY journeys,
peer-order convergence, isolated installation, fallbacks and security contracts.
Six new contracts cover shared data and effects. Relevant existing fixtures
load the effects peer explicitly; existing assertions were preserved.

USB result titles, subtitles, exact values, labels, semantic highlights, search
text and detail text matched the original implementation across 4,608 synthetic
result states. No real device, clipboard or GUI application was used.

Syntax checks, whitespace checks and isolated double sourcing passed. All 22
recursive peers have exactly one current README inventory row. Manual
Terminal.app fullscreen/windowed visual acceptance was not performed.

## Performance

Interleaved original/final measurements used an isolated HOME/ZDOTDIR, minimal
PATH, fixed locale and 1,000 synthetic candidates. Candidate values were
`target-N`, labels `candidate-N`, and USB/Xcode metadata `metadata N`. Each
measurement collected up to ten results and constructed the complete picker
frame at 100 columns by 30 rows. Values below are milliseconds per operation,
medians of three runs of 30 warm iterations; they exclude terminal painting.

| Collector/query | Original | Shared |
| --- | ---: | ---: |
| Navigation / empty | 0.671 | 0.716 |
| Navigation / candidate | 0.736 | 0.780 |
| Navigation / 999 | 11.358 | 9.571 |
| Navigation / nomatch | 11.956 | 10.146 |
| USB / empty | 0.641 | 0.690 |
| USB / candidate | 0.688 | 0.801 |
| USB / 999 | 17.374 | 14.670 |
| USB / nomatch | 18.162 | 15.613 |
| Xcode / empty | 0.654 | 0.672 |
| Xcode / candidate | 0.718 | 0.766 |
| Xcode / 999 | 5.501 | 5.502 |
| Xcode / nomatch | 6.321 | 6.106 |

An eager text-array prototype was rejected because even an empty query rebuilt
the full catalog, taking approximately four milliseconds before rendering.
The retained implementation reads only the supplied entries needed for matching.

Separate interleaved shell-launch/bootstrap measurements used ten retained warm
samples per tree after two warmups, with no private initializer. Median startup
was 66.41 ms originally and 65.70 ms after extraction; that difference is too
small to establish a startup improvement.

## Subsequent support component split

The UI and runtime support peers were then split by responsibility, with no
changes to their function bodies after Zsh parsing. The original 2,993-line UI
file became 14 peers under `support/ui/`: actions, views, text, state, layout,
reader, syntax, style, chrome, guide, frame, paint, input and screen. The
939-line runtime file became five peers under `support/runtimes/`: probes,
metadata, parse, compare and requirements. Matching, effects and appearance
remain compact focused peers at the support root.

These directories have no aggregator loader or ordered initialization. Shared
UI state and screen ownership retain separate single owners. Most components
are under 400 lines; the largest is the 793-line shared input state machine.
The README inventory now covers all 39 shipped peers. The earlier 22-peer count
and measurements above describe the extraction before this structural split.

The split passed 691 tests with no failures (169 seconds), including standalone
and repeated component sourcing, lexical/reverse/rotated loading, installations
and native PTY interactions. Exact UI ownership was also checked separately.
Syntax, whitespace and isolated double-bootstrap checks passed. Manual
Terminal.app fullscreen/windowed visual acceptance remains unperformed.

Interleaved startup measurements compared the immediate pre-split tree with the
split tree, using a disposable HOME/ZDOTDIR, no private initializer, a minimal
PATH and fixed locale. Twelve retained warm launches per tree after two warmups
had medians of 60.713 ms before and 61.440 ms after: approximately 0.73 ms added.
This measurement covers the additional source files; runtime function bodies
are unchanged. These timings are separate from the earlier extraction benchmark.

## Classified entry points

The subsequent naming pass supersedes the grouped component paths above.
At that checkpoint, shared operations lived in `support/functions/` as 11 `.zsh.pure.<entry>`
and 14 `.zsh.impure.<entry>` files. There were 13 callable `.zsh.ui.<entry>`
files under `support/ui/`. Each puts its declared entry point first, followed
by exclusive helpers; 27 helpers remained beside their owners. Existing internal
function names are preserved, with the leading underscore omitted in filenames.
Palette setup and data-only UI state remain explicit configuration peers.

Purity requires explicit input data and caller-local return values. External
reads and implicit mutable-state access are classified as impure even when
they do not modify files. For example, reading-disclosure transitions are pure,
while configured metadata-limit checks depend on shared state. Labels are a
review contract, not effect enforcement. The canonical rule is in AGENTS.md.

Every moved function body remains identical after Zsh parsing. The final suite
passed 693 tests with zero failures (169 seconds), including filename/first-entry
agreement, private-helper ownership, peer-order convergence and native PTY
journeys. No private helper is referenced from another production file.
Syntax, whitespace, isolated double sourcing and the 57-peer README inventory
also passed. Manual Terminal.app visual acceptance was not performed.

Twelve retained interleaved warm startup samples per tree after two warmups,
using the same isolated environment as the preceding split, measured medians
of 61.869 ms immediately before naming and 62.199 ms afterward: approximately
0.33 ms added. This is a structural refactor, not a measured algorithm speedup.

The subsequent [production duplication follow-up](production-duplication-audit.md)
records additional shared entries, behavioral fixes and fresh measurements.
The counts and timings above describe the earlier checkpoints.
