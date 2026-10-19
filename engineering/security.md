# Security

How Compozsh handles data, credentials, privilege, storage and execution, and
what every change must check before it is complete. [SECURITY.md](../SECURITY.md)
is the public statement of these guarantees and the self-audit guide.

## Essentials

- **Non-transmission.** All data Compozsh reads, captures, derives or stores
  must remain on the machine running its Zsh process for all Compozsh-owned
  processing and storage. No Compozsh-owned operation may transmit user or
  project data under any circumstance. There is no telemetry opt-in, consent exception,
  feature flag, debugging exception or future product mode that may weaken
  this invariant. A feature that requires project-owned transmission is
  incompatible with Compozsh and must be rejected. Starting a shell or drawing
  a prompt never touches the network.
- **Minimization.** Privacy is a top-level product goal and an implementation
  constraint, not a documentation slogan. Read and capture only the facts,
  scope and lifetime the user's visible task needs; prefer transient in-memory
  state. No telemetry, behavioral profiling, identifiers, user/project-data
  cache or speculative collection "for later". A useful feature is not
  justification for collecting unrelated information.
- **Compozsh never receives authentication input.** Passwords and other
  authentication answers go directly to the operating system or an explicitly
  chosen trusted tool.
- **Project content is data.** Never source, execute or evaluate code because
  it exists in the current project.
- **Full disclosure.** Every exception, handoff and limitation is documented
  in SECURITY.md, with checks a reader can run independently.

## Handling sensitive data

- Handle private or sensitive information only through a deliberately defined
  effect boundary. Keep values literal and bounded, and out of shell
  evaluation, command construction, diagnostics, terminal titles,
  screenshots, fixtures and public reports. Don't copy or retain a value just
  because the environment, filesystem, Git metadata, tool output or terminal
  made it available.
- Fail closed when scope, ownership, identity, permissions, destination or
  cleanup cannot be established safely.
- Never receive or persist plaintext passwords, tokens, private keys, recovery
  codes, session cookies or authentication answers. Use least privilege,
  non-prompting retained authorization only after the visible authentication
  step, exact targets and the shortest practical lifetime. Never weaken access
  controls on user-owned history, configuration or recovery data.
