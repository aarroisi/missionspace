import { test, expect } from "@playwright/test";
import { registerTestUser } from "./helpers/auth";

test.describe("Profile Menu", () => {
  test.beforeEach(async ({ page }) => {
    await registerTestUser(page);
  });

  test("should open profile menu and show user info", async ({ page }) => {
    // Find the profile menu trigger at the bottom of the sidebar
    const profileTrigger = page
      .locator(".w-14")
      .locator("button")
      .filter({ has: page.locator(".rounded-full") })
      .last();
    await profileTrigger.click();

    // Should show user email in dropdown
    await expect(page.getByText(/@example.com/)).toBeVisible();

    // Should show Edit Profile option
    await expect(page.getByText("Edit Profile")).toBeVisible();

    // Should show Sign Out option
    await expect(page.getByText("Sign Out")).toBeVisible();
  });

  test("should open profile modal and edit name", async ({ page }) => {
    // Open profile menu
    const profileTrigger = page
      .locator(".w-14")
      .locator("button")
      .filter({ has: page.locator(".rounded-full") })
      .last();
    await profileTrigger.click();

    // Click Edit Profile
    await page.getByText("Edit Profile").click();

    // Modal should be visible
    await expect(
      page.getByRole("heading", { name: "Edit Profile" }),
    ).toBeVisible();

    // Edit name - use keyboard.insertText for React controlled input
    const nameInput = page.getByLabel("Name");
    await nameInput.click({ clickCount: 3 });
    await page.keyboard.insertText("Updated Name");

    // Save changes
    await page.getByRole("button", { name: "Save Changes" }).click();

    // Modal should close
    await expect(
      page.getByRole("heading", { name: "Edit Profile" }),
    ).not.toBeVisible();

    // Reopen menu to verify change
    await profileTrigger.click();
    await expect(page.getByText("Updated Name")).toBeVisible();
  });

  test("should save timezone from profile modal", async ({ page }) => {
    const profileTrigger = page
      .locator(".w-14")
      .locator("button")
      .filter({ has: page.locator(".rounded-full") })
      .last();

    await profileTrigger.click();
    await page.getByText("Edit Profile").click();

    const timezoneSelect = page.getByLabel("Time zone");
    await expect(timezoneSelect).toHaveClass(/pr-10/);
    await expect(
      timezoneSelect.locator('option[value="America/New_York"]'),
    ).toContainText(/GMT[+-]/);

    await timezoneSelect.selectOption("America/New_York");
    await page.getByRole("button", { name: "Save Changes" }).click();

    await expect(
      page.getByRole("heading", { name: "Edit Profile" }),
    ).not.toBeVisible();

    await profileTrigger.click();
    await page.getByText("Edit Profile").click();

    await expect(page.getByLabel("Time zone")).toHaveValue("America/New_York");
  });

  test("should logout successfully", async ({ page }) => {
    // Open profile menu
    const profileTrigger = page
      .locator(".w-14")
      .locator("button")
      .filter({ has: page.locator(".rounded-full") })
      .last();
    await profileTrigger.click();

    // Click Sign Out
    await page.getByText("Sign Out").click();

    // Should redirect to login
    await page.waitForURL(/\/login/);
    await expect(page.getByLabel("Email")).toBeVisible();
  });

  test("should close dropdown when clicking outside", async ({ page }) => {
    // Open profile menu
    const profileTrigger = page
      .locator(".w-14")
      .locator("button")
      .filter({ has: page.locator(".rounded-full") })
      .last();
    await profileTrigger.click();

    // Dropdown should be visible
    await expect(page.getByText("Edit Profile")).toBeVisible();

    // Click outside by clicking on a navigation button in the sidebar
    await page.locator('button[title="Home"]').click();

    // Dropdown should close
    await expect(page.getByText("Edit Profile")).not.toBeVisible();
  });

  test("should close modal when clicking cancel", async ({ page }) => {
    // Open profile menu
    const profileTrigger = page
      .locator(".w-14")
      .locator("button")
      .filter({ has: page.locator(".rounded-full") })
      .last();
    await profileTrigger.click();

    // Click Edit Profile
    await page.getByText("Edit Profile").click();

    // Modal should be visible
    await expect(
      page.getByRole("heading", { name: "Edit Profile" }),
    ).toBeVisible();

    // Click Cancel
    await page.getByRole("button", { name: "Cancel" }).click();

    // Modal should close
    await expect(
      page.getByRole("heading", { name: "Edit Profile" }),
    ).not.toBeVisible();
  });

  test("should disable save button when no changes made", async ({ page }) => {
    // Open profile menu
    const profileTrigger = page
      .locator(".w-14")
      .locator("button")
      .filter({ has: page.locator(".rounded-full") })
      .last();
    await profileTrigger.click();

    // Click Edit Profile
    await page.getByText("Edit Profile").click();

    // Save button should be disabled since no changes
    await expect(
      page.getByRole("button", { name: "Save Changes" }),
    ).toBeDisabled();
  });
});
