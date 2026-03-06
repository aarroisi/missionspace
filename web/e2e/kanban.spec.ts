import { test, expect } from "@playwright/test";
import { registerTestUser } from "./helpers/auth";

test.describe("Kanban Board", () => {
  test.beforeEach(async ({ page }) => {
    await registerTestUser(page);
  });

  async function createBoard(page: any) {
    // Click on Boards category in outer sidebar
    await page.getByTitle("Boards").click();

    // Wait for inner sidebar to show boards
    await expect(page.getByText("All Boards")).toBeVisible();

    // Click the + button next to "All Boards" to create a new board
    await page
      .locator("div")
      .filter({ hasText: /^All Boards$/ })
      .locator("button")
      .click();

    // Wait for the new board to be created and navigate to it
    await page.waitForURL(/\/boards\/[a-f0-9-]+/);
  }

  async function addColumn(
    page: any,
    name: string,
    options?: { mobile?: boolean },
  ) {
    if (options?.mobile) {
      await page.getByRole("button", { name: /board actions/i }).click();
      await page.getByRole("button", { name: /add column/i }).click();
    } else {
      await page.getByRole("button", { name: /add column/i }).click();
    }

    await expect(
      page.getByRole("heading", { name: /add column/i }),
    ).toBeVisible();

    const nameInput = page.getByLabel(/column name/i);
    await nameInput.focus();
    await page.keyboard.insertText(name);
    await page.getByRole("button", { name: /create column/i }).click();
  }

  async function getColumnOrder(page: any): Promise<string[]> {
    return page
      .locator('[data-testid^="column-"]')
      .evaluateAll((els) =>
        els
          .map((el) => el.getAttribute("data-testid"))
          .filter((value): value is string => Boolean(value)),
      );
  }

  test("should add a column from desktop header", async ({ page }) => {
    await createBoard(page);

    await addColumn(page, "Review");

    await expect(page.getByTestId("column-review")).toBeVisible();
  });

  test("should add a column from mobile board actions menu", async ({
    page,
  }) => {
    await createBoard(page);
    await page.setViewportSize({ width: 390, height: 844 });

    await addColumn(page, "QA", { mobile: true });

    await expect(page.getByTestId("column-qa")).toBeVisible();
  });

  test("should show validation for duplicate column names", async ({ page }) => {
    await createBoard(page);

    await addColumn(page, "Review");
    await expect(page.getByTestId("column-review")).toBeVisible();

    await page.getByRole("button", { name: /add column/i }).click();
    const nameInput = page.getByLabel(/column name/i);
    await nameInput.focus();
    await page.keyboard.insertText("review");
    await page.getByRole("button", { name: /create column/i }).click();

    await expect(page.getByText(/already exists/i)).toBeVisible();
    await expect(
      page.getByRole("heading", { name: /add column/i }),
    ).toBeVisible();
  });

  test("should persist added columns after reload and keep DONE last", async ({
    page,
  }) => {
    await createBoard(page);

    await addColumn(page, "Backlog");
    await expect(page.getByTestId("column-backlog")).toBeVisible();

    const orderBeforeReload = await getColumnOrder(page);
    expect(orderBeforeReload[orderBeforeReload.length - 1]).toBe("column-done");

    await page.reload();

    await expect(page.getByTestId("column-backlog")).toBeVisible({
      timeout: 5000,
    });

    const orderAfterReload = await getColumnOrder(page);
    expect(orderAfterReload[orderAfterReload.length - 1]).toBe("column-done");
    expect(orderAfterReload.indexOf("column-backlog")).toBeGreaterThan(-1);
    expect(orderAfterReload.indexOf("column-backlog")).toBeLessThan(
      orderAfterReload.indexOf("column-done"),
    );
  });

  test("should create a board and add tasks", async ({ page }) => {
    await createBoard(page);

    // Verify kanban columns are visible (default statuses: todo, doing, done)
    await expect(page.getByTestId("column-todo")).toBeVisible();
    await expect(page.getByTestId("column-doing")).toBeVisible();
    await expect(page.getByTestId("column-done")).toBeVisible();

    // Add a task to todo column by clicking Add task button in that column
    await page
      .getByTestId("column-todo")
      .getByRole("button", { name: /add task/i })
      .click();

    // Fill in task title in modal
    const taskInput = page.getByPlaceholder(/task title/i);
    await taskInput.focus();
    await page.keyboard.insertText("My First Task");
    await page.getByRole("button", { name: "Add Task", exact: true }).click();

    // Verify task appears
    await expect(page.getByText("My First Task")).toBeVisible();
  });

  test("should display tasks in correct columns based on status", async ({
    page,
  }) => {
    await createBoard(page);

    // Add a task to todo
    await page
      .getByTestId("column-todo")
      .getByRole("button", { name: /add task/i })
      .click();
    await page.getByPlaceholder(/task title/i).focus();
    await page.keyboard.insertText("Todo Task");
    await page.getByRole("button", { name: "Add Task", exact: true }).click();

    // Verify task is in todo column
    await expect(
      page.getByTestId("column-todo").getByText("Todo Task"),
    ).toBeVisible();

    // Add a task to doing (use the + button in header since "Add task" only shows in first column)
    await page.getByTestId("column-doing").getByRole("button").last().click();
    await page.getByPlaceholder(/task title/i).focus();
    await page.keyboard.insertText("Doing Task");
    await page.getByRole("button", { name: "Add Task", exact: true }).click();

    // Verify task is in doing column
    await expect(
      page.getByTestId("column-doing").getByText("Doing Task"),
    ).toBeVisible();
  });

  test("should persist task order after page reload", async ({ page }) => {
    await createBoard(page);

    // Add multiple tasks
    for (const taskName of ["Task 1", "Task 2", "Task 3"]) {
      await page
        .getByTestId("column-todo")
        .getByRole("button", { name: /add task/i })
        .click();
      await page.getByPlaceholder(/task title/i).focus();
      await page.keyboard.insertText(taskName);
      await page.getByRole("button", { name: "Add Task", exact: true }).click();
      await page.waitForTimeout(300); // Wait for task to be created
    }

    // Verify all tasks are visible
    await expect(page.getByText("Task 1")).toBeVisible();
    await expect(page.getByText("Task 2")).toBeVisible();
    await expect(page.getByText("Task 3")).toBeVisible();

    // Reload the page
    await page.reload();

    // Verify tasks are still visible after reload
    await expect(page.getByText("Task 1")).toBeVisible({ timeout: 5000 });
    await expect(page.getByText("Task 2")).toBeVisible();
    await expect(page.getByText("Task 3")).toBeVisible();
  });

  test("should open task detail modal when clicking a task", async ({
    page,
  }) => {
    await createBoard(page);

    // Add a task
    await page
      .getByTestId("column-todo")
      .getByRole("button", { name: /add task/i })
      .click();
    await page.getByPlaceholder(/task title/i).focus();
    await page.keyboard.insertText("Click Me Task");
    await page.getByRole("button", { name: "Add Task", exact: true }).click();

    // Click the task to open modal
    await page.getByText("Click Me Task").click();

    // Verify modal opens with task title (modal has fixed positioning)
    const modal = page.locator(".fixed").filter({ hasText: "Click Me Task" });
    await expect(modal).toBeVisible();

    // Verify URL contains task parameter
    await expect(page).toHaveURL(/task=/);
  });

  test("should change task status via detail modal dropdown", async ({
    page,
  }) => {
    await createBoard(page);

    // Add a task to todo
    await page
      .getByTestId("column-todo")
      .getByRole("button", { name: /add task/i })
      .click();
    await page.getByPlaceholder(/task title/i).focus();
    await page.keyboard.insertText("Status Test Task");
    await page.getByRole("button", { name: "Add Task", exact: true }).click();

    // Click the task to open modal
    await page.getByText("Status Test Task").click();

    // Click the status dropdown to open it
    await page
      .locator("button")
      .filter({ hasText: /^TODO$/ })
      .first()
      .click();

    // Select "DOING" status
    await page
      .locator("button")
      .filter({ hasText: /^DOING$/ })
      .click();

    // Click Save button to apply changes
    await page.getByRole("button", { name: /^save$/i }).click();

    // Wait for save to complete
    await page.waitForTimeout(500);

    // Close the modal by pressing Escape
    await page.keyboard.press("Escape");

    // Verify task moved to doing column
    await expect(
      page.getByTestId("column-doing").getByText("Status Test Task"),
    ).toBeVisible();
  });

  test("should switch between board and table view", async ({ page }) => {
    await createBoard(page);

    // Add a task
    await page
      .getByTestId("column-todo")
      .getByRole("button", { name: /add task/i })
      .click();
    await page.getByPlaceholder(/task title/i).focus();
    await page.keyboard.insertText("View Test Task");
    await page.getByRole("button", { name: "Add Task", exact: true }).click();

    // Verify we're in board view (columns visible)
    await expect(page.getByTestId("column-todo")).toBeVisible();
    await expect(page.getByTestId("column-doing")).toBeVisible();
    await expect(page.getByTestId("column-done")).toBeVisible();

    // Switch to table view
    await page.getByTitle("Table view").click();

    // Verify table view shows task
    await expect(page.getByText("View Test Task")).toBeVisible();

    // Switch back to board view
    await page.getByTitle("Board view").click();

    // Verify board columns are visible again
    await expect(page.getByTestId("column-todo")).toBeVisible();
  });
});
