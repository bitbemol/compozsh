import test from 'node:test';
import assert from 'node:assert/strict';
import { scenes, fileActions } from '../docs/demo-data.mjs';
import { findMatches } from '../docs/search.mjs';

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
    assert.equal(new Set(scene.items.map(item => item.label)).size, scene.items.length);
    for (const item of scene.items) assert.ok(item.label && item.preview);
  }
  assert.match(scenes['files-project'].items.at(-1).preview,
    /'\/example\/Projects\/example-app\/Notes\/Network client plan.md'/);
});
