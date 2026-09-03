# Simulator run view

## Adopted boundary

Build & Run and Rebuild & Run already used the selected scheme and concrete
Simulator destination. The extension starts after the native build and install:
one run owns two pipes, a bounded combined app-output tail, a scoped native log
observer, and an observed process identity.
It composes the existing shared picker with Stop, a full log reader with
literal filtering and explicit copying, and conditional LLDB actions. There
is no new public command, key map, persistent worker, log
file, or startup discovery.

App stdout/stderr uses `simctl launch --stdout=… --stderr=…` with
`--terminate-running-process` and `SIMCTL_CHILD_NSUnbufferedIO=YES`; the separate
launch response resolves the PID. Never parse a PID from app output. The
installed Apple CLI describes those output-redirection options. Real integration
revealed that these paths are relative to the Simulator data filesystem: a host
temporary path created a different regular file inside the disposable device.
The final implementation obtains `SIMULATOR_SHARED_RESOURCES_DIRECTORY` from
the exact device, validates its data root and `tmp` child, creates the FIFO under
that host directory, and passes the separate `/tmp/compozsh-xcode-run.*/output`
guest path. Native descriptor inspection then confirmed stdout and stderr both
pointed to the intended FIFO. The ordinary regression suite uses command spies;
the isolated real integration check is recorded below.

The other FIFO carries the exact selected Simulator's native unified-log
stream. Its `processImagePath` predicate matches the canonical installed
`CFBundleExecutable` path before delivery. The observer starts before launch,
waits a bounded time for the native startup header, and exists only for this
run. The app can emit framework records within this scope; helpers/extensions
with different executable paths are excluded, while another launch of the
same exact executable can match. The observer uses `LOGRC=/dev/null` to avoid
personal `.logrc` rules broadening capture. The logging follow-up below records
the buffering and privacy evidence behind this boundary.

