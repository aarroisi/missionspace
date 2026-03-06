import { unified } from "unified";
import rehypeParse from "rehype-parse";
import rehypeRemark from "rehype-remark";
import remarkStringify from "remark-stringify";
import remarkParse from "remark-parse";
import remarkGfm from "remark-gfm";
import remarkRehype from "remark-rehype";
import rehypeStringify from "rehype-stringify";
import type { Handle } from "hast-util-to-mdast";

/**
 * Detects whether content is HTML or markdown.
 * Uses simple heuristic: if content starts with an HTML tag, it's HTML.
 */
export function isHtml(content: string): boolean {
  if (!content || !content.trim()) return false;
  const trimmed = content.trim();
  // Check if content starts with an HTML tag
  return /^<[a-z][\s\S]*>/i.test(trimmed);
}

/**
 * Custom rehype-remark handlers for Missionspace-specific HTML elements.
 */
const customHandlers: Record<string, Handle> = {
  // Handle mention spans: <span data-type="mention" data-id="uuid" data-label="Name">@Name</span>
  span: (state, node) => {
    const props = node.properties || {};
    if (props.dataType === "mention" && props.dataId) {
      const label = (props.dataLabel as string) || "";
      const id = props.dataId as string;
      return {
        type: "text",
        value: `@[${label}](member:${id})`,
      };
    }
    // Default: process children
    return state.all(node) as any;
  },

  // Handle image block divs
  div: (state, node) => {
    const props = node.properties || {};
    const dataType = props.dataType as string;

    if (dataType === "image-block" && props.dataAssetId) {
      const attrs: string[] = [`assetId="${props.dataAssetId}"`];
      if (props.dataFilename) attrs.push(`filename="${props.dataFilename}"`);
      if (props.dataAlt) attrs.push(`alt="${props.dataAlt}"`);
      if (props.dataCaption) attrs.push(`caption="${props.dataCaption}"`);
      return {
        type: "text",
        value: `::image{${attrs.join(" ")}}`,
      };
    }

    if (dataType === "file-attachment" && props.dataAssetId) {
      const attrs: string[] = [`assetId="${props.dataAssetId}"`];
      if (props.dataFilename) attrs.push(`filename="${props.dataFilename}"`);
      if (props.dataContentType)
        attrs.push(`contentType="${props.dataContentType}"`);
      if (props.dataSize) attrs.push(`size="${props.dataSize}"`);
      return {
        type: "text",
        value: `::file{${attrs.join(" ")}}`,
      };
    }

    if (dataType === "image-grid") {
      // Process child image blocks
      const children: string[] = [];
      for (const child of node.children || []) {
        if (
          child.type === "element" &&
          (child.properties?.dataType === "image-block" ||
            child.tagName === "div")
        ) {
          const cp = child.properties || {};
          if (cp.dataAssetId) {
            const attrs: string[] = [`assetId="${cp.dataAssetId}"`];
            if (cp.dataFilename) attrs.push(`filename="${cp.dataFilename}"`);
            if (cp.dataAlt) attrs.push(`alt="${cp.dataAlt}"`);
            if (cp.dataCaption) attrs.push(`caption="${cp.dataCaption}"`);
            children.push(`::image{${attrs.join(" ")}}`);
          }
        }
      }
      return {
        type: "text",
        value: `:::image-grid\n${children.join("\n")}\n:::`,
      };
    }

    // Default: process children
    return state.all(node) as any;
  },
};

/**
 * Converts HTML content to Markdown.
 * Handles standard HTML and Missionspace-specific custom nodes (mentions, images, files).
 */
export function htmlToMarkdown(html: string): string {
  if (!html || !html.trim()) return "";

  const result = unified()
    .use(rehypeParse, { fragment: true })
    .use(rehypeRemark, { handlers: customHandlers })
    .use(remarkStringify)
    .processSync(html);

  return String(result).trim();
}

/**
 * Converts Markdown content to HTML for display rendering.
 * Used for backward compatibility and ContentRenderer.
 */
export function markdownToHtml(markdown: string): string {
  if (!markdown || !markdown.trim()) return "";

  // Handle mention syntax in both legacy and standard markdown link forms:
  // - Legacy:   @[Name](member:uuid)
  // - Standard: [@Name](member:uuid)
  // Convert both to a styled mention span before markdown parsing.
  let processed = markdown.replace(
    /@\[([^\]]+)\]\(member:([^)]+)\)/g,
    '<span class="mention" data-type="mention" data-id="$2" data-label="$1">@$1</span>',
  );

  processed = processed.replace(
    /\[@([^\]]+)\]\(member:([^)]+)\)/g,
    '<span class="mention" data-type="mention" data-id="$2" data-label="$1">@$1</span>',
  );

  // Handle image directives: ::image{...} → placeholder div
  processed = processed.replace(
    /::image\{([^}]+)\}/g,
    (_match, attrs: string) => {
      const parsed = parseDirectiveAttrs(attrs);
      return `<div data-type="image-block" data-asset-id="${parsed.assetId || ""}" data-filename="${parsed.filename || ""}" data-alt="${parsed.alt || ""}" data-caption="${parsed.caption || ""}" class="image-block-wrapper"><img alt="${parsed.alt || parsed.filename || ""}" /></div>`;
    },
  );

  // Handle file directives: ::file{...} → placeholder div
  processed = processed.replace(
    /::file\{([^}]+)\}/g,
    (_match, attrs: string) => {
      const parsed = parseDirectiveAttrs(attrs);
      return `<div data-type="file-attachment" data-asset-id="${parsed.assetId || ""}" data-filename="${parsed.filename || ""}" data-content-type="${parsed.contentType || ""}" data-size="${parsed.size || ""}" class="file-attachment-block">${parsed.filename || "File"}</div>`;
    },
  );

  // Handle image grid containers
  processed = processed.replace(
    /:::image-grid\n([\s\S]*?)\n:::/g,
    (_match, content: string) => {
      return `<div data-type="image-grid" class="image-grid">${content}</div>`;
    },
  );

  const result = unified()
    .use(remarkParse)
    .use(remarkGfm)
    .use(remarkRehype, { allowDangerousHtml: true })
    .use(rehypeStringify, { allowDangerousHtml: true })
    .processSync(processed);

  return String(result);
}

/**
 * Parse directive attributes string like: assetId="uuid" filename="photo.jpg"
 */
function parseDirectiveAttrs(attrs: string): Record<string, string> {
  const result: Record<string, string> = {};
  const regex = /(\w+)="([^"]*)"/g;
  let match;
  while ((match = regex.exec(attrs)) !== null) {
    result[match[1]] = match[2];
  }
  return result;
}
