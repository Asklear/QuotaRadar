import { expect, test } from "@playwright/test";

test("tray route renders a fixed-size quota popover", async ({ page }) => {
  await page.setViewportSize({ width: 680, height: 620 });
  await page.goto("/?view=tray");

  const popover = page.getByTestId("tray-popover");
  await expect(popover).toBeVisible();
  await expect(page.getByRole("heading", { name: "Quota Radar" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Statistics" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Favorites" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "Heads Up" })).toBeVisible();
  await expect(page.getByTestId("tray-app-mark").locator("img")).toHaveAttribute("src", /app-icon\.png$/);
  await expect(page.getByRole("button", { name: "Settings" })).toBeVisible();

  const box = await popover.boundingBox();
  const markBox = await page.getByTestId("tray-app-mark").boundingBox();
  expect(box).not.toBeNull();
  expect(markBox).not.toBeNull();
  expect(Math.round(box!.width)).toBe(560);
  expect(Math.round(box!.height)).toBe(500);
  expect(Math.round(markBox!.width)).toBe(30);
  expect(Math.round(markBox!.height)).toBe(30);

  await page.screenshot({ path: "tests/e2e/screenshots/tray-popover.png", fullPage: true });
});

test("tray route fits the real menu bar window without clipping", async ({ page }) => {
  await page.setViewportSize({ width: 560, height: 500 });
  await page.goto("/?view=tray");

  const popover = page.getByTestId("tray-popover");
  await expect(popover).toBeVisible();

  const metrics = await page.evaluate(() => ({
    bodyHeight: document.body.scrollHeight,
    bodyWidth: document.body.scrollWidth,
    viewportHeight: window.innerHeight,
    viewportWidth: window.innerWidth,
  }));
  expect(metrics.bodyWidth).toBeLessThanOrEqual(metrics.viewportWidth);
  expect(metrics.bodyHeight).toBeLessThanOrEqual(metrics.viewportHeight);

  const box = await popover.boundingBox();
  expect(box).not.toBeNull();
  expect(Math.round(box!.x)).toBe(0);
  expect(Math.round(box!.y)).toBe(0);
  expect(Math.round(box!.width)).toBe(560);
  expect(Math.round(box!.height)).toBe(500);
});
