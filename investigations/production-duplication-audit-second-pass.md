# Second production duplication audit

Recorded 2026-09-06 against the working tree after the [first ten fixes](production-duplication-audit.md#implemented-follow-up).
Three agents independently reviewed UI/UX, functional duplication and convention
compliance. The primary reviewer also scanned repeated eight-line windows,
inspected candidate call chains, and reproduced the checksum findings below.
The initial audit changed no production code. The implementation follow-up below
resolves all eleven groups and the purity comment.

The first pass resolved its ten identified groups; it did not establish that
all semantic duplication was gone. This pass found eleven more actionable groups
and one misleading purity comment. The ranking emphasizes correctness and
maintenance value, rather than line count. Some groups contain multiple small
mechanisms. Counts describe implementation sites and must not be summed as a
code-volume metric.

## Original ranked findings (resolved)

All source paths below are relative to `.zsh.addons/`; line numbers describe this
pre-fix snapshot. Recommendations below record the original audit; the
implemented owners are listed in the follow-up.

### 1. USB checksum validation has diverged — confirmed behavior bug

**Sites:** `.zsh.usb:4022` and `:4325` repeat optional checksum algorithm, hex
length and alphabet validation. The digest checks also recur in
`_usb_checksum_output_read` at `:2817`.

The raw execution path enables `EXTENDED_GLOB`; `_usb_windows_execute` at `:4001`
uses `emulate -L zsh` without enabling it, yet matches `[0-9a-f]##`. A valid
64-character SHA-256 digest is consequently rejected with status 2 before
Windows source preflight. An otherwise identical request without a checksum
reaches preflight. The raw path accepts the same supplied digest.

**Recommendation:** one explicit pure digest validator for algorithm/hex input,
with callers retaining optional/required checksum and preflight policies.
Do not merge raw-image writing with Windows installer execution. Add a regression
for the valid-checksum Windows journey before implementation.

### 2. Two checksum readers share a caller-variable dependency — confirmed bugs

**Sites:** `.zsh.usb:2815` and `:2877`, in `_usb_checksum_output_read` and
`_usb_crc32_output_read`.

Both declare an input and derive a token in the same `local` command:

```zsh
local output=$1 ... token=${output%%[[:space:]]*}
```

Zsh expands the token expression before the new local `output` binding exists.
It therefore reads a dynamically inherited `output`, rather than the supplied
argument. With no inherited output, the SHA reader rejects a valid digest. The
CRC reader can return a different checksum from the one supplied: inherited
`output="999 10"`, argument `"123 10"`, expected size `10` returns success with
`REPLY=999`.

Current production callers use a local variable named `output` with matching
contents, masking the problem. This audit does not demonstrate corrupt device
verification in those existing callers; it demonstrates that the readers are
not independent functions of their arguments.

**Recommendation:** separate declaration from derivation in both readers and
cover conflicting/absent caller-local names. Reuse the shared digest validation
from finding 1 where applicable. Keep SHA and CRC output grammars separate;
a new universal parser is unnecessary to repair this duplicated mistake.

### 3. Literal assignment and redirection recognition are copied across surfaces

**Sites:** assignment detection in `.zsh.highlighting:45` and `.zsh.prompt:433`;
redirection detection in `.zsh.highlighting:30` and `.zsh.prompt:439`.

Two implementations repeat assignment unquoting and the same regex. Two others
repeat numeric file-descriptor removal and the complete redirection operator
table. Their literal-token policies match; changes could otherwise reach syntax
highlighting without reaching the Interaction lens, or vice versa.

**Recommendation:** two small pure lexical entries. Leave classification,
rendering and command-context inference in their callers. Before calling the
assignment predicate pure, localize Zsh's implicit regex outputs (`MATCH`,
`MBEGIN`, `MEND`, `match`, `mbegin`, `mend`); current copies do not do so.

### 4. USB workflow state is assembled and reset repeatedly

