# Interaction design

The design map for the implemented experience and the model for designing
transitions. Terms come from the [glossary](glossary.md#domain-glossary).

## Essentials

- **Context flows forward.** Each step consumes the scope or value the
  previous step established, and states what it preserves and produces.
- **Nothing executes by surprise.** Insertion, preview and inspection never
  become execution; only an explicitly named action applies an effect, after
  screen cleanup, on the exact target.
- **Reversible until applied.** Back restores query, selection, viewport and
  focus; it does not claim to undo a completed clipboard, filesystem or Git
  action.
- **Explicit scope changes.** Never silently widen scope, substitute a source
  or run a different action; an unavailable operation keeps usable context and
  explains recovery.
- **Optional routes, not wizards.** Direct selection, Option-digit keys and
  shortcuts stay available; an inspector is never a mandatory stop.

## Adopted interaction design

This maps what is implemented, not a roadmap. Read it before changing an entry
point, then follow the linked contract.

| Surface | Adopted decision | Contract |
| --- | --- | --- |
| Living prompt | One active frame responds to captured context and literal editing; acceptance leaves a command receipt. Useful context without repeated inactive decoration | [Prompt](prompt.md) |
| Shared workspaces | Stable task identity, visible scope, compact numbered choices, bottom input dock, capability-derived hints, semantic colors in both panes. Selection, focus, disclosure and navigation are distinct | [Full-screen standard](full-screen.md) |
| Help | Description stays visible; topics and explanations share one captured guide. Reading is the default; Compose example is a separately labeled capability | [Help topic workspace](full-screen.md#help-topic-workspace) |
| Command composer | Authored literal fields produce a visible quoted draft; Replace draft returns to ordinary editing after cleanup and never submits | [Command composer](prompt.md#command-composer) |
| Change atlas | Navigate captured Git change entries by folder, then read the selected diff. Bars count entries, not lines; Back preserves the review position | [Git review](workspaces/git.md#git-review-workspace-boundary) |
| Action workspaces | Choices compose an explicit target and plan; the named final action keeps its own validation, confirmation and recovery | [Context-preserving composition](#context-preserving-composition) |

"Reactive" means a specified trigger, not monitoring. Prompt edits, filters,
pane focus and resize derive presentation from available inputs; provider
capture stays at its documented boundary. Git Working changes has its own
scoped auto-refresh policy. Don't add polling, bulk reads or animation to make
a view look alive.

### Entry points

Related operations live under their task family: `g` for repository work,
`compozsh` for discovery and maintenance, `external-device` for devices and
`xcode` for Xcode. Direct primitives (`mkcd`, `cpdir`), native wrappers and
contextual keyboard entries stay when their targets or intent differ. Grouping
commands never merges privilege or confirmation boundaries. Keep one owning
implementation per operation and update help, discovery and call sites
together. The [task-oriented command audit](../investigations/tool-entry-points.md)
records the adopted consolidations.

The composer currently supports Git review and directory creation:

```text
Supported draft → Option-Return → Compose this command ─┐
g / mkcd Help → Compose example ────────────────────────┤
                                                      ↓
                           Edit fields → Replace draft → ordinary prompt
```

Only a later ordinary prompt submission executes the draft, and help prose is
never template authority. A new recipe needs its own same-source capability,
literal-field contract and tests; a shared renderer doesn't establish
coverage. Evidence: [composer and atlas](../investigations/composer-and-atlas.md).

### Experience completion gate

Review the complete affected journey for a UI change, not one attractive
screen:

- Before implementing, state the entry, source/scope, capture trigger, exact
  target, visible action, Back/cancel result and post-cleanup effect.
- The current shared design is the baseline for every tool, including
  secondary menus, help, confirmations and result screens; keep intentional
  document-reading layouts and terminal fallbacks.
- Audit against the [full-screen standard](full-screen.md): compact choices,
  useful subtitles, renderer-owned numbering, plain action labels, neutral
  empty states, capability-derived actions, semantic colors across panes and
  selection/focus states. Color is never the only signal for state or danger.
- Check prompt outline continuity, readable shortcut notation, display-cell
  fit with long labels, wide Unicode and narrow/short windows (cell counts
  alone don't prove glyphs look separated in Terminal.app). Drop optional
  chrome before crowding identity or actions. Literal user text and exact
  targets stay independent of abbreviated labels.
- Exercise empty, partial, unavailable and failed states, narrow/short resize,
  focus and reading-position restoration, plain/`NO_COLOR` and missing-peer
  behavior, and the real PTY journey.
- Cover behavior with the [TDD contract](verification.md#test-driven-development),
  including literal quoting, no unintended effects and peer-order independence;
  synchronize help, README, SECURITY and affected contracts.
- Report automated, PTY and manual Terminal.app results separately, and
  don't label a partial implementation a complete experience.
- Label further ideas as proposals until adopted. Investigations keep their
  original scope; mark superseded decisions and link forward instead of
  rewriting evidence.

## Context-preserving composition

Design around the user's current context and progressively more specific
intent. Sharing a screen or renderer doesn't make two tasks a natural
sequence. This model applies to filesystem navigation, Git, history, tool
discovery and future features.

### Operations

For each interaction identify its source, scope, captured facts, query,
selected value and intended action — as design questions, not a mandatory
state object. Keep only the state the task needs, scoped to the invocation.

| Operation | Relationship to the current context | Example |
| --- | --- | --- |
| Refine | Filters or selects within captured facts; keeps source and scope | Filter captured paths, then select a file |
| Discover | Explicitly captures more facts within the established scope | Search descendants of the displayed folder |
| Inspect | Reads an applicable view of the scope or selected value | Inspect a branch; preview a folder |
| Navigate | Chooses another scope or source, labeled explicitly | Open Recents, go to a parent, choose another search provider |
| Apply | Performs the visibly named action on the exact target | Insert a path, copy it, open a file, switch a branch |

Forward flow specializes intent; it needn't shrink a set at every step. A
descendant search may find files absent from a child listing within the same
folder boundary; clearing a filter shows more captured results; changing
provider changes coverage even with the same root and query, so make that
choice and its limits visible.

```text
Folder scope → scoped search → selected file → applicable file actions
Shell directory stack → selected location → browse that folder → scoped search
Repository → local branches → selected branch → inspect or explicitly switch
Loaded tool catalog → selected tool → its safe documentation
```

Nested disclosure uses coherent forward/reverse steps, keeps the target and
semantic reading position, and skips levels that reveal nothing new. At a
disclosure boundary a repeated arrow is inert — it never switches files,
changes scope, executes or wraps. Pane-focus shortcuts stay independent of
disclosure. Offer forward actions only when their inputs and capabilities
exist, and name the target (current folder, selected child, selected file,
selected branch); an abbreviated label is never the action value.

### Path-led and recall-led entry

Path-led and recall-led entries resolve a target in the same domain: a known
folder starts Browse; remembered fragments start Recents over the shell's
directory stack. Once resolved, the target reuses applicable operations
(Browse, scoped Search, copy, directory change). Entry strategy, discovery
source and acceptance intent are separate concerns.

- Browse and Recents insert the exact quoted path in the prompt by default;
  only a later prompt submission performs `AUTO_CD`.
- Entry is fast and keeps the draft and cursor until acceptance; cancellation
  and copying restore both. A lone path or Recents entry replaces the draft;
  completing a command's path argument replaces only that argument.
- A related modifier gesture may pair concrete and recall-led entry when the
  terminal delivers distinct keys and nothing else is assigned to them — for
  filesystem navigation, Tab and
  Option-Tab. This is a product convention; document terminal requirements in
  the [keyboard contract](keyboard-zle.md). Don't infer global search, a
  registry, a mode hierarchy or another command from the idea of diffuse entry.
- Browse is a constrained lookup of a folder's children; scoped Search makes
  discovery more specific within it. Recents is an independent entry derived
  from the directory stack; its selection can supply Browse's folder.

Parent navigation, explicit scope changes, query editing and cancellation
stay first-class operations. Keep contextual operations prominent. Group other reachable tasks as labeled
navigation (for example **Go to**), separate from operations on the current
folder or selection. Never mix recent locations into child or search results,
or make a global destination look like a local filter. Git, history and tool
discovery keep their own source and purpose while sharing the engine.

### Implementation review

- State what each operation consumes, preserves and produces, and whether it
  captures facts or applies an effect.
- Filtering, layout and rendering derive from captured inputs; filesystem
  reads and external actions are effect boundaries, and composing them doesn't
  make them pure or repeatable after the world changes.
- Reuse capture/render/action separation, shared session ownership,
  performance bounds, literal targets and post-cleanup dispatch instead of a
  state-machine framework, transition registry, event bus, workflow graph or
  loader phase.
- Runtime operations have real dependencies; that doesn't change the rule that
  peers load in any order.
- Test preserved scope and targets, explicit source changes, Back/cancel
  restoration, unsupported capabilities and final-action boundaries across the
  complete keyboard journey.
- Document implemented behavior in README and help; never present a design
  rule or illustrative route as a shipped control.

## Retired decisions

- Commands retired by the [task-oriented command audit](../investigations/tool-entry-points.md);
  reintroducing one, or a parallel compatibility flow, needs an explicit
  migration decision.
