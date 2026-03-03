import { ArrowLeft } from "lucide-react";
import { useNavigate } from "react-router-dom";
import { useIsMobile } from "@/hooks/useIsMobile";

interface MobileBackButtonProps {
  to: string;
}

export function MobileBackButton({ to }: MobileBackButtonProps) {
  const isMobile = useIsMobile();
  const navigate = useNavigate();

  if (!isMobile) return null;

  return (
    <button
      onClick={() => navigate(to)}
      className="p-1.5 -ml-1 rounded-lg text-dark-text-muted hover:text-dark-text transition-colors"
    >
      <ArrowLeft size={20} />
    </button>
  );
}
