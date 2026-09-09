# Xcode discovery performance investigation

## Scope and measurements

Investigated slow entry into Actions and switching schemes/destinations, then
traced Build & Run and Test. The initial measurements below used the
`bb0405b` implementation; the implementation and comparison follow below.
Measurements used native Zsh 5.9,
Xcode 27.0 beta (27A5252f), and an already-open Mac application project with one
scheme. They do not establish performance across large workspaces, package-heavy
projects, disconnected devices, or a cold machine.

Native discovery ran with normal macOS service access and all existing package
safety arguments. No builds, tests, installations, app launches, package updates,
or cache flushes were requested. Initial sandbox timings emitted service errors
and were excluded. Existing Xcode service/cache state was retained; these are
repeated-query measurements, not controlled cold-start measurements.

| Operation | Measured time | Samples |
| --- | ---: | ---: |
| Native `-list -json`, median | 817 ms | 5 |
| Compozsh scheme capture and parsing, median | 900 ms | 5 |
| Native `-showdestinations`, median | 903 ms | 5 |
| Compozsh destination capture and parsing, median | 840 ms | 5 |
| Compozsh schemes plus destinations, median of paired totals | 1,748 ms | 5 |
| Destination parsing of the captured native output, mean | 6.5 ms | 100 |
| Bounded capture replay through `cat`, mean | 12.3 ms | 100 |
| Actions → Destination → Actions collection/rendering, mean | 6.8 ms | 100 |
| Bounded native `-showBuildSettings -json` capture, median | 1,015 ms | 3 |
| Existing build-settings parser with captured native JSON, mean | 54.1 ms | 20 |

The native and Compozsh samples ran sequentially with varying host load. Their
differences are noise-sensitive; they do not show that the wrapper accelerates
destination discovery. The capture replay includes process and temporary-file
overhead. The UI measurement exercised the controller, collector and renderer
with fixture providers and a substituted input loop at 120×40; it excludes
terminal painting, keyboard latency and native discovery. It is explanatory,
not an end-to-end interactive benchmark. Settings output was approximately
42 KiB and parsing found an existing runnable product without launching it.

## Where the waits occur

The current controller waits for `-list -json`, selects the first scheme, waits
for its `-showdestinations`, and only then presents Actions. Selecting a different
uncached scheme makes another destination query before returning to Actions.
This eagerly discovers destinations for schemes the user might only browse.

Selecting a destination from the current captured list performs no provider
call. Revisiting one of the four retained scheme snapshots already performs no
provider call. Refresh explicitly re-queries; leaving the workspace releases
the cache, so reopening repeats both initial queries.

| Workflow from a fresh single-container workspace | `xcodebuild` calls |
| --- | --- |
| Open Actions | list, destinations |
| Switch to an uncached scheme | one additional destinations query |
| Build / Analyze / Clean | list, destinations, requested action |
| Build & Run | list, destinations, build, settings |
| Test | list, destinations, test; result queries subsequently use `xcresulttool` |

Other Apple tools have separate jobs: `simctl` manages Simulator operations,
`devicectl` installs/launches on devices, and `open` launches Mac applications.
These are not all `xcodebuild` operations. Run resolves the exact built product
from settings after a successful build; replacing that with guessed paths or a
different settings query would change correctness. Builds already use normal
incremental actions and retain native caches; explicit Rebuild adds `clean`.

## Native CLI alternatives checked

- Apple documents `-list` as the scheme discovery interface. The installed
  `xcodebuild -help` also documents `-showdestinations` and
  `-showBuildSettings -json`. JSON already implies quiet output.
- Combining `-list -json -showdestinations` in three native samples returned
  destination text alone, not both catalogs. It cannot replace both queries.
- Three `-destination-timeout 0` samples took 731–819 ms, compared with
  668–1,052 ms for ordinary destination discovery in that exploratory batch.
  The first ordinary result had fewer records while services warmed. This does
  not prove an equivalent, reliable speedup. The installed manual describes a
  device-search timeout (default 30 seconds), so reducing it needs device
  availability/freshness testing before adoption.
- Target parallelism, job counts and build timing summaries address building;
  they do not eliminate these menu-discovery processes. No supported combined
  discovery query or reusable interactive `xcodebuild` query session was found
  in the installed help/manual or the Apple documentation reviewed.
- The existing package flags retain resolved versions and skip updates. Removing
  them, bypassing validation, inferring compatible destinations from `simctl`, or
  changing artifact locations is not an equivalent discovery optimization.

## Recommended implementation order

1. **Discover destinations on demand.** Present Actions once schemes arrive.
   Show an explicit unresolved destination until the user opens Destination or
   requests an action. Switching to an uncached scheme invalidates the previous
   selection and returns immediately; resolve only when needed. Reuse the
   existing four-scheme cache and preserve exact architecture/variant identity.
   From the measured stages, initial Actions would be expected near 900 ms
   instead of 1,748 ms. This is an estimate, not an implemented speedup. For a
   direct action on the default scheme it moves the destination wait later;
   browsing away from unused schemes actually avoids queries.
2. **Make discovery visibly responsive.** Use the existing screen owner and
   renderer. A busy paint alone provides feedback but does not reduce elapsed
   time or make synchronous discovery cancellable by Escape. Truly responsive
   discovery needs an invocation-owned worker with bounded output, exact process
   cleanup and cancellation, integrated with the existing input loop. No daemon,
   speculative prefetch or second keyboard loop is needed.
3. **Address repeated workflows explicitly.** Reopening currently discards all
   selection/discovery state. Keeping a workspace available across actions could
   remove repeated list/destination queries, but changes the current release-on-
   action contract. Specify revalidation and refresh behavior before adopting
   this. Cross-invocation caching needs a separate freshness decision; a TTL alone
   cannot detect device, scheme, package, configuration or Xcode changes.
