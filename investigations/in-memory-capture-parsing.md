# In-memory capture parsing

> **Status (2026-10-11).** Implemented as an uncommitted change on top of
> `f3bc494`. Every shipped here-string parse now splits in memory, and the one
> remaining TMPPREFIX file — Zsh's own Ctrl-X Ctrl-E widget — is disclosed in
> SECURITY.md. Rule:
> [security](../engineering/security.md#handling-sensitive-data); idioms:
> [Zsh conventions](../engineering/zsh.md#idioms).

## Problem

Zsh 5.9 implements here-strings (`<<<`) and here-documents with a temporary
file under `${TMPPREFIX:-/tmp/zsh}`, which it unlinks before the command reads
it ([implementation](https://github.com/zsh-users/zsh/blob/zsh-5.9/Src/exec.c#L4383-L4406)).
Observed on the reference Mac: with `TMPPREFIX` in a missing directory,
`read -r v <<< x` fails with `can't create temp file for here document`; the
standard input of `<<< x` is a regular file of mode 0400 with `nlink` 0
(`zstat -L +mode -o /dev/fd/0` prints `0100400`, while a pipe prints a FIFO
type).

Thirteen parses fed captured data through `<<<`, so that data was briefly
written to disk although SECURITY.md described it as shell memory:

| Peer or entry | Sites | Capture |
| --- | ---: | --- |
| `.zsh.prompt` `_prompt_git` | 1 | Full `git status --porcelain=v2 --branch --show-stash`, including changed and untracked paths, on every prompt in a repository |
| `.zsh.git-review` | 4 | Working changes (`status -z`), comparison refs, history and committed-file lists |
| `.zsh.navigation` | 3 | Local branch catalog, remote-tracking fallback, branch details (subjects, upstreams) |
| `.zsh.git-worktree` | 3 | Worktree catalog, branch catalog, removal-check `ls-files -v -z` |
| `.zsh.usb` | 1 | Verification progress metadata |
| `.zsh.pure.compozsh_git_filter_overrides` | 1 | Filter driver names (converted first, in a separate session) |

Disclosure was the smaller defect. When `TMPPREFIX` was unwritable, missing,
or on a full volume, every loop printed the error to stderr (into the prompt or
a full-screen view) and ran zero iterations:

- **Repository filters ran (security).** `_compozsh_git_filter_overrides`
  returned success with no overrides, so the passive prompt and Git review
  `git status` captures ran repository-configured clean/process filters,
  breaking the "Safe anywhere" invariant. Reproduced at `f3bc494`: a filter
  that writes a probe file ran from both `_prompt_git` and
  `_git_review_changes_capture`. An untrusted repository cannot make
  `TMPPREFIX` unwritable by itself, but the guarantee must not depend on it.
- **False empty results.** The prompt showed `unknown no-upstream`; Git review
  reported `0 staged · 0 unstaged · 0 untracked` (violating "failed reads
  differ from empty snapshots" in
  [Git workspaces](../engineering/workspaces/git.md)); branch, remote, ref,
  history and file catalogs were empty. The worktree catalog failed closed
  because its own parse came first.

## Exact replacements

`<<<` appends a newline, which defines the old records exactly:

| Old loop over `<<< "$text"` | In-memory replacement |
| --- | --- |
| `while IFS= read -r line` | `for line in "${(@f)text}"` (keeps a final empty line) |
| `while IFS= read -r -d '' rec` | `fields=("${(@0)text}")`, then `for rec in "${(@)fields[1,-2]}"` (keeps empty records, drops the unterminated tail) |
| `while read -d '' a && read -d '' b && …` (K fields) | `for a b … in "${(@)fields[1,(${#fields}-1)/K*K]}"` (complete records only) |

A differential check compared each old loop with its replacement on 4,000
random strings of up to 24 symbols drawn from NUL, newline, tab, space,
backslash, Zsh's Meta byte `0x83`, invalid `0xff`, a UTF-8 character and glob
characters, for line, single-field and two- to five-field NUL shapes, under
both `LC_ALL=C` and `en_US.UTF-8`: 0 mismatches. The security reviewer ran
its own 3,000-string differential for the line, single-field and three-field
forms, and the contract reviewer a 17-case edge corpus, in both locales: 0
mismatches each. A deterministic test now pins the documented idioms against
the read loops on a fixed corpus.

Dropping the unterminated tail matters. A byte-limited capture can end inside
a record, and the old loops never published a cut-off path or ref; the
regression tests pin that.

Deliberate deviations:

- **Filter-override builder.** The separately converted entry uses unquoted
  `${(0)names}`, which drops empty names (they name no driver) and also
  overrides an unterminated final name. `git config --null --name-only` always
  terminates names and its callers reject incomplete captures, so results are
  identical for real input; an extra override fails safe. Its test pins that.
- **`IFS=$'\t' read` sites.** Tab-whitespace splitting strips and collapses
  tab runs, so these are exact for every input their producers emit rather than
  for arbitrary bytes. `_git_recent_branches` reads `%(HEAD)%09%(refname)`:
  `%(HEAD)` is one `*` or space, and Git refnames cannot contain tabs or
  control characters; a malformed line is rejected rather than normalized.
  `_usb_verify_progress_read` reads Compozsh's own `%s\t%d\t%d\n` line.
- **Worktree removal hardening.** The removal check already refused empty or
  non-`H ` index records; text after the last NUL now refuses too (the old loop
  ignored it). The capture already rejects incomplete output, so this only
  closes a theoretical gap.

## Intentional behavior change: USB progress metadata

`total` and `intra` were `local -i`, so `read` assigned the file's text with
arithmetic evaluation. Integer assignment evaluates subscripts, including
command substitutions: at `f3bc494`, metadata containing
`reply[$(command)1]` ran the command (`reply` is a local array there). The file
is an owner-only `mktemp` file written by Compozsh's own worker, so reaching it
needs same-user write access, but it was a command-execution path. Evaluation
also made the `<->` guard vacuous: in the window between `mktemp` and the
worker's first write the empty file produced `0 bytes of 0 bytes` instead of
`Preparing the first raw read block…`.

Fields are now validated as text (`<->`, at most 18 digits) before integer
assignment. An absent third field still means offset 0, as the existing
two-field live-progress test expects.

## Remaining TMPPREFIX file: Ctrl-X Ctrl-E

`.zsh.editor` binds Zsh's stock `edit-command-line` widget to Ctrl-X Ctrl-E.
Its Zsh 5.9 implementation ends with `} =(<<<"$prebuffer$buffer")`, so the
whole draft, including continuation lines, is written to one mode-0600 file
under two hard-linked names, `${TMPPREFIX:-/tmp/zsh}XXXXXX` and the same name
plus `.zsh` (`TMPSUFFIX`), while the editor runs. Verified with the same
construct: one inode, `nlink` 2; Zsh removes both names when the editor
returns, and an abnormal termination can leave both. An editor needs a
file, so this is disclosed rather than replaced: SECURITY.md has an inventory
row, a note under "Secrets on the command line" and an audit command. Replacing
the widget with one that uses a validated `mktemp` file in a mode-0700
`$TMPDIR` directory would still need a row; it is not proposed here.

## Alternatives rejected

- **Keep `<<<` and disclose it.** Plaintext paths and branch metadata on disk,
  however briefly, plus the fail-open and false-empty failure modes and the
  per-prompt file creation cost.
- **A shared splitting support entry.** The rule repeats, but each use is one
  expression, while an optional support entry needs a useful standalone
  fallback at every caller
  ([architecture](../engineering/architecture.md#essentials)) — more code
  than it removes. The rule lives in
  [security](../engineering/security.md#handling-sensitive-data), the idioms
  and their exact semantics in [Zsh conventions](../engineering/zsh.md#idioms),
  and a `security:` scan enforces it.
- **FIFOs or `mktemp` files.** More lifecycle and cleanup for data that is
  already in a shell parameter.

## Measurements

Apple M3 Max, macOS 27.0.1 (26A434), Zsh 5.9, Git 2.54.0 (Apple Git-157).
The load average was about 2.9–3.8 during the runs (not an idle machine).
Baseline: a `git archive` copy of `f3bc494`; candidate: the uncommitted change
(record its commit when it lands). Script:
[`benchmarks/prompt-git-render.zsh`](benchmarks/prompt-git-render.zsh), which
alternates baseline/candidate order every run and reports the median, minimum
and maximum of per-shell medians.

Fixtures: **outside** a repository; **clean** (20 tracked files, upstream set);
**dirty** (200 tracked; 10 staged, 30 modified, 40 untracked, one stash);
**large** (3,000 tracked; 1,000 modified, 2,000 untracked).

Complete prompt rendering — every `precmd` hook plus `PROMPT`/`RPROMPT`
expansion, in-process without a TTY (the TTY-only manual and help captures are
skipped in both versions). Warm: 7 shells × 40 renders after three discarded
warm-up renders, `en_US.UTF-8`, milliseconds:

| Fixture | Before | After | Change |
| --- | ---: | ---: | ---: |
| outside | 4.01 (3.74–4.25) | 4.01 (3.92–4.30) | unchanged |
| clean | 29.58 (27.47–30.55) | 28.58 (26.83–30.54) | within noise |
| dirty | 34.03 (33.25–34.94) | 30.60 (29.50–32.25) | −3.4 (−10%) |
| large | 122.15 (120.68–124.10) | 52.47 (49.68–55.99) | −69.7 (−57%) |

The same under `LC_ALL=C`, 5 shells × 40 renders: outside 4.02 → 3.97, clean
28.58 → 28.38, dirty 33.32 → 31.75, large 122.68 → 52.77.

Fresh: the first render of each of 15 new shells per version (cold
Git-directory cache), `en_US.UTF-8`: outside 4.86 (4.52–5.61) → 4.79
(4.65–5.40); clean 39.05 (36.47–86.58) → 37.74 (36.44–42.63); dirty 43.17
(41.87–46.52) → 40.49 (38.89–44.33); large 132.02 (126.83–143.28) → 61.47
(59.21–65.58).

End to end in a real PTY — Return on an empty line until the next ZLE
`line-init`, after the first prompt's background work settled. Milliseconds,
5 sessions × 30 samples, `en_US.UTF-8`:

| Fixture | Before | After | Change |
| --- | ---: | ---: | ---: |
| outside | 7.33 (6.71–10.15) | 7.19 (6.81–7.29) | unchanged |
| clean | 32.58 (30.58–35.28) | 32.63 (30.17–33.01) | unchanged |
| dirty | 39.14 (34.69–40.36) | 34.77 (31.77–34.83) | −4.4 (−11%) |
| large | 125.91 (125.33–127.12) | 57.37 (51.67–58.24) | −68.5 (−54%) |

Outside a repository the prompt never runs Git, so no change is expected. In
a clean repository the `git status` process dominates; the saving grows with
the number of status lines. The candidate also removes one temporary-file
create, write and unlink per prompt.

Provider microbenchmark (not an end-to-end workspace measurement):
`_git_recent_branches` over 5,001 local branches with no reflog history, 7
alternating shells × 10 calls, `en_US.UTF-8`: 245.38 ms (230.29–258.88) before,
169.29 ms (160.39–182.86) after. The rest of that time is the `for-each-ref`
process and catalog assembly, not parsing. Git review, branch-picker and
worktree entry were not measured end to end in a PTY.

## Regression coverage

- `tests/in_memory_parsing_test.zsh` (filter `here-string`): each converted
  capture, against disposable repositories or fixtures, run once with the
  default `TMPPREFIX` and once with `TMPPREFIX` inside a missing directory;
  both runs must print the same exact result without diagnostics. Paths contain
  tabs and newlines, subjects tabs and backslashes, branch names non-ASCII
  text, and synthetic captures end inside a record. Also: the prompt and review
  never run a repository filter without a here-string temporary file, and the
  documented idioms match their read loops. Each capture test, and the filter
  test, failed at `f3bc494` only for the intended reason.
- `security:` scan: lexes every shipped Zsh file with comments stripped and
  flags `<<` or a word-initial `=(` inside any token, after removing
  single-quoted literals and the `%<<` prompt escape, so redirections nested in
  `$(...)`, `"..."` or `<(...)` are found. Its fixture proves both the nested
  forms and the ignored quoted patterns; at `f3bc494` it reports exactly the 13
  sites. It cannot see stock Zsh functions, hence the Ctrl-X Ctrl-E row.
- `USB verification progress waits for numeric metadata before counting bytes`
  (empty, non-numeric, overflowing and substitution-bearing metadata).
- `worktree removal blocks empty unterminated or malformed index records`.
- `shared Git filter override builder keeps every override without temporary files`.
