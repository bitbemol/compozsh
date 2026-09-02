# Security and privacy

Compozsh is shell code: installing it gives the tracked bootstrap and enabled
peer add-ons access to the interactive shell environment. That trust should be
based on inspectable behavior, not on a promise from the maintainer. This
document defines the shipped security boundary, identifies every intentional
sensitive-data and administrator boundary, and provides repeatable checks for
the exact commit you intend to run.

The guarantees below apply to all behavior implemented by repository-managed
files at the commit being audited. Private add-ons, the machine-local
initializer, installed programs, inspected repositories, the operating system,
GitHub, and software opened or built at the user's request are independently
controlled code or services. The sections below disclose every class of local
handoff from Compozsh to one of those boundaries. Those disclosures do not
create an exception that permits Compozsh itself to transmit data.

## Non-transmission invariant

All processing performed by Compozsh stays on the machine running its Zsh
process, including a user-controlled remote host during SSH. Compozsh never
transmits user or project data under any circumstance. There is no telemetry
opt-in, consent exception, debugging mode, feature flag, or future product mode
that weakens this rule. A feature that requires Compozsh-owned transmission is
outside the product contract and must not be added.

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
every intentional persistent location and lifetime is enumerated below.

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
- The tracked shell and installer define no project endpoint and initiate no
  network request. Updates happen only when the user runs Git themselves.
- It does not collect, read, log, store, or transmit a `sudo` password. The two
  external-media tools and explicit `compozsh-sudo-touch-id enable|disable`
  modes invoke Apple's `/usr/bin/sudo -v`; `sudo` and PAM own the authentication
  prompt, Touch ID exchange, and timestamp. Compozsh never receives the
  password or fingerprint data.
- It does not use `sudo -S`, `SUDO_ASKPASS`, a password variable, the login
  keychain, or the macOS `security` credential command.
- It never reads the clipboard. Explicit Copy actions write only the visibly
  selected path or branch, current directory, or a bounded Xcode test report
  assembled from the visible result snapshot through `pbcopy`. The optional
  website writes a visible installation command only after its Copy button is
  clicked.
- The shell configuration, installer, and static site upload nothing. This
  includes shell history, paths, Git data, project metadata, file previews,
  diffs, runtime versions, disk metadata, and installer output.
- It does not automatically download and execute shell code. Installation uses
  only files already present in the reviewed clone.

These constraints admit no Compozsh exception. They do not claim that the
operating system and independently controlled programs are offline. Compozsh's
transparent `git` wrapper, for example, passes an explicit user request for
`git clone`, `fetch`, `pull`, or `push` to Git without adding data or another
destination. An application opened by an explicit file action, an Xcode build
phase, or an installed runtime queried for its version retains its own security
and privacy behavior.

## Complete local data inventory

Compozsh creates no off-machine storage or transmission destination. Every
intentional Compozsh data location is listed below with its lifetime. Some
entries are persistent because a shell and a recoverable installer need local
state:

| Data | Location and lifetime | Why it exists |
| --- | --- | --- |
| Command history | `${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}` by default | Zsh's normal local, shared history and the in-memory history picker |
| Private initialization and peers | `${ZDOTDIR:-$HOME}/.zsh.addons` | User-owned machine setup and extensions loaded by the bootstrap |
| Recovery copies | `${ZDOTDIR:-$HOME}/.zsh-backups/compozsh-*` | The installer preserves configuration it replaces instead of deleting it |
| Optional sudo Touch ID policy | `/etc/pam.d/sudo_local` until explicit disable; `/etc/pam.d/.compozsh-sudo-touch-id.*` during enable and after an abnormal interruption | Three fixed text lines enabling Apple's `pam_tid`; created only by `compozsh-sudo-touch-id enable`, ACL-free, owned by `root:wheel`, and mode `0444` before publication |
| Prompt, appearance, and picker facts | Shell memory | Configured or passively hinted color-scheme classification, runtime versions, Git state, paths, and temporary view snapshots; discarded with the shell or view |
| Created Git worktrees | Explicitly selected new folder; branch refs and registration in the repository's Git common directory | Created only by `g -w` / `g --worktree` acceptance; persists until explicit Git/workspace removal, with branches preserved by workspace removal and all worktrees preserved on Compozsh uninstall |
| Temporary operation captures | `${TMPDIR:-/tmp}` | USB progress, bounded Xcode discovery output, transient test-result bundles, and Git syntax-rendering input; validated temporary paths are removed during normal and handled-error cleanup |
| Exported Apple skills | Detected coding agents' local skill directories | Created only by an explicit `update-xcode-skills` invocation and marked for safe refresh |
| Clipboard values | The clipboard of the machine running Zsh | Written only by an explicit Copy action; values can contain a path, branch, current directory, visible website command, or bounded Xcode test report with local project paths and diagnostics; never read back by Compozsh |

