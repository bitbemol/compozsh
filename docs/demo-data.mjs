// Synthetic, bounded examples—not a shell emulator or a visitor's filesystem.
// Each task owns its copy and outcomes; the renderer has no command semantics.
const readme = 'https://github.com/bitbemol/compozsh#';

export const scenes = {
  prompt: {
    mode: 'prompt', command: 'swift build', title: 'Project context', query: '',
    benefit: 'Useful context, at a glance.',
    description: 'Your location, Git state, and project runtime in a prompt that adapts to the space available.',
    hint: 'Resize your Zsh terminal: the active prompt adapts.',
    docs: `${readme}project-runtime-line`, items: [],
  },
  history: {
    mode: 'history', command: 'Ctrl-R', title: 'History', query: 'swift -c',
    benefit: 'Remember fragments. Find the command.',
    description: 'Search with the pieces you remember, in any order. Review the result before you run it.',
    hint: 'Try “-c swift”. Fragment order doesn’t matter.',
    docs: `${readme}fuzzy-history-search`,
    items: [
      'swift build -c release', 'swift test -c debug', 'swift build -c debug',
      'git status', 'git log --oneline', 'git switch main', 'npm run test',
    ].map((label) => ({ label, preview: `Editable preview: ${label}\nIn Zsh, review and edit before running. Browser preview only.` })),
  },
  'files-project': {
    mode: 'files', label: 'Project · Git', command: 'f net cli', title: 'Project files', query: '',
    benefit: 'Project files, within reach.',
    description: 'Search project files with f, then refine the captured paths. Select a sample to preview its safely quoted path.',
    hint: 'Try “plan” to narrow the results. ▸ directory · · file',
    docs: `${readme}fuzzy-file-finder`,
    items: [
      { kind: 'file', label: 'Sources/Network/Client.swift', preview: 'Path preview: /example/Projects/example-app/Sources/Network/Client.swift\nSynthetic path. Browser preview only.' },
      { kind: 'directory', label: 'Sources/Network/Client/', preview: 'Path preview: /example/Projects/example-app/Sources/Network/Client/\nSynthetic path. Browser preview only.' },
      { kind: 'file', label: 'Notes/Network client plan.md', preview: "Path preview: '/example/Projects/example-app/Notes/Network client plan.md'\nSpaces stay together. Browser preview only." },
    ],
  },
  'files-home': {
    mode: 'files', label: 'Home · Spotlight', command: 'f --home budget', title: 'Home index', query: '',
    benefit: 'Search across your Mac.',
    description: 'On macOS, f can query Spotlight’s existing index. Indexed results may be incomplete; these are sample paths.',
    hint: 'Try “2026” to refine these captured index results.',
    docs: `${readme}fuzzy-file-finder`,
    items: [
      { kind: 'file', label: 'Documents/Budget 2026.xlsx', preview: "Path preview: '/example/Documents/Budget 2026.xlsx'\nSynthetic index result. Browser preview only." },
      { kind: 'file', label: 'Documents/Travel budget 2026.md', preview: "Path preview: '/example/Documents/Travel budget 2026.md'\nSynthetic index result. Browser preview only." },
      { kind: 'directory', label: 'Documents/Budgets/', preview: 'Path preview: /example/Documents/Budgets/\nSynthetic index result. Browser preview only.' },
    ],
  },
  'navigate-dirs': {
    mode: 'navigate', label: 'Directories · d', command: 'd', title: 'Directory stack', query: '',
    benefit: 'Back to where you were, in one pick.',
    description: 'Use the same familiar picker for visited directories and local Git branches. Arrows, search, or a visible number.',
    hint: 'Try “docs”, or press a number while search is empty.',
    docs: `${readme}navigation-stacks`,
    items: ['~/Projects/example-app', '~/Projects/docs', '~/Downloads'].map((label) => ({
      label, kind: 'directory', preview: `Directory preview: ${label}\nIn Zsh, d changes directory. Browser preview only.`,
    })),
  },
  'navigate-git': {
    mode: 'navigate', label: 'Branches · g', command: 'g', title: 'Branch stack', query: '',
    benefit: 'Pick up on another branch.',
    description: 'Browse local branches, with recent switches first. Refine the list and pick the branch you want.',
    hint: 'Try “docs” to find the documentation branch.',
    docs: `${readme}navigation-stacks`,
    items: ['main', 'feature/docs', 'feature/search', 'fix/prompt'].map((label) => ({
      label, preview: `Branch preview: ${label}\nIn Zsh, g switches branches. Browser preview only.`,
    })),
  },
  tools: {
    mode: 'tools', command: 'compozsh', title: 'Compozsh tools', query: '',
    benefit: 'A shell that reminds you what it can do.',
    description: 'Discover your loaded tools and inspect their help. Personal add-ons appear automatically.',
    hint: 'Select a tool to preview its help.',
    docs: `${readme}self-documenting-commands`,
    items: [
      ['compozsh', 'Explore your loaded tools', 'usage: compozsh [--list | help command]', 'Explore public functions loaded from Compozsh add-on directories.'],
      ['cpdir', 'Copy your current directory', 'usage: cpdir', 'Copy the exact current directory to the local macOS clipboard.'],
      ['d', 'Revisit recent directories', 'usage: d [--list]', 'With no arguments, open the recent-directory picker.'],
      ['f', 'Find files and directories', 'usage: f [--here | --home | --global | --root directory] [--list | --print0] query ...', 'Fuzzily find files and directories using one or more query fragments.'],
      ['g', 'Switch Git branches', 'usage: g [git-arguments ...]', 'With no arguments, open the recent-branch picker.'],
    ].map(([name, description, usage, help]) => ({ label: `${name} — ${description}`, preview: `${usage}\n${help}` })),
  },
};
