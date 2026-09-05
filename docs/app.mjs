import { findMatches } from './search.mjs';
import { scenes, fileActions } from './demo-data.mjs';
import { showJourney } from './journeys.mjs';
import './composition.mjs';
const tabs = [...document.querySelectorAll('[role="tab"]')];
const panel = document.querySelector('#demo-panel');
const query = document.querySelector('#demo-query');
const results = document.querySelector('#demo-results');
const output = document.querySelector('#demo-output');
const example = document.querySelector('#demo-example');
const review = document.querySelector('#git-review-demo');
const reviewFiles = document.querySelector('#review-files');
const reviewLines = document.querySelector('#review-lines');
const shellPrompt = document.querySelector('.shell-prompt');
const interactionMode = document.querySelector('#interaction-mode');
const interactionRows = document.querySelector('#interaction-rows');
const promptBuffer = document.querySelector('#prompt-buffer');
let scene = scenes['prompt-run'];
let matches = [];
let selected = 0;
let bookmark = null;

function highlight(index) {
  selected = index;
  [...results.children].forEach((row, rowIndex) => {
    row.classList.toggle('selected', rowIndex === selected);
    const cursor = row.querySelector('.result-cursor');
    if (cursor) cursor.textContent = rowIndex === selected ? '▸' : ' ';
  });
}

function preview(index) {
  const match = matches[index];
  if (!match) return;
  highlight(index);
  if (scene.mode === 'files' && match.kind === 'file') {
    bookmark = { scene, query: query.value, selected };
    scene = { ...scene, title: 'File actions', scope: match.label,
      input: 'Filter actions', query: '', items: fileActions(match),
      hint: 'Choose an action to preview its outcome. Escape returns to your results.',
    };
    showScene();
    query.focus();
    return;
  }
  output.textContent = match.preview;
}

function renderResults() {
  selected = 0;
  const labels = scene.matching === 'literal'
    ? scene.items.filter((item) => `${item.label} ${item.preview}`.toLowerCase().includes(query.value.toLowerCase())).map((item) => item.label)
    : findMatches(scene.items.map((item) => item.label), query.value);
  // Bound visible choices; refining always searches every item in the sample.
  matches = labels.slice(0, 5).map((label) => scene.items.find((item) => item.label === label));
  document.querySelector('.picker-primary').hidden = matches.length === 0;
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
    if (item.description) {
      const description = document.createElement('span');
      description.className = 'result-description';
      description.textContent = item.description;
      text.append(description);
    }
    row.append(text);
    row.addEventListener('focus', () => highlight(index));
    row.addEventListener('click', () => preview(index));
    results.append(row);
  }
  highlight(0);
}

function appendReviewText(parent, line) {
  if (line.segments) {
    for (const segment of line.segments) {
      const token = document.createElement('span');
      token.className = `syntax-${segment.token}`;
      token.textContent = segment.text;
      parent.append(token);
    }
    return;
  }
  parent.textContent = line.text;
}

function selectReviewFile(index, focusReader = false) {
  selected = Math.max(0, Math.min(index, scene.items.length - 1));
  const item = scene.items[selected];
  for (const [rowIndex, row] of [...reviewFiles.children].entries()) {
    row.classList.toggle('selected', rowIndex === selected);
    row.setAttribute('aria-selected', String(rowIndex === selected));
    row.tabIndex = rowIndex === selected ? 0 : -1;
  }
  document.querySelector('#review-file-title').textContent = `${item.label} · ${item.status}`;
  reviewLines.replaceChildren();
  for (const line of item.preview) {
    const row = document.createElement('div');
    row.className = `review-line ${line.kind}`;
    const oldNumber = document.createElement('span');
    oldNumber.textContent = line.old;
    const newNumber = document.createElement('span');
    newNumber.textContent = line.next;
    const marker = document.createElement('span');
    marker.textContent = line.kind === 'added' ? '+' : line.kind === 'removed' ? '−' : ' ';
    const code = document.createElement('code');
    appendReviewText(code, line);
    row.append(oldNumber, newNumber, marker, code);
    reviewLines.append(row);
  }
  if (focusReader) reviewLines.focus();
}

function renderReview() {
  selected = 0;
  reviewFiles.replaceChildren();
  document.querySelector('#review-file-count').textContent = String(scene.items.length);
  for (const [index, item] of scene.items.entries()) {
    const row = document.createElement('button');
    row.type = 'button';
    row.className = 'review-file-row';
    row.setAttribute('role', 'option');
    const name = document.createElement('span');
    name.textContent = item.label;
    const status = document.createElement('span');
    status.textContent = item.status;
    row.append(name, status);
    row.addEventListener('focus', () => selectReviewFile(index));
    row.addEventListener('click', () => selectReviewFile(index));
    row.addEventListener('keydown', (event) => {
      if (event.key === 'ArrowDown' || event.key === 'ArrowUp') {
        event.preventDefault();
        const next = Math.max(0, Math.min(
          index + (event.key === 'ArrowDown' ? 1 : -1), scene.items.length - 1,
        ));
        selectReviewFile(next);
        reviewFiles.children[next].focus();
      } else if (event.key === 'ArrowRight' || event.key === 'Enter') {
        event.preventDefault();
        selectReviewFile(index, true);
      }
    });
    reviewFiles.append(row);
  }
  selectReviewFile(0);
}

const promptRoleClasses = {
  danger: 'danger', environment: 'runtime', git: 'git', info: 'command',
  path: 'path', project: 'subtle', frame: 'subtle', success: 'git', tool: 'runtime',
  warning: 'warning',
};

