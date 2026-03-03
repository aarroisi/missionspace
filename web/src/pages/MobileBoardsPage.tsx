import { useState } from "react";
import { useNavigate } from "react-router-dom";
import { Kanban, Plus, Star } from "lucide-react";
import { format } from "date-fns";
import { useBoardStore } from "@/stores/boardStore";
import { useToastStore } from "@/stores/toastStore";
import { CreateBoardModal } from "@/components/features/CreateBoardModal";

export function MobileBoardsPage() {
  const navigate = useNavigate();
  const boards = useBoardStore((s) => s.boards) || [];
  const createBoard = useBoardStore((s) => s.createBoard);
  const { success, error } = useToastStore();
  const [showCreateModal, setShowCreateModal] = useState(false);

  const starred = boards.filter((b) => b.starred);
  const unstarred = boards.filter((b) => !b.starred);

  const handleCreateBoard = async (name: string, prefix: string) => {
    try {
      const board = await createBoard(name, prefix);
      success("Board created successfully");
      setShowCreateModal(false);
      navigate(`/boards/${board.id}`);
    } catch (err) {
      error("Error: " + (err as Error).message);
    }
  };

  const renderCard = (board: (typeof boards)[0]) => (
    <div
      key={board.id}
      onClick={() => navigate(`/boards/${board.id}`)}
      className="p-4 bg-dark-surface border border-dark-border rounded-lg hover:border-blue-500 transition-colors cursor-pointer flex items-center gap-3"
    >
      <Kanban size={18} className="text-blue-400 flex-shrink-0" />
      <div className="flex-1 min-w-0">
        <div className="flex items-center gap-2">
          <span className="text-xs font-mono text-dark-text-muted">
            {board.prefix}
          </span>
          <h3 className="font-medium text-dark-text truncate">{board.name}</h3>
        </div>
        {board.createdBy && (
          <p className="text-xs text-dark-text-muted mt-1">
            by {board.createdBy.name} ·{" "}
            {format(new Date(board.insertedAt), "MMM d, yyyy")}
          </p>
        )}
      </div>
      {board.starred && (
        <Star
          size={14}
          className="fill-yellow-400 text-yellow-400 flex-shrink-0"
        />
      )}
    </div>
  );

  return (
    <div className="flex-1 flex flex-col">
      <div className="px-4 py-3 border-b border-dark-border flex items-center justify-between">
        <h1 className="text-lg font-semibold text-dark-text">Boards</h1>
        <button
          onClick={() => setShowCreateModal(true)}
          className="p-2 text-dark-text-muted hover:text-dark-text transition-colors"
        >
          <Plus size={20} />
        </button>
      </div>
      <div className="flex-1 overflow-y-auto p-4">
        {starred.length > 0 && (
          <div className="pb-1 mb-2 text-xs font-semibold text-dark-text-muted uppercase tracking-wider flex items-center gap-1.5">
            <Star size={12} />
            Starred
          </div>
        )}
        {starred.length > 0 && (
          <div className="space-y-2 mb-4">{starred.map(renderCard)}</div>
        )}
        {starred.length > 0 && unstarred.length > 0 && (
          <div className="pb-1 mb-2 text-xs font-semibold text-dark-text-muted uppercase tracking-wider">
            All Boards
          </div>
        )}
        <div className="space-y-2">{unstarred.map(renderCard)}</div>
        {boards.length === 0 && (
          <div className="py-8 text-center text-dark-text-muted text-sm">
            No boards yet
          </div>
        )}
      </div>
      <CreateBoardModal
        isOpen={showCreateModal}
        onClose={() => setShowCreateModal(false)}
        onSubmit={handleCreateBoard}
      />
    </div>
  );
}
