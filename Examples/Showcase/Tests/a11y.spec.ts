import { test, expect } from "@playwright/test";
import AxeBuilder from "@axe-core/playwright";
import { ROUTES } from "./lib/routes.js";
import { THEMES } from "./lib/themes.js";
import { setTheme, waitForHydration } from "./lib/helpers.js";

for (const theme of THEMES) {
  for (const route of ROUTES) {
    test(`a11y: ${route.name} ${theme}`, async ({ page }) => {
      await setTheme(page, theme);
      await page.goto(route.path);
      await waitForHydration(page);

      const results = await new AxeBuilder({ page })
        .withTags(["wcag2a", "wcag2aa", "wcag21aa"])
        .analyze();

      expect(results.violations, JSON.stringify(results.violations, null, 2)).toEqual([]);
    });
  }
}
