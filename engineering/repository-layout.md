# Repository layout

What lives where, how the bootstrap loads it, and what each file owns.
"Configuration base" means `${ZDOTDIR:-$HOME}`; `~/` paths describe the default
layout when `ZDOTDIR` is unset.

## Essentials

- **`.zshrc` is only the bootstrap**: interactive guard, optional initializer,
  recursive peer discovery, the compiled-mirror check (with its startup
  recompile of changed shipped peers) and diagnostics. Features go in peers.
  The owner accepted that fork-free mirror check, which grew `.zshrc`, as
  part of the minimal bootstrap (decision 2026-10-18): moving it into a
  sourced file would come close to an extra initialization phase.
- **One ordered boundary.** The optional `local/init.zsh` loads first; every
  `.zsh.<name>` peer after it loads in any order with the same result.
- **Enabled by filename.** A peer is on when its basename starts with
  `.zsh.` and off when renamed or removed; a `.zwc` file is compiled data,
  never a peer. There is no registry, allowlist, dependency graph, core module
  list or lifecycle manager.
- **Private state is off-limits.** The real `~/.zsh.addons/local/init.zsh`,
  private peers, history and machine state are outside the repository; never
  read, copy, overwrite or commit them during repository work.

## Repository tree

```text
compozsh/
├── .zshrc                 bootstrap: guard, initializer, peer discovery
├── .zsh.addons/           repository-managed peers and shared support
│   ├── .zsh.<name>        feature peers (inventory: README "Shipped configuration units")
│   └── support/
│       ├── .zsh.appearance  palette defaults and light/dark selection
│       ├── functions/     .zsh.pure.<entry> and .zsh.impure.<entry> shared entries
│       ├── ui/            .zsh.ui.<entry> shared UI entries and .zsh.ui.state
│       ├── compile.zsh    compiles shipped peers and the completion dump into the compiled mirror (not a peer)
│       └── git-syntax.vim adapter asset for .zsh.git-syntax (not a peer)
├── install.zsh            symlink/copy installer with preview, backups and rollback
├── templates/init.zsh     inert starter for the private initializer
├── tests/
│   ├── run.zsh, support.zsh, verify.zsh   runner, harness, handoff baseline
│   ├── *_support.zsh      focused helpers: PTY expectations, picker scripts,
│   │                      palette contrast, synchronous Git syntax capture
│   ├── *_test.zsh         behavioral specifications
│   ├── fixtures/          sourced by PTY tests
│   └── site*.mjs          optional Node and browser checks for docs/
├── docs/                  published static website (index.html, styles.css,
│                          *.mjs modules, images, README.md maintenance guide)
├── engineering/           contributor contracts (routed from CLAUDE.md)
├── investigations/        decision records, measurements, benchmarks/, archive/
├── .claude/               Claude Code: settings.json, hooks/, skills/, agents/, rules/
├── CLAUDE.md              always-loaded agent guide
├── README.md              public usage and shipped-unit inventory
├── SECURITY.md            public trust contract and self-audit
└── LICENSE                GNU GPL version 3
```

## File ownership

- `.zsh.addons/` holds all shared behavior as focused peers named
  `.zsh.<name>`, with no privileged core tier. Each unit is independently
  sourceable, re-source safe, narrow in purpose and successful after setup.
