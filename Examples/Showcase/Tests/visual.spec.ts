import { test, expect } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { THEMES } from "./lib/themes.js";
import { setTheme, waitForHydration } from "./lib/helpers.js";

for (const theme of THEMES) {
  for (const route of ROUTES) {
    test(`visual: ${route.name} ${theme}`, async ({ page }, testInfo) => {
      await setTheme(page, theme);
      await page.goto(route.path);
      await waitForHydration(page);
      await page.waitForTimeout(150);

      await expect(page).toHaveScreenshot(`${route.name}-${theme}.png`, {
        fullPage: true,
        maxDiffPixelRatio: 0.001,
        animations: "disabled",
      });
    });
  }
}
