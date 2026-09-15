# Repository layout

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Repository boundaries](#repository-boundaries)

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
- `.zsh.addons/support/functions/` contains classified shared function entries;
  `.zsh.addons/support/ui/` contains shared UI entries and their state peer.
  The support root retains palette setup and adapter assets. Follow the
  [shared support organization](architecture.md#shared-support-organization) contract for
  filenames, purity, entry points and private-helper ownership.
  Keep these implementations installed and intact during normal customization;
  public settings belong in the machine-local initializer.
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
  and architecture decisions. Keep durable product rules in the focused engineering contracts
  and link to the relevant investigation. Treat measured timings as observations
  from their recorded environment, never universal compatibility thresholds.
- `AGENTS.md` defines essential contributor rules and routes to `engineering/`
  contracts. Update the relevant canonical contract when an intentional
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
