import { expect, test } from "@playwright/test";

const email = process.env.E2E_COMPANY_EMAIL;
const password = process.env.E2E_COMPANY_PASSWORD;

test.describe("authenticated company portal", () => {
  test.skip(!email || !password, "E2E company credentials are not configured");

  test.beforeEach(async ({ page }) => {
    await page.goto("/signin");
    await page.getByRole("button", { name: /use a password/i }).click();
    await page.getByRole("textbox", { name: /work email/i }).fill(email!);
    await page.getByLabel(/password/i).fill(password!);
    await page.getByRole("button", { name: /^sign in$/i }).click();
    await expect(page).toHaveURL(/\/portal/);
  });

  test("company member can open every operational section", async ({ page }) => {
    for (const path of [
      "/portal",
      "/portal/people",
      "/portal/schedules",
      "/portal/trips",
      "/portal/corridors",
      "/portal/credits",
      "/portal/billing",
    ]) {
      const response = await page.goto(path);
      expect(response?.status(), path).toBe(200);
      await expect(page).not.toHaveURL(/\/signin/);
    }
  });

  test("company member cannot enter platform dispatch without platform role", async ({ page }) => {
    await page.goto("/ops/dispatch");
    await expect(page).toHaveURL(/\/portal/);
  });
});
