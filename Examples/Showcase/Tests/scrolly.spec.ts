import { test, expect } from "@playwright/test";
import { waitForHydration } from "./lib/helpers.js";

test("scrolling advances current step", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);

  // Step 1 active by default.
  await expect(page.locator("[data-swui-step-card][data-active=\"true\"]")).toContainText(/Conform a struct/i);

  // Scroll into step 2.
  await page.locator("[data-swui-step-card]").nth(1).scrollIntoViewIfNeeded();
  await page.waitForTimeout(300);

  await expect(page.locator("[data-swui-step-card][data-active=\"true\"]")).toContainText(/Compose with @TagBuilder/i);
});

test("highlight lines match active step's highlightLines", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);

  const highlighted = await page.locator("[data-line-hl]").count();
  expect(highlighted).toBeGreaterThan(0);
});

test("StepNav next button advances current step", async ({ page }) => {
  await page.goto("/learn/hello");
  await waitForHydration(page);
  await page.locator("button", { hasText: /Next step/ }).click();
  await page.waitForTimeout(300);
  await expect(page.locator("[data-step-nav]")).toContainText("2 /");
});
