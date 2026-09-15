# Filesystem workspace

Read this contract when the task matches its route in [AGENTS.md](../../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Filesystem workspace boundary](#filesystem-workspace-boundary)

## Filesystem workspace boundary

- Path + Tab establishes the folder context for Browse and scoped Search.
  Recents is a separate navigation entry that can supply a folder to Browse;
  sharing the session does not make it a specialization of that folder.
  Keep `d` and `f` retired; do not reintroduce aliases, compatibility parsers,
  or duplicate file interfaces.
- Browse shows the opened folder's children. Recents is explicitly labeled
  and uses only this shell's stack; never inject it into child listings.
- Ctrl-F in Browse opens **Search descendants** for the displayed folder.
  Resolve the default source once on entry: Git within a worktree (same
  subfolder scope), otherwise Spotlight for exactly home/root on macOS,
  otherwise bounded filesystem. Show the source before submission; explicit
  Ctrl-X choices bypass default selection. Missing/failed Spotlight must never
  trigger a filesystem fallback. Never target the highlighted child.
  Return submits positive search text or a nonempty exclusion (filesystem/Git);
  Spotlight retains its positive filename-seed requirement;
  typing, redraw and resize cannot discover. Label memory-only input **Filter
  folders** in Browse and **Filter results** after discovery. Ctrl-F in results
  edits the submitted query using the same source/root; cancel retains the
  snapshot. Back to Browse restores filter, selection, viewport and preview
  focus in the same screen session. Ctrl-X retains explicit source choices.
  Secondary menus/query entry and unrelated tools must suppress this capability;
  Ctrl-E/B owns detail/list focus throughout the shared modal UI. Keep normal
  prompt editing and autosuggestion bindings unchanged. Test actual key bytes,
  cancellation, scope and capture counts alongside shared hint/guide contracts.
- Option-Tab at the ordinary prompt opens Recents. Enter and Option plus visible digits use
  the same insertion dispatcher as path + Tab: replace the draft with the exact
  quoted path, place the cursor at its end, and repaint it visibly after screen
  cleanup. Selection must not change PWD or the stack. Submission at the normal
  prompt performs AUTO_CD. Cancellation and copy preserve the existing draft,
  cursor and directory. Test empty/nonempty drafts, Enter/Option-digits, literal numeric queries, quoting and
  actual post-cleanup terminal painting, not just BUFFER values.
  Bind native Meta-Tab (`ESC TAB`) with ZLE; require Terminal's
  Option-as-Meta setting and document it. Leave Ctrl-Tab with Terminal's tab
  switching, Ctrl-D with native delete/EOF and Ctrl-X Ctrl-E with command editing.
  Do not reintroduce the Ctrl-X Ctrl-D entry or a double-Tab timing recognizer.
  Ordinary Tab completion and modal Tab/Escape semantics stay unchanged.
- Ctrl-X inside the workspace opens its shared options menu. Mode changes
  and secondary actions retain one screen session. Do not recursively start
  editors or build an extensible mode registry for three known views.
  Group the flat searchable menu by **Selected folder** (or **Selected file** /
  **Selected link** for search results), **Current folder**, and **Go to**,
  with contextual operations first and independent destinations
  last. Keep the group in every action label so filtering and paging preserve
  its meaning. Omit unavailable capabilities and empty groups; group labels
  never become selectable results or consume numeric shortcuts on their own.
  Details identify each action's exact path. Scoped Search belongs to Current
  folder; Recents belongs to Go to and retains the native stack as its source.
  Preserve the selected search result and its captured type when opening the
  menu; never substitute the search root or a parent for item actions. Open
  uses the exact path with `open --`; Reveal uses `open -R --` to select that
  item in Finder. Files and folders use their registered app; directory links
  require an explicit follow action for shell navigation. Dispatch after screen
  cleanup, recheck mutable path facts, and omit Open for broken links. Test
  literal launcher arguments with PATH-shadowed spies and real keyboard flows.
- Search requires a source, the displayed folder as root, and explicit nonempty
  query submission. No automatic root/home crawl; no search on keystrokes.
  Git search from a subfolder stays within it. Display provider and partial
  limits; Spotlight coverage is not equivalent to a filesystem walk.
- Paint a scoped **Searching…** frame before synchronous capture, using the
  shared renderer and existing screen session. No fake percentage, empty-result
  count, or interactive key promises during blocked reads. Resize handling may
  be deferred until a provider returns; repaint at current dimensions afterward.
  Preserve provider exit outcomes independently of UI navigation status:
  successful empty results, failure/unavailability, and partial output differ.
  Do not disguise a failed index as no matches or start a fallback crawl.
  Test first/repeated submissions with FIFO-gated, PATH-shadowed providers,
  real PTY resizing, exact scope, no eager capture, and clean restoration.
  Do not flush system caches or read protected/private files to test latency.
- Query entry uses the shared picker input/renderer with an explicit submit
  capability, not a parallel key reader. Secondary menus disable workspace
  actions. Unavailable peers omit their capabilities without source ordering.
- Search providers and Recents remain private capabilities in focused peers.
  The editor coordinates Files views at runtime; the UI peer owns final screen
  cleanup.
- Document filesystem keys/scopes in README and `compozsh --help`; Ctrl-K
  provides the in-view guide. Native scripting tools replace the removed
  `f --list`/`--print0` API; do not leave dead printing/argument-parsing paths.
