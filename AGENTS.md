# Repository instructions

These instructions apply to the entire repository. They describe the design
contract for humans and coding agents working on this configuration. Follow the
user's current request first; within that scope, preserve the principles below.

## Product contract

This project is a polished, self-contained interactive Zsh configuration. Its
core promises are:

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

## Modern-first compatibility policy

The declared minimum Zsh version is a product boundary, not a suggestion:

- Treat the Zsh version included with the latest generally available macOS as
  the compatibility ceiling. Never require Homebrew, MacPorts, or a
  user-compiled replacement shell merely to run Compozsh.
- Review the declared minimum and newly available native features with each
  major macOS release. Do not adopt upstream-only Zsh behavior until Apple
  ships it in a generally available macOS release.
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
- `AGENTS.md` defines engineering conventions. Update it when an intentional
  architectural rule changes, not for ordinary implementation details.
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

1. Correctness and preservation of shell semantics
2. Safety and predictable failure behavior
3. Interactive latency
4. Clarity and maintainability
5. UI consistency and useful information density
6. Additional feature breadth

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

## Keyboard and ZLE behavior

- Use the Emacs keymap as the macOS terminal baseline. Favor familiar Control
  navigation/editing and Option-as-Meta word operations.
- Command-key shortcuts belong to macOS and the terminal application; do not
  pretend Zsh can bind them portably.
- Apple keyboards without physical Home, End, or forward-Delete keys must have
  first-class Control/Option alternatives. Physical/Fn sequences are aliases,
  not requirements.
- Use terminfo capabilities plus common normal/application cursor sequences so
  behavior survives Terminal, iTerm2, SSH, and multiplexers.
- Do not steal a standard editing key for unrelated behavior. A wrapped key may
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
- Keep picker input on a stable dedicated row, visually distinct from titles,
  counts, and other metadata. Long queries must remain complete internally and
  abbreviate safely for display, with non-color delimiters for accessibility.
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
  tool's information hierarchy: optional secondary labels and pane proportions
  are presentation data; exact action values remain untouched. Keep shared
  scope and actions in the header/footer and avoid repeated selection headings.
  Preserve each tool's actual Enter/copy actions. Do not steal hierarchy-navigation
  keys when adding inspectors to directory completion. File panels show captured path
  facts only; content previews require a separate safety and performance design.
  Preserve search and selection across pane focus and responsive layouts, and
  keep numbered selection restricted to visibly rendered list rows.
- File search selection is type-aware: ordinary directories navigate; files
  and symbolic links require an explicit action picker. Keep action dispatch
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
6. Update `README.md`, its shipped-unit inventory and repository layout,
   `templates/init.zsh`, and relevant `.zsh.addons/`
   documentation when public behavior, a unit boundary, or an extension point
   changes.
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
