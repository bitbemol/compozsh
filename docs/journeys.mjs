// Bounded browser illustrations. These helpers never interpret or execute a draft.
export function composeDraft(recipe, fields) {
  const valid = value => typeof value === 'string' && value.length > 0 && value.length <= 120;
  const quote = value => `'${value.replaceAll("'", "'\\''")}'`;
  if (recipe === 'directory' && valid(fields.path)) return `mkcd -- ${quote(fields.path)}`;
  if (recipe !== 'review' || !valid(fields.base) || !valid(fields.head)
      || fields.base.startsWith('-') || fields.head.startsWith('-')) return '';
  return `g --review${fields.method === 'ancestor' ? ' --merge-base' : ''} ${quote(fields.base)} ${quote(fields.head)}`;
}

export function atlasEntries(items, prefix = '') {
  const rows = [];
  const folders = new Map();
  items.forEach((item, index) => {
    if (!item.label.startsWith(prefix)) return;
    const relative = item.label.slice(prefix.length);
    const slash = relative.indexOf('/');
    if (slash < 0 || slash === relative.length - 1) {
      rows.push({ kind: 'file', label: relative, index, count: 1 });
      return;
    }
    const name = relative.slice(0, slash + 1);
    if (!folders.has(name)) {
      const row = { kind: 'folder', label: name, prefix: prefix + name, count: 0 };
      folders.set(name, row);
      rows.push(row);
    }
    folders.get(name).count++;
  });
  return rows;
}

