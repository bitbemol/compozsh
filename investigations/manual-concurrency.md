# Manual capture concurrency exploration

## Status and question

September 15, 2026: the first two sections retain historical experiments, **not
shipped runtime behavior**. The implementation and verification section below
records the subsequent authorized lifecycle implementation.
Can independent manual processing reduce collection time, and can moving optional
capture out of synchronous `precmd` make an uncached shell editable promptly?
The [startup investigation](terminal-startup-latency.md) retains the baseline,
implemented cache and full parity/latency evidence.

## Parallel collection experiment

[manual-parallelism.zsh](benchmarks/manual-parallelism.zsh) selects a fixed,
ordered workload of 2919 public `/usr/share/man` pages using a lightweight
selection fixture, then performs the same real read/parser/formatter work with
one, two and four forked Zsh workers. Selection is outside the timer. Workers
stride through the same list; each owns an empty formatter directory and emits
only a count. No description data is saved or transmitted. This compares page
processing, not a complete catalog merge, root discovery or ZLE delivery.

Same arm64 macOS 27.0 / native Zsh 5.9 host, isolated HOME/ZDOTDIR/TMPDIR,
system-only PATH and `en_US.UTF-8`; no concurrent suite, no filesystem-cache
flush. Order was 1,2,4 / 4,1,2 / 2,4,1 workers.

| Workers | Samples (ms) | Median (ms) | Speedup |
| ---: | --- | ---: | ---: |
| 1 | 2645.212, 2591.199, 2646.582 | 2645.212 | 1.00× |
| 2 | 1367.526, 1371.794, 1361.871 | 1367.526 | 1.93× |
| 4 | 750.739, 755.479, 756.103 | 755.479 | 3.50× |

All workers collectively read 2919 pages per trial. The broader public-only
workload includes pages outside the normal combined-root first-4096-entry
capture; it is not the cache benchmark's 1898 eligible records. Four existing
parser `illegal byte sequence` diagnostics occurred per trial in this broader
UTF-8 workload, with formatter fallback still completing. They were not hidden
or counted as successful fast parses. Existing Unicode/byte-boundary parsing
needs a separate regression investigation before parallel production adoption.
These timings support parallelism but do not prove output equivalence or optimal
worker count on other hardware. More workers also increase simultaneous process
and CPU pressure; do not spawn one worker per page.

## Background readiness experiment

The `background` mode of
[first-editable-prompt.zsh](benchmarks/first-editable-prompt.zsh) forks actual cold
capture and lets the parent reach ZLE with its normal unknown-description
fallback. A separate FIFO carries readiness/edit/completion markers, keeping
measurement output out of the editor. A bound key confirms the parent accepted
a 26-character draft while collection continued. The worker then reports its
final name count. This prototype **does not import descriptions into the parent**;
it is evidence of scheduling feasibility, not a finished UI feature.

| Trial | Editable (ms) | Draft observed (ms) | Collection complete (ms) |
| ---: | ---: | ---: | ---: |
| 1 | 240.279 | 284.531 | 3598.612 |
| 2 | 225.429 | 269.376 | 3586.714 |
| 3 | 224.741 | 268.680 | 3560.266 |

Each child captured 2308 names. Median editable time was **225.429 ms**, while
median collection completion was **3586.714 ms**. The edit milestone includes
driver round-trip time, so it is not a keystroke latency benchmark. Parent name
count remained zero because result merging was deliberately outside the test.
No claim is made for immediate ABOUT availability, job-control polish, multiple
simultaneous terminal windows, cancellation safety or interactive result delivery.

## Original proposed design (historical)

Use both disposable public-data caching and bounded background capture. Caching
avoids repeated work across windows; concurrency controls when/how the remaining
work runs. Removing the cache would repeat that CPU/process load in every shell.

1. Make the first prompt usable from existing shell facts and eligible cached
   descriptions. Optional missing descriptions retain the current fallback.
2. One shell-owned coordinator captures a fixed discovery/environment generation.
   Start with a small bounded pool; the four-worker result justifies a candidate,
   not a universal fixed default.
3. Preserve discovery ordinals through worker results. Merge in original section,
   root, page and alias order so completion order cannot change precedence.
4. Deliver bounded inert records through kernel pipes/FIFOs, not private-data
   cache files. Validate framing, length and generation before applying a complete
   map in the parent. Only eligible public results may be persisted.
5. Use an event-driven native descriptor callback. It must preserve BUFFER,
   CURSOR, exit status, hooks and foreground command behavior; defer repaint
   while a fullscreen view owns the terminal. Bound work per callback so parsing
   a large result does not merely move the pause into typing.
