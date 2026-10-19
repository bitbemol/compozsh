# Verification

How Compozsh is tested and what "done" means.

## Essentials

- **Behavioral TDD.** Every observable feature or fix starts with a test that
  fails for the intended reason. Never weaken an assertion to make it green.
- **Isolation.** Tests never touch the operator's real configuration, history
  or private peers, never need the network, and never launch GUI applications.
- **Done means verified.** Parsing is not completion: interactive code is done
  when fallbacks, display, failure paths and latency have been checked and the
  documentation matches reality.

## Test-driven development

For every observable feature or bug fix:

1. Describe the intended behavior and edge cases.
2. Add the smallest test that expresses the behavior without implementing it.
3. Run it with its description filter and see `FAIL` — because the behavior is
   missing or broken, not because of a syntax or setup mistake (**red**).
4. Implement the smallest correct change until the focused test passes
   (**green**).
5. Improve names, boundaries, duplication or performance without changing
   behavior, rerunning the test (**refactor**).
6. Run the required verification below before finishing.

A bug's regression test must demonstrably fail against the buggy code and stay
afterward. Pure documentation edits need no manufactured failing test. A
behavior-preserving refactor starts from green characterization coverage; add
missing characterization tests before moving code. A test that pins
already-correct behavior is characterization coverage and passes from the
start; say so rather than manufacturing a failure. When intended behavior
changes, update the exact expectation first and watch it fail; never loosen an
exact assertion to pass. When behavior is inherently visual or terminal-driven,
write the smallest deterministic test of its underlying logic first, record the
manual reproduction and acceptance criteria before implementing, and finish
with a real PTY check.

## The native harness

Zsh has no complete unit-test framework, so the suite is a deliberately small
harness of ordinary Zsh functions, arrays, subshells and exit statuses — no
library, plug-in or downloaded runner. Keep the harness smaller than the
product: add a shared helper only for a repeated lifecycle, isolation or
assertion rule.

- `tests/run.zsh` sources every regular `tests/*_test.zsh`. Each file registers
  functions with `test_case '<description>' <function>`; every test runs in its
  own subshell with `ERR_RETURN` and a validated temp-dir cleanup trap, so
  variables, options, directories, functions and traps never leak. `INT` or
  `TERM` cleans up and then ends the test by that signal, even mid-wait, so it
  fails instead of continuing without its directory; Ctrl-C stops the run.
- `zsh tests/run.zsh 'fragment'` selects tests whose descriptions contain the
  case-insensitive fragment. The runner prints `PASS`/`FAIL` lines and a
  summary, and exits nonzero when anything fails.
- `tests/support.zsh` provides assertions (`test_fail`, `test_assert_equal`,
  `test_assert_contains`), temporary state (`test_make_temp_dir`,
  `test_write_file`) and shells under test (`test_run_zsh`,
  `test_run_interactive`, `test_run_noninteractive`). Those launch Zsh through
  `env -i` with a fresh temporary `HOME`/`ZDOTDIR`, a minimal fixed environment
  and locale, `-d -f` to skip startup files, and `-i` only when the behavior
  needs an interactive shell. Once a test has called `test_make_temp_dir`, its
  children get `TMPDIR=$TEST_TMP_DIR/tmp`, so product temporary files are
  removed with the test rather than left in the runner's `TMPDIR`.
- A child script loads shared support as the installed unit: it sources
  `tests/support.zsh` and calls `test_source_support <repository-root>`, which
  sources every regular `support/**/.zsh.?*` file in the bootstrap's lexical
  order, skips `support/cache` and stops on the first failed source. Hand-pick
  `support/ui` units only when a test needs a support unit absent or loaded at
  a chosen point, or unit-tests a few UI entries with their collaborators
  stubbed, and name that subset in a `# Support subset:` comment in the same
  test function. A harness check rejects a line that sources a UI unit by
  path, or loops over UI units to source them, in either path spelling,
  without that comment. `support/functions` entries are outside the check: a
  test may source the entries under test, or those a peer under test needs,
  directly and without a comment.
