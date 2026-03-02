import { ReactNode } from "react";
import { X } from "lucide-react";
import { clsx } from "clsx";

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
}: ModalProps) {
  const handleBackdropClick = (e: React.MouseEvent) => {
    if (e.target === e.currentTarget) {
      onClose();
    }
  };

  return (
    <div
      className="fixed inset-0 bg-black/50 flex items-center justify-center p-4"
      style={{ zIndex }}
      onClick={handleBackdropClick}
    >
      <div
        className={clsx(
          "border border-dark-border rounded-lg flex flex-col",
          variant === "surface" ? "bg-dark-surface" : "bg-dark-bg",
          sizeClasses[size],
          className,
        )}
        style={{ maxHeight: maxHeight }}
      >
        {(title || showCloseButton) && (
          <div className="px-6 py-4 border-b border-dark-border flex items-center justify-between flex-shrink-0">
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
