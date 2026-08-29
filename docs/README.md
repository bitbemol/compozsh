# Compozsh website

A static showcase for the shell. The site
uses semantic HTML, layered CSS with shared design tokens, and small native
JavaScript modules. No build step, package manifest, external font, analytics,
or third-party asset request is required. No shell files are loaded by it.

The repository README remains the complete product reference. Keep commands,
requirements, help samples, installation safety, and architecture synchronized
when those change. The terminal examples use synthetic data and illustrate the
real features; they are not a shell emulator or an exact copy of Zsh's ranker.

## Showcase structure and voice

One terminal contains five task tabs: Context, History, Files, Git, and
Tools. Files and Git reveal an **Example** selector for their specialized
scenarios. Git includes the two-pane, read-only Working changes workspace:
changed files remain visible on the left while the selected focused diff stays
independently readable on the right. Each scenario has a benefit, short explanation, useful
starting hint, and a link to the corresponding product documentation.
Secondary features live in an expandable section below the hero.

This uses [recognition over recall](https://www.nngroup.com/articles/recognition-and-recall/)
and [progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/):
visitors can recognize a task, try it, and choose to explore further. Five is
a design choice for these tasks, not a universal cognitive limit. Validate
clarity with people using the page. Keep the terminal frame stable, tab labels
visible on narrow screens, and navigation user-controlled. Follow the
[WAI-ARIA tabs pattern](https://www.w3.org/WAI/ARIA/apg/patterns/tabs/) for keyboard
and selection behavior.

`demo-data.mjs` holds synthetic examples, documentation links, and safe preview
outcomes. `app.mjs` shares rendering, search, and keyboard behavior across them.
The browser shows at most five choices and refines across the entire small
sample. These are illustrative fixtures, not Compozsh's actual search limits.
File search starts with a captured sample and an empty refinement field, as
the workspace Search view does. Path + Tab opens Browse, Ctrl-F explicitly
opens descendant Search, and Return submits discovery with the displayed source:
Git within a worktree, Spotlight for home/root on macOS, bounded filesystem
elsewhere. Ctrl-X can choose a source explicitly; the demos name their sources.
The Files tab groups Browse, Recents, project search and home search. Git has
its own tab, alongside Context, History and Tools. File selections open a
four-action simulation; Escape restores the exact prior filter and selection.
Those actions describe outcomes only: they never open an app, navigate the
visitor's filesystem, or access the clipboard. The demo's explicit install
Copy buttons are the only clipboard users. Keep the simulation visibly labeled;
it previews captured examples rather than emulating Zsh or discovery timing.

Keep full-screen identity, source/scope and input visually separate. Preserve
the product's visible-focus grammar in multi-pane examples: the primary
navigator and contextual reader remain spatially stable, while selection and
pane headings make the active task legible. The entry
row teaches the real key sequence; the demo footer describes browser controls.
Website Escape clears its sample filter or returns from its action menu, while
the product's Escape cancels/returns. All task tabs retain the same frame size.

Spotlight examples acknowledge index incompleteness. Keep entry-point copy
aligned with the README; the retired `d` and `f` commands are not entry points.

Use direct, affirmative copy about real capabilities. Avoid “X, not Y”
comparisons, negative slogans, and unsupported superiority claims. Preserve
clear safety instructions and factual limitations.

The visual system uses a compact three-level hierarchy, fluid `clamp()` type,
short reading measures and 44-pixel interaction targets. Large screens gain
scale and density together; narrow screens reflow the Git navigator above its
reader without creating page-level horizontal scrolling. Keep body copy
comfortably readable and let secondary details remain visually quieter than the
user's current task.

## Local review

From the repository root, use any static server. With Python 3 available:

```sh
python3 -m http.server 4173 --bind 127.0.0.1 --directory docs
```

Open `http://127.0.0.1:4173/`. Stop that server with Ctrl-C when finished.
Opening the HTML directly with `file://` does not reliably load browser modules.
The server is only a development convenience and is never part of installation.

Before the first publication, get the owner's local visual approval. Check the
layout at desktop and narrow phone widths, every demo tab and Example option, reordered query
fragments, arrow/Enter and numeric selection, Copy buttons, and copy-mode
disclosure. Ensure that links, setup instructions, and synthetic examples are
still meaningful without JavaScript. Automatic tests complement this review;
they do not substitute for it.

## Tests

The dependency-free shell suite also checks the website's static boundary:

```sh
zsh tests/run.zsh website
```

If Node.js is available as a development tool, its built-in test runner checks
the demo's pure search behavior and bounded fixtures without installing packages:

```sh
node --test tests/site.test.mjs tests/site-scenes.test.mjs
```

The optional real-browser check uses an existing development installation of
Playwright and its Chromium browser. It is not installed by this repository.
With the local server above running and Playwright available to Node:

```sh
node tests/site.browser.mjs
```

`NODE_PATH` may point to an existing package directory. `SITE_URL` can point to
a different localhost URL, including a project subpath. `SITE_SCREENSHOTS` can
name a separate output directory for desktop/phone screenshots; keep private
review artifacts outside the repository. The test stubs clipboard access, never
runs shell commands, refuses non-local URLs, and checks keyboard behavior,
literal input, captured file scopes, branch previews, copy success/failure,
stable tab geometry, responsive overflow, reduced motion,
no-JavaScript content, and the absence of third-party requests.

## GitHub Pages — only after visual approval

This site needs no custom build, secret, token, or deployment workflow. GitHub
recommends branch publishing when a site does not need a controlled build.

1. Review, commit, and push the approved `docs/` files to `main`.
2. Open the repository's **Settings → Pages**.
3. Under **Build and deployment**, choose **Deploy from a branch**.
4. Select branch **main** and folder **/docs**, then **Save**.
5. Wait for GitHub's Pages deployment to finish and check its reported URL.
6. Keep **Enforce HTTPS** enabled when available. Leave the custom-domain field
   empty unless deliberately configuring a domain you own.

The expected project URL is `https://bitbemol.github.io/compozsh/`. Set that URL
in the repository's About/Website field after checking the published result.
GitHub will publish later changes from the configured branch and folder. There
is no reason to add a separate `gh-pages` branch or a framework for this site.
Do not enable Pages before the review just to obtain a preview URL.

`.nojekyll` prevents Jekyll processing. All asset URLs are relative, so the page
works both at localhost `/` and GitHub's `/compozsh/` project path. Canonical and
social-image URLs intentionally name the public project URL. Update them if the
repository name or domain changes. The image is metadata for social previews;
it is not downloaded as part of the visible page.

See GitHub's official [publishing-source guide](https://docs.github.com/en/pages/getting-started-with-github-pages/configuring-a-publishing-source-for-your-github-pages-site).

## Asset provenance

- `favicon.png` is a raster capture of this page's CSS/text brand mark.
- `og.png` is a locally stored, optimized 1200×630 social card generated with
  the built-in image-generation tool. It contains only project branding and
  the neutral example path. No third-party image service is contacted at runtime.

Social-card generation brief:

> One typography-first landscape card for Compozsh. Flat warm paper #f5f3eb,
> graphite #242c27 type, deep green #176650 accent, sparse cyan #72d6dc details.
> Editorial Swiss layout, generous margins, left-aligned typography, a subtle
> terminal rectangle on the right. Exact brand: “Compozsh”. Exact headline:
> “Your terminal. Composed for you.” Exact subtitle: “A composable, native Zsh
> environment.” Only terminal path: “~/Projects/example-app”. No private data,
> gradients, blobs, 3D, robots, stock illustrations, clutter, or extra slogans.