- Interactive regressions drive an isolated terminal with Zsh's bundled
  `zsh/zpty` module, sending keys and real resize signals. The shell that owns
  the terminal sources `tests/pty_support.zsh`: `test_pty_start` opens a
  nonblocking session, and `test_pty_expect` waits for terminal text or a FIFO
  event under one absolute deadline, reporting what it read. A missing marker
  or an endless repaint fails instead of hanging the suite, silence alone never
  fails, and a finished command fails at once. Don't hand-roll blocking reads
  or per-wake timeouts. `test_pty_screen_sessions` checks the alternate-screen
  sessions in a kept trace in linear time and returns each session's output.
  Check sessions with it, appending the caller's `rmcup` while a screen is
  still open, instead of hand-written marker patterns or stripping a trace one
  marker at a time, which is quadratic in its length.
- A test that drives a workspace's own views without a terminal sources
  `tests/picker_support.zsh` and, once the code under test is loaded, calls
  `test_picker_script`, whose steps (`select VALUE [ACTION]`, `cancel`,
  `abort`, `observe FUNCTION`, separated by `--`) give successive views the
  engine's outcomes, statuses and bookmarks and log each view's title,
  subtitle, page size, requested start row and visible labels. An observe
  function runs in the view's scope, so it can check the view's state, render
  it or call its idle callback; a later step ends the view. A session callback
  given to `_zle_picker_run` runs for real, so a lifecycle test scripts the
  session's views rather than replacing the screen. New tests script outcomes
  through it instead of redefining `_zle_picker_loop`, `_zle_picker_run` or
  `_zle_picker_screen_session`, so the engine's result and bookmark protocol
  is restated in one place; tests of the engine's own keys, painting, idle
  work or documents keep the real loop.

Adding a test — arrange, act, assert, guarding each step with `|| return` so a
later success cannot hide an earlier failure:

```zsh
_test_mkcd_rejects_a_missing_operand() {
  test_make_temp_dir || return
  local output='' exit_status=0

  output=$(test_run_noninteractive "$TEST_TMP_DIR/home" '
    source "$1/.zsh.addons/.zsh.tools"
    mkcd
  ' "$TEST_REPO_ROOT" 2>&1) || exit_status=$?

  test_assert_equal 2 "$exit_status" \
    'mkcd accepted a missing directory' || return
  test_assert_contains "$output" 'usage: mkcd [--] <directory>' \
    'mkcd omitted its usage diagnostic'
}
test_case 'mkcd rejects a missing directory operand' \
  _test_mkcd_rejects_a_missing_operand
```

Put a test beside the closest concern in an existing `*_test.zsh`, or create a
focused new file with that suffix.

## Writing good tests

- Test public behavior and durable state. Call an underscore-prefixed helper
  only when its narrow algorithm is the contract and driving it through ZLE
  would make the test ambiguous; never make a private name public for testing.
- Be deterministic: disposable `HOME`/`ZDOTDIR`, minimal environment, fixed
  locale, validated `mktemp` paths. Avoid sleeps, wall-clock assumptions,
  machine-specific paths, installed optional tools and assertions on unstable
  presentation details. Destructive tests run only in disposable repositories.
  `tests/run.zsh` unsets inherited `GIT_*` variables and disables global and
  system Git configuration, so an inherited selector cannot redirect Git
  fixtures in the runner process into another repository, and the operator's
  global hooks and signing setup never run on them (Git's default per-user
  ignore and attributes files still apply).
