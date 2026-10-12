# Git workspaces

`g` is the Git task family: bare `g` opens the recent-branch workspace,
`g --worktree` the worktree workspace, `g --review` the read-only review
workspace, `g --discard-all` the guarded discard (a private operation in
`.zsh.tools`), and `g --help` (also `g --review --help` and
`g --discard-all --help`) its help; any other
arguments go straight to `command git` with its status.
`.zsh.navigation` owns dispatch and the canonical `g` help; `.zsh.git-worktree`,
`.zsh.git-review` and `.zsh.git-syntax` are optional peers detected at
invocation. Disabling them keeps ordinary `g` switch/copy and Git delegation.

## Essentials

- **Local only.** Compozsh's own Git captures (prompt status, review,
  comparison, worktree capture) and its discard and worktree operations
  disable network transport, lazy fetch, hooks and fsmonitor; read-only
  captures also disable optional index writes, external diffs and textconv and
  neutralize configured filter drivers per invocation, and worktree creation
  refuses configured checkout filters. An explicit, confirmed branch switch or
  creation (`git switch`) deliberately keeps the repository's own checkout
  filters and hooks, as SECURITY.md discloses. Repository and global
  configuration are never changed.
- **Review is read-only.** Review views dispatch no stage, discard, commit,
  checkout, clipboard or app action; adding a mutation shortcut needs a
  separately authorized design and behavioral tests. Worktree mutations happen
  only through explicit, reviewed, revalidated actions after screen
  restoration.
- **Literal data.** Parse NUL-delimited output with literal pathspecs,
  validate full object IDs before using them as revisions, disable replacement
  refs, and treat every Git string as inert, sanitized display data.
- **Bounded and honest.** Every capture has byte/row bounds with visible
  partial notices; counts describe captured data, and a truncated capture is
  never a complete safety check. Bounds limit retained output, not Git's own
  time, memory or CPU.
- **Input never waits on Git.** Navigation paints immediately; provider work
  runs in the controller outside the input loop. Filtering, scrolling, resize
  and the guide never call Git.

## Branches

Bare `g` opens recent local branches (it can also create a local branch from
a remote one). Ctrl-X on Branches opens review choices (below). The branch
picker keeps its actions — switch, copy — performed after terminal cleanup.
Branch snapshot reads (refs, checkout reflog, detail subjects) keep the
local-only controls and disable commit-signature verification, so reading a
signed reflog never runs a configured verifier.

## Git worktree workspace boundary

- `g --worktree` is the sole worktree entry. `.zsh.git-worktree` owns capture,
  temporary choices and actions; `g` keeps its recent-branch default and
  transparent Git arguments.
- Reuse the navigation fuzzy collector and shared UI (text entry, keys, guide,
  focus, screen lifecycle). Options consume the selected registered path.
  Creation composes branch, captured start commit and new folder into one
  explicit action after restoration; parent browsing uses the hierarchy keys;
  Back preserves caller bookmarks.
- Create, Enter, Move / rename, Remove and Refresh stay visible in the main
  menu; contextual options are shortcuts to the same flows, never their only
  entry. Move edits parent/folder name, keeps files and branch, and delegates
  to native Git on the same filesystem after showing exact old/new paths.
- Capture registered worktrees from NUL-delimited porcelain and all local
  branches within explicit bounds — not recent checkout history. Filtering and
  painting read no providers; refresh is explicit.
- Transport, lazy fetch, hooks, fsmonitor, automatic maintenance and submodule
  recursion stay disabled. Creation and removal refuse configured checkout
  filters and submodule trees. Register new worktrees without checkout, then
  check their effective configuration (conditional includes can differ from
  the source checkout) before materializing files. Revalidate exact
  repository/directory identity, branch/commit and destination after cleanup.
  Never evaluate command previews.
- Removal keeps the branch; refuses main, current, locked, missing or detached
  targets and active Git operations; and checks ignored files as well as
  tracked and untracked changes. Sparse, unmerged or assume-unchanged indexes
  can't establish safety. Never force, auto-stash, reset branches or
  recursively delete failed-creation residue. Disclose concurrent-writer races
  and partial failures.
- Full help lives in the same-source `g` companion. README and SECURITY
  document persistent Git/checkout effects, local reads, refusals and recovery
  together. Test synthetic repositories and real ZLE journeys, including
  hostile literal values and post-cleanup dispatch.

## Git review workspace boundary

### Ownership

