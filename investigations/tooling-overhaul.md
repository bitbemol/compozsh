# Docked, focus-responsive tooling

2026-09-04. This extends [focus-responsive views](focus-responsive-ui.md) with
shared screen composition, rather than adding another renderer or input loop.

## Implemented boundary

- Quiet task identity above captured scope and a passive disclosure strip.
- A bottom input surface with the actual ZLE cursor at the query end, followed
  by an emphasized, capability-derived acceptance action and bounded hints.
- Numbered choices now use compact rows with no decorative gaps. This
  supersedes the original height-dependent blank-row spacing: only real,
  nonblank descriptions may occupy a subordinate row when twice the configured
  visible-slot budget fits. Filtering cannot toggle description eligibility;
  documents, passive information and stacked output keep their semantic rows.
No selectable slot is lost. See the current rule in AGENTS.md.
- Neutral selected surfaces, quieter inactive selection and separate semantic
  title/input/action roles in both palettes. Existing overrides remain owned
  by the user's initializer. Full key help remains available through Ctrl-K.
- Short and inline layouts retain top input. Busy status views retain their
  noninteractive presentation, without a fake typing cursor or acceptance.

History, Browse/Search/Recents, branches/worktrees, tool help, Git documents,
Xcode actions/readers, and USB menus/confirmations use these shared components.
Their captures, keys, exact targets, confirmation rules and post-cleanup actions
are unchanged. Ordinary external command output remains ordinary terminal text.

The frame is temporarily split across PREDISPLAY and POSTDISPLAY at the query
end for one paint. BUFFER stays empty inside the owned screen; caller draft,
cursor, undo and history state remain under existing screen-session cleanup.
No daemon, extra provider read, background animation or persistent state was
introduced. This is an immediate input/focus-responsive UI, not a claim that
every shell operation now has a GUI or that arbitrary commands are understood.

## Native measurements

Zsh 5.9, 120 × 30, ten synthetic choices, 80-line captured inspector. Thirty
native ZLE render-and-paint iterations per sample, isolated HOME/ZDOTDIR and a
continuously drained zsh/zpty. Capture and startup are outside the measurement.
These observations exclude physical display latency and Terminal.app's
compositor and are not promises for other machines or terminal profiles.

| Workload | Before this pass, ms/frame | After, ms/frame |
| --- | --- | --- |
| Repeated frame | 3.427 / 3.358 / 3.321 | 3.787 / 3.677 / 3.629 |
| Alternating list/reader focus | 14.219 / 14.854 / 14.600 | 14.926 / 15.515 / 15.277 |

The small repeated-frame cost buys actual caret placement and spaced rows.
Keep native recalculation rather than adding another cache or render scheduler.

## Verification and limits

The new overhaul tests began with four failing contracts. Coverage checks frame
order, actual caret position at paint, literal text, restoration, density,
indexed versus passive rows, absent acceptance, hint bounds and palette roles.
Browser inspection of actual native renderer captures exposed a misplaced
action highlight in a short Git navigator; a fifth regression reproduced it
before the fix. Reader filler rows now exclude the former navigator footer's
metadata. Existing native PTY journeys cover focus, filtering, source anchors,
resize, cancellation, multiline draft restoration, readers and screen cleanup.

Synthetic renderer captures were inspected at 120, 80 and 40 columns across
light/dark choices, focused help, Git review, typed confirmation and progress.
The browser preview is a rendering of native frame text and highlight ranges,
not a Terminal.app screenshot. Computer Use explicitly denied Terminal.app
control; no alternate GUI automation was used. Visual acceptance in the user's
actual Terminal.app profile remains a manual check.

The optional static showcase mirrors the bottom dock and neutral selection.
Filtering, empty-action suppression, file-action entry and returning to the
same query were checked in the in-app browser. Its dock was also inspected in
390px iframe viewports, including a sandbox without script execution. This is
a script-disabled visual check, not the optional standalone Playwright suite.
No publishing occurred.

Focused verification: 21 appearance tests, 19 help tests, 35 workspace tests,
four original overhaul contracts and the reader-footer regression pass. The
ten static-demo algorithm tests pass; syntax, isolated double sourcing,
security/documentation checks and `git diff --check` pass.

