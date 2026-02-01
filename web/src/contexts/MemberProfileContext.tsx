import { createContext, useContext, useState, useCallback } from "react";
import { MemberProfileModal } from "@/components/features/MemberProfileModal";

interface MemberProfileContextType {
  openMemberProfile: (memberId: string) => void;
  closeMemberProfile: () => void;
}

const MemberProfileContext = createContext<MemberProfileContextType | null>(
  null,
);

export function MemberProfileProvider({
  children,
}: {
  children: React.ReactNode;
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [memberId, setMemberId] = useState<string | null>(null);

  const openMemberProfile = useCallback((id: string) => {
    setMemberId(id);
    setIsOpen(true);
  }, []);

  const closeMemberProfile = useCallback(() => {
    setIsOpen(false);
    setMemberId(null);
  }, []);

  return (
    <MemberProfileContext.Provider
      value={{ openMemberProfile, closeMemberProfile }}
    >
      {children}
      <MemberProfileModal
        isOpen={isOpen}
        onClose={closeMemberProfile}
        memberId={memberId}
      />
    </MemberProfileContext.Provider>
  );
}

export function useMemberProfile() {
  const context = useContext(MemberProfileContext);
  if (!context) {
    throw new Error(
      "useMemberProfile must be used within a MemberProfileProvider",
    );
  }
  return context;
}
