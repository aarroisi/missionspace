# E2E Tests

End-to-end tests for the Missionspace application using Playwright.

## What These Tests Do

These tests verify the full integration between frontend and backend:

1. **Document CRUD Operations** (`docs.spec.ts`)
   - Creating documents
   - Editing documents
   - Canceling edits
   - Adding comments
   - Text formatting

2. **API Integration** (`api-integration.spec.ts`)
   - Verifies API response structure
   - Catches breaking changes in backend responses
   - Tests pagination
   - Tests HTML sanitization (XSS protection)
   - Tests error handling

## Running Tests

### Prerequisites

Make sure both backend and frontend are running:

```bash
# Terminal 1 - Backend
cd server
iex -S mix phx.server

# Terminal 2 - Frontend (handled automatically by Playwright)
# No need to run manually, playwright.config.ts will start it
```

### Run All Tests

```bash
npm test
```

### Run Tests with UI Mode (Recommended for Development)

```bash
npm run test:ui
```

This opens an interactive UI where you can:
- See tests running in real-time
- Debug failures
- Time-travel through test steps

### Run Tests in Headed Mode (See Browser)

```bash
npm run test:headed
```

### Run Specific Test File

```bash
npx playwright test docs.spec.ts
```

### View Test Report

```bash
npm run test:report
```

## What Will Break Tests

These tests will **fail** if:

1. **Backend API Changes**
   - Response structure changes (e.g., field renamed from `author_name` to `authorName`)
   - Endpoint URLs change
   - Status codes change
   - Pagination format changes

2. **Frontend Changes**
   - Button labels change (e.g., "Save" → "Submit")
   - Component structure changes
   - Navigation flows change
   - Form field placeholders change

3. **Integration Issues**
   - Backend not running
   - CORS issues
   - Authentication issues
   - Database connection issues

## Writing New Tests

1. Add test file in `e2e/` directory
2. Use descriptive test names
3. Follow existing patterns
4. Test both happy path and error cases
5. Verify API responses when possible

Example:

```typescript
test('should do something', async ({ page }) => {
  // Navigate
  await page.goto('/some-page');
  
  // Interact
  await page.getByRole('button', { name: /click me/i }).click();
  
  // Assert
  await expect(page.getByText('Success')).toBeVisible();
});
```

## Debugging Failed Tests

1. **Run in headed mode**: `npm run test:headed`
2. **Check screenshots**: Failed tests automatically capture screenshots
3. **View trace**: `npx playwright show-trace trace.zip`
4. **Use UI mode**: `npm run test:ui` for step-by-step debugging

## CI/CD Integration

Add to your GitHub Actions or CI pipeline:

```yaml
- name: Install Playwright Browsers
  run: npx playwright install --with-deps

- name: Run E2E tests
  run: npm test
```
