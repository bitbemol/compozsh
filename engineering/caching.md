# Optional performance caches

Persistent caching is allowed for measured repeated work on reproducible public
system data.

## Essentials

- **An optimization, never a source of truth.** Every feature works fully with
  the cache missing, stale, corrupt or unwritable.
- **Public data only.** Never persist user or project information or
  fingerprints of it; each producer documents the public provenance of every
  field.
- **No new machinery.** No cache manager, daemon, polling, registry, load
  phase or per-project cache; no cache I/O at source time or while typing or
  resizing. The manual producer's bounded asynchronous capture is the only
  background work a cache producer may do (other approved background work is
  listed in [performance](performance.md#approved-background-work)).
- **Workspace snapshots are not caches.** Listings, search results and other
  user or project facts are never written to disk; any shell-memory retention
  is limited to what SECURITY.md's data inventory discloses.
- **Disclosed.** Contents, location, retention and removal are documented in
  README and SECURITY.

## Eligibility and ownership

- Each producer documents the public provenance of every persisted field.
  A conventional installation path, root ownership, a hash, encryption or the
  word “stateless” alone does not make information public.
- Never persist user or project information: private manuals, paths, selections,
  arbitrary environment values, identifiers, credentials, history, drafts, logs, repository
  facts or fingerprints of those inputs. Existing history,
  [completion](../SECURITY.md#native-completion-dump) and recovery storage
  retain their own separately documented purposes.
- Keep all performance cache files under
  `${ZDOTDIR:-$HOME}/.zsh.addons/support/cache`, independent of installation
  layout and current directory. The owning `.zsh.<module>` uses
  `.zsh.<module>.cache`; lock and staging names retain the same module prefix.
  Do not create per-project caches or an additional cache home.
- The owner contains its capture, validation and cleanup policy. There is no
  mandatory cache manager, registry, initialization phase or load-order edge.
  Source-time setup and typing/resize remain free of cache I/O.

## Freshness and responsive interaction

- Separate live discovery from reusable derived results. Additions and removals
  must be observed at the documented capture boundary; a cache cannot freeze
  the available-tool catalog. Do not persist negative lookups indefinitely.
- Match a schema version and the relevant public source/implementation identity.
  Each producer documents what changes invalidate its results and what requires
  explicit refresh. There is no universal TTL that proves freshness.
- On a miss or invalidation, compute at a bounded capture boundary and publish
  eligible successful results. Unknown input during editing is an immediate
  fallback, never a synchronous scan, formatter, executable probe or disk write.
- `compozsh --refresh` must invalidate participating shell-memory results and
  request fresh capture. Already open shells keep their snapshots until their
  own refresh. Do not introduce a daemon or polling timer. The manual producer's
  [bounded asynchronous capture](manual-cache.md#asynchronous-prompt-capture)
  is an explicit exception, with its own cancellation and stale-result contract.
- Cached descriptions are advisory. Revalidate mutable identities and targets
  before an action; cached device IDs, authorization or project state must never
  authorize an action.

## Storage and failure behavior

- Missing, stale, malformed, unsafe or unwritable storage preserves the complete
  uncached feature. Deleting the cache directory is supported; recreate it when
  eligible capture next needs storage. Do not repair unsafe existing permissions.
- Specify finite record/byte bounds, inert serialization, complete validation,
  restrictive file modes, directory ownership, symlink/special-file refusal, atomic
  publication and bounded concurrent-writer coordination. Cache data is never
  shell source. Document crash residue and the limits of filesystem checks.
- Bootstrap discovery excludes the reserved cache directory. Git ignores it;
  installers exclude source caches, preserve destination caches during normal
  updates and archive them with the add-on tree during `--clean`.
- Document exact contents, location, retention and removal in README/SECURITY.
  No Compozsh-owned transmission or external cache service is allowed.

## Acceptance

Demonstrate red/green coverage for reuse, additions/removals, refresh,
invalidation, privacy, inert data, corruption, storage refusal, cleanup and
concurrency. Verify standalone/re-source behavior and both installation layouts.
Measure the actual user-visible endpoint across repeated cold and warm runs;
include validation/discovery overhead, not just skipped computation.

The first producer is [system manual descriptions](manual-cache.md). Other
providers require their own measured need, provenance and freshness contract;
this policy does not automatically authorize persistence of generic tool output.