Appearance selection reads only `ZSH_COLOR_SCHEME` and the optional passive
`COLORFGBG` environment hint, then retains a `light` or `dark` classification.
It writes no terminal query, reads no terminal input, sends no data, and starts
no process. An absent or invalid automatic hint retains the dark palette.

Path + Tab can capture immediate directory entries from a lone path or an
explicit directory argument such as `vim ~/Developer`. The editor retains the
command prefix only in invocation-local memory; insertion replaces that
argument after screen cleanup, without executing the command. Escape and Copy
preserve the draft. Browsing reads entry names and file-type metadata, never
file contents; snapshots and the retained prefix are released on return.
Inspect `.zsh.addons/.zsh.editor` and run `zsh tests/run.zsh 'directory argument'`
to verify insertion, quoting, cancellation, clipboard dispatch and native file
completion in isolated fixtures. These checks do not establish availability
or latency for arbitrary mounted filesystems.

These are local process, filesystem, agent-directory, and operating-system
clipboard interfaces on the machine running Compozsh. A user can independently
configure a history, configuration, temporary, or agent directory on a synced
or network-mounted filesystem. macOS can also synchronize its clipboard when
the user enables that operating-system feature. Compozsh does not configure,
detect, start, or control either form of synchronization. Users who require
physical single-machine retention must choose local, nonsynchronized paths and
disable operating-system clipboard synchronization or avoid Copy actions.

The installer never prints the contents of an old `.zshrc` or private add-on,
but a recovery backup can contain secrets that were already present there.
Protect and eventually archive or remove those backups according to your own
retention policy. Compozsh deliberately does not delete them automatically.
An uncatchable process termination or system failure can also leave a temporary
capture behind; its validated `compozsh-*` name makes it identifiable in
`${TMPDIR:-/tmp}`.

The Xcode dashboard's Test and Rebuild & Test actions ask Xcode to create a
transient result bundle while disabling verbose test-diagnostic collection.
Xcode can still put test-authored attachments and logs in that bundle. Compozsh
reads only size-bounded summary/detail JSON and structured source locations,
never those attachments or source files, rejects a symlink substituted for the
result bundle, and removes the complete bundle before opening the result view.
An uncatchable termination can leave the local bundle behind under the
identifiable `compozsh-xcode-test.*` temporary directory.

The worktree workspace reads local refs, commit IDs, registered paths and flags
from Git, directory identities, and explicitly browsed parent-folder names.
Removal additionally reads Git operation markers, tracked-tree modes, index
flags, and status including ignored and untracked names; Git may read working
file contents to establish status. Creation reads the selected committed tree
to check for submodules. Captures stay in invocation memory, bounded to 256 KiB
each and 1,000 worktrees, branches or child folders per catalog. Failed or
oversized safety captures refuse the action. No worktree catalog or navigation
history is written by Compozsh. Git may take longer than these output bounds
suggest, especially on slow storage.

