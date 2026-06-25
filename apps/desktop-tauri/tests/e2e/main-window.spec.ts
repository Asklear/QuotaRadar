import { expect, test } from "@playwright/test";

test("main window renders sidebar and switches between mock pages", async ({ page }) => {
  await page.goto("/");

  const nav = page.getByRole("navigation", { name: "Primary" });

  await expect(page.getByRole("heading", { name: "Quota Radar" })).toBeVisible();
  await expect(nav.getByRole("button", { name: "Quota Overview", exact: true })).toHaveAttribute("data-active", "true");
  await expect(page.getByRole("heading", { name: "STATISTICS" })).toBeVisible();
  await expect(page.getByRole("heading", { name: "AI Search" }).first()).toBeVisible();

  await nav.getByRole("button", { name: "Credentials", exact: true }).click();
  await expect(nav.getByRole("button", { name: "Credentials", exact: true })).toHaveAttribute("data-active", "true");
  await expect(page.getByRole("button", { name: "Add Credential" })).toBeVisible();

  await nav.getByRole("button", { name: "Diagnostics", exact: true }).click();
  await expect(page.getByRole("region", { name: "Tavily diagnostics" })).toBeVisible();
  await expect(page.getByText("HTTP 200").first()).toBeVisible();

  await nav.getByRole("button", { name: "Settings", exact: true }).click();
  await expect(page.getByText("Network proxy")).toBeVisible();
  await expect(page.getByRole("button", { name: "Customize provider order" })).toBeVisible();

  await nav.getByRole("button", { name: "Quota Overview", exact: true }).click();
  await expect(page.getByRole("heading", { name: "Quota Overview" })).toBeVisible();
  await expect(nav.getByRole("button", { name: "Quota Overview", exact: true })).toHaveAttribute("data-active", "true");

  await page.screenshot({ path: "tests/e2e/screenshots/main-window.png", fullPage: true });
});

test("main window keeps sidebar and content layout separated", async ({ page }) => {
  await page.goto("/");

  const sidebarBox = await page.locator(".app-sidebar").boundingBox();
  const mainBox = await page.locator(".app-main").boundingBox();
  const appMark = page.getByTestId("app-mark");
  const appMarkBox = await appMark.boundingBox();

  expect(sidebarBox).not.toBeNull();
  expect(mainBox).not.toBeNull();
  expect(Math.round(sidebarBox!.width)).toBe(220);
  expect(mainBox!.x).toBeGreaterThanOrEqual(sidebarBox!.x + sidebarBox!.width - 1);
  await expect(appMark.locator("img")).toHaveAttribute("src", /app-icon\.png$/);
  expect(appMarkBox).not.toBeNull();
  expect(Math.round(appMarkBox!.width)).toBe(42);
  expect(Math.round(appMarkBox!.height)).toBe(42);

  for (const button of await page.locator(".sidebar-nav-item").all()) {
    const buttonBox = await button.boundingBox();
    expect(buttonBox).not.toBeNull();
    expect(buttonBox!.x).toBeGreaterThanOrEqual(sidebarBox!.x);
    expect(buttonBox!.x + buttonBox!.width).toBeLessThanOrEqual(sidebarBox!.x + sidebarBox!.width + 1);
    expect(buttonBox!.height).toBeGreaterThanOrEqual(30);
  }
});

test("main window scrolls content without moving the sidebar", async ({ page }) => {
  await page.goto("/");

  await page.locator(".app-main").evaluate((main) => {
    const filler = document.createElement("div");
    filler.setAttribute("data-testid", "scroll-filler");
    filler.style.height = "1400px";
    main.appendChild(filler);
  });

  const appMark = page.getByTestId("app-mark");
  const before = await appMark.boundingBox();

  await page.locator(".app-main").evaluate((main) => {
    main.scrollTop = 320;
  });

  const after = await appMark.boundingBox();
  const mainScrollTop = await page.locator(".app-main").evaluate((main) => main.scrollTop);
  const windowScrollY = await page.evaluate(() => window.scrollY);

  expect(before).not.toBeNull();
  expect(after).not.toBeNull();
  expect(mainScrollTop).toBeGreaterThan(250);
  expect(windowScrollY).toBe(0);
  expect(Math.round(after!.y)).toBe(Math.round(before!.y));
});

test("main window uses the same provider icon assets as the Swift app", async ({ page }) => {
  await page.goto("/");

  await expect(page.locator('.provider-icon[data-provider="tavily"] img').first()).toHaveAttribute(
    "src",
    /provider-icons\/tavily\.png$/,
  );
  await expect(page.locator('.provider-icon[data-provider="brave"] img').first()).toHaveAttribute(
    "src",
    /provider-icons\/brave\.png$/,
  );
});
