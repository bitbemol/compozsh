# Native Zsh conventions

Idioms, naming and the public command/help interface.

## Essentials

- **Native Zsh 5.9**, not POSIX-shaped or Bash-shaped shell. Use newer
  features when they make code safer or simpler.
- **Untrusted text stays inert.** Terminal input, filenames, Git data,
  environment variables and project metadata are data: quote them, never
  `eval` them, never build shell source from them.
- **Preserve exit statuses.** A wrapper never turns a failure into success.
- **Every public command explains itself** through a same-source `--help`
  companion that has no side effects.

## Idioms

- Prefer `[[ ... ]]`, `(( ... ))`, native arrays and associative arrays,
  parameter-expansion flags, `zstyle`, ZLE hooks and bundled `zsh/*` modules.
- Start non-trivial functions with `emulate -L zsh` (they may run after users
  change options); enable extra options locally.
- Declare function variables with typed `local` (`-i`, `-F`, `-a`, `-A`).
  Declare intentional globals with `typeset -g`, `-gi`, `-gF`, `-ga` or `-gA`.
- Return a helper's scalar in `REPLY` and a short list in `reply` to avoid a
  subshell; pure entries return only this way. Use a clearly named typed
  global only when several results or shared widget state need it.
- `print -r --` instead of `echo`; diagnostics to stderr with `print -u2`.
- `command name` inside wrappers, so aliases and functions cannot recurse.
- Quote arguments and paths. Leave an expansion unquoted only when a specific
  splitting, globbing or array flag is intentional and evident.
- `--` before user-controlled path operands when the command supports it;
  `IFS= read -r` for input.
- Define splitting delimiters locally in all shipped code, not only pure
  entries. `emulate -L zsh` keeps the caller's `IFS`, such as a newline from
  a line loop or an empty one from `IFS= read`. Split single-space internal
  records with `${(s: :)text}`; where runs of blanks and tabs must collapse
  (typed queries, tool output, policy lines), declare `local IFS=$' \t\n'`
  before `${=text}` in the same function. A `security:` test scans shipped
  code.