function renderInteractionRow(item) {
  const row = document.createElement('div');
  row.className = 'interaction-row';
  row.dataset.source = item.source;
  const label = document.createElement('span');
  const tree = document.createElement('span');
  tree.className = 'tree';
  tree.setAttribute('aria-hidden', 'true');
  tree.textContent = '│';
  label.append(tree, ` ${item.label}`);
  const value = document.createElement('strong');
  value.className = promptRoleClasses[item.role] ?? 'command';
  value.textContent = item.value;
  row.append(label, value);
  return row;
}

function renderPrompt() {
  if (scene.mode !== 'prompt') return;
  shellPrompt.setAttribute('aria-label', `Fixed synthetic ${scene.label} prompt example`);
  if (scene.promptState === 'interaction') {
    interactionMode.textContent = scene.promptKind;
    interactionMode.className = `mode-${scene.promptKind.toLowerCase()}`;
    interactionRows.replaceChildren(...scene.rows.map(renderInteractionRow));
    promptBuffer.textContent = scene.buffer;
  } else if (scene.promptState === 'transcript') {
    document.querySelector('#transcript-time').textContent = scene.transcript.time;
    document.querySelector('#transcript-command').textContent = scene.transcript.command;
    document.querySelector('#transcript-output').textContent = scene.transcript.output;
    const outcome = document.querySelector('#transcript-outcome');
    outcome.replaceChildren();
    const outcomeText = document.createElement('span');
    outcomeText.className = scene.transcript.outcome.startsWith('×') ? 'danger' : 'git';
    outcomeText.textContent = scene.transcript.outcome;
    outcome.append(outcomeText);
  }
}

function showScene() {
  const isReview = scene.layout === 'review';
  const isJourney = scene.layout === 'journey';
  const journey = document.querySelector('#journey-demo');
  journey.onkeydown = null;
  journey.hidden = !isJourney;
  journey.replaceChildren();
  document.querySelector('#picker-demo').hidden = scene.mode === 'prompt' || isReview || isJourney;
  review.hidden = !isReview;
  document.querySelector('#context-demo').hidden = scene.mode !== 'prompt';
  shellPrompt.hidden = scene.mode !== 'prompt';
  for (const state of document.querySelectorAll('[data-prompt-state]')) {
    state.hidden = state.dataset.promptState !== scene.promptState;
  }
  renderPrompt();
  document.querySelector('#demo-command-label').textContent = scene.entryLabel ?? 'ENTRY';
  document.querySelector('#demo-command').textContent = scene.command;
  document.querySelector('#picker-title').textContent = scene.title;
  document.querySelector('#demo-scope').textContent = scene.scope ?? '';
  document.querySelector('#demo-input-label').textContent = scene.input ?? 'Search';
  document.querySelector('#demo-back-hint').textContent = bookmark ? 'Esc back' : 'Esc cancel';
  document.querySelector('#demo-benefit').textContent = scene.benefit;
  document.querySelector('#demo-description').textContent = scene.description;
  document.querySelector('#demo-docs').href = scene.docs;
  query.value = scene.query;
  output.textContent = scene.hint;
  if (isJourney) showJourney(journey, scene, scenes, output);
  else if (isReview) renderReview();
  else if (scene.mode !== 'prompt') renderResults();
}

function selectScene(id) {
  bookmark = null;
  scene = scenes[id];
  showScene();
}

function selectMode(mode) {
  // Context uses fixed synthetic states; give keyboard users a focus stop.
  panel.tabIndex = mode === 'prompt' ? 0 : -1;
  for (const tab of tabs) {
    const active = tab.dataset.mode === mode;
    tab.setAttribute('aria-selected', String(active));
    tab.tabIndex = active ? 0 : -1;
    if (active) panel.setAttribute('aria-labelledby', tab.id);
  }
  const choices = Object.entries(scenes).filter(([, item]) => item.mode === mode);
  example.replaceChildren();
  const groups = new Map();
  for (const [id, item] of choices) {
    const option = document.createElement('option');
    option.value = id;
    option.textContent = item.label ?? item.title;
    if (!item.group) {
      example.append(option);
      continue;
    }
    if (!groups.has(item.group)) {
      const group = document.createElement('optgroup');
      group.label = item.group;
      groups.set(item.group, group);
      example.append(group);
    }
    groups.get(item.group).append(option);
  }
  document.querySelector('#demo-example-control').hidden = choices.length < 2;
  selectScene(choices[0][0]);
}
example.addEventListener('change', () => selectScene(example.value));

for (const link of document.querySelectorAll('[data-demo-scene]')) {
  link.addEventListener('click', event => {
    event.preventDefault();
    const id = link.dataset.demoScene;
    selectMode(scenes[id].mode);
    example.value = id;
    selectScene(id);
    document.querySelector('#experience').scrollIntoView({ block: 'nearest' });
    document.querySelector('#journey-demo button, #journey-demo input')?.focus({ preventScroll: true });
  });
}

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
    highlight(Math.max(0, Math.min(
      selected + (event.key === 'ArrowDown' ? 1 : -1), matches.length - 1,
    )));
    results.children[selected].focus();
  } else if (event.key === 'Enter' && event.target === query) {
    event.preventDefault();
    preview(selected);
  } else if (event.key === 'Escape') {
    if (bookmark) {
      const previous = bookmark;
      bookmark = null;
      scene = previous.scene;
      showScene();
      query.value = previous.query;
      renderResults();
      highlight(previous.selected);
      query.focus();
      return;
    }
    output.textContent = 'Picker cancelled. In Zsh, Escape closes the workspace and restores your draft. Browser preview remains available.';
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
selectMode('prompt');
example.value = 'prompt-run';
selectScene(example.value);
