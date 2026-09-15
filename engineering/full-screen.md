# Full Screen

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Full-screen interaction standard](#full-screen-interaction-standard)

## Full-screen interaction standard

Every Compozsh full-screen tool shares one interaction system while retaining
its own task context. Follow **Context-preserving composition** for transitions.
Use the shared UI peer's renderer, input loop, guide and cleanup; callers supply
captured content, capabilities and the meaning of acceptance. Never fork a
renderer, key parser or hand-written shortcut bar for an individual tool.

The design draws on cognitive psychology and HCI guidance, not a claim of
neuroscientific validation. In particular, use [recognition cues](https://www.nngroup.com/articles/recognition-and-recall/),
[consistent conventions](https://www.nngroup.com/articles/consistency-and-standards/),
[progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/)
and Apple's [focus guidance](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection).
These motivate the following product decisions; validate the actual terminal
experience through behavior tests and user feedback rather than claiming the
sources prove a particular column ratio or key assignment is optimal.

| Region | Contract |
| --- | --- |
| Title bar | Stable tool identity on the left; quiet right-aligned COMPOZSH branding when space permits, or captured busy status |
| Status | Separate, quieter snapshot/result status; keep scope visible while filtering |
| Context | One separate location/source row, abbreviated as needed and omitted only in very short windows |
| Search/filter input | Bottom input dock above the footer on usable full screens, with the real ZLE caret at the literal query end; label the operation (`Filter folders`, `Search descendants`, `Filter results`). Inline and very short fallbacks retain top input |
| Navigation strip | Passive disclosure map in the existing separator row; highlight current focus and show a whole next-gesture hint when it fits. Derive stages from current capabilities, never infer available actions from a tool name |
| Main body | Pickers prioritize results; document workspaces prioritize the selected document beside a stable navigator. Preserve exact values separately from labels |
| Details / reader | Secondary information or a primary document, respectively; explicit focus and independent scroll, no provider calls during repaint. In a document workspace, distinguish selected content from keyboard focus |
| Footer | Emphasized real acceptance action, Escape, then at most five complete capability hints on the full screen. Reserve the final `^K all keys` hint before fitting optional controls, prioritizing the available filter/exclusion toggle and then an explicit Option-number hint before secondary actions. The guide retains all applicable keys and ends with `^K close`; narrow fallbacks shorten whole labels before omitting guide access |

The visible `[n]` prefix is reserved for actionable candidates: directories,
files, menu operations, or other exact values that the input loop can select and
accept. Showing `[n] some text` promises that the row participates in selection
and that Option plus its visible digit can choose it whenever digit selection is active.
Information-only text must use passive rows, status/context regions, or
details/reader content. It must not enter the result/candidate array, receive a
selection cursor or selected-row highlight, become an arrow-navigation stop, or
acquire a digit shortcut or acceptance action. When a screen has one action such
as **Done** followed by an explanation, index only **Done**; render every reason,
warning, statistic, and recovery instruction as passive content. Preserve this
affordance consistently across every Compozsh screen and cover both candidate
membership and rendered indexes in shared UI regression tests.

The following is the canonical **modal picker key map**. These are Compozsh
controls, not claims about macOS-wide shortcut standards. Use the same key for
the same action in every tool. A missing capability leaves its key inert and
omits its hint; never repurpose that key for an unrelated per-tool action.

| Key | Shared meaning |
| --- | --- |
| Escape / Ctrl-G | Cancel or return from a secondary view |
| Ctrl-C | Abort the interaction |
| Enter | Apply the visibly named primary action |
| Ctrl-K | Open/close the keyboard guide |
| Up/Down, Ctrl-P/N | Move results or scroll the focused view |
| Fn/Option-Up/Down, Ctrl-V/Ctrl-D | Page up/down in the focused view; reader pages retain one overlapping line |
| Ctrl-U / Ctrl-W | Clear the active field / delete its last word |
| Ctrl-] | Reveal exclusion and switch positive/exclusion field editing in candidate filters |
| Backspace | Delete the last character in the active positive/exclusion field |
| Ctrl-Y | Copy the selected value and close, when available |
| Ctrl-L | Redraw |
| Ctrl-F | Start descendant discovery in Browse; edit discovery query in Search results |
| Ctrl-E / Ctrl-B | Focus details/list, when available |
| Tab / Shift-Tab | Switch list/details focus; in the browser, enter/go Back |
| Ctrl-O | Inspect a folder: browse from Recents, preview inside the browser |
| Ctrl-X | Open **review** on Branches, **options** in filesystem/worktree views, or **View options** in Git file-review views; otherwise inactive |
| Right / Left in a document workspace | Disclose files → focused diff → full-file context / reverse the sequence; on a folder summary, focus the summary / return to the file list |
| Ctrl-A in an auto-refresh document workspace | Pause/resume automatic refresh for the current screen session |
| Ctrl-R in a refreshable workspace | Refresh the captured choices or document; Git review retains available selection/focus/source area |
| Ctrl-T | Toggle hidden folders in the browser |

Candidate filters share positive and optional exclusion fields. Ctrl-] reveals
and switches fields; both remain active, with a visible focus marker and literal
input. Keep the exclusion row visible once revealed, including narrow/inline
fallbacks. Ctrl-U, Ctrl-W, Backspace and paste edit only the focused field.
Changing either value resets the result position; switching fields alone does
not. Back restores both values, field focus/visibility and the existing bookmark.
Secondary views start with independent fields. Plain digits always edit literal
text in every filter, including its first character. Option/Meta-digit acceptance
requires both fields empty, the positive field active and visible list focus;
history retains numeric typing without slot shortcuts. Terminal.app shortcuts
require Option-as-Meta; arrows and Enter remain available without it.

Exclusion uses each view’s complete searchable text and preserves the positive
matching policy, duplicate policy and ordering, including history’s conditional
fuzzy fallback. Apply rejection before retained result-prefix limits. Keep the
matching calculation pure and explicit; shared UI state belongs in its adapter.
Authored text, confirmations, status notices and document-only readers do not
advertise candidate exclusion. Missing matching support keeps the key inert.

Search descendants owns submitted positive/exclusion discovery conditions.
Filesystem/Git allow exclusion-only capture with existing bounds; both-empty
submission remains inert. Spotlight requires positive filename text and offers
explicit recovery without switching sources. Submitted conditions remain visible
in result status; bottom fields refine only the captured snapshot. Editing
submitted conditions and pressing Return is the only recapture route for this
change. Exclusion never authorizes content reads, effects or broader coverage.

The hierarchy, document disclosure/refresh and Ctrl-O contexts above are explicit
exceptions, not permission for arbitrary tool-specific remapping. Keep the actual action visible in the
footer/guide. Add new keys only after checking this map, normal shell editing,
Terminal.app interception and control-byte collisions (for example Tab/Ctrl-I,
Enter/Ctrl-M and flow-control keys). Prefer an existing action or menu over a
new binding. A key-map change must update this table, shared handler, hints,
guide, public help, README and native PTY tests together. Keep contract coverage
across history, Recents, branches, files, tool discovery and secondary menus.
Collectors and tool providers must not implement their own key parsers or hints.
Ctrl-R refreshes a document workspace or candidate view only when it explicitly
exposes the corresponding shared refresh capability. Preserve prompt history search and the existing
next-result alias in other pickers. Refresh remains available with empty or
filtered-out refreshable lists, allowing new changes to be discovered.
Ctrl-A remains beginning-of-line at the prompt and is advertised
only when the active document workspace provides automatic refresh. The
keyboard guide must never trigger refresh or an automatic provider check.
Its authored key and fact labels use the shared heading style, descriptions
use ordinary text, and general keyboard notes use muted text. Clip emphasis
spans to the visible row; caller-owned context remains literal prose. These
passive labels never acquire candidate numbers or selection behavior.

- Preserve spatial landmarks when results shrink. Blank space is acceptable;
  do not fill the screen with unrelated widgets, repeated paths or decoration.
- Author action labels as plain, descriptive text such as `Done` or `Copy
  report and done`. The shared renderer owns the number and selection marker;
  do not add decorative button brackets inside numbered choices. Preserve
  literal brackets in filenames and other captured user data unchanged.
- Ordinary empty results use the shared neutral `picker-empty` role, whose
  default follows the muted palette in both color schemes. Reserve error
  styling for actual failures and preserve public palette overrides. Keep
  empty-state information passive, with no invented candidate or digit.
- Derive acceptance labels from the captured capability actually available.
  For example, Tool explorer offers `read help` for a captured usage guide and
  `inspect` for a missing-help or capture-limit notice. A helper's existence
  alone does not guarantee that its guide was captured. Do not execute or
  recapture providers to decide a footer label during interaction.
- Numbered choice lists use compact, consecutive rows in every tool and view.
  Never insert decorative empty rows, reserve missing-description slots, or
  add a per-tool density mode. A nonblank captured description may occupy one
  subordinate row when twice the configured visible-slot budget fits; that
  row belongs to its candidate and has no index, matching span or arrow stop.
  Keep its selection surface continuous with the parent while its unselected
  text uses the shared muted role. Empty/whitespace-only descriptions add no
  row. Filtering alone must not toggle description eligibility. Short windows
  omit secondary descriptions without losing selectable slots; details remain
  the place for full explanations. Documents, passive information and stacked
  output retain their own semantic reading rows, not decorative choice gaps.
  Keep the shared row renderer, help, showcase and native navigation/resize
  tests aligned with this single rule. Use bottom-body padding to preserve the
  input dock, never inter-option padding to fill available height.
- Treat that optional description row as the option's subtitle: a supported
  part of the shared choice design, not a spacer or a second choice. Use it for
  useful secondary context such as scope, a target summary or the next step;
  do not merely repeat the main label. Supply captured literal text through
  the existing `_ZLE_PICKER_DESCRIPTIONS` capability, not a parallel subtitle
  renderer or new per-tool layout. Align it beneath the option label, fit it
  to one physical line, and retain the parent selection surface and shared
  muted unselected text style. The compact-row eligibility and fallback rules
  above apply. Longer explanations belong in details/readers. Essential safety
  facts must remain in the main label, persistent context or confirmation,
  never only in a subtitle that can disappear in a short window. This item
  subtitle is distinct from the workspace's status and context rows.
- The input dock temporarily splits the captured frame across PREDISPLAY and
  POSTDISPLAY at the query end during paint. Never put the query in the caller's
  BUFFER or change its cursor; restore both display parameters after paint and
  the complete caller editing state on screen exit.
- On the owned full screen, focusing an ordinary inspector at 100 columns or
  wider expands reading width beside a retained navigator (roughly one third,
  at most 42 cells). Returning to results restores the compact preview
  (one third, at most 48 cells). Preserve selection and the source paragraph
  across rewrapping; captured text and its existing 256-row bound stay unchanged.
  Inline fallback retains stable pane widths. Document workspaces already
  prioritize reading and retain their existing geometry and source anchors.
- Navigation strips describe disclosure, not an execution plan. Generic
  choices show Results and only an available inspector; readers show only
  their reading surface. Files → Focused diff → Full file requires the selected
  document's corresponding captured mode. Query, guide and capture states
  replace the map, and narrow screens retain the active stage first. Never
  give these passive labels indexes or reduce result capacity to fit them.
- Treat selection and pane focus as separate state in every split-pane tool.
  Keep the pane title, including a selected file path or Folder summary, in the
  shared heading color and bold style regardless of keyboard focus. Only
  secondary body headings soften while the list is focused; never dim the
  selected target's identity merely because navigation remains on the left.
  List focus uses the normal high-emphasis selected row. Detail/reader focus
  retains that selection with a subdued background and marks the active pane
  with the semantic focus rail plus its `▸` heading. Keep the rail on the shared
  divider so it consumes no body columns and cannot compete with diff rows.
  A focused single-pane detail/reader uses its heading alone; never draw an orphaned
  divider or a full-pane box. Use `picker-selected-inactive` and `picker-focus`
  palette roles rather than embedding terminal escapes or tool-specific colors.
- Full-screen titles use the existing first screen row, without reducing result
  capacity. Hide optional metadata, then branding, before truncating tool identity.
  Reuse semantic title/muted colors. Derive dock action labels from the shared
  capability state (including per-result actions), show keyboard-guide mode,
  and never imply an actionable selection when there is none. Keep title/status
  generation provider-free; inline fallback retains its compact combined header.
- Add only whole shortcut hints that fit. Never truncate the Escape route or
  show half a key sequence to squeeze in optional actions. Tiny terminals may
  use compact Enter/Escape labels. All remaining keys are in the shared guide.
  Enter remains the primary file/link action-menu route. Keep the optional
  context-specific Ctrl-X hint after acceptance, Escape and guide access, ahead of
  convenience shortcuts: it exposes distinct context operations and review views.
  Name its actual destination: `^X review` on Branches and `^X options` for
  filesystem context menus. Document readers expose their available arrow
  disclosure steps and `^R refresh`; add `^X views` only with the explicit Git
  file-view options capability. Other readers keep Ctrl-X inert and omit its hint.
  Derive these hints from the same capability state/transition rules used by
  key dispatch. Do not offer expansion for single-level previews or notices.
  Derive context-menu labels from the existing capability/kind in the shared
  renderer; do not add per-tool key strings or
  remap the shortcut. Keep the guide and public help aligned with that intent.
  Omit it inside secondary action menus where the capability is disabled.
  Do not require a modified shortcut for ordinary file Open/Reveal/Copy/Insert.
- Ctrl-K opens the keyboard guide in the same session. It is scrollable
  and capability-aware. Ctrl-K, Escape, Ctrl-G or Enter returns to the identical query,
  selection, viewport and detail focus; Ctrl-C aborts the session. Text, digits
  and copy keys cannot edit the filter or apply a result while the guide is open.
- Shared keys: arrows/Ctrl-P/N move, Enter applies the displayed action,
  Escape/Ctrl-G cancels or returns from a secondary view, Ctrl-C aborts,
  Ctrl-U clears, Ctrl-W/Option-Delete deletes a word, Fn/Option-Up/Down and
  Ctrl-V/Ctrl-D page up/down,
  Ctrl-Y/Option-W copies when supported, and Tab/Shift-Tab switches detail focus.
  Command shortcuts remain owned by Terminal.app. Primary picker actions must
  work with Control and no profile changes. Escape is cancellation, not a
  human command prefix: allow only a short transport window (currently 20 ms)
  for terminal sequences, never a human-sized chord delay. Ctrl-G has no
  decoding delay. Keep suffix reads bounded and preserve arrows, Shift-Tab,
  forward Delete and bracketed paste. Optional Option-Up/Down and
  Option-V/W/Delete Meta aliases must not increase Escape latency; they depend
  on Terminal's Meta setting. Decode and test both xterm modified arrows
  (`ESC [ 1 ; 3 A/B`) and Terminal.app Meta-prefixed arrows
  (`ESC ESC [ A/B`) as the same Option-Up/Down paging gesture. A second Escape
  may extend transport only when followed by a cursor introducer.
  Modal shortcuts must not rebind normal ZLE editing outside the picker.
  Test the requested read allowance deterministically; measure actual Escape
  latency separately from correctness assertions to avoid scheduler-sensitive tests.
- After recognizing a bracketed-paste opening prefix, retain input ownership
  until its closing marker. Timeout or overflow discards the whole paste in the
  existing screen with bounded suffix storage and visible recovery instructions.
  Cancellation bytes and handled SIGINT are not an exit boundary for incomplete
  paste; restore ordinary cancellation, filter, focus and viewport after
  resynchronization. The modal screen owns SIGINT abort through terminal cleanup,
  then restores caller signal registrations on return. Terminal EOF must exit
  without a busy loop.
  Keep the ordinary short Escape recognition window before prefix recognition.
- Keep task semantics explicit: history, the Tab directory browser and Recents
  insert; `g` switches branch; Files search inserts directories
  and offers explicit file/link actions;
  `compozsh` opens captured help with a printable fallback; Git review acceptance
  drills into files/diffs or focuses reading. Help's explicit Compose action
  follows the separate draft-insertion contract. Shared interaction must never
  turn insertion or a preview into execution. Option-digits apply visible slots only with both filter fields empty
  and list focus; the history picker retains ordinary numeric input.
- The directory browser is the deliberate hierarchy exception: Right/Tab
  enters and Left/Shift-Tab goes Back; Ctrl-E/B focuses preview/list. Its guide
  and footer must use those actual keys. Ctrl-T toggles hidden folders.
  Ctrl-O loads a preview, Ctrl-X opens workspace options, and Ctrl-O in Recents
  opens its selected location for browsing. Plain punctuation and letters filter.
- Folder workspaces compose a captured ancestor trail with the shared list and
  inspector. The trail collapses first (below 120 columns), then the passive
  inspector (below 100). Keep full-width footer hints and selected-row colors
  scoped to the actual list, not the trail. Do not introduce a second renderer.
- Folder previews are explicit shallow name/type snapshots, at most 40 entries
  plus one lookahead, stopped before sorting with native glob qualifiers.
  Describe filesystem-order samples and truncation truthfully. Never read file
  contents, follow child links to enumerate descendants, or load previews from
  movement/filter/resize. Retain only the last requested snapshot per level.
  Explicitly loaded snapshots may use available inspector height; narrow screens
  open them focused. Mounted filesystem calls can still block; do not claim a
  wall-clock bound. Folder enumeration remains outside the active picker loop.
- Empty folders remain navigable; the actions menu offers the current folder.
  No selected child means preview targets the current folder, including when
  a filter hides all directories. Distinguish no child directories, no visible
  entries and a filter with no matches; an empty list is not itself an error.
  Reuse the existing shallow level enumeration for directory/file/other counts
  and at most eight informational non-directory names. Hidden scope and omitted
  names must be clear. Never create fake selectable file rows in a directory
  browser. Escape/Control shortcuts and informational empty-state rows belong
  to the shared renderer/input loop; fallback inspector context is caller-owned
  and must not leak into a secondary action menu or the next tool.
  An explicitly requested current-folder preview has no selected list to share
  space with: open it focused in the full main body, at any width. Ctrl-B restores
  the summary and Ctrl-E returns to the same captured preview. Do not duplicate
  a passive preview beside the same empty-state file sample.
  Copy/insert/reveal run only after cleanup. Reveal requires explicit selection
  and a usable system `open`; pass a literal absolute argument and recheck the
  item. Browse, Search and Recents insert paths by default.
  Folder changes and file actions are explicit. Preserve drafts on copy/cd and
  preserve per-view bookmarks when returning.
- Copy closes after restoring the terminal and leaves unrelated shell state
  alone. Availability hints derive from captured capabilities, with a checked
  failure path if a tool disappears or fails. Never launch applications merely
  to fill a panel.
- For Recents, keep the native stack as the source of truth. Show short names with
  parent context and current/previous cues; match full captured paths. Check
  availability once for at most the first 200 entries when opening, explicitly
  label later metadata as not checked while retaining those paths in search,
  keep missing entries identifiable, and let
  Zsh validate again when the inserted path is submitted at the prompt.
  Explicit browsing is a separate user action;
  ordinary recent-list rendering never enumerates children. Never recursively inspect visited folders,
  invent visit timestamps or persist a second history. Native `dirs -v` retains
  stack indexes; picker digits are visible slots, and details may show `~N`.
- Cover empty/one/many results, duplicate names, long/control-character paths,
  unavailable capabilities, stale entries, guide dismissal, typed digits,
  pane focus and live resize with shared tests plus native PTY interaction.
  Measure complete warm collection/render/paint work and isolated startup.
