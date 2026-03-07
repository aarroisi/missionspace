import { Page } from "@playwright/test";

const DEV_MAILBOX_URL = "http://localhost:4000/dev/mailbox";
const DEV_API_URL = "http://localhost:4000/api";
const TEST_PASSWORD = "password123";
const LOGIN_REDIRECT_REGEX = /\/(dashboard|home|projects|docs|boards|$)/;
const MAILBOX_POLL_TIMEOUT_MS = 15000;
const MAILBOX_POLL_INTERVAL_MS = 500;

function delay(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function loginWithCredentials(
  page: Page,
  email: string,
  password: string,
) {
  await page.goto("/login");

  await page.getByLabel("Email").focus();
  await page.keyboard.insertText(email);

  await page.getByLabel("Password").focus();
  await page.keyboard.insertText(password);

  await page.getByRole("button", { name: /sign in/i }).click();
  await page.waitForURL(LOGIN_REDIRECT_REGEX);
}

async function findVerificationToken(email: string): Promise<string> {
  const deadline = Date.now() + MAILBOX_POLL_TIMEOUT_MS;

  while (Date.now() < deadline) {
    const mailboxResponse = await fetch(DEV_MAILBOX_URL);
    const mailboxHtml = await mailboxResponse.text();
    const messagePaths = Array.from(
      new Set(
        [...mailboxHtml.matchAll(/href="(\/dev\/mailbox\/[a-f0-9]+)"/g)].map(
          (match) => match[1],
        ),
      ),
    );

    for (const messagePath of messagePaths) {
      const messageResponse = await fetch(`http://localhost:4000${messagePath}`);
      const messageHtml = await messageResponse.text();

      if (!messageHtml.includes(email)) {
        continue;
      }

      const tokenMatch = messageHtml.match(/verify-email\?token=([A-Za-z0-9_-]+)/);

      if (tokenMatch?.[1]) {
        return tokenMatch[1];
      }
    }

    await delay(MAILBOX_POLL_INTERVAL_MS);
  }

  throw new Error(`Verification email not found for ${email}`);
}

async function verifyEmail(email: string) {
  const token = await findVerificationToken(email);

  const response = await fetch(`${DEV_API_URL}/auth/verify-email`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ token }),
  });

  if (!response.ok) {
    const data = await response.json().catch(() => ({}));
    throw new Error(data.error || "Failed to verify test email");
  }
}

export async function loginAsTestUser(page: Page) {
  await loginWithCredentials(page, "test@example.com", TEST_PASSWORD);
}

export async function registerTestUser(page: Page) {
  await page.goto("/register");

  const uniqueId = `${Date.now().toString().slice(-6)}${Math.random().toString(36).slice(2, 6)}`;
  const email = `test${uniqueId}@example.com`;

  // Use keyboard.insertText for React controlled inputs
  await page.getByLabel("Workspace Name").focus();
  await page.keyboard.insertText(`WS ${uniqueId}`);

  await page.getByLabel("Your Name").focus();
  await page.keyboard.insertText(`Test User ${uniqueId}`);

  await page.getByLabel("Email").focus();
  await page.keyboard.insertText(email);

  await page.getByLabel("Password").focus();
  await page.keyboard.insertText(TEST_PASSWORD);

  await page.getByRole("button", { name: /create workspace/i }).click();

  await page.waitForURL(/\/verify-email/);

  await verifyEmail(email);
  await page.goto("/dashboard");
  await page.waitForURL(LOGIN_REDIRECT_REGEX);
}
