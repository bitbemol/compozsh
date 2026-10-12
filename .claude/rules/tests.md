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
