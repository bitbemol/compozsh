# General Git comparison in the review workspace

Status: implemented; the user confirmed the revised interaction feels easy to follow.
Recorded: 2026-09-02. Source baseline: `0bc9098`.

## Interaction revision after the user's first trial

The user could not tell how to choose the second branch and found the
comparison wording confusing. The original From/To setup and automatic To
selection did not communicate the pair clearly enough. The first trial is
evidence of a usability problem despite passing implementation tests.

The current guided flow supersedes the labels and entry sequence in the
original design record below:

```text
Compare branches or commits

[1] Compare · feature/search
[2] Against · Choose branch or commit…
[3] Show · All differences
```

Compare starts at the highlighted branch/current HEAD; Against starts empty
and focused. Both rows explicitly change their branch or commit with Enter.
Each chooser keeps the other side visible. Once both choices resolve, the
fourth action is Review differences, with a summary saying “Compare
feature/search against release/next”. Editing either choice preserves the
other. All differences retains exact old→new semantics. Changes since common
ancestor retains the ancestor→target method; its explanation names both
selected values. Reopening Show selects the currently chosen method.

The chooser now accepts its best matching ref on Enter. Previously, its first
row was always Enter revision, which redirected even matching branch queries
to another text-entry view. Enter branch or commit now stays second after the
best ref, or first when none match. It must not be appended to a growing
result prefix: that would move the action away during pagination. Branch
labels stay simple, while tags and remote-tracking refs retain their kind to
distinguish identical short names. Literal digits/paste remain supported.

Direct syntax is unchanged: `g --review A B` means Compare B against A.
Providers, pinned IDs, local-only behavior and the two-pane reader are unchanged.
New tests first failed for the missing pair affordances, wrong Enter target,
method reset and lost ref-kind identity, then passed after their fixes. Native
PTY coverage now selects both actual branch endpoints, changes the initial
Compare branch, opens the correct diff and restores both choices on Back.

Validation of this revision: all 14 focused comparison tests and both public
help checks passed. UI and architecture re-review reported no further
actionable findings. A fixed-copy unfiltered suite passed **449 tests, zero
failures**, in approximately 101 seconds. Native syntax, isolated double
sourcing and whitespace checks also passed. These checks establish behavior,
not usability success. In the next trial, the user confirmed the revised
interaction feels easy to follow and then requested a commit.

Before committing, the Git feature and its supporting fixes were staged
separately from concurrent Xcode work, including shared renderer, help and
documentation edits. An export of that staged tree passed the unfiltered
suite: **437 tests, zero failures**, in approximately 97 seconds.

The sections below preserve the original design and first implementation's
audit record. Current user-facing instructions are in the README and `g --help`.

## Recommendation

Extend Git review with **Compare revisions…**, preserving Working changes and
Branch commits and reusing their file navigator and primary diff reader.
Offer two explicitly named methods: **Exact versions** (default) and **Since
common ancestor**. Provide an expert entry through the existing `g` command:
`g --review A B`. Both entries resolve the same comparison and open the same
reader. Branches, tags and commit IDs identify endpoints, not different tools.

The value is orientation while reading: a visible comparison, a stable file
map, independent scrolling, retained source position and optional full context.
Success means users choose and understand the right comparison with little
setup, then concentrate on code. Feature count is not the success criterion.

## What existed at the source baseline

The feedback describes comparison against `develop`. This checkout has no
hard-coded `develop` baseline. Its actual routes are:

| Existing route | Actual scope |
| --- | --- |
| `g` → Ctrl-X → Working changes | Current checkout; separate staged/unstaged rows and untracked previews |
| `g` → Ctrl-X → Branch commits | Local history reachable from the highlighted branch's captured tip |
| Commit → files | Commit versus its first parent; root commits use the empty tree |

History is not restricted to a first-parent walk; the *comparison for a selected
commit* uses its first parent. The working checkout is independent of the
highlighted branch. Preserve both distinctions.

