---
name: compozsh-release-draft
description: Draft the next Compozsh GitHub release — tag, title and release notes — by resolving the latest published release and auditing the real implementation, help, tests and docs diff since then. Use when the user asks for release notes, a changelog, the next version number or "draft the next release". Draft-only; never tags, pushes, publishes or signs in.
argument-hint: "[candidate-ref]"
context: fork
agent: read-only-auditor
allowed-tools: WebFetch(domain:github.com) WebFetch(domain:api.github.com)
---

Release candidate, when given: $ARGUMENTS (defaults to committed `HEAD`).

# Draft a Compozsh release

Produce release metadata from verified repository evidence. The user performs
every publication action; this workflow is permanently draft-only.

## Access rules

- Use only public, unauthenticated GitHub reads with WebFetch against
  github.com / api.github.com. Do **not** use `gh`: it
  authenticates as the user. Never request or use credentials, cookies,
  tokens, an authenticated browser session or an account connection.
- Never put local paths, repository contents, credentials or private remote
  parameters into a network request. Redact a credential-bearing remote URL
  instead of displaying or querying it.
- Don't touch the clipboard; if the user wants the draft copied, the main
  session can do it after you hand back the report.

## 1. Establish the published baseline

The canonical repository is `https://github.com/bitbemol/compozsh`; its
authoritative release list is `https://github.com/bitbemol/compozsh/releases`.
Confirm that the sanitized `remote.origin.url` identifies `bitbemol/compozsh`.
A missing or different origin blocks the release unless the user supplies and
verifies the intended checkout. If the canonical URLs have moved, stop and
report the mismatch rather than guessing a replacement.

1. Read the release list and the full page of the latest published, non-draft
   release; resolve its tag to the exact commit. Local tags, `git describe`,
   commit subjects and remembered versions are not sufficient — local tags can
   be stale or incomplete.
2. Record its tag, title, publication date, body and commit. Confirm through
   GitHub that the proposed new tag is unused.
3. If GitHub cannot be read, stop and report an unverified baseline. Continue
   only with complete release metadata and the exact tag commit supplied by the
   user — never substitute the newest local tag.
4. Check `git merge-base --is-ancestor <baseline> <candidate>`. The candidate
   defaults to committed `HEAD`; report a dirty worktree and include
   uncommitted changes only when the user puts them in scope.

## 2. Audit what actually changed

Using [CLAUDE.md](../../../CLAUDE.md) (already in context), read [security](../../../engineering/security.md),
[verification](../../../engineering/verification.md),
[Zsh conventions](../../../engineering/zsh.md) and the domain contracts CLAUDE.md
routes to for the affected areas. Then inspect the whole `baseline..candidate`
range: commit log and bodies, diff stat and name/status, final diffs of every
changed implementation file, baseline versions where needed to prove novelty,
current `--help`, README, SECURITY.md, website and installer text, and the
focused regression tests behind each claim.

Commit messages are navigation aids, not evidence. Describe the final candidate
state; ignore intermediate features that were later removed, narrowed or turned
into refusals. Keep a private evidence record per claim:

```text
Claim: concise user-facing behavior
Baseline: absent, present, or materially different — with evidence
Candidate implementation: exact owning file/function/data mapping
Public contract: matching help and documentation
Tests: focused behavioral coverage and observed result when run
```

Include a claim only when baseline and candidate evidence are both understood:

- Read explicit extension maps, allowlists, dispatchers, validation branches
  and fallbacks. Never infer coverage from what an underlying program (Vim,
  Git, Xcode, `diskutil`) can do.
- Separate new features from existing ones that were merely documented,
  integrated or refined; defaults from optional actions; a passing safety check
  from a guarantee the code does not make.
- State destructive effects, confirmation, privilege, verification, recovery
  and unsupported paths exactly as implemented.
- Treat `--help` output as shipped contract, but verify it against code and
  tests.

If implementation, help, tests, README or SECURITY.md disagree on a material
fact, report the exact conflict as a release blocker. Do not pick a side,
silently fix the prose in the draft, or omit it.

## 3. Check completeness and version

Inventory additions, removals and material changes across: shipped peers and
public commands; entry points, key bindings, defaults and configuration knobs;
requirements, dependencies, fallbacks and supported platforms; installer,
update, migration and uninstall behavior; security, privacy, local-data,
privilege and external trust boundaries; the website and repository skills.
Keep internal hardening subordinate to visible outcomes unless it materially
changes safety, recovery, correctness or responsiveness.

Recommend SemVer by comparing the published public interface with the
candidate: major for an intentional incompatible change, minor for new
backward-compatible capability, patch for fixes only. Diff size never implies a
major version, and never propose a tag that already exists remotely.

## 4. Verify claims

Run `git diff --check` and the focused tests relevant to the notes. Run the
complete native suite (and website suites) only if the notes will claim they
pass or quote counts — a definition count is not a passing count. Record
failures, timeouts, skips and environmental limits exactly; never present a
partial run as verified or reuse counts from an older release.

## 5. Draft

Write direct, user-facing Markdown proportional to the release:

- an opening summary of the largest verified outcomes;
- added behavior and material refinements grouped by task;
- safety or compatibility limitations users need;
- breaking changes and migration only when evidenced;
- update instructions matching both installer layouts;
- a full-changelog link from the verified baseline tag to the proposed tag.

Avoid implementation trivia, commit-by-commit paraphrase, superiority claims
and capabilities inferred from dependencies.

Finish by presenting the tag, title and raw release body as separate blocks
(code fences are wrappers, not part of the text), plus the evidence and any
blockers. Even when asked to "make" or "publish" the release, do not create
tags, releases, commits or pushes, open an authenticated release form, or ask
the user to sign in — hand them the draft to apply.