Create writes the chosen new folder and native Git refs/registration; the
installed Git and the user's umask govern normal checkout ownership and modes.
`git rev-parse --path-format=absolute --git-common-dir` resolves the metadata
base: linked-worktree registrations live under its `worktrees/<id>` directory,
and branch references use the repository's native Git reference storage.
Compozsh neither copies ignored/private files from another checkout nor changes
existing access controls. The workspace refuses configured clean/smudge/process
filters or required-filter settings, rather than invoking them or disabling
their content transformations. This includes globally configured Git LFS even
when a particular checkout might not use it. Submodule checkouts are refused.
Creation first uses `worktree add --no-checkout`, then checks effective
configuration in that new branch/directory before a non-forcing `read-tree -m
-u --no-sparse-checkout` populates the complete committed tree. This second
check covers conditional includes absent from the source checkout. Refusal at
that stage leaves the branch and registered empty folder for inspection; no
filter is executed and no automatic cleanup is attempted.
All workspace Git calls disable transport, lazy fetch, hooks, fsmonitor,
automatic maintenance, optional index writes and submodule recursion. Explicit
roots override inherited Git directory/index/object/namespace selectors.
Entering a worktree changes this shell's directory and can invoke independently
owned user `chpwd` hooks, as with an ordinary explicit directory change.

Removal deletes only the confirmed registered linked checkout, preserves its
branch, and refuses main/current, locked, missing or detached worktrees,
in-progress Git operations, changes, untracked and ignored files, submodules,
sparse/unmerged indexes and assume-unchanged flags. Repository and directory
identities, branch/commit and safety checks are revalidated after screen
restoration. These checks are not an atomic filesystem transaction: concurrent
writers or path replacement between validation and Git can still change the
outcome. Stop other writers before removal; there is no Undo. No force, branch
deletion, automatic stash, recursive shell deletion or rollback is used.
Git action errors retain their status. An interrupted/failed creation may leave a
branch, registration or partial folder. Inspect `git worktree list`,
`git branch` and the exact destination before retrying; Compozsh does not delete
that residue automatically. A failed directory change after creation preserves
the checkout. Removing Compozsh leaves created worktrees and branches intact.

Shell command lines are a poor place for passwords, tokens, or private keys:
they can be exposed through history, process listings, logs, or the invoked
program itself. `HIST_IGNORE_SPACE` is enabled, but a leading space is only a
convenience and not a secret-storage mechanism. Prefer the macOS Keychain or a
dedicated secret store, and rotate any credential that was exposed.

## Administrator boundary

No administrator access occurs at shell startup, during installation, while
showing help, during `compozsh-sudo-touch-id status`, or during normal prompt,
search, history, Git, and navigation features. Administrator access has two
explicit boundaries: `flash-usb` and `format-external-device` after the user
selects a whole external physical disk and types the exact visible `ERASE
diskN` confirmation; and `compozsh-sudo-touch-id enable|disable` after the user
names that state-changing mode.

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

The raw-image routine passes image paths, captured source fingerprints, device
names, sizes, and verification flags as literal arguments. Its privileged
routine opens the source once with no-follow semantics, verifies the held file
descriptor's device, inode, size, and modification time against the capture,
and uses that descriptor for writing and read-back comparison. It does not pass
shell history, environment dumps, credentials, or network destinations.
Password handling remains entirely inside the operating system's `sudo`
process.

The Touch ID policy flow is separate and equally bounded:

1. Compozsh verifies macOS and an ACL-free, root-owned, non-writable
   `/etc/pam.d`. Enable additionally requires the root-owned, ACL-free system
   `sudo` policy to include `sudo_local` before its required
   `pam_opendirectory.so` password fallback, and the matching system template to
   advertise `pam_tid`. Policy files observed above 64 KiB are rejected before
   reading; this is a fail-closed size check, not atomic isolation from root.
2. `status` reads fixed PAM-directory metadata and the fixed target. `enable`
   proceeds only when `/etc/pam.d/sudo_local` is absent. `disable` remains
   usable if the enable prerequisites later drift, but proceeds only for a regular, ACL-free,
   `root:wheel`, mode `0444`, byte-identical managed file. Existing
   custom, symbolic-link, special-file, changed, or unsafe policy is preserved.
