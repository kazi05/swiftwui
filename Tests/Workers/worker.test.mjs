import assert from 'node:assert/strict';
import test from 'node:test';
import { Worker } from 'node:worker_threads';
import { once } from 'node:events';

test('typed worker protocol transfers buffers, reuses modules and reports errors', async () => {
  const worker = new Worker(new URL('./fixture.mjs', import.meta.url));
  try {
    const module = await WebAssembly.compile(Uint8Array.from([0,97,115,109,1,0,0,0]));
    worker.postMessage({ type: 'initialize', module });
    const buffer = Uint8Array.from([4]).buffer;
    const reply = once(worker, 'message');
    worker.postMessage({ type: 'request', id: 1, json: JSON.stringify({ value: 21 }), buffers: [buffer] }, [buffer]);
    assert.equal(buffer.byteLength, 0);
    const [result] = await reply;
    assert.deepEqual(JSON.parse(result.json), { answer: 42, compiled: true });
    assert.equal(new Uint8Array(result.buffers[0])[0], 5);
    const failure = once(worker, 'message');
    worker.postMessage({ type: 'request', id: 2, json: '{"fail":true}' });
    assert.match((await failure)[0].error, /expected failure/);
  } finally { await worker.terminate(); }
});

test('cancellation suppresses an obsolete reply while another request completes', async () => {
  const worker = new Worker(new URL('./fixture.mjs', import.meta.url));
  try {
    const received = []; worker.on('message', value => received.push(value));
    worker.postMessage({ type: 'request', id: 1, json: '{"value":1,"delay":100}' });
    worker.postMessage({ type: 'cancel', id: 1 });
    const reply = once(worker, 'message');
    worker.postMessage({ type: 'request', id: 2, json: '{"value":2}' });
    assert.equal((await reply)[0].id, 2);
    await new Promise(resolve => setTimeout(resolve, 150));
    assert.deepEqual(received.map(value => value.id), [2]);
  } finally { await worker.terminate(); }
});
