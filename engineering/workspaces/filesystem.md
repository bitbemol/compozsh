# Filesystem workspace

Browse, Search descendants, Recents, folder previews and file actions. The
editor coordinates these views at runtime; search providers and Recents are
private capabilities in focused peers; the shared UI owns screen cleanup.

## Essentials

- **Path + Tab sets the folder context** for Browse and scoped Search.
  Recents is a separate navigation entry over this shell's directory stack.
- **Discovery is explicit.** Search runs only on submitted input, rooted at the
  displayed folder, with a visible source. No automatic root/home crawl, no
  search on keystrokes, no silent fallback to another source.
- **Insert, don't act.** Browse, Search and Recents insert the exact quoted
  path by default; only a later prompt submission changes directory (via
  `AUTO_CD`). Cancellation and copy keep the draft, cursor and directory.
- **File actions are explicit.** Dispatch after screen cleanup, recheck mutable
  path facts, pass literal absolute paths as arguments, and never execute a
  selected path as shell code. Opening an application is a user action, never
  a preview.

## Entry points

- **Tab** at the prompt (`directory-context-complete`) opens contextual
  directory completion for a path argument; ordinary Tab completion and modal
  Tab/Escape semantics are otherwise unchanged. Completing a command's path
  argument replaces only that argument. A trailing `/` names a folder: if it
  is missing, Tab delegates to native completion instead of filtering the
  parent by its name.
