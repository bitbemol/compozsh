# Website

Read this contract when the task matches its route in [AGENTS.md](../AGENTS.md).
Paths in code spans are repository-relative unless explicitly qualified.
These are maintained product contracts; investigations retain historical evidence.

## Contents

- [Website boundary](#website-boundary)

## Website boundary

- `docs/` is the optional static GitHub Pages showcase, not a shell feature.
  Use semantic HTML, CSS, and small native JavaScript modules. No framework,
  build pipeline, runtime package installation, remote fonts, third-party
  scripts, analytics, or coupling to `.zshrc` is needed.
- Keep installation and safety copy synchronized with the README, which stays
  authoritative. Use only synthetic terminal examples, never private history
  or screenshots. Intentional official project URLs in website links and
  metadata are permitted; other privacy rules still apply.
- Demo interactions must be labeled simulations and operate on bounded static
  data. Never execute commands or discover files on a visitor's machine. Copy
  only the exact visible command, following an explicit click, with a readable
  failure path. Do not copy an install-and-execute chain automatically.
- The website Context demo may illustrate Context lens, Interaction lens and
  transcript prompt moments only through user-selected fixed synthetic data.
  Do not read the visitor's clock, terminal, command line, filesystem, Git
  state or environment, and do not autoplay the state sequence.
- Organize the showcase by recognizable tasks in one user-controlled terminal.
  Reveal specialized examples within their task and secondary features on
  request. Keep tab changes spatially stable; avoid autoplay and competing
  demos. Shared interaction code should consume bounded sample data.
- Showcase numbered choices mirror the native compact-row rule: no decorative
  inter-option gaps, and actual descriptions remain attached to their item.
  Preserve browser hit areas within rows. Keep example-selector labels concise
  enough to fit at narrow mobile widths; put fuller explanations in the visible
  description rather than shrinking text or relying on clipped option names.
- Open the showcase on Context. Keep website example controls and feedback
  outside the simulated terminal viewport. Prompt demos share one monospace
  cell rhythm for labels and values, a continuous outline and attached input;
  do not recreate rails from differently sized, loosely spaced text rows.
  Keep explanatory material in a separate disclosure. Validate inner label,
  value and frame geometry at phone and desktop widths, not just outer-page
  overflow; preserve the stable task viewport and accessible browser controls.
- Keep synthetic prompt fixtures aligned with the prompt contract: retained
  READY toolchains when available, directional versus unverified version warnings,
  qualified inference versus sourced help intent, unchanged stock-alias descriptions,
  and ordinary receipts for empty or spaces-only submissions. Reuse semantic
  palette roles within mixed-color rows; fixtures must not implement a second
  command classifier or version resolver. Test these distinctions as well as layout.
- Write direct, affirmative product copy about actual capabilities. Avoid
  formulaic contrasts such as “X, not Y,” negative slogans, and unsupported
  superiority claims. Keep factual limitations and safety instructions clear.
- Preserve semantic landmarks, keyboard navigation, visible focus, adequate
  contrast, reduced-motion preferences, small-screen containment, and useful
  content with JavaScript disabled. Use relative asset paths for project-site
  hosting. Keep the restrictive Content Security Policy free of unsafe-inline
  and unsafe-eval; treat it as defense in depth, not a security guarantee.
- Use the native suite for the static boundary and Node's built-in test runner
  for the small pure browser algorithms. Browser QA is an optional development
  tool, never a Compozsh dependency. Test real interactions, failure states,
  mobile widths, and no-JavaScript behavior before handoff.
- Do not enable Pages, deploy, push, or create a hosting project without the
  user's authorization. Get their local visual approval before first publish.
