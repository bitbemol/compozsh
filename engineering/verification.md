# Verification

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Test-driven development](#test-driven-development)
- [Change workflow](#change-workflow)
- [Required verification](#required-verification)

## Test-driven development

Compozsh requires behavioral TDD. See the [contributor TDD workflow](../README.md#strict-tdd-workflow) for the red/green/refactor cycle.

Pure documentation edits do not require manufacturing a failing product test.
A behavior-preserving refactor begins from green characterization coverage; add
missing characterization tests before moving code. When behavior is inherently
visual or terminal-driven, write the smallest deterministic automated contract
for its underlying logic first, record the manual reproduction and acceptance
criteria before implementation, and complete the change with a real PTY check.

Prefer tests against public behavior and durable state. A focused test may call
an underscore-prefixed helper only when that narrow algorithm is the contract
being protected and exercising it through ZLE would make the test ambiguous.
Do not make private names public merely for testing.

Every automated test must be deterministic and isolated. Use a disposable
`HOME`/`ZDOTDIR`, a minimal environment, fixed locale, and validated
`mktemp`-created paths. Never source the operator's real configuration, inspect
private history or add-ons, depend on network access, launch GUI applications,
or perform destructive tests outside a disposable repository. Avoid sleeps,
wall-clock assumptions, machine-specific paths, installed optional tools, and
assertions on unstable presentation details.

Keep the harness smaller than the product. Add a shared test helper only for a
repeated lifecycle, isolation, or assertion rule; do not build a shell testing
framework inside the repository. Test architectural invariants such as
standalone sourcing and the [peer configuration laws](architecture.md#peer-configuration-algebra)
directly; a browser model of those laws cannot validate the Zsh implementation.
Complement automation with a real PTY/ZLE check for key sequences, resize
behavior, colors, cursor motion, and terminal cleanup that a child-shell test
cannot establish.
For resize regressions, verify the painted editor display and preserved caller
state, and reject runtime diagnostics. Calculated layout values or a frame
marker alone cannot prove that a redraw succeeded.
For screen-cleanup regressions, send test synchronization over a separate
channel; printing markers inside the terminal changes the cursor and can mask
the fault. Include automatic pre-handler refreshes in resize coverage and
record Terminal.app's manual fullscreen/windowed acceptance result separately.

## Change workflow

- Keep README, SECURITY, shipped-unit inventory, repository layout, initializer
  template and affected add-on documentation synchronized when their contracts
  change. Review the final diff against the security contract even when no
  security documentation edit is needed.
- Review shell changes for quoting, idiomatic supported Zsh, exit-status
  preservation, effects, and the applicable performance and terminal contracts.
- When commits are requested, use one coherent unit and a short imperative
  message. Never stage unrelated files or push unless asked.


## Required verification

Run at least:

```sh
zsh tests/run.zsh
syntax_status=0
for syntax_file in .zshrc install.zsh templates/init.zsh tests/*.zsh \
                   .zsh.addons/**/.zsh.?*(N.); do
  zsh -n "$syntax_file" || syntax_status=1
done
(( syntax_status == 0 ))
git diff --check
test_home=$(mktemp -d) || exit
verify_status=0
TERM=xterm-256color HOME=$test_home ZDOTDIR=$test_home \
  ZSH_LOCAL_INIT=/dev/null \
  zsh -dfi -c 'source ./.zshrc; source ./.zshrc' || verify_status=$?
if [[ -d $test_home && ${test_home:t} == tmp.* ]]; then
  rm -rf -- "$test_home" || verify_status=$?
else
  print -u2 -r -- "Refusing unsafe test cleanup: $test_home"
  verify_status=1
fi
(( verify_status == 0 ))
```

Then select relevant checks from this list:

- For every change, reread `SECURITY.md` against the final tree and run the
  focused security and documentation contracts. When a sensitive boundary
  changes, exercise its independent audit commands, confirm their documented
  expected output and limitations, and include that evidence in the handoff.
- Whenever shipped add-ons change, compare every recursive repository-relative
  `.zsh.<name>` path with the README inventory. Every file must have exactly one
  current row and every row must resolve to a shipped file.
- After adding, moving or changing shared support entries, run
  `zsh tests/run.zsh 'support components'`,
  `zsh tests/run.zsh 'support function filenames'` and
  `zsh tests/run.zsh 'support private helpers'`. Review purity through the
  callees as well; naming and ownership checks cannot establish it. Remove
  obsolete paths and ownership claims from active instructions, documentation
  and fixtures; keep historical investigation layouts explicitly historical.
- When the loader or repository layout changes, exercise both symlinked and
  copied installations under disposable home directories and verify a public
  add-on command is discoverable in each.
- After changing add-on boundaries or shared state, source every enabled unit
  in normal, reverse, and at least one rotated order under isolated shells.
  Compare options, aliases, bindings, styles, hooks, prompts, and public names;
  checked orders must converge without load diagnostics. Apply the
  [peer configuration algebra](architecture.md#peer-configuration-algebra) to repeated sourcing,
  affected runtime behavior, overrides, fallbacks and any regrouping as well.
- Inspect final bindings with `bindkey` under `xterm-256color` and
  `screen-256color`; exercise changed keys in a real PTY/ZLE session.
- Verify standalone Escape, bracketed paste, cancellation, redraw, and resize
  behavior after changing an interactive widget.
- Test prompt changes outside Git, in clean/dirty/detached repositories, during
  an operation, with missing tools, and at wide and narrow terminal widths.
- Test destructive Git helpers only in a disposable temporary repository.
- Confirm wrappers preserve plain output through a pipe or redirect and retain
  the underlying command's options and status.
- Time several isolated startups before and after latency-sensitive changes.
- Source twice to prove hooks, functions, and bindings remain stable.

Do not declare work complete merely because the file parses. Interactive shell
code is complete when its fallback behavior, display, failure paths, and latency
have also been checked and the documentation matches reality.