3. The state-changing modes run `/usr/bin/sudo -v`. Before enable, this normally
   means a password; after enable, Apple's PAM stack can present Touch ID.
   Authentication data remains inside `sudo`, PAM, and macOS. The local
   `pam_tid` result is scoped to sudo; Compozsh receives no fingerprint,
   template, or reusable biometric token and introduces no network request.
   Either authentication method can refresh sudo's ordinary credential cache;
   a process already controlling the same terminal session may benefit until
   expiry. `sudo -k` invalidates the current timestamp.
4. After visible authorization, enable repeats platform validation and absence
   checking. One `sudo -n` fixed internal `/bin/zsh -dfc` routine repeats the
   fixed system-policy checks, creates a root-only temporary file beneath
   `/etc/pam.d`, writes only the fixed policy, strips inherited ACLs, applies
   `root:wheel` ownership and mode `0444`, verifies exact metadata and bytes,
   and uses `/bin/link` to publish exactly `/etc/pam.d/sudo_local` without
   replacing any path. It removes the temporary link and verifies the published
   inode. Disable's one fixed privileged routine revalidates type, numeric link
   count, ownership, mode, ACL and bytes immediately before `/bin/unlink`. An
   exact managed target with additional hard links remains removable, but only
   the literal `/etc/pam.d/sudo_local` name is unlinked; every other link is
   preserved for separate inspection. Handled failures do not broaden either
   target. The privileged routines do not trust
   the caller's inspection path: they repeat checks against literal
   `/etc/pam.d` targets. A concurrent root policy manager can
   still replace state around shell-level checks; Compozsh fails closed when it
   observes drift but does not claim compare-and-unlink isolation from root.
5. `pam_tid` is configured as `sufficient`. A failed or unavailable biometric
   attempt falls through to the verified later required
   `pam_opendirectory.so` authenticator; the rule changes the authentication
   method, not who is authorized for sudo.

The managed policy persists across shells and macOS updates until explicit
disable. No backup is created because existing `sudo_local` policy is never
changed. An abnormal or unhandled termination during the short privileged
enable step can leave a root-owned `.compozsh-sudo-touch-id.*` file beneath
`/etc/pam.d`; it is not included by sudo and may be empty, partially written,
or complete, with mode `0600` or finalized mode `0444`. Inspect and remove such
residue as administrator after confirming its fixed path and contents. Apple's
`pam_tid` cannot present Touch ID in SSH's non-graphical session and may also be
unavailable through a multiplexer or another remote context. The later password
authenticator can prompt only when `sudo` has usable terminal input.

Audit the complete privilege surface with:

```sh
git grep -n 'sudo' -- .zshrc install.zsh '.zsh.addons/**'
git grep -nE 'sudo[[:space:]]+(-S|--stdin)|SUDO_ASKPASS|pbpaste|/usr/bin/security' \
  -- .zshrc install.zsh '.zsh.addons/**'
```

The first command should identify only `.zsh.addons/.zsh.usb` and
`.zsh.addons/.zsh.sudo-touch-id`. The second should print no matches and return
status 1. Inspect every changed result rather than treating the command as a
permanent allowlist. In the Touch ID peer, confirm every privileged target is a
literal path beneath `/etc/pam.d` and that only `/usr/bin/sudo -v` can prompt.
On a supported Mac, independently inspect the active system files for Apple's
documented interface with
`ls -lde /etc/pam.d /etc/pam.d/sudo /etc/pam.d/sudo_local.template`,
`sed -n '1,120p' /etc/pam.d/sudo`, and
`sed -n '1,120p' /etc/pam.d/sudo_local.template`; do not paste these files into
a shell command. Apple's macOS Sonoma enterprise notes document the persistent
`sudo_local` interface, and Apple's published `pam_tid` source documents its
local graphical-session and askpass limitations.

## Compozsh network prohibition and external boundaries

