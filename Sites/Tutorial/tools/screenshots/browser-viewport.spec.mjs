import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.__viewportProbe = { document: [], metrics: [], added: {}, removed: {} };
    const add = EventTarget.prototype.addEventListener;
    const remove = EventTarget.prototype.removeEventListener;
    const key = (target, type) => {
      if (target === document && type === 'visibilitychange') return 'document';
      if (target === window && type === 'resize') return 'window.resize';
      if (target === window.visualViewport && ['resize', 'scroll'].includes(type)) return `visual.${type}`;
      return null;
    };
    EventTarget.prototype.addEventListener = function(type, listener, options) {
      const name = key(this, type);
      if (name) window.__viewportProbe.added[name] = (window.__viewportProbe.added[name] ?? 0) + 1;
      return add.call(this, type, listener, options);
    };
    EventTarget.prototype.removeEventListener = function(type, listener, options) {
      const name = key(this, type);
      if (name) window.__viewportProbe.removed[name] = (window.__viewportProbe.removed[name] ?? 0) + 1;
      return remove.call(this, type, listener, options);
    };
  });
});

test('real resize reports a coherent snapshot and remount shares listeners', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('#viewport-subscriber')).toBeAttached();
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.length)).toBe(1);
  const before = await page.evaluate(() => ({ ...window.__viewportProbe.added }));
  await page.setViewportSize({ width: 720, height: 510 });
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.at(-1)?.layoutViewportHeight)).toBe(510);
  const measurement = await page.evaluate(() => window.__viewportProbe.metrics.at(-1));
  expect(measurement).toEqual({ width: 720, height: 510, offsetTop: 0,
    offsetLeft: 0, scale: 1, layoutViewportHeight: 510 });
  await page.locator('#viewport-toggle').click();
  await expect(page.locator('#viewport-subscriber')).toHaveCount(0);
  const count = await page.evaluate(() => window.__viewportProbe.metrics.length);
  await page.setViewportSize({ width: 710, height: 500 });
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  expect(await page.evaluate(() => window.__viewportProbe.metrics.length)).toBe(count);
  await page.locator('#viewport-toggle').click();
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.at(-1)?.height)).toBe(500);
  expect(await page.evaluate(() => window.__viewportProbe.added)).toEqual(before);
});

test('controlled document visibility uses visibilityState and suppresses equal values', async ({ page }) => {
  await page.goto('/');
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.document.length)).toBe(1);
  await page.evaluate(() => {
    Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'hidden' });
    document.dispatchEvent(new Event('visibilitychange'));
    document.dispatchEvent(new Event('visibilitychange'));
  });
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.document)).toEqual([true, false]);
});

test('absent visualViewport falls back to window dimensions', async ({ page }) => {
  await page.addInitScript(() => Object.defineProperty(window, 'visualViewport', {
    configurable: true, value: undefined,
  }));
  await page.goto('/');
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.at(-1))).toEqual({
    width: 800, height: 600, offsetTop: 0, offsetLeft: 0, scale: 1, layoutViewportHeight: 600,
  });
  await page.setViewportSize({ width: 700, height: 480 });
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.at(-1)?.height)).toBe(480);
});

test('discarded backend removes its new listeners exactly once', async ({ page }) => {
  await page.goto('/');
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.length)).toBe(1);
  const before = await page.evaluate(() => ({ ...window.__viewportProbe.removed }));
  await page.locator('#viewport-dispose').click();
  const after = await page.evaluate(() => ({ ...window.__viewportProbe.removed }));
  for (const key of ['document', 'window.resize', 'visual.resize', 'visual.scroll']) {
    expect((after[key] ?? 0) - (before[key] ?? 0)).toBe(1);
  }
  await page.evaluate(() => {
    document.dispatchEvent(new Event('visibilitychange'));
    window.dispatchEvent(new Event('resize'));
    window.visualViewport.dispatchEvent(new Event('scroll'));
  });
  expect(await page.evaluate(() => window.__viewportProbe.cleanupDeliveries)).toBe(0);
});

test('controlled viewport scroll delivers offsets and scale together', async ({ page }) => {
  await page.addInitScript(() => {
    const viewport = new EventTarget();
    Object.assign(viewport, { width: 390, height: 500, offsetTop: 20, offsetLeft: 4, scale: 1.5 });
    Object.defineProperty(window, 'visualViewport', { configurable: true, value: viewport });
  });
  await page.goto('/');
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.length)).toBe(1);
  await page.evaluate(() => {
    Object.assign(window.visualViewport, { height: 420, offsetTop: 35, scale: 2 });
    window.visualViewport.dispatchEvent(new Event('scroll'));
  });
  await expect.poll(() => page.evaluate(() => window.__viewportProbe.metrics.at(-1))).toEqual({
    width: 390, height: 420, offsetTop: 35, offsetLeft: 4, scale: 2, layoutViewportHeight: 600,
  });
});

for (const animationFirst of [false, true]) {
  test(`visibility and animations share one listener, animation first=${animationFirst}`, async ({ page }) => {
    await page.goto(animationFirst ? '/?viewport-animation-first' : '/');
    await page.locator('#viewport-animate').click();
    await expect.poll(() => page.evaluate(() => document.querySelector('#viewport-animated')
      .getAnimations().filter(animation => animation.playState === 'running').length)).toBeGreaterThan(0);
    await page.locator('#viewport-mount').click();
    await expect.poll(() => page.evaluate(() => window.__viewportProbe.document.length)).toBe(1);
    expect(await page.evaluate(() => window.__viewportProbe.added.document)).toBe(1);
    await page.evaluate(() => {
      Object.defineProperty(document, 'visibilityState', { configurable: true, get: () => 'hidden' });
      document.dispatchEvent(new Event('visibilitychange'));
    });
    await expect.poll(() => page.evaluate(() => window.__viewportProbe.document.at(-1))).toBe(false);
    await expect.poll(() => page.evaluate(() => document.querySelector('#viewport-animated')
      .getAnimations().filter(animation => animation.playState === 'running').length)).toBe(0);
  });
}