`.zsh.git-review` owns bounded Git providers and review controllers. Source
time defines functions only; navigation detects it at invocation. It adds no
public command, registration table, loader phase or key parser, and uses the
shared screen owner, collector, renderer, semantic palette, busy painter and
input loop. A fixed shallow view nesting scopes snapshots and bookmarks — no
general workflow engine. Escape restores list query, selection, viewport and
focus.

### Scopes and comparisons

- Ctrl-X on Branches offers **current working changes**, **selected branch
  commits**, **Compare branches or commits** and **Change atlas**;
  `g --review` offers the same for the current checkout, with scopes labeled
  explicitly. Commits open a
  file-and-diff document workspace; working changes opens it directly.
- Resolve a branch tip once to a full hex object ID and keep first-parent IDs
  for stable commit review. A root commit compares with the empty tree.
- Comparison setup reads Compare (To) against Against (From), both editable.
  **All differences** compares From → To; **Changes since common ancestor**
  compares their unique local merge base → To. No inferred branch of origin
  or fixed branch name.
- Accept only explicit local branch, tag or remote-tracking names, `HEAD`, or
  unambiguous commit IDs; reject ambiguity, revision expressions and ranges.
  Capture at most 1,000 refs / 256 KiB (excluded refs count toward discovery)
  and keep typed input literal until submission. Ref selection accepts the
  best match; literal entry keeps a stable second slot (first when no refs
  match).
- Resolve full IDs once, show the actual endpoints in the guide, and keep them
  on Ctrl-R; re-selecting a ref explicitly picks up its newer tip. Missing
  objects, absent ancestry or multiple merge bases never change the method
  silently.
- Setup and direct `g --review [--merge-base] A B` share providers and reader;
  Back returns to setup or exits the direct entry. No checkout, index
  mutation, fetch or persistent comparison state. Evidence:
  [Git comparison design](../../investigations/git-comparison-design.md).

### Git invocation safety

