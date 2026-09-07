# Production duplication audit

Initial audit recorded 2026-09-06 against the then-current working tree, following the classified
support-entry migration. Three agents independently reviewed UI/UX duplication,
functional duplication, and convention/purity compliance. The primary agent
consolidated their findings, inspected the strongest repeated implementations,
and independently reproduced the abbreviation mismatch. The initial audit made no production changes. The implementation follow-up below
resolves all ten groups; original locations describe the pre-fix snapshot.

## Result and scope

The three focused support checks passed: independent/repeated sourcing,
filename/first-entry agreement, and private-helper ownership. No cross-file
private-helper call or incorrectly pure entry was found in the inspected shared
call chains. These checks establish structural properties; they cannot detect
all semantic duplication or prove purity automatically.

The ranking below weighs existing behavioral drift and maintenance impact,
not just repeated line count. Occurrence counts are implementation sites,
sometimes with intentional policy differences. Groups can overlap, especially
Git filter handling and bounded capture; their sizes must not be added together.
The initial audit contained no new performance measurement. Follow-up evidence
is recorded below.

## Original ranked findings (resolved by the follow-up)

1. **Git content-filter overrides: three implementations, with hardening drift.**
   `_prompt_git_filter_config` in `.zsh.addons/.zsh.prompt:313`,
   `_tools_git_filter_config` in `.zsh.addons/.zsh.tools:165`, and
   `_git_review_prepare` in `.zsh.addons/.zsh.git-review:149` derive and
   deduplicate filter driver names before building invocation-only overrides.
   Review rejects driver names containing `=` at line 164 and bounds generated
   arguments at line 169; the other two copies omit those protections. Git's
   `-c key=value` transport cannot faithfully encode such a driver name.
   Extract a pure captured-name-to-validated-arguments entry, with acquisition
   kept impure. Preserve Tools' additional `smudge` override. The initial audit
   demonstrated inconsistent hardening. The follow-up subsequently reproduced
   unintended local filter execution with a harmless synthetic marker.

2. **Middle abbreviation: three implementations, with a reproduced width bug.**
   `.zsh.addons/.zsh.navigation:40`, `.zsh.addons/.zsh.prompt:160`, and
   `support/functions/.zsh.pure.zle_picker_abbreviate:7` under `.zsh.addons/`
   calculate a shortened label retaining both ends. With `LC_ALL=en_US.UTF-8`,
   `_navigation_abbreviate "界界界界界界" 8` returns all six characters,
   occupying 12 cells; the shared helper returns `界…界界`, occupying 7 cells.
   Consolidate into a pure calculation with explicit head/tail bias and preserve
   the prompt implementation's combining-mark treatment. Prefix-only
   autosuggestion truncation has a different contract.

3. **Palette role resolution: four direct copies and two related variants.**
   `.zsh.output:8`, `.zsh.usb:4815`, `.zsh.editor:118`, and
   `support/ui/.zsh.ui.zle_picker_show:261` repeat override selection, numeric
   validation and fallback lookup. Related prompt-role variants occur at
   `.zsh.prompt:13` and `.zsh.tools:121`. All paths are under `.zsh.addons/`.
   Introduce an impure shared resolver over mutable palette maps, or a pure
   resolver supplied the actual candidate/fallback values. Preserve appearance
   without the optional Output peer. Keep ANSI, prompt and ZLE styling separate.

4. **Bounded synchronous output capture: four implementations.**
   `.zsh.git-review:122`, `.zsh.git-worktree:38`, `.zsh.prompt:313`, and
   `.zsh.tools:165` under `.zsh.addons/` repeat stdout plus trailing NUL/status,
   bounded lookahead reads and packet splitting. Share the impure capture
   mechanism with explicit limits and completion/status outputs. Review may
   retain a marked partial prefix; Worktree requires a complete snapshot;
   filter discovery accepts Git statuses 0 and 1. Keep these decisions in
   callers. Exclude the asynchronous Review worker and its PID/timeout ownership.

5. **Matching-index projection into UI state: four adapters plus a partial owner.**
   `.zsh.navigation:62`, `.zsh.help:743`, `.zsh.usb:1437`, and
   `.zsh.xcode:1693` repeat clearing result arrays, invoking the shared matcher
   and projecting indexes into values/labels. The existing partial owner is
   `support/functions/.zsh.impure.zle_ui_action_collect:7`, all beneath
   `.zsh.addons/`. Generalize the state adapter with explicit array and numbering
   inputs. Preserve source order, ranked policies, optional search text and
   exact values. Benchmark early matches before accepting extra indirection.

