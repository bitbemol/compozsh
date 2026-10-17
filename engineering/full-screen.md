# Full-screen workspaces

The shared interaction system behind every Compozsh picker and workspace.
Transitions follow [context-preserving composition](interaction-design.md#context-preserving-composition);
input decoding and screen lifecycle follow [keyboard and ZLE](keyboard-zle.md).

## Essentials

- **One system.** Every tool uses the shared `support/ui` renderer, input
  loop, guide and cleanup. Callers supply captured content, capabilities and
  the meaning of acceptance. Never fork a renderer, key parser or hand-written
  shortcut bar for one tool.
- **Same key, same action.** A missing capability leaves its key inert and
  hides its hint; never repurpose it for an unrelated per-tool action.
- **Numbers mean actions.** Only actionable candidates get `[n]` and a
  selection stop; everything informational is passive.
- **Interaction never discovers.** Paint, filter, scroll, focus, resize and
  the guide use captured facts only — no provider calls, subprocesses or
  filesystem reads.
- **Exact values stay exact.** Display labels may be sanitized and
  abbreviated; action values never are.

The design draws on HCI guidance — [recognition over recall](https://www.nngroup.com/articles/recognition-and-recall/),
[consistency](https://www.nngroup.com/articles/consistency-and-standards/),
[progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/)
and Apple's [focus guidance](https://developer.apple.com/design/human-interface-guidelines/focus-and-selection) —
as motivation, not proof that a given ratio or key is optimal. Validate with
behavior tests and user feedback.

## Regions

| Region | Contract |
| --- | --- |
| Title bar | Stable tool identity left; quiet right-aligned COMPOZSH branding when space permits, or captured busy status. Uses the first screen row without reducing result capacity; hide optional metadata, then branding, before truncating identity |
| Status | Separate, quieter snapshot/result status; scope stays visible while filtering |
| Context | One location/source row, sanitized and fitted by the renderer, omitted only in very short windows. Title, location and filter stay distinct and share one height budget |
| Input | Bottom dock above the footer on usable full screens, with the real ZLE caret at the literal query end, labeled with the operation (`Filter folders`, `Search descendants`, `Filter results`). Inline and very short fallbacks keep top input |
| Navigation strip | Passive disclosure map in the separator row: current focus highlighted, a whole next-gesture hint when it fits, stages derived from current capabilities (never from a tool name). Query, guide and capture states replace it; narrow screens show the active stage first |
| Main body | Pickers prioritize results; document workspaces prioritize the selected document beside a stable navigator |
| Details / reader | Secondary information or a primary document; explicit focus, independent scroll, no provider calls during repaint |
| Footer | Emphasized real acceptance action, Escape, then at most five complete capability hints (rules below) |

- Preserve spatial landmarks when results shrink; blank space is fine. Don't
  fill the screen with unrelated widgets, repeated paths or decoration.
  Identity stays at the top and the input/action dock near the bottom,
  independent of result count or focus. Workspace padding keeps parallel row
  metadata aligned.
- One frame uses one width: the renderer captures `COLUMNS` once and passes it
  to the trail, navigation strip, guide and footer. Resize timing is in
  [keyboard and ZLE](keyboard-zle.md#screen-session-lifecycle).
- The navigation strip describes disclosure, not an execution plan: generic
  choices show Results plus an available inspector; readers show only their
  reading surface; Files → Focused diff → Full file requires the selected
  document's captured mode. Its labels never get indexes or reduce result
  capacity.
- The input dock splits the captured frame across `PREDISPLAY` and
  `POSTDISPLAY` at the query end during paint. The query never enters the
  caller's `BUFFER` or moves its cursor; both display parameters and the full
  caller editing state are restored.
- Long queries stay complete internally and abbreviate safely for display,
  with non-color delimiters.
- Title/status generation is provider-free; the inline fallback keeps its
  compact combined header.

## Actionable rows and passive content

The visible `[n]` prefix is reserved for actionable candidates: directories,
files, menu operations or other exact values the input loop can select and
accept. `[n] some text` promises that the row participates in selection and
that Option plus its digit chooses it whenever digit selection is active.

Information-only text must use passive rows, status/context regions, or
details/reader content. It must not enter the result/candidate array, receive
a selection cursor or highlight, become an arrow stop, or acquire a digit or
acceptance action. On a screen with one action such as **Done** followed by an
explanation, index only **Done** and render every reason, warning, statistic
and recovery instruction as passive content. Shared UI tests cover both
candidate membership and rendered indexes.

## Modal picker key map

These are Compozsh controls, not claims about macOS-wide standards.

| Key | Shared meaning |
| --- | --- |
| Escape / Ctrl-G | Cancel, or return from a secondary view |
| Ctrl-C | Abort the interaction; the command returns 130 |
| Enter | Apply the visibly named primary action |
| Ctrl-K | Open/close the keyboard guide |
| Up/Down, Ctrl-P/N | Move results or scroll the focused view |
| Fn/Option-Up/Down, Ctrl-V/Ctrl-D | Page the focused view; reader pages keep one overlapping line |
| Ctrl-U / Ctrl-W, Option-Delete | Clear the active field / delete its last word |
| Ctrl-] | Reveal exclusion and switch positive/exclusion field editing |
| Backspace | Delete the last character of the active field |
| Ctrl-Y, Option-W | Copy the selected value and close, when available |
| Ctrl-L | Redraw |
| Ctrl-F | Start descendant discovery in Browse; edit the discovery query in Search results |
| Ctrl-E / Ctrl-B | Focus details / list, when available |
| Tab / Shift-Tab | Switch list/details focus; in the directory browser, enter / go Back |
| Ctrl-O | Inspect a folder: browse from Recents, preview inside the browser |
| Ctrl-X | **review** on Branches, **options** in filesystem/worktree views, **View options** in Git file review; otherwise inert |
| Right / Left in a document workspace | Disclose files → focused diff → full-file context, and reverse; on a folder summary, focus it / return to the list |
| Ctrl-A in an auto-refresh document workspace | Pause/resume automatic refresh for this screen session |
| Ctrl-R in a refreshable workspace | Refresh captured choices or document, keeping available selection, focus and source anchor |
| Ctrl-T | Toggle hidden folders in the browser |

- Printable characters always reach the filter, so secondary actions use
  non-conflicting modified keys. Primary actions work with Control keys and no
  profile change; Option aliases depend on Terminal's Meta setting. Modal shortcuts never rebind
  ordinary ZLE editing outside the picker.
- The directory-browser hierarchy keys, document disclosure/refresh and Ctrl-O
  contexts are the explicit exceptions — not permission for per-tool
  remapping. Keep the actual action visible in footer and guide.
- Ctrl-R refreshes only views exposing the shared refresh capability, and stays
  available with empty or filtered-out lists; other pickers keep prompt
  history search and the next-result alias. Ctrl-A stays beginning-of-line at
  the prompt and is advertised only where automatic refresh exists.
- Before adding a key, check this map, normal shell editing, Terminal.app
  interception and control-byte collisions (Tab/Ctrl-I, Enter/Ctrl-M,
  flow-control keys); prefer an existing action or menu. A key-map change
  updates this table, the shared handler, hints, guide, public help, README and
  PTY tests together, with coverage across history, Recents, branches, files,
  tool discovery and secondary menus.

## Filters and exclusion

- Candidate filters have a positive field and an optional exclusion field.
  Ctrl-] reveals and switches between them; both stay active with a visible
  focus marker and literal input. Once revealed, the exclusion row stays
  visible, including in narrow/inline fallbacks. Ctrl-U, Ctrl-W, Backspace and
  paste edit only the focused field.
- Changing either value resets the result position; switching fields alone
  doesn't. Back restores both values, field focus/visibility and the bookmark.
  Secondary views start with independent fields.
- Plain digits always edit text, including as the first character.
  Option-digit acceptance requires both fields empty, the positive field
  active and list focus. History keeps numeric typing with no slot shortcuts.
- Exclusion is one case-insensitive literal phrase matched against the view's
  complete searchable text. It keeps the positive matching policy, duplicate
  policy and ordering (including history's conditional fuzzy fallback) and is
  applied before retained result-prefix limits. The calculation is pure;
  shared UI state lives in the adapter. Authored text, confirmations, notices
  and document-only readers don't advertise exclusion; missing matching
  support leaves the key inert.
- Match emphasis is bounded presentation over visible text only: it never
  changes ranking, query values or action values, and never evaluates user
  fragments as patterns or code. It reuses the semantic picker palette and
  keeps selected-row contrast. Test literal metacharacters, Unicode, partial
  fragments and redraws during the input reader's temporary empty `IFS`.

## Results and viewport

- Keep the viewport separate from the ranked result prefix. Arrows and paging
  may extend the prefix from already captured candidates, with no provider
  calls or traversal. Render only visible rows, keep selection on resize, stop
  at either end, reset to the first match on query change, and release
  buffered results on exit.
- Visible digits are viewport-local slots, never indexes into unseen results.
  Distinguish capture limits from the visible row count and advertise
  remaining results.
- Every picker uses this contract — history, directory stack, branches, file
  search, tool discovery, contextual completion — and each caller keeps its
  own action and capture bounds. Keep cross-feature coverage for collectors
  extending past one screen and for detail panes paging without changing the
  selection.

## Choice rows

- Numbered choices are compact, consecutive rows in every tool and view: no
  decorative empty rows, reserved description slots or per-tool density mode.
  Bottom-body padding preserves the input dock; never pad between options.
- A nonblank captured description may add one subordinate row — the option's
  subtitle — when twice the configured visible-slot budget fits. It belongs to
  its candidate: no index, matching span or arrow stop, a selection surface
  continuous with the parent, shared muted text when unselected. Empty
  descriptions add no row; filtering never toggles eligibility; short windows
  drop subtitles before selectable slots.
- Use the subtitle for useful secondary context (scope, target summary, next
  step), not a repeat of the label. Supply it through
  `_ZLE_PICKER_DESCRIPTIONS`, aligned under the label and fitted to one line.
  Essential safety facts belong in the label, persistent context or
  confirmation — never only in a subtitle that can disappear.
- Action labels are plain text such as `Done` or `Copy report and done`; the
  renderer owns the number and selection marker, so no decorative brackets.
  Literal brackets in filenames and other user data stay unchanged.
- Ordinary empty results use the neutral `picker-empty` role (muted in both
  schemes); error styling is for real failures. Empty-state information is
  passive.
- Acceptance labels derive from the captured capability: for example Tool
  explorer offers `read help` for a captured guide and `inspect` for a
  missing-help or capture-limit notice. Never execute or recapture a provider
  to choose a footer label.

## Footer and keyboard guide

- The footer shows the emphasized acceptance action, Escape, then whole hints
  that fit. Reserve the final `^K all keys` hint first, then prioritize the
  filter/exclusion toggle, an explicit Option-number hint, then secondary
  actions. Never truncate the Escape route or show half a key sequence. Tiny
  terminals may use compact Enter/Escape labels; narrow fallbacks shorten whole
  labels before dropping guide access.
- The context-specific Ctrl-X hint comes after acceptance, Escape and guide
  access and names its destination: `^X review` on Branches, `^X options` for
  filesystem menus, `^X views` only with the Git file-view capability. Readers
  show available arrow disclosure steps and `^R refresh`; others keep Ctrl-X
  inert and hide it. Derive hints from the same capability state as key
  dispatch, including per-result actions; never imply an actionable selection
  when there is none, and don't offer expansion for single-level previews.
- Ordinary file Open/Reveal/Copy/Insert never require a modified shortcut;
  Enter remains the file/link action-menu route.
- Ctrl-K opens the guide in the same session; it scrolls, is
  capability-aware, lists every applicable key and ends with `^K close`.
  Ctrl-K, Escape, Ctrl-G or Enter return to the identical query, selection,
  viewport and focus; Ctrl-C aborts. While it's open, text,
  digits and copy keys don't edit the filter or apply a result, and it never
  triggers refresh or a provider check. Key and fact labels use the heading
  style, descriptions ordinary text, notes muted text; emphasis is clipped to
  the visible row and passive labels never get numbers. Caller-supplied
  context lines arrive as raw captured facts; the guide sanitizes and fits
  them like every other row and paints them as unemphasized literal text.

## Selection and focus

- Selection and pane focus are separate state in every split-pane tool.
- Pane titles — including a selected file path or Folder summary — keep the
  heading color and bold regardless of focus; only secondary body headings
  soften while the list is focused.
- List focus uses the high-emphasis selected row. Detail/reader focus keeps
  the selection with a subdued background and marks the active pane with the
  semantic focus rail on the shared divider (consuming no body columns) plus
  its `▸` heading. A focused single-pane reader uses only its heading — no
  orphaned divider or full-pane box. Use the `picker-selected-inactive` and
  `picker-focus` palette roles, never embedded escapes or tool colors.
- Search and selection survive pane focus changes and responsive layouts.

## Inspectors and readers

- Optional inspectors show bounded caller-supplied snapshots (at most 256
  wrapped rows) captured before entering ZLE: trusted same-source help
  companions or bounded tool metadata. File panels show captured path facts
  only; content previews need their own safety and performance design.
  Never call tools or providers during selection, scrolling or resize. Release
  snapshots on exit, report preview limits visibly, and keep full-help access.
  These limits are not a sandbox; private help providers follow the
  static-help contract.
- The caller supplies the panel title and acceptance label; the shared UI owns
  layout, focus, scrolling and capability-aware copy hints. Keep scope and
  actions in header/footer rather than repeated selection headings, and keep
  each tool's real Enter/copy actions.
- Inspectors are secondary to the list, under one list-first width policy
  with a bounded reading column; no per-tool proportions. Passive previews
  stay compact and quiet beside short lists, keeping warning emphasis. At 100
  columns or wider, focusing an inspector widens reading beside a retained
  navigator (about one third, at most 42 cells); returning to results
  restores the compact preview (one third, at most 48 cells). Selection and
  source paragraph survive rewrapping; captured text keeps its existing row
  bound. Narrow windows keep the focus switch; inline fallback keeps stable
  widths. Explicit focus may use the available body height without raising
  capture limits.
- A caller may opt into a reader-only document view: no navigator, selectable
  candidates, result count or digit actions. It uses shared full-width
  wrapping, source bookmarks, guide and input loop; printable input refines
  the captured document; Enter, copy, refresh and Back are capability-aware
  caller requests that still work with zero matching lines. Static text
  readers filter literal lines case-insensitively and release their maps on
  exit.
- Primary document workspaces follow the [Git review contract](workspaces/git.md#git-review-workspace-boundary).

## Action workspaces

On an owned screen at least 90 columns wide, an action workspace uses one
shared choice pane of 45% width capped at 52 columns; the captured plan takes
the rest and may fill the body before focus. Narrower screens keep the focus
switch (Ctrl-E/Right or Tab to the plan, Ctrl-B/Left back). Descriptive second
rows never reduce visible choice capacity, receive digits, change matching or
become action values. Known plan labels may be emphasized; prose and literal
commands stay ordinary text. Files actions, Git review/comparison and worktree
setup, Xcode actions and log options, and external-device review share this
presentation while keeping their own capture, action and confirmation rules.

## Help topic workspace

Direct owned help and tool-catalog Enter share a topic workspace over one
bounded static help capture.

- The title names the catalog tool or owned command (subcommand help keeps
  its usage line's command word), never missing-help or preview-limit notice
  prose; the topic reader extends that title.
- The description stays in the context row; Overview keeps the complete
  captured usage and description. Derive at most 128 topics from headings and
  documented argument/mode prefixes, plus a Complete guide entry for
  unclassified text. Topic numbers are navigation targets, never arguments.
- Matching is literal, case-insensitive substrings over labels and text; never
  infer executable semantics or evaluate examples.
- From 90 columns the explanation gets primary width; narrower windows switch
  focus. It doesn't inherit Git document keys. Documented arguments are
  accented in navigator, explanation and full-width reader using shared
  palette roles and bounded spans from literal help structure; prose stays
  neutral, and help accents never apply to arbitrary draft or log readers.
- Enter opens a full-width topic reader; Back restores the topic position,
  then the catalog bookmark without recapture.
- Direct help captures at most 32,768 characters with a visible partial
  notice; piping prints the complete guide. History's optional inspector reads
  at most 32,768 characters of the exact candidate, while acceptance still
  inserts the complete value.
- Compose example requires an explicit trusted command identity and its
  same-source template capability, labeled separately from topics. It opens
  the [composer](prompt.md#command-composer), returns to the same help
  bookmark on cancel, and never parses or runs example prose. Only explicit
  Replace draft leaves help with an insertion request, applied after screen
  restoration. It never appears in plain output or derives authority from an
  arbitrary usage line.

## Task semantics

Keep each tool's acceptance explicit: history, the directory browser and
Recents insert; `g` switches branch; Files search inserts directories and
offers explicit file/link actions; `compozsh` opens captured help with a
printable fallback; Git review drills into files and diffs or focuses reading;
bare `external-device` selection reads no provider and dispatches its task
after screen restoration. Help's Compose action follows the draft-insertion
contract. Shared interaction never turns insertion or a preview into
execution.

Every entry reports one status vocabulary. The shared run returns 0 for an
accepted choice, 1 for a cancel (Escape or Ctrl-G), 130 when Ctrl-C aborts the
screen and 2 when the nested editor fails; the screen session records the
abort, whether it arrives as SIGINT or as the byte the loop reads, and the run
ends the interrupt after cleanup. Public commands pass 130 and 2 through
unchanged and no peer maps Ctrl-C privately; a cancelled workspace normally
returns 0, usage errors stay 2 and a chosen action keeps its own status.

## Testing

Cover empty, one and many results, duplicate names, long and control-character
paths, unavailable capabilities, stale entries, guide dismissal, typed digits,
pane focus and live resize with shared tests plus native PTY interaction, and
exercise every inspector caller when inspector layout changes.
Measure warm collection, render and paint work and isolated startup.

## Retired decisions

- Per-tool style switches, density modes and superseded visual flows — the
  shared design is the baseline for every tool.
- Hand-written per-tool shortcut bars and key parsers in collectors or tool
  providers.
