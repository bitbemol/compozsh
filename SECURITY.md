# Security and privacy

Compozsh is shell code: installing it gives the tracked bootstrap and enabled
peer add-ons access to the interactive shell environment. That trust should be
based on inspectable behavior, not on a promise from the maintainer. This
document defines the shipped security boundary, identifies every intentional
sensitive-data and administrator boundary, and provides repeatable checks for
the exact commit you intend to run.

The claims below apply to repository-managed files at the commit being audited.
They do not extend to private add-ons, the machine-local initializer, programs
already installed on the machine, repositories being inspected, the operating
system, GitHub, or software opened or built at the user's request.

## Non-transmission invariant

All data Compozsh reads, captures, derives, or stores stays on the user's
computer. Compozsh never transmits user or project data under any circumstance.
There is no telemetry opt-in, consent exception, debugging mode, feature flag,
or future product mode that weakens this rule. A feature that requires
Compozsh-owned transmission is outside the product contract and must not be
added.

This invariant governs Compozsh code; it does not pretend that the operating
system or a program explicitly invoked by the user is offline. If the user asks
Git to push, fetch, pull, or clone, Git communicates with the destination the
user selected. The transparent Compozsh Git wrapper does not add data, an
endpoint, or a separate request. Applications, build tools, and private add-ons
likewise retain their own independently auditable trust boundaries.

## Privacy model

Privacy, credential protection, data minimization, and user control are
top-level product goals. Compozsh's model is to acquire only the facts required
for the visible task, within its displayed scope, and retain them only for the
necessary lifetime. Temporary view state stays in memory when practical;
intentional persistent local state is enumerated below rather than hidden
behind a broad “everything is local” claim.

Sensitive values are handled as literal, bounded data and are not evaluated as
shell code. Compozsh does not collect information merely because it is
available in the environment, filesystem, Git metadata, command output, or
terminal session. It does not accept plaintext authentication secrets; an
operating-system or explicitly chosen external tool owns its authentication
input. Operations use the least privilege and narrowest exact target their
implementation permits.

New collection, persistence, or privilege is not an ordinary implementation
detail. It requires an explicit product decision, disclosure of the exact data,
purpose, path, trigger, lifetime, access and cleanup behavior, independent audit
evidence, and focused regression coverage. Transmission is prohibited rather
than configurable. If scope, ownership, permissions, or cleanup cannot be
established safely, the operation must fail without broadening access or
retaining another copy. External tools, user-owned configuration, and hosting
remain separate trust boundaries and are disclosed rather than presented as
guarantees made by Compozsh.

## What the shipped project does not do

- It has no telemetry, analytics, crash-reporting service, account, project
  server, background daemon, automatic update check, or runtime package
  download.
- The tracked shell and installer contain no network-client invocation or
  project endpoint. Updates happen only when the user runs Git themselves.
- It does not collect, read, log, store, or transmit a `sudo` password. The two
  external-media tools invoke Apple's `/usr/bin/sudo -v`; `sudo` owns the
  terminal prompt and its timestamp. Compozsh never receives the password.
- It does not use `sudo -S`, `SUDO_ASKPASS`, a password variable, the login
  keychain, or the macOS `security` credential command.
- It never reads the clipboard. Explicit Copy actions write only the visibly
  selected path or branch through `pbcopy`. The optional website writes a
  visible installation command only after its Copy button is clicked.
- The shell configuration, installer, and static site do not upload shell
  history, paths, Git data, project metadata, file previews, diffs, runtime
  versions, disk metadata, or installer output.
- It does not automatically download and execute shell code. Installation uses
  only files already present in the reviewed clone.

These are implementation constraints, not a claim that the wider computer is
offline. A command the user runs can use the network. Compozsh's `git` wrapper,
for example, passes the user's `git clone`, `fetch`, `pull`, and `push` requests
to Git. An application opened by an explicit file action, an Xcode build phase,
or an installed runtime queried for its version has its own security and
privacy behavior.

## Data that stays on the machine

No project-owned service receives any of the following data. Some data is
intentionally persistent because a shell and a recoverable installer need local
state:

| Data | Location and lifetime | Why it exists |
| --- | --- | --- |
| Command history | `${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}` by default | Zsh's normal local, shared history and the in-memory history picker |
| Private initialization and peers | `${ZDOTDIR:-$HOME}/.zsh.addons` | User-owned machine setup and extensions loaded by the bootstrap |
| Recovery copies | `${ZDOTDIR:-$HOME}/.zsh-backups/compozsh-*` | The installer preserves configuration it replaces instead of deleting it |
| Prompt and picker facts | Shell memory | Runtime versions, Git state, paths, and temporary view snapshots; discarded with the shell or view |
| Bounded operation captures | `${TMPDIR:-/tmp}` | USB progress, Xcode output, and Git syntax transport; validated temporary paths are removed during normal and handled-error cleanup |
| Exported Apple skills | Detected coding agents' local skill directories | Created only by an explicit `update_xcode_skills` invocation and marked for safe refresh |
| Clipboard values | The clipboard of the machine running Zsh | Written only by an explicit Copy action; never read back by Compozsh |

