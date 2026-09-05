# Repository instructions

These instructions apply to the entire repository. They describe the design
contract for humans and coding agents working on this configuration. Follow the
user's current request first; within that scope, preserve the principles below.

## Product contract

This project is a polished, self-contained interactive Zsh configuration. Its
core promises are:

- Local-only operation is the highest security invariant. All processing
  performed by Compozsh remains on the machine running its Zsh process. No
  Compozsh-owned code may transmit user or project data under any circumstance.
- Privacy, credential protection, data minimization, and user control are
  top-level product goals. Handle only the minimum information required for a
  visible feature, keep it local and ephemeral whenever possible, and never
  trade privacy for convenience, analytics, personalization, or feature breadth.
- Zsh 5.9 or newer; compatibility with older Zsh releases is not a goal.
- No plugin manager, prompt framework, third-party shell code, patched font, or
  background daemon.
- macOS-first ergonomics with correct behavior in SSH sessions, multiplexers,
  and ordinary Unicode/color terminals.
- Target stock macOS Terminal.app and Apple's supported Zsh for new terminal
  UI. Do not require another emulator, enhanced terminal protocol, downloaded
  UI library, or replacement shell. Existing fallbacks remain intact.
- Fast startup and prompt redraws with no project-specific persistent cache or
  background state.
- A minimal stable `.zshrc` bootstrap, one optional first-loaded machine
  initializer, and focused order-independent peer add-ons.
- Safe behavior in arbitrary directories, including untrusted repositories.

Do not weaken one of these promises merely to add broader feature coverage.

## Domain glossary

Use these canonical terms in designs, comments, tests, reviews and documentation.
Definitions establish meaning; the later contracts specify behavior and limits.
Qualify overloaded words such as source, state and session when ambiguity is
possible. User-facing labels may use simpler language while preserving meaning.

### Configuration boundaries

