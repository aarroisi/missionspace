import { $nodeSchema, $remark, $prose, $ctx } from "@milkdown/utils";
import type { Ctx } from "@milkdown/ctx";
import { Plugin, PluginKey } from "@milkdown/prose/state";
import type { EditorView } from "@milkdown/prose/view";
import type { MentionMember } from "@/components/ui/MentionList";
import type { RemarkPluginRaw } from "@milkdown/transformer";

// Context slice for providing members list
export const mentionMembersCtx = $ctx([] as MentionMember[], "mentionMembers");

// Context slice for mention active state callback
export const mentionActiveCtx = $ctx(
  null as ((active: boolean) => void) | null,
  "mentionActive",
);

/**
 * Remark plugin that transforms link nodes with `member:` protocol
 * into `mention` MDAST nodes, and vice versa.
 *
 * Markdown format: @[Name](member:uuid)
 * Parsed as standard link by remark, then we transform links with member: protocol
 */
const remarkMentionPlugin: RemarkPluginRaw<Record<string, unknown>> =
  function () {
    // Transform MDAST: convert links with member: protocol to mention nodes
    return (tree: any) => {
      visitTree(tree, (node: any, index: number, parent: any) => {
        // Match links like [Name](member:uuid) or [@Name](member:uuid)
        if (
          node.type === "link" &&
          typeof node.url === "string" &&
          node.url.startsWith("member:")
        ) {
          const memberId = node.url.slice("member:".length);
          let label = "";
          // Extract text from children
          if (node.children?.length > 0) {
            label = node.children
              .map((c: any) => c.value || "")
              .join("")
              .replace(/^@/, ""); // Remove leading @ if present
          }
          // Replace link node with mention node
          parent.children[index] = {
            type: "mention",
            data: {
              id: memberId,
              label,
            },
          };
        }
      });
    };
  };

function visitTree(
  tree: any,
  visitor: (node: any, index: number, parent: any) => void,
) {
  if (tree.children) {
    for (let i = 0; i < tree.children.length; i++) {
      visitor(tree.children[i], i, tree);
      visitTree(tree.children[i], visitor);
    }
  }
}

export const remarkMention = $remark("remarkMention", () => remarkMentionPlugin);

/**
 * Milkdown mention node schema.
 * Defines how mentions are parsed from markdown and serialized back.
 */
export const mentionSchema = $nodeSchema("mention", () => ({
  inline: true,
  group: "inline",
  atom: true,
  selectable: true,
  marks: "",
  attrs: {
    id: { default: "" },
    label: { default: "" },
  },
  parseDOM: [
    {
      tag: 'span[data-type="mention"]',
      getAttrs: (dom: Node) => {
        if (!(dom instanceof HTMLElement)) return false;
        return {
          id: dom.getAttribute("data-id") || "",
          label: dom.getAttribute("data-label") || "",
        };
      },
    },
  ],
  toDOM: (node: any) => [
    "span",
    {
      class: "mention",
      "data-type": "mention",
      "data-id": node.attrs.id,
      "data-label": node.attrs.label,
    },
    `@${node.attrs.label}`,
  ],
  parseMarkdown: {
    match: (mdNode: any) => mdNode.type === "mention",
    runner: (state: any, mdNode: any, proseType: any) => {
      state.addNode(proseType, {
        id: mdNode.data?.id || "",
        label: mdNode.data?.label || "",
      });
    },
  },
  toMarkdown: {
    match: (node: any) => node.type.name === "mention",
    runner: (state: any, node: any) => {
      // Serialize as @[Name](member:uuid) — a standard markdown link
      state.addNode("link", undefined, undefined, {
        url: `member:${node.attrs.id}`,
        title: null,
        children: [{ type: "text", value: `@${node.attrs.label}` }],
      });
    },
  },
}));

/**
 * Plugin key for the mention autocomplete ProseMirror plugin
 */
const mentionPluginKey = new PluginKey("mention-autocomplete");

/**
 * ProseMirror plugin for mention autocomplete.
 * Detects @ character input and shows a popup with member suggestions.
 */
