# Keyboard and ZLE

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Keyboard and ZLE behavior](#keyboard-and-zle-behavior)

## Keyboard and ZLE behavior

- Use the Emacs keymap as the macOS terminal baseline. Favor familiar Control
  navigation/editing and Option-as-Meta word operations.
- Command-key shortcuts belong to macOS and the terminal application; do not
  pretend Zsh can bind them portably.
- Apple keyboards without physical Home, End, or forward-Delete keys must have
  first-class Control/Option alternatives. Fn-Up/Down remains the native Apple
  page gesture; Option-Up/Down is the matching Meta alias inside pickers, and
  Ctrl-V/Ctrl-D remains the profile-independent fallback.
- Use terminfo capabilities plus common normal/application cursor sequences so
  behavior survives Terminal, iTerm2, SSH, and multiplexers.
- Outside a modal picker, do not steal a standard editing key for unrelated behavior. A wrapped key may
  add contextual behavior only when its fallback exactly preserves the native
  widget's meaning.
- At the ordinary prompt, Option-I (`Meta-I`) is the explicit Context lens
  control and must invoke the `compozsh-context-lens` widget. It toggles only
  the pinned disclosure state, preserves the draft and cursor, and is inactive
  as a prompt shortcut inside modal picker input. Automatic lens behavior must
  not depend on the Terminal Option-as-Meta preference.
- Interactive pickers should consistently support arrows and `Ctrl-P/N`, Enter
  to accept, Escape/`Ctrl-G` to cancel, `Ctrl-C` to abort, `Ctrl-U` to clear,
  and macOS-style Option-Backspace/`Ctrl-W` word deletion. History selection
  must return the command to the editable line without executing it.
- Pickers with visible single-digit indexes may accept an indexed Option-digit
  immediately while the query is empty. Only activate an index that is visibly
  rendered, and preserve plain digits as ordinary search text from the first character.
- Keep the picker viewport separate from the ranked result prefix. Arrows and
  page keys may extend that prefix from already captured in-memory candidates,
  with no provider calls or filesystem traversal. Render only visible rows,
  retain selection on resize, stop at either end, reset to the first match on
  query changes, and release buffered results on exit. Visible digit labels are
  viewport-local slots, never indexes into an unseen result. Distinguish search
  capture limits from the visible row count and advertise remaining results.
- Apply this shared viewport and focused-pane paging contract to every picker:
  history, directory stack, branches, file search, tool discovery, and contextual
  directory completion. New pickers must reuse it. Keep cross-feature coverage
  for collectors extending beyond one screen and for detail panes paging without
  changing the selected result; preserve each caller's action and capture bounds.
- The shared UI peer owns a paired native alternate-screen session for every
  picker when terminal output and both terminfo capabilities are available.
  Keep the inline fallback for unsupported terminals. Screen ownership is
  separate from an individual input loop: directory hierarchy changes, previews
  and folder-action menus share one session and one nested ZLE when needed.
  Keep the previous frame visible between views; never restore the shell or
  clear the screen for an ordinary transition. Explicit level/preview capture
  stays outside the input loop, with resize guarded during that handoff.
  Enter once, restore in always-cleanup on every exit, and perform final caller
  actions after restoration. Test the emitted enter/leave controls across a
  complete journey, including cancellation, capture/read failures and abort.
  Full-screen resize clears are allowed only inside the owned alternate screen;
  never clear the main screen or erase scrollback to hide stale picker frames.
  Preserve the original edit state, use a registered ZLE widget for resize,
  and keep ordinary selection redraws incremental. Cover the emitted control
  stream, input failures, interrupts, and fallbacks with isolated native tests.
- In the owned screen, keep identity at the top and input/action dock anchored
  near the bottom, independent of result count or detail focus. Hide the original
  prompt and multiline draft during the modal session and restore their exact
  editing state on exit. Preserve the living prompt's pinned/consumed disclosure
  state and derive the correct compact or lens presentation for the restored
  buffer; never turn a picker transition into a transcript receipt. Keep a
  spare terminal row to avoid scrolling the frame.
  Workspace padding must preserve alignment of all parallel row metadata.
  Compact inline fallbacks retain their existing layout.
- Optional location/breadcrumb rows are captured caller data, sanitized and
  fitted by the shared renderer. Keep title, location, and filter distinct and
  use one height budget for collection, panels, and footer anchoring; very short
  windows may omit the location. Do not create a parallel navigator renderer.
- Keep picker input on a stable dedicated row, visually distinct from titles,
  counts, and other metadata. Long queries must remain complete internally and
  abbreviate safely for display, with non-color delimiters for accessibility.
- Match emphasis is bounded presentation work on visible result text only.
  Preserve ranking, complete query values, and action values; never evaluate
  user fragments as patterns or code. Reuse the semantic picker palette and
  preserve selected-row contrast. Test literal metacharacters, Unicode, partial
  fragments, and redraws during the input reader's temporary empty `IFS`.
- Contextual directory completion preserves Right/Tab for drill-down and
  Left/Shift-Tab for Back. Keep visibility toggles on modified keys so ordinary
  punctuation remains searchable. Back restores query and viewport and resolves
  selection by literal path in the newly captured parent, with a safe fallback
  if it disappeared. Scope snapshots, visibility, and bookmarks to that picker
  invocation. Read only the explicitly entered, previewed or refreshed level; filtering and
  resizing cannot scan descendants. Clipboard actions run after picker cleanup,
  copy literal absolute paths, and preserve the original editable command.
- Keep printable characters available to picker filtering. Secondary actions
  require non-conflicting modified keys, appear in the footer only when their
  capability exists, and return an action for the caller to perform after ZLE
  cleanup rather than running external commands inside the input loop.
- Optional picker inspectors consume bounded caller-supplied text snapshots.
  Capture trusted same-source help companions or bounded tool metadata before
  entering ZLE; never call tools or providers during selection, scrolling, or
  resize. Reuse existing captured facts where possible. Release snapshots on
  exit, visibly report preview limits, and preserve full-help access. These
  limits are not a sandbox: private help providers obey the static-help contract.
  The caller supplies the panel title and acceptance label; the shared UI peer
  owns layout, focus, scrolling, and capability-aware copy hints. Preserve each
  tool's information hierarchy: optional secondary labels are presentation
  data; exact action values remain untouched. Keep shared
  scope and actions in the header/footer and avoid repeated selection headings.
  Preserve each tool's actual Enter/copy actions. Do not steal hierarchy-navigation
  keys when adding inspectors to directory completion. File panels show captured path
  facts only; content previews require a separate safety and performance design.
  Preserve search and selection across pane focus and responsive layouts, and
  keep numbered selection restricted to visibly rendered list rows.
- Information panels are secondary to the result list. Primary document
  workspaces follow the separate [Git review contract](workspaces/git.md#git-review-workspace-boundary). A caller can opt
  into a reader-only document view with no navigator, selectable candidates,
  result count or digit actions; the Xcode log-reader contract defines its
  captured data and actions. Such a view uses the shared full-width document
  wrapping, source bookmarks, guide and input loop. It keeps focus on reading
  while printable input refines the caller's captured document. Enter, copy,
  refresh and Back remain capability-aware caller requests; Enter, refresh and
  Back still work with zero matching lines. The shared UI peer owns
  one list-first width policy with a bounded reading column; do not restore
  per-tool proportions or give previews the remaining unbounded screen width.
  Keep passive previews compact beside short lists and visually quiet, while
  preserving warning emphasis. Explicit focus may use the available body height
  in the owned screen, without increasing the caller's capture limits.
  Respect both terminal dimensions, preserve visible list capacity, and retain
  the narrow-window focus switch. Test all inspector callers and real resize
  signals; changing layout must not rerun providers or lose the selected value.
- An action workspace is the explicit exception to secondary-preview geometry:
  on an owned screen at least 90 columns wide, use one shared 45%-width choice
  pane capped at 52 columns, with the remaining width for the captured plan.
  The plan may fill the body before focus. Narrow screens retain the shared
  focus switch. Optional descriptive second rows must not reduce visible choice
  capacity, receive digits, change matching or become action values. Use known
  plan labels for emphasis; prose and literal commands remain ordinary text.
- Direct owned help and tool-catalog Enter share a topic workspace over one
  bounded static help capture. The description stays in the context row and
  Overview retains complete captured usage/description. Derive at most 128
  topics from headings and documented argument/mode prefixes, with a Complete
  guide entry preserving unclassified text. Numeric topic IDs are navigation
  targets, never command arguments. Match literal case-insensitive substrings
  in labels/text; do not infer executable semantics or evaluate examples.
  Shared reference geometry gives the explanation primary width from 90 columns,
  with narrow focus switching, without inheriting Git-specific document keys.
  Accent documented arguments in both the topic navigator and explanation,
  including the full-width topic reader, using shared semantic palette roles.
  Derive bounded spans from literal help structure; keep prose neutral and
  do not apply help-specific accents to arbitrary draft or log readers.
  Enter opens a full-width topic reader; Back restores topic position, then
  the catalog bookmark without recapture. Direct help captures at most 32,768
  characters with a partial notice; pipe it for the complete printable guide.
  An additional Compose example action requires an explicit trusted command
  identity and its same-source template capability. Label that handoff and its
  editor effect separately from ordinary topics. It opens the composer and
  returns to the same help bookmark on cancellation; it never parses or runs
  example prose. Only explicit Replace draft may leave help with an insertion
  request, applied after screen restoration. Do not expose it in plain output
  or infer authority from the usage line of arbitrary captured text.
  Static text readers filter literal lines case-insensitively,
  retain no selectable rows, and scope their text/frame/source maps on exit.
  History's optional inspector reads at most 32,768 characters of the exact
  captured candidate; acceptance still inserts its complete value. All preview
  bounds and truncation must remain visible and documented.
- File search selection is type-aware: ordinary directories insert an editable
  path; files and symbolic links require an explicit action picker. Keep action dispatch
  outside ZLE, recheck mutable filesystem facts, pass literal absolute paths
  as arguments, and never execute a selected path as shell code. Opening an
  application is an explicit user action, not a preview. Secondary pickers
  reuse the shared engine and return to a caller-owned query/selection/viewport
  bookmark without recapturing providers. Action labels are captured display
  data; never call filesystem or application providers while rendering them.
- Escape-sequence parsing must handle standalone Escape, application cursor
  mode, Shift-Tab, Option chords, forward Delete, and bracketed paste without
  leaking bytes into the command buffer.
- Preserve other widgets' `region_highlight`, `PREDISPLAY`, and `POSTDISPLAY`
  state. Living-prompt repaint must additionally preserve `BUFFER`, `CURSOR`,
  undo/history behavior and prompt disclosure state. Use Zsh 5.9 memo tags to
  remove only highlights owned here.
- Re-sourcing must not stack hooks, wrap a widget recursively, or duplicate
  widget definitions/bindings. A fresh `exec zsh` remains the recommended way
  to apply changes.
