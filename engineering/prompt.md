# Prompt

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Prompt and terminal UI](#prompt-and-terminal-ui)

## Prompt and terminal UI

- Option-Return (`ESC CR`) may open the Draft inspector through the editor peer.
  Normal Return retains shell acceptance. Scope its at-most-32,768-character
  reading copy, frames and filters to the widget; exact restoration uses the
  existing native screen owner. Reading/help/review preserve the draft and
  return bookmark. Files and History are explicit post-cleanup handoffs whose
  insertion can replace the draft. A supported Command composer can explicitly
  replace the draft after cleanup; ordinary Help navigation remains read-only.
  Git review uses the current folder, never
  an inferred target from shell text. Do not add automatic capture, evaluation,
  command validation or execution to this bridge. The prompt's capability hint
  is captured presentation only. Keep optional-peer fallbacks and Meta guidance.
- Composer templates opt in with a private `_compozsh_template_<command>` in
  the same source as that command and its help companion. Resolve the capability
  from loaded `functions_source` metadata, never files, a registry or help prose.
  Source-owned providers return a supported recipe ID only. Prefill only bounded
  simple literal drafts; preserve unsupported shell syntax untouched. Fields are
  invocation-local, bounded to 4,096 characters, and quoted with native Zsh
  parameter expansion. No evaluation, command validation or execution occurs.
  Explicit revision-field selection may use the established safe local Git ref
  chooser; preview/filter/render steps perform no provider reads. Validate the
  captured folder still matches before exporting the draft. Export through a
  caller-local result, unwind all screen owners, then insert in BUFFER or the
  ordinary prompt buffer stack. Retain an editor draft's leading-space prefix
  so composition does not remove its history preference. Cancellation exports nothing. Preserve optional
  peers, inert printable help, source-order independence and exact quoting tests.
- The living prompt has exactly three presentation modes in `_PROMPT_VIEW`:
  `compact`, `lens`, and `transcript`. Keep this private state inside
  `.zsh.prompt`; it is not a public configuration surface or a new lifecycle
  framework. Do not add `interaction` as a fourth mode: the private `compact`
  mode renders the active Interaction lens when the editor adapters are
  available, and retains the responsive one-context-row fallback when they are
  absent. Private `lens` renders Context; `transcript` is acceptance-time paint.
- Treat Context lens, Interaction lens and transcript as the three public
  moments of one ordinary prompt. Repaint the active frame in place as state or
  `BUFFER` changes; do not accumulate superseded prompt frames in scrollback.
  Acceptance alone replaces the frame with one timestamped command receipt.
- The Interaction capsule header, vertical rail and bottom corner share its
  current semantic palette role. Keep labels, values, input arrow and editor
  syntax independently styled; outline color must not bleed into row content.
  This is presentation-only and preserves all widths and capture boundaries.
- Prompt shortcut hints use readable `Option-Return` and `Option-I` text,
  with at least two terminal cells between the heading and a whole hint.
  Omit optional hints before crowding the context identity. Shared shortcut
  bars separate paired arrows (`↑/↓`) and spell out `Option`; never concatenate
  modifier/Return glyphs whose font ink can collide despite correct cell
  counts. Keep shortcuts unchanged, fit whole hints by display-cell width,
  and test long/wide-character headings and narrow-window redraws.
- The Interaction lens renders `READY` while the buffer is empty. It may show
  captured `PROJECT`, `PATH`, `GIT`, `TOOLCHAIN`, `ENV` and the active `LAST` outcome; use
  `SESSION` only when no more relevant captured fact exists. `LAST` is mutable
  shell-memory state for the most recently completed command, including a fast
  success that has no separate outcome receipt. It disappears with or is
  replaced in the active prompt; it is not a durable scrollback record.
  Keep available toolchain facts in READY after ordinary command acceptance or
  clearing the screen; an expanded Context lens is not required to see them.
  Reuse captured items and widths, align values with the other Interaction rows,
  and allow up to six READY body rows when height permits so the added toolchain
  does not displace ENV/LAST. Narrow/short windows still use bounded omission.
- While editing, morph the Interaction lens among `COMMENT`, `RUN`, `GIT`,
  `NAVIGATE`, `SEARCH`, `BUILD`, `TEST`, `ENVIRONMENT`, `REMOTE`, `PIPELINE`,
  `CHAIN`, `REDIRECT` and `CAUTION`. Derive these kinds from bounded lexical
  structure, without command evaluation, expansion, resolution or execution.
  Preserve the exact buffer, cursor, undo/history state, autosuggestion display
  and shell semantics.
- Labels ending in ` TEXT` identify sanitized, width-bounded excerpts derived
  from literal editor text. They do not assert that a path exists, a target
  resolves, a connection was made or the command will have the described
  effect. Rows such as `PROJECT`, `PATH`, `GIT`, `BRANCH`, `TOOLCHAIN`, `FROM`,
  `SCOPE`, `CURRENT` and `LAST` reuse captured prompt facts. `FLOW`, `STAGES`,
  `STEPS`, and `CONTROL` summarize pipeline or `&&`, `||`, `;`, and `&` chain
  structure as applicable. Inferred `ACTION` rows remain advisory and retain
  qualifying language such as `likely`, `appears` or `may`. A recognized owned
  operation may use its captured help description directly to name its purpose,
  with Compozsh help attribution; this does not validate arguments or guarantee
  success. Unsupported shapes retain general ABOUT information rather than
  asserting a different operation. Caution/compound presentations take priority.
- A matching highlighter observation of a single existing directory with
  AUTO_CD enabled uses NAVIGATE, its usual path-colored outline, DESTINATION
  TEXT and an advisory AUTO_CD action. Preserve command/alias/function/builtin
  precedence and actual shell execution unchanged; do not infer navigation
  merely from a slash or tilde prefix, or expand a draft to classify it.
- `ABOUT` is a captured manual NAME or same-source tool-help description, not
  an ACTION prediction. Manual capture is asynchronous under the
  [manual lifecycle contract](manual-cache.md#asynchronous-prompt-capture): retain
  the normal fallback until a complete current snapshot arrives, and repaint
  only the ordinary editor without changing its draft or display ownership.
  Tool help is the canonical source for its summaries and
  option descriptions; do not duplicate that prose in the prompt. Stock aliases
  share their default expansion and description in the owning navigation peer.
  Show EXPANSION for current ordinary, global and suffix alias definitions,
  including machine-local aliases. Within the existing 512-character/64-token
  draft bound, observe at most eight literal references: command positions in
  pipelines/chains, leading assignments, global argument/redirection aliases,
  and the word following a trailing-space alias. Respect quoted/escaped tokens,
  disabled ALIASES and native alias-suppressing modifiers. Keep at most 240
  characters per definition with an omission marker; sanitize and escape each
  preview through the shared prompt renderer. Empty definitions display `""`. Custom
  definitions retain a neutral alias description; stock descriptions require an
  exact current default match. Caution views retain their warning alongside the
  definition, while compound views keep structural priority alongside previews.
  Anchor EXPANSION as the final information row above the command input for
  every alias shape. Reserve its visible row before optional context when
  height is limited. Retain caution ACTION text above it; a one-row caution
  presentation shows only the warning.
  Stop at here-document operators; do not inspect nested substitutions or
  promise full shell-parser coverage. Never evaluate
  aliases, follow alias chains, borrow executable manuals for an alias, or
  reinterpret a precommand modifier to manufacture an owned-tool claim.
  Generic RUN replaces its filler ACTION with ABOUT plus SOURCE attribution;
  specific action cues and owned same-source-help commands retain priority.
  Never invoke a help companion during redraw. Suppress external summaries for
  user aliases/functions except the source-identified transparent output
  wrappers. The literal-name lookup is not executable or PATH resolution.
  Caution and compound-command presentations take priority over manual detail.
- `COMMENT` exposes the bounded comment body as `COMMENT TEXT` with the advisory
  `likely remain an interactive shell comment`. `REDIRECT` pairs its literal
  `OPERATOR TEXT` with `OUTPUT TEXT`, `INPUT TEXT`, `DESCRIPTOR TEXT`, or
  `RESOURCE TEXT` according to the recognized lexical operator; these labels do
  not validate or open the named target.
- Treat the shipped `g` command as Git interaction. A bare `g` describes its
  local branch workspace; `g --review`, `g --worktree`, and applicable `--help`
  forms expose review, worktree, or help cues. Preserve the same literal,
  advisory distinction as ordinary `git`; classification must not invoke `g`.
  `g --discard-all` receives the advisory CAUTION presentation; its `--help`
  form remains help. This mode is the sole public discard entry: no legacy
  alias or duplicate command/help companion. Navigation owns dispatch and the
  canonical `g` help, while the optional tools peer owns the private operation.
- Keep the remaining owned task entries similarly cohesive: `external-device`
  owns flash/format, `xcode --export-skills` owns Apple skill export, and
  `compozsh --refresh` dispatches the optional tools peer's cache invalidation,
  including next-prompt public manual cache replacement for future shells under
  [the cache contract](caching.md). Remove superseded public names/help companions instead of
  retaining aliases. Bare external-device selection reads no provider; task
  dispatch occurs after screen restoration. Help remains same-source and inert.
  The Interaction lens distinguishes task entry, export/refresh, help and
  destructive device modes using literal text only; bare Xcode is not a build.
- Never copy a leading assignment's value into Interaction-lens presentation
  state; a name may help locate or describe the command. This minimizes a
  second display of a potentially sensitive value but does not redact the ZLE
  buffer, accepted transcript, history or process arguments. A `SUGGESTION` row
  may repeat only a bounded visible prefix from matching editor-owned
  autosuggestion state; it must not search history or retain the unseen tail.
- Validate the optional `prompt_add_project_segment` color before composing
  prompt syntax. Accept only a `0`–`255` index or Zsh's fixed basic color names;
  malformed values use the validated `tool` role or native text.
- `CAUTION` is a deliberately incomplete cue for a small set of recognizable,
  high-confidence literal forms. It is not authorization, validation,
  confirmation, policy enforcement or proof that any unmarked command is safe.
  It must neither block Return nor weaken an operation's own safety boundary.
- The Context lens is progressive disclosure of the same captured snapshot. On
  the first prompt inside a recognized project or Git repository, open it
  automatically. Reopen it only when a recognized project root or raw Git
  branch appears or changes, or when the virtual/Conda environment,
  Git operation/conflict attention, or runtime
  unknown/missing/unavailable/mismatch attention changes. Staged, modified,
  untracked, stash, ahead and behind count changes must not reopen it alone.
- Render the expanded lens with a `CONTEXT · reason` header and its current
  `Option-I pin`/`Option-I close` affordance when space permits. Use semantic
  `PROJECT`, `PATH`, `GIT`, `TOOLCHAIN`, `ENV`, `JOBS`, and `SESSION` rows when
  their facts and height budget apply; `SESSION` is where local user/host and
  Zsh-version identity belong.
- An automatic lens remains while `BUFFER` is empty. The first nonempty edit or
  paste replaces it with the Interaction lens and consumes that disclosure for
  the current trigger fingerprint; returning to an empty buffer does not reopen
  Context. Option-I maps to the `compozsh-context-lens` widget and toggles a
  pinned Context lens. A pinned Context lens survives editing and reserves a
  small live interaction section that follows the buffer; accepting a command
  clears the pin.
- Line finish must leave `HH:MM › ` as the transcript prompt while preserving
  the exact accepted buffer. Empty and whitespace-only submissions use this
  same receipt, never leave inactive frames or substitute blank spacer rows.
  Preserve literal whitespace and native shell semantics; do not synthesize
  command execution, an outcome receipt, or a new `LAST` result for empty input.
  Nested editors retain their own lifecycle. After command output, render an outcome receipt
  for every failure and for successful commands meeting the two-second duration
  threshold: `× exit N`, add ` · 2.3s` for a slow failure, and use `✓ 2.3s`
  for a slow success. Fast successes add no outcome row. Receipt painting must not
  change command bytes, normal history insertion, output, or the captured exit
  status represented by the next prompt.
- Layout must respond to `$COLUMNS`, avoid wrapping the active prompt, preserve
  the highest-value facts first, and restore hidden facts when space returns.
  Interaction morphing, Context replacement/pinning, transcript repaint and
  resize operate only on the literal buffer, bounded editor-owned suggestion
  state and captured facts; none is a provider or effect boundary.
- Completed receipts are ordinary terminal scrollback. Never claim they can be
  dynamically relaid out after resize, cleared as a privacy feature, or removed
  from terminal-owned retention.
- Use `…` for width-aware abbreviation and keep useful beginning/end context.
- Sanitize control characters and preserve dynamic text literally before placing
  it in a prompt-expanded string. Escape `%` for prompt escapes; when
  `PROMPT_SUBST` is enabled, also escape backslash, `$`, and backticks; when
  `PROMPT_BANG` is enabled, also escape `!` into its literal prompt form. Route
  all dynamic values through the established prompt sanitation/escaping helpers.
- Measure visible characters, not color escape bytes. Keep color application
  outside width calculations.
- Preserve the semantic, collision-resistant palette. A color should identify
  one role in its local context; warnings and errors retain conventional warm
  colors. Keep coherent light- and dark-background defaults with useful
  contrast, and preserve explicit initializer roles across automatic selection.
- Unicode tree glyphs are welcome; patched-font/private-use glyphs are not.
- Color command output only when stdout is a terminal. Pipes, redirects,
  command substitutions, and machine-readable output must remain plain and
  byte-compatible with the original command.
- Wrappers such as `grep` and `man` must stay narrow in scope and delegate all
  unsupported behavior to the system command.
