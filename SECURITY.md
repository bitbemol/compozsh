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
with a digit bound unless the fixed output format of `/usr/bin/stat` or
`/usr/bin/cksum` already bounds the field; names such as paths and branches
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
| Native completion dump | `${ZDOTDIR:-$HOME}/.zcompdump`, written by Zsh's stock `compinit` (called bare by `.zsh.editor`) when a fresh shell finds it missing or its `fpath` file count or Zsh version changed; persists until deleted, including after `--clean` and uninstall | [Zsh-generated shell code](#native-completion-dump) that `compinit` sources: the count, Zsh version and the verbatim first-line words of `fpath` completion files (normally function, command, service, pattern and key names), private entries included, plus completion widget bindings. No `fpath` directory paths, file bodies, history, environment values or project data. Mode follows the umask at write time (0644 under the default 022); an interrupted write can leave `.zcompdump.<host>.<pid>` |
| Private initialization and peers | `${ZDOTDIR:-$HOME}/.zsh.addons` | User-owned machine setup and extensions loaded by the bootstrap |
| Recovery copies | `${ZDOTDIR:-$HOME}/.zsh-backups/compozsh-*` | Configuration the installer replaced, preserved instead of deleted |
| Optional sudo Touch ID policy | `/etc/pam.d/sudo_local` until explicit disable; `/etc/pam.d/.compozsh-sudo-touch-id.*` during enable and after an abnormal interruption | Three fixed lines enabling Apple's `pam_tid`, created only by `compozsh --sudo-touch-id enable`; ACL-free, `root:wheel`, mode `0444` before publication |
| Prompt, appearance, and picker facts | Shell memory; discarded with the shell or view | Color-scheme classification, runtime versions, Git state, paths, Context trigger/disclosure flags, positive/exclusion fields and their bookmarks, temporary view snapshots |
| Local manual summaries | Shell memory until refresh, discovery-selector invalidation or shell exit | Bounded NAME descriptions and page-name/section attribution from the [manual roots](#local-manual-summaries); describes literal names, not executable identity |
| Manual background transport | Shell memory, native PTYs and an unlinked kernel FIFO during one request | At most 16 MiB / 8,192 records in 8-KiB reads from one capture process under two supervisors; mode-0600 FIFO in a mode-0700 `${TMPDIR:-/tmp}/compozsh-manual-async.*` directory, both unlinked once opened; no regular file of descriptions or selectors |
| Public OS manual cache | `${ZDOTDIR:-$HOME}/.zsh.addons/support/cache/.zsh.manual.cache`, until refresh/replacement/removal | Protected OS manual NAME descriptions, aliases, relative page IDs and a public freshness key, owner-only and inert; `.zsh.manual.lock` and bounded `.zsh.manual.cache.*` staging residue. No private selectors or custom manuals |
| Manual formatter directory | Private mode-0700 temporary directory during capture | Empty mandoc working directory; page text stays in bounded memory and pipes, never a file. Removed on cleanup; an uncatchable termination can leave it empty |
| Interaction lens state | Shell memory for the active prompt; replaced as buffer or outcome changes, discarded with the shell | Interaction kind, sanitized bounded excerpts and structural summaries, up to eight 240-character alias previews, context anchors, latest outcome, a bounded autosuggestion prefix; never leading assignment values |
| Draft inspector | Invocation memory, only after Option-Return; released on return | At most 32,768 literal draft characters plus a truncation notice, cursor/length/current-folder facts, reading filters and frames; can display sensitive text, unredacted and unexecuted |
| Captured help and command readers | View-scoped shell memory | Tool help: at most 64 same-source companions of 32,768 characters each (direct help: only its companion). History inspector: at most 32,768 characters of the selected command, no second history catalog |
| Command composer | Invocation memory; an accepted draft moves to ZLE or the native buffer stack until edited, submitted or discarded | Literal prefill and fields of at most 4,096 characters each, current folder, generated quoted draft; optional local ref capture for Git revisions. No file, clipboard or custom history write |
| Git Change atlas | View-scoped shell memory; released on return | Path-prefix groups, entry-count bars and bookmarks from the captured file list, staged/unstaged distinct. No discovery, bulk content read, saved atlas or new worker |
| Git Tree / All files navigation | Current review's shell memory; released on review exit | Directory prefixes, folder summaries (change states, child areas, captured numstat) and expansion/filter/scope/selection state from the 1,000-entry/256-KiB list; ancestor choices at most 200 rows/262,144 prefix characters, with a partial notice. No discovery, saved preference or new worker |
| Living prompt receipts | Ordinary terminal display and terminal-owned scrollback | A local `HH:MM` timestamp and the exact submitted command in each command receipt, plus status/duration in applicable outcome receipts; Compozsh writes no receipt log, and terminal retention follows the user's terminal settings |
| Prompt tool descriptions | Current-shell memory; cleared on shell exit or invalidation | At most 64 same-source command/help pairs; up to 262,144 characters of source/definition identity; 240-character summaries and option descriptions from at most 4,096 characters per guide plus the Touch ID subguide. No disk cache |
| Git comparison choices and snapshots | View memory, released on view exit | At most 1,000 refs/256 KiB of names, kinds and object IDs; resolved endpoints, paths and bounded diff snapshots. No saved comparison catalog |
| Git branch picker | Shell memory; catalog replaced on the next invocation or shell exit, details cleared on view exit | All local branch names (no count cap), ordered by current branch and up to 200 checkout reflog entries, then other refnames; details at most 262,144 characters across 401 refs, 512 per subject. No fetch, saved history or background refresh |
| Known remote branch fallback | Invocation memory until `g` returns; tracking configuration and a created local branch persist in the repository only after confirmation | Up to 1,000 remote-tracking ref names and commit IDs / 256 KiB, and 128 remote names / 32 KiB; no remote URLs. No fetch, pull or disk cache |
| Git Working changes refresh transport | One mode-0700 `${TMPDIR:-/tmp}/compozsh-review.*` directory with a mode-0600 FIFO, plus screen-scoped worker/provider processes and shell memory | One framed local status/selected-diff candidate at a time, at most 1 MiB; no log, daemon or persistent review cache |
| Created Git worktrees | Explicitly selected new folder; branch refs and registration in the repository's Git common directory | Created only on `g --worktree` acceptance; persists until explicit Git/workspace removal, which preserves branches, and survives Compozsh uninstall |
| Temporary operation captures | `${TMPDIR:-/tmp}` | USB disk metadata, ISO listings, progress, read-back, GPT headers and image mount points ([names and exceptions](#external-media-temporary-files)), bounded Xcode discovery output, transient test-result bundles, Git syntax transport FIFOs (not source files); validated paths removed on normal and handled-error cleanup |
| Simulator run output | Run-scoped shell memory and two pipes beneath the selected Simulator's data/tmp; released at run exit | Stdout/stderr and unified logs of the exact installed executable: tail and frozen snapshots each at most 32 KiB/200 source lines, 8 KiB unfinished line per source; reader state; launch PID, observed identity, executable and data-directory paths. No log file; native log privacy behavior can expose sensitive app values |
| Explicit physical-device app installation and console | The selected device, under Apple's tools and storage policy; a run-scoped local FIFO and shell memory | `devicectl` replaces the app's installed copy, which stays after console exit or failed launch. Monitoring keeps at most 32 KiB/200 source lines plus snapshots via a mode-0600 FIFO in a mode-0700 directory, removed on cleanup. No log file |
| Command line opened in an editor | One mode-0600 file under two hard-linked names, `${TMPPREFIX:-/tmp/zsh}XXXXXX` and the same name plus `.zsh`, written by Zsh's stock `edit-command-line` widget, only on an explicit Ctrl-X Ctrl-E, while `$VISUAL`/`$EDITOR` runs (Zsh writes the draft directly into that file); Zsh removes both names when the editor returns, and an abnormal termination can leave both | The complete draft, including continuation lines, which can hold anything typed on the command line. The editor's own swap, backup, undo or history files follow the editor's settings |
| Exported Apple skills | Detected coding agents' local skill directories | Created only by an explicit `xcode --export-skills` invocation and marked for safe refresh |
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
runs `rehash`. At the next TTY prompt it also requests replacement of eligible
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
arithmetic. Completion and printable-stack colors follow terminal capabilities
and `NO_COLOR`; manual-page selection contrast uses fixed indexed-color
arithmetic. Reference RGB colors do not establish contrast
for arbitrary terminal profiles. Inspect `.zsh.addons/support/.zsh.appearance`,
`.zsh.addons/support/ui/`, and the `.zsh.output`, `.zsh.editor`,
`.zsh.navigation` and `.zsh.prompt` peers.

**Shared screens.** The `support/ui/` peers own views, input, painting and
screen restoration. Layout, resize, disclosure navigation, rewrapping (with a
bounded source-row map), row spacing, focus expansion and per-paint styles
derive only from captured facts, the current palette and terminal dimensions:
they discover, capture and execute nothing and keep no copy of the user's draft
beyond screen-restoration state. The input dock places the caret through ZLE's
PREDISPLAY/POSTDISPLAY, restored by paint, without putting query text in the
caller's buffer. View state is scoped to the feature callback; secondary menus
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
This covers lens derivation and repaint, not the complete ZLE pre-redraw hook
chain: the independent syntax highlighter keeps bounded filesystem checks for
literal path tokens without evaluating substitutions or globs. READY keeps
captured toolchain facts visible after acceptance and screen clearing, within
display bounds; this extends visibility, not capture scope or lifetime. Row
vocabulary is specified in [the prompt contract](engineering/prompt.md).

- Rows labeled `… TEXT`, including `ENDPOINT TEXT`, are sanitized,
  width-bounded buffer excerpts that do not prove a path, endpoint, query or
  operation exists. Context rows reuse the prior `precmd` capture. `PIPELINE`
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
the real buffer. The public project-segment extension accepts only a `0`–`255`
color index or a fixed basic Zsh color name; an invalid color falls back
through the validated `tool` role or native text before reaching prompt syntax.

A transcript repaint changes only decoration; ZLE keeps the exact submitted
command, and Compozsh keeps no separate command store. Empty and
whitespace-only submissions receive the same receipt without changing their
literal buffer, executing an extra command or adding history. The `LAST` row is
replaceable shell-memory status for the latest command, including fast
success. Command receipts, plus outcome receipts for failures and slow
successes, become terminal display and terminal-owned scrollback; compaction
neither conceals nor removes submitted command text from the terminal or Zsh
history (see [Secrets on the command line](#secrets-on-the-command-line)).

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
prompt's existing fact-capture boundary. Loading them defines functions and
shell-memory data only: it inspects no project, probes no executable, installs
no toolchain and registers no background task. Numeric comparison consumes
supplied strings, separately from metadata observation. README's **Project and
runtime context** section documents the sources and precedence. Besides simple
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

`.zsh.editor` runs Zsh's stock `compinit` with no options once per fresh shell;
re-sourcing skips it while `_comps` exists, and if the initializer or an
earlier private peer already ran `compinit`, that call owns the dump instead.
Without `-d`, `-C`, `-i`, `-u` or `-D`, `compinit` keeps its full `compaudit`
ownership and permission check of `fpath` (an interactive prompt can exclude
insecure entries or abort) and its default dump path,
`${ZDOTDIR:-$HOME}/.zcompdump`, resolved when it runs and with no Zsh-version
suffix. Compozsh adds no `fpath` entry, leaves completion's `use-cache` style
off (so it writes no `.zcompcache`) and never compiles the dump.

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
  `.zcompdump.zwc` no older than the dump if another tool created one.

Independently read the call and Zsh's own implementation:

```sh
git grep -n -e compinit -e compdump -e zcompile -e fpath -e use-cache \
  -e cache-path -- .zshrc install.zsh templates '.zsh.addons/**'
zsh -fc 'print -rl -- ${^fpath}/(compinit|compaudit|compdump)(N)'
ls -l "${ZDOTDIR:-$HOME}/.zcompdump"
```

The first command should list only `.zsh.editor`'s `autoload -Uz compinit`
line, its bare `compinit` call and two comments, plus the two commented
`fpath` lines in `templates/init.zsh`; the second prints the stock functions
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

Zsh 5.9's `wait` and `jobs` builtins scan prior completed records when `NOTIFY`
is off, even with an exact operand. Cleanup therefore uses a narrowly scoped
`MONITOR`-off, `NOTIFY`-on section and restores caller options afterward. This
avoids that broad scan and keeps already-pending unrelated completion records.
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
suspension, cleanup conservatively keeps the earlier nonzero stop status. Other
owned children (Git review worker, manual capture supervisors, Xcode discovery
supervisor and Run observer) are stopped and reaped as their sections describe.

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
reflog. When nothing local matches, the fallback reads `git remote` names and
`for-each-ref refs/remotes/` through the same local-only provider controls,
and further unmatched filters reuse that snapshot.
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
captures refuse the action. Compozsh writes no worktree catalog or navigation
history. Git may take longer than these output bounds suggest on slow storage.

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
(262,144 by default, minimum 4,096) and diagnostics at most 8,192 bytes,
enforced while the command runs, including bytes in temporary files; readers
hold one 8-KiB chunk while discarding excess. Two-byte completion records
identify finished synchronous streams; incomplete captures and stdout overflow
are rejected unparsed. Streams stay separate, the native status is kept within
the limit, and byte bounds impose no duration limit. Cleanup removes the private
capture directory. **Scheme and destination discovery** streams through three
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
targets; product paths and validated bundle identifiers stay in invocation
memory. Several qualifying products require an explicit choice, no filesystem
search infers one, and a symlink leaf or vanished product is rejected before
handoff, not atomically. A Mac app opens as a new instance through native
`open`, with the chosen architecture and no process monitor; a command-line
product runs in the restored terminal with native output and status. App code
has its own access and network behavior.

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
`SIMCTL_CHILD_NSUnbufferedIO=YES` affects only that child, not the shell or log
privacy. Launch metadata uses the temporary capture boundary; app output never
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
discovery or private skill-directory scan; mode help is inert. Inspect
`.zsh.addons/.zsh.xcode`.

### External devices and task routing

Bare `external-device` presents two fixed task choices without reading disks or
images; choosing one closes that screen before its normal scoped capture. USB
review and the flash and format modes keep their separate exact-device
confirmations ([Administrator boundary](#administrator-boundary)). Shared pure
USB readers validate supplied SHA/CRC text and native progress records without
consulting caller-local variables or reading devices; raw and Windows execution
share digest validation, while media-specific preflight, checksum requirements
and final verification stay with their effect owners. Progress byte counts,
verification-phase totals, installer percentages, diskutil `TotalSize` and
`DeviceBlockSize`, and GPT header fields read from images or devices are
validated as decimal text of at most 18 digits before arithmetic, and progress
stage names are compared literally, so this text never reaches arithmetic as an
expression or an out-of-range number. The GPT backup entry location is
range-checked by subtraction against the image's last sector, and against the
target's last sector during verification, before its byte offset is computed. Each verification progress poll reads its phase record with one
no-follow, nonblocking native read of at most 1,025 bytes and ignores a record
longer than 1 KiB; the raw-read progress capture it also polls is read only when
it is at most 1 MiB, measured by `/usr/bin/stat`. Only the first
line is parsed; it needs exactly three tab-separated fields, and anything else
keeps the preparing message, and the metadata never reads or modifies caller variables or runs
commands. Installer candidate labels
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

### Installer backups and temporary residue

The installer never prints the contents of an old `.zshrc` or private add-on,
but a recovery backup can contain secrets that were already present there.
Protect and eventually archive or remove those backups according to your own
retention policy; Compozsh deliberately does not delete them automatically.

An uncatchable process termination or system failure can leave a temporary
capture behind; its validated `compozsh-*` name makes it identifiable in
`${TMPDIR:-/tmp}`. For Git review this can be an empty mode-0700
`compozsh-review.*` directory containing its mode-0600 FIFO; provider output is
streamed through pipes and is not persisted there. Normal exit removes both;
after an uncatchable termination, the user may inspect and remove the
identifiable directory. Other feature-specific residue (manual transport and
formatter directories, cache and completion-dump staging files, Xcode test
bundles, device and Simulator run directories, interrupted worktree creation,
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
[inventory](#complete-local-data-inventory)). Assignment
values are omitted only from the Interaction lens's secondary presentation; the
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

### External media temporary files

`external-device` keeps its captures in shell memory except for these
`/usr/bin/mktemp` names directly beneath `${TMPDIR:-/tmp}`, created as mode
`0600` files or `0700` directories owned by the invoking user. Privileged
output reaches them only through redirections opened by that user's shell; no
`sudo` command receives a temporary path.

| Name | Created during | Contents and bounds |
| --- | --- | --- |
| `compozsh-usb.*` | Each `diskutil … -plist` capture: external disk list, disk or volume info, filesystem catalog | One property list: disk and volume identifiers, names, mount points, sizes, UUIDs and device-tree facts, or the filesystem catalog's names and size limits. No size cap on disk; output above 1 MiB is rejected unread |
| `compozsh-usb-iso.*` | ISO classification | The selected ISO's `tar -tf` path listing, at most 16 MiB + 1 byte |
| `compozsh-usb-inspect.*` | ISO classification when that listing is inconclusive | Read-only, `nobrowse` `hdiutil` mount point. While attached it presents the image's file tree with the mount's own permissions (observed `0755` with an ISO 9660 fixture; check with `stat -f %Lp` on the attached mount point), so other local users can read it only through a traversable parent such as `/tmp`; the default per-user macOS `TMPDIR` is owner-only. The mount path itself is visible to them in `mount` and `df` output |
| `compozsh-usb-progress.*` | Raw image write, including `flash-verify` read-back inside the same privileged session | Standard error of that session: `dd` write and read-back progress and record counts, fixed `compozsh-write-*` stage and result markers, and native error text that can name the image or device. No size cap on disk; read in steps of at most 1 MiB |
| `compozsh-usb-verify-progress.*`, `compozsh-usb-verify-meta.*`, `compozsh-usb-verify-result.*` | Only the post-write read-back fallback (below) | Privileged `dd` read progress and native error text (no size cap on disk; not read above 1 MiB, which fails the comparison); one fixed phase label with the compared byte count and the byte offset within the first read block; one `scope=` and one `error=` line from fixed vocabularies |
| `compozsh-usb-primary-gpt.*`, `compozsh-usb-backup-gpt.*` | Only that fallback, for a hybrid GPT image whose full comparison differed | Raw 512-byte copies of the target's LBA 1 and final LBA: normally GPT headers carrying the written image's disk GUID, otherwise whatever those sectors held |
| `compozsh-usb-read.*` | Only a read-back comparison outside that fallback's worker, which no shipped caller makes | `dd` read progress and native error text. No size cap on disk; not read above 1 MiB, which fails the comparison |
| `compozsh-createinstallmedia.*` | Apple `createinstallmedia` | Its combined standard output and error. No size cap on disk; ignored above 1 MiB |
| `compozsh-usb-windows.*`, `compozsh-windows-readonly.*`, `compozsh-windows-verify.*` | Only the retired `_usb_windows_execute` writer, which no public path reaches (`_usb_media_execute` refuses Windows media) | Read-only ISO and target mount points; per-file `dd` read progress |

The post-write read-back fallback, `_usb_verify_payload`, runs only after a
write that succeeded without in-session verification. Current `flash-verify`
never produces one: `_usb_execute` requests verification inside the privileged
write session, and `_usb_write_image` then reports success only after that
session's `compozsh-write-verified` marker; `flash-only` skips read-back. When
the fallback runs, its progress poll also reads the fixed phase label and two
integers from `compozsh-usb-verify-meta.*` every 0.25 seconds with one bounded
native read; no here-string or other temporary file is involved.

Each capture file lives only inside the function that created it, whose
`always` block removes the exact path `mktemp` returned on normal return,
handled failure or an interrupt that unwinds Zsh. An interrupt in the instant
between a `mktemp` call and the start of its `always` block, including between
the fallback's consecutive `mktemp` calls, can leave that file. Most sites also
recheck the
`compozsh-` name and `${TMPDIR:-/tmp}` parent first; the verification, GPT and
read files rely on the exact path alone. Progress views first wait for their
native worker to exit, because a command started with `&` while the `MONITOR`
option is off ignores `SIGINT` (`man zshmisc`, SIGNALS). A second interrupt
during that wait skips the rest of the `always` block: the privileged worker
keeps running after `external-device` returns, its capture file remains, and
the outer cleanup can request `diskutil eject` while the write continues. A
mount point is removed the same way, but only after `hdiutil detach` succeeds;
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
`ls -ld "${TMPDIR:-/tmp}"/compozsh-(usb|windows|createinstallmedia)*` (no
residue: `no matches found`, status 1) and `hdiutil info` (no residue: no
`compozsh-usb-inspect.*` mount point); release an attachment with
`hdiutil detach /dev/diskN`, then remove its empty directory with `rmdir`. Read
the creation and cleanup sites with
`grep -n -e mktemp -e 'rm -f' -e rmdir .zsh.addons/.zsh.usb`.
`zsh tests/run.zsh 'USB temporary'` uses stand-ins for `diskutil`, `hdiutil`,
`dd` and `createinstallmedia` to check removal after success and handled
failure, and each name and mode while it exists, for every name except
`compozsh-usb-iso.*` (removal only; `tar` has no stand-in seam) and the retired
Windows names. `zsh tests/run.zsh 'ISO inspection'` covers the failed-detach
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
text and does not create a connection.

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
  revalidates repository, HEAD, operation (including Git's sequencer directory,
  before and after), filter-name and listed-path state. An existing index lock
  refuses before writes and is never removed. Native untracked cleanup runs
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
  filesystem monitors, optional writes, lazy fetches and transport, so
  repository-configured fsmonitor commands cannot run during `ls-files`.
  Inspect `.zsh.addons/.zsh.find`.

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
Zsh because the bootstrap intentionally loads matching private peers too.

Inspect the only automatic source boundary:

```sh
sed -n '1,220p' .zshrc
git grep -nE '(^|[[:space:]])(source|eval)[[:space:]]' \
  -- .zshrc install.zsh '.zsh.addons/**' templates
```

The tracked bootstrap sources the optional machine-local initializer and every
matching peer beneath the repository and user add-on directories, excluding the
reserved `support/cache` data directory. The tracked starter is inert, but an
existing private initializer or peer is user-owned code and must be audited
separately. Within that boundary, peers autoload stock Zsh functions from
`fpath` (such as `compinit` and `add-zle-hook-widget`), and `.zsh.editor`'s
`compinit` also sources Zsh's own [completion dump](#native-completion-dump)
from the configuration base and autoloads completion functions. Compozsh adds
no `fpath` entry, and neither path comes from the current directory while
`fpath` holds only absolute directories; an inherited relative `FPATH` entry
would make `autoload` search the current directory.

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

Read the fixed Git policy in `_git_worktree_git`, complete-capture checks,
creation/removal validation and post-screen dispatch. The tests cover
aliases/fallbacks, exact targets, refusals, move preservation of local files,
branch preservation and native keyboard/screen behavior.

Audit the living prompt's local presentation boundary:

```sh
git show HEAD:.zsh.addons/.zsh.prompt
git show HEAD:.zsh.addons/.zsh.editor
zsh tests/run.zsh 'living prompt'
```

Read the ordinary `precmd` fact capture, the bounded Context trigger
fingerprint, the private compact/lens/transcript modes, the Context/Interaction
renderers, and the editor peer's line-init/pre-redraw/line-finish transitions
and `compozsh-context-lens` Option-I widget. The tests check that READY,
operation-specific, advisory, assignment-value, autosuggestion, pin,
transcript and resize behavior preserve the exact ZLE buffer, replace
providers and executables with sentinels to keep Interaction edits inert, and
instrument provider calls in a resize PTY.

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
zsh tests/run.zsh 'Xcode monitor'
zsh tests/run.zsh 'Xcode device monitor'
zsh tests/run.zsh 'log reader'
zsh tests/run.zsh 'log copy'
zsh tests/run.zsh 'editor reader'
```

Read `_xcode_run_live`, `_xcode_run_identity`, `_xcode_run_idle`, their scoped
log-observer and `_xcode_logs_*` helpers, the shared picker's screen cleanup,
and for device consoles `_xcode_run_device_live` and `_xcode_device_poll`.
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
| Living prompt buffer preservation and inert edits | `living prompt` |
| READY toolchains without extra reads or probes | `runtime prompt` |
| Help workspace capture, fallback and cleanup | `help workspace` |
| Tool descriptions and alias previews | `tool descriptions`, `alias coverage` |
| Draft inspector | `task experience` |
| Command composer | `command composer` |
| Runtime metadata bounds and installed-runtime probes | `runtime versions`, `bounded direct metadata`, `prompt probes installed runtimes` |
| Manual capture, formatter and transport | `manual coverage`, `manual summaries`, `manual async` |
| Public manual cache and installer exclusion | `manual cache`, `cache data`, `installer excludes generated` |
| Native completion dump call, path, contents, mode and `--clean` survival | `native completion dump`, `clean installer touches only` |
| Matching and exclusion | `exclusion`, `matching component` |
| Captured-data parsing without temporary files | `here-string`, `filter override builder`, `worktree removal` |
| Captured, setting and inherited text kept out of arithmetic | `never splices text into arithmetic`, `stay text`, `overflowing`, `hostile`, `inherited`, `numeric metadata`, `stat numbers`, `dd parser`, `validates width text` |
| Shared effects and data | `shared effects`, `shared data` |
| Picker digits and slot acceptance | `numeric`, `detail panels preserve native` |
| Path + Tab directory arguments | `directory argument` |
| Bracketed paste | `picker nonpaste CSI`, `picker interrupted paste` |
| Job lifecycle | `job lifecycle` |
| Git file review and Change atlas | `Git tree`, `Git atlas`, `Git review native g` |
| Branch catalog and remote fallback | `absent from the reflog`, `branch remote` |
| Git filter, selector, Files, promisor and signature-verifier controls | `shared Git`, `Git selectors`, `Files Git`, `promisor fetch`, `signature verifier` |
| Git comparison bounds | `Git comparison` |
| Discard with a dirty submodule | `g --discard-all preserves dirty submodule` |
| Worktrees | `worktree ` |
| Xcode discovery | `Xcode discovery` |
| Xcode Run, device console and logs | `Xcode run`, `Xcode monitor`, `Xcode device monitor`, `log reader`, `log copy`, `editor reader` |
| Task routing and external-device modes | `task families`, `USB verification progress` |
| USB progress, phase, disk-size and GPT number bounds | `USB numeric bounds`, `backup GPT entry` |
| External media writes, read-back and temporary files | `USB raw`, `USB verification`, `USB temporary`, `ISO inspection`, `external-media temporary` |
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
