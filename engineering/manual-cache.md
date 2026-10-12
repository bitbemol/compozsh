# System manual descriptions

How `.zsh.manual` discovers manual NAME descriptions for the prompt's ABOUT
row, captures them off the critical path, and caches the public OS subset. It
is the first producer under [optional performance caches](caching.md).
Measurements, alternatives and remaining opportunities are in the
[startup investigation](../investigations/terminal-startup-latency.md) and
[manual concurrency](../investigations/manual-concurrency.md).

## Essentials

- **Never on the critical path.** Source time does no discovery or cache I/O;
  the first editable prompt never waits for capture; typing, lookup and resize
  read memory only.
- **Only public OS data persists.** Pages under `/usr/share/man` with
  root-owned provenance may be cached; custom, Homebrew, developer and SDK
  manuals and every discovery selector stay in shell memory.
- **Manual text is inert.** It is never sourced, evaluated or interpreted as
  shell code; `man`, `manpath`, `whatis` and documented commands are never
  invoked.
- **Complete or nothing.** Only a complete, validated, current-generation
  snapshot is published; anything else keeps the fallback.

## Discovery

Each capture discovers roots, sections and pages fresh, so additions and
removals stay visible.

- Resolve at most 64 roots from literal `MANPATH`, the first 128 absolute
  `PATH` entries, conventional installations, inert `MANPATH`/`MANCONFIG`
  directives (17 configuration files, 8 KiB each), and one native
  `/usr/bin/xcode-select --show-manpaths` query (16 validated paths). Honor
  empty `MANPATH` fields and the validated `MANSECT` value; prioritize
  sections across roots.
- Read at most 4,096 entries, 64 KiB per page, 8,192 retained names and 240
  characters per summary. Installed symlinks and literal whole-page `.so`
  forwarders may resolve outside the initial root, capped at eight file reads
  per chain. Use non-following, nonblocking opens on resolved paths and
  regular-descriptor checks.
- Native gzip may decode bounded compressed input. Try the inert NAME parser
  first; native mandoc may format captured stdin from an owned, empty
  mode-0700 temporary directory, with bounded output and a one-second child
  CPU limit. Remove that directory in guaranteed cleanup and never write page
  text to disk.
- Missing or unreadable pages are quiet misses; readable pages without a
  usable NAME keep an explicit manual-available notice.

## Asynchronous prompt capture

One shell-owned capture worker runs the existing ordered collector, which
preserves section/root/page/alias precedence. A parallel worker pool is a
separate, measured increment.

- At a TTY prompt, request capture and return with the existing fallback.
  Publish a complete validated snapshot when it's ready; never partially
  replace a catalog or interpret worker output as shell code.
- Keep a monotonic request generation plus a bounded in-memory discovery
  identity (`PATH`, `MANPATH`, `MANSECT`, locale, developer selectors,
  configuration base, and working directory only for relative manual roots),
  and check both before accepting results. Never persist those selectors or
  their hashes.
- A new selector identity, explicit refresh or re-source cancels in-flight
  work; a foreground command cancels pending capture and the next prompt may
  restart it. Completed catalogs stay until invalidated. No retry loop: a
  failed request keeps the fallback until refresh or identity change.
- Transport uses native Zsh-owned processes and a bounded kernel channel,
  never regular files of manual data; transport names are removed after the
  inherited descriptors open. Each editor callback reads at most 8 KiB;
  retained transport data is bounded to 16 MiB and 8,192 complete records.
- A frame carries schema, generation, count and completion; also require the
  worker's success notification and no remaining queued bytes. Reject
  malformed, duplicate, truncated, oversized, stale or failed frames without
  publishing any field. Preserve literal Unicode and exact serial attribution.
- Candidate maps are private to the producer. Publication selects the
  complete validated map in place without copying the catalog in a callback;
  lookup returns one description/source pair. Cancellation keeps a published
  snapshot; refresh and selector invalidation discard it at the next capture
  boundary. Split each received chunk natively rather than rescanning its
  suffix with wildcards.
- Process ownership covers formatter and discovery descendants. Two native
  supervisors own one capture: the outer holds a native `zpty` identity, the
  inner owns the capture process group. Delete each native handle before
  terminating its owner. Cancellation, shell exit and a 30-second deadline
  stop capture — no daemon, retry timer or polling; after a deadline an idle
  outer owner keeps its identity until
  the parent handles failure, so a suspended editor can't later signal a stale
  PID. Normal cancellation allows up to 100 ms of cleanup; forced interruption
  may leave the disclosed empty formatter directory or public staging residue,
  never private document files.
