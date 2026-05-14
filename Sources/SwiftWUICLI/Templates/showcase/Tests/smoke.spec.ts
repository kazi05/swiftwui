import { test, expect } from "@playwright/test";
import { ROUTES } from "./lib/routes.js";
import { waitForHydration } from "./lib/helpers.js";

for (const route of ROUTES) {
  test(`smoke: ${route.name} (${route.path})`, async ({ page }) => {
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(`pageerror: ${e.message}`));
    page.on("console", (msg) => {
      if (msg.type() === "error") errors.push(`console.error: ${msg.text()}`);
    });

    const response = await page.goto(route.path);
    expect(response, `${route.path} returned no response`).not.toBeNull();
    expect(response!.status(), `${route.path} not 200`).toBe(200);

    await waitForHydration(page);
    await expect(page.locator("h1").first()).toBeVisible();

    expect(errors, `Console errors on ${route.path}:\n${errors.join("\n")}`).toEqual([]);
  });
}
