import test from 'node:test';
import assert from 'node:assert/strict';
import { scenes } from '../docs/demo-data.mjs';
import * as search from '../docs/search.mjs';

test('Recents presents zero-based basename choices with separate location context', () => {
  const scene = scenes['files-recents'];
  assert.equal(scene.slotBase, 0);
  assert.deepEqual(scene.items.map(item => item.displayLabel), ['example-app/', 'docs/', 'Downloads/']);
  assert.deepEqual(scene.items.map(item => item.label), ['~/Projects/example-app', '~/Projects/docs', '~/Downloads']);
  assert.match(scene.items[0].context, /current.*~\/Projects/);
  assert.match(scene.items[1].context, /previous.*~\/Projects/);
  for (const item of scene.items) assert.ok(item.preview.includes(item.label));
});

test('picker matching retains full targets while excluding one literal phrase', () => {
  assert.equal(typeof search.findItemMatches, 'function');
  const items = scenes['files-recents'].items;
  assert.deepEqual(search.findItemMatches(items, 'Projects', 'docs'), [items[0]]);
  assert.deepEqual(search.findItemMatches(items, '', 'PROJECTS'), [items[2]]);
  assert.deepEqual(search.findItemMatches(items, '', 'Project docs'), items);
  assert.deepEqual(search.findItemMatches(items, '', '[.*'), items);
  assert.deepEqual(search.findItemMatches(items, 'previous'), [items[1]]);
});

test('picker matching retains exact duplicate-label entries and literal guide coverage', () => {
  assert.equal(typeof search.findItemMatches, 'function');
  const first = Object.freeze({ label: 'same', context: 'first' });
  const second = Object.freeze({ label: 'same', context: 'second' });
  const items = Object.freeze([first, second]);
  assert.deepEqual(search.findItemMatches(items, 'same'), items);
  assert.deepEqual(search.findItemMatches(items, 'same', 'second'), [first]);
  const topics = [{ label: 'Safety', preview: 'Ignored files remain.' }];
  assert.deepEqual(search.findItemMatches(topics, 'Ignored', '', 'literal'), topics);
  assert.deepEqual(search.findItemMatches(topics, '', 'Ignored', 'literal'), []);
});
