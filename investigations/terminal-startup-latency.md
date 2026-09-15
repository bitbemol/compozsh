# Terminal startup latency investigation

## Status and intended outcome

Diagnosis reproduced on September 14, 2026 against
`ed6c944a2e4e7131b1a17d3e99e44644b446a7b6`. On September 15 the user approved
optional persistent public-system caches and requested exploration of concurrent
collection. The second target Mac has not been measured directly.

The outcome is a promptly editable new Terminal.app window with full manual
descriptions. Measure through the final ZLE line-init hook: source-only timings
missed the largest delay. The earlier blanket no-cache rule prevented a useful
optimization; it is replaced by [the cache contract](../engineering/caching.md).
Keep user/project/private data out of performance caches, preserve uncached
features and memory-only editing, and retain order-independent peers.

The first implementation added a disposable `.zsh.manual.cache` for protected OS
manual results. Its synchronous measurements below are historical. The subsequent
[asynchronous lifecycle implementation](manual-concurrency.md#implemented-lifecycle-increment)
delivers complete validated results without blocking editing. Independent
exploratory scripts also measure parallel page processing; that worker pool
remains unimplemented. Private configuration and Terminal
profiles are untouched. No real installation or commit is part of this work.

## Reproduction and causal evidence

The baseline `_prompt_update` calls `_manual_prompt_capture` synchronously when
stdin and stdout are terminals. Each fresh shell starts with an empty manual
snapshot; repeated prompts in that shell reuse it. `compozsh --refresh` clears
it, causing another capture at the next prompt.

The manual peer enumerates up to 4,096 entries. Its formatting fallback uses a
command substitution, a subshell and a `print | mandoc | head` pipeline per
page. Compressed input separately uses `head | gzip | head`. These are repeated
child processes in Compozsh's own first-prompt path, without recursive loading
of the bootstrap. The bounded work still multiplies process-launch and parsing
costs across installed pages. More installed manuals can increase the delay.

A separate instrumented capture observed:

| Native command | Invocations |
| --- | ---: |
| `head` | 207 |
| `mandoc` | 199 |
| `gzip` | 4 |
| `xcode-select` | 1 |
| `mktemp` | 1 |
| `rmdir` | 1 |

These are 413 external-command invocations, excluding Zsh subshells and pipeline
children. Most `head` calls on this host came from formatting, not decompression.
Counts were gathered separately from timing by logging only command basenames
inside a disposable home; no manual contents or private configuration were logged.

A native `zprof` run measured 227.695 ms sourcing plus 3,509.422 ms for manual
capture. It recorded 2,226 page-reader calls, 200 formatter-helper calls (one
declined before launching `mandoc`), and 2,308 retained names. Formatter self
time was 1,387.59 ms; developer-root selection took 635.12 ms. File reads,
parsing and enumeration also contributed, so removing `head` alone would not
remove this bottleneck.

## First editable prompt measurements

Environment: arm64 Mac, macOS 27.0, Apple Zsh 5.9
(`arm64-apple-darwin26.0`). All trials used the same immutable baseline archive,
a new disposable HOME/ZDOTDIR/TMPDIR, system-only PATH, `en_US.UTF-8`,
`xterm-256color`, and `ZSH_LOCAL_INIT=/dev/null`. The working directory was the
disposable home, outside Git. No private initializer, peers or history were
accessed. Filesystem caches were not flushed; native completion state was fresh
in every home. No test suite ran concurrently with these six samples.

A native `zsh/zpty` driver started `/bin/zsh -dfi`, sourced the baseline bootstrap,
then signaled the last line-init hook over a separate FIFO. The clock began just
before sourcing. This measures shell readiness, not Terminal.app launch, login
profiles, window animation or pixel presentation. A diagnostic variant replaced
only `_manual_prompt_capture` with a no-op after sourcing and before `precmd`.
Both variants retained all other peers and normal prompt/editor hooks.

| Sample order | Variant | Source (ms) | Editable prompt (ms) | Manual names |
| --- | --- | ---: | ---: | ---: |
| 1 | Baseline | 230.299 | 3817.642 | 2308 |
| 2 | Manual capture bypassed | 221.389 | 236.874 | 0 |
| 3 | Manual capture bypassed | 218.978 | 234.086 | 0 |
| 4 | Baseline | 216.476 | 3597.851 | 2308 |
| 5 | Baseline | 224.111 | 3736.144 | 2308 |
| 6 | Manual capture bypassed | 223.029 | 238.552 | 0 |

Median readiness fell from 3,736.144 to 236.874 ms: 3,499.270 ms, or 93.66%.
Ranges were 3,597.851–3,817.642 ms and 234.086–238.552 ms respectively.
This establishes a Compozsh bottleneck on the measured host and matches the
reported process signature. It does not establish the exact work-Mac delay or
exclude additional costs in that machine's login profiles or initializer.

The earlier [critical-path performance pass](critical-path-performance.md)
already recorded manual capture as the largest remaining startup cost. Its
optimization preserved the eager scope; the current measurements confirm that
the remaining cost warrants a product decision.

## Repeating the capture measurement

From a reviewed clone, run this with native Zsh. The explicit source path and
disposable configuration base exclude the operator's private configuration.
This narrower measurement isolates sourcing and manual capture; it does not
replace the PTY endpoint used above.

```zsh
repo=$PWD
bench_home=$(mktemp -d /tmp/compozsh-startup-home.XXXXXXXX) || exit 1
{
  env -i HOME="$bench_home" ZDOTDIR="$bench_home" TMPDIR="$bench_home" \
    PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=xterm-256color LC_ALL=en_US.UTF-8 \
    ZSH_LOCAL_INIT=/dev/null /bin/zsh -dfi -c '
      cd -q -- "$HOME"
      zmodload zsh/datetime
      local -F started=$EPOCHREALTIME loaded=0 captured=0
      source "$1/.zshrc"
      loaded=$EPOCHREALTIME
      _manual_prompt_capture
      captured=$EPOCHREALTIME
      printf "source_ms=%.3f manual_ms=%.3f names=%d\n" \
        "$(( (loaded-started)*1000 ))" "$(( (captured-loaded)*1000 ))" \
        "${#_MANUAL_SUMMARIES}"
    ' startup "$repo"
} always {
  [[ -d $bench_home && ${bench_home:t} == compozsh-startup-home.* ]] &&
    rm -rf -- "$bench_home"
}
```

## Accepted cache design and alternatives

The first prototype serialized the complete manual catalog and fingerprints of
its discovery selectors. The user's stricter privacy requirement rejected that
scope: MANPATH can name private documentation, and hashing private selectors
still persists derived private information. The implemented design caches only
public OS page descriptions and simple aliases with protected-source provenance.
Custom and developer manuals and final catalog composition remain in memory.

The cache is optional and independent of peer loading order. It lives only under
the configuration base's `.zsh.addons/support/cache/`, with owner-matching
`.zsh.manual.cache`, `.zsh.manual.lock` and staging names. Loader and installer
exclude inert cache files. Live root/section/page discovery preserves precedence,
observes additions/removals, and avoids permanent negative cache entries. Warm
readers do not lock unless publishing additions. The full contract, bounds,
invalidation and failure behavior live in
[system manual descriptions](../engineering/manual-cache.md).

This first increment preserved features but still blocked cold startup and live
discovery. Persistent caching reduced repeated work; subsequent worker lifecycle
and delivery changes are recorded in [the concurrency investigation](manual-concurrency.md).

## Final cache measurements

Same host, OS, shell, isolated environment and last-line-init endpoint as above.
Each trial used a new home and fresh native completion state. For a warm trial,
a separate shell first built only the manual cache in that disposable home.
No suite ran concurrently. Filesystem caches were not flushed. Compare this
alternating batch internally; the lower baseline than the earlier batch shows
why historical timings must not be treated as a fixed threshold.

| Order | Variant | Source (ms) | Editable prompt (ms) |
| --- | --- | ---: | ---: |
| 1 | Baseline | 202.807 | 3173.542 |
| 2 | Cold cache | 202.382 | 3569.084 |
| 3 | Warm cache | 201.465 | 875.605 |
| 4 | Warm cache | 202.529 | 872.865 |
| 5 | Baseline | 202.867 | 3178.471 |
| 6 | Cold cache | 201.358 | 3432.159 |
| 7 | Cold cache | 202.318 | 3458.090 |
| 8 | Warm cache | 202.857 | 871.409 |
| 9 | Baseline | 201.382 | 3179.965 |

Median baseline **3178.471 ms**, cold **3458.090 ms**, warm **872.865 ms**.
Warm saves **2305.606 ms (72.54%)**, about **3.64× faster**. Cold adds
**279.619 ms (8.80%)** for public-source validation, key/serialization and
publication. Ranges: baseline 3173.542–3179.965, cold 3432.159–3569.084,
warm 871.409–875.605 ms. This cold cost motivates background collection.

Both cold and warm retained **2308 names** and **1898 public cache records**.
An independent in-memory comparison verified every complete description and
page-name/section attribution against the immutable baseline in both states;
counts alone were not used to claim parity. No raw catalog was logged.

Reproduce with [first-editable-prompt.zsh](benchmarks/first-editable-prompt.zsh)
and [manual-cache-parity.zsh](benchmarks/manual-cache-parity.zsh). The former
creates/removes its own disposable home; pass a reviewed baseline clone or the
candidate clone and `baseline`, `cold` or `warm`. The parity script requires an
explicit disposable HOME/ZDOTDIR/TMPDIR and system-only PATH, as in the capture
example above. Benchmark scripts are experiments, never bootstrap peers.

## Broader repeated-work audit

| Source | Finding and next decision |
| --- | --- |
| `.zsh.manual` developer-root selection | The baseline profile spent 635 ms in one `xcode-select --show-manpaths`. Selection/custom paths are user information, so do not persist them. Background discovery is a better candidate; measure its lifetime separately. |
| `.zsh.usb` filesystem catalog | `diskutil listFilesystems -plist` at format entry is a possible future system-capability cache, subject to proving provider provenance, installed-extension effects and measurable cost. No cache added. |
| `.zsh.usb` disk capture | Disk identifiers, volume names, attachment and writability are user/live state. Keep transient, with action-time identity checks; never use a persistent target cache. |
| Runtime version support | Already caches per shell/project/environment. Generic tool output and selector paths can contain private information; blanket persistence would violate policy. A future narrowly typed public provider needs its own evidence. |
| `.zsh.xcode` | Toolchain selection, devices, projects, build/test state and logs are contextual/private. Keep transient. Reusable public capability facts are only candidates after a measured, narrowly defined provider contract. |
| `.zsh.help` | Same-source documentation can come from private peers. Existing bounded in-memory snapshots are appropriate. |
| Git/filesystem workspaces | Project facts, recents, paths and previews remain in memory. Existing session snapshots avoid redraw work; persistence is outside the approved policy. |

This is a bounded source review, not a claim that every feature was benchmarked.
The rule change allows measured opportunities; it is not a reason to cache all
system command output indiscriminately.

## Verification and remaining work

Behavioral regressions demonstrated failure before implementation for fresh-shell
reuse, inert bootstrap exclusion, installer exclusion, warm-reader locking,
invalid publication and identity invalidation. Coverage also includes literal
Unicode/aliases, private forwarders/selectors, additions/removals, refresh,
corruption, unsafe/unwritable storage, atomic failure cleanup, concurrency,
ZDOTDIR, both installation layouts and real ZLE edit/resize/unknown fallback.

Final native suite: **882 passed, zero failed, 188434.3 ms**. The first full
run found one missing engineering-document route (881 passed, one failed); the
route was corrected and the full rerun passed. All 14 focused manual-cache
checks also passed after the final macOS-only provenance guard. Native syntax,
isolated double sourcing, normal/reverse/rotated peer ordering, both installer
layouts, cache-data exclusion, security/documentation and whitespace checks
passed. The final SECURITY review documents storage, public provenance, POSIX
mode/ACL limitations, inert data and cleanup; no network/credential capability
was added. Baseline before changes: 866 passed, zero failed, 199516.1 ms.
No work-Mac timing or manual Terminal.app visual acceptance is claimed. These
cache-only results precede the [implemented asynchronous delivery and its separate
verification](manual-concurrency.md#implemented-lifecycle-increment).
