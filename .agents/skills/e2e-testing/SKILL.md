---
name: e2e-testing
description: Playwright E2E testing for React applications. Critical gotcha about React controlled inputs and Playwright. Use when writing or debugging E2E tests, especially for form inputs.
---

# E2E Testing with Playwright and React

## Critical Gotcha: React Controlled Inputs and Playwright

**Problem**: Playwright's standard methods (`fill()`, `clear()`, `pressSequentially()`) do NOT properly trigger React's `onChange` event for controlled inputs. This is a well-known limitation.

### Why it happens

1. React uses a synthetic event system for cross-browser compatibility
2. React listens to the native `input` event (not `change`) and maps it to `onChange`
3. Playwright's `fill()` method sets the DOM value but doesn't trigger events in a way React's synthetic event system recognizes
4. Manually dispatching events with `dispatchEvent(new Event("input"))` also doesn't work because React doesn't recognize these as "trusted" events

### Symptoms

- After using `fill()` or `pressSequentially()`, the input's value appears correct in the DOM
- But the React state is not updated
- The component re-renders with the old state value, resetting the input

### Solution: Use keyboard.insertText()

```typescript
// ❌ DOESN'T WORK - fill() doesn't trigger React onChange
await input.fill("New Value");

// ❌ DOESN'T WORK - pressSequentially() is unreliable with controlled inputs
await input.pressSequentially("New Value");

// ✅ WORKS - Use keyboard.insertText() with selection
await input.focus();
await input.click({ clickCount: 3 }); // Triple-click to select all
await page.waitForTimeout(100); // Wait for selection
await page.keyboard.insertText("New Value"); // Triggers proper events
await page.waitForTimeout(500); // Wait for React state update
```

### Why insertText() works

- `keyboard.insertText()` simulates real keyboard input
- It triggers proper input events that React's synthetic event system recognizes
- Each character insertion triggers `onChange` in React

## Important Notes

1. **This issue only affects regular HTML inputs** with React controlled state (`value` + `onChange`)
2. **TipTap editor works fine with `fill()`** because it has its own event handling
3. **Always add timeouts** after `insertText()` to allow React to process state updates
4. **Triple-click is more reliable** than keyboard shortcuts like `Control+a` for text selection

## Working Example

See `web/e2e/critical-flows.spec.ts` - the "should successfully edit and save a document" test demonstrates the working pattern:

```typescript
test("should successfully edit and save a document", async ({ page }) => {
  // ... setup code ...

  // Make changes to title - use keyboard.insertText()
  await titleInput.focus();
  await titleInput.click({ clickCount: 3 }); // Select all
  await page.waitForTimeout(100); // Wait for selection
  await page.keyboard.insertText("Updated Title");
  await page.waitForTimeout(500); // Wait for React state

  // Make changes to content - TipTap works with fill()
  const editor = page.locator(".ProseMirror").first();
  await editor.fill("Updated content");

  // Verify changes
  await expect(titleInput).toHaveValue("Updated Title");
  await expect(editor).toContainText("Updated content");
});
```

## Related Resources

- **GitHub Issue**: https://github.com/microsoft/playwright/issues/15813
- **Test File**: `web/e2e/critical-flows.spec.ts`
- **Test Helpers**: `web/e2e/helpers/auth.ts`