- Both descriptors use native ZLE widget handlers (plain FD callbacks don't
  expose the draft). Delivery paints only in the ordinary top-level editor; a
  nested editor or full-screen view keeps display ownership and completed data
  waits for the ordinary prompt. Preserve draft, cursor, undo and highlights,
  prompt disclosure, caller statuses, user jobs, coprocesses and unrelated FD
  handlers. Invoke the optional editor presentation adapter before requesting
  redisplay — `zle -R` alone doesn't run line-pre-redraw hooks.
- Missing async capabilities fall back to complete synchronous capture;
  missing or unwritable persistent cache still uses background uncached
  capture. Redirected or noninteractive startup never captures automatically.

## Persistent public results

- `.zsh.manual` owns `.zsh.manual.cache` under
  `${ZDOTDIR:-$HOME}/.zsh.addons/support/cache` for both installation layouts
  and standalone sourcing — never the source peer's directory or the project.
- Cache hits skip OS page reads, decompression and formatting. Other manuals
  keep the full uncached in-memory path.
- Eligibility: only pages discovered under `/usr/share/man`, where every
  resolved regular descriptor in a symlink/`.so` chain stays in that protected
  tree, is root-owned and lacks group/world write permission. Apple's OS
  protection is the provenance assumption; installation paths and ownership
  elsewhere don't establish public data. Persistent capture is macOS-only and
  requires readable OS-version metadata.
- Store system-relative page IDs, simple NAME aliases and bounded
  descriptions. Never persist document bodies, discovery selectors, private
  attribution, custom manuals, user paths, arbitrary environment values or
  fingerprints of them.
- Identity: format version, SHA-256 of the loaded owning implementation, Zsh
  version, an accepted installed system locale and fixed OS-version-file
  metadata. The hash command runs with an empty environment and a fixed system
  `PATH`; the digest is an invalidation key, not authentication.
- Live discovery applies `MANPATH`/`MANSECT` precedence on each capture; new
  pages extend the cache, removed pages are no longer offered, no negative
  lookups persist. An open shell keeps its snapshot until `compozsh --refresh`
  or an in-memory selector change. Source, locale or OS identity changes
  invalidate persistent results; in-place OS manual replacement without an
  OS-version change needs an explicit refresh.
- `compozsh --refresh` clears this shell's maps and requests fresh capture at
  its next TTY prompt, replacing eligible persistent results for future
  shells; other open shells keep theirs until their own refresh.
- Missing, stale, malformed, unsafe or unwritable storage keeps full uncached
  behavior. Deleting the cache directory is supported. Never repair unsafe
  existing state or fail startup when caching is unavailable.

## Storage and concurrency

- Inert format: version line, key, count, tab-separated records and an END
  sentinel. At most 4,096 records and 32 MiB; page IDs at most 512 characters,
  descriptions 240, and at most 16 simple aliases of 255 characters. Reject
  malformed fields, controls, NUL, duplicates, truncation, excess bytes and
  incompatible identities before committing any loaded map.
- Validate configuration-base ownership and non-writable-by-others ancestors
  from that base through `support/cache`. Directories and files use owner-only
  POSIX modes; files are regular, singly linked and not symlinks. Extended
  ACLs are not inspected or removed — document that limit. Descriptor checks
  complement non-following, nonblocking opens; they don't sandbox races
  against another process of the same account or writable ancestors above the
  configuration base.
- Publish complete files by same-directory atomic rename. Native kernel
  advisory locks on `.zsh.manual.lock` coordinate first builders and
  publication, rechecking after waiting; warm readers lock only to add
  results. Lock acquisition is bounded to ten seconds; failure falls back to
  capture without publication. Handled failures remove owned
  `.zsh.manual.cache.*` staging files; uncatchable interruption can leave an
  owner-only staging file. A leftover empty lock file is harmless.
- Git ignores the directory, bootstrap never sources it, installs never copy
  generated caches, normal updates preserve them and `--clean` archives them.
  One current snapshot is kept until refresh, invalidation or removal; removed
  public entries may linger until replacement, within the record cap.

## Verification

Use disposable homes and manuals with an explicit test-only public provider.
Establish red/green coverage for: real ZLE coverage forbidding provider calls
during editing and resize, the frame contract, no partial publication,
stale generations and selectors, cancellation with a live provider,
refresh/re-source/exit cleanup, no user-job or coprocess interference, real
ZLE typing/resize/full-screen ownership, exact serial parity, cross-shell
reuse, literal descriptions and aliases, additions and removals, private-data
exclusion, precedence, refresh and identity changes, inert corruption, unsafe
or unwritable storage, atomic failure cleanup and concurrent first builders.
Measure cold construction, first editable prompt and complete-description
arrival separately for cold and warm states, with fresh completion state and
no private configuration. Record Terminal.app acceptance separately from PTY
evidence. README and SECURITY own public usage and trust disclosure.
