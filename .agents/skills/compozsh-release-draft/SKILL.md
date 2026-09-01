---
name: compozsh-release-draft
description: Draft a Compozsh GitHub release tag, title, and notes for the user to publish by resolving the latest published release and auditing the final implementation, help, tests, and documentation diff. Use for release-note, changelog, or next-version requests; never access the user's account, publish, tag, or push.
---

# Draft a Compozsh release

Produce release metadata from verified repository evidence. Work read-only; the
user owns every publication action. Public, unauthenticated GitHub reads are
allowed, but never request or use the user's credentials, authenticated browser
session, cookies, tokens, account connection, or approval to sign in on their
behalf. Copy draft text to the local clipboard only when explicitly requested.

## Establish the published baseline

The canonical public repository is
`https://github.com/bitbemol/compozsh`; its authoritative release list is
`https://github.com/bitbemol/compozsh/releases`. Use those public URLs directly
instead of inferring a repository from an arbitrary local remote. Before
continuing, sanitize `remote.origin.url` and confirm that its owner/repository
identity is `bitbemol/compozsh`. A missing or different origin is a release
blocker unless the user explicitly supplies and verifies the intended checkout.
Never display credentials or private remote parameters while checking it.

1. Read the canonical GitHub releases list and the complete page for the latest
   published, non-draft release. Resolve its tag to the exact commit. A local
   tag list, `git describe`, commit subject, or remembered version is never
   sufficient: local tags can be stale or incomplete.
2. Record the release tag, title, publication date, body, and commit before
   choosing the next version. Confirm through GitHub that the proposed tag is
   unused.
3. If GitHub cannot be read, stop and report that the release baseline is
   unverified. Continue only when the user supplies the complete published
   release metadata and exact tag commit. Never substitute the newest local tag.
4. Confirm the baseline commit is available and is an ancestor of the release
   candidate with `git merge-base --is-ancestor`. Default the candidate to
   committed `HEAD`. Report a dirty worktree; do not include uncommitted changes
   unless the user explicitly puts them in release scope.

Use public GitHub data only. Do not put local paths, repository contents,
credentials, or private remote parameters into a network request. Redact a
credential-bearing remote URL rather than displaying or querying it. If the
canonical public URLs move, stop and report the mismatch instead of guessing a
replacement repository from local configuration.

## Audit what actually changed

Read the repository `AGENTS.md` release, security, documentation, testing, and
public-interface contracts. Then inspect the complete `baseline..candidate`
range:

- chronological commit log and commit bodies;
- diff statistics and name/status inventory;
- final diffs for every changed implementation file;
- the baseline version of a file when needed to prove that behavior is new;
- current public `--help`, README, `SECURITY.md`, website, and installer text;
- focused regression tests for each claimed capability or boundary.

Commit messages are navigation aids, not release evidence. Describe the final
candidate state. Ignore an intermediate feature that was later removed,
reversed, narrowed, or converted into a refusal path.

Build a private evidence record for every prospective release claim:

```text
Claim: concise user-facing behavior
Baseline: absent, present, or materially different—with evidence
Candidate implementation: exact owning file/function/data mapping
Public contract: matching help and documentation
Tests: focused behavioral coverage and observed result when run
```

Do not include a claim until its baseline and candidate evidence are both
understood. In particular:

- Read explicit extension maps, allowlists, dispatchers, validation branches,
  and fallbacks. Never infer coverage from the capabilities of an underlying
  program such as Vim, Git, Xcode, or `diskutil`.
- Distinguish a newly added feature from a pre-existing feature that was merely
  documented, integrated, or refined in the range.
- Distinguish defaults from optional actions and a successful safety check from
  a guarantee the implementation does not make.
- State destructive effects, confirmation, privilege, verification, recovery,
  and unsupported paths exactly as implemented.
- Treat output from public help as a shipped contract, but verify it against the
  implementation and tests rather than assuming it is current.

If implementation, help, tests, README, or `SECURITY.md` disagree on a material
fact, flag the exact conflict as a release blocker. Do not silently select one
value, repair the prose in the draft, or omit the contradiction without telling
the user.

## Check completeness and versioning

Inventory additions, removals, and material changes across:

- shipped peers and public commands;
- entry points, key bindings, defaults, and configuration knobs;
- requirements, dependencies, fallbacks, and supported platforms;
- installer, update, migration, and uninstall behavior;
- security, privacy, local-data, privilege, and external trust boundaries;
- website and repository-scoped agent workflows.

Keep internal hardening subordinate to visible outcomes, but include it when it
materially changes safety, recovery, correctness, or responsiveness.

Recommend SemVer only after comparing the latest published public interface
with the candidate:

- major for an intentional incompatible public-interface change;
- minor for backward-compatible user-facing capabilities;
- patch for backward-compatible fixes without new public capability.

Do not infer a major version from the size of the diff. Do not propose a tag
that already exists remotely.

## Verify claims

Run `git diff --check` and focused tests relevant to the notes when practical.
Run the complete native and website suites when the release body will claim
they pass or quote passing counts. A definition count is not a passing count.

Record failures, timeouts, interruptions, skipped checks, and environmental
limits exactly. Never describe a partial or interrupted run as verified, and
never reuse counts from an older release.

## Draft the GitHub release

Write direct user-facing Markdown proportional to the release. Include:

- an opening summary grounded in the largest verified outcomes;
- added behavior and material refinements grouped by task;
- exact safety or compatibility limitations where users need them;
- breaking changes and migration only when the evidence shows them;
- update instructions synchronized with the supported installer layouts;
- a full changelog link from the verified baseline tag to the proposed tag.

Avoid implementation trivia, exhaustive commit paraphrases, unsupported
superiority claims, and capabilities inferred from dependencies. Describe only
behavior shipped at the candidate commit.

When requested, output separate tag, title, and release-body blocks. Code fences
are presentation wrappers and must not be included in text copied to GitHub.
Copy raw Markdown to the clipboard only after explicit authorization, and do
not read the existing clipboard contents.

This workflow is permanently draft-only. The user will create any Git tag and
GitHub release and perform any commit, push, deployment, or publication. Do not
open an authenticated release form, ask the user to sign in, or attempt those
actions on the user's behalf, even when a request says to make or publish the
release. Finish by presenting the verified tag, title, raw release body,
evidence, and blockers for the user to apply themselves.
