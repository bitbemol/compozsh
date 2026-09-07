import { findMatches } from './search.mjs';

// Small captured-data illustration; it never reads a repository or refreshes facts.
function matchingEntries(items, query = '', exclude = '') {
  const phrase = exclude.toLowerCase();
  const matches = new Set(findMatches(items.map(item => `${item.label} ${item.status}`), query));
  return items.map((item, index) => ({ ...item, index })).filter(item => {
    const text = `${item.label} ${item.status}`;
    return matches.has(text) && (!phrase || !text.toLowerCase().includes(phrase));
  });
}

export function reviewRows(items, { mode = 'all', query = '', exclude = '', closed = new Set(), filterClosed = new Set(), scope = '' } = {}) {
  const entries = matchingEntries(items, query, exclude);
  const rows = [];
  const file = (item, depth = 0) => ({ id: `file:${item.index}`, kind: 'file',
    label: item.label.split('/').at(-1), path: item.label, status: item.status, index: item.index, depth });
  if (mode === 'all') {
    const names = new Map();
    for (const item of entries) {
      const name = item.label.split('/').at(-1);
      if (!names.has(name)) names.set(name, new Set());
      names.get(name).add(item.label);
    }
    return entries.map(item => {
      const row = file(item);
      if (names.get(row.label).size > 1) row.label += ` · ${item.label.slice(0, item.label.lastIndexOf('/')) || '.'}/`;
      return row;
    });
  }
  const folds = query || exclude ? filterClosed : closed;
  function visit(prefix, depth) {
    const children = entries.filter(item => item.label.startsWith(prefix));
    const folders = new Set();
    for (const item of children) {
      const tail = item.label.slice(prefix.length);
      if (!tail.includes('/')) { rows.push(file(item, depth)); continue; }
      const name = tail.slice(0, tail.indexOf('/') + 1);
      const path = prefix + name;
      if (folders.has(path)) continue;
      folders.add(path);
      const count = children.filter(child => child.label.startsWith(path)).length;
      const boundary = depth === 3;
      const expanded = !boundary && !folds.has(path);
      rows.push({ id: `dir:${path}`, kind: 'folder', label: name, path, count, depth, boundary, expanded });
      if (expanded) visit(path, depth + 1);
    }
  }
  if (scope) {
    const count = entries.filter(item => item.label.startsWith(scope)).length;
    if (count) {
      rows.push({ id: `dir:${scope}`, kind: 'folder', label: `${scope.slice(0, -1).split('/').at(-1)}/`,
        path: scope, count, depth: 0, boundary: false, expanded: !folds.has(scope) });
      if (!folds.has(scope)) visit(scope, 1);
    }
  } else visit('', 0);
  return rows;
}

export function folderSummary(items, prefix, query = '', exclude = '') {
  const entries = matchingEntries(items, query, exclude).filter(item => item.label.startsWith(prefix));
  const states = new Map(), areas = new Map();
  for (const item of entries) {
    states.set(item.status, (states.get(item.status) ?? 0) + 1);
    const tail = item.label.slice(prefix.length);
    const area = tail.includes('/') ? tail.slice(0, tail.indexOf('/') + 1) : 'Direct entries';
    areas.set(area, (areas.get(area) ?? 0) + 1);
  }
  const rank = map => [...map].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]));
  return { count: entries.length, paths: new Set(entries.map(item => item.label)).size,
    states: rank(states), areas: rank(areas).slice(0, 6) };
}

