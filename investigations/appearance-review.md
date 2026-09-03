# Light/dark palette audit

Date: 2026-09-03. Reviewed the palette feature introduced by `ba63b22` and
corrected by `e773087` and `4c5783c`, in the working tree based on `7f302f9`.
Existing Xcode work was present during validation and was preserved.

This records the initial correctness audit. The subsequent
[palette perception review](palette-perception.md) tunes the complete palettes
and resolves the diff-token contrast limits recorded below.

Three independent agent reviews covered correctness/security, architecture/code
quality/performance, and UI/contrast. Findings were reproduced with synthetic
data in isolated Zsh shells before implementation. No private initializer,
history, terminal profile, or project data was used.

## Corrected findings

| Finding | Reproduction | Correction |
| --- | --- | --- |
| Missing palette values restored dark defaults in light shells | Select light, remove a public role or complete palette, then re-source its owner | Owners fill missing values from the already selected fallback and record the installed value; includes BSD `LSCOLORS` |
| Status headers used the dark heading color | Render a light progress view: main header used 75 while title/body used 25 | Main header resolves the optional output heading role, preserving an explicit status-header override |
| Selection metadata lost contrast | Bright metadata on dark-mode blue 75 measured 1.76–2.32:1; the same metadata on light-mode inactive gray 250 measured 1.44–1.90:1 | Active selections use deep blue 25 with light text; inactive metadata has separate semantic roles, with a pale gray 253 background in light mode |
| Inactive selection overlays erased its background | Focus the reader while a selected result contains a query match and secondary context | Matching retains and underlines the inactive selection style; secondary context retains the row style |

Focused regressions demonstrated the old failures before the corresponding
implementation changes. Additional characterization covers padded, oversized,
arithmetic-looking, and control-bearing passive hints without changing the
detector's behavior.

## Architecture and safety

Selection remains once per shell, using only `ZSH_COLOR_SCHEME` and optional
`COLORFGBG`. It sends no terminal query, consumes no input, launches no process,
and registers no prompt or typing hook. No automatic system/profile lookup,
loader phase, registry, dependency, exported ownership marker, or persistent
palette state was introduced.

Public initializer values remain authoritative. The fixed-size in-memory
ownership and fallback maps let the appearance peer converge with independently
sourceable palette owners. The changes use existing renderer and validator
capabilities at invocation time. `SECURITY.md` was compared against these
changes; its appearance data, lifetime, process, terminal-I/O and
non-transmission claims remain accurate.

`LSCOLORS` inherited from a parent shell is treated as a deliberate environment
override, even when the parent generated it automatically. This cannot safely
be distinguished from a custom palette by value alone. The README explains
unsetting it before `exec zsh` when requesting new automatic BSD `ls` colors.

## Validation scope

- Final unfiltered suite: 479 passed, zero failed (114.4 seconds in this run).
  All shipped/test Zsh files parsed, `git diff --check` passed, and isolated
  bootstrap double-sourcing passed for dark/light under both xterm and screen
  256-color terminal descriptions.
- All 16 peers sourced twice independently under `xterm-256color`,
  `screen-256color`, and `dumb`, with explicit light mode and no diagnostics.
- Complete state comparisons covered four traversal orders, explicit dark and
  light, automatic dark and light hints, and custom/default initializer maps:
  palettes, `LSCOLORS`, options, aliases, hooks, prompts, public functions,
  completion styles, and bindings converged after repeated sourcing.
- Automated selection contrast calculations cover both schemes, both focus
  states, first/last appearance loading, exact row backgrounds, and distinct
  initializer overrides. Tested selection metadata pairs meet 4.5:1 in the
  standard xterm cube/grayscale palette.
- Existing tests cover queued terminal input, one-shot selection, optional
  peers, explicit `LS_COLORS`, manual-page selection, help colors, malformed
  output overrides, and plain output fallbacks.
