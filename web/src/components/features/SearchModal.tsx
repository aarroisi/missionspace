import { useEffect, useRef, useMemo, useCallback } from "react";
import { useNavigate } from "react-router-dom";
import {
  Search,
  Briefcase,
  Kanban,
  CheckSquare,
  Folder,
  FileText,
  Hash,
  X,
} from "lucide-react";
import { clsx } from "clsx";
import { useSearchStore } from "@/stores/searchStore";
import { useIsMobile } from "@/hooks/useIsMobile";
import { Avatar } from "@/components/ui/Avatar";
import type { SearchResults } from "@/types";

type ResultType =
  | "project"
  | "board"
  | "task"
  | "docFolder"
  | "doc"
  | "channel"
  | "member";

interface FlatResult {
  type: ResultType;
  id: string;
  data: any;
}

const categoryLabels: Record<ResultType, string> = {
  project: "Projects",
  board: "Boards",
  task: "Tasks",
  docFolder: "Folders",
  doc: "Docs",
  channel: "Channels",
  member: "Members",
};

function flattenResults(results: SearchResults): FlatResult[] {
  const flat: FlatResult[] = [];
  results.projects.forEach((p) =>
    flat.push({ type: "project", id: p.id, data: p }),
  );
  results.boards.forEach((b) =>
    flat.push({ type: "board", id: b.id, data: b }),
  );
  results.tasks.forEach((t) =>
    flat.push({ type: "task", id: t.id, data: t }),
  );
  results.docFolders.forEach((f) =>
    flat.push({ type: "docFolder", id: f.id, data: f }),
  );
  results.docs.forEach((d) => flat.push({ type: "doc", id: d.id, data: d }));
  results.channels.forEach((c) =>
    flat.push({ type: "channel", id: c.id, data: c }),
  );
  results.members.forEach((m) =>
    flat.push({ type: "member", id: m.id, data: m }),
  );
  return flat;
}

function getResultUrl(item: FlatResult): string | null {
  switch (item.type) {
    case "project":
      return `/projects/${item.id}`;
    case "board":
      return `/boards/${item.id}`;
    case "task":
      return `/boards/${item.data.boardId}?task=${item.id}`;
    case "docFolder":
      return `/doc-folders/${item.id}`;
    case "doc":
      return item.data.docFolderId
        ? `/doc-folders/${item.data.docFolderId}/docs/${item.id}`
        : `/docs/${item.id}`;
    case "channel":
      return `/channels/${item.id}`;
    case "member":
      return null;
    default:
      return "/dashboard";
  }
}

function ResultIcon({ type }: { type: ResultType }) {
  switch (type) {
    case "project":
      return <Briefcase size={16} className="text-dark-text-muted shrink-0" />;
    case "board":
      return <Kanban size={16} className="text-dark-text-muted shrink-0" />;
    case "task":
      return (
        <CheckSquare size={16} className="text-dark-text-muted shrink-0" />
      );
    case "docFolder":
      return <Folder size={16} className="text-dark-text-muted shrink-0" />;
    case "doc":
      return <FileText size={16} className="text-dark-text-muted shrink-0" />;
    case "channel":
      return <Hash size={16} className="text-dark-text-muted shrink-0" />;
    default:
      return null;
  }
}

function ResultRow({
  item,
  isSelected,
  onSelect,
  onNavigate,
}: {
  item: FlatResult;
  isSelected: boolean;
  onSelect: () => void;
  onNavigate: () => void;
}) {
  const ref = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (isSelected && ref.current) {
      ref.current.scrollIntoView({ block: "nearest" });
    }
  }, [isSelected]);

  if (item.type === "member") {
    return (
      <button
        ref={ref}
        className={clsx(
          "w-full px-3 py-2 flex items-center gap-3 text-left text-sm transition-colors",
          isSelected ? "bg-dark-border" : "hover:bg-dark-border/50",
        )}
        onMouseEnter={onSelect}
        onClick={onNavigate}
      >
        <Avatar name={item.data.name} src={item.data.avatar} size="xs" />
        <span className="text-dark-text truncate">{item.data.name}</span>
        <span className="text-dark-text-muted text-xs truncate ml-auto">
          {item.data.email}
        </span>
      </button>
    );
  }

  return (
    <button
      ref={ref}
      className={clsx(
        "w-full px-3 py-2 flex items-center gap-3 text-left text-sm transition-colors",
        isSelected ? "bg-dark-border" : "hover:bg-dark-border/50",
      )}
      onMouseEnter={onSelect}
      onClick={onNavigate}
    >
      <ResultIcon type={item.type} />
      <span className="text-dark-text truncate">
        {item.type === "task" && item.data.key && (
          <span className="text-dark-text-muted mr-1.5">{item.data.key}</span>
        )}
        {item.type === "doc" && item.data.key && (
          <span className="text-dark-text-muted mr-1.5">{item.data.key}</span>
        )}
        {item.type === "board" && (
          <span className="text-dark-text-muted mr-1.5">
            {item.data.prefix}
          </span>
        )}
        {item.data.name || item.data.title}
      </span>
      {item.type === "task" && item.data.status && (
        <span
          className="ml-auto text-xs px-1.5 py-0.5 rounded shrink-0"
          style={{
            backgroundColor: item.data.status.color + "20",
            color: item.data.status.color,
          }}
        >
          {item.data.status.name}
        </span>
      )}
    </button>
  );
}