The installer never prints the contents of an old `.zshrc` or private add-on,
but a recovery backup can contain secrets that were already present there.
Protect and eventually archive or remove those backups according to your own
retention policy. Compozsh deliberately does not delete them automatically.
An uncatchable process termination or system failure can also leave a temporary
capture behind; its validated `compozsh-*` name makes it identifiable in
`${TMPDIR:-/tmp}`.

Shell command lines are a poor place for passwords, tokens, or private keys:
they can be exposed through history, process listings, logs, or the invoked
program itself. `HIST_IGNORE_SPACE` is enabled, but a leading space is only a
convenience and not a secret-storage mechanism. Prefer the macOS Keychain or a
dedicated secret store, and rotate any credential that was exposed.

## Administrator boundary

No administrator access occurs at shell startup, during installation, while
showing help, or during normal prompt, search, history, Git, and navigation
features. Only `flash-usb` and `format_external_device` use `sudo`, after the
user selects a whole external physical disk and types the exact visible
`ERASE diskN` confirmation.

The privilege flow is deliberately narrow:

1. Compozsh captures and validates an external whole-disk identity.
2. The user reviews the exact `/dev/diskN` target and confirms it by name.
3. Compozsh runs `/usr/bin/sudo -v`. Apple's `sudo` reads any password directly
   from the terminal and manages its own authorization timestamp.
4. Compozsh revalidates the target before mutation.
5. Privileged operations use `sudo -n`, which refuses to prompt or read a
   password. The permitted implementations are Apple's `/bin/dd`,
   `/usr/sbin/diskutil`, one fixed internal Zsh raw-device routine, and an
   Apple-signature-validated `createinstallmedia` from the explicitly selected
   macOS installer application.

The raw-image routine passes image paths, device names, sizes, and verification
flags as literal arguments. It does not pass shell history, environment dumps,
credentials, or network destinations. Password handling remains entirely
inside the operating system's `sudo` process.

Audit the complete privilege surface with:

```sh
git grep -n 'sudo' -- .zshrc install.zsh '.zsh.addons/**'
git grep -nE 'sudo[[:space:]]+(-S|--stdin)|SUDO_ASKPASS|pbpaste|/usr/bin/security' \
  -- .zshrc install.zsh '.zsh.addons/**'
```

The first command should identify only `.zsh.addons/.zsh.usb`. The second
should print no matches and return status 1. Inspect every changed result rather
than treating the command as a permanent allowlist.

## Network boundary

The active shell configuration contains no network client and no project
endpoint. Compozsh's Git inspection does not request `clone`, `fetch`, `pull`,
`push`, or another remote operation: prompt status disables a
repository-configured filesystem monitor, branch views read local refs and
reflogs, and Git review disables repository-configured clean/process filters
for its own reads. File discovery uses bounded filesystem reads, local Git
metadata, or the local Spotlight index.

These boundaries can still lead to network activity outside Compozsh itself:

