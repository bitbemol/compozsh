# Interaction Design

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Adopted interaction design](#adopted-interaction-design)
- [Context-preserving composition](#context-preserving-composition)

## Adopted interaction design

This is the design map for the implemented experience, not a roadmap or a
promise that every command has a graphical flow. Read it before changing a
user-facing entry point, then follow the linked behavioral contract. The
[Domain glossary](glossary.md#domain-glossary) remains canonical for terminology.

| Surface | Adopted decision | Detailed contract |
| --- | --- | --- |
| Living prompt | One active frame responds to captured context and literal editing; acceptance leaves a command receipt. Preserve useful context without repeating inactive decoration | [Prompt and terminal UI](prompt.md#prompt-and-terminal-ui) |
| Shared workspaces | Stable task identity, visible scope, compact numbered choices, bottom input dock, capability-derived hints and official semantic colors across both panes. Selection, focus, disclosure and navigation are distinct | [Full-screen interaction standard](full-screen.md#full-screen-interaction-standard) |
| Help | Keep the description visible; topics and explanations share one captured guide. Reading is the default; Compose example is a separately labeled capability | [Keyboard and ZLE behavior](keyboard-zle.md#keyboard-and-zle-behavior) |
| Command composer | Authored literal fields produce a visible quoted draft. Replace draft returns to ordinary editing after cleanup; it never submits the command | [Prompt and terminal UI](prompt.md#prompt-and-terminal-ui) |
| Change atlas | Navigate captured Git change entries by folder, then read the selected diff. Bars count entries, not changed lines; Back preserves the review position | [Git review workspace boundary](workspaces/git.md#git-review-workspace-boundary) |
| Action workspaces | Choices compose an explicit target and plan; the named final action retains its own validation, confirmation and recovery rules | [Context-preserving composition](#context-preserving-composition) |

“Reactive” describes a specified trigger, not unrestricted monitoring. Prompt
edits, filters, pane focus and resize derive presentation from available inputs.
Provider capture stays at its documented boundary; Git Working changes has
its explicitly scoped automatic-refresh policy. Do not add polling, bulk
reads or animation merely to make another view appear alive.

### Entry points and effects

Organize related operations under the existing task family: `g` for repository
work, `compozsh` for discovery/maintenance, `external-device` for device tasks,
and `xcode` for Xcode tasks. Keep direct primitives such as `mkcd` and `cpdir`,
native wrappers, and contextual keyboard entries when their targets or intent
differ. Grouping commands does not merge privilege or confirmation boundaries.
The [task-oriented command audit](../investigations/tool-entry-points.md) records
the adopted consolidations. Do not reintroduce retired commands or parallel
compatibility flows without an explicit migration decision; retain one owning
implementation and update help, discovery and call sites together.

The composer currently supports **Git review and directory creation only**:

```text
Supported draft → Option-Return → Compose this command ─┐
g / mkcd Help → Compose example ────────────────────────┤
                                                      ↓
                           Edit fields → Replace draft → ordinary prompt
```

These are optional entries, not mandatory wizard steps. Only a later ordinary
prompt submission executes the draft. Help prose is never executable template
authority. New recipes require their own same-source capability, literal-field
contract and tests; a shared renderer does not establish feature coverage.
See [composer and atlas evidence](../investigations/composer-and-atlas.md).

### Experience completion gate

For a UI change, review the complete affected journey, including secondary views
and fallbacks, rather than approving a single attractive screen:

- Treat the current shared design as the baseline for every tool, including
  secondary menus, help, confirmations and result screens. Do not retain a
  superseded visual flow or add a per-tool style switch. Preserve intentional
  document-reading layouts and supported terminal fallbacks.
- Audit against the [full-screen standard](full-screen.md#full-screen-interaction-standard):
  compact choices, useful optional subtitles, renderer-owned numbering,
  plain action labels, neutral empty states and capability-derived actions.
  Check semantic colors in both panes and all selection/focus states, not
  only the first view shown by the command.
- Check prompt outline continuity and readable shortcut notation alongside
  shared headers, pane boundaries and footer hints. Verify display-cell fit
  with long labels, wide Unicode and narrow/short windows; cell counts alone
  do not establish that glyphs look separated in Terminal.app. Omit optional
  chrome before crowding essential identity or actions. Preserve literal
  user text and exact targets independently from abbreviated display labels.
- State the entry, source/scope, capture trigger, exact target, visible action,
  Back/cancel result and post-cleanup effect before implementation.
- Reuse shared layout, palette roles, key handling and screen ownership. Check
  both panes, selected/unselected states, passive versus actionable rows, and
  complete hints; color must not be the only way to identify state or danger.
- Exercise empty, partial, unavailable and failed states; narrow/short resize;
  focus and reading-position restoration; and the actual native PTY journey.
  Preserve plain/NO_COLOR and missing-peer behavior where applicable.
- Cover changed behavior through the [TDD contract](verification.md#test-driven-development),
  including literal quoting, no unintended effects and peer-order independence.
  Synchronize public help, README, SECURITY and any affected canonical rule.
- When a convention changes, audit existing assertions throughout active docs,
  showcase copy and tests; adding a new correct paragraph does not repair a
  contradictory older rule. Keep historical investigation evidence labeled as
  historical and link superseded decisions to the current contract.
- Report automated results, timing failures, native PTY evidence and manual
  Terminal.app acceptance separately. Do not label a partial implementation a
  complete experience or treat a rerun as an entirely green original run.

Further ideas belong in explicitly labeled proposals until adopted and
implemented. Historical investigations record their original scope and results;
mark superseded decisions and link forward instead of treating them as current
requirements or silently rewriting their evidence.

## Context-preserving composition

Use the [Domain glossary](glossary.md#domain-glossary) for context, scope, view state and transition terms.
Design interactions around the user's current context and progressively more
specific intent. A forward operation should consume the scope or selected value
established by the preceding step. Sharing a screen or renderer does not make
two tasks a natural sequence. Use this model for filesystem navigation, Git,
history, tool discovery, and future features.

### State and forward operations

For each interaction, identify its data source, scope, captured facts, query,
selected value, and intended action. These are design questions, not a mandatory
state object or new API. Keep only the state the task actually needs, scoped to
the current invocation using existing helpers and bookmarks.

Distinguish these operations when designing a transition:

| Operation | Relationship to the current context | Example |
| --- | --- | --- |
| Refine | Filters or selects within captured facts; retains source and scope | Filter captured paths, then select one file |
| Discover | Explicitly captures more facts using the established scope | Search descendants of the displayed folder |
| Inspect | Reads an applicable view of the scope or selected value | Inspect a branch or request a shallow folder preview |
| Navigate | Chooses another scope or source; label the change explicitly | Open Recents, go to a parent folder, or choose another search provider |
| Apply | Performs the visibly named action on the exact selected target | Insert a path, copy it, open a file, or switch a branch |

The forward flow specializes intent; it need not shrink a mathematical set at
every step. A descendant search may discover files absent from a child-directory
listing while preserving the same folder boundary. Clearing a filter can show
more captured results. Changing provider changes coverage even with the same
root and query, so make that choice and its limits visible.

Useful compositions include:

```text
Folder scope → scoped search → selected file → applicable file actions
Shell directory stack → selected location → browse that folder → scoped search
Repository → local branches → selected branch → inspect or explicitly switch
Loaded tool catalog → selected tool → its safe documentation
```

These are optional routes, not required wizard steps. Retain direct selection,
Option-digit keys, and shortcuts; an inspector must not become a mandatory stop.
For nested disclosure, use coherent forward/reverse steps, retain the target
and semantic reading position, and skip levels that reveal no additional
information. Keep direct pane-focus shortcuts independent of disclosure.
At a disclosure boundary, a repeated arrow is inert; it never switches files,
changes scope, executes the target or wraps to another level.
Offer forward actions only when their inputs and capabilities are available.
Name the target: current folder, selected child, selected file, or selected
branch. An abbreviated display label is never the underlying action value.

### Contextual actions and independent entry points

Path-led and recall-led entries are complementary ways to resolve a target in
the same task domain. A known folder starts Browse directly; remembered
fragments start Recents against its finite native-stack source. Once a target
is resolved, reuse applicable operations such as Browse, scoped Search, copy or
directory change. Entry strategy, discovery source and acceptance intent are
separate concerns. Browse and Recents share default acceptance: insert the exact
quoted path visibly in the ordinary prompt. Only subsequent prompt submission
performs AUTO_CD; an entry strategy must not silently change this contract.

Keep direct entry fast and preserve the draft/cursor until acceptance; cancellation
and copying restore both. Path insertion replaces the draft for a lone path or
Recents entry; completion of a command's path argument replaces only that
argument and preserves the preceding command text. A related modifier gesture
may pair concrete and recall-led entry when the terminal delivers distinct keys
and has no conflicting assignment. For filesystem navigation that pair is Tab
and Option-Tab. This is a product convention, not a universal macOS rule; follow
the keyboard contract and document terminal/profile requirements. Do not infer
global search or add a registry, new mode hierarchy or another public command
from the abstract concept of a diffuse entry.

Browse is a constrained lookup of a folder's children. Scoped Search composes
with that folder context by making the discovery intent more specific.
Recents derives from the current shell's directory stack; opening it does not
refine that folder.
Treat Recents as an independent navigation entry point. Its selected location
can supply the folder context for Browse, or acceptance can insert its editable
path. Preserve its direct prompt shortcut and native stack semantics.

Keep contextual operations prominent. If another task is reachable from the
same menu, group and label it as navigation (for example, **Go to**), separately
from operations on the current folder or selection. Never mix recent locations
into child/search results or make a global destination look like a local filter.
Keep Git, command history, and tool discovery identifiable by their own source
and purpose even though they share the interaction engine.

Forward composition remains reversible until an action is applied. Secondary
views return to the caller's query, selection, viewport and focus using existing
bookmarks. Parent navigation, explicit scope changes, query editing and
cancellation remain first-class operations. Back restores navigation context;
it does not claim to undo a completed clipboard, filesystem or Git action.
An unavailable operation preserves usable context and explains recovery; never
silently widen scope, substitute a source, or execute a different action.

### Implementation and review contract

- Before changing a flow, state what the operation consumes, what it preserves,
  what it produces, and whether it captures facts or applies a side effect.
- Derive filtering, layout and rendering from captured inputs. Filesystem reads
  and external actions are effectful boundaries; functional composition does
  not make them pure or guarantee identical results after the world changes.
- Keep the existing capture/render/action separation, shared session ownership,
  performance bounds, literal targets and post-cleanup action dispatch. Reuse
  these mechanisms instead of adding a state-machine framework, transition
  registry, event bus, general workflow graph or extra loader phase.
- UI operations have meaningful dependencies. This does not change the separate
  rule that peer add-ons load in any order; runtime operations need not commute.
- For behavior changes, use TDD to cover preserved scope/targets, explicit source
  changes, Back/cancel restoration, unsupported capabilities and final-action
  boundaries. Validate the complete keyboard journey, not just isolated screens.
- Document implemented behavior in README/help. A design rule or illustrative
  route must not be presented as an already implemented control or guarantee.