- Test architectural invariants such as standalone sourcing and the
  [peer configuration laws](architecture.md#peer-configuration-algebra)
  directly; the website's browser model cannot validate the Zsh code.
- Resize regressions verify the painted display and preserved caller state and
  reject runtime diagnostics; a calculated layout value or frame marker alone
  does not prove a redraw worked.
- Screen-cleanup regressions send test synchronization over a separate
  channel, because markers printed in the terminal move the cursor and can
  mask the fault. Include Zsh's automatic pre-handler refresh in resize
  coverage.
- Complement automation with a real PTY/ZLE check for key sequences, resize,
  colors, cursor motion and terminal cleanup. A PTY still cannot prove how
  Terminal.app renders colors or reflows scrollback, or physical key
  ergonomics, so record Terminal.app fullscreen/windowed and other manual
  acceptance separately.
- A static scan of source or documentation text is a fine test for a static
  invariant (for example, no shipped file names a retired peer); behavior
  still needs a behavioral test.

## Required verification

Run at least:

```sh
zsh tests/run.zsh      # full suite
zsh tests/verify.zsh   # syntax of every shipped Zsh file, git diff --check, silent double re-source
```

The full suite takes about 5 minutes. The Xcode Logger cleanup timing test
is environment-sensitive; rerun it alone before treating a failure as a
regression.

Then add the checks for each boundary you changed:

| Changed | Also verify |
| --- | --- |
| Anything | Reread SECURITY.md against the final tree; during development run `zsh tests/run.zsh 'docs:'` and `zsh tests/run.zsh 'security:'`. When a sensitive boundary changes, run its independent audit commands, confirm their documented expected output and limitations, and report that evidence. |
| Shipped peer files | Every recursive `.zsh.addons/**/.zsh.<name>` has exactly one README inventory row and every row resolves to a file. |
| Shared support entries | `zsh tests/run.zsh 'support components'`, `'support function filenames'`, `'support private helpers'`, `'support pure'`, `'start with emulate'`; review purity through callees. Remove obsolete paths from active docs and fixtures. |
| Loader or layout | Symlinked and copied installs under disposable homes; a public command is discoverable in each. |
| Peer boundaries or source-time state (aliases, options, bindings, hooks, defaults) | Source every unit in normal, reverse and a rotated order; compare options, aliases, bindings, styles, hooks, prompts and public names — checked orders must converge without load diagnostics; source twice for stable hooks/bindings. See the [peer configuration algebra](architecture.md#peer-configuration-algebra). |
| Keys or widgets | `zsh tests/run.zsh 'start with emulate'`; `bindkey` under `xterm-256color` and `screen-256color`; standalone Escape, bracketed paste, cancellation, redraw and resize in a real PTY. |
| Prompt | Outside Git; clean, dirty and detached repositories; during an operation; missing tools; wide and narrow widths. |
| Destructive Git helpers | Only in disposable repositories. |
| Wrappers | Plain output through pipes/redirects; original options and exit status preserved. |
| Latency-sensitive paths | Several isolated startups before and after, or the workspace measurement recipe in [performance](performance.md#measuring-latency). |
| Manual async capture | `zsh tests/run.zsh 'manual async'`; compare serial/async catalogs with `investigations/benchmarks/manual-async-parity.zsh`; measure editable prompt and catalog arrival with `investigations/benchmarks/async-first-prompt.zsh`, separately from the suite. |
| Claude Code setup (`.claude/`) | `zsh tests/run.zsh 'tooling:'`, `'docs:'` and `'platform'`; start a new session to load changed settings, agents or skills. |
| Website | `zsh tests/run.zsh 'website'`; with Node, `node --test tests/site.test.mjs tests/site-scenes.test.mjs tests/site-picker.test.mjs tests/site-review.test.mjs`; browser checks per [docs/README.md](../docs/README.md). |

## Change hygiene

- Keep README, SECURITY, the shipped-unit inventory, the repository-layout
  tree, the initializer template and affected `--help` text synchronized when
  their contracts change; a change is incomplete while any of them is stale.
- Don't label a partial implementation a complete experience.
- When a convention changes, fix contradicting assertions across active docs,
  showcase copy and tests; adding a correct paragraph doesn't repair an older
  contradictory one. Keep historical investigations labeled as historical.
- Review shell changes for quoting, idiomatic Zsh, exit-status preservation,
  effects, and the applicable performance and terminal contracts.
- When commits are requested, make one coherent unit with a short imperative
  message. Never stage unrelated files or push unless asked.
- Report automated results, timing failures, PTY evidence and manual
  Terminal.app acceptance separately; don't call a rerun an entirely green
  original run.
