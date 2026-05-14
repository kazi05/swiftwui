import { test, expect } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { waitForHydration } from "./lib/helpers.js";

for (const route of ROUTES) {
  test(`preview: ${route.name}`, async ({ page }) => {
    await page.goto(route.path);
    await waitForHydration(page);

    const panes = page.locator("[data-swui-preview-pane]");
    const count = await panes.count();
    test.skip(count === 0, `${route.name} has no preview panes`);

    for (let i = 0; i < count; i++) {
      await expect(panes.nth(i)).toHaveScreenshot(`${route.name}-step-${i + 1}.png`, {
        maxDiffPixelRatio: 0.001,
        animations: "disabled",
      });
    }
  });
}
