# Native Zsh conventions

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Zsh conventions](#zsh-conventions)

## Zsh conventions

- Write native Zsh, not lowest-common-denominator POSIX shell or Bash-shaped
  Zsh. Use 5.9 features when they make the code safer or simpler.
- Prefer `[[ ... ]]`, `(( ... ))`, native arrays and associative arrays,
  parameter-expansion flags, `zstyle`, ZLE hooks, and bundled `zsh/*` modules.
- Use `emulate -L zsh` in non-trivial functions that may be called after users
  change shell options. Enable additional options locally.
- Declare function variables with `local`, including integer, float, array, and
  associative types where useful. Declare intentional global state explicitly
  with `typeset -g`, `typeset -gi`, `typeset -gF`, `typeset -ga`, or
  `typeset -gA`.
- Prefix internal functions and state with `_`, including component-facing
  shared entries and their file-private helpers. Reserve unprefixed names for
  public terminal commands and documented extension points. Public configuration
  uses the existing `ZSH_*` and `PROMPT_*` families.
- ZLE widget names and Zsh special trap function names such as `TRAPWINCH` are
  shell-facing registrations, not public callable functions. Keep their
  implementation in underscore-prefixed helpers wherever Zsh permits an
  explicit mapping, and document unavoidable special-name exceptions locally.
- Treat the leading underscore as the boundary of the internal library.
  User-facing command examples, aliases and local configuration must not call
  or override internal names; the shipped-unit inventory may identify them.
  Product components may call another file's declared shared entry point,
  never its private helpers. Zsh does not enforce privacy, so reviews and tests
  enforce ownership. Focused unit tests may invoke a private helper when that
  is the narrowest way to verify its contract.
- Give every public add-on command a descriptive collision-resistant name and
  document it in `README.md`. Keep orchestration public only when users need to
  invoke it; prefix its detectors, renderers, installers, and state with `_`.
- Name Compozsh-owned public terminal commands in lowercase kebab-case: use
  hyphens between words, as in `external-device --format`, and never underscores.
  One-word commands remain one word. This naming rule does not apply to private
  underscore-prefixed helpers, Zsh special functions, or documented extension
  APIs such as `prompt_add_project_segment`. The suffix of a command's
  `_compozsh_help_<command>` companion must preserve the command's exact name.
- Use descriptive long options for Compozsh-owned commands and repository
  utilities, such as `--help` and `--worktree`, without single-letter aliases.
  Transparent wrappers preserve the underlying executable's native options.
- Treat self-documenting help as a hard public-interface contract. Every public
  add-on function intended for direct terminal invocation must accept the exact
  single argument `--help`, even when the command otherwise takes no options.
  Handle it before dependency checks, environment detection, or operational
  logic so help remains available on every supported machine.
- Define that help once in a private `_compozsh_help_<command>` companion in the
  same add-on file, and make the public command's `--help` branch delegate to
  it. The companion is a distributed capability marker used by the live
  `compozsh` explorer; do not duplicate its text, place it in another peer, or
  replace this convention with a central registry.
- Keep public help content deterministic and consistent:
  - The first line in plain-text form is `usage: command [arguments ...]`, using
    the command's real name and syntax. Spell the prefix exactly as lowercase
    `usage:`.
  - The second stdout line is a concise sentence explaining what the command
    does. Additional lines document supported options, modes, defaults, and
    important safety behavior when those exist; do not merely repeat syntax.
  - Make help a self-contained usage guide, proportional to the tool. Answer
    where its data comes from, the no-option default, scope from home or a
    subdirectory when relevant, what selection actually does, and why expected
    results may be missing. Distinguish collection bounds from visible-row
    limits, and snapshots from live discovery. State the actual matching rules;
    do not imply every fuzzy selector supports unordered fragments.
  - Document applicable prerequisites, missing-tool and noninteractive
    fallbacks, modified keys, literal numeric input and Option-digit behavior, quoting, and output
    formats. For commands that write, copy, switch, or discard, state exact
    targets, confirmation policy, preservation boundaries, and failure/recovery
    limitations. Include practical synthetic examples and relevant public
    configuration knobs; omit irrelevant sections for simple tools.
  - Keep scope and safety facts under focused regression tests, without
    freezing entire paragraphs. Update help and README together when a
    behavior, default, key, limit, or failure policy changes. Keep ordinary
    usage errors concise instead of dumping the complete guide to stderr.
  - A help request normally returns status 0, writes no diagnostics to stderr, and
    performs no project/configuration reads, mutations, navigation, clipboard
    access, operational tool detection, or network access. Direct owned help may
    open the shared topic workspace when stdin/stdout and terminfo support its
    alternate screen. Ordinary topics only read. The separately labeled Compose
    example action may hand off to an authored Command composer; only its
    explicit Replace draft accepts insertion after cleanup, never execution.
    Optional revision capture belongs to that explicit composer interaction,
    not help capture or topic navigation. Follow the [composer contract](prompt.md#prompt-and-terminal-ui);
    do not launch an external pager.
    Capture the static companion once through a bounded native Zsh pipe before
    entering ZLE. Presentation may inspect stdin/stdout, TERM, NO_COLOR and
    native terminfo; paint/filter/resize launch no subprocess or provider.
    Pipes, redirects, NO_COLOR, missing help/UI peers and unsupported terminals
    retain printable help without interaction. Companions themselves always
    print; they must never recursively open a workspace.
  - Color help through the optional `_output_print_help` renderer owned by
    `.zsh.output`, using validated `ZSH_OUTPUT_COLORS` roles. A same-source
    help provider selects that capability at invocation time and otherwise
    prints its identical plain lines. Do not introduce a required peer, a
    loader phase, or duplicated palettes to style help. Keep the standalone
    installer plain; help must not source add-ons to acquire styling.
    Keep section headings unindented and body lines indented by two spaces;
    separate option/example prefixes from explanations with at least two
    spaces. Use `Examples:` for the example section. This small known format
    lets the renderer emphasize structure without interpreting shell syntax.
  - Emit help colors only to a supported 256-color terminal, and respect a
    nonempty NO_COLOR. Pipes, redirects, substitutions, dumb/unsupported
    terminals, and an unavailable renderer retain exact plain text. Keep all
    whitespace, words, and examples unchanged by styling, reset every styled
    span, and never prompt-expand, evaluate, or execute documentation text.
    Cover colored output and plain fallbacks with native PTY regression tests.
  - Invalid Compozsh-owned invocations print the same usage line to stderr and
    return status 2. Operational failures retain their meaningful nonzero
    status and diagnostics rather than masquerading as usage errors.
- Keep the complete direct-command help contract covered by the focused help
  test. Add every new public command to its inventory in the same TDD unit of
  work, and assert success, the canonical usage and description lines, empty
  stderr, freedom from side effects, presence of the same-source companion, and
    byte-identical printable direct/provider output. Cover interactive direct
    help separately with native capture-once, resize, Back and cleanup tests.
    Keep the README command inventory in
  sync with that test.
- Keep tool discovery stateless and derived from Zsh's live `functions_source`
  metadata only when `compozsh` runs. Restrict it to public command-like names
  defined beneath a `.zsh.addons` tree. Never scan add-on files, snapshot the
  loader, cache a catalog, require an end-of-load phase, or invoke an unknown
  public function to probe its help behavior. A function without a same-source
  companion remains discoverable as `no help` and must not be executed.
- Public extension APIs called by other functions, such as
  `prompt_add_project_segment`, document their signature in the README rather
  than pretending to be CLI tools. A transparent wrapper around an existing
  executable preserves that tool's own help; a wrapper that introduces a
  distinct Compozsh mode, such as `g`, owns help for that mode and points users
  to the underlying command's help.
- Use `REPLY` for a helper's scalar result when that avoids a subshell. Use a
  clearly named typed global only when multiple results or shared widget state
  genuinely require it.
- Prefer `print -r --` over `echo`. Send diagnostics to stderr with `print -u2`.
- Use `command name` inside wrappers to call the underlying executable and
  prevent aliases or functions from recursing.
- Quote command arguments and paths. Leave expansions unquoted only when a
  specific Zsh splitting, globbing, or array flag is intentional and evident.
- Use `--` before user-controlled path operands when the command supports it.
- Use `IFS= read -r` for input. Treat terminal input, filesystem names, Git
  data, environment variables, and project metadata as untrusted text.
- Do not use `eval` for parsing or dispatch. Do not construct shell source from
  project data.
- Preserve useful exit statuses. A convenience wrapper must not silently turn
  an underlying command failure into success.
