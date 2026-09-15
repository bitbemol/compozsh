# Glossary

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Domain glossary](#domain-glossary)

## Domain glossary

Use these canonical terms in designs, comments, tests, reviews and documentation.
Definitions establish meaning; the later contracts specify behavior and limits.
Qualify overloaded words such as source, state and session when ambiguity is
possible. User-facing labels may use simpler language while preserving meaning.

### Configuration boundaries

| Term | Meaning in Compozsh |
| --- | --- |
| Bootstrap | The minimal `.zshrc` entry that loads the optional initializer and discovers peer add-ons. |
| Initializer | The optional machine-local `local/init.zsh` file that establishes prerequisites before peers load. |
| Peer / add-on | One focused `.zsh.<name>` unit, enabled by its filename and independently sourceable. These two terms are synonyms. |
| Repository-managed configuration | Shared product files updated as a unit; personal edits belong in the machine-local space. “Immutable” describes this ownership convention, not enforced filesystem permissions. |
| Machine-local configuration | The user's private initializer and peers beneath the configuration base. Updates preserve this customization space. |
| Composition | Combining focused peers or runtime capabilities into a larger system. The [peer configuration algebra](architecture.md#peer-configuration-algebra) governs setup; runtime composition preserves the input and effect dependencies of each operation. |
| Order independence | Loading the same enabled peers in any order converges on the same configured behavior under the same prerequisites. Runtime interaction steps can still have dependencies. |

“Configuration base” retains its exact path definition in
[Repository boundaries](repository-layout.md#repository-boundaries). Use **peer** for the unit; qualify its ownership as shared or
private. Avoid inventing a privileged core tier through new terminology.

### Task and interaction boundaries

| Term | Meaning in Compozsh |
| --- | --- |
| Context | The source, scope and user intent that give an operation meaning. |
| Scope | The explicit boundary within which an operation works: a folder root, one repository, or the current shell's retained history. Scope does not guarantee exhaustive coverage. |
| Source | The origin of task facts: filesystem entries, Git metadata, Spotlight's index, the native directory stack, or loaded function metadata. |
| Tool | A user-facing task capability, reached through a command or widget; it can use several views and peer units. |
| Task workspace | Related views composed around a task. A shared renderer or screen session can also host explicitly labeled navigation to a different task context. |
| Entry point | The command or key gesture that establishes the initial context, such as path + Tab or the prompt shortcut for Recents. |
| Living prompt | The ordinary ZLE prompt system whose Context lens, Interaction lens and transcript presentations respond to captured shell/project state and the editing lifecycle. It does not describe a background monitor. |
| Context lens | Temporary expanded disclosure of the living prompt's current captured facts. It is prompt presentation, not an independent View, provider capture or input loop. |
| Interaction lens | The living prompt's active edit-time disclosure. `READY` presents the current captured context while the buffer is empty; operation-specific presentations derive bounded structural excerpts from the literal buffer and combine them with captured facts. It performs no action and is not an independent View, command validator or provider boundary. |
| Draft inspector | An explicitly opened task workspace over a bounded literal copy of the current draft and its cursor/folder context. Option-Return opens reading and labeled tool navigation; it is separate from the automatic Interaction lens and never executes or validates the draft. |
| Command composer | An explicit task workspace over authored literal fields and a generated, shell-quoted command draft. Replace draft applies editor insertion after screen cleanup, never command execution. Same-source templates currently cover Git review and directory creation; help prose is not a template source. |
| Change atlas | A hierarchical view derived from a Git review's captured change entries, grouped by exact path prefixes. Bars represent entry counts, not line counts; opening a file enters the existing diff reader. No filesystem discovery or list refresh occurs inside the map. |
| Receipt | A compact line intentionally left in ordinary terminal scrollback. A command receipt replaces active prompt decoration at acceptance while retaining the exact submitted buffer; an outcome receipt reports a slow success or any failure after command output. Neither is a shell-history record. |
| Path-led / concrete entry | Starts from an explicit known location, such as `~/Projects/` + Tab. The path establishes the initial folder scope. |
| Recall-led / diffuse entry | Starts from remembered fragments within a named source, such as Option-Tab over the shell's directory stack. “Diffuse” describes the user's starting knowledge; source and coverage still have explicit boundaries. |
| View | One presentation of a context with a defined purpose and applicable operations. Browse, Search and Recents are named views with distinct sources or intents. |
| View state | The context, captured facts and current editing/navigation position needed to render and continue a view. It is temporary interaction state. |
| Screen session | Ownership of the terminal display from entry through guaranteed restoration. One screen session may contain several views and input loops; distinguish it from the longer-lived shell session. |
| Input loop | Key handling against the active view and captured data, returning operation requests to its caller. View changes can finish one loop and start another within the same screen session. |
| Bookmark | Caller-owned return information such as query, selected value, viewport and focus. It is navigation state, not a persistent favorite. |
| Capability | An operation currently supported by the context and available implementation/tools. Its presence controls affordances; execution still validates mutable facts. |

### Facts, selection and effects

| Term | Meaning in Compozsh |
| --- | --- |
| Provider | Code that obtains facts from a source, such as a bounded filesystem enumerator or a trusted help companion. |
| Capture | An explicit acquisition of facts for subsequent interaction, subject to the provider's coverage and limits. |
| Snapshot | Captured facts retained for reuse, including relevant scope and partial-result information. It records observations, without promising an atomic or permanently current view of the outside world. |
| Candidate | One captured exact value with its display label and relevant facts, eligible for matching or selection. |
| Collector | Picker code that filters, ranks or extends a result prefix from captured candidates. It performs no new provider discovery. |
| Result | A candidate matching the current query/filter; it may be outside the visible viewport. |
| Query / filter | Literal user input used for positive matching or exclusion. Specify **discovery query** when submission triggers capture and **refinement filter** when it only narrows captured candidates. |
| Exclusion filter | One case-insensitive literal phrase that removes candidates containing it in the view’s complete searchable text. Empty exclusion removes nothing; spaces remain part of the phrase. Example: `nod` removes `Node.swift`, while `new/other/data.swift` remains. |
| Viewport / visible row | The displayed slice of results / one actionable presentation slot in that slice. A visible digit identifies that slot; the exact underlying value remains separate. Passive information is not a result row and receives no digit. |
| Selection / target | Selection identifies the active candidate. A target is the exact value and necessary scope an operation will use, such as repository plus branch; it may instead be an explicitly named current folder. |
| Target resolution | Turns a path or a selected recall result into an exact target for the next operation. It does not itself authorize insertion, directory change or execution; action dispatch validates mutable facts again. |
| Operation / transition | An operation is a supported step; a transition is its change to interaction context or state. Use the five operation categories in [Context-preserving composition](interaction-design.md#context-preserving-composition). |
| Acceptance / action | Acceptance requests the visibly named primary operation. An action applies an explicit effect to a target, including insertion, copying, directory change or application launch. Acceptance can instead open another view. |
| Renderer / paint | The renderer derives frame text and styles from view state. Painting applies that frame to the terminal through the shared ZLE machinery. |
| Document workspace | A file navigator paired with a primary, independently scrollable reader, such as Git review. Distinct from a picker with secondary information. |
| Action workspace | A task workspace that composes captured configuration choices into one explicit post-cleanup action, such as Xcode scheme + destination + Build. An explicit Run can then open a separate view of its scoped output; configuration selection itself does not execute or monitor a process. |
| Source anchor | A semantic reading position independent of display rows: for Git review, the old/new file side and line number at the top of the reader. Used when changing context density. |
| Disclosure | Revealing more detail about the same target without changing its task or scope. Reverse disclosure returns to the less detailed presentation using a source anchor; it is distinct from switching pane focus or navigating to another target. |
| Effect boundary | The point where code reads external facts or changes observable state. Frame construction and filtering derive from captured inputs; painting, provider reads and final actions have their own lifecycle rules. |

### Conceptual structures and vocabulary maintenance

Use these small descriptions to reason about a feature:

```text
Context: source + scope + intent
Candidate: exact value + display label + captured facts
View state: context + snapshot + query/filter + selection + viewport + focus
Transition contract: input → operation → outcome; preserved context, effects, recovery
```

These describe relationships, not mandatory records, new types or serialization
formats. Reuse existing scoped variables and helpers; omit irrelevant fields.
“Stateless discovery” means deriving a catalog when requested without maintaining
a second persistent registry. It does not prohibit temporary view state or the
specifically allowed caches of derived results under [caching](caching.md).
A disposable cache is not an authoritative registry. “Pure” applies to deterministic calculation
from inputs without external reads or observable effects, not to an entire shell
or filesystem workflow.

- Reuse an existing term when its meaning fits. Add a term only for a distinct
  concept needed by implemented behavior or an explicitly adopted design rule.
- Add or revise its definition in the same unit of work that introduces the
  concept; include its boundary and a concrete example where useful.
- Keep each definition canonical here and link to behavioral contracts instead
  of copying them. Resolve conflicting terminology when touching related docs.
- Keep proposed behavior distinguishable from shipped behavior. Definitions do
  not authorize new features, blanket renames, API changes or extra abstractions.
