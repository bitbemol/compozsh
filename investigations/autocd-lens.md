# Bare-directory Interaction lens

## Behavior and boundaries

Compozsh enables AUTO_CD: at the ordinary interactive prompt a lone directory
can change location without `cd`. A path prefix alone is insufficient evidence:
it may identify an executable, and command, alias, function, builtin, reserved
word and suffix-alias classifications must retain precedence.

The existing syntax highlighter already checks bounded literal path tokens.
It now shares a lone-directory observation using only the exact bounded draft
and current-folder key. Caller AUTO_CD is inspected before local emulation.
Every highlighting pass clears the prior observation, including early exits.
The optional prompt consumes a matching observation without filesystem reads,
expansion, command execution or a second provider. It uses the existing
NAVIGATE outline, DESTINATION TEXT, FROM and advisory ACTION presentation.
Observed directories take precedence over lexical tool-name guesses and manual
descriptions. Missing/stale facts retain the lexical fallback.

This does not implement CDPATH resolution, unbounded discovery or speculative
completion of unfinished paths. Existing path restrictions remain conservative:
substitutions and globs are not evaluated; brace/history-dependent forms do not
publish a navigation observation. An observation is not a guarantee that a
directory still exists at Return. Actual execution remains entirely native.

## Regression evidence

The focused lens regression failed on the original implementation: `./folder`
was RUN despite the highlighter recognizing a directory. The fix passed literal
relative/home paths, escaped/quoted spaces, directory symlinks, AUTO_CD toggles,
command/function/alias/suffix collisions, extra arguments and compound drafts.
An additional missing-peer fixture exposed a directory named `g` receiving the
lexical Git cue; it failed before directory observations took precedence.
Prompt-only resize is checked with the path provider replaced by a failing spy;
changed buffers and folders cannot reuse the observation.

A real isolated interactive Zsh PTY verifies typed NAVIGATE at 120 columns,
native resize to 40 columns, preserved input/cursor, painted destination text,
and Return actually changing directory. A same-named function and executable
still run, while directory commands with arguments or AUTO_CD disabled fail.
The initial `zsh -c` fixture did not exercise interactive AUTO_CD and was
replaced with this actual prompt. Initial observer synchronization and empty
PTY writes were corrected in the harness, not treated as product regressions.
No private configuration or user history is used.

## Local latency observation

Apple Zsh 5.9, September 5, 2026: three alternating old/new samples of 400 warm
frames at 120x30, cycling `./folder`, `~/folder`, `cd ./folder` and `printf hello`
over disposable directories. Each frame includes native highlighting, complete
Interaction update/layout and prompt expansion, but not terminal painting.
The baseline functions came from the committed parent; both variants ran in
the same isolated shell. Other regression tests were running concurrently.

| Sample | Before (ms/frame) | After (ms/frame) |
| --- | --- | --- |
| 1 | 1.162 | 1.211 |
| 2 | 1.135 | 1.209 |
| 3 | 1.122 | 1.208 |

The added observation and richer directory frames cost roughly 0.05–0.09 ms
per frame in this workload. There is no additional path probe or subprocess.
These are local observations, not universal latency thresholds. Source setup
adds only two empty scalar declarations; it performs no new capture.

Final verification: **651/651** native tests passed in 151,880.1 ms, including
the typed AUTO_CD/resize/acceptance journey. All 14 Node tests, focused syntax
highlighting, manual summaries, peer-order checks, documentation/security
checks, changed-file Zsh syntax and whitespace checks passed. The website was
not changed; no new browser visual acceptance is claimed. Native PTY coverage
is distinct from manual acceptance in the user's Terminal.app font.