- Split captured text with parameter flags, never through `<<<`, a
  here-document or `=(...)` ([security](security.md#handling-sensitive-data)).
  Each split is equivalent, record for record, to a read loop over
  `<<< "$text"`:
  - `"${(@f)text}"` equals the lines `IFS= read -r` reads, including a final
    empty one;
  - after `fields=("${(@0)text}")`, `"${(@)fields[1,-2]}"` equals the records
    `IFS= read -r -d ''` reads: NUL-terminated ones, empty records kept and an
    unterminated tail dropped;
  - for K-field records, `for a b … in "${(@)fields[1,(${#fields}-1)/K*K]}"`
    equals K chained `read -d ''` calls: complete records only.

  A fail-closed check can treat text after the last NUL as one more record to
  reject: `"${(@)fields[1,-2]}" ${fields[-1]:+unterminated}`. Unquoted
  `${(0)text}` instead drops empty records and keeps an unterminated tail; use
  it only where both are harmless, as in the filter-override builder, where an
  extra override fails safe.
- Consume a long record stream from a pipe in `sysread` chunks: prepend the
  previous chunk's cut-off tail, split with `"${(@0)chunk}"` and carry the last
  element on. `IFS= read -d ''` makes one read(2) per byte on a pipe, so it
  costs time in proportion to the bytes listed. `_file_search_stream` in
  `.zsh.addons/.zsh.find` is the model.
- Validate numeric text (`<->` and a digit bound) before assigning it to an
  integer: integer assignment evaluates arithmetic, including `$(...)` in a
  subscript. The same holds for float assignment, `read` into either, `(( ))`,
  `$(( ))`, `[[ -lt ]]`, ordinary-array subscripts, `${s:i:n}`, padding
  widths, `printf %d` and `return`, and 19 or more digits truncate or wrap.
  Use `[[ $n == <-> && ${#n} -le 18 ]]` or a small range pattern such as
  `<0-65536>`; when a producer legitimately reports 19 digits, compare that
  text with `9223372036854775807` as text. `<->` alone suffices only for a
  field whose fixed tool format bounds it (`/usr/bin/stat`, `/usr/bin/cksum`).
- Never splice text into arithmetic text. `(( h[$key] ))` and
  `(( a[(Ie)$text] ))` reparse the subscript, so `]` or `$(...)` in the text
  becomes expression or command. Expand first (`${h[$key]}`,
  `${a[(Ie)$text]}`) or assign (`h[$key]=$(( ${h[$key]:-0} + 1 ))`); a
  `security:` test scans shipped code.
- A name that a view, session or worker scopes has no global value: its owner
  declares it for every reader or drops inherited copies at load (`unset`),
  and readers that can run without the owner loaded compare text
  (`[[ ${flag-} == 1 ]]`). A load-time `typeset -gi name` without a value
  converts, and so evaluates, a value inherited from the environment; discard
  numeric state that is not already your own type.
- Don't use `eval`, for parsing, dispatch or anything else.

## Naming and visibility

- Prefix internal functions and state with `_`, including shared entries and
  their file-private helpers. The underscore marks the internal library: user
  examples, aliases and local configuration never call or override internal
  names. Product code may call another file's declared shared entry, never its
  private helpers. Zsh doesn't enforce this, so reviews and tests do; a focused
  unit test may call a private helper when that is the narrowest check.
- Unprefixed names are reserved for public commands and documented extension
  points. Public configuration uses the existing `ZSH_*` and `PROMPT_*`
  families.
- ZLE widget names and special functions such as `TRAPWINCH` are shell-facing
  registrations, not public commands. Keep their implementation in
  underscore-prefixed helpers wherever Zsh allows an explicit mapping, and
  comment unavoidable exceptions.
- Public commands have descriptive, collision-resistant, lowercase kebab-case
  names (`external-device --format`), never underscores; one-word commands
  stay one word.
- Put `unalias <name> 2>/dev/null` immediately before every public function
  definition. If a user (or an earlier peer) already defined an alias of that
  name, `name() { … }` expands the alias and fails to parse, which aborts the
  rest of the peer. Cover each public command with a test that sources its
  peer after a same-name alias. Keep orchestration public only when users invoke it; detectors,
  renderers, installers and state get `_`. Document every public command in
  README.
- Use descriptive long options (`--help`, `--worktree`) without single-letter
  aliases. Transparent wrappers keep the underlying executable's options.
- Documented extension APIs such as `prompt_add_project_segment` keep their
  established names and document their signature in README rather than
  posing as CLI tools.

## Public command help

### Interface

- Every public add-on command accepts the exact single argument `--help`, even
  when it otherwise takes no options, and handles it before dependency checks,
  environment detection or operational logic, so help works on every machine.
- Help is defined once in a private `_compozsh_help_<command>` companion in the
  same file; the suffix is the command's exact name, and the command's `--help`
  branch delegates to it. The companion is also the capability marker the live
  `compozsh` explorer uses — don't duplicate its text, move it to another peer
  or replace it with a central registry.
- A help request normally returns 0, writes nothing to stderr, and performs no
  project/configuration reads, mutations, navigation, clipboard access,
  operational tool detection or network access. Presentation may inspect only
  stdin/stdout, `TERM`, `NO_COLOR` and native terminfo.
- Invalid invocations print the same usage line to stderr and return 2.
  Operational failures keep their meaningful status and diagnostics. Keep
  usage errors short instead of dumping the whole guide, and make diagnostics
  actionable: name current components (for example "the shared
  `support/ui` components"), never retired peer names.
- A transparent wrapper keeps the wrapped tool's help. A wrapper that adds a
  distinct Compozsh mode, such as `g`, owns help for that mode and points to
  the underlying command's help.

### Content

- Line 1 is exactly `usage: command [arguments ...]` with the real name and
  syntax; line 2 is one sentence saying what the command does. Further lines
  cover options, modes, defaults and important safety behavior rather than
  repeating the syntax.
- Make help a self-contained guide proportional to the tool: where its data
  comes from, the no-option default, scope from home versus a subdirectory,
  what selection actually does, and why expected results may be missing.
  Distinguish collection bounds from visible-row limits and snapshots from
  live discovery; state the actual matching rules (not every fuzzy selector
  supports unordered fragments).
- Where applicable, document prerequisites, missing-tool and noninteractive
  fallbacks, modified keys, literal numeric input and Option-digit behavior,
  quoting and output formats. For commands that write, copy, switch or
  discard, state exact targets, confirmation policy, preservation boundaries
  and failure/recovery limits. Include synthetic examples and relevant knobs;
  skip irrelevant sections for simple tools.
- Format: section headings unindented, body lines indented two spaces,
  option/example prefixes separated from explanations by at least two spaces,
  and an `Examples:` section. This small known format lets the renderer
  emphasize structure without interpreting shell syntax.
- Update help and README together when a behavior, default, key, limit or
  failure policy changes.

### Presentation

- Color comes from the optional `_output_print_help` renderer in `.zsh.output`
  using validated `ZSH_OUTPUT_COLORS` roles, selected at invocation; without
  it, print the identical plain lines. No required peer, loader phase or
  duplicated palette for help; the standalone installer stays plain and never
  sources add-ons for styling.
- Emit color only to a supported 256-color terminal and respect a nonempty
  `NO_COLOR`. Pipes, redirects, substitutions, dumb terminals and a missing
  renderer get exact plain text. Styling never changes whitespace, words or
  examples, resets every span, and never prompt-expands, evaluates or executes
  documentation text.
- Direct help may open the shared topic workspace (see
  [full-screen](full-screen.md#help-topic-workspace)) when stdin/stdout and
  terminfo support the alternate screen. Capture the static companion once
  through a bounded native Zsh pipe before entering ZLE; paint, filter and
  resize launch no subprocess or provider. Pipes, redirects, `NO_COLOR`,
  missing help/UI peers and unsupported terminals keep printable help.
  Companions always print and never open a workspace themselves. Never launch
  an external pager.
- Ordinary help topics only read. The separately labeled Compose example
  action may hand off to the [Command composer](prompt.md#command-composer);
  only its explicit Replace draft inserts text, after cleanup, and never
  executes. Optional revision capture belongs to that composer interaction.

### Tests

The focused help test covers every public command: success, canonical usage
and description lines, empty stderr, no side effects, a same-source companion,
and byte-identical printable direct/provider output. Add each new command to
its inventory in the same TDD unit, and keep README's command list in sync.
Cover interactive help separately (capture once, resize, Back, cleanup), and
cover colored output and plain fallbacks with PTY tests. Assert scope and
safety facts without freezing whole paragraphs.

## Wrappers

- Output wrappers (`git`, `grep`, `man`) stay narrow and delegate all
  unsupported behavior to the system command with its native options.
- Color command output only when stdout is a terminal. Pipes, redirects,
  command substitutions and machine-readable output stay plain and
  byte-compatible with the original command, and the exit status is preserved.
- `grep` and `man` add palette styling only where help would: a nonempty
  `NO_COLOR`, an unset or dumb `TERM`, or fewer than 256 terminfo colors runs
  them as without Compozsh. `man` never chooses the pager; native `MANPAGER`,
  `MANCOLOR` and `PAGER` precedence stays with the system command.

## Tool discovery

`compozsh` derives its catalog from Zsh's live `functions_source` metadata
when it runs, restricted to public command-like names defined beneath a
`.zsh.addons` tree. Never scan add-on files, snapshot the loader, cache a
catalog, add an end-of-load phase, or invoke an unknown public function to
probe its help. A function without a same-source companion is listed as
`no help` and never executed. The catalog is invocation state: `compozsh` and
the Draft inspector's `_compozsh_tool_explore` declare it, so it is released
when that call returns and has no global value.