export const mentionAutocomplete = $prose((ctx: Ctx) => {
  return new Plugin({
    key: mentionPluginKey,
    state: {
      init() {
        return {
          active: false,
          query: "",
          from: 0,
          popup: null as HTMLDivElement | null,
        };
      },
      apply(tr, prev) {
        const meta = tr.getMeta(mentionPluginKey);
        if (meta) return { ...prev, ...meta };
        if (!tr.docChanged) return prev;
        // If doc changed and we were active, update the query
        if (prev.active) {
          const { from } = prev;
          const $pos = tr.doc.resolve(Math.min(from, tr.doc.content.size));
          const textAfter = tr.doc.textBetween(
            from,
            tr.selection.from,
            "\0",
            "\0",
          );
          if (textAfter.includes(" ") || textAfter.includes("\n")) {
            return { active: false, query: "", from: 0, popup: prev.popup };
          }
          return { ...prev, query: textAfter, from: $pos.pos };
        }
        return prev;
      },
    },
    props: {
      handleTextInput(view, from, _to, text) {
        if (text === "@") {
          const state = mentionPluginKey.getState(view.state);
          if (!state?.active) {
            view.dispatch(
              view.state.tr.setMeta(mentionPluginKey, {
                active: true,
                query: "",
                from: from + 1, // Position after the @
              }),
            );
            setTimeout(() => showPopup(view, ctx), 0);
          }
        }
        return false;
      },
      handleKeyDown(view, event) {
        const state = mentionPluginKey.getState(view.state);
        if (!state?.active) return false;

        if (event.key === "Escape") {
          dismissPopup(view);
          return true;
        }

        if (
          event.key === "ArrowDown" ||
          event.key === "ArrowUp" ||
          event.key === "Enter" ||
          event.key === "Tab"
        ) {
          // Let the popup handle these
          const popup = getPopupContainer();
          if (popup.style.display !== "none") {
            const customEvent = new CustomEvent("mention-keydown", {
              detail: { key: event.key },
            });
            popup.dispatchEvent(customEvent);
            return true;
          }
        }

        return false;
      },
    },
    view() {
      return {
        update(view) {
          const state = mentionPluginKey.getState(view.state);
          if (state?.active) {
            updatePopup(view, ctx);
          }
        },
        destroy() {
          // Cleanup popup if exists
        },
      };
    },
  });
});

function getPopupContainer(): HTMLDivElement {
  let container = document.getElementById(
    "milkdown-mention-popup",
  ) as HTMLDivElement | null;
  if (!container) {
    container = document.createElement("div");
    container.id = "milkdown-mention-popup";
    container.style.position = "fixed";
    container.style.zIndex = "9999";
    container.style.display = "none";
    document.body.appendChild(container);
  }
  return container;
}

function showPopup(view: EditorView, ctx: Ctx) {
  const state = mentionPluginKey.getState(view.state);
  if (!state?.active) return;

  const container = getPopupContainer();
  container.style.display = "block";

  // Notify active state
  const onActive = ctx.get(mentionActiveCtx.key);
  onActive?.(true);

  updatePopup(view, ctx);
}

function updatePopup(view: EditorView, ctx: Ctx) {
  const state = mentionPluginKey.getState(view.state);
  if (!state?.active) return;

  const container = getPopupContainer();
  const members = ctx.get(mentionMembersCtx.key);
  const query = state.query.toLowerCase();
  const filtered = members.filter((m: MentionMember) =>
    m.name.toLowerCase().includes(query),
  );

  // Position popup near cursor
  const coords = view.coordsAtPos(view.state.selection.from);
  container.style.left = `${coords.left}px`;
  container.style.top = `${coords.bottom + 4}px`;

  // Render the mention list
  renderMentionList(container, filtered, view, ctx, state);
}

function dismissPopup(view: EditorView) {
  const container = getPopupContainer();
  container.style.display = "none";
  container.innerHTML = "";

  // Get active callback before dismissing
  try {
    // Note: ctx might not be accessible here, so we just hide the popup
  } catch {
    // Ignore
  }

  view.dispatch(
    view.state.tr.setMeta(mentionPluginKey, {
      active: false,
      query: "",
      from: 0,
      popup: null,
    }),
  );
}

