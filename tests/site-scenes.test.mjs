import test from 'node:test';
import assert from 'node:assert/strict';
import { scenes, fileActions } from '../docs/demo-data.mjs';
import { findMatches } from '../docs/search.mjs';

test('Context examples cover the fixed living and Interaction prompt system without a live source', () => {
  const promptScenes = Object.values(scenes).filter(scene => scene.mode === 'prompt');
  assert.deepEqual(promptScenes.map(scene => scene.promptState), [
    'lens', 'interaction', 'interaction', 'interaction', 'interaction',
    'interaction', 'interaction', 'interaction', 'interaction', 'interaction',
    'interaction', 'interaction', 'interaction', 'interaction', 'interaction',
    'transcript', 'interaction',
  ]);
  assert.deepEqual(promptScenes.filter(scene => scene.promptState === 'interaction')
    .map(scene => scene.promptKind), [
    'READY', 'RUN', 'COMMENT', 'GIT', 'NAVIGATE', 'SEARCH', 'BUILD', 'TEST',
    'ENVIRONMENT', 'REMOTE', 'PIPELINE', 'CHAIN', 'REDIRECT', 'CAUTION', 'READY',
  ]);
  assert.ok(promptScenes.every(scene => scene.docs.endsWith('#living-prompt')));
  assert.deepEqual(new Set(promptScenes.map(scene => scene.group)),
    new Set(['Orientation', 'Live draft', 'After Return']));
  assert.match(promptScenes[0].description, /captured.*change/i);
  assert.match(scenes['prompt-ready'].description, /buffer is empty/i);
  assert.match(scenes['prompt-transcript'].description, /timestamped command receipt/i);
  assert.match(scenes['prompt-ready-last'].description, /LAST/i);
  assert.ok(promptScenes.every(scene => scene.items.length === 0));
});

test('Interaction fixtures distinguish literal and captured rows from advisory ACTION', () => {
  const promptScenes = Object.values(scenes)
    .filter(scene => scene.mode === 'prompt' && scene.promptState === 'interaction');
  const modesWithDrafts = promptScenes.filter(scene => scene.buffer);
  const requiredModes = [
    'RUN', 'COMMENT', 'GIT', 'NAVIGATE', 'SEARCH', 'BUILD', 'TEST', 'ENVIRONMENT',
    'REMOTE', 'PIPELINE', 'CHAIN', 'REDIRECT', 'CAUTION',
  ];
  assert.deepEqual(modesWithDrafts.map(scene => scene.promptKind), requiredModes);
  for (const scene of modesWithDrafts) {
    assert.ok(scene.rows.some(row => row.source === 'literal'),
      `${scene.promptKind} needs an exact draft row`);
    const action = scene.rows.find(row => row.label === 'ACTION');
    if (scene.promptKind === 'RUN') {
      assert.equal(action, undefined);
      assert.deepEqual(scene.rows.find(row => row.label === 'ABOUT'), {
        label: 'ABOUT', value: 'list directory contents', source: 'captured', role: 'info',
      });
      assert.equal(scene.rows.find(row => row.label === 'SOURCE')?.value,
        'Local manual · ls(1)');
    } else {
      assert.equal(action?.source, 'advisory');
      assert.match(action.value, /likely|appears|may/);
    }
    assert.ok(scene.rows.some(row => row.source === 'captured'),
      `${scene.promptKind} needs a captured anchor`);
    assert.ok(scene.rows.length <= 5);
  }
  assert.ok(scenes['prompt-ready'].rows.every(row => row.source === 'captured'));
  assert.deepEqual(scenes['prompt-ready-last'].rows.at(-1), {
    label: 'LAST', value: '✓ 2.9s', source: 'captured', role: 'success',
  });
  assert.equal(scenes['prompt-transcript'].transcript.command,
    'swift test --filter ParserTests');
  assert.match(scenes['prompt-search'].description, /literal query.*does not search/i);
  assert.match(scenes['prompt-remote'].description,
    /literal endpoint text.*never claims.*connection/i);
  assert.ok(scenes['prompt-remote'].rows.some(row => row.label === 'ENDPOINT TEXT'));
  assert.deepEqual(scenes['prompt-chain'].rows.slice(0, 3).map(row => row.label),
    ['FLOW', 'STEPS', 'CONTROL']);
  assert.deepEqual(scenes['prompt-comment'].rows.slice(0, 2), [
    { label: 'COMMENT TEXT', value: 'explain this migration', source: 'literal', role: 'info' },
    { label: 'ACTION', value: 'likely remain an interactive shell comment', source: 'advisory', role: 'info' },
  ]);
  assert.match(scenes['prompt-redirect'].description,
    /OUTPUT, INPUT, DESCRIPTOR, or RESOURCE TEXT/);
});