export function SearchModal() {
  const navigate = useNavigate();
  const inputRef = useRef<HTMLInputElement>(null);
  const isMobile = useIsMobile();
  const {
    isOpen,
    query,
    results,
    isLoading,
    selectedIndex,
    close,
    setQuery,
    fetchResults,
    setSelectedIndex,
  } = useSearchStore();

  const flatResults = useMemo(() => flattenResults(results), [results]);

  // Auto-focus input when modal opens
  useEffect(() => {
    if (isOpen) {
      setTimeout(() => inputRef.current?.focus(), 0);
    }
  }, [isOpen]);

  // Debounced fetch
  useEffect(() => {
    if (!isOpen) return;
    const timer = setTimeout(() => {
      fetchResults(query);
    }, 300);
    return () => clearTimeout(timer);
  }, [query, isOpen, fetchResults]);

  const handleNavigate = useCallback(
    (item: FlatResult) => {
      const url = getResultUrl(item);
      if (url) {
        navigate(url);
        close();
      }
    },
    [navigate, close],
  );

  const handleKeyDown = useCallback(
    (e: React.KeyboardEvent) => {
      if (e.key === "ArrowDown") {
        e.preventDefault();
        setSelectedIndex(
          selectedIndex >= flatResults.length - 1 ? 0 : selectedIndex + 1,
        );
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setSelectedIndex(
          selectedIndex <= 0 ? flatResults.length - 1 : selectedIndex - 1,
        );
      } else if (e.key === "Enter" && flatResults.length > 0) {
        e.preventDefault();
        const item = flatResults[selectedIndex];
        if (item) {
          handleNavigate(item);
        }
      } else if (e.key === "Escape") {
        close();
      }
    },
    [selectedIndex, flatResults, close, setSelectedIndex, handleNavigate],
  );

  if (!isOpen) return null;

  // Determine which category headers to show
  let lastType: ResultType | null = null;
  const hasResults = flatResults.length > 0;
  const hasQuery = query.trim().length > 0;

  return (
    <div
      className={clsx(
        "fixed inset-0 z-[70] flex",
        isMobile
          ? "flex-col bg-dark-surface"
          : "bg-black/50 items-start justify-center pt-[15vh]",
      )}
      onClick={(e) => {
        if (!isMobile && e.target === e.currentTarget) close();
      }}
    >
      <div className={clsx(
        "overflow-hidden flex flex-col",
        isMobile
          ? "w-full h-full"
          : "w-full max-w-xl bg-dark-surface border border-dark-border rounded-lg shadow-2xl",
      )}>
        {/* Search input */}
        <div className={clsx(
          "flex items-center gap-3 px-4 py-3 border-b border-dark-border",
          isMobile && "pt-[max(0.75rem,env(safe-area-inset-top))]",
        )}>
          <Search size={18} className="text-dark-text-muted shrink-0" />
          <input
            ref={inputRef}
            type="text"
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="Search anything..."
            className="flex-1 bg-transparent text-dark-text placeholder:text-dark-text-muted focus:outline-none text-sm"
          />
          {isMobile ? (
            <button onClick={close} className="text-dark-text-muted hover:text-dark-text">
              <X size={20} />
            </button>
          ) : (
            <kbd className="hidden sm:inline-flex text-xs text-dark-text-muted bg-dark-bg px-1.5 py-0.5 rounded border border-dark-border">
              ESC
            </kbd>
          )}
        </div>

        {/* Results */}
        <div className={clsx(
          "overflow-y-auto",
          isMobile ? "flex-1" : "max-h-[50vh]",
        )}>
          {isLoading && hasQuery && (
            <div className="px-4 py-6 text-center text-dark-text-muted text-sm">
              Searching...
            </div>
          )}

          {!isLoading && hasQuery && !hasResults && (
            <div className="px-4 py-6 text-center text-dark-text-muted text-sm">
              No results found for "{query}"
            </div>
          )}

          {!hasQuery && (
            <div className="px-4 py-6 text-center text-dark-text-muted text-sm">
              Start typing to search across your workspace
            </div>
          )}

          {hasResults &&
            flatResults.map((item, index) => {
              const showHeader = item.type !== lastType;
              lastType = item.type;

              return (
                <div key={`${item.type}-${item.id}`}>
                  {showHeader && (
                    <div className="px-3 pt-3 pb-1 text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
                      {categoryLabels[item.type]}
                    </div>
                  )}
                  <ResultRow
                    item={item}
                    isSelected={index === selectedIndex}
                    onSelect={() => setSelectedIndex(index)}
                    onNavigate={() => handleNavigate(item)}
                  />
                </div>
              );
            })}
        </div>
      </div>
    </div>
  );
}
