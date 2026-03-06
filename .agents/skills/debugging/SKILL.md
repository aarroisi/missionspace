# Debugging Skills

## Tailwind CSS Class Conflicts - Active/Highlight States

### The Problem
When using `clsx` to conditionally add highlight classes, you might write:

```typescript
// BROKEN - text-dark-text-muted always wins!
className={clsx(
  "text-dark-text-muted",
  isActive && "text-blue-400",
)}
```

The highlight (`text-blue-400`) never appears even when `isActive` is true.

### Why It Happens
In Tailwind CSS, when two classes affect the same CSS property (e.g., `color`), the winner is determined by:
1. **CSS specificity** (same for utility classes)
2. **Order in the compiled stylesheet** (NOT the order in your class attribute)

Since both classes have the same specificity, whichever appears later in Tailwind's compiled CSS wins. The order in your `className` string is irrelevant.

### The Fix
Use mutually exclusive classes with ternary operator:

```typescript
// CORRECT - only one text color class is ever applied
className={clsx(
  "other-classes",
  isActive
    ? "bg-dark-surface text-blue-400"
    : "text-dark-text-muted",
)}
```

### Debugging Checklist for "Highlight Not Working"

1. **Check if the condition is true** - Add `console.log` to verify
2. **Check for CSS class conflicts** - Look for competing color/background classes
3. **Use browser DevTools** - Inspect element, see which class is winning (crossed out = losing)
4. **Use either/or pattern** - Never have both base and highlight color classes applied simultaneously

### Real Example from Missionspace

```typescript
// Before (broken):
{projectDocs.map((doc) => (
  <button
    className={clsx(
      "... text-dark-text-muted",
      activeItemId === doc.id && "bg-dark-surface text-blue-400",
    )}
  >

// After (fixed):
{projectDocs.map((doc) => {
  const isActive = activeItemId === doc.id;
  return (
    <button
      className={clsx(
        "... hover:bg-dark-surface transition-colors",
        isActive
          ? "bg-dark-surface text-blue-400"
          : "text-dark-text-muted",
      )}
    >
```

### Other Common Patterns

**Background colors:**
```typescript
className={clsx(
  "base-styles",
  isSelected ? "bg-blue-600" : "bg-dark-surface",
)}
```

**Border colors:**
```typescript
className={clsx(
  "border",
  hasError ? "border-red-500" : "border-dark-border",
)}
```

## URL-Based State vs Store State for UI Highlighting

### The Problem
Using Zustand store state set via `useEffect` for highlighting can cause timing issues:
1. Component renders with old/null state
2. `useEffect` runs and updates store
3. Component should re-render but sometimes doesn't

### The Fix
Compute UI state directly from URL using `useMemo` for immediate, synchronous updates:

```typescript
// Compute directly from URL - no timing issues
const activeItemId = useMemo(() => {
  const pathParts = location.pathname.split("/").filter(Boolean);
  // Parse URL and return the active item ID
  return pathParts[3] || null;
}, [location.pathname]);

// Still sync to store for other components if needed
useEffect(() => {
  setActiveItem({ type: itemType, id: activeItemId });
}, [location.pathname]);
```

This ensures highlighting is always in sync with the URL on every render.
