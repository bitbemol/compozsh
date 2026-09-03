# Shared terminal components and view interfaces

Date: 2026-09-03.
Status: implemented; final validation evidence appears below.

This extends the [palette ownership design](palette-ownership-design.md).
The approved appearance, key map, task scopes and action policies are the
behavioral baseline. In the repository glossary, the terminal “windows” are
views within a screen session; reusable components compose those views.

## Decision

Extract the existing shared terminal interaction implementation from
`.zsh.editor` into a focused `support/.zsh.ui` peer. Reuse that implementation
and give recurring view compositions a small internal interface. Feature peers
supply captured content, capabilities and operation intent; they retain their
providers, matching semantics, controllers and actions.

“Pluggable” means a feature can use an available component at invocation time.
It does not mean loading a file each time a view opens, discovering components
inside projects, registering plugins, or adding a lifecycle manager. The normal
bootstrap continues discovering peers in any order.

The palette and UI files live in `.zsh.addons/support/` as maintained shared
implementations. Keep them installed when selecting features; customize public
settings in the machine-local initializer. This folder changes placement and
ownership guidance without introducing a load phase or removing standalone
fallbacks.

There is one owner per responsibility:

| Owner | Responsibility |
| --- | --- |
| `support/.zsh.appearance` | Authored light/dark roles and variants |
| `support/.zsh.ui` | Shared components, layout, frame composition, input loop, guide, painting and guaranteed screen restoration |
| `.zsh.editor` | Normal command-line editing, completion, autosuggestions and existing history/filesystem entry behavior |
| Feature peers | Source capture, task meaning, exact targets, view transitions, final validation and actions |

These are runtime collaboration boundaries between ordinary peers, not loader
tiers. UI requires native Zsh/ZLE capabilities, while appearance and normal
editor customization remain optional. Move the existing implementation instead
of maintaining a second renderer or a compatibility copy.

## Existing shared implementation

Before extraction, `.zsh.editor` owned `_zle_picker_titlebar`,
`_zle_picker_footer`, `_zle_picker_guide_render`, `_zle_picker_trail_render`,
`_zle_picker_inspect_render`, `_zle_picker_render`, `_zle_picker_show`,
`_zle_picker_loop`, `_zle_picker_screen_session` and `_zle_picker_run`.
Git review, worktrees, navigation, Xcode, USB and tool discovery already reuse
these mechanisms. Their implementations and state now live only in
`support/.zsh.ui`.

Repeated view setup was present in `_xcode_choose`, `_usb_choose`,
`_git_worktree_pick` and the corresponding query/notice/result functions.
Those callers repeatedly configured title, context, query label, detail text,
acceptance labels, disabled capabilities and view-local arrays.

Some similar-looking code protects different behavior. Xcode's collector uses
ordered subsequence matching; USB additionally ranks literal prefix and
substring matches first. Shared presentation must preserve that distinction.
Git source anchors, filesystem hierarchy and Xcode log-following also remain
task-specific inputs or controllers rather than one generic workflow.

## Presentation, interaction and effects

The complete UI cannot be read-only: it changes selection, focus and scroll
position and writes to the terminal. Use three explicit boundaries:

1. **Frame construction:** derive text, semantic role spans and layout from
   captured view state, supplied dimensions and effective palette roles. It
   performs no provider discovery, process launch or terminal painting.
2. **Shared interaction:** own keyboard decoding, selection/focus, viewport,
   bookmarks, resize, frame painting and restoration. Return operation requests
   to the feature controller, preserving exact candidate identity.
3. **Feature effects:** capture or refresh facts, resolve mutable targets and
   execute visibly requested effects under each tool's existing contract.

Frame construction may fill scoped output arrays; the existing global-output
helpers are not automatically pure functions. Keep their scratch/output state
explicit and test that rendering has no external effects. Avoid a purity claim
that the native implementation does not establish.

The shared `_zle_picker_capture` helper paints and invokes a provider callback;
it is an effectful orchestration boundary, not a passive component. Likewise,
Xcode's existing idle callback drains already authorized bounded streams. Keep
such calls in explicit controller/input-loop hooks, outside frame construction
and resize. This extraction authorizes no new capture, process or timer.

