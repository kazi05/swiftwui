import { test, expect } from '@playwright/test';

// Each spy observes the real browser primitive and delegates unchanged. A
// regression that buffers a file or substitutes a byte copy fails these probes.
async function ready(page) {
  page.on('pageerror', error => { throw error; });
  await page.addInitScript(() => {
    const probe = window.__blobProbe = {
      reads: [], slices: [], creates: [], revokes: [], requests: [], responses: [],
    };
    const read = Blob.prototype.arrayBuffer;
    const text = Blob.prototype.text;
    const slice = Blob.prototype.slice;
    Blob.prototype.arrayBuffer = function () {
      probe.reads.push({ method: 'arrayBuffer', size: this.size });
      return read.call(this);
    };
    Blob.prototype.text = function () {
      probe.reads.push({ method: 'text', size: this.size });
      return text.call(this);
    };
    Blob.prototype.slice = function (...args) {
      const result = slice.apply(this, args);
      probe.slices.push({ start: args[0], end: args[1], type: args[2], size: result.size });
      probe.lastSlice = result;
      return result;
    };
    const create = URL.createObjectURL;
    const revoke = URL.revokeObjectURL;
    URL.createObjectURL = function (blob) {
      const url = create.call(this, blob);
      probe.creates.push({ url, original: blob === probe.file });
      return url;
    };
    URL.revokeObjectURL = function (url) {
      probe.revokes.push(url);
      return revoke.call(this, url);
    };
    const nativeFetch = window.fetch;
    window.fetch = async function (url, options) {
      if (String(url).startsWith('/__blob/')) {
        probe.requests.push({
          path: String(url), original: options.body === probe.file,
          originalSlice: options.body === probe.lastSlice,
          bodyType: options.body?.constructor.name, method: options.method,
          credentials: options.credentials,
          contentType: new Headers(options.headers).get('Content-Type'),
        });
      }
      const response = await nativeFetch.call(this, url, options);
      if (String(url).startsWith('/__blob/')) probe.responses.push(String(url));
      return response;
    };
    document.addEventListener('change', event => {
      if (event.target.id === 'blob-file') probe.file = event.target.files[0];
    }, true);
  });
  await page.goto('/');
  await expect(page.locator('html')).toHaveAttribute('data-ready', 'true');
  await page.locator('#blob-file').setInputFiles({
    name: 'selected.bin', mimeType: 'application/octet-stream', buffer: Buffer.from('0123456789'),
  });
  await expect(page.locator('#blob-status')).toHaveText('ready');
}

test('native file wrapping, URLs and upload avoid full reads and retain File identity', async ({ page }) => {
  await ready(page);
  await expect(page.locator('#blob-result')).toHaveText('10:application/octet-stream');
  const url = await page.locator('#blob-image').getAttribute('src');
  expect(url).toMatch(/^blob:/);
  for (const selector of ['#blob-video', '#blob-audio']) {
    await expect(page.locator(selector)).toHaveAttribute('src', url);
  }
  await expect(page.locator('#blob-link')).toHaveAttribute('href', url);
  expect(await page.evaluate(() => window.__blobProbe.reads)).toEqual([]);
  expect(await page.evaluate(() => window.__blobProbe.creates.map(x => x.original))).toEqual([true]);

  await page.locator('#blob-file').evaluate(input => { input.value = ''; });
  await page.locator('#blob-revoke').click();
  await expect(page.locator('#blob-image')).not.toHaveAttribute('src');
  await page.locator('#blob-upload').click();
  await expect(page.locator('#blob-status')).toHaveText('uploaded:200');
  await expect(page.locator('#blob-result')).toHaveText('0123456789');
  expect(await page.evaluate(() => window.__blobProbe.requests)).toEqual([{
    path: '/__blob/echo', original: true, originalSlice: false, bodyType: 'File', method: 'PUT',
    credentials: 'same-origin', contentType: 'application/octet-stream',
  }]);
  expect(await page.evaluate(() => window.__blobProbe.reads)).toEqual([]);
  expect(await page.evaluate(() => window.__blobProbe.revokes)).toEqual([url]);
});

test('explicit data reads only the native slice', async ({ page }) => {
  await ready(page);
  await page.locator('#blob-read').click();
  await expect(page.locator('#blob-status')).toHaveText('read');
  await expect(page.locator('#blob-result')).toHaveText('23456');
  expect(await page.evaluate(() => window.__blobProbe.slices)).toEqual([
    { start: 2, end: 7, type: 'application/octet-stream', size: 5 },
  ]);
  expect(await page.evaluate(() => window.__blobProbe.reads)).toEqual([
    { method: 'arrayBuffer', size: 5 },
  ]);
});