**Sites:** `.zsh.usb:2018` and `:2177` copy five captured drive arrays before
retargeting and restore them on cancel. At `:2039` and `:2206`, the same
controller copies selected image/drive values, sizes, labels and fingerprints
into the post-cleanup request state. Common result initialization is also copied
in macOS (`.zsh.usb:3917`), Windows (`:4012`) and raw (`:4311`) execution:
outcome/error/rate, byte/time, verification, ejection and started flags.

**Recommendation:** narrow impure helpers for snapshot/restore and accepted
request assembly, plus a common result reset with explicit checksum fields.
No stale-result bug was demonstrated. Media-specific minimum sizes, subtitles, permitted actions,
Apple-signature state and checksum/integrity state remain explicit caller
choices. This does not justify merging entire media workflows or their final
validation boundaries.

### 5. The shared input loop repeats its idle callback protocol

**Sites:** `support/ui/.zsh.ui.zle_picker_loop:143` and `:197`.

Both invoke the idle callback, preserve its status, inspect the requested
operation, publish the action and mark acceptance.

**Recommendation:** an exclusive private helper beneath `_zle_picker_loop` for
that protocol. It is impure because it invokes a callback and uses interaction
state. Keep scheduling in the two caller branches: pre-paint runs after layout
only when no input byte is queued; timed idle runs after the quiet read. Immediate
rendering versus repaint/deadline/blocking-read behavior must remain distinct.
No new support file is needed for an exclusively owned private helper.

### 6. Git automatic refresh repeats poll, deadline and failure handling

**Sites:** `.zsh.git-review:1734` and `:1778`.

The guide and normal branches duplicate in-flight polling, deadline checks,
failed-packet handling and the 0.10-second wait request.

**Recommendation:** one private impure poll-outcome helper. Guide mode must
continue to drain existing work without starting discovery or adopting results.
Normal mode alone retains adaptive pacing and snapshot adoption. This is a
separate mechanism from the generic UI callback protocol in finding 5.

### 7. Prompt project results repeat hook and final assembly

**Sites:** `.zsh.prompt:2191` and `:2398`, with result-array finalization at
`:2196` and `:2419`.

Saturated-root and ordinary project paths both reset extension arrays, invoke
extension hooks, append extra segments and warnings, and publish the final
project name/items/widths/attention state.

**Recommendation:** share hook invocation and final result publication through
narrow impure helpers, or use one common epilogue. Preserve the saturated-root
path's early exit before optional filesystem decoration. This assembly is not
pure merely because its output is presentation: it runs hooks and updates state.

### 8. Apple dd byte-record recognition is repeated

**Sites:** `.zsh.usb:2373` and `:2689`.

Both trim leading whitespace, recognize the native `N bytes ... transferred`
record and extract the leading decimal byte count.

**Recommendation:** a pure line-to-byte-count parser with rejection status.
Retain separate acquisition and interpretation: one caller consumes incremental
chunks and write/verify stage markers; the other reads a bounded captured log
and retains the last observed count. Preserve incomplete-line handling and
native progress/final-record variants.

### 9. USB and Xcode repeat native structured-document extraction

**Sites:** `.zsh.usb:1182` (`_usb_plist_raw`) and `.zsh.xcode:154`
(`_xcode_json_raw`).

Both pipe supplied document text to `/usr/bin/plutil -extract "$key" raw -o - -- -`
and return the captured scalar in `REPLY`. Xcode additionally checks the PATH
command table, although it executes the fixed system binary.

**Recommendation:** one impure native scalar-extraction entry with an explicit
availability contract. Retain optional-key fallback policy, input bounds and
domain-specific structure validation with the callers. The subprocess makes
this impure even though its document input is supplied. No speed gain was
measured.

### 10. macOS installer metadata is read twice for the same candidate

**Sites:** `.zsh.usb:198` reads installer-root stat metadata inside
`_usb_macos_installer_fingerprint`; `.zsh.usb:708` immediately repeats the same
`stat -f '%d:%i:%m:%B'` after calling that helper at `:706`.

**Recommendation:** reuse the root fields already captured in the fingerprint,
or explicitly return both captured values. This removes one `/usr/bin/stat`
launch per accepted installer candidate and keeps displayed timestamps aligned
with that capture. Later action-time revalidation remains necessary and is not
a duplicate to remove. No elapsed-time improvement was measured in this audit.

