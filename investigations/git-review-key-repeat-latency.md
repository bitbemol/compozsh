# Git review key-repeat latency investigation

Status: preview-settlement and nonblocking viewport implementation complete; confirmed in Terminal.app
Recorded: 2026-08-30

## Question

Git review continued moving for roughly three or four rows after the user
released Up or Down. The investigation asked whether queued input should be
discarded, or whether the selection path was taking longer than macOS delivered
repeat events.

## Environment and limits

The observations came from stock macOS Terminal.app with Apple Zsh 5.9. The
measured Git review workspace was 211 columns by 55 rows. Repository contents,
selected files, Terminal geometry, font, macOS version, system Vim grammars,
hardware and system load can all change the timings.

The keyboard settings were using their implicit macOS values: the global
`KeyRepeat` and `InitialKeyRepeat` preferences had no explicit stored override.
macOS exposes both repeat rate and delay until repeat as user settings, so the
observed cadence is machine configuration evidence rather than a platform
constant. Apple documents both controls in
[Set how quickly a key repeats on Mac](https://support.apple.com/guide/mac-help/set-how-quickly-a-key-repeats-mchl0311bdb4/mac).

Temporary diagnostic probes captured these measurements and were intentionally
removed after the investigation.

## Observations

### Input cadence

| Probe | Observation |
| --- | ---: |
| Initial delay before a held key repeated | 497.665 ms |
| Held-key steady median interval | 83.452 ms |
| Held-key steady observed range | 79.668–87.856 ms |
| Held-key peak observed rate | 12.6 events/s |
| Separate rapid-tap median interval | 114.595 ms |
| Separate rapid-tap fastest interval | 55.668 ms |

The approximately 83 ms interval describes this configured held-key run. It is
not a fixed interval for macOS, Terminal.app or Mac hardware.

Keyboard polling rate is a separate quantity. An
[8,000 Hz keyboard](https://www.razer.com/technology/razer-hyperpolling) can report
its physical state to the host every 0.125 ms, reducing actuation latency; it
does not turn one held key into 8,000 Terminal input events per second. macOS
still controls ordinary held-key repetition through its repeat-rate setting.
Keyboard firmware that emits a macro or turbo stream of distinct key presses is
a different input source: every complete press remains user intent and may
outpace the workspace if its event interval is shorter than the hot path.

### Frame and document work

The focused reproduction recorded:

| Work | Samples | Average | Median | 95th percentile | Slowest |
| --- | ---: | ---: | ---: | ---: | ---: |
| Render and paint frame | 62 | 43.373 ms | 42.978 ms | 60.538 ms | 76.792 ms |
| Selected-document load | 29 | 57.560 ms | 57.836 ms | 101.432 ms | 123.963 ms |

Document-load phases isolated the expensive optional work:

| Phase | Calls | Average | Slowest |
| --- | ---: | ---: | ---: |
| Git diff capture | 29 | 14.598 ms | 18.218 ms |
| Diff parse | 29 | 1.025 ms | 7.176 ms |
| Vim syntax capture | 29 | 35.800 ms | 92.300 ms |
| Syntax application | 23 | 3.125 ms | 12.121 ms |

A later torture fixture retained 993 diff rows for one Swift file. Whole-document
syntax exceeded the 300 ms provider deadline. Capturing source rows 1–250 with
the same system Vim completed in 91.062 ms, returned 4,117 bytes of validated
metadata and colored 236 source rows. This is one machine observation, not a
fixed viewport budget; it demonstrates why provider work must scale with the
displayed region rather than the retained document.

The old selection path could require two paints plus a synchronous document
load. Using the measured averages, that path was approximately
`2 × 43.373 + 57.560 = 144.306 ms`, well beyond the 83.452 ms median repeat
interval. Input therefore arrived faster than selection could be presented and
accumulated in Terminal's input stream.

## Decision

Each complete terminal key sequence remains user intent. Terminal.app does not
provide a key-release event to this byte-oriented ZLE input loop, so the picker
does not flush or guess which repeated sequences happened after the physical
release.

The investigation originally optimized the wrong boundary. Even after syntax
became asynchronous, the controller still synchronously captured and parsed one
Git document for every arrow selection. That left a 25–55 ms terminal paint plus
Git work in each repeat interval and could still accumulate unread input.

The final selection path separates lightweight navigation from preview work.
Every complete arrow sequence updates and paints the file selection immediately.
When that selection differs from the loaded reader, the pane shows a stable
loading surface. Each further navigation sequence restarts a 120 ms settlement
window; after the input stream is quiet, the controller captures exactly the
latest selected document. This coalesces previews, not input: no key event is
dropped, and a later independent key applies to the final loaded selection.

Optional syntax is owned by one resident system-Vim process for
the document screen session. Vim retains scratch buffers for the five audited
languages, so grammar startup is paid once rather than on each selected file.
Residency alone was not the latency fix: synchronously waiting for that process
still serialized a 35–92 ms syntax step into an approximately 83 ms repeat stream
and recreated the input tail.

After layout publishes the exact viewport, an input-idle callback schedules one
framed, bounded request for a multi-page window around that viewport. It
never waits for process readiness or request completion. The worker permits one
in-flight request and no queue. Each request receives a monotonically increasing
ID; a completed response can publish only if its document key and source-row
window still cover the current view. Older responses are discarded and the
latest desired viewport is scheduled next.

This follows the event-loop/task boundary documented by mature terminal tools:
Lazygit moves expensive work to a worker, returns view updates to its UI thread,
and uses task IDs plus cancellation to prevent older tasks from updating the
view ([codebase guide](https://github.com/jesseduffield/lazygit/blob/master/docs/dev/Codebase_Guide.md),
[task manager](https://github.com/jesseduffield/lazygit/blob/master/pkg/tasks/tasks.go)).
Neovim likewise integrates input and asynchronous job/timer/RPC events through
its event loop rather than synchronously waiting for a job in key handling
([developer architecture](https://neovim.io/doc/user/dev_arch.html)).
Compozsh implements the small native-Zsh subset needed here; it does not import
either tool or add a general task framework.

While supported source is pending, the reader retains one hidden presentation
row per source row. This preserves the viewport coordinates needed to complete
the request without exposing an unhighlighted code frame. The validated current
response replaces that stable loading surface atomically. The child has an
800 ms analysis guard and the asynchronous parent has a one-second liveness
deadline; neither is an input wait. A transient failure retires the child,
remains retryable once for the same settled viewport and never poisons unrelated
files or the whole session. A second failure for that captured window leaves an
explicit readable plain fallback. Snapshot epochs reject pre-refresh responses
even when numeric file indexes are reused. Interactive job control stays
disabled only for the workspace; normal shell state is restored on exit.

The torture fixture also isolated how provider time scales with captured source
rows on this machine:

| Captured rows | Vim capture |
| ---: | ---: |
| 60 | 38.82 ms |
| 150 | 63.12 ms |
| 250 | 88.46 ms |
| 450 | 136.48 ms |

The resident prototype averaged about **39.8 ms** for 40 dense synthetic Swift
rows and **45.5 ms** for 44 rows on this machine. Expanding to 120 rows averaged
about **213.2 ms**, which ruled out synchronous screen-multiple capture in the
input path. The shipped asynchronous request can use a bounded read-ahead
window (normally three visible spans each way, capped at 256 guard rows) because
the installed colored frame remains usable while its replacement runs. Two
visible spans before an interior edge, that speculative replacement starts in
the background. Page gestures therefore consume retained coverage instead of
exposing a loading frame; a speculative failure retains the old valid window.
These are machine-specific observations, not universal timing constants.

The earlier adjacent-file prediction did not remove the visible transition and
has been deleted. There is no speculative neighbor cache. The existing
four-document visited snapshot cache retains only windows that were actually
requested, and all Vim buffers, FIFOs and process state disappear with the
screen session.

The earlier estimate of one paint plus Git capture and parse—approximately
`43.373 + 14.598 + 1.025 = 58.996 ms`—left too little variance beneath this
run's 83.452 ms median repeat interval. Git capture and parse therefore no longer
belong to the repeating navigation path at all. The remaining requirement is
that list-only render/paint consume repeated input with useful headroom; the
final interaction must still be measured and felt in Terminal.app.

## Portability rule

Keyboard repeat cadence is a configurable input rate. Faster hardware can
reduce Git, parsing, rendering and painting time, making backlog less likely
when the complete hot path stays below that machine's configured repeat period.
Faster hardware does not itself shorten or lengthen the configured repeat
interval. A faster repeat setting, larger terminal, slower repository operation,
different system Vim grammar or heavy system load can expose the same pressure
on any Mac.

Future work should compare complete hot-path latency with the observed repeat
cadence under the supported test configuration and retain useful headroom.
Hard-coded assumptions that every Mac supplies an 83 ms interval are invalid.
Optional work remains outside the key path even when a measured resident request
often fits the interaction budget: worst-case variance is enough to recreate a
queue. Moving syntax behind a focus gesture is not an
acceptable latency fix when metadata should be visible in the passive pane too.

## Verification record

Focused implementation checks cover wrapped-row viewport derivation, bounded
overscan derivation, framed resident FIFO requests, latest-generation and
snapshot-epoch publication, transient retry, selected/document alignment,
pending-surface geometry, cleanup, system-Vim protocol output and native ZLE
color rendering. A deterministic PTY test writes eight complete Down sequences
in one burst, observes only the initial and final document loads (`1 → 9`), then
verifies that Right focuses file 9 with no unread movement tail. The same native
lane delivers five more Down sequences at approximately 80 ms intervals and
again proves that only the final document loads and no unread movement remains.
A deterministic unit sequence also proves the full quiet countdown restarts
after repeated keys, including Down repeats at the list boundary where selection
cannot move. Final focused verification passes **21 syntax tests, 7 document
tests, the buffered/paced native burst test and the queued-input/prepaint-order
test with 0 failures**. The complete shared-worktree suite passes **267 tests
with 0 failures**.

The final acceptance condition remains a manual Terminal.app hold-and-release
test after reloading the shell. Automated tests preserve event ordering and the
single-frame/provider boundary; they cannot observe a physical key release that
Terminal.app does not report.
