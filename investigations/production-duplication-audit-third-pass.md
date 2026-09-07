# Third production duplication audit

Recorded 2026-09-06 after the [second cleanup](production-duplication-audit-second-pass.md#implemented-follow-up).
Three agents reviewed production UI, functionality and shared-support conventions.
The primary reviewer inspected repeated code windows and independently reproduced
the principal findings. The initial audit was read-only; the follow-up below records
the implemented corrections.

The result is three substantive groups plus one smaller purity opportunity.
Earlier fixes remain implemented; these findings identify remaining cases and
test gaps. No fixed quota or claim of exhaustive semantic uniqueness is used.
All source paths below are relative to `.zsh.addons/`, at the pre-fix snapshot.

## 1. Display-cell prefix clipping disagrees about combining marks

**Three implementations:**

- `.zsh.prompt:139`, `_prompt_prefix_abbreviate`: a character/cell-budget loop.
- `support/functions/.zsh.pure.zle_picker_fit:17`: native prompt truncation.
- `support/ui/.zsh.ui.zle_picker_inspect_render:322`: a separate native truncation
  path inside reader wrapping.

**Confirmed behavior:** with UTF-8 text `éabcde` and a two-cell budget, prompt
abbreviation returns `é…`, while picker fitting returns `e…`, losing the accent.
The same mismatch occurs at an ordinary 40-cell width using 38 `a` characters
followed by `érest`. A two-cell document wrap of `éabcd` produces these rows:

```text
e
́a
b
cd
```

The accent is separated from its original base and placed before the next letter.
These are synthetic display probes; no provider, real document or effect runs.

**Recommended boundary:** one pure prefix-by-display-cells operation returning
retained text and consumed character count. Preserve base/combining-mark attachment.
Leave ellipsis, padding, prefix-only autosuggestion privacy, prose word wrapping,
ASCII reader fast paths and source/span offsets with their existing callers.
This does not require merging complete renderers or promise full grapheme-cluster
support beyond the tested character contract. Add regressions for both clipped
labels and wrapped source positions before extraction; benchmark the fast path.

## 2. Two Xcode count readers validate after arithmetic conversion

**Sites:** `.zsh.xcode:208` declares integer `children`, then `:226` assigns
provider text before checking it. `.zsh.xcode:301` declares integer
`failure_count`, then `:323` does the same.

The later `<->` checks examine an already converted number. Zsh has evaluated
the original text by that point, so these checks do not establish literal
numeric input.

**Confirmed behavior with native capture replaced by stubs:**

- A supplied `root.children` scalar of `1+1` visits three nodes: parent plus two
  children, instead of rejecting the malformed count.
- A supplied `testFailures` scalar of `1+1` creates two retained failure rows.

The probes demonstrate arithmetic interpretation and ineffective validation;
they do not demonstrate arbitrary command execution. No Xcode operation, device
access or private data was involved.

**Recommended boundary:** validate and bound the original scalar before assigning
it to an integer, reusing the existing literal decimal-limit calculation. Preserve
64 children per node, 20 retained failures, and the independent depth/node budgets.
Test malformed expressions, leading zeroes, zero and oversized decimal text.
A second generic numeric parser would recreate duplication.

## 3. macOS review subtitle depends on an inherited index

**Site:** `.zsh.usb:1842`, `_usb_macos_review_choose`:

```zsh
local installer=$1 disk_index=$2 disk=${_USB_DISK_IDS[disk_index]}
```

The array expression reads the caller's `disk_index` before argument 2 is bound
locally. Later label construction reads the newly bound index. This repeats the
same defective initialization pattern previously repaired in SHA/CRC readers
and violates the now-documented local-initializer convention.

**Confirmed behavior:** captured drives `disk7`/`disk8`, caller-local index `1`,
and explicit argument `2` produce a subtitle ending `/dev/disk7` beside the
choice `Change drive · DriveB`. With no inherited index, the subtitle ends at
`/dev/`. The chooser was replaced by a printer; no operation executed.

The normal workspace caller currently passes its own same-named local, masking
the inconsistency. There is no demonstrated wrong-device write or changed final
action target in that existing journey.

**Smallest fix:** bind the supplied index, then derive the disk in a separate
statement. Test conflicting and absent caller-local indexes. No generic controller
or additional shared file is necessary for this correction.

## Additional purity opportunity: deterministic highlight-span splitting

`support/functions/.zsh.impure.zle_picker_highlights_shift:15` computes offsets
and clipping from supplied spans and numeric inputs, but `${=specifications}`
uses ambient `IFS`.

Identical supplied spans and numeric arguments produce
`1:3:picker-match 4:5:picker-dim` with default `IFS`, and no spans with `IFS=,`.
Its current impure label is therefore conservative and defensible, not a falsely
pure filename.

Localize whitespace splitting, clarify the validated numeric-input contract,
and this calculation can become a pure entry. Rename it and update its callers,
fixtures and public inventory together if that cleanup is adopted. The shared
matching fragment compiler already localizes `IFS`; equivalent queries remained
identical under the same probe, so it needs no duplicate fix or new split helper.

## Minimal independent probes

Historical pre-fix probes, retained as evidence rather than current reproduction
instructions. These snippets use
only synthetic data and stub the relevant provider/chooser boundaries.

```zsh
zsh -df -c '
  export LC_ALL=en_US.UTF-8
  source .zsh.addons/.zsh.prompt
  source .zsh.addons/support/functions/.zsh.pure.zle_picker_fit
  local text="éabcde" REPLY=""
  _prompt_prefix_abbreviate "$text" 2; print -r -- "prompt=[$REPLY]"
  _zle_picker_fit "$text" 2; print -r -- "fit=[$REPLY]"
'
# prompt=[é…]
# fit=[e…]
```

```zsh
zsh -df -c '
  source .zsh.addons/.zsh.xcode
  _compozsh_plutil_raw() {
    if [[ $2 == root.children ]]; then REPLY="1+1"; return 0; fi
    return 1
  }
  _XCODE_TEST_DETAIL_NODE_COUNT=0
  _xcode_test_node_sources_capture synthetic root
  print -r -- "nodes=$_XCODE_TEST_DETAIL_NODE_COUNT"
'
# nodes=3
```

```zsh
zsh -df -c '
  source .zsh.addons/.zsh.usb
  _USB_DISK_IDS=(disk7 disk8)
  _USB_DISK_LABELS=(DriveA DriveB)
  local disk_index=1
  _usb_choose() { print -r -- "$2 | $_USB_PICKER_LABELS[4]"; }
  _usb_macos_review_choose /synthetic/Installer.app 2
'
# ... → /dev/disk7 | Change drive · DriveB
```

## Verification and exclusions

- Seven focused support checks passed. Sourceability, entry-first naming and
  private-helper ownership remain conformant in the checked tree.
- Whitespace checks passed. The preceding full implementation run passed 725
  tests; this read-only audit did not rerun the entire suite. The probes above
  identify uncovered behavior to turn into regressions during a follow-up.
- No newly falsely pure shared entry or external private-helper dependency was
  established in the reviewed call chains. Structural checks do not prove
  semantic purity or exhaustive absence of bugs.
- Different Git ancestor policies, command-capture lifecycles, file-reader
  policies, simple span-intersection math, ordinary field assignments and
  necessary capability guards were excluded from the actionable duplication list.
- Small repeated option-operand loops and version-token fragments remain lower
  priority; similarity alone does not justify another configurable framework.

The initial audit made no performance claim and changed no production/private
configuration. All four findings were subsequently addressed below.


## Implemented follow-up

- Added pure `_compozsh_cell_prefix` and routed prompt prefix abbreviation,
  picker fitting and Unicode reader wrapping through it. Retained characters
  keep their following zero-cell marks; callers retain ellipsis, padding,
  prefix-only privacy, word wrapping and source/span offset policies. The reader
  keeps its printable-ASCII slicing fast path.
- Reused `_matching_decimal_limit` for Xcode child and failure counts before
  integer conversion. Malformed expressions are rejected, oversized decimal
  counts are bounded, and missing support yields neutral results.
- Bound the macOS review's supplied disk index before deriving its device label.
- Made highlight-span shifting deterministic with local whitespace splitting
  and bounded decimal validation before arithmetic. Renamed its peer to
  `.zsh.pure.zle_picker_highlights_shift`; the callable name is unchanged.
- Updated the README peer inventory/layout, SECURITY numeric-input guarantees
  and AGENTS conventions. Direct-source test fixtures load the new pure helper
  wherever they exercise its consumers.

Regression tests demonstrated the old failures before implementation. Integrated
verification and bounded performance observations are recorded below.

### Final verification

- Full native suite: **731 passed, 0 failed**, 169.6 seconds. This includes
  native PTY journeys, Xcode/USB regressions, source order, peer ownership,
  inventory and security/documentation contracts.
- Syntax checks across bootstrap, installer, template, tests, native fixtures
  and recursive peers passed; `git diff --check` passed.
- Double-sourcing the bootstrap in an isolated interactive shell passed with
  disposable HOME/ZDOTDIR and no machine-local initializer.
- Final inventory: 78 peers, including 27 pure and 19 impure function entries.
- Independent agent review found no concrete blockers in the changed production
  paths. Manual visual acceptance in Terminal.app was not performed; automated
  native PTY results do not establish visual glyph quality in that application.
- No real device operation, private configuration/history access, commit or push
  was performed.

### Performance observations

Measured locally on 2026-09-06 with stock Zsh 5.9 and UTF-8, comparing an
immediate pre-fix snapshot with the final implementation. Seven interleaved
isolated process pairs measured 1,000 calls per fitting/abbreviation sample,
or 20 reader preparations per sample. Clipping used a 40-cell budget; reader
samples used 100 synthetic 300-character lines and an 80-cell width. No real
history, files or provider capture were used.

| Operation | Before median | After median |
| --- | ---: | ---: |
| Truncated ASCII picker fit | 19.36 µs | 29.58 µs |
| Combining-accent picker fit | 17.20 µs | 36.27 µs |
| Short, untruncated picker fit | 11.53 µs | 11.94 µs |
| ASCII prompt prefix | 103.70 µs | 34.30 µs |
| Combining-accent prompt prefix | 102.02 µs | 41.09 µs |
| ASCII reader preparation | 8.04 ms | 8.27 ms |
| Unicode reader preparation | 14.56 ms | 23.85 ms |

Prompt prefix clipping improved in these samples, while shared calls and correct
Unicode boundary repair add work to picker fitting and Unicode wrapping. The
Unicode reader cost is approximately 9.29 ms per 100-line preparation; this is
a correctness/maintainability tradeoff, not an overall performance improvement.
Cached repaint was not measured. The ASCII reader retains its slicing fast path.

Fourteen retained interleaved startup samples after three warmups measured
68.29 → 68.77 ms median in separate disposable HOME/ZDOTDIR environments.
These are local observations, not compatibility thresholds or universal gains.
