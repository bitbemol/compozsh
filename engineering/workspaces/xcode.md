# Xcode workspace

`.zsh.xcode` owns the native Xcode action workspace and Apple skill export.
`xcode` owns both modes (`xcode`, `xcode --export-skills`) through one
same-source help companion; any other arguments delegate directly to
`xcodebuild` and keep its status.

## Essentials

- **Nothing at load time.** Source time defines functions only: never probe
  Xcode, enumerate projects, start Simulator, export skills or write files.
- **Xcode owns Xcode semantics.** Schemes, destinations, build/test/settings
  behavior, compatibility, dependency graphs and rebuild decisions come from
  Xcode's own tools; Compozsh never infers them from Git, timestamps or
  DerivedData.
- **Actions are explicit execution boundaries.** Build, Rebuild, Test,
  Analyze, Clean, Run and their variants may execute project scripts, plugins,
  macros, tests and app code.
  They run only when chosen, after screen restoration, against a revalidated
  container — never to populate details.
- **Bounded and provider-free interaction.** Every provider capture, item
  count and diagnostic is bounded during capture. Repaint, filtering, focus,
  scrolling and resize never invoke a provider.
- **Native handoffs, disclosed.** Device installation/launch and log streaming
  are explicit native-tool handoffs, like a user's `git push`; they are not
  Compozsh-owned network discovery. Logging privacy settings are never
  changed.

## Entry and discovery

- Bare `xcode` walks upward from `PWD` for literal `.xcworkspace` and
  `.xcodeproj` directories, stops at the nearest scope, offers workspaces
  before projects there, rejects symlink containers and never scans
  descendants. A dumb or noninteractive bare call may print the nearest
  container's safe native list instead of opening the workspace.
- Request machine-readable JSON where the CLI offers it and parse it with the
  system `plutil`; accept the documented destination listing only after
  validating a fixed platform vocabulary and a literal stable identifier.
