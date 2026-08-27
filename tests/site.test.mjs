import test from 'node:test';
import assert from 'node:assert/strict';
import { findMatches } from '../docs/search.mjs';

test('demo search accepts unordered literal fragments and fuzzy abbreviations', () => {
  const items = ['git status', 'swift build -c release', 'git switch main'];
  assert.deepEqual(findMatches(items, '-c swift'), ['swift build -c release']);
  assert.deepEqual(findMatches(items, 'sft bld'), ['swift build -c release']);
  assert.deepEqual(findMatches(items, '[.*'), []);
});

test('demo search preserves source order on ties and does not mutate data', () => {
  const items = Object.freeze(['git log', 'git status', 'swift build']);
  assert.deepEqual(findMatches(items, ''), [...items]);
  assert.deepEqual(findMatches(items, 'GIT'), ['git log', 'git status']);
  assert.deepEqual(findMatches(items, 'not-found'), []);
});

test('demo prefers contiguous matches over loose subsequences', () => {
  assert.deepEqual(findMatches(['giraffe in transit', 'git status'], 'git'),
    ['git status', 'giraffe in transit']);
});
