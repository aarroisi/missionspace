# Rich Text Editors Inventory

All rich text editors in Missionspace use a single unified `RichTextEditor` component
(`src/lib/milkdown/RichTextEditor.tsx`) that bundles the toolbar, node plugins,
and Milkdown editor into one place. Every editor has identical functionality;
only styling differs via props.

## Editor Locations

| Location | Component | File | Notes |
|----------|-----------|------|-------|
| Document editing | `RichTextEditor` | `src/pages/DocView.tsx` | Full editor with file uploads, mentions, drag/drop |
| Comments | `CommentEditor` wraps `RichTextEditor` | `src/components/features/CommentEditor.tsx` | Enter to submit, quote UI, send button via `toolbarExtra` |
| Thread replies | `CommentEditor` (variant="thread") | `src/components/features/DiscussionThread.tsx` | Same as comments |
| Task notes | `RichTextNotesEditor` wraps `RichTextEditor` | `src/components/ui/RichTextNotesEditor.tsx` | Thin wrapper adding border + min-height |
| Message edit | `RichTextEditor` | `src/components/features/Message.tsx` | Inline editing with save/cancel |

## Unified Component: `RichTextEditor`

**File**: `src/lib/milkdown/RichTextEditor.tsx`

### What it bundles internally:
- `useToolbarPlugin()` hook for tracking active formatting state
- `EditorToolbar` — always renders full toolbar (B, I, S, Code | H1, H2, H3 | Quote, BulletList, OrderedList)
- All node plugins: `imageBlockPlugins`, `fileAttachmentPlugins`, `imageGridPlugins`, `nodeViewPlugins`
- Optional file upload button (paperclip icon) when `fileUpload` prop is provided
- `MilkdownEditor` with all plugins merged

### Key Props:
- `value`, `onChange`, `onBlur`, `onFocus` — standard controlled input
- `placeholder`, `editable`, `className` — standard editor config
- `mentions` — `{ members, onActiveChange? }` for @mention support
- `fileUpload` — `{ attachableType, attachableId, onError }` for toolbar file upload button
- `plugins` — extra MilkdownPlugin[] (e.g. submit-on-enter)
- `showToolbar` — override toolbar visibility (default: true when editable)
- `toolbarExtra` — ReactNode rendered at the far-right of the toolbar row
- `onReady` — `(handle: RichTextEditorHandle) => void`

## Internal Components (not used directly by consumers)

- **`MilkdownEditor`** (`src/lib/milkdown/MilkdownEditor.tsx`): Low-level Crepe wrapper
- **`EditorToolbar`** (`src/lib/milkdown/EditorToolbar.tsx`): Toolbar with formatting buttons
- **`useToolbarPlugin()`**: Hook that creates ProseMirror plugin for tracking active state
- **`ContentRenderer`** (`src/lib/milkdown/ContentRenderer.tsx`): Read-only markdown/HTML renderer
- **Node plugins** (`src/lib/milkdown/nodes/`): Custom node schemas and views for images, files, grids

## Important Notes

1. Delete buttons on attachments use inline `style.backgroundColor` (not Tailwind classes) because `.milkdown button` CSS resets backgrounds
2. Images have `maxWidth: 800px` applied via inline styles
3. Crepe's built-in features (toolbar, block-edit, image-block, code-mirror, table, latex) are disabled — we use our own implementations
