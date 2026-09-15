# Performance

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Performance contract](#performance-contract)

## Performance contract

Compozsh runs in every new interactive shell and parts of it run before every
prompt or ZLE redraw. Treat those paths as latency-sensitive.

- Measure latency-sensitive changes instead of assuming they are faster. When
  more than one reasonable design exists, implement or prototype representative
  alternatives, benchmark them under the same realistic workload, and retain
  the most performant option that also preserves correctness, security, and
  maintainability.
- Evaluate alternatives in this order: semantic correctness, safety and
  predictable failure behavior, idiomatic modern Zsh 5.9, measured speed, then
  code size. Reject a faster option if it weakens shell semantics or a security
  boundary; reject a compact option if it is slower or less clear in a hot path.
- Record the relevant before/after measurements in the task handoff. Include
  the workload, distinguish fresh from warm/cache-assisted results, and compare
  several runs so filesystem and process-startup noise do not decide the design.
- Test performance at the scope affected by the change: isolated startup for
  top-level initialization, complete prompt rendering for prompt work, project
  and Git helpers both inside and outside repositories, and redraw latency for
  ZLE work. Microbenchmarks may explain a result but must not replace an
  end-to-end measurement.

- ZLE syntax highlighting and autosuggestions must launch no subprocesses,
  perform no network access, write no files, and avoid unbounded scans.
- A live resize must only recalculate presentation from in-memory facts. It
  must not rerun Git, language tools, or project detection.
- The Context/Interaction derivation and repaint capabilities owned by
  `.zsh.prompt`, including calls from the editor's line-init, pre-redraw,
  line-finish and manual Context adapters, must derive from the current prompt
  snapshot and ZLE state. Those prompt capabilities must launch no subprocess,
  read no filesystem or project metadata, write no file, or make a network
  request. This does not describe every independent ZLE pre-redraw hook: syntax
  highlighting retains its bounded checks of literal path tokens. Ordinary
  `precmd` remains the prompt fact-capture boundary.
- The highlighter may share its existing lone-directory observation with the
  optional Interaction lens, keyed to the exact bounded buffer and current
  folder. Capture the caller's AUTO_CD option before local emulation; normal
  command categories retain precedence. Clear the observation before skipped
  or changed highlighting and never resolve paths again from prompt code.
  Missing/stale observations retain the lexical fallback; this is not a
  CDPATH resolver, provider catalog, or new per-redraw discovery pass.
- Context lens automation is event driven. Do not add a dismissal timer,
  polling loop, worker or background refresh. Its trigger fingerprint contains
  only recognized-project-root or raw-Git-branch appearances and changes, the
  active virtual/Conda environment, Git operation/conflict attention, and
  runtime unknown/missing/unavailable/mismatch attention. Dirty-count-only changes update
  display without reopening the lens.
- Prompt code should minimize external commands and never add a per-prompt
  subprocess when native Zsh state or an existing command result is enough.
- Existing generic runtime/tool version probes retain memory-only caching.
  Cache keys must include every environment selector that can change the
  answer, and `compozsh --refresh` must invalidate the relevant caches.
- Reproducible public system data may use disposable persistent caches under
  the [caching contract](caching.md). Never persist user/project facts or make
  a feature depend on cache availability. Do not add a cache daemon, background
  worker, timer loop or eager startup scan without an explicit architectural
  decision. Zsh's native completion dump is not feature-state storage.
- The approved local manual-summary exception requests one bounded background
  capture from the optional `.zsh.manual` peer at the first TTY `precmd`.
  The prompt returns before discovery/cache I/O. Only complete current-generation
  results reach the editor through bounded native descriptor callbacks; see the
  [lifecycle contract](manual-cache.md#asynchronous-prompt-capture). Source time
  and editor callbacks never discover providers. Resolve at most 64 roots from literal MANPATH, the first 128 absolute
  PATH entries, conventional installations, inert MANPATH/MANCONFIG directives
  (17 configuration files, 8 KiB each), and one native
  `/usr/bin/xcode-select --show-manpaths` query (16 validated paths). Honor empty
  MANPATH fields and the validated MANSECT environment value; prioritize
  sections across roots. Read at most 4,096 entries, 64 KiB per page, 8,192
  retained names and 240 characters per summary. Installed symlinks and literal
  whole-page `.so` forwarders may resolve outside the initial root; cap a chain
  at eight file reads. Use non-following/nonblocking opens on resolved paths
  and regular-descriptor checks. Native gzip may decode bounded compressed
  input. Try the inert NAME parser first; native mandoc may format captured
  stdin from an owned, empty mode-0700 temporary directory, with bounded output
  and a one-second child CPU limit. Remove that empty directory in guaranteed
  cleanup; never write page text to disk or interpret manual configuration as
  shell code. Never invoke man, manpath, whatis, indexes or documented commands.
  Missing/unreadable pages are quiet misses; readable pages without a usable
  NAME description retain an explicit manual-available notice. Reuse eligible
  public OS page descriptions under the [manual cache contract](manual-cache.md).
  Discover roots/sections/pages at capture so additions and removals remain
  visible; custom/developer manuals and final attribution stay in shell memory.
  `compozsh --refresh` clears memory and rebuilds eligible persistent results at
  the next TTY prompt. Typing and resize never perform discovery or cache I/O.
  Measure first editable prompt and complete-description arrival separately from source time and warmed
  redraw; see `investigations/terminal-startup-latency.md` for current evidence.
- Working-changes auto-refresh in the Git review screen is the narrowly approved
  screen-session worker exception. Its ownership, bounds, lifecycle and local-only
  behavior are defined by the [Git review workspace boundary](workspaces/git.md#git-review-workspace-boundary).
- The optional help peer may capture loaded same-source help companions at a
  TTY prompt boundary for command descriptions. Never call a public command's
  `--help` or a help companion while editing. Capture at most 64 command/help
  pairs, with each definition limited to 65,536 characters and the combined
  identity snapshot to 262,144 characters. Read at most 4,096 complete help
  characters per guide (plus one lookahead character); the existing Touch ID
  subguide has a separate read under the same bound. Keep descriptions at most
  240 characters, reject controls, and never accept a truncated final line.
  Cache only in shell memory; changed definitions, removed capabilities and
  `compozsh --refresh` invalidate capture. Source-time setup performs no capture.
  Same-source companions remain trusted static documentation providers, not
  arbitrary executable probes or a sandbox. Preserve standalone fallbacks.
- Do not recursively scan entire repositories. Use bounded upward searches,
  exact marker checks, and shallow conventional source directories.
- Recursive add-on discovery is allowed only inside the shared `.zsh.addons`
  beside the resolved `.zshrc` and the configuration base's user
  `.zsh.addons`. Use one native glob, load regular `.zsh.<name>` files in
  deterministic order for reproducible diagnostics, and do not follow nested
  symlink directories. Never make correctness depend on that order.
- Never execute repository-local wrappers, binaries, manifests, or scripts to
  discover prompt information. Resolve trusted installed tools through `PATH`.
- Bound user-controlled display work and result counts. Preserve the existing
  fuzzy-history maximum and width/height-aware rendering.
- Prefer a small memoization point around a proven repeated cost. Do not cache
  code merely because caching sounds faster.

As a regression target on the reference Mac, isolated startup should normally
remain around the current tens-of-milliseconds range and should not exceed
roughly 50 ms without a measured, justified tradeoff. Compare several runs;
never optimize from a single timing sample.
