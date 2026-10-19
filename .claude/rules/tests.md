---
paths:
  - "tests/*.zsh"
  - "tests/fixtures/*"
---

Native harness (`engineering/verification.md`): register with
`test_case '<description>' <function>`; assert with `test_fail`,
`test_assert_equal`, `test_assert_contains`; isolate with `test_make_temp_dir`,
`test_write_file`, `test_run_noninteractive` / `test_run_interactive` (fresh
`HOME`/`ZDOTDIR`, `env -i`, `LC_ALL=C`); drive PTYs with `zsh/zpty`. Run one
area with `zsh tests/run.zsh '<description fragment>'`; `'docs:'` and
`'security:'` select those suites.

New tests use the shared helpers that `engineering/verification.md` describes,
never hand-rolled waits or stubs: `test_pty_expect` (deadline and event PTY
waits), `test_pty_screen_sessions` (linear screen-session checks),
`test_picker_script` (scripted picker steps) and `test_source_support`
(loading shared support in child scripts).