Ordinary insertion, copy, navigation, application launch, build and destructive
actions retain their existing post-screen-cleanup boundary. Existing run-scoped
observers retain their separate lifecycle and cleanup ownership. Enter means
the operation currently advertised by the feature; the UI never infers that a
selected string should be executed.

## Component vocabulary

Start with the components already represented by the implementation. These are
cohesive helpers inside the UI peer, not individual peer files.

| Component | Inputs and responsibility |
| --- | --- |
| Title/status/context | Tool identity, scope, captured status, action/focus labels; shared hierarchy and truncation |
| Query/filter field | Literal text and an explicit purpose label; visibly distinguish submission from refinement |
| Result list | Exact candidate values, plain labels, semantic spans, selection and viewport; one numbering/focus contract |
| Details pane | Already captured text for the selected target; its own reading position and optional focus |
| Document reader | Captured source lines, roles, anchors, optional syntax spans and bookmark; wrapping and reading navigation |
| Ancestor trail | Captured location labels; common collapse/layout behavior without filesystem discovery |
| Passive notice/status | Informational lines and severity roles; no fake candidates or digits |
| Footer and keyboard guide | Existing capability state and operation labels; one source for visible hints and key behavior |

Compose these into the existing recurring views:

- Choice list, optionally paired with details.
- Literal query entry, whose acceptance returns text for explicit discovery.
- Document workspace with a navigator, or a full-width reader.
- Notice/result view with passive information and separately identified actions.
- Status view showing a captured progress/result snapshot and only the controls
  allowed by its caller.

Implement a view helper only where repeated setup or an invariant justifies it.
Do not add speculative controls, resizable floating windows, nested independent
screen owners, a widget tree, or arbitrary window-layout configuration.

## Interface and state contract

Use native Zsh functions, arrays and invocation-scoped variables. Begin with the
existing `_ZLE_PICKER_*` inputs and operation/bookmark outputs; moving ownership
does not require renaming every private identifier in the same change.

The logical contract is:

```text
Feature provides:
  context + captured candidates/document + labels + capabilities + bookmark
Shared view returns:
  operation request + exact selected value (if applicable) + updated bookmark
Feature controller decides:
  another view, explicit capture, cancellation, or validated post-cleanup action
```

This is an interface description, not a mandatory record or serialization
format. Preserve the established status distinctions and action identifiers;
do not introduce a universal success/cancel enum that changes callers' meaning.
Keep inputs limited to fields used by that composition. Shared helpers own
common defaults and reset rules, while features own task content and overrides.

Collectors continue filtering/ranking captured candidates under their existing
matching contracts. They may not discover more providers from a renderer or
repaint. Internal callbacks are fixed functions supplied by trusted code, with
capability checks and explicit effect contracts; names never come from labels,
paths, project metadata or a runtime component registry.

Keep large snapshots caller-owned and use existing scoped access instead of
copying entire documents for every component or paint. A helper's `local`
variables disappear when it returns: a common setup helper must not pretend to
declare locals for its caller. Put view-local defaults around the actual view
execution, with output/bookmark capture before that scope exits. Preserve the
existing small bookmark mechanism instead of serializing all UI globals.

Selecting another composition resets unrelated fields. A query view must not
inherit a reader's follow mode, copy capability or hidden inspector content;
returning to the reader restores its own bookmark. Multiple views reuse one
screen session, with the same acceptance/cancellation and restoration behavior.

These interfaces initially remain private implementation contracts. A future
public component API for machine-local peers would need a separately documented
signature and compatibility commitment; examples must not present private
helpers as supported public extension APIs.

## Loading and standalone behavior

Each peer installs only its own functions, state and registrations. Feature
widgets and commands check the UI capability when invoked. They neither source
the UI themselves nor call another peer during setup. Appearance is consulted
at runtime, retaining the palette design's neutral fallback.

