// Acceptance smoke (spec §8/§10.4) against the BUILT site (`swiftwui serve dist`).
import { test, expect } from '@playwright/test';

const SLUGS = [
  'install-the-toolchain', 'create-your-first-project', 'hello-swiftwui',
  'wrap-up-explore', 'style-in-swift', 'wrap-up-styles', 'route-between-pages',
  'wrap-up-routing', 'prerender-and-hydrate', 'deploy-with-docker', 'wrap-up-ship',
];
const PATHS = ['/', ...SLUGS.map(s => `/tutorials/${s}`)];

for (const path of PATHS) {
  test(`hydrates without console errors: ${path}`, async ({ page }) => {
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(path);
    // console silence is NOT proof — the adoption-failure path cold-renders
    // silently; the runtime sets this attribute ONLY on successful adoption.
    await expect(page.locator('[data-swui-hydrated="true"]')).toHaveCount(1, { timeout: 30_000 });
    expect(errors).toEqual([]);
  });
}

test('quiz: select → check → highlight', async ({ page }) => {
  await page.goto('/tutorials/hello-swiftwui');
  await page.waitForSelector('[data-swui-hydrated="true"]');
  await page.locator('.tut-option', { hasText: '@State' }).click();
  await expect(page.locator('.tut-option-selected')).toHaveCount(1);
  await page.getByRole('button', { name: 'Check answer' }).click();
  await expect(page.locator('.tut-option-correct')).toHaveCount(1);
  await expect(page.locator('.tut-explain-ok')).toBeVisible();
});

test('chapter menu: open overlay → navigate', async ({ page }) => {
  await page.goto('/tutorials/hello-swiftwui');
  await page.waitForSelector('[data-swui-hydrated="true"]');
  await page.locator('.tut-dropdown').click();
  await expect(page.locator('.tut-menu-open')).toBeVisible();
  await page.locator('.tut-menu-open').getByText('Style in Swift').click();
  await expect(page).toHaveURL(/\/tutorials\/style-in-swift$/);
  await expect(page.locator('h1')).toContainText('Style in Swift');
  await expect(page.locator('.tut-menu-open')).toHaveCount(0);
});

test('scrollspy: active step flips and panel swaps', async ({ page }) => {
  await page.goto('/tutorials/hello-swiftwui');
  await page.waitForSelector('[data-swui-hydrated="true"]');
  // section "state": step 0 override = code card; scrolled to step 2 → browser mock (spec D2)
  await page.locator('#state').scrollIntoViewIfNeeded();
  await expect(page.locator('#state-step-0')).toHaveClass(/tut-step-active/);
  await expect(page.locator('#state .tut-panel .tut-card-dark')).toBeVisible();
  // ScrollSpy v2 activates a step once its row top crosses a line at 35% of
  // the viewport height (rect-based, no IntersectionObserver — see
  // Support/ScrollSpy.swift). Step rows are ~56px tall, so a single big jump
  // can overshoot past the target step onto the next one; nudge in small
  // real-scroll increments and stop as soon as step 2 activates (same
  // contract as before, just tolerant of the new mechanism's finer band).
  for (let i = 0; i < 60; i++) {
    const active = await page.locator('#state-step-2')
      .evaluate(el => el.classList.contains('tut-step-active'));
    if (active) break;
    await page.mouse.wheel(0, 20);
    await page.waitForTimeout(30);
  }
  await expect(page.locator('#state-step-2')).toHaveClass(/tut-step-active/);
  await expect(page.locator('#state .tut-panel .tut-browser')).toBeVisible();
});
