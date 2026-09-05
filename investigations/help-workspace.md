# Help as a task workspace

2026-09-04. Implemented direct owned `--help` and tool-catalog reading through
the same captured topic workspace. This intentionally replaces the prior
always-print direct-help policy for supported interactive terminals.

**Scope of this record:** the text and verification below describe the original
reading-only implementation. The later [composer and atlas work](composer-and-atlas.md)
adds a separate authored Compose example action for `g` and `mkcd`, with explicit
post-cleanup draft insertion. Ordinary topic acceptance still only reads.
Current help also accents literal arguments in both panes using the shared
palette. Follow [AGENTS.md](../AGENTS.md#adopted-interaction-design) for the adopted
contract; the original measurements and test counts below are historical.

## Design and boundaries

The header retains the tool description. Overview keeps complete captured
description and usage; the navigator contains documented arguments, options,
modes, sections and examples. Selection reveals an explanation; Enter opens a
full-width reader and Back preserves the topic filter, viewport and focus.
Returning from catalog-launched help preserves the catalog bookmark too.

Reference presentation is a small shared UI profile, not a separate renderer or
key loop. From 90 columns the navigator uses one third of the body width,
capped at 42 cells; the explanation uses the remainder. Narrow windows retain
explicit focus switching. Explanation prose is neutral, including a topic
whose first line is an indented argument description. No Git-specific document
refresh/disclosure keys are inherited. All topic acceptance means reading,
never running, inserting or copying an example.

The same-source companion remains the only documentation definition and always
prints. Direct help captures it once, before ZLE, through a native pipe capped
at 32,768 characters plus lookahead. The catalog reuses its existing capture.
The pure topic derivation recognizes the documented heading/indent/separator
grammar; repeated labels share an entry without losing their text. It derives
at most 128 topics plus Complete guide, which retains all captured prose,
including unclassified content. Partial capture and preview limits are visible.
Filtering uses case-insensitive literal substrings in labels and explanations.
Complete guide matches by label so it does not match every query.

Pipes, redirects, missing peers, unavailable alternate screens, dumb terminals
and NO_COLOR retain complete printable help. The standalone installer and
transparent external commands keep their own help. No operational dependency
check, project read, configuration read, executable help probe, network request,
clipboard access, privilege or file write is added. Trusted private companions
must still be static and return promptly; capture bounds are not a sandbox or
wall-clock deadline. User terminal retention remains independently controlled.

## Verification

Five new native-suite cases cover literal topic derivation and duplicate labels,
argument indexing, primary-reader geometry, neutral prose and view isolation,
every owned public help mode, and a real ZLE journey. The journey opens direct
Git help, filters, reads and returns, focuses, resizes 120 → 40 columns, handles
no matches and cancels. It then opens every other public guide and both device
and Xcode submode guides. A separate event channel verifies one Git capture,
paint, caller bookmark restoration and terminal cleanup. NO_COLOR, dumb and
non-terminal-input fallbacks remain noninteractive. Existing plain/provider
identity, semantic output colors and help safety assertions remain in place.
The native Draft → Tools → Help → Back journey retains the exact multiline
draft/cursor with the new topic view. No real operation or private config ran.

Synthetic native renderer captures were inspected in wide dark and narrow light
layouts. Browser inspection caught over-emphasized first-line explanation prose;
a failing role assertion preceded its correction. The optional website now has
a fixed help-topic example. Browser QA reproduced and fixed label-only matching;
explanation text now uses the same literal substring rule. Keyboard acceptance,
no-match behavior and a 390px iframe were checked alongside the script-disabled
static fallback. These are browser renders and native PTY tests, not a claim of
manual acceptance in the user's Terminal.app profile. Nothing was published.

The final unfiltered suite passed **626/626** in 159.4 seconds; an earlier full
run also passed 626/626. All 27 help-focused cases and all 13 browser algorithm/
data cases passed. Native syntax, isolated double sourcing, peer-order and
UI/palette convergence, security and README inventory checks, and whitespace
validation passed. The optional standalone Playwright script was updated with
the explanation-search regression but was not run; browser QA used the in-app
browser. Temporary localhost preview servers were stopped. No installation,
commit or publication was performed.

## Latency observation

Zsh 5.9, isolated HOME/ZDOTDIR, 120 × 30 native zpty with continuously drained
output. Thirty render-and-paint iterations per sample, alternating among four
topics with the same captured 20-line explanation. Initial capture and setup
are excluded; the comparison is the old compact choice presentation versus
the new reference presentation, not equivalent displayed information density.

| Presentation | Milliseconds per render-and-paint, three samples |
| --- | --- |
| Compact choice preview | 4.10 / 4.16 / 4.05 |
| Primary reference explanation | 7.10 / 6.98 / 7.03 |

The larger reading surface costs about 3 ms per changing-topic frame in this
fixture. It uses no provider read, new cache or scheduling mechanism. These
observations exclude physical display/compositor latency and are not universal
thresholds. Keep the existing compact profile for ordinary picker previews.

## Argument accent refinement

Argument and mode topics now attach the existing `picker-header` semantic span
to their unchanged navigator label. Section titles remain neutral. The shared
painter retains active/inactive selection contrast and resolves current palette
overrides; no new colors, provider reads, retained state or security boundary
are introduced. This remains within the appearance/help guarantees in
`SECURITY.md`.

The regression failed first on the missing argument accent. It now covers
options, positional arguments, modes, neutral sections, filtering, narrow
rendering, palette overrides and view cleanup. The native help journey also
checks the actual terminal escape stream for the palette-colored `--worktree`.

Repeating the native workload above with the reference profile on both sides,
four topics and three argument-label spans gave 6.70 / 6.71 / 6.84 ms without
spans and 7.10 / 6.91 / 7.19 ms with spans per render-and-paint. This warm,
synthetic measurement excludes initial capture and physical display latency;
the observed overhead was roughly 0.2–0.4 ms per changing-topic frame.

## Explanation accent correction

The argument accent now reaches the explanation pane and explicit full-width
help reader. Sanitized documentation yields bounded semantic spans for aligned
argument/mode/example prefixes, option spellings and angle-bracket placeholders.
Both surfaces reuse the existing syntax slicing and palette overlay machinery;
ordinary draft/log readers do not enable help presentation. A consumed wrap
separator now advances the source offset too, keeping later accents aligned.

The missing right-pane span failed first. Regression coverage includes neutral
prose, Unicode, narrow wrapping, reader filtering/isolation, the 128-span bound,
and regex scratch-state preservation. The native journey selects --discard-all
and checks real ZLE color ranges in both the right pane and full-width reader,
then returns, focuses, resizes and cancels without a second help capture.

With identical reference geometry and left-label accents, 30 changing-topic
render-and-paint iterations per sample over 20 argument-bearing explanation
lines measured 7.70 / 7.78 / 7.77 ms with explanation spans disabled and
10.06 / 10.31 / 10.49 ms enabled. A variant without the cheap literal-marker
guard measured 10.13 / 10.15 / 10.20 ms; these ranges overlap. The guard skips
regex matching when there is no option/placeholder marker in remaining prose.
These warm synthetic measurements exclude capture and physical display latency;
they deliberately exercise substantially more accented lines than the single
argument topic in the reported screenshot. Existing prepared wrapping is reused
when scrolling without changing topic or width.
