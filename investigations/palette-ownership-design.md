# One owner for terminal palette defaults

Date: 2026-09-03.
Status: implemented; final validation is recorded in the companion UI extraction report.

This design follows the [palette design review](palette-perception.md).
It preserves the approved light/dark colors while removing competing default
definitions. Its scope is Compozsh-owned terminal presentation, including native
output integrations. The optional static website, terminal profile settings and
arbitrary external programs remain separate presentation boundaries.

The [shared UI component design](ui-components-design.md) builds on this
ownership model. Palette centralization and UI extraction are implemented in
one change, with one color source consumed by the shared components.

The durable setup rules now live in the
[peer configuration algebra](../AGENTS.md#peer-configuration-algebra).
The load-order argument below explains how this ownership design supports
those contracts. The dated validation records remain bounded evidence.

## Decision

Make `support/.zsh.appearance` the sole author and installer of both schemes'
color defaults. Other peers consume semantic roles at invocation or rendering
time. The maintained palette and UI implementations live together beneath
`.zsh.addons/support/` and stay installed during normal customization. Public
settings remain in the machine-local initializer. The existing bootstrap still
discovers them as ordinary, order-independent peers; standalone consumers retain
fallbacks when these capabilities are unavailable.

Color values are data, but loading them is still an effect: Zsh declarations
populate shell memory, copying defaults changes public maps, `zstyle` installs
completion configuration, and exporting `LSCOLORS` affects child processes.
Read-only values alone cannot fix an early consumer that copied an absent value.

The intended invariant is **one default writer, runtime readers**. The loader
remains discovery-only and order-independent. The selected scheme and palette
are bounded in-memory configuration, not a claim that the shell contains no
state. There is no new registry, dependency graph, end-of-load hook, timer,
project cache or persistent palette storage.

## Sources of duplication before extraction

| Previous owner | Previous responsibility |
| --- | --- |
| `.zsh.appearance` | Light defaults, scheme detection, ownership reconciliation, completion style updates, light `LSCOLORS` |
| `.zsh.highlighting` | Dark syntax/picker/review defaults and ownership reconciliation |
| `.zsh.prompt` | Dark prompt defaults and ownership reconciliation |
| `.zsh.output` | Dark output defaults, repeated numeric fallbacks and ownership reconciliation |
| `.zsh.editor` | Dark completion table, picker/review fallback colors, completion ownership state |
| `.zsh.shell` | Dark `LSCOLORS` and ownership reconciliation |
| Navigation and USB presentation | Numeric defaults passed to output adapters |

Tools directly reads the prompt's path role for confirmation text; Git review
and Xcode consume shared rendering/output capabilities. Their final audit must
catch direct and indirect fallback assumptions and help text. Their task logic,
actions, capture boundaries and screen lifecycle remain unchanged.

## Data and ownership

Appearance contains the authored defaults for both schemes in one cohesive
section. Keep explicit semantic families: prompt, output, highlighting/picker/
review, completion file types and BSD file colors. Two distinct roles may share
an index today without becoming the same role. Foreground/background pairs and
selected/inactive/diff variants remain deliberate design decisions.

Where the same semantic value is repeated across families, define it once in
that scheme and derive its consumer entries in the same appearance setup.
Use ordinary local values and native arrays; no recursive alias resolver or
generic theme language. Terminal-specific encodings such as BSD `LSCOLORS`
remain explicit where translating them would lose the approved appearance.

Retain the public customization maps:

- `ZSH_PROMPT_COLORS`
- `ZSH_OUTPUT_COLORS`
- `ZSH_HIGHLIGHT_STYLES`, including existing legacy picker override precedence

Do not introduce a fourth competing public palette API. Appearance materializes
the selected defaults into the existing `_COMPOZSH_COLOR_FALLBACKS` map and fills
only absent public keys. These derived values are not separately authored
palettes. Keep at most the selected scheme in retained memory; the other
scheme's local setup data does not need a live catalog.

Consumers may declare a public associative array without clearing it. They must
not install color defaults into it, rewrite its roles or maintain their own
colored fallback table. Removing those writers also removes the reason for
`_COMPOZSH_COLOR_MANAGED`: no peer needs to distinguish a preceding peer's dark
default from a user override so that it can replace the former with light.

The private selected defaults are read-only to consumers by convention. Public
maps remain writable for user customization. Do not apply Zsh's `readonly`
attribute to the public maps or freeze them after setup. Re-sourcing appearance
uses the same selected scheme and fills missing keys without replacing present
ones; literal read-only declarations must not obstruct this lifecycle.

## Resolution and effects

Effective role precedence is:

1. Applicable explicit public override, with the existing legacy picker
   override priority and format-specific validation.
2. The selected default from appearance.
3. Native/default text and non-color emphasis when neither supplies a value.

Missing or malformed colors must never produce an empty indexed-color escape,
an invalid Git/LLDB argument, shell evaluation or a renderer diagnostic. A
format adapter returns a valid value or an explicit absence that its caller
handles. Existing output and ZLE style helpers remain the adapters; remove
numeric fallback arguments from their call sites. Keep validation appropriate
to each existing format instead of introducing a new style language.

| Surface | Consumption and effect owner |
| --- | --- |
| Prompt | Read roles while building/expanding the prompt. Remove source-time copies into `_PROMPT_GIT_COLOR` and `_PROMPT_SYMBOL_COLOR`; initialize those to a neutral state and resolve them in prompt preparation. |
| Highlighting and picker/review | Read current public roles and central defaults. Retain background-preserving composition and selection/focus distinctions; no per-token provider read or default-table rebuild. |
| Help, Git, grep, man and LLDB | Output adapters translate roles into the tool's existing native format at invocation. Omit unsupported/missing color properties safely; explicit external-tool overrides retain authority. |
| Navigation and USB text | Keep their terminal and `NO_COLOR` gates. Request roles from the existing optional presentation capabilities; retain literal plain output when unavailable. |
| Tool confirmation paths | Resolve the prompt path role with the same override/default precedence and existing numeric validation; preserve plain fallback and explicit-copy behavior. |
| Completion | Editor registers a fixed `zstyle -e` callback for file colors, as it already does for headings. The callback returns explicit `LS_COLORS` or the central completion defaults when invoked. Appearance never installs completion styles. |
| BSD `ls` | Appearance owns the default `LSCOLORS` export, preserving any existing value. Shell retains its existing `CLICOLOR` behavior and stops choosing colors. |

No consumer calls another peer during source-time setup. A completion callback
is registered as fixed code owned by the editor; palette access happens only
when completion requests its value. No user data becomes callback source.

Preserve current terminal capability checks, plain-output behavior, quoting,
exit statuses and explicit `LESS_TERMCAP_*`, `LS_COLORS`, `LSCOLORS` and native
command configuration. Output with missing palette roles must be tested against
each native adapter; treating absence as an empty string in every format is
not sufficient. For multi-role properties, emit only a valid composed style or
leave the property's native behavior intact.

## Load-order argument

With the same initializer/environment and enabled peers:

- **Appearance first:** it installs defaults. Consumers subsequently declare
  functions, bindings and fixed callbacks without replacing palette values.
- **Appearance last:** consumers initially define neutral-capable functions and
  callbacks. Appearance then installs the same defaults; subsequent rendering
  reads them rather than an earlier snapshot.
- **Appearance between consumers:** no consumer writes defaults, so the result
  is identical to either ordering above.
- **Appearance absent:** independently sourced peers remain functional using
  explicit applicable overrides and native/plain fallback presentation.
- **Re-source or rename:** the same enabled peers converge again, without
  duplicate hooks or bookkeeping. Scheme selection remains once per shell.

Do not run an interaction halfway through an artificial loading sequence and
call its temporary display an order-convergence failure. Convergence describes
the configured result after the same enabled peers have loaded. Runtime tests
should additionally prove that rendering before appearance is available does
not cache its absence or prevent a later rendering from using its defaults.

## Explicit compatibility changes

The ordinary full installation must retain its approved colors and public
override behavior. Three edge cases need an intentional documented transition:

1. **Appearance disabled:** the independent peers retain usable native/plain
   presentation and attributes instead of a complete copied dark theme.
   Selection markers, focus cues, diff prefixes and severity words remain.
   An actual PTY must prove selected/focused content is still distinguishable.
2. **A public key is deleted:** effective rendering falls back to its central
   default without needing a peer reload. Re-sourcing appearance refills the
   public key. Re-sourcing a consumer no longer writes that key back; direct
   inspection of the map can therefore still show it as absent until then.
3. **`LS_COLORS` changes after startup:** the deferred completion callback reads
   the current value at completion time. An explicit user-installed completion
   style still has normal Zsh precedence; re-sourcing appearance cannot replace
   it because appearance no longer writes `zstyle` entries.

Keep the inherited `LSCOLORS` override rule, including its documented behavior
across parent/child shells. Scheme changes still require a new shell; this work
does not add live theme switching or terminal-profile detection.

## Implementation and acceptance gates

1. Capture the current effective default maps, completion colors and rendered
   representative output for both schemes as the visual-equivalence baseline.
   Keep the existing contrast arithmetic independent of the implementation.
2. Add red tests for single default ownership, appearance-only provisioning of
   both schemes, consumers leaving maps unchanged, deferred completion and
   neutral standalone behavior. Existing passing characterization coverage
   protects the behavior-preserving movement of tables.
3. Move the complete selected defaults into appearance. Migrate every consumer
   and native adapter in the same coherent unit, then remove duplicate tables,
   numeric fallback arguments, `_COMPOZSH_COLOR_MANAGED` and the obsolete
   completion custom/default coordination flag. A partial migration cannot be
   handed off as the completed design.
4. Update README responsibilities/layout and customization/fallback guidance,
   relevant help, `SECURITY.md`'s state/effect inventory, and `AGENTS.md`'s palette
   ownership rule. Keep proposed behavior out of those shipped contracts until
   implementation exists. The bootstrap gains no feature logic or load phase.
5. Run the complete native suite, syntax/diff checks, security/documentation
   contracts and isolated bootstrap double-source check. Confirm the shipped
   peer inventory still matches. Review the entire final diff for source-time
   snapshots and invalid absent-color paths.

Required focused evidence includes:

- Both schemes, automatic selection, explicit/partial/invalid/empty overrides,
  legacy picker overrides, unknown extension roles, override removal and
  re-sourcing, including an override equal to a default in the other scheme.
- Normal, reverse and rotated load orders, both default/custom palettes and
  double sourcing. Compare palette state, prompts, options, aliases, hooks,
  styles, bindings and public functions after loading.
- Missing appearance and individually missing consumer peers; render once
  before appearance, then load it and render again without stale style state.
- A valid role absent from both maps, unsupported terminals, redirects,
  `NO_COLOR`, optional presentation capabilities and explicit native overrides.
- Native PTY prompt/completion, selected/inactive metadata, diff backgrounds,
  focus, cancellation and terminal restoration in both schemes and neutral
  fallback mode. Preserve the 418 reference-pair contrast audit and current
  numeric thresholds for the normal full installation.
- A bounded source audit demonstrating that authored production palette
  literals occur only in appearance. Protocol constants, non-color attributes,
  numeric color-validation/luminance rules and independent test expectations
  are not duplicate palette definitions; do not use a blanket numeric ban.
- Interleaved before/after startup, complete prompt and metadata rendering
  measurements. Use direct lookups in hot paths; no per-span default rebuild,
  new subprocess, terminal query, project read or retained rendering cache.

## Implementation evidence

Both schemes now live in `support/.zsh.appearance`. Consumers resolve overrides and
selected defaults at runtime, with neutral absence handling. The approved
93 serialized entries per scheme (including completion and BSD file colors)
and representative rendered prompt bytes match the pre-extraction snapshot.
`_COMPOZSH_COLOR_MANAGED` and completion default/custom reconciliation are gone.

Focused ownership tests cover independent sourcing, late appearance, deletion,
invalid numeric overrides, empty styles, native adapter absence and explicit
external-tool overrides. The existing 418-pair independent contrast gates stay
in place. See the [UI extraction report](ui-components-design.md) for final
suite, terminal, source-order and measured performance evidence and limits.

An explicit empty command-line syntax style disables that highlight, while
empty picker/review roles retain their existing fallback meaning. Legacy
`history-search-*` empty overrides remain literal. Light-mode picker/review
fallbacks now use the selected light role instead of the previous copied dark
fallback; the ordinary approved palette values remain unchanged.
