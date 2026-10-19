# Security and privacy

Compozsh is shell code: installing it gives the tracked bootstrap and enabled
peer add-ons access to the interactive shell environment. That trust should
rest on inspectable behavior, not on a promise from the maintainer. This
document defines the shipped security boundary, identifies every intentional
sensitive-data and administrator boundary, and provides repeatable checks for
the exact commit you intend to run.

The guarantees apply to all behavior implemented by repository-managed files at
the commit being audited. Private add-ons, the machine-local initializer,
installed programs, inspected repositories, the operating system, GitHub, and
software opened or built at the user's request are independently controlled
code or services. This document discloses every class of local handoff from
Compozsh to one of those boundaries. No disclosure creates an exception that
permits Compozsh itself to transmit data.

## Non-transmission invariant

All processing performed by Compozsh stays on the machine running its Zsh
process, including a user-controlled remote host during SSH. Compozsh never
transmits user or project data under any circumstance. There is no telemetry
opt-in, consent exception, debugging mode, feature flag, or future product mode
that weakens this rule. A feature that requires Compozsh-owned transmission is
outside the product contract and must not be added.

This invariant governs Compozsh code; it does not pretend that the operating
system or a program explicitly invoked by the user is offline. If the user asks
Git to clone, fetch, pull, or push, Git communicates with the destination the
user selected; the transparent Compozsh `git` wrapper adds no data, endpoint,
or separate request. An application opened by an explicit file action, an Xcode
build phase, an installed runtime queried for its version, build tools, and
private add-ons retain their own independently auditable security and privacy
behavior. [Compozsh network prohibition and external
boundaries](#compozsh-network-prohibition-and-external-boundaries) lists the
network-capable handoffs; the feature sections below disclose the remaining
local handoffs (for example Git hooks and filters during explicit switches,
`chpwd` hooks and [external synchronization](#external-synchronization)). The
sections apply this invariant without restating it.

## Privacy model

Privacy, credential protection, data minimization, and user control are
top-level product goals. Compozsh acquires only the facts required for the
visible task, within its displayed scope, and retains them only for the
necessary lifetime. Temporary view state stays in memory when practical; every
intentional persistent location and lifetime is enumerated below.

Sensitive values are handled as literal, bounded data and are never evaluated
as shell code. That includes Zsh arithmetic, which expands `$(...)` inside a
subscript: numbers from files, Git, tools, settings, the terminal and the
inherited environment are validated as decimal text before any arithmetic use,
with a digit bound unless the fixed output format of `/usr/bin/stat` already
bounds the field; names such as paths and branches
never enter arithmetic text; and private state names inherited from the
environment are discarded or read only as text. Compozsh does not collect
information merely because it is available in the environment, filesystem, Git
metadata, command output, or terminal session. It does not accept plaintext
authentication secrets; an operating-system or explicitly chosen external tool
owns its authentication input. Operations use the least privilege and
narrowest exact target their implementation permits.

New collection, persistence, or privilege is not an ordinary implementation
detail. It requires an explicit product decision, disclosure of the exact data,
purpose, path, trigger, lifetime, access and cleanup behavior, independent audit
evidence, and focused regression coverage.
Transmission is prohibited rather than configurable. If scope, ownership,
permissions, or cleanup cannot be established safely, the operation must fail
without broadening access or retaining another copy. External tools,
user-owned configuration, and hosting remain separate trust boundaries and are
disclosed rather than presented as guarantees made by Compozsh.

## What the shipped project does not do

- It has no telemetry, analytics, crash-reporting service, account, project
  server, background daemon, automatic Compozsh software update check, or
  runtime package download.
- The tracked shell and installer define no project endpoint and initiate no
  network request. Updates happen only when the user runs Git themselves.
- It does not collect, read, log, store, or transmit a `sudo` password. The two
  external-media tools and explicit `compozsh --sudo-touch-id enable|disable`
  modes invoke Apple's `/usr/bin/sudo -v`; `sudo` and PAM own the authentication
  prompt, Touch ID exchange, and timestamp. Compozsh never receives the
  password or fingerprint data.
- It does not use `sudo -S`, `SUDO_ASKPASS`, a password variable, the login
  keychain, or the macOS `security` credential command.
- It never reads the clipboard. Explicit Copy actions write only the visibly
  selected path or branch, current directory, a bounded Xcode test report,
  or complete matching lines from the retained Simulator or device log snapshot
  through `pbcopy`. The optional website writes a visible installation command
  only after its Copy button is clicked.
- The shell configuration, installer, and static site upload nothing. This
  includes shell history, paths, Git data, project metadata, file previews,
  diffs, runtime versions, disk metadata, and installer output.
- It does not automatically download and execute shell code. Installation uses
  only files already present in the reviewed clone.

These constraints admit no Compozsh exception.

## Complete local data inventory

Compozsh creates no off-machine storage or transmission destination. This table
is the authoritative list of every intentional Compozsh data location, its
lifetime and its limits. Some entries are persistent because a shell and a
recoverable installer need local state.

| Data | Location and lifetime | Contents and bounds |
| --- | --- | --- |
| Command history | `${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}` by default | Zsh's normal local, shared history and the in-memory history picker |
| Native completion dump | `${ZDOTDIR:-$HOME}/.zcompdump`, written by Zsh's stock `compinit` (called by `.zsh.editor` with its full audit, and with `-d` only for the [compiled copy](#native-completion-dump)) when a fresh shell finds it missing or its `fpath` file count or Zsh version changed; persists until deleted, including after `--clean` and uninstall | [Zsh-generated shell code](#native-completion-dump) that `compinit` sources: the count, Zsh version and the verbatim first-line words of `fpath` completion files (normally function, command, service, pattern and key names), private entries included, plus completion widget bindings. No `fpath` directory paths, file bodies, history, environment values or project data. Mode follows the umask at write time (0644 under the default 022); an interrupted write can leave `.zcompdump.<host>.<pid>`, or `zcompdump.<host>.<pid>` in the compiled mirror while the compiled copy was in use |
| Private initialization and peers | `${ZDOTDIR:-$HOME}/.zsh.addons`; an initializer moved by `ZSH_LOCAL_INIT` stays at that absolute path (a relative value is ignored) | User-owned machine setup and extensions loaded by the bootstrap |
| Recovery copies | `${ZDOTDIR:-$HOME}/.zsh-backups/compozsh-*` | Configuration the installer replaced, preserved instead of deleted; a rollback that cannot put an item back keeps it there and prints the path |
| Installer copy staging | `${ZDOTDIR:-$HOME}/.compozsh-install.*`, a mode-0700 directory that exists only while `install.zsh --copy` runs; removed on success, handled failure, and Ctrl-C, hangup or termination signals ([residue limits](#installer-backups-and-temporary-residue)) | The clone's `.zsh.addons` tree without `support/cache` or `support/compiled` (untracked files included) plus the `.managed-by-compozsh` marker, staged before any active state moves; never sourced |
| Compiled peer mirror | `${ZDOTDIR:-$HOME}/.zsh.addons/support/compiled`, a mode-0700 directory written by `install.zsh` (both layouts; rebuilt by each installation) and by interactive startup, which creates it when missing, recompiles shipped peers that are new or changed, drops the entry, wordcode and record of a shipped peer that was removed or renamed and, after `compinit`, compiles a new or changed completion dump; persists until the next installation, `--clean` (archived with the add-on tree) or uninstall, except that a removed or renamed peer's entry lasts only until the next shell that can compile | [Executable Zsh wordcode](#compiled-peer-mirror): per shipped peer (every regular `.zsh.<name>` file in the shared add-on directory, tracked or not: the clone's `.zsh.addons` for `--symlink`, the managed `compozsh/` namespace for `--copy`) a symlink to its absolute path and the `.zwc` that `zcompile` made from it, never private peers in `${ZDOTDIR:-$HOME}/.zsh.addons`; for the [completion dump](#native-completion-dump) a `zcompdump` symlink to it, its `zcompdump.zwc` (the dump's names, compiled) and a `zcompdump.manifest` of the Zsh version, the dump's path, the same parse context and the dump's device, inode, size, mtime and ctime; a `manifest` of the Zsh version, the parse context it was compiled under (always Zsh's default parse-affecting options and its two built-in aliases, `run-help` and `which-command`; never an alias a startup file defined), the shipped add-on directory and each peer's relative path, device, inode, size, mtime and ctime (a `-` record marks a peer that stays text until it changes); the `.managed-by-compozsh` marker; only after a compile refused a shell of another Zsh version, a `zsh` note of `/bin/zsh`'s version, device, inode, size, mtime and ctime; only while a compile runs, a `.lock` directory and `*.compozsh-tmp-<pid>` files; and, only when `compinit`, given the compiled copy's entry, must rewrite its dump, Zsh's own `zcompdump.<host>.<pid>` and then the rewritten dump at the `zcompdump` entry, written by stock `compdump` under your umask (0644 under the default 022) until `.zsh.editor` moves it to `${ZDOTDIR:-$HOME}/.zcompdump` or deletes it (if that step cannot run, it stays there as a regular file, never loaded as the compiled copy, until the next dump compile replaces it with the symlink). It holds only the compiled code of the shipped peers (including any `.zsh.<name>` file you added to the clone), the completion dump's contents (compiled, or as text in that transient file), the parse context, paths and file identity; never your aliases, environment values, history or project data. Loaded only while fresh |
| Installer compile staging | `${ZDOTDIR:-$HOME}/.compozsh-compiled.*`, a mode-0700 directory that exists only while `install.zsh` runs; removed on success, handled failure, and Ctrl-C, hangup or termination signals ([residue limits](#installer-backups-and-temporary-residue)) | The new compiled mirror before activation and the superseded one after it; never sourced |
| Optional sudo Touch ID policy | `/etc/pam.d/sudo_local` until explicit disable; `/etc/pam.d/.compozsh-sudo-touch-id.*` during enable and after an abnormal interruption | Three fixed lines enabling Apple's `pam_tid`, created only by `compozsh --sudo-touch-id enable`; ACL-free, `root:wheel`, mode `0444` before publication |
| Prompt, appearance, and picker facts | Shell memory; discarded with the shell or view | Color-scheme classification, runtime versions, Git state, paths, Context trigger/disclosure flags, positive/exclusion fields and their bookmarks, temporary view snapshots |
| Direct Git behind `/usr/bin/git` | Shell memory until `compozsh --refresh` or shell exit; replaced when a selector changes | Only when `PATH` selects `/usr/bin/git`: the Git path `/usr/bin/xcrun --find git` names, its device, inode, mode, owner, size and modification/change times, and the selectors it was resolved under (the `PATH` choice, exported `DEVELOPER_DIR`, `TOOLCHAINS` and `SDKROOT`, and the `/var/db/xcode_select_link` target), or a refusal ([Apple's Git launcher](#local-only-git-controls)) |
| Local manual summaries | Shell memory until refresh, discovery-selector invalidation or shell exit | Bounded NAME descriptions and page-name/section attribution from the [manual roots](#local-manual-summaries); describes literal names, not executable identity |
| Manual background transport | Shell memory, native PTYs and an unlinked kernel FIFO during one request | At most 16 MiB / 8,192 records in 8-KiB reads from one capture process under two supervisors; mode-0600 FIFO in a mode-0700 `${TMPDIR:-/tmp}/compozsh-manual-async.*` directory, both unlinked once opened; no regular file of descriptions or selectors |
| Public OS manual cache | `${ZDOTDIR:-$HOME}/.zsh.addons/support/cache/.zsh.manual.cache`, until refresh/replacement/removal | Protected OS manual NAME descriptions, aliases, relative page IDs and a public freshness key, owner-only and inert; `.zsh.manual.lock` and bounded `.zsh.manual.cache.*` staging residue. No private selectors or custom manuals |
| Manual formatter directory | Private mode-0700 temporary directory during capture | Empty mandoc working directory; page text stays in bounded memory and pipes, never a file. Removed on cleanup; an uncatchable termination can leave it empty |
| Interaction lens state | Shell memory for the active prompt; replaced as buffer or outcome changes, discarded with the shell | Interaction kind, sanitized bounded excerpts and structural summaries, up to eight 240-character alias previews, context anchors, latest outcome, a bounded autosuggestion prefix; never leading assignment values |
| Draft inspector | Invocation memory, only after Option-Return; released on return | At most 32,768 literal draft characters plus a truncation notice, cursor/length/current-folder facts, reading filters and frames; can display sensitive text, unredacted and unexecuted |
| Captured help and command readers | View-scoped shell memory; the tool catalog is released when its `compozsh` call or Draft inspector Tools view returns | Tool catalog: every loaded public add-on function name (no count cap), whether it has a same-source companion, and its sanitized file label under `.zsh.addons` (private peers included), from Zsh's in-memory function metadata. Tool help: at most 64 same-source companions of 32,768 characters each (direct help: only its companion). History inspector: at most 32,768 characters of the selected command, no second history catalog |
| Command composer | Invocation memory; an accepted draft moves to ZLE or the native buffer stack until edited, submitted or discarded | Literal prefill and fields of at most 4,096 characters each, current folder, generated quoted draft; optional local ref capture for Git revisions. No file, clipboard or custom history write |
| Git Change atlas | View-scoped shell memory; released on return | Path-prefix groups, entry-count bars and bookmarks from the captured file list, staged/unstaged distinct. No discovery, bulk content read, saved atlas or new worker |
| Git Tree / All files navigation | Current review's shell memory; released on review exit | Directory prefixes, folder summaries (change states, child areas, captured numstat) and expansion/filter/scope/selection state from the 1,000-entry/256-KiB list; ancestor choices at most 200 rows/262,144 prefix characters, with a partial notice. No discovery, saved preference or new worker |
| Living prompt receipts | Ordinary terminal display and terminal-owned scrollback | A local `HH:MM` timestamp and the exact submitted command in each command receipt, plus status/duration in applicable outcome receipts; Compozsh writes no receipt log, and terminal retention follows the user's terminal settings |
| Terminal title | The terminal's window/tab title, replaced at each prompt, after an in-widget directory change and at each command start; display and retention follow the terminal and any multiplexer | `user@host: <current folder>` (home as `~`) at each prompt and after an in-widget directory change, and while a command runs `user@host: <command word>`: the first lexical word after leading assignments, at most 60 characters. Never an assignment value; the identity alone after an array assignment or when no command word is established. Controls sanitized; written only when standard output is a terminal and `TERM` is not `dumb` |
| Prompt tool descriptions | Current-shell memory; cleared on shell exit or invalidation | At most 64 same-source command/help pairs; up to 262,144 characters of source/definition identity; 240-character summaries and option descriptions from at most 4,096 characters per guide plus the Touch ID subguide. No disk cache |
| Git comparison choices and snapshots | View memory, released on view exit | At most 1,000 refs/256 KiB of names, kinds and object IDs; resolved endpoints, paths and bounded diff snapshots. No saved comparison catalog |
| Git branch picker | Invocation memory; catalog released when `g` returns, details cleared on view exit | Up to 5,000 local branch names / 512 KiB, current branch first, with a partial notice beyond either bound; ordered by current branch and up to 200 checkout reflog entries, then other refnames. Details at most 262,144 characters across 401 refs, 512 per subject, with inspector text built only for the selected branch. No fetch, saved history or background refresh |
| Known remote branch fallback | Invocation memory until `g` returns; tracking configuration and a created local branch persist in the repository only after confirmation | Up to 1,000 remote-tracking ref names and commit IDs / 256 KiB, and 128 remote names / 32 KiB; no remote URLs. No fetch, pull or disk cache |
| Git Working changes refresh transport | One mode-0700 `${TMPDIR:-/tmp}/compozsh-review.*` directory with a mode-0600 FIFO, plus screen-scoped worker/provider processes and shell memory | One framed local status/selected-diff candidate at a time, at most 1 MiB; no log, daemon or persistent review cache |
| Created Git worktrees | Explicitly selected new folder; branch refs and registration in the repository's Git common directory | Created only on `g --worktree` acceptance; persists until explicit Git/workspace removal, which preserves branches, and survives Compozsh uninstall |
| External device captures | Invocation memory; released when `external-device --flash` or `--format` returns | Image and installer paths and stat identities, an optional user-supplied checksum and computed digests, disk identifiers, media names, sizes, protocols and device-tree paths, the filesystem catalog (each `diskutil` property list read straight into memory, at most 1 MiB), and the writer's stage, byte counts and native error text that can name the image or device. Its files are the [external media temporary files](#external-media-temporary-files) |
| Temporary operation captures | `${TMPDIR:-/tmp}` | USB ISO listings, write and in-session verification progress and image mount points ([names and exceptions](#external-media-temporary-files)), bounded Xcode discovery and Build & Run settings output, transient test-result bundles, Xcode skill-export staging (`compozsh-xcode-skills.*`, Apple-authored skill text), Git syntax transport FIFOs (not source files); validated paths removed on normal and handled-error cleanup |
| Simulator run output | Run-scoped shell memory and two pipes beneath the selected Simulator's data/tmp; released at run exit | Stdout/stderr and unified logs of the exact installed executable: tail and frozen snapshots each at most 32 KiB/200 source lines, 8 KiB unfinished line per source; reader state; launch PID, observed identity, executable and data-directory paths. No log file; native log privacy behavior can expose sensitive app values |
| Explicit physical-device app installation and console | The selected device, under Apple's tools and storage policy; a run-scoped local FIFO and shell memory | `devicectl` replaces the app's installed copy, which stays after console exit or failed launch. Monitoring keeps at most 32 KiB/200 source lines plus snapshots via a mode-0600 FIFO in a mode-0700 directory, removed on cleanup. No log file |
| Command line opened in an editor | One mode-0600 file under two hard-linked names, `${TMPPREFIX:-/tmp/zsh}XXXXXX` and the same name plus `.zsh`, written by Zsh's stock `edit-command-line` widget, only on an explicit Ctrl-X Ctrl-E, while `$VISUAL`/`$EDITOR` runs (Zsh writes the draft directly into that file); Zsh removes both names when the editor returns, and an abnormal termination can leave both | The complete draft, including continuation lines, which can hold anything typed on the command line. The editor's own swap, backup, undo or history files follow the editor's settings |
| Exported Apple skills | Detected coding agents' local skill directories | Created only by an explicit `xcode --export-skills` invocation and marked for safe refresh; per-skill staging and backup siblings and their cleanup limits are listed under [Apple skill export](#xcode-capture-run-and-logs) |
| Clipboard values | The clipboard of the machine running Zsh; may outlive the view or run under operating-system/user control | Only explicit Copy writes: a path, branch, current directory, visible website command, bounded Xcode test report, or matching Simulator/device log lines that can hold local paths, diagnostics and sensitive app values. Never read back |

Where a row names shell, view or invocation memory, Compozsh keeps that data in
process memory and pipes and writes no file of it; any file, FIFO or directory
is named in the row. Operating-system paging (encrypted swap, the sleep image)
is outside this guarantee. Captured command output, including Git status
paths, branch and worktree catalogs and USB progress metadata, is split into
fields inside Zsh. Compozsh's own code passes no data through here-strings
(`<<<`), here-documents or `=(...)` substitution, which Zsh 5.9 implements with
temporary files under `${TMPPREFIX:-/tmp/zsh}`; the editor row above is Zsh's
own widget. Process substitution `<(...)` and `>(...)` uses `/dev/fd` pipes on
macOS.

`compozsh --refresh` clears the current shell's in-memory runtime,
manual-summary, help-description, Git-directory and grep-capability caches and
the direct Git behind `/usr/bin/git`, and runs `rehash`. At the next TTY prompt it also requests replacement of eligible
public OS manual cache data for future shells. It neither reloads private
configuration nor updates installed tools or other shell sessions.

The subsections below give, per feature, what is read beyond the table, its
limitations, and where to inspect it. Interaction details that carry no data,
lifetime or privilege consequence live in the linked engineering contracts.
Regression filters are collected in
[Focused regression checks](#focused-regression-checks).

### Appearance and shared screens

**Appearance** reads only `ZSH_COLOR_SCHEME` and the passive `COLORFGBG` hint
and keeps a `light` or `dark` classification (dark when an automatic hint is
absent or invalid). It sends no terminal query, reads no terminal input,
starts no process, and reads no project or private file. Palette defaults and
public overrides live in shell memory; consumers resolve current roles without
separate default palettes, rendering never recreates them, and missing or
non-associative public maps count as unavailable rather than being read as
arithmetic. Completion, printable-stack, help, `grep` and `man` colors follow
terminal capabilities and `NO_COLOR`; manual-page selection contrast uses fixed
indexed-color arithmetic. Reference RGB colors do not establish contrast
for arbitrary terminal profiles. Inspect `.zsh.addons/support/.zsh.appearance`,
`.zsh.addons/support/ui/`, and the `.zsh.output`, `.zsh.editor`,
`.zsh.navigation` and `.zsh.prompt` peers.

**Shared screens.** The `support/ui/` peers own views, input, painting and
screen restoration. Layout, resize, disclosure navigation, rewrapping (with a
bounded source-row map), row spacing, focus expansion and per-paint styles
derive only from captured facts, the current palette and terminal dimensions:
they discover, capture and execute nothing and keep no copy of the user's draft
beyond screen-restoration state. Without an alternate screen, a session keeps
only the display width of each prompt and draft line, measured at entry from
the prompt's % escapes without running its substitutions. The input dock
places the caret through ZLE's PREDISPLAY/POSTDISPLAY, restored by paint,
without putting query text in the
caller's buffer. View state is scoped to the feature callback and the painted
frame to its screen session, released on every exit; secondary menus
and notices scope their own labels and capabilities and return exact action
values; callback names come from trusted feature code, never labels or project
data. Explicit capture and input-idle hooks keep their own limits, final actions
stay feature-owned, and cleanup restores the caller's terminal and editing
state. There is no registry, persistent storage or shared background process; a
feature may use one documented, bounded input-idle child per screen session, as
the Git review transports and the optional resident system-Vim syntax helper do.
See the [full-screen standard](engineering/full-screen.md).

**`support/` and peer laws.** `support/` holds maintained implementations
shipped in both installation modes, loaded by ordinary recursive peer
discovery with no added loader privilege, load phase, storage or enforced
read-only permission; personal customization uses documented settings in the
machine-local initializer. Shared callable files declare one first entry point
with exclusive helpers below it and are classified `pure` (calculation
from supplied inputs with caller-local results), `impure` (external reads,
mutable shared state, writes, process execution) or UI; these names aid review
but sandbox nothing and do not prove arbitrary input safe. The [peer
configuration laws](engineering/architecture.md#peer-configuration-algebra)
describe equivalent configured behavior after loading the same peers under the
same prerequisites; they confer no sandbox or permission to replay effects.
Sourcing changes shell memory, and sourcing `.zshrc` again can rerun the
private initializer. Tests exercise order convergence and re-sourcing; the
website's algebraic model is an illustration, not evidence that arbitrary
add-ons are safe or effect-free.

### Living prompt and Interaction lens

Context and Interaction lens rendering, the Option-I pin toggle, resize and
line-finish transcript repaint derive from the in-memory prompt snapshot and
ZLE buffer using bounded Zsh lexical structure, without evaluation, expansion,
target resolution or execution. They launch no process, read no
provider/project/runtime/Git/filesystem data and write no file; ordinary
`precmd` capture is the boundary that reads the local facts in this inventory.
The one other prompt capture repeats it after an explicit in-widget directory
change: when a Browse, Recents, Search or Draft inspector Files action
(Change directory, Enter linked directory) succeeds, the editor runs the
prompt's same fact capture and title update after screen cleanup and before
repainting, so the prompt never describes the previous folder. It keeps the
draft and records no outcome, receipt or history entry. Like `precmd`, it runs
any `PROMPT_PROJECT_CONTEXT_FUNCTIONS` a private add-on registered, here
inside the line editor; those functions are that add-on's own code.
This covers lens derivation and repaint, not the complete ZLE pre-redraw hook
chain: the independent syntax highlighter keeps bounded filesystem checks for
literal path tokens without evaluating substitutions or globs. READY keeps
captured toolchain facts visible after acceptance and screen clearing, within
display bounds; this extends visibility, not capture scope or lifetime. Row
vocabulary is specified in [the prompt contract](engineering/prompt.md).

- Rows labeled `… TEXT`, including `ENDPOINT TEXT`, are sanitized,
  width-bounded buffer excerpts that do not prove a path, endpoint, query or
  operation exists. Context rows reuse the latest prompt capture. `PIPELINE`
  (`FLOW`/`STAGES`) and `CHAIN` (`FLOW`/`STEPS`/`CONTROL`) summarize literal
  `&&`, `||`, `;` or `&` structure; `COMMENT` uses `COMMENT TEXT` and the
  advisory `likely remain an interactive shell comment`; `REDIRECT` selects
  `OUTPUT TEXT`, `INPUT TEXT`, `DESCRIPTOR TEXT` or `RESOURCE TEXT` from the
  literal operator without opening or validating a target.
- Inferred `ACTION` text uses `likely`, `appears`, or `may`. Help-derived
  `ACTION` text instead names documented intent from the bounded same-source
  help capture. Neither is a prediction, authorization, validation, or
  completed effect.
- `CAUTION` recognizes only selected high-confidence forms: it is
  intentionally incomplete, does not block Return, and its absence is not
  evidence that a command is safe.
- The shipped `g` helper is classified as Git (bare `g`: local branch
  workspace; `g --review`, `g --worktree` and help forms: review, worktree or
  help cues) from literal structure and captured Git context, without calling
  `g` or Git.
- With AUTO_CD and a lone directory, the highlighter shares only the exact
  bounded draft and current-folder key of its existing observation for an
  advisory NAVIGATE cue; it is cleared on the next highlighting pass
  (including skipped passes), is never reused for a changed draft or folder,
  resolves no command, and does not guarantee that the directory remains
  available at Return.
- Leading assignment values are never copied into lens state, although their
  names may help describe the command, avoiding a second display of a
  potentially sensitive value; the value stays in the real buffer and can enter
  the transcript, process arguments and history if accepted. A `SUGGESTION` row
  reuses only a bounded visible prefix of editor-owned autosuggestion state
  matching the exact buffer, with no history search or unseen tail.

Dynamic prompt text has controls sanitized and prompt syntax escaped: `%`
always; backslash, `$` and backticks under `PROMPT_SUBST`; `!` preserved under
`PROMPT_BANG`. This prevents prompt evaluation or rewriting without changing
the real buffer. The shared display sanitizer replaces C0 controls, DEL and C1
controls (U+0080–U+009F, such as CSI and ST) with `?` in every shell locale,
including C and US-ASCII, where it matches a C1 control by its two-byte UTF-8
encoding. A stray 0x80–0x9F byte outside a UTF-8 sequence can remain; Compozsh
relies on the Unicode terminal it requires to decode that byte as invalid
UTF-8, not as a control. The public project-segment extension accepts only a
`0`–`255` color index or a fixed basic Zsh color name; an invalid color falls
back through the validated `tool` role or native text before reaching prompt
syntax.

A transcript repaint changes only decoration; ZLE keeps the exact submitted
command, and Compozsh keeps no separate command store. Empty and
whitespace-only submissions receive the same receipt without changing their
literal buffer, executing an extra command or adding history. The `LAST` row is
replaceable shell-memory status for the latest command, including fast
success. Command receipts, plus outcome receipts for failures and slow
successes, become terminal display and terminal-owned scrollback; compaction
neither conceals nor removes submitted command text from the terminal or Zsh
history (see [Secrets on the command line](#secrets-on-the-command-line)).

The [terminal title](#complete-local-data-inventory) is another
terminal-owned display. At command start, `.zsh.prompt`'s `preexec` hook lexes
at most 512 characters of the accepted command without evaluation or expansion
and titles only the first word after leading assignments, so it never shows an
assignment value. After an array assignment, without a command word, or
without the shared assignment predicate it shows `user@host` alone. The command
word itself appears unredacted, so the title is not a redaction boundary
either. Check it with `zsh tests/run.zsh 'running-command title'`.

### Help workspace and tool descriptions

**Help workspace.** Owned `--help` modes (calling their fixed same-source
companion) and exact `compozsh help command` requests (resolving the
loaded-function metadata catalog) open a workspace when terminal I/O and the
alternate screen are available. One native pipe captures at most 32,768
characters plus lookahead before interactive input, disclosing truncation; it
reads no project, skill directory, operational tool or private configuration
and launches no pager. At most 128 derived topics plus Complete guide (which
keeps unclassified text within the same limit) hold usage, description, sections
and literal argument explanations in invocation memory.
Navigation, filtering, scrolling and resize call no provider; topic IDs never
become arguments, and prose examples are never executed, inserted or copied.
Pipes, redirects, `NO_COLOR`, absent UI/help peers and unsupported terminals
get complete printable help. Accents derive at most 128 spans per sanitized
line from literal documentation structure; draft and log readers do not opt
in. The separate **Compose example** action appears
only with explicit command identity and a `_compozsh_template_<command>`
capability from the same source as the command and its help companion
(currently `g` and `mkcd`); providers are trusted source-owned code returning
fixed recipe IDs, never discovered from files or help prose, and the action
opens the [command composer](#draft-inspector-and-command-composer). Other help
paths stay inert. Inspect `.zsh.addons/.zsh.help` and the public help
branches.

**Prompt tool descriptions** are captured only at a TTY `precmd` from loaded
function/source metadata, without filesystem discovery, by calling matching
same-source `_compozsh_help_<command>` companions; a public command is never
invoked with `--help`. Each definition is capped at 65,536 characters. The pipe
reads one character past its 4,096-character guide bound and discards an
incomplete final line; control-bearing or overlong descriptions are omitted.
Changed or removed definitions and `compozsh --refresh` invalidate the
help-description snapshots; identity data stays in shell memory and is never
written. In both help paths, companions are trusted static documentation
providers under the add-on contract: output bounds neither sandbox a
misbehaving machine-local companion nor impose a wall-clock limit.

**Edit-time descriptions and alias previews** read only those snapshots, current
definition identity and bounded alias definitions. They name documented
tool/option intent, not target resolution or argument validation; compound and
danger cues take priority, and stock alias descriptions require the exact
current definition. Ordinary, global and suffix aliases preview at literal
command positions, including pipelines, chains and after leading assignments;
global aliases also match literal arguments and redirection targets, and a
trailing-space alias enables the next word's preview. Within 512 draft
characters and 64 lexical tokens, at most eight definitions are retained, each
capped at 240 characters with an omission marker. Quoting, escaping and native
alias suppression are respected; here-document operators stop inspection, and
nested substitutions are not inspected. Definitions are never evaluated,
recursively expanded or cached separately. Previews are sanitized,
prompt-escaped and width-fitted; they can show sensitive text already in an
alias to someone viewing the terminal and are not credential redaction.

### Draft inspector and command composer

**Draft inspector.** Option-Return opens it explicitly. Unlike passive prompt
disclosure, its Read action can show the literal draft, including leading
assignment values; no token is evaluated, expanded, resolved or executed, and
the full draft stays in native editing/screen-restoration state. Help discovery
and read-only Git capture happen only after their named choices; Git uses the
displayed current folder and ignores draft flags and paths. Files and History
receive ownership only after the inspector closes. Only explicitly accepted
insertion replaces the draft (History inserts the original full command);
cancellation and read-only return preserve the original command and cursor.

**Command composer.** Simple prefill is never expanded or evaluated;
unsupported or complex drafts keep the ordinary inspector. A pure builder
applies native Zsh quoting to literal fields around fixed command/option
tokens; preview and filtering perform no external reads. Fields are displayed
literally and can contain sensitive values, so this is not a secret-entry or
redaction mechanism. A Git endpoint field may explicitly acquire the current
folder's repository and safe local refs through the review providers, within
the same 1,000-ref/256-KiB bounds; only the submitted endpoint is validated,
and a pinned local commit ID is returned. No
network, checkout, whole-draft validation or command execution occurs; without
ref browsing, literal entry remains possible without promising a valid
revision. Only **Replace draft** exports: it verifies that the current folder
still matches the displayed scope, unwinds the screen, and inserts via ZLE
`BUFFER` or `print -zr` into the native buffer stack for the user to submit. It
adds no clipboard, file or history write; normal acceptance can record the
submitted command as usual. The editor's leading-space prefix is carried over,
so composition does not silently remove a `HIST_IGNORE_SPACE` preference.
Escape exports nothing and restores the original cursor and bookmarks.
Inspect `.zsh.addons/.zsh.compose`, the same-source
template companions in navigation and tools, and the editor/help handoffs.

### Runtime and project context

The runtime functions in `.zsh.addons/support/functions/` run only at the
prompt's fact capture (`precmd`, or after an in-widget directory change).
Loading them defines functions and shell-memory data only: it inspects no
project, probes no executable, installs no toolchain and registers no
background task. Numeric comparison consumes supplied strings, separately
from metadata observation. README's **Project and runtime context** section
documents the sources and precedence. Besides simple
version files and `.tool-versions`, readers recognize literal Rust toolchain
TOML, Go `go.work`/`go.mod` minima, Swift's first-line tools minimum, Cargo's
package Rust minimum and Python's project version range. No manifest is sourced,
evaluated, passed to a package manager or used to install or activate software.

Metadata paths must resolve inside the detected project, be regular files, not
be leaf symlinks, and pass a 1 MiB eligibility size check. Non-following/
nonblocking opens, descriptor type validation and mode-specific byte budgets
also reject leaf replacement with symlinks/FIFOs and bound reads of a growing
file. Simple selection files and Swift's tools declaration need a complete first
line (newline or observed EOF) within a 4 KiB read budget. TOML and multi-entry
sources use a 64 KiB read/parse budget (at most one extra byte to detect
growth), 256 lines and 4 KiB per line, rejecting excess work before interpreting
declarations. An incomplete first line, a source over a parsing budget, a
selector over the 240-character display cap (displayed requirements are
prompt-sanitized and escaped), an ambiguous value or unsupported syntax is
unverified, not inferred compatible. A file rejected by the initial path/type/1
MiB check is skipped and a later eligible source may supply a requirement; this
neither validates the skipped source nor establishes compatibility with all
project requirements. These checks are not an atomic snapshot of a concurrently
changing tree. Captured text stays in invocation memory; the installed-version
cache is shell memory, refreshable with `compozsh --refresh`, and disappears
with the shell. Missing runtime support leaves project identity/tool markers.
Without Apple's developer tools, a runtime whose probe would run one of
Apple's `/usr/bin` launchers shows as `not-installed` and runs nothing
([missing developer tools](#local-only-git-controls)). On macOS,
`/usr/bin/java` is Apple's stub for an installed JDK; without one it fails and
may offer to install one. When the Java probe would run it (found on `PATH`,
directly or through a link), the prompt first looks, with file tests only,
for a runtime the stub could start: an exported absolute `JAVA_HOME` that
holds an executable `bin/java`, any visible entry in
`/Library/Java/JavaVirtualMachines` or
`$HOME/Library/Java/JavaVirtualMachines`, or
`/Library/Internet Plug-Ins/JavaAppletPlugin.plugin`. With none, Java shows as
`not-installed`, nothing runs and the answer is never remembered, so the next
prompt after an install probes it. Without running anything,
`ls /Library/Java/JavaVirtualMachines ~/Library/Java/JavaVirtualMachines '/Library/Internet Plug-Ins/JavaAppletPlugin.plugin'`
shows what counts: an entry listed under either folder, or an existing
plug-in, means the prompt runs the stub, as does such a `JAVA_HOME` (inspect
`_prompt_runtime_java_present` in
`.zsh.addons/support/functions/.zsh.impure.prompt_runtime_version`).
Probing installed runtimes is an [external
boundary](#independently-controlled-network-capable-software). Inspect without
executing: `git grep -n . HEAD -- .zsh.addons/support/functions/`.

### Local manual summaries

The optional `.zsh.manual` peer captures local manual NAME descriptions once,
in the background, at the first TTY `precmd`; source time captures nothing and
the editor does not wait. [The producer contract](engineering/manual-cache.md)
specifies the mechanics.

- **Sources.** Literal MANPATH, relative entries resolved at capture (without
  empty fields it skips default and configuration discovery; empty fields insert
  defaults); conventions for the first 128 absolute PATH entries and documented
  fallbacks; literal MANPATH/MANCONFIG directives in `/etc/man.conf` and at most
  16 selected configuration files, 8 KiB each, never evaluated, formatter
  settings and other directives ignored; and at most 16 absolute, control-free
  SDK/platform/developer/toolchain roots of at most 4,096 characters from one
  fixed `/usr/bin/xcode-select --show-manpaths` query, which honors
  `DEVELOPER_DIR` and is validated against 64 KiB (conventional roots remain
  without it). At most 64 deduplicated roots and 16 validated `MANSECT` entries
  apply. Capture can read manuals in user-selected project folders, but not
  private shell peers, the initializer or history.
- **Bounds.** At most 4,096 entries, 64 KiB per page, and 8,192 retained
  name/summary pairs of 240 characters. Symlinks and whole-page `.so` aliases
  can reach installed manuals outside a root, with at most eight reads per
  chain, through non-following/nonblocking opens and regular-descriptor checks
  (not an ancestor-race sandbox). Fixed native gzip and, for formatting-heavy
  NAME sections, fixed native mandoc on captured stdin each process at most
  64 KiB in and out under a one-second child CPU limit, not a wall-clock
  deadline. mandoc ignores command/file-writing requests and refuses
  absolute/parent includes, and its private empty working directory blocks
  relative includes of the caller's folder; this is native formatting, not an
  OS sandbox. Corrupt, unreadable or unresolved pages fail
  quietly; pages without usable NAME text keep a
  manual-available notice. No `man`, `manpath`, `whatis`, index generator or
  documented command runs, and no manual text becomes shell code.
- **Use.** ABOUT text is inert, prompt-escaped and describes a literal name,
  not executable identity or argument effects; aliases and functions do not
  inherit it. Typing and resizing consult only the snapshot
  and loaded metadata; bounded descriptor callbacks may merge a completed
  candidate without discovery or cache I/O. Custom, third-party and developer
  manuals never persist; only eligible OS descriptions use the [public
  cache](#public-system-performance-cache).
- **Transport.** The bounded request identity (PATH, MANPATH, MANSECT, locale,
  developer selectors, configuration base, source generation, and PWD only for
  relative roots) stays in memory; neither selectors nor fingerprints are
  saved. A candidate replaces the visible map only if generation and identity
  still match, framing, schema, count, every record and END validate, the
  worker succeeded and no bytes trail; failed or obsolete candidates never
  partially apply. Each callback reads at most 8 KiB.
- **Ownership.** Two native Zsh supervisors isolate the ordered capture process
  and its descendants from the user's job table, coprocess and event handlers;
  only fixed function names become `zpty` commands. Refresh, re-source,
  selector change, pre-execution cancellation and shell exit release them. A
  30-second deadline stops collection; cancellation allows 100 ms of cleanup,
  then terminates the owned group. After a deadline an idle outer owner keeps
  its identity, without collecting or polling, until the parent handles the
  failure; it is not a daemon. Another same-account process can still kill or
  alter supervisors. Without async support capture is synchronous; failures
  use the ordinary fallback with no retry loop until explicit refresh.
- **Residue.** Uncatchable interruption can leave an empty setup
  directory/FIFO, the empty formatter directory or a public cache staging file;
  no transport document body is ever a regular file.

### Public system performance cache

All Compozsh performance caches use the configuration base's
`.zsh.addons/support/cache/` (following `${ZDOTDIR:-$HOME}`, never the project
or the source peer's symlink target). The sole producer, `.zsh.manual`, writes
`.zsh.manual.cache`, an empty `.zsh.manual.lock` and temporary
`.zsh.manual.cache.*` files. No private, user or project facts or their
fingerprints belong there; history, the [native completion
dump](#native-completion-dump) and recovery storage stay separate. Format,
locking and digest mechanics are in [the
producer contract](engineering/manual-cache.md).

- **Eligibility.** Only discovered `/usr/share/man` pages whose whole resolved
  symlink/`.so` forwarding chain stays in that OS tree, on root-owned regular
  descriptors without group/world write. This relies on Apple's protected
  system tree; ownership or a conventional path elsewhere is insufficient.
  Persistence also requires macOS and readable fixed OS-version metadata;
  other platforms stay uncached.
- **Contents.** Only relative system page IDs, NAME aliases, descriptions and
  a format/version key; never page bodies, custom documentation, discovery
  paths, selectors or negative lookups. The inert format is bounded (4,096
  records, 32 MiB; page IDs up to 512 characters, descriptions up to 240, at
  most 16 aliases of 255 characters) and rejected before loading on controls,
  NUL, truncation,
  duplicates or malformed fields. It is never sourced or evaluated, bootstrap
  discovery excludes the directory, and valid owner-controlled prose is still
  untrusted advisory text, not executable identity, authorization or a target.
- **Freshness.** The key is a `/usr/bin/shasum` digest, run in an empty
  environment with a fixed PATH, of the owning implementation code, Zsh
  version, an accepted installed locale and fixed OS-version-file metadata; it
  detects identity changes but does not authenticate data. Capture still
  discovers pages: removed pages disappear, new eligible pages extend the
  cache, other documents stay memory-only, and unknown commands cause no
  edit-time reads. In-place OS manual edits without an OS-version-file change
  need `compozsh --refresh`, which requests fresh capture at the next TTY
  prompt and replaces eligible results for future shells; refresh also
  invalidates the help-description snapshot with the other in-memory caches.
  Other open shells keep their snapshots until refreshed.
- **Storage safety.** Ownership and POSIX modes without group/world write are
  validated from the resolved configuration base through add-ons/support/cache;
  directories are owner-only, and files must be regular, owner-only, singly
  linked and not symlinks, checked with non-following/nonblocking opens and
  descriptor checks. Extended ACLs are not inspected or removed, so these
  checks neither authenticate the cache nor establish exclusive access under a
  custom ACL, and they do not sandbox another process controlling the account
  or ancestor replacement above the configuration base. Unsafe state
  is refused, not repaired; missing, stale, corrupt or unwritable storage keeps
  full uncached features.
- **Publication and residue.** Same-directory atomic rename publishes complete
  snapshots under a time-bounded kernel advisory lock; lock failure falls back
  to uncached capture. The empty lock file can remain, and an uncatchable kill
  can leave owner-only staging residue (handled failures remove it). The
  snapshot persists until removal, refresh or replacement, and removed public
  records may remain within its bound until replacement.
- **Removal.** Deleting the cache directory removes every module's cache and
  residue; later eligible capture recreates it. Git ignores generated caches.
  Installers exclude source caches, preserve destination caches on normal
  updates and archive them with the old add-on tree on `--clean`; uninstalling
  that tree removes active caches, while recovery archives keep their own
  retention. User-selected synchronized or network-mounted configuration
  storage is an [external boundary](#external-synchronization); Compozsh adds
  no cache service.

Independently read `.zsh.manual`'s eligibility, key, load/store and capture
helpers, `.zshrc`'s cache exclusion and `install.zsh`'s staging exclusion. Its
fixtures exercise inert data, private-input exclusion, freshness, failures and
concurrency.

### Native completion dump

`.zsh.editor` runs Zsh's stock `compinit` once per fresh shell; re-sourcing
skips it while `_comps` exists, and if the initializer or an earlier private
peer already ran `compinit`, that call owns the dump instead. Without `-C`,
`-i`, `-u` or `-D`, `compinit` keeps its full `compaudit` ownership and
permission check of `fpath` (an interactive prompt can exclude insecure
entries or abort). Its dump is `${ZDOTDIR:-$HOME}/.zcompdump`, resolved when it
runs and with no Zsh-version suffix; `compinit` gets `-d` only for the compiled
copy below, and `_comp_dumpfile` names that usual path afterwards either way.
Compozsh adds no `fpath` entry and leaves completion's `use-cache` style off
(so it writes no `.zcompcache`).

- **Contents.** A `#files: <count>` and `version: <zsh>` header; the
  `_comps`, `_services`, `_patcomps`, `_postpatcomps`, `_compautos` and
  `_comp_assocs` tables; `zle -C` and `bindkey` lines for every
  underscore-named completion widget that exists when `compinit` runs
  (including any the initializer or an earlier private peer defined), with
  `zmodload -i zsh/complist` when one needs it; and `autoload -Uz` lines.
  `compinit` reads only the first line of each `fpath` completion file and
  copies its words verbatim. Normally they are function, command, service,
  pattern and key names, and names from private `fpath` entries (for example
  Homebrew's site-functions or a personal directory) are recorded too; a
  private file that declares a command by path records that path, and the
  rest of an `#autoload` line becomes dump code, so text in `fpath` files is
  trusted like their function bodies. The dump holds no `fpath` directory
  paths, file bodies, history, environment values, host name or project data.
- **Rewrite and lifetime.** On a fresh shell, `compinit` sources the dump as
  shell code when its header matches the current `fpath` scan and Zsh version,
  and rewrites it only when it is missing or either differs; editing a
  completion file without changing the count keeps the old dump until it is
  deleted. The file persists across shells, installs, `--clean` and uninstall,
  and `compozsh --refresh` does not touch it. Deleting it loses nothing: the
  next fresh shell that runs `compinit` regenerates it, at the cost of one full
  `fpath` scan.
- **Mode and residue.** Zsh's `compdump` writes `.zcompdump.<host>.<pid>` in the
  same directory and renames it into place, so each rewrite applies the shell's
  umask at that moment (0644 under macOS's default 022, 0600 under 077);
  Compozsh neither tightens nor checks the mode. Stock `compdump` installs no
  cleanup, so any interruption between that write and the rename (for example
  Ctrl-C while a first shell starts) can leave the staging file, whose name
  carries the host name and process ID. An unwritable configuration base skips
  the dump, and completion still works from the scan.
- **Trust.** `compaudit` checks `fpath` directories and files, not the dump.
  It sits in the configuration base beside the bootstrap, never in the current
  directory or a project, so an account that can replace it can already
  replace `.zshrc`. Editing it in place depends on its own umask-derived mode:
  with group or other write, other accounts that can reach the configuration
  base could change code `compinit` sources, so keep a umask without group or
  other write (the macOS default 022 qualifies). Zsh's `.` would load a
  `.zcompdump.zwc` no older than the dump if another tool created one;
  Compozsh never creates one.
- **Compiled copy.** After `compinit`, a dump that is a regular file with no
  fresh record is compiled by `.zsh.addons/support/compile.zsh` in Apple's
  `/bin/zsh -f` from `/` (the same rules, lock, atomic renames and fallbacks as the
  [compiled peer mirror](#compiled-peer-mirror); a dump written in the current
  second waits for the next shell) into `zcompdump.zwc` beside `zcompdump`, a
  symlink to the dump, with a `zcompdump.manifest` holding only the header,
  parse context and the dump's identity. `compinit` is then given that symlink
  as `-d`, so Zsh's `.` reads the wordcode, only while the mirror passes the
  peer checks, the manifest names the running Zsh and this dump, the dump's
  device, inode, size, mtime and ctime equal the record, and the parse context
  `compinit` sources it in (its own `emulate -L zsh`, then the alias tables)
  equals the compiling shell's; any other case loads the text dump, and a dump
  over 512 KiB or one that fails to compile stays text until it changes. The
  header check and `fpath` scan are unchanged: when they differ, `compinit`
  rewrites its dump at the symlink's path, and `.zsh.editor` has the same
  script rename that new dump onto `${ZDOTDIR:-$HOME}/.zcompdump` at once (or
  delete it if the rename fails, so the next shell rewrites the dump itself).
  Its staging file `zcompdump.<host>.<pid>` left by an interruption is deleted
  by a later compile once a minute old.

Independently read the call and Zsh's own implementation:

```sh
git grep -n -e compinit -e compdump -e zcompile -e fpath -e use-cache \
  -e cache-path -- .zshrc install.zsh templates '.zsh.addons/**'
zsh -fc 'print -rl -- ${^fpath}/(compinit|compaudit|compdump)(N)'
ls -l "${ZDOTDIR:-$HOME}/.zcompdump"
```

The first command should list only `.zsh.editor`'s `autoload -Uz compinit`
line, its `compinit -d` call for the compiled copy and bare `compinit` call
with their comments and its `_zle_compdump_state` and `_zle_compdump_compile`
helpers, the two commented `fpath` lines in `templates/init.zsh` and
`.zsh.addons/support/compile.zsh`'s `zcompile` of shipped peers and the dump
into their [mirror](#compiled-peer-mirror) with its `zcompdump` names and
comments;
the second prints the stock functions
(on macOS under `/usr/share/zsh/5.9/functions/`) whose `_comp_dumpfile`
default, header check and `compdump` writer establish the facts above. The
third should show your account as owner and no `w` for group or other; if it
shows either, delete the dump and choose a umask without group or other write
before the next shell. These reads cover the call and format, not every
completion function's runtime behavior.

### Pickers, matching and effects

**Matching.** The pure `matching_*` entries under `support/functions/` compile
literal queries (keyword fragments in any order) and filter caller-supplied
captured text into caller-local results. They read no provider, UI state,
filesystem, command metadata or history and create no persistent cache or saved
filter; feature collectors keep their ranking, duplicate policy and capture
limits. Exclusion rejects candidates matching one case-insensitive literal
phrase before result limits, without reading file contents. Query punctuation is
literal, operators are never evaluated, and decimal result limits are checked
before arithmetic. Both fields and their bookmarks are view-local. Refinement
performs no discovery; exclusion-only filesystem/Git capture requires explicit
submission and keeps the source bounds. Spotlight requires positive filename
text and never falls back to a walk. Missing matching support selects
native/plain fallbacks. In pickers, plain digits always edit a filter, including
its first character; acceptance requires Enter or an explicit shortcut, and
Option/Meta-digit shortcuts apply only a visible slot with both filters empty.

**Effects.** The `compozsh_effect_*` entries own explicit clipboard writes and
file Open/Reveal. Each receives the exact caller-selected value and captured
executable path, checks executable availability, and rechecks an absolute file
target before opening it. Clipboard payloads go to standard input literally,
without an added newline; the helper reads no clipboard and keeps no payload
after return. UI and result-model code never calls effects; callers dispatch
only after screen cleanup, or directly for explicit commands such as `cpdir`.
Without an effect entry, its workspace capability is omitted and direct
requests fail safely. Loading and re-sourcing invoke no command and need no
peer order.

**Path + Tab** captures immediate directory entries for a lone path or an
explicit directory argument such as `vim ~/Developer`. The command prefix stays
in invocation memory; insertion replaces that argument after screen cleanup
without executing the command, and Escape and Copy preserve the draft. Browsing
reads entry names and file-type metadata, never contents, and releases snapshots
and prefix on return. Quoted or escaped leading tildes, including lone
command-position paths, delegate to native completion, so quote removal cannot
redirect a literal path to HOME. Inspect `.zsh.addons/.zsh.editor`.

### Bracketed paste

Once a bracketed-paste opening prefix is recognized, the shared picker keeps
input ownership through the closing marker. A stalled or oversized paste is
discarded in the existing screen, keeping only a bounded marker suffix during
recovery; Enter, cancellation bytes and handled SIGINT cannot release a delayed
payload into the command buffer. The modal screen owns SIGINT abort through
terminal cleanup and restores prior function, static or ignored handlers on
return; recovery temporarily intercepts SIGINT in that scope while resize
handling stays active. If the terminal omits the closing marker, the recovery
screen tells the user to press Escape and type `[201~`, after which normal
cancellation resumes; a closed input stream exits recovery without a busy retry
loop. The ordinary short Escape-key window applies before a paste prefix is
recognized, and complete non-paste CSI keys consume a bounded suffix (at most 32
characters after `ESC [ 2`) without entering recovery. Recovery also pauses
enclosing Git result consumption and live log draining; retained data stays
bounded, and a timed-out Git check is reported when normal input resumes. See
[Keyboard and ZLE](engineering/keyboard-zle.md).

### Job lifecycle

The optional syntax helper uses a private system-Vim child and mode-600 FIFOs
inside a mode-700 temporary directory. Captured source travels through those
pipes, not regular temporary source files. On timeout or screen exit, cleanup
closes descriptors, kills and reaps the owned child when still live, retires its
completed shell-job record, and removes the transport paths. It does not signal
unrelated running or suspended jobs or detach a live helper.

The Git Working changes auto-refresh worker is reaped the same way. A worker
that has published its result or exited is reaped without a signal. Pause,
manual refresh, timeout, an invalid or oversized response and screen exit send
`TERM` only while its job is running or suspended; the worker then kills and
reaps its own Git provider before exiting. Either way the parent retires only
the worker's completed job record.

Xcode reaps its discovery supervisor, Run log observer, device console and LLDB
output drainer the same way once its own ownership-checked stop has ended the
child: each reap leaves unrelated completion records in place and retires only
that child's completed job record.

Zsh 5.9's `wait` and `jobs` builtins scan prior completed records when `NOTIFY`
is off, even with an exact operand. These cleanups therefore share one narrowly
scoped `MONITOR`-off, `NOTIFY`-on section and restore caller options afterward.
This avoids that broad scan and keeps already-pending unrelated completion
records.
**Limitation:** an unrelated job that newly finishes during this short section
can still have its completion notification retired by native Zsh handling;
preserving every concurrent notification is not guaranteed. See the [native
implementation](https://github.com/zsh-users/zsh/blob/zsh-5.9/Src/jobs.c).

Prompt capture only reads native job states: running and suspended jobs count;
completed records do not. It never lists, waits for, or acknowledges jobs to
update the indicator. `jobs -l` can report a previously killed process and
acknowledge that completed record; listing it does not kill the process.

Xcode device console polling recognizes suspended jobs without blocking on
them, and cleanup preserves failures after resuming a stopped child. If Zsh
cannot distinguish an exit status of 127 from a missing cached status after
suspension, cleanup conservatively keeps the earlier nonzero stop status.
Manual capture supervisors are stopped and reaped as their section describes.

### Git review and branches

**File review.** All files, Tree, Jump to ancestor and the Change atlas derive
every view, folder summary, count and filter result from the captured Git list
and existing commit/comparison numstat facts (summaries for retained result rows
only), including deleted prefixes and distinct staged/unstaged entries.
Navigation, folding, scope changes and filtering (including hidden descendants)
perform no provider read or directory enumeration, and folders request no diff
or syntax data. Opening a file uses the bounded diff providers and safety
checks, including the failed-preparation block on uncached reads. Filtered or
partial coverage, scope and refresh limits stay visible. Wrapped path displays
are presentation, with no redaction guarantee or clipboard action. Refresh
reconciles navigation with the new list, keeps the file bookmark as its target,
and invalidates bookmarks whose numeric identities belonged to the old list. The
atlas keeps the original numeric file/change-kind identities and
commit/comparison IDs, stops pending Working changes refresh work until return,
and its nested Back returns to the previous filter/selection and review
position. Working files may change after capture; no view promises an atomic
snapshot. See [Git workspaces](engineering/workspaces/git.md).

**Confirmations.** Action cards, their captured target/plan columns and Xcode
configuration-return bookmarks add no provider or execution boundary.
`g --discard-all` prints complete captured status before confirmation and may
add a scoped native confirmation screen with at most 32,768 status characters
in its inspector. Only literal `y` or `Y` confirms; empty Return and
cancellation refuse. Screen restoration precedes the revalidation and writes
described under [Local-only Git controls](#local-only-git-controls); plain and
missing-UI confirmation remains. No new privilege, network path, persistence,
automatic action or rollback claim is introduced.

**Branches.** The local catalog includes names absent from the bounded checkout
reflog. It is one bounded read; beyond its bounds the picker labels itself
partial, filtering covers captured branches only, and the remote fallback
stays off because a partial catalog cannot show that a name is not already a
local branch. Opening the `g` branch picker also reads `git remote` names and
`for-each-ref refs/remotes/` once, before the first filter, through the same
local-only provider controls, so filtering never calls Git; those refs are
offered only when nothing local matches, and every later filter reuses that
snapshot.
These are locally known remote-tracking refs, not a server result or freshness
guarantee: a missing branch requires an explicit user-run `g fetch <remote>`
before reopening `g`, and typing, selection, confirmation and creation never
fetch. Confirmation shows the exact source and new local branch and defaults to
Back. After terminal cleanup, a non-forcing
`git switch --track=direct --create` revalidates
the selected ref's locally available commit and refuses a moved or deleted tip
or an existing local branch, with transport, lazy fetching and submodule
recursion disabled. As with any explicit Git switch, configured checkout
filters and post-checkout hooks remain external programs with their own effects
and network behavior, unsandboxed by this workflow. Git can fail after partial
checkout work; inspect its diagnostic and the repository before retrying, as no
automatic rollback or cleanup is attempted.

### Git worktrees

**Reads.** The workspace reads local refs, commit IDs, registered paths and
flags, directory identities, and explicitly browsed parent-folder names.
Removal also reads operation markers, tracked-tree modes, index flags and
status including ignored and untracked names (Git may read working file
contents for status); creation reads the selected committed tree to check for
submodules; moving reads operation markers and committed-tree modes and
validates source/destination directory identities without scanning contents.
Captures stay in invocation memory, bounded to 256 KiB each and 1,000
worktrees, branches or child folders per catalog; failed or oversized safety
captures refuse the action. The committed-tree mode and index-flag checks,
whose listings grow with the repository, instead stream Git's NUL-terminated
output through a pipe in 64-KiB chunks, holding at most one chunk and one
partial record, and keep only whether a submodule or a non-ordinary index
entry appears, so repository size alone never refuses them; a Git failure, or
an empty, unterminated or longer-than-one-chunk record, still refuses.
Compozsh writes no worktree catalog or navigation history. Git may take longer
than these output bounds suggest on slow storage.

**Git policy.** Every workspace Git call disables transport, lazy fetch, hooks,
fsmonitor, automatic maintenance, optional index writes and submodule
recursion, and explicit roots override inherited Git
directory/index/object/namespace selectors. Entering a worktree changes this
shell's directory and can run independently owned user `chpwd` hooks.

**Create** writes the chosen new folder and native Git refs/registration; the
installed Git and the user's umask govern checkout ownership and modes.
`git rev-parse --path-format=absolute --git-common-dir` resolves the metadata
base: registrations live under its `worktrees/<id>` directory, and branches in
the repository's native reference storage. No ignored/private files are copied
from another checkout and no access controls change. Configured
clean/smudge/process filters or required-filter settings, including globally
configured Git LFS even where a checkout might not use it, are refused rather
than invoked or disabled; submodule checkouts are refused. Creation runs
`worktree add --no-checkout`, rechecks effective configuration in the new
branch/directory (covering conditional includes absent from the source), then
populates the complete committed tree with a non-forcing
`read-tree -m -u --no-sparse-checkout`. Refusal at that stage leaves the branch
and registered empty folder for inspection; no filter runs.

**Move / rename** calls native `git worktree move` after review of the exact
source and destination; tracked edits, untracked and ignored files travel with
the folder, its registration is updated and the branch is kept. The destination
must be absent and on the same filesystem; main/current, locked, missing,
in-progress and submodule checkouts are refused. Moving runs no checkout or
filter, copies no file, changes no privilege and leaves the shell's directory
unchanged.

**Remove** deletes only the confirmed registered linked checkout and keeps its
branch. It refuses main/current, locked, missing or detached worktrees,
in-progress operations, changes, untracked or ignored files, submodules,
sparse/unmerged indexes and assume-unchanged flags. The removal chooser filters
the captured catalog and reads file status only for the selected target, sharing
confirmation and validation with selected-worktree options. Repository and
directory identities, branch/commit and safety checks are revalidated after
screen restoration. No force, branch deletion, automatic stash, recursive shell
deletion or rollback is used; there is no Undo.

**Limitations.** Validation followed by Git is not an atomic filesystem
transaction: concurrent writers or path replacement can change a move or
removal outcome, so stop other writers first. Git errors keep their status. A
failed move can leave location and registration partially updated; an
interrupted or failed creation can leave a branch, registration or partial
folder. Inspect `git worktree list`, `git branch` and the exact paths before
retrying; Compozsh performs no automatic rollback or residue deletion. A failed
directory change after creation preserves the checkout. Removing Compozsh
leaves created worktrees and branches intact.

### Xcode capture, Run and logs

Interaction details are specified in [the Xcode
workspace contract](engineering/workspaces/xcode.md).

**Captures.** Provider stdout keeps at most `ZSH_XCODE_CAPTURE_MAX_BYTES`
(262,144 by default, minimum 4,096; the Build & Run settings capture keeps
5,242,880 bytes when that limit is smaller, as under Run targets) and
diagnostics at most 8,192 bytes, enforced while the command runs, including
bytes in temporary files; readers hold one 8-KiB chunk while discarding
excess. Two-byte completion records identify finished synchronous streams;
incomplete captures and stdout overflow are rejected unparsed. Streams stay
separate, the native status is kept within the limit, and byte bounds impose
no duration limit. Cleanup removes the private capture directory. **Scheme and destination discovery** streams through three
mode-0600 FIFOs in a mode-0700 directory into the same budgets, writing only an
atomically published exit-status record of at most four bytes. After exit,
queued output is consumed without waiting for inherited writers, and at most
eight 8-KiB chunks per stream per poll keep a busy provider from monopolizing
input. A supervisor keeps the provider group's identity until cleanup; owned
child state is checked before signaling the group, the supervisor is then
reaped, and completion, Escape and Ctrl-C remove the FIFOs and record. Discovery reads no terminal stdin and never starts during paint or
resize; its loading label is view-scoped, and later captures keep their own
status and cancellation guidance. Snapshots and selections stay bounded to four
schemes in the open workspace; canceled or removed destinations never become
implicit selections.

**Tests.** Test and Rebuild & Test use a transient result bundle with verbose
test diagnostics disabled; Xcode can still store test-authored attachments and
logs there. Compozsh reads only size-bounded summary/detail JSON and source
locations, never attachments or source files, rejects a symlinked bundle, and
deletes the whole bundle before showing results. An uncatchable termination can
leave it under the identifiable `compozsh-xcode-test.*` temporary directory.

**Run targets.** Build & Run and Rebuild & Run keep the captured destination's
platform, device ID, architecture and variant. Build settings are bounded to 100
targets and 5,242,880 bytes (about 100 targets at Xcode's roughly 42 KiB each),
or `ZSH_XCODE_CAPTURE_MAX_BYTES` when larger; up to that many bytes sit in the
private capture files while the command runs and in invocation memory until
product resolution returns, and a larger capture fails unparsed with guidance
naming the bound. Product paths and validated bundle identifiers stay in
invocation memory. Several qualifying products require an explicit choice, no
filesystem search infers one, and a symlink leaf or vanished product is
rejected before handoff, not atomically. A Mac app opens as a new instance
through native `open`, with the chosen architecture and no process monitor; a
command-line product runs in the restored terminal with native output and
status. App code has its own access and network behavior.

**Physical devices.** `devicectl` receives the selected app and device ID and
reaches that device over its configured wired or wireless connection, an
independent tool boundary like explicit Git transport. Installation replaces the
installed copy and launch replaces the running instance, with the captured
architecture. Compozsh adds no network client, endpoint, broad device scan,
automatic connection policy, provisioning update or device log file;
pairing/trust, Developer Mode, signing and provisioning stay with Xcode and the
user. A failed build or installation prevents launch; a failed launch does not
undo installation. `--console` owns stdout, waiting and catchable signal
forwarding. Monitoring sends the owned child's output to a private FIFO and the
bounded reader without bridging stdin; plain fallback keeps the native console
and scrollback. Stop restores the screen, signals the still-owned child, drains
for at most one second, then forces exit with a notice to check the device; a
forced console end cannot guarantee that the app stopped. The child is reaped
and its FIFO/directory removed; an uncatchable termination can leave a
`compozsh-xcode-device.*` directory whose FIFO holds no log. Console messages
may contain sensitive app values.

**Simulators.** Run reads only the selected device's `SIMULATOR_ARCHS`,
`SIMULATOR_RUNTIME_VERSION` and `SIMULATOR_SHARED_RESOURCES_DIRECTORY` through
bounded `simctl getenv` captures. A captured architecture is requested at boot
and passed explicitly to runtime 26 and newer; older runtimes must report only
that architecture. Missing, malformed, incompatible or ambiguous output stops
before the viewer, installation or launch, and a running Simulator is never
shut down to change architecture. The data directory must be a normalized
absolute control-free path whose `tmp` child exists, without symlink leaves; a
fresh mode-0700 `data/tmp/compozsh-xcode-run.*` holds two mode-0600 FIFOs that
the app reaches as `/tmp/compozsh-xcode-run.*/output`, a path `simctl`
resolves in the device's data filesystem, and cleanup reuses the
captured host path. `--terminate-running-process` replaces the running bundle
and binds its new process to this run's output FIFO;
`SIMCTL_CHILD_NSUnbufferedIO=YES` is exported only for the launch and the
log-stream spawn, so only the app and its log process get `NSUnbufferedIO=YES`;
the shell, `ps`, LLDB, stopping and log privacy are unaffected. Launch metadata
uses the temporary capture boundary; app output never
serves as a PID or command. `ps` reads the launch-returned PID's user, start
time and executable identity, rechecked before attaching or stopping; this
cannot be atomic against exit or replacement. The window opens through the
explicit Device Hub or Simulator bundle of the Xcode chosen by
`xcode-select --print-path` (honoring `DEVELOPER_DIR`); Device Hub receives a
local `devices:///manage/select` URL with only the validated device ID, so
another app's URL registration cannot choose the viewer, and a failed open
prevents installation and launch. Apple's viewer is an explicit
external-application boundary.

**Unified logs.** `xcrun simctl spawn` runs the device's
`log stream --level debug --style compact --color none` with a native predicate
matching `processImagePath` to the installed `CFBundleExecutable` path, so
filtering happens before records reach Compozsh. In-app framework records are
included; helpers and extensions with other executables are excluded; another
launch of the same executable can match. The observer starts before launch
with a bounded readiness wait, but native drops and startup races prevent
exhaustive capture; records can appear in both sources, and merged order is not
timestamp order. Only the log child gets `LOGRC=/dev/null`, so personal
`.logrc` rules cannot broaden capture. Compozsh never enables private-data
logging or changes log privacy settings, and native behavior is no redaction
guarantee: a disposable iOS 27 Simulator exposed a probe's synthetic `.private`
payload by default. Captured logs may therefore contain sensitive app data,
including values marked private, a limit distinct from Compozsh's local,
ephemeral handling. Compozsh writes no app-output log and does not control the
Simulator's own log retention.

**Reading and copying logs.** The input loop drains at most 32 KiB per idle
turn, fairly across sources, sanitizing display; Read wraps at most 20,000 rows.
A noisy app can see temporary pipe backpressure. A failed source is disclosed
and stops while the other continues; a closed pipe does not mean the app exited.
Read is a full-width view of the retained tail. Search, exclusion, severity
view, counts, formatting and copies derive only from the displayed snapshot,
without new log discovery, while the run keeps draining; following, pausing,
filters and bookmark persist for the run, and Options and the guide hold
displayed text while capture continues. Matching keeps source order and
duplicates; display controls are sanitized while filters and copies keep raw
lines and metadata. Message words never set severity, and Error/Fault counters
cover recognized native records, filtered ones included, without establishing
app health. Copy all, Copy filtered and Ctrl-Y copy complete matching raw lines,
including offscreen text, without labels or wrapping, but not the run's whole
history; empty output has no Copy action. Options freezes its scope, direct
Ctrl-Y uses the current displayed capture, and acceptance freezes the payload
without fetching newer output. The captured `pbcopy` path is rechecked and
invoked only after screen restoration, without reading the clipboard; Run
reopens with feedback while the app continues, and a clipboard failure makes the
final status nonzero. Copies may contain the sensitive values above and outlive
the run, including through [clipboard
synchronization](#external-synchronization).

**LLDB and cleanup.** Enter LLDB gives the restored terminal to the
Xcode-selected debugger for that PID with automatic `.lldbinit` and
symbol-script loading disabled; LLDB may read the app's memory, symbols and
source, and its commands, macOS authorization and the app are separate trust
boundaries. Colors use only fixed native settings and validated numeric palette
values for this invocation: no debugger configuration or color plugin, no
interpretation of app output or input, and `NO_COLOR` or non-color output
disables them without relaxing the autoload protections. Nothing elevates
privileges or changes signing. The log observer lives only within the run and
is stopped and reaped before LLDB and on cleanup: each signal revalidates the
owned child, a suspended child is resumed for termination, and an observer
still alive after one second of bounded draining is killed and reaped without
masking the app's or debugger's status. During LLDB a temporary Zsh child
discards app output so the app does not block. LLDB exit, Stop, Escape and
handled errors stop the still-identical app, reap children, close descriptors
and remove the FIFOs and directory. A changed or unavailable identity prevents
termination and reports a failure telling the user to check or stop the app in
Simulator, which does not prove the app is alive; failed stops are reported.
An uncatchable termination can leave an app, observer, drainer or pipe
directory; Simulator can stop the app, and there is no recovery log to retrieve
or uninstall.

**Apple skill export.** `xcode --export-skills` detects local coding-agent
installations and the selected exporter. With interactive UI it first shows
destination and exporter paths in a scoped plan (context bounded to 32,768
characters, truncation disclosed) before staging; Escape writes nothing, and
Export skills closes the screen before exporting and installing each skill.
Noninteractive, dumb and missing-UI calls run immediately. The plan is not a
dry run or transaction: personal conflicts stay preserved, and a later failure
can leave earlier skills updated. Rendering performs no provider read, project
discovery or private skill-directory scan; mode help is inert. The exporter
writes Apple-authored skill text into one mode-0700
`${TMPDIR:-/tmp}/compozsh-xcode-skills.*` staging directory. Each skill is then
built in a sibling `.xcode-skill-stage.*` directory inside the agent skill
folder, and a refresh moves the previous managed copy into a sibling
`.xcode-skill-backup.*` directory until the new copy is active. Normal and
handled-error cleanup removes all three, except that a failed rollback
deliberately keeps `.xcode-skill-backup.*/previous` and prints its path.
Ctrl-C still removes the `${TMPDIR:-/tmp}` staging directory, but interrupting
installation can leave a `.xcode-skill-stage.*` or `.xcode-skill-backup.*`
directory in an agent skill folder, and an uncatchable termination can leave
any of the three. A backup can hold the previous managed skill (an interrupted
refresh can leave it there instead of in place), so inspect it before removing
it. Inspect `.zsh.addons/.zsh.xcode`;
`zsh tests/run.zsh 'Xcode skill'` checks the staging name and cleanup, and
`zsh tests/run.zsh 'Xcode rollback'` the retained recovery backup.

### External devices and task routing

Bare `external-device` presents two fixed task choices without reading disks or
images; choosing one closes that screen before its normal scoped capture. USB
review and the flash and format modes keep their separate exact-device
confirmations ([Administrator boundary](#administrator-boundary)). Shared pure
USB readers validate supplied SHA text and native progress records without
consulting caller-local variables or reading devices; raw execution uses that
shared digest validation, while media-specific preflight, checksum requirements
and final verification stay with their effect owners. Progress byte counts,
installer percentages, and diskutil `TotalSize` and `DeviceBlockSize` are
validated as decimal text of at most 18 digits before arithmetic, and progress
stage names are compared literally, so this text never reaches arithmetic as an
expression or an out-of-range number. Installer candidate labels
reuse captured metadata, but action-time identity checks acquire fresh
observations. USB and Xcode scalar
extraction share one fixed `/usr/bin/plutil` invocation over supplied document
text, without provider discovery or persistent state. Xcode child/failure
counts and display-span offsets are validated as bounded decimal text before
arithmetic (offsets use local whitespace splitting), without reading or
modifying caller variables; missing count support keeps neutral results within
the existing traversal and retained-failure limits. Inspect
`.zsh.addons/.zsh.usb`, `.zsh.addons/.zsh.help`, `.zsh.addons/.zsh.tools` and
`.zsh.addons/.zsh.xcode`.

### Compiled peer mirror

Compozsh compiles the shipped peers, which are every regular `.zsh.<name>`
file in the shared add-on directory, tracked or not (the clone's `.zsh.addons`
for `--symlink`, the managed `compozsh/` namespace for `--copy`; never private
peers in `${ZDOTDIR:-$HOME}/.zsh.addons`), and Zsh's
[completion dump](#native-completion-dump), into
`${ZDOTDIR:-$HOME}/.zsh.addons/support/compiled`. Each peer gets a symlink,
named like the peer, to the peer's absolute path, and beside it the `.zwc`
wordcode that `zcompile` produced. One shipped file,
`.zsh.addons/support/compile.zsh` (not a peer: discovery never sources it),
does all compiling, always in Apple's `/bin/zsh -f`, run by that absolute path
(never a `zsh` found on `PATH`) from `/`, under Zsh's default options
and only its two built-in aliases, `run-help` and `which-command`, with a 077
umask, so the directory is mode 0700 and the files it writes owner-only. Even
`zsh -f` reads `/etc/zshenv`, so the file first removes every alias that
defined and writes nothing if it cannot; no startup file's alias reaches the
mirror.
`zcompile` only parses a peer; it never runs it. Three callers run
that file, Compozsh's only writer of the mirror (`compozsh --refresh` neither
checks nor rebuilds it):

- `install.zsh`, through the same `/bin/zsh` run from `/`, builds a complete
  new mirror in a `${ZDOTDIR:-$HOME}/.compozsh-compiled.*` staging directory
  and swaps it in;
  an existing `support/compiled` without the `.managed-by-compozsh` marker is
  refused before any change. It waits for the clock to pass a just-written
  peer's ctime, at most about 2 s in total; a peer whose ctime is still ahead
  of the clock then (the clock moved back, or a network volume's server clock
  runs fast) gets no entry or record and loads as text until a shell compiles
  it once the clock has passed it (`zsh tests/run.zsh 'peers ahead of the clock'`).
- Interactive startup, before any peer loads, when a discovered shipped peer
  has no record matching its current metadata (new, edited, or after a Zsh
  update), a record names a peer file that no longer exists (removed or
  renamed), or the mirror is missing. It passes only those peers; their paths
  come from discovery or the manifest, never from the current directory.
  Once the new manifest is in place, it deletes every symlink and `.zwc` under
  the mirror's `.zsh.addons` that the manifest does not name, so a removed or
  renamed shipped peer leaves no entry, wordcode or record. The mirror must be a
  real directory owned by you with no group or other access and holding a
  regular-file marker; a missing one is created (with `support/` if needed,
  only inside an existing add-on directory), and anything else at that path
  is left untouched while every peer loads as text. The work runs under a
  `.lock` directory; a shell that finds a live lock loads text without
  waiting, and a lock older than a minute is treated as abandoned. New
  wordcode and the manifest are written to `*.compozsh-tmp-<pid>` names and
  renamed into place, so a half-written file is never used, and leftovers from
  an interrupted compile are deleted by the next one. A peer edited in the
  current second is left for the next shell, no new peer starts compiling
  after about 300 ms, and a peer over 512 KiB, or one that fails to compile,
  gets a `-` text record so later shells do not retry it until it changes.
  Startup prints nothing about any of this; every failure means text. Its
  standard input is `/dev/null`, so it cannot consume typed-ahead input. It
  runs `/bin/zsh`, Apple's Zsh, by that absolute path with `/` as the working
  directory, never a `zsh` found on `PATH` (which could be a version-manager
  shim that resolves the start directory's policy, or a project's own
  binary), and compiles only when that Zsh reports the running
  `$ZSH_VERSION`. Otherwise it compiles nothing and records in the mirror's
  `zsh` note this `/bin/zsh`'s version, device, inode, size, mtime and ctime;
  while the note still matches `/bin/zsh`, a shell of another Zsh version
  starts no compile child and loads text, and so does every shell when
  `/bin/zsh` is missing (`zsh tests/run.zsh 'no compile child'`).
- `.zsh.editor`, right after `compinit`, for the completion dump only, under
  the same mirror rules, lock, bounds, `/bin/zsh` run from `/`, `zsh` note,
  `/dev/null` input and
  silent fallbacks, as its [compiled copy](#native-completion-dump) describes.

The one other writer is Zsh's stock `compdump`. When `compinit` was given the
compiled copy's `zcompdump` entry but must rewrite its dump (the `fpath` file
count or Zsh version changed), it writes `zcompdump.<host>.<pid>`
in the mirror under your umask (0644 under the default 022; the mode-0700
directory still keeps other accounts out) and renames it over the entry.
`.zsh.editor` then has `compile.zsh` move that file to
`${ZDOTDIR:-$HOME}/.zcompdump`, or delete it if the move fails. If that step
cannot run, the rewritten dump stays at the entry as a regular file under your
umask. It is never loaded as the compiled copy, because the fresh check
requires the symlink, and the next dump compile replaces it with the symlink.

The bootstrap sources a peer through its mirror entry, so Zsh runs the
wordcode, only when all of these hold; otherwise it sources the peer's text
as it would without a mirror:

- the mirror is a real directory owned by you with no group or other access,
  with a regular-file marker, and its `manifest` a regular file owned by you
  without group or other write;
- the manifest names the running `$ZSH_VERSION`, so a Zsh upgrade means text
  until the peers are recompiled;
- the mirror entry is a symlink to exactly the discovered peer path;
- the peer's device, inode, size, mtime and ctime equal the values recorded
  when it was compiled. A peer is compiled only after the clock has passed its
  ctime and dropped if any value changed meanwhile, and no account can set
  ctime, so any later write, `chmod`, replacement or `touch` that restores an
  older mtime puts that peer back on text until it is recompiled. Zsh's own
  check (and `zrecompile`), a `.zwc` not older than its source, would accept
  same-second edits and restored mtimes. The values are read again just before
  each compiled peer loads, so a peer changed while earlier peers load (by one
  of them, or by an edit in the same second as its compile) loads its new
  text, and one removed meanwhile fails to load rather than running the
  wordcode left behind
  (`zsh tests/run.zsh 'changed while earlier peers load'`); the wordcode a
  shell runs is the text the peer held at that last check, and only a write
  racing it, as with any file read while it is being written, can still meet
  the code compiled from the text it replaces. The check relies on the file
  system recording this machine's clock, as local volumes do;
- the parse context matches the compiling shell's when peers start loading
  (exactly Zsh's default parse-affecting options and its two built-in aliases,
  unchanged by any system or personal startup file, the initializer or a
  re-sourced bootstrap), and no peer loaded as text has changed it since.
  While a manifest exists and the context does not match, startup does not
  compile either.

So the mirror can change startup time and the source path Zsh records for each
function a compiled peer defines (`functions_source` names the mirror entry),
never the rest of the resulting shell state; tests compare the complete state
apart from those paths with and without it in both layouts. Discovery
never treats a `.zwc` file or anything under `support/compiled` as a peer, and
Git ignores `.zsh.addons/support/compiled/` (like `support/cache/`) and, at
the clone's root only, `.zsh_history*`, `.zsh_sessions/`, `.zcompdump*` and
`.zsh-backups/`, so a shell whose `ZDOTDIR` is a clone never offers the
mirror's absolute paths or compiled completion names, its default history
file (and its interrupted-write residue), Terminal.app's per-session history
and state, its completion dump (with interrupted-write residue) or the
installer's recovery copies to a commit
(`zsh tests/run.zsh 'Git ignores the compiled mirror'`). A
`.zwc` placed beside a peer by hand is Zsh's own mechanism and outside this
check: Zsh's `source` uses it while it is not older than the peer.

**Residue.** An uncatchable termination (`SIGKILL`, power loss) during a
startup compile can leave the `.lock` directory, which the next compile
after a minute removes, and `*.compozsh-tmp-<pid>` files, which are never
used and which the next compile deletes; an interrupted `compinit` rewrite
through the mirror can leave `zcompdump.<host>.<pid>`, which a compile deletes
once it is a minute old; a rewritten dump whose move-back step could not run
stays at the `zcompdump` entry as a regular file, never loaded as the compiled
copy, until the next dump compile replaces it with the symlink. The entry,
wordcode and record of a shipped peer that was removed or renamed remain
until the next shell whose parse context allows compiling (and that finds no
live lock), or until the next installation; `--clean` archives whatever is
present. Deleting the whole mirror is always safe: the next shell rebuilds it.

**Trust.** The mirror is executable configuration with the same trust as the
add-on tree it lives in: an account that can replace it can already replace
private peers. Its access checks read ownership and POSIX mode bits only:
extended ACLs on the mirror, which it can inherit from `support/`, are not
inspected or removed (Zsh has no native way to read them, and startup starts
no process just to check them), so an ACL that grants another account access to the
mirror gives it the same access as one on the add-on tree. Inspect it (`ls -e`
also lists any ACL), and check every entry independently of Compozsh's own
code, with:

```sh
ls -laeR "${ZDOTDIR:-$HOME}/.zsh.addons/support/compiled"
sed -n '1,6p' "${ZDOTDIR:-$HOME}/.zsh.addons/support/compiled/manifest"
zsh -fc 'zmodload -F zsh/stat b:zstat; m=${ZDOTDIR:-$HOME}/.zsh.addons/support/compiled
  b=${${(f)"$(<$m/manifest)"}[3]#base }
  for l in ${${(f)"$(<$m/manifest)"}[7,-1]}; do f=(${(ps:\t:)l}); [[ $f[1] == - ]] && continue
    zstat -H s -- $b/$f[1]; [[ "$s[device] $s[inode] $s[size] $s[mtime] $s[ctime]" == "${f[2,6]}" ]] &&
    r=fresh || r=stale; print -r -- "$r $f[1] -> $(readlink $m/.zsh.addons/$f[1])"; done
  l=(${(f)"$(<$m/zcompdump.manifest)"}); zstat -H s -- ${l[3]#dump }
  [[ "$s[device] $s[inode] $s[size] $s[mtime] $s[ctime]" == "${(j: :)${(ps:\t:)l[7]}}" ]] &&
    r=fresh || r=stale; print -r -- "$r dump -> $(readlink $m/zcompdump)"'
```

The last command compares file identity only. It lists every compiled entry
as `fresh` (used while the running Zsh version and parse context also match
those its manifest records, which the second command shows for the peers) or
`stale` (ignored; the next shell recompiles it) with its link target, which
must be the shipped peer or, for the dump, `${ZDOTDIR:-$HOME}/.zcompdump`.
`zsh tests/run.zsh 'compiled peers'` checks discovery, freshness, fallbacks,
state equality, startup recompilation, locking, interrupted compiles, the size
bound and the installer lifecycle;
`zsh tests/run.zsh 'compiled completion dump'` checks the dump's freshness,
fallbacks and rewrite at its usual path.

### Installer backups and temporary residue

The installer never prints the contents of an old `.zshrc` or private add-on,
but a recovery backup can contain secrets that were already present there.
Protect and eventually archive or remove those backups according to your own
retention policy; Compozsh deliberately does not delete them automatically.

Ctrl-C, a hangup or a termination signal during installation rolls back like a
handled failure, and further such signals are ignored while it cleans up.
Rollback moves an archived item back only into a free location, so an item it
cannot restore stays in the `.zsh-backups/compozsh-*` directory, whose path it
prints. Copy mode first stages the shipped add-ons in a mode-0700
`${ZDOTDIR:-$HOME}/.compozsh-install.*` directory, which the bootstrap never
sources and cleanup removes. An uncatchable termination (`SIGKILL`, power loss),
or a signal that stops `mktemp` between creating that directory and reporting
its name, can leave it behind, and an uncatchable termination can also leave a
partially applied installation whose replaced files remain in the backup.
Earlier releases named the staging directory `.my-zsh-install.*`. Every
installation also builds the [compiled peer mirror](#compiled-peer-mirror) in a
mode-0700 `${ZDOTDIR:-$HOME}/.compozsh-compiled.*` directory, which holds the
superseded mirror after the swap and is removed the same way, with the same
uncatchable-termination limits. Inspect
`install.zsh`; `zsh tests/run.zsh 'installer'` checks rollback after failures
and signals, the staging name and its cleanup.

An uncatchable process termination or system failure can leave a temporary
capture behind; its validated `compozsh-*` name makes it identifiable in
`${TMPDIR:-/tmp}`. For Git review this can be an empty mode-0700
`compozsh-review.*` directory containing its mode-0600 FIFO; provider output is
streamed through pipes and is not persisted there. Normal exit removes both;
after an uncatchable termination, the user may inspect and remove the
identifiable directory. Other feature-specific residue (manual transport and
formatter directories, cache and completion-dump staging files, Xcode test
bundles, Xcode skill staging and its agent skill-folder siblings, device and
Simulator run directories, interrupted worktree creation,
external media captures and image mount points, and Touch ID policy
temporaries) is disclosed in its own section; the Ctrl-X Ctrl-E draft file,
which does not use a `compozsh-` name, has its own inventory row.

### External synchronization

The locations above are local process, filesystem, agent-directory, and
operating-system clipboard interfaces on the machine running Compozsh. A user
can independently configure a history, configuration, temporary, or agent
directory on a synced or network-mounted filesystem. macOS can also synchronize
its clipboard when the user enables that operating-system feature. Compozsh does
not configure, detect, start, or control either form of synchronization. Users
who require physical single-machine retention must choose local,
nonsynchronized paths and disable
operating-system clipboard synchronization
or avoid Copy actions.

### Secrets on the command line

Shell command lines are a poor place for passwords, tokens, or private keys:
they can be exposed through history, process listings, logs, or the invoked
program itself. `HIST_IGNORE_SPACE` is enabled, but a leading space is only a
convenience and not a secret-storage mechanism. Prefer the macOS Keychain or a
dedicated secret store, and rotate any credential that was exposed. Ctrl-X
Ctrl-E hands the whole draft to your editor through a temporary file (see the
[inventory](#complete-local-data-inventory)). History autosuggestions show the
unaccepted rest of a matching recent history entry beside the draft; accepting
a line removes it before Zsh repaints that line into scrollback, on
continuation and nested lines and without the prompt peer too, but a line
interrupted with Ctrl-C stays on screen as painted.
Only the Interaction lens and
the terminal title, both secondary presentations, omit assignment values; the
living prompt transcript deliberately retains the exact submitted command text.
Both behaviors are presentation choices, not a
privacy or redaction boundary.

## Administrator boundary

No administrator access occurs at shell startup, during installation, while
showing help, during `compozsh --sudo-touch-id status`, or during normal prompt,
search, history, Git, and navigation features. Administrator access has two
explicit boundaries: `external-device --flash` and `external-device --format`
after the user selects a whole external physical disk and types the exact
visible `ERASE diskN` confirmation; and
`compozsh --sudo-touch-id enable|disable` after the user names that
state-changing mode.

### External media writes

1. Compozsh captures and validates an external whole-disk identity.
2. The user reviews the exact `/dev/diskN` target and confirms it by name.
3. Compozsh runs `/usr/bin/sudo -v`. Apple's `sudo` reads any password directly
   from the terminal and manages its own authorization timestamp.
4. Compozsh revalidates the target before mutation.
5. Privileged operations use `sudo -n`, which refuses to prompt or read a
   password. The permitted implementations are `/usr/sbin/diskutil`, one
   fixed internal Zsh raw-device routine (the only place Apple's `/bin/dd`
   runs with privilege), and an Apple-signature-validated `createinstallmedia`
   from the explicitly selected macOS installer application.

A write never targets the disk holding its own source. Before drive capture,
`_usb_image_source_disk_capture` in `.zsh.addons/.zsh.usb` resolves the
selected media's filesystem device with `/bin/df` and `diskutil info`, follows
an APFS volume to the whole disk of every physical store behind its container,
excludes those whole disks from the drive list, and refuses them again before
any effect when the write starts. Media on a whole disk that `diskutil` reports
as virtual (a mounted disk image, sparsebundle or AppleRAID set) is refused
before any drive is captured, because macOS does not report the drives behind
it; copy it to a regular drive first. A device, physical store or whole disk
that cannot be resolved is refused too. Media on a filesystem whose device is
not a local `/dev/disk` node, such as a network share, maps to no local disk
and needs no exclusion. `zsh tests/run.zsh 'USB source exclusion'` checks these
cases against recorded `diskutil` answers.

Apple signature validation never consults the requirement a signer declares
for its own code. `_usb_codesign_is_apple` and
`_usb_codesign_is_apple_application` in `.zsh.addons/.zsh.usb` pass fixed
requirements to `/usr/bin/codesign --verify --strict -R`: the
`Contents/Resources/createinstallmedia` that runs as root must satisfy
`anchor apple` (Apple's own code), and the enclosing `Install macOS <name>.app`
must satisfy
`anchor apple or (anchor apple generic and certificate leaf[field.1.2.840.113635.100.6.1.9] /* exists */)`,
which also admits Apple's Mac App Store signature. Both checks run when the
installer is selected, again after administrator authorization, and again
after the drive is prepared and immediately before `createinstallmedia` starts;
the last two also compare the installer's and tool's captured device, inode
and times and the tool's size. An installer whose signature no longer
validates, including a genuine older copy whose Apple certificate has expired
or whose chain is not trusted, is refused, because `codesign` then cannot
establish that Apple signed it; download a current copy from Apple instead.
Check an installer yourself with
`codesign --verify --strict -R '=anchor apple' "/Applications/Install macOS <name>.app/Contents/Resources/createinstallmedia"`
and, for the application, the second requirement in the same form (expected: no
output, status 0; a refused object prints
`code failed to satisfy specified code requirement(s)` with status 3, or
another `codesign` error). `zsh tests/run.zsh 'USB Apple signature boundary'`
ad-hoc signs copies of `/usr/bin/true` in a temporary directory, without the
keychain or network, that declare `anchor apple`, a Developer ID-shaped or a
Mac App Store-shaped requirement or sit under a folder named `anchor apple`,
plus an ad-hoc signed `Install macOS Example.app`, and checks that each is
refused while Apple's `/usr/bin/hdiutil` passes both requirements. No hermetic
fixture carries a genuine installer signature, so the tests do not show that a
real installer is accepted.

The raw-image routine passes image paths, captured source fingerprints, device
names, sizes, and verification flags as literal arguments. Its privileged
routine opens the source once with no-follow semantics, verifies the held file
descriptor's device, inode, size, and modification time against the capture,
and uses that descriptor for writing and read-back comparison. It does not pass
shell history, environment dumps, credentials, or network destinations.
Password handling remains entirely inside the operating system's `sudo`
process.

### External media temporary files

`external-device` keeps its captures in invocation memory, released when the
flash or format task returns. Each `diskutil … -plist` answer (external disk
list, disk or volume info, filesystem catalog) is read straight into memory
through the shared bounded reader, and output above 1 MiB is refused after at
most 1 MiB + 5 bytes are read. The exceptions are these
`/usr/bin/mktemp` names directly beneath `${TMPDIR:-/tmp}`, created as mode
`0600` files or `0700` directories owned by the invoking user. Privileged
output reaches them only through redirections opened by that user's shell; no
`sudo` command receives a temporary path. `zsh tests/run.zsh 'USB invocation state'`
checks that the only `_USB_*` parameters at load are fixed limits, and that
every `_USB_*` parameter, `REPLY`, `reply` and the picker's selection and
bookmark (which can hold filter text) are back to their load-time values after
leaving `--flash` or `--format` at drive selection, after a failed write and
after a completed format.

| Name | Created during | Contents and bounds |
| --- | --- | --- |
| `compozsh-usb-iso.*` | ISO classification | The selected ISO's `tar -tf` path listing, at most 16 MiB + 1 byte |
| `compozsh-usb-inspect.*` | ISO classification when that listing is inconclusive | Read-only, `nobrowse` `hdiutil` mount point. While attached it presents the image's file tree with the mount's own permissions (observed `0755` with an ISO 9660 fixture; check with `stat -f %Lp` on the attached mount point), so other local users can read it only through a traversable parent such as `/tmp`; the default per-user macOS `TMPDIR` is owner-only. The mount path itself is visible to them in `mount` and `df` output |
| `compozsh-usb-progress.*` | Raw image write, including `flash-verify` read-back inside the same privileged session | Standard error of that session: `dd` write and read-back progress and record counts, fixed `compozsh-write-*` stage and result markers, and native error text that can name the image or device. No size cap on disk; read in steps of at most 1 MiB |
| `compozsh-createinstallmedia.*` | Apple `createinstallmedia` | Its combined standard output and error. No size cap on disk; ignored above 1 MiB |

`flash-verify` reads the drive back only inside the privileged write session,
before that session releases the device. `_usb_execute` treats a write without
that session's `compozsh-write-verified` evidence as an incomplete-evidence
failure and never rereads the drive afterwards; `flash-only` skips read-back.

Each of these names is removed by an `always` block. The ISO listing
(`compozsh-usb-iso.*`) and the inspection mount point
(`compozsh-usb-inspect.*`) use the block of the function that created them.
The progress files, `compozsh-usb-progress.*` from `_usb_write_image` and
`compozsh-createinstallmedia.*` from `_usb_createinstallmedia_run`, use the
block of the shared worker loop `_usb_worker_progress_run`, which the creator
calls immediately after `mktemp`. Each block removes the exact path `mktemp`
returned, on normal return, handled failure or an interrupt that unwinds Zsh,
after checking that the name sits directly in `${TMPDIR:-/tmp}` and starts
with its own `compozsh-usb-iso.` or `compozsh-usb-inspect.` prefix or, in the
worker loop, with either progress prefix, `compozsh-usb-progress.` or
`compozsh-createinstallmedia.`; the loop leaves any other name it is handed in
place. An interrupt between a `mktemp` call and the start of that block can
leave the name; for the progress files that window includes entering the
worker loop. Progress views first wait for their
native worker to exit, because a command started with `&` while the `MONITOR`
option is off ignores `SIGINT` (`man zshmisc`, SIGNALS). A second interrupt
during that wait skips the rest of the worker loop's `always` block: the
privileged worker keeps running after `external-device` returns, its progress
file remains, and the outer cleanup can request `diskutil eject` while the
write continues. The mount point is removed only after `hdiutil detach` succeeds;
when detaching fails, the image stays attached read-only there, detaching is
retried before the next inspection and when `external-device --flash` returns,
and a further failure leaves both in place without a separate notice. An
interrupt while `hdiutil attach` itself runs unwinds before Compozsh records the
device: the empty directory's removal then fails if macOS completed the
attachment, which stays mounted there with no retry or notice (find it with
`hdiutil info`).

Neither the USB peer nor the shared screen it runs in traps `SIGHUP`; the
screen session installs only `TRAPINT` and `TRAPWINCH`. A hangup (closing the
terminal or losing an SSH session), `SIGKILL`, crash or power loss therefore
skips that cleanup and
can leave any of these names with the contents above; a worker that outlives the shell can keep writing to its progress file
until it exits. Confirm the traps with
`grep -nE '\btrap\b|TRAP[A-Z]' .zsh.addons/.zsh.usb .zsh.addons/support/ui/.zsh.ui.zle_picker_screen_session`
(only that screen session's comments, `LOCAL_TRAPS`, `TRAPINT` and `TRAPWINCH`
lines).
List residue in Zsh with
`ls -ld "${TMPDIR:-/tmp}"/compozsh-(usb|createinstallmedia)*` (no
residue: `no matches found`, status 1) and `hdiutil info` (no residue: no
`compozsh-usb-inspect.*` mount point); release an attachment with
`hdiutil detach /dev/diskN`, then remove its empty directory with `rmdir`. Read
the creation and cleanup sites with
`grep -n -e mktemp -e 'rm -f' -e rmdir .zsh.addons/.zsh.usb`. The `rmdir` call is
in `_usb_mount_cleanup`, which the inspection's `always` block calls, and the
progress files' shared `rm -f` is in `_usb_worker_progress_run`, away from both
of their `mktemp` calls.
`zsh tests/run.zsh 'USB temporary'` uses stand-ins for `diskutil`, `hdiutil`,
`dd` and `createinstallmedia` to check removal after success and handled
failure, and each name and mode while it exists, for every name except
`compozsh-usb-iso.*` (removal only; `tar` has no stand-in seam); the
`diskutil` stand-in sees no file at all. It also checks that the worker loop
leaves another `compozsh-*` name in place.
`zsh tests/run.zsh 'ISO inspection'` covers the failed-detach
retry and a later refused inspection.
`zsh tests/run.zsh 'external-media temporary'` fails when a
`command /usr/bin/mktemp` call in `.zsh.addons/.zsh.usb` lacks a literal
`compozsh-*` name or when that name is missing from this section. It pairs
calls and names by count rather than per call and does not recognize other
`mktemp` spellings.

### Touch ID for sudo

1. Compozsh verifies macOS and an ACL-free, root-owned, non-writable
   `/etc/pam.d`. Enable additionally requires the root-owned, ACL-free system
   `sudo` policy to include `sudo_local` before its required
   `pam_opendirectory.so` password fallback, and the matching system template to
   advertise `pam_tid`. Policy files observed above 64 KiB are rejected before
   reading; this is a fail-closed size check, not atomic isolation from root.
2. `status` reads fixed PAM-directory metadata and the fixed target. `enable`
   proceeds only when `/etc/pam.d/sudo_local` is absent. `disable` remains
   usable if the enable prerequisites later drift, but proceeds only for a
   regular, ACL-free, `root:wheel`, mode `0444`, byte-identical managed file.
   Existing custom, symbolic-link, special-file, changed, or unsafe policy is
   preserved.
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
   target. The privileged routines do not trust the caller's inspection path:
   they repeat checks against literal `/etc/pam.d` targets. A concurrent root
   policy manager can still replace state around shell-level checks; Compozsh
   fails closed when it observes drift but does not claim compare-and-unlink
   isolation from root.
5. `pam_tid` is configured as `sufficient`. A failed or unavailable biometric
   attempt falls through to the verified later required
   `pam_opendirectory.so` authenticator; the rule changes the authentication
   method, not who is authorized for sudo.

`compozsh --sudo-touch-id` is the sole public entry, with status as its default.
Its `--help` path is static and remains available without the operation peer;
malformed arguments fail before dispatch. The retired command is not an alias.
New policies name the grouped command in their removal comment. Status and
disable also recognize the exact earlier three-line policy whose comment names
the retired command. The privileged removal routine independently validates
either fixed byte sequence, including its exact size, owner, mode and ACL; a
similar or edited comment is not ownership proof. Nothing rewrites existing PAM
files during loading or this command migration. The fixed temporary filename
prefix remains unchanged so interrupted-operation residue stays identifiable.

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

### Audit the privilege surface

```sh
git grep -n 'sudo' -- .zshrc install.zsh '.zsh.addons/**'
git grep -nE 'sudo[[:space:]]+(-S|--stdin)|SUDO_ASKPASS|pbpaste|/usr/bin/security' \
  -- .zshrc install.zsh '.zsh.addons/**'
```

The first command identifies operations in `.zsh.addons/.zsh.usb` and
`.zsh.addons/.zsh.sudo-touch-id`, grouped dispatch and static documentation in
`.zsh.addons/.zsh.help`, and a literal advisory in `.zsh.addons/.zsh.prompt`.
Only the first two peers invoke sudo. The second should print no matches and
return status 1. Inspect every changed result rather than treating the command
as a permanent allowlist. In the Touch ID peer, confirm every privileged target
is a literal path beneath `/etc/pam.d` and that only `/usr/bin/sudo -v` can
prompt. On a supported Mac, independently inspect the active system files for
Apple's documented interface with
`ls -lde /etc/pam.d /etc/pam.d/sudo /etc/pam.d/sudo_local.template`,
`sed -n '1,120p' /etc/pam.d/sudo`, and
`sed -n '1,120p' /etc/pam.d/sudo_local.template`; do not paste these files into
a shell command. Apple's macOS Sonoma enterprise notes document the persistent
`sudo_local` interface, and Apple's published `pam_tid` source documents its
local graphical-session and askpass limitations.

## Compozsh network prohibition and external boundaries

Compozsh defines no project endpoint and initiates no network request. Living
prompt disclosure and transcript transitions use only the literal editor buffer
and current captured snapshot; they do not evaluate the buffer, poll, run a
background worker, or recapture providers as the user edits, toggles the lens,
or resizes the terminal. A `REMOTE` or remote-related `ACTION` row is advisory
text and does not create a connection. The compiles that interactive startup
and `.zsh.editor` may start run Apple's `/bin/zsh -f` by that absolute path
from `/` ([compiled peer mirror](#compiled-peer-mirror)), never a `zsh`
resolved through `PATH`, so these compiles start no version-manager shim or
project directory policy.

### Local-only Git controls

Compozsh's Git inspection does not request `clone`, `fetch`, `pull`, `push`, or
another remote operation.

- **Prompt status** disables repository-configured clean/process filters,
  filesystem monitors, hooks, required-filter enforcement, and lazy fetches.
- **Branch snapshot providers** disable lazy fetches, prompts, transport and
  optional writes while reading local refs, reflogs and detail subjects, so a
  missing promised object cannot start transport during branch details. They
  also disable commit-signature verification (`log.showSignature`), so no
  configured verifier program such as `gpg.program` runs while reflogs are
  read. Branch switching separates options from the exact selected ref name,
  including a ref beginning with `--`.
- **Git review** applies its own equivalent read-only filter boundary and
  disables commit-signature verification, so commit history and root-commit
  documents never run a configured verifier program or mix its output into
  captured commit IDs.
- **One local-only Git entry.** Prompt status, filter-name discovery, branch
  snapshots, Search's Git discovery, Git review (manual and automatic), the
  worktree workspace's captures and operations, and every `g --discard-all`
  read, cleanup, restore and verification reach Git only through one shared
  support entry, `_compozsh_git_local`. Every call it makes disables optional
  locks, lazy fetches, terminal prompts, transport protocols, the pager,
  replacement objects, filesystem monitors, the untracked cache, hooks and
  commit-signature verification; each feature only adds its own controls.
  Without the entry these features run no Git command. Only transparent `g`
  and `git` arguments and confirmed branch switches or creations call Git
  directly.
- **Apple's Git launcher.** When `PATH` selects `/usr/bin/git`, Apple's
  launcher that starts the Git of the active developer directory, the entry
  may run that Git directly instead, saving the launcher's start-up on each
  read. The prompt resolves it once per shell, in its own shell process, at
  its first Git status read: one `/usr/bin/xcrun --find git` (output bounded
  to 4 KiB) and one
  `/usr/bin/codesign --verify --strict -R '=anchor apple and identifier "com.apple.git"'`
  on the named file. Only status 0 from that check makes the file eligible;
  any other answer, a missing tool, or a path that is not an absolute regular
  executable keeps `/usr/bin/git`, and the refusal is remembered for the same
  selectors. The check uses the file's own signature and Compozsh requests no
  notarization or online revocation check. The file's zstat identity is
  recorded before and confirmed after the check, then compared again before
  every direct run; any difference runs `/usr/bin/git` for that call, and the
  next prompt verifies again. A changed `PATH` choice, exported
  `DEVELOPER_DIR`, `TOOLCHAINS` or `SDKROOT`, or xcode-select link resolves
  again; `compozsh --refresh` forgets the answer. A Git chosen elsewhere on
  `PATH` is never resolved, verified or replaced, transparent `g` and `git`
  arguments always run the `PATH` choice, and other entry callers only reuse a
  prompt's answer. The direct Git runs without the `SDKROOT`, `MANPATH`,
  `CPATH` and `LIBRARY_PATH` the launcher adds. Git does not use them, and
  these reads keep hooks, content filters, the pager and signature verifiers
  off (Git review also turns off external diff and textconv programs). Like
  the launcher, which runs whatever its developer directory holds, this
  cannot stop a file swapped between the last identity check and the run. Inspect `_compozsh_git_local_resolve` in
  `.zsh.addons/support/functions/.zsh.impure.compozsh_git_local`, and check
  the file yourself with
  `codesign --verify --strict -R '=anchor apple and identifier "com.apple.git"' "$(xcrun --find git)"`
  (expected: no output, status 0).
- **Missing developer tools.** Without Xcode or the Command Line Tools,
  running one of Apple's `/usr/bin` launchers, such as `git`, `xcrun`, the
  compilers, `swift` or `python3`, makes macOS offer to install them. On
  macOS, three passive reads first look for a developer directory the way the
  launcher does, with file tests only (`_compozsh_developer_dir`): an exported,
  non-empty `DEVELOPER_DIR`, else the first xcode-select link
  (`/var/select/developer_dir`, `/var/db/xcode_select_link`,
  `/usr/share/xcode-select/xcode_dir_link`), else Xcode, the Command Line Tools
  or Xcode beta at their default places, each counted only when it (or its
  `Contents/Developer`) holds `usr/lib/libxcrun.dylib`. With none, when `PATH`
  selects `/usr/bin/git` the prompt shows no Git context and runs neither its
  Git reads nor the launcher resolution above, and Search's default source is
  not Git; and when a C, C++, Objective-C, assembly, Swift or Python runtime
  probe would run `/usr/bin/c++`, `clang++`, `g++`, `clang`, `cc`, `swift` or
  `python3` (found on `PATH`, directly or through a link), the prompt shows
  that runtime as `not-installed` and runs nothing. That answer is never
  remembered, so the next prompt after an install finds Git and probes those
  runtimes again. Git you start yourself (`g`, `git`, the Git workspaces, an
  explicitly chosen Git Search, `g --discard-all`) still runs `/usr/bin/git`,
  which may bring up the offer, and a Git or runtime elsewhere on `PATH` is
  unaffected. On other systems `/usr/bin/git` is an ordinary Git and these
  reads run it as usual. Inspect
  `.zsh.addons/support/functions/.zsh.impure.compozsh_developer_dir` and its
  callers in `.zsh.impure.compozsh_git_local` and
  `.zsh.impure.prompt_runtime_version`. Without running any launcher,
  `ls -lf /var/select/developer_dir /var/db/xcode_select_link /usr/share/xcode-select/xcode_dir_link /Applications/Xcode.app/Contents/Developer/usr/lib/libxcrun.dylib /Library/Developer/CommandLineTools/usr/lib/libxcrun.dylib /Applications/Xcode-beta.app/Contents/Developer/usr/lib/libxcrun.dylib`
  lists each of these paths that exists, in the order the probe checks them
  (each missing one is reported as `No such file or directory` first); an
  exported `DEVELOPER_DIR` replaces them all. The prompt shows Git and those
  runtimes when the first entry listed is a link (`->`) to a folder that
  holds `usr/lib/libxcrun.dylib` itself or under `Contents/Developer`, or,
  with no link listed, when any `libxcrun.dylib` is listed; six missing paths
  mean it shows neither (the focused tests are `without developer tools`).
- **Repository selection.** Interactive branch, review, worktree and explicit
  discard workspaces, and explicit-root review providers, use the current
  folder's repository, temporarily shadowing inherited Git directory, worktree,
  common-directory, index, object-store, alternate-object and namespace
  selectors; the caller's environment survives, and transparent `g` arguments
  and the prompt keep native Git-context behavior.
- **Revision comparisons** acquire local refs only on chooser entry and resolve
  literal names/IDs only on submission or direct entry; filtering, scrolling,
  resizing and the guide discover nothing. Refresh keeps both commit IDs and any
  resolved common ancestor; missing objects and ambiguous ancestry fail visibly
  without fetching or switching method. The ref catalog holds no author
  identities or commit subjects.
- **Working changes refresh** is the only automatic local recheck, only while
  its review screen is open: one bounded worker/provider pair at a time,
  results through private pipes and bounded memory, and the same disabled
  filters, hooks, lazy fetch, prompts and transport as manual refresh. Checks
  start enabled; pause with Ctrl-A or `ZSH_GIT_REVIEW_AUTO_REFRESH=0` set before
  peers load. Intervals adapt from a two-second floor to measured cost; a
  thirty-second worker deadline bounds capture and delivery even with input
  queued. The response FIFO is opened without following links and written
  nonblocking in chunks of at most 8 KiB; cleanup drains incomplete packets,
  terminates and reaps owned processes and removes the FIFO. No daemon,
  persistent cache, Git hook or fetch is created.
- **Filter overrides.** One pure builder protects manual and automatic review
  refresh, prompt status and guarded discard reads: filter discovery and its
  inert override argv share a 4,096-entry bound, and a driver name containing
  `=` is refused because Git's command-line configuration cannot
  unambiguously override it. Discard also requests inert smudge overrides.
  Filter names come from the shared bounded reader, which keeps completion and
  exit status apart from the payload; Review may show a marked partial prefix,
  while Worktree and filter discovery require complete captures. The byte bound
  is not a wall-time deadline.
- **Worktrees** disable transport and hooks and refuse checkout filters
  ([Git worktrees](#git-worktrees)).
- **`g --discard-all`** applies these controls to initial HEAD validation
  (where a missing promised object likewise cannot start transport), preview,
  restore, cleanup and verification, and after confirmation
  revalidates repository, HEAD, operation (before and after: any merge,
  autostash, cherry-pick, revert, bisect, rebase or sequencer marker of any
  file type, the check worktree move and removal also use), filter-name and
  listed-path state. An existing index lock refuses before writes and is never
  removed. Native untracked cleanup runs
  before tracked restoration while reviewed ignore rules apply; ignored files
  newly exposed by restoring `.gitignore` stay on disk and yield a
  remaining-changes report with status 1. An empty committed tree supports
  untracked-only cleanup. If tracked restoration fails after cleanup, the
  diagnostic reports the partial outcome; completed deletion is not rolled
  back. Restore disables submodule recursion even under
  `submodule.recurse=true`, preserving child contents; a dirty child can still
  make verification report remaining changes (status 1) after parent changes
  are discarded.
- **Files** discovery uses bounded filesystem reads, local Git metadata, or the
  local Spotlight index. Its Git detection and capture share one
  explicit-folder boundary with the same selector isolation and disabled
  filesystem monitors, hooks, replacement objects, optional writes, lazy
  fetches and transport, so repository-configured fsmonitor commands cannot
  run during `ls-files`.
  Inspect `.zsh.addons/.zsh.find` and the shared `_compozsh_git_local` entry.

### Independently controlled network-capable software

The following independently controlled software can use the network; none is
a permission for Compozsh to add a request, destination, or data:

- Cloning and updating the repository, and network-capable Git subcommands the
  user explicitly runs, use the configured Git transport. Git also documents
  that a [partial clone](https://git-scm.com/docs/partial-clone) may
  demand-fetch a missing object during an otherwise local command; that is
  installed Git behavior against the repository's configured promisor remote,
  not a Compozsh endpoint. Compozsh's own Git calls disable lazy fetching as
  listed above.
- Prompt runtime detection invokes a trusted-path installed runtime with a fixed
  version argument from `/`. Common auto-install and telemetry controls are
  disabled where supported, but the executable on `PATH` remains independently
  trusted software with its own behavior. Scala CLI's version capture explicitly
  passes `--offline` to suppress its documented update check; it displays the
  default Scala version rather than the CLI launcher version. See [Scala CLI
  version](https://scala-cli.virtuslab.org/docs/commands/version/). An ambiguous
  `scala` launcher is left unprobed and labeled `launcher-managed`; its
  incompatible classic/modern interfaces cannot safely identify themselves
  through a speculative version invocation.
- Explicit Xcode build, test, analyze, clean, run, LLDB, and Apple skill-export
  actions invoke Apple's tools. Discovery disables automatic package resolution
  and updates; a chosen build can execute project build phases. Physical-device
  Run explicitly asks Apple's `devicectl` to install and launch the app on the
  selected device over its configured connection, as detailed under [Xcode
  capture, Run and logs](#xcode-capture-run-and-logs).
- Open and Reveal actions can launch Finder or another installed application.
  That application's later behavior is outside this repository.
- An explicit branch switch, including creating a local branch from a
  remote-tracking one, runs the repository's configured checkout filters and
  post-checkout hooks (see [Git review and branches](#git-review-and-branches));
  worktree operations disable hooks and refuse filters. Any explicit directory
  change — entering a worktree, a Browse or Recents directory change, `mkcd` —
  runs the user's own `chpwd` hooks, as an ordinary `cd` would. Each has its own
  effects and network behavior. Private add-ons and the machine-local
  initializer are likewise independently controlled code.
- The repository's contributor skills in `.claude/skills/` are Claude Code
  project skills. They run when a contributor invokes them by name or asks
  Claude Code for the task in their description, inside a forked subagent of
  the same Claude Code session that has no file-editing tools and is
  instructed to stay read-only (shell commands other than the listed
  pre-approvals still need the contributor's approval); the coding agent and its model
  provider apply their own network and data policies, and content the agent
  reads is sent to that provider as context. `compozsh-platform-review` asks
  the agent to consult current Apple documentation and official upstream Zsh
  and tool documentation, and pre-approves page reads only from
  `developer.apple.com`, `support.apple.com`, `opensource.apple.com` and
  `zsh.sourceforge.io` (other fetches and web searches still prompt); its local
  snapshot script contains no URL request and omits personal machine data.
  `compozsh-release-draft` asks the agent to read this project's public GitHub
  release metadata and tag resolution using only public, unauthenticated
  reads, never the user's credentials, an authenticated session or `gh`, and
  pre-approves page reads from `github.com` and `api.github.com`; those reads
  run without a per-request prompt from the contributor's machine. Its
  instructions prohibit sending repository contents, local paths,
  credentials, or private remote parameters in those requests; the agent, its
  provider, and GitHub retain their own network and data policies. Neither
  skill pre-approves shell commands beyond the platform snapshot script and
  `sw_vers` version queries. The shared `.claude/settings.json` pre-approves
  only `zsh tests/run.zsh`, `zsh tests/verify.zsh` and `zsh -fn -- <file>`
  syntax checks (the `--` keeps later arguments from re-enabling execution).
  Pre-approving the runner means an agent can run the working tree's own test
  code without a shell prompt, relative to its current directory. The file
  denies Claude Code reads and edits of `~/.zshrc`, `~/.zshenv`, `~/.zprofile`,
  `~/.zlogin`, `~/.zsh_history`, `~/.zsh_sessions/` and `~/.zsh.addons/`;
  those rules also cover recognized shell file commands such as `cat`, `tee`
  and `sed` and input or output redirections, but not other programs or
  scripts, and a custom `ZDOTDIR` or `HISTFILE` lives elsewhere. It registers a local hook
  that runs `zsh -fn` on an edited Zsh file and reports the first parse error.
  None of it adds network access.

### Static website

The optional `docs/` website is static and self-contained. Its Content Security
Policy uses `connect-src 'none'`; JavaScript has no fetch, beacon, WebSocket, or
remote script path. Links and canonical metadata point to the official GitHub
project, but a network navigation occurs only when the browser loads the hosted
page or the user follows a link. GitHub or another chosen host may retain normal
web-server access logs; that hosting boundary is not controlled by the static
files in this repository.

The interactive examples run entirely on fixed synthetic data in page memory.
They execute no shell code, read no user configuration or visitor files, and
use no browser storage, clipboard access, provider lookup or network request;
reloading or closing the page discards their state, and re-entering an example
resets its controls. The composition model's three fixed peer labels and its
loading-order and repeated-load controls change only that illustration. The
Context tab switches among fixed synthetic prompt moments and never inspects
the visitor's terminal, clock, command line, filesystem, Git repository,
environment, or project metadata. Help → Compose accepts at most 120 characters
per field and quotes them into a displayed sample; Replace draft changes only
an editable page control, never submitting a command, and reset discards the
values. Do not enter secrets in the demo. The Change atlas groups six fixed
synthetic entries. Picker and Git-review filters accept at most 120 characters
per field and derive results from fixed sample paths, labels and context; the
Git example keeps view choice, folds, selection and reading positions in page
memory and summarizes three synthetic entries. Keyboard guides keep only their
caller's browser focus. These illustrative limits are
separate from the native tool contracts above.

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
Zsh: the bootstrap loads an untracked `.zsh.<name>` file in the clone, and
compiles it into the [compiled mirror](#compiled-peer-mirror), as a shipped
peer.

Inspect the only automatic source boundary:

```sh
cat .zshrc
git grep -nE '(^|[[:space:]])(source|eval)[[:space:]]' \
  -- .zshrc install.zsh '.zsh.addons/**' templates
```

The tracked bootstrap sources the optional machine-local initializer and every
matching peer beneath the repository and user add-on directories, excluding the
reserved `support/cache` data directory, the `support/compiled`
mirror, `.zwc` files and hidden folders. A shared peer may run from that
[compiled mirror](#compiled-peer-mirror) only under its checks
(`zsh tests/run.zsh 'compiled peers'`). Before any peer loads, the bootstrap may
run the shipped `.zsh.addons/support/compile.zsh` in Apple's `/bin/zsh -f` from
`/`, which
compiles (parses, never runs) shipped peers into that mirror. Discovery runs
under fixed Zsh options, so glob options set by the initializer or a peer
cannot widen it
(`zsh tests/run.zsh 'peer discovery ignores glob options'`). An explicit
`ZSH_LOCAL_INIT` must be an absolute path: the bootstrap ignores a relative
initializer path with a diagnostic and never resolves it against the current
directory (`zsh tests/run.zsh 'relative ZSH_LOCAL_INIT'`). The tracked
starter is inert, but an existing private initializer or peer is user-owned
code and must be audited separately. Within that boundary, peers autoload
stock Zsh functions from `fpath` (such as `compinit` and
`add-zle-hook-widget`), and `.zsh.editor`'s `compinit` also sources Zsh's own
[completion dump](#native-completion-dump) from the configuration base (or,
while it is provably unchanged, its compiled copy in that mirror, after which
the same `compile.zsh` may compile a new or changed dump) and autoloads
completion functions. Compozsh adds no `fpath` entry, and neither
path comes from the current directory while `fpath` holds only absolute
directories; an inherited relative `FPATH` entry would make `autoload` search
the current directory.

Search the executable shell surface for common network clients:

```sh
git grep -nE -e '(^|[;&|[:space:]])(command[[:space:]]+)?(/usr/bin/)?(curl|wget|ssh|scp|sftp|nc|netcat|socat|telnet|rsync)([[:space:]]|$)' \
  --and --not -e '^[[:space:]]*#' \
  -- .zshrc install.zsh '.zsh.addons/**' templates
```

Full-line comments are excluded, matching the native regression check; the
prompt classifier mentions network clients as inert draft text. The command
should print no matches and return status 1. This is a useful regression check,
not proof by keyword absence; also read new command execution, redirection,
dynamic function dispatch, and source paths in the diff.

Audit the worktree action boundary before exercising it:

```sh
git show HEAD:.zsh.addons/.zsh.git-worktree
git show HEAD:.zsh.addons/.zsh.navigation
zsh tests/run.zsh 'worktree '
```

Read the fixed Git policy in `_git_worktree_git`, complete-capture and
streamed-listing checks, creation/removal validation and post-screen dispatch.
The tests cover aliases/fallbacks, exact targets, refusals, move preservation
of local files, branch preservation and native keyboard/screen behavior.

Audit the living prompt's local presentation boundary:

```sh
git show HEAD:.zsh.addons/.zsh.prompt
git show HEAD:.zsh.addons/.zsh.editor
zsh tests/run.zsh 'living prompt'
```

Read the ordinary `precmd` fact capture and its repeat after an in-widget
directory change, the bounded Context trigger fingerprint, the private
compact/lens/transcript modes, the Context/Interaction renderers, and the
editor peer's line-init/pre-redraw/line-finish transitions, post-cleanup
directory-change recapture and `compozsh-context-lens` Option-I widget. The
tests check that READY, operation-specific, advisory, assignment-value,
autosuggestion, pin, transcript and resize behavior preserve the exact ZLE
buffer, replace providers and executables with sentinels to keep Interaction
edits inert, and instrument provider calls in a resize PTY. They also check
that Change directory and Enter linked directory recapture the new folder's
facts and title while keeping the draft and a manual pin, without a `precmd`
or history entry.

Audit alias previews and manual capture without reading private shell settings:

```sh
zsh tests/run.zsh 'alias coverage'
zsh tests/run.zsh 'tool descriptions'
zsh tests/run.zsh 'manual coverage'
zsh tests/run.zsh 'manual summaries'
```

Read `_prompt_alias_expansions` and the `.zsh.manual` capture/reader/formatter
helpers alongside these tests. Fixtures cover current, quoted and suppressed
aliases, nonexecution during native ZLE painting, MANPATH ordering,
links/compression/forwarding, literal configuration, unavailable NAME
summaries, and inert formatter command requests and caller-folder includes.

Audit Simulator and device monitoring without launching Xcode or a real app:

```sh
git show HEAD:.zsh.addons/.zsh.xcode
zsh tests/run.zsh 'Xcode run'
zsh tests/run.zsh 'Xcode Logger'
zsh tests/run.zsh 'Xcode logs'
zsh tests/run.zsh 'Xcode monitor'
zsh tests/run.zsh 'Xcode device monitor'
zsh tests/run.zsh 'log reader'
zsh tests/run.zsh 'log copy'
zsh tests/run.zsh 'editor reader'
```

Read `_xcode_run_session`, which declares both modes' Run state once and owns
their pipe and cleanup, with its mode `prepare`, `start` and `stop` helpers and
`_xcode_run_attach`; then `_xcode_run_identity`, `_xcode_run_idle`, their scoped
log-observer and `_xcode_logs_*` helpers, the Copy-and-reopen loop
`_xcode_run_screen` both modes share, the shared picker's screen cleanup, and
for device consoles `_xcode_device_poll`.
Check literal launch arguments, owned-job termination, failure preservation,
temporary FIFO permissions, post-screen cleanup and clipboard dispatch, copy
payload bounds, matching and exclusion over captured text, following and
paused/Options capture boundaries, full-reader returns that keep the app
running, the exact device and installed-executable predicate, child-only
`LOGRC` and unbuffered launch settings, the readiness bound, fair draining and
line bounds, source failure disclosure, and observer stop/reap before LLDB and
on cleanup. The tests also cover malformed launch responses, frozen reading,
native PTY resize/guide/cancellation, identity replacement and failure status.

For each `git show HEAD:...` block, run against the exact checkout being
audited; before commit, read the corresponding working files instead.

Audit website connection primitives and all hard-coded destinations:

```sh
git grep -nE 'fetch\(|XMLHttpRequest|WebSocket|sendBeacon|src="https?://|@import' -- docs
git grep -nE 'https?://|wss?://|ftp://' \
  -- .zshrc install.zsh '.zsh.addons/**' templates docs .claude
```

The first command should print no matches. The second is intentionally broad:
review every URL. Expected tracked URLs are documentation comments, official
project links and website metadata. The optional platform-audit inventory also
runs `/usr/bin/curl --version`; it records the installed binary's version and
does not give curl a URL.

Review local storage and sensitive effect boundaries:

```sh
git grep -nE 'HISTFILE|compinit|mktemp|\.zsh-backups|pbcopy|sudo|/dev/(r)?disk|diskutil|createinstallmedia' \
  -- .zshrc install.zsh '.zsh.addons/**' templates README.md
```

Check that data never passes through Zsh's temporary-file redirections:

```sh
git grep -n -e '<<' -- .zshrc install.zsh '.zsh.addons/**' templates
git grep -nE '(^|[[:space:];|&(])=\(' -- .zshrc install.zsh '.zsh.addons/**' templates
zsh -fc 'print -r -- <(:) >(:)'
zsh -fc 'grep -n "=(<<<" /dev/null $^fpath/edit-command-line(N)'
```

The first command prints four lines and no redirection: quoted operator
patterns in the prompt's command classifier (two in `.zsh.prompt`, one in
`.zsh.pure.compozsh_is_redirection`) and the `%<<` prompt truncation escape in
`.zsh.pure.zle_picker_abbreviate`. The second prints nothing and returns status
1. The third prints two `/dev/fd/N` paths, showing that process substitution
uses pipes. The fourth shows the one line of Zsh's stock `edit-command-line`
that writes the Ctrl-X Ctrl-E draft to a temporary file, as disclosed in the
inventory.

Finally run the isolated regression suite:

```sh
zsh tests/run.zsh
```

Tests improve confidence in documented behavior but do not replace source
review. A new commit is new code and should be compared before it becomes the
active symlinked configuration.

### Focused regression checks

Run one boundary's checks with `zsh tests/run.zsh '<filter>'` from the
repository root; a filter selects every test whose description contains it,
ignoring case. Expected result: all selected tests pass. The tests use isolated
homes, synthetic fixtures, disposable repositories and command stand-ins; they
read no private configuration or real cache contents and contact no remote
server.

| Boundary | Filters |
| --- | --- |
| Appearance, contrast and plain output | `appearance` |
| Shared screens and native ZLE cleanup | `UI`, `picker screen` |
| Living prompt buffer preservation, inert edits and the in-widget directory-change recapture | `living prompt` |
| Terminal title without assignment values | `running-command title` |
| Display control sanitization, including UTF-8-encoded C1 in every locale | `sanitiz`, `encoded C1` |
| READY toolchains without extra reads or probes | `runtime prompt` |
| Help workspace capture, fallback and cleanup | `help workspace` |
| Tool descriptions and alias previews | `tool descriptions`, `alias coverage` |
| Draft inspector | `task experience` |
| Command composer | `command composer` |
| Runtime metadata bounds and installed-runtime probes | `runtime versions`, `bounded direct metadata`, `prompt probes installed runtimes` |
| Manual capture, formatter and transport | `manual coverage`, `manual summaries`, `manual async` |
| Public manual cache and installer exclusion | `manual cache`, `cache data`, `installer excludes generated` |
| Native completion dump call, path, contents, mode and `--clean` survival; its compiled copy's freshness, fallbacks and rewrite | `native completion dump`, `clean installer touches only`, `compiled completion dump` |
| Compiled peer mirror: freshness, ownership, parse context, `/bin/zsh` only, startup recompile, locking, size bound, Git ignore and installer lifecycle | `compiled peers` |
| Installer rollback after failures and signals, copy staging name and cleanup | `installer` |
| Matching and exclusion | `exclusion`, `matching component` |
| Captured-data parsing without temporary files | `here-string`, `filter override builder`, `worktree removal` |
| Captured, setting and inherited text kept out of arithmetic | `never splices text into arithmetic`, `stay text`, `overflowing`, `hostile`, `inherited`, `stat numbers`, `dd parser`, `validates width text` |
| Shared effects and data | `shared effects`, `shared data` |
| Picker digits and slot acceptance | `numeric`, `detail panels preserve native` |
| Path + Tab directory arguments | `directory argument` |
| Bracketed paste | `picker nonpaste CSI`, `picker interrupted paste` |
| Job lifecycle | `job lifecycle` |
| Git file review and Change atlas | `Git tree`, `Git atlas`, `Git review native g` |
| Branch catalog and remote fallback | `absent from the reflog`, `branch remote` |
| Git filter, selector, Files, promisor and signature-verifier controls | `shared Git`, `Git selectors`, `Files Git`, `promisor fetch`, `signature verifier` |
| Direct Apple Git behind `/usr/bin/git`: signature, identity, selectors, `PATH` choice and refresh | `git shim` |
| Without Apple's developer tools, the prompt's Git context and runtime probes and Search's default source run no `/usr/bin` Git, `xcrun`, compiler, `swift` or `python3` launcher | `without developer tools` |
| Without a JDK, the prompt's Java probe runs no `/usr/bin/java` stub, and its file tests count only runtimes the stub could start | `Java stub` |
| Git comparison bounds | `Git comparison` |
| Discard with a dirty submodule | `g --discard-all preserves dirty submodule` |
| Worktrees | `worktree ` |
| Xcode discovery | `Xcode discovery` |
| Xcode Run, device console and logs | `Xcode run`, `Xcode monitor`, `Xcode device monitor`, `log reader`, `log copy`, `editor reader` |
| Task routing and external-device modes | `task families` |
| USB progress, phase and disk-size number bounds | `USB numeric bounds` |
| External media writes, read-back and temporary files | `USB raw`, `USB verification`, `USB temporary`, `ISO inspection`, `external-media temporary` |
| Source disk excluded from targets; media on a virtual disk refused | `USB source exclusion` |
| External device captures released when the task returns | `USB invocation state` |
| Apple signature before `createinstallmedia` runs as root | `USB Apple signature boundary`, `USB macOS` |
| Touch ID policy in unprivileged fixtures | `sudo Touch ID` |

These checks do not establish: an operating-system sandbox or OS protection
boundary; defense of a compromised account; atomicity against concurrent
external writers, ref or configuration changes, or filesystem mutation; Git
server freshness; visual behavior in Terminal.app on every Mac, arbitrary
terminal profiles' contrast, or how a custom terminal stores scrollback;
mounted-filesystem availability or latency; exhaustive shell grammar, manual
formats or `CAUTION` coverage; arithmetic in code held in single-quoted
strings, such as the fixed `sudo` routines, which the arithmetic scan does not
lex; version-manager shim behavior; macOS application behavior or prevention of
clipboard synchronization; for external media, real device writes, `sudo`,
`diskutil`, `hdiutil` or `createinstallmedia` behavior; or, for Xcode,
Simulator FIFO support, native log privacy behavior, complete log delivery,
signing permission or LLDB attachment on the host.

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
[GitHub private vulnerability
reporting](https://github.com/bitbemol/compozsh/security/advisories/new) when it
is available. If that route is unavailable, open a minimal issue asking for a
private reporting channel without including the sensitive details.

Include the affected commit ID, macOS and Zsh versions, the smallest synthetic
reproduction, the observed data or privilege boundary, and whether credentials
may have been exposed. Revoke or rotate exposed credentials immediately; a
source-code fix cannot make a disclosed secret private again.
