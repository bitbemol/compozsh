# Docked, focus-responsive tooling

2026-09-04. This extends [focus-responsive views](focus-responsive-ui.md) with
shared screen composition, rather than adding another renderer or input loop.

## Implemented boundary

- Quiet task identity above captured scope and a passive disclosure strip.
- A bottom input surface with the actual ZLE cursor at the query end, followed
  by an emphasized, capability-derived acceptance action and bounded hints.
- Ordinary choices receive blank-row spacing only when twice the configured
  visible-slot budget fits. Filtering cannot switch density. Documents, passive
  information and stacked output remain compact; no selectable slot is lost.
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