- Disable optional index writes, fsmonitor, hooks, lazy fetch, network
  protocols, external diffs, textconv and commit-signature verification
  (`-c log.showSignature=false`: no configured verifier such as `gpg.program`
  runs, and history captures hold only Git's own output). Discover configured
  clean/process filter names and override them to inert values per
  invocation, also disabling required-filter enforcement. Refuse a capped or
  failed filter-name discovery and any driver name containing `=` (Git's
  `-c key=value` can't address it unambiguously). Bound the generated override
  argv to 4,096 entries in manual and automatic paths. Help explains the
  unfiltered comparison. These measures are not an OS sandbox. References:
  [git diff](https://git-scm.com/docs/git-diff),
  [git status](https://git-scm.com/docs/git-status),
  [Git environment](https://git-scm.com/docs/git).
- Reject escaping paths and special working files; don't follow replaced
  parents outside the worktree. Renames are add/delete pairs; submodules are
  excluded; nested repositories remain separate-repository notices.

### Capture and parsing

- Retain at most 256 KiB per capture and 1,000 change rows or 200 commits,
  with visible partial notices. A continuous document holds at most 10,000
  logical / 20,000 wrapped lines, with notices. Full-file context is opt-in
  under the same bounds. Add no background processes or persistent caches
  beyond the auto-refresh and syntax children below.
- Patch captures pin their output shape per invocation, overriding
  configuration: default prefixes, no relative paths, word diff or color,
  `diff.suppressBlankEmpty=false`, the Myers algorithm and zero inter-hunk
  context, so the parser numbers every line, blank context included.
- Use `git status --untracked-files=all` so files in new directories are
  individually selectable. Git owns enumeration and ignore rules; never add a
  second recursive walker or enumerate on movement or redraw. Large untracked
  trees can be slow — retained-output bounds don't cap traversal time.
- Selected untracked regular text files use the same numbered reader as
  all-additions patches in both context modes, prefixing every source line so
  header-like text stays inert; modes share one snapshot/cache key. Read only
  on selection or refresh, without execution, staging, filters, directory
  scans or caller-directory/hook changes. Use native no-follow, nonblocking
  open and descriptor stat to reject symlink and special-file replacements;
  pin and validate a physical parent in a subshell. Bound bytes across short
  reads, keep trailing newlines, distinguish read failures from empty files. A
  NUL in the captured prefix yields a binary notice (no claim of universal
  binary detection). Symlinks and folder entries are notices; missing, unsafe
  or failed reads are unavailable; conflicts are notices. Reference:
  [Zsh system/stat modules](https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html).
- Keep canonical `Untracked` wording and exact relative paths in captured
  facts, filtering, details and document context; presentation may shorten
  state to the compact word `New`, but never combines state and folder into
  one truncation-prone field.

### Responsive navigation

File selection and document inspection have separate service paths. The input
loop applies and paints every complete navigation sequence immediately; when
selection outruns the loaded document, the reader shows a stable loading
surface with matching geometry. A short preview-settlement window resets after
each navigation key; once input is quiet, exactly the latest target goes to the
controller, which alone captures and parses its diff outside the input loop.

This coalesces expensive preview work — it is not input debouncing. Never
flush, discard or infer release of repeated keys: every complete sequence is
user intent, and Terminal.app sends no key-up event. Keep the list-only
selection/paint path well below the observed key-repeat cadence; optional
provider work is a latest-request-wins input-idle operation, never hidden
behind an extra focus step. Test a buffered PTY arrow burst: only the initial
and final documents load, and the next key applies to the final selection with
no unread movement tail. Evidence:
[key-repeat latency](../../investigations/git-review-key-repeat-latency.md).

### Document reader

- The navigator gets about one third of the width (at most 42 cells), the
  reader the rest; below 90 columns they switch full-width. Tab/Shift-Tab
  switch focus, Enter/Ctrl-E read, Ctrl-B focuses files, and arrows and page
  keys scroll the focused pane independently. Reading never moves to another
  file. A pending frame shows no stale content from the previous selection.
- Git supplies continuous lines, old/new line numbers and semantic +/− roles;
  the shared renderer sanitizes and wraps them, caching wrapping until the
  selection or width changes, and maps wrapped rows to logical lines. Never
  evaluate source code or terminal escapes.
- Right discloses navigator → focused diff → full-file context; Left reverses;
  at either end the arrow is inert. Untracked previews and notices have one
  level. Tab/Shift-Tab and Ctrl-E/B change only focus and keep context mode;
  Right from the navigator always enters focused diff. The loop returns
  disclosure and refresh requests; only the controller captures data.
- Start focused with three context lines per hunk. Context mode persists until
  another disclosure. Changing it keeps each file's semantic source anchor —
  the first visible code line, resolving a hunk header forward and a trailing
  notice backward; deletions use old-side coordinates, context and additions
  new-side. Collapsing into omitted code seeks the nearest retained same-side
  line (ties prefer earlier context), reports the adjustment, and falls back
  to the notice when no code remains. Same-mode selection keeps the visual
  position. Never claim content tracking through concurrent edits.
- Retain four raw file/context snapshots (at most 1 MiB) with per-file reading
  offsets; a loading placeholder never overwrites a saved position. Release
  captures and bookmarks on exit.

### File projections

- File review defaults to **All files**; **Tree** is the alternate projection
  of the same captured changes. Ctrl-X opens View options (All files, Tree,
  Jump to ancestor, Change atlas) where present; an atlas child reader doesn't
  offer them recursively.
- Projections keep original file/change-kind identities, status labels,
  filters and reader bookmarks, and restore each projection's row and
  viewport when returning with the same change and filters. Choosing the
  active projection is inert; a new capture invalidates saved projection
  bookmarks.
- All files shows clean filenames, using parent paths to disambiguate
  duplicates. Tree opens three directory levels with their files and shows
  fourth-level folders collapsed; nonbranching chains compress into one row;
  deeper scopes open in the same panel. One cell of indent per level, a space
  after folder arrows, nested files aligned with their parent's name. Enter
  expands/collapses folders or reads files; Escape restores the previous tree
  scope and bookmark; Left/Right keep document disclosure.
- Folder selection shows a captured summary in the right pane — path and
  change counts, state mix and up to six child areas; bars count captured
  entries; commit/comparison line totals use existing numstat facts only;
  filtered or partial coverage is labeled. Build summaries only for the
  retained result prefix, never on paint. Right and Tab focus the summary,
  Left returns to the tree, focused-summary Enter is inert, folder rows keep
  Option-digit acceptance, and a folder never becomes a diff or syntax target.
- Filtering covers the whole captured list, reveals ancestors temporarily and
  restores unfolded state on clear. Ancestor choices keep at most 200 rows /
  262,144 prefix characters with a partial notice, Repository always
  reachable. Structure is derived on collection or navigation only, never
  during rendering or by filesystem discovery, and released on exit.

### Change atlas

Ctrl-X → Change atlas opens a map derived solely from the captured list,
keeping numeric file/change-kind identities beneath directory-prefix grouping.
Show source bounds and partial notices; bars count entries and imply no
content analysis. Child folders and file readers keep Back bookmarks, and
returning restores the review's filter, focus and source anchor. Pending
automatic refresh pauses while the atlas is open and resumes after return.
Selected files are read through the existing bounded providers with
commit/comparison IDs; never discover child paths or bulk-read contents to
paint it.

### Refresh

- Ctrl-R rechecks filter-safety configuration, recaptures the file list and
  eagerly reloads only the selected diff, outside the input loop. Keep the
  filter and identify the selection by literal path **and** change kind, then
  find its new filtered rank (numeric IDs are valid only within one
  observation). Keep pane focus, context mode and source anchor for a
  surviving selection; preserve surviving folder bookmarks and folds, return a
  vanished tree scope to its nearest captured ancestor, and keep a surviving
  item's visible slot. Manual refresh may explain a selection that left the
  results and focus the first match in focused mode. Empty lists stay
  refreshable.
- A successful refresh invalidates every raw, token and context cache and
  other-file bookmark, so cached context never resurrects an older diff. On
  list or configuration failure keep the previous observation with a retry
  status and propagate cancellation; failed safety preparation blocks uncached
  diff reads until retry while allowing already captured documents; newly
  validated filter overrides survive a following list-read failure. Commit
  refresh keeps immutable IDs.

### Working-changes auto-refresh

The narrowly approved screen-session worker exception.

- Working changes refreshes automatically unless the initializer sets
  `ZSH_GIT_REVIEW_AUTO_REFRESH=0`. Ctrl-A pauses or resumes it for the current
  screen only; Ctrl-R checks immediately and resumes after an automatic
  failure, while an intentional pause stays paused. Commit and comparison
  workspaces are immutable-ID snapshots refreshed only by Ctrl-R. Show
  separate relative ages for the last completed check and the last published
  snapshot, so an unchanged check never implies an update.
- Checks are input-idle with at most one owned worker/provider pair in flight,
  using a private mode-0700 directory, a mode-0600 FIFO, bounded in-memory
  streams, a framed literal-data protocol and the 1 MiB snapshot cap. No
  daemon, hook or persistent watcher or cache. The worker performs only the
  same bounded, transport-disabled status and selected-diff reads as manual
  refresh, and owns the exact provider PID so pause, manual refresh, timeout
  and cleanup terminate and reap it without signaling a parent-visible
  handoff PID. The parent reaps the worker through the shared job reaper and
  retires only its own job record — never an unqualified `jobs`/`wait` sweep
  (see the [job-lifecycle limitation](../../SECURITY.md#job-lifecycle)).
- Pace checks no faster than two seconds and at least four times the measured
  capture duration, capped at thirty seconds. One check has a thirty-second
  screen-session deadline that doesn't depend on picker-idle callbacks or an
  empty input queue and includes result delivery (nonblocking writes, partial
  counts, responsive cancellation when the pipe is full). A failed or
  timed-out check keeps the old observation, pauses checks and offers Ctrl-R.
- Validate a complete result before publishing; publish a change with one
  repaint and no busy or blank frame, preserving filter, path and change kind,
  filtered rank, viewport slot, focus, context mode and source anchor. If the
  target disappears or leaves the filter while the reader is focused, keep the
  old reader, show `update ready`, and publish when focus returns to the list —
  never move focus automatically. A disclosure change invalidates a pending
  diff candidate. File lists and later diffs are separate observations, not a
  transaction; failed reads differ from empty snapshots; abort propagates.

### Syntax highlighting

- `.zsh.git-syntax` is an optional token provider over the selected captured
  document, with no public command or startup probe. `support/git-syntax.vim`
  is a shipped adapter asset, not a peer; both installation modes include it.
  It is independent of Vim user settings and of the shell's command-line
  highlighter.
- Syntax is lexical snapshot metadata: old/new sides are analyzed separately
  and reset at omitted gaps; fragments are labeled honestly. Never fetch extra
  objects or files to color a diff. Document text and anchors stay verbatim.
  Unsupported, missing, failed or limited syntax falls back visibly to the
  same readable diff, never a blank document.
- The child is `/usr/bin/vim` only, with an empty environment plus explicit
  `PATH` and UTF-8 locale; vimrc, gvimrc, viminfo, modelines, plugins, swap and
  undo disabled; a system-only runtime path; and only reviewed OS syntax
  definitions enabled (initially Swift, Zsh, shell, JSON, Python). No filetype
  detection, repository paths, source execution, user runtime scripts, HTML
  export or ANSI extraction. Source reaches it through private mode-600 FIFOs,
  never a here-string: Zsh 5.9 backs `<<<` with a temporary file
  ([implementation](https://github.com/zsh-users/zsh/blob/zsh-5.9/Src/exec.c#L4383-L4406)),
  which is also why Git captures are parsed in memory
  ([security](../security.md#handling-sensitive-data)).
  It returns a versioned, request-ID-framed, fully validated protocol of
  numeric character spans and fixed semantic roles. This is configuration
  hardening, not an OS sandbox.
- Bounds: 64 KiB input, 3,000 document rows, 2,048 characters per line, 4,096
  spans and 128 KiB output; an 800 ms analysis guard in the child and a
  one-second liveness deadline for the request. These are Vim failure bounds,
  not UI budgets — the input loop never waits for them.
- One child starts on document-workspace entry, keeps at most one nofile
  buffer per allowlisted language, and is reused only within that session.
  No daemon, persistent cache, neighbor prediction or process queue. Always
  close descriptors, kill and reap the owned child and retire its own job
  record — never an unqualified `jobs`/`wait`/`disown` sweep or detaching a
  live child to hide it. Preserve caller options and unrelated jobs; prompt
  capture only observes running/suspended entries and never consumes
  completion notifications (see the documented
  [job-lifecycle limitation](../../SECURITY.md#job-lifecycle)).
- Acquisition is passive and focus-independent. After layout publishes the
  exact source viewport, an input-idle callback schedules one bounded window
  around it — normally three visible spans each side, clamped to 256 guard
  rows and reduced to fit the byte bound — and refills two spans before an
  interior edge while the installed window still covers the reader. Startup,
  completion and parsing never block input.
- Each request gets a monotonically increasing generation; exactly one is in
  flight and only the generation matching the current document and viewport
  publishes. Discard stale responses before they touch caches or render state,
  then schedule the latest viewport. Include the capture-snapshot epoch in
  publication identity so a refresh can't accept an older response. Show the
  stable loading surface only when no installed window covers the reader;
  during read-ahead keep the colored frame until its replacement validates,
  and never paint plain code to color it later. A missing, invalid or timed-out
  response retires that request without poisoning other documents; retry the
  settled viewport once, and only a second transient failure for the same
  window becomes an explicit plain fallback. Deterministic unsupported, size
  and locale outcomes may go plain immediately.
- Cache one bounded syntax window per raw snapshot key (four), invalidate it
  with its snapshot on refresh, and release descriptors, FIFOs, child, buffers
  and caches on exit. Measure request, validation, render and paint costs
  separately.
- Diff backgrounds and lexical foregrounds are separate layers: green/red
  backgrounds mark additions/removals, with +/− for non-color recognition.
  `ZSH_HIGHLIGHT_STYLES[review-*]` owns customizable colors; token spans keep
  their row background; navigator selection is independent. Map character
  spans through tab/control sanitization and cell-aware wrapping before native
  ZLE highlighting; never embed escapes in document text. Apple's OS updates
  may change grammar coverage, so don't promise automatic support for every
  language or require a beta Vim.

### Testing

Exercise the real g → options → changes/history → file reader → Back journey
with ZLE: single alternate-screen ownership, guide and resize, kept
bookmarks, aborts and unavailable peers. Use disposable repositories for
staged versus unstaged rows, binary, unborn and merge commits, unusual paths,
configured helper suppression, immutable IDs, limits and unchanged
index/configuration. For syntax, cover Unicode, wraps, empty tokens, missing
grammar, size and time limits, cancellation, hostile config and modelines,
cache/refresh and ZLE cleanup. For projections and refresh, cover wrapped
lines, gaps, deleted and new files, truncation, cache visits, replacement
races and mode switches.

## Retired decisions

- The original comparison labels ("Exact versions", "Compare revisions…"),
  replaced by **All differences**, **Changes since common ancestor** and
  **Compare branches or commits**.
- A Ctrl-X-only route into the change atlas; it now lives under View options.
- Line-count change atlas bars, narrowed to entry counts before release: for
  working changes, line counts would need content reads beyond the
  selected-file capture boundary
  ([composer and atlas](../../investigations/composer-and-atlas.md)).
