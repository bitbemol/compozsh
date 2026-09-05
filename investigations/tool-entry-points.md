# Task-oriented command audit

2026-09-04. Audit of the current public function definitions and their help
companions, followed by implementation of the task-family consolidation below.
This is an implementation record, not a new command registry.

## Already consolidated

`g --discard-all` is the only public discard entry point. It dispatches to one
private implementation, owns its help through `g`, and scopes Git selectors to
the current folder's repository. Re-sourcing removes the former public
function, help companion and alias; no compatibility workflow remains.

## Implemented consolidation

| Task family | Retired entry | Canonical entry | Reason |
| --- | --- | --- | --- |
| External devices | `flash-usb [media]` | `external-device --flash [media]` | Bootable-media creation and formatting already share device capture, identity validation and confirmation machinery in `.zsh.usb`. |
| External devices | `format-external-device` | `external-device --format` | Keep an explicit destructive mode under the same device family; the source is whole external physical disks, not only USB. |
| Xcode | `update-xcode-skills` | `xcode --export-skills` | Export belongs with the selected Xcode; “export” describes the existing action more precisely than a general update. |
| Compozsh maintenance | `prompt-refresh` | `compozsh --refresh` | The current action also clears tool-capability caches and rehashes commands. It does not reload configuration. |
| Compozsh maintenance | `compozsh-sudo-touch-id [mode]` | `compozsh --sudo-touch-id [mode]` | Status is the default; one grouped entry owns validation and static help while the optional operation peer retains the fixed PAM boundary. |

The no-argument `external-device` entry presents two clearly named tasks,
Create bootable media and Format a drive, before either task captures its
sources. Both use the shared action view, captured plan, bottom input dock and
narrow-window disclosure. Explicit modes enter their task directly. Acceptance
restores the chooser's screen before dispatch; cancellation performs no task.

All five migrations remove the old public function, help companion and alias
on re-source. Diagnostic prefixes, prompt classification, explorer discovery,
help, README inventories, website examples, security claims and tests were
updated together. Each action has one private implementation; no compatibility
alias, persistent catalog or peer ordering dependency was added.

The Touch ID guide now belongs to the same-source `compozsh` companion in
`.zsh.help`, including when `.zsh.sudo-touch-id` is disabled. The operation peer
has no public command. Re-sourcing removes stale definitions; fresh discovery
therefore has one maintenance entry. The prompt recognizes the new mode as an
environment operation and keeps its help form inert.

Existing exact managed PAM files remain recognizable for status/removal when
their fixed comment still names the retired command. New installations use the
new command in that comment. The privileged removal routine checks either exact
fixed byte sequence with the same owner/mode/ACL/size requirements. There is no
command alias or automatic PAM rewrite. Tests execute the rewritten fixed-path
routines only in unprivileged disposable fixtures, including old-marker removal
and refusal of an extra newline. No actual Touch ID setting was inspected or
changed during this cleanup.

For the literal prompt cue, three isolated 120×30 runs of 400 complete prompt
updates across Touch ID, refresh, help and echo drafts measured 0.702 / 0.698 /
0.715 ms per render with the new cue disabled, versus 0.722 / 0.737 / 0.717 ms
enabled. These are warm synthetic rendering observations, excluding terminal
painting, startup and provider capture; they show no material latency change.

### Boundaries that must survive grouping

- `xcode --export-skills` is recognized before project discovery, with
  side-effect-free mode help. Other advanced arguments remain transparent.
  Interactive export now reviews the selected exporter, exact detected agent
  destinations, replacement policy and partial-recovery limits before staging.
  Escape writes nothing; acceptance closes the screen before export. Without a
  usable interactive UI, direct execution remains the documented fallback.
  Recovery remains per skill, not a whole-operation transaction.
- Device modes must preserve exact-device typed confirmation, separate
  administrator authorization, identity revalidation, and post-screen writes.
  Formatting and flashing remain different operations within one task family.
- A Compozsh refresh must remain current-shell-only. It must not source private
  configuration, install tools, or imply that other shells were refreshed.

## Keep distinct

- `g`: branches, read-only review, worktrees and confirmed discard already form
  one repository task family. Native Git arguments remain native arguments.
- `mkcd` and `cpdir`: small direct shell conveniences. `cpdir` copies the current
  folder; a file-workspace Copy action targets the selected entry. These are
  different targets, not redundant implementations to merge indiscriminately.
- `compozsh --sudo-touch-id`: keep administrator policy visibly separate from
  ordinary browsing, refresh and project operations inside this explicit mode.
  The former standalone command is retired, as recorded above; grouping retains
  the same privilege boundary.
- `git`, `grep`, `man`: transparent wrappers retain the underlying tools' names
  and syntax. They are not new Compozsh task families.
- Browse, Search, Recents, History and Draft inspector: keep their contextual
  keyboard entry points. Do not invent additional public commands merely to
  make every view appear in the tool catalog.

These retained direct primitives are intentional boundaries, not deferred
renames. Their help and applicable output use the shared presentation; native
wrappers preserve the underlying executable's interaction contract.

## Verification

Six task-family unit cases cover routing, exact arguments and statuses, retired
definitions and catalog entries, inert mode help, invalid combinations, captured
action plans, reactive prompt cues and nested task identity. A native ZLE/PTY
journey exercises filtering, narrow resize, acceptance, cancellation, caller
bookmark preservation and post-restoration dispatch for device and export
choices. Export and disk effects are replaced with spies in a disposable home;
no real disk or agent installation is changed. The focused help inventory keeps
the existing device and skill-export safety assertions under the new entries.
