import { test } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { waitForHydration } from "./lib/helpers.js";
import { promises as fs } from "node:fs";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const OUT_DIR = join(__dirname, "..", "Resources", "snapshots");

test.describe("@generate-snapshots", () => {
  for (const route of ROUTES) {
    test(`generate ${route.name} previews`, async ({ page }) => {
      await page.goto(route.path);
      await waitForHydration(page);
      await fs.mkdir(OUT_DIR, { recursive: true });

      const panes = await page.locator("[data-swui-preview-pane]").all();
      for (let i = 0; i < panes.length; i++) {
        const png = await panes[i].screenshot();
        const file = join(OUT_DIR, `${route.name}-step-${i + 1}.png`);
        await fs.writeFile(file, png);
      }
    });
  }
});