test('native slicing, URL creation and upload preserve the sliced Blob without reading it', async ({ page }) => {
  await ready(page);
  await page.locator('#blob-native-slice').click();
  await expect(page.locator('#blob-status')).toHaveText('uploaded:200');
  await expect(page.locator('#blob-result')).toHaveText('23456');
  expect(await page.evaluate(() => window.__blobProbe.requests.at(-1).originalSlice)).toBe(true);
  expect(await page.evaluate(() => window.__blobProbe.reads)).toEqual([]);
  expect(await page.evaluate(() => window.__blobProbe.creates.length)).toBe(2);
  expect(await page.evaluate(() => window.__blobProbe.revokes.length)).toBe(1);
});

test('resource and String replacement respects casing and localized precedence', async ({ page }) => {
  await ready(page);
  const image = page.locator('#blob-image');
  const url = await image.getAttribute('src');
  await page.locator('#blob-plain').click();
  await expect(image).toHaveAttribute('src', '/__blob/plain-image');
  await page.locator('#blob-resource').click();
  await expect(image).toHaveAttribute('src', url);
  await page.locator('#blob-upper').click();
  await expect(image).toHaveAttribute('src', '/__blob/uppercase-image');
  await page.locator('#blob-after-upper').click();
  await expect(image).toHaveAttribute('src', url);
  await page.locator('#blob-localized').click();
  await expect(image).toHaveAttribute('src', '/__blob/localized-image');
});

test('shared consumers and distinct URLs have independent ownership', async ({ page }) => {
  await ready(page);
  const shared = await page.locator('#blob-image').getAttribute('src');
  await page.locator('#blob-independent-create').click();
  const independent = await page.locator('#blob-independent').getAttribute('src');
  expect(independent).toMatch(/^blob:/);
  expect(independent).not.toBe(shared);
  await page.locator('#blob-unmount-image').click();
  await expect(page.locator('#blob-image')).toHaveCount(0);
  await expect(page.locator('#blob-video')).toHaveAttribute('src', shared);
  expect(await page.evaluate(() => window.__blobProbe.revokes)).toEqual([]);
  await page.locator('#blob-revoke').click();
  for (const selector of ['#blob-video', '#blob-audio']) {
    await expect(page.locator(selector)).not.toHaveAttribute('src');
  }
  await expect(page.locator('#blob-link')).not.toHaveAttribute('href');
  await expect(page.locator('#blob-independent')).toHaveAttribute('src', independent);
  expect(await page.evaluate(() => window.__blobProbe.revokes)).toEqual([shared]);
  await page.locator('#blob-clear').click();
  await expect.poll(() => page.evaluate(() => window.__blobProbe.revokes)).toEqual([shared, independent]);
});

test('byte-backed uploads send just the range and existing Data fetch remains intact', async ({ page }) => {
  await ready(page);
  await page.locator('#blob-bytes').click();
  await expect(page.locator('#blob-status')).toHaveText('uploaded:200');
  await expect(page.locator('#blob-result')).toHaveText('DEFG');
  expect(await page.evaluate(() => window.__blobProbe.requests.at(-1).contentType)).toBe('text/plain');
  await page.locator('#blob-data').click();
  await expect(page.locator('#blob-result')).toHaveText('old-data');
  await expect(page.locator('#blob-status')).toHaveText('uploaded:200');
  expect(await page.evaluate(() => window.__blobProbe.reads)).toEqual([]);
});

test('pre-cancelled uploads do not dispatch fetch', async ({ page }) => {
  await ready(page);
  await page.locator('#blob-pre-cancel').click();
  await expect(page.locator('#blob-status')).toHaveText('cancelled');
  expect(await page.evaluate(() => window.__blobProbe.requests)).toEqual([]);
});

test('cancellation aborts an upload waiting for response headers', async ({ page }) => {
  await ready(page);
  await page.locator('#blob-slow').click();
  await expect.poll(() => page.evaluate(() => window.__blobProbe.requests.length)).toBe(1);
  await page.locator('#blob-cancel').click();
  await expect(page.locator('#blob-status')).toHaveText('cancelled');
});

test('cancellation aborts the response body read after headers arrive', async ({ page }) => {
  await ready(page);
  await page.locator('#blob-slow-body').click();
  await expect.poll(() => page.evaluate(() => window.__blobProbe.responses)).toEqual(['/__blob/slow-body']);
  await expect(page.locator('#blob-status')).toHaveText('pending');
  await page.locator('#blob-cancel').click();
  await expect(page.locator('#blob-status')).toHaveText('cancelled');
});

for (const [button, name] of [['#blob-timeout', 'headers'], ['#blob-timeout-body', 'response body']]) {
  test(`timeout aborts the upload while waiting for ${name}`, async ({ page }) => {
    await ready(page);
    await page.locator(button).click();
    await expect(page.locator('#blob-status')).toHaveText('timeout');
    if (name === 'response body') {
      expect(await page.evaluate(() => window.__blobProbe.responses)).toEqual(['/__blob/slow-body']);
    }
  });
}
