# Shared UI consumer cleanup and broader code review

Date: 2026-09-03. Baseline: the frozen working tree after the
[519-test extraction review](ui-extraction-review.md), including the move to
`.zsh.addons/support/`. These measurements cover the follow-up cleanup, not the
entire difference from the last commit.

The subsequent [shared matching review](shared-matching-review.md) records the
reusable search component and the next independent defect review.

Three agents reviewed and simplified Files/navigation, Git/help/worktrees, and
Xcode/USB while the coordinating reviewer checked shared UI, output, integration
and documentation. A second pass covered prompt/highlighting/utilities,
bootstrap/installer, privileged Touch ID routines, the syntax worker and static
website. Independent cross-review checked the new fuzzy matcher and paint-style
reuse. Review depth followed effects and changed boundaries; this is not a
formal proof that every path is defect-free.

## Defects reproduced and fixed

Confirmed behavioral defects have retained regression tests that failed for the
intended defect before the fix and passed afterward. Behavior-preserving
refactors began with green characterization coverage. Performance observations
use separate bounded benchmarks rather than unstable test deadlines.

| Defect | Fix and retained evidence |
| --- | --- |
| **P1: parent cleanup could erase submodule edits** when `submodule.recurse=true` | `git-discard-all` explicitly disables restore recursion. `discard_submodule_test.zsh` uses real disposable parent/child repositories and verifies child tracked/untracked contents and configuration survive while parent edits are removed. Existing verification still returns 1 and reports remaining changes when the preserved child stays dirty; this is documented. |
| Files Git enumeration could execute repository-configured fsmonitor commands | One same-peer read helper disables fsmonitor, optional writes, lazy fetches, prompts and transport. `files_ui_cleanup_test.zsh` includes an executable synthetic monitor spy and asserts it never runs. |
| Inherited Git selectors could redirect explicit-folder capture/review | Files and review helpers isolate seven repository/index/object selectors. Interactive `g` holds that isolation through capture, review and final branch switch. Real repositories, linked worktrees and submodules, native ZLE journeys and restored caller settings are covered by `files_ui_cleanup_test.zsh`, `git_help_ui_cleanup_test.zsh` and `navigation_scope_test.zsh`. Transparent `g` arguments retain native Git environment semantics. |
| Secondary menus/notices inherited unrelated instructions and capabilities | File/folder menus consume shared `choice` defaults; unavailable Git review consumes `notice`. Tests retain exact targets, caller state, abort status, native guide/Back and terminal restoration. |
| USB formatting rejected valid 129–255-character names at final dispatch and collapsed native failure status | Dispatch reuses the format-specific name validator before authorization and retains the native erase status. `action_ui_cleanup_test.zsh` exercises boundary names, invalid requests, exact native operands and failure status using effect stand-ins. |
| Oversized `~number` input printed arithmetic diagnostics over the editor | Decimal text is bounded against the native directory stack before integer conversion. `highlighting_bounds_test.zsh` covers huge and leading-zero indexes plus a native editable-buffer journey. |
| Saturated prompt source samples collapsed 128 filenames into one string | Preserve array elements when slicing the bounded sample. `prompt_source_sample_test.zsh` uses 130 mixed C/Swift files and verifies both observed languages survive full project-context rendering. |
| Website hero overflowed at intermediate desktop widths | Move only the hero's single-column breakpoint to the width required by its columns and margins. The browser suite failed at 1024 px before the fix, then passed all 11 widths including both sides of the new breakpoint. |

The fuzzy matcher had a separate performance defect: repeated characters could
cause combinatorial glob backtracking. Each fuzzy gap now consumes characters
only until the next required literal. Existing fragment intersection and ranking
remain intact. Independent review caught a backslash regression in the proposed
class escaping; its failing punctuation case was added before correction.
Retained tests cover literal punctuation, Unicode, repeated characters and
ranking. Independent baseline comparisons agreed across 5,000 generated cases
and 117,649 exhaustive comparisons.

## Architecture and maintainability

- Appearance remains the only default palette writer. No palette values,
  public overrides, support ownership, peer loading rules or registry changed.
- Feature peers own providers, matching, transitions, bookmarks and effects.
  Shared UI owns scoped defaults, layout, input, painting and restoration.
  Complex document controllers retain explicit composition where it is useful.