- `.zsh.addons/support/functions/` holds classified shared function entries and
  `support/ui/` shared UI entries plus their state peer; the support root keeps
  palette setup and adapter assets. Naming, purity and ownership follow the
  [shared support organization](architecture.md#shared-support-organization).
  Support `.zsh.<name>` files are ordinary peers under discovery — no
  ordering, special loader treatment or filesystem immutability. Keep them
  installed during customization; public settings belong in the initializer.
  Preserve standalone fallbacks when support capabilities are unavailable.
- `${ZDOTDIR:-$HOME}/.zsh.addons/support/cache/` is reserved inert data,
  excluded from sourcing even though filenames name their owning peers; it is
  not a peer tier. It follows [caching](caching.md). Both installation layouts
  use it; installs never copy generated source caches, normal updates preserve
  destination caches, and `--clean` archives them with the add-on tree.
- `${ZDOTDIR:-$HOME}/.zsh.addons/support/compiled/` is the marked, owner-only
  compiled mirror of the shipped peers (every regular `.zsh.<name>` file in
  the shared add-on directory, tracked or not; never private peers) and of
  Zsh's completion dump, never discovered as peers. Of Compozsh's code only
  `.zsh.addons/support/compile.zsh`, run in Apple's `/bin/zsh -f` from `/`
  (never a `zsh` found on `PATH`), writes it:
  every installation rebuilds it in both layouts, interactive startup
  recompiles just the shipped peers without a fresh record (creating a missing
  mirror) and drops the entry, wordcode and record of a removed or renamed
  one, and `.zsh.editor` compiles a new or changed dump after `compinit`,
  under a lock with atomic renames and a time box. The one other writer is
  stock `compdump`: when `compinit` was given the compiled copy but must rewrite
  its dump, it stages `zcompdump.<host>.<pid>` there and renames it over the
  `zcompdump` entry, and `.zsh.editor` has `compile.zsh` move it to the usual
  dump path (or delete it) at once; a rewritten dump left at the entry is
  never loaded as the compiled copy. An installation waits at most about 2 s
  in total for the clock to pass a peer's ctime; a peer still ahead of it
  gets no record and loads as text. `--clean` archives the mirror with the
  add-on tree, `compozsh --refresh` never writes it, Git ignores it (like
  `support/cache/`) in case a shell's `ZDOTDIR` is a clone, and deleting it
  is always safe. Its format and checks are in
  [Bootstrap and loading](#bootstrap-and-loading) and SECURITY.md.
- `README.md` is user-facing documentation synchronized with visible behavior,
  keys, installation, extension points and safety guarantees. Its **Shipped
  configuration units** table is the public peer inventory: any change that
  adds, deletes, renames, splits, merges or materially changes a shipped
  `.zsh.<name>` file updates that table in the same change (a test enforces
  the file set).
- `SECURITY.md` is the public trust and self-audit contract. Keep its claims,
  limitations, local-data inventory, privilege boundaries, reporting guidance
  and reproducible checks synchronized with code, installer, tests, website and
  repository skills. A change that makes a security or privacy statement stale
  is incomplete.
- `templates/init.zsh` is a valid, fully commented, inert starter. Installers
  copy it only when the private destination is absent; never symlink it,
  overwrite an existing initializer, or add active machine policy to it.
- `install.zsh` is the installation boundary: dry-run plan, symlink and
  namespaced-copy modes, `ZDOTDIR` support, confirmation, timestamped recovery
  backups, transactional rollback (also after Ctrl-C, hangup or termination,
  never restoring over an occupied path), and refusal to overwrite unmarked
  managed namespaces. `--clean` means archive and start fresh, never delete.
- `tests/` is the native-Zsh regression suite: files focused by behavior,
  `tests/support.zsh` as the minimal harness, no third-party dependencies.
- `investigations/` preserves bounded evidence behind decisions. Durable rules
  belong in the engineering contracts, which link to the evidence. Timings are
  observations from their recorded environment, not universal thresholds.
  `investigations/archive/` holds superseded records kept for history only.
- `CLAUDE.md` holds essential contributor rules and routes to `engineering/`.
  Every engineering contract must be linked from it (a test enforces this).
  Update a contract when an intentional architectural rule changes, not for
  ordinary implementation details.
- `.claude/agents/` holds read-only subagents: the `security-reviewer` and
  `contract-reviewer` used before handoff, and the `read-only-auditor` the
  skills run in (no editing tools). `.claude/rules/` holds short
  path-scoped pointers that load the right contract reference when matching
  files are opened. Keep rules as pointers — the contracts stay canonical —
  and update their `paths` when files move. `.claude/settings.json` (shared)
  pre-approves only the native test runner, `tests/verify.zsh` and
  `zsh -fn -- <file>` (any zsh grant must end options with `--`), denies
  Claude Code access to the operator's Zsh startup files, history, sessions
  and `~/.zsh.addons/`, and runs `.claude/hooks/zsh-syntax.zsh` after each
  edit; `zsh tests/run.zsh 'tooling:'` pins those grants. Personal overrides
  belong in the git-ignored `.claude/settings.local.json`.
- `.claude/skills/compozsh-platform-review/` is the read-only platform audit.
  Keep its trigger description narrow, its inventory script deterministic and
  free of personal data, and its recommendations separate from implementation
  authority. Update it when the native-platform contract, evidence lanes,
  compatibility gates or report workflow change. Don't commit generated
  snapshots automatically.
- `.claude/skills/compozsh-release-draft/` is the read-only release-evidence
  workflow. It resolves the actual latest published release and exact tag
  commit instead of trusting local tags, compares baseline and final
  implementation, help, tests and docs before drafting a claim, and treats
  conflicts as release blockers. It never infers coverage from an underlying
  tool or intermediate commit, and grants no tagging, commit, push, publish or
  clipboard authority.
- `LICENSE` is the canonical, unmodified GNU GPL v3 text; the project is
  `GPL-3.0-or-later`. Keep the README declaration and SPDX identifier
  synchronized, add no contradictory terms, and don't imply the GPL prohibits
  commercial use.

## Bootstrap and loading

The local initializer is optional and read only when it exists. It is the sole
ordering exception and loads before peer discovery. Its default path is
`~/.zsh.addons/local/init.zsh` (override: an absolute `ZSH_LOCAL_INIT`; a
relative path is refused with a diagnostic, never resolved against the start
directory), and its basename must not match `.zsh.<name>` so discovery cannot
load it twice. It may set `PATH`, Homebrew or language-manager environments,
selected runtimes, trusted vendor hooks that need early loading, and
documented public defaults. It must
not call peer functions during setup. Aliases, ordinary functions and
app-specific behavior that don't need first-load semantics belong in focused
private peers. Add no further phases
or ordered directories.

After the initializer, the bootstrap sources shared peers beside the resolved
`.zshrc` and private peers under `~/.zsh.addons`, canonicalizing and
deduplicating those directories so a copied install scans its combined
directory once. Discovery collects every file before sourcing any, under fixed
Zsh options (`emulate -LR zsh`), so glob options set by the initializer or a
peer cannot change the set: the `.zsh.` prefix matches case-sensitively, hidden
folders are never searched and nested directory symlinks are never followed.
Peers are then sourced at top level. A shared peer listed in the
compiled mirror is sourced through its mirror entry (a symlink to the peer,
beside the peer's `.zwc`) only while the mirror passes the checks `.zshrc`
documents and SECURITY.md discloses: ownership, Zsh version, the exact peer
path, unchanged device, inode, size, mtime and ctime, and the compiling
shell's parse context (options and aliases) when peers start loading and
across every text-loaded peer. Otherwise the peer's text loads, so compiled
loading reaches the same state. Before any peer loads, shipped peers with no
record matching their current metadata are compiled by
`support/compile.zsh` in Apple's `/bin/zsh -f`, run from `/` and never found
on `PATH` (only parsing them, never running them; no child starts when
`/bin/zsh` is missing or its `zsh` note in the mirror records another Zsh
version than the running one, so that shell loads text) when the mirror is absent or the user's own and the parse
context matches the manifest's (a record whose peer no longer exists starts
that compile too, which deletes every entry the new manifest does not name);
the manifest is then read again, so a changed peer runs compiled in the first
shell that can compile it. Compiled peers report the mirror path in
`functions_source`, which keeps the `/.zsh.addons/` label suffix. Lexical
traversal only makes diagnostics reproducible:

- loading the same enabled units in any order produces the same behavior;
- a peer never calls another peer at source time, relies on sorting before
  another, or needs a registration list;
- cross-feature behavior is deferred to runtime behind capability checks, so a
  missing peer degrades cleanly;
- renaming an enabled `.zsh.<name>` file never changes semantics.

Public values documented as initializer-customizable preserve an early value:
scalars and convenience aliases default only when absent; associative palettes
fill missing roles without replacing existing keys; public extension arrays are
declared without clearing them. Shared functions and prompt definitions remain
peer-owned — avoid collisions or disable the owning peer rather than relying on
overwrite order.

## Installation layouts

Keep documentation correct for both layouts. A symlinked `~/.zshrc` resolves
peers beside the repository file, plus private peers in `~/.zsh.addons`. A
copied `.zshrc` uses a copied `~/.zsh.addons` with the managed copy in its
marked `compozsh/` namespace. Both layouts get the compiled mirror; in the
symlink layout the first shell after a repository update recompiles the
changed peers, which README's update instructions say. Whenever
repository structure changes, audit installation, updating and uninstall
instructions together, and update the repository tree above in the same
change.

## Retired decisions

- `.zshrc.core`, `.zsh.core/`, numeric filename prefixes, dependency metadata
  and extra initialization phases — each would recreate a core/add-on
  distinction.
- `.agents/skills/` with Codex `agents/openai.yaml` metadata and the root
  `AGENTS.md`, replaced by `.claude/` and `CLAUDE.md` (2026-10); the project
  targets Claude Code only.
