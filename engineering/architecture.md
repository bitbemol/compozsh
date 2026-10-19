# Architecture

How peers, shared support and runtime capabilities fit together.

## Essentials

- **Focused peers, no core tier.** Each task-specific behavior has one owning
  peer; reusable operations live in shared support entries. A feature may use
  many entries — it need not fit in one growing file.
- **Order-independent setup.** Peers load in any order, regroup freely and
  re-source safely (the [peer configuration algebra](#peer-configuration-algebra)).
  Optional capabilities are detected at invocation, with useful standalone
  fallbacks.
- **Pure calculation, effects at the edges.** Collect facts, sanitize,
  calculate layout, render, act — each helper does one job. Facts enter at
  explicit capture boundaries (entry, `precmd`, an explicit submission,
  refresh or preview, or another read a contract approves, such as an approved
  worker or the highlighter's bounded path checks); the shared UI owns painting
  and input; other effects leave through named final actions after screen
  cleanup. Filtering, layout and frame construction, resize and repaint
  included, calculate over captured values only. This keeps hot paths fast,
  effects few and auditable, and calculations testable without a terminal.
- **Pure entries stay pure.** A pure entry computes only from explicit inputs
  (arguments, or read-only arrays named by a validated argument) and returns
  through caller-local `REPLY`/`reply`; its whole call chain reaches no impure
  entry, UI callback, provider, file (here-strings create one), process,
  ambient parameter such as `$COLUMNS` or `$PWD`, or shared mutable state.
  Move a needed read or effect to an impure entry or the caller; making a pure
  entry impure is a design change to raise with the user.
- **State lives no longer than disclosed.** View state and workspace
  snapshots are released with their view or invocation unless SECURITY.md's
  data inventory discloses a longer lifetime, such as the `precmd` snapshot
  until the next capture; memoized results last until `compozsh --refresh` or
  invalidation. Catalogs are derived from live sources at their capture
  boundary, and nothing becomes a registry or persistent feature state beyond
  what [caching](caching.md) allows.
- **Plain mechanisms.** No plugin manager, registry, dependency resolution,
  lifecycle hooks, state-machine framework or event bus. Extract a helper when
  it centralizes a repeated rule, security boundary or non-trivial algorithm,
  not for two lines that merely look alike today.

## Boundaries and coupling

- Choose boundaries by cohesive behavior and entry-point ownership. Keep an
  entry's exclusive helpers with it; extract independently reusable operations
  rather than collecting unrelated entries in a utility file. A unit owns its
  defaults, registrations, cleanup and fallbacks.
- Avoid both unguarded cross-unit calls and duplicated frameworks. When
  optional interaction is valuable, detect the peer capability at runtime.
- Keep coupling explicit: pass a project root or Git directory into helpers
  instead of having each rediscover ambient state.
- Prefer data tables for stable mappings (palettes, runtime labels, markers)
  and functions where behavior, validation or failure handling is involved.
- Extend project support through marker data, focused detector branches and
  the documented `PROMPT_PROJECT_*` extension points. The loader is not a
  plugin manager: no dependency resolution, remote installation, manifests or
  lifecycle-hook framework (peers may register ordinary Zsh hooks), and no code
  discovery inside projects.
- Remove temporary setup helpers after use unless they are public interface.

### Shared support organization

Paths are relative to `.zsh.addons/`. A filename is the entry function's name
without its leading underscore.

| Responsibility | Filename | Example |
| --- | --- | --- |
| Calculation from supplied data | `support/functions/.zsh.pure.<entry>` | `.zsh.pure.matching_select` defines `_matching_select` |
| External reads, shared-state access or effects | `support/functions/.zsh.impure.<entry>` | `.zsh.impure.compozsh_effect_copy` defines `_compozsh_effect_copy` |
| UI element or interaction | `support/ui/.zsh.ui.<entry>` | `.zsh.ui.zle_picker_footer` defines `_zle_picker_footer` |

- Each callable support file declares exactly one `# Entry point: name` before
  its first function; that function is the component-facing entry, and its
  private helpers follow it. No other production file calls those helpers.
- When a second entry needs a private helper, promote it to its own classified
  entry and update callers — no duplicate, no forwarding alias at the old
  location, no second entry in one file. Search existing entries before
  writing another implementation; even a small shared entry gets its own file.
- **Pure** entries calculate from explicit inputs, returning through
  caller-local `REPLY`/`reply`; read-only arrays may be passed by validated
  name. Audit the whole call chain: no impure calls, UI callbacks, provider
  discovery or implicit mutable feature state. Localize regex match parameters
  so only the declared result escapes. Initialize an input local before
  deriving another from it — Zsh expands every right-hand side of one `local`
  command before binding, which can read a caller's same-named variable.
  Validate numeric text before integer assignment (assignment evaluates
  arithmetic), and define splitting delimiters locally instead of trusting the
  caller's `IFS`. Every function in a pure file, private helpers included, is
  pure; checking a pure callee's presence with `${+functions[name]}` is
  allowed. Split captured text in memory with `${(f)…}` or `${(0)…}`:
  here-strings and here-documents are backed by temporary files.
- `zsh tests/run.zsh 'support pure'` flags calls outside pure code, commands
  other than allowlisted builtins, substitutions, subshells, pipelines,
  background jobs, redirections, here-strings, file tests, `(e)`, `(D)` and
  `(%%)` expansion, `emulate` without `-L`, globals, non-local parameters (in
  `(( ))` and same-declaration reads included), and assignments, shifts or
  match parameters that escape. It can't see filename generation, `(%)` or `~`
  expansion, names built at run time (`${(P)…}`), bare names evaluated as
  arithmetic outside `(( ))` (subscripts, integer assignments, `[[ -lt ]]`,
  `return`), or reads hidden by unusual quoting, so still audit the chain. A
  genuinely pure construct it flags is a scan false positive to fix with a
  clean-fixture case; widening its builtin allowlist is the user's decision.
- **Impure** covers external reads, filesystem/process operations and implicit
  mutable state — including read-only operations. Rename an entry when its
  contract changes, updating callers, tests and the README inventory together:
  an impure entry that no longer reads or acts may become pure, while making a
  pure entry impure needs the user's agreement. Labels aid review; they don't
  prove safety.
- Entries are internal library interfaces: extraction implies no new command,
  help topic or extension point.
- Two configuration peers are explicit exceptions: `support/.zsh.appearance`
  (palette setup) and `support/ui/.zsh.ui.state` (transient declarations).
  Don't wrap data initialization in callable entries to satisfy naming, and
  don't put unrelated utilities in these exceptions.
- Directories and prefixes organize code; they create no load phase, registry,
  aggregator or runtime sourcing. Support stays installed as a unit —
  sourceability doesn't promise an entry runs with its callees absent — so
  runtime capability checks and feature fallbacks remain. Support placement or
  read-only behavior alone doesn't prove peer-order independence; the
  algebra's order and re-source checks do.

### Shared behavior ownership

| Area | Owner and rule |
| --- | --- |
| Terminal components | `support/ui/` owns components, view defaults, layout, input, painting and screen restoration, with one terminal owner in `.zsh.ui.zle_picker_screen_session`. Feature peers supply captured content, labels and capabilities, and own collection, ranking, transitions and final actions. Views reach the engine only through `_zle_ui_view KIND CONFIGURE`, which scopes the view defaults to that call; `_zle_picker_run` given a session controller only opens the screen its views share, and the `view state:` scan flags any other `_zle_picker_loop` or `_zle_picker_run` call outside its allowlist of helpers that run inside a view. Save caller bookmarks before returning, and keep provider hooks out of frame construction and resize. |
| Matching | Pure `matching_*` entries compile queries and filter supplied text, returning indexes into explicitly supplied arrays under the caller's source-order or prefix/substring/fuzzy policy. Collectors keep task ranking, duplicate policy and capture bounds; match spans are presentation. Missing matching support selects existing fallbacks, never a duplicate matcher. |
| Effects | `compozsh_effect_*` entries own clipboard writes and file Open/Reveal. Callers pass exact values and captured executable paths after cleanup; the entry revalidates mutable operands and reports status. Missing effects are omitted from workspaces and fail safely when called. Privileged, device and Git operations keep their own validation and confirmation. |
| Presentation calculations | Shared path-action metadata and row adapters; domain peers own result models. Pure helpers take captured values and return caller-local results; UI adapters apply them. Share mechanisms while keeping distinct scopes, intents, limits and return navigation — no universal controller. |
| Palette | `support/.zsh.appearance` alone authors and installs color defaults; consumers resolve public overrides and selected defaults at invocation and never copy palettes or write fallback keys. Public maps stay writable: removing an override restores the selected default at render time, re-sourcing appearance refills the key, re-sourcing a consumer writes nothing, and a missing or non-associative map means "use defaults" without recreating it. The resolver honors explicit overrides even when appearance is absent; without the resolver, presentation uses native text attributes. Appearance installs no other peer's registrations; completion owns its deferred style callback, reads the current `LS_COLORS` at invocation, and re-sourcing appearance never replaces a custom completion `zstyle`. Shared resolution validates roles and selects fallbacks; consumers keep ANSI, prompt and ZLE encoding. Both schemes keep primary reading neutral, navigation and focus cool, secondary text gray and warnings/errors warm; diff `+`/`−` prefixes and selection markers keep meaning without color. |
| Display and progress | Sanitization changes labels only, never exact targets. Progress models take captured bytes, totals and elapsed time; callers own clocks, provider reads and painting. |
| Bounded capture and Git filters | Shared bounded capture returns payload, completion and command status; callers keep partial-result, timeout and action policies. Git filter overrides have one validated builder with explicit clean/restore policy. The prompt, filter discovery, discard, branch reads and the Search, review and worktree wrappers call one local-only entry, `compozsh_git_local`, which owns the environment, read-safety flags, a root/inherit selector policy and the verified direct run of Apple's Git behind `/usr/bin/git` ([git](workspaces/git.md#git-invocation-safety), [SECURITY.md](../SECURITY.md#local-only-git-controls)); callers append only their own controls and fail closed without it. Async worker lifecycles and privileged actions stay with their owners. |
| Runtime versions | `support/functions/` runtime entries own installed-version probes and memory cache, the version-source inventory, bounded requirement capture and pure comparison. Source time defines functions only. The prompt resolves this capability at invocation; semantics are in [prompt](prompt.md#project-and-runtime-context). |
| Living prompt | `.zsh.prompt` owns fact capture, its trigger fingerprint, the compact/lens/transcript modes, lens derivation and rendering, and outcome receipts. `.zsh.editor` owns the optional ZLE adapters, hooks and the `compozsh-context-lens` binding that invoke them. Both preserve existing widget state without depending on load order. |

## Peer configuration algebra

A letter denotes a peer or group of peers, `⊕` combines their configuration
and `≈` means equivalent configured behavior. The notation adds no shell
operator, registry, dependency graph or loading phase.

| Law | Contract | Consequence |
| --- | --- | --- |
| Commutativity | `A ⊕ B ≈ B ⊕ A` | Reordering enabled peers preserves behavior. Resolve optional peer capabilities when invoked, not by capturing their source-time presence or values. |
| Associativity | `(A ⊕ B) ⊕ C ≈ A ⊕ (B ⊕ C)` | Grouping preserves behavior. Concern directories confer no priority or group-level setup. |
| Idempotence | `A ⊕ A ≈ A` | Re-sourcing unchanged peers accumulates no hooks, registrations or defaults and replaces no documented user override. |

Compare after the same enabled peer definitions finish loading, with the same
initializer inputs, shell, environment and native capabilities. Peer-owned
definitions need distinct ownership; competing definitions or private
overrides of internal functions violate the contract. Grouping preserves
discovered peers and required relative asset paths. The initializer is the
sole first-load exception and sits outside the laws (re-sourcing `.zshrc` can
run it again).

`≈` covers supported commands and their behavior, options, aliases, key
bindings, hook behavior and multiplicity, prompts, effective styles and
documented fallbacks. A difference in any of those is a defect even when a
sorted catalog looks equal; incidental source locations or scratch layout may
differ. Loading shipped peers from the compiled mirror is the same
peer set: it must reach the same state as their text, and only their source
locations differ. Loading a different peer set or changing prerequisites is a different
comparison.

The laws describe setup and safe re-sourcing between interactions. Runtime
workflows still compose in meaningful sequences — capture → filter → display →
validated action — and need not commute. Palette installation changes shell
memory; shared UI owns temporary interaction state and cleanup. Recommend
`exec zsh` to apply updates. The equations are engineering contracts backed by
regression evidence, not a formal proof for every permutation or arbitrary
shell function; don't add abstractions just to resemble the notation.

For changes to peer boundaries, defaults, registrations or shared capabilities:

- Exercise normal, reverse and rotated orders in isolated shells, with the
  owner of a shared capability both before and after its consumers; compare
  configured observations and representative runtime results.
- Re-source the affected peer and the complete set, including a repeated peer
  separated by others. Verify stable hooks and bindings and preserved
  overrides; don't hide duplicate hooks by sorting them into a set.
- When placement or discovery changes, cover grouping and renaming inside the
  discovery roots and both installation layouts, preserving assets.
- Check standalone/missing-peer behavior and later-invocation capability
  detection. When colors are affected, include both schemes and documented
  early overrides.

## Retired decisions

- Forwarding aliases or wrapper functions left at an old helper location after
  promotion.
- The grouped support peers `support/.zsh.ui`, `support/.zsh.matching` and
  `support/.zsh.runtimes`, replaced by one file per entry.
