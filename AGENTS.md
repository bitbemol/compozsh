# Repository instructions

These instructions apply to the entire repository. They describe the design
contract for humans and coding agents working on this configuration. Follow the
user's current request first; within that scope, preserve the principles below.

## Product contract

This project is a polished, self-contained interactive Zsh configuration. Its
core promises are:

- Local-only operation is the highest security invariant. All data Compozsh
  reads, captures, derives, or stores remains on the user's computer. No
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
| Viewport / visible row | The displayed slice of results / one presentation slot in that slice. A visible digit identifies a slot; the exact underlying value remains separate. |
| Selection / target | Selection identifies the active candidate. A target is the exact value and necessary scope an operation will use, such as repository plus branch; it may instead be an explicitly named current folder. |
| Target resolution | Turns a path or a selected recall result into an exact target for the next operation. It does not itself authorize insertion, directory change or execution; action dispatch validates mutable facts again. |
| Operation / transition | An operation is a supported step; a transition is its change to interaction context or state. Use the five operation categories in [Context-preserving composition](#context-preserving-composition). |
| Acceptance / action | Acceptance requests the visibly named primary operation. An action applies an explicit effect to a target, including insertion, copying, directory change or application launch. Acceptance can instead open another view. |
| Renderer / paint | The renderer derives frame text and styles from view state. Painting applies that frame to the terminal through the shared ZLE machinery. |
| Document workspace | A file navigator paired with a primary, independently scrollable reader, such as Git review. Distinct from a picker with secondary information. |
| Action workspace | A task workspace that composes captured configuration choices into one explicit post-cleanup action, such as Xcode scheme + destination + Build. It is not a live console or a general workflow engine. |
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
- Organize the showcase by recognizable tasks in one user-controlled terminal.
  Reveal specialized examples within their task and secondary features on
  request. Keep tab changes spatially stable; avoid autoplay and competing
  demos. Shared interaction code should consume bounded sample data.
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
  - A help request returns status 0, writes no diagnostics to stderr, and
    performs no project/configuration reads, mutations, navigation, clipboard
    access, operational tool detection, network access, or prompts. Never add
    a pager. Presentation alone may inspect stdout, TERM, NO_COLOR, and native
    terminfo capabilities; it must not launch subprocesses.
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
  byte-identical direct/provider output. Keep the README command inventory in
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
- Give each helper one clear responsibility: collect facts, sanitize data,
  calculate layout, render UI, or perform an action. Do not mix all five.
- Keep detection separate from presentation. Terminal resize handlers may
  recompute layout from captured facts but must not rediscover Git or runtimes.
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
and copying restore both, while path insertion replaces the draft. A related modifier gesture
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
- Prompt code should minimize external commands and never add a per-prompt
  subprocess when native Zsh state or an existing command result is enough.
- Runtime/tool versions may be cached only in memory for the current shell.
  Cache keys must include every environment selector that can change the
  answer, and `prompt-refresh` must invalidate the relevant caches.
- Do not add a project-specific disk cache, cache daemon, background worker,
  timer loop, or eager startup scan without an explicit architectural decision
  from the user. Zsh's native completion dump is not feature-state storage.
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

- Keep the prompt compact: two lines normally and an additional project line
  only when it conveys real context.
- Layout must respond to `$COLUMNS`, avoid wrapping the active prompt, preserve
  the highest-value facts first, and restore hidden facts when space returns.
- Never claim completed scrollback can be dynamically relaid out after resize.
- Use `…` for width-aware abbreviation and keep useful beginning/end context.
- Sanitize control characters and escape `%` before placing dynamic text in a
  prompt-expanded string. Route all such values through the established prompt
  sanitation helpers.
- Measure visible characters, not color escape bytes. Keep color application
  outside width calculations.
- Preserve the semantic, collision-resistant palette. A color should identify
  one role in its local context; warnings and errors retain conventional warm
  colors. Ensure useful contrast on the supported dark terminal theme.
- Unicode tree glyphs are welcome; patched-font/private-use glyphs are not.
- Color command output only when stdout is a terminal. Pipes, redirects,
  command substitutions, and machine-readable output must remain plain and
  byte-compatible with the original command.
- Wrappers such as `grep` and `man` must stay narrow in scope and delegate all
  unsupported behavior to the system command.

## Full-screen interaction standard

Every Compozsh full-screen tool shares one interaction system while retaining
its own task context. Follow **Context-preserving composition** for transitions.
Use the shared editor's renderer, input loop, guide and cleanup; callers supply
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
| Title bar | Stable tool identity (`Compozsh / Tool name`); optional right-aligned Enter action and focused view from captured state |
| Status | Separate, quieter snapshot/result status; keep scope visible while filtering |
| Context | One separate location/source row, abbreviated as needed and omitted only in very short windows |
| Search/filter input | Dedicated, visibly delimited input; label the operation (`Filter folders`, `Search descendants`, `Filter results`); ordinary printable characters remain searchable |
| Main body | Pickers prioritize results; document workspaces prioritize the selected document beside a stable navigator. Preserve exact values separately from labels |
| Details / reader | Secondary information or a primary document, respectively; explicit focus and independent scroll, no provider calls during repaint. In a document workspace, distinguish selected content from keyboard focus |
| Footer | Shared capability-derived hints; acceptance, Escape and keyboard-guide access get first priority |

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
| Ctrl-X | Open **review** on Branches or **options** in filesystem views; inactive in document readers |
| Right / Left in a document workspace | Disclose files → focused diff → full-file context / reverse the sequence |
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
discovered. The keyboard guide must never trigger refresh.

- Preserve spatial landmarks when results shrink. Blank space is acceptable;
  do not fill the screen with unrelated widgets, repeated paths or decoration.
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
  Reuse semantic header/muted colors. Derive action labels from the shared
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
  filesystem context menus. Document readers instead expose their available
  arrow disclosure steps and `^R refresh`; omit Ctrl-X and keep it inert.
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
  `compozsh` prints help; Git review acceptance drills into files/diffs or
  focuses reading. Shared interaction must never turn insertion or a
  preview into execution. Digits apply visible slots only with an empty filter
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
- Ctrl-X on Branches selects **current working changes** or **selected branch
  commits**. Distinguish their scopes explicitly. Commits open a file-and-diff
  document workspace; working changes opens that workspace directly.
  Resolve a branch tip once to a full hex object ID and retain first-parent
  IDs for stable commit review. A root commit compares with the empty tree.
  Disable replacement refs so captured IDs refer to literal objects.
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
  file workspace; Ctrl-X has no reader action or menu.
  Tab/Shift-Tab and Ctrl-E/B change only pane focus and preserve context mode;
  Right from the navigator always enters focused diff. The shared loop returns
  explicit disclosure/refresh requests; only the controller captures their data.
  Start focused with three context lines around each hunk. Context mode remains
  until another disclosure changes it; changing it preserves each file's source
  anchor rather than reusing a visual offset from a differently sized document. The shared editor
  maps wrapped rows to logical document lines; Git owns old/new coordinates.
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
  and reloads only the selected diff eagerly, outside the input loop. Keep the
  filter and identify the selection by literal path AND change kind, then find
  its new filtered rank; numeric IDs are valid only within one observation.
  Retain pane focus, context mode and source anchor for a surviving selection.
  If it leaves the filtered results, visibly explain and focus the first match
  in the file list, in focused mode. Empty lists remain refreshable.
  Invalidate every raw/token/context cache and other-file reading bookmark on
  successful refresh; never let cached full context resurrect an older diff.
  On list/configuration failure, retain the previous observation with a retry
  status; propagate cancellation. Failed safety preparation must block uncached
  diff reads until retry, while allowing already captured documents. Keep newly
  validated filter overrides even if the following list read fails.
  Commit-file refresh retains immutable IDs.
  Advertise manual snapshots and Ctrl-R in shared chrome/help. No background
  watcher or polling; reopening branch history discovers new commits.
  Working-file lists and later diffs are
  separate observations, not an atomic transaction. Failed reads must be
  distinguished from successful empty snapshots. Preserve abort propagation.
- Git invocations disable optional index writes, fsmonitor, hooks, lazy fetch
  and network protocols, external diffs and textconv. Discover configured
  clean/process filter names and override them to inert values per invocation;
  disable required-filter enforcement too. Never change repository/global
  configuration. Refuse a capped/failed filter-name discovery. Explain the
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
  The editor coordinates views at runtime and owns final screen cleanup.
- Document filesystem keys/scopes in README and `compozsh --help`; Ctrl-K
  provides the in-view guide. Native scripting tools replace the removed
  `f --list`/`--print0` API; do not leave dead printing/argument-parsing paths.

## Xcode workspace boundary

- `.zsh.xcode` owns both the native Xcode action workspace and Apple skill export.
  Source-time behavior remains definitions only: never probe Xcode, enumerate
  projects, start Simulator, export skills, or write files while loading the
  peer. Keep `xcode` and `update_xcode_skills` as separate public operations
  with independent help providers and tests.
- Bare `xcode` discovers only literal `.xcworkspace` and `.xcodeproj`
  directories while walking upward from PWD. Stop at the nearest scope, offer
  workspaces before projects there, reject symlink containers, and never scan
  descendants. With arguments, delegate directly to `xcodebuild` and preserve
  its status. A dumb/noninteractive bare call may print the nearest container's
  safe native list; it must not open the modal workspace.
- Xcode owns scheme, destination, build, test and settings semantics. Request
  machine-readable JSON where the CLI provides it and parse it with the system
  `plutil`; accept the documented destination listing only after validating a
  fixed platform vocabulary and literal stable identifier. Bound every retained
  provider capture (currently 256 KiB), diagnostic and item count. No repaint,
  filtering, focus, scrolling or resize may invoke an Xcode provider.
- Use the shared full-screen renderer, screen owner, input loop, guide, focus
  language and temporary-screen cleanup. The dashboard is one shallow
  controller over Container → Scheme → Destination → Action, with configuration
  choices returning to the action dashboard. Do not add a renderer, key parser,
  background watcher, workflow framework, persistent project state or new
  shortcut. Dispatch every action only after the screen is restored.
- Discovery is read-only coordination, though Xcode may inspect project and
  package metadata. Always disable automatic package resolution and package
  updates and require versions from `Package.resolved`. Never silently enable
  provisioning updates or skip package-plugin/macro validation. Keep these
  policy arguments centralized and cover their exact presence/absence in tests.
- Build, Test, Analyze, Clean and Simulator Run are explicit code-execution
  boundaries. Project build scripts, package plugins, macros, tests and app code
  may execute. State this in the dashboard, README and `xcode --help`; never run
  an action merely to populate details. Native Xcode output belongs in the
  restored terminal, not a captured pseudo-console.
- Simulator Run initially supports only an exact simulator destination. Build
  first, derive one installable `.app` and validated bundle identifier from
  bounded `xcodebuild -showBuildSettings -json`, then use `xcrun simctl` to boot,
  install and launch it; opening Apple's Simulator app is part of that explicit
  action. Do not claim physical-device launch, alter signing, choose a generic
  destination or infer a product from recursive filesystem search.
- Test discovery order, spaces in literal paths, bounded/failed JSON, hostile
  destination text, no-scheme/no-destination states, argument delegation,
  noninteractive fallback, cancellation, resize cleanup, exact action arrays
  and simulator dispatch with PATH-shadowed first-party command spies. Real
  Xcode/Simulator checks are optional host integration tests and must not read
  private project data or mutate a user's active project.

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
- The shared editor owns a paired native alternate-screen session for every
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
- In the owned screen, keep title/search at the top and shortcuts anchored near
  the bottom, independent of result count or detail focus. Hide the original
  prompt and multiline draft during the modal session and restore their exact
  editing state on exit. Keep a spare terminal row to avoid scrolling the frame.
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
  The caller supplies the panel title and acceptance label; the shared editor
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
  workspaces follow the separate Git review contract above. The shared editor owns
  one list-first width policy with a bounded reading column; do not restore
  per-tool proportions or give previews the remaining unbounded screen width.
  Keep passive previews compact beside short lists and visually quiet, while
  preserving warning emphasis. Explicit focus may use the available body height
  in the owned screen, without increasing the caller's capture limits.
  Respect both terminal dimensions, preserve visible list capacity, and retain
  the narrow-window focus switch. Test all inspector callers and real resize
  signals; changing layout must not rerun providers or lose the selected value.
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
  state. Use Zsh 5.9 memo tags to remove only highlights owned here.
- Re-sourcing must not stack hooks or duplicate widgets. A fresh `exec zsh`
  remains the recommended way to apply changes.

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
  user's computer. No Compozsh-owned operation may transmit user or project
  data under any circumstance. There is no telemetry opt-in, consent exception,
  feature flag, debugging exception, or future product mode that may weaken
  this invariant. A proposed feature that requires project-owned transmission
  is incompatible with Compozsh and must be rejected.
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
standalone sourcing and order convergence directly. Complement automation with
a real PTY/ZLE check for key sequences, resize behavior, colors, cursor motion,
and terminal cleanup that a child-shell test cannot establish.
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
  all orders must converge on the same state without load diagnostics.
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
