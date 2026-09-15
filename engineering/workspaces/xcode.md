# Xcode workspace

Read this contract when the task matches its route in [AGENTS.md](../../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Xcode workspace boundary](#xcode-workspace-boundary)

## Xcode workspace boundary

- `.zsh.xcode` owns both the native Xcode action workspace and Apple skill export.
  Source-time behavior remains definitions only: never probe Xcode, enumerate
  projects, start Simulator, export skills, or write files while loading the
  peer. `xcode` owns workspace and `--export-skills` modes through its one
  same-source help companion; no separate public skill-export command remains.
  Interactive export reviews captured agent destinations in the shared action
  view before staging or writing. Escape cancels. Noninteractive/dumb/missing-UI
  export retains direct execution, explicitly documented. No project discovery
  is required for export, and no exporter runs while its plan is painted.
- Bare `xcode` discovers only literal `.xcworkspace` and `.xcodeproj`
  directories while walking upward from PWD. Stop at the nearest scope, offer
  workspaces before projects there, reject symlink containers, and never scan
  descendants. Except for the owned `--export-skills` mode and help, arguments
  delegate directly to `xcodebuild` and preserve
  its status. A dumb/noninteractive bare call may print the nearest container's
  safe native list; it must not open the modal workspace.
- Xcode owns scheme, destination, build, test and settings semantics. Request
  machine-readable JSON where the CLI provides it and parse it with the system
  `plutil`; accept the documented destination listing only after validating a
  fixed platform vocabulary and literal stable identifier. Bound every retained
  provider capture (currently 256 KiB), diagnostic and item count. Enforce byte
  bounds during capture, including temporary files; never write unbounded
  provider output and check its size only after the command finishes. Retain every
  validated scheme within those bounds; an exceeded item bound fails with no
  partial catalog. No repaint, filtering, focus, scrolling or resize may invoke
  an Xcode provider.
- Use the shared full-screen renderer, screen owner, input loop, guide, focus
  language and temporary-screen cleanup. The dashboard is one shallow
  controller over Container → Scheme → Destination → Action, with configuration
  choices returning to the action dashboard. Do not add a renderer, key parser,
  persistent background watcher, workflow framework, persistent project state or new
  shortcut. Keep each digit-select Xcode page at ten rows so every visible index
  is reachable with Option plus one of 0–9; ordinary paging retains later candidates.
  Dispatch every action only after the screen is restored, and revalidate that
  the exact captured container leaf still exists, matches its project/workspace
  kind and is not a symlink immediately before execution. Test may
  start a new screen session after xcodebuild returns, using only its already
  captured result snapshot; it must never run a provider from the renderer.
  Present Actions after scheme discovery. Defer destination discovery until
  opening Destination or requesting an action with no selected destination;
  uncached scheme browsing must not start a provider. An unresolved action
  requires explicit destination selection with its pending action and relevant
  execution effects visible. Canceling that choice never grants a selection.
  Interactive discovery uses the shared status view and input loop, with one
  invocation-owned supervisor process group, bounded nonblocking streams and
  ownership-checked cleanup. Never background an untracked synchronous capture
  or launch a provider from an idle callback. Escape cancels initial discovery
  or returns to Actions from destination discovery; Ctrl-C aborts the workspace.
  Destination compatibility may reuse an LRU of at most four successful parsed
  scheme snapshots inside this controller only. Retain exact IDs, platforms and
  names, architectures and variants; never merge destinations solely by device
  ID. Preserve the complete validated destination specification through refresh,
  cached restoration, build, test, settings and launch. Keep explicitly selected
  specifications separate from successful snapshots and evict them together.
  Never cache raw output or failures. Returning to a cached scheme performs no
  provider call. **Refresh destinations** explicitly replaces the current
  snapshot while preserving an exact surviving destination specification. A
  missing refreshed selection becomes unresolved and requires an explicit new
  choice. Release every remaining entry
  on action, cancellation or workspace exit; reopening `xcode` is always fresh.
  A refresh that cannot retain its newly parsed snapshot must forget the prior
  scheme entry and fail explicitly rather than allowing stale restoration.
- Discovery is read-only coordination, though Xcode may inspect project and
  package metadata. Always disable automatic package resolution and package
  updates and require versions from `Package.resolved`. Never silently enable
  provisioning updates or skip package-plugin/macro validation. Keep these
  policy arguments centralized and cover their exact presence/absence in tests.
- Build, Rebuild, Test, Rebuild & Test, Analyze, Clean, Build & Run and Rebuild
  & Run are explicit code-execution boundaries. Project build scripts, package
  plugins, macros, tests and app code may execute. State this in the dashboard,
  README and `xcode --help`; never run an action merely to populate details.
  Native build/test output belongs in the restored terminal. An explicit
  Simulator Run may then open its scoped app-output view as described below.
  Build, Test and Build & Run use Xcode's normal incremental
  `build`/`test` actions. Do not infer artifact freshness from Git state,
  filesystem timestamps or private DerivedData metadata; Xcode owns the target
  membership, dependency graph and rebuild decision. Rebuild and **Rebuild &
  Run** are explicit slower recoveries that send ordered `clean build` actions;
  **Rebuild & Test** sends `clean test` for the exact scheme and destination.
  Never trigger these recovery actions automatically. Both test modes add
  one temporary result bundle, then use bounded `xcresulttool` summaries,
  failed-test source locations and build issues to reopen a shared result view.
  Show success and failure with the shared semantic palette, retain exact
  scheme/destination context and mode, keep the native action status, read no
  attachments or source contents, disable verbose test-diagnostic collection for
  that transient bundle, and remove it before presenting the snapshot. When
  `pbcopy` is available, the result view may offer one explicit **Copy report and
  done** candidate. Build its plain text only from the retained snapshot,
  including the native status, mode, exact test context, totals, every retained
  test/build failure, identifiers, reasons, involved files and capture
  limitations. Perform the clipboard write after screen restoration, recheck the
  captured executable, never read source files or the clipboard, and preserve a
  failing native test status even when copying succeeds or fails.
- Offer Build, Test, Build & Run and their explicit rebuild modes for every
  concrete destination reported by Xcode. Xcode owns scheme/action compatibility.
  Build incrementally, or clean then build only for explicit Rebuild & Run.
  Resolve runnable `.app` bundles with validated bundle identifiers, or native
  Mac command-line products, from bounded `xcodebuild -showBuildSettings -json`
  over at most 100 targets. Multiple runnable products require an explicit
  shared Run product selection after building; absent interactive UI fails on
  ambiguity. Revalidate the chosen product leaf after selection. Do not infer
  products or target membership through recursive filesystem search.
- Mac Run opens a new instance of the exact built app with native `open`, or
  executes a built command-line product in the restored terminal. Honor the
  captured architecture; an app launch status is not its eventual exit status.
  Physical-device Run delegates the user's explicit installation and launch to
  the selected Xcode's `devicectl`, with the exact device ID and app path/bundle
  identifier. Installation can replace the device's installed app; launch uses
  `--terminate-existing --console`. Interactive Run captures that owned native
  child's stdout/stderr through one private FIFO under a mode-0700 temporary
  directory and presents the shared bounded log reader; plain/missing-UI fallback
  retains the native foreground console. Stop restores the screen before
  forwarding termination, waits at most one second while draining, then ends an
  unresponsive child with an explicit check-the-device notice. Revalidate the
  owned job before signaling, reap it, preserve native failures, and remove the
  FIFO and directory. The interactive monitor has no app-stdin editor. This is
  an explicit native-tool device handoff,
  like user-requested Git transport, not Compozsh-owned network discovery or a
  new endpoint. Document native wired/wireless communication, persistent device
  installation, failure status and absence of installation rollback. Never
  silently pair devices, enable Developer Mode, alter signing or provisioning,
  launch another target after failure, or claim compatibility beyond the
  selected native tools. LLDB and scoped unified logging remain Simulator-only;
  shared reading, fuzzy/exclusion filtering and copying also cover device output.
- Simulator Run uses `xcrun simctl` to boot, install and launch the chosen app;
  opening the selected Xcode's Device Hub or Simulator app is part of that
  explicit action. Never choose a generic destination for a launch.
  See [destination Run evidence](../../investigations/xcode-destination-run.md) for
  native argument checks, product selection and integration-test limits.
- Simulator and physical-device Run open the full-width log reader first;
  Escape returns to Run controls without ending the run. The Run view reuses the shared picker
  with Stop, Read output, and conditional LLDB actions. Retain only the newest
  32 KiB/200 lines of combined app stdout/stderr and scoped unified logs as a
  live tail, plus bounded frozen preview and full-reader snapshots, in memory.
  Each source may retain at most 8 KiB of an unfinished line. Two private mode-0600
  FIFOs beneath a mode-0700 invocation directory in the selected Simulator's
  `data/tmp` carry output; they are never log files. Resolve that exact device's
  data root with a bounded native capture, validate the root and temporary
  child, and keep the host FIFO path separate from the Simulator-relative
  launch path. Cleanup uses the captured host root. Explicit Run replaces an
  already-running instance of that selected bundle with
  `--terminate-running-process`, and sets `SIMCTL_CHILD_NSUnbufferedIO=YES` only
  for launch. App-controlled buffering can still occur. Read at most 32 KiB per
  shared idle turn, fairly across both sources; never read during paint or
  resize, and keep input priority. Freeze displayed text while reading or in
  the guide; returning to Run actions follows the newest tail in its preview.
  Disclose a failed source while allowing the other to continue. No source-time
  work, persistent worker, or new key map.
- Read output composes a reader-only shared document view: full width, wrapped
  up to the shared 20,000-row bound, with no selectable or numbered log rows.
  Reuse shared case-insensitive fuzzy character matching and opt into the shared
  Exclude contains field: one case-insensitive literal phrase. Preserve source
  order and duplicates instead of ranking log lines. Both fields, their editing
  focus, and the selected severity view survive Options, Copy and reopen;
  counts refer to source lines, not wrapped rows. Follow the latest retained
  tail automatically by default, preserving both filters as output
  arrives. Scroll upward to pause publication; reaching the bottom or Follow
  latest resumes. Retain the mode, filter and paused snapshot/semantic reading
  bookmark through Options, Return to Run, reopen, and Copy. Capture continues
  in the Run owner. Options and the guide hold displayed text and raw copy
  scope; returning resumes the prior mode. Reuse the shared opt-in document
  following capability, with no mandatory refresh command or new key map.
  Unchanged raw output must not trigger formatting or repainting; capture
  status and limit changes still need visible updates. Enter opens options;
  Escape/Ctrl-G returns to Run, and Options Escape
  returns to the reader. Reader-only controls must not expose a phantom list
  focus, result count or digit action. Reuse the shared key map and guide.
- Format recognized native compact records using a bounded pure text helper:
  compact time/severity/scope header, separate message body, and spacing
  between entries. Keep textual severity and existing semantic palette roles;
  unrecognized lines stay plain, and message words never infer severity.
  Summarize recognized Error/Fault records across the retained snapshot, including
  hidden records. An explicit Errors and faults view intersects the two filters;
  Show all levels includes plain output again. These are log counts, never app
  health, process-exit or delivery-completeness claims.
  See [shared log-monitor evidence](../../investigations/xcode-log-monitor.md) for
  native terminal, device-console lifecycle and bounded matching checks.
  Matching/counts/copying use the original source lines, including omitted
  display metadata. Keep formatted rows and regex scratch local, sanitization
  in the shared renderer, and wrapping under its existing document bound.
- Explicit Copy all captured logs, Copy filtered logs, or reader Ctrl-Y freezes
  the complete matching raw lines from the displayed snapshot, including
  offscreen content, without UI labels or wrapping. Offer copying only for
  nonempty matching text and a captured clipboard capability. Options copying
  uses the display captured when Options opened, even as new output arrives;
  direct reader copy uses the currently displayed capture. Revalidate that
  executable and write only after screen restoration; never read the
  clipboard. Reopen Run with visible success/failure feedback and preserve the
  reader bookmark and running app. Clipboard failure must retain a nonzero run
  status even after a later successful action. Copied text outlives the run
  under operating-system/user control and may retain native private payloads;
  keep that boundary explicit in public privacy documentation.
- The Run unified-log observer is scoped to the exact selected Simulator and
  canonical installed `CFBundleExecutable` path. Start the device's native
  `log stream --level debug --style compact --color none` through
  `simctl spawn`, with an exact `processImagePath` predicate applied before
  delivery; never collect a broad stream and filter it afterward. Start the
  observer before app launch and wait only a bounded time for its native
  readiness header. Set `LOGRC=/dev/null` only for that log child so personal
  `.logrc` rules cannot broaden capture. Include framework records emitted
  inside the app; exclude helpers/extensions with different executable paths.
  Disclose that another launch of the same exact executable can match, native
  records can drop, startup capture can race, duplicate messages can reach both
  sources, and merged read order is not guaranteed timestamp order. Never
  enable private-data logging or alter native privacy behavior; do not promise
  redaction, because native Simulator defaults can expose private payloads.
  The observer belongs only to this run: stop and reap it before LLDB and in
  normal/error cleanup. There is no persistent logging configuration or daemon.
- Resolve the Run PID solely from simctl's separate launch response, never app
  output. Revalidate its observed user/start time/executable before LLDB and
  before stopping the exact Simulator bundle. Disclose non-atomic exit races.
  Escape/Stop in Run and handled errors stop the run after screen restoration.
  Escape in its full log reader returns to Run without stopping the app. LLDB
  receives the restored terminal with automatic init and symbol-script loading
  disabled; one scoped native child drains/discards stdout/stderr until LLDB
  exits, then cleanup stops the run and reaps the drainer. Never change signing, use
  sudo, attach by a guessed name, or silently launch a different app. A closed
  output stream is not proof of process exit. Preserve launch/debugger failure
  status and disclose missing identity, failed stop, and crash cleanup limits.
- Test discovery order, spaces in literal paths, complete multi-page scheme
  catalogs, bounded/failed JSON, hostile destination text,
  no-scheme/no-destination states, argument delegation, noninteractive fallback,
  cancellation, resize cleanup, ten-row digit pages, container replacement,
  failed refresh eviction, exact incremental/rebuild action arrays and Mac/device/Simulator
  dispatch with PATH-shadowed first-party command spies. Cover hostile literal
  action arguments, result-bundle symlink rejection, destination provider-call
  counts, exact cache restoration, four-scheme eviction, explicit refresh, and
  successful test totals, assertion and build-stage failures, source locations,
  semantic result colors, bounded report contents, conditional clipboard
  affordance, post-screen copying, native output/status preservation and
  result-bundle cleanup. Run tests must cover the exact installed-executable
  log predicate, child environment isolation, bounded observer readiness,
  fair source draining and partial-line bounds, independent source failure,
  replacement launch, and observer stop/reap before debugger handoff and on
  cancellation/error. Cover full-width reader geometry, source anchors after
  resize/reopen, fuzzy source-line matching, literal exclusion/counts, live no-match recovery,
  scroll pause/resume, stable guide/Options copying, quiet callbacks,
  independent action/reader bookmarks, complete matching
  clipboard payloads, post-screen copying, and visible/sticky clipboard failure.
  Real Xcode/Simulator checks are optional host
  integration tests and must not read private project data or mutate a user's
  active project.
