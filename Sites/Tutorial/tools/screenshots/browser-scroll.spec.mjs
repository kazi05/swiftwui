import { test, expect } from '@playwright/test';

const row = (page, id) => page.locator(`[data-scroll-row="${id}"]`);

async function ready(page) {
  page.on('pageerror', error => { throw error; });
  await page.goto('/?scroll');
  await expect(page.locator('html')).toHaveAttribute('data-ready', 'true');
  await expect(page.locator('#scroll-timeline')).toBeAttached();
}

async function visibleTop(page) {
  return page.locator('#scroll-timeline').evaluate(element => {
    const rect = element.getBoundingClientRect();
    const viewportTop = window.visualViewport?.offsetTop ?? 0;
    return Math.max(rect.top + element.clientTop, viewportTop);
  });
}

async function settleLayout(page) {
  await page.evaluate(() => new Promise(resolve =>
    requestAnimationFrame(() => requestAnimationFrame(resolve))));
}

async function setElementScroll(page, position) {
  await page.locator('#scroll-timeline').evaluate((element, { left, top }) => {
    const previous = element.style.scrollBehavior;
    element.style.scrollBehavior = 'auto';
    if (left !== undefined) element.scrollLeft = left;
    if (top !== undefined) element.scrollTop = top;
    element.getBoundingClientRect();
    element.style.scrollBehavior = previous;
  }, position);
  await settleLayout(page);
}

async function placeElementRow(page, id, wantedOffset) {
  await page.evaluate(({ id, wantedOffset }) => {
    const element = document.querySelector('#scroll-timeline');
    const target = document.querySelector(`[data-scroll-row="${id}"]`);
    const viewportTop = window.visualViewport?.offsetTop ?? 0;
    const top = Math.max(element.getBoundingClientRect().top + element.clientTop, viewportTop);
    const previous = element.style.scrollBehavior;
    element.style.scrollBehavior = 'auto';
    element.scrollTop += target.getBoundingClientRect().top - top - wantedOffset;
    element.getBoundingClientRect();
    element.style.scrollBehavior = previous;
  }, { id, wantedOffset });
  await settleLayout(page);
}

async function placeWindowRow(page, id, wantedOffset) {
  await page.evaluate(({ id, wantedOffset }) => {
    const target = document.querySelector(`[data-scroll-row="${id}"]`);
    const top = window.visualViewport?.offsetTop ?? 0;
    const previous = document.documentElement.style.scrollBehavior;
    document.documentElement.style.scrollBehavior = 'auto';
    window.scrollBy(0, target.getBoundingClientRect().top - top - wantedOffset);
    document.documentElement.style.scrollBehavior = previous;
  }, { id, wantedOffset });
  await settleLayout(page);
}

async function elementRowOffset(page, id) {
  const [box, top] = await Promise.all([row(page, id).boundingBox(), visibleTop(page)]);
  return box.y - top;
}

async function windowRowOffset(page, id) {
  const box = await row(page, id).boundingBox();
  const top = await page.evaluate(() => window.visualViewport?.offsetTop ?? 0);
  return box.y - top;
}

async function readMetrics(page) {
  const previous = await page.locator('#scroll-metrics').getAttribute('data-revision');
  await page.getByRole('button', { name: 'Capture metrics' }).click();
  await expect(page.locator('#scroll-metrics')).not.toHaveAttribute('data-revision', previous);
  return page.locator('#scroll-metrics').evaluate(element => ({
    available: element.dataset.available === 'true',
    x: Number(element.dataset.x), y: Number(element.dataset.y),
    viewportWidth: Number(element.dataset.viewportWidth),
    viewportHeight: Number(element.dataset.viewportHeight),
    contentWidth: Number(element.dataset.contentWidth),
    contentHeight: Number(element.dataset.contentHeight),
  }));
}

async function readAnchorAfter(page, action) {
  const output = page.locator('#scroll-anchor');
  const previous = await output.getAttribute('data-revision');
  await action();
  await expect(output).not.toHaveAttribute('data-revision', previous);
  return output.evaluate(element => ({
    available: element.dataset.available === 'true',
    id: element.dataset.elementId ?? '',
    offset: Number(element.dataset.offset),
  }));
}

for (const anchoring of ['auto', 'none']) {
  test(`prepend preserves the actual row and offset with overflow-anchor ${anchoring}`, async ({ page }) => {
    await ready(page);
    if (anchoring === 'none') {
      await page.getByRole('button', { name: 'Toggle native anchoring' }).click();
      await expect(page.locator('#scroll-timeline')).toHaveCSS('overflow-anchor', 'none');
    }
    await placeElementRow(page, 100, 73.5);
    const before = await row(page, 100).boundingBox();

    await page.getByRole('button', { name: 'Prepend 50' }).click();

    await expect.poll(async () => {
      const after = await row(page, 100).boundingBox();
      return Math.abs(after.y - before.y);
    }).toBeLessThanOrEqual(1);
    await expect(page.locator('[data-scroll-row="-50"]')).toBeAttached();
  });
}

