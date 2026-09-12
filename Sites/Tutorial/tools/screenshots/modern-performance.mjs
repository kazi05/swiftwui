#!/usr/bin/env node
import { chromium } from '@playwright/test';
import { mkdir, writeFile } from 'node:fs/promises';
import { cpus, loadavg, platform, release } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const scriptDirectory = path.dirname(fileURLToPath(import.meta.url));
const repository = path.resolve(scriptDirectory, '../../../..');
const targetURL = process.env.BROWSER_EVENTS_BASE_URL ?? 'http://127.0.0.1:4181';
const outputPath = process.env.SWIFTWUI_PERFORMANCE_OUTPUT
  ?? path.join(repository, 'Documentation/Measurements/browser-performance-2026-09-12.json');

function percentile(values, fraction) {
  if (values.length === 0) return 0;
  const sorted = values.toSorted((left, right) => left - right);
  return sorted[Math.min(sorted.length - 1, Math.ceil(sorted.length * fraction) - 1)];
}

function summarize(values) {
  const rounded = value => Math.round(value * 1000) / 1000;
  return {
    samples: values.length,
    minMs: rounded(Math.min(...values)),
    medianMs: rounded(percentile(values, 0.5)),
    p95Ms: rounded(percentile(values, 0.95)),
    maxMs: rounded(Math.max(...values)),
    totalMs: rounded(values.reduce((total, value) => total + value, 0)),
  };
}

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage({ viewport: { width: 800, height: 600 } });
const pageErrors = [];
page.on('pageerror', error => pageErrors.push(error.message));

