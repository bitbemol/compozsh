// Synthetic, bounded examples—not a shell emulator or a visitor's filesystem.
// Each task owns its copy and outcomes; the renderer has no command semantics.
const readme = 'https://github.com/bitbemol/compozsh#';

// Pure sample outcomes. Selection never opens an app or touches the clipboard.
export function fileActions(item) {
  return [
    ['Open with default app', 'The registered macOS app opens this exact file.'],
    ['Reveal in Finder', 'Finder selects this exact item.'],
    ['Copy path', 'The literal path goes to the clipboard.'],
    ['Insert path into command line', 'The quoted path returns to the editable prompt.'],
  ].map(([label, outcome]) => ({ label,
    preview: `${outcome}\n${item.label}\nSimulation only — no application, clipboard or shell action.`,
  }));
}

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
    scope: 'Shell history · sample commands', input: 'Search history',
    benefit: 'Remember fragments. Find the command.',
    description: 'Search with the pieces you remember, in any order. Review the result before you run it.',
    hint: 'Try “-c swift”. Fragment order doesn’t matter.',
    docs: `${readme}fuzzy-history-search`,
    items: [
      'swift build -c release', 'swift test -c debug', 'swift build -c debug',
      'git status', 'git log --oneline', 'git switch main', 'npm run test',
    ].map((label) => ({ label, preview: `Editable preview: ${label}\nIn Zsh, review and edit before running. Browser preview only.` })),
  },
  'files-browse': {
    mode: 'files', label: 'Browse folders', command: '~/ + Tab', title: 'Directory browser', query: '',
    scope: '~ · child directories · hidden off', input: 'Filter folders',
    benefit: 'Start with a place. Follow your intent.',
    description: 'Type a path and press Tab. Browse children, use Ctrl-O for a shallow preview, or Ctrl-F to search below the displayed folder.',
    hint: 'In Zsh: → enters a folder; ← goes back; Enter inserts its path.',
    docs: `${readme}contextual-directory-completion`,
    items: ['Documents/', 'Downloads/', 'Projects/'].map(label => ({ label, kind: 'directory',
      preview: `Editable path: ~/${label}\nEnter at the normal prompt changes directory. Browser preview only.`,
    })),
  },
  'files-recents': {
    mode: 'files', label: 'Recent folders', command: 'Option-Tab', title: 'Recent directories', query: '',
    scope: 'This shell · native directory stack', input: 'Filter recents',
    benefit: 'Recall a place. Continue from there.',
    description: 'Option-Tab recalls this shell’s visited folders. Enter inserts the path; Ctrl-O browses it. Enable Use Option as Meta key in your Terminal profile.',
    hint: 'Try “docs”. Recents uses the native stack; each shell has its own.',
    docs: `${readme}navigation-stacks`,
    items: ['~/Projects/example-app', '~/Projects/docs', '~/Downloads'].map(label => ({
      label, kind: 'directory', preview: `Editable path: ${label}\nEnter at the normal prompt changes directory. Browser preview only.`,
    })),
  },
  'files-project': {
    mode: 'files', label: 'Project search', command: './ + Tab → Ctrl-F', title: 'Files', query: '',
    scope: 'Git · ~/Projects/example-app · captured sample', input: 'Filter results',
    benefit: 'Project files, within reach.',
    description: 'Ctrl-F uses Git within a repository and keeps the displayed folder as scope. Submit a query, then refine captured results. Enter on a file opens its actions.',
    hint: 'Try “plan”, then Enter for file actions. ▸ directory · · file',
    docs: `${readme}filesystem-search-in-the-path-workspace`,
    items: [
      { kind: 'file', label: 'Sources/Network/Client.swift', preview: 'Path preview: /example/Projects/example-app/Sources/Network/Client.swift\nSynthetic path. Browser preview only.' },
      { kind: 'directory', label: 'Sources/Network/Client/', preview: 'Path preview: /example/Projects/example-app/Sources/Network/Client/\nSynthetic path. Browser preview only.' },
      { kind: 'file', label: 'Notes/Network client plan.md', preview: "Path preview: '/example/Projects/example-app/Notes/Network client plan.md'\nSpaces stay together. Browser preview only." },
    ],
  },
  'files-home': {
    mode: 'files', label: 'Home search', command: '~/ + Tab → Ctrl-F', title: 'Files', query: '',
    scope: 'Spotlight · ~ · samples for “budget”', input: 'Filter results',
    benefit: 'A clear scope. A useful next step.',
    description: 'At home or root, Ctrl-F defaults to Spotlight on macOS. The source and Searching… status appear before capture; failures are reported explicitly. Index coverage may be incomplete.',
    hint: 'Try “2026” to refine these captured index results.',
    docs: `${readme}filesystem-search-in-the-path-workspace`,
    items: [
      { kind: 'file', label: 'Documents/Budget 2026.xlsx', preview: "Path preview: '/example/Documents/Budget 2026.xlsx'\nSynthetic index result. Browser preview only." },
      { kind: 'file', label: 'Documents/Travel budget 2026.md', preview: "Path preview: '/example/Documents/Travel budget 2026.md'\nSynthetic index result. Browser preview only." },
      { kind: 'directory', label: 'Documents/Budgets/', preview: 'Path preview: /example/Documents/Budgets/\nSynthetic index result. Browser preview only.' },
    ],
  },
  'navigate-git': {
    mode: 'git', label: 'Switch branches', command: 'g', title: 'Branches', query: '',
    scope: 'example-app · recent local checkouts', input: 'Filter branches',
    benefit: 'Pick up on another branch.',
    description: 'Inspect recent local branches, tip commits and upstreams in a responsive workspace. Enter switches; Ctrl-Y copies the branch name.',
    hint: 'Try “docs” to find the documentation branch.',
    docs: `${readme}navigation-stacks`,
    items: ['main', 'feature/docs', 'feature/search', 'fix/prompt'].map((label) => ({
      label, preview: `Branch: ${label}\nTip: a1b2c3d · Refine example layout\nUpstream: origin/${label}\nIn Zsh, Enter switches. Browser preview only.`,
    })),
  },
  'git-review': {
    mode: 'git', label: 'Review changes', layout: 'review', command: 'g → Ctrl-X',
    title: 'Working changes', query: '', scope: 'Working changes · read-only snapshot',
    input: 'Filter files', benefit: 'Review the change. Keep your flow.',
    description: 'A focused file navigator and independently scrollable reader bring working changes into one native workspace. Ctrl-R refreshes the snapshot while you review AI or editor work.',
    hint: 'In Zsh: → focuses the diff; → again reveals full-file context; Ctrl-R refreshes.',
    docs: `${readme}read-only-git-review`,
    items: [
      {
        label: 'README.md', status: 'Unstaged M', preview: [
          { old: '2171', next: '2171', kind: 'context', text: 'The selected file stays anchored while the reader moves.' },
          { old: '2172', next: '', kind: 'removed', text: 'Ctrl-R refreshes the selected snapshot.' },
          { old: '', next: '2172', kind: 'added', text: 'Ctrl-R refreshes the file list and selected diff.' },
          { old: '', next: '2173', kind: 'added', text: 'Focus and source position remain visible.' },
          { old: '2173', next: '2174', kind: 'context', text: 'Arrow disclosure keeps the same selected file.' },
        ],
      },
      {
        label: '.zsh.addons/.zsh.git-review', status: 'Unstaged M', preview: [
          { old: '812', next: '812', kind: 'context', segments: [
            { text: 'local', token: 'keyword' }, { text: ' selected_path=$1', token: 'text' },
          ] },
          { old: '813', next: '', kind: 'removed', text: '_git_review_capture "$selected_path"' },
          { old: '', next: '813', kind: 'added', segments: [
            { text: '_git_review_refresh', token: 'function' }, { text: ' "$selected_path"', token: 'string' },
          ] },
          { old: '814', next: '814', kind: 'context', segments: [
            { text: 'return', token: 'keyword' }, { text: ' $?', token: 'variable' },
          ] },
        ],
      },
      {
        label: 'tests/git_refresh_test.zsh', status: 'New', preview: [
          { old: '', next: '1', kind: 'added', text: '# Refresh retains the selected path and reading anchor.' },
          { old: '', next: '2', kind: 'added', segments: [
            { text: 'test_case', token: 'function' }, { text: " 'Git workspace refreshes safely'", token: 'string' },
          ] },
          { old: '', next: '3', kind: 'added', text: '  _test_git_refresh_workspace' },
        ],
      },
    ],
  },
  tools: {
    mode: 'tools', command: 'compozsh', title: 'Compozsh tools', query: '',
    scope: 'Loaded add-ons · safe help providers', input: 'Filter tools',
    benefit: 'A shell that reminds you what it can do.',
    description: 'Discover your loaded tools and inspect their help. Personal add-ons appear automatically.',
    hint: 'Select a tool to preview its help.',
    docs: `${readme}self-documenting-commands`,
    items: [
      ['compozsh', 'Explore your loaded tools', 'usage: compozsh [--list | help command]', 'Explore public functions loaded from Compozsh add-on directories.'],
      ['cpdir', 'Copy your current directory', 'usage: cpdir', 'Copy the exact current directory to the local macOS clipboard.'],
      ['g', 'Branches and worktrees', 'usage: g [git-arguments ...]', 'Open recent branches, manage worktrees with -w or --worktree, or run Git.'],
    ].map(([name, description, usage, help]) => ({ label: `${name} — ${description}`, preview: `${usage}\n${help}` })),
  },
};
