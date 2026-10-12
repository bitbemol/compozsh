# Website

`docs/` is the optional static GitHub Pages showcase. It is not a shell
feature. The maintenance guide, local review steps and test commands live in
[docs/README.md](../docs/README.md).

## Essentials

- **Static and self-contained.** Semantic HTML, CSS and small native
  JavaScript modules. No framework, build pipeline, package installation,
  remote fonts, third-party scripts, analytics or coupling to `.zshrc`.
- **Simulation only.** Demos run on bounded, synthetic, user-selected data.
  They never execute commands or read the visitor's clock, terminal, command
  line, filesystem, Git state or environment.
- **README is authoritative.** Installation and safety copy follows the README.
  Examples are synthetic and never private history or screenshots.
- **No publishing without approval.** Never enable Pages, deploy, push or
  create a hosting project without the user's authorization, and get their
  local visual approval before the first publish.

## Content and interaction

- Organize the showcase by recognizable tasks in one user-controlled
  terminal, opening on Context. Specialized examples appear within their task
  and secondary features on request. Tab changes are spatially stable; nothing
  autoplays and demos don't compete.
- The Context demo illustrates Context lens, Interaction lens and transcript
  moments only through user-selected fixed data.
- Copy only the exact visible command, after an explicit click, with a
  readable failure path; never copy an install-and-execute chain
  automatically. Official project URLs in links and metadata are fine; the
  other privacy rules still apply.
- Numbered choices mirror the native compact-row rule: no decorative gaps,
  descriptions attached to their item, browser hit areas within rows.
  Example-selector labels fit narrow mobile widths; fuller explanations go in
  the visible description, not shrunken text or clipped names.
- Example controls and feedback sit outside the simulated terminal. Prompt
  demos share one monospace cell rhythm, a continuous outline and attached
  input; explanatory material sits in a separate disclosure. Validate inner
  label, value and frame geometry at phone and desktop widths, not only page
  overflow.
- Synthetic prompt fixtures follow the [prompt contract](prompt.md): READY
  keeps available toolchains; directional versus unverified version warnings;
  qualified inference versus sourced help intent; unchanged stock-alias
  descriptions; ordinary receipts for empty or spaces-only submissions. Reuse
  semantic palette roles; fixtures never implement a second command classifier
  or version resolver. Test these distinctions as well as layout.
- Write direct, affirmative copy about actual capabilities. Avoid formulaic
  "X, not Y" contrasts, negative slogans and superiority claims, while keeping
  factual limitations and safety instructions clear.

## Quality bar

- Semantic landmarks, keyboard navigation, visible focus, adequate contrast,
  reduced-motion support, small-screen containment and useful content with
  JavaScript disabled. Relative asset paths for project-site hosting.
- A restrictive Content Security Policy without `unsafe-inline` or
  `unsafe-eval` — defense in depth, not a guarantee.
- The native suite covers the static boundary (`zsh tests/run.zsh 'website'`);
  Node's built-in test runner covers the small pure browser algorithms; browser
  QA is an optional development tool, never a dependency. Test real
  interactions, failure states, mobile widths and no-JavaScript behavior before
  handoff.