| Term | Meaning in Compozsh |
| --- | --- |
| Bootstrap | The minimal `.zshrc` entry that loads the optional initializer and discovers peer add-ons. |
| Initializer | The optional machine-local `local/init.zsh` file that establishes prerequisites before peers load. |
| Peer / add-on | One focused `.zsh.<name>` unit, enabled by its filename and independently sourceable. These two terms are synonyms. |
| Repository-managed configuration | Shared product files updated as a unit; personal edits belong in the machine-local space. “Immutable” describes this ownership convention, not enforced filesystem permissions. |
| Machine-local configuration | The user's private initializer and peers beneath the configuration base. Updates preserve this customization space. |
| Composition | Combining focused peers or runtime capabilities into a larger system. The [peer configuration algebra](#peer-configuration-algebra) governs setup; runtime composition preserves the input and effect dependencies of each operation. |
| Order independence | Loading the same enabled peers in any order converges on the same configured behavior under the same prerequisites. Runtime interaction steps can still have dependencies. |

“Configuration base” retains its exact path definition in
[Repository boundaries](#repository-boundaries). Use **peer** for the unit; qualify its ownership as shared or
private. Avoid inventing a privileged core tier through new terminology.

### Task and interaction boundaries

| Term | Meaning in Compozsh |
| --- | --- |
| Context | The source, scope and user intent that give an operation meaning. |
| Scope | The explicit boundary within which an operation works: a folder root, one repository, or the current shell's retained history. Scope does not guarantee exhaustive coverage. |
| Source | The origin of task facts: filesystem entries, Git metadata, Spotlight's index, the native directory stack, or loaded function metadata. |
| Tool | A user-facing task capability, reached through a command or widget; it can use several views and peer units. |
| Task workspace | Related views composed around a task. A shared renderer or screen session can also host explicitly labeled navigation to a different task context. |
| Entry point | The command or key gesture that establishes the initial context, such as path + Tab or the prompt shortcut for Recents. |
| Living prompt | The ordinary ZLE prompt system whose Context lens, Interaction lens and transcript presentations respond to captured shell/project state and the editing lifecycle. It does not describe a background monitor. |
| Context lens | Temporary expanded disclosure of the living prompt's current captured facts. It is prompt presentation, not an independent View, provider capture or input loop. |
| Interaction lens | The living prompt's active edit-time disclosure. `READY` presents the current captured context while the buffer is empty; operation-specific presentations derive bounded structural excerpts from the literal buffer and combine them with captured facts. It performs no action and is not an independent View, command validator or provider boundary. |
| Draft inspector | An explicitly opened task workspace over a bounded literal copy of the current draft and its cursor/folder context. Option-Return opens reading and labeled tool navigation; it is separate from the automatic Interaction lens and never executes or validates the draft. |
| Command composer | An explicit task workspace over authored literal fields and a generated, shell-quoted command draft. Replace draft applies editor insertion after screen cleanup, never command execution. Same-source templates currently cover Git review and directory creation; help prose is not a template source. |
| Change atlas | A hierarchical view derived from a Git review's captured change entries, grouped by exact path prefixes. Bars represent entry counts, not line counts; opening a file enters the existing diff reader. No filesystem discovery or list refresh occurs inside the map. |
| Receipt | A compact line intentionally left in ordinary terminal scrollback. A command receipt replaces active prompt decoration at acceptance while retaining the exact submitted buffer; an outcome receipt reports a slow success or any failure after command output. Neither is a shell-history record. |
| Path-led / concrete entry | Starts from an explicit known location, such as `~/Projects/` + Tab. The path establishes the initial folder scope. |
| Recall-led / diffuse entry | Starts from remembered fragments within a named source, such as Option-Tab over the shell's directory stack. “Diffuse” describes the user's starting knowledge; source and coverage still have explicit boundaries. |
| View | One presentation of a context with a defined purpose and applicable operations. Browse, Search and Recents are named views with distinct sources or intents. |
| View state | The context, captured facts and current editing/navigation position needed to render and continue a view. It is temporary interaction state. |
| Screen session | Ownership of the terminal display from entry through guaranteed restoration. One screen session may contain several views and input loops; distinguish it from the longer-lived shell session. |
| Input loop | Key handling against the active view and captured data, returning operation requests to its caller. View changes can finish one loop and start another within the same screen session. |
| Bookmark | Caller-owned return information such as query, selected value, viewport and focus. It is navigation state, not a persistent favorite. |
| Capability | An operation currently supported by the context and available implementation/tools. Its presence controls affordances; execution still validates mutable facts. |

### Facts, selection and effects

| Term | Meaning in Compozsh |
| --- | --- |
| Provider | Code that obtains facts from a source, such as a bounded filesystem enumerator or a trusted help companion. |
| Capture | An explicit acquisition of facts for subsequent interaction, subject to the provider's coverage and limits. |
| Snapshot | Captured facts retained for reuse, including relevant scope and partial-result information. It records observations, without promising an atomic or permanently current view of the outside world. |
| Candidate | One captured exact value with its display label and relevant facts, eligible for matching or selection. |
| Collector | Picker code that filters, ranks or extends a result prefix from captured candidates. It performs no new provider discovery. |
| Result | A candidate matching the current query/filter; it may be outside the visible viewport. |
| Query / filter | Literal user input used for matching. Specify **discovery query** when submission triggers capture and **refinement filter** when it only narrows captured candidates. |
| Viewport / visible row | The displayed slice of results / one actionable presentation slot in that slice. A visible digit identifies that slot; the exact underlying value remains separate. Passive information is not a result row and receives no digit. |
| Selection / target | Selection identifies the active candidate. A target is the exact value and necessary scope an operation will use, such as repository plus branch; it may instead be an explicitly named current folder. |
| Target resolution | Turns a path or a selected recall result into an exact target for the next operation. It does not itself authorize insertion, directory change or execution; action dispatch validates mutable facts again. |
| Operation / transition | An operation is a supported step; a transition is its change to interaction context or state. Use the five operation categories in [Context-preserving composition](#context-preserving-composition). |
| Acceptance / action | Acceptance requests the visibly named primary operation. An action applies an explicit effect to a target, including insertion, copying, directory change or application launch. Acceptance can instead open another view. |
| Renderer / paint | The renderer derives frame text and styles from view state. Painting applies that frame to the terminal through the shared ZLE machinery. |
| Document workspace | A file navigator paired with a primary, independently scrollable reader, such as Git review. Distinct from a picker with secondary information. |
| Action workspace | A task workspace that composes captured configuration choices into one explicit post-cleanup action, such as Xcode scheme + destination + Build. An explicit Run can then open a separate view of its scoped output; configuration selection itself does not execute or monitor a process. |
| Source anchor | A semantic reading position independent of display rows: for Git review, the old/new file side and line number at the top of the reader. Used when changing context density. |
| Disclosure | Revealing more detail about the same target without changing its task or scope. Reverse disclosure returns to the less detailed presentation using a source anchor; it is distinct from switching pane focus or navigating to another target. |
| Effect boundary | The point where code reads external facts or changes observable state. Frame construction and filtering derive from captured inputs; painting, provider reads and final actions have their own lifecycle rules. |

### Conceptual structures and vocabulary maintenance

Use these small descriptions to reason about a feature:

```text
Context: source + scope + intent
Candidate: exact value + display label + captured facts
View state: context + snapshot + query/filter + selection + viewport + focus
Transition contract: input → operation → outcome; preserved context, effects, recovery
```

These describe relationships, not mandatory records, new types or serialization
formats. Reuse existing scoped variables and helpers; omit irrelevant fields.
“Stateless discovery” means deriving a catalog when requested without maintaining
a second persistent registry. It does not prohibit temporary view state or the
specifically allowed in-memory caches. “Pure” applies to deterministic calculation
from inputs without external reads or observable effects, not to an entire shell
or filesystem workflow.

- Reuse an existing term when its meaning fits. Add a term only for a distinct
  concept needed by implemented behavior or an explicitly adopted design rule.
- Add or revise its definition in the same unit of work that introduces the
  concept; include its boundary and a concrete example where useful.
- Keep each definition canonical here and link to behavioral contracts instead
  of copying them. Resolve conflicting terminology when touching related docs.
- Keep proposed behavior distinguishable from shipped behavior. Definitions do
  not authorize new features, blanket renames, API changes or extra abstractions.

## Modern-first compatibility policy

The declared minimum Zsh version is a product boundary, not a suggestion:

- Treat the Zsh version included with the latest generally available macOS as
  the compatibility ceiling. Never require Homebrew, MacPorts, or a
  user-compiled replacement shell merely to run Compozsh.
- Review the declared minimum and newly available native features after macOS
  major updates and relevant point releases. Use the repository-scoped
  `compozsh-platform-review` skill for this evidence-gathering pass. Do not
  adopt upstream-only Zsh behavior until Apple ships it in a generally
  available macOS release.
- Do not add compatibility branches, polyfills, or lowest-common-denominator
  syntax for Zsh releases older than the declared minimum.
- Prefer a newer native mechanism only when it concretely improves correctness,
  security, measured performance, or clarity. Novelty alone is not a reason to
  change working code.
- When the minimum advances, remove superseded implementations instead of
  retaining permanent legacy paths.
- Treat a minimum-version increase as a breaking change. Update requirements,
  release notes, migration guidance, and tests in the same unit of work.
- Test against the declared minimum and current supported Zsh releases; do not
  spend project complexity validating versions outside the support contract.

## Repository boundaries

“Configuration base” means `${ZDOTDIR:-$HOME}` throughout this document. Paths
written with `~/` describe the default layout when `ZDOTDIR` is unset; all
active bootstrap, initializer, and private-peer rules apply under the selected
configuration base.

- `.zshrc` is only the bootstrap. Keep its early non-interactive guard, optional
  first local-initializer load, native recursive peer discovery, and
  diagnostics; do not move product features into it.
- `.zsh.addons/` contains all shared behavior as focused peer units named
  `.zsh.<name>`. There is no privileged core tier. Keep every unit independently
  sourceable, re-source safe, narrow in purpose, and successful after setup.
- `.zsh.addons/support/` groups repository-managed palette, matching, UI
  components and adapter assets. Keep these implementations installed and intact
  during normal customization; public settings belong in the machine-local initializer.
  Its `.zsh.<name>` files remain ordinary peers under recursive discovery, with
  no required ordering, special loader treatment or filesystem immutability.
  Preserve standalone fallbacks when support capabilities are unavailable.
- `README.md` is user-facing documentation. Keep it synchronized with visible
  behavior, keys, installation steps, extension points, and safety guarantees.
- `SECURITY.md` is the public trust and self-audit contract. Keep its claims,
  limitations, local-data inventory, privilege boundaries, reporting guidance,
  and independently reproducible checks synchronized with the shipped code,
  installer, tests, website, and repository-scoped agent workflows. A change is
  incomplete when it makes any security or privacy statement stale.
- The README's **Shipped configuration units** table is the public inventory of
  repository peers. In the same change that adds, deletes, renames, splits,
  merges, or materially changes the responsibility or public surface of a
  shipped `.zsh.<name>` file, update that table and the repository layout. A
  unit change is incomplete while either inventory is stale.
- `templates/init.zsh` is the valid, fully commented, inert starter for the
  optional per-machine initializer. Installers may copy it only when the private
  destination is absent; never symlink it, overwrite an existing initializer,
  or add active machine policy to the tracked starter.
- `install.zsh` is the native installation boundary. Keep its dry-run plan,
  symlink and namespaced-copy modes, `ZDOTDIR` support, confirmation, timestamped
  recovery backups, transactional rollback, and refusal to overwrite unmarked
  managed namespaces. `--clean` means archive and start fresh, never delete.
- `tests/` is the native-Zsh regression suite. Keep test files focused by
  behavior, use `tests/support.zsh` for the minimal shared harness, and keep the
  runner free of third-party dependencies.
- `investigations/` preserves bounded engineering evidence behind performance
  and architecture decisions. Keep durable product rules concise in this file
  and link to the relevant investigation. Treat measured timings as observations
  from their recorded environment, never universal compatibility thresholds.
- `AGENTS.md` defines engineering conventions. Update it when an intentional
  architectural rule changes, not for ordinary implementation details.
- `.agents/skills/compozsh-platform-review/` is the repository-scoped,
  read-only platform audit. Keep its trigger description narrow, its inventory
  deterministic and free of personal data, and its recommendations separated
  from implementation authority. Update it when the native-platform contract,
  audit evidence lanes, compatibility gates, or report workflow changes. Do
  not commit generated platform snapshots automatically.
- `.agents/skills/compozsh-release-draft/` is the repository-scoped,
  read-only GitHub release evidence workflow. It must resolve the actual latest
  published release and exact tag commit instead of trusting local tags, then
  compare the baseline and final implementation, public help, tests and
  documentation before drafting a claim. Treat conflicts as release blockers;
  never infer coverage from an underlying tool or an intermediate commit. The
  skill does not authorize tagging, committing, pushing, publishing or
  clipboard access.
- `LICENSE` is the canonical, unmodified GNU GPL version 3 text. The repository
  is distributed under `GPL-3.0-or-later`; keep the README declaration and SPDX
  identifier synchronized with it. Do not add contradictory licensing terms or
  imply that the GPL prohibits commercial use.
- The real `~/.zsh.addons/local/init.zsh`, private peer add-ons, history, and
  machine state are outside this repository. Do not read, copy, overwrite, or
  commit them during normal work.

The local initializer must remain optional and readable only when it exists. It
is the sole documented ordering exception and loads before peer discovery. Its
fixed default path is `~/.zsh.addons/local/init.zsh`, and its basename must not
match `.zsh.<name>` so it cannot be loaded twice. It may establish `PATH`,
Homebrew or language-manager environments, selected runtimes, trusted vendor
hooks that require early loading, and documented public defaults, but it must
not call peer functions during source-time setup. Aliases, ordinary functions,
and app-specific behavior that do not require first-load semantics belong in
focused private peers. Do not add more phases or ordered directories.

After the initializer, source shared peers adjacent to the resolved bootstrap
and private peers under `~/.zsh.addons`. Canonicalize and deduplicate those
directories so a copied installation scans its combined directory once. A user
may disable a peer by renaming or removing its file rather than maintaining a
registration list.

Public values documented as initializer-customizable must preserve an early
value. Scalars and convenience aliases use defaults only when absent;
associative palettes fill missing roles without replacing existing keys; public
extension arrays are declared without clearing them. Full shared functions and
prompt definitions remain peer-owned—avoid collisions or disable the owning
peer instead of depending on accidental overwrite order.

Add-on order is not an architecture mechanism. The loader uses lexical order
only to make diagnostics reproducible; loading the same enabled units in any
order must produce the same final behavior. An add-on must not call another
add-on during source-time setup, rely on a filename sorting before another, or
require an ordered registration list. Cross-feature behavior must be deferred
until runtime and guarded by capability checks so a missing peer degrades
cleanly. Renaming an enabled `.zsh.<name>` file must not change semantics.

There is deliberately no add-on registry, allowlist, dependency graph, core
module list, or lifecycle manager. A unit is enabled by its `.zsh.<name>`
filename and disabled by breaking that prefix or removing the file. Do not add
`.zshrc.core`, `.zsh.core/`, numeric filename prefixes, dependency metadata, or
additional initialization phases to recreate a core/add-on distinction
indirectly.

Keep installation documentation correct for both supported layouts. A symlinked
`.zshrc` resolves add-ons beside the repository file; a copied `.zshrc` requires
an adjacent copied `~/.zsh.addons`. Whenever repository structure changes,
audit installation, updating, and uninstall instructions together.

## Website boundary

- `docs/` is the optional static GitHub Pages showcase, not a shell feature.
  Use semantic HTML, CSS, and small native JavaScript modules. No framework,
  build pipeline, runtime package installation, remote fonts, third-party
  scripts, analytics, or coupling to `.zshrc` is needed.
- Keep installation and safety copy synchronized with the README, which stays
  authoritative. Use only synthetic terminal examples, never private history
  or screenshots. Intentional official project URLs in website links and
  metadata are permitted; other privacy rules still apply.
- Demo interactions must be labeled simulations and operate on bounded static
  data. Never execute commands or discover files on a visitor's machine. Copy
  only the exact visible command, following an explicit click, with a readable
  failure path. Do not copy an install-and-execute chain automatically.
- The website Context demo may illustrate Context lens, Interaction lens and
  transcript prompt moments only through user-selected fixed synthetic data.
  Do not read the visitor's clock, terminal, command line, filesystem, Git
  state or environment, and do not autoplay the state sequence.
- Organize the showcase by recognizable tasks in one user-controlled terminal.
  Reveal specialized examples within their task and secondary features on
  request. Keep tab changes spatially stable; avoid autoplay and competing
  demos. Shared interaction code should consume bounded sample data.
- Showcase numbered choices mirror the native compact-row rule: no decorative
  inter-option gaps, and actual descriptions remain attached to their item.
  Preserve browser hit areas within rows. Keep example-selector labels concise
  enough to fit at narrow mobile widths; put fuller explanations in the visible
  description rather than shrinking text or relying on clipped option names.
- Open the showcase on Context. Keep website example controls and feedback
  outside the simulated terminal viewport. Prompt demos share one monospace
  cell rhythm for labels and values, a continuous outline and attached input;
  do not recreate rails from differently sized, loosely spaced text rows.
  Keep explanatory material in a separate disclosure. Validate inner label,
  value and frame geometry at phone and desktop widths, not just outer-page
  overflow; preserve the stable task viewport and accessible browser controls.
- Write direct, affirmative product copy about actual capabilities. Avoid
  formulaic contrasts such as “X, not Y,” negative slogans, and unsupported
  superiority claims. Keep factual limitations and safety instructions clear.
- Preserve semantic landmarks, keyboard navigation, visible focus, adequate
  contrast, reduced-motion preferences, small-screen containment, and useful
  content with JavaScript disabled. Use relative asset paths for project-site
  hosting. Keep the restrictive Content Security Policy free of unsafe-inline
  and unsafe-eval; treat it as defense in depth, not a security guarantee.
- Use the native suite for the static boundary and Node's built-in test runner
  for the small pure browser algorithms. Browser QA is an optional development
  tool, never a Compozsh dependency. Test real interactions, failure states,
  mobile widths, and no-JavaScript behavior before handoff.
- Do not enable Pages, deploy, push, or create a hosting project without the
  user's authorization. Get their local visual approval before first publish.

## Decision order

When concerns conflict, prefer them in this order:

1. Local-only operation and non-transmission of user data
2. Privacy, credential protection, and user control
3. Correctness and preservation of shell semantics
4. Safety and predictable failure behavior
5. Interactive latency
6. Clarity and maintainability
7. UI consistency and useful information density
8. Additional feature breadth

Small, native, understandable code is preferred to a clever framework. Avoid
both copy-paste sprawl and speculative abstraction.

## Adopted interaction design

This is the design map for the implemented experience, not a roadmap or a
promise that every command has a graphical flow. Read it before changing a
user-facing entry point, then follow the linked behavioral contract. The
[Domain glossary](#domain-glossary) remains canonical for terminology.

| Surface | Adopted decision | Detailed contract |
| --- | --- | --- |
| Living prompt | One active frame responds to captured context and literal editing; acceptance leaves a command receipt. Preserve useful context without repeating inactive decoration | [Prompt and terminal UI](#prompt-and-terminal-ui) |
| Shared workspaces | Stable task identity, visible scope, compact numbered choices, bottom input dock, capability-derived hints and official semantic colors across both panes. Selection, focus, disclosure and navigation are distinct | [Full-screen interaction standard](#full-screen-interaction-standard) |
| Help | Keep the description visible; topics and explanations share one captured guide. Reading is the default; Compose example is a separately labeled capability | [Keyboard and ZLE behavior](#keyboard-and-zle-behavior) |
| Command composer | Authored literal fields produce a visible quoted draft. Replace draft returns to ordinary editing after cleanup; it never submits the command | [Prompt and terminal UI](#prompt-and-terminal-ui) |
| Change atlas | Navigate captured Git change entries by folder, then read the selected diff. Bars count entries, not changed lines; Back preserves the review position | [Git review workspace boundary](#git-review-workspace-boundary) |
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
The [task-oriented command audit](investigations/tool-entry-points.md) records
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
See [composer and atlas evidence](investigations/composer-and-atlas.md).

### Experience completion gate

For a UI change, review the complete affected journey, including secondary views
and fallbacks, rather than approving a single attractive screen:

- Treat the current shared design as the baseline for every tool, including
  secondary menus, help, confirmations and result screens. Do not retain a
  superseded visual flow or add a per-tool style switch. Preserve intentional
  document-reading layouts and supported terminal fallbacks.
- Audit against the [full-screen standard](#full-screen-interaction-standard):
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
- Cover changed behavior through the [TDD contract](#test-driven-development),
  including literal quoting, no unintended effects and peer-order independence.
  Synchronize public help, README, SECURITY and any affected canonical rule.
- Report automated results, timing failures, native PTY evidence and manual
  Terminal.app acceptance separately. Do not label a partial implementation a
  complete experience or treat a rerun as an entirely green original run.

Further ideas belong in explicitly labeled proposals until adopted and
implemented. Historical investigations record their original scope and results;
mark superseded decisions and link forward instead of treating them as current
requirements or silently rewriting their evidence.

## Zsh conventions

- Write native Zsh, not lowest-common-denominator POSIX shell or Bash-shaped
  Zsh. Use 5.9 features when they make the code safer or simpler.
- Prefer `[[ ... ]]`, `(( ... ))`, native arrays and associative arrays,
  parameter-expansion flags, `zstyle`, ZLE hooks, and bundled `zsh/*` modules.
- Use `emulate -L zsh` in non-trivial functions that may be called after users
  change shell options. Enable additional options locally.
- Declare function variables with `local`, including integer, float, array, and
  associative types where useful. Declare intentional global state explicitly
  with `typeset -g`, `typeset -gi`, `typeset -gF`, `typeset -ga`, or
  `typeset -gA`.
- Prefix private functions and state with `_`. Reserve unprefixed names for
  public commands and documented extension points. Public configuration uses
  the existing `ZSH_*` and `PROMPT_*` families.
- ZLE widget names and Zsh special trap function names such as `TRAPWINCH` are
  shell-facing registrations, not public callable functions. Keep their
  implementation in underscore-prefixed helpers wherever Zsh permits an
  explicit mapping, and document unavoidable special-name exceptions locally.
- Treat the leading underscore as an API boundary, not decoration. User-facing
  documentation, examples, aliases, and local configuration must not call or
  override private names. Zsh does not enforce privacy, so reviews and tests
  must enforce the convention. Focused unit tests may invoke a private helper
  when that is the narrowest way to verify its contract.
- Give every public add-on command a descriptive collision-resistant name and
  document it in `README.md`. Keep orchestration public only when users need to
  invoke it; prefix its detectors, renderers, installers, and state with `_`.
- Name Compozsh-owned public terminal commands in lowercase kebab-case: use
  hyphens between words, as in `external-device --format`, and never underscores.
  One-word commands remain one word. This naming rule does not apply to private
  underscore-prefixed helpers, Zsh special functions, or documented extension
  APIs such as `prompt_add_project_segment`. The suffix of a command's
  `_compozsh_help_<command>` companion must preserve the command's exact name.
- Use descriptive long options for Compozsh-owned commands and repository
  utilities, such as `--help` and `--worktree`, without single-letter aliases.
  Transparent wrappers preserve the underlying executable's native options.
- Treat self-documenting help as a hard public-interface contract. Every public
  add-on function intended for direct terminal invocation must accept the exact
  single argument `--help`, even when the command otherwise takes no options.
  Handle it before dependency checks, environment detection, or operational
  logic so help remains available on every supported machine.
- Define that help once in a private `_compozsh_help_<command>` companion in the
  same add-on file, and make the public command's `--help` branch delegate to
  it. The companion is a distributed capability marker used by the live
  `compozsh` explorer; do not duplicate its text, place it in another peer, or
  replace this convention with a central registry.
- Keep public help content deterministic and consistent:
  - The first line in plain-text form is `usage: command [arguments ...]`, using
    the command's real name and syntax. Spell the prefix exactly as lowercase
    `usage:`.
  - The second stdout line is a concise sentence explaining what the command
    does. Additional lines document supported options, modes, defaults, and
    important safety behavior when those exist; do not merely repeat syntax.
  - Make help a self-contained usage guide, proportional to the tool. Answer
    where its data comes from, the no-option default, scope from home or a
    subdirectory when relevant, what selection actually does, and why expected
    results may be missing. Distinguish collection bounds from visible-row
    limits, and snapshots from live discovery. State the actual matching rules;
    do not imply every fuzzy selector supports unordered fragments.
  - Document applicable prerequisites, missing-tool and noninteractive
    fallbacks, modified keys, empty-query digit behavior, quoting, and output
    formats. For commands that write, copy, switch, or discard, state exact
    targets, confirmation policy, preservation boundaries, and failure/recovery
    limitations. Include practical synthetic examples and relevant public
    configuration knobs; omit irrelevant sections for simple tools.
  - Keep scope and safety facts under focused regression tests, without
    freezing entire paragraphs. Update help and README together when a
    behavior, default, key, limit, or failure policy changes. Keep ordinary
    usage errors concise instead of dumping the complete guide to stderr.
  - A help request normally returns status 0, writes no diagnostics to stderr, and
    performs no project/configuration reads, mutations, navigation, clipboard
    access, operational tool detection, or network access. Direct owned help may
    open the shared topic workspace when stdin/stdout and terminfo support its
    alternate screen. Ordinary topics only read. The separately labeled Compose
    example action may hand off to an authored Command composer; only its
    explicit Replace draft accepts insertion after cleanup, never execution.
    Optional revision capture belongs to that explicit composer interaction,
    not help capture or topic navigation. Follow the composer contract below;
    do not launch an external pager.
    Capture the static companion once through a bounded native Zsh pipe before
    entering ZLE. Presentation may inspect stdin/stdout, TERM, NO_COLOR and
    native terminfo; paint/filter/resize launch no subprocess or provider.
    Pipes, redirects, NO_COLOR, missing help/UI peers and unsupported terminals
    retain printable help without interaction. Companions themselves always
    print; they must never recursively open a workspace.
  - Color help through the optional `_output_print_help` renderer owned by
    `.zsh.output`, using validated `ZSH_OUTPUT_COLORS` roles. A same-source
    help provider selects that capability at invocation time and otherwise
    prints its identical plain lines. Do not introduce a required peer, a
    loader phase, or duplicated palettes to style help. Keep the standalone
    installer plain; help must not source add-ons to acquire styling.
    Keep section headings unindented and body lines indented by two spaces;
    separate option/example prefixes from explanations with at least two
    spaces. Use `Examples:` for the example section. This small known format
    lets the renderer emphasize structure without interpreting shell syntax.
  - Emit help colors only to a supported 256-color terminal, and respect a
    nonempty NO_COLOR. Pipes, redirects, substitutions, dumb/unsupported
    terminals, and an unavailable renderer retain exact plain text. Keep all
    whitespace, words, and examples unchanged by styling, reset every styled
    span, and never prompt-expand, evaluate, or execute documentation text.
    Cover colored output and plain fallbacks with native PTY regression tests.
  - Invalid Compozsh-owned invocations print the same usage line to stderr and
    return status 2. Operational failures retain their meaningful nonzero
    status and diagnostics rather than masquerading as usage errors.
- Keep the complete direct-command help contract covered by the focused help
  test. Add every new public command to its inventory in the same TDD unit of
  work, and assert success, the canonical usage and description lines, empty
  stderr, freedom from side effects, presence of the same-source companion, and
    byte-identical printable direct/provider output. Cover interactive direct
    help separately with native capture-once, resize, Back and cleanup tests.
    Keep the README command inventory in
  sync with that test.
- Keep tool discovery stateless and derived from Zsh's live `functions_source`
  metadata only when `compozsh` runs. Restrict it to public command-like names
  defined beneath a `.zsh.addons` tree. Never scan add-on files, snapshot the
  loader, cache a catalog, require an end-of-load phase, or invoke an unknown
  public function to probe its help behavior. A function without a same-source
  companion remains discoverable as `no help` and must not be executed.
- Public extension APIs called by other functions, such as
  `prompt_add_project_segment`, document their signature in the README rather
  than pretending to be CLI tools. A transparent wrapper around an existing
  executable preserves that tool's own help; a wrapper that introduces a
  distinct Compozsh mode, such as `g`, owns help for that mode and points users
  to the underlying command's help.
- Use `REPLY` for a helper's scalar result when that avoids a subshell. Use a
  clearly named typed global only when multiple results or shared widget state
  genuinely require it.
- Prefer `print -r --` over `echo`. Send diagnostics to stderr with `print -u2`.
- Use `command name` inside wrappers to call the underlying executable and
  prevent aliases or functions from recursing.
- Quote command arguments and paths. Leave expansions unquoted only when a
  specific Zsh splitting, globbing, or array flag is intentional and evident.
- Use `--` before user-controlled path operands when the command supports it.
- Use `IFS= read -r` for input. Treat terminal input, filesystem names, Git
  data, environment variables, and project metadata as untrusted text.
- Do not use `eval` for parsing or dispatch. Do not construct shell source from
  project data.
- Preserve useful exit statuses. A convenience wrapper must not silently turn
  an underlying command failure into success.

## Architecture and abstraction

Apply DRY and SOLID as practical design heuristics:

- Put every shared feature in one focused peer add-on, whether universally
  useful or optional. Keep only initializer and peer discovery in `.zshrc`;
  keep only genuine pre-peer machine prerequisites in
  `~/.zsh.addons/local/init.zsh`, and put other private behavior in focused
  `.zsh.<name>` peers.
- Split by cohesive behavior, not file size. A unit owns its defaults, private
  helpers, hooks, cleanup, and fallbacks. Avoid both unguarded cross-unit calls
  and duplicated frameworks; when optional interaction is valuable, detect the
  peer capability at runtime and preserve useful standalone behavior.
- `support/.zsh.appearance` alone authors and installs terminal color defaults.
  Consumers resolve public overrides and selected defaults at invocation; they neither
  copy palettes nor write fallback keys. Public maps stay writable, and missing
  appearance uses native text and attributes. Completion owns its deferred
  style callback; appearance does not install another peer's registrations.
- `support/.zsh.ui` owns shared terminal components, view defaults, layout, input,
  painting and screen restoration. Feature peers supply captured content,
  labels and capabilities; they own task-specific collection, ranking,
  transitions and final actions.
  Scope common defaults around view execution and save caller bookmarks before
  returning. Keep explicit provider hooks outside frame construction and resize.
  These private interfaces introduce no required peer, registry or load phase.
- `support/.zsh.matching` owns query compilation and filtering over supplied
  captured text. Keep its outputs caller-local and its calculations free of
  provider reads, UI state and actions. Feature collectors retain task-specific
  ranking, duplicate policy and capture bounds; display match spans remain a
  presentation concern. Missing matching support selects existing runtime
  fallbacks without an ordered load phase or a duplicate matcher.
- Give each helper one clear responsibility: collect facts, sanitize data,
  calculate layout, render UI, or perform an action. Do not mix all five.
- Keep detection separate from presentation. Terminal resize handlers may
  recompute layout from captured facts but must not rediscover Git or runtimes.
- `.zsh.prompt` owns ordinary-prompt fact capture, its trigger fingerprint,
  the private compact/lens/transcript modes, Context and Interaction lens
  derivation/rendering, and outcome receipts.
  `.zsh.editor` owns the optional ZLE adapters, hook registrations and
  `compozsh-context-lens` binding that invoke those prompt capabilities. Both
  peers must preserve existing widget state without depending on add-on order.
  Shared full-screen components remain owned by `support/.zsh.ui`.
- Extend project support through marker data, focused detector branches, and
  the documented `PROMPT_PROJECT_*` extension points. The add-on loader is not
  a plugin manager: do not add dependency resolution, remote installation,
  manifests, lifecycle hooks, or code discovery inside projects.
- Extract a helper when it centralizes a repeated rule, security boundary, or
  non-trivial algorithm. Do not create a generic abstraction for two obvious
  lines that are merely similar today.
- Prefer data tables for stable mappings such as palettes, runtime labels, and
  markers. Prefer functions when behavior, validation, or failure handling is
  involved.
- Keep coupling explicit. Pass a project root or Git directory into helpers
  instead of having every helper rediscover ambient state.
- Remove temporary setup helpers after use when they are not part of the public
  interface.

## Peer configuration algebra

Use this model when designing, reviewing and documenting peer setup. A letter
denotes a peer or a group of peers; `⊕` combines their configuration, and `≈`
means equivalent configured behavior. This notation does not introduce a shell
operator, component registry, dependency graph or loading phase.

| Law | Contract | Engineering consequence |
| --- | --- | --- |
| Commutativity | `A ⊕ B ≈ B ⊕ A` | Reordering the same enabled peers must preserve configured behavior. Resolve optional peer capabilities when invoked, rather than capturing their source-time presence or values. |
| Associativity | `(A ⊕ B) ⊕ C ≈ A ⊕ (B ⊕ C)` | Grouping the same peers must preserve configured behavior. Concern directories organize files and confer no initialization priority or group-level setup. |
| Idempotence | `A ⊕ A ≈ A` | Re-sourcing unchanged peers must preserve configured behavior without accumulating hooks, registrations or default entries, or replacing documented user overrides. |

Compare after the same enabled peer definitions have finished loading, with
the same initializer inputs, supported shell/environment and available native
capabilities. Peer-owned definitions must have distinct ownership; competing
definitions or private overrides of internal functions violate the contract.
Grouping preserves the discovered peers and required relative asset paths.
The optional initializer remains the sole first-load exception and sits outside
these laws; re-sourcing `.zshrc` can run that initializer again.

`≈` covers supported commands and their behavior, options, aliases, key bindings,
hook behavior and multiplicity, prompts, effective styles and documented
fallbacks. A difference affecting those observations is a defect, even when a
sorted catalog or a function-name list looks equal. Incidental source locations
or internal scratch layout need not be byte-identical. Compare runtime behavior
using the same inputs and captured facts; loading a different peer set or
changing prerequisites is a different comparison.

Composition itself does not imply commutativity. Runtime workflows compose
providers, matching, UI and actions in meaningful sequences, such as capture →
filter → display → validated action. The laws describe peer setup and safe
re-sourcing between interactions, not replaying actions or resetting an active
screen session. Continue recommending a fresh `exec zsh` to apply updates.
Palette installation changes shell memory; public color maps remain writable.
Shared UI owns temporary interaction state, painting and cleanup. Read-only
consumer conventions and centralized ownership help preserve the laws but do
not establish purity or order independence on their own.

Treat the equations as engineering contracts supported by regression evidence.
Finite source-order checks and the website's fixed-data model do not constitute
a formal proof for every permutation, environment or arbitrary shell function.
Do not add abstractions merely to make the implementation resemble the notation.

For changes to peer boundaries, defaults, registrations or shared capabilities:

- Exercise normal, reverse and rotated orders in isolated shells; place the
  peer owning a shared capability before and after consumers. Compare configured
  observations and representative runtime results after loading finishes.
- Re-source the affected peer and complete peer set, including a repeated peer
  separated by other peers. Verify stable hooks/bindings, preserved public
  overrides and unchanged behavior; do not hide duplicate hooks by sorting them
  into a set.
- When placement or discovery changes, cover grouping/renaming inside the
  supported discovery roots and both installation layouts, preserving assets.
- Check standalone/missing-peer behavior and capability availability at a later
  invocation. Include both schemes and documented early overrides when colors
  are affected. Use existing focused tests and the minimal shared harness.

## Context-preserving composition

Use the [Domain glossary](#domain-glossary) for context, scope, view state and transition terms.
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
number keys, and shortcuts; an inspector must not become a mandatory stop.
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

## Performance contract

This file runs in every new interactive shell and parts of it run before every
prompt or ZLE redraw. Treat those paths as latency-sensitive.

- Measure latency-sensitive changes instead of assuming they are faster. When
  more than one reasonable design exists, implement or prototype representative
  alternatives, benchmark them under the same realistic workload, and retain
  the most performant option that also preserves correctness, security, and
  maintainability.
- Evaluate alternatives in this order: semantic correctness, safety and
  predictable failure behavior, idiomatic modern Zsh 5.9, measured speed, then
  code size. Reject a faster option if it weakens shell semantics or a security
  boundary; reject a compact option if it is slower or less clear in a hot path.
- Record the relevant before/after measurements in the task handoff. Include
  the workload, distinguish fresh from warm/cache-assisted results, and compare
  several runs so filesystem and process-startup noise do not decide the design.
- Test performance at the scope affected by the change: isolated startup for
  top-level initialization, complete prompt rendering for prompt work, project
  and Git helpers both inside and outside repositories, and redraw latency for
  ZLE work. Microbenchmarks may explain a result but must not replace an
  end-to-end measurement.

- ZLE syntax highlighting and autosuggestions must launch no subprocesses,
  perform no network access, write no files, and avoid unbounded scans.
- A live resize must only recalculate presentation from in-memory facts. It
  must not rerun Git, language tools, or project detection.
- The Context/Interaction derivation and repaint capabilities owned by
  `.zsh.prompt`, including calls from the editor's line-init, pre-redraw,
  line-finish and manual Context adapters, must derive from the current prompt
  snapshot and ZLE state. Those prompt capabilities must launch no subprocess,
  read no filesystem or project metadata, write no file, or make a network
  request. This does not describe every independent ZLE pre-redraw hook: syntax
  highlighting retains its bounded checks of literal path tokens. Ordinary
  `precmd` remains the prompt fact-capture boundary.
- Context lens automation is event driven. Do not add a dismissal timer,
  polling loop, worker or background refresh. Its trigger fingerprint contains
  only recognized-project-root or raw-Git-branch appearances and changes, the
  active virtual/Conda environment, Git operation/conflict attention, and
  runtime unknown/missing/unavailable/mismatch attention. Dirty-count-only changes update
  display without reopening the lens.
- Prompt code should minimize external commands and never add a per-prompt
  subprocess when native Zsh state or an existing command result is enough.
- Runtime/tool versions may be cached only in memory for the current shell.
  Cache keys must include every environment selector that can change the
  answer, and `compozsh --refresh` must invalidate the relevant caches.
- Do not add a project-specific disk cache, cache daemon, background worker,
  timer loop, or eager startup scan without an explicit architectural decision
  from the user. Zsh's native completion dump is not feature-state storage.
- The approved local manual-summary exception is one bounded capture by the
  optional `.zsh.manual` peer at the first TTY `precmd`, never source time or
  editing. Read only regular uncompressed section 1/8 pages beneath the fixed
  conventional installation roots documented in the README: at most 4,096
  pages, 8 KiB per page, 8,192 retained names and 240 characters per summary.
  Use native non-following/nonblocking opens and descriptor type checks; parse
  only inert NAME text, never roff includes, formatters, man/whatis, config,
  indexes or documented executables. Keep summaries in shell memory and clear
  them with `compozsh --refresh`. Missing pages/unsupported formats are quiet
  misses. Measure first-prompt capture separately from source time and warmed
  redraw; see `investigations/manual-summaries.md` for the accepted tradeoff.
- Working-changes auto-refresh in the Git review screen is the narrowly approved
  screen-session worker exception. Its ownership, bounds, lifecycle and local-only
  behavior are defined by the Git review workspace boundary below.
- Do not recursively scan entire repositories. Use bounded upward searches,
  exact marker checks, and shallow conventional source directories.
- Recursive add-on discovery is allowed only inside the shared `.zsh.addons`
  beside the resolved `.zshrc` and the configuration base's user
  `.zsh.addons`. Use one native glob, load regular `.zsh.<name>` files in
  deterministic order for reproducible diagnostics, and do not follow nested
  symlink directories. Never make correctness depend on that order.
- Never execute repository-local wrappers, binaries, manifests, or scripts to
  discover prompt information. Resolve trusted installed tools through `PATH`.
- Bound user-controlled display work and result counts. Preserve the existing
  fuzzy-history maximum and width/height-aware rendering.
- Prefer a small memoization point around a proven repeated cost. Do not cache
  code merely because caching sounds faster.

As a regression target on the reference Mac, isolated startup should normally
remain around the current tens-of-milliseconds range and should not exceed
roughly 50 ms without a measured, justified tradeoff. Compare several runs;
never optimize from a single timing sample.

## Prompt and terminal UI

- Option-Return (`ESC CR`) may open the Draft inspector through the editor peer.
  Normal Return retains shell acceptance. Scope its at-most-32,768-character
  reading copy, frames and filters to the widget; exact restoration uses the
  existing native screen owner. Reading/help/review preserve the draft and
  return bookmark. Files and History are explicit post-cleanup handoffs whose
  insertion can replace the draft. A supported Command composer can explicitly
  replace the draft after cleanup; ordinary Help navigation remains read-only.
  Git review uses the current folder, never
  an inferred target from shell text. Do not add automatic capture, evaluation,
  command validation or execution to this bridge. The prompt's capability hint
  is captured presentation only. Keep optional-peer fallbacks and Meta guidance.
- Composer templates opt in with a private `_compozsh_template_<command>` in
  the same source as that command and its help companion. Resolve the capability
  from loaded `functions_source` metadata, never files, a registry or help prose.
  Source-owned providers return a supported recipe ID only. Prefill only bounded
  simple literal drafts; preserve unsupported shell syntax untouched. Fields are
  invocation-local, bounded to 4,096 characters, and quoted with native Zsh
  parameter expansion. No evaluation, command validation or execution occurs.
  Explicit revision-field selection may use the established safe local Git ref
  chooser; preview/filter/render steps perform no provider reads. Validate the
  captured folder still matches before exporting the draft. Export through a
  caller-local result, unwind all screen owners, then insert in BUFFER or the
  ordinary prompt buffer stack. Retain an editor draft's leading-space prefix
  so composition does not remove its history preference. Cancellation exports nothing. Preserve optional
  peers, inert printable help, source-order independence and exact quoting tests.
- The living prompt has exactly three presentation modes in `_PROMPT_VIEW`:
  `compact`, `lens`, and `transcript`. Keep this private state inside
  `.zsh.prompt`; it is not a public configuration surface or a new lifecycle
  framework. Do not add `interaction` as a fourth mode: the private `compact`
  mode renders the active Interaction lens when the editor adapters are
  available, and retains the responsive one-context-row fallback when they are
  absent. Private `lens` renders Context; `transcript` is acceptance-time paint.
- Treat Context lens, Interaction lens and transcript as the three public
  moments of one ordinary prompt. Repaint the active frame in place as state or
  `BUFFER` changes; do not accumulate superseded prompt frames in scrollback.
  Acceptance alone replaces the frame with one timestamped command receipt.
- The Interaction capsule header, vertical rail and bottom corner share its
  current semantic palette role. Keep labels, values, input arrow and editor
  syntax independently styled; outline color must not bleed into row content.
  This is presentation-only and preserves all widths and capture boundaries.
- Prompt shortcut hints use readable `Option-Return` and `Option-I` text,
  with at least two terminal cells between the heading and a whole hint.
  Omit optional hints before crowding the context identity. Shared shortcut
  bars separate paired arrows (`↑/↓`) and spell out `Option`; never concatenate
  modifier/Return glyphs whose font ink can collide despite correct cell
  counts. Keep shortcuts unchanged, fit whole hints by display-cell width,
  and test long/wide-character headings and narrow-window redraws.
- The Interaction lens renders `READY` while the buffer is empty. It may show
  captured `PROJECT`, `PATH`, `GIT`, `ENV` and the active `LAST` outcome; use
  `SESSION` only when no more relevant captured fact exists. `LAST` is mutable
  shell-memory state for the most recently completed command, including a fast
  success that has no separate outcome receipt. It disappears with or is
  replaced in the active prompt; it is not a durable scrollback record.
- While editing, morph the Interaction lens among `COMMENT`, `RUN`, `GIT`,
  `NAVIGATE`, `SEARCH`, `BUILD`, `TEST`, `ENVIRONMENT`, `REMOTE`, `PIPELINE`,
  `CHAIN`, `REDIRECT` and `CAUTION`. Derive these kinds from bounded lexical
  structure, without command evaluation, expansion, resolution or execution.
  Preserve the exact buffer, cursor, undo/history state, autosuggestion display
  and shell semantics.
- Labels ending in ` TEXT` identify sanitized, width-bounded excerpts derived
  from literal editor text. They do not assert that a path exists, a target
  resolves, a connection was made or the command will have the described
  effect. Rows such as `PROJECT`, `PATH`, `GIT`, `BRANCH`, `TOOLCHAIN`, `FROM`,
  `SCOPE`, `CURRENT` and `LAST` reuse captured prompt facts. `FLOW`, `STAGES`,
  `STEPS`, and `CONTROL` summarize pipeline or `&&`, `||`, `;`, and `&` chain
  structure as applicable. Every `ACTION` row is deliberately advisory and must
  retain qualifying language such as `likely`, `appears` or `may`.
- `ABOUT` is a captured manual NAME description, not an ACTION prediction.
  Generic RUN replaces its filler ACTION with ABOUT plus SOURCE attribution;
  specific action cues and owned same-source-help commands retain priority.
  Never invoke a help companion during redraw. Suppress external summaries for
  user aliases/functions except the source-identified transparent output
  wrappers. The literal-name lookup is not executable or PATH resolution.
  Caution and compound-command presentations take priority over manual detail.
- `COMMENT` exposes the bounded comment body as `COMMENT TEXT` with the advisory
  `likely remain an interactive shell comment`. `REDIRECT` pairs its literal
  `OPERATOR TEXT` with `OUTPUT TEXT`, `INPUT TEXT`, `DESCRIPTOR TEXT`, or
  `RESOURCE TEXT` according to the recognized lexical operator; these labels do
  not validate or open the named target.
- Treat the shipped `g` command as Git interaction. A bare `g` describes its
  local branch workspace; `g --review`, `g --worktree`, and applicable `--help`
  forms expose review, worktree, or help cues. Preserve the same literal,
  advisory distinction as ordinary `git`; classification must not invoke `g`.
  `g --discard-all` receives the advisory CAUTION presentation; its `--help`
  form remains help. This mode is the sole public discard entry: no legacy
  alias or duplicate command/help companion. Navigation owns dispatch and the
  canonical `g` help, while the optional tools peer owns the private operation.
- Keep the remaining owned task entries similarly cohesive: `external-device`
  owns flash/format, `xcode --export-skills` owns Apple skill export, and
  `compozsh --refresh` dispatches the optional tools peer's current-shell cache
  invalidation. Remove superseded public names/help companions instead of
  retaining aliases. Bare external-device selection reads no provider; task
  dispatch occurs after screen restoration. Help remains same-source and inert.
  The Interaction lens distinguishes task entry, export/refresh, help and
  destructive device modes using literal text only; bare Xcode is not a build.
- Never copy a leading assignment's value into Interaction-lens presentation
  state; a name may help locate or describe the command. This minimizes a
  second display of a potentially sensitive value but does not redact the ZLE
  buffer, accepted transcript, history or process arguments. A `SUGGESTION` row
  may repeat only a bounded visible prefix from matching editor-owned
  autosuggestion state; it must not search history or retain the unseen tail.
- Validate the optional `prompt_add_project_segment` color before composing
  prompt syntax. Accept only a `0`–`255` index or Zsh's fixed basic color names;
  malformed values use the validated `tool` role or native text.
- `CAUTION` is a deliberately incomplete cue for a small set of recognizable,
  high-confidence literal forms. It is not authorization, validation,
  confirmation, policy enforcement or proof that any unmarked command is safe.
  It must neither block Return nor weaken an operation's own safety boundary.
- The Context lens is progressive disclosure of the same captured snapshot. On
  the first prompt inside a recognized project or Git repository, open it
  automatically. Reopen it only when a recognized project root or raw Git
  branch appears or changes, or when the virtual/Conda environment,
  Git operation/conflict attention, or runtime
  unknown/missing/unavailable/mismatch attention changes. Staged, modified,
  untracked, stash, ahead and behind count changes must not reopen it alone.
- Render the expanded lens with a `CONTEXT · reason` header and its current
  `Option-I pin`/`Option-I close` affordance when space permits. Use semantic
  `PROJECT`, `PATH`, `GIT`, `TOOLCHAIN`, `ENV`, `JOBS`, and `SESSION` rows when
  their facts and height budget apply; `SESSION` is where local user/host and
  Zsh-version identity belong.
- An automatic lens remains while `BUFFER` is empty. The first nonempty edit or
  paste replaces it with the Interaction lens and consumes that disclosure for
  the current trigger fingerprint; returning to an empty buffer does not reopen
  Context. Option-I maps to the `compozsh-context-lens` widget and toggles a
  pinned Context lens. A pinned Context lens survives editing and reserves a
  small live interaction section that follows the buffer; accepting a command
  clears the pin.
- Line finish must leave `HH:MM › ` as the transcript prompt while preserving
  the exact accepted buffer. After command output, render an outcome receipt
  for every failure and for successful commands meeting the two-second duration
  threshold: `× exit N`, add ` · 2.3s` for a slow failure, and use `✓ 2.3s`
  for a slow success. Fast successes add no outcome row. Receipt painting must not
  change command bytes, normal history insertion, output, or the captured exit
  status represented by the next prompt.
- Layout must respond to `$COLUMNS`, avoid wrapping the active prompt, preserve
  the highest-value facts first, and restore hidden facts when space returns.
  Interaction morphing, Context replacement/pinning, transcript repaint and
  resize operate only on the literal buffer, bounded editor-owned suggestion
  state and captured facts; none is a provider or effect boundary.
- Completed receipts are ordinary terminal scrollback. Never claim they can be
  dynamically relaid out after resize, cleared as a privacy feature, or removed
  from terminal-owned retention.
- Use `…` for width-aware abbreviation and keep useful beginning/end context.
- Sanitize control characters and preserve dynamic text literally before placing
  it in a prompt-expanded string. Escape `%` for prompt escapes; when
  `PROMPT_SUBST` is enabled, also escape backslash, `$`, and backticks; when
  `PROMPT_BANG` is enabled, also escape `!` into its literal prompt form. Route
  all dynamic values through the established prompt sanitation/escaping helpers.
- Measure visible characters, not color escape bytes. Keep color application
  outside width calculations.
- Preserve the semantic, collision-resistant palette. A color should identify
  one role in its local context; warnings and errors retain conventional warm
  colors. Keep coherent light- and dark-background defaults with useful
  contrast, and preserve explicit initializer roles across automatic selection.
- Unicode tree glyphs are welcome; patched-font/private-use glyphs are not.
- Color command output only when stdout is a terminal. Pipes, redirects,
  command substitutions, and machine-readable output must remain plain and
  byte-compatible with the original command.
- Wrappers such as `grep` and `man` must stay narrow in scope and delegate all
  unsupported behavior to the system command.

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
| Footer | Emphasized real acceptance action, Escape, then at most five complete capability hints on the full screen; keyboard-guide access gets first priority and the guide retains all applicable keys |

The visible `[n]` prefix is reserved for actionable candidates: directories,
files, menu operations, or other exact values that the input loop can select and
accept. Showing `[n] some text` promises that the row participates in selection
and that its visible digit can choose it whenever digit selection is active.
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
| Ctrl-U / Ctrl-W | Clear the query / delete its last word |
| Backspace | Delete the last query character |
| Ctrl-Y | Copy the selected value and close, when available |
| Ctrl-L | Redraw |
| Ctrl-F | Start descendant discovery in Browse; edit discovery query in Search results |
| Ctrl-E / Ctrl-B | Focus details/list, when available |
| Tab / Shift-Tab | Switch list/details focus; in the browser, enter/go Back |
| Ctrl-O | Inspect a folder: browse from Recents, preview inside the browser |
| Ctrl-X | Open **review** on Branches, **options** in filesystem/worktree views, or **atlas** in Git file-review views that expose it; otherwise inactive |
| Right / Left in a document workspace | Disclose files → focused diff → full-file context / reverse the sequence |
| Ctrl-A in an auto-refresh document workspace | Pause/resume automatic refresh for the current screen session |
| Ctrl-R in a document workspace | Refresh the file list and selected diff, retaining available selection/focus/source area |
| Ctrl-T | Toggle hidden folders in the browser |

The hierarchy, document disclosure/refresh and Ctrl-O contexts above are explicit
exceptions, not permission for arbitrary tool-specific remapping. Keep the actual action visible in the
footer/guide. Add new keys only after checking this map, normal shell editing,
Terminal.app interception and control-byte collisions (for example Tab/Ctrl-I,
Enter/Ctrl-M and flow-control keys). Prefer an existing action or menu over a
new binding. A key-map change must update this table, shared handler, hints,
guide, public help, README and native PTY tests together. Keep contract coverage
across history, Recents, branches, files, tool discovery and secondary menus.
Collectors and tool providers must not implement their own key parsers or hints.
Ctrl-R's refresh meaning is limited to document workspaces. Preserve prompt
history search and the existing next-result alias in other pickers. Refresh is
available with empty/filtered-out document lists, allowing new changes to be
discovered. Ctrl-A remains beginning-of-line at the prompt and is advertised
only when the active document workspace provides automatic refresh. The
keyboard guide must never trigger refresh or an automatic provider check.

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
  disclosure steps and `^R refresh`; add `^X atlas` only with the explicit Git
  atlas capability. Other readers keep Ctrl-X inert and omit its hint.
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
- Keep task semantics explicit: history, the Tab directory browser and Recents
  insert; `g` switches branch; Files search inserts directories
  and offers explicit file/link actions;
  `compozsh` opens captured help with a printable fallback; Git review acceptance
  drills into files/diffs or focuses reading. Help's explicit Compose action
  follows the separate draft-insertion contract. Shared interaction must never
  turn insertion or a preview into execution. Digits apply visible slots only with an empty filter
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

## Git worktree workspace boundary

- `g --worktree` is the sole worktree entry point. The optional
  `.zsh.git-worktree` peer owns capture, temporary choices and actions; `g`
  retains its recent-branch default and transparent ordinary Git arguments.
- Reuse the navigation fuzzy collector and shared UI peer, text entry, keys,
  guide, focus and screen lifecycle. Worktree options consume the selected
  registered path. Creation composes branch, captured start commit and a new
  folder into one explicit action after terminal restoration. Parent browsing
  uses the existing hierarchy keys; Back preserves caller bookmarks.
- Keep Create, Enter, Move / rename, Remove and Refresh visible in the main
  menu. Each operation specializes the captured worktree catalog; contextual
  options are shortcuts to the same flows, never their only entry points.
  Move edits the parent/folder name, preserves files and branch, and delegates
  to native Git on the same filesystem after reviewing exact old/new paths.
- Capture registered worktrees from NUL-delimited Git porcelain and all local
  branches within explicit bounds, rather than using recent checkout history
  as an eligibility catalog. Never treat a truncated capture as a complete
  safety check. Filtering and painting read no providers. Refresh is explicit.
- Keep Git transport, lazy fetches, hooks, fsmonitor, automatic maintenance and
  submodule recursion disabled. Creation/removal refuse configured checkout
  filters and submodule trees. Register new worktrees without checkout, then
  check their effective configuration before materializing files; conditional
  includes can differ from the source checkout. Revalidate exact repository/directory identities,
  branch/commit and destination after cleanup. Never evaluate command previews.
- Removal keeps the branch, refuses main/current/locked/missing/detached targets
  and active Git operations, and checks ignored files as well as tracked and
  untracked changes. Sparse/unmerged/assume-unchanged indexes cannot establish
  safety. Never force, auto-stash, reset branches or recursively delete failed
  creation residue. Disclose concurrent-writer races and partial failures.
- Keep full help in the same-source `g` companion. Document persistent native
  Git/checkout effects, local data reads, refusal policies and recovery in
  README and SECURITY together. Test synthetic repositories and real ZLE
  journeys, including hostile literal values and post-cleanup dispatch.

## Git review workspace boundary

- `.zsh.git-review` owns bounded Git providers and review controllers. Its
  source-time work is definitions only; navigation detects it at invocation.
  No new public command, registration table, loader phase or key parser.
  Disabling the peer preserves ordinary `g` switch/copy and Git delegation.
- `.zsh.git-syntax` is an optional, order-independent token provider over the
  selected captured document. It has no public command or startup probe.
  `support/git-syntax.vim` is a shipped adapter asset, not a shell add-on; both
  installation modes must include it. Keep this boundary independent of Vim
  user settings and of the shell's command-line syntax classifier.
- Code syntax is lexical snapshot metadata. Analyze old/new sides separately
  and reset at omitted source gaps; label fragments honestly. Never fetch
  additional Git objects/files just to color a focused diff. Retain original
  document text and source anchors verbatim. Unsupported/missing/failed/limited
  syntax falls back visibly to the same readable diff, never a blank document.
- The syntax child uses only `/usr/bin/vim`, an empty environment with explicit
  PATH/UTF-8 locale, disabled vimrc/gvimrc/viminfo/modelines/plugins/swap/undo,
  and a system-only runtime path. Enable only reviewed OS syntax definitions:
  initially Swift, Zsh, shell, JSON and Python. No filetype detection, repository
  paths, source execution, user runtime scripts, HTML export or ANSI extraction.
  Feed captured source through private mode-600 FIFOs: Zsh 5.9 here-strings
  create temporary files, so `<<<` is not a no-disk transport. Return a
  versioned, request-ID-framed and fully validated protocol of numeric
  character spans and fixed semantic roles. No source temp files.
  Treat this as configuration hardening, never an OS security sandbox.
  Reference: [Zsh 5.9 here-string implementation](https://github.com/zsh-users/zsh/blob/zsh-5.9/Src/exec.c#L4383-L4406).
- Bound syntax independently: 64 KiB input, 3,000 document rows, 2,048 source
  characters per line, 4,096 spans and 128 KiB output. The child has an 800 ms
  analysis guard and its asynchronous parent request has a one-second liveness
  deadline. These are failure bounds for Vim, not keyboard, Git or rendering
  budgets; the input loop never waits for either deadline. A document workspace
  starts exactly one system-Vim child on entry, retains at most one nofile
  buffer per allowlisted language, and reuses it only for that screen session.
  Never create a daemon, persistent cache, neighboring-file prediction or a
  queue of Vim processes. Always close descriptors and kill/reap the owned
  child; keep job state isolated from the user's shell.
  Syntax acquisition is passive and pane-focus independent. After layout
  publishes the exact source viewport, an input-idle callback schedules one
  bounded multi-page window around it: normally three visible source spans on
  each side, clamped to 256 guard rows and reduced when the byte bound requires
  it. Refill two visible spans before an interior edge while the installed
  highlighted window still covers the reader. Provider
  startup, request completion and response parsing never block the input loop.
  Assign each request a monotonically increasing generation; permit exactly one
  in-flight request, keep no process queue, and let only the generation that
  still matches the current document and viewport publish. Discard stale
  responses before they touch caches or render state, then schedule the latest
  desired viewport. Use the explicit stable loading surface only when no
  installed syntax window covers the current reader. During same-document
  read-ahead, retain the existing colored frame until its complete replacement
  validates; a speculative failure must not erase valid coverage. Never paint
  plain code and fill its colors later. A missing, invalid or timed-out response
  retires that child request
  without poisoning other documents or the whole screen session. Retry the
  current settled viewport once; only a second transient failure for the same
  captured document window becomes an explicit plain fallback. Deterministic
  unsupported, size and locale outcomes may become plain immediately. Include
  the capture-snapshot epoch in publication identity so a refresh cannot accept
  an older response after numeric indexes are reused.
  Cache one bounded syntax window with each of the four raw snapshot keys,
  invalidate it with its snapshot on refresh, and release descriptors, FIFOs,
  child, buffers and caches on workspace exit. Measure resident request,
  validation, render and paint costs separately.
- Diff backgrounds and lexical foregrounds are distinct layers. Green/red
  backgrounds identify additions/removals, with +/- for non-color recognition.
  `ZSH_HIGHLIGHT_STYLES[review-*]` owns shared customizable colors; token spans
  preserve their row background, while navigator selection stays independent.
  Map raw character spans through tab/control sanitization and cell-aware
  wrapping before native ZLE highlighting. Do not embed escapes in document
  text. Test Unicode, wraps, empty tokens, missing grammar, size/time limits,
  cancellation, hostile config/modelines, cache/refresh and native ZLE cleanup.
  Apple's OS updates may change grammar coverage; do not promise automatic
  support for every language or make a beta Vim version a requirement.
- Ctrl-X on Branches selects **current working changes**, **selected branch
  commits**, or **Compare branches or commits**. `g --review` opens the same choices for
  the current checkout. Distinguish their scopes explicitly. Commits open a file-and-diff
  document workspace; working changes opens that workspace directly.
  Resolve a branch tip once to a full hex object ID and retain first-parent
  IDs for stable commit review. A root commit compares with the empty tree.
  Disable replacement refs so captured IDs refer to literal objects.
- Revision comparisons use the existing document workspace. Setup reads
  Compare (To) against Against (From); both choices are explicitly editable.
  All differences compares From → To; Changes since common ancestor compares
  their unique local merge base → To. No inferred branch of origin or fixed branch name. Accept only
  explicit local branch/tag/remote-tracking names, HEAD, or unambiguous commit
  IDs; reject ambiguity, revision expressions and ranges. Capture at most
  1,000 refs/256 KiB, counting excluded refs toward discovery, and retain typed
  input as literal text until submission. Ref selection accepts the best match;
  literal entry retains a stable second slot, first when no refs match. Resolve full IDs once, expose the
  actual endpoints in the guide, and retain them on Ctrl-R. Re-selecting a ref
  explicitly acquires its newer tip. Missing objects, absent ancestry or
  multiple merge bases never change the method silently. Setup and direct
  `g --review [--merge-base] A B` share the same providers and reader; Back
  restores setup or exits the direct entry. No checkout, index mutation, fetch
  or persistent comparison state. Design evidence:
  [General Git comparison](investigations/git-comparison-design.md).
- Review is read-only. No stage/discard/commit/checkout, clipboard or app
  action is dispatched from these views. The main branch picker retains its
  original actions after terminal cleanup. Do not add mutation shortcuts
  without a separately authorized design and behavioral tests.
- Use the shared screen owner, collector, renderer, semantic palette, busy
  painter and input loop. A fixed shallow view nesting scopes snapshots and
  list bookmarks; no general workflow engine. Escape restores list query,
  selection, viewport and focus. Resize never calls Git.
- File selection and document inspection have separate service paths. The
  shared input loop applies and paints every complete navigation sequence
  immediately; when selection outruns the loaded document, the reader shows a
  stable loading surface with matching geometry. Reset a short preview-settlement
  window after each further navigation key, then return exactly the latest exact
  target to the controller after input is quiet. Only the controller may capture
  and parse that target's diff outside the input loop. This is coalescing of
  expensive preview work, not input debouncing: never flush, discard or infer
  release of repeated terminal keys. Every complete sequence is user intent,
  and Terminal.app supplies no key-up event. Keep the list-only selection/paint
  path comfortably below the observed repeat cadence. Optional provider work
  belongs in a latest-request-wins input-idle operation, never behind an extra
  focus step merely to hide latency. Test a buffered native-PTY arrow burst and
  assert that it loads only its initial and final documents, then that the next
  independent key applies to the final selection with no unread movement tail.
  Evidence and portability
  notes: [Git review key-repeat latency](investigations/git-review-key-repeat-latency.md).
  Refinement can select another file and request its diff; filtering the list
  itself remains provider-free. Scrolling, resize and guide never capture Git;
  scrolling may update the syntax viewport request without blocking input.
  Retain four raw file/context snapshots (at most 1 MiB) for this workspace,
  with per-file reading offsets. A loading placeholder must not overwrite a
  saved reading position. Release captures/bookmarks on workspace exit.
  Right discloses file navigator → focused diff → full-file context; Left
  reverses the sequence. At either boundary the arrow is inert. Untracked
  previews and metadata/notices have one reading level. Ctrl-R refreshes the
  file workspace. Ctrl-X opens the captured Change atlas only where that
  capability is present; an atlas child reader does not recursively offer it.
  Tab/Shift-Tab and Ctrl-E/B change only pane focus and preserve context mode;
  Right from the navigator always enters focused diff. The shared loop returns
  explicit disclosure/refresh requests; only the controller captures their data.
  Start focused with three context lines around each hunk. Context mode remains
  until another disclosure changes it; changing it preserves each file's source
  anchor rather than reusing a visual offset from a differently sized document.
  The shared UI peer maps wrapped rows to logical document lines; Git owns
  old/new coordinates.
  Anchor the first visible code line, resolving a hunk header forward and a
  trailing notice backward. Deletions use old-side coordinates; context and
  additions use new-side coordinates. Collapse into omitted unchanged code
  seeks the nearest retained same-side line; ties prefer earlier context.
  Report a nearest-context adjustment, retain existing capture limits and their
  notices, and reset to the notice when no code remains. Refresh follows the
  same anchor rule. Same-mode selection preserves the visual position. Never
  claim content tracking through concurrent edits. Test wrapped lines, gaps,
  deleted/new files, truncation, cache visits and native mode-switch journeys.
  Refresh rechecks Git filter-safety configuration, recaptures the file list,
  and reloads only the selected diff eagerly, outside the input loop. Manual
  Ctrl-R does this synchronously; Working changes also performs it through the
  bounded automatic-refresh path below. Keep the
  filter and identify the selection by literal path AND change kind, then find
  its new filtered rank; numeric IDs are valid only within one observation.
  Retain pane focus, context mode and source anchor for a surviving selection.
  Manual refresh may explain a selection that left the filtered results and
  focus the first match in the file list, in focused mode. Empty lists remain
  refreshable.
  Invalidate every raw/token/context cache and other-file reading bookmark on
  successful refresh; never let cached full context resurrect an older diff.
  On list/configuration failure, retain the previous observation with a retry
  status; propagate cancellation. Failed safety preparation must block uncached
  diff reads until retry, while allowing already captured documents. Keep newly
  validated filter overrides even if the following list read fails.
  Commit-file refresh retains immutable IDs.
  Ctrl-X may navigate to a Change atlas derived solely from the captured list.
  Keep original numeric file/change-kind identities beneath directory-prefix
  grouping. Expose source bounds and partial notices; bars count entries and
  must not imply content analysis. Child folders and file readers preserve Back
  bookmarks, and returning to review preserves its filter/focus/source anchor.
  Stop pending automatic-refresh work while this child workspace is open;
  resume its schedule only after return. Read selected files through existing
  bounded safe providers, retaining commit/comparison IDs; never discover child
  paths or bulk-read contents to paint the atlas.
  Working changes starts automatic refresh unless the initializer set
  `ZSH_GIT_REVIEW_AUTO_REFRESH=0`. Ctrl-A pauses or resumes it for only the
  current review screen; Ctrl-R checks immediately and resumes after an
  automatic failure, while an intentional pause remains paused after manual
  success or failure. Commit and comparison workspaces remain immutable-ID
  snapshots and refresh only on Ctrl-R; reopening branch history discovers new
  commits. Show separate relative ages for the last completed local check and
  the last published snapshot, so an unchanged automatic check never implies
  a snapshot update.
  Automatic checks are input-idle and keep at most one owned worker/provider
  pair in flight. Use a private mode-0700 invocation directory, mode-0600 FIFO,
  bounded in-memory provider streams, a framed literal-data
  protocol and the existing 1 MiB snapshot cap. Start no daemon, hook or
  persistent watcher/cache. The worker performs only the same bounded,
  transport-disabled local status and selected-diff reads as manual refresh.
  The worker must own the exact Git provider PID in memory so pause, manual
  refresh, timeout and screen cleanup terminate and reap the provider without
  signalling a parent-visible handoff PID. Pace checks
  no faster than two seconds and at least four times the capture duration
  measured inside the worker, capped at thirty seconds. Give one check a
  screen-session thirty-second deadline that does not depend on ordinary
  picker-idle callbacks or an empty terminal-input queue. A failed or timed-out
  automatic check retains the old
  observation, pauses further checks and exposes Ctrl-R as retry.
  Parse and validate a complete worker result before publishing it. Publish a
  changed snapshot with one repaint and no busy/blank intermediate frame,
  preserving filter, exact path and change kind, filtered rank, viewport slot,
  pane focus, context mode and semantic source anchor. If that target disappears
  or leaves the active filter while the reader is focused, retain the old reader,
  show `update ready`, and publish only when focus returns to the file list; do
  not move focus automatically. A disclosure change invalidates a pending diff
  candidate and waits for the next normally paced check. Guide, resize,
  scrolling and filtering remain
  provider-free, though ordinary input-idle time can make a due automatic check.
  Working-file lists and later diffs are
  separate observations, not an atomic transaction. Failed reads must be
  distinguished from successful empty snapshots. Preserve abort propagation.
- Git invocations disable optional index writes, fsmonitor, hooks, lazy fetch
  and network protocols, external diffs and textconv. Discover configured
  clean/process filter names and override them to inert values per invocation;
  disable required-filter enforcement too. Never change repository/global
  configuration. Refuse a capped/failed filter-name discovery and any driver
  containing `=`, which Git's `-c key=value` form cannot address unambiguously;
  bound the generated override argv to 4,096 entries in both manual and
  automatic paths.
  Explain the
  unfiltered comparison in help. These measures are not an OS sandbox.
  References: [Git diff](https://git-scm.com/docs/git-diff),
  [Git status](https://git-scm.com/docs/git-status),
  [Git environment](https://git-scm.com/docs/git).
- Parse NUL-delimited paths with literal pathspec semantics; validate full
  commit IDs before treating them as revisions. Reject escaping paths and
  special working files; do not follow replaced parents outside the worktree.
  Selected untracked regular text files use the same numbered reader as
  all-additions patches in both context modes. Prefix every source line so
  header-like text stays inert. Modes share one snapshot/cache key; refresh
  invalidates that same key. Read only on selection/refresh, without execution,
  staging, Git filters, directory scans or caller-directory/hook changes.
  Use native no-follow, nonblocking open and descriptor stat to reject symlink
  and special-file replacements; pin and validate a physical parent in a
  subshell. Bound bytes across short reads, preserve trailing newlines, and
  distinguish read failures from empty files. A NUL in the captured prefix
  yields a binary notice; do not claim universal binary detection. Keep
  symlinks/folder entries as notices, missing/unsafe/read failures unavailable,
  and conflicts as notices. Test replacement races and mode/refresh reuse.
  Reference: [Zsh system/stat modules](https://zsh.sourceforge.io/Doc/Release/Zsh-Modules.html).
  Use Git status with `--untracked-files=all` so new-directory files are
  individually selectable. At the navigator boundary, keep nested relative
  paths as primary row labels and adapt their metadata to the complete compact
  word `New`; never combine state and folder into one truncation-prone field.
  Keep canonical `Untracked` wording and exact relative paths in captured facts,
  filtering, details and document context; presentation must not weaken or
  replace the source fact. Git owns enumeration;
  honor ignore rules and retain byte/row limits. Do not introduce a second
  recursive walker or perform enumeration on movement/redraw. Git may still
  report nested repositories as folders; keep them as separate-repository
  notices. Directory replacement races also remain notices, never scans.
  Measure added capture cost and document that large untracked trees may be
  slower; retained-output bounds do not cap traversal time. Exclude submodules. Renames
  are add/delete pairs. Treat all Git strings as inert, sanitized display data.
- Retain at most 256 KiB per capture, 1,000 change rows or 200 commits, with
  visible partial-result notices. Counts describe captured data. A continuous
  document has at most 10,000 logical / 20,000 wrapped lines, with notices.
  Full-file context is opt-in and retains the same capture bounds.
  These bounds do not promise a wall-clock timeout or bound Git's own
  memory/CPU usage. Do not add background processes or persistent caches.
- The shared document capability gives the navigator roughly one third of the
  width (at most 42 cells), with the remainder for reading. Below 90 columns,
  switch between full-width navigator and reader. Use available body height;
  Tab/Shift-Tab switches focus, Enter/Ctrl-E reads, Ctrl-B focuses files, and
  Up/Down and page keys scroll the focused pane independently. Reading never moves
  to another file. Preserve per-file offsets; a pending frame shows no stale
  content from the prior selection. Ordinary secondary inspectors keep their
  list-first policy and 256 wrapped-line bound.
  Git supplies continuous lines, old/new line numbers and semantic +/− roles;
  the shared renderer sanitizes and wraps them, caching wrapping until the
  selection or width changes. Never evaluate source code or terminal escapes.
- Test actual g → options → changes/history → file reader → Back with real
  ZLE, single alternate-screen ownership, guide/resize, retained bookmarks,
  aborts and unavailable peers. Use disposable repositories for staged versus
  unstaged rows, binary/unborn/merge commits, unusual paths, configured helper
  suppression, immutable IDs, limits and unchanged index/configuration.

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
  Return submits a nonempty query;
  typing, redraw and resize cannot discover. Label memory-only input **Filter
  folders** in Browse and **Filter results** after discovery. Ctrl-F in results
  edits the submitted query using the same source/root; cancel retains the
  snapshot. Back to Browse restores filter, selection, viewport and preview
  focus in the same screen session. Ctrl-X retains explicit source choices.
  Secondary menus/query entry and unrelated tools must suppress this capability;
  Ctrl-E/B owns detail/list focus throughout the shared modal UI. Keep normal
  prompt editing and autosuggestion bindings unchanged. Test actual key bytes,
  cancellation, scope and capture counts alongside shared hint/guide contracts.
- Option-Tab at the ordinary prompt opens Recents. Enter and visible digits use
  the same insertion dispatcher as path + Tab: replace the draft with the exact
  quoted path, place the cursor at its end, and repaint it visibly after screen
  cleanup. Selection must not change PWD or the stack. Submission at the normal
  prompt performs AUTO_CD. Cancellation and copy preserve the existing draft,
  cursor and directory. Test empty/nonempty drafts, Enter/digits, quoting and
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

## Xcode workspace boundary

- `.zsh.xcode` owns both the native Xcode action workspace and Apple skill export.
  Source-time behavior remains definitions only: never probe Xcode, enumerate
  projects, start Simulator, export skills, or write files while loading the
  peer. `xcode` owns workspace and `--export-skills` modes through its one
  same-source help companion; no separate public skill-export command remains.
  Interactive export reviews captured agent destinations in the shared action
  view before staging or writing. Escape cancels. Noninteractive/dumb/missing-UI
  export retains direct execution, explicitly documented. No project discovery
  is required for export, and no exporter runs while its plan is painted.
- Bare `xcode` discovers only literal `.xcworkspace` and `.xcodeproj`
  directories while walking upward from PWD. Stop at the nearest scope, offer
  workspaces before projects there, reject symlink containers, and never scan
  descendants. Except for the owned `--export-skills` mode and help, arguments
  delegate directly to `xcodebuild` and preserve
  its status. A dumb/noninteractive bare call may print the nearest container's
  safe native list; it must not open the modal workspace.
- Xcode owns scheme, destination, build, test and settings semantics. Request
  machine-readable JSON where the CLI provides it and parse it with the system
  `plutil`; accept the documented destination listing only after validating a
  fixed platform vocabulary and literal stable identifier. Bound every retained
  provider capture (currently 256 KiB), diagnostic and item count. Retain every
  validated scheme within those bounds; an exceeded item bound fails with no
  partial catalog. No repaint, filtering, focus, scrolling or resize may invoke
  an Xcode provider.
- Use the shared full-screen renderer, screen owner, input loop, guide, focus
  language and temporary-screen cleanup. The dashboard is one shallow
  controller over Container → Scheme → Destination → Action, with configuration
  choices returning to the action dashboard. Do not add a renderer, key parser,
  persistent background watcher, workflow framework, persistent project state or new
  shortcut. Keep each digit-select Xcode page at ten rows so every visible index
  is reachable with one of 0–9; ordinary paging retains later candidates.
  Dispatch every action only after the screen is restored, and revalidate that
  the exact captured container leaf still exists, matches its project/workspace
  kind and is not a symlink immediately before execution. Test may
  start a new screen session after xcodebuild returns, using only its already
  captured result snapshot; it must never run a provider from the renderer.
  Destination compatibility may reuse an LRU of at most four successful parsed
  scheme snapshots inside this controller only. Retain exact IDs, platforms and
  names; never cache raw output or failures. Returning to a cached scheme performs
  no provider call. **Refresh destinations** explicitly replaces the current
  snapshot while preserving an exact surviving identifier. Release every entry
  on action, cancellation or workspace exit; reopening `xcode` is always fresh.
  A refresh that cannot retain its newly parsed snapshot must forget the prior
  scheme entry and fail explicitly rather than allowing stale restoration.
- Discovery is read-only coordination, though Xcode may inspect project and
  package metadata. Always disable automatic package resolution and package
  updates and require versions from `Package.resolved`. Never silently enable
  provisioning updates or skip package-plugin/macro validation. Keep these
  policy arguments centralized and cover their exact presence/absence in tests.
- Build, Rebuild, Test, Rebuild & Test, Analyze, Clean, Build & Run and Rebuild
  & Run are explicit code-execution boundaries. Project build scripts, package
  plugins, macros, tests and app code may execute. State this in the dashboard,
  README and `xcode --help`; never run an action merely to populate details.
  Native build/test output belongs in the restored terminal. An explicit
  Simulator Run may then open its scoped app-output view as described below.
  Build, Test and Build & Run use Xcode's normal incremental
  `build`/`test` actions. Do not infer artifact freshness from Git state,
  filesystem timestamps or private DerivedData metadata; Xcode owns the target
  membership, dependency graph and rebuild decision. Rebuild and **Rebuild &
  Run** are explicit slower recoveries that send ordered `clean build` actions;
  **Rebuild & Test** sends `clean test` for the exact scheme and destination.
  Never trigger these recovery actions automatically. Both test modes add
  one temporary result bundle, then use bounded `xcresulttool` summaries,
  failed-test source locations and build issues to reopen a shared result view.
  Show success and failure with the shared semantic palette, retain exact
  scheme/destination context and mode, keep the native action status, read no
  attachments or source contents, disable verbose test-diagnostic collection for
  that transient bundle, and remove it before presenting the snapshot. When
  `pbcopy` is available, the result view may offer one explicit **Copy report and
  done** candidate. Build its plain text only from the retained snapshot,
  including the native status, mode, exact test context, totals, every retained
  test/build failure, identifiers, reasons, involved files and capture
  limitations. Perform the clipboard write after screen restoration, recheck the
  captured executable, never read source files or the clipboard, and preserve a
  failing native test status even when copying succeeds or fails.
- Simulator Run initially supports only an exact simulator destination. Build
  incrementally, or clean then build only for explicit Rebuild & Run, derive one
  installable `.app` and validated bundle identifier from bounded `xcodebuild
  -showBuildSettings -json`, then use `xcrun simctl` to boot, install and launch
  it; opening the selected Xcode's Device Hub or Simulator app is part of that
  explicit action. Do not claim
  physical-device launch, alter signing, choose a generic destination or infer a
  product or target membership from recursive filesystem search.
- After an explicit Simulator launch, the Run view reuses the shared picker
  with Stop, Read output, and conditional LLDB actions. Retain only the newest
  32 KiB/200 lines of combined app stdout/stderr and scoped unified logs as a
  live tail, plus bounded frozen preview and full-reader snapshots, in memory.
  Each source may retain at most 8 KiB of an unfinished line. Two private mode-0600
  FIFOs beneath a mode-0700 invocation directory in the selected Simulator's
  `data/tmp` carry output; they are never log files. Resolve that exact device's
  data root with a bounded native capture, validate the root and temporary
  child, and keep the host FIFO path separate from the Simulator-relative
  launch path. Cleanup uses the captured host root. Explicit Run replaces an
  already-running instance of that selected bundle with
  `--terminate-running-process`, and sets `SIMCTL_CHILD_NSUnbufferedIO=YES` only
  for launch. App-controlled buffering can still occur. Read at most 32 KiB per
  shared idle turn, fairly across both sources; never read during paint or
  resize, and keep input priority. Freeze displayed text while reading or in
  the guide; returning to Run actions follows the newest tail in its preview.
  Disclose a failed source while allowing the other to continue. No source-time
  work, persistent worker, or new key map.
- Read output composes a reader-only shared document view: full width, wrapped
  up to the shared 20,000-row bound, with no selectable or numbered log rows.
  Type a case-insensitive literal substring to filter captured source lines;
  counts refer to source lines, not wrapped rows. Follow the latest retained
  tail automatically by default, preserving the literal filter as output
  arrives. Scroll upward to pause publication; reaching the bottom or Follow
  latest resumes. Retain the mode, filter and paused snapshot/semantic reading
  bookmark through Options, Return to Run, reopen, and Copy. Capture continues
  in the Run owner. Options and the guide hold displayed text and raw copy
  scope; returning resumes the prior mode. Reuse the shared opt-in document
  following capability, with no mandatory refresh command or new key map.
  Unchanged raw output must not trigger formatting or repainting; capture
  status and limit changes still need visible updates. Enter opens options;
  Escape/Ctrl-G returns to Run, and Options Escape
  returns to the reader. Reader-only controls must not expose a phantom list
  focus, result count or digit action. Reuse the shared key map and guide.
- Format recognized native compact records using a bounded pure text helper:
  compact time/severity/scope header, separate message body, and spacing
  between entries. Keep textual severity and existing semantic palette roles;
  unrecognized lines stay plain, and message words never infer severity.
  Matching/counts/copying use the original source lines, including omitted
  display metadata. Keep formatted rows and regex scratch local, sanitization
  in the shared renderer, and wrapping under its existing document bound.
- Explicit Copy all captured logs, Copy filtered logs, or reader Ctrl-Y freezes
  the complete matching raw lines from the displayed snapshot, including
  offscreen content, without UI labels or wrapping. Offer copying only for
  nonempty matching text and a captured clipboard capability. Options copying
  uses the display captured when Options opened, even as new output arrives;
  direct reader copy uses the currently displayed capture. Revalidate that
  executable and write only after screen restoration; never read the
  clipboard. Reopen Run with visible success/failure feedback and preserve the
  reader bookmark and running app. Clipboard failure must retain a nonzero run
  status even after a later successful action. Copied text outlives the run
  under operating-system/user control and may retain native private payloads;
  keep that boundary explicit in public privacy documentation.
- The Run unified-log observer is scoped to the exact selected Simulator and
  canonical installed `CFBundleExecutable` path. Start the device's native
  `log stream --level debug --style compact --color none` through
  `simctl spawn`, with an exact `processImagePath` predicate applied before
  delivery; never collect a broad stream and filter it afterward. Start the
  observer before app launch and wait only a bounded time for its native
  readiness header. Set `LOGRC=/dev/null` only for that log child so personal
  `.logrc` rules cannot broaden capture. Include framework records emitted
  inside the app; exclude helpers/extensions with different executable paths.
  Disclose that another launch of the same exact executable can match, native
  records can drop, startup capture can race, duplicate messages can reach both
  sources, and merged read order is not guaranteed timestamp order. Never
  enable private-data logging or alter native privacy behavior; do not promise
  redaction, because native Simulator defaults can expose private payloads.
  The observer belongs only to this run: stop and reap it before LLDB and in
  normal/error cleanup. There is no persistent logging configuration or daemon.
- Resolve the Run PID solely from simctl's separate launch response, never app
  output. Revalidate its observed user/start time/executable before LLDB and
  before stopping the exact Simulator bundle. Disclose non-atomic exit races.
  Escape/Stop in Run and handled errors stop the run after screen restoration.
  Escape in its full log reader returns to Run without stopping the app. LLDB
  receives the restored terminal with automatic init and symbol-script loading
  disabled; one scoped native child drains/discards stdout/stderr until LLDB
  exits, then cleanup stops the run and reaps the drainer. Never change signing, use
  sudo, attach by a guessed name, or silently launch a different app. A closed
  output stream is not proof of process exit. Preserve launch/debugger failure
  status and disclose missing identity, failed stop, and crash cleanup limits.
- Test discovery order, spaces in literal paths, complete multi-page scheme
  catalogs, bounded/failed JSON, hostile destination text,
  no-scheme/no-destination states, argument delegation, noninteractive fallback,
  cancellation, resize cleanup, ten-row digit pages, container replacement,
  failed refresh eviction, exact incremental/rebuild action arrays and Simulator
  dispatch with PATH-shadowed first-party command spies. Cover hostile literal
  action arguments, result-bundle symlink rejection, destination provider-call
  counts, exact cache restoration, four-scheme eviction, explicit refresh, and
  successful test totals, assertion and build-stage failures, source locations,
  semantic result colors, bounded report contents, conditional clipboard
  affordance, post-screen copying, native output/status preservation and
  result-bundle cleanup. Run tests must cover the exact installed-executable
  log predicate, child environment isolation, bounded observer readiness,
  fair source draining and partial-line bounds, independent source failure,
  replacement launch, and observer stop/reap before debugger handoff and on
  cancellation/error. Cover full-width reader geometry, source anchors after
  resize/reopen, literal source-line filtering/counts, live no-match recovery,
  scroll pause/resume, stable guide/Options copying, quiet callbacks,
  independent action/reader bookmarks, complete matching
  clipboard payloads, post-screen copying, and visible/sticky clipboard failure.
  Real Xcode/Simulator checks are optional host
  integration tests and must not read private project data or mutate a user's
  active project.

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
- Pickers with visible single-digit indexes may accept an indexed digit
  immediately while the query is empty. Only activate an index that is visibly
  rendered, and preserve digits as ordinary search text after filtering begins.
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
  workspaces follow the separate Git review contract above. A caller can opt
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

## Safety and security

- Starting a shell or drawing a prompt must never access the network.
- Privacy is a top-level product goal and an implementation constraint, not a
  documentation slogan. Minimize every read and capture to the facts, scope,
  and lifetime required by the user's visible task. Prefer transient in-memory
  state. Do not introduce telemetry, behavioral profiling, identifiers, a
  project-owned persistent cache, or speculative collection “for later.” A
  useful feature is not justification for collecting unrelated information.
- Handle private or sensitive information only through a deliberately defined
  effect boundary. Keep values literal, bounded, and out of shell evaluation,
  command construction, diagnostics, terminal titles, screenshots, fixtures,
  and public reports. Do not copy or retain a value merely because it was
  available in the environment, filesystem, Git metadata, tool output, or
  terminal session. Fail closed when scope, ownership, identity, permissions,
  destination, or cleanup cannot be established safely.
- Never receive or persist plaintext passwords, tokens, private keys, recovery
  codes, session cookies, or authentication answers. Authentication input must
  go directly to the operating system or explicitly chosen trusted tool. Use
  least privilege, non-prompting retained authorization after the visible
  authentication step, exact targets, and the shortest practical lifetime.
  Never weaken file or directory access controls while preserving user-owned
  history, configuration, or recovery data.
- New persistent storage requires an explicit product need and user-visible
  documentation of its exact path, contents, ownership, access controls,
  retention, cleanup, crash residue, recovery behavior, and uninstall result.
  Preserve existing user-owned modes and ownership, create sensitive state with
  the least access the platform supports, reject symlink/special-file and path
  substitution hazards, and test failure cleanup. If those properties cannot
  be guaranteed, do not store the data. The existing local history and recovery
  boundaries remain fully disclosed in `SECURITY.md`; do not silently expand
  them.
- All data Compozsh reads, captures, derives, or stores must remain on the
  machine running its Zsh process for all Compozsh-owned processing and
  storage. No Compozsh-owned operation may transmit user or project data under
  any circumstance. There is no telemetry opt-in, consent exception, feature
  flag, debugging exception, or future product mode that may weaken this
  invariant. A proposed feature that requires project-owned transmission is
  incompatible with Compozsh and must be rejected.
- Treat user-configured synced or network-mounted storage, operating-system
  clipboard synchronization, explicitly invoked external programs, and hosted
  services as separate trust boundaries. Compozsh must never configure or
  silently select those external destinations. Disclose every local handoff and
  the steps required for physical single-machine retention; never hide an
  independently controlled transfer behind an unqualified “always local” claim.
- An external program remains a separate trust boundary when the user
  deliberately asks that program to communicate—for example, by invoking
  `git push` through the transparent Git wrapper. Compozsh must not add data,
  destinations, requests, uploads, synchronization, or background activity to
  that explicit external command. Disclose this boundary precisely; never use
  it to disguise project-owned transmission or claim that the external program
  keeps its data local.
- Before declaring any work complete—including a refactor, documentation-only
  change, test change, website change, or agent-workflow change—compare the
  final diff with `SECURITY.md`. Explicitly determine whether it changes a
  network or update path; collection, reading, storage, retention, display, or
  transmission of user data; history, clipboard, Keychain, credential, token,
  environment, project, or private-configuration access; temporary or
  persistent state; an external command or hosted-service boundary; privilege,
  `sudo`, authentication, destructive behavior, or recovery; project-code
  execution; dependencies; or any documented audit result. If it does, update
  `SECURITY.md` in the same unit of work and add or revise focused regression
  coverage. If it does not, completion still requires verifying that every
  existing security claim remains true for the final tree.
- Security documentation requires full disclosure, including inconvenient
  limitations. State what data is read, where it comes from, where it is kept,
  its lifetime and cleanup limits, what can leave the machine, the destination
  and trigger, the exact privileged boundary, who receives authentication
  input, and which operating-system, hosting, installed-tool, repository,
  private-peer, and user-action behaviors remain outside Compozsh's guarantee.
  Distinguish shipped-code guarantees from assumptions about external tools.
  Never use broad claims such as “local,” “safe,” “private,” or “no phone home”
  to conceal an exception or transfer of trust.
- Every material `SECURITY.md` claim must be independently checkable against an
  exact commit without first executing Compozsh. Provide the relevant readable
  source boundary plus copy-paste commands or focused tests using Git, Zsh, or
  stock macOS tools; state the expected output/status and the check's limits.
  Keyword searches and deny-lists are regression aids, not proofs. Keep the
  README and website links to the policy working, and keep the reporting and
  supported-version guidance accurate. Agents must never replace verifiable
  evidence with a maintainer assurance.
- Treat this as a public repository. Never commit a real name, personal email,
  private username, home-directory username, hostname, device identifier, IP
  address, internal company or project name, absolute machine path, terminal
  history, screenshot containing private data, credential, token, or secret.
  Use neutral examples such as `user@host`, `~/Projects/example-app`, and
  documented placeholders. A public repository-owner URL is allowed only when
  it is intentional and required for working installation instructions.
- Before every commit, inspect the staged diff and search the complete tracked
  tree for private data and secrets. Before a public release, also audit every
  reachable commit, tag, branch, commit author/committer identity, signature,
  remote URL, and historical file version. Deleting data in a later commit does
  not remove it from Git history.
- Publish only explicitly reviewed branches and tags. Never mirror local refs
  with `git push --mirror` for a public release: tool, checkpoint, stash, or
  notes refs are not part of the product and may contain unreviewed snapshots.
- If private data is found in history, stop and report it. Never rewrite shared
  history or force-push without the user's explicit approval. If a credential
  was exposed, instruct the user to revoke or rotate it before rewriting;
  history cleanup alone does not make a credential safe again.
- Never source or execute code merely because it exists in the current project.
  Startup sourcing is restricted to the fixed/explicit local initializer,
  shared add-ons adjacent to the resolved bootstrap, and private peers in the
  fixed user add-on directory. Add-on names and paths must never come from the
  current working directory or project metadata.
- Never interpolate unsanitized branch names, paths, history, or tool output
  into prompt syntax, glob patterns, terminal control sequences, or shell code.
- Treat receipt compaction as presentation, never redaction. The transcript
  prefix may change prompt decoration but must retain the exact submitted
  command as ZLE input, create no second persistent command copy, and make no
  claim to remove it from terminal scrollback, process exposure, invoked-tool
  logs or normal Zsh history.
- Explicit add-on installers may write only to documented, fixed user-level
  integration directories. Stage generated content first, mark installed units,
  and never replace a same-named directory that lacks the installer's marker.
  Temporary cleanup must validate its exact `mktemp`-created target.
- The repository installer may replace only the active bootstrap, its own
  marked copy namespace, and—when `--clean` is explicit—the complete add-on
  tree after moving existing state to a recovery backup. It must never modify
  `.zshenv`, `.zprofile`, `.zlogin`, `.zlogout`, a private initializer during a
  normal install, or an unmarked same-named namespace.
- Install only for integrations actually detected on the machine. Prefer cheap,
  deterministic discovery through CLI commands on `PATH` and documented local
  application bundles; do not launch applications, authenticate accounts, scan
  arbitrary disks, or create empty vendor configuration directories.
- Missing optional tools are normal. Detect them cheaply and degrade cleanly;
  show `not-installed` only when the current project makes that fact relevant.
- Destructive conveniences require exact scope discovery, a clear preview, an
  explicit confirmation defaulting to no, and refusal during unsafe Git states.
- Do not broaden deletion behavior to ignored files, nested repositories,
  submodule contents, stashes, commits, or paths outside the resolved root.
- Do not add secrets to examples. Mention secret handling only to direct users
  toward private, untracked configuration or a proper secret store.
- Preserve `NO_CLOBBER`/`CLOBBER_EMPTY` protections and terminal-only color
  semantics unless the user explicitly changes the product contract.

## Test-driven development

Use strict red-green-refactor for every observable product change. Do not edit
the production implementation before establishing the red phase:

1. State the observable contract. For a bug, first add the smallest regression
   test that fails for the reported behavior. For a feature, first encode its
   intended success, fallback, and safety behavior where practical.
2. Run the focused test and confirm it fails for the intended reason. A test
   that passes before the change, fails because of a harness mistake, or tests
   an unrelated implementation detail is not a valid red phase.
3. Make the smallest correct, safe, idiomatic Zsh 5.9 implementation pass.
4. Refactor only while the focused test and complete suite remain green.

A bug regression is valid only when it demonstrably fails against the buggy
implementation. Preserve that test after the fix. A new feature test must fail
because the capability is absent, not because its fixture is incomplete. Never
weaken, delete, skip, or overfit an assertion merely to turn the suite green.
Run a focused description filter during the loop, for example
`zsh tests/run.zsh fuzzy`, and run the unfiltered suite before handoff.

Pure documentation edits do not require manufacturing a failing product test.
A behavior-preserving refactor begins from green characterization coverage; add
missing characterization tests before moving code. When behavior is inherently
visual or terminal-driven, write the smallest deterministic automated contract
for its underlying logic first, record the manual reproduction and acceptance
criteria before implementation, and complete the change with a real PTY check.

Prefer tests against public behavior and durable state. A focused test may call
an underscore-prefixed helper only when that narrow algorithm is the contract
being protected and exercising it through ZLE would make the test ambiguous.
Do not make private names public merely for testing.

Every automated test must be deterministic and isolated. Use a disposable
`HOME`/`ZDOTDIR`, a minimal environment, fixed locale, and validated
`mktemp`-created paths. Never source the operator's real configuration, inspect
private history or add-ons, depend on network access, launch GUI applications,
or perform destructive tests outside a disposable repository. Avoid sleeps,
wall-clock assumptions, machine-specific paths, installed optional tools, and
assertions on unstable presentation details.

Keep the harness smaller than the product. Add a shared test helper only for a
repeated lifecycle, isolation, or assertion rule; do not build a shell testing
framework inside the repository. Test architectural invariants such as
standalone sourcing and the [peer configuration laws](#peer-configuration-algebra)
directly; a browser model of those laws cannot validate the Zsh implementation.
Complement automation with a real PTY/ZLE check for key sequences, resize
behavior, colors, cursor motion, and terminal cleanup that a child-shell test
cannot establish.
For resize regressions, verify the painted editor display and preserved caller
state, and reject runtime diagnostics. Calculated layout values or a frame
marker alone cannot prove that a redraw succeeded.
For screen-cleanup regressions, send test synchronization over a separate
channel; printing markers inside the terminal changes the cursor and can mask
the fault. Include automatic pre-handler refreshes in resize coverage and
record Terminal.app's manual fullscreen/windowed acceptance result separately.

## Change workflow

1. Read the relevant section and its callers before editing. Search with `rg`.
2. Check `git status` and preserve unrelated user changes.
3. State the behavior and invariant being changed. Add or update the focused
   test first, run it, and confirm the expected red phase before implementation.
   Choose the smallest complete design that handles the real edge cases.
4. For latency-sensitive work, establish a reproducible baseline and compare
   plausible native Zsh 5.9 implementations before selecting one. Keep the
   benchmark proportional to the decision rather than building a permanent
   framework for a one-time comparison.
5. Implement with `apply_patch`; keep section ordering and comments coherent.
6. Update `README.md`, `SECURITY.md`, the shipped-unit inventory and repository
   layout, `templates/init.zsh`, and relevant `.zsh.addons/` documentation when
   their public behavior, security/privacy claims, unit boundaries, or
   extension points change. Even when `SECURITY.md` needs no edit, verify it
   against the final diff before continuing.
7. Test proportionally to the risk, including an actual ZLE session for
   interactive behavior.
8. Review the final diff for correctness, idiomatic Zsh, security, measured
   performance, quoting, and unintended semantic changes.
9. When the user requests commits, commit one coherent unit at a time with a
   short imperative message. Never stage unrelated files or push unless asked.

## Required verification

Run at least:

```sh
zsh tests/run.zsh
syntax_status=0
for syntax_file in .zshrc install.zsh templates/init.zsh tests/*.zsh \
                   .zsh.addons/**/.zsh.?*(N.); do
  zsh -n "$syntax_file" || syntax_status=1
done
(( syntax_status == 0 ))
git diff --check
test_home=$(mktemp -d) || exit
verify_status=0
TERM=xterm-256color HOME=$test_home ZDOTDIR=$test_home \
  ZSH_LOCAL_INIT=/dev/null \
  zsh -dfi -c 'source ./.zshrc; source ./.zshrc' || verify_status=$?
if [[ -d $test_home && ${test_home:t} == tmp.* ]]; then
  rm -rf -- "$test_home" || verify_status=$?
else
  print -u2 -r -- "Refusing unsafe test cleanup: $test_home"
  verify_status=1
fi
(( verify_status == 0 ))
```

Then select relevant checks from this list:

- For every change, reread `SECURITY.md` against the final tree and run the
  focused security and documentation contracts. When a sensitive boundary
  changes, exercise its independent audit commands, confirm their documented
  expected output and limitations, and include that evidence in the handoff.
- Whenever shipped add-ons change, compare every recursive repository-relative
  `.zsh.<name>` path with the README inventory. Every file must have exactly one
  current row and every row must resolve to a shipped file.
- When the loader or repository layout changes, exercise both symlinked and
  copied installations under disposable home directories and verify a public
  add-on command is discoverable in each.
- After changing add-on boundaries or shared state, source every enabled unit
  in normal, reverse, and at least one rotated order under isolated shells.
  Compare options, aliases, bindings, styles, hooks, prompts, and public names;
  checked orders must converge without load diagnostics. Apply the
  [peer configuration algebra](#peer-configuration-algebra) to repeated sourcing,
  affected runtime behavior, overrides, fallbacks and any regrouping as well.
- Inspect final bindings with `bindkey` under `xterm-256color` and
  `screen-256color`; exercise changed keys in a real PTY/ZLE session.
- Verify standalone Escape, bracketed paste, cancellation, redraw, and resize
  behavior after changing an interactive widget.
- Test prompt changes outside Git, in clean/dirty/detached repositories, during
  an operation, with missing tools, and at wide and narrow terminal widths.
- Test destructive Git helpers only in a disposable temporary repository.
- Confirm wrappers preserve plain output through a pipe or redirect and retain
  the underlying command's options and status.
- Time several isolated startups before and after latency-sensitive changes.
- Source twice to prove hooks, functions, and bindings remain stable.

Do not declare work complete merely because the file parses. Interactive shell
code is complete when its fallback behavior, display, failure paths, and latency
have also been checked and the documentation matches reality.
