// Optional component interaction QA; serve docs locally before running.
import assert from 'node:assert/strict';
import { before, after, test } from 'node:test';
import { createRequire } from 'node:module';
const { chromium } = createRequire(import.meta.url)('playwright');
const origin = process.env.SITE_URL || 'http://127.0.0.1:4173/';
assert.ok(['localhost', '127.0.0.1', '[::1]'].includes(new URL(origin).hostname));
let browser;
before(async () => { browser = await chromium.launch(); });
after(async () => { await browser?.close(); });
async function fixture() {
  const page = await browser.newPage();
  const markup = `<select id="view"><option value="all">All files</option><option value="tree">Tree</option></select>
    <section id="review"><input id="review-query"><input id="review-exclude">
    <span id="review-file-count"></span><span id="review-scope"></span>
    <div id="review-files" style="height:120px;overflow:auto"></div>
    <h3 id="review-file-title"></h3><span id="review-detail-kind"></span>
    <div id="review-lines" tabindex="0" style="height:70px;width:200px;overflow:auto"></div></section>`;
  // Serve a test-owned document so the production CSP does not suppress fixture
  // geometry; the real page and its CSP are exercised by site.browser.mjs.
  await page.route(`${origin}component-review-test`, route => route.fulfill({ contentType: 'text/html', body: markup }));
  await page.goto(`${origin}component-review-test`);
  await page.evaluate(async origin => {
    const { showReview } = await import(`${origin}review.mjs`);
    const items = ['README.md', 'a/first', 'a/b/second', 'a/b/c/third', 'a/b/c/d/deep', 'z/target', 'a/first']
      .map((label, index) => ({ label, status: index === 6 ? 'Staged M' : 'Unstaged M',
        preview: Array.from({ length: 80 }, (_, line) => ({ old: String(line), next: String(line), kind: 'context', text: `sample line ${line}` })) }));
    showReview(document.querySelector('#review'), { items }, document.querySelector('#view'));
  }, origin);
  return page;
}

test('review filters preserve current and temporarily hidden reader positions', async () => {
  const page = await fixture();
  try {
    await page.locator('#review-lines').evaluate(node => { node.scrollTop = 80; });
    assert.equal(await page.locator('#review-lines').evaluate(node => node.scrollTop), 80, 'fixture must have a scrollable reader');
    await page.locator('#review-query').fill('README');
    assert.equal(await page.locator('#review-lines').evaluate(node => node.scrollTop), 80);
    await page.locator('#review-query').fill('unmatched');
    await page.locator('#review-query').fill('');
    assert.equal(await page.locator('#review-file-title').innerText(), 'README.md');
    assert.equal(await page.locator('#review-lines').evaluate(node => node.scrollTop), 80);
  } finally { await page.close(); }
});

test('review searches the captured sample outside a scoped folder and restores scope on clear', async () => {
  const page = await fixture();
  try {
    await page.locator('#view').selectOption('tree');
    await page.locator('[data-id="dir:a/b/c/d/"]').press('Enter');
    await page.locator('#review-query').fill('target');
    assert.equal(await page.locator('[data-id="file:5"]').count(), 1);
    await page.locator('#review-query').fill('');
    assert.match(await page.locator('#review-scope').innerText(), /a\/b\/c\/d\//);
    await page.locator('#view').selectOption('all');
    assert.match(await page.locator('#review-scope').innerText(), /All files · Repository/);
    await page.locator('#review-lines').press('Escape');
    await page.locator('#view').selectOption('tree');
    assert.match(await page.locator('#review-scope').innerText(), /a\/b\/c\/d\//);
  } finally { await page.close(); }
});

test('filtered folder toggles have their own fold state', async () => {
  const page = await fixture();
  try {
    await page.locator('#view').selectOption('tree');
    await page.locator('[data-id="dir:a/"]').press('Enter');
    assert.equal(await page.locator('[data-id="file:1"]').count(), 0);
    await page.locator('#review-query').fill('first');
    assert.equal(await page.locator('[data-id="file:1"]').count(), 1);
    await page.locator('[data-id="dir:a/"]').press('Enter');
    assert.equal(await page.locator('[data-id="file:1"]').count(), 0);
    await page.locator('#review-query').fill('');
    assert.equal(await page.locator('[data-id="file:1"]').count(), 0);
  } finally { await page.close(); }
});

test('digits do not change files while reading or typing an exclusion', async () => {
  const page = await fixture();
  try {
    await page.locator('#review-lines').focus();
    await page.keyboard.press('2');
    assert.equal(await page.locator('#review-file-title').innerText(), 'README.md');
    await page.locator('#review-exclude').focus();
    await page.keyboard.press('2');
    assert.equal(await page.locator('#review-exclude').inputValue(), '2');
  } finally { await page.close(); }
});
