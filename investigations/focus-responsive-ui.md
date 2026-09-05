# Focus-responsive shared tooling UI

2026-09-04. Native Zsh 5.9; measurements are observations on the development
Mac, not performance guarantees for other hosts or Terminal profiles.

## Adopted behavior

The shared full-screen renderer uses its existing separator row as a passive
disclosure map. The active stage and next applicable focus/disclosure gesture
derive from the current view's capabilities, not a tool-name registry. No
result row is lost. Generic choice views, query entry, single readers, the
keyboard guide and Git's captured focused/full-file modes remain distinct.

At 100 columns or more, focusing an ordinary inspector gives it the remaining
width beside a one-third navigator capped at 42 cells. Returning restores the
list-first layout and its one-third preview capped at 48 cells. Below that
width, existing single-pane focus remains. Inline fallback and Git document
geometry are unchanged. This is an immediate layout transition, not animation.

Rewrapping preserves the top source paragraph rather than the old display-row
number, subject to end-of-document clamping and existing capture bounds. It
reuses the existing source-row map, now also populated for ordinary inspectors.
No providers, snapshots, command execution or shell-draft handling were added.

## Measurement

Compare the previous fixed-width inspector with focus-responsive geometry.
Both use 120 columns × 30 lines, ten synthetic choices and an 80-line captured
inspector. Warm repeats hold selection/focus constant; transition repeats
alternate list/detail focus. All observations use the same loaded support
peers and data; initialization and capture are outside the timed interval.

Three samples per case:

| Workload | Before (ms/frame) | After (ms/frame) |
| --- | --- | --- |
| Frame + highlight construction, warm | 2.305 / 2.291 / 2.372 | 2.311 / 2.376 / 2.389 |
| Frame + highlight construction, alternating focus | 3.050 / 3.083 / 3.046 | 4.192 / 4.259 / 4.251 |
| Native ZLE render + paint, warm | 3.359 / 3.252 / 3.251 | 3.463 / 3.325 / 3.334 |
| Native ZLE render + paint, alternating focus | 11.011 / 11.425 / 11.134 | 14.141 / 14.609 / 14.761 |

Construction samples repeat the complete renderer and highlight construction
150 times with terminal writes stubbed. Native samples use an isolated
interactive Zsh, `zsh/zpty`, the existing alternate-screen session and real
`zle -R`, thirty frames per sample; the parent continuously drains terminal
output. Timing includes rendering, rewrapping, highlight construction and ZLE
painting, but not physical display latency or Terminal.app's compositor.
Only the synthetic fixture is supplied; no private configuration/history is
loaded. Native samples compare the HEAD UI peer with the working implementation.

Rewrapping and repainting a wider pane increases deliberate focus-transition
cost; repeated frames remain close to baseline. Retain simple native
recalculation rather than introducing another cache, timer or rendering loop.

## Acceptance evidence and remaining manual check

`tests/workspace_focus_test.zsh` covers capability-derived maps, absent and
stale document capabilities, non-indexed chrome, row capacity, Unicode/control
safety, whole hints, reversible geometry and paragraph continuity.
`tests/panel_layout_test.zsh` checks actual ZLE paints while changing focus and
terminal dimensions, with unchanged capture count and restored caller state.
`tests/inspector_test.zsh` now checks reading-source continuity across pane
changes instead of assuming a wrapped-row offset stays numerically identical.
Existing workspace tests cover multiline drafts, cursor state and restoration.

Final native suite: 594 passed, one pre-existing failure in “Git automatic
worker enforces its deadline without picker-idle polling.” That worker and its
timing fixture were not changed here. Focused UI (63), inspector (6), panel
layout (3), new workspace focus (3), security, documentation and inventory
checks pass, as do syntax, isolated double sourcing and `git diff --check`.

Manual Terminal.app visual acceptance remains for the user: in a window at
least 100 columns wide, open `compozsh`, focus Help with Ctrl-E, scroll, return
with Ctrl-B, resize, and cancel. Repeat with `g` and path + Tab (load Preview
explicitly). Verify comfortable reading width, retained selection, useful
navigation hints and intact shell draft. Native PTY tests do not establish
the appearance of a particular Terminal.app font/color profile.