Full-suite observations: the first completed rerun passed 599/599. After adding
the reader-footer regression, the final run passed 597/600. Three intermittent
tests failed: Git worker deadline, Git worker-owned cancellation, and Xcode's
native run journey. Each passed immediately when rerun in isolation. The Xcode
failure timed out after READY but before PIPE (which the fixture emits before
entering the screen), rather than during a new dock paint. The Git worker and
these three fixture implementations are unchanged by this pass. Do not present
the final full suite as entirely green or silently relax their timing limits.

To check the installed experience: start a fresh shell, run `compozsh`, type a
filter, enter Help with Ctrl-E, scroll, return with Ctrl-B and cancel. Repeat
with Ctrl-R and a concrete path + Tab; request Preview explicitly. Resize to
a short/narrow window and verify the draft returns unchanged. Do not perform
destructive USB operations merely to inspect this design.

## Follow-up: task actions and explicit draft inspection

The subsequent pass adds an Option-Return Draft inspector with a bounded literal
reader and explicit routes to Tools, read-only Git review, Files and History.
Read/Back preserves the original draft and cursor. Files/History own a separate
post-cleanup interaction and replace the draft only on explicit acceptance.
Tool selection now opens the existing captured help in a full-width reader;
Back preserves its catalog query, exact selection, viewport and focus without
recapturing help. History can disclose the exact captured command before
inserting it for editing.

File actions, Git options/comparison setup, worktree operations, Xcode options
and USB review share descriptive action rows and captured target/plan text.
At 90 columns and above, action choices reserve 45% of available columns,
capped at 52, leaving the plan visible. Smaller views retain shared disclosure
and cleanup. Xcode configuration returns preserve the action bookmark. These
are presentation and transition changes, not new provider or execution powers.

Discard now lives only at `g --discard-all`, with optional native default-no
confirmation and the existing post-confirmation checks. Native PTY tests verify
empty Return cancels and literal acceptance performs the operation only after
screen restoration in a disposable repository. No real project was discarded
and no external disk, Xcode build, Simulator app or skill export was operated.

The focused task-experience suite passes all 12 cases, including native
read/filter/resize/Back/draft restoration and default-no discard. Both canonical
Git entry tests pass. All 21 help tests, the security and documentation checks,
eight static-scene tests, syntax checks, isolated double source and diff
whitespace validation pass. The final full run reports **613 passed, 1 failed**:
the existing Git automatic-worker deadline test. Its isolated rerun passed in
563 ms. No deadline assertion or worker implementation was relaxed. This is
not a fully green full-suite result.

The website adds fixed Draft, Xcode, USB and worktree examples. Browser QA
confirmed Xcode descriptions, selected-row spacing and explicit simulated plan
output; every example remains synthetic and user-controlled. Earlier native
frame and narrow/no-script checks above are distinct from these new examples;
they do not establish exhaustive visual coverage of the follow-up. Real
Terminal.app visual acceptance remains manual. Nothing was published.

The remaining public entry points were audited and then consolidated as
recorded in [Task-oriented command audit](tool-entry-points.md).

## Completion: consistent task families

`external-device` now starts a two-task action workspace; explicit `--flash`
and `--format` modes retain direct entry. All nested media, drive, format,
confirmation and progress views carry the same task-family identity.
`xcode --export-skills` now reviews captured destinations and replacement rules
before interactive export. `compozsh --refresh` owns the current-shell cache
refresh. Retired functions, aliases and help companions are removed on re-source,
not kept as alternate workflows. All canonical modes have inert help, and the
Interaction lens distinguishes selection, export, refresh and destructive modes.

The new native journey verifies caller bookmark preservation, filter/focus,
120-to-40-column resize, cancel and post-screen dispatch for device and export
choices. Export cancellation is verified before staging or writes. No real
external device or installed agent skills were changed. Shared unit, public-help,
source-order and double-source checks cover these entries and absent peers.

