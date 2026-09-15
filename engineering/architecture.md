# Architecture

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Architecture and abstraction](#architecture-and-abstraction)
- [Peer configuration algebra](#peer-configuration-algebra)

## Architecture and abstraction

Apply DRY and SOLID as practical design heuristics:

- Give each task-specific behavior a focused owning peer and compose reusable
  operations through shared support entries. A feature may use several entries;
  it does not need to fit in one growing file.
  Keep only initializer and peer discovery in `.zshrc`;
  keep only genuine pre-peer machine prerequisites in
  `~/.zsh.addons/local/init.zsh`, and put other private behavior in focused
  `.zsh.<name>` peers.
- Choose boundaries by cohesive behavior and entry-point ownership. Keep an
  entry's exclusive helpers with it; extract independently reusable operations
  instead of collecting unrelated entry points in a broad utility file.
  A unit owns its defaults, registrations, cleanup and fallbacks.
  Avoid both unguarded cross-unit calls
  and duplicated frameworks; when optional interaction is valuable, detect the
  peer capability at runtime and preserve useful standalone behavior.
- `support/.zsh.appearance` alone authors and installs terminal color defaults.
  Consumers resolve public overrides and selected defaults at invocation; they neither
  copy palettes nor write fallback keys. Public maps stay writable, and missing
  appearance uses native text and attributes. Completion owns its deferred
  style callback; appearance does not install another peer's registrations.
### Shared support organization

Paths below are relative to `.zsh.addons/`. Strip only the entry function's
leading underscore when forming its filename; retain the function name itself.

| Responsibility | Filename | Existing example |
| --- | --- | --- |
| Calculation from supplied data | `support/functions/.zsh.pure.<entry>` | `.zsh.pure.matching_select` defines `_matching_select` |
| External reads, shared-state access or effects | `support/functions/.zsh.impure.<entry>` | `.zsh.impure.compozsh_effect_copy` defines `_compozsh_effect_copy` |
| UI element or interaction | `support/ui/.zsh.ui.<entry>` | `.zsh.ui.zle_picker_footer` defines `_zle_picker_footer` |

- Every callable support file declares exactly one `# Entry point: name` before
  its first function. That function is the component-facing entry. Put its
  private helpers afterward; they may call each other within the owning file.
  No other production file may call or depend on those private helpers.
- When a second entry needs a private helper, promote it to a separately owned,
  classified shared entry and update its callers. Do not duplicate it, retain
  a forwarding alias at the old location, or add multiple shared entries to one
  file. Search existing entries before creating another implementation.
- Pure entries calculate from explicit inputs. Caller-local `REPLY`/`reply`
  implements native Zsh returns; explicitly supplied read-only arrays may be
  passed by validated name. Audit the complete call chain: pure calculations
  must not invoke impure operations or UI callbacks, discover providers, or
  read implicit mutable feature state. Text calculations use the supported
  Zsh and locale environment.
- Localize regex match parameters inside pure predicates so only the declared
  result escapes. Initialize an input local before deriving another local from
  it: Zsh expands every right-hand side in one `local` command before installing
  those bindings, which can otherwise read a caller's same-named variable.
- Validate raw numeric text before assigning an integer parameter, because the
  assignment itself evaluates arithmetic. Pure text operations define their
  splitting delimiters locally instead of depending on the caller's `IFS`.
- External reads, filesystem/process operations and implicit mutable-state
  dependencies are impure, including read-only operations. Reclassify and
  rename an entry when its contract changes; update callers, tests and the
  README inventory together. Purity labels aid review and do not enforce
  effects or prove safety for arbitrary input.
- Component-facing entries remain internal library interfaces, with no new
  terminal command, help topic or user extension point implied by extraction.
- Configuration peers are explicit exceptions: `support/.zsh.appearance` owns
  palette setup, and `support/ui/.zsh.ui.state` owns transient declarations.
  Do not invent callable wrappers for data initialization to satisfy naming,
  or use these exceptions to house unrelated callable utilities.
- Keep every peer independently sourceable and re-source safe. Directories and
  filename prefixes organize code without load phases, registries, aggregator
  loaders or runtime sourcing. Shared support remains installed as a unit;
  sourceability does not promise that an entry can run with its callees absent.
  Preserve capability checks and existing feature fallbacks at runtime.
- Keep one terminal owner in `support/ui/.zsh.ui.zle_picker_screen_session`.
  UI entries assemble captured data and return operation requests; final
  actions retain their established validation and post-cleanup boundaries.

### Shared behavior ownership

- The peers in `support/ui/` own shared terminal components, view defaults, layout, input,
  painting and screen restoration. Feature peers supply captured content,
  labels and capabilities; they own task-specific collection, ranking,
  transitions and final actions.
  Scope common defaults around view execution and save caller bookmarks before
  returning. Keep explicit provider hooks outside frame construction and resize.
  This composition introduces no privileged peer tier, registry or load phase.
- The pure `matching_*` entries under `support/functions/` own query compilation
  and filtering over supplied captured text. Keep outputs caller-local and
  calculations free of provider reads, UI state and actions. Feature collectors retain task-specific
  ranking, duplicate policy and capture bounds. Shared selection implements
  the caller-selected source-order or prefix/substring/fuzzy policy and returns
  indexes into explicitly supplied arrays, without implicit feature-state inputs.
  Display match spans remain a presentation concern. Missing matching support
  selects existing runtime fallbacks without an ordered load phase or a
  duplicate matcher.
- The `compozsh_effect_*` entries under `support/functions/` own explicit
  clipboard writes and file Open/Reveal execution. Callers pass exact values and captured executable paths after
  screen cleanup; the helper revalidates mutable operands and reports status.
  Source time defines functions only. Missing effect capabilities are omitted
  from workspaces and direct calls fail safely, without a duplicate execution
  path or runtime sourcing. Privileged/device/Git operations retain their
  owning peers and domain-specific validation and confirmation rules.
- Keep common presentation calculations data-in/results-out: shared functions own
  path-action metadata and row adapters, and domain peers own their result
  models. Pure helpers receive captured values and return caller-local outputs;
  UI adapters apply those results to view state. Do not move provider reads,
  commands or screen ownership into these calculations. Share repeated
  mechanisms, while preserving distinct scopes, selection intents, limits and
  return-navigation semantics instead of building a universal controller.
- Shared palette resolution owns role validation and fallback selection;
  consumers retain ANSI, prompt and ZLE encoding. Shared display sanitization
  changes labels only, never exact targets. Progress models receive captured
  bytes, totals and elapsed time; their callers own clocks, provider reads and
  painting. Reuse these entries before adding a feature-specific copy.
- Shared bounded capture returns payload, completion and command status;
  callers retain their partial-result, timeout and action policies. Git filter
  overrides have one validated builder with explicit clean/restore policy.
  Keep asynchronous worker lifecycle and privileged actions with their owners.
- The runtime functions in `support/functions/` own installed-version
  probes/cache, the version-source inventory, bounded read-only requirement
  capture and pure numeric comparison.
  Source time defines data/functions only; no project reads or executable probes.
  Prompt capture resolves this optional capability at invocation and retains
  project identity/tool markers without it. Do not duplicate probes or readers
  in prompt/UI peers. Reading external state is an observation boundary even
  when it does not intentionally mutate the project; comparison consumes only
  supplied values. Neither support placement nor read-only behavior alone proves
  peer-order independence. Preserve neutral-directory probes, trust checks,
  in-memory cache invalidation and normal/reverse/rotated/re-source tests.
  Numeric pins distinguish older (danger) from newer (warning), include both
  requested and observed versions, and preserve partial-version matching.
  Minimums and supported ranges use their source-specific semantics. Unsupported
  selectors, formats or compiler-family relationships remain unverified, never
  compatibility claims. Keep exact supported sources and limitations in README;
  new parsers need fail-closed literal-data, precedence and malformed-input tests.
  Bound parsing work independently of file bytes before expensive text patterns;
  never infer a requirement from a truncated first line. Tests must distinguish
  skipped ineligible files from captured but unverified requirements and cover
  permitted worst-case line shapes, not only small ordinary manifests.
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
  Shared full-screen components remain owned by `support/ui/`.
- Extend project support through marker data, focused detector branches, and
  the documented `PROMPT_PROJECT_*` extension points. The add-on loader is not
  a plugin manager: do not add dependency resolution, remote installation,
  manifests, lifecycle hooks, or code discovery inside projects.
- Extract a helper when it centralizes a repeated rule, security boundary, or
  non-trivial algorithm. Do not create a generic abstraction for two obvious
  lines that are merely similar today. This governs new abstractions; an
  existing shared entry still gets its own file even when its body is small.
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
