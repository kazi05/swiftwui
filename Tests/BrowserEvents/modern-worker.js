import { serveWorker } from '/swiftwui-worker.js';
serveWorker(input => ({ value: input.value * 2 }));
