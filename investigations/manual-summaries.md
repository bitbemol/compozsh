# Local manual summaries for the Interaction lens

## Decision and boundary

The adopted behavior preserves Compozsh-owned cues and supplements ordinary
commands with the short NAME description from installed local manuals. ABOUT
describes a literal command name; ACTION remains a qualified lexical advisory.
For a generic RUN, ABOUT and SOURCE replace the filler ACTION. Specific cues
remain primary, and caution/compound-command frames receive no manual detail.
Unknown summaries retain the existing fallback. No draft is executed, expanded,
validated or resolved to an executable.

The optional `.zsh.manual` peer captures a bounded shell-memory snapshot at the
first interactive TTY precmd and after `compozsh --refresh` invalidation. It
performs no source-time discovery. Editing and resize read only that snapshot
and loaded shell metadata. Owned same-source help is never called to enrich a
redraw. Arbitrary aliases/functions suppress external summaries; only the
source-identified transparent git/grep/man output wrappers are exceptions.

Capture uses five fixed conventional installation roots, shallow section 1/8
regular-file enumeration, at most 4,096 pages and one 8 KiB native descriptor
read per page. It retains at most 8,192 name/description entries (including
bounded NAME aliases) with 240-character descriptions and page/section labels.
The README and SECURITY document roots, precedence and limits. Compressed pages,
symlinks, includes, incomplete NAME sections and unsupported formatting are
quiet misses. The cache is not a complete manual index or executable catalog.

## Alternatives and measurements

Measurements on the development Mac, Apple Zsh 5.9, September 4, 2026. These are
observations, not universal latency guarantees. No OS caches were flushed;
capture measurements are fresh Compozsh snapshots over warm filesystem data.
The regression suite was running during the later measurements.

- `whatis ls man git` was not a reliable read-only provider here: the installed
  script attempted index generation and reported missing indexes/permission
  errors. Running man itself also introduces formatter/configuration/pager
  behavior. Neither is used by this feature.
- The first native parser prototype took 12,051 / 11,928 / 11,961 ms for 1,371
  summaries. Native bulk `sysread` alone did not fix the slow prefix/suffix glob
  extraction, nor did byte-mode parsing alone (about 11,920–11,935 ms).
- Native regex section offsets followed by bounded slices reduced capture to
  417.552 / 404.129 / 408.099 ms. A final run with guaranteed descriptor cleanup
  measured 419.037 / 410.249 / 404.074 ms for the same 1,371 names.
- Fresh isolated peer sourcing, interleaved without/with the manual peer:
  54.740 / 53.238 / 53.389 ms versus 54.231 / 53.827 / 54.106 ms. This measures
  source setup, not the first interactive prompt or machine-local initializer.
- Full warm Interaction update plus native prompt expansion, alternating
  `ls -la`, `man ls`, `git status`, and `unknown-command` over 400 frames per
  sample, with all peers loaded and BUFFER changed for each frame:

| Width | Optional lookup disabled (ms/frame) | Snapshot enabled (ms/frame) |
| --- | --- | --- |
| 120 | 0.707 / 0.727 / 0.703 | 0.794 / 0.788 / 0.790 |
| 40 | 0.676 / 0.671 / 0.671 | 0.782 / 0.790 / 0.775 |

These frame measurements include derivation, layout and prompt expansion, not
Terminal.app painting. The native PTY test separately exercises actual ZLE
reset-prompt/repaint, draft preservation and resize. The first prompt pays
roughly 0.4 seconds **in addition** to its normal fact capture on this machine;
that is an explicit tradeoff, not a claim of free startup. No timer, worker,
persistent cache or per-keystroke provider is introduced.

## Verification

`zsh tests/run.zsh 'manual summaries'` covers inert mdoc/man NAME parsing,
unsupported macro/include rejection, length/read/control bounds, local regular
capture, aliases, refresh, re-source preservation, own-help priority, overrides,
literal prompt metacharacters, and a real ZLE edit/120→40-column resize/accept
journey with provider capture forbidden while editing. Tests use disposable
manual fixtures, never personal configuration or history.

The showcase's existing RUN scene now uses fixed `ls -la` / ABOUT / SOURCE sample
data. Node tests distinguish that captured explanation from advisory ACTION;
the website still reads no visitor manual or shell state. Manual Terminal.app
visual acceptance remains a user check; automated PTY evidence is distinct.

The initial full native run passed 642 tests. The final full run, including the
added lifecycle/metacharacter case, passed 643 tests with zero failures in
159,467.9 ms. All 14 Node website tests passed.
The changed manual-summary scene passed real Chromium checks at 1440, 390 and
320 pixels, including readable ABOUT/SOURCE and horizontal containment; the
390-pixel screenshot was inspected. The broader website browser suite stopped
at its Git numbered-sample visibility assertion at 390 pixels, outside the
changed scene. No claim is made that the entire browser suite is green.
The later [compact-choice consistency pass](tooling-overhaul.md#follow-up-one-compact-choice-style)
resolved that mobile spacing issue and clipped example labels; its final full
browser suite passed, with the earlier failures retained as historical evidence.

## Follow-up: semantic capsule outline

The header role now also colors only the vertical rail and bottom corner.
Label/value spans and the input arrow retain their own roles. The role mapping
is shared by header and footer; row renderers accept the outline role while
Context rows retain their existing frame color. No provider or geometry changes
were needed. Regression tests cover each semantic role, custom palette values,
toolchain rows and missing-palette fallback; both native editing/resize journeys
pass. Browser checks confirm header/rail/footer color agreement and independent
label colors for READY, RUN, ENVIRONMENT and CAUTION at 1440 and 390 pixels.
The complete native suite passed 644 tests with zero failures; all 14 Node
website tests and the static website boundary check also passed.

Repeating the same warm 400-frame workload above during the full suite, with
manual summaries enabled, measured 0.950 / 0.986 / 0.975 ms/frame at 120 columns
and 0.980 / 1.005 / 0.984 ms/frame at 40 columns. Earlier values were about
0.79 ms/frame; the extra separately reset color spans add small rendering work,
with concurrent-suite timing noise also present. No per-edit capture was added.
