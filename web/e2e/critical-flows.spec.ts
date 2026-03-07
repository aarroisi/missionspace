import { test, expect } from "@playwright/test";
import { registerTestUser } from "./helpers/auth";

test.describe("Critical User Flows", () => {
  test.beforeEach(async ({ page }) => {
    // Register a new user for each test to have clean state
    await registerTestUser(page);
  });

  test("should create a document with content", async ({ page }) => {
    // Create new doc
    await page.goto("/docs/new");
    await expect(page).toHaveURL(/\/docs\/new/);

    // Fill in title
    const titleInput = page.getByPlaceholder(/title/i);
    await titleInput.fill("Integration Test Doc");

    // Add content
    const editor = page.locator(".ProseMirror").first();
    await editor.click();
    await editor.fill("This is test content");

    // Save - click first save button (in header)
    await page.getByRole("button", { name: /save/i }).first().click();

    // Confirm save in modal
    await page
      .getByRole("button", { name: /^save$/i })
      .last()
      .click();

    // Should redirect to doc view
    await page.waitForURL(/\/docs\/[a-f0-9-]+/);

    // Verify title and content were saved
    await expect(titleInput).toHaveValue("Integration Test Doc");
    await expect(page.getByText("This is test content")).toBeVisible();
  });

  test("should copy a document link", async ({ page }) => {
    await page.context().grantPermissions(["clipboard-read", "clipboard-write"]);

    await page.goto("/docs/new");

    const titleInput = page.getByPlaceholder(/title/i);
    await titleInput.fill("Shareable Doc");

    const editor = page.locator(".ProseMirror").first();
    await editor.click();
    await editor.fill("Doc content for sharing");

    await page.getByRole("button", { name: /save/i }).first().click();
    await page
      .getByRole("button", { name: /^save$/i })
      .last()
      .click();

    await page.waitForURL(/\/docs\/[a-f0-9-]+$/);

    const expectedUrl = page.url();

    await page.getByRole("button", { name: /copy doc link/i }).click();
    await expect(page.getByText("Doc link copied to clipboard")).toBeVisible();

    const copiedUrl = await page.evaluate(() => navigator.clipboard.readText());
    expect(copiedUrl).toBe(expectedUrl);
  });

  test("should add and display comments with HTML sanitization", async ({
    page,
  }) => {
    // Create a doc first
    await page.goto("/docs/new");
    await page.getByPlaceholder(/title/i).fill("Comment Test Doc");
    await page
      .locator(".ProseMirror")
      .first()
      .fill("Doc content for commenting");
    await page.getByRole("button", { name: /save/i }).first().click();
    // Confirm save in modal
    await page
      .getByRole("button", { name: /^save$/i })
      .last()
      .click();
    await page.waitForURL(/\/docs\/[a-f0-9-]+/);

    // Scroll to bottom where comments are
    await page.evaluate(() => window.scrollTo(0, document.body.scrollHeight));

    // Add a comment with HTML (should be sanitized)
    const commentEditor = page.locator(".ProseMirror").last();
    await commentEditor.click();
    await commentEditor.fill('<script>alert("XSS")</script>Safe comment text');

    // Submit comment
    await page.getByRole("button", { name: /send/i }).click();

    // Wait a moment for comment to appear
    await page.waitForTimeout(1000);

    // Verify safe text is visible
    await expect(page.getByText(/safe comment text/i)).toBeVisible();

    // Verify script tag is NOT in the DOM (sanitized)
    const scriptTags = await page.locator('script:has-text("alert")').count();
    expect(scriptTags).toBe(0);

    // Verify no alert dialog appeared
    let dialogAppeared = false;
    page.on("dialog", () => {
      dialogAppeared = true;
    });
    await page.waitForTimeout(500);
    expect(dialogAppeared).toBe(false);
  });

  test("should submit channel messages with keyboard shortcut and keep Enter for newlines", async ({
    page,
  }) => {
    const channelName = "shortcut-channel";

    await page.getByTitle("Channels").click();
    await expect(page.getByText("All Channels")).toBeVisible();

    await page
      .locator("div")
      .filter({ hasText: /^All Channels$/ })
      .locator("button")
      .click();

    const channelNameInput = page.getByLabel(/name/i);
    await channelNameInput.focus();
    await page.keyboard.insertText(channelName);
    await page
      .locator("form")
      .getByRole("button", { name: /create channel/i })
      .click();
    await page.waitForURL(/\/channels\/[a-f0-9-]+/);

    const emptyStateTitle = page.getByText(`No messages in #${channelName} yet`);
    await expect(emptyStateTitle).toBeVisible();

    const commentEditor = page.locator(".ProseMirror").last();
    await commentEditor.click();
    await page.keyboard.insertText("First line");
    await page.keyboard.press("Enter");
    await page.keyboard.insertText("Second line");
    await page.waitForTimeout(300);

    await expect(emptyStateTitle).toBeVisible();
    await expect(commentEditor).toContainText("First line");
    await expect(commentEditor).toContainText("Second line");

    await page.keyboard.press("Control+Enter");

    await expect(emptyStateTitle).toHaveCount(0);
    await expect(page.getByText("First line")).toBeVisible();
    await expect(page.getByText("Second line")).toBeVisible();
  });

  test("should successfully edit and save a document", async ({ page }) => {
    // Create a doc
    await page.goto("/docs/new");
    await page.getByPlaceholder(/title/i).fill("Original Title");
    await page.locator(".ProseMirror").first().fill("Original content");
    await page.getByRole("button", { name: /save/i }).first().click();
    await page
      .getByRole("button", { name: /^save$/i })
      .last()
      .click();
    await page.waitForURL(/\/docs\/[a-f0-9-]+/);

    // Verify document was created
    const titleInput = page.getByPlaceholder(/title/i);
    await expect(titleInput).toHaveValue("Original Title");
    await expect(page.getByText("Original content")).toBeVisible();

    // Enter edit mode
    await page.getByRole("button", { name: /^edit$/i }).click();

    // Verify we're in edit mode
    await expect(titleInput).toBeEnabled();

    // Make changes to title - use keyboard.insertText() which properly triggers React onChange
    await titleInput.focus();
    await titleInput.click({ clickCount: 3 }); // Triple-click to select all
    await page.waitForTimeout(100); // Wait for selection to complete
    await page.keyboard.insertText("Updated Title"); // insertText triggers proper events
    await page.waitForTimeout(500); // Wait for React state update (increased for reliability)

    // Make changes to content
    const editor = page.locator(".ProseMirror").first();
    await editor.fill("Updated content"); // fill() works fine with TipTap

    // Verify the changes were applied
    await expect(titleInput).toHaveValue("Updated Title");
    await expect(editor).toContainText("Updated content");

    // Save the changes - click header Save button
    await page.getByRole("button", { name: /save/i }).first().click();

    // Confirm save in the modal
    await page
      .getByRole("button", { name: /^save$/i })
      .last()
      .click();

    // Wait for save to complete - the Edit button should reappear when save is done and edit mode exits
    await expect(page.getByRole("button", { name: /^edit$/i })).toBeVisible({
      timeout: 10000,
    });

    // Reload page to verify changes persisted
    await page.reload();

    // Wait for the doc to load after reload, then verify the edited content persisted
    await expect(titleInput).toHaveValue("Updated Title", { timeout: 5000 });
    await expect(page.getByText("Updated content")).toBeVisible();
  });

  test("should persist content after save and reload", async ({ page }) => {
    // Create doc with content
    await page.goto("/docs/new");
    const titleInput = page.getByPlaceholder(/title/i);
    await titleInput.fill("Persistence Test");

    const editor = page.locator(".ProseMirror").first();
    await editor.click();
    await editor.fill("Content that should persist");

    // Save
    await page.getByRole("button", { name: /save/i }).first().click();
    // Confirm save in modal
    await page
      .getByRole("button", { name: /^save$/i })
      .last()
      .click();
    await page.waitForURL(/\/docs\/[a-f0-9-]+/);

    // Reload page
    await page.reload();

    // Wait for doc to load, then verify content still exists
    await expect(titleInput).toHaveValue("Persistence Test", { timeout: 5000 });
    await expect(page.getByText("Content that should persist")).toBeVisible();
  });

  test("should verify API pagination structure for messages", async ({
    page,
  }) => {
    // Create a doc
    await page.goto("/docs/new");
    await page.getByPlaceholder(/title/i).fill("API Test");
    await page.locator(".ProseMirror").first().fill("Content");
    await page.getByRole("button", { name: /save/i }).first().click();
    // Confirm save in modal
    await page
      .getByRole("button", { name: /^save$/i })
      .last()
      .click();
    await page.waitForURL(/\/docs\/[a-f0-9-]+/);

    // Listen for messages API call
    const responsePromise = page.waitForResponse(
      (response) =>
        response.url().includes("/api/messages") && response.status() === 200,
      { timeout: 10000 },
    );

    await page.reload();

    const response = await responsePromise;
    const data = await response.json();

    // Verify paginated structure
    expect(data).toHaveProperty("data");
    expect(data).toHaveProperty("metadata");
    expect(Array.isArray(data.data)).toBe(true);
    expect(data.metadata).toHaveProperty("limit");
  });
});
