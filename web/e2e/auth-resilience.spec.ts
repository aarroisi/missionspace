import { test, expect, Page } from "@playwright/test";

const PAGINATED_ENDPOINTS = new Set([
  "/api/projects",
  "/api/boards",
  "/api/doc-folders",
  "/api/docs",
  "/api/channels",
  "/api/direct_messages",
  "/api/messages",
  "/api/notifications",
]);

const AUTH_SUCCESS_BODY = {
  user: {
    id: "test-user-id",
    name: "Test User",
    email: "test@example.com",
    avatar: "",
    timezone: null,
    role: "owner",
    workspace_id: "test-workspace-id",
  },
  workspace: {
    id: "test-workspace-id",
    name: "Test Workspace",
    slug: "test-workspace",
    logo: null,
  },
};

async function mockApi(
  page: Page,
  authMeHandler: (attempt: number) => { status: number; body: unknown },
) {
  let authMeAttempts = 0;

  await page.route("**/api/**", async (route) => {
    const request = route.request();
    const { pathname } = new URL(request.url());

    if (pathname === "/api/auth/me") {
      authMeAttempts += 1;
      const { status, body } = authMeHandler(authMeAttempts);

      await route.fulfill({
        status,
        contentType: "application/json",
        body: JSON.stringify(body),
      });
      return;
    }

    if (request.method() === "GET" && PAGINATED_ENDPOINTS.has(pathname)) {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({
          data: [],
          metadata: { after: null, limit: 50 },
        }),
      });
      return;
    }

    if (pathname === "/api/notifications/unread-count") {
      await route.fulfill({
        status: 200,
        contentType: "application/json",
        body: JSON.stringify({ count: 0 }),
      });
      return;
    }

    await route.fulfill({
      status: 200,
      contentType: "application/json",
      body: JSON.stringify({ data: [] }),
    });
  });

  return {
    getAuthMeAttempts: () => authMeAttempts,
  };
}

test.describe("Authentication resilience", () => {
  test("retries /auth/me after transient failure", async ({ page }) => {
    const api = await mockApi(page, (attempt) => {
      if (attempt === 1) {
        return {
          status: 503,
          body: { error: "temporary_unavailable" },
        };
      }

      return {
        status: 200,
        body: AUTH_SUCCESS_BODY,
      };
    });

    await page.goto("/dashboard");

    await page.waitForURL(/\/dashboard$/);
    await expect(page.getByRole("heading", { name: "Starred Items" })).toBeVisible();
    expect(api.getAuthMeAttempts()).toBeGreaterThanOrEqual(2);
  });

  test("redirects to login when session is unauthorized", async ({ page }) => {
    await mockApi(page, () => ({
      status: 401,
      body: { error: "Not authenticated" },
    }));

    await page.goto("/dashboard");

    await page.waitForURL(/\/login$/);
    await expect(page.getByRole("heading", { name: "Welcome Back" })).toBeVisible();
  });
});
