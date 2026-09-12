import { parentPort } from 'node:worker_threads';
import { serveWorker, workerResult } from '../../Sources/SwiftWUIToolchain/Resources/swiftwui-worker.js';
const listeners = new Map();
const scope = {
  addEventListener(_, listener) { const fn = data => listener({ data }); listeners.set(listener, fn); parentPort.on('message', fn); },
  removeEventListener(_, listener) { parentPort.off('message', listeners.get(listener)); },
  postMessage: (value, transfers) => parentPort.postMessage(value, transfers),
};
serveWorker(async (request, { signal, buffers, compiledModule }) => {
  if (request.fail) throw new Error('expected failure');
  if (request.delay) await new Promise(resolve => { const timer = setTimeout(resolve, request.delay); signal.addEventListener('abort', () => { clearTimeout(timer); resolve(); }); });
  if (buffers.length) new Uint8Array(buffers[0])[0] += 1;
  return workerResult({ answer: request.value * 2, compiled: compiledModule instanceof WebAssembly.Module }, buffers);
}, scope);
