import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  page.on('pageerror', error => { throw error; });
});

async function ready(page) {
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-ready', 'true');
  await expect.poll(() => page.evaluate(() => window.__browserEvents.half.length)).toBeGreaterThan(0);
}

test('visibility reports the threshold fraction, including the initial clipped state', async ({ page }) => {
  await ready(page);
  // Only the bottom 10px of the clipping parent overlap the 100px target.
  await expect.poll(() => page.evaluate(() => window.__browserEvents.half.at(-1))).toBe(false);
  await expect.poll(() => page.evaluate(() => window.__browserEvents.zero.at(-1))).toBe(true);
  await expect.poll(() => page.evaluate(() => window.__browserEvents.full.at(-1))).toBe(false);

  await page.locator('#target').evaluate(el => el.style.transform = 'translateY(40px)');
  await expect.poll(() => page.evaluate(() => window.__browserEvents.half.at(-1))).toBe(true);

  await page.locator('#target').evaluate(el => el.style.transform = 'translateY(90px)');
  await expect.poll(() => page.evaluate(() => window.__browserEvents.half.at(-1))).toBe(false);

  await page.locator('#target').evaluate(el => el.style.transform = 'translateY(110px)');
  await expect.poll(() => page.evaluate(() => window.__browserEvents.zero.at(-1))).toBe(false);
});

test('visibility includes exact thresholds and preserves zero-area intersection semantics', async ({ page }) => {
  await ready(page);
  await page.locator('#target').evaluate(el => el.style.transform = 'translateY(50px)');
  await expect.poll(() => page.evaluate(() => window.__browserEvents.half.at(-1))).toBe(true);
  await expect.poll(() => page.evaluate(() => window.__browserEvents.full.at(-1))).toBe(false);

  await page.locator('#target').evaluate(el => el.style.transform = 'none');
  await expect.poll(() => page.evaluate(() => window.__browserEvents.full.at(-1))).toBe(true);
  await expect.poll(() => page.evaluate(() => window.__browserEvents.zeroSize.at(-1))).toBe(true);
});

test('visibility delivers every queued entry and ignores delivery after unmount', async ({ page }) => {
  await page.addInitScript(() => {
    const NativeObserver = window.IntersectionObserver;
    window.__observers = [];
    window.IntersectionObserver = class extends NativeObserver {
      constructor(callback, options) {
        super(callback, options);
        window.__observers.push({ callback, options, observer: this });
      }
    };
  });
  await ready(page);
  const delivered = await page.evaluate(() => {
    const { callback, observer } = window.__observers.find(item => item.options.threshold === 0.5);
    const target = document.querySelector('#target');
    const rect = target.getBoundingClientRect();
    const entry = (isIntersecting, intersectionRatio) => ({
      target, time: performance.now(), rootBounds: null,
      boundingClientRect: rect, intersectionRect: rect,
      isIntersecting, intersectionRatio,
    });
    window.__browserEvents.half = [];
    // Deterministic delivery of a batch to the actual Swift observer callback.
    callback([entry(true, 0.1), entry(true, 0.6), entry(true, 0.1), entry(false, 0), entry(true, 1)], observer);
    return window.__browserEvents.half;
  });
  expect(delivered).toEqual([false, true, false, false, true]);

  await page.locator('#unmount').click();
  await expect(page.locator('#target')).toHaveCount(0);
  const afterUnmount = await page.evaluate(() => {
    const { callback, observer } = window.__observers.find(item => item.options.threshold === 0.5);
    const before = window.__browserEvents.half.length;
    callback([{ isIntersecting: true, intersectionRatio: 1 }], observer);
    return window.__browserEvents.half.length - before;
  });
  expect(afterUnmount).toBe(0);
});

test('Enter sends once without a newline; Shift+Enter retains the browser newline', async ({ page }) => {
  await ready(page);
  const composer = page.locator('#composer');
  await composer.fill('hello');
  await composer.press('Enter');
  await expect(page.locator('#sent')).toHaveText('1');
  await expect(composer).toHaveValue('hello');

  await composer.press('Shift+Enter');
  await expect(page.locator('#sent')).toHaveText('1');
  await expect(composer).toHaveValue('hello\n');

  const repeatedCancelled = await composer.evaluate(el => {
    const event = new KeyboardEvent('keydown', { key: 'Enter', repeat: true, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  });
  expect(repeatedCancelled).toBe(true);
  await expect(page.locator('#sent')).toHaveText('1');
});

test('IME and legacy 229 reach the handler without triggering send', async ({ page }) => {
  await ready(page);
  const composer = page.locator('#composer');
  await composer.fill('draft');
  for (const legacy of [false, true]) {
    const cancelled = await composer.evaluate((el, legacy) => {
      const event = new KeyboardEvent('keydown', {
        key: 'Enter', isComposing: !legacy, bubbles: true, cancelable: true,
      });
      if (legacy) Object.defineProperty(event, 'keyCode', { value: 229 });
      el.dispatchEvent(event);
      return event.defaultPrevented;
    }, legacy);
    expect(cancelled).toBe(false);
  }
  await expect(page.locator('#sent')).toHaveText('0');
  expect(await page.evaluate(() => window.__browserEvents.composition)).toEqual([true, true]);

  const upCancelled = await composer.evaluate(el => {
    const event = new KeyboardEvent('keyup', { key: 'Escape', isComposing: true, bubbles: true, cancelable: true });
    el.dispatchEvent(event);
    return event.defaultPrevented;
  });
  expect(upCancelled).toBe(true);
  expect(await page.evaluate(() => window.__browserEvents.keyUpComposition.at(-1))).toBe(true);
});

test('empty and disabled sending do not submit', async ({ page }) => {
  await ready(page);
  const composer = page.locator('#composer');
  await composer.press('Enter');
  await expect(composer).toHaveValue('');
  await expect(page.locator('#sent')).toHaveText('0');
  await page.locator('#toggle-sending').click();
  await composer.fill('draft');
  await composer.press('Enter');
  await expect(composer).toHaveValue('draft');
  await expect(page.locator('#sent')).toHaveText('0');
});

test('cancellation after the Swift callback has returned is inert', async ({ page }) => {
  await ready(page);
  const late = page.locator('#late');
  await late.fill('hello');
  await late.press('Enter');
  await expect.poll(() => page.evaluate(() => window.__browserEvents.late.length)).toBe(1);
  await expect(late).toHaveValue('hello\n');
});
