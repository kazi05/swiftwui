import { defineConfig } from '@playwright/test';

// Uses the repository's existing Playwright installation; the fixture is a
// small separate WASM package, independent of the tutorial site's content.
export default defineConfig({
  testMatch: ['browser-events.spec.mjs', 'browser-blobs.spec.mjs', 'browser-observer-roots.spec.mjs',
    'browser-viewport.spec.mjs', 'browser-scroll.spec.mjs', 'browser-modern.spec.mjs'],
  timeout: 30_000,
  workers: 1,
  use: {
    baseURL: process.env.BROWSER_EVENTS_BASE_URL ?? 'http://127.0.0.1:4175',
    viewport: { width: 800, height: 600 },
  },
});