try {
  await page.goto(new URL('/modern', targetURL).href, { waitUntil: 'load' });
  await page.locator('html[data-ready="true"]').waitFor();
  await page.locator('[data-row]').first().waitFor();

  const virtualCollection = await page.evaluate(async () => {
    const scrollport = document.querySelector('#virtual-list > div');
    if (!(scrollport instanceof HTMLElement)) throw new Error('Virtual collection scrollport not found');
    const rowValues = () => [...scrollport.querySelectorAll('[data-row]')]
      .map(row => Number(row.getAttribute('data-row')));
    const nextFrame = () => new Promise(resolve => requestAnimationFrame(resolve));
    const initialRows = rowValues();
    let minimumDOMRows = initialRows.length;
    let maximumDOMRows = initialRows.length;
    const observeCount = () => {
      const count = rowValues().length;
      minimumDOMRows = Math.min(minimumDOMRows, count);
      maximumDOMRows = Math.max(maximumDOMRows, count);
    };
    const observer = new MutationObserver(observeCount);
    observer.observe(scrollport, { childList: true, subtree: true });

    const frameIntervals = [];
    let previousFrame = await nextFrame();
    const maximumScroll = scrollport.scrollHeight - scrollport.clientHeight;
    const stepsPerSweep = 48;
    for (const direction of [1, -1, 1]) {
      for (let step = 1; step <= stepsPerSweep; step += 1) {
        const fraction = step / stepsPerSweep;
        scrollport.scrollTop = direction === 1
          ? maximumScroll * fraction
          : maximumScroll * (1 - fraction);
        const frame = await nextFrame();
        frameIntervals.push(frame - previousFrame);
        previousFrame = frame;
        observeCount();
      }
    }
    await nextFrame();
    await nextFrame();
    observeCount();
    observer.disconnect();
    const finalRows = rowValues();
    return {
      configuredItemCount: 10_000,
      scrollHeightPx: scrollport.scrollHeight,
      viewportHeightPx: scrollport.clientHeight,
      initialRenderedRows: initialRows.length,
      initialRenderedRange: [Math.min(...initialRows), Math.max(...initialRows)],
      minimumRenderedRows: minimumDOMRows,
      maximumRenderedRows: maximumDOMRows,
      finalRenderedRows: finalRows.length,
      finalRenderedRange: [Math.min(...finalRows), Math.max(...finalRows)],
      frameIntervalsMs: frameIntervals,
      intervalsOverTwoFrameBudgets: frameIntervals.filter(value => value > (2 * 1000 / 60)).length,
      scrollSweeps: 3,
      stepsPerSweep,
    };
  });

  const cpu = await page.evaluate(async () => {
    function cpuWork(iterations) {
      let state = 0x12345678;
      for (let index = 0; index < iterations; index += 1) {
        state = (Math.imul(state ^ index, 1_664_525) + 1_013_904_223) | 0;
        state ^= state >>> 13;
      }
      return state >>> 0;
    }

    const iterations = 8_000_000;
    const repetitions = 5;
    const heartbeatPeriodMs = 8;
    const delay = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

    async function measuredWithHeartbeat(operation) {
      const gaps = [];
      let previous = performance.now();
      const timer = setInterval(() => {
        const now = performance.now();
        gaps.push(now - previous);
        previous = now;
      }, heartbeatPeriodMs);
      await delay(heartbeatPeriodMs * 4);
      const probeScheduled = performance.now();
      const probe = new Promise(resolve => setTimeout(() => resolve(performance.now()), 0));
      const started = performance.now();
      const value = await operation();
      const ended = performance.now();
      const probeObserved = await probe;
      await delay(heartbeatPeriodMs * 4);
      clearInterval(timer);
      const maximumGap = Math.max(...gaps);
      return {
        value,
        totalWallTimeMs: ended - started,
        zeroDelayHeartbeatLatencyMs: probeObserved - probeScheduled,
        maximumHeartbeatGapMs: maximumGap,
        estimatedBlockedHeartbeatMs: Math.max(0, maximumGap - heartbeatPeriodMs),
        heartbeatGapsMs: gaps,
      };
    }

    const mainThread = await measuredWithHeartbeat(async () => {
      const durationsMs = [];
      const checksums = [];
      for (let repeat = 0; repeat < repetitions; repeat += 1) {
        const started = performance.now();
        checksums.push(cpuWork(iterations));
        durationsMs.push(performance.now() - started);
      }
      return { durationsMs, checksums };
    });

    const helperURL = new URL('/swiftwui-worker.js', location.href).href;
    const workerSource = `
      import { serveWorker } from ${JSON.stringify(helperURL)};
      ${cpuWork.toString()}
      serveWorker(({ iterations }) => {
        const started = performance.now();
        const checksum = cpuWork(iterations);
        return { checksum, computeTimeMs: performance.now() - started };
      });
    `;
    const blobURL = URL.createObjectURL(new Blob([workerSource], { type: 'text/javascript' }));
    const worker = new Worker(blobURL, { type: 'module' });
    let nextID = 0;
    const pending = new Map();
    const receive = ({ data }) => {
      const request = pending.get(data.id);
      if (!request) return;
      pending.delete(data.id);
      if (data.type === 'result') request.resolve(JSON.parse(data.json));
      else request.reject(new Error(data.error ?? `Unexpected worker response: ${data.type}`));
    };
    worker.addEventListener('message', receive);
    const callWorker = input => new Promise((resolve, reject) => {
      const id = ++nextID;
      pending.set(id, { resolve, reject });
      worker.postMessage({ type: 'request', id, json: JSON.stringify(input), buffers: [] });
    });

    let moduleWorker;
    try {
      moduleWorker = await measuredWithHeartbeat(async () => {
        const roundTripDurationsMs = [];
        const computeDurationsMs = [];
        const checksums = [];
        for (let repeat = 0; repeat < repetitions; repeat += 1) {
          const started = performance.now();
          const result = await callWorker({ iterations });
          roundTripDurationsMs.push(performance.now() - started);
          computeDurationsMs.push(result.computeTimeMs);
          checksums.push(result.checksum);
        }
        return { roundTripDurationsMs, computeDurationsMs, checksums };
      });
    } finally {
      worker.removeEventListener('message', receive);
      worker.terminate();
      URL.revokeObjectURL(blobURL);
    }

    return { iterations, repetitions, heartbeatPeriodMs, mainThread, moduleWorker };
  });

  const mainChecksums = cpu.mainThread.value.checksums;
  const workerChecksums = cpu.moduleWorker.value.checksums;
  if (new Set([...mainChecksums, ...workerChecksums]).size !== 1) {
    throw new Error(`CPU result mismatch: main=${mainChecksums}, worker=${workerChecksums}`);
  }
  if (virtualCollection.finalRenderedRange[1] < 9_950) {
    throw new Error(`Virtual collection did not reach its final window: ${virtualCollection.finalRenderedRange}`);
  }
  if (pageErrors.length > 0) throw new Error(`Page errors: ${pageErrors.join('; ')}`);

  const result = {
    schemaVersion: 1,
    capturedAt: new Date().toISOString(),
    scope: 'Existing compiled Tests/BrowserEvents /modern fixture in headless Chromium',
    observationCaveat: 'Local, non-isolated observation while other build agents could consume CPU; use the script in a quiet controlled environment for release comparisons.',
    host: {
      platform: platform(),
      release: release(),
      logicalCPUCount: cpus().length,
      loadAverageAtCompletion: loadavg(),
    },
    browser: {
      name: 'chromium',
      version: browser.version(),
      headless: true,
      viewport: { width: 800, height: 600 },
    },
    virtualCollection: {
      ...virtualCollection,
      frameIntervalsMs: summarize(virtualCollection.frameIntervalsMs),
    },
    cpuOffload: {
      iterationsPerRepeat: cpu.iterations,
      repetitions: cpu.repetitions,
      checksum: mainChecksums[0],
      heartbeatPeriodMs: cpu.heartbeatPeriodMs,
      mainThread: {
        totalWallTimeMs: cpu.mainThread.totalWallTimeMs,
        computeDurationsMs: summarize(cpu.mainThread.value.durationsMs),
        zeroDelayHeartbeatLatencyMs: cpu.mainThread.zeroDelayHeartbeatLatencyMs,
        maximumHeartbeatGapMs: cpu.mainThread.maximumHeartbeatGapMs,
        estimatedBlockedHeartbeatMs: cpu.mainThread.estimatedBlockedHeartbeatMs,
        heartbeatGapsMs: summarize(cpu.mainThread.heartbeatGapsMs),
      },
      moduleWorker: {
        totalWallTimeMs: cpu.moduleWorker.totalWallTimeMs,
        workerComputeDurationsMs: summarize(cpu.moduleWorker.value.computeDurationsMs),
        roundTripDurationsMs: summarize(cpu.moduleWorker.value.roundTripDurationsMs),
        zeroDelayHeartbeatLatencyMs: cpu.moduleWorker.zeroDelayHeartbeatLatencyMs,
        maximumHeartbeatGapMs: cpu.moduleWorker.maximumHeartbeatGapMs,
        estimatedBlockedHeartbeatMs: cpu.moduleWorker.estimatedBlockedHeartbeatMs,
        heartbeatGapsMs: summarize(cpu.moduleWorker.heartbeatGapsMs),
      },
    },
  };

  await mkdir(path.dirname(outputPath), { recursive: true });
  await writeFile(outputPath, `${JSON.stringify(result, null, 2)}\n`);
  process.stdout.write(`${JSON.stringify(result, null, 2)}\n`);
} finally {
  await page.close();
  await browser.close();
}
