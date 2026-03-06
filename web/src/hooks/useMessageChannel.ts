import { useChannel } from "@/hooks/useChannel";
import { convertKeysToCamelCase } from "@/lib/api";
import { useChatStore } from "@/stores/chatStore";
import { Message } from "@/types";

export function useMessageChannel(topic: string) {
  const addMessage = useChatStore((state) => state.addMessage);
  const upsertMessage = useChatStore((state) => state.upsertMessage);
  const removeMessage = useChatStore((state) => state.removeMessage);

  useChannel(topic, (event, payload) => {
    const normalizedPayload = convertKeysToCamelCase(payload) as {
      message?: Message;
      messageId?: string;
    };

    if (event === "new_message" && normalizedPayload.message) {
      addMessage(normalizedPayload.message);
      return;
    }

    if (event === "message_updated" && normalizedPayload.message) {
      upsertMessage(normalizedPayload.message);
      return;
    }

    if (event === "message_deleted" && normalizedPayload.messageId) {
      removeMessage(normalizedPayload.messageId);
    }
  });
}