- Cloning and updating the repository, and network-capable Git subcommands the
  user explicitly runs, use the configured Git transport. Git also documents
  that a [partial clone](https://git-scm.com/docs/partial-clone) may
  demand-fetch a missing object during an otherwise local command; that is
  installed Git behavior against the repository's configured promisor remote,
  not a Compozsh endpoint.
- Project runtime detection invokes an installed runtime's version command from
  `/`. Common auto-install and telemetry controls are disabled where supported,
  but the executable on `PATH` remains independently trusted software.
- Explicit Xcode build, test, analyze, clean, run, and Apple skill-export actions
  invoke Apple's tools. Discovery disables automatic package resolution and
  updates; a chosen build can execute project build phases.
- Open and Reveal actions can launch Finder or another installed application.
  That application's later behavior is outside this repository.
- Explicitly invoking the repository's `compozsh-platform-review` agent skill
  asks the chosen coding agent to consult current official documentation. The
  local snapshot script contains no URL request and omits personal machine
  data, but the agent and its provider have their own network and data policies.

The optional `docs/` website is static and self-contained. Its Content Security
Policy uses `connect-src 'none'`; JavaScript has no fetch, beacon, WebSocket, or
remote script path. Links and canonical metadata point to the official GitHub
project, but a network navigation occurs only when the browser loads the hosted
page or the user follows a link. GitHub or another chosen host may retain normal
web-server access logs; that hosting boundary is not controlled by the static
files in this repository.

## Audit a commit before installing

Run these commands from the clone. They use the required Git and stock shell
tools; they do not execute Compozsh.

First establish exactly what is being reviewed:

```sh
git -c core.fsmonitor=false status --short
git rev-parse HEAD
git remote get-url --all origin
git ls-files .zshrc install.zsh templates .zsh.addons docs tests SECURITY.md
```

An empty status means tracked files match the checked-out commit. Record the
commit ID. The expected project remote is
`https://github.com/bitbemol/compozsh.git` or
`git@github.com:bitbemol/compozsh.git`; a remote URL should not contain a token
or password, and its output should not be pasted into a report without review.
Review any local modification or untracked `.zsh.<name>` file before starting
Zsh because the bootstrap intentionally loads matching private peers too.

Inspect the only automatic source boundary:

```sh
sed -n '1,220p' .zshrc
git grep -nE '(^|[[:space:]])(source|eval)[[:space:]]' \
  -- .zshrc install.zsh '.zsh.addons/**' templates
```

The tracked bootstrap sources the optional machine-local initializer and every
matching peer beneath the repository and user add-on directories. The tracked
starter is inert, but an existing private initializer or peer is user-owned code
and must be audited separately.

Search the executable shell surface for common network clients:

```sh
git grep -nE '(^|[;&|[:space:]])(command[[:space:]]+)?(/usr/bin/)?(curl|wget|ssh|scp|sftp|nc|netcat|socat|telnet|rsync)([[:space:]]|$)' \
  -- .zshrc install.zsh '.zsh.addons/**' templates
```

The command should print no matches and return status 1. This is a useful
regression check, not proof by keyword absence; also read new command execution,
redirection, dynamic function dispatch, and source paths in the diff.

Audit website connection primitives and all hard-coded destinations:

```sh
git grep -nE 'fetch\(|XMLHttpRequest|WebSocket|sendBeacon|src="https?://|@import' -- docs
git grep -nE 'https?://|wss?://|ftp://' \
  -- .zshrc install.zsh '.zsh.addons/**' templates docs .agents
```

The first command should print no matches. The second is intentionally broad:
review every URL. Expected tracked URLs are documentation comments, official
project links and website metadata. The optional platform-audit inventory also
runs `/usr/bin/curl --version`; it records the installed binary's version and
does not give curl a URL.

Review local storage and sensitive effect boundaries:

```sh
git grep -nE 'HISTFILE|mktemp|\.zsh-backups|pbcopy|sudo|/dev/(r)?disk|diskutil|createinstallmedia' \
  -- .zshrc install.zsh '.zsh.addons/**' templates README.md
```

Finally run the isolated regression suite:

```sh
zsh tests/run.zsh
```

Tests improve confidence in documented behavior but do not replace source
review. A new commit is new code and should be compared before it becomes the
active symlinked configuration.

## Audit an update before activating it

`git pull` changes a symlink installation immediately. To review first, fetch
the proposed commit without moving the working tree, compare it, and only then
fast-forward:

```sh
git fetch origin
git --no-pager log --oneline --decorate HEAD..origin/main
git --no-pager diff --no-ext-diff --no-textconv --text HEAD..origin/main -- \
  .zshrc install.zsh .zsh.addons templates docs tests SECURITY.md README.md
git merge --ff-only origin/main
exec zsh
```

Fetching necessarily contacts the configured remote; it does not activate the
fetched shell files. Replace `origin/main` with the exact remote ref you intend
to trust. Compare the recorded old and new commit IDs, inspect renamed and new
files, and rerun the audit and tests. Copy installations do not change until the
reviewed installer is run again.

## Supported versions

Security fixes target the current `main` branch and the next release. This
repository does not currently maintain separate long-lived release branches;
older tags should not be assumed to receive backports unless a security
advisory says otherwise. Reports for any version are welcome—include the exact
commit ID so the affected behavior can be reproduced.

## Reporting a vulnerability

Do not place a live password, token, private key, personal path, private
repository content, or exploitable sensitive detail in a public issue. Use
[GitHub private vulnerability reporting](https://github.com/bitbemol/compozsh/security/advisories/new)
when it is available. If that route is unavailable, open a minimal issue asking
for a private reporting channel without including the sensitive details.

Include the affected commit ID, macOS and Zsh versions, the smallest synthetic
reproduction, the observed data or privilege boundary, and whether credentials
may have been exposed. Revoke or rotate exposed credentials immediately; a
source-code fix cannot make a disclosed secret private again.
