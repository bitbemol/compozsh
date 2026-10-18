# Prompt

The living prompt, its receipts, project/runtime context, the Draft inspector
and the Command composer. Ownership: `.zsh.prompt` captures facts and renders;
`.zsh.editor` provides the optional ZLE adapters and bindings
([architecture](architecture.md#shared-behavior-ownership)).

## Essentials

- **One ordinary prompt, three moments.** Context lens, Interaction lens and
  transcript are presentations of one ZLE prompt, repainted in place; only
  acceptance leaves a line (the receipt) in scrollback.
- **Presentation, never a provider.** Lens derivation, morphing, pinning,
  transcript repaint and resize use only the literal buffer, bounded
  editor-owned suggestion state and already captured facts: the prompt
  snapshot (captured at `precmd` and after an explicit in-widget directory
  change), the asynchronously delivered manual catalog and the highlighter's
  shared directory observation. They
  launch no subprocess, read no files or project metadata, write nothing and
  make no network request.
- **Literal and advisory.** The Interaction lens derives from bounded lexical
  structure without evaluating, expanding, resolving or executing anything,
  and preserves the exact buffer, cursor, undo/history state, autosuggestion
  display and shell semantics. Inferred statements stay qualified.
- **Receipts are presentation, not redaction** (see
  [security](security.md#handling-sensitive-data)).

## Modes and moments

- The living prompt has exactly three presentation modes in `_PROMPT_VIEW`:
  `compact`, `lens`, and `transcript`. The state is private to `.zsh.prompt`
  — not public configuration or a lifecycle framework. `compact` renders the
  active Interaction lens when the editor adapters are available and the
  responsive one-context-row fallback when they're absent; `lens` renders
  Context; `transcript` is acceptance-time paint.
- Repaint the active frame as state or `BUFFER` changes; never accumulate
  superseded frames in scrollback.
- Layout follows `$COLUMNS`, never wraps the active prompt, keeps the
  highest-value facts first and restores hidden facts when space returns.
  Completed receipts are ordinary scrollback: never claim they relayout after
  resize, can be cleared as a privacy feature, or leave terminal retention.

## Context lens

- Progressive disclosure of the captured snapshot. It opens automatically on
  the first prompt inside a recognized project or Git repository, and reopens
  only when a recognized project root or raw Git branch appears or changes, or
  when the virtual/Conda environment, Git operation/conflict attention, or
  runtime unknown/missing/unavailable/mismatch attention changes. Staged,
  modified, untracked, stash, ahead and behind counts alone never reopen it.
- Automation is event driven: no dismissal timer, polling, worker or
  background refresh.
- Header `CONTEXT · reason` plus the current `Option-I pin` / `Option-I close`
  affordance when space permits. Rows: `PROJECT`, `PATH`, `GIT`, `TOOLCHAIN`,
  `ENV`, `JOBS` and `SESSION` (local user/host and Zsh version) as facts and
  height allow.
- An automatic lens stays while `BUFFER` is empty. The first nonempty edit or
  paste replaces it with the Interaction lens and consumes the disclosure for
  the current trigger fingerprint; emptying the buffer doesn't reopen it. A
  trigger captured while a draft exists (after an in-widget directory change)
  is consumed the same way at the next repaint.
- Option-I maps to the `compozsh-context-lens` widget and toggles a pinned
  lens. A pinned lens survives editing, reserves a small live interaction
  section that follows the buffer, and is cleared by accepting a command; a
  trigger never unpins it.

## Interaction lens

### READY

`READY` shows while the buffer is empty: captured `PROJECT`, `PATH`, `GIT`,
`TOOLCHAIN`, `ENV` and the active `LAST` outcome, with `SESSION` only when no
more relevant fact exists. `LAST` is shell-memory state for the most recently
completed command — including a fast success with no outcome receipt — and is
replaced in the next active prompt, not a scrollback record. Toolchain facts
stay in READY after ordinary acceptance or clearing the screen. Reuse captured
items and widths, align values with other rows, and allow up to six READY body
rows when height permits so the toolchain doesn't displace ENV/LAST; narrow or
short windows use bounded omission.

### Kinds and rows

- While editing, the lens morphs among `COMMENT`, `RUN`, `GIT`, `NAVIGATE`,
  `SEARCH`, `BUILD`, `TEST`, `ENVIRONMENT`, `REMOTE`, `PIPELINE`, `CHAIN`,
  `REDIRECT` and `CAUTION`. Caution and compound presentations take priority.
- Labels ending in ` TEXT` are sanitized, width-bounded excerpts of literal
  editor text; they don't assert that a path exists, a target resolves, a
  connection happens or the command has that effect. `PROJECT`, `PATH`,
  `GIT`, `BRANCH`, `TOOLCHAIN`, `FROM`, `SCOPE`, `CURRENT` and `LAST` reuse
  captured facts. `FLOW`, `STAGES`, `STEPS` and `CONTROL` summarize pipeline
  and `&&`, `||`, `;`, `&` structure.
- Inferred `ACTION` rows are advisory and keep qualifiers such as `likely`,
  `appears` or `may`. A recognized owned operation may name its purpose from
  its captured help description, with Compozsh help attribution; that neither
  validates arguments nor promises success. Unsupported shapes keep general
  ABOUT information rather than asserting a different operation.
- `COMMENT` shows `COMMENT TEXT` with the advisory
  `likely remain an interactive shell comment`. `REDIRECT` pairs
  `OPERATOR TEXT` with `OUTPUT TEXT`, `INPUT TEXT`, `DESCRIPTOR TEXT` or
  `RESOURCE TEXT` by recognized operator, without validating or opening the target.
- A matching highlighter observation of one existing directory with `AUTO_CD`
  enabled uses NAVIGATE, the path-colored outline, `DESTINATION TEXT` and an
  advisory AUTO_CD action. Command/alias/function/builtin precedence and real
  execution are unchanged; never infer navigation from a slash or tilde prefix
  or expand the draft to classify it. The highlighter shares its existing
  lone-directory observation keyed to the exact bounded buffer and folder,
  captures the caller's `AUTO_CD` before local emulation, and clears it before
  skipped or changed highlighting; prompt code never resolves paths itself.
  Missing or stale observations use the lexical fallback — this is not a
  CDPATH resolver or a per-redraw discovery pass.
- `g` is Git interaction: bare `g` describes the local branch workspace;
  `g --review`, `g --worktree` and `--help` forms get review, worktree or help
  cues; `g --discard-all` gets CAUTION (its `--help` stays help).
  Classification never invokes `g`.
- Other owned task entries are classified from literal text only:
  `external-device` (task entry, help, destructive flash/format modes),
  `xcode --export-skills` (export), `compozsh --refresh` (refresh). Bare
  `xcode` is not a build.
- Every pipeline and chain command finds its head by one lexical rule:
  leading assignments, the precommand modifiers `command`, `builtin`, `exec`,
  `noglob`, `nocorrect`, `time` and `env` (with its options and `NAME=value`
  operands) and their options, redirections with their targets and comments
  never name it, so a head-only `CAUTION` cue such as `rm` reads the same in
  any position. The first head names the draft, except that a literal alias
  of a modifier's name in first position is itself the head. Only a draft of
  assignments alone is the environment update; another headless draft, such
  as a bare redirection or modifier, keeps its first literal word.
- A leading assignment's value is never copied into lens state; its name may
  help locate or describe the command. This avoids a second display of a
  possibly sensitive value but doesn't redact the buffer, transcript, history
  or process arguments.
- A `SUGGESTION` row may repeat only a bounded visible prefix of matching
  editor-owned autosuggestion state; it never searches history or keeps the
  unseen tail.
- `CAUTION` is a deliberately incomplete cue for a few recognizable,
  high-confidence literal forms. It is not authorization, validation,
  confirmation, policy or proof that unmarked commands are safe, and it never
  blocks Return or weakens an operation's own safety boundary.

### Adding an Interaction kind

- **Precedence** (first match wins): comment → leading-assignment-only
  environment → `CAUTION` → `CHAIN` → `PIPELINE` → `REDIRECT` → owned task
  entries → `REMOTE` → `GIT` → `NAVIGATE` → `SEARCH` → `ENVIRONMENT` →
  `TEST` → `BUILD` → `RUN`, then alias handling. Place a new kind where it
  can't steal a more specific or safer view, and add rows for the neighbors
  it could shadow to the precedence matrix in `tests/prompt_lens_test.zsh`
  (`keep their precedence`), which checks each kind alone and against its
  lower neighbor's evidence.
- **Matcher:** each kind is one `_prompt_interaction_match_<kind>` function
  in `.zsh.addons/.zsh.prompt`, and `_prompt_interaction_classify` runs them
  in the precedence order above, so adding a kind means writing its matcher,
  inserting its name in that list and giving its view a row shape in the
  rows step. A matcher reads only the lex and heads facts the model already
  captured, keeps its scratch words local and stays provider-free. It
  accepts (status 0) by writing the kind, the view and its own view facts,
  or declines (status 1) and writes nothing; it needn't repeat the evidence
  of matchers above it, because the list alone owns precedence.
- **Rows:** non-READY views show at most five body rows (READY six);
  `EXPANSION` reserves the last row. Order rows from most to least specific
  and reuse captured-fact labels (`PROJECT`, `PATH`, `CURRENT`, `SCOPE`,
  `FROM`) instead of inventing new ones.
- **Color:** `_prompt_interaction_color_role` maps the kind to a semantic
  role (`caution` → danger, `ready` → success, `git`, `navigate` → path,
  `environment`, `build`/`test` → tool, everything else → info). Keep warm
  roles for warnings.
- **Literal-data safety:** never show option values (`--opt=value` or the
  value after an option that takes one); stop collecting targets at an
  unknown option rather than guess; reduce URLs to `scheme://host` with no
  userinfo, path or query, as `REMOTE` does; never show leading-assignment
  values. Prefix commands such as `sudo` are classified as the command
  itself today, so a dangerous command behind them is not recognized.
- **Checklist:** focused lens tests (classification, precedence guards,
  no-disclosure cases, the provider-free test), the outline color-role test,
  a PTY journey, this contract, the README lens table, SECURITY's lens
  bullets, and optionally a website scene (needs visual approval).

### ABOUT and alias expansion

- `ABOUT` is a captured manual NAME or same-source tool-help description, not
  an ACTION prediction. Generic RUN replaces its filler ACTION with ABOUT plus
  SOURCE attribution; specific action cues and owned help commands keep
  priority. Tool help is the canonical source for its summaries; don't
  duplicate that prose in the prompt.
- Manual descriptions arrive asynchronously under the
  [manual lifecycle contract](manual-cache.md#asynchronous-prompt-capture):
  keep the fallback until a complete current snapshot arrives, then repaint
  only the ordinary editor without changing the draft or display ownership.
- Help descriptions are captured by the optional help peer at a TTY prompt
  boundary — never by calling a command's `--help` or a companion while
  editing. Capture at most 64 command/help pairs, each definition at most
  65,536 characters and the combined identity snapshot at most 262,144; read
  at most 4,096 help characters per guide plus one lookahead (the Touch ID
  subguide has a separate read under the same bound). Keep descriptions to 240
  characters, reject controls and never accept a truncated final line. Cache
  in shell memory only; changed definitions, removed capabilities and
  `compozsh --refresh` invalidate it; source time captures nothing.
  Companions are trusted static documentation, not executable probes or a
  sandbox.
- Suppress external summaries for user aliases and functions, except the
  source-identified transparent output wrappers. The literal-name lookup is
  not executable or `PATH` resolution. Never borrow an executable's manual for
  an alias or reinterpret a precommand modifier to manufacture an owned-tool
  claim.
- Stock aliases share their default expansion and description in the owning
  navigation peer. Show `EXPANSION` for current ordinary, global and suffix
  aliases, including machine-local ones. Within the 512-character/64-token
  draft bound, observe at most eight literal references: command positions in
  pipelines and chains, leading assignments, global argument/redirection
  aliases, and the word after a trailing-space alias. Respect quoting,
  escaping, disabled `ALIASES` and alias-suppressing modifiers; stop at
  here-documents; don't inspect nested substitutions or promise full parser
  coverage; never evaluate aliases or follow alias chains.
- Keep at most 240 characters per definition with an omission marker,
  sanitized and escaped through the shared prompt renderer; empty definitions
  show `""`. Custom definitions get a neutral description; stock descriptions
  require an exact match with the current default. `EXPANSION` is the final
  information row above the input for every alias shape and reserves its row
  before optional context. Caution views keep their warning (a one-row caution
  shows only the warning); compound views keep structural priority.

## Transcript and outcome receipts

- Line finish leaves `HH:MM › ` as the transcript prompt with the exact
  accepted buffer. Empty and whitespace-only submissions use the same receipt
  — no inactive frames, blank spacer rows, outcome receipt or new `LAST`.
  Nested editors keep their own lifecycle.
- After command output, show an outcome receipt for every failure and for
  successes of at least two seconds: `× exit N`, plus ` · 2.3s` for a slow
  failure, and `✓ 2.3s` for a slow success. Fast successes add nothing.
  Painting never changes command bytes, history insertion, output or the exit
  status the next prompt reports.
- The terminal title, written only to a terminal whose `TERM` isn't `dumb`,
  is `user@host: <current folder>` at each prompt (and after an in-widget
  directory change) and
  `user@host: <command word>` from `preexec` while a command runs. It is a
  second display of the draft, so the word is the first one after leading
  assignments in bounded lexical structure (512 characters lexed, 60 shown,
  sanitized) and never an assignment value. An array assignment, a first
  command without a word or a missing assignment predicate leaves the
  identity alone.

## Layout, sanitization and color

- Sanitize control characters and keep dynamic text literal before placing it
  in a prompt-expanded string: escape `%`; with `PROMPT_SUBST` also backslash,
  `$` and backticks; with `PROMPT_BANG` also `!`. Route every dynamic value
  through the established sanitation helpers.
- Measure visible cells, not escape bytes; keep color out of width math. Use
  `…` for width-aware abbreviation, keeping useful beginning/end context.
- The Interaction capsule header, rail and bottom corner share the current
  semantic role; labels, values, input arrow and editor syntax are styled
  independently, so outline color never bleeds into content.
- Shortcut hints read `Option-Return` and `Option-I`, with at least two cells
  between heading and a whole hint; omit hints before crowding the identity.
  Shared shortcut bars separate paired arrows (`↑/↓`) and spell out `Option`;
  never concatenate modifier/Return glyphs whose ink can collide despite
  correct cell counts. Test long and wide-character headings and narrow
  redraws.
- Keep the semantic, collision-resistant palette: one role per color in its
  local context, conventional warm colors for warnings and errors, coherent
  light and dark defaults with useful contrast, explicit initializer roles
  preserved across automatic selection. Unicode tree glyphs are welcome;
  patched-font/private-use glyphs are not.
- `prompt_add_project_segment` colors are validated before composing prompt
  syntax: a `0`–`255` index or Zsh's fixed basic color names; anything else
  uses the `tool` role or native text.

## Project and runtime context

- `precmd` is the fact-capture boundary, with one explicit addition: an
  in-widget directory change. A filesystem workspace's Change directory or
  Enter linked directory runs `cd` inside its widget after screen cleanup, so
  no `precmd` follows before the next edit. Once it succeeds, the editor runs
  the prompt's `_prompt_capture_context` (resolved at invocation) before
  repainting, so the prompt and title never describe the previous folder. It
  recaptures the same facts and title as `precmd`, user
  `PROMPT_PROJECT_CONTEXT_FUNCTIONS` included, keeps the draft, and adds no
  outcome, receipt, history entry, manual or help capture request. Each widget
  that can reach it reads the caller's `ALIASES` into `_prompt_alias_enabled`
  at entry, before its own `emulate`, so the recaptured lens agrees with the
  next redraw.
- Detection uses bounded upward searches, exact marker checks and shallow
  conventional directories (see [performance](performance.md)); it never
  executes repository-local wrappers, binaries, manifests or scripts, and
  resolves trusted installed tools through `PATH`.
- Marker detection is data: `_PROMPT_PROJECT_RULES` in
  `.zsh.addons/.zsh.prompt` lists languages, project markers, tools,
  frameworks and environment signals in display order. `_prompt_project_context`
  captures only the tokens those rules name, and the pure
  `_prompt_project_classify` decides from that evidence. Exact markers keep
  exact checks; an ordinary root matches its wildcards in memory, in the root
  listing and in at most one read per conventional folder, which globs only
  names some rule can match (the pure `_prompt_project_capture_plan` derives
  these reads once per shell; a listing past its bound falls back to bounded
  per-token wildcards). Add a marker as a row with a fixture in the
  `prompt project detection` tests.
- Runtime support is an optional capability resolved at invocation; without
  it the prompt keeps project identity and tool markers. Don't duplicate
  probes or readers in the prompt peer or shared UI support. Reading external
  state is an observation boundary even when nothing is mutated.
- Version probes cache in memory only, keyed by every environment selector
  that can change the answer, and `compozsh --refresh` invalidates them.
  Preserve neutral-directory probes, trust checks and normal/reverse/rotated/
  re-source tests.
- Comparison semantics: numeric pins distinguish older (danger) from newer
  (warning), show both requested and observed versions, and keep
  partial-version matching. Minimums and supported ranges use their
  source-specific semantics. Unsupported selectors, formats or compiler-family
  relationships stay unverified — never a compatibility claim. README lists
  the exact supported sources and limitations.
- Parsers fail closed on literal data with precedence and malformed-input
  tests. Bound parsing work independently of file size before expensive text
  patterns, and never infer a requirement from a truncated first line. Tests
  distinguish skipped ineligible files from captured-but-unverified
  requirements and cover worst-case line shapes.

## Draft inspector

Option-Return (`ESC CR`) opens the Draft inspector through the editor peer;
plain Return keeps shell acceptance. Its reading copy (at most 32,768
characters), frames and filters are scoped to the widget, and restoration uses
the native screen owner. Reading, help and review keep the draft and return
bookmark. Files and History are explicit post-cleanup handoffs whose insertion
can replace the draft; a supported composer can explicitly replace it after
cleanup. Git review uses the current folder, never a target inferred from
shell text. No automatic capture, evaluation, validation or execution; the
prompt's capability hint is captured presentation only. Keep optional-peer
fallbacks and Meta guidance.

## Command composer

- Templates opt in with a private `_compozsh_template_<command>` in the same
  source as the command and its help companion, resolved from loaded
  `functions_source` metadata — never files, a registry or help prose.
  Providers return a supported recipe ID only.
- Prefill only bounded simple literal drafts and leave unsupported syntax
  untouched. Fields are invocation-local, at most 4,096 characters, and quoted
  with native Zsh parameter expansion. No evaluation, validation or execution.
- Revision fields may use the established safe local Git ref chooser;
  preview, filter and render steps read no providers. Check that the captured
  folder still matches before exporting.
- Export through a caller-local result, unwind all screen owners, then insert
  into `BUFFER` or the ordinary prompt buffer stack, keeping an editor draft's
  leading-space prefix (its history preference). Cancellation exports nothing.
- Test optional peers, inert printable help, source-order independence and
  exact quoting.

## Retired decisions

- An `interaction` fourth prompt mode — `compact` already renders the
  Interaction lens.
- Legacy discard aliases and duplicate commands or help companions;
  `g --discard-all` is the sole public discard entry (navigation owns dispatch and
  help, the tools peer the private operation).
- Superseded public command names and companions for owned tasks; remove them
  instead of keeping aliases.