6. Increment an in-memory generation on explicit refresh or relevant selector
   changes. Reject obsolete results, cancel/reap owned workers and close their
   descriptors on refresh, re-source and shell exit. No daemon, polling loop or
   unbounded retry queue. Private selectors stay in memory, including identities
   used to detect stale worker results.
7. Observe additions/removals at a documented capture boundary. Unknown input
   during editing must be an immediate fallback, not a blocking provider call.
   Do not interpret every typo as a request to rescan every manual.

Before shipping, demonstrate failing tests and then correctness for deterministic
merge, slow/failed workers, partial/malformed delivery, byte bounds, stale
completion after refresh/environment change, cancellation/exit cleanup,
fullscreen ownership, uninterrupted real ZLE typing/resize and standalone/re-source
behavior. Compare exact final descriptions against the serial implementation.
Measure cold/warm readiness, description arrival, keystroke behavior, CPU/process
pressure and multiple-window contention. Native Terminal.app acceptance remains
separate from PTY tests.

## Implemented lifecycle increment

The follow-up explicitly authorized safe merging, cancellation and outdated-result
rejection. The maintained behavior is in
[the manual producer contract](../engineering/manual-cache.md#asynchronous-prompt-capture).
This increment uses **one ordered capture worker**, with two native ownership
supervisors. It does not enable the four-worker page-processing prototype.
Serial collection preserves section/root/page/alias precedence; the parent only
selects its new catalog after complete validated delivery and successful completion.
Both control and data descriptors run as native ZLE widgets, with an 8-KiB data
read bound. A fallback prompt is immediately usable while results are pending.

### Decisions and red/green evidence

- Existing manual behavior began green: 36 selected tests passed before the
  asynchronous refactor. New frame/identity/lifecycle tests first failed for
  absent validation, identity and nonblocking request capabilities.
- Split-control coverage failed because a partial `D` was treated as a failed
  worker. Bounded accumulation now accepts split `DONE` and rejects failure.
- Real ZLE delivery first failed because `zle -R` did not derive a new prompt.
  Calling the existing editor presentation adapter fixed observable repaint.
  Completion through a plain FD handler then exposed an empty BUFFER; making
  both handlers ZLE widgets fixed that path. No keypress is required to update.
- A truncated frame plus worker success originally waited indefinitely for END.
  Success now closes the producer's write phase: remaining bytes must drain,
  the complete frame must validate, and trailing data is rejected before commit.
- The ownership test first failed for a missing deadline keeper. The outer
  native owner now stays alive after terminating overdue collection, until the
  parent acknowledges failure. Handles are removed before owner termination;
  a suspended parent cannot retain a reusable PID for a future signal.
- Native tests stop live descendants, including a termination-ignoring child,
  on refresh, selector change, re-source, command execution and deadline. They
  preserve the caller's jobs, coprocess and unrelated FD handler. Shell exit
  is exercised separately. Failed requests do not retry until invalidated.
- The existing peer-order test caught reversed pre-execution hooks. Manual
  cancellation now prepends only its own hook, preserving other hooks' relative
  order and converging across normal, reverse and rotated loading.
- Real PTY checks cover ordinary/nested editor delivery, automatic description
  repaint, draft/cursor/undo/mark/region and prior exit-status preservation, and resize. Nested screen
  ownership defers prompt painting until returning to the ordinary editor.
- Final budget coverage reproduced rejection of a valid 7,000-name ASCII
  catalog above 4 MiB: a four-bytes-per-character estimate exhausted the nominal
  16-MiB budget early. The sender now counts actual bytes, while the record
  validator retains Unicode character limits. The regression passes without
  changing transport bounds or filtering out valid records.

Native API evidence: the installed Zsh 5.9 `zshmodules(1)`/`zshzle(1)` manuals,
the official [ZLE builtin reference](https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html#Zle-Builtins),
and [Zsh 5.9 zpty source](https://raw.githubusercontent.com/zsh-users/zsh/zsh-5.9/Src/Modules/zpty.c).
These confirm the widget/descriptor distinction and native process-group
ownership behavior; the repository tests exercise those contracts on this Mac.

### Paired end-to-end measurements

Same arm64 macOS 27.0, Apple Zsh 5.9, isolated HOME/ZDOTDIR/TMPDIR,
`en_US.UTF-8`, system-only PATH, neutral directory and no concurrent test suite.
No filesystem-cache flushing. Each trial ran serial cold, async cold, serial
warm, async warm. The serial fixture uses the pre-refactor manual producer
saved before implementation with the reviewed HEAD bootstrap/other peers.
Warm phases prebuild their own public cache in a separate shell; all start with
fresh completion state. Both measure entry into the real ZLE prompt.

| Endpoint | Samples (ms) | Median (ms) |
| --- | --- | ---: |
| Serial cold editable, all descriptions | 3274.625, 3294.914, 3349.902 | 3294.914 |
| Async cold editable | 217.933, 223.562, 224.506 | 223.562 |
| Async cold full parent catalog | 3417.269, 3463.120, 3523.857 | 3463.120 |
| Serial warm editable, all descriptions | 848.107, 863.667, 868.990 | 863.667 |
| Async warm editable | 218.816, 226.635, 225.977 | 225.977 |
| Async warm full parent catalog | 1056.160, 1079.228, 1073.069 | 1073.069 |

Cold median editable latency improves by **3071.352 ms (93.2%)**; warm by
**637.690 ms (73.8%)**. Complete descriptions arrive later than the serial prompt
by 168.206 ms cold and 209.402 ms warm: transport validation, scheduling and
safe ownership have a cost. Async scheduling does not eliminate collection CPU
work; the public cache still avoids repeated OS parsing. The implementation
adds two bounded ownership processes and a transient candidate map, with no
page-worker fan-out. These initial runs did not quantify resource cost or callback
latency; the additional review below measures those separately.

The benchmark accepted a 26-character draft before results in every trial and
reported the same draft/cursor at publication. Median draft observation was
263.692 ms cold and 266.735 ms warm, including driver round-trip delay; this is
not an individual-keystroke latency measurement.

Reproduce using `benchmarks/first-editable-prompt.zsh <serial-fixture> cold|warm`
and `benchmarks/async-first-prompt.zsh <candidate> cold|warm`.
`benchmarks/manual-async-parity.zsh <serial-fixture> <candidate>`, in a disposable
minimal environment, compared all **2308** descriptions and attribution labels
exactly in memory for both cold and warm capture. No manual prose is logged.

### Verification and remaining boundaries

#### Additional review under the updated global rules

Review targets chosen before additional profiling on this reference Mac:
median editable startup at most 350 ms; ordinary delivery callbacks at most
16 ms; synthetic boundary callbacks at most 50 ms. These are local profiling
targets, not portable wall-clock CI assertions. Include small/typical catalogs,
the 8,192-record limit, near-16-MiB Unicode transport and a near-limit selector
identity. Measure final publication as part of delivery, and report aggregate
process CPU/memory separately from callback latency.

The review found two introduced costs that startup measurements alone missed:
repeated wildcard suffix matching in the parser, and a full map copy at commit.
`zprof` attributed 98.7% of the long-Unicode fixture's capture-callback time to
the parser itself. Native index searches were also slower on these encoded
strings; native literal line splitting preserves empty fields and avoids those
repeated scans. Complete validation still rejects NUL, empty records, duplicate
END, trailing bytes and obsolete identities. Publication now selects the
validated catalog in place; description lookup returns its matching source in
the same result. The new metadata contract first failed, then passed. Existing
frame, invalidation, cancellation, ZLE and serial-parity tests remained required.

For N records, B transport bytes and S selector characters, retained state is
O(B + N + S), plus interpreter/hash-table overhead. Native hash lookups are
expected constant time per bounded key. The background sender sorts N names;
delivery does not sort. Across delivery, parsing visits bounded chunks and
records; identity comparison adds O(S) per callback. Final publication selects
the catalog without an O(B + N) copy. Invalidating an old catalog frees it at
the capture boundary. More complicated worker pools, disk IPC for private data,
and progressive visible publication are unnecessary for these latency targets.

`benchmarks/manual-delivery-budgets.zsh` exercises the complete native reader
callback, including final publication/descriptor cleanup, without ZLE painting.
The last two profiles use 4,096 long Unicode records totaling 16,444,372 bytes;
the selector case additionally sets a synthetic 260,001-character MANPATH.
No real private selector or manual prose is recorded. Two final runs gave:

| Workload | Bytes | Callback p95 range (ms) | Maximum callback range (ms) |
| --- | ---: | ---: | ---: |
| 32 short records | 3260 | 3.839–4.446 | 3.839–4.446 |
| 2308 ordinary records | 236656 | 1.853–2.325 | 4.482–4.524 |
| 8192 long ASCII records | 5995476 | 0.823–0.908 | 3.623–3.880 |
| Near byte cap, Unicode | 16444372 | 1.172–1.231 | 6.178–6.901 |
| Unicode plus near-limit selectors | 16444372 | 8.944–9.152 | 18.654–19.133 |

Before the changes, the ASCII-limit case peaked at 63.586–67.730 ms and the
Unicode case failed to complete within the profiling harness's 60-second limit.
After literal splitting alone, Unicode completed but whole-map publication still
paused for 224.971 ms. Selecting the validated map removed that pause. These
are explicit workloads and reference-machine results, not universal maxima.

One final native `/usr/bin/time -l` run measured the entire synthetic driver,
including fixture construction and interpreter startup:

| Workload | Real time (s) | User + system CPU (s) | Peak RSS (bytes) |
| --- | ---: | ---: | ---: |
| 32 records | 0.01 | below displayed precision | 4046848 |
| 2308 ordinary records | 0.09 | 0.08 | 5390336 |
| 8192 long ASCII records | 0.72 | 0.72 | 14434304 |
| Near byte cap, Unicode | 2.62 | 2.61 | 42713088 |
| Unicode plus large selectors | 17.66 | 17.63 | 50298880 |

The comparable ASCII-limit profile previously took 9.70 s real / 9.68 s CPU
and 41,975,808 bytes peak RSS. Resource counters required the authorized native
profiler outside the sandbox; no project/user data was supplied to a service.
Energy and total memory across a real shell plus all worker processes were not
measured. The large-selector case still costs CPU, but each callback met the
review budget and the ordinary workload is much smaller.

The final real-ZLE benchmark types `ls -la` before completion and times both
descriptor widgets through prompt repaint. Three paired serial/async trials,
with no concurrent suite or resource benchmark, produced:

| Endpoint | Samples (ms) | Median (ms) |
| --- | --- | ---: |
| Serial cold editable | 3876.164, 3711.065, 3962.831 | 3876.164 |
| Final async cold editable | 234.994, 231.134, 259.425 | 234.994 |
| Final async cold full catalog | 3531.939, 3679.163, 3890.658 | 3679.163 |
| Serial warm editable | 948.032, 899.613, 912.777 | 912.777 |
| Final async warm editable | 234.263, 240.432, 243.057 | 240.432 |
| Final async warm full catalog | 1059.776, 1032.938, 986.571 | 1032.938 |

The editable median improves by 3641.170 ms (93.9%) cold and 672.345 ms (73.7%)
warm within this batch. Maximum actual ZLE callback time was 1.830–2.271 ms,
including repaint. All runs retained the six-character draft and cursor. The
final cold and warm catalogs again matched all 2308 serial descriptions and
source labels exactly. Historical batches above are not fixed thresholds;
collection timing varies with native provider and machine conditions.

The public-artifact review covered 32 changed/untracked text files and 23
agent-created diagnostic logs, with no binary deliverables. The scan
found no confirmed introduced personal/credential data in repository artifacts.
An identifying temporary diagnostic log was sanitized; new PTY/benchmark failure
diagnostics now redact repository/home/user/host values. Synthetic temporary fixture
paths and an unchanged documented Git SSH remote were reviewed as false positives.
No unrelated files or history were rewritten. This is a scoped review, not an
assertion that the entire repository/history is free of private information.

Security review covered private manual/selector retention, inert public cache
data, unsafe filesystem entries, malformed/oversized transport, partial/stale
publication and owned-process cancellation. Native syntax and repository security
tests provide available static/behavioral checks. Gitleaks, TruffleHog, Semgrep
and ShellCheck were unavailable; no third-party dependency was introduced, and
no dependency advisory scanner was available. Apple's
[signed system volume guidance](https://support.apple.com/guide/security/signed-system-volume-security-secd698747c9/web)
supports the stated protected-system-content assumption; lowered platform
protections, ACLs and same-account interference retain their disclosed limits.

One additional full-suite run with an explicitly forced `TMPDIR=/tmp` returned
893 passes and one failure in the unchanged isolated Touch ID fixture. The
fixture expects its account's primary group, but directories beneath `/tmp`
inherit a different group on this host. The failure reproduces in isolation;
assigning the primary group to the disposable fixture before creating children
makes it pass. The normal macOS temporary directory also passes unchanged.
This is an existing fixture environment assumption, not an async regression;
no privileged product routine or unrelated fixture was modified.

Final verification with the standard macOS temporary directory: **894 passed,
0 failed in 184466.4 ms**. The focused asynchronous contract has eleven cases
plus the matching-metadata lookup contract. Native syntax checks, isolated
double sourcing, all supported peer traversal orders, README inventory,
security/privacy and documentation contracts, and `git diff --check` passed.
Cold/warm serial parity and the profiling results are recorded above.

No installation was performed during this review. Native Terminal.app manual
acceptance and the second target Mac's reported 6–7-second experience
remain unmeasured. The four-worker pool remains a separate optimization with
its own ordered-merge and broader-parser work.
