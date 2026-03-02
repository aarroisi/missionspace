import { useState, useRef, useEffect, ReactNode } from "react";
import { clsx } from "clsx";

interface DropdownProps {
  trigger: ReactNode;
  children: ReactNode;
  align?: "left" | "right";
  position?: "top" | "bottom";
  className?: string;
}

export function Dropdown({
  trigger,
  children,
  align = "left",
  position = "bottom",
  className,
}: DropdownProps) {
  const [isOpen, setIsOpen] = useState(false);
  const dropdownRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    function handleClickOutside(event: MouseEvent) {
      if (
        dropdownRef.current &&
        !dropdownRef.current.contains(event.target as Node)
      ) {
        setIsOpen(false);
      }
    }

    if (isOpen) {
      document.addEventListener("mousedown", handleClickOutside);
    }

    return () => {
      document.removeEventListener("mousedown", handleClickOutside);
    };
  }, [isOpen]);

  useEffect(() => {
    function handleEscape(event: KeyboardEvent) {
      if (event.key === "Escape") {
        setIsOpen(false);
      }
    }

    if (isOpen) {
      document.addEventListener("keydown", handleEscape);
    }

    return () => {
      document.removeEventListener("keydown", handleEscape);
    };
  }, [isOpen]);

  return (
    <div ref={dropdownRef} className={clsx("relative", className)}>
      <div
        onClick={(e) => {
          e.stopPropagation();
          setIsOpen(!isOpen);
        }}
      >
        {trigger}
      </div>

      {isOpen && (
        <div
          className={clsx(
            "absolute z-50 min-w-48 py-1 bg-dark-surface border border-dark-border rounded-lg shadow-lg",
            align === "left" ? "left-0" : "right-0",
            position === "top" ? "bottom-full mb-2" : "top-full mt-2",
          )}
          onClick={() => setIsOpen(false)}
        >
          {children}
        </div>
      )}
    </div>
  );
}

interface DropdownItemProps {
  onClick?: () => void;
  children: ReactNode;
  variant?: "default" | "danger";
  disabled?: boolean;
}

export function DropdownItem({
  onClick,
  children,
  variant = "default",
  disabled = false,
}: DropdownItemProps) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      className={clsx(
        "w-full px-4 py-2 text-left text-sm transition-colors",
        disabled && "opacity-50 cursor-not-allowed",
        variant === "danger"
          ? "text-red-400 hover:bg-red-500/10"
          : "text-dark-text hover:bg-dark-border",
      )}
    >
      {children}
    </button>
  );
}

export function DropdownDivider() {
  return <div className="my-1 border-t border-dark-border" />;
}