test('file scenes distinguish captured project paths from home-index samples', () => {
  const project = scenes['files-project'];
  const home = scenes['files-home'];
  assert.equal(project.command, './ + Tab → Ctrl-F');
  assert.equal(home.command, '~/ + Tab → Ctrl-F');
  assert.equal(scenes['files-recents'].command, 'Option-Tab');
  assert.ok(!scenes.tools.items.some(item => /^(d|f) —/.test(item.label)));
  assert.deepEqual(findMatches(project.items.map(item => item.label), 'budget'), []);
  assert.equal(findMatches(home.items.map(item => item.label), '2026').length, 2);
  assert.ok(project.items.some(item => item.kind === 'directory'));
  assert.ok(project.items.some(item => item.kind === 'file' && item.label.includes(' ')));
});

test('filesystem examples share one task and teach scoped Control-F discovery', () => {
  for (const id of ['files-browse', 'files-recents', 'files-project', 'files-home']) {
    assert.equal(scenes[id].mode, 'files');
    assert.ok(scenes[id].scope && scenes[id].input);
  }
  assert.equal(scenes['files-browse'].command, '~/ + Tab');
  assert.match(scenes['files-project'].command, /Ctrl-F/);
  assert.match(scenes['files-project'].scope, /Git/);
  assert.match(scenes['files-home'].command, /Ctrl-F/);
  assert.match(scenes['files-home'].scope, /Spotlight/);
  assert.match(scenes['files-recents'].description, /Meta/);
  assert.equal(scenes['navigate-git'].mode, 'git');
});

test('Git examples include a bounded two-pane working-changes review', () => {
  const review = scenes['git-review'];
  assert.equal(review.mode, 'git');
  assert.equal(review.layout, 'review');
  assert.equal(review.command, 'g → Ctrl-X');
  assert.match(review.scope, /Working changes/);
  assert.ok(review.items.length >= 3);
  assert.ok(review.items.every(item => item.label && item.status && item.preview));
  assert.ok(review.items.some(item => item.preview.some(line => line.kind === 'added')));
  assert.ok(review.items.some(item => item.preview.some(line => line.kind === 'removed')));
});

test('file actions preserve the exact sample target and only describe outcomes', () => {
  const item = scenes['files-project'].items.at(-1);
  const actions = fileActions(item);
  assert.deepEqual(actions.map(action => action.label), [
    'Open with default app', 'Reveal in Finder', 'Copy path', 'Insert path into command line',
  ]);
  for (const action of actions) {
    assert.ok(action.preview.includes(item.label));
    assert.match(action.preview, /Simulation only/);
    assert.equal(action.kind, undefined);
  }
});

test('scenes are bounded, intentional examples with safe outcomes and clear tasks', () => {
  assert.equal(new Set(Object.values(scenes).map(scene => scene.mode)).size, 5);
  for (const scene of Object.values(scenes)) {
    assert.ok(scene.benefit && scene.description && scene.hint && scene.docs);
    assert.ok(scene.items.length <= 7);
    // Atlas targets retain change kind: one path can have staged and unstaged entries.
    const identity = item => scene.journey === 'atlas' ? `${item.label}\0${item.status}` : item.label;
    assert.equal(new Set(scene.items.map(identity)).size, scene.items.length);
    for (const item of scene.items) assert.ok(item.label && item.preview);
  }
  assert.match(scenes['files-project'].items.at(-1).preview,
    /'\/example\/Projects\/example-app\/Notes\/Network client plan.md'/);
});