The UI peer owns `compozsh-picker`, `compozsh-picker-redraw`, its nested-ZLE
entry hook and screen lifecycle. Editor retains normal key bindings and
autosuggestion hooks. Audit their current interaction explicitly: editor
previously registered `_zle_picker_line_init`, and screen ownership temporarily
suspends autosuggestions. UI now registers `compozsh-picker-init` and invokes
it through native `vared -i`; it needs no global editor line-init hook.
No second hook coordinator or source-time cross-peer helper call is needed.

Without UI, commands retain their existing plain fallback or a concise
unavailable message. Normal completion/history bindings must fall back to
native ZLE behavior instead of invoking an undefined UI function. Without
editor, UI-backed direct commands must still be able to use the UI's own
nested-ZLE entry and cleanup. Readable neutral UI remains available without
appearance. These combinations require tests rather than an assumption that a
file move preserves optional-peer behavior.

## Sequencing and validation

1. Finish palette centralization as a separate coherent change, preserving the
   approved colors. UI components then consume those roles without embedding
   their own palette values.
2. Characterize the existing screen journeys and representative frames. Add
   failing tests for any proposed new ownership, missing-peer or shared-default
   behavior before implementation; preserve existing green behavioral tests
   for a mechanical extraction.
3. Move the shared UI as one cohesive ownership change, including its state,
   registrations and cleanup. Keep history/filesystem providers and task
   controllers outside generic component code. Do not split every helper into
   another peer or combine this with a broad identifier rename.
4. Consolidate repeated view setup, starting with choice/details views and
   query/notice views. Migrate one representative pair of callers at a time;
   preserve their matching, scope, action labels and return behavior.
5. Update README inventory/layout and optional-peer guidance, relevant help,
   `SECURITY.md` pointers and `AGENTS.md`'s shared-editor ownership wording in
   the implementation change. The current contracts remain authoritative until
   that change exists.

Acceptance evidence must cover:

- Identical normal-installation colors, layout priorities, labels and actions;
  the existing palette contrast gates remain in force.
- Normal/reverse/rotated source order, re-sourcing, missing UI/editor/appearance
  and optional provider peers, hook/widget convergence and direct/widget entry.
- Native PTY empty/long/Unicode/control-character content, selected/inactive
  panes, narrow/tall/short resizing, guide dismissal, bracketed paste, Escape,
  Ctrl-C and terminal/read failures, with exact draft/cursor restoration.
- Sequential tools and nested views with different capabilities, including
  reader → query/options → reader, to detect state leakage and lost bookmarks.
- No provider reads during frame construction or resize; no clipboard,
  filesystem or process action caused by a component accepting a label.
- Existing Git comparison/disclosure, files Browse/Search/Recents, worktree,
  history, tool explorer, Xcode result/log and USB confirmation journeys.
- The full native suite, syntax/diff checks, security/documentation contracts,
  shipped-peer inventory and symlink/copy installation discovery checks.
- Interleaved startup and complete collection/render/paint measurements against
  the pre-extraction tree, distinguishing warm and captured-data workloads.
  No new per-row dispatch, full-snapshot copying, subprocess or background work.

## Implemented interfaces

`_zle_ui_view kind callback [arguments ...]` scopes common configuration around
a fixed, capability-checked feature callback. Supported compositions are
`choice`, `notice`, `query`, `document`, `reader` and `status`. The callback
supplies content/capabilities and enters the shared loop or capture boundary.
Operation, selection and bookmark outputs deliberately survive the scope;
large provider/document snapshots remain caller-owned.

History, tool discovery, branch choices, worktree choices/text, comparison
choices/text/options, descendant-search entry, USB choices/text/status and
Xcode choices/results/run/log readers now reuse these defaults. Git comparison
maps and USB passive result rows are explicit feature inputs. Xcode saves
filter, following state and source bookmarks before its scoped callback exits.

The Files hierarchy and Git document controllers keep their existing explicit
state composition: they intentionally inherit workspace capabilities and own
cross-view transitions. They consume the same extracted components, renderer,
input loop and screen owner. The directory entry controller also preserves the
caller's `AUTO_CD` option before applying local shell options. Forcing these
controllers through a blanket reset would change their task behavior.