test('metrics exactly match element and document scrollports, including fractional offsets', async ({ page }) => {
  await ready(page);
  await setElementScroll(page, { left: 51.5, top: 73.5 });
  const elementExpected = await page.locator('#scroll-timeline').evaluate(element => ({
    x: element.scrollLeft, y: element.scrollTop,
    viewportWidth: element.clientWidth, viewportHeight: element.clientHeight,
    contentWidth: element.scrollWidth, contentHeight: element.scrollHeight,
    clientLeft: element.clientLeft, clientTop: element.clientTop,
  }));
  expect(elementExpected.clientLeft).toBe(17);
  expect(elementExpected.clientTop).toBe(7);
  const { clientLeft: _, clientTop: __, ...elementScrollport } = elementExpected;
  expect(await readMetrics(page)).toEqual({ available: true, ...elementScrollport });

  await page.getByRole('button', { name: 'Toggle scroll container' }).click();
  await expect(page.locator('#scroll-mode')).toHaveText('window');
  await page.evaluate(() => {
    const previous = document.documentElement.style.scrollBehavior;
    document.documentElement.style.scrollBehavior = 'auto';
    window.scrollTo(31.5, 91.5);
    document.documentElement.style.scrollBehavior = previous;
  });
  await settleLayout(page);
  const windowExpected = await page.evaluate(() => ({
    x: window.scrollX, y: window.scrollY,
    viewportWidth: document.documentElement.clientWidth,
    viewportHeight: document.documentElement.clientHeight,
    contentWidth: document.scrollingElement.scrollWidth,
    contentHeight: document.scrollingElement.scrollHeight,
  }));
  expect(await readMetrics(page)).toEqual({ available: true, ...windowExpected });
});

test('restore and explicit end preserve the current horizontal offset', async ({ page }) => {
  await ready(page);
  await setElementScroll(page, { left: 57.5 });
  await placeElementRow(page, 100, 73.5);
  const beforeRestore = await page.locator('#scroll-timeline').evaluate(element => element.scrollLeft);

  await page.getByRole('button', { name: 'Prepend 50' }).click();
  await expect(page.locator('[data-scroll-row="-50"]')).toBeAttached();
  expect(await page.locator('#scroll-timeline').evaluate(element => element.scrollLeft))
    .toBe(beforeRestore);

  await setElementScroll(page, { left: 91.5, top: 300 });
  const beforeEnd = await page.locator('#scroll-timeline').evaluate(element => element.scrollLeft);
  await page.getByRole('button', { name: 'Scroll to end', exact: true }).click();
  await expect.poll(() => page.locator('#scroll-timeline').evaluate(element =>
    Math.abs(element.scrollTop - (element.scrollHeight - element.clientHeight))))
    .toBeLessThanOrEqual(1);
  expect(await page.locator('#scroll-timeline').evaluate(element => element.scrollLeft))
    .toBe(beforeEnd);
});

test('capture ignores fully offscreen and zero-area candidates', async ({ page }) => {
  await ready(page);
  const offscreen = await readAnchorAfter(page, () =>
    page.getByRole('button', { name: 'Capture special anchors' }).click());
  expect(offscreen.available).toBe(false);

  await row(page, 0).evaluate(element => { element.style.display = 'none'; });
  const anchor = await readAnchorAfter(page, () =>
    page.getByRole('button', { name: 'Capture anchor' }).click());
  expect(anchor.available).toBe(true);
  expect(anchor.id).toBe('row-1');
  expect(anchor.offset).toBe(0);
});

test('capture accepts a partially hidden row taller than the scrollport', async ({ page }) => {
  await ready(page);
  await placeElementRow(page, 110, -43.25);
  const anchor = await readAnchorAfter(page, () =>
    page.getByRole('button', { name: 'Capture anchor' }).click());

  expect(anchor.available).toBe(true);
  expect(anchor.id).toBe('row-110');
  expect(anchor.offset).toBeCloseTo(-43.25, 0);
  const height = await row(page, 110).evaluate(element => element.getBoundingClientRect().height);
  const viewportHeight = await page.locator('#scroll-timeline').evaluate(element => element.clientHeight);
  expect(height).toBeGreaterThan(viewportHeight);
});

