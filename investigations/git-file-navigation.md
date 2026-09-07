# Git file navigation

## Adopted behavior

Git Working changes, Commit files and comparison readers start in All files.
Ctrl-X opens View options with All files, Tree, Jump to ancestor and Change atlas.
The existing options gesture and digit acceptance provide direct selection
without intercepting Tab, disclosure arrows or Terminal.app tab shortcuts.

Both projections consume the same bounded change list. Files keep their numeric
snapshot identities; directories use exact captured prefixes. Staged and
unstaged entries remain distinct. All files uses filenames with separate
status metadata and adds parent paths for duplicate names. Its details expose
the captured path through the existing wrapped inspector.

Tree opens three directory levels including their files; fourth-level folders
appear as collapsed scope entries. Common directory stretches without
captured branches or intervening files share one label, with an ellipsis for
omitted components. Enter expands/collapses folders; at the depth boundary
Open folder moves the panel into that scope. Its selectable root shows the
folder summary and preserves the previous file's bookmark. Escape
restores the previous scope, selected folder and viewport. Ancestor navigation
returns directly to a retained parent, with Repository always available.
Ancestor choices are capped at 200 rows and 262,144 prefix characters; partial
lists are labeled.

Filtering and exclusion operate on complete captured path/state text. They
use separate temporary folds and scope; clearing restores the unfiltered tree.
A changed filter selects the first visible matching document where available.
Folder selection displays a captured change summary, clears the file syntax
viewport and retains the file reading offset for return. The existing refresh
worker remains bound to that retained document's path/change kind.
Refresh reconciles vanished prefixes and removes obsolete folds. Grouping,
scope changes, resize and paint never scan directories, read unselected
content, persist preferences or add workers.

Each projection retains its selected row and viewport when switching away and
back with the same document and filters. Selecting the active projection is
inert. A newly selected file in All files is revealed when returning to Tree.
Refresh invalidates those saved numeric identities, rebinds the reader by exact
path and change kind, and preserves the surviving file or folder's screen slot
after projecting the new list. All files ancestor navigation uses its selected
file even when a previous Tree scope is retained.

The folder pane presents distinct path and entry counts, change-state bars,
direct paths/child-folder counts and up to six busiest child areas. Commit and
comparison views also total existing captured numstat facts, separating binary
entries. Bars always count entries, and filtered/partial coverage is explicit.
Only folders in the retained result prefix receive full summaries; rank
resolution builds none. Reading a summary performs no discovery or file read.
Right/Tab focuses it, Left returns, and Enter while summary-focused is inert.
Numbered folders keep the same acceptance behavior as other actionable rows.
Prepared summaries invalidate their wrapping when a filter changes their facts.
Folder scroll bookmarks use exact prefixes, survive temporary filtering and
unchanged observations, and are pruned only when their prefix vanishes from a
replacement capture. Numeric file identities still follow snapshot invalidation.
Literal path controls are made visible before joining summary prose, so a newline
in a name cannot create a false summary heading. Unsupported line-count fields
produce an incomplete-totals notice rather than a silently incomplete sum.

The shared shortcut bar reserves its final `^K all keys` entry before fitting
optional hints. Ctrl-K opens the complete applicable keyboard guide and returns
without changing the review position; inside the guide the final hint is
`^K close`. Ctrl-] reveals the exclusion field and switches field editing.
The selected path or folder-summary title keeps its heading style with either
pane focused; the caret, divider and selection surface convey keyboard focus.

The canonical behavior is in [AGENTS.md](../AGENTS.md#git-review-workspace-boundary).
The earlier direct Ctrl-X-to-atlas route in
[composer-and-atlas.md](composer-and-atlas.md) is historical; the map remains
available through View options with its original read/Back boundaries.

## Validation and performance

`tests/git_tree_test.zsh` covers 100 nested directories, duplicate changes,
literal metacharacters, exclusion, filter restoration, captured nested-repository
notices, vanished scopes, wide Unicode, complete statuses and terminal row bounds.
Additional focused files cover refresh insertion/failure/empty observations,
leading-space filenames at narrow widths, and deep-path algorithmic work.
Reachability coverage traverses overlapping literal scopes and verifies that
every captured entry remains accessible.

`tests/git_tree_native_test.zsh` uses a real ZLE/PTY, a disposable Git repository
and a separate observation FIFO. It exercises Tree, folding, Ctrl-X view
switching, deep scopes, Escape, ancestors, filtering, refresh and resize from
120 to 40 columns. It checks unchanged index bytes, capture-free folder/ancestor
navigation, one alternate-screen lifetime and cleanup without runtime errors.
The existing native Git journey covers the updated atlas menu route, source
positions, new-file previews, abort, unborn repositories and absent-peer fallback.
These checks are not manual visual approval in Terminal.app.

An isolated 11-sample measurement on the development Mac, using native Zsh
with the test harness's C locale, projected 1,000 synthetic changes under
`src/groupN/deep/fileN.swift` across 50 groups. Median full-list costs were
9.22 ms for existing matching, 16.01 ms for revised All files labels and
40.88 ms for matching plus Tree projection. These are local observations,
not latency guarantees. Reproduce with an isolated test home, those captured
arrays, `_git_review_rows`, then time `_navigation_picker_collect '' 1001`
and `_git_review_file_collect '' 1001` with each projection using
`zsh/datetime`. Tree can contain more rows than file entries because folders
are additional actionable navigation choices.

Projection runs on collection/filter changes and navigation, not paint. The
shared result prefix retains rows for ordinary arrow movement and coalesces
selected-file provider work. Recursive grouping follows three expanded directory
levels plus collapsed fourth-level entries; a 100-component chain uses common-prefix calculation rather
than 100 recursive calls.

Independent review found two pathological deep-path costs. Repeatedly removing
the final component made divergent grouping and vanished-scope recovery scan
shrinking paths once per directory. Grouping now compares components forward
only when a literal shared-prefix check fails. Reconciliation binary-searches
the deepest surviving captured prefix. With 10,000 synthetic directory
components, local grouping measurements fell from about 2.07 seconds to
4.27 ms, and vanished-scope recovery from 3.21 seconds to 1.81 ms. A separate
1,000-file shared-parent case measured 34.46 ms after retaining the cheap prefix
fast path. These observations use native Zsh on the development Mac and are
not guarantees. The permanent regressions count bounded shell steps with a
DEBUG trap instead of relying on wall-clock thresholds.

The review also fixed projection round-trip bookmarks, flat-view ancestor
selection, refresh viewport drift and filenames whose literal leading spaces
were mistaken for indentation. Only explicit generated prefixes are now fixed
during abbreviation; literal filename text retains the remaining display budget.

The folder-summary follow-up measured actual collection with 1,000 changes
over nine samples in isolated stock Zsh 5.9/C locale. With 50 folders, the median
was 53.8 ms for the first 21 rows and 63.9 ms for the first 1,001 rows. With
1,000 singleton folders, those medians were 100.7 ms and 136.0 ms. Limiting
summary construction to the retained prefix reduced singleton-folder summary
text from roughly 325K to 23.4K characters for the first 21 rows. Reproduce with
synthetic `groupN/fileN` captured arrays and `_git_review_file_collect` at the
stated limits. These local observations do not establish latency guarantees.

The first broad development run found five integration failures involving
automatic-refresh identity, eager initial capture and the old atlas route.
Targeted reruns verified their fixes. Final verification is reported separately
in the task handoff rather than describing that earlier run as green.