test('task action examples disclose explicit scopes and effects without running anything', () => {
  for (const name of ['draft-inspect', 'xcode-actions', 'usb-review', 'worktree-plan']) {
    const scene = scenes[name];
    assert.equal(scene?.mode, 'tools');
    assert.ok(scene.items.every(item => item.description && /Simulation only/.test(item.preview)));
  }
  assert.equal(scenes['draft-inspect'].command, 'Option-Return');
  assert.match(scenes['draft-inspect'].description, /literal draft.*never executes/i);
  assert.match(scenes['usb-review'].items[0].preview, /separate.*ERASE disk9/);
});

test('help topics demonstrate overview arguments and safety without execution', () => {
  const scene = scenes['help-topics'];
  assert.equal(scene?.command, 'g --help');
  assert.equal(scene?.input, 'Find a topic');
  assert.equal(scene?.matching, 'literal');
  assert.deepEqual(scene.items.map(item => item.label), ['Overview', '--review [base head]', '--discard-all', 'Safety', 'Examples', 'Compose example…']);
  for (const item of scene.items) assert.match(item.preview, /Simulation only/);
});

test('showcase connects authored help, editable composers and a captured entry atlas', async () => {
  const { composeDraft, atlasEntries } = await import('../docs/journeys.mjs');
  assert.equal(scenes['help-topics'].layout, 'journey');
  assert.equal(scenes['command-compose'].mode, 'tools');
  assert.equal(scenes['git-atlas'].mode, 'git');
  assert.equal(atlasEntries(scenes['git-atlas'].items)[0].count, 3);
  assert.deepEqual(atlasEntries(scenes['git-atlas'].items, 'Sources/').map(row => row.index), [0, 1, 2]);
  assert.match(scenes['git-atlas'].description, /entries.*not.*lines/i);
  assert.equal(composeDraft('directory', { path: './Design notes' }), "mkcd -- './Design notes'");
  assert.equal(composeDraft('review', { base: 'main', head: 'feature/search', method: 'ancestor' }),
    "g --review --merge-base 'main' 'feature/search'");
  assert.equal(composeDraft('review', { base: '--help', head: 'HEAD' }), '');
  assert.equal(composeDraft('directory', { path: '' }), '');
  assert.equal(composeDraft('directory', { path: 'x'.repeat(121) }), '');
  assert.equal(composeDraft('unknown', { path: './test' }), '');
  assert.equal(composeDraft('directory', { path: "./don't $(run)" }), "mkcd -- './don'\\''t $(run)'");
  const entries = [
    { label: 'src/a.zsh', status: 'Staged M' },
    { label: 'src/a.zsh', status: 'Unstaged M' },
    { label: 'src/nested/b.zsh', status: 'New' },
    { label: 'README.md', status: 'Unstaged M' },
  ];
  const root = atlasEntries(entries);
  assert.equal(root[0].count, 3);
  assert.equal(root[0].prefix, 'src/');
  assert.equal(root[1].index, 3);
  assert.deepEqual(atlasEntries(entries, 'src/').filter(row => row.kind === 'file').map(row => row.index), [0, 1]);
  assert.deepEqual(atlasEntries(entries, 'missing/'), []);
});

test('task families expose device selection and export review as bounded simulations', () => {
  assert.equal(scenes['device-tasks']?.command, 'external-device');
  assert.equal(scenes['skill-export']?.command, 'xcode --export-skills');
  assert.equal(scenes['device-tasks'].items.length, 2);
  assert.match(scenes['skill-export'].items[0].preview, /\.xcode-skill-export/);
  for (const name of ['device-tasks', 'skill-export']) {
    for (const item of scenes[name].items) assert.match(item.preview, /Simulation only/);
  }
  for (const scene of Object.values(scenes)) {
    assert.doesNotMatch(scene.command, /flash-usb|format-external-device|update-xcode-skills|prompt-refresh/);
  }
});
