# Runtime requirement advisories

## Adopted boundary

`support/.zsh.runtimes` owns runtime labels, installed-version capture/cache,
safe requirement reads and numeric comparison. It is an ordinary optional peer,
not an ordered prerequisite. Source time defines functions/data only. Prompt
capture calls it later; typing and resize reuse captured presentation. Pure
comparison and TOML scalar parsing take supplied text; filesystem observations
and external version probes have separate explicit boundaries.

The previous implementation treated every non-prefix match as danger. The new
numeric-pin relation distinguishes older (danger), newer (warning), and matching
(no advisory). Minimums accept newer versions; supported ranges reject values
outside either bound. Unsupported formats are unverified, with warning styling.
Every advisory carries requested and observed versions plus a textual relation.
This is not package resolution or a build-compatibility guarantee.

The complete source inventory, precedence, numeric grammar and omissions are in
README's Project and runtime context section. In particular, selection files
remain preferred over manifest requirements; the implementation does not solve
their conjunction or inspect dependencies. Partial pins preserve their existing
prefix semantics. Runtime providers remain independently trusted installed
software, not an operating-system sandbox.

## Source semantics checked

- [Rustup overrides](https://rust-lang.github.io/rustup/overrides.html):
  plain and TOML toolchain selectors; legacy filename precedence.
- [Cargo rust-version](https://doc.rust-lang.org/cargo/reference/rust-version.html):
  package minimum, separate from toolchain selection.
- [Go toolchains](https://go.dev/doc/toolchain): `go` is a minimum;
  `toolchain` is a separate selection suggestion, not an exact pin enforced here.
- [Swift PackageDescription](https://docs.swift.org/package-manager/PackageDescription/PackageDescription.html):
  tools-version is a minimum, distinct from `.swift-version` selection.
- [Python project metadata](https://packaging.python.org/en/latest/specifications/pyproject-toml/):
  `requires-python` specifies the project's Python requirements. The native
  reader implements only the explicitly documented numeric comparison subset.
- [Scala CLI version](https://scala-cli.virtuslab.org/docs/commands/version/):
  launcher/default-language versions differ, and `version --offline` suppresses
  the automatic update check. The probe now uses that documented offline mode.

The audit also retained LuaJIT implementation identity and Godot prerelease
suffixes instead of treating those numbers as ordinary Lua/final Godot versions.
An ambiguous `scala` launcher is left unprobed as `launcher-managed`; probing
its classic/modern interface merely to choose an offline flag would defeat
that boundary. A fixture sentinel verifies that it is never executed.

## TDD evidence and acceptance

The first three new regressions failed on the original tree: both directional
warnings were red, the shared comparison capability was absent, and Rust TOML /
manifest minima were not recognized. Subsequent red-green steps protected
multiline/duplicate/oversized selectors, Scala's language version and offline
arguments, malformed range whitespace, descriptor-bound reads, LuaJIT identity
and Godot prereleases. Existing runtime security tests were retargeted to source
the extracted owner; their behavioral assertions remain intact. The display
sanitization test now measures the complete new warning text.

`zsh tests/run.zsh 'runtime versions'` covers every dedicated version-file entry,
normal/reverse/rotated affected-peer orders, re-source cache preservation,
missing-peer then late availability, minimum/range parsing, numeric edge cases,
read bounds, unsafe file types and native ZLE painting/entered-text preservation.
The full suite additionally checks all-peer order, both palette schemes,
installation discovery, prompt resizing, redraw isolation and source security.

The first full refactor run had three integration failures: two source
tests had not loaded the extracted owner and README lacked the new inventory
row. After fixing those integrations, the next full run passed 660 tests in
153,868.5 ms. A later native-warning test and the offline-probe regression are
included in the final verification reported with this change; the earlier run
is not presented as validation of changes made afterward.

Pre-review verification: 666 tests passed, zero failed, in 156,506.2 ms, including
11 focused runtime-version cases and the concurrent Git-review tests present
in the working tree. All shipped/test shell files passed syntax checks; the
README inventory, security documentation and diff-whitespace checks passed.
An isolated bootstrap sourced twice without diagnostics. Unrelated concurrent
Git-review implementation/test edits were left untouched.

Native PTY acceptance checks the real ZLE prompt carrying amber/red warning
escapes and both versions, followed by successful unchanged draft input.
Terminal.app visual acceptance remains a separate user check: after `exec zsh`,
compare a newer/older/matching fixture at wide and narrow widths, confirm that
optional content is omitted/abbreviated without rail overlap, and type a draft
without triggering another requirement capture. No private screenshots or
project data were used as fixtures.

## Timing observations

Five isolated Apple Zsh 5.9 shells per tree, all peer files sourced, synthetic
Swift project with `.swift-version`, fixed runtime probe result `6.4`, no Git
repository. Baseline prompt came from the pre-change HEAD and omitted the new
support peer; current tree used the extracted peer. Each shell measured all-peer
source time, one cold `_prompt_update`, then twenty warmed `_prompt_update`
calls. Median milliseconds:

| Workload | Before | After |
| --- | ---: | ---: |
| All-peer sourcing | 58.410 | 59.297 |
| First synthetic prompt capture | 4.016 | 4.268 |
| Warm complete prompt capture | 3.739 | 4.112 |

The first baseline source sample was a 212.530 ms outlier; all other baseline
source samples were 56.984–59.128 ms and current samples 58.073–61.141 ms.
These observations include the complete peer set, not just comparator cost,
and were taken while regression work was running. They are not universal
thresholds or measurements of installed compiler startup. The extra bounded
descriptor validation and advisory work is at capture, not on every keypress.
Native numeric comparison avoids a new per-capture external version utility;
no new project cache, background job or redraw provider was introduced.

A final five-shell repeat after first-line read minimization and launcher
hardening also measured one hundred `_prompt_interaction_update` calls over the
same captured facts and the literal draft `swift build`. Median milliseconds:

| Final repeat | Before | After |
| --- | ---: | ---: |
| All-peer sourcing | 58.939 | 58.734 |
| First synthetic prompt capture | 4.535 | 4.647 |
| Warm complete prompt capture | 3.771 | 3.935 |
| Interaction update from captured facts | 1.008 | 0.999 |

Concurrent Git-review work was present during the final repeat; both columns
used the same other peers and differed only in prompt/runtime implementation.
The small differences are observations under that workload, not evidence of a
universal startup speedup. Source/edit-time costs were essentially unchanged.

## Independent review and corrective TDD

The initial independent review held publication despite 666 passing tests.
It found a costly whitespace pattern on long TOML lines, excessive line-count
work, acceptance of an incomplete first-line prefix, overconfident partial TOML
parsing, missing Go-workspace integration and an inaccurate oversized-file claim.
The follow-up parser review additionally exercised escaped table/key aliases,
empty Cargo minima and duplicate/malformed Go directives.

Each behavioral correction began with a failing regression. The first parser
correction run had 12 passes and three expected failures; the aggregate parsing
budget, escaped names, empty Cargo and malformed Go cases were separate later
red-green steps. Go integration first failed because the workspace root was not
retained; both ordinary and saturated-root paths now capture its minimum.
Oversized-file fallback was characterized before changing documentation: files
rejected by initial eligibility checks remain skipped, distinct from a captured
source whose content cannot be interpreted. The reader remains deliberately
partial, not a general TOML/Go manifest validator or compatibility resolver.

The resulting full-source boundary is 64 KiB, 256 lines and 4 KiB per line,
checked before syntax-pattern work. A descriptor size check rejects excessive
full sources before reading them; growth reads at most one additional byte.
First-line sources require observed newline/EOF within their 4 KiB budget.
The initial 1 MiB file-eligibility ceiling remains a separate fallback rule.

Independent local remeasurements on Apple Zsh 5.9:

| Synthetic workload | Reviewed defect | Corrected |
| --- | ---: | ---: |
| 500 KiB single-comment TOML, direct parser | ~14,570 ms | 5.30 ms, unverified |
| 500 KiB single-comment requirement capture | not recorded | 0.82 ms, unverified |
| 900 KiB / 300,000-line manifest, complete prompt | 1,546–1,575 ms | 3.14–4.07 ms |
| Permitted 64,053-byte / sixteen-long-comment manifest | not recorded | 6.94 ms, parsed |

Five-shell medians over the same synthetic Swift workload: all-peer source
52.683 → 52.961 ms, cold capture 4.394 → 4.459 ms, warm capture 3.793 → 4.106 ms,
and captured Interaction update 0.996 → 1.001 ms. These measurements describe
local observations, not portable test thresholds. Deterministic regressions
assert budget/fallback outcomes instead of elapsed time.

## READY toolchain visibility

The reported disappearing row was an existing presentation rule: consuming
automatic Context returned to READY, which omitted toolchain data. Captured
versions remained present; restarting the shell opened Context again. The user
approved retaining TOOLCHAIN in READY. A failing acceptance-lifecycle regression
preceded the change; a second failure protected ENV/LAST from displacement.
READY now permits six body rows when height allows, and toolchain values share
the ordinary Interaction value column. Context and operation-specific views
retain their existing behavior. No new capture or persistent state was added.

Native PTY verification runs an isolated real interactive shell through `ls`,
`clear`, narrow resize and wide restoration. It confirms the READY warning
returns with space, while the model tests assert no metadata/runtime discovery
on repaint and no empty toolchain row without captured items. Manual acceptance
in the user's actual Terminal.app remains separate from this automated evidence.

Final corrective verification: 678 tests passed, zero failed, in 163,851.5 ms.
The final independent performance pass ran 30 runtime-related tests successfully;
the independent architecture/parser pass ran all 20 runtime-version tests and
repeated its exact malformed-source reproductions. No remaining actionable
blocker was found in those reviewed scopes. All shipped/test shell files passed
syntax checks, an isolated bootstrap sourced twice without diagnostics, and
focused security/documentation and diff-whitespace checks passed. Earlier
native-test development failures were synchronization/ANSI-quoting harness issues
and were corrected before this final run; they are not counted as passing runs.
