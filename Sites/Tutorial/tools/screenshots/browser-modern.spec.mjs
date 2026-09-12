import { test, expect } from '@playwright/test';

test('navigation commits focus, announcement and back scroll after render', async ({ page }) => {
  await page.goto('/modern');
  await expect(page.locator('html')).toHaveAttribute('data-ready', 'true');
  await page.evaluate(() => window.scrollTo(0, 500));
  await page.getByRole('link', { name: 'Next page' }).evaluate(element => element.click());
  await expect(page).toHaveTitle('Second modern page');
  await expect(page.locator('main')).toBeFocused();
  await expect(page.locator('[data-swui-route-announcer]')).toHaveText('Second modern page');
  await expect.poll(() => page.evaluate(() => scrollY)).toBe(0);
  await page.goBack();
  await expect(page).toHaveTitle('First modern page');
  await expect.poll(() => page.evaluate(() => scrollY)).toBe(500);
});

test('malformed URL fragments do not interrupt navigation commit', async ({ page }) => {
  const errors = [];
  page.on('pageerror', error => errors.push(error.message));
  await page.goto('/modern');
  await expect(page.locator('html')).toHaveAttribute('data-ready', 'true');
  await page.getByRole('link', { name: 'Next page' }).evaluate(element => {
    element.setAttribute('href', '/modern/second#%');
    element.click();
  });
  await expect(page).toHaveTitle('Second modern page');
  await expect(page.locator('main')).toBeFocused();
  await page.waitForTimeout(100);
  expect(errors).toEqual([]);
});

test('virtual collection bounds DOM, forms enhance, workers compute and islands activate', async ({ page }) => {
  await page.goto('/modern?diagnostics');
  await expect(page.locator('html')).toHaveAttribute('data-ready', 'true');
  expect(await page.locator('[data-row]').count()).toBeLessThan(30);
  await page.locator('#virtual-list > div').evaluate(element => { element.scrollTop = 30_000; });
  await expect(page.locator('[data-row="1000"]')).toBeVisible();
  expect(await page.locator('[data-row]').count()).toBeLessThan(30);
  await page.locator('#modern-name').fill('Grace');
  await page.getByRole('button', { name: 'Submit', exact: true }).click();
  await expect(page.locator('#form-result')).toHaveText('Grace');
  await page.locator('#compute').click();
  await expect(page.locator('#worker-result')).toHaveText('42');
  await page.locator('#worker-checks').click();
  await expect(page.locator('#worker-checks-result')).toHaveText('passed');
  await expect(page.locator('#separate-island')).toHaveText('Static island');
  await page.locator('#separate-island').dispatchEvent('pointerdown');
  await expect(page.locator('#island-counter')).toHaveText('Island 0');
  await page.locator('#island-counter').click();
  await expect(page.locator('#island-counter')).toHaveText('Island 1');
  const diagnostics = await page.evaluate(() => window.__swiftwui_diagnostics);
  expect(diagnostics.length).toBeGreaterThan(0);
  expect(diagnostics.length).toBeLessThanOrEqual(32);
  expect(diagnostics.some(event => event.kind === 'render' && event.components.length > 0)).toBe(true);
  expect(JSON.stringify(diagnostics)).not.toContain('Grace');
});
