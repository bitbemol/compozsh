import test from 'node:test';
import assert from 'node:assert/strict';
import { reviewRows, folderSummary } from '../docs/review.mjs';

const items = [
  { label: 'README.md', status: 'New' },
  { label: 'a/b/c/file.zsh', status: 'Staged M' },
  { label: 'a/b/c/file.zsh', status: 'Unstaged M' },
  { label: 'a/b/c/d/deep.zsh', status: 'New' },
  { label: 'ab/other.zsh', status: 'New' },
];

test('review defaults to All files with clean names and exact entry identity', () => {
  const rows = reviewRows(items);
  assert.deepEqual(rows.map(row => row.id), ['file:0', 'file:1', 'file:2', 'file:3', 'file:4']);
  assert.equal(rows[1].label, 'file.zsh');
  assert.equal(rows[1].path, items[1].label);
});

test('tree exposes third-level files, bounds depth, and filters inside closed folders', () => {
  const rows = reviewRows(items, { mode: 'tree' });
  assert.ok(rows.some(row => row.id === 'file:1'));
  assert.ok(rows.some(row => row.id === 'dir:a/b/c/d/' && row.boundary));
  assert.ok(!rows.some(row => row.id === 'file:3'));
  assert.ok(reviewRows(items, { mode: 'tree', scope: 'a/b/c/d/' }).some(row => row.id === 'file:3'));
  const options = { mode: 'tree', closed: new Set(['a/']) };
  assert.ok(!reviewRows(items, options).some(row => row.id === 'file:1'));
  assert.ok(reviewRows(items, { ...options, query: 'file.zsh', exclude: 'unstaged' }).some(row => row.id === 'file:1'));
  assert.ok(!reviewRows(items, { ...options, query: 'file.zsh', exclude: 'unstaged' }).some(row => row.id === 'file:2'));
  assert.deepEqual(reviewRows(items, { query: '[.*' }), []);
  assert.equal(reviewRows(items, { exclude: 'A/B/C/' }).length, 2);
});

test('folder summaries count entries separately, use exact prefixes, and disclose their scope', () => {
  const summary = folderSummary(items, 'a/');
  assert.equal(summary.count, 3);
  assert.equal(summary.paths, 2);
  assert.deepEqual(summary.states, [['New', 1], ['Staged M', 1], ['Unstaged M', 1]]);
  assert.deepEqual(summary.areas, [['b/', 3]]);
  assert.equal(folderSummary(items, 'a/', '', 'unstaged').count, 2);
  assert.equal(folderSummary(items, 'missing/').count, 0);
});

test('All files disambiguates duplicate basenames without merging separate change entries', () => {
  const items = [{ label: 'a/file', status: 'Staged M' }, { label: 'b/file', status: 'New' },
    { label: 'a/file', status: 'Unstaged M' }];
  const rows = reviewRows(items);
  assert.deepEqual(rows.map(row => row.label), ['file · a/', 'file · b/', 'file · a/']);
  assert.deepEqual(rows.map(row => row.id), ['file:0', 'file:1', 'file:2']);
});
