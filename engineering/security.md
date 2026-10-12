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

- Startup sourcing is restricted to the fixed or explicit local initializer,
  shared peers adjacent to the resolved bootstrap, and private peers in the
  fixed user add-on directory. Add-on names and paths never come from the
  current directory or project metadata.
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