- Bound every retained capture (currently 256 KiB; Run's build settings
  5 MiB, see [Run targets](#run-targets)), diagnostic and item count,
  enforcing byte bounds during capture — including temporary files — rather
  than checking size afterward. Keep every validated scheme within bounds; an
  exceeded scheme bound fails with no partial catalog, while the destination
  list keeps its first 100 validated entries.
- Discovery is read-only coordination, though Xcode may inspect project and
  package metadata. Always disable automatic package resolution and updates and
  require versions from `Package.resolved`. Never silently enable provisioning
  updates or skip package-plugin/macro validation. Keep these policy arguments
  centralized and test their exact presence and absence.

## Dashboard

- One shallow controller over Container → Scheme → Destination → Action, using
  the shared renderer, screen owner, input loop, guide, focus language and
  cleanup; configuration choices return to the action dashboard. No new
  renderer, key parser, watcher, workflow framework, persistent project state
  or shortcut.
- Digit-select pages hold ten rows so every visible index is reachable with
  Option plus 0–9; ordinary paging reaches later candidates.
- Present Actions after scheme discovery. Destination discovery waits until
  Destination opens or an action needs one; browsing uncached schemes starts
  no provider. An unresolved action requires explicit destination selection
  with the pending action and its execution effects visible; canceling grants
  nothing.
- Interactive discovery uses the shared status view and input loop with one
  invocation-owned supervisor process group, bounded nonblocking streams and
  ownership-checked cleanup. Never background an untracked synchronous capture
  or launch a provider from an idle callback. Escape cancels initial discovery
  or returns from destination discovery; Ctrl-C aborts.
- Dispatch every action after screen restoration, first revalidating that the
  exact captured container leaf still exists, matches its project/workspace
  kind and isn't a symlink. Test may start a new screen session afterward
  using only its captured result snapshot.

## Destinations

- Destination compatibility may reuse an LRU of at most four successful parsed
  scheme snapshots inside the controller. Keep exact IDs, platforms, names,
  architectures and variants; never merge destinations by device ID alone.
- Preserve the complete validated destination specification through refresh,
  cached restoration, build, test, settings and launch. Explicit selections
  are kept separately from snapshots and evicted with them. Never cache raw
  output or failures; returning to a cached scheme makes no provider call.
- **Refresh destinations** replaces the current snapshot, keeping an exact
  surviving selection; a missing one becomes unresolved and needs a new
  choice. A refresh that can't retain its new snapshot forgets the prior entry
  and fails explicitly rather than allowing stale restoration.
- Release all entries on action, cancellation or exit; reopening `xcode` is
  always fresh.

## Actions

- Build, Rebuild, Test, Rebuild & Test, Analyze, Clean, Build & Run and
  Rebuild & Run are offered for every concrete destination Xcode reports; the
  code-execution boundary is stated in the dashboard, README and
  `xcode --help`. Native build/test output goes to the restored terminal.
- Build, Test and Build & Run use Xcode's incremental `build`/`test`. Rebuild
  and Rebuild & Run send ordered `clean build`; Rebuild & Test sends
  `clean test` for the exact scheme and destination. Recovery actions are
  never triggered automatically.
- Both test modes add one temporary result bundle, then reopen a shared result
  view from bounded `xcresulttool` summaries, failed-test source locations and
  build issues: semantic success/failure colors, exact scheme/destination and
  mode, the native status preserved. Read no attachments or source contents,
  disable verbose test-diagnostic collection for that bundle, and remove it
  before presenting the snapshot.
- With `pbcopy` available, the result view may offer one **Copy report and
  done** candidate: plain text built only from the snapshot (native status,
  mode, test context, totals, every retained failure with identifiers,
  reasons, files and capture limits). Write it after screen restoration,
  recheck the captured executable, never read source files or the clipboard,
  and keep a failing test status whether or not copying succeeds.
- The view and the report are two projections of one pure model over the
  retained snapshot, so they agree on totals, failures and files; each
  involved source location gets its own line.

## Run targets

- Resolve runnable `.app` bundles (with validated bundle identifiers) or
  native Mac command-line products from bounded
  `xcodebuild -showBuildSettings -json` over at most 100 targets. Xcode
  reports about 42 KiB of settings per target, so this one capture has its own
  5 MiB bound (or the user limit when larger), held in invocation memory and
  released on return; beyond it, Run fails with guidance that names the bound
  and `ZSH_XCODE_CAPTURE_MAX_BYTES`. Several
  runnable products require an explicit shared Run product choice after
  building; Escape there launches nothing and returns 1, the shared cancel
  status ([task semantics](../full-screen.md#task-semantics)), and without
  interactive UI, ambiguity fails. Revalidate the chosen leaf. Never infer
  products by recursive filesystem search.
- **Mac:** open a new instance of the exact built app with native `open`, or
  run a built command-line product in the restored terminal, honoring the
  captured architecture. An app launch status is not its exit status.
- **Physical device:** the selected Xcode's `devicectl` installs and launches
  with the exact device ID and app path/bundle identifier
  (`--terminate-existing --console`); installation can replace the device's
  app. Interactive Run captures the owned child's output through one private
  FIFO in a mode-0700 directory into the shared log reader; plain fallback
  keeps the native foreground console. Stop restores the screen, forwards
  termination, drains for at most one second, then ends an unresponsive child
  with a check-the-device notice; revalidate the job before signaling, reap
  it, keep native failures, remove FIFO and directory. No app-stdin editor.
  Document wired/wireless communication, persistent installation, failure
  status and the absence of rollback. Never silently pair devices, enable
  Developer Mode, change signing or provisioning, launch another target after
  failure, or claim compatibility beyond the selected tools. LLDB and unified
  logging stay Simulator-only; reading, filtering and copying cover device
  output too.
- **Simulator:** `xcrun simctl` boots, installs and launches the chosen app;
  opening the selected Xcode's Device Hub or Simulator app is part of that
  action. Never choose a generic destination for a launch. Evidence:
  [destination Run](../../investigations/xcode-destination-run.md).

## Run view and logs

- Simulator and device Run open the full-width log reader first; Escape
  returns to Run controls (Stop, Read output, conditional LLDB) without ending
  the run.
- Keep only the newest 32 KiB / 200 lines of combined stdout/stderr and scoped
  unified logs as a live tail, plus bounded frozen preview and reader
  snapshots, in memory; each source keeps at most 8 KiB of an unfinished line.
- Simulator output travels through two private mode-0600 FIFOs under a
  mode-0700 invocation directory in the selected Simulator's `data/tmp` —
  never log files. Resolve that device's data root with a bounded capture,
  validate root and child, keep host and Simulator-relative paths separate,
  and clean up via the captured host root. Run replaces a running instance of
  the selected bundle (`--terminate-running-process`) and sets
  `SIMCTL_CHILD_NSUnbufferedIO=YES` only for the launch and its log-stream
  child; app buffering can still occur.
- Read at most 32 KiB per idle turn, fairly across sources, never during paint
  or resize, with input priority. Freeze displayed text while reading or in
  the guide. A failed source is disclosed while the other continues. No
  source-time work, persistent worker or new key map.
- **Read output** is a reader-only shared document view: full width, wrapped
  up to the shared 20,000-row bound, no selectable or numbered rows. It uses
  shared fuzzy character matching plus the literal Exclude field, keeps source
  order and duplicates, and counts source lines rather than wrapped rows. Both
  fields, their focus and the severity view survive Options, Copy and reopen.
  It follows the latest tail by default; scrolling up pauses publication and
  reaching the bottom or Follow latest resumes, with mode, filters and paused
  bookmark kept across Options, Run and reopen. Unchanged output triggers no
  reformat or repaint, but status and limit changes still update. Enter opens
  options; Escape/Ctrl-G returns to Run; Options Escape returns to the reader.
  No phantom list focus, count or digit action.
- A bounded pure helper formats recognized native compact records (compact
  time/severity/scope header, separate body, spacing); unrecognized lines stay
  plain and message words never imply severity. Error/Fault counts cover the
  whole snapshot including hidden records; **Errors and faults** intersects
  with the filters; **Show all levels** restores plain output. These are log
  counts, not app health or delivery-completeness claims. Matching, counts and
  copying use original source lines. Evidence:
  [log monitor](../../investigations/xcode-log-monitor.md).
- Copy all, Copy filtered or reader Ctrl-Y freezes the complete matching raw
  lines of the displayed snapshot (including offscreen content, without UI
  labels or wrapping), offered only for nonempty text and a captured clipboard
  capability. Options copies the display captured when Options opened. Write
  after screen restoration, never read the clipboard, reopen Run with visible
  feedback, keep the reader bookmark and running app, and keep a nonzero
  status after clipboard failure. Copied text outlives the run under OS/user
  control and may hold native private payloads — disclose that in public
  privacy docs.

## Unified-log observer

Scoped to the selected Simulator and the canonical installed
`CFBundleExecutable` path: native
`log stream --level debug --style compact --color none` through `simctl spawn` with an exact `processImagePath`
predicate applied before delivery — never a broad stream filtered afterward.
Start it before launch, wait a bounded time for its readiness header, and set
`LOGRC=/dev/null` for that child only so personal `.logrc` rules can't broaden
capture. Framework records inside the app are included; helpers and
extensions with other executable paths are not. Disclose that another launch
of the same executable can match, records can drop, startup can race,
duplicates can reach both sources and merged order isn't timestamp order.
Never enable private-data logging or promise redaction (Simulator defaults can
expose private payloads). The observer belongs to this run only: stop and reap
it before LLDB and in all cleanup. No persistent logging configuration.

## LLDB and stopping

Resolve the Run PID only from simctl's launch response, never app output, and
revalidate user, start time and executable before LLDB and before stopping the
exact bundle; disclose non-atomic exit races. Escape/Stop in Run and handled
errors stop the run after restoration. LLDB gets the restored terminal with
automatic init and symbol-script loading disabled; one scoped child drains
app output until LLDB exits, then cleanup stops the run and reaps the drainer.
Never change signing, use `sudo`, attach by a guessed name or launch a
different app. A closed output stream is not proof of exit. Preserve
launch/debugger failure status and disclose missing identity, failed stop and
crash-cleanup limits.

Signal an owned child (discovery supervisor, device console, log observer or
drainer) only after revalidating its job, and reap it through the shared job
reaper: retire only its own job record and preserve unrelated jobs — never an
unqualified `jobs`/`wait` sweep (see the
[job-lifecycle limitation](../../SECURITY.md#job-lifecycle)). The discovery
supervisor's process group, the device console and the log observer stop
through one grace-period helper: TERM, CONT for a suspended child (always for
the group), at most one second of caller-specific draining, KILL, reap.

## Apple skill export

`xcode --export-skills` runs `xcrun agent skills export` for detected coding
agents' skill directories. Interactive export reviews the captured
destinations in the shared action view before staging or writing; Escape
cancels and no exporter runs while the plan is painted. Noninteractive, dumb
or missing-UI export runs directly, as documented. Export needs no project
discovery.

## Testing

Cover discovery order, spaces in paths, multi-page scheme catalogs,
bounded/failed JSON, hostile destination text, no-scheme/no-destination
states, argument delegation, noninteractive fallback, cancellation, resize
cleanup, ten-row digit pages, container replacement, failed-refresh eviction,
exact incremental/rebuild action arrays and Mac/device/Simulator dispatch with
`PATH`-shadowed first-party spies. Also: hostile action arguments,
result-bundle symlink rejection, destination provider-call counts, cache
restoration, four-scheme eviction, explicit refresh, test totals, assertion
and build failures, source locations, result colors, bounded reports,
conditional clipboard affordance, post-screen copying, status preservation,
bundle cleanup; for Run, the exact log predicate, child environment isolation,
bounded readiness, fair draining and partial-line bounds, independent source
failure, replacement launch, observer stop/reap before LLDB and on error,
bounded stops of suspended or TERM-ignoring children (with the device
notice), reader geometry, anchors after resize/reopen, fuzzy and exclusion matching,
no-match recovery, scroll pause/resume, stable Options copying, quiet
callbacks, independent bookmarks and sticky clipboard failure. Real
Xcode/Simulator checks are optional host integration tests and never read
private project data or mutate the user's active project.

## Retired decisions

- A separate public skill-export command; `xcode --export-skills` is the
  only entry.
