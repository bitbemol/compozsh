# Security

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Safety and security](#safety-and-security)

## Safety and security

- Starting a shell or drawing a prompt must never access the network.
- Privacy is a top-level product goal and an implementation constraint, not a
  documentation slogan. Minimize every read and capture to the facts, scope,
  and lifetime required by the user's visible task. Prefer transient in-memory
  state. Do not introduce telemetry, behavioral profiling, identifiers, a
  user/project-data performance cache, or speculative collection “for later.” A
  useful feature is not justification for collecting unrelated information.
  Reproducible public system data may use an optional persistent cache under
  the [caching contract](caching.md), with explicit provenance and no private
  inputs or fingerprints of them.
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