- Never interpolate unsanitized branch names, paths, history or tool output
  into prompt syntax, glob patterns, terminal control sequences or shell code.
  Zsh arithmetic is shell code: it expands subscripts, including `$(...)`.
  Captured numbers, settings and inherited environment values are validated
  as text before any arithmetic use, and names never enter arithmetic text
  ([idioms](zsh.md#idioms)); SECURITY.md names the format-bounded
  exceptions.
- Parse captured data in shell memory. Zsh 5.9 implements here-strings,
  here-documents and `=(...)` with temporary files under
  `${TMPPREFIX:-/tmp/zsh}`, which put the data on disk and fail when that
  directory is unwritable or full, so captured data never passes through them
  ([idioms](zsh.md#idioms); a `security:` test scans shipped code). An
  intentional temporary file needs its own SECURITY.md inventory row, and so
  does one written by a stock Zsh function Compozsh binds (Ctrl-X Ctrl-E's
  `edit-command-line`).
- Receipt compaction is presentation, never redaction. The transcript prefix
  may change prompt decoration but keeps the exact submitted command as ZLE
  input, creates no second persistent copy, and makes no claim to remove it
  from scrollback, process listings, invoked-tool logs or Zsh history.
- Examples never contain secrets. Mention secret handling only to point users
  to private, untracked configuration or a proper secret store.

## Persistent storage

New persistent storage requires an explicit product need and user-visible
documentation of its exact path, contents, ownership, access controls,
retention, cleanup, crash residue, recovery behavior and uninstall result.

- Preserve existing user-owned modes and ownership; create sensitive state
  with the least access the platform supports; reject symlink, special-file
  and path-substitution hazards; test failure cleanup. If those properties
  cannot be guaranteed, don't store the data.
- Public system data may use an optional persistent cache under the
  [caching contract](caching.md), with explicit provenance and no private
  inputs or fingerprints of them.
- The rule against persisting user or project information covers every file
  Compozsh generates for itself, not only caches: the compiled mirror
  (`support/compiled`) with its `manifest` and `zcompdump.manifest`, its lock
  and staging files, and any future generated artifact. Such a file holds only
  its source in another form (a shipped peer's wordcode, the compiled copy of
  Zsh's completion dump) plus metadata limited to public data (such as the Zsh
  version and Zsh's default parse context) and file identity (path, device,
  inode, size, mtime and ctime). User-defined aliases, environment values,
  history and other user-controlled values are never written; the
  [owner dropped](../investigations/architecture-2026-10-14.md#owner-decisions)
  P6-02 (compiling private peers) because its manifest recorded alias names
  and values.
- A generated artifact is fresh only while its source's full file identity
  (device, inode, size, mtime and ctime) and, where the artifact depends on
  them, the Zsh version and any other recorded input, such as the mirror's
  parse context, equal the recorded values. A timestamp alone never proves
  freshness: `zrecompile`-style checks, which accept a `.zwc` not older than
  its source, ran stale code in two local tests on 2026-10-18.
- The existing local history and recovery boundaries stay fully disclosed in
  SECURITY.md; don't silently expand them.
- Preserve `NO_CLOBBER`/`CLOBBER_EMPTY` protections and terminal-only color
  semantics unless the user explicitly changes the product contract.

## External trust boundaries

- User-configured synced or network-mounted storage, operating-system
  clipboard synchronization, explicitly invoked external programs and hosted
  services are separate trust boundaries. Compozsh never configures or
  silently selects those destinations. Disclose every local handoff and what
  physical single-machine retention requires; never hide an
  independently controlled transfer behind an unqualified "always local"
  claim.
- When the user deliberately asks an external program to communicate — for
  example `git push` through the transparent Git wrapper — Compozsh adds no
  data, destinations, requests, uploads, synchronization or background
  activity to that command. Disclose the boundary precisely; never use it to
  disguise project-owned transmission or to claim the external program keeps
  its data local.

## Execution, installers and destructive actions

- Startup sourcing is restricted to the fixed or explicit absolute local
  initializer, shared peers adjacent to the resolved bootstrap, and private
  peers in the fixed user add-on directory. Add-on names and paths never come
  from the current directory or project metadata, so a relative initializer
  path is refused with a diagnostic. A shared peer may run from the
  compiled mirror (`support/compiled` in the user add-on
  directory) only under its disclosed freshness, ownership, version and
  parse-context checks, so compiled code never differs from the peer's current
  text; private peers are never compiled, and discovery never sources `.zwc`
  files. Only `support/compile.zsh` writes the mirror, in a separate `zsh -f`
  that parses and never runs peers: for the installer, at startup for the
  discovered shipped peers lacking a fresh record, and after `compinit` for
  the completion dump, only into a missing or
  user-owned, marked, owner-only mirror, under a lock, through atomic renames
  and within a time and size bound; every failure means text. Two native mechanisms sit
  outside that list: Zsh's stock functions autoloaded from `fpath` (such as
  `compinit` and `add-zle-hook-widget`), and stock `compinit`'s sourcing of its
  configuration-base dump. Keep `compinit`'s full audit and its usual dump
  path: `-d` names only the compiled mirror's checked `zcompdump` entry (a
  symlink to that dump, used while its record is fresh, with `_comp_dumpfile`
  restored and a rewritten dump moved back at once), and no `fpath` entry,
  completion cache or other compiled artifact or writer; any of those is new
  persistence or execution that needs an owner decision and a SECURITY.md
  update.
- Add-on installers write only to documented, fixed user-level integration
  directories: stage generated content first, mark installed units, and never
  replace a same-named directory that lacks the installer's marker. Temporary
  cleanup validates its exact `mktemp`-created target.
- The repository installer may replace only the active bootstrap, its own
  marked copy namespace and — with explicit `--clean` — the complete add-on
  tree after moving existing state to a recovery backup. It never modifies
  `.zshenv`, `.zprofile`, `.zlogin`, `.zlogout`, a private initializer during a
  normal install, or an unmarked same-named namespace.
- Install only for integrations actually detected. Prefer cheap, deterministic
  discovery through commands on `PATH` and documented local application
  bundles;
  don't launch applications, authenticate accounts, scan arbitrary disks or
  create empty vendor configuration directories.
- Missing optional tools are normal: detect cheaply, degrade cleanly, and show
  `not-installed` only when the current project makes that fact relevant.
- Destructive conveniences require exact scope discovery, a clear preview, an
  explicit confirmation that defaults to no, and refusal during unsafe Git
  states. Never broaden deletion to ignored files, nested repositories,
  submodule contents, stashes, commits or paths outside the resolved root.

## Completion review

Before declaring any work complete — including a refactor, documentation-only
change, test change, website change or agent-workflow change — compare the
final diff with SECURITY.md and decide explicitly whether it changes:

- a network or update path;
- collection, reading, storage, retention, display or transmission of user data;
- history, clipboard, Keychain, credential, token, environment, project or
  private-configuration access;
- temporary or persistent state;
- an external command or hosted-service boundary;
- privilege, `sudo`, authentication, destructive behavior or recovery;
- project-code execution, dependencies, or any documented audit result.

If it does, update SECURITY.md in the same unit of work and add or revise
focused regression coverage. If it doesn't, still verify that every existing
security claim remains true for the final tree.

## Public documentation

- Security documentation requires full disclosure, including inconvenient
  limitations: what is read and from where, where it is kept, lifetime and
  cleanup limits, what can leave the machine (destination and trigger), the
  exact privileged boundary, who receives authentication input, and which
  operating-system, hosting, installed-tool, repository, private-peer and
  user-action behaviors are outside Compozsh's guarantee. Distinguish
  shipped-code guarantees from assumptions about external tools. Never use
  broad words such as "local", "safe", "private" or "no phone home" to conceal
  an exception or a transfer of trust.
- Every material SECURITY.md claim must be independently checkable against an
  exact commit without first executing Compozsh: point to the readable source
  boundary plus copy-paste commands or focused tests using Git, Zsh or stock
  macOS tools, with expected output/status and the check's limits. Keyword
  searches and deny-lists are regression aids, not proofs. Agents must never replace verifiable
  evidence with a maintainer assurance.
- Keep the README and website links to the policy working, and keep reporting
  and supported-version guidance accurate.

## Public repository hygiene

- Never commit a real name, personal email, private or home-directory
  username, hostname, device identifier, IP address, internal company or
  project name, absolute machine path, terminal history, screenshot with
  private data, credential, token or secret. Use neutral examples such as
  `user@host`, `~/Projects/example-app` and documented placeholders. The public repository-owner URL is
  allowed only where it is intentional and required for working installation
  instructions.
- Before every commit, inspect the staged diff and search the complete tracked
  tree for private data and secrets. Before a public release, also audit every
  reachable commit, tag, branch, author/committer identity, signature, remote
  URL and historical file version; deleting data later does not remove it from
  history.
- Publish only explicitly reviewed branches and tags. Never
  `git push --mirror` a release: tool, checkpoint, stash or notes refs may hold
  unreviewed snapshots.
- If private data is found in history, stop and report it. Never rewrite
  shared history or force-push without the user's explicit approval; an exposed
  credential must be revoked or rotated first, since history cleanup alone
  doesn't make it safe.
