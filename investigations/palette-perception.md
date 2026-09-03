# Palette design informed by visual perception

Date: 2026-09-03. This follows the [initial appearance audit](appearance-review.md).
The scope is every shipped palette family and its known rendering consumers,
including prompt runtimes, completion chrome, printable navigation and manual
pages. Existing unrelated Xcode work was preserved.

## Evidence and design choices

Three agent reviews examined primary research and accessibility guidance,
quantitative color pairs, and terminal UI hierarchy. The resulting colors are
engineering/design choices informed by that evidence, not a neuroscientifically
validated optimum or a claim of reduced eye fatigue.

- [W3C contrast guidance](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html)
  supplies the 4.5:1 small-text target and cautions that thin rendered strokes
  can remain difficult near the threshold. Secondary metadata and unfocused
  panes remain readable content; they are not disabled controls.
- [Apple Dark Mode guidance](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
  motivates separately tuned light/dark variants and a 7:1 goal for primary
  small-text reading. We keep ordinary reading neutral and tune each appearance
  independently instead of inverting colors.
- [W3C use-of-color guidance](https://www.w3.org/WAI/WCAG22/Understanding/use-of-color.html)
  motivates retaining diff `+`/`−`, selected-row markers, match underlines,
  diagnostic words and severity symbols. Red/green hue distinction alone
  cannot carry those states.
- [Apple color guidance](https://developer.apple.com/design/human-interface-guidelines/color)
  supports consistent meanings and testing under different viewing conditions.
  Navigation/focus keep cool hues; ordinary runtime labels share the tool role;
  warm warnings/errors remain identifiable through text and symbols.
- [Experimental research on visual attention](https://pubmed.ncbi.nlm.nih.gov/8301354/)
  connects visual salience with attentional demands. Our design inference is
  to reserve strong emphasis for focus, matches and exceptional states, while
  keeping secondary information readable. It does not establish an optimal
  saturation, RGB value or number of terminal hues.

These are WCAG-derived design targets, not a claim that a terminal theme
achieves WCAG conformance. User preference remains authoritative. No terminal
profile is read or changed, and no system appearance probe is introduced.

## Palette changes

| Surface | Dark | Light |
| --- | --- | --- |
| Secondary text | Muted text and comments use gray 245; prompt frame/clock also 245 | Muted picker/autosuggestion text uses gray 242 |
| Ordinary accent corrections | Existing readable semantic families retained | Teal 30 → 23; green 28 → 22; ochre 130 → 94 |
| Active selection | White 231 on deep blue 24 | White 231 on deep blue 24 |
| Unfocused selection | Foreground 252 on gray 237; distinct metadata roles retained | Foreground 236 on gray 253; distinct metadata roles retained |
| Diff base text | White 231 on green 22 or red 52 | Foreground 236 on pale green 194 or pale red 224 |
| Diff syntax | Lavender keywords 189, sage strings 151, warm numbers 223, gray comments 251 | Purple keywords 90, green strings 22, warm olive numbers 58, gray comments 240 |
| Highlighted completion file names | Black text on privileged-file fills; missing-file red 203 | Deeper warning fills and black text on the sticky-directory fill |

The fixed 256-color cube limits available intermediate hues. Changing a few
diff token colors preserves red/green row backgrounds and their prefixes while
making every tested lexical overlay readable. Type/function/variable colors
already met the target and were retained. This is preferable to inventing
extra per-row token roles or a runtime contrast optimizer for every paint.

Normal runtime/version labels now use `ZSH_PROMPT_COLORS[tool]`; explicit
missing/unavailable states retain danger colors and their diagnostic words.
Completion descriptions/warnings use the existing heading/error roles through
a fixed native `zstyle -e` helper. Printable stacks use validated output colors
only in a capable terminal; redirects, `NO_COLOR`, unsupported terminals and
absence of the output peer retain plain text and the same labels/markers.

Manual-page standout keeps its heading-colored background but chooses whichever
of standard black/white gives greater contrast. Profile-defined ANSI 0–15
use native inverse video; explicit `LESS_TERMCAP_so` still wins. Only this
explicit manual-page request performs the small bounded luminance calculation.

## Measured checks

Independent Python arithmetic inspected 418 normal/reference, selection, diff
and completion foreground/background pairs. The pre-change palette failed 52
of the combined 4.5:1 text and 7:1 primary-text targets. The final palette failed
none. Minimum measured text ratios are 4.66:1 in dark mode and 4.75:1 in light
mode; the minimum primary/selected-label pair is 7.03:1.

Normal surfaces use black and `#1c1c1c` for dark, white and `#f5f5f5` for light.
Composed surfaces use the actual shipped selection/diff/completion backgrounds.
The tests evaluate each lexical token over both diff backgrounds, not merely
over the terminal's default background.

Native regression gates independently calculate contrast from the live public
maps and renderer-composed styles:

```sh
zsh tests/run.zsh 'appearance palette'
zsh tests/run.zsh 'appearance standalone editor'
zsh tests/run.zsh 'manual selection adapts'
zsh tests/run.zsh appearance
```

Tests first demonstrated the low contrast and adaptive-consumer failures, then
passed after implementation. Existing assertions for changed default colors
were updated without removing their target, override, background-preservation,
or terminal-cleanup checks. Native PTYs verify actual ZLE colors, pane focus,
cancellation, draft/cursor restoration, completion formats, and navigation's
colored/plain paths. Ordinary runtime tests stub providers and launch no real
runtime. The shared test helper contains only numeric contrast arithmetic.

The final complete suite passed **487 tests, zero failures** in 113.1 seconds.
All shipped/test Zsh files passed syntax checks, and the focused security,
credential-boundary and README inventory contracts passed. The final independent
source-order matrix covered four orders × two schemes × default/custom palettes
× double sourcing, comparing palette ownership, options, aliases, hooks, prompts,
public functions, styles, bindings and runtime completion-format resolution.

## Performance and architecture review

A separate agent found no safety, architecture, load-order or performance blocker.
Completion registers fixed callbacks and looks up the palette at invocation;
navigation keeps its output peer optional. No startup subprocess, background
work, persistent state or source-time peer dependency was added.

Five interleaved before/after batches used disposable homes and minimal
environments on the same reference Mac. Values below are median milliseconds;
startup is warm filesystem behavior, not a cold boot. Concurrent full-suite
activity affected both trees, so these observations are comparisons rather than
universal timing thresholds.

| Workload | Dark before → after | Light before → after |
| --- | --- | --- |
| Warm startup | 54.003 → 53.980 | 54.159 → 54.657 |
| Complete ordinary prompt | 0.257 → 0.259 | 0.261 → 0.260 |
| Prompt with three synthetic cached runtimes | 0.613 → 0.615 | 0.600 → 0.599 |
| Empty-Git prompt | 25.327 → 26.044 | 26.560 → 26.357 |

Each batch used eight startup samples per variant, 300 ordinary prompts, 500
cached-runtime prompts and twenty Git prompts. Light-mode metadata render/show
measured ten rows/fifty spans over five batches of 300 iterations: active
selection 4.238 → 4.305 ms; inactive selection 4.243 → 4.229 ms. This metadata
workload excludes terminal painting. Differences are small and inconsistent
across workloads; no measurable performance regression was established.

## Boundaries and visual review

The static comparison uses synthetic terminal text and the actual indexed
palette values. It is a simulation, not a screenshot of Terminal.app. Browser
security blocked loading its standalone local-file preview, so no browser
visual-acceptance result is claimed. Native terminal verification is separate.

Color-vision robustness comes from retained text, syntax, symbols and structure;
no simulation certifies every visual condition. Terminal palette remapping,
transparency, fonts, display brightness and ambient light can change the real
result. BSD `ls` remains limited to the profile's ANSI colors. Manual inspection
of the chosen light/dark Terminal.app profiles remains useful.

`SECURITY.md` was compared with the final changes. Only styles derived from
already available state changed. The bounded manual contrast calculation and
terminal capability checks introduce no project/private-file access, storage,
credential handling, network path or background process. Public customization,
one-shot selection, optional peers and local-only behavior remain intact.
