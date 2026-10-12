import { test, expect } from '@playwright/test';

// Live entries in JavaScriptKit's object table. Reads runtime internals:
// recheck the field names on every JavaScriptKit minor.
const liveSlots = page => page.evaluate(() => {
  const heap = window.__swift.swift.memory;
  return heap._values.length - heap._freeSlotStack.length;
});

test('remounted listeners leave no live JS objects and a re-added handler fires once', async ({ page }) => {
  page.on('pageerror', error => { throw error; });
  await page.goto('/?remount');
  await expect(page.locator('html')).toHaveAttribute('data-ready', 'true');
  const rows = page.locator('#rows > div');
  await expect(rows).toHaveCount(100);

  const before = await liveSlots(page);
  for (const count of [0, 100, 0, 100]) {
    await page.locator('#toggle-rows').click();
    await expect(rows).toHaveCount(count);
  }
  expect(await liveSlots(page)).toBe(before);

  const row = rows.first();
  const taps = page.locator('#taps');
  await row.click();
  await expect(taps).toHaveText('1');
  await row.click();
  await expect(taps).toHaveText('2');
  await page.locator('#toggle-handler').click();
  await expect(page.locator('#armed')).toHaveText('off');
  await row.click();
  await page.locator('#toggle-handler').click();
  await expect(page.locator('#armed')).toHaveText('on');
  await row.click();
  // 3, not 4: the click while the handler was off dispatched nothing.
  await expect(taps).toHaveText('3');
});