Compozsh defines no project endpoint and initiates no network request. Its Git
inspection does not request `clone`, `fetch`, `pull`, `push`, or another remote
operation: prompt status disables repository-configured clean/process filters,
filesystem monitors, hooks, required-filter enforcement, and lazy fetches;
branch views read local refs and reflogs; and Git review applies its own
equivalent read-only filter boundary. The `g -w` / `g --worktree` action
workspace also disables transport and hooks and refuses checkout filters;
its checkout/removal boundary is detailed in the local-data inventory above.
`git-discard-all` applies those controls
to preview, restore, cleanup, and verification, and revalidates repository,
HEAD, operation, filter-name, and listed-path state after confirmation. File
discovery uses bounded filesystem reads, local Git metadata, or the local
Spotlight index.

This is the complete external-network boundary disclosure. The following
independently controlled software can use the network; none is a permission for
Compozsh to add a request, destination, or data:

- Cloning and updating the repository, and network-capable Git subcommands the
  user explicitly runs, use the configured Git transport. Git also documents
  that a [partial clone](https://git-scm.com/docs/partial-clone) may
  demand-fetch a missing object during an otherwise local command; that is
  installed Git behavior against the repository's configured promisor remote,
  not a Compozsh endpoint.
- Prompt runtime detection invokes a trusted-path installed runtime with a
  fixed version argument from `/`. Common auto-install and telemetry controls
  are disabled where supported, but the executable on `PATH` remains
  independently trusted software with its own behavior.
- Explicit Xcode build, test, analyze, clean, run, and Apple skill-export actions
  invoke Apple's tools. Discovery disables automatic package resolution and
  updates; a chosen build can execute project build phases.
- Open and Reveal actions can launch Finder or another installed application.
  That application's later behavior is outside this repository.
- Explicitly invoking the repository's `compozsh-platform-review` agent skill
  asks the chosen coding agent to consult current official documentation. The
  local snapshot script contains no URL request and omits personal machine
  data, but the agent and its provider have their own network and data policies.
- Invoking the repository's `compozsh-release-draft` agent skill asks the chosen
  coding agent to read this project's public GitHub release metadata and tag
  resolution. Its instructions prohibit sending repository contents, local
  paths, credentials, or private remote parameters in those requests, but the
  agent, its provider, and GitHub retain their own network and data policies.

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

Audit the worktree action boundary before exercising it:

```sh
git show HEAD:.zsh.addons/.zsh.git-worktree
git show HEAD:.zsh.addons/.zsh.navigation
zsh tests/run.zsh 'worktree '
```

Read the fixed Git policy in `_git_worktree_git`, complete-capture checks,
creation/removal validation and post-screen dispatch. The focused tests use
disposable repositories and should all pass: aliases/fallbacks, exact targets,
refusals, branch preservation and native keyboard/screen behavior. They do not
prove atomicity against concurrent external writers. Run against the exact
checkout being audited; before commit, read the corresponding working files
instead of `git show HEAD:...`.

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
reviewed installer is run again. This fetch is a deliberate command run by the
user for an update review; Compozsh never performs it automatically.

## Supported versions

Security fixes target the current `main` branch and the next release. This
repository does not currently maintain separate long-lived release branches;
older tags should not be assumed to receive backports unless a security
advisory says otherwise. Reports for any version are welcome—include the exact
commit ID so the affected behavior can be reproduced.

## Reporting a vulnerability

Reporting is optional, deliberate communication initiated by the user and is
not performed by Compozsh. GitHub receives whatever the reporter chooses to
submit, so review and redact the report before sending it.

Do not place a live password, token, private key, personal path, private
repository content, or exploitable sensitive detail in a public issue. Use
[GitHub private vulnerability reporting](https://github.com/bitbemol/compozsh/security/advisories/new)
when it is available. If that route is unavailable, open a minimal issue asking
for a private reporting channel without including the sensitive details.

Include the affected commit ID, macOS and Zsh versions, the smallest synthetic
reproduction, the observed data or privilege boundary, and whether credentials
may have been exposed. Revoke or rotate exposed credentials immediately; a
source-code fix cannot make a disclosed secret private again.
