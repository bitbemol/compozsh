# Local manual summaries for the Interaction lens

## Decision and boundary

This records the original manual-summary implementation. The later
[current prompt description contract](../README.md#living-prompt) adds
same-source help-derived intent and unchanged stock-alias descriptions.
Its sourced ACTION descriptions supersede the blanket qualified-ACTION rule
below; inferred actions remain qualified. The original manual capture boundary
and evidence below describe that initial version. The selected-developer capture
follow-up at the end records the later root and parser changes.

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

## Follow-up: selected developer manuals and NAME separators

This intermediate implementation and its measurements are retained as history;
the expanded capture below supersedes its root, format and byte restrictions.

On September 7, 2026, `man -w swift` on the development Mac identified
`/Applications/Xcode-beta.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/share/man/man1/swift.1`.
The original capture omitted both the selected alternative Xcode location and
the default toolchain's manual directory. Independently, Swift's Pod::Man NAME
line used `\-\-` as its separator, while the parser accepted only `\-`.
The installed page was 7,087 bytes, within the existing 8 KiB read bound.

Capture now makes one fixed `/usr/bin/xcode-select --print-path` query on macOS,
validates its absolute, control-free existing directory result, and includes
that directory's default toolchain and developer manual roots. This honors
Apple's `DEVELOPER_DIR` selection rather than scanning application directories.
The system root remains first; the selected developer roots precede conventional
fallbacks, which now also include the default toolchain inside `Xcode.app`.
Exact duplicate roots are removed. Missing selection retains those fallbacks.
The selector runs only for a fresh snapshot, including after explicit refresh.

NAME parsing now recognizes the first literal or escaped single/double dash
separator. Later dashes remain part of the description. This remains inert
bounded parsing, with no formatter, roff evaluation, include following or
documented-command execution. The page, byte, retained-name and summary bounds
are unchanged. Compressed pages, page symlinks and unsupported formatting still
produce quiet misses; this is not an exhaustive replacement for native `man`.

Regression tests first failed for Swift's separator and omitted selected roots.
The resulting coverage includes first-separator behavior, unsupported includes,
paths with spaces, selection capture once per snapshot, missing-selection
fallback, root deduplication, and native ZLE display of a Swift fixture at 120
and 40 columns with further capture and selection queries forbidden. The real
installed page was also captured locally and supplied the expected ABOUT text
and `Local manual · swift(1)` attribution to the Interaction model.

Three fresh captures over warm filesystem data in isolated shells measured
534.6 / 451.6 / 447.8 ms before, retaining 1,371 names without Swift, and
582.8 / 520.3 / 519.2 ms afterward, retaining 1,639 names including Swift.
These are host observations, not general latency guarantees. Source time still
performs no capture, and warmed lookup and paint remain memory-only.

The final native suite passed all 793 tests, including the pending alias-preview
changes, in 189,103.7 ms. Syntax checks, isolated double sourcing and whitespace
checks passed. Native developer selection was verified with `DEVELOPER_DIR`
set to both the installed Xcode app bundle and its `Contents/Developer` directory.

## Follow-up: custom installations and broader literal alias previews

The user requested broader coverage before committing the initial fixes.
Capture now respects literal MANPATH replacement/empty-field ordering, absolute
PATH installation conventions, inert MANPATH/MANCONFIG path directives, and
Apple's selected SDK/platform/developer/toolchain roots from `--show-manpaths`.
Sections precede roots and the MANSECT environment can select their order.
Installed symlinks, Unicode filenames, native gzip-decodable compression and
bounded whole-page `.so` forwarding are supported. Regular descriptor checks
remain mandatory; forwarding can leave the initial root to reach installed
manuals. The current README and SECURITY document all bounds and trust limits.

The fast NAME parser handles header comments, CRLF and simple cross references.
Native mandoc handles formatting-heavy NAME sections from captured stdin in a
private empty directory. Native roff documentation identifies command/file-write
requests as ignored and restricts `.so` to non-parent relative paths; the empty
working directory prevents caller-file inclusion. The child has bounded output
and CPU time. Page text stays in memory/pipes. Readable pages without usable
NAME descriptions retain an explicit availability notice. This is bounded local
metadata capture, not a full manual reader or executable-identity resolver.

The initial broadened implementation took about 7.1 seconds on this host.
Fast-parser improvements, native overstrike removal in Zsh and one shared empty
formatter directory reduced a fresh capture over warm filesystem data to
3,410.2 ms, retaining 2,308 names including the installed Swift description.
A separate instrumentation run recorded 200 native formatter fallbacks.
These observations are machine-specific; the broader first-prompt cost is real.
Source setup still performs no capture and edit-time lookup remains memory-only.

Alias observations now cover unquoted command positions in pipelines/chains,
leading assignments, global argument/redirection aliases and trailing-space
aliases. At most eight definitions are observed within the existing bounded
draft, with 240 characters per definition. Native suppression and quoted/escaped
tokens retain their semantics. Definitions are literal previews: they are never
evaluated or recursively substituted, and nested substitutions/here-document
bodies are not inspected. Structural and warning presentations retain priority.

Red/green regressions cover each added discovery/format capability, absent NAME
summaries, inert formatter/configuration inputs, forwarding loops, special-file
rejection, and compound/global/suffix alias observations and suppression. Native
ZLE tests also paint combined alias previews, preserve the exact draft/cursor,
and render Swift metadata at 120 and 40 columns with capture forbidden while
editing. No physical device or private project is needed for these checks.
Final review added a failing regression for a `.so` target whose installed page
exists only as `.gz`; forwarding now checks the same fixed compression suffixes
before declaring the target unavailable. A 1,200-model loop alternating a
synthetic alias pipeline, global alias argument and `git status` averaged
0.326 ms per model on this host; it excludes layout and Terminal.app painting.
Review also established red/green coverage for disabled ALIASES with a custom
`env` definition. The caller's option now survives local emulation through
prompt layout, redraw, disclosure and resize. The real ZLE regression disables
alias expansion while a definition is visible and confirms that EXPANSION is
removed without submitting the draft.

Final verification passed all 801 native tests with zero failures in
190,634.7 ms, all 26 Node website tests, native syntax checks, isolated double
sourcing and whitespace checks. Native PTY coverage includes the expanded alias
and manual journeys and both Xcode log owners. Physical-device behavior remains
covered by synthetic command spies rather than a paired-hardware launch.

## Subsequent capture optimization

The [critical-path performance pass](critical-path-performance.md) preserves
this capture scope and first-TTY lifecycle while normalizing only the formatted
lines needed for NAME. Paired captures retained all 2,308 names, summaries and
source attributions exactly and reduced median capture time from 3,415 to
2,624 ms on the measured host. The linked report separates provider timings
from first editable prompt measurements and records the regression coverage.
