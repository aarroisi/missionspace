---
name: frontend
description: React/TypeScript frontend development patterns for Bridge. Use when working on components, pages, state management, or UI. Includes critical Playwright testing gotchas.
user-invocable: false
---

# Bridge Frontend Development

## Context

When working on frontend code, you're in the `web/` directory working with:

- **Components** (`src/components/`) - Reusable React components
- **Pages** (`src/pages/`) - Page-level components
- **Stores** (`src/stores/`) - Zustand state management
- **API Client** (`src/lib/api.ts`) - HTTP client
- **Tests** (`e2e/`) - Playwright E2E tests

## Technology Stack

- React 18 with TypeScript
- Vite for build/dev
- Zustand for state management
- TipTap for rich text editing
- Tailwind CSS for styling
- Playwright for E2E testing

## Development Principle: Test-Driven Development (TDD)

ALWAYS start with writing tests before implementing features:

1. Write E2E tests that verify the user flow you're implementing
2. Run tests and see them fail
3. Implement the feature to make tests pass
4. Refactor if needed while keeping tests green

## Key Patterns

### Always Use Reusable UI Components

**ALWAYS** check for existing reusable components in `src/components/ui/` before implementing UI patterns. If a reusable component doesn't exist for a common pattern, create one.

Available reusable components:

- `Dropdown` - Dropdowns with click-outside handling and keyboard support
- `ConfirmModal` - Confirmation dialogs for destructive actions
- `Modal` - Base modal component
- `Avatar` - User avatars
- `RoleBadge` - Role display badges
- `StatusBadge` - Status display badges
- `Toast` - Toast notifications

```typescript
// ✅ CORRECT - Use existing Dropdown component
import { Dropdown, DropdownItem } from "@/components/ui/Dropdown";

<Dropdown
  trigger={<button>Open Menu</button>}
  align="left"
>
  <DropdownItem onClick={handleEdit}>Edit</DropdownItem>
  <DropdownItem onClick={handleDelete} variant="danger">Delete</DropdownItem>
</Dropdown>

// ❌ WRONG - Custom dropdown without click-outside handling
const [isOpen, setIsOpen] = useState(false);
{isOpen && <div className="absolute ...">...</div>}
```

### Never Use Browser Dialogs (alert, confirm, prompt)

**NEVER** use browser native dialogs like `alert()`, `confirm()`, or `prompt()`. Always use the custom modal components:

```typescript
// ❌ WRONG - Native browser dialog
if (!confirm("Delete this item?")) return;
await deleteItem(id);

// ✅ CORRECT - Use ConfirmModal component
const [showDeleteConfirm, setShowDeleteConfirm] = useState(false);

// In JSX:
<ConfirmModal
  isOpen={showDeleteConfirm}
  title="Delete Item"
  message="Are you sure you want to delete this item? This action cannot be undone."
  confirmText="Delete"
  confirmVariant="danger"
  onConfirm={handleDelete}
  onCancel={() => setShowDeleteConfirm(false)}
/>
```

The `ConfirmModal` component is located at `src/components/ui/ConfirmModal.tsx` and provides:

- Consistent dark theme styling
- Proper accessibility
- Customizable title, message, and button text
- Danger variant for destructive actions

### State Management with Zustand

```typescript
export const useDocStore = create<DocState>((set, get) => ({
  docs: [],
  isLoading: false,

  fetchDocs: async () => {
    set({ isLoading: true });
    const response = await api.get<Doc[]>("/docs");
    set({ docs: response, isLoading: false });
  },

  updateDoc: async (id: string, data: Partial<Doc>) => {
    const doc = await api.patch<Doc>(`/docs/${id}`, data);
    set((state) => ({
      docs: state.docs.map((d) => (d.id === id ? doc : d)),
    }));
  },
}));
```

### API Calls - Use Flat Params

**IMPORTANT**: Always send params directly without nested wrappers:

```typescript
// ✅ CORRECT - flat params
await api.post("/docs", { title: "My Doc", content: "..." });
await api.post("/channels", { name: "general" });
await api.post("/workspace/members", { name, email, password, role });

// ❌ WRONG - nested under a key
await api.post("/docs", { doc: { title: "My Doc", content: "..." } });
await api.post("/channels", { channel: { name: "general" } });
await api.post("/workspace/members", { user: { name, email, password, role } });
```

This keeps the API contract simple and consistent across all endpoints.

## E2E Testing with Playwright

See the [e2e-testing skill](../e2e-testing/SKILL.md) for critical gotchas about React controlled inputs and Playwright.

**TL;DR**: Use `page.keyboard.insertText()` after selecting text, NOT `fill()`:

```typescript
// ✅ Works with React controlled inputs
await input.focus();
await input.click({ clickCount: 3 }); // Select all
await page.waitForTimeout(100);
await page.keyboard.insertText("New Value");
await page.waitForTimeout(500); // Wait for React state

// ❌ Does NOT work with React
await input.fill("New Value"); // Doesn't trigger onChange
```

## File Locations

- **Pages**: `src/pages/`
- **Components**: `src/components/ui/` (reusable) and `src/components/features/` (feature-specific)
- **Stores**: `src/stores/`
- **Types**: `src/types/index.ts`
- **E2E Tests**: `e2e/`
- **Test Helpers**: `e2e/helpers/`

## Running Frontend

```bash
cd web
npm run dev         # Start dev server (port 5173)
npm test            # Run unit tests
npx playwright test # Run E2E tests
npm run build       # Production build
npm run lint        # Lint code
```

## Testing Best Practices

1. **Write E2E tests for critical user flows**: authentication, document CRUD, real-time features
2. **Use proper selectors**: `getByRole`, `getByLabel`, `getByPlaceholder`
3. **Add accessibility attributes**: `htmlFor` on labels, `id` on inputs
4. **Handle async properly**: Always wait for elements with proper timeouts
5. **Test across browsers**: Chromium, Firefox, and WebKit