The UI owns all shared title/context, query, result, details, document, trail,
notice/status, footer/guide and keyboard/screen components. Normal editor hooks,
providers, matching, task labels, final validation and actions retain their
feature owners. There is no public component API or required loader tier.

## Validation evidence

The initial extraction passed **508 tests, 0 failures**. The subsequent
[independent review](ui-extraction-review.md) records additional edge-case fixes
and final verification. Syntax checks, diff
whitespace checks, isolated bootstrap double sourcing, standalone peers,
symlink/copy installation discovery and the README peer inventory pass. The
dedicated convergence matrix covers four orders × both schemes × default and
custom overrides, comparing initial and double-sourced state in each case.
The pre-extraction tree was captured before moving code; intermediate suite
runs against a changing tree were diagnostic only.

The screen PTY fixture now sources UI with neither editor nor appearance,
covering native entry and cleanup independently. Existing native journeys
exercise palette-driven frames, pane focus, narrow/short resize, selection,
Escape/Ctrl-C, paste and terminal restoration. Focused new contracts cover
source ownership, missing UI fallbacks, sequential view isolation, returned
operations and bookmarks, passive rows, semantic overlays, deferred completion
and native output absence.

Review caught and fixed explicit empty syntax overrides acquiring a fallback,
native completion bypassing its registered widget, prior-reader capabilities
leaking into new choices, and USB matching returning failure after removal of
its old numbering loop. Focused regression tests retain those contracts.

## Measured performance

Observed on macOS 27.0, arm64, stock `/bin/zsh` 5.9. Five interleaved batches
compare frozen public configuration before extraction and the final tree in
isolated homes, with fixed terminal/locale and no private configuration.
Startup uses eight warm starts per batch after priming completion. Frame,
prompt and view measurements use 100 iterations per batch. The table reports
medians in milliseconds; these observations are not compatibility thresholds.

| Workload | Dark before → final | Light before → final |
| --- | --- | --- |
| Warm bootstrap | 54.66 → 54.62 | 55.36 → 54.61 |
| 10-row metadata frame, active selection | 4.414 → 4.468 | 4.444 → 4.494 |
| 10-row metadata frame, inactive selection | 4.427 → 4.481 | 4.433 → 4.447 |
| Diff frame, 198 visible syntax spans | 8.030 → 7.123 | 8.084 → 7.189 |
| Prompt outside Git | 0.256 → 0.325 | 0.256 → 0.322 |
| Prompt in an empty Git repository | 24.92 → 24.36 | 24.50 → 24.43 |
| Choice entry with 1,000 captured refs | 0.030 → 1.186 | 0.030 → 1.188 |

These initial extraction measurements precede the independent review fixes.
Frame workloads call `_zle_picker_render` and `_zle_picker_show`; native
`zle -R` is stubbed, so timings exclude physical terminal painting. Metadata
uses 120×30 geometry with five semantic spans per row. The 120×40 diff uses
100 captured lines with six lexical spans each, displaying 198 spans. Prompt
timing covers `_prompt_update` and prompt expansion. Choice entry stubs only
the input loop to isolate configuration and captured-map setup.
Frame views are pre-rendered and keep selection, content and geometry stable;
these are warm repeated-frame measurements, excluding first wrapping,
selection-to-preview latency and resize rewrapping.

Central role lookup adds about 0.07 ms to the non-Git prompt. Explicit view
scoping adds about 1.16 ms for the largest ref-choice fixture, once per entry;
documents are not copied for each frame. Both costs preserve the intended
interactive behavior. Startup and ordinary metadata frames remain comparable.

The first shared overlay implementation increased the diff workload to about
11.1 ms by splitting the same styles for every token. The final painter keeps
a function-local map of surface/semantic-role combinations and composes each
once per paint, reducing the workload below the original ~8.0 ms. The map is
discarded on return and reads fresh roles on the next paint; it introduces no
persistent cache or provider work.

Automated PTYs establish native ZLE behavior; they are not a new manual
Terminal.app fullscreen/windowed acceptance session. The prior approved visual
is preserved, with unchanged full-installation palette data and contrast gates.
