# Showcase prompt fidelity

The user's September 4 screenshots exposed a mismatch between the native
prompt and its website illustration: smaller label fonts, generous line
spacing and separate glyph rows broke the visual rail; controls, an always-open
explanation key and reserved result space interrupted the prompt presentation.

## Implemented presentation

- Use one monospace size and cell height for prompt labels and values. A
  continuous CSS outline spans the header through the attached input; literal
  glyph placeholders retain alignment but are hidden visually. The outline
  follows the same semantic mode color as the heading.
- Reserve enough label columns for the longest authored label, including on
  phones. Keep the existing ellipsis policy for values; do not shrink labels
  into a second typography scale.
- Map captured frame/source and project roles to quiet text instead of the
  generic blue fallback. Keep code, paths, warnings and Git roles separate.
- Place entry/example controls in a separate strip above the simulated
  viewport, and feedback beneath the terminal. Move the reading key into a
  native HTML disclosure. No prompt-specific minimum-height spacer remains.
- Keep one stable 360px task viewport across all five tabs. The mobile
  control strip reserves enough height for both the label and selector even
  in a tab without examples; changing tabs does not resize the terminal.
- Open on Context's RUN/manual-summary example, as the user requested Context
  first. No-JavaScript HTML shows a static Context lens. Examples remain
  user-controlled, synthetic and explicitly labeled simulations.

The site-design guidance informed the density and separation of explanation
from the working surface. The existing static GitHub Pages architecture,
local-only data boundary, CSP, dependencies and deployment policy are unchanged.
No publish, repository push, hosting registration or private screenshot reuse
was performed.

## Regression evidence

`tests/site-prompt.browser.mjs` initially failed because explanation content
was inside the simulated viewport. Its added initial-tab check failed on Files.
Testing every prompt mode then exposed a phone-width collision for DESTINATION
TEXT; increasing the shared label column corrected it. Coverage now includes
every Context/Interaction example at 320, 390, 768, 1440 and 1920px, consecutive
row geometry, shared typography, continuous outline, attached input, role
mapping and a disclosure that cannot stretch the terminal.

The complete browser suite caught the changed keyboard order and a mobile
frame-height regression. Keyboard coverage now verifies Tab moves from the
Context tab through its Example control and then to the prompt viewport. The
mobile control-strip reservation fixed the real height regression; a focused
five-tab check found identical heights at 320, 390, 520, 768 and 1440px.
These earlier failures remain part of the evidence, not successful runs.

Synthetic desktop and phone screenshots were inspected locally after the
frame, column and color fixes. They were kept outside the repository. Final
verification results are recorded below; local review does not claim that the
public GitHub Pages deployment has changed.

Final verification passed: all 11 responsive widths in the complete browser
suite (keyboard, copy success/failure, journeys, reduced motion, no-JavaScript
and local-only requests), the all-prompt geometry suite at five widths, all
14 Node unit tests, and **649/649** native tests in 164,572.4 ms. JavaScript/Zsh
syntax, website boundary, documentation, inventory, security and whitespace
checks passed. SECURITY.md was reviewed; no security boundary changed.
