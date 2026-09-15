# Git workspaces

Read this contract when the task matches its route in [AGENTS.md](../../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Git worktree workspace boundary](#git-worktree-workspace-boundary)
- [Git review workspace boundary](#git-review-workspace-boundary)

## Git worktree workspace boundary

- `g --worktree` is the sole worktree entry point. The optional
  `.zsh.git-worktree` peer owns capture, temporary choices and actions; `g`
  retains its recent-branch default and transparent ordinary Git arguments.
- Reuse the navigation fuzzy collector and shared UI peer, text entry, keys,
  guide, focus and screen lifecycle. Worktree options consume the selected
  registered path. Creation composes branch, captured start commit and a new
  folder into one explicit action after terminal restoration. Parent browsing
  uses the existing hierarchy keys; Back preserves caller bookmarks.
- Keep Create, Enter, Move / rename, Remove and Refresh visible in the main
  menu. Each operation specializes the captured worktree catalog; contextual
  options are shortcuts to the same flows, never their only entry points.
  Move edits the parent/folder name, preserves files and branch, and delegates
  to native Git on the same filesystem after reviewing exact old/new paths.
- Capture registered worktrees from NUL-delimited Git porcelain and all local
  branches within explicit bounds, rather than using recent checkout history
  as an eligibility catalog. Never treat a truncated capture as a complete
  safety check. Filtering and painting read no providers. Refresh is explicit.
- Keep Git transport, lazy fetches, hooks, fsmonitor, automatic maintenance and
  submodule recursion disabled. Creation/removal refuse configured checkout
  filters and submodule trees. Register new worktrees without checkout, then
  check their effective configuration before materializing files; conditional
  includes can differ from the source checkout. Revalidate exact repository/directory identities,
  branch/commit and destination after cleanup. Never evaluate command previews.
- Removal keeps the branch, refuses main/current/locked/missing/detached targets
  and active Git operations, and checks ignored files as well as tracked and
  untracked changes. Sparse/unmerged/assume-unchanged indexes cannot establish
  safety. Never force, auto-stash, reset branches or recursively delete failed
  creation residue. Disclose concurrent-writer races and partial failures.
- Keep full help in the same-source `g` companion. Document persistent native
  Git/checkout effects, local data reads, refusal policies and recovery in
  README and SECURITY together. Test synthetic repositories and real ZLE
  journeys, including hostile literal values and post-cleanup dispatch.

## Git review workspace boundary

- `.zsh.git-review` owns bounded Git providers and review controllers. Its
  source-time work is definitions only; navigation detects it at invocation.
  No new public command, registration table, loader phase or key parser.
  Disabling the peer preserves ordinary `g` switch/copy and Git delegation.
- `.zsh.git-syntax` is an optional, order-independent token provider over the
  selected captured document. It has no public command or startup probe.
  `support/git-syntax.vim` is a shipped adapter asset, not a shell add-on; both
  installation modes must include it. Keep this boundary independent of Vim
  user settings and of the shell's command-line syntax classifier.
- Code syntax is lexical snapshot metadata. Analyze old/new sides separately
  and reset at omitted source gaps; label fragments honestly. Never fetch
  additional Git objects/files just to color a focused diff. Retain original
  document text and source anchors verbatim. Unsupported/missing/failed/limited
  syntax falls back visibly to the same readable diff, never a blank document.
- The syntax child uses only `/usr/bin/vim`, an empty environment with explicit
  PATH/UTF-8 locale, disabled vimrc/gvimrc/viminfo/modelines/plugins/swap/undo,
  and a system-only runtime path. Enable only reviewed OS syntax definitions:
  initially Swift, Zsh, shell, JSON and Python. No filetype detection, repository
  paths, source execution, user runtime scripts, HTML export or ANSI extraction.
  Feed captured source through private mode-600 FIFOs: Zsh 5.9 here-strings
  create temporary files, so `<<<` is not a no-disk transport. Return a
  versioned, request-ID-framed and fully validated protocol of numeric
  character spans and fixed semantic roles. No source temp files.
  Treat this as configuration hardening, never an OS security sandbox.
  Reference: [Zsh 5.9 here-string implementation](https://github.com/zsh-users/zsh/blob/zsh-5.9/Src/exec.c#L4383-L4406).
- Bound syntax independently: 64 KiB input, 3,000 document rows, 2,048 source
  characters per line, 4,096 spans and 128 KiB output. The child has an 800 ms
  analysis guard and its asynchronous parent request has a one-second liveness
  deadline. These are failure bounds for Vim, not keyboard, Git or rendering
  budgets; the input loop never waits for either deadline. A document workspace
  starts exactly one system-Vim child on entry, retains at most one nofile
  buffer per allowlisted language, and reuses it only for that screen session.
  Never create a daemon, persistent cache, neighboring-file prediction or a
  queue of Vim processes. Always close descriptors and kill/reap the owned
  child and retire its owned completed job record. Never use an unqualified
  jobs/wait/disown sweep or detach a live child to hide its record. Preserve
  caller options and unrelated live/stopped jobs; prompt capture only observes
  running/suspended job entries, never consumes completion notifications.
  Native notification timing has the explicitly documented
  [job-lifecycle limitation](../../SECURITY.md#job-lifecycle).
  Syntax acquisition is passive and pane-focus independent. After layout
  publishes the exact source viewport, an input-idle callback schedules one
  bounded multi-page window around it: normally three visible source spans on
  each side, clamped to 256 guard rows and reduced when the byte bound requires
  it. Refill two visible spans before an interior edge while the installed
  highlighted window still covers the reader. Provider
  startup, request completion and response parsing never block the input loop.
  Assign each request a monotonically increasing generation; permit exactly one
  in-flight request, keep no process queue, and let only the generation that
  still matches the current document and viewport publish. Discard stale
  responses before they touch caches or render state, then schedule the latest
  desired viewport. Use the explicit stable loading surface only when no
  installed syntax window covers the current reader. During same-document
  read-ahead, retain the existing colored frame until its complete replacement
  validates; a speculative failure must not erase valid coverage. Never paint
  plain code and fill its colors later. A missing, invalid or timed-out response
  retires that child request
  without poisoning other documents or the whole screen session. Retry the
  current settled viewport once; only a second transient failure for the same
  captured document window becomes an explicit plain fallback. Deterministic
  unsupported, size and locale outcomes may become plain immediately. Include
  the capture-snapshot epoch in publication identity so a refresh cannot accept
  an older response after numeric indexes are reused.
  Cache one bounded syntax window with each of the four raw snapshot keys,
  invalidate it with its snapshot on refresh, and release descriptors, FIFOs,
  child, buffers and caches on workspace exit. Measure resident request,
  validation, render and paint costs separately.
- Diff backgrounds and lexical foregrounds are distinct layers. Green/red
  backgrounds identify additions/removals, with +/- for non-color recognition.
  `ZSH_HIGHLIGHT_STYLES[review-*]` owns shared customizable colors; token spans
  preserve their row background, while navigator selection stays independent.
  Map raw character spans through tab/control sanitization and cell-aware
  wrapping before native ZLE highlighting. Do not embed escapes in document
  text. Test Unicode, wraps, empty tokens, missing grammar, size/time limits,
  cancellation, hostile config/modelines, cache/refresh and native ZLE cleanup.
  Apple's OS updates may change grammar coverage; do not promise automatic
  support for every language or make a beta Vim version a requirement.
- Ctrl-X on Branches selects **current working changes**, **selected branch
  commits**, or **Compare branches or commits**. `g --review` opens the same choices for
  the current checkout. Distinguish their scopes explicitly. Commits open a file-and-diff
  document workspace; working changes opens that workspace directly.
  Resolve a branch tip once to a full hex object ID and retain first-parent
  IDs for stable commit review. A root commit compares with the empty tree.
  Disable replacement refs so captured IDs refer to literal objects.
- Revision comparisons use the existing document workspace. Setup reads
  Compare (To) against Against (From); both choices are explicitly editable.
  All differences compares From → To; Changes since common ancestor compares
  their unique local merge base → To. No inferred branch of origin or fixed branch name. Accept only
  explicit local branch/tag/remote-tracking names, HEAD, or unambiguous commit
  IDs; reject ambiguity, revision expressions and ranges. Capture at most
  1,000 refs/256 KiB, counting excluded refs toward discovery, and retain typed
  input as literal text until submission. Ref selection accepts the best match;
  literal entry retains a stable second slot, first when no refs match. Resolve full IDs once, expose the
  actual endpoints in the guide, and retain them on Ctrl-R. Re-selecting a ref
  explicitly acquires its newer tip. Missing objects, absent ancestry or
  multiple merge bases never change the method silently. Setup and direct
  `g --review [--merge-base] A B` share the same providers and reader; Back
  restores setup or exits the direct entry. No checkout, index mutation, fetch
  or persistent comparison state. Design evidence:
  [General Git comparison](../../investigations/git-comparison-design.md).
- Review is read-only. No stage/discard/commit/checkout, clipboard or app
  action is dispatched from these views. The main branch picker retains its
  original actions after terminal cleanup. Do not add mutation shortcuts
  without a separately authorized design and behavioral tests.
- Use the shared screen owner, collector, renderer, semantic palette, busy
  painter and input loop. A fixed shallow view nesting scopes snapshots and
  list bookmarks; no general workflow engine. Escape restores list query,
  selection, viewport and focus. Resize never calls Git.
- File selection and document inspection have separate service paths. The
  shared input loop applies and paints every complete navigation sequence
  immediately; when selection outruns the loaded document, the reader shows a
  stable loading surface with matching geometry. Reset a short preview-settlement
  window after each further navigation key, then return exactly the latest exact
  target to the controller after input is quiet. Only the controller may capture
  and parse that target's diff outside the input loop. This is coalescing of
  expensive preview work, not input debouncing: never flush, discard or infer
  release of repeated terminal keys. Every complete sequence is user intent,
  and Terminal.app supplies no key-up event. Keep the list-only selection/paint
  path comfortably below the observed repeat cadence. Optional provider work
  belongs in a latest-request-wins input-idle operation, never behind an extra
  focus step merely to hide latency. Test a buffered native-PTY arrow burst and
  assert that it loads only its initial and final documents, then that the next
  independent key applies to the final selection with no unread movement tail.
  Evidence and portability
  notes: [Git review key-repeat latency](../../investigations/git-review-key-repeat-latency.md).
  Refinement can select another file and request its diff; filtering the list
  itself remains provider-free. Scrolling, resize and guide never capture Git;
  scrolling may update the syntax viewport request without blocking input.
  Retain four raw file/context snapshots (at most 1 MiB) for this workspace,
  with per-file reading offsets. A loading placeholder must not overwrite a
  saved reading position. Release captures/bookmarks on workspace exit.
  Right discloses file navigator → focused diff → full-file context; Left
  reverses the sequence. At either boundary the arrow is inert. Untracked
  previews and metadata/notices have one reading level. Ctrl-R refreshes the
  file workspace. Ctrl-X opens View options (All files, Tree, Jump to ancestor,
  Change atlas) where that capability is present; an atlas child reader does
  not recursively offer these options.
  Tab/Shift-Tab and Ctrl-E/B change only pane focus and preserve context mode;
  Right from the navigator always enters focused diff. The shared loop returns
  explicit disclosure/refresh requests; only the controller captures their data.
  Start focused with three context lines around each hunk. Context mode remains
  until another disclosure changes it; changing it preserves each file's source
  anchor rather than reusing a visual offset from a differently sized document.
  The shared UI peer maps wrapped rows to logical document lines; Git owns
  old/new coordinates.
  Anchor the first visible code line, resolving a hunk header forward and a
  trailing notice backward. Deletions use old-side coordinates; context and
  additions use new-side coordinates. Collapse into omitted unchanged code
  seeks the nearest retained same-side line; ties prefer earlier context.
  Report a nearest-context adjustment, retain existing capture limits and their
  notices, and reset to the notice when no code remains. Refresh follows the
  same anchor rule. Same-mode selection preserves the visual position. Never
  claim content tracking through concurrent edits. Test wrapped lines, gaps,
  deleted/new files, truncation, cache visits and native mode-switch journeys.
  Refresh rechecks Git filter-safety configuration, recaptures the file list,
  and reloads only the selected diff eagerly, outside the input loop. Manual
  Ctrl-R does this synchronously; Working changes also performs it through the
  bounded automatic-refresh path below. Keep the
  filter and identify the selection by literal path AND change kind, then find
  its new filtered rank; numeric IDs are valid only within one observation.
  Retain pane focus, context mode and source anchor for a surviving selection.
  Manual refresh may explain a selection that left the filtered results and
  focus the first match in the file list, in focused mode. Empty lists remain
  refreshable.
  Invalidate every raw/token/context cache and other-file reading bookmark on
  successful refresh; never let cached full context resurrect an older diff.
  On list/configuration failure, retain the previous observation with a retry
  status; propagate cancellation. Failed safety preparation must block uncached
  diff reads until retry, while allowing already captured documents. Keep newly
  validated filter overrides even if the following list read fails.
  Commit-file refresh retains immutable IDs.
  Ctrl-X → Change atlas may navigate to a map derived solely from the captured list.
  Keep original numeric file/change-kind identities beneath directory-prefix
  grouping. Expose source bounds and partial notices; bars count entries and
  must not imply content analysis. Child folders and file readers preserve Back
  bookmarks, and returning to review preserves its filter/focus/source anchor.
  Stop pending automatic-refresh work while this child workspace is open;
  resume its schedule only after return. Read selected files through existing
  bounded safe providers, retaining commit/comparison IDs; never discover child
  paths or bulk-read contents to paint the atlas.
  Working changes starts automatic refresh unless the initializer set
  `ZSH_GIT_REVIEW_AUTO_REFRESH=0`. Ctrl-A pauses or resumes it for only the
  current review screen; Ctrl-R checks immediately and resumes after an
  automatic failure, while an intentional pause remains paused after manual
  success or failure. Commit and comparison workspaces remain immutable-ID
  snapshots and refresh only on Ctrl-R; reopening branch history discovers new
  commits. Show separate relative ages for the last completed local check and
  the last published snapshot, so an unchanged automatic check never implies
  a snapshot update.
  Automatic checks are input-idle and keep at most one owned worker/provider
  pair in flight. Use a private mode-0700 invocation directory, mode-0600 FIFO,
  bounded in-memory provider streams, a framed literal-data
  protocol and the existing 1 MiB snapshot cap. Start no daemon, hook or
  persistent watcher/cache. The worker performs only the same bounded,
  transport-disabled local status and selected-diff reads as manual refresh.
  The worker must own the exact Git provider PID in memory so pause, manual
  refresh, timeout and screen cleanup terminate and reap the provider without
  signalling a parent-visible handoff PID. Pace checks
  no faster than two seconds and at least four times the capture duration
  measured inside the worker, capped at thirty seconds. Give one check a
  screen-session thirty-second deadline that does not depend on ordinary
  picker-idle callbacks or an empty terminal-input queue. Include final result
  delivery in that deadline: use nonblocking writes, retain partial-write counts,
  and keep cancellation responsive when the response pipe is full. A failed or timed-out
  automatic check retains the old
  observation, pauses further checks and exposes Ctrl-R as retry.
  Parse and validate a complete worker result before publishing it. Publish a
  changed snapshot with one repaint and no busy/blank intermediate frame,
  preserving filter, exact path and change kind, filtered rank, viewport slot,
  pane focus, context mode and semantic source anchor. If that target disappears
  or leaves the active filter while the reader is focused, retain the old reader,
  show `update ready`, and publish only when focus returns to the file list; do
  not move focus automatically. A disclosure change invalidates a pending diff
  candidate and waits for the next normally paced check. Guide, resize,
  scrolling and filtering remain
  provider-free, though ordinary input-idle time can make a due automatic check.
  Working-file lists and later diffs are
  separate observations, not an atomic transaction. Failed reads must be
  distinguished from successful empty snapshots. Preserve abort propagation.
- Git invocations disable optional index writes, fsmonitor, hooks, lazy fetch
  and network protocols, external diffs and textconv. Discover configured
  clean/process filter names and override them to inert values per invocation;
  disable required-filter enforcement too. Never change repository/global
  configuration. Refuse a capped/failed filter-name discovery and any driver
  containing `=`, which Git's `-c key=value` form cannot address unambiguously;
  bound the generated override argv to 4,096 entries in both manual and
  automatic paths.
  Explain the
  unfiltered comparison in help. These measures are not an OS sandbox.
  References: [Git diff](https://git-scm.com/docs/git-diff),
  [Git status](https://git-scm.com/docs/git-status),
  [Git environment](https://git-scm.com/docs/git).
- Parse NUL-delimited paths with literal pathspec semantics; validate full
  commit IDs before treating them as revisions. Reject escaping paths and
  special working files; do not follow replaced parents outside the worktree.
  Selected untracked regular text files use the same numbered reader as
  all-additions patches in both context modes. Prefix every source line so
  header-like text stays inert. Modes share one snapshot/cache key; refresh
  invalidates that same key. Read only on selection/refresh, without execution,
  staging, Git filters, directory scans or caller-directory/hook changes.
  Use native no-follow, nonblocking open and descriptor stat to reject symlink
  and special-file replacements; pin and validate a physical parent in a
  subshell. Bound bytes across short reads, preserve trailing newlines, and
  distinguish read failures from empty files. A NUL in the captured prefix
  yields a binary notice; do not claim universal binary detection. Keep
  symlinks/folder entries as notices, missing/unsafe/read failures unavailable,
  and conflicts as notices. Test replacement races and mode/refresh reuse.
  Reference: [Zsh system/stat modules](https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html).
  Use Git status with `--untracked-files=all` so new-directory files are
  individually selectable. At the navigator boundary, show their filename under
  captured directory prefixes in Tree, or a clean filename in All files. Use
  parent paths to disambiguate duplicate filenames in All files, and adapt
  untracked metadata to the complete compact word `New`; never combine state
  and folder into one truncation-prone field.
  Keep canonical `Untracked` wording and exact relative paths in captured facts,
  filtering, details and document context; presentation must not weaken or
  replace the source fact. Git owns enumeration;
  honor ignore rules and retain byte/row limits. Do not introduce a second
  recursive walker or perform enumeration on movement/redraw. Git may still
  report nested repositories as folders; keep them as separate-repository
  notices. Directory replacement races also remain notices, never scans.
  Measure added capture cost and document that large untracked trees may be
  slower; retained-output bounds do not cap traversal time. Exclude submodules. Renames
  are add/delete pairs. Treat all Git strings as inert, sanitized display data.
- Retain at most 256 KiB per capture, 1,000 change rows or 200 commits, with
  visible partial-result notices. Counts describe captured data. A continuous
  document has at most 10,000 logical / 20,000 wrapped lines, with notices.
  Full-file context is opt-in and retains the same capture bounds.
  These bounds do not promise a wall-clock timeout or bound Git's own
  memory/CPU usage. Do not add background processes or persistent caches.
- File review defaults to All files; Tree is the second, alternate projection of the
  same captured changes. Ctrl-X opens their shared View options menu and the
  captured-path ancestor chooser. Keep original file/change-kind identities,
  status labels, filters and reader bookmarks across projection changes.
  Restore each projection's selected row and viewport when returning with the
  same change and filters; choosing the active projection is inert. Invalidate
  saved projection bookmarks when a new capture replaces numeric identities.
  Tree opens three directory levels including their files and shows fourth-level
  folders as collapsed scope entries. Compress nonbranching captured directory
  chains and open deeper scopes in the same panel. Use one cell of indentation
  per directory level, a space after folder arrows, and align nested files with
  their parent name. Enter expands/collapses folders or reads files; Escape restores
  a previous tree scope and bookmark. Left/Right retain document disclosure.
  Folder selection shows a captured summary in the right pane, with independent
  scroll position and retained file bookmarks. Preserve surviving literal folder
  bookmarks across refresh and filters that temporarily hide them; invalidate
  obsolete numeric file identities. Show path/change counts, state
  mix and up to six child areas; bars count captured entries. Commit/comparison
  line totals use existing numstat facts only. Label filtered/partial coverage.
  Build summaries only for the retained result prefix, never on paint. Right
  and Tab focus the summary, Left returns to the tree; focused-summary Enter
  is inert. Folder rows retain ordinary Option-digit acceptance. A folder never
  becomes a diff or syntax-provider target. Filter the whole captured
  list, reveal ancestors temporarily, and restore unfiltered folds on clear.
  Ancestor choices retain at most 200 rows/262,144 prefix characters, with a
  partial notice and Repository always reachable. Refresh reconciles folders
  against captured paths, preserves surviving folds, and returns a vanished
  scope to its nearest captured ancestor. Preserve a surviving file or folder's
  visible slot after projecting the refreshed list. Derive structure only on collection
  or navigation, never during frame rendering or by filesystem discovery.
  All of this state belongs to the current review and is released on exit.
- The shared document capability gives the navigator roughly one third of the
  width (at most 42 cells), with the remainder for reading. Below 90 columns,
  switch between full-width navigator and reader. Use available body height;
  Tab/Shift-Tab switches focus, Enter/Ctrl-E reads, Ctrl-B focuses files, and
  Up/Down and page keys scroll the focused pane independently. Reading never moves
  to another file. Preserve per-file offsets; a pending frame shows no stale
  content from the prior selection. Ordinary secondary inspectors keep their
  list-first policy and 256 wrapped-line bound.
  Git supplies continuous lines, old/new line numbers and semantic +/− roles;
  the shared renderer sanitizes and wraps them, caching wrapping until the
  selection or width changes. Never evaluate source code or terminal escapes.
- Test actual g → options → changes/history → file reader → Back with real
  ZLE, single alternate-screen ownership, guide/resize, retained bookmarks,
  aborts and unavailable peers. Use disposable repositories for staged versus
  unstaged rows, binary/unborn/merge commits, unusual paths, configured helper
  suppression, immutable IDs, limits and unchanged index/configuration.
