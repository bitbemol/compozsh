import test from 'node:test';
import assert from 'node:assert/strict';
import { scenes } from '../docs/demo-data.mjs';
import { findMatches } from '../docs/search.mjs';

test('file scenes distinguish captured project paths from home-index samples', () => {
  const project = scenes['files-project'];
  const home = scenes['files-home'];
  assert.equal(project.command, 'f net cli');
  assert.equal(home.command, 'f --home budget');
  assert.deepEqual(findMatches(project.items.map(item => item.label), 'budget'), []);
  assert.equal(findMatches(home.items.map(item => item.label), '2026').length, 2);
  assert.ok(project.items.some(item => item.kind === 'directory'));
  assert.ok(project.items.some(item => item.kind === 'file' && item.label.includes(' ')));
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