- Native PTY/ZLE checks paint active and inactive selections and status headers
  in both schemes, with and without the output peer. They verify emitted
  foreground/background sequences, focus transitions, cancellation and exact
  draft/cursor restoration. Existing workspace checks also cover real resize.

Useful focused reproduction commands:

```sh
zsh tests/run.zsh appearance
zsh tests/run.zsh palette
zsh tests/run.zsh 'light status header'
zsh tests/run.zsh 'help uses semantic terminal colors'
zsh tests/run.zsh 'fullscreen'
zsh tests/run.zsh 'security'
zsh tests/run.zsh 'README inventory'
```

## Performance method

Measurements used Apple's `/bin/zsh` 5.9 on arm64 with a minimal environment,
disposable homes, stock completion paths, and copied public shell files.
Five batches each interleaved twelve warm shell starts for appearance disabled,
explicit dark, explicit light, and automatic mode without a hint. Warm starts
reused only each disposable home's native completion dump. The first start
without that dump was recorded separately.

Before corrections, batch-median warm startup was 46.59–47.20 ms without the
appearance peer and 47.41–48.68 ms with light mode: approximately 0.9 ms of
palette setup in this workload. Dark and automatic mode were within sub-ms
noise. First-start completion setup took 176–196 ms.

Five interleaved hot-path batches used 1,000 syntax-highlighting iterations,
1,000 ten-row picker frame calculations over 25 synthetic candidates,
300 complete prompt renders outside Git, and 40 in an empty disposable Git
repository. Baseline medians in milliseconds per iteration:

| Workload | Appearance disabled | Dark | Light |
| --- | ---: | ---: | ---: |
| Syntax highlighting | 1.080 | 1.110 | 1.096 |
| Picker frame calculation | 0.547 | 0.547 | 0.539 |
| Complete prompt outside Git | 0.258 | 0.254 | 0.252 |
| Complete prompt in empty Git repository | 27.371 | 26.452 | 26.849 |

These are local observations, not compatibility limits. Frame calculation
excludes terminal painting. There was no repeatable palette penalty in these
runtime workloads.

Final medians (appearance disabled versus light) were 49.811 versus 50.319 ms
for startup, 1.103 versus 1.114 ms for syntax highlighting, 0.550 versus
0.549 ms for frame calculation, 0.259 versus 0.257 ms for the non-Git prompt,
and 27.490 versus 27.608 ms for the Git prompt. Shared machine timing rose
between runs; the interleaved comparison still puts light setup below 1 ms.

The affected rendering path was measured separately with ten visible rows and
50 semantic metadata spans. Five alternating batches of 300 frames per focus
state included both frame construction and `_zle_picker_show`, replacing only
`zle -R` with a no-op. Active selection measured 4.360 ms before and 4.314 ms
after; inactive selection measured 4.358 ms before and 4.380 ms after. This
comparison excludes terminal painting, which the PTY checks validate for
correctness. It shows no meaningful rendering regression in this workload.

Final production also passed the complete state comparison again for every
traversal order, explicit scheme, and custom/default initializer combination,
including all managed/fallback palette entries after two sources.

## Limits

The contrast test is not a claim of accessibility conformance for every theme
role. Existing light diff numbers (130 on removed background 224) measure
3.58:1; light keywords (94 on 224) measure 4.35:1. Dark diff numbers (216 on
22) measure 4.45:1 and comments (250 on 22) 4.19:1. These token colors were
left unchanged; changing their semantic hues solely to impose a new global
threshold was outside the selection correction.

ANSI completion-description colors and BSD `ls` colors depend on the terminal
profile. A user can also customize indexed colors or override either side of
a selection pair. Automatic detection remains a best-effort hint; stock
Terminal.app generally needs an explicit scheme for a light profile.
Native PTY checks cannot establish the appearance of every real Terminal.app
profile. Manual light/dark profile and fullscreen/windowed visual acceptance
remains a separate check.