export function showReview(host, scene, viewControl) {
  const files = host.querySelector('#review-files'), reader = host.querySelector('#review-lines');
  const filter = host.querySelector('#review-query'), exclude = host.querySelector('#review-exclude');
  const title = host.querySelector('#review-file-title');
  let rows = [], selected = 'file:0', lastFile = 'file:0', mode = 'all';
  const tree = { scope: '', closed: new Set(), back: [] };
  const filteredTree = { scope: '', closed: new Set(), back: [] };
  const positions = new Map(), views = new Map();
  let wasFiltered = false, beforeFilter = null;
  let shown = null;
  const isFiltered = () => Boolean(filter.value || exclude.value);
  const navigation = () => isFiltered() ? filteredTree : tree;
  const rowOptions = () => ({ mode: viewControl.value, query: filter.value, exclude: exclude.value,
    closed: tree.closed, filterClosed: filteredTree.closed, scope: navigation().scope });
  const saveReading = () => {
    if (shown !== null) positions.set(shown, [reader.scrollTop, reader.scrollLeft]);
  };
  const el = (tag, text, className = '') => {
    const node = document.createElement(tag);
    node.textContent = text; node.className = className;
    return node;
  };
  function detail(row) {
    if (shown === row.id) return;
    saveReading();
    shown = row.id;
    reader.replaceChildren();
    title.textContent = row.path;
    title.title = row.path;
    host.querySelector('#review-detail-kind').textContent = row.kind === 'folder' ? 'FOLDER SUMMARY' : 'FOCUSED DIFF';
    reader.setAttribute('aria-label', row.kind === 'folder' ? 'Captured folder summary' : 'Synthetic read-only diff');
    if (row.kind === 'folder') {
      const summary = folderSummary(scene.items, row.path, filter.value, exclude.value);
      reader.append(el('p', `${summary.count} change ${summary.count === 1 ? 'entry' : 'entries'} · ${summary.paths} distinct ${summary.paths === 1 ? 'path' : 'paths'}`, 'folder-count'));
      for (const [heading, values] of [['Change mix', summary.states], ['Where changes are', summary.areas]]) {
        reader.append(el('h4', heading, 'folder-heading'));
        for (const [name, count] of values) {
          const line = el('p', '', 'folder-bar');
          line.append(el('span', name), el('span', '━'.repeat(Math.ceil(count / summary.count * 8)), 'folder-meter'), el('span', String(count)));
          reader.append(line);
        }
      }
      reader.append(el('p', `${filter.value || exclude.value ? 'Filtered' : 'Captured'} sample · bars count change entries.`, 'folder-note'));
    } else {
      lastFile = row.id;
      for (const line of scene.items[row.index].preview) {
        const node = el('div', '', `review-line ${line.kind}`), code = el('code', '');
        if (line.segments) for (const segment of line.segments) code.append(el('span', segment.text, `syntax-${segment.token}`));
        else code.textContent = line.text;
        node.append(el('span', line.old), el('span', line.next), el('span', line.kind === 'added' ? '+' : line.kind === 'removed' ? '−' : ' '), code);
        reader.append(node);
      }
    }
    const position = positions.get(row.id) ?? [0, 0];
    [reader.scrollTop, reader.scrollLeft] = position;
  }
  function select(row) {
    selected = row.id;
    for (const node of files.children) {
      const active = node.dataset.id === selected;
      node.classList.toggle('selected', active);
      node.setAttribute('aria-selected', String(active)); node.tabIndex = active ? 0 : -1;
    }
    detail(row);
  }
  function activate(row) {
    if (row.kind === 'file') { reader.focus(); return; }
    const nav = navigation();
    if (row.boundary) {
      nav.back.push({ scope: nav.scope, selected, offset: files.scrollTop });
      nav.scope = row.path; selected = row.id; files.scrollTop = 0;
    } else if (nav.closed.has(row.path)) nav.closed.delete(row.path);
    else nav.closed.add(row.path);
    render();
    files.querySelector('[aria-selected="true"]')?.focus();
  }
  function render() {
    rows = reviewRows(scene.items, rowOptions());
    files.replaceChildren();
    host.querySelector('#review-file-count').textContent = `${rows.length} shown`;
    host.querySelector('#review-scope').textContent = `${viewControl.value === 'tree' ? 'Tree' : 'All files'} · ${viewControl.value === 'tree' && navigation().scope || 'Repository'} · captured sample`;
    for (const [index, row] of rows.entries()) {
      const node = el('button', '', 'review-file-row');
      node.type = 'button'; node.setAttribute('role', 'option'); node.dataset.id = row.id;
      const indentation = row.depth + Number(row.kind === 'file' && row.depth > 0);
      const label = `${' '.repeat(indentation)}${row.kind === 'folder' ? (row.expanded ? '▾ ' : '▸ ') : ''}${row.label}`;
      node.title = `${row.path} · ${row.status ?? `${row.count} changes`}`;
      node.setAttribute('aria-label', node.title);
      node.append(el('span', `[${index + 1}]`, 'review-slot'), el('span', label, 'review-name'),
        el('span', row.status ?? `${row.count} ${row.count === 1 ? 'change' : 'changes'}`, 'review-state'));
      node.addEventListener('focus', () => select(row));
      node.addEventListener('click', () => { select(row); });
      node.addEventListener('keydown', event => {
        if (event.ctrlKey || event.metaKey || event.altKey || event.isComposing) return;
        if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
          event.preventDefault();
          files.children[Math.max(0, Math.min(index + (event.key === 'ArrowDown' ? 1 : -1), rows.length - 1))].focus();
        } else if (event.key === 'Enter') { event.preventDefault(); activate(row); }
        else if (event.key === 'ArrowRight') { event.preventDefault(); reader.focus(); }
      });
      files.append(node);
    }
    const row = rows.find(item => item.id === selected) ?? rows.find(item => item.id === lastFile) ?? rows[0];
    if (row) select(row);
    else {
      saveReading();
      shown = null; title.textContent = 'No matching changes';
      host.querySelector('#review-detail-kind').textContent = 'CAPTURED SAMPLE';
      reader.replaceChildren(el('p', 'No matching changes. Clear a filter to restore the sample.', 'folder-note'));
    }
  }
  viewControl.value = 'all'; filter.value = ''; exclude.value = '';
  viewControl.onchange = () => {
    const filters = `${filter.value}\0${exclude.value}`;
    views.set(mode, { selected, lastFile, filters, offset: files.scrollTop });
    mode = viewControl.value;
    const previous = views.get(mode);
    if (previous?.lastFile === lastFile && previous.filters === filters) selected = previous.selected;
    else {
      selected = lastFile;
      if (mode === 'tree' && !reviewRows(scene.items, rowOptions()).some(row => row.id === selected)) {
        const path = scene.items[Number(selected.slice(5))]?.label ?? '';
        navigation().scope = path.includes('/') ? path.slice(0, path.lastIndexOf('/') + 1) : '';
        navigation().closed.delete(navigation().scope);
      }
    }
    render();
    files.scrollTop = previous?.lastFile === lastFile && previous.filters === filters ? previous.offset : 0;
  };
  filter.oninput = exclude.oninput = () => {
    saveReading(); shown = null;
    if (!wasFiltered && isFiltered()) beforeFilter = { selected, offset: files.scrollTop };
    filteredTree.scope = ''; filteredTree.closed.clear(); filteredTree.back.length = 0;
    if (wasFiltered && !isFiltered() && beforeFilter) selected = beforeFilter.selected;
    render();
    if (wasFiltered && !isFiltered() && beforeFilter) files.scrollTop = beforeFilter.offset;
    wasFiltered = isFiltered();
  };
  host.onkeydown = event => {
    if (event.defaultPrevented || event.isComposing || event.metaKey || event.altKey || event.ctrlKey) return;
    if (event.key === 'ArrowLeft' && event.target === reader) {
      event.preventDefault(); files.querySelector('[aria-selected="true"]')?.focus();
    } else if (event.key === 'Escape' && viewControl.value === 'tree' && navigation().back.length) {
      event.preventDefault();
      const previous = navigation().back.pop();
      navigation().scope = previous.scope; selected = previous.selected;
      render(); files.scrollTop = previous.offset; files.querySelector('[aria-selected="true"]')?.focus();
    } else if (event.key === 'Enter' && [filter, exclude].includes(event.target)) {
      const row = rows.find(item => item.id === selected);
      if (row) { event.preventDefault(); activate(row); }
    } else if (['ArrowDown', 'ArrowUp'].includes(event.key) && [filter, exclude].includes(event.target) && rows.length) {
      event.preventDefault();
      const index = rows.findIndex(row => row.id === selected);
      files.children[Math.max(0, Math.min(index + (event.key === 'ArrowDown' ? 1 : -1), rows.length - 1))].focus();
    } else if (event.target !== reader && event.target !== exclude && !filter.value && !exclude.value && /^[1-9]$/.test(event.key) && rows[Number(event.key) - 1]) {
      event.preventDefault(); const row = rows[Number(event.key) - 1]; select(row); activate(row);
    }
  };
  render();
}
