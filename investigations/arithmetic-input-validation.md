# Arithmetic input validation

> **Status (2026-10-12).** Implemented as an uncommitted change on top of
> `00deab4`. Rules: [Zsh conventions](../engineering/zsh.md#idioms) and
> [security](../engineering/security.md#handling-sensitive-data); public claim
> and test filters in [SECURITY.md](../SECURITY.md#privacy-model).

## Problem

Zsh evaluates arithmetic whenever text reaches an arithmetic context, and that
evaluation expands array subscripts, including command substitutions. `path`,
`argv` and `funcstack` always exist, so text such as `path[$(cmd)1]` runs
`cmd`. Observed on Zsh 5.9 (macOS 27.0), with scratch scripts under `zsh -f`:

| Context | Evaluates the text |
| --- | --- |
| `local -i x=$t`, `x=$t` into an integer or float, `read` into one | yes |
| `(( $t ))`, `$(( $t ))`, `let`, `for (( ))`, and a bare scalar *name* holding the text (`(( s > 0 ))`) | yes |
| `[[ $t -lt 1 ]]` (any numeric operator) | yes |
| Ordinary-array subscripts and ranges, `${s:$t:1}`, `${(l:$t:)s}`, `printf %d`, `return`, `exit`, `shift`, `repeat`, `read -t` | yes |
| `(( h[$t] ))`, `$(( h[$t] ))`, `(( a[(Ie)$t] ))`: text spliced into arithmetic, subscript reparsed (associative too, quoted or not) | yes |
| `typeset -gi name` / `-gF name` **without** a value over an inherited scalar | yes |
| `${h[$t]}` and `h[$t]=v` on an associative array; `${a[(Ie)$t]}`; `${+h[$t]}`; `(( h[\$t] ))` | no |
| `[ "$t" -gt 0 ]`, `zselect -t`, `[[ $t == <-> ]]`, `typeset -gi name=0` over an inherited scalar | no |

Nineteen or more digits truncate with a warning and can wrap negative
(`99999999999999999999` becomes `-8446744073709551617`). Range patterns with a
small bound (`<0-65536>`, `<2->`) compare correctly at any length, but
`<0-9223372036854775807>` accepted `99999999999999999999`, so the 64-bit bound
is compared as text instead. An inherited `EPOCHREALTIME` makes
`zmodload zsh/datetime` fail and stays plain text.

## Method

Eight read-only audit agents each read one file group in full (every peer,
`.zshrc`, `install.zsh`, `templates/`, every support entry) and traced callers
across files. A correction mid-audit added the spliced-subscript forms. Every
reported site was re-read before it was changed. Each fix started with a test
that failed for the intended reason, and a per-hunk check reverted each changed
hunk alone and required its test to fail; only `local` declarations and
comments survive that revert. A lexing `security:` scan
(`never splices text into arithmetic`) found exactly the six spliced sites below
at `00deab4` plus two over fixed vocabulary, and none afterwards.

## Sites fixed

Code execution from untrusted text (spliced subscripts, verified with a marker):

| Site | Source |
| --- | --- |
| `.zsh.git-review` `_git_review_folder_summary` (`areas[d:$area]`, twice) | A path component in the repository, rendered in the Tree folder summary |
| `.zsh.usb` `_usb_image_add`, `_usb_macos_installer_add`, `_usb_workspace_controller` (`_USB_IMAGE_PATHS[(Ie)…]`) | Media file names from `~/Downloads`, `$PWD`, Spotlight, browsing or pasting, at `external-device --flash` start |
| `.zsh.xcode` `_xcode_test_node_sources_capture` | A test's source path in the project's result bundle |

Text assigned to integers without (or only after) validation:

| Site | Source |
| --- | --- |
| `.zsh.prompt` `_prompt_git` | `# branch.ab` and `# stash` headers of `git status` (a substituted `git` on `PATH`) |
| `.zsh.usb` `_usb_disk_info_capture` | `diskutil` `TotalSize`/`DeviceBlockSize`, validated after assignment |
| `.zsh.usb` `_usb_verify_progress_read` | Progress metadata file, validated after `read`; same hunk as the separate in-memory capture parsing change, which also removes its here-string |
| `.zsh.usb` `_usb_dd_progress_read`, `_usb_dd_bytes_observed`, `_usb_createinstallmedia_progress_read` | `stat -f %z` output assigned directly |
| `.zsh.usb` `_usb_write_image` | Writer stage word used as an arithmetic operand (`image` evaluated the image path); now a string test |

Overflow only (digits, no bound): Xcode summary, failure, build-error and
scheme counts and line numbers; Git hunk headers (the regex now needs `,` or a
space after 18 digits, and a header it cannot number also stops the previous
hunk's numbering) and the auto-refresh duration; `od` GPT fields, dd byte
counts, verify-byte lines, installer percent, `diskutil` counts, format sizes
and free space; the picker limits, `ZSH_DIRECTORY_PICKER_MAX_RESULTS` and
`_file_search_limit`; `sudo` Touch ID size, mode and link count. The mode case
failed open: `1000000000000000000000` passed as a safe mode.

Inherited environment (private names), fixed by the owner rule in the idioms:

| Owner | Names | Fix |
| --- | --- | --- |
| `.zsh.manual` load | Preserved `-gi`/`-gF` state, `_MANUAL_WORKER_CANCELLED` | Keep only state of its own type; drop the rest |
| `.zsh.prompt` load and preexec | `_PROMPT_COMMAND_STARTED`, `EPOCHREALTIME` | Keep a float start only; time only with the module's float |
| `.zsh.ui.state` load | 13 view/session flags and `_ZLE_PICKER_IDLE_CALLBACK` | `unset` (keeps every reader's default, including computed ones) |
| `.zsh.git-review` load | `_GIT_REVIEW_WORKER_DIR`, `_GIT_REVIEW_WORKER_EXEC` and worker flags | `unset`; an inherited `EXEC=1` made a foreground capture `exec git` |
| `.zsh.git-worktree` controller | `_GWT_HIERARCHY` | Declared beside `_GWT_OPTIONS`/`_GWT_FOCUS` |
| `.zsh.xcode` `_xcode_run_live` | Device-console flags | Declared; a Simulator run also wrote them as globals |
| editor, highlighting, manual, prompt hooks; screen session | `_ZLE_PICKER_ACTIVE`/`SCREEN_ACTIVE`; `_ZLE_AUTOSUGGEST_SUSPENDED` | Compared as text; validated as a bounded decimal, then restored exactly. Their owner may be absent |

Anyone who controls the environment can already run code through
`ZSH_LOCAL_INIT` or `ZDOTDIR`, so this class crosses no new trust boundary; the
owner chose to fix it for robustness (a stray value also aborted peer loads).

## Decisions

- **Eighteen digits** is the general bound: it always fits 64 bits and matches
  the other worktree's idiom. `diskutil` reports APFS's maximum size as
  `9223372034707292160`, so `_usb_decimal_is_int64` compares 19-digit text
  with `9223372036854775807`; the first 18-digit attempt broke the existing
  format-catalog test.
- **Invalid limits fall back to a default**, as non-numeric text already did:
  `_zle_picker_run`'s 10, but 8 inside `_zle_picker_loop` for callers that pass
  the raw setting straight to it (a pre-existing difference from the
  documented 10). `_file_search_limit` accepts at most nine digits because the
  walk passes `remaining + 1` to the `Y` glob qualifier, which fails fatally at
  2³¹.
- **Owner state is restored exactly.** The screen session first compared the
  editor's flag with `1`; the lifecycle test, which restores a sentinel `7`,
  failed in the full suite, so the session validates the text as a bounded
  decimal instead.
- **Range patterns** replace arithmetic only where the bound is small
  (`<0-65536>`, `<2->`).

## Safe, with the reason

- Validated before use with a bound: manual cache fields (`<1-2147483647>`,
  `<0-8192>`, `<0-4096>`), runtime version components (≤8 digits), Git review
  framing and summary numbers (≤4–10 digits), capture-bounded status, Xcode
  PIDs and `request` (≤10), `max_bytes` (compared with INT64_MAX as text),
  appearance `<0-255>`, output `<16-255>`, highlighting `~N` (bounded by
  `${#dirstack}`), `_matching_decimal_limit` callers.
- Produced by Zsh: lengths, `$?`, `$!`, `SECONDS`, `EPOCH*` after a checked
  load, `COLUMNS`/`LINES`, ZLE specials, `zstat`, `sysread -c`, fds from
  `sysopen`/`exec {fd}`, `(I)`/`(Ie)` results in expansion form, terminfo
  numbers.
- Callers pass integer-typed values: every helper whose `$1`… reaches
  arithmetic was traced repo-wide (prompt widths, picker bookmarks and focus,
  Git document rows, USB progress model, Xcode action status).
- Bounded by the producer's format and not injectable: other `stat` fields
  under `<->` (int64 output), the CRC, and the root-run `_trusted` mode check in
  the fixed `sudo` script (real `stat %Lp`, at most four octal digits).
- `.zsh.git-review` `states[$state]` used fixed kind words; converted anyway so
  the scan expects no matches.

## Not changed (proposals)

- `.zsh.usb` GPT fallback: `backup_entry_lba * 512` can wrap for a 17-digit
  LBA from a crafted image and pass the bounds after it; it needs an
  `lba <= last_lba` check before multiplying (not text evaluation).
- One shared pure entry beside `_matching_decimal_limit` could replace the
  three 64-bit text comparisons: `_usb_decimal_is_int64` and the two inline
  `ZSH_XCODE_CAPTURE_MAX_BYTES` checks in `.zsh.xcode`.
- `.zsh.manual` keeps an inherited `_MANUAL_ASYNC_STATE` (a word, not
  arithmetic); `running` or `failed` would disable asynchronous capture.
- The root-run `_trusted` check in the fixed `sudo` script uses `<->` before
  `8#$mode`; real `/usr/bin/stat %Lp` output bounds it, no test can reach it,
  and the `security:` scan cannot lex code held in single-quoted strings.
- `install.zsh` loads only `b:strftime`, so `$EPOCHSECONDS` is empty and
  `strftime` uses the current time by accident; an inherited numeric value
  changes the backup stamp and a non-numeric one fails closed.
- Without `.zsh.ui.state` (a partial support install) associative view arrays
  would be ordinary and keyed lookups would become arithmetic; the bootstrap
  always loads the whole UI group.

## Coordination

`_usb_verify_progress_read` and its test are byte-identical to the separate
in-memory capture parsing change (uncommitted when this was written), so the
two merge cleanly there. That change's
[Zsh conventions](../engineering/zsh.md#idioms) bullet and `security:` test sit
next to this change's and need a small manual merge; it also removes the
remaining here-strings that write project data to temporary files.