4. **Then optimize Run metadata if broader measurements justify it.** Settings
   parsing launches multiple `plutil` extractions per target over the complete
   JSON document. A bounded single-conversion parser is a candidate for larger
   target graphs. In this sample its entire 54 ms cost is secondary to the
   one-second settings query. Do not guess output products to skip that query.

For implementation, first add deterministic tests that opening Actions and
browsing schemes do not query unused destinations, and that every action still
resolves an exact valid selection. Cover cancellation, failed discovery,
refresh after device changes, cache eviction, and switching back to a scheme.
Measure real PTY first-paint, scheme-change and action-ready latency separately,
then repeat native measurements on a package-heavy multi-scheme workspace and
Simulator/device destinations. Run the complete suite after product changes.

## Implemented changes and measured deltas

Implemented on-demand destinations and interactive cancellable discovery.
Actions opens after schemes load; browsing an uncached scheme clears selection
without querying destinations. A pending action requires explicit destination
selection with the action and platform-specific effects visible. The existing
four-scheme snapshot cache now remembers explicit selections separately,
including architecture and variant. Cancellation never selects a cached entry;
refresh preserves an exact surviving selection and clears a vanished one.

Interactive discovery uses the existing status view and input loop. One native
supervisor retains ownership of the provider process group until cleanup, with
two bounded nonblocking output streams and a release FIFO. Provider status is
published atomically in at most four bytes; raw payload is not written to disk.
Escape and Ctrl-C stop the owned group, reap its supervisor and restore the
screen. Noninteractive and missing-UI calls retain synchronous capture.

The native benchmark caught an intermittent completed-query stall in an early
async implementation: Xcode had exited successfully and its complete JSON was
captured, but the streams did not produce EOF. A red-first regression reproduced
this with an exited provider and a surviving writer. Completion now drains all
queued bytes after the provider exits without waiting for inherited handles to
close. The fixture retains an exact 131,072-byte tail; all 20 subsequent native
journeys completed, covering 40 queries.

The final comparison used three alternating baseline/current samples per
journey in a real 120×40 PTY. Timing starts immediately before nearest-container
discovery, with support functions already loaded, and records the shared native
screen paint. Keyboard actions follow each relevant frame. Build-request timing
ends after selection and screen restoration, before dispatch: no build ran.
Existing Xcode services and caches stayed warm. This batch is directly
comparable internally; it should not be combined with the earlier raw-command
baseline above, taken under different host conditions.

| Native PTY metric | Baseline median | Optimized median |
| --- | ---: | ---: |
| First visible feedback | 1,319 ms | 21 ms |
| First actionable Actions screen | 1,319 ms | 679 ms |
| Destination picker ready, from invocation | 1,323 ms | 1,401 ms |
| Build request ready, before dispatch | 1,320 ms | 1,488 ms |
| Cancel discovery and restore terminal | not measured | 62 ms |

Actions appears **48.5% sooner**. The complete destination/action path in this
batch added 78–168 ms of responsive capture and selection overhead. This is a
menu-responsiveness improvement, not a compilation speedup. A user who proceeds
directly to Build still needs both native queries.

A separate deterministic multi-scheme PTY fixture used a 400 ms scheme query
and a 600 ms destination query. Across three samples, initial Actions improved
1,040 → 422 ms and an uncached scheme switch improved 630 → 15 ms. Its complete
switch-and-cancel journey made zero destination queries instead of two. These
are controlled scheduling results, not native large-workspace measurements.

Ten alternating isolated full-bootstrap samples, from tracked temporary copies
with an empty home and no local initializer, measured 72.654 → 73.149 ms median.
There is no material measured shell-startup regression.

The implementation retains invocation-local freshness: reopening queries Xcode
again. Cross-action workspace retention and build-settings parser changes remain
separate follow-ups; they were not needed for the measured menu improvement.

Regression coverage includes all eight actions, actual accept labels, exact
cached selections, canceled choices, refresh removals/failures, bounded eviction,
literal scheme keys, unusual shell options, native Escape/Ctrl-C/resize, stopped
providers, unrelated-job survival, descendant cleanup, bounded failure/overflow,
and provider exit with an inherited writer. The final full suite passed
**843 tests, zero failures, in 195.2 seconds**. Syntax checks covered 222 shell
files, and the shared UI/palette passed four load orders with double sourcing.

Verification also caught and removed a cross-component private-helper call:
discovery now owns its empty collector instead of calling the private collector
of the shared view component. The architecture check and four native discovery
tests passed afterward. A subsequent suite run passed every Xcode test but saw
one intermittent failure in the unchanged worktree Enter fixture (successful
command return without changing directory). That fixture runs in an isolated
shell that never loads Xcode code. Its one immediate retry and 20 further
focused/instrumented repetitions passed. No root cause was reproduced and no
worktree behavior was changed; a duplicate resize signal is only an unconfirmed
hypothesis. This observation is retained rather than treating retries as proof
that an underlying intermittent issue cannot exist.

## Primary references

- [Apple: Building from the Command Line with Xcode FAQ](https://developer.apple.com/library/archive/technotes/tn2339/_index.html)
- [Apple: Building Swift packages or apps that use them in continuous integration workflows](https://developer.apple.com/documentation/xcode/building-swift-packages-or-apps-that-use-them-in-continuous-integration-workflows)
- Installed Xcode 27.0 beta `xcodebuild -help` and `man xcodebuild` for exact
  command modes, JSON behavior, package flags and destination timeout semantics.