test('capture skips missing and duplicate IDs but accepts an odd literal ID', async ({ page }) => {
  await ready(page);
  await page.locator('[data-scroll-special="odd"]').evaluate(target => {
    const container = document.querySelector('#scroll-timeline');
    const previous = container.style.scrollBehavior;
    container.style.scrollBehavior = 'auto';
    container.scrollTop += target.getBoundingClientRect().top
      - (container.getBoundingClientRect().top + container.clientTop) - 100;
    container.getBoundingClientRect();
    container.style.scrollBehavior = previous;
  });
  await settleLayout(page);
  const anchor = await readAnchorAfter(page, () =>
    page.getByRole('button', { name: 'Capture special anchors' }).click());

  // The odd row is the last 40px of content, so the browser clamps its top to 200px
  // in the 240px client-height scrollport.
  expect(anchor).toEqual({ available: true, id: 'odd ] # : / 💬', offset: 200 });
});

for (const resize of [
  { name: 'media', changedRow: 120, targetRow: 140, delta: 137 },
  { name: 'ordinary row', changedRow: 90, targetRow: 100, delta: 63 },
]) {
  test(`a ${resize.name} resize before restore uses current anchor geometry`, async ({ page }) => {
    await ready(page);
    await placeElementRow(page, resize.targetRow, 82);
    const before = await row(page, resize.targetRow).boundingBox();
    const oldHeight = await row(page, resize.changedRow).evaluate(element => element.offsetHeight);

    await page.getByRole('button', { name: resize.name === 'media'
      ? 'Grow media and restore' : 'Grow row and restore' }).click();

    await expect.poll(async () => {
      const after = await row(page, resize.targetRow).boundingBox();
      return Math.abs(after.y - before.y);
    }).toBeLessThanOrEqual(1);
    expect(await row(page, resize.changedRow).evaluate(element => element.offsetHeight))
      .toBe(oldHeight + resize.delta);
  });
}

test('card to window and back preserves visible offsets in both directions', async ({ page }) => {
  await ready(page);
  await placeElementRow(page, 100, 78);
  const cardOffset = await elementRowOffset(page, 100);

  await page.getByRole('button', { name: 'Toggle scroll container' }).click();
  await expect(page.locator('#scroll-mode')).toHaveText('window');
  await expect.poll(() => windowRowOffset(page, 100)).toBeCloseTo(cardOffset, 0);

  await page.getByRole('button', { name: 'Toggle scroll container' }).click();
  await expect(page.locator('#scroll-mode')).toHaveText('card');
  await expect.poll(() => elementRowOffset(page, 100)).toBeCloseTo(cardOffset, 0);
});

test('append does not follow, while the explicit own-send action reaches the physical end', async ({ page }) => {
  await ready(page);
  await placeElementRow(page, 100, 60);
  const before = await page.locator('#scroll-timeline').evaluate(element => element.scrollTop);

  await page.getByRole('button', { name: 'Append' }).click();
  await expect(page.locator('[data-scroll-row="200"]')).toBeAttached();
  expect(await page.locator('#scroll-timeline').evaluate(element => element.scrollTop)).toBe(before);

  await page.getByRole('button', { name: 'Own send to end' }).click();
  await expect(page.locator('[data-scroll-row="201"]')).toBeAttached();
  await expect.poll(() => page.locator('#scroll-timeline').evaluate(element =>
    Math.abs(element.scrollTop - (element.scrollHeight - element.clientHeight))))
    .toBeLessThanOrEqual(1);
});

test('inner commands leave outer scroll unchanged and unavailable targets are one-shot no-ops', async ({ page }) => {
  await ready(page);
  await page.evaluate(() => window.scrollTo(0, 40));
  await setElementScroll(page, { top: 350 });
  const outerBefore = await page.evaluate(() => window.scrollY);

  await page.getByRole('button', { name: 'Scroll to end', exact: true }).click();
  await expect.poll(() => page.locator('#scroll-timeline').evaluate(element =>
    Math.abs(element.scrollTop - (element.scrollHeight - element.clientHeight))))
    .toBeLessThanOrEqual(1);
  expect(await page.evaluate(() => window.scrollY)).toBe(outerBefore);

  await setElementScroll(page, { top: 412 });
  await page.getByRole('button', { name: 'Toggle unavailable container' }).click();
  await expect(page.locator('#scroll-mode')).toHaveText('unavailable');
  const metrics = await readMetrics(page);
  expect(metrics.available).toBe(false);
  await page.getByRole('button', { name: 'Scroll to end', exact: true }).click();
  await page.evaluate(() => new Promise(resolve => queueMicrotask(resolve)));
  expect(await page.locator('#scroll-timeline').evaluate(element => element.scrollTop)).toBe(412);
  expect(await page.evaluate(() => window.scrollY)).toBe(outerBefore);

  await page.getByRole('button', { name: 'Toggle unavailable container' }).click();
  await expect(page.locator('#scroll-mode')).toHaveText('card');
  await settleLayout(page);
  expect(await page.locator('#scroll-timeline').evaluate(element => element.scrollTop)).toBe(412);
  expect(await page.evaluate(() => window.scrollY)).toBe(outerBefore);

  await page.getByRole('button', { name: 'Scroll to end', exact: true }).click();
  await expect.poll(() => page.locator('#scroll-timeline').evaluate(element =>
    Math.abs(element.scrollTop - (element.scrollHeight - element.clientHeight))))
    .toBeLessThanOrEqual(1);
  expect(await page.evaluate(() => window.scrollY)).toBe(outerBefore);
});

