import { ReactRenderer } from "@tiptap/react";
import Mention from "@tiptap/extension-mention";
import { SuggestionProps, SuggestionKeyDownProps } from "@tiptap/suggestion";
import tippy, { Instance as TippyInstance } from "tippy.js";
import {
  MentionList,
  MentionListRef,
  MentionMember,
} from "@/components/ui/MentionList";

export interface MentionSuggestionOptions {
  members: MentionMember[];
  onActiveChange?: (isActive: boolean) => void;
}

/**
 * Creates a configured TipTap Mention extension for workspace members.
 *
 * @param options - Configuration options including the list of members
 * @returns Configured Mention extension
 *
 * @example
 * ```tsx
 * const editor = useEditor({
 *   extensions: [
 *     StarterKit,
 *     createMentionExtension({ members: workspaceMembers }),
 *   ],
 * });
 * ```
 */
export function createMentionExtension(options: MentionSuggestionOptions) {
  return Mention.configure({
    HTMLAttributes: {
      class: "mention",
    },
    suggestion: {
      char: "@",
      items: ({ query }: { query: string }) => {
        return options.members.filter((member) =>
          member.name.toLowerCase().includes(query.toLowerCase()),
        );
      },
      render: () => {
        let component: ReactRenderer<MentionListRef> | null = null;
        let popup: TippyInstance[] | null = null;

        return {
          onStart: (props: SuggestionProps<MentionMember>) => {
            options.onActiveChange?.(true);
            component = new ReactRenderer(MentionList, {
              props: {
                items: props.items,
                onSelect: (member: MentionMember) => {
                  props.command({ id: member.id, label: member.name });
                },
              },
              editor: props.editor,
            });

            if (!props.clientRect) {
              return;
            }

            popup = tippy("body", {
              getReferenceClientRect: props.clientRect as () => DOMRect,
              appendTo: () => document.body,
              content: component.element,
              showOnCreate: true,
              interactive: true,
              trigger: "manual",
              placement: "bottom-start",
            });
          },

          onUpdate: (props: SuggestionProps<MentionMember>) => {
            component?.updateProps({
              items: props.items,
              onSelect: (member: MentionMember) => {
                props.command({ id: member.id, label: member.name });
              },
            });

            if (!props.clientRect) {
              return;
            }

            popup?.[0]?.setProps({
              getReferenceClientRect: props.clientRect as () => DOMRect,
            });
          },

          onKeyDown: (props: SuggestionKeyDownProps) => {
            if (props.event.key === "Escape") {
              popup?.[0]?.hide();
              return true;
            }

            return component?.ref?.onKeyDown(props.event) ?? false;
          },

          onExit: () => {
            options.onActiveChange?.(false);
            popup?.[0]?.destroy();
            component?.destroy();
          },
        };
      },
    },
  });
}

// Re-export types for convenience
export type { MentionMember } from "@/components/ui/MentionList";