### 11. Full Git object-ID validation has two owners

**Sites:** `.zsh.git-worktree:67` and `.zsh.git-review:228`.

Both require hexadecimal text of exactly 40 or 64 characters. Review's separate
nonempty check is redundant with its length check. Several operations consume
these predicates.

**Recommendation:** one pure Git object-ID predicate; preserve support for both
lengths and rejection of abbreviated IDs. This is a smaller maintenance item
than the bugs and repeated interaction protocols above.

## Additional convention correction

`.zsh.git-review:2565` calls `_git_review_comparison_subtitle` “Pure,” but it reads
`_git_compare_*` and `_ZLE_PICKER_SUBTITLE` implicitly. Correct the comment to
state-dependent presentation, or supply the captured facts explicitly before
extracting a pure calculation. This is misleading documentation in a feature
peer, not a falsely classified `.zsh.pure.*` support file.

## Historical pre-fix no-effect probes

These probes describe the pre-fix snapshot. The final regression tests load
the extracted support entries and are authoritative for the shipped behavior.
The original probes ran from the repository in a disposable shell, sourcing only the USB peer;
provider and progress callbacks are stubbed before the Windows probe. Neither
probe invokes disk utilities, authorization, image writes or private config.

```zsh
zsh -df -c '
  source .zsh.addons/.zsh.usb
  _usb_progress_stage() { :; }
  _usb_windows_source_open() { print PRECHECK-REACHED; return 1; }
  local digest=${(l:64::0:)}
  _usb_windows_execute /synthetic disk42 fp ifp 1024 flash-verify "" 1 256 "$digest" 4096
  print "checksum-status=$?"
  _usb_windows_execute /synthetic disk42 fp ifp 1024 flash-verify "" 1 "" "" 4096
  print "no-checksum-status=$?"
  unset output
  _usb_checksum_output_read "$digest" 256
  print "direct-parser-status=$?"
  local output=$digest
  _usb_checksum_output_read "$digest" 256
  print "inherited-parser-status=$?"
  output="999 10"
  _usb_crc32_output_read "123 10" 10
  print "crc-status=$? returned=$REPLY supplied=123"
'
```

Observed output:

```text
checksum-status=2
PRECHECK-REACHED
no-checksum-status=1
direct-parser-status=1
inherited-parser-status=0
crc-status=0 returned=999 supplied=123
```

## Initial audit verification and limits

- Six focused support checks passed: `zsh tests/run.zsh 'support '`.
- The 68-peer README inventory check passed; whitespace checks passed.
- No external private-helper use or falsely pure shared entry was found in the
  inspected call chains. Structural checks cannot prove semantic purity or
  exhaustively detect equivalent algorithms.
- The preceding implementation run passed all 707 tests. This read-only audit
  did not rerun the full suite; the new checksum probes reveal gaps in that
  coverage and should become regressions in the implementation follow-up.
- Required fallback guards, task-specific lifecycle decisions, distinct quoting
  contracts and routine field assignments were excluded. Repeated generic help
  prose and small version-token parsing fragments were lower-value candidates,
  not reasons to create larger frameworks.

These findings were subsequently implemented below. Neither pass proves
exhaustive semantic uniqueness.


## Implemented follow-up

The second cleanup uses nine new classified support entries. Existing feature
controllers retain their provider, privilege, scheduling and recovery boundaries.
Exclusive idle and USB controller helpers remain beside their only owners.

