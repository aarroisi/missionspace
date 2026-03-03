import { ReactNode } from "react";
import { X } from "lucide-react";
import { clsx } from "clsx";
import { useIsMobile } from "@/hooks/useIsMobile";

type ModalSize = "sm" | "md" | "lg" | "xl" | "2xl" | "3xl" | "full";
type ModalVariant = "surface" | "bg";

interface ModalProps {
  children: ReactNode;
  onClose: () => void;
  title?: string;
  size?: ModalSize;
  variant?: ModalVariant;
  className?: string;
  showCloseButton?: boolean;
  zIndex?: number;
  maxHeight?: string;
  fullScreenOnMobile?: boolean;
}

const sizeClasses: Record<ModalSize, string> = {
  sm: "max-w-sm w-full",
  md: "max-w-md w-full",
  lg: "max-w-lg w-full",
  xl: "max-w-xl w-full",
  "2xl": "max-w-2xl w-full",
  "3xl": "max-w-3xl w-full",
  full: "w-full max-w-[900px] max-h-[calc(100vh-2rem)]",
};

export function Modal({
  children,
  onClose,
  title,
  size = "md",
  variant = "surface",
  className,
  showCloseButton = true,
  zIndex = 50,
  maxHeight,
  fullScreenOnMobile = true,
}: ModalProps) {
  const isMobile = useIsMobile();

  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  const mobileFullScreen = isMobile && fullScreenOnMobile;

  return (
    <div
      className={clsx(
        "fixed inset-0 bg-black/50 flex",
        mobileFullScreen
          ? "items-stretch"
          : "items-center justify-center p-4",
      )}
      style={{ zIndex }}
      onClick={handleBackdropClick}
    >
      <div
        className={clsx(
          "flex flex-col",
          variant === "surface" ? "bg-dark-surface" : "bg-dark-bg",
          mobileFullScreen
            ? "w-full h-full"
            : clsx(
                "border border-dark-border rounded-lg overflow-hidden",
                sizeClasses[size],
                className,
              ),
        )}
        style={{ maxHeight: mobileFullScreen ? undefined : maxHeight }}
      >
        {(title || showCloseButton) && (
          <div className={clsx(
            "border-b border-dark-border flex items-center justify-between flex-shrink-0",
            mobileFullScreen ? "px-4 py-3 pt-[max(0.75rem,env(safe-area-inset-top))]" : "px-6 py-4",
          )}>
            {title && <h3 className="font-semibold text-dark-text">{title}</h3>}
            {showCloseButton && (
              <button
                onClick={onClose}
                className="text-dark-text-muted hover:text-dark-text transition-colors ml-auto"
              >
                <X size={20} />
              </button>
            )}
          </div>
        )}
        {children}
      </div>
    </div>
  );
}