6. **Git operation detection: two filesystem decision trees.**
   `.zsh.addons/.zsh.prompt:276` and `.zsh.addons/.zsh.tools:140` repeat marker
   checks for merge, cherry-pick, revert, bisect and rebase. Tools additionally
   checks the sequencer directory at line 155. A shared impure entry should
   consume an explicit Git metadata directory. Preserve conservative action
   gating and decide display coverage explicitly; the difference is not by
   itself proof that the prompt is incorrect.

7. **Folder actions discard and reconstruct shared catalog metadata.**
   `.zsh.addons/.zsh.editor:825` keeps only values and labels from the shared
   catalog, queries details again at line 921, and rebuilds acceptance labels
   at line 931. `.zsh.addons/.zsh.find:510` already consumes full tuples from
   `support/functions/.zsh.pure.zle_ui_path_actions`. Retain applicable catalog
   fields while assembling folder choices. Preserve folder grouping, path
   descriptions and the intentional linked-directory acceptance wording.

8. **USB progress calculation: two presentation assemblies.**
   `.zsh.addons/.zsh.usb:2467` and `:2842` repeat byte clamping, percentage/bar
   construction, size formatting and elapsed-time text. Extract a pure result
   model supplied bytes, total, elapsed, width and optional phase. Provider
   reads and interpretation of observed progress remain with their callers.

9. **Display control-character sanitization: four identical policies.**
   `.zsh.prompt:140`, `.zsh.navigation:36`, `.zsh.help:623`, and
   `.zsh.tools:136` under `.zsh.addons/` all implement
   `REPLY=${1//[[:cntrl:]]/?}`. A pure entry can own the display transformation.
   Preserve prompt escaping as a separate step and never sanitize the exact
   underlying action target. Code-volume savings are small; policy consistency
   is the reason to consolidate.

10. **Safe decimal-limit clamping: two copies inside shared matching.**
    `.zsh.addons/support/functions/.zsh.pure.matching_search:22` (its private
    `_matching_filter`) and `.zsh.pure.matching_select:10` in the same directory
    both validate decimal text, strip leading zeroes, compare lengths/value
    before arithmetic and clamp to the candidate count. A pure shared limit
    calculation is possible, but benchmark the extra call in the matching hot
    path. This is lower priority than the demonstrated divergences above.

## Deliberate boundaries to retain

- Git wrappers share parts of their isolation policy, but explicit roots,
  inherited selectors, mutations and direct worker `exec` have different
  contracts. A broad universal Git executor is not justified by this audit.
- File/folder quoting has different authored-tilde and absolute-home semantics.
  Do not merge these by visual similarity alone.
- File, folder, USB and Xcode controllers have distinct acquisition, navigation,
  cleanup and confirmation contracts. Share mechanisms rather than whole loops.
- The browser showcase uses bounded synthetic simulations. Similarity to native
  shell operations is not a reason to make it execute or import shell behavior.

Any implementation follow-up must use the canonical AGENTS.md convention:
one declared entry first, exclusive private helpers below it, and pure/impure
classification based on the complete call chain. Start with characterization
coverage, then add failing regressions for actual behavioral changes. Preserve
missing-peer fallbacks and benchmark affected hot paths.


## Implemented follow-up

All ten ranked groups were addressed on 2026-09-06. Each new support file follows
one declared entry first, exclusive helpers afterward and pure/impure naming.
The current README inventory is authoritative; the line references above are
historical. No forwarding implementation or loader phase was introduced.

| Group | Shared ownership and preserved caller policy |
| --- | --- |
| 1. Git filter overrides | Pure `compozsh_git_filter_overrides`, with impure `compozsh_git_filter_config` acquisition. Prompt and discard inherit review's ambiguous-name rejection and 4,096-argument bound. Restore explicitly includes smudge. |
| 2. Middle abbreviation | Pure `zle_picker_abbreviate` now serves prompt, navigation and pickers, with explicit bias and combining-mark handling. Removed both feature copies. |
| 3. Palette resolution | Impure `compozsh_palette_color` validates output/prompt roles and shared fallbacks. Callers retain their terminal encoding and plain-output policy. |
| 4. Synchronous capture | Impure `compozsh_capture_bounded` returns payload, completion and command status. Review permits marked partial results; Worktree and filter discovery require complete capture. Async worker lifecycle remains separate. |
| 5. Matching projection | Impure `zle_ui_collect` owns six callers' result/label projection with explicit source/ranked matching, metadata and numbering policies. It replaces the narrower action collector. |
| 6. Git operations | Impure `compozsh_git_operation` reads supplied Git metadata. Discard requests sequencer detection explicitly; prompt retains its concise labels. |
| 7. Folder metadata | Folder choices retain descriptions and acceptance metadata from the existing pure path-action catalog. Linked-directory wording and grouping are preserved. |
| 8. USB progress | Pure `usb_progress_model` assembles captured bytes, total, elapsed and optional phase. Size, duration and bar calculations each have their own pure entry; provider reads stay in callers. Windows stages retain their distinct labels while sharing those primitives. |
| 9. Sanitization | Pure `compozsh_sanitize` replaces four copies; only display text changes, with exact operation targets preserved. |
| 10. Decimal limits | Pure `matching_decimal_limit` owns literal validation and clamping for both matching paths, before arithmetic conversion. |

