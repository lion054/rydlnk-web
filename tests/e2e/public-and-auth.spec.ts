import { expect, test } from "@playwright/test";

test("public homepage renders the two product paths", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/Rydlnk/i);
  await expect(page.getByRole("link", { name: /For employers/i })).toBeVisible();
  await expect(page.getByRole("heading", { name: /company pays for staff transport/i })).toBeVisible();
  await expect(page.getByRole("link", { name: /Get the app|Download/i }).first()).toBeVisible();
});

test("sign-in page renders a secure email flow", async ({ page }) => {
  await page.goto("/signin");
  await expect(page.getByRole("heading", { name: /sign in/i })).toBeVisible();
  await expect(page.getByRole("textbox", { name: /email/i })).toBeVisible();
});

test("company portal requires authentication", async ({ page }) => {
  await page.goto("/portal");
  await expect(page).toHaveURL(/\/signin\?next=%2Fportal/);
});

test("operator dispatch requires authentication", async ({ page }) => {
  await page.goto("/ops/dispatch");
  await expect(page).toHaveURL(/\/signin\?next=%2Fops%2Fdispatch/);
});

test("super admin requires authentication", async ({ page }) => {
  await page.goto("/ops/admin");
  await expect(page).toHaveURL(/\/signin\?next=%2Fops%2Fadmin/);
});

test("legal and security pages remain publicly reachable", async ({ page }) => {
  for (const path of ["/legal/privacy", "/legal/terms", "/security"]) {
    const response = await page.goto(path);
    expect(response?.status()).toBe(200);
  }
});