The repeated Git deadline failure was traced to the fixture publishing its PID
only after executing a newly created fake executable; the worker could stop it
before that observation ran. The fixture now records the owned coprocess PID
before exec. The same half-second deadline, elapsed bound and worker/provider
termination checks remain. Four consecutive focused deadline runs passed. No
production Git-worker behavior changed.

The Xcode native fixture also intermittently timed out outside its screen,
before PIPE or after LLDB handoff. Its generated executable spies now complete
an inert setup invocation before the timed journey. Every three-second event
bound and cleanup assertion remains; this does not establish an OS-level cause.

The static showcase adds fixed device-task and export-review examples. Browser
checks covered device refinement, empty-result action suppression and explicit
export-plan disclosure. Actual native frame captures were inspected with the
shared dock and captured plan at wide and narrow sizes, including the light
export reader at 40 columns. These remain synthetic browser renders, not actual
Terminal.app screenshots; that profile's visual acceptance remains manual.

Final verification: the unfiltered native suite passed **621/621** in 191.7 s,
including the Git deadline/cancellation and Xcode native journey. The seven
task-family cases also passed separately after adding a regression for the
export action's `update` search term. All twelve static-browser algorithm/data
tests passed. Native syntax, isolated double sourcing, four-order UI/palette
convergence, peer traversal convergence, security and README inventory checks,
and `git diff --check` passed. Option-Return, Option-I and Ctrl-R resolve to their
intended widgets under both xterm-256color and screen-256color. These timings are
local observations, not performance guarantees. No configuration was installed,
no private initializer was read, and no website was published.

## Follow-up: one compact choice style

The user-approved choice standard supersedes decorative blank-row spacing.
Every shared numbered list uses consecutive rows. A real description can add
one subordinate row within the existing viewport budget; absent or
whitespace-only descriptions reserve no space. Description rows stay passive,
retain their parent selection surface, and never consume an index or keyboard
navigation stop. Short windows retain the same candidate capacity. Document
paragraphs and meaningful passive content keep their reading structure.

The change is in the shared UI renderer, not per-tool overrides. The audit
covered ordinary selectors, reference/help views, action plans, description
metadata, split-pane row arrays and the printable directory-stack fallback
(already compact). The showcase also removed inter-option margins and empty
space above descriptions. Five oversized example labels were shortened without
changing their scenes or commands. AGENTS.md, the README, affected command help
and website guidance now establish the same compact convention alongside the
semantic capsule-outline and independent text-color rules.

The updated density test first failed on the old blank-row behavior and then
passed. A whitespace-only description fixture separately failed before its
empty-row fix. The full native suite passed **644/644** in 161,849.1 ms; native
multiline-draft/resize restoration, all 14 Node tests, security, documentation,
inventory, syntax and static website checks passed. Focused real-browser checks
covered History, Files, Git and Tools at 1440, 390 and 320 pixels. The earlier
mobile Git sample overflow disappeared with compact spacing; subsequent full
browser passes exposed the oversized example labels, which were corrected.
The final complete browser run passed all checks, including 11 responsive
widths, keyboard/digit selection, copy success/failure, disclosure, reduced
motion, no-JavaScript behavior and local-only requests. Earlier failed passes
were not silently reclassified as successful.

On the development Mac, three 200-frame samples of complete shared render/show
composition at 120×30 with 20 candidates, 10 visible slots, two descriptions and
moving selection measured 1.765 / 1.764 / 1.758 ms/frame before, versus
1.710 / 1.696 / 1.684 ms/frame after. ZLE painting was stubbed for this timing;
the native PTY test separately exercised actual editing and resize. These are
warm local observations during the suite, not a universal speed guarantee.
Provider capture, action dispatch, privacy and security boundaries are unchanged.

## Follow-up: consistent labels, empty states and available actions

The next shared-screen audit found three remaining presentation mismatches:

- USB media, review and result screens and Xcode test results supplied their
  own button brackets inside the renderer's numbered rows. These authored
  labels now use plain action text. The renderer does not strip brackets;
  literal filenames and captured user text retain theirs.
- Ordinary empty matches used the error color. Both stock palettes now give
  `picker-empty` the same neutral default as `picker-muted`, while actual
  errors and user-provided color overrides remain independent. The existing
  showcase empty-results style was already neutral.
