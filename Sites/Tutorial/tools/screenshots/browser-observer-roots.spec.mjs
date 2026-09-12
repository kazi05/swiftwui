import { test, expect } from '@playwright/test';

test.beforeEach(async ({ page }) => {
  await page.addInitScript(() => {
    window.__rootProbe = { clipped: [], margin: [], scoped: [], offscreenRoot: [],
      offscreenViewport: [], exiting: [] };
    window.__rootObservers = [];
    const Native = window.IntersectionObserver;
    window.IntersectionObserver = class extends Native {
      constructor(callback, options) {
        super(callback, options);
        this.probe = {
          options, target: null, disconnected: false,
          pendingRecords: [], takeRecordsCalls: 0, takenRecords: 0,
        };
        window.__rootObservers.push(this.probe);
      }
      observe(target) { this.probe.target = target; super.observe(target); }
      disconnect() { this.probe.disconnected = true; super.disconnect(); }
      takeRecords() {
        const records = [...this.probe.pendingRecords, ...super.takeRecords()];
        this.probe.pendingRecords = [];
        this.probe.takeRecordsCalls += 1;
        this.probe.takenRecords += records.length;
        return records;
      }
    };
  });
  await page.goto('/');
  await expect(page.locator('#configured-target')).toBeAttached();
});

test('real clipping root uses the exact mounted ancestor', async ({ page }) => {
  await expect.poll(() => page.evaluate(() => window.__rootProbe.clipped.at(-1))).toBe(false);
  expect(await page.evaluate(() => window.__rootObservers.find(row => row.target?.id === 'configured-target')
    .options.root === document.querySelector('#configured-clip'))).toBe(true);
  await page.locator('#configured-target').evaluate(target => target.style.transform = 'translateY(40px)');
  await expect.poll(() => page.evaluate(() => window.__rootProbe.clipped.at(-1))).toBe(true);
});

test('negative viewport margins shrink the root and changing them rebinds', async ({ page }) => {
  await expect.poll(() => page.evaluate(() => window.__rootProbe.margin.at(-1))).toBe(false);
  await page.locator('#root-margin-toggle').click();
  await expect.poll(() => page.evaluate(() => window.__rootProbe.margin.at(-1))).toBe(true);
  expect(await page.evaluate(() => window.__rootObservers.filter(row =>
    row.target?.id === 'configured-margin' && !row.disconnected).length)).toBe(1);
});

test('offscreen explicit root keeps native ancestor semantics', async ({ page }) => {
  await expect.poll(() => page.evaluate(() => window.__rootProbe.offscreenRoot.at(-1))).toBe(true);
  await expect.poll(() => page.evaluate(() => window.__rootProbe.offscreenViewport.at(-1))).toBe(false);
});

test('nearest marker updates and an unresolved root creates no observer', async ({ page }) => {
  await expect.poll(() => page.evaluate(() => window.__rootProbe.scoped.at(-1))).toBe(false);
  await page.locator('#root-marker-toggle').click();
  await expect.poll(() => page.evaluate(() => window.__rootProbe.scoped.at(-1))).toBe(true);
  expect(await page.evaluate(() => window.__rootObservers.findLast(row =>
    row.target?.id === 'scope-target' && !row.disconnected).options.root === document.querySelector('#scope-outer'))).toBe(true);
  const before = await page.evaluate(() => window.__rootObservers.length);
  await page.locator('#root-missing-toggle').click();
  await expect.poll(() => page.evaluate(() => window.__rootProbe.scoped.at(-1))).toBe(false);
  expect(await page.evaluate(() => window.__rootObservers.length)).toBe(before);
  expect(await page.evaluate(() => window.__rootObservers.filter(row =>
    row.target?.id === 'scope-target' && !row.disconnected).length)).toBe(0);
  await page.locator('#root-missing-toggle').click();
  await expect.poll(() => page.evaluate(() => window.__rootProbe.scoped.at(-1))).toBe(true);
});

test('reinserted subtree binds the new exact host', async ({ page }) => {
  await expect.poll(() => page.evaluate(() => window.__rootProbe.scoped.length)).toBeGreaterThan(0);
  await page.evaluate(() => { window.__oldRoot = document.querySelector('#scope-inner'); });
  await page.locator('#root-mount-toggle').click();
  await expect(page.locator('#scope-target')).toHaveCount(0);
  await page.locator('#root-mount-toggle').click();
  await expect.poll(() => page.evaluate(() => {
    const active = window.__rootObservers.findLast(row => row.target?.id === 'scope-target' && !row.disconnected);
    return !!active && active.options.root === document.querySelector('#scope-inner')
      && active.options.root !== window.__oldRoot;
  })).toBe(true);
});

test('logical exit drains pending records and disconnects while the physical ghost remains', async ({ page }) => {
  await expect.poll(() => page.evaluate(() => window.__rootProbe.exiting.length)).toBeGreaterThan(0);
  await page.evaluate(() => {
    const observer = window.__rootObservers.findLast(row =>
      row.target?.id === 'configured-exiting' && !row.disconnected);
    window.__exitObserver = observer;
    observer.pendingRecords.push({ isIntersecting: true, intersectionRatio: 1 });
  });
  await page.locator('#root-exit').evaluate(button => button.click());
  await expect.poll(() => page.evaluate(() => {
    const observer = window.__exitObserver;
    return [observer?.disconnected, observer?.takeRecordsCalls,
      observer?.takenRecords, observer?.pendingRecords.length];
  })).toEqual([true, 1, 1, 0]);
  await expect(page.locator('#configured-exiting')).toHaveCount(1);
  const count = await page.evaluate(() => window.__rootProbe.exiting.length);
  await page.locator('#configured-exiting').evaluate(target => target.style.transform = 'translateY(200px)');
  await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
  expect(await page.evaluate(() => window.__rootProbe.exiting.length)).toBe(count);
  await page.evaluate(() => document.getAnimations().forEach(animation => animation.finish()));
  await expect(page.locator('#configured-exiting')).toHaveCount(0);
});
