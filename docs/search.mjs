// Deliberately small browser illustration, not a port of the shell's ranker.
// Literal fragments can appear in any order; each may be a subsequence.
export function findMatches(items, query) {
  const fragments = query.slice(0, 120).toLowerCase().trim().split(/\s+/).filter(Boolean);
  return items.map((text, index) => {
    const value = text.toLowerCase();
    let score = 0;
    for (const fragment of fragments) {
      if (value.includes(fragment)) continue;
      let cursor = 0;
      for (const character of fragment) {
        const position = value.indexOf(character, cursor);
        if (position < 0) return null;
        cursor = position + 1;
      }
      score += 1;
    }
    return { text, index, score };
  }).filter(Boolean).sort((a, b) => a.score - b.score || a.index - b.index)
    .map(({ text }) => text);
}

// Preserve exact sample identities independently of their abbreviated labels.
// Exclusion is one literal phrase over the same complete searchable text.
export function findItemMatches(items, query, exclusion = '', matching = 'ranked') {
  const omitted = exclusion.slice(0, 120).toLowerCase();
  const entries = items.map(item => ({ item, text: [item.label, item.displayLabel,
    item.context, item.description, matching === 'literal' ? item.preview : '']
    .filter(value => typeof value === 'string').join(' ') }))
    .filter(({ text }) => !omitted || !text.toLowerCase().includes(omitted));
  if (matching === 'literal') {
    const wanted = query.slice(0, 120).toLowerCase();
    return entries.filter(({ text }) => text.toLowerCase().includes(wanted)).map(({ item }) => item);
  }
  const candidates = new Map();
  for (const { item, text } of entries) {
    if (!candidates.has(text)) candidates.set(text, []);
    candidates.get(text).push(item);
  }
  return findMatches(entries.map(({ text }) => text), query).map(text => candidates.get(text).shift());
}
