# Keyboard and ZLE

Keymap, prompt bindings, input decoding, screen lifecycle and widget hygiene.
What keys *mean* inside workspaces is in the [full-screen key map](full-screen.md#modal-picker-key-map).

## Essentials

- **macOS-native baseline.** Emacs keymap, familiar Control navigation and
  Option-as-Meta word operations. Command-key shortcuts belong to macOS and
  the terminal; Zsh cannot bind them portably.
- **Don't steal editing keys.** Outside a modal picker, never repurpose a
  standard editing key. A wrapped key may add contextual behavior only when its
  fallback exactly preserves the native widget's meaning.
- **One screen owner.** Enter the alternate screen once, restore it on every
  exit, then perform the caller's final action. Never clear the main screen or
  erase scrollback.
- **No leaked bytes.** Escape sequences, Option chords and bracketed paste are
  decoded completely; nothing leaks into the command buffer.
- **Re-source safe.** Re-sourcing never stacks hooks, wraps a widget
  recursively or duplicates definitions and bindings. `exec zsh` remains the
  recommended way to apply changes.

## Keymap and prompt bindings

- Bind terminfo capabilities plus the common normal/application cursor
  sequences so behavior survives Terminal.app, iTerm2, SSH and multiplexers.
- Apple keyboards without Home, End or forward-Delete get first-class
  Control/Option alternatives. Fn-Up/Down is the native page gesture,
  Option-Up/Down its Meta alias inside pickers, and Ctrl-V/Ctrl-D the
  profile-independent fallback.
- Option shortcuts require Terminal's Option-as-Meta setting; document it
  wherever such a key is introduced. Arrows and Enter work without it, and
  automatic prompt behavior never depends on it.

| Key at the ordinary prompt | Widget / behavior | Contract |
| --- | --- | --- |
| Tab | `directory-context-complete`: contextual directory Browse, native completion otherwise | [filesystem](workspaces/filesystem.md) |
| Option-Tab (`ESC TAB`) | `files-recents`: Recents over the directory stack | [filesystem](workspaces/filesystem.md) |
| Ctrl-R | `history-fuzzy-search`: history picker; selection returns the command to the editable line without executing it | [full-screen](full-screen.md) |
| Option-Return (`ESC CR`) | `compozsh-inspect`: Draft inspector | [prompt](prompt.md#draft-inspector) |
| Option-I (`Meta-I`) | `compozsh-context-lens`: toggle the pinned Context lens, preserving draft and cursor; inactive inside modal input | [prompt](prompt.md) |
| Ctrl-F / Right, Option-F, Ctrl-E / End | Accept autosuggestion character, word, all — falling back to the native motion | this contract |
| Up/Down, Ctrl-P/N | Prefix history search | this contract |
| Ctrl-X Ctrl-E | Edit the command line in `$EDITOR` (native widget; the draft passes through a [disclosed temporary file](../SECURITY.md#complete-local-data-inventory)) | this contract |

Leave Ctrl-Tab to Terminal's tab switching, Ctrl-D to native delete/EOF and
Ctrl-X Ctrl-E to command editing.

## Escape and paste decoding

- Escape is cancellation, not a human command prefix: allow only a short
  transport window (currently 20 ms) for terminal sequences, never a
  human-sized chord delay. Ctrl-G has no decoding delay. Keep suffix reads
  bounded.
- Decode standalone Escape, application cursor mode, Shift-Tab, Option chords,
  forward Delete and bracketed paste. Treat xterm modified arrows
  (`ESC [ 1 ; 3 A/B`) and Terminal.app Meta-prefixed arrows (`ESC ESC [ A/B`)
  as the same Option-Up/Down gesture; a second Escape may extend transport only
  when followed by a cursor introducer. Optional Meta aliases
  (Option-Up/Down, Option-V/W/Delete) must not increase Escape latency.
- Read each CSI key through its final byte, one bounded read per byte, then
  dispatch the complete sequence. A complete cursor or function key without a
  meaning in the current view (Left/Right, Home/End or F-keys where the view
  enables none of them) is inert: it may beep, never cancels, leaves the
  fields unchanged and consumes no later key. This is the
  [same key, same action](full-screen.md#essentials) rule; it leaves Escape,
  Ctrl-G and Option-chord cancellation unchanged.
- After a bracketed-paste opening prefix, keep input ownership until the
  closing marker. Timeout or overflow discards the whole paste in the existing
  screen, with bounded suffix storage and visible recovery instructions.
  Cancellation bytes and handled SIGINT do not end an incomplete paste; after
  resynchronization, restore ordinary cancellation, filter, focus and
  viewport. Keep the short Escape window before prefix recognition.
- Terminal EOF exits without a busy loop.
- Test the requested read allowance deterministically and measure actual
  Escape latency separately, so correctness tests aren't scheduler-sensitive.

## Screen session lifecycle

- The shared UI owns a paired native alternate-screen session for every
  picker when terminal output and both terminfo capabilities are available,
  with an inline fallback otherwise.
- Screen ownership is separate from an input loop: hierarchy changes, previews
  and action menus share one session and one nested ZLE. Keep the previous
  frame visible between views; never restore the shell or clear the screen for
  an ordinary transition. Explicit level/preview capture happens outside the
  input loop, with resize guarded during that handoff.
- Enter once, restore in always-cleanup on every exit (accept, cancel, Ctrl-C,
  capture/read failure, abort), and perform final caller actions after
  restoration. The modal screen owns SIGINT through terminal cleanup, then
  restores the caller's signal registrations.
- The session owns its painted frame. Its rows, bars and composed display copy
  labels, inspector, document, query and location text, so the session scopes
  the frame state its views and capture statuses render into and releases it
  on every exit; no painted text outlives the session.
- Full-screen clears are allowed only inside the owned alternate screen.
  Redraw (Ctrl-L) calls builtin widgets only, so a user or plugin
  `clear-screen` widget never runs in the modal session: `.clear-screen` inside
  that screen, an in-place `.redisplay` repaint in the inline fallback.
  Resize goes through a registered ZLE widget; ordinary selection redraws stay
  incremental. That widget can run inside a frame still being laid out or
  painted, so a frame is laid out again before painting whenever the size
  changed during its layout, and the input loop, capture status and paste
  recovery lay out and paint again before waiting for input or starting their
  work whenever it changed during the paint. It also runs while the input
  loop waits in `IFS= read`, so layout, wrapping and painting split label,
  match and syntax span lists on explicit separators, never the ambient
  `IFS`; a wrap cached there must equal an ordinary one.
- Hide the original prompt and multiline draft during the modal session and
  restore their exact editing state on exit. Preserve the living prompt's
  pinned/consumed disclosure state and derive the right compact or lens
  presentation for the restored buffer; a picker transition never becomes a
  transcript receipt. Keep a spare terminal row so the frame never scrolls.
- Test the emitted enter/leave control stream across complete journeys,
  including cancellation, input failures, interrupts and fallbacks.

## Widget hygiene

- Preserve other widgets' `region_highlight`, `PREDISPLAY` and `POSTDISPLAY`.
  Use Zsh 5.9 memo tags to remove only highlights owned here.
- Zsh paints a finished line into scrollback after the line-finish hooks, so
  the editor removes only its own unaccepted suggestion display at every line
  finish: top-level, continuation, nested or without the prompt peer.
- Living-prompt repaint additionally preserves `BUFFER`, `CURSOR`, undo and
  history behavior and the prompt disclosure state.
- Peers that register hooks re-register them in one canonical order so load
  order doesn't change hook sequence.