- Tool explorer advertised `read help` even for a missing or capture-limited
  guide. Its existing per-candidate acceptance labels now use `read help`
  only when a canonical usage guide was actually captured, and `inspect`
  otherwise. This metadata is prepared at view entry; it performs no provider
  work during filtering, selection or painting.

AGENTS.md records these shared rules alongside compact choices and their
optional one-line subtitles. Public help and README explain the actual action
labels. No commands, disk operations, confirmations, clipboard behavior or
capture bounds changed; SECURITY.md was reviewed against the final changes.

All three focused regressions first failed and then passed. The additional
capture-limit fixture also failed before acceptance was based on captured
content rather than helper presence. The full native suite passed **647/647**
in 151,924.6 ms. After the final help wording and capture-limit refinement,
focused consistency and all 33 help checks passed, including native help
navigation/resize. Native task-family and appearance journeys, all 14 Node
tests, static website, documentation, security, inventory, Zsh syntax,
isolated bootstrap re-sourcing and whitespace checks also passed. This pass
did not change browser layout; it does not claim a new manual Terminal.app
visual acceptance run.

## Follow-up: readable shortcut hints without touching glyphs

The supplied Terminal.app screenshot shows the adjacent Option and Return
symbols touching in the Interaction header. Display-cell counts alone cannot
prevent font ink from touching across adjacent symbol cells. Prompt hints now
spell out `Option-Return` and `Option-I`; Context reserves at least 18 cells
for its identity and two cells of separation before admitting a whole hint.
Narrow windows omit optional hints without changing their bindings. Shared
footers separate paired arrows as `↑/↓` and use `Fn/Option ↑/↓ page`.
Standalone Return, directional and frame symbols remain unchanged.

The audit checked shared title bars, acceptance/footer hints, Context and
Interaction headers, and the showcase. Native regression cases cover long
context text, wide Unicode, both pin states, reading/list focus, keyboard-guide
mode and narrow through wide column budgets. The footer regression failed on
the original labels. After correcting the prompt fixture to include a captured
path (an empty lens is intentionally not rendered), restoring the original
adjacent glyphs made the prompt regression fail; the readable hint passed.
Native prompt editing/resize/transcript, fullscreen and chrome checks passed.
The full browser suite passed all 11 responsive widths, and visible Context
headers stayed on one line at 320, 390, 768 and 1440 pixels. These checks do not
claim manual visual acceptance in the user's particular Terminal.app font.

This change adds no provider work, new key bindings, terminal protocols or
dependencies. Headers use the existing display-width and abbreviation helpers;
footers retain whole-hint admission. AGENTS.md and README now document that
contract; the website's synthetic labels use the same readable notation.

Three 500-frame Context-layout samples at 120×30 with synthetic project/path/Git
facts measured 0.427 / 0.413 / 0.424 ms/frame for the previous header routine
and 0.407 / 0.420 / 0.421 ms/frame after. Both used the current shared helpers
and no color map; this measures pure warm layout, not capture or ZLE painting.
These local observations show no material regression, not a speed guarantee.

Final verification: **649/649** native tests passed in 159,440.9 ms, along
with all 14 Node tests, Zsh syntax, isolated bootstrap re-sourcing, inventory,
documentation, security and whitespace checks. Existing private configuration
and unrelated worktree changes were preserved.

## Release-candidate verification

The later pre-commit run passed 648/649 native tests. The existing worktree
enter PTY journey returned successfully but remained in the fixture's original
folder, failing its post-cleanup target assertion. A focused retry and twelve
consecutive repeats passed without changing implementation or assertions.
The cause of this intermittent result has not been established; successful
retries do not prove it fixed. The complete browser suite passed all 11 widths,
the prompt-geometry suite passed five widths, and all 14 Node tests, syntax,
isolated re-sourcing, documentation, security and inventory checks passed.

The second complete native run passed **649/649** in 157,491.7 ms. This is
the final observed suite result, with the earlier intermittent failure retained
above rather than described as a repaired regression.
