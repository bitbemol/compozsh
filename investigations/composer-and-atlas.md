# Composing drafts and exploring captured changes

2026-09-04. Three connected native-terminal interactions, implemented on the
existing shared screen owner, input loop, palette and reader. No release tag,
installation change, external UI dependency or background daemon is involved.

## Implemented scope

- Option-Return offers a composer for bounded simple `g --review` and `mkcd`
  drafts. Git fields retain readable ref labels alongside pinned commit IDs;
  the generated command remains visible. Literal field entry repaints its draft
  preview as the user types. Replace draft is explicit insertion after cleanup,
  never execution. Unsupported syntax retains ordinary inspection.
- `g` and `mkcd` own private same-source template capabilities. Their help
  workspaces add a labeled Compose example action; matching its label prioritizes
  it ahead of prose mentioning it. Plain help remains inert. A template comes
  from authored code, not a parsed example, filesystem scan or central catalog.
- Change atlas is a review-menu entry for working changes and Ctrl-X navigation
  from working/commit/comparison file readers. Exact captured path prefixes
  group the existing list; bars count change entries. Staged and unstaged entries
  remain distinct. Folder → file → focused diff → full context composes with
  Back bookmarks and the original review source position.

The original line-count-bar concept was deliberately narrowed to **entry-count
bars**. The file list already supplies that information. Computing line counts
would require additional content reads, inconsistent with the selected-file
capture boundary. This atlas inherits the 1,000-row/256-KiB list bounds and
partial notices; it is not a recursive filesystem browser or an atomic snapshot.
Pending automatic refresh is stopped during atlas navigation and scheduled
again after returning, preserving the previous enabled/paused policy.

## Effect boundaries

The composer retains fields (4,096 characters each), folder and generated draft
in invocation memory. Native Zsh quoting protects literal argument boundaries.
Opening a Git revision field explicitly invokes existing safe local providers;
filtering and paint do not. Ref choices pin IDs. The initial main/HEAD values
are labeled/documented editable placeholders, not discovered default branches.
Missing Git support leaves literal entry available without claiming validity.
Accepted help drafts use the ordinary prompt buffer stack; editor entry replaces
BUFFER after restoration. No clipboard, custom history, project file, system
configuration or command execution is added.
Existing editor leading spaces survive composition, including the Help route;
native history policy must not silently change when a draft is replaced.

The atlas reads only a selected file through the existing bounded diff reader.
Its child reader must inherit the prohibition on uncached reads after failed
Git safety preparation. A regression initially demonstrated the missing guard;
the atlas now requires returning to review and successfully retrying refresh.

## Acceptance and evidence

Visual/interaction criteria: use the official palette and shared geometry;
keep the generated command visible; preserve the live field preview at narrow
widths; distinguish navigation from Replace draft; return to exact filters,
selection, focus and source position; restore ZLE after cancellation/insertion.

Native tests cover:

- Literal quoting round trips, metacharacters, unsupported prefill, same-source
  capability identity, scope ownership and absent-Git literal fallback.
- Real help → composer → path field → live preview → resize 120 to 40 columns
  → Replace draft; exact post-cleanup editor text and cursor, with no creation.
- Draft inspector → composer → cancellation restoring the original text/cursor.
- Real local main/topic selection with pinned IDs, retained readable labels,
  explicit insertion, unchanged branch/index and no execution.
- Actual `mkcd --help` completion placing its generated text on the native
  prompt stack; the test's vared editor explicitly pops that stack because
  vared does not do so automatically as the ordinary shell prompt does.
- Pure atlas grouping over newline/percent paths, duplicate staged/unstaged
  identities, nested folders and failed-preparation read refusal.
- Real Git menu/reader → atlas → folder/filter → Back → selected diff → full
  context → Back, preserving the original reader position and screen lifetime.
  Folder navigation is asserted to perform no Git captures.

`tests/compose_test.zsh`, `tests/compose_ui_test.zsh`, `tests/git_atlas_test.zsh`
and the extended `tests/git_review_native_test.zsh` retain those checks.
All peers also passed independent source, forward/reverse double-source,
syntax and whitespace checks. These are native PTY checks, not a claim of
manual visual approval in Terminal.app or every custom terminal profile.

An isolated native-Zsh measurement on the development Mac grouped 1,000
synthetic change entries into 50 folders in a median **9.38 ms** over 11 runs.
Grouping runs on level entry, not each repaint. This is a local observation,
not a universal latency threshold or a measurement of Git capture time.

Nine interleaved isolated peer-loading samples, while the regression suite was
also running, measured medians of 56.386 ms without `.zsh.compose` and 56.551 ms
with it. This comparison isolates the new peer's definition-time contribution;
it is not an idle-machine interactive-startup benchmark. No new source-time
provider work or project cache was introduced.

## Final regression results

The final 638-case suite completed with **637 passed and one optional Git
syntax-provider timeout** (`sample.sh: plain syntax · unavailable or time
limit`). An immediate isolated rerun of that unchanged language-allowlist check
passed (247.3 ms). Earlier broad runs passed all 636 and then all 637 registered
cases before the last additional comparison-scope assertion was added; that
assertion also passes in the final run. The timeout remains recorded rather
than reporting the final broad run as entirely green. No timeout threshold or
syntax-provider implementation was changed to obtain a passing rerun.
The complete Git syntax group then passed **22/22** in isolation (3,310.9 ms).

All six command-composer tests, three atlas tests, seven existing help-workspace
tests, and the extended native Git journey passed. Final evidence logs are
development artifacts under `/private/tmp/compozsh-composer-atlas-release-candidate-suite.log`
and `/private/tmp/compozsh-composer-syntax-rerun.log`, not shipped product data.
