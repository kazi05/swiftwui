import type { Page } from "@playwright/test";
import type { Theme } from "./themes.js";

export async function setTheme(page: Page, theme: Theme) {
  await page.addInitScript((t) => {
    try { localStorage.setItem("swui-theme", t); } catch (_) {}
    document.documentElement.setAttribute("data-theme", t);
  }, theme);
}

export async function waitForHydration(page: Page) {
  await page.waitForFunction(
    () => document.querySelector("[data-swui-mounted]") !== null,
    null,
    { timeout: 10_000 },
  );
}
