// Optional visual regression for the synthetic terminal's native row rhythm.
import assert from 'node:assert/strict';
import { createRequire } from 'node:module';
import { scenes } from '../docs/demo-data.mjs';
const { chromium } = createRequire(import.meta.url)('playwright');
const origin = process.env.SITE_URL || 'http://127.0.0.1:4174/';
assert.ok(['localhost', '127.0.0.1', '[::1]'].includes(new URL(origin).hostname));
const browser = await chromium.launch();
try {
  const page = await browser.newPage();
  for (const width of [320, 390, 768, 1440, 1920]) {
    await page.setViewportSize({ width, height: 1100 });
    await page.goto(origin);
    assert.equal(await page.getByRole('tab', { name: 'Context', exact: true }).getAttribute('aria-selected'), 'true',
      'The showcase must open on Context');
    await page.getByRole('tab', { name: 'Context', exact: true }).click();
    assert.equal(await page.locator('#demo-output').evaluate(e => !!e.closest('.terminal-body')), false,
      'Website explanations must not create gaps inside the terminal viewport');
    assert.equal(await page.locator('#demo-example').evaluate(e => !!e.closest('.terminal-body')), false,
      'Example controls belong outside the simulated terminal viewport');
    const terminalHeight = (await page.locator('.terminal').boundingBox()).height;
    await page.locator('#context-demo summary').click();
    assert.equal(await page.locator('#context-demo').evaluate(e => e.open), true);
    assert.equal((await page.locator('.terminal').boundingBox()).height, terminalHeight,
      'Reading the explanation must not stretch the simulated terminal');
    for (const [scene] of Object.entries(scenes).filter(([, value]) =>
      value.mode === 'prompt' && value.promptState !== 'transcript')) {
      await page.getByLabel('Example', { exact: true }).selectOption(scene);
      for (const [index, row] of (scenes[scene].rows ?? []).entries()) {
        if (row.role === 'frame' || row.role === 'project') {
          assert.equal(await page.locator('.interaction-row > strong').nth(index).getAttribute('class'), 'subtle',
            `${row.label} must retain its muted captured role`);
        }
      }
      const geometry = await page.locator('.prompt-state:visible').evaluate(e => {
        const rows = [...e.querySelectorAll('.lens-row, .interaction-row')];
        const font = getComputedStyle(e).fontSize;
        const rowHeight = Number.parseFloat(getComputedStyle(e).lineHeight);
        const rects = rows.map(row => row.getBoundingClientRect());
        const last = rects.at(-1);
        const input = e.querySelector('.interaction-input').getBoundingClientRect();
        const outline = getComputedStyle(e, '::before');
        return {
          fontMatches: rows.every(row => getComputedStyle(row.firstElementChild).fontSize === font),
          labelsFit: rows.every(row => row.firstElementChild.scrollWidth <= row.firstElementChild.clientWidth),
          consecutive: rects.every((rect, i) => !i || Math.abs(rect.top - rects[i - 1].bottom) < 1),
          oneRow: rects.every(rect => Math.abs(rect.height - rowHeight) < 1),
          inputGap: input.top - last.bottom,
          outline: outline.borderLeftStyle === 'solid' && Number.parseFloat(outline.borderLeftWidth) > 0,
          contained: e.scrollWidth <= e.clientWidth,
        };
      });
      assert.ok(geometry.fontMatches && geometry.labelsFit && geometry.consecutive && geometry.oneRow,
        `${scene} must share one terminal cell rhythm at ${width}px`);
      assert.ok(Math.abs(geometry.inputGap) < 1 && geometry.outline && geometry.contained,
        `${scene} must have one continuous outline through its input at ${width}px`);
    }
    assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  }
  console.log('PASS: native-like prompt rhythm, continuous frame, attached input and separated demo controls at five widths');
} finally {
  await browser.close();
}