- Xcode and USB rely on shared default acceptance instead of populating an
  identical per-row map. USB skips metadata setup when no metadata is requested.
- Semantic label styles are derived once per selection state, complete surface
  and role within one paint. The local map expires on return. The next paint
  reads live palette overrides; six independently compared complete paints
  retained identical frame text and highlight spans across focus/palette changes.
- No source-time cross-peer calls, ordered phase, persistent registry, new
  background process or project cache was introduced. Order independence does
  not mean the UI has no temporary interaction state or terminal effects.

## Measured performance

Native Zsh 5.9 on arm64 macOS 27.0, with disposable homes, public configuration
and synthetic fixtures. Values are median milliseconds across alternating
before/after batches. They are observations from this host, not compatibility
thresholds. Warm frames use the full render/show path with physical `zle -R`
painting stubbed. They exclude real input, initial wrapping, resize rewrapping
and provider acquisition unless explicitly stated.

| Workload | Before → final | Sampling |
| --- | ---: | --- |
| Repeated-character fuzzy miss, complete warm frame | 193.603 → 0.548 | 5 × 3 |
| Normal fuzzy frame, 1,000 captured paths | 13.501 → 13.841 | 5 × 30 |
| File actions, setup and first frame | 1.262 → 1.348 | 5 × 30 |
| Folder actions, setup and first frame | 1.284 → 1.346 | 5 × 30 |
| USB 500-choice setup and frame, no details | 3.203 → 1.569 | 3 × 50 |
| USB 500-choice setup and frame, with details | 5.621 → 4.803 | 3 × 50 |
| Xcode 20-choice setup and frame, with details | 2.667 → 2.599 | 3 × 50 |
| Dark metadata frame, active / inactive selection | 4.519 → 3.715 / 4.509 → 3.720 | 5 × 100 |
| Light metadata frame, active / inactive selection | 4.510 → 3.750 / 4.502 → 3.739 | 5 × 100 |
| 198-span diff frame, dark / light | 7.183 → 7.162 / 7.202 → 7.197 | 5 × 100 |
| Git prepare, change capture and selected unstaged diff | 38.779 → 38.590 | 5 × 20 |
| Eight-token command-line highlighting | 0.8030 → 0.8106 | 5 × 1,000 |
| Full prompt, saturated 130-file C/Swift source fixture | 1.561 → 2.079 | 5 × 50 |
| Warm bootstrap, dark / light | 54.248 → 54.227 / 54.415 → 54.232 | 3 × 8 |

Metadata paints improve approximately 17–18%; the large USB choice fixture
avoids redundant map work. Ordinary fuzzy matching adds 0.34 ms in the measured
1,000-path fixture while removing the severe repeated-character stall. The
prompt correction costs 0.52 ms because the old implementation omitted an
observed language. Menu scoping adds 0.06–0.09 ms. No uniform speedup is claimed.

## Validation and limits

The combined native suite passed **536 tests, 0 failures** in 133.0 seconds:
the previous 519 plus 17 new cases. All 95 native Zsh files passed syntax
checks; whitespace and isolated bootstrap double-source checks passed without
diagnostics. Full-suite coverage includes security/documentation contracts,
side-effect-free help, the shipped-peer inventory, symlink/copy installation,
four peer orders, both schemes, custom palettes, re-sourcing and native feature
journeys. These results precede the subsequently requested shared matcher pass.

The browser suite passed task navigation, exact synthetic targets, keyboard,
literal input, simulated clipboard success/failure, disclosure, stable layout,
reduced motion, no-JavaScript behavior and 11 viewport widths from 320 to 1440
pixels. All requests were intercepted from local files. Native PTY tests cover
the changed terminal interactions and caller restoration. Node's eight pure
browser algorithm tests also passed.

Reproductions use isolated homes, disposable repositories and synthetic data.
USB/build/privileged effects use test stand-ins; no real disk was erased, GUI
application launched, private history/configuration read or clipboard changed.
No new manual Terminal.app fullscreen/windowed visual acceptance was performed.
Real device/build outcomes and user-remapped terminal colors remain outside this
synthetic validation. Nothing was committed, pushed or deployed.
