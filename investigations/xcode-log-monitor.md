# Shared Xcode log monitoring

The requested improvement makes captured output the primary Run surface and
uses the same fuzzy matching and literal exclusion controls as other tools.
Simulator and physical-device runs now open the full-width Xcode / Logs reader;
Escape returns to existing Run controls. Mac app launching is outside this
log-monitor change.

The entry scope is one explicitly launched app on one selected destination.
Simulator retains its existing stdout/stderr and executable-scoped Logger
sources. The physical-device owner retains the existing native devicectl launch
arguments but sends its stdout/stderr through a private FIFO instead of painting
untrusted raw output directly into an interactive terminal. Plain/missing-UI
fallback retains the native foreground console. The interactive monitor does
not forward typed search input to the application's stdin.

Both owners keep the same 32 KiB/200-line tail and partial-line bounds. Filtering
uses shared case-insensitive fuzzy character matching, preserves source order
and duplicates, and excludes one literal phrase through Ctrl-]. Both fields,
their editing focus, severity selection and paused reading position survive
Options and reopening. Copy uses matching original source lines, including
offscreen data and metadata omitted by compact presentation.

Native-format records keep separate time/severity/scope headers and message
bodies in the shared palette. Counts summarize recognized Error/Fault records
across the retained snapshot, including hidden records. Errors and faults is an
explicit view intersected with search and exclusion. Plain output remains
unclassified: words such as "error" do not establish severity, and no count or
closed stream establishes app health. The monitor keeps the existing source
failure notices, dropped-tail disclosure, follow/pause behavior and shared guide.

The device console belongs only to this Run. Shell job state is checked before
signaling its captured child PID. Cleanup follows screen restoration, drains
while waiting through at most twenty 50 ms waits, and reaps the child. If forced
termination is necessary, an explicit notice asks the user to check the app on
the device. Normal launch/console failures and failures during termination
remain nonzero. The private temporary FIFO/directory are removed on normal and
handled-error exit; no persistent Compozsh log file or extra device discovery is
added. Device LLDB and unified-log capture are not inferred from Simulator.

Regression tests first demonstrated absent fuzzy/exclusion filtering, severity
views and primary-reader entry. Existing native Simulator PTY coverage now
exercises the initial reader and both search fields before continuing through
live updates, pause/guide/copy, narrow resize, Stop, LLDB and abort cleanup.
A separate real PTY uses a synthetic device-console child to verify initial
logs, fuzzy/exclusion input, a 40-column redraw and post-screen Stop/terminal
cleanup. Lifecycle tests cover native failure, graceful termination, termination
failure and an unresponsive console, including exact argv and temporary cleanup.
One test initially compared an unset restored numeric flag to the text "0";
using its actual numeric state corrected that harness assertion. No production
terminal-cleanup workaround was introduced.

A bounded synthetic benchmark of 200 native-format records with 50 changing
fuzzy queries averaged about 15.4 ms per collection on the development host.
Unchanged output still avoids publication/painting, and matching remains
bounded by the existing retained tail. This observation is not a cross-machine
performance guarantee. Device output and cleanup tests use native-command
spies; no physical hardware was installed or launched for this change.

The completed change passed all 789 native regression tests, native syntax
checks, isolated double-sourcing and whitespace checks. Help, public inventory
and security contracts passed within that suite. Native PTY coverage includes
both Run owners; physical-device execution remains unverified on paired hardware.