The [LLDB command reference](https://lldb.llvm.org/man/lldb.html) documents
PID attachment and disabling automatic initialization. The handoff adds a
fixed setting disabling automatic symbol-script loading. Attachment remains
subject to signing, developer permissions, and process liveness.
The installed LLDB accepted and reported `target.load-script-from-symbol-file`
as `false` in a batch invocation with initialization disabled and no target.

## Interaction decisions

The action list stays stable while output updates. Only actions receive digits.
One fixed inspection key keeps the output independent of action selection or
filtering. Below 100 columns, the shared renderer stacks output under actions,
reserving a title and a log row when the window has room for both. Secondary
prose yields space before action navigation or output. Focus expands reading.
The output pane uses ordinary text styling and clips long lines through the
shared inspector. Keeping one source line per display row preserves the recent
tail when the window narrows; ordinary inspector wrapping would exhaust its
256-row limit before reaching the newest output.

The combined live tail is bounded to 32 KiB and 200 source lines, with at most
8 KiB of an unfinished line per source. Focusing the small preview or opening
the guide freezes its display; returning to actions resumes following.
Read output opens a separate full-width wrapped reader that follows the newest
retained tail with its literal filter. Scrolling upward holds the displayed
snapshot and position; reaching the bottom or Follow latest resumes updates.
Mode, filter and paused bookmark survive Options and returns to Run. Options
holds its displayed copy scope while the run owner keeps capturing. Copy uses its
complete matching source lines, including offscreen content, after terminal
restoration; Run then reopens. Clipboard data can outlive the run under
operating-system/user control. The full reader uses the shared document
wrapping boundary of 20,000 rows; there are no selectable log rows.

Stop/Escape in Run restores the terminal before terminating the exact
Simulator bundle; Escape in the full reader returns to Run. The unified-log observer is
stopped and reaped before LLDB receives the terminal; stdout/stderr is drained
and discarded until debugger exit. Cleanup then stops the
run. A stream closing does not prove process exit. An unavailable or changed
process identity prevents termination, reports manual Simulator recovery, and
returns failure; the app may already have exited.

These choices apply recognition, consistent controls, stable reading position,
and progressive disclosure. They make no claim of neuroscientific validation.

## Verification

Focused red phases established missing run lifecycle and log bounds, resuming
after reading, preserving the newest rows across resize, pipe-read failure
disclosure, help facts, and clearing the last rendered log frame on exit.

```sh
zsh tests/run.zsh xcode
zsh tests/run.zsh 'tool help explains'
zsh tests/run.zsh 'README inventory'
zsh tests/run.zsh security
```

Native PTY coverage exercises 120×30 → 70×18, incoming output during frozen
reading, guide opening/dismissal, resumed output, Escape, Ctrl-C, and LLDB
handoff after screen restoration. Synthetic launch/debugger/termination spies
verify exact targets and status, malformed PID refusal, process replacement,
failed launch/stop, and removal of temporary pipes and retained log frames.
The debugger handoff also checks that internal helper job notices do not leak
into the terminal; the helper stays alive until cleanup, and foreground LLDB
retains the caller's job-control setting.
Independent architecture/security, performance, and UI/regression reviews found
and prompted regressions for missing-identity disclosure, redundant redraws of
frozen output, hidden live output at narrow widths, action changes resetting the
tail, and lost digit actions after Follow latest. Focused tests reproduced these
failures before fixes. Coverage now includes 80/70/40-column windows at 24/18/12
and 11/10/9 rows, empty action matches, quiet-output action changes and repeated
digit use. A delayed-writer FIFO regression also covers the launch-time gap
between the initial keeper closing and the app opening its output handles.
EOF remains provisional until the first app bytes arrive.

A later user-visible check exposed a missing window handoff: Xcode 27 ships
Device Hub at `Contents/Applications/DeviceHub.app`, while the old coordinator
called `open -a Simulator` and suppressed errors. Booting a Simulator through
`simctl` does not require its viewer to exist. The correction resolves the
active Xcode with `xcode-select --print-path` (including either documented
`DEVELOPER_DIR` form), chooses only its bundled viewer, and targets the selected
device. Device Hub uses its local `devices:///manage/select?id=…` route with an
explicit application bundle. Legacy Simulator receives `-CurrentDeviceUDID`;
an already-open legacy app may retain its current window selection. Any failed
open stops before app installation or launch. Regressions cover both viewers,
Xcode paths containing spaces, invalid IDs, missing viewers and failure status.
Opening the user's already-running selected device in Device Hub resolved the
reported missing-window symptom; the user confirmed that the window appeared.
Apple describes the current viewer in its
[Device Hub documentation](https://developer.apple.com/documentation/xcode/device-hub).
These regression tests exercise Compozsh's terminal lifecycle. A separate real
host check used Xcode 27.0 (27A5252f), the iOS 26.5 runtime, and a synthetic UIKit
app compiled locally for arm64 Simulator. Every device was created inside a
fresh disposable device set; no existing Simulator or private project was used.
Both stdout and stderr markers arrived through the FIFO, Stop terminated the
launched app, LLDB attached to the observed PID and detached, and post-debugger
cleanup stopped the run. The run directory and temporary device were removed;
the device set was empty afterward. This verified the actual product run
lifecycle using a test controller and a batch LLDB wrapper; nested ZLE interaction
is covered separately by the PTY regressions. App stdout/stderr descriptors were
confirmed to be FIFO handles rather than regular files.

Manual visual acceptance inside Terminal.app remains unperformed here:
choose a synthetic app's scheme and Simulator; Build & Run; produce stdout and
stderr; read older output through window/fullscreen resizing; resume following;
enter LLDB, continue, and quit; repeat with Escape and a naturally exiting app.
Check app termination, prompt restoration, and absence of pipe directories.

## Timing observations

On the local macOS/Zsh 5.9 host, 15 alternating isolated startup samples compared
HEAD with this change. Excluding the first pair to separate cold filesystem
effects, median bootstrap time was 49.992 ms before and 50.764 ms after. Every
sample used a fresh shell and disposable HOME/ZDOTDIR; files were warm. No
project or user configuration was loaded. The first baseline copy read was
209.308 ms, illustrating why it was not treated as steady-state startup cost.

Ten batches of 20 frames, each publishing a 200-line synthetic tail with
80-character bodies into the shared 120×30 renderer, took 7.489–7.880 ms/frame.
This measures snapshot publication plus frame construction, excluding terminal
painting and Simulator execution. The native PTY tests cover painting and
input correctness separately. These observations are not compatibility limits
or measurements of cold Xcode build/launch performance.

The independent performance review compared 200 paused iterations, each with
four approximately 7.8 KiB reads. Fixing redundant redraw requests reduced
unchanged-frame requests from 200 to zero while retaining all 800 reads; time
fell from 2.64 to 1.67 ms/iteration. Quiet paused polling measured 0.041 ms;
following a flood measured 8.86 ms/frame. These synthetic measurements exclude
terminal painting and real Simulator execution. The UI review separately swept
224 UTF-8 layouts over 20–200 columns, 9–40 rows, matching/empty results, and
both focuses, checking body bounds, row widths, and metadata alignment.

Initial feature review result: **445 passed, 0 failed** in the full native suite, and
**45 passed, 0 failed** in the focused Xcode suite. These runs used the
shared working tree, which also contained unrelated ongoing changes. The Xcode
reviews and native integration checks were scoped to this feature. Syntax
validation, double bootstrap sourcing in an isolated home, the privilege and
credential boundary checks, help facts, README inventory, and `git diff --check`
also passed. All independent review findings were resolved and rechecked.

After the viewer handoff correction, the full native suite passed **450 tests**
with **0 failures**, and the focused Xcode suite passed **46 tests** with
**0 failures**. The failure-path regressions failed before the correction and
passed afterward. Syntax validation, isolated double bootstrap sourcing, help
facts, and `git diff --check` also passed. An independent architecture and
correctness review found no blocking issues; exact device selection in an
already-running legacy Simulator remains unverified as described above.

## Native LLDB presentation follow-up

The debugger handoff now sets invocation-local native presentation options
after the mandatory init/symbol-script protections and before attachment.
The Xcode peer owns terminal detection and execution; the optional output peer
derives six fixed settings from validated heading, warning and muted palette
indexes. There is no new input loop, output filter, source-time probe, persistent
configuration or worker. Missing presentation properties use LLDB's native
`settings set --exists` behavior; unavailable styling cannot relax hardening.
Nonempty `NO_COLOR`, unsupported terminals, or redirected stdout/stderr pass
`--no-use-colors`. Quiet startup suppresses only the initial command echoes.

The focused regression failed before implementation, then passed with both
256-color terminal types, palette overrides, malformed values, an absent output
capability, low-color terminals, plain fallbacks, and debugger exit status.
Independent architecture, performance, and UI/regression reviews found no
blocking issues. Runtime peer lookup and a caller-owned argument array preserve
load-order independence; presentation calculation adds no per-keystroke work.

Native validation used the installed Xcode 27 LLDB in a disposable home and
synthetic C and Swift executables, without launching or attaching to a user
process. At 40 columns, `xterm-256color` and `screen-256color` showed the palette
prompt, source markers, and C token colors. A command crossed the right edge,
was corrected with Backspace, and executed successfully; Quit completed.
`NO_COLOR` and `dumb` retained plain source and prompts. Native LLDB still uses
terminal controls and inverse status emphasis where applicable under `NO_COLOR`.
Swift source tokens remained plain in this Apple LLDB despite the enabled
setting; its prompt and source markers used the palette. These are PTY checks,
not a manual Terminal.app visual acceptance.

The native command editor exposes no shell-style input-token highlighter.
The [LLDB source-highlighting setting](https://lldb.llvm.org/use/settings.html#highlight-source-boolean)
controls displayed source, with language-dependent support. README/help state
both limits explicitly; command or Swift expression coloring is not claimed.

Validation after this follow-up: **451 passed, 0 failed** in the shared-tree
native suite, **47 passed, 0 failed** in the focused Xcode suite, plus native
PTY checks, syntax checks, isolated double sourcing, and `git diff --check`.
The suite includes the security, documentation inventory, and peer-order
contracts. Temporary native validation fixtures were removed afterward.

## Action option-name emphasis

Actions now provides one keyed `picker-header` span for each option name,
ending before its first literal separator. Settings and descriptions retain
normal text; other Xcode views receive an empty local span map. Captured labels,
exact values, filtering, and providers are unchanged. The shared renderer
preserves the complete active/inactive selected-row style for a heading span,
so heading blue cannot disappear against a blue selection background.

The focused regression failed before the change and passed afterward. It
covers all Actions prefixes, a setting containing the separator, filtering,
narrow clipping, plain labels, submenu isolation, a custom palette role, and
dark/light/inactive selection contrast. Independent UI/regression review found
no actionable issues. Native ZLE validation in a disposable home confirmed the
painted Destination prefix in bold palette blue (75 dark / 25 light), followed
by normal text (252 dark / 236 light). Both palettes passed Scheme/Back,
filtering, resizing from 120 to 40 columns, and cancellation. No real project,
Simulator, or Xcode process was used; this was a PTY check rather than manual
Terminal.app visual acceptance.

Two alternating 100-frame samples with eight synthetic Actions rows at 120×30
measured 1.01–1.03 ms/frame without label spans and 1.09–1.15 ms/frame with
option spans, for frame calculation only. These local observations exclude
painting and are not compatibility limits. Validation passed **452 tests** in
the shared-tree suite and **48 focused Xcode tests**, with **0 failures**, plus
syntax checks, isolated double sourcing, help facts, and `git diff --check`.

## Read output replaces redundant following

The user reported that selecting the second run action only reloaded the
window and focused Stop. The original Follow latest action restarted the
picker even though Actions already followed automatically, so it offered no
distinct reading operation. At that stage, Read output opened the shared preview
at the captured tail, preserving the filter and selected action. Only display
publication pauses; returning to Actions resumes automatic following. The
output title names Following/Paused and retains Closed/Unavailable states.
At this stage, the quiet-output message explained received bytes, possible
buffering/absence, and the stdout/stderr scope without claiming why an
app produced no bytes. The logging follow-up below supersedes that source
limitation and its empty-state copy; the full-reader follow-up supersedes
this initial preview-only action.

Regressions first reproduced the redundant action and missing feedback, then
passed for reader focus, newest-line positioning, default and filtered
selection, digit actions, frozen display, quiet callbacks, visible explanation,
and stream-state titles. Native PTY validation used both digit 2 and filtered
`read` + Enter, then resize, guide, resume, Stop and LLDB. Independent
UI/correctness review found no remaining actionable issues. No user project or
Simulator inspection was needed to reproduce the reported menu reset.

Two thousand quiet callbacks per mode, with a synthetic nonblocking read,
measured approximately 0.043 ms while following and 0.042 ms while reading.
Both produced zero redundant redraw requests after the initial frame. These
local CPU observations exclude real pipe I/O and painting; the native PTY
tests exercise the actual pipe and terminal lifecycle separately.

Validation passed **453 tests** in the shared-tree native suite and **49 focused
Xcode tests**, with **0 failures**. Syntax checks, isolated double sourcing,
the final filtered-selection regression, security/documentation contracts,
and `git diff --check` also passed.

## App stdout and unified-log capture

The user subsequently reported no visible app logs. The earlier Read output
change corrected a redundant action, but it did not establish the cause of
missing messages or add a logging source. A disposable native iOS 27 probe
then separated stdout buffering from unified logging. Its machine-readable
evidence was recorded at `/tmp/compozsh-xcode-logs.Ac1dl6Jl/probe-result.json`;
this temporary path is not a durable repository artifact. The observations
below preserve the relevant synthetic results without user app data.

During the baseline observation window, startup and two tick markers from
stderr and `NSLog` arrived, but the corresponding `print` markers did not.
Repeating launch with `SIMCTL_CHILD_NSUnbufferedIO=YES` delivered all three
startup/tick families: `print`, stderr, and `NSLog`. The scoped device-native
stream delivered startup and tick `Logger` debug, info, and error records in
both modes. Both probe stream runs reported status 0 and no error text.
These are observations from this fixture/runtime, not a guarantee that all
apps flush their own buffers or that native logging delivers every record.

The new launch requests unbuffered output and uses
`--terminate-running-process` so a requested new run replaces an existing
instance and binds the new process to its output FIFO. Before launch, a second
FIFO receives native `log stream --level debug --style compact --color none`
through `simctl spawn` for the exact device. Compozsh resolves the canonical
installed `CFBundleExecutable` path and supplies an exact `processImagePath`
predicate before capture, with a bounded wait for the native startup header.
It does not collect a broad device stream for later filtering. The observer's
`LOGRC=/dev/null` environment prevents personal `.logrc` rules from changing
that scope; the setting is local to the log child.

This path predicate includes framework messages emitted inside the app and
excludes helpers/extensions with different executables. Another launch of the
same exact executable can match. Native startup races and record drops remain
possible; duplicate messages can appear through both sources, and merged read
order does not establish a global timestamp order. This is a bounded live view
of these two sources, not coverage of every Xcode console feature.

The native Simulator probe exposed its synthetic `.private` payload by
default in both modes. No private-data enabling option was requested.
Documentation therefore preserves native privacy behavior without promising
redaction: sensitive app values can be displayed. The local-only contract,
absence of a persistent Compozsh log file, and bounded memory lifetime are
separate guarantees.

The combined tail remains limited to 32 KiB/200 lines, plus up to 8 KiB of an
unfinished line per source and one bounded frozen reading snapshot. The shared
idle boundary drains fairly across both FIFOs within a 32 KiB turn budget;
rendering and resize remain provider-free. A source failure is visible while
the other source continues. Read output freezes only display publication.
The waiting state names stdout/stderr and Logger capture, without claiming
that the app must emit a message. The observer is stopped and reaped before
LLDB and in cleanup; only the existing stdout/stderr drainer remains while
debugging.

The historical suite counts and timings above precede this source extension.
The actual updated Run implementation was separately exercised against the
disposable iOS 27 fixture: its combined live tail received Swift print, stderr,
NSLog, and Logger debug/info/error records. Stop returned status 0, the app and
owned observer were gone, and its invocation directory was removed. A strict
initial assertion requiring the same early timer tick from both sources failed:
the startup framework burst had already displaced that stdout record from the
bounded tail. Subsequent checks verified all six output types in the live tail;
the earlier source probes separately establish startup capture. This is why
the feature promises a bounded recent tail rather than complete log history.

Independent native cancellation probes identified only their own exact-path
stream using a unique predicate marker. TERM to the simctl wrapper returned
143 in about 7 ms and its Simulator log process disappeared. INT returned 0 in
about 7 ms with the same cleanup. The guest belongs to Simulator launchd and a
different process group; forwarding TERM/INT and waiting for the owned wrapper
is required. KILL cannot forward. Production additionally checks Zsh's native
job state before signalling, so an early observer exit cannot leave a stale
numeric PID as an eventual cleanup target.

Reviews also caught an extra-newline regression, misleading whole-output
closure while Logger remained active, and excessive glob work in partial-line
merging. A native line-array split reduced fragment processing from
1.37–1.40 ms to 0.47–0.51 ms per approximately 7.8 KiB chunk over three
alternating 400-chunk batches on this host. The final reader retains the same
four-read/32 KiB callback budget, independent source state, bounded pending
fragments, and frozen-display behavior. These are local observations, not
compatibility thresholds.

Final source-extension validation: the full native suite passed 458 tests with
zero failures (104.2 seconds on this host); syntax checks, isolated double
bootstrap sourcing, and diff whitespace checks also passed. The rendered
70×18 paused-reader regression covers seven source-failure scenarios, including
empty and nonempty snapshots: failed-source status stays visible, empty rows
refresh, and captured frozen log text is preserved. Architecture/security,
performance, and UI/regression reviewers found no remaining actionable issues
in the reviewed changes. After the real run check, no owned native log observer
remained; the disposable Simulator was shut down and deleted, its device set
was confirmed empty, and its synthetic app and capture files were removed.

## Initial full log reader and explicit copying

The later request added a primary reading view for the retained output. This
initial version, superseded by live following below, opened the shared
renderer's reader-only document capability:
full width at narrow and wide sizes, wrapped source lines, stable source
anchors across resize, and no placeholder candidates, selection highlight,
digit actions or hidden list focus. Run's small preview remains available
through its existing pane controls. This separates the recent live tail from
the user's explicitly captured reading document without changing the source
observer or introducing a second screen lifecycle or key map.

The first reader entry captures the newest bounded tail and starts at its end.
Typing matches a case-insensitive literal substring against each original
source line before wrapping, with matching/total source-line counts. A filter
change starts at the first match. Snapshot, filter and reading position survive
Options, Escape to Run, reopening and Copy. The existing Run owner continues
draining both sources during reading and Options; the full document only
changes on explicit Refresh latest logs or Ctrl-R. Refresh keeps the filter
and moves to the latest matching line. Empty/no-match states remain readable
and offer refresh and filter recovery.

Enter opens Options: Copy all captured logs for an empty filter or Copy
filtered logs otherwise, Refresh latest logs, Go to beginning, Go to latest,
Clear filter when present, and Return to Run. Escape in Options returns to the
reader; Escape/Ctrl-G in the reader returns to Run with the app running.
Ctrl-Y performs the same copy-and-return action. Ctrl-K uses the shared guide,
and Ctrl-C retains the run's abort-and-cleanup semantics.

The accepted clipboard payload consists only of complete matching raw lines
from the retained snapshot, including offscreen content, without UI text or
display wrapping. It is bounded by the 32 KiB/200-source-line capture, not the
current viewport or the shared 20,000 wrapped-row rendering limit. It does not
claim complete run history. Copy is unavailable for empty/no-match output or
without a captured clipboard capability. The owner restores the screen before
rechecking and invoking the captured `pbcopy`, then reopens Run with feedback;
failure keeps the app running and retains a nonzero eventual status. Compozsh
never reads the clipboard. The user-requested export intentionally extends
the log-data lifetime into the operating system's clipboard, including native
sensitive values and independently enabled clipboard synchronization.

Initial read-only review reproduced two narrow-window feedback failures with
synthetic controller frames: at 70×11, the Run renderer discarded a copy
failure appended as secondary prose; at 40×18, counts and trim notices clipped
the later Logger failure state. Review also identified a later successful LLDB
exit overwriting an earlier clipboard failure status. Focused regressions first
failed, then passed after copy feedback moved to the Run header, source failures
moved ahead of reader counts, and a successful debugger stopped overwriting an
earlier failure. The eight matching Xcode log cases passed with zero failures;
the public-help boundary was also updated through a failing regression. These
checks involved no real Simulator, private project or clipboard access.

The shared reader's native tests passed for full-width 140/90/40-column
rendering, source anchors after resize/reentry, full 32 KiB ASCII wrapping,
literal filtering and digits, no-match options/refresh, copy, paging, guide
isolation, and restored keys/screens. The preview, retained full-reader
snapshot, and live tail are separate bounded copies with distinct purposes;
rendered document arrays and filtered copy text are bounded derivations, not
another source or an accumulated log history. Existing dashboard action-name
spans remain limited to that dashboard; the new reader and Options use shared
document and picker palette roles without embedding styles in raw log text.

The architecture review measured one long 32 KiB ASCII source line at 120,
70 and 40 columns. Wrapping fell from approximately 146/251/445 ms to
19/30/51 ms after using direct cell slicing for printable ASCII in the
reader-only document path. Native Unicode wrapping remains unchanged, and
focused tests compare preserved text, bounds and source-row mappings across
ASCII, Unicode and control characters. An ordinary 199-line document measured
approximately 9/11/16 ms at the same widths. These are observations on the
development host, not universal latency thresholds.

The extended synthetic native PTY flow exercises a zero-match filter,
Options, Escape back to the reader, Ctrl-R refresh, filtered copy, return to
Run, reopening with the retained filter, clearing it, and Ctrl-Y copying the
whole retained snapshot. All functional assertions passed before final
privacy checks. A new cleanup assertion then failed with `DONE96` because
the helper scratch value `REPLY` retained process-identity text after run exit.
After scoping it to the run owner, the next check failed with `ABORT95`:
aborting directly from the reader retained its synthetic private filter in the
shared bookmark. Scoping that bookmark and its focus to the same owner resolved
the second leak while preserving navigation during the run. The final native
full-flow/privacy test passed in approximately 1.5 seconds. These checks use
disposable command and clipboard spies; they are not a manual Terminal.app
check or a new real Simulator test.

Final full-reader validation passed all 466 native regression tests with zero
failures (approximately 108 seconds on the development host). Syntax checks,
isolated double-bootstrap loading, and whitespace validation also passed.
Independent architecture, performance, UI/UX, code-quality and regression
reviews found no remaining actionable defects in the reviewed changes.

## Live reader and structured presentation follow-up

The user found the full reader too dense and expected current logs to arrive
automatically. The adopted follow-up keeps the same bounded sources and
full-width document, but follows new output by default. Scrolling upward
pauses publication so the reading position stays stable; returning to the
bottom or explicitly following the latest output resumes it. The literal
source-line filter stays active across incoming output. Manual refresh is no
longer the required path to current logs.

Presentation separates recognized native compact-log metadata from message
bodies, with textual severity and existing semantic colors. Default/Info
headers use the information role, Debug is muted, and Error/Fault use the
error role. Visual review favored the existing soft-blue information accent
for Default because those records dominate ordinary output; their native
severity labels remain distinct and message bodies keep normal text styling.
The formatter change passed its focused red/green regression.
Blank rows separate recognized records without adding a trailing
separator; ordinary output and continuation lines remain contiguous.
The formatter derives display rows from bounded captured text; it parses no
commands, changes no raw matching/copy semantics, and requests no additional
logs. A plain fallback preserves unrecognized source lines without guessing
severity from their message words. Opening Options freezes the
displayed document and its raw copy scope while the existing run owner keeps
capturing; returning restores the prior reading mode. Options offers Copy,
conditional Pause display, Follow latest, Go to beginning (which pauses),
conditional Clear filter, and Return to Run. Up/page-up/Home pauses; reaching
the bottom or End follows. The reader title names Live/Paused, and its footer
and guide show the applicable controls without a refresh requirement.

Review found that a stream of identical lines could roll the bounded tail
without changing its raw text. The live callback now updates trim metadata
independently, preserving the dropped-logs notice without needless formatting
or redraw on the next quiet callback. Nonmatching output that changes the raw
tail without changing the visible matching text also preserves prepared
formatting and wrapping; counts and status still update when needed.

The extended native PTY test passed in approximately 1.9 seconds. It verifies
automatic arrival with no key press, resize, guide capture freeze, scrolling
up while new bytes arrive, End following, and Options holding a zero-match
capture until return. New matching output then appears under the existing
filter. The same flow covers filtered/all copying, return/reentry, LLDB, and
abort privacy cleanup. Twelve focused Xcode log cases and the formatted-copy
case also passed independently. The integrated focused Xcode suite then passed
all 64 cases. These use synthetic command/clipboard spies;
they do not claim a new manual Terminal.app or real Simulator check.

The full reader opts out of the shared callback before paint because capture
does not depend on viewport geometry. The default remains intact for other
documents. A native PTY regression verified callback counts at the first two
painted frames: 1/3 by default, 0/1 with the opt-out. This prevents a continuous
stream from preparing a second update before the previous one is displayed.

An initial full run passed 475 checks and encountered two selection-contrast
failures while a separate palette change was in progress. Both cases passed
against the updated workspace immediately afterward. A repeated complete run
passed 478 checks, including all 64 Xcode cases and all four shared-reader
cases, while one newly added native palette check failed during further edits
to that separate change. That palette check passed on immediate focused rerun.
Syntax checks, isolated double-bootstrap loading, and whitespace checks also
passed. These results distinguish the full-run observations from the focused
reruns rather than claiming one uninterrupted green run of a changing tree.

The final performance review measured zero unnecessary redraws in 20 changing
nonmatching-noise callbacks. With an unchanged 16 KiB matching line, each such
callback fell from approximately 19.9 ms to 2 ms; a zero-match filter measured
about 1.1 ms, unchanged live capture about 0.4 ms, and paused capture about
0.15 ms. Ordinary 200-record frame construction measured about 29–37 ms.

A retained native Unicode wrapping limitation remains: cold reflow of a single
32 KiB line consisting mostly of ASCII and ending in `é` measured approximately
153/254/442 ms at 120/70/40 columns, compared with 20/30/51 ms for pure ASCII.
This change preserves native Unicode geometry rather than broadening the
wrapper algorithm; unchanged matching text reuses its prepared wrapping.
These isolated measurements exclude terminal painting and are observations
from the development host, not universal latency guarantees.

Before commit, an isolated snapshot containing only this feature and its
supporting changes passed all 472 regression checks in approximately 109 seconds.
Syntax checks, isolated double-bootstrap loading, whitespace checks, and the
tracked-tree private-data scan also passed. Concurrent palette work was excluded
from that snapshot and from the feature commit.
