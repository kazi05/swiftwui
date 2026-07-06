// playwright.config.mjs
import { defineConfig } from '@playwright/test';

export default defineConfig({
  testMatch: 'smoke.spec.mjs',
  timeout: 60_000,
  use: {
    baseURL: process.env.SMOKE_BASE_URL ?? 'http://localhost:4174',
    viewport: { width: 1440, height: 900 },
  },
});