// One small view owner for the three connected, user-controlled simulations.
export function showJourney(host, scene, scenes, output) {
  const el = (tag, className, text) => {
    const node = document.createElement(tag);
    if (className) node.className = className;
    if (text !== undefined) node.textContent = text;
    return node;
  };
  const button = (text, action, className = 'journey-button') => {
    const node = el('button', className, text);
    node.type = 'button';
    node.addEventListener('click', action);
    return node;
  };
  let back = () => { output.textContent = 'Simulation cancelled. No shell or machine state changed.'; };
  const originalBack = back;
  let helpFilter = '', helpSelected = 'Overview', helpScroll = 0;
  let fromHelp = false;
  function frame(title, trail, leftTitle, rightTitle) {
    host.replaceChildren();
    const heading = el('div', 'journey-heading');
    heading.append(el('span', '', title), el('span', 'picker-brand', 'COMPOZSH'));
    host.append(heading, el('p', 'journey-trail', trail));
    const split = el('div', 'journey-split');
    const left = el('section', 'journey-choices');
    const right = el('section', 'journey-detail');
    left.setAttribute('aria-label', leftTitle);
    right.setAttribute('aria-label', rightTitle);
    right.tabIndex = 0;
    left.append(el('h3', 'journey-pane-title', leftTitle));
    right.append(el('h3', 'journey-pane-title', rightTitle));
    split.append(left, right);
    const footer = el('div', 'journey-footer');
    host.append(split, footer);
    return { left, right, footer };
  }
  function accent(parent, text) {
    // Literal documentation spelling only; never markup or shell parsing.
    for (const part of text.split(/(--[a-z][a-z-]*|\[[a-z ]+\])/g)) {
      parent.append(part.startsWith('--') || part.startsWith('[')
        ? el('span', 'command', part) : document.createTextNode(part));
    }
  }
  function help() {
    const { left, right, footer } = frame('Help / g', 'Topics › Explanation · captured sample', 'Topics', 'Explanation');
    host.insertBefore(el('p', 'journey-description journey-context', scenes['help-topics'].scope), host.querySelector('.journey-split'));
    const explanation = el('pre', 'journey-text');
    right.append(explanation);
    const filterLabel = el('label', 'journey-filter', 'Find a topic');
    const filter = el('input');
    filter.type = 'text'; filter.maxLength = 120; filter.value = helpFilter;
    filter.setAttribute('aria-label', 'Find a help topic');
    filterLabel.append(filter);
    const list = el('div', 'journey-list');
    left.append(list);
    const paint = () => {
      const items = scenes['help-topics'].items.filter(item =>
        `${item.label} ${item.preview}`.toLowerCase().includes(helpFilter.toLowerCase()));
      list.replaceChildren();
      explanation.replaceChildren();
      if (!items.length) {
        list.append(el('p', 'journey-empty', 'No topics. Try fewer words.'));
        explanation.textContent = 'The filter only searches this fixed guide.';
        return;
      }
      if (!items.some(item => item.label === helpSelected)) helpSelected = items[0].label;
      const selectTopic = item => {
        helpSelected = item.label;
        [...list.children].forEach((row, index) => row.setAttribute('aria-pressed', String(items[index].label === helpSelected)));
        explanation.replaceChildren();
        accent(explanation, item.preview);
      };
      items.forEach((item, index) => {
        const row = button('', () => {
          helpSelected = item.label;
          if (item.action === 'compose') {
            helpScroll = left.scrollTop; fromHelp = true; composer('review');
          } else selectTopic(item);
        }, 'journey-choice');
        row.dataset.choice = '';
        row.setAttribute('aria-pressed', String(item.label === helpSelected));
        accent(row, item.label);
        row.addEventListener('focus', () => selectTopic(item));
        list.append(row);
        if (item.label === helpSelected) accent(explanation, item.preview);
      });
    };
    filter.addEventListener('input', () => { helpFilter = filter.value; paint(); });
    footer.append(filterLabel, button('Compose a sample →', () => {
      helpScroll = left.scrollTop; fromHelp = true; composer('review');
    }, 'journey-button journey-primary'));
    paint(); left.scrollTop = helpScroll;
    back = originalBack;
  }
  function composer(recipe, previous = {}) {
    const { left, right, footer } = frame('Compose / editable draft', 'Fields › Draft › Keep editing · simulation', 'Fields', 'Generated draft');
    const fields = { path: './Design notes', base: 'main', head: 'HEAD', method: 'exact', ...previous };
    const recipeLabel = el('label', 'journey-field', 'Template');
    const select = el('select'); select.setAttribute('aria-label', 'Command template');
    for (const [value, label] of [['review', 'Git review'], ['directory', 'Directory']]) {
      const option = el('option', '', label); option.value = value; select.append(option);
    }
    select.value = recipe;
    select.addEventListener('change', () => composer(select.value));
    recipeLabel.append(select); left.append(recipeLabel);
    const draft = el('pre', 'journey-draft');
    const message = el('p', 'journey-note');
    right.append(draft, message, el('p', 'journey-note', 'Literal fields · sample folder ~/Projects/example-app. No ref lookup or directory creation.'));
    const apply = button('Replace draft → keep editing', () => {
      const value = composeDraft(recipe, fields);
      if (!value) return;
      const { left: summary, right: editor, footer: done } = frame('Draft ready', 'Composer › Ordinary prompt · simulated handoff', 'Next step', 'Editable prompt');
      summary.append(el('p', 'journey-note', 'In Zsh, the composer closes before your draft returns. Only a later Return at the ordinary prompt runs it.'));
      const label = el('label', 'journey-field', 'Keep editing this sample');
      const input = el('textarea', 'journey-draft'); input.value = value; input.maxLength = 500;
      input.setAttribute('aria-label', 'Simulated editable prompt');
      label.append(input); editor.append(label, el('p', 'journey-note', 'This browser prompt never executes. Nothing was copied or written.'));
      done.append(button('Back to composer', () => composer(recipe, fields)));
      back = () => composer(recipe, fields);
      output.textContent = 'Simulation: draft returned to editing. No command executed.';
      input.focus();
    }, 'journey-button journey-primary');
    const update = () => {
      const value = composeDraft(recipe, fields);
      draft.textContent = value || 'Complete the fields to preview a draft.';
      apply.disabled = !value;
      message.textContent = value ? 'Review the exact text. Replace draft returns it to editing.'
        : 'Use nonempty fields up to 120 characters in this demo; revisions cannot start with a dash.';
    };
    const keys = recipe === 'directory' ? [['path', 'Directory']] : [['base', 'Against'], ['head', 'Compare']];
    if (recipe === 'review') {
      const label = el('label', 'journey-field', 'Comparison');
      const method = el('select'); method.setAttribute('aria-label', 'Comparison method');
      for (const [value, text] of [['exact', 'Exact revisions'], ['ancestor', 'From common ancestor']]) {
        const option = el('option', '', text); option.value = value; method.append(option);
      }
      method.value = fields.method;
      method.addEventListener('change', () => { fields.method = method.value; update(); });
      label.append(method); left.append(label);
    }
    for (const [key, title] of keys) {
      const label = el('label', 'journey-field', title);
      const input = el('input'); input.type = 'text'; input.value = fields[key]; input.maxLength = 120;
      input.autocomplete = 'off'; input.spellcheck = false; input.setAttribute('aria-label', title);
      input.addEventListener('input', () => { fields[key] = input.value; update(); });
      label.append(input); left.append(label);
    }
    const cancel = () => {
      if (fromHelp) { help(); host.querySelector('.journey-filter input').focus(); }
      else { composer(recipe); output.textContent = 'Simulation cancelled; the original shell draft would be preserved.'; }
    };
    footer.append(apply, button(fromHelp ? 'Back to Help' : 'Reset sample', cancel));
    back = cancel;
    update();
  }
  function atlas(prefix = '', selectedIndex = null, trail = []) {
    const { left, right, footer } = frame('Change atlas', `${prefix || 'Repository'} · captured entries · simulation`, 'Folders / files', selectedIndex === null ? 'Entry counts' : 'Focused diff');
    const items = scenes['git-atlas'].items;
    const rows = atlasEntries(items, prefix);
    const max = Math.max(1, ...rows.map(row => row.count));
    rows.forEach(row => {
      const choice = button('', () => row.kind === 'folder'
        ? atlas(row.prefix, null, [...trail, { prefix, index: rows.indexOf(row) }])
        : atlas(prefix, row.index, trail), 'journey-choice atlas-choice');
      choice.dataset.choice = '';
      choice.setAttribute('aria-pressed', String(row.kind === 'file' && row.index === selectedIndex));
      choice.append(el('span', '', `${row.kind === 'folder' ? '▸' : '·'} ${row.label}${row.kind === 'file' ? ` · ${items[row.index].status}` : ''}`),
        el('span', 'atlas-meter', `${'▰'.repeat(Math.max(1, Math.round(row.count / max * 6)))} ${row.count}`));
      left.append(choice);
    });
    if (selectedIndex === null) {
      right.append(el('p', 'atlas-total', String(items.filter(item => item.label.startsWith(prefix)).length)),
        el('p', 'journey-description', 'captured change entries'),
        el('p', 'journey-note', 'Bars count entries, not changed lines. Staged and unstaged entries remain distinct. Open a folder, then a file to read its diff.'),
        el('p', 'journey-note', `Fixed ${items.length}-entry sample. The real atlas inherits the review’s bounds and partial notices; it does not scan folders.`));
    } else {
      const item = items[selectedIndex];
      right.append(el('p', 'journey-description', `${item.label} · ${item.status}`));
      const code = el('div', 'atlas-code'); code.tabIndex = 0;
      code.setAttribute('aria-label', 'Captured file diff');
      item.preview.forEach(line => {
        const text = line.text ?? line.segments.map(segment => segment.text).join('');
        code.append(el('pre', `atlas-line ${line.kind}`, `${line.kind === 'added' ? '+' : line.kind === 'removed' ? '−' : ' '} ${text}`));
      });
      right.append(code);
    }
    back = () => {
      if (selectedIndex !== null) {
        atlas(prefix, null, trail);
        host.querySelectorAll('[data-choice]')[rows.findIndex(row => row.index === selectedIndex)]?.focus();
      } else if (trail.length) {
        const parent = trail.at(-1);
        atlas(parent.prefix, null, trail.slice(0, -1));
        host.querySelectorAll('[data-choice]')[parent.index]?.focus();
      } else originalBack();
    };
    footer.append(button('Back', () => back()), el('span', 'journey-note', 'Choose a folder or file · Esc back'));
  }
  host.onkeydown = event => {
    if (event.isComposing || event.ctrlKey || event.metaKey || event.altKey) return;
    if (event.key === 'Escape') { event.preventDefault(); back(); }
    else if (event.target.matches('[data-choice]') && ['ArrowDown', 'ArrowUp'].includes(event.key)) {
      event.preventDefault();
      const choices = [...host.querySelectorAll('[data-choice]')];
      choices[Math.max(0, Math.min(choices.length - 1, choices.indexOf(event.target) + (event.key === 'ArrowDown' ? 1 : -1)))]?.focus();
    }
  };
  if (scene.journey === 'atlas') atlas();
  else if (scene.journey === 'compose') composer('review');
  else help();
}