test('missing and ambiguous anchors do not move the selected container', async ({ page }) => {
  await ready(page);
  await setElementScroll(page, { top: 777 });
  for (const name of ['Restore missing anchor', 'Restore duplicate anchor']) {
    const before = await page.locator('#scroll-timeline').evaluate(element => element.scrollTop);
    await page.getByRole('button', { name }).click();
    await page.evaluate(() => new Promise(resolve => queueMicrotask(resolve)));
    expect(await page.locator('#scroll-timeline').evaluate(element => element.scrollTop)).toBe(before);
  }
});

test('a retained proxy from a removed reader cannot control its replacement', async ({ page }) => {
  await ready(page);
  await page.getByRole('button', { name: 'Retain proxy' }).click();
  await page.getByRole('button', { name: 'Toggle scroll reader' }).click();
  await expect(page.locator('#scroll-timeline')).toHaveCount(0);
  await page.getByRole('button', { name: 'Toggle scroll reader' }).click();
  await expect(page.locator('#scroll-timeline')).toBeAttached();
  await setElementScroll(page, { top: 321 });

  await page.getByRole('button', { name: 'Use retained proxy' }).click();
  await page.evaluate(() => new Promise(resolve => queueMicrotask(resolve)));

  expect(await page.locator('#scroll-timeline').evaluate(element => element.scrollTop)).toBe(321);
});

test('explicit instant overrides CSS smooth scrolling', async ({ page }) => {
  await ready(page);
  await setElementScroll(page, { top: 0 });
  await expect(page.locator('#scroll-timeline')).toHaveCSS('scroll-behavior', 'smooth');

  await page.getByRole('button', { name: 'Scroll to end', exact: true }).click();

  const position = await page.locator('#scroll-timeline').evaluate(element => ({
    y: element.scrollTop, end: element.scrollHeight - element.clientHeight,
  }));
  expect(Math.abs(position.y - position.end)).toBeLessThanOrEqual(1);
});

test('a smooth request becomes instant when reduced motion is active', async ({ page }) => {
  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.addInitScript(() => {
    window.__scrollCalls = [];
    const nativeScroll = Element.prototype.scroll;
    Element.prototype.scroll = function (...args) {
      if (this.id === 'scroll-timeline') window.__scrollCalls.push(args[0]);
      return nativeScroll.apply(this, args);
    };
  });
  await ready(page);
  await setElementScroll(page, { top: 0 });

  await page.getByRole('button', { name: 'Smooth scroll to end' }).click();

  await expect.poll(() => page.evaluate(() => window.__scrollCalls.at(-1)?.behavior)).toBe('instant');
  const position = await page.locator('#scroll-timeline').evaluate(element => ({
    y: element.scrollTop, end: element.scrollHeight - element.clientHeight,
  }));
  expect(Math.abs(position.y - position.end)).toBeLessThanOrEqual(1);
});

for (const viewport of ['controlled offset', 'fallback']) {
  test(`window capture uses the visual viewport ${viewport}`, async ({ page }) => {
    if (viewport === 'controlled offset') {
      await page.addInitScript(() => {
        const visualViewport = new EventTarget();
        Object.assign(visualViewport, {
          width: 720, height: 430, offsetTop: 67, offsetLeft: 9, scale: 1.5,
        });
        Object.defineProperty(window, 'visualViewport', {
          configurable: true, value: visualViewport,
        });
      });
    } else {
      await page.addInitScript(() => Object.defineProperty(window, 'visualViewport', {
        configurable: true, value: undefined,
      }));
    }
    await ready(page);
    await page.getByRole('button', { name: 'Toggle scroll container' }).click();
    await expect(page.locator('#scroll-mode')).toHaveText('window');
    await settleLayout(page);
    await placeWindowRow(page, 110, -43);

    const anchor = await readAnchorAfter(page, () =>
      page.getByRole('button', { name: 'Capture anchor' }).click());

    expect(anchor.available).toBe(true);
    expect(anchor.id).toBe('row-110');
    expect(anchor.offset).toBeCloseTo(-43, 0);
  });
}