- **Option-Tab** (`ESC TAB`, requires Terminal's Option-as-Meta) opens Recents.
  Enter and Option-digits use the same insertion dispatcher as path + Tab:
  replace the draft with the exact quoted path, put the cursor at its end and
  repaint visibly after cleanup. Selection never changes `PWD` or the stack.
- Leave Ctrl-Tab, Ctrl-D and Ctrl-X Ctrl-E to Terminal and native ZLE.
- Document filesystem keys and scopes in README and `compozsh --help`; Ctrl-K
  provides the in-view guide.

## Browse

- Browse shows the opened folder's children. The directory browser is the
  deliberate hierarchy exception to the shared key map: Right/Tab enters,
  Left/Shift-Tab goes Back, Ctrl-E/B focus preview/list, Ctrl-T toggles hidden
  folders, Ctrl-O loads a preview, Ctrl-X opens workspace options. Plain
  punctuation and letters filter; visibility toggles stay on modified keys,
  and inspectors added here never take the hierarchy-navigation keys.
  Guide and footer show these actual keys.
- Back restores query and viewport and reselects by literal path in the newly
  captured parent, with a safe fallback if it disappeared. A child that
  vanished or became unreadable after capture keeps the current level and
  says so. Snapshots, visibility and bookmarks are scoped to the invocation.
- At a bare-name level (a lone `x` + Tab lists the current directory), a child
  whose name starts with `-` or `~` gets the value `./-name/` or `./~name/`
  and keeps its plain label, so Right/Tab can enter it and the inserted path
  never reads as an option or a quoted tilde.
- Read only the explicitly entered, previewed or refreshed level; filtering
  and resizing never scan descendants.
- Folder workspaces compose a captured ancestor trail with the shared list and
  inspector. The trail collapses first (below 120 columns), then the passive
  inspector (below 100). Footer hints and selected-row colors apply to the
  list, not the trail. No second renderer.

### Folder previews and empty folders

- Previews are explicit shallow name/type snapshots: at most 40 entries plus
  one lookahead, stopped before sorting with native glob qualifiers. Describe
  filesystem-order samples and truncation truthfully. Never read file
  contents, follow child links, or load previews from movement, filtering or
  resize. Keep only the last requested snapshot per level. Explicit snapshots
  may use the inspector height; narrow screens open them focused. Mounted
  filesystems can still block, so claim no wall-clock bound; enumeration stays
  outside the active input loop.
- Empty folders stay navigable and the actions menu offers the current folder.
  With no selected child (including when a filter hides every directory),
  preview targets the current folder. Distinguish no child directories, no
  visible entries and no filter matches; an empty list is not an error. Reuse
  the shallow enumeration for directory/file/other counts and at most eight
  informational non-directory names, making hidden scope and omissions clear.
  Never create fake selectable file rows.
- An explicitly requested current-folder preview opens focused in the full
  body at any width; Ctrl-B restores the summary and Ctrl-E returns to the same
  captured preview. Don't duplicate a passive preview beside the same sample.
- Fallback inspector context is caller-owned and never leaks into a secondary
  action menu or the next tool.

## Search descendants

- Ctrl-F in Browse opens **Search descendants** for the displayed folder,
  never the highlighted child. Resolve the default source once on entry: Git
  inside a worktree (same subfolder scope) when `_compozsh_git_local
  available` (never Apple's `/usr/bin/git` without developer tools, which
  would offer their installation), otherwise Spotlight for exactly
  home or `/` on macOS, otherwise a bounded filesystem walk. Show the source
  before submission; explicit Ctrl-X choices bypass the default. Missing or
  failed Spotlight never triggers a filesystem fallback.
- The walk is breadth-first, includes hidden entries and never follows
  directory links. It counts but never matches or descends `.git` metadata at
  any depth (directories and worktree/submodule gitfiles), so a folder of
  projects spends its budget on the user's files.
- Return submits positive text or — for filesystem and Git — a nonempty
  exclusion alone; both-empty submission is inert. Spotlight needs positive
  filename text and offers explicit recovery without switching sources.
  Exclusion never authorizes content reads, effects or broader coverage.
- Submitted conditions stay visible in result status; the bottom fields refine
  only the captured snapshot (**Filter folders** in Browse, **Filter results**
  after discovery). Ctrl-F in results edits the submitted query with the same
  source and root — the only recapture route; cancel keeps the snapshot. Back
  to Browse restores filter, selection, viewport and preview focus in the same
  session.
- Paint a scoped **Searching…** frame before synchronous capture using the
  shared renderer and session; no fake percentage, empty count or key promises
  while blocked. Resize may wait until the provider returns, then repaint.
- Keep provider outcomes distinct: successful empty results, failure or
  unavailability, and partial output. Never disguise a failed index as no
  matches or start a fallback crawl. Show provider and partial limits;
  Spotlight coverage is not a filesystem walk.
- Query entry uses the shared input and renderer with an explicit submit
  capability. Query entry, secondary menus and unrelated tools suppress search
  and the other workspace actions; missing peers omit capabilities without
  source ordering.

## Options menu and file actions

- Ctrl-X opens one flat, searchable options menu in the same screen session,
  grouped as **Selected folder** (or **Selected file** / **Selected link** for
  search results), **Current folder**, then **Go to**. The group appears in
  every action label so filtering and paging keep meaning; unavailable
  capabilities and empty groups are omitted; group labels are never selectable
  or numbered. Details show each action's exact path. Scoped Search belongs to
  Current folder; Recents to Go to. No mode registry for three known views.
- Keep the selected search result and its captured type when opening the
  menu; never substitute the search root or a parent for item actions.
  Change directory on a result captured as an ordinary folder is refused if
  it has since become a link; Browse rows and the current folder may be links
  and are followed as listed.
- Selection is type-aware: ordinary directories insert an editable path;
  files and symbolic links open an explicit action picker. Action labels are
  captured display data — never call filesystem or application providers to
  render them.
- Open uses `open -- <path>`; Reveal uses `open -R -- <path>` and requires an
  explicit selection and a usable system `open`. Files and folders use their
  registered app; directory links need an explicit follow action for shell
  navigation; broken links omit Open.
- Copy closes after restoring the terminal, copies the literal absolute path,
  and preserves the original editable command and unrelated shell state; an
  explicit directory change also preserves the draft, and the prompt
  recaptures its facts for the new folder before repainting
  ([prompt](../prompt.md#project-and-runtime-context)).
  Capability hints come from captured facts, with a checked failure path if a
  tool disappears. Never launch applications to fill a panel.
- A target that changed or became unavailable, or a vanished `open`, is
  reported after cleanup and any prompt refresh as one fixed `zle -M` message
  that never echoes the raw path; Open, Reveal, link following and Change
  directory all report this way and keep the draft and directory. A directory
  is rechecked as a searchable folder before `cd`, so a stale one never
  reaches `cd`'s raw diagnostic, while `chpwd` hooks keep their own output.
- Secondary pickers return to a caller-owned query/selection/viewport bookmark
  without recapturing providers.

## Recents

- The native directory stack is the source of truth. Show short names with
  parent context and current/previous cues; match full captured paths.
- Check availability once for at most the first 200 entries when opening;
  label later metadata as not checked while keeping those paths searchable;
  keep missing entries identifiable; Zsh validates again when the inserted
  path is submitted.
- Rendering never enumerates children or recursively inspects visited
  folders, and never invents visit timestamps or persists a second history.
  `dirs -v` keeps stack indexes; picker digits are visible slots, and details
  may show `~N`. Ctrl-O browses the selected location; if it is now
  unavailable, Recents stays with its bookmark and a one-time notice naming
  only the short folder name.

## Testing

Test actual key bytes, cancellation, scope and capture counts alongside the
shared hint and guide contracts; empty and nonempty drafts, Enter and
Option-digits, literal numeric queries, quoting and real post-cleanup painting
(not just `BUFFER`); first and repeated submissions with FIFO-gated,
`PATH`-shadowed providers, real PTY resizing and clean restoration; literal
launcher arguments with `PATH`-shadowed spies. Never flush system caches or
read protected or private files to test latency.

## Retired decisions

- The `d` and `f` commands, their aliases, compatibility parsers and the
  `f --list` / `--print0` printing API (native scripting tools replace them).
- The Ctrl-X Ctrl-D entry and a double-Tab timing recognizer.