The new generic projection also rejects array names that alias return parameters
or its UI outputs. A red regression demonstrated silent empty results when a
supplied search array was named `REPLY`; the fixed API rejects that ambiguity
without changing the supplied array. Current feature arrays use distinct names.

A synthetic disposable Git repository reproduced unintended local filter
execution through a driver name containing `=` before the change. The regression
uses a harmless local marker and now passes. Wide-character navigation overflow
was likewise reproduced before consolidation and is covered by a passing test.
Missing optional presentation support remains bounded/plain; late loading restores
the shared presentation. Missing Git safety support omits capture or refuses the
action. No network, private configuration or real device operations were used.

### Verification and measurements

The immediate pre-fix suite was green: 693 tests, zero failures, 169.9 seconds.
An independent before/after comparison covered 144 collector cases across all
six adapters, literal/Unicode queries and decimal limits. Status, exact values,
labels and numbering matched byte for byte. Display differential coverage over
7,344 character/width/bias combinations matched the previous prompt algorithm.

Abbreviation medians from five runs of 2,000 calls, microseconds per call:

| Captured input | Previous prompt | Shared entry |
| --- | ---: | ---: |
| Short, untruncated | 16.52 | 12.41 |
| ASCII path, 24 cells | 71.17 | 27.74 |
| Unicode, 12 cells | 44.01 | 28.65 |
| 1,000 characters, 36 cells | 161.29 | 81.51 |

The previous picker algorithm measured 20.37 microseconds for ASCII truncation;
the shared version measured 27.74. Bias and combining correctness add about
7 microseconds there. These are calculation timings, not terminal painting.

Shared Git filter capture showed no meaningful speed improvement: three
interleaved samples of 100 captures measured 13.105→13.410 ms for an empty
configuration and 15.758→15.691 ms for 100 drivers. Its principal gain is shared
safety behavior. All timings describe this stock-Zsh/macOS environment and are
observations, not product thresholds.


Collector medians from five quiet interleaved sample pairs, 40 calls per workload,
1,000 synthetic candidates and a ten-result limit (milliseconds per call):

| Caller / query | Before | After |
| --- | ---: | ---: |
| Navigation / empty | 0.106 | 0.170 |
| Navigation / early prefix | 0.225 | 0.288 |
| Navigation / unique final-row match | 16.754 | 16.622 |
| Navigation / no match | 17.501 | 17.317 |
| Usb / empty | 0.084 | 0.137 |
| Usb / early prefix | 0.200 | 0.252 |
| Usb / unique final-row match | 15.796 | 15.864 |
| Usb / no match | 16.442 | 16.430 |
| Xcode / empty | 0.086 | 0.139 |
| Xcode / early prefix | 0.186 | 0.233 |
| Xcode / unique final-row match | 5.707 | 5.776 |
| Xcode / no match | 6.311 | 6.329 |

The shared validation/projection adds 0.048–0.064 ms to empty/early queries.
Full scans remain broadly unchanged within observed variation. The adapter
preserves lazy matching and avoids copying complete candidate arrays. This is
an explicit small latency tradeoff for one projection and limit implementation,
not a collector speedup.

Fourteen retained interleaved warm startup samples, using disposable HOME and
ZDOTDIR, a minimal PATH, fixed UTF-8 locale and no private initializer, measured
66.268→66.962 ms (about 0.69 ms added). The shipped inventory grew from 57 to
68 focused peers. Total production peer text changed from 26,185 to 26,168 lines:
removed duplication is largely balanced by explicit contracts, guards and the
new file boundaries. Line count alone is not the gain claimed by this pass.


Final integrated verification: **707 tests passed, zero failed, 165.1 seconds**.
This includes native PTY journeys, normal/reverse/rotated peer convergence,
independent/repeated support sourcing, first-entry/filename agreement,
private-helper ownership, literal targets, fallbacks and installer layouts.
The README inventory matches all 68 shipped peers. Full shell syntax checks,
whitespace checks and an additional isolated double bootstrap load passed.
An intermediate integration run exposed stale direct-source fixtures; those
were updated to load the extracted capabilities while preserving assertions.
Manual Terminal.app visual acceptance was not performed.
