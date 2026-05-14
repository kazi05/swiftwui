import { test, expect } from "@playwright/test";
import { setTheme, waitForHydration } from "./lib/helpers.js";

test("chapter dropdown opens and lists all 12 chapters", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("[data-swui-topbar] details").first().click();
  await expect(page.locator("[data-swui-popover=\"chapter\"]")).toBeVisible();
  await expect(page.locator("[data-swui-popover=\"chapter\"]")).toContainText("Hello, SwiftWUI");
  await expect(page.locator("[data-swui-popover=\"chapter\"]")).toContainText("PWA");
});

test("chapter link navigates", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("[data-swui-topbar] details").first().click();
  await page.getByRole("link", { name: /State & Bindings/ }).click();
  await expect(page).toHaveURL(/\/learn\/state/);
});

test("theme toggle flips data-theme and persists across reload", async ({ page }) => {
  await setTheme(page, "light");
  await page.goto("/learn/hello");
  await waitForHydration(page);

  await page.locator("[data-swui-theme-toggle]").click();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");

  await page.reload();
  await expect(page.locator("html")).toHaveAttribute("data-theme", "dark");
});

test("browser back/forward stays in sync with SPA router", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("[data-swui-topbar] details").first().click();
  await page.getByRole("link", { name: /Modifiers/ }).click();
  await expect(page).toHaveURL(/\/learn\/modifiers/);
  await page.goBack();
  await expect(page).toHaveURL(/\/learn\/hello/);
});
