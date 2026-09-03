// Optional website QA; Node + Playwright are development tools, not shell deps.
// Start a local static server first. No real clipboard or shell commands used.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { mkdir } from 'node:fs/promises';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');
const origin = process.env.SITE_URL || 'http://127.0.0.1:4173/';
assert.ok(['localhost', '127.0.0.1', '[::1]'].includes(new URL(origin).hostname),
  'Browser QA must target localhost, never the deployed site');
const screenshots = process.env.SITE_SCREENSHOTS;
if (screenshots) await mkdir(screenshots, { recursive: true });
const browser = await chromium.launch();
try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  const errors = [];
  const requests = [];
  page.on('pageerror', (error) => errors.push(error.message));
  page.on('console', (message) => { if (message.type() === 'error') errors.push(message.text()); });
  page.on('request', (request) => requests.push(request.url()));
  await page.addInitScript(() => {
    // A fake clipboard proves exactly what would be copied without changing it.
    Object.defineProperty(navigator, 'clipboard', { value: {
      writeText: async (value) => { document.documentElement.dataset.copied = value; },
    }, configurable: true });
  });
  assert.equal((await page.goto(origin)).status(), 200);
  await page.locator('.demo-tabs').waitFor({ state: 'visible' });
  assert.equal(await page.title(), 'Compozsh — Your terminal. Composed for you.');
  assert.deepEqual(await page.getByRole('tab').allTextContents(),
    ['Context', 'History', 'Files', 'Git', 'Tools'],
    'Showcase choices should be a small, recognizable set of tasks');
  const documentProblems = await page.evaluate(() => {
    const problems = [];
    const ids = [...document.querySelectorAll('[id]')].map((element) => element.id);
    if (new Set(ids).size !== ids.length) problems.push('duplicate IDs');
    for (const link of document.querySelectorAll('a[href^="#"]')) {
      const id = link.getAttribute('href').slice(1);
      if (id && !document.getElementById(id)) problems.push(`missing anchor ${id}`);
    }
    if (document.querySelectorAll('h1').length !== 1) problems.push('expected one h1');
    return problems;
  });
  assert.deepEqual(documentProblems, [], 'Semantic document structure must be valid');
  const composition = page.locator('#composition');
  assert.equal(await composition.count(), 1, 'The architecture must explain its composition laws');
  assert.equal(await composition.getByRole('math').count(), 3);
  const order = page.locator('#composition-order');
  const configured = page.locator('#composition-configured');
  const reorder = composition.getByRole('button', { name: 'Change order', exact: true });
  const reload = composition.getByRole('button', { name: 'Load A again', exact: true });
  const orders = new Set();
  const initialTerminal = await page.locator('#demo-command').innerText();
  for (let index = 0; index < 6; index += 1) {
    const sequence = await order.innerText();
    assert.deepEqual(sequence.split(' → ').sort(), ['A', 'B', 'C']);
    orders.add(sequence);
    await reload.focus();
    await page.keyboard.press('Space');
    assert.equal(await order.innerText(), `${sequence} → A`);
    for (let repeat = 0; repeat < 3; repeat += 1) await page.keyboard.press('Enter');
    assert.equal(await order.innerText(), `${sequence} → A`, 'Reload illustration stays bounded');
    assert.equal(await configured.innerText(), 'A · B · C', 'Repeated loading preserves the configured set');
    assert.equal(await reload.evaluate(element => element === document.activeElement), true);
    await reorder.click();
    assert.equal(await configured.innerText(), 'A · B · C', 'Every loading order gives the same set');
  }
  assert.equal(orders.size, 6, 'Change order visits all six permutations');
  assert.equal(await order.innerText(), 'A → B → C', 'The model cycles back to its initial order');
  assert.equal(await page.locator('#demo-command').innerText(), initialTerminal,
    'The architecture model must leave the task demo alone');
  assert.equal(await page.locator('html').getAttribute('data-copied'), null);
  await reorder.click();
  await reload.click();
  await page.reload();
  await composition.locator('.composition-controls').waitFor({ state: 'visible' });
  assert.equal(await order.innerText(), 'A → B → C', 'Page reload clears the illustrative loading state');
  assert.equal(await page.getByRole('tab', { name: 'Files', exact: true }).getAttribute('aria-selected'), 'true');
  assert.equal(await page.locator('#demo-command').innerText(), '~/ + Tab');
  assert.equal(await page.locator('#picker-title').innerText(), 'Compozsh / Directory browser');
  assert.equal(await page.locator('#demo-back-hint').innerText(), 'Esc cancel');
  assert.equal(await page.locator('.shell-prompt').isVisible(), false);
  await page.getByRole('tab', { name: 'History', exact: true }).click();
  assert.equal(await page.locator('.result-row').count(), 3);
  await page.locator('#demo-query').press('ArrowUp');
  assert.match(await page.locator('.result-row.selected').innerText(), /swift build -c release/,
    'Picker movement must stop at the first result');
  await page.locator('.result-row').last().focus();
  const lastHistoryResult = await page.locator('.result-row').last().innerText();
  await page.keyboard.press('ArrowDown');
  assert.equal(await page.locator('.result-row.selected').innerText(), lastHistoryResult,
    'Picker movement must stop at the last result');
  await page.getByLabel('Search', { exact: false }).fill('-c swift');
  assert.equal(await page.locator('.result-row').count(), 3);
  await page.locator('#demo-query').press('ArrowDown');
  await page.keyboard.press('Enter');
  assert.match(await page.locator('#demo-output').innerText(), /swift test -c debug/);
  await page.keyboard.type('x');
  assert.equal(await page.locator('#demo-query').inputValue(), '-c swiftx',
    'Typing after arrow selection must keep refining the query');
  await page.locator('#demo-query').fill('<img src=x onerror=alert(1)>');
  assert.equal(await page.locator('#match-count').innerText(), '0 matches');
  assert.equal(await page.locator('#demo-results img').count(), 0);
  await page.locator('#demo-query').fill('npm');
  assert.equal(await page.locator('.result-row').count(), 1);
  assert.match(await page.locator('.result-row').innerText(), /npm run test/,
    'Refining must search sample items beyond the first five displayed');
  await page.locator('#demo-query').press('Escape');
  assert.equal(await page.locator('#demo-query').inputValue(), 'npm',
    'Top-level Escape must model cancellation, not clear the filter');
  assert.match(await page.locator('#demo-output').innerText(), /Picker cancelled.*restores your draft/,
    'Top-level Escape must explain the real picker cancellation outcome');
  await page.getByRole('tab', { name: 'Files', exact: true }).click();
  await page.getByLabel('Example', { exact: true }).selectOption('files-project');
  assert.equal(await page.locator('#demo-command').innerText(), './ + Tab → Ctrl-F');
  assert.match(await page.locator('#demo-scope').innerText(), /Git/);
  assert.equal(await page.locator('.result-row').count(), 3);
  await page.locator('#demo-query').fill('plan');
  await page.getByRole('button', { name: 'Preview file Notes/Network client plan.md', exact: true }).click();
  assert.equal(await page.locator('#picker-title').innerText(), 'Compozsh / File actions');
  assert.equal(await page.locator('.result-row').count(), 4);
  await page.getByRole('button', { name: 'Preview Reveal in Finder', exact: true }).click();
  assert.match(await page.locator('#demo-output').innerText(), /Finder selects this exact item/);
  assert.match(await page.locator('#demo-output').innerText(), /Notes\/Network client plan.md/);
  await page.getByRole('button', { name: 'Preview Copy path', exact: true }).click();
  assert.equal(await page.locator('html').getAttribute('data-copied'), null,
    'Selecting a sample must not access the clipboard');
  await page.locator('#demo-query').press('Escape');
  assert.equal(await page.locator('#demo-query').inputValue(), 'plan');
  assert.equal(await page.locator('#picker-title').innerText(), 'Compozsh / Files');
  assert.equal(await page.locator('.result-row').count(), 1);
  await page.getByLabel('Example', { exact: true }).selectOption('files-home');
  assert.equal(await page.locator('#demo-command').innerText(), '~/ + Tab → Ctrl-F');
  await page.locator('#demo-query').fill('2026');
  assert.equal(await page.locator('.result-row').count(), 2);
  await page.getByLabel('Example', { exact: true }).selectOption('files-recents');
  assert.equal(await page.locator('#demo-command').innerText(), 'Option-Tab');
  await page.getByRole('tab', { name: 'Git', exact: true }).click();
  await page.locator('#demo-query').fill('docs');
  await page.locator('#demo-query').press('Enter');
  assert.match(await page.locator('#demo-output').innerText(), /feature\/docs/);
  await page.getByLabel('Example', { exact: true }).selectOption('git-review');
  assert.equal(await page.locator('#git-review-demo').isVisible(), true);
  assert.ok(await page.locator('.review-file-row').count() >= 3);
  assert.ok(await page.locator('.review-line.added').count() >= 1);
  assert.ok(await page.locator('.review-line.removed').count() >= 1);
  assert.match(await page.locator('.review-file-row.selected').innerText(), /README\.md/);
  await page.locator('.review-file-row').first().focus();
  await page.keyboard.press('ArrowUp');
  assert.match(await page.locator('.review-file-row.selected').innerText(), /README\.md/,
    'Git navigator movement must stop at the first file');
  await page.locator('.review-file-row').last().focus();
  const lastReviewFile = await page.locator('.review-file-row').last().innerText();
  await page.keyboard.press('ArrowDown');
  assert.equal(await page.locator('.review-file-row.selected').innerText(), lastReviewFile,
    'Git navigator movement must stop at the last file');
  await page.getByRole('tab', { name: 'Tools', exact: true }).click();
  assert.equal(await page.getByLabel('Example', { exact: true }).isVisible(), false,
    'Specialized options should only appear inside relevant tasks');
  await page.locator('#demo-query').focus();
  await page.keyboard.press('2');
  assert.match(await page.locator('#demo-output').innerText(), /usage: cpdir/);
  await page.getByRole('tab', { name: 'Tools', exact: true }).focus();
  await page.keyboard.press('ArrowRight');
  assert.equal(await page.getByRole('tab', { name: 'Context', exact: true }).getAttribute('aria-selected'), 'true');
  await page.keyboard.press('Tab');
  assert.equal(await page.locator('#demo-panel').evaluate((element) => element === document.activeElement), true,
    'The static Context panel must be reachable from its tab');
  await page.getByRole('tab', { name: 'History', exact: true }).click();
  await page.getByRole('button', { name: 'Copy preview command' }).click();
  assert.equal(await page.locator('html').getAttribute('data-copied'), 'zsh "$repo_dir/install.zsh" --symlink --dry-run');
  await page.evaluate(() => {
    navigator.clipboard.writeText = async () => { throw new Error('Denied'); };
  });
  await page.getByRole('button', { name: 'Copy install command' }).click();
  assert.match(await page.locator('#copy-status').innerText(), /Select and copy.*manually/);
  await page.getByText('Prefer a copy instead of a symlink?', { exact: true }).click();
  assert.equal(await page.locator('details').filter({ hasText: 'Prefer a copy instead of a symlink?' }).getAttribute('open'), '');
  await page.getByText('Prefer a copy instead of a symlink?', { exact: true }).click();
  assert.equal(await page.locator('.more-features').getAttribute('open'), null);
  await page.locator('.more-features summary').click();
  assert.equal(await page.locator('.more-features dd').count(), 4);
  await page.locator('.more-features summary').click();
  const responsiveWidths = [1440, 1100, 1059, 1058, 1024, 1000, 941, 940, 768, 390, 320];
  for (const width of responsiveWidths) {
    await page.setViewportSize({ width, height: 1000 });
    await reorder.click();
    const modelHeight = (await composition.locator('.composition-example').boundingBox()).height;
    await reload.click();
    assert.ok(await order.evaluate(element => element.scrollWidth <= element.clientWidth),
      `The repeated-load example must fit at ${width}px`);
    assert.ok(Math.abs((await composition.locator('.composition-example').boundingBox()).height - modelHeight) <= 1,
      `Repeating a load must not move the model controls at ${width}px`);
    assert.ok(await composition.locator('button').evaluateAll(buttons => buttons.every(button => {
      const rect = button.getBoundingClientRect();
      return rect.left >= 0 && rect.right <= innerWidth && rect.width >= 44 && rect.height >= 44;
    })), `Composition controls must fit and remain touch-sized at ${width}px`);
    assert.ok(await composition.getByRole('math').evaluateAll(equations => equations.every(equation =>
      equation.scrollWidth <= equation.clientWidth)), `Equations must fit at ${width}px`);
    if (screenshots && [1440, 390].includes(width)) {
      await composition.screenshot({ path: `${screenshots}/composition-${width}.png` });
    }
    const heights = [];
    for (const tab of ['Context', 'History', 'Files', 'Git', 'Tools']) {
      await page.getByRole('tab', { name: tab, exact: true }).click();
      heights.push((await page.locator('.terminal').boundingBox()).height);
      const tabFits = await page.getByRole('tab', { name: tab, exact: true }).evaluate((element) => {
        const rect = element.getBoundingClientRect();
        return rect.left >= 0 && rect.right <= innerWidth && rect.width >= 44 && rect.height >= 44;
      });
      assert.ok(tabFits, `${tab} must stay visible and touch-sized at ${width}px`);
      if (tab !== 'Context') {
        assert.ok(await page.locator('#demo-results').evaluate((list) => {
          const bounds = list.getBoundingClientRect();
          return [...list.children].every((row) => {
            const rect = row.getBoundingClientRect();
            return rect.top >= bounds.top - 1 && rect.bottom <= bounds.bottom + 1;
          });
        }), `Every numbered sample must be visible in ${tab} at ${width}px`);
      }
      const exampleControl = page.getByLabel('Example', { exact: true });
      if (await exampleControl.isVisible()) {
        assert.ok(await exampleControl.evaluate((select) => {
          const context = document.createElement('canvas').getContext('2d');
          context.font = getComputedStyle(select).font;
          return [...select.options].every((option) =>
            context.measureText(option.textContent).width + 40 <= select.clientWidth);
        }), `Example labels must fit their control at ${width}px`);
      }
    }
    // All filesystem examples and the secondary action menu must fit too.
    await page.getByRole('tab', { name: 'Files', exact: true }).click();
    for (const id of ['files-browse', 'files-recents', 'files-project', 'files-home']) {
      await page.getByLabel('Example', { exact: true }).selectOption(id);
      assert.ok(await page.locator('#demo-results').evaluate(list => {
        const bounds = list.getBoundingClientRect();
        return [...list.children].every(row => row.getBoundingClientRect().bottom <= bounds.bottom + 1);
      }), `${id} results fit at ${width}px`);
    }
    await page.getByLabel('Example', { exact: true }).selectOption('files-project');
    await page.locator('#demo-query').fill('plan');
    await page.locator('#demo-query').press('Enter');
    assert.equal(await page.locator('#picker-title').innerText(), 'Compozsh / File actions');
    assert.ok(await page.locator('#demo-results').evaluate(list => {
      const bounds = list.getBoundingClientRect();
      return [...list.children].every(row => row.getBoundingClientRect().bottom <= bounds.bottom + 1);
    }), `File actions fit at ${width}px`);
    await page.getByRole('tab', { name: 'Git', exact: true }).click();
    await page.getByLabel('Example', { exact: true }).selectOption('git-review');
    const reviewGeometry = await page.locator('.review-workspace').evaluate(workspace => {
      const bounds = workspace.getBoundingClientRect();
      const files = document.querySelector('#review-files').getBoundingClientRect();
      const reader = document.querySelector('.review-reader').getBoundingClientRect();
      return {
        contained: files.left >= bounds.left - 1 && files.right <= bounds.right + 1 &&
          reader.left >= bounds.left - 1 && reader.right <= bounds.right + 1,
        readable: reader.width >= Math.min(180, bounds.width),
      };
    });
    assert.ok(reviewGeometry.contained && reviewGeometry.readable,
      `Git review panes must reflow inside the terminal at ${width}px`);
    if (screenshots && width === 1440) {
      await page.locator('.terminal').screenshot({ path: `${screenshots}/git-review-terminal.png` });
    }
    assert.ok(Math.max(...heights) - Math.min(...heights) <= 1,
      `Switching tasks should not move the terminal frame at ${width}px`);
    await page.getByRole('tab', { name: 'Files', exact: true }).click();
    await page.evaluate(() => window.scrollTo(0, 0));
    const dimensions = await page.evaluate(() => ({ scroll: document.documentElement.scrollWidth, viewport: innerWidth }));
    assert.ok(dimensions.scroll <= dimensions.viewport, `Horizontal overflow at ${width}px`);
    if (screenshots) await page.screenshot({ path: `${screenshots}/site-${width}.png`, fullPage: true });
  }
  await page.emulateMedia({ reducedMotion: 'reduce' });
  assert.equal(await page.evaluate(() => getComputedStyle(document.documentElement).scrollBehavior), 'auto');
  assert.deepEqual(errors, [], 'Browser console must be clean');
  assert.ok(requests.every((url) => url.startsWith(new URL(origin).origin)), 'No third-party asset or telemetry requests');

  const noJS = await browser.newPage({ javaScriptEnabled: false, viewport: { width: 390, height: 844 } });
  await noJS.goto(origin);
  assert.equal(await noJS.locator('#install-command').innerText(), 'zsh "$repo_dir/install.zsh" --symlink');
  assert.equal(await noJS.locator('.demo-tabs').isVisible(), false);
  assert.equal(await noJS.locator('[data-copy]:visible').count(), 0);
  assert.equal(await noJS.locator('#composition button:visible').count(), 0);
  for (const law of ['Commutativity', 'Associativity', 'Idempotence']) {
    assert.equal(await noJS.locator('#composition').getByRole('heading', { name: law }).isVisible(), true);
  }
  assert.equal(await noJS.locator('#composition-configured').innerText(), 'A · B · C');
  assert.match(await noJS.locator('#composition-scope').innerText(), /initializer.*first/);
  await noJS.close();
  console.log(`PASS: composition laws and bounded permutations, task tabs, captured file scopes, branch previews, keyboard, unordered search, literal input, numeric selection, copy success/failure, disclosure, stable geometry, reduced motion, no-JS, local-only requests, and ${responsiveWidths.length} responsive widths`);
} finally {
  await browser.close();
}
