import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import test from 'node:test';
import vm from 'node:vm';

// Run: node --experimental-vm-modules --test Tests/BootJS/boot-stall.test.mjs
// SourceTextModule is still behind Node's VM-modules flag on the supported runner.
const shimURL = new URL('../../Sources/SwiftWUIToolchain/Resources/swiftwui-boot.js', import.meta.url);

function deferred() {
  let resolve;
  const promise = new Promise((resume) => { resolve = resume; });
  return { promise, resolve };
}

function bootHarness(fetchPromise, activation = 'eager') {
  let now = 0;
  let headersReceived = false;
  const intervals = [];
  const timeouts = [];
  const activationListeners = new Map();
  let requests = 0;
  let idleCallback;
  let visibilityCallback;
  const root = {
    dataset: {},
    style: { setProperty() {}, removeProperty() {} },
  };
  const tag = { dataset: { wasm: '/app/App.wasm', entry: '/app/index.js', size: '100', delay: '300', activation } };
  const document = {
    documentElement: root,
    querySelector(selector) {
      if (selector === 'script[data-swui-boot-config]') return tag;
      return null;
    },
    querySelectorAll() { return []; },
    addEventListener() {},
    removeEventListener() {},
    body: { contains() { return false; }, appendChild() {},
      addEventListener(name, callback) { activationListeners.set(name, callback); },
      removeEventListener(name) { activationListeners.delete(name); } },
    activeElement: null,
  };
  const context = vm.createContext({
    document,
    window: { __swiftwui_dev: false,
      requestIdleCallback(callback) { idleCallback = callback; },
      IntersectionObserver: class { constructor(callback) { visibilityCallback = callback; } observe() {} disconnect() { visibilityCallback = null; } },
    },
    location: { href: 'http://example.test/', reload() {}, replace() {} },
    URL,
    URLSearchParams,
    performance: { now: () => now },
    fetch: () => { requests++; return fetchPromise; },
    console: { error() {} },
    setTimeout(callback, delay) { timeouts.push({ callback, due: now + delay, active: true }); return timeouts.length; },
    clearTimeout(id) { if (timeouts[id - 1]) timeouts[id - 1].active = false; },
    setInterval(callback) { intervals.push(callback); return intervals.length; },
    clearInterval() {},
    Promise,
    Map,
    ReadableStream,
    Response,
    Node: { ELEMENT_NODE: 1 },
  });
  return {
    context,
    root,
    advanceTo(value) { now = value; },
    tickIntervals() { intervals.forEach((callback) => callback()); },
    tickTimeouts() { for (const timer of timeouts) if (timer.active && timer.due <= now) { timer.active = false; timer.callback(); } },
    markHeadersReceived() { headersReceived = true; },
    headersReceived: () => headersReceived,
    requests: () => requests,
    activate() {
      if (activation === 'idle') idleCallback();
      else if (activation === 'visible') visibilityCallback([{ isIntersecting: true }]);
      else activationListeners.get('pointerdown')();
    },
    activationListeners,
  };
}

async function runShim(harness) {
  const source = await readFile(shimURL, 'utf8');
  const module = new vm.SourceTextModule(source, {
    context: harness.context,
    // Header-stall coverage deliberately never reaches init(); keep the
    // subsequent dynamic import pending instead of turning it into a failure.
    importModuleDynamically: () => new Promise(() => {}),
  });
  await module.link(() => { throw new Error('the shim has no static imports'); });
  await module.evaluate();
}

async function waitFor(check) {
  for (let attempt = 0; attempt < 20; attempt += 1) {
    if (check()) return;
    await new Promise((resume) => setTimeout(resume, 0));
  }
  assert.fail('timed out waiting for shim progress');
}

test('fails a wasm request that stalls before response headers', async () => {
  const request = deferred();
  const harness = bootHarness(request.promise);
  await runShim(harness);

  harness.advanceTo(30_001);
  harness.tickIntervals();
  assert.equal(harness.root.dataset.swuiBoot, 'failed');
});

test('a stalled interop module reaches visible failure before any WASM request', async () => {
  const harness = bootHarness(new Promise(() => {}));
  harness.context.window.__swiftwui_interop_ready = new Promise(() => {});
  await runShim(harness);
  harness.advanceTo(300); harness.tickTimeouts();
  assert.equal(harness.root.dataset.swuiBoot, 'downloading');
  harness.advanceTo(30_001); harness.tickTimeouts();
  await waitFor(() => harness.root.dataset.swuiBoot === 'failed');
  assert.equal(harness.requests(), 0);
});

for (const policy of ['idle', 'visible', 'interaction']) {
  test(`defers the actual WASM request until ${policy} activation`, async () => {
    const request = deferred();
    const harness = bootHarness(request.promise, policy);
    await runShim(harness);
    assert.equal(harness.requests(), 0);
    harness.advanceTo(60_000); harness.tickIntervals();
    assert.notEqual(harness.root.dataset.swuiBoot, 'failed');
    harness.activate();
    await waitFor(() => harness.requests() === 1);
    assert.equal(harness.activationListeners.size, 0);
  });
}

test('resets the stall deadline when response headers arrive', async () => {
  const request = deferred();
  const harness = bootHarness(request.promise);
  await runShim(harness);

  harness.advanceTo(29_000);
  request.resolve({
    ok: true,
    body: { getReader: () => {
      harness.markHeadersReceived();
      return { read: () => new Promise(() => {}) };
    } },
  });
  await waitFor(harness.headersReceived);

  harness.advanceTo(58_000);
  harness.tickIntervals();
  assert.notEqual(harness.root.dataset.swuiBoot, 'failed');

  harness.advanceTo(59_001);
  harness.tickIntervals();
  assert.equal(harness.root.dataset.swuiBoot, 'failed');
});