Evidence: [public workflow](../README.md#read-only-git-review),
[review providers/controllers](../.zsh.addons/.zsh.git-review),
[wrapper and help](../.zsh.addons/.zsh.navigation), and
[review contracts](../AGENTS.md#git-review-workspace-boundary).
Any different installed or historical workflow needs its own evidence before
claiming compatibility with it.

## Research and design implications

These are cognitive psychology and HCI arguments, not neuroscientific
validation of this interface. Research motivates hypotheses; user observation
must establish whether the actual terminal interaction helps.

| Evidence | Proposed application | What remains unproven |
| --- | --- | --- |
| Recognition cues reduce the need to reconstruct commands or names from memory. [NN/g, recognition and recall](https://www.nngroup.com/articles/recognition-and-recall/) | Show named refs with their kinds; keep endpoints, direction and method visible. Allow literal entry when users already know an ID. | This exact chooser's speed and error rate |
| Progressive disclosure gives common operations priority while moving secondary choices into a related view. [NN/g, progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/) | One new review-menu item; comparison setup appears only on that route. Keep three-line context as the reader default. | Whether the additional setup step earns its cost |
| An observational/interview/survey study identifies code and change understanding as central to review. [Microsoft Research, ICSE 2013](https://www.microsoft.com/en-us/research/publication/expectations-outcomes-and-challenges-of-modern-code-review/) | Preserve the file navigator and continuous reader; make the question being answered explicit. | A productivity advantage for Compozsh or a particular pane ratio |

Product hypotheses: stable landmarks should reduce reorientation; unchanged
keys should transfer existing learning; reversible setup should make exploration
comfortable. Never claim a universal working-memory item count, an optimal
number of clicks, or a neuroscience-derived column ratio. The existing terminal
layout and latency evidence are stronger starting points than a speculative
redesign. See [key-repeat investigation](git-review-key-repeat-latency.md).

## The comparison question

| Method | Meaning | Git semantic reference |
| --- | --- | --- |
| Exact versions | Difference from the committed tree at A to the committed tree at B | `git diff A B` |
| Since common ancestor | Difference from the unique best common ancestor of A and B to B | `git diff A...B`, when the base is unique |

Git's two-dot diff form is also an endpoint comparison; its three-dot diff
form is directional. It is not a symmetric comparison of both branches' unique
commits. These meanings differ from history-range notation.
[Git diff documentation](https://git-scm.com/docs/git-diff).

Example: `develop` changes `baseline.txt` after a shared commit; `feature/search`
changes `feature.txt`. Exact versions includes both files, expressing what
differs between the tips. Since common ancestor includes only `feature.txt`.
The latter is often useful for reviewing a contribution, but does not predict
merge results or conflicts. Present it as a method, never infer it from a name,
ref kind, upstream, or presumed pull-request target.

The main UI uses words rather than dot-count syntax. Default every new generic
comparison to Exact versions. Branch history and Working changes retain their
existing semantics. A routine comparison with `develop` remains possible by
selecting it explicitly; there is no guessed base or persistent preference.

## Entry points

### Guided entry

Keep `g`'s branch switch/copy behavior and the first two review choices intact.
Append one item:

```text
Compozsh / Git review

[1] Working tree · Review working changes
[2] Selected branch · Commits in feature/search
[3] Compare revisions…
```

Compare consumes the current repository and uses the selected branch as the
initial **To** endpoint. It never checks that branch out. **From** starts unset.
Both endpoints remain editable, so comparing two unrelated branch names or
two hashes does not require returning to Branches. Without a selected branch,
use a valid captured HEAD as To; an unborn HEAD leaves it unset. Available
local tags/refs can still supply both endpoints in an unborn checkout.

Use a small existing-style choice list:

```text
Compozsh / Git review
Compare revisions · committed content

[1] From       Choose revision…
[2] To         feature/search · branch
[3] Method     Exact versions
[4] Open comparison
```

Focus the missing endpoint initially. After choosing it, focus Open comparison.
With either endpoint missing, omit the Open action and explain the missing
input in passive text. The final Open step commits the comparison choices; it
is not an additional security confirmation. No confirmation follows it.

Selecting Method shows two choices with their actual meaning and direction.
Do not add an immediate mode-toggle key. Changing setup edits a draft; it does
not recapture a large diff until Open. Back from the reader returns to setup
with endpoint and method choices intact. Reopening unchanged captured choices
preserves their IDs; choosing a ref again explicitly acquires its current ID.

### Exact input and ref recognition

Use one endpoint chooser with bounded local branch, tag and remote-tracking
ref candidates. Each row has a name plus kind, e.g. `develop · branch`,
`v2.1 · tag`, `origin/develop · remote-tracking`. Remote-tracking means metadata
already on this machine; it says nothing about the current server state.
Details can show the full ref and captured commit ID without collecting author
identity or commit messages. Capture on chooser entry, never on each keystroke.

Offer an actionable **Enter revision…** row as well as captured refs. Keep it
reachable with zero matches; it opens the existing shared text-entry mode,
optionally seeded with the chooser query. Label that field **Revision**, disable
digit selection, retain literal digits/paste, and validate only on submission.
Do not interpret a filter as a revision or execute it on Enter unexpectedly.
Both the action and refs are real selectable candidates; counts describe refs
separately from the entry action.

The initial accepted input is a local branch/tag/remote-tracking ref, HEAD, or
an unambiguous full/abbreviated commit ID. Annotated tags must peel to commits.
Do not promise arbitrary Git revision expressions, reflog queries, ranges,
paths, blobs or trees in this version. A submitted name that matches multiple
ref kinds requires selection of its exact qualified ref. Keep invalid input
editable with an inline explanation, including what forms are supported.
Typing never runs a subprocess; resolving an accepted value may do so.

### Direct entry for known endpoints

Implemented syntax:

```text
g --review
g --review develop feature/search
g --review 4e12ab7 93cd201
g --review --merge-base develop feature/search
```

`g --review` opens the review choices directly, using the current checkout's
branch/HEAD context. Exactly two endpoints opens their reader directly, with
Exact versions unless `--merge-base` is explicit. There is no setup screen or
confirmation for a complete valid pair. One endpoint is a usage error, rather
than an implicit comparison with the mutable worktree. No arbitrary diff flags
or path operands in this first version. `g --review --help` shows deterministic
mode guidance; the same-source `g` help remains canonical.

This is an intentional wrapper extension, like the existing `g --worktree`:
reserve only `--review`, preserve ordinary Git delegation and `g diff`, and do
not intercept `g review` (which could be a user's Git alias). It introduces no
new public function, alias, key or peer. Update the wrapper's documented
argument contract with implementation. Missing review/picker capabilities
produce an actionable failure; never substitute a differently scoped raw diff.
Noninteractive direct review fails clearly before acquiring screen ownership.

## Reader behavior

Keep the existing navigator-left, continuous-diff-right document workspace.
The two panes represent **files and reading**, not a new old/new split. Keep
the 90-column focus-based fallback, colors, independent scroll, selection
settlement, source anchors and bounded syntax provider.

The user should always be able to answer: which repository, which versions,
which direction, and which method? In Exact versions, show From and To names
with short captured IDs. In Since common ancestor, show the **actual computed
ancestor** as the old endpoint and the target as the new endpoint; retain the
requested reference name in context/details. A headline saying only
`develop → feature/search` would conceal the changed old endpoint.

Use current title/status/context regions, with complete IDs in details/guide.
At narrow sizes, drop branding and secondary metadata before hiding method,
direction or target. Do not make precision depend on red/green colors alone.
File counts describe captured results; addition/deletion counts describe the
retained patch. An incomplete capture is never labeled a complete review.

Keep the key map:

- Right/Left: files → focused diff → full context and back; no endpoint changes.
- Tab/Shift-Tab and Ctrl-E/B: pane focus only.
- Up/Down and page keys: move the focused pane; reading never changes files.
- Ctrl-R: recapture the current file workspace using the **same captured IDs**.
- Escape: reader → comparison setup → review choices → original caller.
- Ctrl-K: shared guide. Ctrl-X remains inactive in the reader.

Ctrl-R must not follow a branch that moved during reading. To select newer
tips, return to setup and choose the named ref again, or invoke the direct
command again. State this in help and the comparison guide. A direct reader's
Escape returns to the prompt, because it has no setup caller. Cancellation
restores the prompt draft and cursor wherever entry owns them.

New endpoint IDs or a changed method create a new comparison observation:
discard old file/context/syntax caches and reading bookmarks. Returning through
setup preserves the choices, not a stack of old multi-file captures. Retain
source anchors across disclosure and Ctrl-R within one comparison, as today.

## Transition contracts

| Input → operation | Preserves | Produces / effect | Recovery |
| --- | --- | --- | --- |
| Selected branch → Inspect comparison setup | Repository; caller filter/selection/viewport/focus | Draft To endpoint; local resolution only | Back restores caller |
| Endpoint chooser entry → Discover refs | Repository and opposite endpoint | Bounded local ref snapshot | Failure leaves draft usable |
| Chooser typing → Refine | Captured refs, exact values and scope | Filtered results; no Git reads | Clear filter or enter a revision |
| Revision submission → Resolve target | Opposite endpoint and method | One validated commit ID; local reads | Ambiguity/error keeps editable input |
| Open comparison → Inspect | Captured endpoints and method | Effective pair, bounded files and selected diff | Failure returns to usable setup |
| File selection / disclosure → Inspect | Pair, method, filter and file identity | Bounded selected document; existing controller reads | Notice or retained safe capture |
| Ctrl-R → Discover current comparison facts | IDs, filter; surviving selection/focus/anchor | New snapshot epoch and invalidated caches | Existing refresh failure policy |
| Escape → Navigate back | Caller bookmark and comparison choices | Restored caller; release reader resources | No action to undo |

## Endpoint correctness and local-only boundary

All acquisition goes through the hardened review invocation boundary. Reuse
disabled transport/lazy fetch, replacement refs, external diff/textconv, hooks,
fsmonitor, optional index writes and configured clean/process filters. Do not
write configuration, fetch a missing object, run a repository helper, check
out a branch, stage, copy, or launch an application. Support stock Apple Git
and Zsh; no new persistent storage, daemon or startup work.

Resolve before capture. Keep the requested label, exact ref when applicable,
and full commit ID separately. A ref candidate uses its full captured ref/ID;
an abbreviation must identify one commit. Do not rely solely on successful
`rev-parse --verify` for ambiguous short names: Git can succeed with a warning.
Validate the allowed input and disambiguate namespaces, then use
`rev-parse --verify --end-of-options` with commit peeling as appropriate. Only
validated full IDs reach diff providers; retain SHA-1/SHA-256 support.
[Git rev-parse](https://git-scm.com/docs/git-rev-parse).

For Since common ancestor, request all best merge bases and require exactly
one complete valid result. Git can have multiple equally good bases, and a
single unqualified result is not a deterministic selection contract.
[Git merge-base](https://git-scm.com/docs/git-merge-base).

| Condition | Visible result |
| --- | --- |
| Same tree / same endpoint | Successful empty comparison with named endpoints |
| No available common ancestor | Explain absent/incomplete local ancestry; offer returning to Exact versions |
| Multiple best ancestors | Explain ambiguity; let user choose an explicit From commit with Exact versions |
| Missing object / shallow or partial history | Unavailable locally; no automatic fetch or empty-tree substitution |
| Branch moved after capture | Continue using captured IDs; no automatic following |
| Tag points to a noncommit | Refuse it with supported-input guidance |
| Dirty current checkout | Excluded from committed comparisons; Working changes remains available |
| Submodule, binary, rename, oversized output | Retain current exclusions/notices; renames remain add/delete |

Do not convert a failed common-ancestor request into Exact versions silently.
Do not describe a comparison as a merge preview, a conflict detector, a
range-diff, or an exhaustive Git diff frontend.

Use a ref cap of 1,000 entries and 256 KiB with a visible partial
notice. Missing rows in a capped catalog do not establish nonexistence;
explicitly submitted exact names can be resolved separately. Keep existing
file/patch/document limits, four retained raw snapshots, and 1 MiB aggregate
raw-cache ceiling. Output limits are not runtime or Git memory limits.

## Implementation shape

Reuse `.zsh.git-review` for providers and controllers and `.zsh.navigation`
for the `g` entry/help. Parameterize the existing committed-file and diff
provider around explicit old/new IDs, while retaining root-commit handling
and separate working-tree kinds. Remove first-parent-specific labels from the
generic provider; the commit-review caller supplies that meaning. Do not model
an arbitrary From endpoint as the target's actual parent.

Resolve a comparison once, then use it for file-list, selected diff, full
context and refresh reads. Associate cache/syntax identity with the comparison
and snapshot epoch; numeric file rows alone are not identities. Selecting
another method cannot reuse old content under a misleading header.

Reuse the shared picker/text-entry capabilities, busy painter, one screen owner,
guide and cleanup. No new registry, generic workflow engine, lifecycle phase,
renderer or key parser. The existing first-parent reader is one caller of the
general committed comparison, not a second implementation to keep synchronized.

## Evidence gathered in this design pass

A disposable, isolated repository probe ran under Zsh 5.9 and Apple Git
2.54.0 (Apple Git-157). It used synthetic names/content, disabled global/system
Git config and transport, and cleaned its temporary repository. This is local
semantic evidence, not a platform-floor certification or performance benchmark.

Observed assertions:

1. Divergent tips changed `baseline.txt` and `feature.txt` in Exact versions;
   only `feature.txt` appeared from their common ancestor.
2. Identical endpoints produced a successful empty diff.
3. A branch/tag name collision returned success and selected the tag while
   emitting a warning: successful resolution alone is insufficient.
4. Moving the branch did not change a comparison using retained full IDs.
5. Unrelated commits had no common ancestor; an exact tree comparison worked.
6. Synthetic criss-cross parents returned two best merge bases with `--all`.

To reproduce the semantic questions in a disposable repository: create a root
with two files; fork `develop` and `topic`; change one distinct file on each;
compare `git diff --name-only develop topic` and
`git diff --name-only develop...topic`. Add a same-named branch and tag pointing
to different commits and inspect both stdout and stderr of
`git rev-parse --verify --end-of-options 'ambiguous^{commit}'`. Use
`git commit-tree` with reversed pairs of sibling parents to construct the
criss-cross case. These commands are investigation steps, not product code.

## Validation before shipping

Implementation evidence (2026-09-02): endpoint/provider, dispatch and setup
contracts were added first and observed failing before the corresponding
production changes. Native PTY journeys now exercise `g --review`, literal hash
paste, method selection, opening the reader, focused/full disclosure, guide,
120→80-column resize, retained setup and direct-entry cleanup. Moving a branch
while the reader is open leaves both captured IDs unchanged after Ctrl-R.
Fixtures verify index/checkout preservation, ordinary Git delegation, tags,
ambiguous names, root commits, unrelated histories, multiple merge bases,
literal special-character paths, missing old endpoints and ref capture limits.
The original native `g` journey also passes, including abort and missing-peer
fallback. Terminal.app fullscreen/windowed acceptance is still for the user;
native PTYs do not establish cognitive-load improvements.

The earlier full-suite stall was traced to shortest-prefix glob removal of a
terminal-exit marker near the end of a long Unicode trace. The terminal journey
had finished; its assertion was expensive. Equivalent literal occurrence
counts now verify exactly one exit marker. Assertions that inspect text after
the exit use longest-prefix removal only after proving uniqueness. This keeps
screen-restoration and redraw checks intact. The original Git journey completed
in about 3.9 seconds after that correction.

Local timing observations, with Zsh 5.9 and Apple Git 2.54.0: 12 isolated startups
had median 52.20 ms at HEAD and 53.10 ms for the current working tree. The latter
also contained concurrent worktree/Xcode changes, so this is a combined-tree
observation. In a disposable two-commit repository with 1,000 local refs, nine
observations per operation gave these medians:

| Operation | Median |
| --- | ---: |
| Resolve one named endpoint | 61.34 ms |
| Capture 1,000 refs | 327.33 ms |
| Filter captured refs | 3.88 ms |
| Existing commit file capture | 12.03 ms |
| Comparison file capture | 11.77 ms |
| Selected comparison diff capture | 12.38 ms |

Captures use the existing busy surface; refinement remains provider-free.
These observations include local process/storage costs and concurrent test
activity. They are not performance guarantees or compatibility thresholds.

Before independent review, a fixed-copy unfiltered run completed with 435 passes and
one failure in the concurrently developed Xcode narrow-window log layout test.
That Xcode test passed on a focused rerun against the later live checkout.
The fixed copy passed all six comparison tests and all 13 existing Git review
tests. Final comparison footer wording was subsequently checked with the native
comparison journey. Native syntax, isolated double sourcing, traversal-order
convergence, README peer inventory, security/privacy documentation and
`git diff --check` passed. This records the actual full-run result rather than
claiming a single all-green run across a changing working tree.

## Independent review and hardening

The user requested separate agent reviews after implementation. Performance,
architecture/code quality, UI/UX and bug/regression reviewers independently
examined the change. The primary agent also audited configured-executable
suppression, local-only behavior, index/working-file preservation, caller
environment, public help, source-order convergence and complete-suite results.

Confirmed findings and corrections:

| Finding | Correction and evidence |
| --- | --- |
| Repetitive ref names caused combinatorial fuzzy-glob backtracking; long labels exposed quadratic suffix scanning | Shared matching searches forward through literal characters while retaining prefix/substring priority; regression fixtures include capture-sized ASCII/Unicode labels, repeated characters, metacharacters and search labels. |
| Git shortened a current branch differently when a same-named tag existed | Both direct review entry and the original recent-branch source capture full ref identities and strip only the branch namespace. A real PTY fixture includes the collision. |
| Cancelling invalid revision input printed a stale error after successful cleanup | Guided error state belongs to the review menu; the native journey now cancels invalid input through every view and requires empty stderr. |
| A valid short branch name beginning with `refs/` was rejected | Only the three supported fully qualified namespaces are parsed as qualified input; `refs/topic` also resolves as a normal branch name. |
| Narrow layouts removed the direction and target label | A guarded pure subtitle formatter shortens endpoint labels independently, retains direction/IDs, and leaves repository/method in the summary. Unit and native painted-frame assertions cover this. |
| Editing a pair retained the old computed ancestor | Endpoint/method edits invalidate derived ancestry; setup describes unresolved ancestry until explicit Open computes it. |
| Full SHA-256 ancestor IDs were clipped in the guide | Each endpoint label and ID occupies a separate guide row. |
| Unborn HEAD left focus/status on the wrong setup step | Setup selects and names the remaining missing endpoint; Open appears only after both endpoints resolve. |
| Shared guide text implied committed comparisons followed working-file edits | Common reader guidance is scope-neutral; comparison context states pinned-ID refresh explicitly. |

The bug reviewer additionally exercised SHA-1 and SHA-256 repositories, nested
annotated tags, uppercase IDs, newline/tab/quote/colon/glob filenames, missing
objects, moving refs and nondefault diff configuration. Architecture re-review
checked the fixes and compared 19 matching cases with the original ranker,
including Unicode, combining marks, punctuation, backslashes and emoji; results
matched. No additional actionable issue was reported by that re-review.

The final matcher uses one ephemeral character array per candidate and forward
native array searches. Shortest-prefix removal and native scalar indexing both
showed quadratic behavior on near-end Unicode matches during investigation;
neither remains in the fuzzy path. The performance reviewer compared 42 cases
against the original matcher, including literal spaces, backslashes, glob
characters, Unicode and result limits; ranks and values matched. Three focused
regressions and all ten navigation tests passed.

Final independent local measurements (Zsh 5.9, Apple Git 2.54.0):

| Operation / fixture | Observed time |
| --- | ---: |
| Empty / prefix filter over 1,000 refs | 0.073 / 0.115 ms |
| Unmatched / fuzzy filter over 1,000 refs | 13.7 / 16.3 ms |
| Repeated-character query over 1,000 refs | 22.7 ms |
| Near-end match in a 262,000-character ASCII label | 29.4 ms |
| Near-end match in a 130,000-character Unicode label | 25.2 ms |
| 512-character query over a 262 KiB label | 70 ms |
| Named endpoint / full ID resolution | 51 / 65 ms |
| Ref capture in a 1,000-ref / 50,000-ref repository | 350 / 1,215 ms |
| Comparison file / selected diff capture | 13 / 15 ms |

The two capture-sized near-end cases previously exceeded a three-second
guard. The larger ref repository still retained only 1,000 refs with a partial
notice. Capture bounds limit retained data; they do not bound Git's internal
enumeration time, storage latency or memory. Measurements are environment
observations, not promised response times. The complete user-facing journey
still needs the user's Terminal.app acceptance.

Final review gate: a fixed copy of the completed working tree passed the
unfiltered native suite: **446 passed, 0 failed**, in approximately 98 seconds.
This includes all 11 comparison tests, the three matcher regressions, existing
Git review journeys, security/documentation contracts and the concurrent Xcode
work's tests. Native syntax, isolated double sourcing and `git diff --check`
also passed. Source checksums confirmed that the reviewed Git/editor/navigation
files and comparison/matcher tests remained unchanged during the suite run.
No commits or pushes were performed by this task.

### Historical design-pass validation

Design-pass checks: the six semantic probes above passed, as did focused
README inventory, security/privacy, network-client and privilege-boundary
contracts, native shell syntax checks and isolated double sourcing. The full
baseline suite reported 107 passes without a reported failure, then stopped
making progress in the existing native Git review journey test and was
interrupted. This is an incomplete full-suite run, not a passing gate or a
diagnosis of the cause. No production implementation was edited by this design
pass. Browser checks of the synthetic simulation covered both methods, retained
setup, full-context disclosure, 736/360-pixel layouts, invalid revision recovery
and numeric commit entry. The simulation checks cannot validate native ZLE
behavior or demonstrate a cognitive-load improvement.

### Adopted implementation acceptance plan

Use strict red-green-refactor for implementation. Add tests for endpoints,
method semantics and wrapper dispatch before changing production files. Keep
Working changes, root/first-parent review, ordinary `g diff`, switch/copy and
missing-peer behavior characterized. Cover ambiguous refs/IDs, tags, unrelated
and shallow histories, multiple bases, special filenames, failed/truncated
capture, disabled helpers/transport and unchanged repository/index state.

Test full keyboard journeys in native PTYs: guided pair selection, literal hash
paste with digits, caller restoration, direct entry/exit, disclosure, refresh,
resize, guide, abort and syntax cleanup. Test wide and <90-column layouts.
Measure entry capture, ref filtering, settled file load and repeat navigation
separately. Compare several runs against current review on identical fixtures;
do not turn retained-output caps into promised latency budgets.

Run the complete suite and repository verification gates. Synchronize README,
`g` help and help tests, shipped-unit responsibilities, SECURITY local-data
claims and independent checks, and AGENTS' entry/target/refresh contracts.
Any showcase example must remain a labeled simulation. This proposal alone
does not change those documents' claims about shipped behavior.

Conduct a formative study with roughly 5–8 developers spanning regular and
occasional Git users; this is a practical recruiting target, not statistical
proof. Use counterbalanced synthetic tasks and retain observations locally
with participant consent; add no product telemetry. Tasks:

- Review current uncommitted work using the existing path.
- Compare two supplied hashes without changing branches.
- Review a feature when its baseline has advanced independently.
- Explain the direction and included changes before reading the patch.
- Expand context, return to a previous file, then cancel back to the caller.
- Explain what refresh should do after a named branch moves.

Record correct comparison choice, endpoint/direction errors, time to the first
useful diff, help requests, recovery steps, lost-place incidents and reported
effort. Compare the current workflow, proposed guided entry and direct Git
where the task is possible; separate learning from experienced use. Persistent
confusion between methods or expectations that refresh follows moving refs
requires copy/flow revision before shipping. Do not claim the mockup or passing
tests establish lower cognitive load.

## Deliberate scope

Ship the two committed comparison methods and equivalent guided/direct entry
as one coherent extension. Leave arbitrary diff options, file-to-file diff,
range-diff, merge simulation, staging, persistent recent pairs, automatic base
guessing and a new old/new-column reader for separately demonstrated needs.
They introduce different questions and interaction costs. The proposed
extension earns its place by preserving a small, predictable reading workspace.
