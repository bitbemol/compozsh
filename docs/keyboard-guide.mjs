// Shared, scoped browser controls. The guide keeps its caller's DOM and position.
export function attachKeyboardGuide(host, footer, rows, { filter, exclude } = {}) {
  const button = (label, action, className = '') => {
    const node = document.createElement('button');
    node.type = 'button'; node.textContent = label; node.className = className;
    node.addEventListener('click', action);
    return node;
  };
  let guide = null, returnFocus = null;
  function close() {
    if (!guide) return;
    guide.remove(); guide = null;
    for (const child of host.children) child.inert = false;
    host.classList.remove('guide-open');
    const target = returnFocus?.isConnected ? returnFocus : host.querySelector('[aria-selected="true"], input, button');
    target?.focus({ preventScroll: true });
  }
  function toggleExclusion() {
    const line = exclude.closest('.exclusion-line');
    line.hidden = false;
    (document.activeElement === exclude ? filter : exclude).focus();
  }
  function toggle() {
    if (guide) { close(); return; }
    returnFocus = document.activeElement;
    for (const child of host.children) child.inert = true;
    host.classList.add('guide-open');
    guide = document.createElement('section');
    guide.className = 'keyboard-guide'; guide.tabIndex = -1;
    guide.setAttribute('role', 'dialog'); guide.setAttribute('aria-label', 'Keyboard guide');
    const title = document.createElement('h3'); title.textContent = 'Keyboard guide';
    const context = document.createElement('p'); context.className = 'guide-note';
    context.textContent = 'Browser simulation · controls apply inside this example.';
    const list = document.createElement('dl');
    list.tabIndex = 0;
    list.setAttribute('aria-label', 'Scrollable keyboard controls');
    const entries = [...rows];
    if (exclude) entries.push(['Ctrl-]', 'Switch between Filter and Exclude contains'],
      ['Exclude contains', 'Hide one case-insensitive literal phrase; both fields stay active'],
      ['Ctrl-U', 'Clear the field you are editing']);
    entries.push(['Ctrl-K / Escape', 'Close this guide and restore your place']);
    for (const [key, description] of entries) {
      const term = document.createElement('dt'), detail = document.createElement('dd');
      term.textContent = key; detail.textContent = description; list.append(term, detail);
    }
    guide.append(title, context, list, button('Ctrl-K close', close, 'guide-close'));
    host.append(guide); list.focus();
  }
  if (exclude) footer.append(button('Ctrl-] filter/exclude', toggleExclusion, 'exclude-toggle'));
  footer.append(button('Ctrl-K all keys', toggle, 'all-keys'));
  const onKey = event => {
    if (event.isComposing || event.metaKey || event.altKey) return;
    if (event.ctrlKey && event.key.toLowerCase() === 'k') {
      event.preventDefault(); event.stopPropagation(); toggle();
    } else if (guide) {
      if (event.key === 'Escape') { event.preventDefault(); close(); }
      event.stopPropagation();
    } else if (exclude && event.ctrlKey && event.key === ']') {
      event.preventDefault(); event.stopPropagation(); toggleExclusion();
    } else if (exclude && event.ctrlKey && event.key.toLowerCase() === 'u' && [filter, exclude].includes(document.activeElement)) {
      event.preventDefault(); event.stopPropagation();
      document.activeElement.value = '';
      document.activeElement.dispatchEvent(new Event('input', { bubbles: true }));
    }
  };
  host.addEventListener('keydown', onKey, true);
  return () => { close(); host.removeEventListener('keydown', onKey, true); footer.querySelectorAll('button').forEach(node => node.remove()); };
}
