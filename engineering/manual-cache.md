# System manual description cache

This producer follows [optional performance caches](caching.md). It preserves
manual-derived ABOUT descriptions while avoiding repeated parsing and formatting
of Apple's public OS manuals across shells. Asynchronous capture also removes
that collection work from the wait before editing.

## Behavior and acceptance criteria

### Asynchronous prompt capture

The September 15 follow-up authorizes asynchronous capture and its lifecycle.
Use one shell-owned capture worker using the existing ordered
collector. This preserves section/root/page/alias precedence without introducing
parallel merge semantics prematurely. A worker pool remains a separate measured
increment; the first prompt must no longer wait for discovery or cache I/O.

- At a TTY prompt, request capture and return with the existing description
  fallback. Publish a complete validated snapshot when ready. The parent never
  partially replaces a catalog or interprets worker output as shell code.
- Keep a monotonic request generation plus bounded in-memory discovery identity
  (PATH, MANPATH, MANSECT, locale, developer selectors, configuration base and
  working directory only for relative manual roots). Check both before
  accepting results. Never persist those private selectors or their hashes.
- A new selector identity, explicit refresh or re-source cancels in-flight work.
  Before a foreground command, cancel pending capture; the next prompt can
  restart it. Completed catalogs remain available until invalidated. No retry
  loop: a failed request retains fallback until refresh/identity change.
- Use native Zsh-owned processes and a bounded kernel transport, never regular
  files containing custom manual data. Remove transport filesystem names after
  opening inherited descriptors. Limit each editor callback to one 8-KiB read;
  bound retained transport data to 16 MiB and 8,192 complete records.
- A frame identifies schema, generation, count and completion. Also require the
  worker's successful completion notification and no remaining queued bytes.
  Reject malformed,
  duplicate, truncated, oversized, stale or failed frames without publishing any
  of their fields. Preserve literal Unicode and exact serial attribution.
- Keep candidate maps private to the producer. Publication selects the complete
  validated map in place; it must not copy the whole catalog in an editor callback.
  Lookup returns one matching description/source pair from the selected catalog.
  Cancellation retains a published snapshot; refresh and selector invalidation
  discard it at the next capture boundary. Native literal splitting processes
  each received chunk; avoid repeated wildcard scans over its remaining suffix.
- Process ownership includes formatter/discovery descendants. Two native Zsh
  supervisors own one capture process: the outer owner holds a native `zpty`
  identity; the inner supervisor owns the capture process group. Delete each
  native handle before terminating its owner. Cancellation, shell exit and a
  30-second request deadline stop capture. After a deadline, an idle outer owner
  retains its identity until the parent handles failure; a suspended editor
  cannot cause a stale process ID to be signaled later. No daemon or polling.
  Normal cancellation gives capture up to 100 ms of cleanup opportunity;
  forced interruption can retain the already disclosed empty formatter directory
  or public cache staging residue. It must not retain private document files.
- Both descriptors use native ZLE widget handlers; plain FD callbacks do not
  expose the draft. Descriptor delivery may only paint in the ordinary top-level editor. A nested
  editor/fullscreen view keeps display ownership; completed data may be retained
  for the ordinary prompt. Preserve draft, cursor, undo/highlights, prompt
  disclosure, caller statuses, user jobs, coprocesses and unrelated FD handlers.
  Invoke the optional editor presentation adapter before requesting redisplay;
  `zle -R` alone does not run line-pre-redraw hooks.
- Missing async capabilities retain the complete synchronous capture fallback;
  missing/unwritable persistent cache still uses full background uncached capture.
  Redirected/noninteractive startup remains free of automatic capture.

Tests must establish red/green evidence for the frame contract, no partial
publication, stale generations/selectors, cancellation with a live provider,
refresh/re-source/exit cleanup, no user-job/coprocess interference, real ZLE
typing/resize/fullscreen ownership and exact serial parity. Measure first
editable prompt and complete-description arrival separately for cold and warm
cache states. Record Terminal.app acceptance independently of PTY evidence.

### Persistent public results

- `.zsh.manual` owns `.zsh.manual.cache` under
  `${ZDOTDIR:-$HOME}/.zsh.addons/support/cache`. Both installation layouts and
  standalone sourcing use this configuration-base location, never the source
  peer's directory or current project.
