import { defineConfig, devices } from "@playwright/test";

const PORT = Number(process.env.SHOWCASE_TEST_PORT ?? 4173);

// The Showcase dev server is the unified `swiftwui` CLI, invoked from the
// SwiftWUI repo root (it resolves Examples/Showcase via --target Showcase).
// There is no npm script wrapping it, so we shell out directly with `cwd`
// pointed three levels up (tests/ → Showcase/ → Examples/ → repo root).
const REPO_ROOT = "../../..";

export default defineConfig({
  testDir: ".",
  fullyParallel: false,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  workers: 1,
  reporter: process.env.CI ? "github" : "list",
  use: {
    baseURL: `http://localhost:${PORT}`,
    trace: "retain-on-failure",
  },
  projects: [
    {
      name: "chromium-desktop",
      use: { ...devices["Desktop Chrome"], viewport: { width: 1280, height: 800 } },
    },
    {
      name: "chromium-mobile",
      use: { ...devices["iPhone 14"], browserName: "chromium" },
    },
  ],
  webServer: {
    command: `swift run swiftwui dev --target Showcase --port ${PORT}`,
    cwd: REPO_ROOT,
    port: PORT,
    reuseExistingServer: !process.env.CI,
    timeout: 90_000,
  },
  snapshotPathTemplate: "{testDir}/__screenshots__/{testFilePath}/{arg}{ext}",
});
