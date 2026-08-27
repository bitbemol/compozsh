import { findMatches } from './search.mjs';
import { scenes } from './demo-data.mjs';
const tabs = [...document.querySelectorAll('[role="tab"]')];
const panel = document.querySelector('#demo-panel');
const query = document.querySelector('#demo-query');
const results = document.querySelector('#demo-results');
const output = document.querySelector('#demo-output');
const example = document.querySelector('#demo-example');
let scene = scenes.history;
let matches = [];
let selected = 0;

function highlight(index) {
  selected = index;
  [...results.children].forEach((row, rowIndex) => {
    row.classList.toggle('selected', rowIndex === selected);
    const cursor = row.querySelector('.result-cursor');
    if (cursor) cursor.textContent = rowIndex === selected ? '●' : ' ';
  });
}

function preview(index) {
  const match = matches[index];
  if (!match) return;
  highlight(index);
  output.textContent = match.preview;
}

function renderResults() {
  selected = 0;
  const labels = findMatches(scene.items.map((item) => item.label), query.value);
  // Bound visible choices; refining always searches every item in the sample.
  matches = labels.slice(0, 5).map((label) => scene.items.find((item) => item.label === label));
  results.replaceChildren();
  document.querySelector('#match-count').textContent = `${labels.length} ${labels.length === 1 ? 'match' : 'matches'}${labels.length > matches.length ? ' · 5 shown' : ''}`;
  if (!matches.length) {
    const empty = document.createElement('p');
    empty.className = 'empty-results';
    empty.textContent = 'No matches. Try fewer fragments.';
    results.append(empty);
  }
  for (const [index, item] of matches.entries()) {
    const row = document.createElement('button');
    row.type = 'button';
    row.className = 'result-row';
    row.setAttribute('aria-label', `Preview ${item.kind ? `${item.kind} ` : ''}${item.label}`);
    for (const [className, value] of [['result-number', `[${index + 1}]`], ['result-cursor', ' ']]) {
      const span = document.createElement('span');
      span.className = className;
      span.textContent = value;
      span.setAttribute('aria-hidden', 'true');
      row.append(span);
    }
    const text = document.createElement('span');
    text.className = 'result-text';
    if (item.kind) {
      const glyph = document.createElement('span');
      glyph.className = 'result-kind';
      glyph.setAttribute('aria-hidden', 'true');
      glyph.textContent = item.kind === 'directory' ? '▸ ' : '· ';
      text.append(glyph);
    }
    text.append(item.label);
    row.append(text);
    row.addEventListener('focus', () => highlight(index));
    row.addEventListener('click', () => preview(index));
    results.append(row);
  }
  highlight(0);
}

function selectScene(id) {
  scene = scenes[id];
  document.querySelector('#picker-demo').hidden = scene.mode === 'prompt';
  document.querySelector('#context-demo').hidden = scene.mode !== 'prompt';
  document.querySelector('#demo-command').textContent = scene.command;
  document.querySelector('#picker-title').textContent = scene.title;
  document.querySelector('#demo-benefit').textContent = scene.benefit;
  document.querySelector('#demo-description').textContent = scene.description;
  document.querySelector('#demo-docs').href = scene.docs;
  query.value = scene.query;
  output.textContent = scene.hint;
  if (scene.mode !== 'prompt') renderResults();
}

function selectMode(mode) {
  // The Context panel contains static text; give keyboard users a focus stop.
  panel.tabIndex = mode === 'prompt' ? 0 : -1;
  for (const tab of tabs) {
    const active = tab.dataset.mode === mode;
    tab.setAttribute('aria-selected', String(active));
    tab.tabIndex = active ? 0 : -1;
    if (active) panel.setAttribute('aria-labelledby', tab.id);
  }
  const choices = Object.entries(scenes).filter(([, item]) => item.mode === mode);
  example.replaceChildren();
  for (const [id, item] of choices) {
    const option = document.createElement('option');
    option.value = id;
    option.textContent = item.label ?? item.title;
    example.append(option);
  }
  document.querySelector('#demo-example-control').hidden = choices.length < 2;
  selectScene(choices[0][0]);
}
example.addEventListener('change', () => selectScene(example.value));

for (const [index, tab] of tabs.entries()) {
  tab.addEventListener('click', () => selectMode(tab.dataset.mode));
  tab.addEventListener('keydown', (event) => {
    let next;
    if (event.key === 'ArrowRight') next = (index + 1) % tabs.length;
    if (event.key === 'ArrowLeft') next = (index + tabs.length - 1) % tabs.length;
    if (event.key === 'Home') next = 0;
    if (event.key === 'End') next = tabs.length - 1;
    if (next === undefined) return;
    event.preventDefault();
    selectMode(tabs[next].dataset.mode);
    tabs[next].focus();
  });
}

function refine() {
  renderResults();
  output.textContent = scene.hint;
}
query.addEventListener('input', refine);
document.querySelector('#picker-demo').addEventListener('keydown', (event) => {
  if (event.isComposing || event.metaKey || event.altKey || event.ctrlKey) return;
  if ((event.key === 'ArrowDown' || event.key === 'ArrowUp') && matches.length) {
    event.preventDefault();
    highlight((selected + (event.key === 'ArrowDown' ? 1 : matches.length - 1)) % matches.length);
    results.children[selected].focus();
  } else if (event.key === 'Enter' && event.target === query) {
    event.preventDefault();
    preview(selected);
  } else if (event.key === 'Escape') {
    query.value = '';
    renderResults();
    output.textContent = 'Search cleared. Browser preview only.';
    query.focus();
  } else if (!query.value && /^[1-9]$/.test(event.key) && matches[Number(event.key) - 1]) {
    event.preventDefault();
    preview(Number(event.key) - 1);
  } else if (event.target !== query && (event.key.length === 1 || event.key === 'Backspace')) {
    event.preventDefault();
    query.value = event.key === 'Backspace' ? Array.from(query.value).slice(0, -1).join('') : (query.value + event.key).slice(0, 120);
    query.focus();
    refine();
  }
});

for (const button of document.querySelectorAll('[data-copy]')) {
  const code = document.getElementById(button.dataset.copy);
  if (!navigator.clipboard?.writeText || !code) continue;
  button.hidden = false;
  button.addEventListener('click', async () => {
    const status = document.querySelector('#copy-status');
    try {
      await navigator.clipboard.writeText(code.textContent);
      status.textContent = 'Copied. Review the command before running it in your terminal.';
    } catch {
      status.textContent = 'Clipboard unavailable. Select and copy the command manually.';
    }
  });
}

query.disabled = false;
document.querySelector('.demo-tabs').hidden = false;
selectMode('history');