function selectMember(
  view: EditorView,
  member: MentionMember,
  ctx: Ctx,
  pluginState: any,
) {
  const { from } = pluginState;
  const mentionType = view.state.schema.nodes.mention;
  if (!mentionType) return;

  // Replace @query with mention node
  // from is the position after @, so we need from - 1 to include the @
  const tr = view.state.tr
    .delete(from - 1, view.state.selection.from)
    .insert(
      from - 1,
      mentionType.create({ id: member.id, label: member.name }),
    );

  view.dispatch(tr);
  view.focus();

  // Dismiss popup
  const container = getPopupContainer();
  container.style.display = "none";
  container.innerHTML = "";

  view.dispatch(
    view.state.tr.setMeta(mentionPluginKey, {
      active: false,
      query: "",
      from: 0,
      popup: null,
    }),
  );

  // Notify active state
  const onActive = ctx.get(mentionActiveCtx.key);
  onActive?.(false);
}

let selectedIndex = 0;

function renderMentionList(
  container: HTMLDivElement,
  members: MentionMember[],
  view: EditorView,
  ctx: Ctx,
  pluginState: any,
) {
  // Reset selection if it's out of bounds
  if (selectedIndex >= members.length) selectedIndex = 0;

  container.innerHTML = "";

  if (members.length === 0) {
    container.innerHTML = `
      <div class="bg-dark-surface border border-dark-border rounded-lg shadow-lg p-3">
        <p class="text-dark-text-muted text-sm">No members found</p>
      </div>
    `;
    return;
  }

  const list = document.createElement("div");
  list.className =
    "bg-dark-surface border border-dark-border rounded-lg shadow-lg overflow-hidden max-h-64 overflow-y-auto";

  members.forEach((member, index) => {
    const item = document.createElement("button");
    item.className = `w-full flex items-center gap-3 px-3 py-2 text-left transition-colors ${
      index === selectedIndex
        ? "bg-dark-border text-dark-text"
        : "text-dark-text hover:bg-dark-border/50"
    }`;
    item.innerHTML = `
      <div class="w-7 h-7 rounded-full bg-blue-600 flex items-center justify-center text-white text-xs font-medium flex-shrink-0">
        ${member.name.charAt(0).toUpperCase()}
      </div>
      <div class="flex-1 min-w-0">
        <p class="text-sm font-medium truncate">${member.name}</p>
        ${member.email ? `<p class="text-xs text-dark-text-muted truncate">${member.email}</p>` : ""}
      </div>
    `;
    item.addEventListener("mousedown", (e) => {
      e.preventDefault();
      selectMember(view, member, ctx, pluginState);
    });
    list.appendChild(item);
  });

  container.appendChild(list);

  // Handle keyboard events from the editor
  container.addEventListener(
    "mention-keydown",
    ((e: CustomEvent) => {
      const { key } = e.detail;
      if (key === "ArrowDown") {
        selectedIndex = (selectedIndex + 1) % members.length;
        renderMentionList(container, members, view, ctx, pluginState);
      } else if (key === "ArrowUp") {
        selectedIndex =
          selectedIndex <= 0 ? members.length - 1 : selectedIndex - 1;
        renderMentionList(container, members, view, ctx, pluginState);
      } else if (key === "Enter" || key === "Tab") {
        const member = members[selectedIndex];
        if (member) {
          selectMember(view, member, ctx, pluginState);
        }
      }
    }) as EventListener,
    { once: true },
  );
}

/**
 * All mention plugin pieces bundled together.
 * Usage:
 * ```ts
 * const crepe = new Crepe({ ... });
 * crepe.editor
 *   .use(remarkMention)
 *   .use(mentionSchema.node)
 *   .use(mentionSchema.ctx)
 *   .use(mentionMembersCtx)
 *   .use(mentionActiveCtx)
 *   .use(mentionAutocomplete);
 * ```
 */
export const mentionPlugins = [
  remarkMention,
  mentionSchema.node,
  mentionSchema.ctx,
  mentionMembersCtx,
  mentionActiveCtx,
  mentionAutocomplete,
];