- Source time performs no cache I/O. The first TTY prompt requests a background
  worker that loads eligible public descriptions and performs bounded discovery.
  Cache hits skip OS page reads, decompression and formatting. Custom, Homebrew,
  developer and selected SDK pages retain their full uncached in-memory path.
  Typing, lookup and resize consult memory only, including unknown commands.
- Only pages discovered under `/usr/share/man` are eligible. Every resolved
  regular descriptor in a symlink/whole-page `.so` chain must stay under that
  protected OS tree, be root-owned and lack group/world write permission.
  Apple's OS protection is the provenance assumption; ordinary installation
  paths and ownership alone do not establish public data elsewhere.
  Persistent capture is macOS-only and requires readable OS-version metadata;
  other platforms retain full uncached manual behavior.
- Store system-relative page IDs, simple NAME aliases and bounded descriptions.
  Never persist document bodies, discovery selectors, private attribution,
  custom manuals, user paths, arbitrary environment values or fingerprints of them.
- Match format version and SHA-256 identity of the loaded owning implementation,
  Zsh version, an accepted installed system locale and fixed OS-version-file
  metadata. The native hash command runs with an empty environment plus a
  fixed system PATH. The digest is an invalidation key, not authentication.
- Live discovery applies MANPATH and MANSECT precedence on each new capture.
  Added pages are parsed and eligible results extend the cache; removed pages
  are no longer offered. No negative lookup is persisted. An existing shell
  retains its snapshot until `compozsh --refresh` or an in-memory discovery
  selector change. New files or changed system selection outside the shell
  require refresh in an already-open shell. Source/locale/OS
  identity changes invalidate persistent results; unusual in-place OS manual
  replacement without an OS-version-file change requires explicit refresh.
- `compozsh --refresh` clears this shell's maps and requests a fresh capture at
  its next TTY prompt, replacing eligible persistent results for future shells.
  Other already-open shells retain their snapshots until their own refresh.
- Missing, stale, malformed, unsafe or unwritable storage retains full uncached
  behavior. Deleting the cache directory is supported. Do not repair unsafe
  existing state or fail shell startup when caching is unavailable.

## Storage and concurrency

The inert format contains a version line, key, count, tab-separated records and
an END sentinel. Limit it to 4,096 records and 32 MiB; page IDs are at most 512
characters, descriptions at most 240, and at most 16 simple aliases of 255
characters each. Reject malformed fields, controls, NUL, duplicates, truncation,
excess bytes and incompatible identities before committing any loaded map.
Never source or evaluate cache text. Existing capture bounds remain unchanged.

Validate configuration-base ownership and non-writable-by-others ancestors from
that base through add-ons/support/cache. Cache directories/files use owner-only
POSIX modes; files are regular, singly linked and not symlinks. Extended ACLs
are not inspected or removed; document that access-control limit. Descriptor checks
complement non-following/nonblocking opens. These checks do not sandbox races
against another process controlling the same account or writable ancestors above
the configuration base. Owner-controlled cache prose remains advisory/inert.

Publish complete files through same-directory atomic rename. Native kernel
advisory locks on `.zsh.manual.lock` coordinate first builders and publication;
recheck after waiting. Warm readers do not lock unless they add eligible results.
Bound lock acquisition to ten seconds; failure or timeout falls back to capture
without publication. Process exit releases the kernel lock. Handled failures
remove owned `.zsh.manual.cache.*` staging files; uncatchable interruption can
leave an owner-only staging file. A remaining empty lock file is harmless.

Git ignores this directory, bootstrap never sources it, and installation never
copies generated source caches. Normal updates preserve destination caches;
`--clean` archives them with the previous add-on tree. Retain one current
snapshot until refresh, invalidation/replacement or explicit removal. Removed
public entries may remain on disk until that replacement, within the record cap.

## Verification

Use disposable homes and manuals with an explicit test-only public provider.
Test cross-shell reuse, literal descriptions/aliases, additions/removals,
private-data exclusion, precedence, refresh/identity changes, inert corruption,
unsafe/unwritable storage, atomic failure cleanup and concurrent first builders.
Preserve real ZLE coverage forbidding provider calls during editing and resize.
Measure cold construction and warm first-editable-prompt latency separately,
with fresh native completion state and no private configuration.

[README](../README.md) and [SECURITY](../SECURITY.md) own public usage and trust
disclosure. The [startup investigation](../investigations/terminal-startup-latency.md)
retains measurements, alternatives, limitations and remaining opportunities.
