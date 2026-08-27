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