| Finding | Final ownership |
| --- | --- |
| 1. Digest validation | Pure `usb_checksum_validate`, shared by raw/Windows execution and SHA output interpretation. Valid Windows checksums now reach normal preflight. |
| 2. SHA/CRC readers | Separate pure `usb_checksum_output_read` and `usb_crc32_output_read` entries derive tokens only after initializing their supplied input. No caller-local `output` dependency remains. |
| 3. Literal lexical rules | Pure `compozsh_is_assignment` and `compozsh_is_redirection`; assignment recognition localizes all regex match parameters. |
| 4. USB workflow state | Exclusive retarget/request helpers retain the controller's context; impure `usb_result_reset` owns common execution-result initialization. |
| 5. Picker idle protocol | An exclusive helper below the shared input loop owns callback invocation and action handoff, with phase scheduling retained in callers. |
| 6. Git idle polling | An exclusive poll-outcome helper retains the guide's no-discovery/no-adoption policy and normal refresh pacing. |
| 7. Prompt finalization | One common hook/render/publication path; saturated roots skip optional detection before joining it. No new persistent state or helper registry. |
| 8. dd records | Pure `usb_dd_progress_bytes` interprets one supplied record; caller-owned stream/remainder and write/verify handling remain distinct. |
| 9. Native scalar reads | Impure `compozsh_plutil_raw` uses the fixed system binary on supplied text. Optional-field policies stay in callers; the shared reader clears failed outputs and retains native failure status. |
| 10. Installer metadata | Candidate assembly reuses the root-stat portion of its existing fingerprint, removing one repeated stat subprocess. Action-time revalidation remains fresh. |
| 11. Git OIDs | Pure `compozsh_git_valid_oid` owns full 40/64-character hexadecimal validation for review and worktree. |

The comparison-subtitle comment now describes state-dependent presentation.
AGENTS.md also documents regex-output localization and Zsh local-initializer
ordering so future pure functions avoid the reproduced hidden dependency.
README's layout/inventory and SECURITY's read/effect boundaries are synchronized.

Actual bug regressions were red before their fixes. Characterization covered
existing behavior before extraction; no real device operation or authorization
was used. The immediate pre-change baseline is the preceding 707-test green
suite and an isolated copy of the production peers for before/after checks.


### Integration and performance evidence

Integration caught an optional-parent guard precedence regression in the OID
migration. Grouping the guarded predicate restores root commits; an added
real-Git regression exercises both root-commit file capture and diff reading.
Before the correction both returned status 2; afterward both returned 0 and
preserved the added file's literal content. Direct-source fixtures were also
updated to load their extracted capabilities without weakening assertions.
Missing lexical support has an explicit regression: owned highlighting stays
plain and nonempty drafts show neutral context rather than exposing unclassified
assignment values. Missing dd parsing support refuses writing before launching
the worker.

Five interleaved isolated samples of 4,000 calls per shape measured:

| Predicate | Before | After |
| --- | ---: | ---: |
| Assignment match | 14.81 µs | 17.03 µs |
| Assignment nonmatch | 13.97 µs | 16.33 µs |
| Redirection match | 9.43 µs | 9.66 µs |
| Redirection nonmatch | 10.64 µs | 10.51 µs |

Regex-state isolation adds approximately 2–3 µs per assignment check.
Redirection performance is effectively unchanged. Fourteen retained warm,
interleaved isolated startup samples after three warmups measured medians of
66.723 ms before and 66.614 ms after; this small difference does not establish
a startup improvement. Measurements used disposable HOME/ZDOTDIR, minimal PATH,
fixed UTF-8 locale and stock Zsh, with no private initializer.

A synthetic capture-count regression proves that macOS installer candidate
assembly now reuses fingerprint metadata instead of issuing a second identical
root stat. No elapsed-time gain is claimed for that change. The final structure
has 77 shipped peers: 25 pure function entries, 20 impure function entries,
13 callable UI entries, two support configuration peers and 17 feature peers.
Production peer text changes from 26,168 to 26,206 lines; the gains are shared
ownership, consistent behavior and the corrected bugs, rather than total line
count reduction.

Final integrated verification: **725 passed, zero failed, 164.1 seconds**.
Coverage includes root commits and native Git review, USB media workflows,
lexical privacy/fallbacks, shared callbacks, source-order convergence, private
helper ownership, independent/repeated support loading and installation layouts.
All 77 shipped peers match README's inventory. Shell syntax, whitespace and an
additional isolated double bootstrap load passed. Manual Terminal.app visual
acceptance was not performed. All eleven audited groups and the misleading
purity comment are resolved; this is not a proof that no other duplication exists.
